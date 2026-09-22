import Foundation

/// One persistent CoreRF session. Every failure closes it; writes are never replayed.
@MainActor
public final class ShoeChannel {
    public typealias Writer = (Data) async throws -> Void
    private let write: Writer
    private var receiver = FragmentReceiver()
    private var sent = 0
    private var acknowledged = 0
    private var hasAcknowledgement = false
    private var expectedAck = 1
    private var active = false
    private var responseAllowed = false
    private var messages = [WireMessage]()
    private var waiter: CheckedContinuation<Void, Never>?
    private var failure: Error?
    private var pump: Task<Void, Never>?
    private var input: AsyncStream<Data>.Continuation!
    private var captureEnrollmentPeer: ((Data) throws -> Void)?
    public var onIdlePosition: ((Int) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public var isClosed: Bool { failure != nil }
    private let timeoutNanoseconds: UInt64

    public init(timeout: TimeInterval = 8, write: @escaping Writer) {
        self.write = write
        self.timeoutNanoseconds = UInt64(max(0.01, min(120, timeout)) * 1_000_000_000)
        let stream = AsyncStream<Data>(bufferingPolicy: .bufferingOldest(128)) { input = $0 }
        pump = Task { [weak self] in
            for await packet in stream {
                guard let self, !self.isClosed else { break }
                do { try await self.consume(packet) }
                catch { self.close(error) }
            }
        }
    }
    public func receive(_ packet: Data) {
        guard !isClosed else { return }
        guard (2...20).contains(packet.count) else { close(AdaptError.malformedMessage); return }
        if case .dropped = input.yield(packet) { close(AdaptError.malformedMessage) }
    }
    public func close(_ error: Error = AdaptError.disconnected) {
        guard failure == nil else { return }
        failure = error; input.finish(); pump?.cancel(); signal()
        onFailure?(error)
    }
    private func signal() { let continuation = waiter; waiter = nil; continuation?.resume() }
    private func check() throws { if let failure { throw failure }; try Task.checkCancellation() }
    private var windowFull: Bool { sent - acknowledged - (hasAcknowledgement ? 1 : 0) >= 4 }
    private func wait() async {
        await withCheckedContinuation { waiter = $0 }
    }
    private func consume(_ packet: Data) async throws {
        let bytes = [UInt8](packet)
        if bytes[0] & 64 != 0 {
            guard bytes.count == 2, bytes[0] & 192 == 192, bytes[1] == 0 else { throw AdaptError.sequence }
            let sequence = Int(bytes[0] & 63)
            let advance = (sequence - acknowledged % 64 + 64) % 64
            guard sequence == expectedAck, advance > 0, acknowledged + advance < sent else { throw AdaptError.sequence }
            acknowledged += advance; hasAcknowledgement = true; expectedAck = (sequence + 2) % 64
            signal(); return
        }
        let result = try receiver.feed(packet)
        // Save the peer value/candidate before acknowledging its final fragment.
        // A failed durable write closes the channel without sending that ACK.
        if let message = result.message, message.opcode == 111, message.action == 1,
           let capture = captureEnrollmentPeer {
            guard active, responseAllowed, let peer = try message.fields()[1]?.bytes else {
                throw AdaptError.malformedMessage
            }
            try capture(peer)
            captureEnrollmentPeer = nil
        }
        if let ack = result.acknowledgement { try await write(ack); try check() }
        guard let message = result.message else { return }
        if !active {
            guard message.opcode == 5, message.action == 3 else { throw AdaptError.malformedMessage }
            let fields = try message.fields()
            guard fields[1]?.integer == 0, let position = fields[2]?.integer else { throw AdaptError.movement }
            onIdlePosition?(position); return
        }
        guard responseAllowed, messages.count < 16 else { throw AdaptError.malformedMessage }
        messages.append(message); signal()
    }
    private func nextMessage() async throws -> WireMessage {
        while true {
            try check()
            if !messages.isEmpty { return messages.removeFirst() }
            await wait()
        }
    }
    public func request(_ opcode: UInt8, value: Data = Data()) async throws -> [Int: WireMessage.Field] {
        try await exchange(opcode, value: value, movementTarget: nil)
    }
    /// These operations are only used by the explicit enrollment coordinator.
    /// The normal request API still rejects opcodes 110/111.
    public func enrollmentGroup() async throws -> Int {
        let reply = try await perform(try WireMessage(opcode: 110, action: 0), movementTarget: nil)
        guard let group = reply[1]?.integer else { throw AdaptError.malformedMessage }
        return group
    }
    public func exchangeEnrollmentKey(_ publicKey: Data, timeout: TimeInterval = 33,
                                     onReady: @escaping () -> Void,
                                     capturePeer: @escaping (Data) throws -> Void) async throws {
        guard (1...256).contains(publicKey.count) else { throw AdaptError.malformedMessage }
        let payload = Data([10] + WireMessage.varint(UInt32(publicKey.count))) + publicKey
        _ = try await perform(try WireMessage(opcode: 111, action: 0, payload: payload), movementTarget: nil,
            enrollmentReady: onReady, capturePeer: capturePeer, timeout: timeout)
    }
    public func move(raw: Int) async throws -> Int {
        guard (0...100).contains(raw) else { throw AdaptError.calibration }
        _ = try await request(0)
        do {
            let result = try await exchange(3, value: Data([UInt8(raw)]), movementTarget: raw)
            return result[2]!.integer!
        } catch {
            // Only a best-effort Stop on the existing link, never another target.
            // Delivery cannot be confirmed after a protocol or radio failure.
            if !windowFull {
                let packet = FragmentReceiver.fragments(try WireMessage.request(0), sequence: sent % 64)[0]
                try? await write(packet)
            }
            throw error
        }
    }
    private func exchange(_ opcode: UInt8, value: Data, movementTarget: Int?) async throws -> [Int: WireMessage.Field] {
        try await perform(WireMessage.request(opcode, value: value), movementTarget: movementTarget)
    }
    private func perform(_ request: WireMessage, movementTarget: Int?,
                         enrollmentReady: (() -> Void)? = nil,
                         capturePeer: ((Data) throws -> Void)? = nil,
                         timeout: TimeInterval? = nil) async throws -> [Int: WireMessage.Field] {
        try check()
        guard !active else { throw AdaptError.busy }
        let opcode = request.opcode
        let packets = FragmentReceiver.fragments(request, sequence: sent % 64)
        active = true; responseAllowed = false
        captureEnrollmentPeer = capturePeer
        let duration = timeout.map { UInt64(max(0.01, min(33, $0)) * 1_000_000_000) } ?? timeoutNanoseconds
        let timer = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: duration) } catch { return }
            self?.close(AdaptError.timeout)
        }
        defer { timer.cancel(); active = false; responseAllowed = false; captureEnrollmentPeer = nil }
        return try await withTaskCancellationHandler {
            do {
                guard messages.isEmpty else { throw AdaptError.malformedMessage }
                for (index, packet) in packets.enumerated() {
                    while windowFull { try check(); await wait() }
                    try check()
                    responseAllowed = index == packets.count - 1
                    sent += 1
                    try await write(packet)
                    try check()
                }
                var reply = try await nextMessage()
                var sawReady = false
                while opcode == 111, reply.opcode == 111, reply.action == 3 {
                    guard let enrollmentReady, !sawReady else { throw AdaptError.malformedMessage }
                    _ = try reply.fields()
                    sawReady = true; enrollmentReady()
                    reply = try await nextMessage()
                }
                guard reply.opcode == opcode, reply.action == 1 else { throw AdaptError.malformedMessage }
                if opcode == 111, !sawReady { throw AdaptError.malformedMessage }
                let fields = try reply.fields()
                guard let target = movementTarget else { return fields }
                let completion = try await nextMessage()
                guard completion.opcode == 5, completion.action == 3 else { throw AdaptError.movement }
                let result = try completion.fields()
                guard result[1]?.integer == 0, let position = result[2]?.integer, abs(position - target) <= 1 else {
                    throw AdaptError.movement
                }
                return result
            } catch { close(error); throw error }
        } onCancel: {
            Task { @MainActor [weak self] in self?.close(CancellationError()) }
        }
    }
}

