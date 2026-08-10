import SwiftUI

/// ファイル未選択時やデータがない場合に表示する共通のプレースホルダー。
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

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
                    .padding(.horizontal, 32)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "doc.on.doc",
        title: "結合したいPDFファイルを選択してください",
        actionTitle: "PDFを選択",
        action: {}
    )
}
