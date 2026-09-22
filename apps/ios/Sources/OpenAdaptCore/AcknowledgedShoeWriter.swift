import Foundation

/// Serializes ATT writes, including CoreRF flow acknowledgements. A timeout or
/// cancellation ends the stream: an unconfirmed packet must never be replayed.
@MainActor
public final class AcknowledgedShoeWriter {
    private let send: (Data) -> Void
    private let onFailure: (Error) -> Void
    private let timeout: TimeInterval
    private var queued: [(Data, CheckedContinuation<Void, Error>)] = []
    private var pending: CheckedContinuation<Void, Error>?
    private var timer: Task<Void, Never>?
    private var failure: Error?

    public init(timeout: TimeInterval = 3, send: @escaping (Data) -> Void,
                onFailure: @escaping (Error) -> Void) {
        self.timeout = max(0.01, min(30, timeout))
        self.send = send; self.onFailure = onFailure
    }

    public func write(_ packet: Data) async throws {
        try Task.checkCancellation()
        if let failure { throw failure }
        guard queued.count + (pending == nil ? 0 : 1) < 32 else { throw AdaptError.busy }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queued.append((packet, continuation))
                flush()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.fail(CancellationError()) }
        }
    }

    /// Called only for the selected characteristic's didWriteValue callback.
    public func didWrite(error: Error?) {
        guard failure == nil, let continuation = pending else { return }
        if let error { fail(error); return }
        pending = nil; timer?.cancel(); timer = nil
        continuation.resume()
        flush()
    }

    public func close(_ error: Error) {
        guard failure == nil else { return }
        failure = error; timer?.cancel(); timer = nil
        let awaiting = pending; pending = nil
        let remaining = queued; queued.removeAll()
        awaiting?.resume(throwing: error)
        for (_, continuation) in remaining { continuation.resume(throwing: error) }
    }

    private func fail(_ error: Error) {
        guard failure == nil else { return }
        close(error)
        onFailure(error)
    }

    private func flush() {
        guard failure == nil, pending == nil, !queued.isEmpty else { return }
        let (packet, continuation) = queued.removeFirst()
        pending = continuation
        let duration = timeout
        timer = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            self?.fail(AdaptError.timeout)
        }
        send(packet)
    }
}
