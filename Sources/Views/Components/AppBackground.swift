import SwiftUI

/// 全画面で共有するパステルグラデーション背景。トーンをToolsViewに揃える。
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hue: 0.62, saturation: 0.04, brightness: 0.97),
                Color(hue: 0.62, saturation: 0.06, brightness: 0.93)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// パステルグラデーション背景を敷き、List/Formの標準背景を透過させて重ねる。
    func appBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackground())
    }
}
