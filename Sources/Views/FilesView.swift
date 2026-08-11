import SwiftUI

struct FilesView: View {
    @State private var viewModel = FilesViewModel()
    @State private var fileToShare: SavedFile?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.displayedFiles.isEmpty, !viewModel.isLoading {
                    EmptyStateView(
                        systemImage: "folder",
                        title: viewModel.searchText.isEmpty ? "保存されたPDFはまだありません" : "一致するファイルがありません",
                        message: viewModel.searchText.isEmpty ? "各ツールで作成したPDFがここに表示されます。" : nil
                    )
                } else {
                    List {
                        ForEach(viewModel.displayedFiles) { file in
                            Button {
                                fileToShare = file
                            } label: {
                                FileRow(file: file)
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            viewModel.delete(at: offsets)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .tabBarClearance()
            .withTopAdBanner()
            .navigationTitle("ファイル")
            .searchable(text: $viewModel.searchText, prompt: "ファイル名で検索")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("並び替え", selection: $viewModel.sortOption) {
                            ForEach(FilesViewModel.SortOption.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .task {
                await viewModel.loadFiles()
            }
            .refreshable {
                await viewModel.loadFiles()
            }
            .sheet(item: $fileToShare) { file in
                ModernSheet(title: "共有") {
                    ActivityView(activityItems: [file.url])
                }
            }
            .toast($viewModel.toast)
        }
    }
}

private struct FileRow: View {
    let file: SavedFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let pageCount = file.pageCount {
            parts.append("\(pageCount)ページ")
        }
        parts.append(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
        parts.append(file.modifiedDate.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " ・ ")
    }
}

#Preview {
    FilesView()
}
