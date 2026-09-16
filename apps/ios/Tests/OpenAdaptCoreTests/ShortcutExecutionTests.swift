import XCTest
@testable import OpenAdaptCore

final class ShortcutExecutionTests: XCTestCase {
    @MainActor func testCompletionReleasesReservationForNextCommand() async throws {
        let execution = ShortcutExecution()
        var cleanupCount = 0
        for _ in 0..<2 {
            let result = try await execution.run(onCancel: { cleanupCount += 1 }) { "Confirmed" }
            XCTAssertEqual(result, "Confirmed")
        }
        execution.expire() // A stale system callback has no work to cancel.
        XCTAssertEqual(cleanupCount, 0)
    }

    @MainActor func testDeadlineClosesTransportAndPreventsLateCommand() async {
        let execution = ShortcutExecution()
        var cleanupCount = 0
        var writes = 0
        do {
            _ = try await execution.run(timeout: .milliseconds(20), onCancel: { cleanupCount += 1 }) {
                try await Task.sleep(for: .seconds(30)) // A shoe that never wakes.
                writes += 1
                return "Done"
            }
            XCTFail("Must expire")
        } catch { XCTAssertTrue(error.localizedDescription.contains("ran out of time")) }
        XCTAssertEqual(cleanupCount, 1)
        XCTAssertEqual(writes, 0)
    }

    @MainActor func testSystemExpirationRejectsLateSuccessAndCleansUpOnce() async {
        let execution = ShortcutExecution()
        var cleanupCount = 0
        var suspended: CheckedContinuation<Void, Never>?
        let request = Task {
            try await execution.run(onCancel: {
                cleanupCount += 1
                execution.cancel() // Reentrant disconnect is harmless.
            }) {
                await withCheckedContinuation { suspended = $0 }
                return "Late completion"
            }
        }
        while suspended == nil { await Task.yield() }
        execution.expire(); execution.expire()
        suspended?.resume()
        do { _ = try await request.value; XCTFail("Expired success must be rejected") }
        catch { XCTAssertTrue(error.localizedDescription.contains("ran out of time")) }
        XCTAssertEqual(cleanupCount, 1)
    }

    @MainActor func testOverlappingCommandIsRejectedWithoutStarting() async throws {
        let execution = ShortcutExecution()
        var suspended: CheckedContinuation<Void, Never>?
        let first = Task {
            try await execution.run(onCancel: {}) {
                await withCheckedContinuation { suspended = $0 }; return "First"
            }
        }
        while suspended == nil { await Task.yield() }
        var started = false
        do {
            _ = try await execution.run(onCancel: {}) { started = true; return "Second" }
            XCTFail("Must reject overlap")
        } catch { XCTAssertFalse(started) }
        suspended?.resume()
        let result = try await first.value
        XCTAssertEqual(result, "First")
    }

    @MainActor func testCallerCancellationClosesTransport() async {
        let execution = ShortcutExecution()
        var started = false
        var cleanupCount = 0
        let request = Task {
            try await execution.run(onCancel: { cleanupCount += 1 }) {
                started = true
                try await Task.sleep(for: .seconds(30))
                return "Done"
            }
        }
        while !started { await Task.yield() }
        request.cancel()
        do { _ = try await request.value; XCTFail("Must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(cleanupCount, 1)
    }

    @MainActor func testAlreadyCanceledRequestNeverStartsTransport() async {
        let execution = ShortcutExecution()
        var started = false
        let request = Task {
            try await execution.run(onCancel: {}) { started = true; return "Done" }
        }
        request.cancel()
        do { _ = try await request.value; XCTFail("Must cancel") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(started)
    }
}
