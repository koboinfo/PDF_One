import SwiftUI

struct PDFToJPGGridView: View {
    let pages: [PDFImagePage]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(pages) { page in
                    VStack(spacing: 6) {
                        Image(uiImage: page.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 140)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("\(page.pageNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 100)
                }
            }
            .padding()
        }
    }
}
