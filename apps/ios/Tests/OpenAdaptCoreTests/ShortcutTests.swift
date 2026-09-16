import XCTest
@testable import OpenAdaptCore

@MainActor
private final class ShortcutShoes: ShoeShortcutController {
    var events: [String] = []
    var statuses: [ShoeSide: ShoeStatus] = [
        .left: ShoeStatus(battery: 85, charger: 1, rawPosition: 20),
        .right: ShoeStatus(battery: 63, charger: 1, rawPosition: 30)
    ]
    var prepareError: Error?
    var failureSide: ShoeSide?
    var validContext = true
    var cancelAfterReads = false
    var suspended: CheckedContinuation<Void, Never>?
    var suspendFit = false
    func prepareShortcut(sides: [ShoeSide]) async throws {
        events.append("prepare")
        if let prepareError { throw prepareError }
    }
    func checkShortcutContext() throws { if !validContext { throw CancellationError() } }
    func shortcutMaximum(_ side: ShoeSide) throws -> Int { 80 }
    func shortcutStatus(_ side: ShoeSide) async throws -> ShoeStatus {
        events.append("read.\(side.rawValue)")
        if cancelAfterReads { validContext = false }
        return statuses[side]!
    }
    func shortcutFit(_ side: ShoeSide, percent: Int) async throws {
        events.append("fit.\(side.rawValue).\(percent)")
        if suspendFit { await withCheckedContinuation { suspended = $0 } }
        if failureSide == side { throw AdaptError.movement }
    }
    func shortcutLights(_ side: ShoeSide, rgb: [UInt8], colorID: String?) async throws {
        events.append("light.\(side.rawValue).\(colorID ?? "off").\(rgb)")
        if failureSide == side { throw AdaptError.timeout }
    }
}

final class ShortcutTests: XCTestCase {
    @MainActor func testInvalidFitFailsBeforeConnecting() async {
        for percent in [-1, 101] {
            let shoes = ShortcutShoes()
            do {
                _ = try await ShoeShortcutRunner.run(.fit([.left: percent]), using: shoes)
                XCTFail("Invalid fit must fail")
            } catch { XCTAssertTrue(shoes.events.isEmpty) }
        }
    }
    @MainActor func testBothPreflightBeforeEitherMotorAndSnappedReply() async throws {
        let shoes = ShortcutShoes()
        let reply = try await ShoeShortcutRunner.run(.fit([.left: 62, .right: 34]), using: shoes)
        XCTAssertEqual(Array(shoes.events.prefix(3)), ["prepare", "read.left", "read.right"])
        XCTAssertEqual(Set(shoes.events.suffix(2)), Set(["fit.left.60", "fit.right.35"]))
        XCTAssertTrue(reply.contains("Left fit confirmed at 60"))
        XCTAssertTrue(reply.contains("Right fit confirmed at 35"))
    }
    @MainActor func testChargingOrLowBatteryOnOtherShoePreventsBothMotors() async {
        for status in [ShoeStatus(battery: 10, charger: 1, rawPosition: 20), ShoeStatus(battery: 90, charger: 2, rawPosition: 20)] {
            let shoes = ShortcutShoes(); shoes.statuses[.right] = status
            do {
                _ = try await ShoeShortcutRunner.run(.fit([.left: 60, .right: 60]), using: shoes)
                XCTFail("Preflight must fail")
            } catch {
                XCTAssertFalse(shoes.events.contains { $0.hasPrefix("fit") })
                XCTAssertTrue(error.localizedDescription.contains("Right shoe"))
            }
        }
    }
    @MainActor func testPartialCompletionIsAnErrorWithoutReplay() async {
        let shoes = ShortcutShoes(); shoes.failureSide = .right
        do {
            _ = try await ShoeShortcutRunner.run(.fit([.left: 60, .right: 60]), using: shoes)
            XCTFail("Partial completion must fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Left shoe confirmed"))
            XCTAssertTrue(error.localizedDescription.contains("Right shoe:"))
            XCTAssertEqual(shoes.events.filter { $0.hasPrefix("fit") }.count, 2)
        }
    }
    @MainActor func testConnectionFailureDoesNotExecuteOrReturnCachedBattery() async {
        let shoes = ShortcutShoes(); shoes.prepareError = AdaptError.timeout
        do {
            _ = try await ShoeShortcutRunner.run(.battery([.left, .right]), using: shoes)
            XCTFail("Must not succeed")
        } catch { XCTAssertEqual(shoes.events, ["prepare"]) }
    }
    @MainActor func testPairChangeAfterReadPreventsMovement() async {
        let shoes = ShortcutShoes(); shoes.cancelAfterReads = true
        do {
            _ = try await ShoeShortcutRunner.run(.fit([.left: 50]), using: shoes)
            XCTFail("Must cancel")
        } catch { XCTAssertFalse(shoes.events.contains { $0.hasPrefix("fit") }) }
    }
    @MainActor func testCanceledRequestDoesNotConnect() async {
        let shoes = ShortcutShoes()
        let task = Task { try await ShoeShortcutRunner.run(.fit([.left: 50]), using: shoes) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Must cancel") }
        catch { XCTAssertTrue(shoes.events.isEmpty) }
    }
    @MainActor func testBatteryIsFreshAndOnlyReadsRequestedSide() async throws {
        let shoes = ShortcutShoes()
        let reply = try await ShoeShortcutRunner.run(.battery([.right]), using: shoes)
        XCTAssertEqual(reply, "Right shoe battery is 63 percent.")
        XCTAssertEqual(shoes.events, ["prepare", "read.right"])
    }
    @MainActor func testLightsOnlyWriteRequestedSideAndOffRemainsDistinct() async throws {
        let shoes = ShortcutShoes()
        _ = try await ShoeShortcutRunner.run(.lights(sides: [.left], rgb: [0, 0, 0], colorID: nil, name: "Off"), using: shoes)
        XCTAssertEqual(shoes.events, ["prepare", "light.left.off.[0, 0, 0]"])
        shoes.events = []
        _ = try await ShoeShortcutRunner.run(.lights(sides: [.right], rgb: [49, 133, 255], colorID: "blue", name: "Blue"), using: shoes)
        XCTAssertEqual(shoes.events, ["prepare", "light.right.blue.[49, 133, 255]"])
    }
    @MainActor func testSuccessWaitsForCompletionAndCancellationIsNotSuccess() async throws {
        let shoes = ShortcutShoes(); shoes.suspendFit = true
        var succeeded = false
        let task = Task {
            let result = try await ShoeShortcutRunner.run(.fit([.left: 50]), using: shoes)
            succeeded = true
            return result
        }
        while shoes.suspended == nil { await Task.yield() }
        XCTAssertFalse(succeeded)
        task.cancel(); shoes.suspended?.resume(); shoes.suspended = nil
        do { _ = try await task.value; XCTFail("Canceled completion must not succeed") }
        catch { XCTAssertFalse(succeeded) }
    }
}
