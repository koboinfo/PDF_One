import SwiftUI

/// ファイル未選択時やデータがない場合に表示する共通のプレースホルダー。
/// すりガラス調のカードに包むことで、`AppBackground`のグラデーションを透かしつつ
/// 主役要素として視線を集める。`BaseToolView`のfooterと同時表示されることはないため、
/// 内部でScrollViewにしても他要素との被りは発生しない。
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
            }
            .frame(minHeight: 320)
            .frame(maxWidth: .infinity)
        }
    }

    private var card: some View {
        VStack(spacing: 24) {
            iconBadge

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.tertiary)
                }
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: "plus.circle.fill", action: action)
                    .padding(.horizontal, 8)
            }
        }
        .padding(28)
        .background(cardBackground)
        .padding(.horizontal, 24)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 88, height: 88)
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
    }
}

#Preview("Standard") {
    EmptyStateView(
        systemImage: "doc.on.doc",
        title: "結合したいPDFファイルを選択してください",
        actionTitle: "PDFを選択",
        action: {}
    )
    .background(AppBackground())
}

#Preview("Long Title - iPhone SE") {
    EmptyStateView(
        systemImage: "doc.on.doc",
        title: "結合したいPDFファイルを\nドラッグ＆ドロップ、またはタップして選択してください",
        message: "複数ファイルを選択した場合、選んだ順に結合されます",
        actionTitle: "PDFを選択",
        action: {}
    )
    .background(AppBackground())
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("No Action") {
    EmptyStateView(
        systemImage: "tray",
        title: "保存されたファイルはありません"
    )
    .background(AppBackground())
}
