import SwiftUI

/// ファイル選択・プレビューなど `.sheet` で提示するダイアログをアプリ全体で統一するためのラッパー。
/// ハーフモーダル（`.medium`/`.large`）と角丸コーナーを標準化する。
struct ModernSheet<Content: View>: View {
    var title: String?
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
                .background(AppBackground())
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationTitle(title ?? "")
                .navigationBarTitleDisplayMode(.inline)
        }
        .modernSheetPresentation(detents: detents)
    }
}

extension View {
    /// 既存の `.sheet` コンテンツにハーフモーダル標準スタイル（角丸24pt・ドラッグインジケータ）を適用する。
    func modernSheetPresentation(detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(24)
            .presentationDragIndicator(.visible)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ModernSheet(title: "プレビュー") {
                Text("シートの内容")
            }
        }
}
