import SwiftUI

struct ToolsView: View {
    @State private var viewModel = ToolsViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.availableTools) { tool in
                        ToolCardView(tool: tool) {
                            viewModel.open(tool.route)
                        }
                    }

                    ForEach(viewModel.comingSoonTools) { tool in
                        ToolCardView(tool: tool, action: {})
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("ツール")
            .navigationDestination(for: ToolRoute.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ToolRoute) -> some View {
        switch route {
        case .merge:
            MergeView()
        case .imageToPDF:
            ImageToPDFView()
        case .compress:
            CompressView()
        case .pageEdit:
            PageEditView()
        case .pdfToJPG:
            PDFToJPGView()
        case .splitPDF:
            SplitPDFView()
        case .protectPDF:
            ProtectPDFView()
        case .signature:
            SignatureView()
        case .ocr:
            OCRView()
        case .watermark:
            WatermarkView()
        case .officeConvert:
            OfficeConvertView()
        case .officeToPDF:
            OfficeToPDFView()
        }
    }
}

#Preview {
    ToolsView()
}
