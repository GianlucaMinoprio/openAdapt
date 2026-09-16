import SwiftUI
import AppIntents

@main
struct OpenAdaptApp: App {
    @StateObject private var store = AppStore.shared
    @Environment(\.scenePhase) private var phase
    init() { OpenAdaptShortcuts.updateAppShortcutParameters() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: phase) { _, phase in
                    if phase == .background { store.background() }
                    else if phase == .active { store.foreground() }
                }
        }
    }
}
