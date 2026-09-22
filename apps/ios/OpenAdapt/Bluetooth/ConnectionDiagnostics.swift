import Foundation

/// Bounded local diagnostics. No device identifiers, credentials or payload bytes.
@MainActor
enum ConnectionDiagnostics {
    private static var sequence = 0
    static func linkID() -> Int { sequence += 1; return sequence }
    static func record(_ event: String, link: Int? = nil) {
        #if DEBUG
        let defaults = UserDefaults.standard
        var events = defaults.array(forKey: "connectionDiagnostics") as? [[String: String]] ?? []
        events.append(["time": ISO8601DateFormatter().string(from: Date()),
            "event": event, "link": link.map(String.init) ?? "app"])
        defaults.set(Array(events.suffix(160)), forKey: "connectionDiagnostics")
        #endif
    }
}
