import SwiftUI

struct FilesView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "folder",
                title: "ファイル一覧は準備中です"
            )
            .navigationTitle("ファイル")
        }
    }
}

#Preview {
    FilesView()
}
