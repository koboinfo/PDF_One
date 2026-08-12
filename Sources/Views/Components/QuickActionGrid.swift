import SwiftUI

/// ホーム画面のクイックアクション用グリッド。`ToolsView`のツール一覧グリッドと同じ視覚言語
/// （角丸カード・アイコンバッジ・幅に応じた列数切替）を踏襲するが、`HomeQuickAction`専用の
/// 軽量なカードを持ち、`ToolCardView`/`ToolItem`には依存しない。
struct QuickActionGrid: View {
    let actions: [HomeQuickAction]
    let onSelect: (HomeQuickAction) -> Void

    @State private var containerWidth: CGFloat = 0

    private var columnCount: Int {
        switch containerWidth {
        case ..<380: return 2
        case ..<1000: return 3
        default: return 4
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(actions) { action in
                Button {
                    onSelect(action)
                } label: {
                    QuickActionCard(action: action)
                }
                .buttonStyle(QuickActionCardButtonStyle())
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
    }
}

private struct QuickActionCard: View {
    let action: HomeQuickAction

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(action.tint.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: action.systemImage)
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(action.tint)
            }

            Text(action.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 26)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
                .shadow(color: .white.opacity(0.9), radius: 6, x: -3, y: -3)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct QuickActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    QuickActionGrid(
        actions: [
            HomeQuickAction(title: String(localized: "スキャン"), systemImage: "doc.viewfinder", tint: .blue, destination: .scanner),
            HomeQuickAction(title: String(localized: "PDF結合"), systemImage: ToolIconType.merge.systemImage, tint: ToolIconType.merge.tint, destination: .merge),
            HomeQuickAction(title: String(localized: "画像→PDF"), systemImage: ToolIconType.imageToPDF.systemImage, tint: ToolIconType.imageToPDF.tint, destination: .imageToPDF),
            HomeQuickAction(title: String(localized: "圧縮"), systemImage: ToolIconType.compress.systemImage, tint: ToolIconType.compress.tint, destination: .compress)
        ],
        onSelect: { _ in }
    )
    .padding(20)
    .background(Color(hue: 0.62, saturation: 0.05, brightness: 0.95))
}
