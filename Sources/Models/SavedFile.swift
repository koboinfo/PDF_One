import Foundation

struct SavedFile: Identifiable, Hashable {
    let url: URL
    let sizeBytes: Int64
    let modifiedDate: Date
    let pageCount: Int?

    var id: URL { url }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }
}
