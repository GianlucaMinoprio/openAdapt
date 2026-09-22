import XCTest
@testable import OpenAdaptCore

final class EnrollmentCryptoTests: XCTestCase {
    func testFixedWidthSecretsAgainstIndependentPythonVectors() throws {
        // Synthetic x=3, peer public=2^5, shared=2^15. Python hashlib fixtures
        // include leading zeros to each RFC prime's byte width.
        let keys = ["add40626005c2f6b72c5d410571a8227", "0bd822ed5926edce93fccfee0412f6e3",
                    "b801140388f4b7c0f77538e54ef9e1d8", "a7b295dde70e154b27134ff76ff23ea1"]
        for group in 0..<4 {
            let exchange = try ShoeEnrollmentExchange(group: group, restoring: Data([3]))
            XCTAssertEqual(try exchange.publicKey(), Data([8]))
            XCTAssertEqual(try exchange.derive(peerPublicKey: Data([32])), Data(hex: keys[group]))
            let restored = try ShoeEnrollmentExchange(group: group, restoring: exchange.recoveryKey())
            XCTAssertEqual(try restored.publicKey(), try exchange.publicKey())
            for invalid in [Data(), Data([0]), Data([1]), Data(repeating: 255, count: 257)] {
                XCTAssertThrowsError(try exchange.derive(peerPublicKey: invalid))
            }
        }
        XCTAssertThrowsError(try ShoeEnrollmentExchange(group: 4))
        XCTAssertThrowsError(try ShoeEnrollmentExchange(group: 1, restoring: Data([1])))
    }
    func testEnrollmentSchemaIsRestricted() throws {
        XCTAssertEqual(try WireMessage(opcode: 110, action: 1).fields()[1]?.integer, 0)
        XCTAssertThrowsError(try WireMessage(opcode: 110, action: 1, payload: Data([8, 4])).fields())
        XCTAssertThrowsError(try WireMessage(opcode: 111, action: 3, payload: Data([0])).fields())
        XCTAssertThrowsError(try WireMessage.request(110))
        XCTAssertThrowsError(try WireMessage.request(111, value: Data([2])))
        XCTAssertThrowsError(try ShoeCrypto.validate(key: Data(repeating: 1, count: 16)))
    }
}

