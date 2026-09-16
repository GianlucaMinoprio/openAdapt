import XCTest
@testable import OpenAdaptCore

final class WireTests: XCTestCase {
    func testKnownRequestVectors() throws {
        XCTAssertEqual(try WireMessage.request(0).encoded, Data([0, 2, 0, 8, 8]))
        XCTAssertEqual(try WireMessage.request(3, value: Data([49])).encoded, Data([3, 2, 0, 8, 49]))
        XCTAssertEqual(try WireMessage.request(3, value: Data([0])).encoded, Data([3, 0, 0]))
        XCTAssertEqual(try WireMessage.request(20).encoded, Data([20, 0, 192]))
        XCTAssertEqual(try WireMessage.request(222, value: Data([255, 0, 1])).encoded,
                       Data([222, 9, 0, 8, 4, 16, 128, 254, 3, 32, 128, 2]))
        XCTAssertThrowsError(try WireMessage.request(110))
        XCTAssertThrowsError(try WireMessage.request(111))
        XCTAssertThrowsError(try WireMessage.request(3, value: Data([101])))
    }
    func testCalibratedTargetsAndRounding() throws {
        XCTAssertEqual(try FitScale.rawTarget(percent: 80, maximum: 61), 49)
        XCTAssertEqual(try FitScale.rawTarget(percent: 80, maximum: 65), 52)
        XCTAssertEqual(try FitScale.rawTarget(percent: 50, maximum: 61), 31)
        XCTAssertThrowsError(try FitScale.rawTarget(percent: 101, maximum: 61))
        XCTAssertThrowsError(try FitScale.rawTarget(percent: 80, maximum: 0))
        XCTAssertEqual(FitScale.snapped(83), 85)
    }
    func testFragmentSequenceWrapAndAcknowledgements() throws {
        var receiver = FragmentReceiver()
        for index in 0..<140 {
            let message = try WireMessage(opcode: 4, action: 1, payload: Data([8, UInt8(index % 100)]))
            let packets = FragmentReceiver.fragments(message, sequence: index % 64)
            let result = try receiver.feed(packets[0])
            XCTAssertEqual(result.message, message)
            XCTAssertEqual(result.acknowledgement, index % 2 == 1 ? Data([UInt8(index % 64) | 192, 0]) : nil)
        }
    }
    func testRejectDuplicateAndMalformedFragments() throws {
        var receiver = FragmentReceiver()
        let packet = Data([128, 4, 0, 64])
        _ = try receiver.feed(packet)
        XCTAssertThrowsError(try receiver.feed(packet))
        XCTAssertThrowsError(try WireMessage.decode(Data([4, 2, 64, 8])))
        XCTAssertThrowsError(try WireMessage(opcode: 4, action: 1, payload: Data([8, 1, 8, 2])).fields())
        XCTAssertThrowsError(try WireMessage(opcode: 4, action: 1, payload: Data([8, 128, 0])).fields())
        XCTAssertThrowsError(try WireMessage(opcode: 4, action: 1, payload: Data([8, 101])).fields())
        XCTAssertThrowsError(try WireMessage(opcode: 81, action: 1, payload: Data([8, 4])).fields())
        XCTAssertThrowsError(try WireMessage(opcode: 112, action: 1, payload: Data([10, 16]) + Data(repeating: 0, count: 16)).fields())
    }
    func testFirmwareIsExactlyAllowlisted() throws {
        try ShoeCrypto.verifyFirmware(Data("2.4.3M".utf8))
        try ShoeCrypto.verifyFirmware(Data("2.4.3M".utf8) + Data(repeating: 0, count: 14))
        for value in [Data("2.4.4M".utf8), Data("2.4.3M".utf8) + Data([0]), Data("2.4.3M".utf8) + Data(repeating: 1, count: 14)] {
            XCTAssertThrowsError(try ShoeCrypto.verifyFirmware(value))
        }
    }
    func testAESKnownVectorAndSuffixProof() throws {
        let key = Data(hex: "000102030405060708090a0b0c0d0e0f")!
        let block = Data(hex: "00112233445566778899aabbccddeeff")!
        XCTAssertEqual(try ShoeCrypto.crypt(block, key: key), Data(hex: "69c4e0d86a7b0430d8cdb78070b4c55a")!)
        let proof = try ShoeCrypto.crypt(Data("TEST".utf8) + block.suffix(12), key: key)
        try ShoeCrypto.verify(proof: proof, nonce: block, key: key)
        XCTAssertThrowsError(try ShoeCrypto.verify(proof: proof, nonce: Data(repeating: 0, count: 16), key: key))
        XCTAssertThrowsError(try ShoeCrypto.validate(key: Data(repeating: 1, count: 16)))
    }
}

