import SwiftUI

@main
struct LiDARForgeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .environment(\.locale, appState.resolvedLocale)
                .onOpenURL { url in
                    appState.importProjectPackage(from: url)
                }
        }
    }
}