@MainActor
private final class EnrollmentPeer {
    var group = 1
    var receiver = FragmentReceiver()
    var sequence = 0
    var commands: [UInt8] = []
    var key: Data?
    var omitPublicReply = false
    var duplicateReady = false
    var badReady = false
    var corruptSetupProof = false
    var readyCount = 0
    var records: [ShoeEnrollmentRecord] = []
    var publicReplyFinalSequence: Int?
    var savedBeforeFinalAcknowledgement = false
    lazy var channel = ShoeChannel(timeout: 0.1) { [weak self] packet in try self?.write(packet) }
    lazy var session = ShoeSession(channel: channel)
    func reply(_ opcode: UInt8, action: UInt8 = 1, payload: Data = Data()) throws {
        let packets = FragmentReceiver.fragments(try WireMessage(opcode: opcode, action: action, payload: payload), sequence: sequence)
        sequence = (sequence + packets.count) % 64
        if opcode == 111, action == 1 { publicReplyFinalSequence = Int(packets.last![0] & 63) }
        for packet in packets { channel.receive(packet) }
    }
    func write(_ packet: Data) throws {
        if packet[0] & 64 != 0 {
            if Int(packet[0] & 63) == publicReplyFinalSequence {
                savedBeforeFinalAcknowledgement = records.last?.candidateKey != nil
            }
            return
        }
        let result = try receiver.feed(packet)
        if let ack = result.acknowledgement { channel.receive(ack) }
        guard let message = result.message else { return }
        commands.append(message.opcode)
        switch message.opcode {
        case 112:
            let nonce = Data(message.payload.dropFirst(2))
            let clear = Data("TEST".utf8) + (corruptSetupProof && key == nil ? Data(repeating: 0, count: 12) : nonce.suffix(12))
            let proof = try key.map { try ShoeCrypto.crypt(clear, key: $0) } ?? ShoeCrypto.setupBlock(clear)
            try reply(112, payload: Data([10, 16]) + proof + Data([18, 16]) + Data(repeating: 7, count: 16))
        case 113:
            let challenge = Data(repeating: 7, count: 16)
            let expected = try key.map { try ShoeCrypto.crypt(challenge, key: $0) } ?? ShoeCrypto.setupBlock(challenge)
            XCTAssertEqual(Data(message.payload.dropFirst(2)), expected)
            try reply(113)
        case 110:
            XCTAssertEqual(records.last?.phase, .exchangeStarted)
            try reply(110, payload: Data([8, UInt8(group)]))
        case 111:
            XCTAssertNotNil(records.last?.privateKey)
            let peer = try ShoeEnrollmentExchange(group: group)
            let clientPublic = try XCTUnwrap(message.fields()[1]?.bytes)
            key = try peer.derive(peerPublicKey: clientPublic)
            try reply(111, action: 3, payload: badReady ? Data([0]) : Data())
            if duplicateReady { try reply(111, action: 3) }
            if !omitPublicReply {
                let value = try peer.publicKey()
                try reply(111, payload: Data([10] + WireMessage.varint(UInt32(value.count))) + value)
            }
        default: XCTFail("Enrollment must not issue other commands")
        }
    }
    func record(side: ShoeSide = .right) -> ShoeEnrollmentRecord {
        ShoeEnrollmentRecord(peripheralID: UUID(), advertisedName: "004-SYNTHETIC-001",
            advertisement: ShoeAdvertisement(manufacturerData: Data([0x78, 0, 0xaf, 0x28, 1, 2, 3, 4, 5, side == .left ? 0 : 1]))!)
    }
    func enroll(_ record: ShoeEnrollmentRecord? = nil) async throws -> ShoeEnrollmentRecord {
        try await ShoeEnrollment.run(session: session, record: record ?? self.record(),
            save: { self.records.append($0) }, onReady: { self.readyCount += 1 }, exchangeTimeout: 0.1)
    }
}

