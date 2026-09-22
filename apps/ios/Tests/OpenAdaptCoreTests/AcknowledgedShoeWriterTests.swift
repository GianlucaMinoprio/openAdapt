import XCTest
@testable import OpenAdaptCore

@MainActor
final class AcknowledgedShoeWriterTests: XCTestCase {
    private func waitFor(_ condition: @escaping () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while !condition() {
            guard ContinuousClock.now < deadline else { XCTFail("Writer did not advance"); return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func testFragmentsAndFlowAcknowledgementsShareOrderedQueue() async throws {
        var sent: [Data] = []
        var completed = 0
        let writer = AcknowledgedShoeWriter(send: { sent.append($0) }, onFailure: { _ in XCTFail() })
        let first = Task { try await writer.write(Data([1])); completed += 1 }
        try await waitFor { sent.count == 1 }
        let second = Task { try await writer.write(Data([2])); completed += 1 }
        // Let the second task enter the queue; only the first may be sent.
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(sent, [Data([1])]); XCTAssertEqual(completed, 0)
        writer.didWrite(error: nil)
        try await first.value
        XCTAssertEqual(sent, [Data([1]), Data([2])]); XCTAssertEqual(completed, 1)
        writer.didWrite(error: nil)
        try await second.value
        XCTAssertEqual(completed, 2)
        writer.close(AdaptError.disconnected)
    }

    func testFailureDropsQueuedPacketsAndNeverReplays() async throws {
        var sent: [Data] = []; var failures = 0
        let writer = AcknowledgedShoeWriter(send: { sent.append($0) }, onFailure: { _ in failures += 1 })
        let first = Task { try await writer.write(Data([1])) }
        try await waitFor { sent.count == 1 }
        let second = Task { try await writer.write(Data([2])) }
        try await Task.sleep(nanoseconds: 10_000_000)
        writer.didWrite(error: AdaptError.disconnected)
        for task in [first, second] {
            do { try await task.value; XCTFail("Write must fail") }
            catch { XCTAssertEqual(error as? AdaptError, .disconnected) }
        }
        writer.didWrite(error: nil); writer.close(AdaptError.timeout)
        do { try await writer.write(Data([3])); XCTFail("Closed stream must reject writes") }
        catch { XCTAssertEqual(error as? AdaptError, .disconnected) }
        XCTAssertEqual(sent, [Data([1])]); XCTAssertEqual(failures, 1)
    }

    func testMissingAcknowledgementTimesOutWithoutResending() async throws {
        var sent = 0; var failures = 0
        let writer = AcknowledgedShoeWriter(timeout: 0.02, send: { _ in sent += 1 }, onFailure: { _ in failures += 1 })
        do { try await writer.write(Data([1])); XCTFail("Missing acknowledgement must time out") }
        catch { XCTAssertEqual(error as? AdaptError, .timeout) }
        writer.didWrite(error: nil)
        XCTAssertEqual(sent, 1); XCTAssertEqual(failures, 1)
    }

    func testDisconnectReleasesPendingAndQueuedWrites() async throws {
        var sent = 0
        let writer = AcknowledgedShoeWriter(send: { _ in sent += 1 }, onFailure: { _ in XCTFail() })
        let first = Task { try await writer.write(Data([1])) }
        try await waitFor { sent == 1 }
        let second = Task { try await writer.write(Data([2])) }
        try await Task.sleep(nanoseconds: 10_000_000)
        writer.close(AdaptError.disconnected)
        for task in [first, second] {
            do { try await task.value; XCTFail("Disconnected writes must fail") }
            catch { XCTAssertEqual(error as? AdaptError, .disconnected) }
        }
        writer.didWrite(error: nil)
        XCTAssertEqual(sent, 1)
    }

    func testCancellationClosesStreamAndIgnoresLateAcknowledgement() async throws {
        var sent = 0; var failures = 0
        let writer = AcknowledgedShoeWriter(send: { _ in sent += 1 }, onFailure: { _ in failures += 1 })
        let task = Task { try await writer.write(Data([1])) }
        try await waitFor { sent == 1 }
        task.cancel()
        do { try await task.value; XCTFail("Cancelled write must fail") }
        catch { XCTAssertTrue(error is CancellationError) }
        writer.didWrite(error: nil)
        do { try await writer.write(Data([2])); XCTFail("Cancelled stream must reject writes") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(sent, 1); XCTAssertEqual(failures, 1)
    }
}
