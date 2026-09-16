import AppIntents

// Actions run offscreen. Local authentication is independent of foregrounding;
// saved keys remain in the device-only, when-unlocked Keychain.
enum IntentShoe: String, AppEnum {
    case both, left, right
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shoes"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .both: "Both shoes", .left: "Left shoe", .right: "Right shoe"
    ]
    var sides: [ShoeSide] { self == .both ? ShoeSide.allCases : [self == .left ? .left : .right] }
}

enum IntentLightColor: String, AppEnum {
    case volt, green, mint, ice, blue, indigo, purple, pink, red, orange, yellow, white
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Light color"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .volt: "Volt", .green: "Green", .mint: "Mint", .ice: "Ice", .blue: "Blue",
        .indigo: "Indigo", .purple: "Violet", .pink: "Pink", .red: "Red",
        .orange: "Orange", .yellow: "Yellow", .white: "White"
    ]
    var shoeColor: ShoeColor { ShoeColor.palette.first { $0.id == rawValue }! }
}

struct ShoeModeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Saved fit"
    static var defaultQuery = ShoeModeQuery()
    let id: String
    let name: String
    let left: Int
    let right: Int
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "Left \(left)% · Right \(right)%")
    }
    @MainActor static func current() throws -> [Self] {
        let store = AppStore.shared
        try store.reloadShortcutProfiles()
        guard !store.demo, let pair = store.pair else { return [] }
        return store.modes.map { Self(id: "\(pair.id)/\($0.id.uuidString)", name: $0.name, left: $0.left, right: $0.right) }
    }
}

struct ShoeModeQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [ShoeModeEntity] {
        try ShoeModeEntity.current().filter { identifiers.contains($0.id) }
    }
    @MainActor func entities(matching string: String) async throws -> [ShoeModeEntity] {
        try ShoeModeEntity.current().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    @MainActor func suggestedEntities() async throws -> [ShoeModeEntity] { try ShoeModeEntity.current() }
}

struct ConnectShoesIntent: AppIntent {
    static var title: LocalizedStringResource = "Connect Shoes"
    static var description = IntentDescription("Connect your selected saved pair. Connect each shoe in OpenAdapt once before using Siri.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Connect \(\.$shoes)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = try await AppStore.shared.runShortcut(.connect(shoes.sides))
        return .result(dialog: "\(reply)")
    }
}

struct SetShoeFitIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Shoe Fit"
    static var description = IntentDescription("Adjust fit from 0 to 100 percent, rounded to the nearest 5 percent. Waits for confirmed completion.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Fit percentage", inclusiveRange: (0, 100), requestValueDialog: "What fit percentage?") var percentage: Int
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$shoes) to \(\.$percentage) percent fit") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let targets = Dictionary(uniqueKeysWithValues: shoes.sides.map { ($0, percentage) })
        let reply = try await AppStore.shared.runShortcut(.fit(targets))
        return .result(dialog: "\(reply)")
    }
}

struct TieShoesIntent: AppIntent {
    static var title: LocalizedStringResource = "Tie Shoes"
    static var description = IntentDescription("Tie both shoes using your last applied saved mode, or your first saved fit to start. No percentage or mode to choose.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    static var parameterSummary: some ParameterSummary { Summary("Tie my shoes using my last saved fit") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await AppStore.shared.tieShoes()
        return .result(dialog: "Your shoes are tied.")
    }
}

struct LoosenShoesIntent: AppIntent {
    static var title: LocalizedStringResource = "Loosen Shoes"
    static var description = IntentDescription("Set fit to zero percent for the selected shoes.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Loosen \(\.$shoes)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await AppStore.shared.runShortcut(.fit(Dictionary(uniqueKeysWithValues: shoes.sides.map { ($0, 0) })))
        let reply = shoes == .both ? "Your shoes are loosened." : "Your \(shoes.rawValue) shoe is loosened."
        return .result(dialog: "\(reply)")
    }
}

struct ApplyShoeModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Shoe Mode"
    static var description = IntentDescription("Apply a saved fit to both shoes. This becomes the fit used by Tie Shoes after both shoes confirm.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Mode", requestValueDialog: "Which saved fit?") var mode: ShoeModeEntity
    static var parameterSummary: some ParameterSummary { Summary("Apply \(\.$mode) to my shoes") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        // The store re-resolves this identity; cached percentages are never used.
        let name = try await AppStore.shared.runSavedMode(id: mode.id)
        return .result(dialog: "\(name) fit applied.")
    }
}

