import SwiftUI
import Combine
import UIKit
import AppIntents

struct FootState {
    var target = 0
    var measured: Double?
    var progress: Double = 0
    var movementStartedAt: Date?
    var movementStart: Double = 0
    var battery: Int?
    var firmware: String?
    var features: [ShoeFeature: ShoeFeatureConfirmation] = [:]
    var lightColorID: String?
    var connected = false
    var hasFitCalibration = true
    var connecting = false
    var busy = false
    var lacing = false
    var dragging = false
    var dragPosition: Double?
    var directAdjustment = false
    var note = "Not connected"
}

struct FitMode: Codable, Identifiable {
    var id = UUID()
    var name: String
    var left: Int
    var right: Int
    var colorID: String?
}

struct ShoeColor: Identifiable, Equatable {
    let id: String
    let name: String
    let rgb: [UInt8]
    var color: Color { Color(red: Double(rgb[0]) / 255, green: Double(rgb[1]) / 255, blue: Double(rgb[2]) / 255) }
    var usesDarkInk: Bool {
        let channels = rgb.map { component -> Double in
            let value = Double(component) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722 > 0.179
    }
    static let palette: [ShoeColor] = [
        .init(id: "volt", name: "Volt", rgb: [183, 255, 44]),
        .init(id: "green", name: "Electric green", rgb: [48, 220, 41]),
        .init(id: "mint", name: "Mint", rgb: [46, 255, 171]),
        .init(id: "ice", name: "Ice", rgb: [31, 235, 246]),
        .init(id: "blue", name: "Blue", rgb: [49, 133, 255]),
        .init(id: "indigo", name: "Indigo", rgb: [77, 48, 255]),
        .init(id: "purple", name: "Violet", rgb: [174, 50, 255]),
        .init(id: "pink", name: "Pink", rgb: [255, 66, 183]),
        .init(id: "red", name: "Red", rgb: [255, 48, 63]),
        .init(id: "orange", name: "Orange", rgb: [255, 123, 34]),
        .init(id: "yellow", name: "Yellow", rgb: [255, 235, 25]),
        .init(id: "white", name: "White", rgb: [255, 255, 255])
    ]
}

@MainActor
final class Haptics {
    var enabled = true
    private let selection = UISelectionFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    func prepare() { guard enabled else { return }; selection.prepare(); impact.prepare() }
    func tick() { guard enabled else { return }; selection.selectionChanged(); selection.prepare() }
    func commit() { guard enabled else { return }; impact.impactOccurred(intensity: 0.7) }
    func success() { guard enabled else { return }; notification.notificationOccurred(.success) }
    func error() { guard enabled else { return }; notification.notificationOccurred(.error) }
}

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()
    @Published private(set) var shortcutRunning = false
    private let shortcutExecution = ShortcutExecution()
    private var keepBackgroundConnections = false
    private var shortcutGeneration: UUID?

