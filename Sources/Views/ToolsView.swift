import SwiftUI

struct ToolsView: View {
    @State private var viewModel = ToolsViewModel()
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var isShowingPaywall = false
    @State private var containerWidth: CGFloat = 0

    /// 画面幅に応じた列数: 小型スマホ(SE等)は2列、通常〜大型スマホ/iPad縦は3列、iPad横等の広幅は4列。
    private var columnCount: Int {
        switch containerWidth {
        case ..<380: return 2
        case ..<1000: return 3
        default: return 4
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(viewModel.availableTools) { tool in
                            ToolCardView(
                                tool: tool,
                                isLocked: isLocked(tool)
                            ) {
                                open(tool)
                            }
                        }
                    } header: {
                        sectionHeader(String(localized: "ツール一覧"))
                    }

                    if !viewModel.comingSoonTools.isEmpty {
                        Section {
                            ForEach(viewModel.comingSoonTools) { tool in
                                ToolCardView(tool: tool, action: {})
                            }
                        } header: {
                            sectionHeader(String(localized: "準備中"))
                        }
                    }
                }
                .padding(.horizontal, LayoutConstants.screenHorizontalPadding)
                .padding(.top, 8)
            }
            .tabBarClearance()
            .withTopAdBanner()
            .background(AppBackground())
            .navigationTitle(String(localized: "ツール"))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                containerWidth = newWidth
            }
            .navigationDestination(for: ToolRoute.self) { route in
                destination(for: route)
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(.ultraThinMaterial)
    }

    private func isLocked(_ tool: ToolItem) -> Bool {
        tool.isPro && !subscriptionManager.isProUser
    }

    private func open(_ tool: ToolItem) {
        if isLocked(tool) {
            isShowingPaywall = true
        } else {
            viewModel.open(tool.route)
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

#Preview(String(localized: "通常時（無料ユーザー）")) {
    ToolsView()
        .environment(SubscriptionManager.preview(isProUser: false))
}

#Preview(String(localized: "Proユーザー時")) {
    ToolsView()
        .environment(SubscriptionManager.preview(isProUser: true))
}

#Preview(String(localized: "小型画面時（iPhone SE）")) {
    ToolsView()
        .environment(SubscriptionManager.preview(isProUser: false))
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}
