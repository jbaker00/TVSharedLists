import SwiftUI
import GoogleMobileAds

/// Google AdMob banner ad view.
/// Ad unit ID is loaded from AdSecrets (Secrets.swift, gitignored).
struct BannerAdView: UIViewRepresentable {
    private let adUnitID = AdSecrets.bannerAdUnitID

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
