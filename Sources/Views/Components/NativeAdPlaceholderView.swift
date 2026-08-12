import SwiftUI

/// フィード中間に挟むネイティブ広告風のプレースホルダー。上部の`AdBannerView`（標準バナー、
/// `.withTopAdBanner()`）とは別枠として共存する。広告SDK導入後は、この内部を実際の
/// `GADNativeAdView`ラッパーに差し替える想定。
///
/// `AdBannerView`の`AdVisibilityModifier`は高さ`AdBannerView.height`固定を前提にしており、
/// このカードは丈が可変なため流用せず、`isAdBannerVisible`を直接見て`if`で出し入れする。
struct NativeAdPlaceholderView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        if subscriptionManager.isAdBannerVisible {
            content
                .transition(.opacity)
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "広告"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 140, height: 12)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.14))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 88, height: 26)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
        )
    }
}

#Preview(String(localized: "無料ユーザー")) {
    NativeAdPlaceholderView()
        .padding(20)
        .environment(SubscriptionManager.preview(isProUser: false))
}

#Preview(String(localized: "Proユーザー")) {
    NativeAdPlaceholderView()
        .padding(20)
        .environment(SubscriptionManager.preview(isProUser: true))
}