@MainActor
public final class ShoeSession {
    public let channel: ShoeChannel
    private var authenticated = false
    private var active = false
    public var isExecuting: Bool { active }
    public init(channel: ShoeChannel) { self.channel = channel }
    public func authenticate(key: Data) async throws {
        guard !authenticated, !active else { throw AdaptError.busy }
        try ShoeCrypto.validate(key: key)
        active = true; defer { active = false }
        do {
            let nonce = try ShoeCrypto.nonce()
            let fields = try await channel.request(112, value: nonce)
            guard let proof = fields[1]?.bytes, let challenge = fields[2]?.bytes else { throw AdaptError.authentication }
            try ShoeCrypto.verify(proof: proof, nonce: nonce, key: key)
            _ = try await channel.request(113, value: ShoeCrypto.crypt(challenge, key: key))
            authenticated = true
        } catch { channel.close(error); throw error }
    }
    private func begin() throws {
        guard authenticated, !channel.isClosed else { throw AdaptError.disconnected }
        guard !active else { throw AdaptError.busy }
        active = true
    }
    private func status() async throws -> ShoeStatus {
        let battery = try await channel.request(81)
        let position = try await channel.request(4)
        return ShoeStatus(battery: battery[4]!.integer!, charger: battery[1]!.integer!, rawPosition: position[1]!.integer!)
    }
    public func readStatus() async throws -> ShoeStatus {
        try begin(); defer { active = false }
        return try await status()
    }
    public func setFit(percent: Int, maximum: Int) async throws -> ShoeStatus {
        let target = try FitScale.rawTarget(percent: percent, maximum: maximum)
        try begin(); defer { active = false }
        let before = try await status()
        guard before.charger == 1 else { throw AdaptError.charging }
        guard before.battery >= 20 else { throw AdaptError.lowBattery }
        guard before.rawPosition <= maximum + 1 else { throw AdaptError.calibration }
        let completion = try await channel.move(raw: target)
        let after = try await channel.request(4)[1]!.integer!
        guard abs(after - target) <= 1, abs(after - completion) <= 1 else {
            channel.close(AdaptError.movement); throw AdaptError.movement
        }
        return ShoeStatus(battery: before.battery, charger: before.charger, rawPosition: after)
    }
    public func setColor(_ rgb: Data, preview: Bool = true) async throws {
        guard rgb.count == 3 else { throw AdaptError.malformedMessage }
        try begin(); defer { active = false }
        _ = try await channel.request(237)
        _ = try await channel.request(222, value: rgb)
        if preview { _ = try await channel.request(20) }
    }
    public func setAutoLace(enabled: Bool) async throws {
        try begin(); defer { active = false }
        // This changes the foot-presence setting only. It does not overwrite
        // the shoe-stored preset or issue a motor target.
        _ = try await channel.request(82, value: Data([enabled ? 1 : 0]))
    }
    public func readGestures() async throws -> ShoeGestureConfiguration {
        try begin(); defer { active = false }
        return try await gestureConfiguration()
    }
    private func gestureConfiguration() async throws -> ShoeGestureConfiguration {
        let result = try await channel.request(179)
        guard let configuration = result[1]?.gestures else { throw AdaptError.malformedMessage }
        return configuration
    }
    public func enableDoubleTapUntie() async throws {
        try await setQuickUnlace(enabled: true)
    }
    public func setQuickUnlace(enabled: Bool) async throws {
        try begin(); defer { active = false }
        do {
            let before = try await gestureConfiguration()
            // Replacement semantics are unknown: never overwrite additional or
            // unfamiliar mappings. Already-enabled shoes need no setting write.
            guard let current = before.doubleTapEnabled else { throw ShoeGestureError.unsupportedConfiguration }
            if current == enabled { return }
            let reply = try await channel.request(178, value: Data([enabled ? 1 : 0]))
            switch reply[1]?.integer {
            case 3: break
            case 1: throw ShoeGestureError.criticalBattery
            case 2: throw ShoeGestureError.activeSession
            default: throw ShoeGestureError.notConfirmed
            }
            guard try await gestureConfiguration().doubleTapEnabled == enabled else {
                throw ShoeGestureError.notConfirmed
            }
        } catch { channel.close(error); throw error }
    }
}
