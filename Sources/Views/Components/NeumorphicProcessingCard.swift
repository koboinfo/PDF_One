import SwiftUI

/// ネオモーフィズム風の柔らかい二重シャドウカードで処理中インジケーターを表示する。BaseToolViewベースの各画面で共通利用する。
struct NeumorphicProcessingCard: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hue: 0.62, saturation: 0.03, brightness: 0.96))
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 8, y: 8)
                    .shadow(color: .white.opacity(0.9), radius: 16, x: -8, y: -8)
            )
        }
    }
}

#Preview {
    NeumorphicProcessingCard(message: "処理中…")
}