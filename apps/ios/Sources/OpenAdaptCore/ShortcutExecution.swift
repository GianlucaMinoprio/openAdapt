import Foundation

/// One in-memory action with a finite lifetime. Expiration invalidates the
/// transport immediately; even a late successful reply cannot become success.
@MainActor
public final class ShortcutExecution {
    private var task: Task<String, Error>?
    private var token: UUID?
    private var deadlineInstant: ContinuousClock.Instant?
    private var failure: Error?
    private var cleanup: (() -> Void)?
    public init() {}

    public func run(timeout: Duration = .seconds(25), onCancel: @escaping () -> Void,
                    operation: @escaping @MainActor () async throws -> String) async throws -> String {
        try Task.checkCancellation()
        guard task == nil else { throw AdaptError.busy }
        let id = UUID()
        token = id; failure = nil; cleanup = onCancel
        deadlineInstant = ContinuousClock.now.advanced(by: timeout)
        let work = Task { try self.checkActive(); return try await operation() }
        task = work
        let deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard self?.token == id else { return }
            self?.expire()
        }
        defer { deadline.cancel(); task = nil; token = nil; deadlineInstant = nil; failure = nil; cleanup = nil }
        return try await withTaskCancellationHandler {
            do {
                let result = try await work.value
                try checkActive()
                return result
            } catch {
                if Task.isCancelled { cancel() }
                throw failure ?? error
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.token == id else { return }
                self?.cancel()
            }
        }
    }

    public func cancel() { stop(CancellationError()) }
    public func checkActive() throws {
        try Task.checkCancellation()
        guard let deadlineInstant else { throw CancellationError() }
        // Also check synchronously at command boundaries: a delayed timer must
        // not allow a suspended process to resume an already expired action.
        if ContinuousClock.now >= deadlineInstant { expire() }
        if let failure { throw failure }
    }
    public func expire() {
        stop(ShoeShortcutError.message("The shortcut ran out of time. Completion was not confirmed. Wake your shoes and try again; this request will not run later."))
    }
    private func stop(_ error: Error) {
        guard task != nil, failure == nil else { return }
        failure = error
        task?.cancel()
        // Set failure first: transport cleanup may itself request cancellation.
        cleanup?()
    }
}
