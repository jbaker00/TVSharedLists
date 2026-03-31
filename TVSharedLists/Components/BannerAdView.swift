import SwiftUI
import GoogleMobileAds

/// Google AdMob banner ad view.
/// Uses the standard test ad unit ID — replace with a real unit ID before submitting to the App Store.
struct BannerAdView: UIViewRepresentable {
    // Test banner ad unit ID (Google's official test ID)
    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first?
            .rootViewController
    }
}
