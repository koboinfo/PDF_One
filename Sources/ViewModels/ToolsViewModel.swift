import Foundation

@Observable
@MainActor
final class ToolsViewModel {

    let availableTools: [ToolItem]
    let comingSoonTools: [ToolItem]

    /// NavigationStackのpushスタック。ツール選択時にここへ積み、戻る操作で自動的にpopされる。
    var path: [ToolRoute] = []

    init() {
        availableTools = [
            ToolItem(title: "PDF結合", iconType: .merge, route: .merge),
            ToolItem(title: "画像→PDF", iconType: .imageToPDF, route: .imageToPDF),
            ToolItem(title: "圧縮", iconType: .compress, route: .compress),
            ToolItem(title: "ページ編集", iconType: .pageEdit, route: .pageEdit),
            ToolItem(title: "PDF→JPG", iconType: .pdfToJPG, route: .pdfToJPG),
            ToolItem(title: "PDF分割", iconType: .splitPDF, route: .splitPDF),
            ToolItem(title: "パスワード設定", iconType: .protectPDF, route: .protectPDF),
            ToolItem(title: "電子署名", iconType: .signature, route: .signature, isPro: true),
            ToolItem(title: "OCR", iconType: .ocr, route: .ocr, isPro: true),
            ToolItem(title: "透かし", iconType: .watermark, route: .watermark, isPro: true),
            ToolItem(title: "PDF→Office", iconType: .pdfToWord, route: .officeConvert, isPro: true),
            ToolItem(title: "Office→PDF", iconType: .officeToPDF, route: .officeToPDF, isPro: true)
        ]

        comingSoonTools = []
    }

    func open(_ route: ToolRoute?) {
        guard let route else { return }
        path.append(route)
    }
}
