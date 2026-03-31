import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct TVSharedListsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MobileAds.shared.start { _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
    }
}
