import CloudKit
import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct TVSharedListsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        MobileAds.shared.start { _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        ATTrackingManager.requestTrackingAuthorization { _ in }
                    }
                }
        }
    }
}

// MARK: - AppDelegate for CloudKit share acceptance

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)
        Task { @MainActor in
            do {
                try await container.accept(cloudKitShareMetadata)
                // Post a notification so any live TVCloudKitManager can refresh
                NotificationCenter.default.post(name: .tvCloudKitShareAccepted, object: nil)
            } catch {
                print("[TVSharedLists] Failed to accept share: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let tvCloudKitShareAccepted = Notification.Name("tvCloudKitShareAccepted")
}
