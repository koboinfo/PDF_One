import Compression
import Foundation

/// OOXML（docx/xlsx/pptx）パッケージ読み込み用の最小限のZIPリーダー。
/// 実際のWord/Excel/PowerPoint/Numbers/Keynote/Google系エクスポートが使うdeflate圧縮に対応する。
/// iOSにはZIPを直接展開する公開APIが存在しないため、中央ディレクトリを解析し、
/// エントリごとにApple `Compression`フレームワーク（生deflateストリーム = ZIPのdeflate方式と互換）で展開する。
enum OOXMLZipReader {
    enum ZipError: Error {
        case invalidArchive
        case entryNotFound(String)
        case decompressionFailed(String)
    }

    private struct CentralDirectoryEntry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    static func extract(from data: Data, path: String) throws -> Data {
        let entries = try readCentralDirectory(data)
        guard let entry = entries.first(where: { $0.path == path }) else {
            throw ZipError.entryNotFound(path)
        }
        return try extractEntry(entry, from: data)
    }

    /// 指定パスに合致する（前方一致）エントリすべてを`path`昇順で返す。スライド一覧の列挙などに使う。
    static func extractAll(from data: Data, pathPrefix: String) throws -> [(path: String, data: Data)] {
        let entries = try readCentralDirectory(data)
            .filter { $0.path.hasPrefix(pathPrefix) }
            .sorted { $0.path < $1.path }
        return try entries.map { ($0.path, try extractEntry($0, from: data)) }
    }

    private static func extractEntry(_ entry: CentralDirectoryEntry, from data: Data) throws -> Data {
        guard let localHeaderData = subdata(data, at: entry.localHeaderOffset, length: 30),
              readUInt32LE(localHeaderData, at: 0) == 0x0403_4b50 else {
            throw ZipError.invalidArchive
        }
        let nameLength = Int(readUInt16LE(localHeaderData, at: 26))
        let extraLength = Int(readUInt16LE(localHeaderData, at: 28))
        let dataStart = entry.localHeaderOffset + 30 + nameLength + extraLength

        guard let compressedData = subdata(data, at: dataStart, length: entry.compressedSize) else {
            throw ZipError.invalidArchive
        }

        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            return try inflate(compressedData, uncompressedSize: entry.uncompressedSize, entryName: entry.path)
        default:
            throw ZipError.decompressionFailed("unsupported compression method \(entry.compressionMethod) for \(entry.path)")
        }
    }

    private static func inflate(_ compressedData: Data, uncompressedSize: Int, entryName: String) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }

        var destination = [UInt8](repeating: 0, count: uncompressedSize)
        let decodedCount = destination.withUnsafeMutableBufferPointer { destBuffer -> Int in
            compressedData.withUnsafeBytes { srcRawBuffer -> Int in
                guard let srcBase = srcRawBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let destBase = destBuffer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    destBase, uncompressedSize,
                    srcBase, compressedData.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }

        guard decodedCount == uncompressedSize else {
            throw ZipError.decompressionFailed(entryName)
        }
        return Data(destination)
    }

    private static func readCentralDirectory(_ data: Data) throws -> [CentralDirectoryEntry] {
        guard let eocdOffset = findEndOfCentralDirectory(data) else {
            throw ZipError.invalidArchive
        }
        guard let eocd = subdata(data, at: eocdOffset, length: 22) else {
            throw ZipError.invalidArchive
        }

        let entryCount = Int(readUInt16LE(eocd, at: 10))
        let centralDirectoryOffset = Int(readUInt32LE(eocd, at: 16))

        var entries: [CentralDirectoryEntry] = []
        var cursor = centralDirectoryOffset

        for _ in 0..<entryCount {
            guard let header = subdata(data, at: cursor, length: 46),
                  readUInt32LE(header, at: 0) == 0x0201_4b50 else {
                throw ZipError.invalidArchive
            }

            let compressionMethod = readUInt16LE(header, at: 10)
            let compressedSize = Int(readUInt32LE(header, at: 20))
            let uncompressedSize = Int(readUInt32LE(header, at: 24))
            let nameLength = Int(readUInt16LE(header, at: 28))
            let extraLength = Int(readUInt16LE(header, at: 30))
            let commentLength = Int(readUInt16LE(header, at: 32))
            let localHeaderOffset = Int(readUInt32LE(header, at: 42))

            guard let nameData = subdata(data, at: cursor + 46, length: nameLength),
                  let path = String(data: nameData, encoding: .utf8) else {
                throw ZipError.invalidArchive
            }

            entries.append(CentralDirectoryEntry(
                path: path,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))

            cursor += 46 + nameLength + extraLength + commentLength
        }

        return entries
    }

    /// ファイル末尾からEOCDシグネチャ(`PK\x05\x06`)を探索する。コメント欄は最大65535バイトのため、
    /// 探索範囲は末尾約64KBに限定する。
    private static func findEndOfCentralDirectory(_ data: Data) -> Int? {
        let signature: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        let searchWindow = min(data.count, 65_557)
        let searchStart = data.count - searchWindow

        var offset = data.count - 22
        while offset >= searchStart {
            if data[data.startIndex + offset] == signature[0],
               data[data.startIndex + offset + 1] == signature[1],
               data[data.startIndex + offset + 2] == signature[2],
               data[data.startIndex + offset + 3] == signature[3] {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func subdata(_ data: Data, at offset: Int, length: Int) -> Data? {
        guard offset >= 0, length >= 0, offset + length <= data.count else { return nil }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + length))
    }

    private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }
}
