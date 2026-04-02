import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct TVSharedListsApp: App {
    init() {
        MobileAds.shared.start { _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // ATT prompt must be requested after the window is presented.
                    // Using scenePhase .active is unreliable on iOS 17+ because it
                    // fires before the window hierarchy is ready, causing the prompt
                    // to be silently suppressed.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        ATTrackingManager.requestTrackingAuthorization { _ in }
                    }
                }
        }
    }
}