final class EnrollmentSessionTests: XCTestCase {
    @MainActor func testBothObservedGroupsPersistBeforeTransmittingAndBeforeFinalAck() async throws {
        for group in [1, 2] {
            let peer = EnrollmentPeer(); peer.group = group
            defer { peer.channel.close() }
            let record = try await peer.enroll()
            XCTAssertEqual(peer.commands, [112, 113, 110, 111, 112, 113])
            XCTAssertEqual(record.phase, .verified)
            XCTAssertEqual(record.candidateKey, peer.key)
            XCTAssertEqual(peer.readyCount, 1)
            if peer.publicReplyFinalSequence! % 2 == 1 { XCTAssertTrue(peer.savedBeforeFinalAcknowledgement) }
            XCTAssertEqual(peer.records.map(\.phase), [.checking, .exchangeStarted, .exchangeStarted, .candidate, .verified])
        }
    }
    @MainActor func testSavedCandidateRecoveryNeverReenrolls() async throws {
        let first = EnrollmentPeer(); defer { first.channel.close() }
        var saved = try await first.enroll(); saved.phase = .candidate
        let next = EnrollmentPeer(); next.key = saved.candidateKey
        defer { next.channel.close() }
        let verified = try await next.enroll(saved)
        XCTAssertEqual(next.commands, [112, 113])
        XCTAssertEqual(next.readyCount, 0)
        XCTAssertEqual(verified.phase, .verified)
    }
    @MainActor func testInterruptedExchangeDoesNotReplayAndStoredRecoverySecretsSurvive() async throws {
        let peer = EnrollmentPeer(); peer.omitPublicReply = true
        do { _ = try await peer.enroll(); XCTFail("Missing ACK must fail") } catch {}
        XCTAssertEqual(peer.commands, [112, 113, 110, 111])
        let pending = try XCTUnwrap(peer.records.last)
        XCTAssertNotNil(pending.privateKey)
        let next = EnrollmentPeer()
        do { _ = try await next.enroll(pending); XCTFail("Must not reenroll") }
        catch { XCTAssertEqual(error as? ShoeEnrollmentError, .interrupted) }
        XCTAssertTrue(next.commands.isEmpty)
    }
    @MainActor func testBadSetupProofStopsBeforeEnrollment() async {
        let peer = EnrollmentPeer(); peer.corruptSetupProof = true
        do { _ = try await peer.enroll(); XCTFail("Must reject setup proof") }
        catch { XCTAssertEqual(error as? ShoeEnrollmentError, .notReady) }
        XCTAssertEqual(peer.commands, [112])
    }
    @MainActor func testMalformedAndDuplicateReadyEventsFailWithoutRetry() async {
        for duplicate in [false, true] {
            let peer = EnrollmentPeer(); peer.badReady = !duplicate; peer.duplicateReady = duplicate
            do { _ = try await peer.enroll(); XCTFail("Bad event must fail") } catch {}
            XCTAssertEqual(peer.commands, [112, 113, 110, 111])
            XCTAssertTrue(peer.channel.isClosed)
        }
    }
    @MainActor func testStorageFailureStopsBeforeEnrollmentCommand() async {
        let peer = EnrollmentPeer()
        do {
            _ = try await ShoeEnrollment.run(session: peer.session, record: peer.record(), save: { record in
                if record.phase == .exchangeStarted { throw ShoeEnrollmentError.storage }
                peer.records.append(record)
            }, onReady: {})
            XCTFail("Storage failure must stop setup")
        } catch {}
        XCTAssertEqual(peer.commands, [112, 113])
    }
    @MainActor func testCandidateSaveFailureDoesNotAcknowledgePeerOrAuthenticate() async {
        let peer = EnrollmentPeer(); peer.group = 2
        do {
            _ = try await ShoeEnrollment.run(session: peer.session, record: peer.record(), save: { record in
                if record.phase == .candidate { throw ShoeEnrollmentError.storage }
                peer.records.append(record)
            }, onReady: {})
            XCTFail("Must stop if candidate cannot be saved")
        } catch {}
        XCTAssertEqual(peer.commands, [112, 113, 110, 111])
        XCTAssertFalse(peer.savedBeforeFinalAcknowledgement)
        XCTAssertEqual(peer.records.last?.phase, .exchangeStarted)
    }
    @MainActor func testCancellationKeepsJournalAndNeverRetries() async throws {
        let peer = EnrollmentPeer(); peer.omitPublicReply = true
        let task = Task { try await peer.enroll() }
        for _ in 0..<50 where peer.readyCount == 0 { try await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(peer.readyCount, 1)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch {}
        XCTAssertEqual(peer.commands, [112, 113, 110, 111])
        XCTAssertNotNil(peer.records.last?.privateKey)
        XCTAssertTrue(peer.channel.isClosed)
    }
    @MainActor func testNativePairRequiresBothVerifiedKeysAndDoesNotInventCalibrationOrMacs() async throws {
        let left = EnrollmentPeer(), right = EnrollmentPeer()
        defer { left.channel.close(); right.channel.close() }
        let l = try await left.enroll(left.record(side: .left))
        var r = try await right.enroll()
        let pair = try ShoePair.enrolled([l, r])
        let restored = try JSONDecoder().decode(ShoePair.self, from: JSONEncoder().encode(pair))
        try restored.validate()
        for side in ShoeSide.allCases {
            let credential = restored.credential(side)
            XCTAssertNotNil(credential.peripheralID)
            XCTAssertTrue(credential.address.isEmpty)
            XCTAssertEqual(credential.fitMaximum, 0)
            XCTAssertFalse(credential.hasFitCalibration)
            XCTAssertThrowsError(try FitScale.rawTarget(percent: 60, maximum: credential.fitMaximum))
        }
        r.phase = .candidate
        XCTAssertThrowsError(try ShoePair.enrolled([l, r]))
        XCTAssertThrowsError(try ShoePair.enrolled([l, l]))
    }
}
