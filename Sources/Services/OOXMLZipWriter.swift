import Foundation

/// OOXML（docx/xlsx/pptx）パッケージ用の最小限のZIPライター。
/// 各エントリは無圧縮（stored）で書き込む。ZIP仕様上stored方式も正規の圧縮方式であり、
/// Word/Excel/PowerPointをはじめとする一般的な実装で問題なく読み込める。
enum OOXMLZipWriter {
    struct Entry {
        let path: String
        let data: Data
    }

    static func write(entries: [Entry]) -> Data {
        var output = Data()

        struct CentralRecord {
            let path: String
            let crc32: UInt32
            let size: UInt32
            let offset: UInt32
        }
        var centralRecords: [CentralRecord] = []

        for entry in entries {
            let nameData = Data(entry.path.utf8)
            let crc = crc32(of: entry.data)
            let offset = UInt32(output.count)

            var localHeader = Data()
            localHeader.appendLittleEndian(UInt32(0x0403_4b50))
            localHeader.appendLittleEndian(UInt16(20))
            localHeader.appendLittleEndian(UInt16(0))
            localHeader.appendLittleEndian(UInt16(0))
            localHeader.appendLittleEndian(UInt16(0))
            localHeader.appendLittleEndian(UInt16(0))
            localHeader.appendLittleEndian(crc)
            localHeader.appendLittleEndian(UInt32(entry.data.count))
            localHeader.appendLittleEndian(UInt32(entry.data.count))
            localHeader.appendLittleEndian(UInt16(nameData.count))
            localHeader.appendLittleEndian(UInt16(0))

            output.append(localHeader)
            output.append(nameData)
            output.append(entry.data)

            centralRecords.append(CentralRecord(path: entry.path, crc32: crc, size: UInt32(entry.data.count), offset: offset))
        }

        let centralDirectoryStart = UInt32(output.count)
        for record in centralRecords {
            let nameData = Data(record.path.utf8)
            var central = Data()
            central.appendLittleEndian(UInt32(0x0201_4b50))
            central.appendLittleEndian(UInt16(20))
            central.appendLittleEndian(UInt16(20))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(record.crc32)
            central.appendLittleEndian(record.size)
            central.appendLittleEndian(record.size)
            central.appendLittleEndian(UInt16(nameData.count))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt16(0))
            central.appendLittleEndian(UInt32(0))
            central.appendLittleEndian(record.offset)

            output.append(central)
            output.append(nameData)
        }
        let centralDirectorySize = UInt32(output.count) - centralDirectoryStart

        var end = Data()
        end.appendLittleEndian(UInt32(0x0605_4b50))
        end.appendLittleEndian(UInt16(0))
        end.appendLittleEndian(UInt16(0))
        end.appendLittleEndian(UInt16(centralRecords.count))
        end.appendLittleEndian(UInt16(centralRecords.count))
        end.appendLittleEndian(centralDirectorySize)
        end.appendLittleEndian(centralDirectoryStart)
        end.appendLittleEndian(UInt16(0))
        output.append(end)

        return output
    }

    private static func crc32(of data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}