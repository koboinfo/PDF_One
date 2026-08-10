import SwiftUI

/// 処理完了画面で、生成されたPDFをカード型プレビューとして表示する共通コンポーネント。
struct ResultPreviewCard: View {
    let url: URL
    var title: String = "生成されたPDF"
    var subtitle: String?

    var body: some View {
        VStack(spacing: 16) {
            PDFPreviewView(url: url)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
        )
    }
}

#Preview {
    ResultPreviewCard(url: URL(fileURLWithPath: "/tmp/sample.pdf"), subtitle: "3ページ・1.2MB")
        .padding(24)
        .background(Color(hue: 0.62, saturation: 0.05, brightness: 0.95))
}