    @Published var pairs: [ShoePair] = []
    @Published var selectedID: String?
    @Published var feet: [ShoeSide: FootState] = [.left: FootState(), .right: FootState()]
    @Published var errorMessage: String?
    @Published var demo = false
    @Published var reconnecting = false
    @Published private(set) var connectionFailed = false
    @Published var connectionMessage = "Wake your shoes to connect."
    @Published var selectedColor = "green"
    @Published var modes: [FitMode] = []
    @Published private(set) var shoeColorways: [String: ShoeColorway] = [:]
    @Published private(set) var lastUsedModeID: UUID?
    var lastUsedMode: FitMode? { modes.first { $0.id == lastUsedModeID } }
    var tieMode: FitMode? { lastUsedMode ?? modes.first }
    private let fitHistory = SavedFitHistory()
    private let autoLaceHistory = SavedAutoLacePreference()
    private let pairHistory = SavedPairHistory()
    private var demoAutoLacePreference = false
    func autoLacePreference(for pairID: String) -> Bool {
        demo ? demoAutoLacePreference : autoLaceHistory.isEnabled(forPair: pairID)
    }
    @Published var hapticsEnabled = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
        didSet { haptics.enabled = hapticsEnabled; UserDefaults.standard.set(hapticsEnabled, forKey: "haptics") }
    }
    let bluetooth = BluetoothController()
    let haptics = Haptics()
    private let vault = PairVault()
    private var localSetupPreview = false
    private var generation = UUID()
    private var links: [ShoeSide: PeripheralLink] = [:]
    private var tasks: [ShoeSide: Task<Void, Never>] = [:]
    private var connectionAttempts: [ShoeSide: UUID] = [:]
    private var connectionFailures: [ShoeSide: String] = [:]
    private var reconnectDeadline: Task<Void, Never>?
    private var reconnectSuppressed = false
    private var settingUpNewShoes = false
    var pair: ShoePair? { pairs.first { $0.id == selectedID } }
    private var preferredPairID: String? { pairHistory.preferredPairID(among: pairs.map(\.id)) }
    var name: String { pair?.displayName ?? (demo ? "Auto Max" : "Your shoes") }
    var connected: Bool { ShoeSide.allCases.allSatisfy { feet[$0]?.connected == true } }
    var anyConnected: Bool { feet.values.contains { $0.connected || $0.connecting } }
    var anyBusy: Bool { shortcutRunning || feet.values.contains { $0.busy || $0.connecting } }
    var canControlBoth: Bool { connected && !anyBusy }
    var canAdjustBoth: Bool { canControlBoth && feet.values.allSatisfy(\.hasFitCalibration) }
    var hasReadyShoe: Bool { feet.values.contains { $0.connected } }
    var connectionInProgress: Bool { reconnecting || feet.values.contains { $0.connecting } }
    private var bindingKey: String { "peripherals.\(selectedID ?? "none")" }
    private var bindings: [String: String] {
        var result = pair?.shoes.compactMapValues { $0.peripheralID?.uuidString } ?? [:]
        for (side, id) in UserDefaults.standard.dictionary(forKey: bindingKey) as? [String: String] ?? [:] { result[side] = id }
        return result
    }
    var canReconnect: Bool { !demo && pair != nil && !connected }
    var connectionTitle: String { connectionInProgress ? "Connecting" : connectionFailed ? "Couldn’t connect" : "Not connected" }
    // LED color is not part of status readback. Only an acknowledged color
    // command establishes a displayed light color; unknown/off is neutral.
    var activeLightColor: ShoeColor? {
        let active = ShoeSide.allCases.compactMap { feet[$0]?.lightColorID }
        let id = active.contains(selectedColor) ? selectedColor : active.first
        return ShoeColor.palette.first { $0.id == id }
    }
    var accent: Color { activeLightColor?.color ?? .gray }
    var canvasUsesDarkInk: Bool { activeLightColor?.usesDarkInk ?? true }
    var canvasInk: Color { canvasUsesDarkInk ? .black : .white }
    func lightColor(_ side: ShoeSide) -> ShoeColor? {
        ShoeColor.palette.first { $0.id == feet[side]?.lightColorID }
    }

    init() {
        haptics.enabled = hapticsEnabled
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            loadModes(); startDemo(); return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo-connecting") {
            demo = true; reconnecting = true; loadModes(); return
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-onboarding") { localSetupPreview = true; loadModes(); return }
        if ProcessInfo.processInfo.arguments.contains("--ui-bluetooth-off") {
            localSetupPreview = true
            // Synthetic profiles; this launch mode never initializes the radio.
            let sample = """
            {"version":2,"pairs":[{"id":"connection-test","name":"Auto Max","shoes":{
              "left":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TESTL-001","key_hex":"03030303030303030303030303030303","fit_maximum":80,"address":"00:00:00:00:00:01"},
              "right":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TESTR-002","key_hex":"02020202020202020202020202020202","fit_maximum":80,"address":"00:00:00:00:00:02"}
            } }]}
            """
            pairs = (try? ProfileImport.decode(Data(sample.utf8))) ?? []
            if ProcessInfo.processInfo.arguments.contains("--ui-multiple-pairs") {
                let other = sample.replacingOccurrences(of: "connection-test", with: "other-test")
                    .replacingOccurrences(of: "\"name\":\"Auto Max\"", with: "\"name\":\"Weekend shoes\"")
                pairs += (try? ProfileImport.decode(Data(other.utf8))) ?? []
            }
            selectedID = pairs.first?.id; loadModes(); return
        }
        #endif
        do {
            pairs = try vault.loadWithLocalDefault()
            selectedID = preferredPairID
        } catch { report(error) }
        loadModes()
    }
    func foreground() {
        guard UIApplication.shared.applicationState == .active, !localSetupPreview, !settingUpNewShoes else { return }
        if !demo && !shortcutRunning {
            do { try reloadShortcutProfiles() } catch { report(error); return }
            // Opening the app returns to the last complete connection. Browsing
            // or a failed attempt at another pair must not replace that default.
            if !anyConnected && !anyBusy, let preferred = pairs.first(where: { $0.id == preferredPairID }),
               selectedID != preferred.id {
                select(preferred)
            }
            reconnectSuppressed = false
        }
        reconnectSavedPair(automatically: true)
    }
    func reconnectSavedPair(automatically: Bool = false) {
        guard !shortcutRunning else { return }
        guard !automatically || (!reconnectSuppressed && UIApplication.shared.applicationState == .active) else { return }
        guard canReconnect, !connectionInProgress, let pair else { return }
        reconnectSuppressed = false
        reconnecting = true; connectionFailed = false; connectionFailures.removeAll()
        connectionMessage = "Keep your shoes close to your iPhone."
        recordConnectionSnapshot()
        for side in ShoeSide.allCases where !feet[side]!.connected {
            let id = bindings[side.rawValue].flatMap(UUID.init(uuidString:))
            startConnection(side, id: id, credential: pair.credential(side), remembered: true)
        }
        reconnectDeadline?.cancel()
        reconnectDeadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self else { return }
            for side in ShoeSide.allCases where feet[side]!.connecting {
                connectionAttempts[side] = nil
                tasks[side]?.cancel()
                tasks[side] = nil
                if let id = links[side]?.peripheral.identifier ?? bindings[side.rawValue].flatMap(UUID.init(uuidString:)) {
                    bluetooth.disconnect(id: id)
                }
                lost(side)
                recordConnectionFailure(AdaptError.timeout, side: side)
            }
            reconnecting = false
            recordConnectionSnapshot()
        }
    }
    func report(_ error: Error) {
        errorMessage = (error as? AdaptError)?.localizedDescription
            ?? (error as? ShoeConnectionError)?.localizedDescription
            ?? (error as? PairVault.VaultError)?.localizedDescription
            ?? "The operation could not be completed. Your saved shoe keys have been preserved."
        haptics.error()
    }
    func importProfiles(from url: URL) {
        guard !shortcutRunning else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 262_144 else { throw AdaptError.invalidProfile }
            let incoming = try ProfileImport.decode(Data(contentsOf: url))
            var merged = pairs
            for item in incoming {
                if let existing = merged.first(where: { $0.id == item.id }) {
                    guard existing == item else {
                        errorMessage = "A different profile already uses this pair name. Remove that saved pair before importing its replacement."; return
                    }
                } else { merged.append(item) }
            }
            try vault.save(merged)
            pairs = merged
            if !anyConnected { selectedID = incoming.first?.id; loadModes() }
            haptics.success()
        } catch { report(error) }
    }
    func select(_ pair: ShoePair) {
        guard !shortcutRunning, selectedID != pair.id else { return }
        disconnect(); demo = false; selectedID = pair.id; loadModes()
        OpenAdaptShortcuts.updateAppShortcutParameters()
    }
    func beginNewShoeSetup() {
        settingUpNewShoes = true
        disconnect()
    }
    func endNewShoeSetup() { settingUpNewShoes = false }
    func saveEnrolledShoes(_ records: [ShoeEnrollmentRecord]) throws {
        let incoming = try ShoePair.enrolled(records)
        let existing = pairs.first { pair in ShoeSide.allCases.allSatisfy { side in
            pair.credential(side).shoeIdentity == incoming.credential(side).shoeIdentity
                && pair.credential(side).key == incoming.credential(side).key
        } }
        let saved = existing ?? incoming
        if existing == nil {
            let updated = pairs + [incoming]
            if !localSetupPreview { try vault.save(updated) }
            pairs = updated
        }
        disconnect(); selectedID = saved.id; loadModes()
        if !localSetupPreview {
            // A recovered peripheral can have a new CoreBluetooth UUID even
            // when this verified identity/key pair was already published.
            UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: records.map {
                ($0.side.rawValue, $0.peripheralID.uuidString)
            }), forKey: bindingKey)
        }
        settingUpNewShoes = false
        if !localSetupPreview {
            // Pair publication is the commit point; cleanup failure cannot lose it.
            try? EnrollmentVault().removeSaved(Set(records.map(\.id)))
            reconnectSavedPair()
        }
        haptics.success()
    }
    func colorway(for id: String) -> ShoeColorway {
        if let saved = shoeColorways[id] { return saved }
        guard !demo else { return .blackBlue }
        return UserDefaults.standard.string(forKey: "shoeAppearance.\(id)").flatMap(ShoeColorway.init(rawValue:)) ?? .blackBlue
    }
    func setColorway(_ colorway: ShoeColorway, for id: String) {
        guard pairs.contains(where: { $0.id == id }) else { return }
        shoeColorways[id] = colorway
        if !demo { UserDefaults.standard.set(colorway.rawValue, forKey: "shoeAppearance.\(id)") }
    }
    @discardableResult func renamePair(_ id: String, nickname: String) -> Bool {
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60, let index = pairs.firstIndex(where: { $0.id == id }) else { return false }
        var updated = pairs; updated[index].name = name
        do {
            if !demo { try vault.save(updated) }
            pairs = updated; return true
        } catch { report(error); return false }
    }
    func removePair(_ id: String) {
        guard !anyBusy, pairs.contains(where: { $0.id == id }) else { return }
        do {
            let remaining = pairs.filter { $0.id != id }
            if !demo { try vault.save(remaining) }
            // Persist first: a Keychain failure must not remove the working UI pair.
            if selectedID == id { disconnect() }
            pairs = remaining; shoeColorways[id] = nil
            if !demo {
                fitHistory.clear(forPair: id)
                autoLaceHistory.clear(forPair: id)
                pairHistory.removePair(id)
                for key in ["shoeAppearance.\(id)", "peripherals.\(id)", "modes.\(id)"] { UserDefaults.standard.removeObject(forKey: key) }
            }
            if selectedID == id { selectedID = preferredPairID; loadModes() }
        } catch { report(error) }
    }
    func connect(_ side: ShoeSide, device: NearbyShoe) {
        guard !demo, !shortcutRunning, let pair, !feet[side]!.connecting, !feet[side]!.connected,
              !links.values.contains(where: { $0.peripheral.identifier == device.id }) else { return }
        let credential = pair.credential(side)
        guard credential.advertisedName == device.name else { report(AdaptError.invalidProfile); return }
        startConnection(side, id: device.id, credential: credential, remembered: false)
    }
    private func startConnection(_ side: ShoeSide, id: UUID?, credential: ShoeCredential, remembered: Bool) {
        ConnectionDiagnostics.record("Saved connection requested: \(side.rawValue)")
        let token = generation
        let attempt = UUID(); connectionAttempts[side] = attempt
        feet[side]!.connecting = true; feet[side]!.note = "Connecting…"
        tasks[side] = Task { [weak self] in
            guard let self else { return }
            do {
                let link: PeripheralLink
                if remembered {
                    let uniqueName = pair?.credential(.left).advertisedName != pair?.credential(.right).advertisedName
                    link = try await bluetooth.connectSaved(id: id, expectedName: credential.advertisedName, allowsNameMatch: uniqueName)
                }
                else if let id { link = try await bluetooth.connect(id: id, expectedName: credential.advertisedName) }
                else { throw AdaptError.invalidProfile }
                try await authenticate(link, side: side, credential: credential, token: token)
                connectionFailures[side] = nil
                connectionFailed = !connectionFailures.isEmpty
                if connected { reconnecting = false; reconnectDeadline?.cancel(); bluetooth.stopScan() }
                haptics.success()
            } catch {
                guard generation == token, connectionAttempts[side] == attempt else { return }
                if let currentID = links[side]?.peripheral.identifier ?? id { bluetooth.disconnect(id: currentID) }
                lost(side)
                if !Task.isCancelled {
                    recordConnectionFailure(error, side: side)
                    if !remembered { report(error) }
                }
            }
            guard connectionAttempts[side] == attempt else { return }
            tasks[side] = nil; connectionAttempts[side] = nil
            if !feet.values.contains(where: { $0.connecting }) {
                reconnecting = false; reconnectDeadline?.cancel()
            }
            recordConnectionSnapshot()
        }
    }
    private func recordConnectionFailure(_ error: Error, side: ShoeSide) {
        let reason = (error as? ShoeConnectionError)?.localizedDescription
            ?? (error as? AdaptError)?.localizedDescription
            ?? "The connection could not be completed. Try again."
        connectionFailures[side] = reason; connectionFailed = true
        feet[side]!.note = reason
        if Set(connectionFailures.values).count == 1 { connectionMessage = reason }
        else {
            connectionMessage = ShoeSide.allCases.compactMap { side in
                connectionFailures[side].map { "\(side.title): \($0)" }
            }.joined(separator: "\n")
        }
    }
    private func recordConnectionSnapshot() {
        #if DEBUG
        // Fixed UI states and messages only; never identifiers or BLE payloads.
        guard !demo, !localSetupPreview else { return }
        UserDefaults.standard.set([
            "connecting": connectionInProgress, "failed": connectionFailed,
            "leftConnected": feet[.left]!.connected, "rightConnected": feet[.right]!.connected,
            "message": connectionMessage
        ] as [String: Any], forKey: "lastConnectionReport")
        #endif
    }
    private func authenticate(_ link: PeripheralLink, side: ShoeSide, credential: ShoeCredential, token: UUID) async throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
        links[side] = link
        link.onDisconnect = { [weak self, weak link] in
            guard let self, let link, self.generation == token, self.links[side] === link else { return }; self.lost(side)
        }
        link.onPosition = { [weak self, weak link] raw in
            guard let self, let link, self.generation == token, self.links[side] === link else { return }
            let value = FitScale.percent(raw: raw, maximum: credential.fitMaximum)
            feet[side]!.measured = value; feet[side]!.progress = value
            if !feet[side]!.dragging && !feet[side]!.lacing { feet[side]!.target = FitScale.snapped(value) }
        }
        guard let session = link.session else { throw AdaptError.disconnected }
        ConnectionDiagnostics.record("Authentication started: \(side.rawValue)", link: link.diagnosticID)
        feet[side]!.note = "Checking saved key…"
        try await session.authenticate(key: credential.key)
        try Task.checkCancellation()
        guard generation == token, links[side] === link else { throw CancellationError() }
        ConnectionDiagnostics.record("Authentication succeeded: \(side.rawValue)", link: link.diagnosticID)
        let status = try await session.readStatus()
        try Task.checkCancellation()
        guard generation == token, links[side] === link else { throw CancellationError() }
        apply(status, side: side, maximum: credential.fitMaximum, syncTarget: true)
        feet[side]!.connecting = false; feet[side]!.connected = true; feet[side]!.note = "Connected"
        feet[side]!.hasFitCalibration = credential.hasFitCalibration
        feet[side]!.firmware = link.firmware?.version
        var remembered = bindings; remembered[side.rawValue] = link.peripheral.identifier.uuidString
        UserDefaults.standard.set(remembered, forKey: bindingKey)
        if !demo && !localSetupPreview, let selectedID {
            pairHistory.recordConnectedPair(selectedID, confirmedSides: Set(ShoeSide.allCases.filter { feet[$0]!.connected }))
        }
    }
    private func lost(_ side: ShoeSide) {
        feet[side]!.movementStartedAt = nil
        feet[side]!.connected = false; feet[side]!.connecting = false
        feet[side]!.busy = false; feet[side]!.lacing = false; feet[side]!.dragging = false
        feet[side]!.dragPosition = nil
        feet[side]!.lightColorID = nil
        feet[side]!.features = [:]
        feet[side]!.note = "Not connected"
        // Last readback remains distinct from an unconfirmed requested target.
        feet[side]!.progress = feet[side]!.measured ?? 0
        links[side] = nil
    }
    func disconnect(suppressReconnect: Bool = true, cancelShortcut: Bool = true) {
        reconnectSuppressed = suppressReconnect
        keepBackgroundConnections = false
        connectionFailed = false; connectionFailures.removeAll()
        connectionMessage = "Wake your shoes and tap Connect shoes."
        if cancelShortcut { shortcutExecution.cancel() }
        reconnectDeadline?.cancel(); reconnecting = false
        generation = UUID()
        connectionAttempts.removeAll()
        for task in tasks.values { task.cancel() }; tasks.removeAll()
        bluetooth.disconnectAll(); links.removeAll()
        feet = [.left: FootState(), .right: FootState()]
    }
    func background() {
        // Siri may start while an existing scene transitions to the background.
        // Its finite execution lease owns cleanup until the command finishes.
        if !demo && !shortcutRunning && !keepBackgroundConnections { disconnect(suppressReconnect: false) }
    }
    func reloadShortcutProfiles() throws {
        guard !demo, !localSetupPreview, !shortcutRunning else { return }
        // Entity queries can initialize the store while Keychain is locked.
        // Re-read after intent authentication instead of keeping an empty store.
        let saved = try vault.loadWithLocalDefault()
        guard saved != pairs || pair == nil else { return }
        pairs = saved
        selectedID = pairs.first(where: { $0.id == selectedID })?.id ?? preferredPairID
        loadModes()
    }
    func change(_ side: ShoeSide, value: Double) {
        guard !shortcutRunning, feet[side]!.connected, feet[side]!.hasFitCalibration, !feet[side]!.busy else { return }
        let target = FitScale.snapped(value)
        if feet[side]!.target != target { haptics.tick() }
        feet[side]!.target = target; feet[side]!.dragging = true
        feet[side]!.directAdjustment = false
        feet[side]!.dragPosition = min(100, max(0, value))
    }
    func cancelDrag(_ originals: [ShoeSide: Int]) {
        for (side, target) in originals { feet[side]!.target = target; feet[side]!.dragging = false; feet[side]!.dragPosition = nil }
    }
    func commit(_ side: ShoeSide) {
        guard !shortcutRunning, feet[side]!.connected, feet[side]!.hasFitCalibration, !feet[side]!.busy else { return }
        haptics.commit()
        move(side, target: feet[side]!.target)
    }
    func adjust(_ side: ShoeSide, by amount: Int) {
        change(side, value: Double(feet[side]!.target + amount))
        feet[side]!.directAdjustment = true
        commit(side)
    }
    private func move(_ side: ShoeSide, target: Int, onConfirmed: @escaping () -> Void = {}) {
        guard feet[side]!.connected, feet[side]!.hasFitCalibration, !feet[side]!.busy else { return }
        feet[side]!.target = target; feet[side]!.dragging = false; feet[side]!.dragPosition = nil
        feet[side]!.busy = true; feet[side]!.lacing = true; feet[side]!.note = "Lacing…"
        let token = generation
        let start = feet[side]!.measured ?? 0
        feet[side]!.movementStart = start; feet[side]!.movementStartedAt = Date()
        tasks[side] = Task { [weak self] in
            guard let self else { return }
            do {
                if demo {
                    try await Task.sleep(for: .seconds(AdaptMotion.lacingEstimate + 0.3))
                    guard generation == token else { return }
                    feet[side]!.measured = Double(target)
                } else {
                    guard let session = links[side]?.session, let maximum = pair?.credential(side).fitMaximum else { throw AdaptError.disconnected }
                    let status = try await session.setFit(percent: target, maximum: maximum)
                    try Task.checkCancellation()
                    guard generation == token else { return }
                    apply(status, side: side, maximum: maximum, syncTarget: false)
                }
                feet[side]!.movementStartedAt = nil
                feet[side]!.progress = feet[side]!.measured ?? 0
                feet[side]!.busy = false; feet[side]!.lacing = false; feet[side]!.note = "Fit confirmed"
                onConfirmed()
                haptics.success()
            } catch {
                guard generation == token else { return }
                feet[side]!.movementStartedAt = nil
                feet[side]!.busy = false; feet[side]!.lacing = false; feet[side]!.progress = feet[side]!.measured ?? 0
                feet[side]!.note = "Fit not confirmed"
                if let link = links[side] { bluetooth.disconnect(id: link.peripheral.identifier) }
                if !Task.isCancelled { report(error) }
            }
            tasks[side] = nil
        }
    }
    private func apply(_ status: ShoeStatus, side: ShoeSide, maximum: Int, syncTarget: Bool) {
        let value = FitScale.percent(raw: status.rawPosition, maximum: maximum)
        feet[side]!.measured = value; feet[side]!.progress = value; feet[side]!.battery = status.battery
        if syncTarget { feet[side]!.target = FitScale.snapped(value) }
    }
    func refreshBattery() {
        guard !shortcutRunning else { return }
        for side in ShoeSide.allCases where feet[side]!.connected && !feet[side]!.busy {
            perform(side) { session in
                guard let session, let maximum = self.pair?.credential(side).fitMaximum else { return }
                let status = try await session.readStatus()
                try Task.checkCancellation()
                self.apply(status, side: side, maximum: maximum, syncTarget: false)
            }
        }
    }
    func setColor(_ color: ShoeColor) {
        guard canControlBoth, !feet.values.contains(where: \.dragging) else { return }
        selectedColor = color.id; haptics.tick()
        for side in ShoeSide.allCases {
            perform(side, operation: { session in
                try await session?.setColor(Data(color.rgb))
            }, onSuccess: { self.feet[side]!.lightColorID = color.id })
        }
    }
    func lightsOff() {
        guard canControlBoth, !feet.values.contains(where: \.dragging) else { return }
        for side in ShoeSide.allCases {
            perform(side, operation: { session in
                try await session?.setColor(Data([0, 0, 0]), preview: false)
            }, onSuccess: { self.feet[side]!.lightColorID = nil })
        }
    }
    func setFeature(_ feature: ShoeFeature, enabled: Bool) {
        guard let pairID = selectedID, canControlBoth, !feet.values.contains(where: \.dragging) else { return }
        haptics.tick()
        for side in ShoeSide.allCases {
            feet[side]!.features[feature] = .applying
            perform(side, operation: { session in
                guard let session else { throw AdaptError.disconnected }
                switch feature {
                case .autoLace: try await session.setAutoLace(enabled: enabled)
                case .doubleTapUntie: try await session.setQuickUnlace(enabled: enabled)
                }
            }, onSuccess: {
                guard self.feet[side]!.connected else { return }
                self.feet[side]!.features[feature] = .confirmed(enabled)
                if feature == .autoLace {
                    let confirmations = ShoeSide.allCases.map { self.feet[$0]!.features[feature] ?? .unknown }
                    if self.demo {
                        if ShoePairFeatureState(confirmations) == .confirmed(enabled) { self.demoAutoLacePreference = enabled }
                    } else {
                        self.autoLaceHistory.record(enabled, forPair: pairID, confirmations: confirmations)
                    }
                }
            }, onFailure: { error in
                self.feet[side]!.features[feature] = .unconfirmed(error.localizedDescription)
                self.haptics.error()
            })
        }
    }
    func refreshGestureSettings() {
        guard !shortcutRunning else { return }
        for side in ShoeSide.allCases where feet[side]!.connected && !feet[side]!.busy && !feet[side]!.dragging {
            let previous = feet[side]!.features[.doubleTapUntie]
            var result: ShoeFeatureConfirmation = .confirmed(previous == .confirmed(true))
            feet[side]!.features[.doubleTapUntie] = .reading
            perform(side, operation: { session in
                guard let session else { throw AdaptError.disconnected }
                let configuration = try await session.readGestures()
                result = configuration.doubleTapEnabled.map(ShoeFeatureConfirmation.confirmed) ?? .unsupported
            }, onSuccess: {
                guard self.feet[side]!.connected else { return }
                self.feet[side]!.features[.doubleTapUntie] = result
            }, onFailure: { error in
                self.feet[side]!.features[.doubleTapUntie] = .unconfirmed(error.localizedDescription)
            })
        }
    }
    private func perform(_ side: ShoeSide, operation: @escaping (ShoeSession?) async throws -> Void,
                         onSuccess: @escaping () -> Void = {}, onFailure: ((Error) -> Void)? = nil) {
        guard !feet[side]!.busy else { return }
        let token = generation
        feet[side]!.busy = true
        tasks[side] = Task { [weak self] in
            guard let self else { return }
            do {
                if demo { try await Task.sleep(for: .milliseconds(150)) }
                else {
                    guard let session = links[side]?.session else { throw AdaptError.disconnected }
                    try await operation(session)
                }
                try Task.checkCancellation()
                guard generation == token else { return }
                onSuccess()
                feet[side]!.busy = false
            } catch {
                guard generation == token else { return }
                if let link = links[side] { bluetooth.disconnect(id: link.peripheral.identifier) }
                feet[side]!.busy = false
                if !Task.isCancelled {
                    if let onFailure { onFailure(error) } else { report(error) }
                }
            }
            tasks[side] = nil
        }
    }
    func saveMode(name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard canAdjustBoth, !clean.isEmpty, modes.count < 20 else { return }
        modes.append(FitMode(name: clean, left: feet[.left]!.target, right: feet[.right]!.target, colorID: nil))
        persistModes(); haptics.success()
    }
    func applyMode(_ mode: FitMode) {
        guard canAdjustBoth, modes.contains(where: { $0.id == mode.id }) else { return }
        let token = generation
        let pairID = selectedID
        var confirmedSides: Set<ShoeSide> = []
        haptics.commit()
        for side in ShoeSide.allCases {
            move(side, target: side == .left ? mode.left : mode.right) { [weak self] in
                guard let self, self.generation == token, self.selectedID == pairID else { return }
                confirmedSides.insert(side)
                self.rememberMode(mode.id, confirmedSides: confirmedSides)
            }
        }
    }
    private func rememberMode(_ id: UUID, confirmedSides: Set<ShoeSide>) {
        guard confirmedSides == Set(ShoeSide.allCases), modes.contains(where: { $0.id == id }) else { return }
        if !demo && !localSetupPreview {
            guard let selectedID else { return }
            fitHistory.recordConfirmedMode(id, forPair: selectedID, confirmedSides: confirmedSides)
        }
        lastUsedModeID = id
    }
    func deleteModes(at offsets: IndexSet) {
        guard !anyBusy else { return }
        modes.remove(atOffsets: offsets)
        if lastUsedMode == nil {
            lastUsedModeID = nil
            if !demo && !localSetupPreview, let selectedID { fitHistory.clear(forPair: selectedID) }
        }
        persistModes()
    }
    private var modeKey: String { "modes.\(selectedID ?? "none")" }
    private func loadModes() {
        if let data = UserDefaults.standard.data(forKey: modeKey), let saved = try? JSONDecoder().decode([FitMode].self, from: data),
           saved.count <= 20, saved.allSatisfy({ (0...100).contains($0.left) && (0...100).contains($0.right) }) {
            modes = saved
        } else { modes = [FitMode(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Move", left: 60, right: 60), FitMode(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Chill", left: 30, right: 30)] }
        lastUsedModeID = selectedID.flatMap { fitHistory.lastUsedMode(forPair: $0, availableModes: modes.map(\.id)) }
    }
    private func persistModes() {
        guard !demo, !localSetupPreview else { return }
        if let data = try? JSONEncoder().encode(modes) { UserDefaults.standard.set(data, forKey: modeKey) }
        OpenAdaptShortcuts.updateAppShortcutParameters()
    }
    #if DEBUG
    private func startDemo() {
        demo = true
        // An in-memory pair lets UI checks exercise editing/removal without Keychain.
        let sample = """
        {"version":2,"pairs":[{"id":"demo-pair","name":"Auto Max","shoes":{
          "left":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TESTL-001","key_hex":"000102030405060708090a0b0c0d0e0f","fit_maximum":61,"address":"00:00:00:00:00:01"},
          "right":{"profile":"auto-max-2.4.3M","credential_status":"hardware-verified","advertised_name":"004-TESTR-002","key_hex":"101112131415161718191a1b1c1d1e1f","fit_maximum":65,"address":"00:00:00:00:00:02"}}}]}
        """
        pairs = (try? ProfileImport.decode(Data(sample.utf8))) ?? []; selectedID = pairs.first?.id
        for side in ShoeSide.allCases {
            feet[side] = FootState(target: 30, measured: 30, progress: 30,
                                   battery: side == .left ? 100 : 93, lightColorID: "green", connected: true, note: "Demo")
        }
    }
    #endif
}