struct SetShoeLightsIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Shoe Lights"
    static var description = IntentDescription("Change the base light color of your selected shoes.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Color", requestValueDialog: "Which light color?") var color: IntentLightColor
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Set \(\.$shoes) lights to \(\.$color)") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let color = color.shoeColor
        let reply = try await AppStore.shared.runShortcut(.lights(sides: shoes.sides, rgb: color.rgb, colorID: color.id, name: color.name))
        return .result(dialog: "\(reply)")
    }
}

struct TurnShoeLightsOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Shoe Lights Off"
    static var description = IntentDescription("Turn off the lights of your selected shoes.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Turn off \(\.$shoes) lights") }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = try await AppStore.shared.runShortcut(.lights(sides: shoes.sides, rgb: [0, 0, 0], colorID: nil, name: "Off"))
        return .result(dialog: "\(reply)")
    }
}

struct ShoeBatteryIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Shoe Battery"
    static var description = IntentDescription("Read current battery levels from your selected shoes.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @Parameter(title: "Shoes", default: .both) var shoes: IntentShoe
    static var parameterSummary: some ParameterSummary { Summary("Check \(\.$shoes) battery") }
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let reply = try await AppStore.shared.runShortcut(.battery(shoes.sides))
        return .result(value: reply, dialog: "\(reply)")
    }
}

struct DisconnectShoesIntent: AppIntent {
    static var title: LocalizedStringResource = "Disconnect Shoes"
    static var description = IntentDescription("Disconnect OpenAdapt from your shoes without removing their saved pairing.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    @available(iOS 26.0, *) static var supportedModes: IntentModes { .background }
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        AppStore.shared.disconnect()
        return .result(dialog: "OpenAdapt has disconnected from your shoes.")
    }
}

struct OpenAdaptShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .lightBlue
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TieShoesIntent(), phrases: ["Tie my shoes with \(.applicationName)", "Can you tie my shoes with \(.applicationName)", "Lace up my shoes with \(.applicationName)", "Lace my shoes with \(.applicationName)", "Make my lace with \(.applicationName)"],
                    shortTitle: "Tie shoes", systemImageName: "shoe.fill")
        AppShortcut(intent: LoosenShoesIntent(), phrases: ["Loosen my shoes with \(.applicationName)", "Untie my shoes with \(.applicationName)", "Can you loosen my shoes with \(.applicationName)", "Can you untie my shoes with \(.applicationName)"],
                    shortTitle: "Loosen shoes", systemImageName: "arrow.down")
        AppShortcut(intent: SetShoeFitIntent(), phrases: ["Set my shoe fit with \(.applicationName)"],
                    shortTitle: "Set shoe fit", systemImageName: "slider.horizontal.3")
        AppShortcut(intent: ApplyShoeModeIntent(), phrases: ["Apply \(\.$mode) with \(.applicationName)", "Apply a shoe mode with \(.applicationName)"],
                    shortTitle: "Apply shoe mode", systemImageName: "slider.horizontal.3")
        AppShortcut(intent: SetShoeLightsIntent(), phrases: ["Set my shoe lights to \(\.$color) with \(.applicationName)", "Change my shoe lights with \(.applicationName)"],
                    shortTitle: "Set shoe lights", systemImageName: "lightbulb")
        AppShortcut(intent: TurnShoeLightsOffIntent(), phrases: ["Turn my shoe lights off with \(.applicationName)"],
                    shortTitle: "Lights off", systemImageName: "lightbulb.slash")
        AppShortcut(intent: ShoeBatteryIntent(), phrases: ["Check my shoe battery with \(.applicationName)"],
                    shortTitle: "Shoe battery", systemImageName: "battery.75percent")
        AppShortcut(intent: ConnectShoesIntent(), phrases: ["Connect my shoes with \(.applicationName)"],
                    shortTitle: "Connect shoes", systemImageName: "link")
        AppShortcut(intent: DisconnectShoesIntent(), phrases: ["Disconnect my shoes with \(.applicationName)"],
                    shortTitle: "Disconnect shoes", systemImageName: "link.badge.plus")
    }
}
