import SwiftUI

struct ImageToPDFListView: View {
    @Bindable var viewModel: ImageToPDFViewModel
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(editMode.isEditing ? String(localized: "完了") : String(localized: "編集")) {
                    editMode = editMode.isEditing ? .inactive : .active
                }
                .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            List {
                Section(String(localized: "選択中の画像（\(viewModel.images.count)）")) {
                    ForEach(viewModel.images) { image in
                        ImageThumbnailRow(image: image)
                    }
                    .onDelete { indexSet in
                        viewModel.images.remove(atOffsets: indexSet)
                    }
                    .onMove { source, destination in
                        viewModel.images.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
        }
    }
}