// App Intents and the visible UI share one store, one set of BLE sessions and
// the same ShoeSession implementation. A voice command lives only in memory.
extension AppStore: ShoeShortcutController {
    func tieShoes() async throws -> String {
        try reloadShortcutProfiles()
        guard !demo else { throw ShoeShortcutError.message("Siri controls your real shoes. Leave demo mode to continue.") }
        guard let selectedID, pair != nil else { throw ShoeShortcutError.message("Add your shoes in OpenAdapt first.") }
        guard let mode = tieMode else {
            throw ShoeShortcutError.message("Save a fit in OpenAdapt to use Tie Shoes.")
        }
        return try await runSavedMode(id: "\(selectedID)/\(mode.id.uuidString)")
    }

    func runSavedMode(id: String) async throws -> String {
        try reloadShortcutProfiles()
        guard let pairID = selectedID, let mode = modes.first(where: { "\(pairID)/\($0.id.uuidString)" == id }) else {
            throw ShoeShortcutError.message("Choose a saved fit for the current pair in OpenAdapt.")
        }
        _ = try await runShortcut(.fit([.left: mode.left, .right: mode.right]))
        try Task.checkCancellation()
        guard selectedID == pairID else { throw CancellationError() }
        rememberMode(mode.id, confirmedSides: Set(ShoeSide.allCases))
        return mode.name
    }

