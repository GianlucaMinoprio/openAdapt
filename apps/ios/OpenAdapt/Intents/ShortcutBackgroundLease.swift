import UIKit

/// A finite UIKit execution assertion, released on every exit path. Bluetooth
/// background mode handles radio events; this assertion protects active work.
@MainActor
final class ShortcutBackgroundLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    func begin(onExpiration: @escaping @MainActor () -> Void) throws {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Shoe shortcut") { [weak self] in
            onExpiration()
            self?.end()
        }
        guard identifier != .invalid else {
            throw ShoeShortcutError.message("iOS could not start this shortcut in the background. Try again while your iPhone is unlocked.")
        }
    }
    func end() {
        guard identifier != .invalid else { return }
        let current = identifier; identifier = .invalid
        UIApplication.shared.endBackgroundTask(current)
    }
}
