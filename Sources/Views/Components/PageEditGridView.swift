import SwiftUI
import UniformTypeIdentifiers

struct PageEditGridView: View {
    @Bindable var viewModel: PageEditViewModel
    @State private var draggingItemID: PDFPageEditItem.ID?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(viewModel.pageItems.enumerated()), id: \.element.id) { index, item in
                    PageThumbnailCell(
                        item: item,
                        displayIndex: index + 1,
                        onRotate: { viewModel.rotatePage(id: item.id) },
                        onDelete: { viewModel.deletePage(id: item.id) },
                        onToggleSelect: { viewModel.toggleSelection(id: item.id) }
                    )
                    .opacity(draggingItemID == item.id ? 0.4 : 1)
                    .scaleEffect(draggingItemID == item.id ? 0.92 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggingItemID)
                    .onDrag {
                        draggingItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: PageDropDelegate(
                            targetItemID: item.id,
                            viewModel: viewModel,
                            draggingItemID: $draggingItemID
                        )
                    )
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.pageItems.map(\.id))
            .padding()
        }
    }
}

private struct PageDropDelegate: DropDelegate {
    let targetItemID: PDFPageEditItem.ID
    let viewModel: PageEditViewModel
    @Binding var draggingItemID: PDFPageEditItem.ID?

    func dropEntered(info: DropInfo) {
        guard let draggingItemID, draggingItemID != targetItemID,
              let fromIndex = viewModel.pageItems.firstIndex(where: { $0.id == draggingItemID }),
              let toIndex = viewModel.pageItems.firstIndex(where: { $0.id == targetItemID }) else {
            return
        }

        viewModel.pageItems.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }
}