    func runShortcut(_ command: ShoeShortcutCommand) async throws -> String {
        try Task.checkCancellation()
        guard !demo else { throw ShoeShortcutError.message("Siri controls your real shoes. Leave demo mode to continue.") }
        guard !shortcutRunning, !feet.values.contains(where: { $0.busy || $0.dragging || $0.connecting }) else { throw AdaptError.busy }
        try reloadShortcutProfiles()
        guard pair != nil else { throw ShoeShortcutError.message("Add your shoes in OpenAdapt first.") }
        shortcutRunning = true
        shortcutGeneration = generation
        let lease = ShortcutBackgroundLease()
        defer {
            shortcutRunning = false; shortcutGeneration = nil
            if UIApplication.shared.applicationState != .active && !keepBackgroundConnections {
                disconnect(suppressReconnect: false)
            }
            lease.end()
        }
        try lease.begin { [weak self] in self?.shortcutExecution.expire() }
        let reply = try await shortcutExecution.run(onCancel: { [weak self] in self?.disconnect() }) {
            try await ShoeShortcutRunner.run(command, using: self)
        }
        // An explicit Connect keeps idle BLE links available. Other actions use
        // one-shot sessions in the background, unless Connect was already used.
        if case .connect = command { keepBackgroundConnections = true }
        return reply
    }

