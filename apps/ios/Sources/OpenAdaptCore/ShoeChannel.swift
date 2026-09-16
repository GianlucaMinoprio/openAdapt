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
        try check()
        guard !active else { throw AdaptError.busy }
        let packets = FragmentReceiver.fragments(try WireMessage.request(opcode, value: value), sequence: sent % 64)
        active = true; responseAllowed = false
        let timer = Task { [weak self, timeoutNanoseconds] in
            do { try await Task.sleep(nanoseconds: timeoutNanoseconds) } catch { return }
            self?.close(AdaptError.timeout)
        }
        defer { timer.cancel(); active = false; responseAllowed = false }
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
                let reply = try await nextMessage()
                guard reply.opcode == opcode, reply.action == 1 else { throw AdaptError.malformedMessage }
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
}