final class ImportTests: XCTestCase {
    private func profile(maximum: Int = 61, rightKey: String = "101112131415161718191a1b1c1d1e1f") -> Data {
        // Synthetic identifiers and keys only.
        Data("""
        {"version":1,"shoes":{
          "left":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TEST-001","address":"00:00:00:00:00:01","key_hex":"000102030405060708090a0b0c0d0e0f","fit_maximum":\(maximum)},
          "right":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TEST-001","address":"00:00:00:00:00:02","key_hex":"\(rightKey)","fit_maximum":65}}}
        """.utf8)
    }
    func testLegacyAndCatalogImport() throws {
        let legacy = try ProfileImport.decode(profile())
        XCTAssertEqual(legacy[0].credential(.left).fitMaximum, 61)
        let pairs = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy))
        let catalog = try JSONSerialization.data(withJSONObject: ["version": 2, "pairs": pairs])
        XCTAssertEqual(try ProfileImport.decode(catalog), legacy)
    }
    func testRejectInvalidAndConflictingProfiles() {
        XCTAssertThrowsError(try ProfileImport.decode(profile(maximum: 0)))
        XCTAssertThrowsError(try ProfileImport.decode(profile(rightKey: "000102030405060708090a0b0c0d0e0f")))
        XCTAssertThrowsError(try ProfileImport.decode(profile(rightKey: "01010101010101010101010101010101")))
        XCTAssertThrowsError(try ProfileImport.decode(Data("{\"version\":2,\"pairs\":[]}".utf8)))
        XCTAssertThrowsError(try ProfileImport.decode(Data(repeating: 0, count: 262_145)))
    }
}

@MainActor
private final class SyntheticShoe {
    let key = Data(0..<16)
    var receiver = FragmentReceiver()
    var txSequence = 0
    var commands = [UInt8]()
    var raw = 0
    var battery = 100
    var charger = 1
    var corruptProof = false
    var earlyCompletion = false
    var omitCompletion = false
    var wrongReadback = false
    var moved = false
    lazy var channel = ShoeChannel(timeout: 0.15) { [weak self] packet in try self?.write(packet) }
    lazy var session = ShoeSession(channel: channel)
    func reply(_ op: UInt8, action: UInt8 = 1, payload: Data = Data()) throws {
        let message = try WireMessage(opcode: op, action: action, payload: payload)
        let fragments = FragmentReceiver.fragments(message, sequence: txSequence)
        txSequence = (txSequence + fragments.count) % 64
        for fragment in fragments { channel.receive(fragment) }
    }
    func write(_ packet: Data) throws {
        if packet[0] & 64 != 0 { return }
        let result = try receiver.feed(packet)
        if let ack = result.acknowledgement { channel.receive(ack) }
        guard let message = result.message else { return }
        commands.append(message.opcode)
        switch message.opcode {
        case 112:
            let nonce = Data(message.payload.dropFirst(2))
            let block = corruptProof ? Data(repeating: 0, count: 16) : Data("TEST".utf8) + nonce.suffix(12)
            let proof = try ShoeCrypto.crypt(block, key: key)
            try reply(112, payload: Data([10, 16]) + proof + Data([18, 16]) + Data(repeating: 7, count: 16))
        case 113:
            XCTAssertEqual(Data(message.payload.dropFirst(2)), try ShoeCrypto.crypt(Data(repeating: 7, count: 16), key: key))
            try reply(113)
        case 81: try reply(81, payload: Data([8, UInt8(charger), 32, UInt8(battery)]))
        case 4: try reply(4, payload: Data([8, UInt8(wrongReadback && moved ? 0 : raw)]))
        case 3:
            raw = message.payload.isEmpty ? 0 : Int(message.payload[1]); moved = true
            if earlyCompletion { try reply(5, action: 3, payload: Data([16, UInt8(raw)])) }
            try reply(3)
            if !omitCompletion && !earlyCompletion { try reply(5, action: 3, payload: Data([16, UInt8(raw)])) }
        case 0, 20, 222, 237: try reply(message.opcode)
        default: XCTFail("Unexpected opcode")
        }
    }
}

