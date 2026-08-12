import GoogleMobileAds
import UIKit

/// 変換ツール完了時に表示するインタースティシャル広告のロード・頻度制御・表示を担うシングルトン。
/// Proユーザーにはロード・表示とも一切行わない。
@MainActor
final class AdMobInterstitialManager: NSObject {

    static let shared = AdMobInterstitialManager()

    // AdMob公式テスト用広告ユニットID。本番リリース前に実際の広告ユニットIDへ差し替えること。
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    private static let completionCountKey = "com.pdfone.admob.completionCount"
    private let userDefaults: UserDefaults

    private var interstitial: GADInterstitialAd?
    private var isProUserProvider: (() -> Bool)?
    private var pendingCompletion: ((Bool) -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// アプリ起動時に一度呼び出し、Pro状態の参照方法を設定する。
    func configure(isProUserProvider: @escaping () -> Bool) {
        self.isProUserProvider = isProUserProvider
    }

    private var isProUser: Bool {
        isProUserProvider?() ?? false
    }

    func preloadAd() {
        guard !isProUser, interstitial == nil else { return }

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            ad?.fullScreenContentDelegate = self
            self.interstitial = ad
        }
    }

    /// 2回の変換処理につき1回、ロード済みの広告を表示する。Proユーザーの場合は即座にcompletion(false)を呼ぶ。
    /// completionの引数は、実際に広告を表示できたかどうか（Paywall導線を出すかの判断に使う）。
    func showAdIfEligible(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard !isProUser else {
            completion(false)
            return
        }

        let count = userDefaults.integer(forKey: Self.completionCountKey) + 1
        userDefaults.set(count, forKey: Self.completionCountKey)

        guard count.isMultiple(of: 2), let interstitial else {
            completion(false)
            if interstitial == nil { preloadAd() }
            return
        }

        pendingCompletion = completion
        interstitial.present(fromRootViewController: viewController)
    }

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}

extension AdMobInterstitialManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        interstitial = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(true)
        preloadAd()
    }

    func ad(_ ad: any GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(false)
        preloadAd()
    }
}