    func checkShortcutContext() throws {
        try shortcutExecution.checkActive()
        guard shortcutGeneration == generation else { throw CancellationError() }
    }

    func prepareShortcut(sides: [ShoeSide]) async throws {
        guard let pair, sides.allSatisfy({ feet[$0]!.connected || bindings[$0.rawValue].flatMap(UUID.init(uuidString:)) != nil }) else {
            throw ShoeShortcutError.message("Connect each requested shoe in OpenAdapt once before using Siri.")
        }
        reconnectDeadline?.cancel(); reconnecting = false; bluetooth.stopScan()
        let remembered = bindings
        let token = generation
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for side in sides where !feet[side]!.connected {
                    let id = UUID(uuidString: remembered[side.rawValue]!)!
                    let credential = pair.credential(side)
                    group.addTask { @MainActor in
                        try Task.checkCancellation(); try self.checkShortcutContext()
                        self.feet[side]!.connecting = true; self.feet[side]!.note = "Connecting…"
                        let link = try await self.bluetooth.connectRemembered(id: id, expectedName: credential.advertisedName)
                        try await self.authenticate(link, side: side, credential: credential, token: token)
                    }
                }
                for try await _ in group {}
            }
            try Task.checkCancellation(); try checkShortcutContext()
        } catch {
            // Cancel pending CoreBluetooth connects too: a shoe waking later
            // must never receive this action after Siri has returned an error.
            disconnect(cancelShortcut: false)
            throw error
        }
    }

    func shortcutMaximum(_ side: ShoeSide) throws -> Int {
        guard let pair else { throw AdaptError.invalidProfile }
        return pair.credential(side).fitMaximum
    }

    private func shortcutSession(_ side: ShoeSide) throws -> ShoeSession {
        try Task.checkCancellation()
        try checkShortcutContext()
        guard feet[side]!.connected, !feet[side]!.busy, let session = links[side]?.session else {
            throw AdaptError.disconnected
        }
        return session
    }

    func shortcutStatus(_ side: ShoeSide) async throws -> ShoeStatus {
        let session = try shortcutSession(side)
        let maximum = try shortcutMaximum(side)
        feet[side]!.busy = true
        defer { if shortcutGeneration == generation { feet[side]!.busy = false } }
        do {
            let status = try await session.readStatus()
            try Task.checkCancellation(); try checkShortcutContext()
            apply(status, side: side, maximum: maximum, syncTarget: false)
            return status
        } catch {
            if shortcutGeneration == generation, let link = links[side] { bluetooth.disconnect(id: link.peripheral.identifier) }
            throw error
        }
    }

    func shortcutFit(_ side: ShoeSide, percent: Int) async throws {
        let session = try shortcutSession(side)
        let maximum = try shortcutMaximum(side)
        feet[side]!.target = percent; feet[side]!.busy = true; feet[side]!.lacing = true
        feet[side]!.movementStart = feet[side]!.measured ?? 0
        feet[side]!.movementStartedAt = Date(); feet[side]!.note = "Lacing…"
        defer {
            if shortcutGeneration == generation {
                feet[side]!.busy = false; feet[side]!.lacing = false
                feet[side]!.movementStartedAt = nil
                feet[side]!.progress = feet[side]!.measured ?? 0
            }
        }
        do {
            let status = try await session.setFit(percent: percent, maximum: maximum)
            try Task.checkCancellation(); try checkShortcutContext()
            apply(status, side: side, maximum: maximum, syncTarget: false)
            feet[side]!.note = "Fit confirmed"; haptics.success()
        } catch {
            if shortcutGeneration == generation {
                feet[side]!.note = "Fit not confirmed"
                if let link = links[side] { bluetooth.disconnect(id: link.peripheral.identifier) }
            }
            throw error
        }
    }

    func shortcutLights(_ side: ShoeSide, rgb: [UInt8], colorID: String?) async throws {
        let session = try shortcutSession(side)
        feet[side]!.busy = true
        defer { if shortcutGeneration == generation { feet[side]!.busy = false } }
        do {
            try await session.setColor(Data(rgb), preview: colorID != nil)
            try Task.checkCancellation(); try checkShortcutContext()
            feet[side]!.lightColorID = colorID
            if let colorID { selectedColor = colorID }
        } catch {
            if shortcutGeneration == generation, let link = links[side] { bluetooth.disconnect(id: link.peripheral.identifier) }
            throw error
        }
    }
}
