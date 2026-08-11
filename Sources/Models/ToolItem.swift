import SwiftUI

enum ToolRoute: Hashable, Identifiable {
    case merge, imageToPDF, compress, pageEdit, pdfToJPG, splitPDF, protectPDF, signature, ocr
    case watermark, officeConvert, officeToPDF

    var id: Self { self }
}

enum ToolIconType: Hashable {
    case merge, imageToPDF, compress, pageEdit, pdfToJPG, splitPDF, protectPDF
    case pdfToWord, signature, ocr, watermark, officeToPDF

    var systemImage: String {
        switch self {
        case .merge: return "doc.on.doc"
        case .imageToPDF: return "photo.on.rectangle.angled"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .pageEdit: return "square.on.square"
        case .pdfToJPG: return "photo"
        case .splitPDF: return "square.split.2x1"
        case .protectPDF: return "lock.doc"
        case .pdfToWord: return "doc.text"
        case .signature: return "signature"
        case .ocr: return "text.viewfinder"
        case .watermark: return "drop"
        case .officeToPDF: return "doc.badge.plus"
        }
    }

    /// HSBで彩度を抑えたパステルトーンを生成し、全ツールで統一感のある配色にする。
    var tint: Color {
        switch self {
        case .merge: return Color(hue: 0.62, saturation: 0.30, brightness: 0.55)
        case .imageToPDF: return Color(hue: 0.08, saturation: 0.35, brightness: 0.68)
        case .compress: return Color(hue: 0.38, saturation: 0.28, brightness: 0.50)
        case .pageEdit: return Color(hue: 0.75, saturation: 0.22, brightness: 0.55)
        case .pdfToJPG: return Color(hue: 0.92, saturation: 0.28, brightness: 0.62)
        case .splitPDF: return Color(hue: 0.45, saturation: 0.28, brightness: 0.52)
        case .protectPDF: return Color(hue: 0.52, saturation: 0.24, brightness: 0.48)
        case .pdfToWord: return Color(hue: 0.98, saturation: 0.32, brightness: 0.55)
        case .signature: return Color(hue: 0.68, saturation: 0.25, brightness: 0.50)
        case .ocr: return Color(hue: 0.07, saturation: 0.24, brightness: 0.42)
        case .watermark: return Color(hue: 0.53, saturation: 0.30, brightness: 0.60)
        case .officeToPDF: return Color(hue: 0.14, saturation: 0.30, brightness: 0.58)
        }
    }
}

struct ToolItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let iconType: ToolIconType
    let route: ToolRoute?
    var isPro: Bool = false

    var isComingSoon: Bool { route == nil }
}
