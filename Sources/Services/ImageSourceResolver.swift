import Foundation

enum ImageSourceResolverError: Error {
    case downloadFailed(underlying: Error)
}

/// `AppImage` が指すローカル/リモート画像を、PDF生成など既存のURLベースAPIが扱えるローカルファイルURLに解決する。
/// Cloudinary等から返るリモートURLは一時ディレクトリにダウンロードしてローカル化する。
protocol ImageSourceResolving {
    func resolveLocalURL(for image: AppImage) async throws -> URL
}

struct ImageSourceResolver: ImageSourceResolving {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func resolveLocalURL(for image: AppImage) async throws -> URL {
        switch image.source {
        case .local(let url):
            return url
        case .remote(let url):
            do {
                let (data, _) = try await urlSession.data(from: url)
                let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                let destinationURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)
                try data.write(to: destinationURL, options: .atomic)
                return destinationURL
            } catch {
                throw ImageSourceResolverError.downloadFailed(underlying: error)
            }
        }
    }
}
