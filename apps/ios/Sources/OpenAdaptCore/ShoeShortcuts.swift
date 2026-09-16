import Foundation

public enum ShoeShortcutError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public enum ShoeShortcutCommand {
    case connect([ShoeSide])
    case fit([ShoeSide: Int])
    case lights(sides: [ShoeSide], rgb: [UInt8], colorID: String?, name: String)
    case battery([ShoeSide])

    public var sides: [ShoeSide] {
        switch self {
        case .fit(let targets): return ShoeSide.allCases.filter { targets[$0] != nil }
        case .connect(let sides), .battery(let sides), .lights(let sides, _, _, _): return sides
        }
    }
}

/// The UI adapter owns its connection lifecycle and command reservation. Only
/// confirmed live results reach Siri; no cached readings or queued commands.
@MainActor
public protocol ShoeShortcutController: AnyObject {
    func prepareShortcut(sides: [ShoeSide]) async throws
    func checkShortcutContext() throws
    func shortcutMaximum(_ side: ShoeSide) throws -> Int
    func shortcutStatus(_ side: ShoeSide) async throws -> ShoeStatus
    func shortcutFit(_ side: ShoeSide, percent: Int) async throws
    func shortcutLights(_ side: ShoeSide, rgb: [UInt8], colorID: String?) async throws
}

@MainActor
public enum ShoeShortcutRunner {
    public static func run(_ command: ShoeShortcutCommand, using controller: ShoeShortcutController) async throws -> String {
        let sides = command.sides
        guard !sides.isEmpty, Set(sides).count == sides.count else {
            throw ShoeShortcutError.message("Choose the left shoe, right shoe, or both shoes.")
        }
        if case .fit(let targets) = command,
           !targets.values.allSatisfy({ (0...100).contains($0) }) {
            throw ShoeShortcutError.message("Choose a fit between 0 and 100 percent.")
        }
        if case .lights(_, let rgb, _, _) = command, rgb.count != 3 {
            throw ShoeShortcutError.message("Choose a shoe light color.")
        }
        try Task.checkCancellation()
        try await controller.prepareShortcut(sides: sides)
        try controller.checkShortcutContext()
        try Task.checkCancellation()
        if case .connect = command { return sides.count == 2 ? "Both shoes are connected." : "Your \(sides[0].rawValue) shoe is connected." }

        var readings: [ShoeSide: ShoeStatus] = [:]
        // Preflight EVERY requested shoe before starting either motor.
        if case .fit = command {
            for side in sides {
                try controller.checkShortcutContext()
                try Task.checkCancellation()
                let status = try await controller.shortcutStatus(side)
                let maximum = try controller.shortcutMaximum(side)
                guard status.charger == 1 else { throw ShoeShortcutError.message("\(side.title) shoe: \(AdaptError.charging.localizedDescription)") }
                guard status.battery >= 20 else { throw ShoeShortcutError.message("\(side.title) shoe: \(AdaptError.lowBattery.localizedDescription)") }
                guard status.rawPosition <= maximum + 1 else { throw AdaptError.calibration }
            }
        }
        if case .battery = command {
            for side in sides {
                try controller.checkShortcutContext()
                try Task.checkCancellation()
                readings[side] = try await controller.shortcutStatus(side)
            }
            try controller.checkShortcutContext()
            try Task.checkCancellation()
            return sides.map { "\($0.title) shoe battery is \(readings[$0]!.battery) percent." }.joined(separator: " ")
        }

        try controller.checkShortcutContext()
        try Task.checkCancellation()
        let outcomes = await withTaskGroup(of: (ShoeSide, String?).self) { group in
            for side in sides {
                group.addTask { @MainActor in
                    do {
                        try Task.checkCancellation()
                        try controller.checkShortcutContext()
                        switch command {
                        case .fit(let targets):
                            try await controller.shortcutFit(side, percent: FitScale.snapped(Double(targets[side]!)))
                        case .lights(_, let rgb, let id, _):
                            try await controller.shortcutLights(side, rgb: rgb, colorID: id)
                        default: break
                        }
                        try controller.checkShortcutContext()
                        try Task.checkCancellation()
                        return (side, nil)
                    } catch {
                        let reason: String
                        if error is CancellationError { reason = "The action was canceled; completion was not confirmed." }
                        else if let error = error as? AdaptError { reason = error.localizedDescription }
                        else if let error = error as? ShoeShortcutError { reason = error.localizedDescription }
                        else { reason = "The shoe did not confirm this action." }
                        return (side, reason)
                    }
                }
            }
            var result: [ShoeSide: String] = [:]
            for await (side, error) in group { result[side] = error ?? "" }
            return result
        }
        // Report partial completion explicitly. Never retry or roll back a motor.
        if outcomes.values.contains(where: { !$0.isEmpty }) {
            throw ShoeShortcutError.message(sides.map { side in
                let error = outcomes[side] ?? "Completion was not confirmed."
                return error.isEmpty ? "\(side.title) shoe confirmed the action." : "\(side.title) shoe: \(error)"
            }.joined(separator: " "))
        }
        try controller.checkShortcutContext()
        try Task.checkCancellation()
        switch command {
        case .fit(let targets):
            return sides.map { "\($0.title) fit confirmed at \(FitScale.snapped(Double(targets[$0]!))) percent." }.joined(separator: " ")
        case .lights(_, _, let id, let name):
            let subject = sides.count == 2 ? "Both shoe lights are" : "Your \(sides[0].rawValue) shoe lights are"
            return "\(subject) \(id == nil ? "off" : name.lowercased())."
        default: return "Done."
        }
    }
}
