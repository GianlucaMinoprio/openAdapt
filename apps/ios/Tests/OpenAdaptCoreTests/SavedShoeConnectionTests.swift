import XCTest
@testable import OpenAdaptCore

final class SavedShoeConnectionTests: XCTestCase {
    @MainActor func testSameNamedShoesKeepTheirSeparateRememberedIdentities() throws {
        let left = UUID(), right = UUID()
        let nearby = [left: "shared-name", right: "shared-name"]
        XCTAssertEqual(try SavedShoeConnection.discoveryCandidate(in: nearby, expectedName: "shared-name", rememberedID: left, allowsNameMatch: false), left)
        XCTAssertEqual(try SavedShoeConnection.discoveryCandidate(in: nearby, expectedName: "shared-name", rememberedID: right, allowsNameMatch: false), right)
        XCTAssertNil(try SavedShoeConnection.discoveryCandidate(in: [right: "shared-name"], expectedName: "shared-name", rememberedID: left, allowsNameMatch: false))
        XCTAssertThrowsError(try SavedShoeConnection.discoveryCandidate(in: nearby, expectedName: "shared-name", rememberedID: nil, allowsNameMatch: false))
    }

    @MainActor func testUniqueNameCanRecoverAChangedIdentifierButRejectsAmbiguity() throws {
        let old = UUID(), replacement = UUID()
        XCTAssertEqual(try SavedShoeConnection.discoveryCandidate(in: [replacement: "saved-left"], expectedName: "saved-left", rememberedID: old, allowsNameMatch: true), replacement)
        XCTAssertThrowsError(try SavedShoeConnection.discoveryCandidate(in: [replacement: "saved-left", UUID(): "saved-left"], expectedName: "saved-left", rememberedID: old, allowsNameMatch: true))
    }

    @MainActor func testRememberedConnectionDoesNotScan() async throws {
        let result = try await SavedShoeConnection.connect(rememberedID: UUID(), expectedName: "saved-left",
            retrieve: { _ in "known" },
            discover: { _ in XCTFail("No unnecessary scan"); return UUID() },
            connectDiscovered: { _ in XCTFail("No second connection"); return "discovered" })
        XCTAssertEqual(result, "known")
    }

    @MainActor func testMissingBindingFindsExactSavedShoe() async throws {
        let id = UUID()
        var events: [String] = []
        let result = try await SavedShoeConnection.connect(rememberedID: nil, expectedName: "saved-right",
            retrieve: { _ in XCTFail("No identifier to retrieve"); return "known" },
            discover: { name in events.append(name); return id },
            connectDiscovered: { found in XCTAssertEqual(found, id); events.append("connect"); return "found" })
        XCTAssertEqual(result, "found")
        XCTAssertEqual(events, ["saved-right", "connect"])
    }

    @MainActor func testStaleCacheAndUnreachablePeripheralFallBackOnce() async throws {
        for error: Error in [ShoeConnectionError.rediscoveryRequired, AdaptError.timeout, AdaptError.disconnected] {
            var searches = 0
            var connections = 0
            let result = try await SavedShoeConnection.connect(rememberedID: UUID(), expectedName: "saved-left",
                retrieve: { _ -> String in throw error },
                discover: { name in XCTAssertEqual(name, "saved-left"); searches += 1; return UUID() },
                connectDiscovered: { _ in connections += 1; return "new identifier" })
            XCTAssertEqual(result, "new identifier")
            XCTAssertEqual(searches, 1); XCTAssertEqual(connections, 1)
        }
    }

    @MainActor func testBluetoothPermissionAndFirmwareErrorsArePreserved() async {
        for error: Error in [ShoeConnectionError.bluetooth("Allow Bluetooth access in iPhone Settings."),
                             AdaptError.unavailable, AdaptError.unsupportedFirmware, AdaptError.authentication] {
            var searched = false
            do {
                _ = try await SavedShoeConnection.connect(rememberedID: UUID(), expectedName: "saved-left",
                    retrieve: { _ -> String in throw error },
                    discover: { _ in searched = true; return UUID() }, connectDiscovered: { _ in "unexpected" })
                XCTFail("Must report the original failure")
            } catch let reported {
                XCTAssertEqual(reported.localizedDescription, error.localizedDescription)
                XCTAssertFalse(searched)
            }
        }
    }

    @MainActor func testNothingFoundDoesNotAttemptAnUnrelatedConnection() async {
        var connected = false
        do {
            _ = try await SavedShoeConnection.connect(rememberedID: nil, expectedName: "saved-right",
                retrieve: { _ in "known" }, discover: { _ in throw ShoeConnectionError.notFound },
                connectDiscovered: { _ in connected = true; return "unexpected" })
            XCTFail("Must fail")
        } catch { XCTAssertEqual(error as? ShoeConnectionError, .notFound) }
        XCTAssertFalse(connected)
    }

    @MainActor func testCanceledDiscoveryCannotConnectWhenItEventuallyReturns() async {
        var waiting: CheckedContinuation<UUID, Never>?
        var connected = false
        let task = Task {
            try await SavedShoeConnection.connect(rememberedID: nil, expectedName: "saved-left",
                retrieve: { _ in "known" }, discover: { _ in await withCheckedContinuation { waiting = $0 } },
                connectDiscovered: { _ in connected = true; return "unexpected" })
        }
        while waiting == nil { await Task.yield() }
        task.cancel(); waiting?.resume(returning: UUID())
        do { _ = try await task.value; XCTFail("Must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(connected)
    }

    @MainActor func testCanceledConnectionDiscardsItsLateLink() async {
        var waiting: CheckedContinuation<String, Never>?
        var discarded: [String] = []
        let task = Task {
            try await SavedShoeConnection.connect(rememberedID: UUID(), expectedName: "saved-left",
                retrieve: { _ in await withCheckedContinuation { waiting = $0 } },
                discover: { _ in XCTFail("Cancellation must not trigger rediscovery"); return UUID() },
                connectDiscovered: { _ in "unexpected" }, discard: { discarded.append($0) })
        }
        while waiting == nil { await Task.yield() }
        task.cancel(); waiting?.resume(returning: "late link")
        do { _ = try await task.value; XCTFail("Must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(discarded, ["late link"])
    }
}
