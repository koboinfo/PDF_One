import SwiftUI
import UniformTypeIdentifiers

/// 全ツール画面共通の雛形。戻る+タイトル+ヘルプの独自ヘッダー、自由なコンテンツ領域、
/// 固定のアクションフッターで構成し、システムのナビゲーションバーは非表示にする。
struct BaseToolView<Content: View, Footer: View>: View {
    let title: String
    let helpText: String?
    let onDropProviders: (([NSItemProvider]) -> Bool)?
    let content: Content
    let footer: Footer

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingHelp = false

    init(
        title: String,
        helpText: String? = nil,
        onDropProviders: (([NSItemProvider]) -> Bool)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.helpText = helpText
        self.onDropProviders = onDropProviders
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .applyingDrop(onDropProviders)
            footer
                .padding(.horizontal, LayoutConstants.screenHorizontalPadding)
                .padding(.top, LayoutConstants.toolFooterTopPadding)
                .padding(.bottom, LayoutConstants.toolFooterBottomPadding)
        }
        // ツール詳細はToolsViewのNavigationStackにプッシュされるため、タブバーが下端に重なる。
        // ここで一括してクリアランスを確保することで、実行ボタンをフッターに置く画面（結合など）は
        // フッターごと押し上がり、Form内に置く画面（圧縮など）は最終セクションまでスクロールできる。
        .tabBarClearance()
        .background(AppBackground())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert(title, isPresented: $isShowingHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(helpText ?? "")
        }
    }

    private var header: some View {
        HStack {
            HeaderIconButton(systemImage: "chevron.left", action: { dismiss() })

            Spacer()

            Text(title)
                .font(.headline)

            Spacer()

            if helpText != nil {
                HeaderIconButton(systemImage: "questionmark.circle", action: { isShowingHelp = true })
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, LayoutConstants.screenHorizontalPadding)
        .padding(.top, LayoutConstants.toolHeaderTopPadding)
        .padding(.bottom, LayoutConstants.toolHeaderBottomPadding)
    }
}

extension BaseToolView where Footer == EmptyView {
    init(
        title: String,
        helpText: String? = nil,
        onDropProviders: (([NSItemProvider]) -> Bool)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, helpText: helpText, onDropProviders: onDropProviders, content: content) {
            EmptyView()
        }
    }
}

/// ヘッダーの丸型アイコンボタン。白背景+ソフトシャドウで他のカード要素とトーンを揃える。
private struct HeaderIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    @ViewBuilder
    func applyingDrop(_ handler: (([NSItemProvider]) -> Bool)?) -> some View {
        if let handler {
            onDrop(of: [UTType.item], isTargeted: nil, perform: handler)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        BaseToolView(
            title: String(localized: "サンプルツール"),
            helpText: String(localized: "ここにツールの使い方の説明が入ります。")
        ) {
            EmptyStateView(
                systemImage: "doc.on.doc",
                title: String(localized: "ファイルをドラッグ＆ドロップ、\nまたはタップして選択してください"),
                actionTitle: String(localized: "ファイルを選択")
            ) {}
        } footer: {
            PrimaryButton(title: String(localized: "実行する"), systemImage: "play.fill", action: {})
        }
    }
}
