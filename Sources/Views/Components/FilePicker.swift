import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// BaseToolViewを使う各画面から共通で呼び出す、PDF/画像選択の種別。
enum FilePickerKind {
    /// `UIDocumentPickerViewController` によるPDF選択。
    case pdf(allowsMultipleSelection: Bool = true)
    /// `PhotosPicker` による画像選択。選択した画像は一時JPEGファイルとして書き出される。
    case image
}

/// PDF選択(UIDocumentPicker)・画像選択(PhotosPicker)を共通のURL配列コールバックへ集約するモディファイア。
private struct FilePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let kind: FilePickerKind
    let onPickURLs: ([URL]) -> Void

    @State private var pickedDocumentURLs: [URL] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []

    @ViewBuilder
    func body(content: Content) -> some View {
        switch kind {
        case .pdf(let allowsMultipleSelection):
            content
                .sheet(isPresented: $isPresented) {
                    DocumentPickerView(
                        selectedURLs: $pickedDocumentURLs,
                        allowsMultipleSelection: allowsMultipleSelection
                    )
                }
                .onChange(of: pickedDocumentURLs) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    onPickURLs(newValue)
                    pickedDocumentURLs = []
                }

        case .image:
            content
                .photosPicker(isPresented: $isPresented, selection: $photoPickerItems, matching: .images)
                .onChange(of: photoPickerItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task {
                        let urls = await Self.writeTempJPEGs(from: newItems)
                        photoPickerItems = []
                        if !urls.isEmpty { onPickURLs(urls) }
                    }
                }
        }
    }

    private static func writeTempJPEGs(from items: [PhotosPickerItem]) async -> [URL] {
        var urls: [URL] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            guard (try? data.write(to: destinationURL, options: .atomic)) != nil else { continue }
            urls.append(destinationURL)
        }
        return urls
    }
}

extension View {
    /// `kind` に応じてPDF(UIDocumentPicker)または画像(PhotosPicker)の選択UIを提示し、選択結果をローカルURL配列として受け取る。
    func filePicker(
        _ kind: FilePickerKind,
        isPresented: Binding<Bool>,
        onPick: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(FilePickerModifier(isPresented: isPresented, kind: kind, onPickURLs: onPick))
    }
}