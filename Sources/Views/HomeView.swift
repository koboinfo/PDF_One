import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var isShowingPaywall = false
    @State private var isShowingSettings = false
    @State private var fileToShare: SavedFile?

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    NativeAdPlaceholderView()
                    quickActionsSection
                    recentFilesSection
                }
                .padding(.horizontal, LayoutConstants.screenHorizontalPadding)
                .padding(.top, 8)
            }
            .tabBarClearance()
            .withTopAdBanner()
            .background(AppBackground())
            .navigationTitle(String(localized: "ホーム"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 18) {
                        if !subscriptionManager.isProUser {
                            Button {
                                isShowingPaywall = true
                            } label: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.orange)
                            }
                            .accessibilityLabel(String(localized: "Proにアップグレード"))
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "設定"))
                    }
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                self.destination(for: destination)
            }
            .task {
                await viewModel.loadRecentFiles()
            }
            .refreshable {
                await viewModel.loadRecentFiles()
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(item: $fileToShare) { file in
            ModernSheet(title: String(localized: "共有")) {
                ActivityView(activityItems: [file.url])
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "クイックアクション"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            QuickActionGrid(actions: viewModel.quickActions) { action in
                viewModel.path.append(action.destination)
            }
        }
    }

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "最近使用したファイル"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.recentFiles.isEmpty {
                EmptyStateView(
                    systemImage: "folder",
                    title: String(localized: "保存されたPDFはまだありません"),
                    message: String(localized: "各ツールで作成したPDFがここに表示されます。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentFiles) { file in
                        Button {
                            fileToShare = file
                        } label: {
                            RecentFileRow(file: file)
                        }
                        .tint(.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for destination: HomeDestination) -> some View {
        switch destination {
        case .merge:
            MergeView()
        case .imageToPDF:
            ImageToPDFView()
        case .compress:
            CompressView()
        case .scanner:
            ScannerView()
        }
    }
}

private struct RecentFileRow: View {
    let file: SavedFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
    }

    private var subtitle: String {
        var parts: [String] = []
        if let pageCount = file.pageCount {
            parts.append(String(localized: "\(pageCount)ページ"))
        }
        parts.append(file.modifiedDate.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " ・ ")
    }
}

#Preview(String(localized: "通常時（無料ユーザー）")) {
    HomeView()
        .environment(SubscriptionManager.preview(isProUser: false))
}

#Preview(String(localized: "Proユーザー時")) {
    HomeView()
        .environment(SubscriptionManager.preview(isProUser: true))
}
