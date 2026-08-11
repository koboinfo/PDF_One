import SwiftUI

/// アイコン下の小さなドットで選択状態を示す、フローティング型のミニマルなタブバー。
struct ModernTabBar: View {
    /// バーの実高。下の`body`の構成から導出した固定値で、レイアウト基準値（`LayoutConstants`）が参照する。
    /// 内訳: アイコン22 + spacing5 + インジケータ4 = 31、ボタンの縦padding 6×2 = +12、HStackの縦padding 10×2 = +20。
    static let height: CGFloat = 63

    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 24)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selection

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: isSelected ? .regular : .thin))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.55))
                    .frame(height: 22)

                Circle()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModernTabBar(selection: .constant(.tools))
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hue: 0.62, saturation: 0.05, brightness: 0.95))
}
