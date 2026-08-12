import SwiftUI

/// ツール一覧グリッドで使うカード。白背景+ソフトシャドウでわずかに浮き上がった質感を出し、
/// アイコンは細身のSF Symbolsとパステルトーンの背景円で統一する。
struct ToolCardView: View {
    let tool: ToolItem
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                iconBadge
                Text(tool.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 26)
            .padding(.horizontal, 10)
            .opacity(tool.isComingSoon ? 0.45 : 1)
            .background(cardBackground)
            .overlay(alignment: .topTrailing) {
                if tool.isComingSoon {
                    comingSoonBadge
                } else if isLocked {
                    proBadge
                }
            }
        }
        .buttonStyle(ToolCardButtonStyle())
        .disabled(tool.isComingSoon)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(tool.iconType.tint.opacity(0.14))
                .frame(width: 52, height: 52)
            Image(systemName: tool.iconType.systemImage)
                .font(.system(size: 20, weight: .thin))
                .foregroundStyle(tool.iconType.tint)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            .shadow(color: .white.opacity(0.9), radius: 6, x: -3, y: -3)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            )
    }

    private var comingSoonBadge: some View {
        Text(String(localized: "準備中"))
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
            .padding(10)
    }

    private var proBadge: some View {
        Label("Pro", systemImage: "crown.fill")
            .labelStyle(.iconOnly)
            .font(.system(size: 10, weight: .semibold))
            .padding(6)
            .background(Color.orange.opacity(0.16), in: Circle())
            .foregroundStyle(.orange)
            .padding(10)
    }
}

/// 押下時にわずかに縮小・減光させ、指で押し込んだ感触を出すボタンスタイル。
private struct ToolCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
        ToolCardView(tool: ToolItem(title: String(localized: "PDF結合"), iconType: .merge, route: .merge), action: {})
        ToolCardView(tool: ToolItem(title: String(localized: "画像→PDF"), iconType: .imageToPDF, route: .imageToPDF), action: {})
        ToolCardView(
            tool: ToolItem(title: String(localized: "電子署名"), iconType: .signature, route: .signature, isPro: true),
            isLocked: true,
            action: {}
        )
        ToolCardView(tool: ToolItem(title: String(localized: "準備中ツール"), iconType: .watermark, route: nil), action: {})
    }
    .padding(20)
    .background(Color(hue: 0.62, saturation: 0.05, brightness: 0.95))
}
