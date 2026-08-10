import SwiftUI

enum ToastStyle: Equatable {
    case success
    case error

    var tintColor: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct ToastData: Equatable, Identifiable {
    let id = UUID()
    let style: ToastStyle
    let message: String

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

/// 処理完了・エラー時に画面上部へ一時的に表示する通知バナー。
struct ToastNotificationView: View {
    let toast: ToastData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.systemImage)
                .foregroundStyle(toast.style.tintColor)
                .font(.title3)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    var duration: TimeInterval = 2.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastNotificationView(toast: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast) {
                            try? await Task.sleep(for: .seconds(duration))
                            guard !Task.isCancelled else { return }
                            self.toast = nil
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast)
    }
}

extension View {
    /// `toast` に値がセットされている間、画面上部にバナーを表示し、`duration` 秒後に自動で閉じる。
    func toast(_ toast: Binding<ToastData?>, duration: TimeInterval = 2.5) -> some View {
        modifier(ToastModifier(toast: toast, duration: duration))
    }
}

#Preview {
    VStack {
        Spacer()
    }
    .toast(.constant(ToastData(style: .success, message: "キャッシュを削除しました")))
}
