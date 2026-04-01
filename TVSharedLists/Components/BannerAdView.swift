import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdSecrets.bannerAdUnitID
        banner.delegate = context.coordinator
        return banner
    }

    /// updateUIView is called after the view is inserted into the live hierarchy,
    /// so rootViewController is reliably non-nil here.
    func updateUIView(_ banner: BannerView, context: Context) {
        guard banner.rootViewController == nil,
              let rootVC = activeRootViewController()
        else { return }
        banner.rootViewController = rootVC
        banner.load(Request())
    }

    private func activeRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive })
            .flatMap { $0 as? UIWindowScene }?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }

    // MARK: - Delegate (logs to console so you can see what AdMob is doing)

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] ✅ Ad loaded successfully")
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] ❌ Failed to load ad: \(error.localizedDescription)")
        }
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("[AdMob] Ad will present screen")
        }
    }
}