final class SessionTests: XCTestCase {
    @MainActor func testAuthenticatedPersistentControlAndSequenceWrap() async throws {
        let peer = SyntheticShoe(); defer { peer.channel.close() }
        try await peer.session.authenticate(key: peer.key)
        for index in 0..<35 {
            _ = try await peer.session.readStatus()
            let result = try await peer.session.setFit(percent: index % 2 == 0 ? 80 : 30, maximum: 61)
            XCTAssertEqual(result.rawPosition, index % 2 == 0 ? 49 : 18)
        }
        try await peer.session.setColor(Data([0, 255, 0]))
        XCTAssertEqual(peer.commands.filter { $0 == 112 }.count, 1)
        XCTAssertEqual(Array(peer.commands.suffix(3)), [237, 222, 20])
    }
    @MainActor func testWrongKeyStopsBeforeClientProofOrMotor() async {
        let peer = SyntheticShoe(); peer.corruptProof = true
        do { try await peer.session.authenticate(key: peer.key); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(peer.commands, [112]); XCTAssertTrue(peer.channel.isClosed)
    }
    @MainActor func testMotorRequiresAuthentication() async {
        let peer = SyntheticShoe(); defer { peer.channel.close() }
        do { _ = try await peer.session.setFit(percent: 80, maximum: 61); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(peer.commands, [])
    }
    @MainActor func testBatteryChargerAndCalibrationPreflight() async throws {
        for condition in 0..<3 {
            let peer = SyntheticShoe(); defer { peer.channel.close() }
            try await peer.session.authenticate(key: peer.key)
            if condition == 0 { peer.battery = 19 }
            if condition == 1 { peer.charger = 2 }
            if condition == 2 { peer.raw = 65 }
            do { _ = try await peer.session.setFit(percent: 80, maximum: 61); XCTFail("Expected failure") } catch {}
            XCTAssertEqual(peer.commands, [112, 113, 81, 4])
        }
    }
    @MainActor func testCompletionOrderingTimeoutAndReadbackNeverReplay() async throws {
        for condition in 0..<3 {
            let peer = SyntheticShoe(); defer { peer.channel.close() }
            try await peer.session.authenticate(key: peer.key)
            peer.earlyCompletion = condition == 0
            peer.omitCompletion = condition == 1
            peer.wrongReadback = condition == 2
            do { _ = try await peer.session.setFit(percent: 80, maximum: 61); XCTFail("Expected failure") } catch {}
            XCTAssertEqual(peer.commands.filter { $0 == 3 }.count, 1)
            XCTAssertTrue(peer.channel.isClosed)
            do { _ = try await peer.session.setFit(percent: 80, maximum: 61); XCTFail("Expected closed") } catch {}
            XCTAssertEqual(peer.commands.filter { $0 == 3 }.count, 1)
        }
    }
    @MainActor func testCancellationAndDisconnectWakeWaiters() async throws {
        for cancel in [true, false] {
            let channel = ShoeChannel(timeout: 2) { _ in }
            let task = Task { try await channel.request(81) }
            await Task.yield()
            if cancel { task.cancel() } else { channel.close() }
            do { _ = try await task.value; XCTFail("Expected failure") } catch {}
            XCTAssertTrue(channel.isClosed)
        }
    }
    @MainActor func testIdleButtonMovementAndUnexpectedIdleMessages() async throws {
        let peer = SyntheticShoe(); defer { peer.channel.close() }
        try await peer.session.authenticate(key: peer.key)
        let updated = expectation(description: "Physical shoe button update")
        peer.channel.onIdlePosition = { value in XCTAssertEqual(value, 30); updated.fulfill() }
        try peer.reply(5, action: 3, payload: Data([16, 30]))
        await fulfillment(of: [updated], timeout: 1)
        try peer.reply(3)
        for _ in 0..<5 { await Task.yield() }
        XCTAssertTrue(peer.channel.isClosed)
    }
}
