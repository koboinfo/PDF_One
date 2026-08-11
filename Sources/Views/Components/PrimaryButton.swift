import SwiftUI

/// アプリ全体で使う統一デザインのメインボタン。ダーク系グラデーションのカプセル型で、処理中はインジケータを表示して二重タップを防ぐ。
struct PrimaryButton: View {
    enum Style {
        case prominent
        case bordered
    }

    let title: String
    let systemImage: String
    var style: Style = .prominent
    var isProcessing: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    private var isEffectivelyDisabled: Bool { isDisabled || isProcessing }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style == .prominent ? .white : .primary)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentTransition(.opacity)
        }
        .buttonStyle(PrimaryButtonStyle(style: style, isDisabled: isEffectivelyDisabled))
        .disabled(isEffectivelyDisabled)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let style: PrimaryButton.Style
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(background)
            .clipShape(Capsule(style: .continuous))
            .opacity(isDisabled ? 0.4 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        style == .prominent ? .primary : .primary.opacity(0.85)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .prominent:
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        case .bordered:
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.75))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1.2)
                )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "PDFを選択", systemImage: "plus.circle.fill", action: {})
        PrimaryButton(title: "処理中…", systemImage: "arrow.down.circle.fill", isProcessing: true, action: {})
        PrimaryButton(title: "共有する", systemImage: "square.and.arrow.up", style: .bordered, action: {})
        PrimaryButton(title: "無効化", systemImage: "xmark", isDisabled: true, action: {})
    }
    .padding()
    .background(Color(hue: 0.62, saturation: 0.05, brightness: 0.95))
}
