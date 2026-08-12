import SwiftUI

struct MergeFileListView: View {
    @Bindable var viewModel: MergeViewModel
    @Binding var isShowingShareSheet: Bool

    var body: some View {
        List {
            Section(String(localized: "選択中のファイル（\(viewModel.selectedURLs.count)）")) {
                ForEach(viewModel.selectedURLs, id: \.self) { url in
                    Label(url.lastPathComponent, systemImage: "doc.text")
                        .lineLimit(1)
                }
                .onDelete { indexSet in
                    viewModel.selectedURLs.remove(atOffsets: indexSet)
                }
                .onMove { source, destination in
                    viewModel.selectedURLs.move(fromOffsets: source, toOffset: destination)
                }
            }

            if let outputURL = viewModel.outputURL {
                Section(String(localized: "結合結果")) {
                    PDFPreviewView(url: outputURL)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label(String(localized: "共有する"), systemImage: "square.and.arrow.up")
                    }
                    .tint(ToolIconType.merge.tint)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}