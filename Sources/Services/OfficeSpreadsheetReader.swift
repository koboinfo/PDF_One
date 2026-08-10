import Foundation

/// xlsxパッケージからシート単位のセル値グリッドを読み取る。
/// 数式結果は`<v>`要素の値（キャッシュ済み計算結果）をそのまま使い、数式そのものは再評価しない。
enum OfficeSpreadsheetReader {
    struct Sheet {
        let name: String
        let rows: [[String]]
    }

    static func readSheets(from xlsxData: Data) throws -> [Sheet] {
        let sharedStrings = (try? readSharedStrings(from: xlsxData)) ?? []
        let sheetRefs = try readSheetRefs(from: xlsxData)

        var sheets: [Sheet] = []
        for ref in sheetRefs {
            guard let sheetXML = try? OOXMLZipReader.extract(from: xlsxData, path: ref.path) else { continue }
            let extractor = SheetRowExtractor(sharedStrings: sharedStrings)
            let parser = XMLParser(data: sheetXML)
            parser.shouldProcessNamespaces = true
            parser.delegate = extractor
            guard parser.parse() else { continue }
            sheets.append(Sheet(name: ref.name, rows: extractor.rows))
        }

        guard !sheets.isEmpty else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }
        return sheets
    }

    // MARK: - workbook.xml / rels からシートのパス一覧を解決する

    private struct SheetRef {
        let name: String
        let path: String
    }

    private static func readSheetRefs(from xlsxData: Data) throws -> [SheetRef] {
        let workbookXML = try OOXMLZipReader.extract(from: xlsxData, path: "xl/workbook.xml")
        let sheetExtractor = WorkbookSheetExtractor()
        let sheetParser = XMLParser(data: workbookXML)
        sheetParser.shouldProcessNamespaces = true
        sheetParser.delegate = sheetExtractor
        guard sheetParser.parse() else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }

        let relationships = (try? OOXMLRelationships.read(from: xlsxData, path: "xl/_rels/workbook.xml.rels")) ?? [:]

        return sheetExtractor.sheets.compactMap { entry in
            guard let target = relationships[entry.relationshipId] else { return nil }
            return SheetRef(name: entry.name, path: OOXMLRelationships.resolvePath(base: "xl/", target: target))
        }
    }

    private final class WorkbookSheetExtractor: NSObject, XMLParserDelegate {
        private(set) var sheets: [(name: String, relationshipId: String)] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard elementName == "sheet" else { return }
            guard let name = attributeDict["name"],
                  let relationshipId = attributeDict["r:id"] ?? attributeDict["id"] else { return }
            sheets.append((name: name, relationshipId: relationshipId))
        }
    }

    // MARK: - sharedStrings.xml

    private static func readSharedStrings(from xlsxData: Data) throws -> [String] {
        let data = try OOXMLZipReader.extract(from: xlsxData, path: "xl/sharedStrings.xml")
        let extractor = SharedStringsExtractor()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }
        return extractor.strings
    }

    private final class SharedStringsExtractor: NSObject, XMLParserDelegate {
        private(set) var strings: [String] = []
        private var currentString = ""
        private var isInText = false

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "si":
                currentString = ""
            case "t":
                isInText = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInText else { return }
            currentString += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "t":
                isInText = false
            case "si":
                strings.append(currentString)
            default:
                break
            }
        }
    }

    // MARK: - worksheets/sheetN.xml

    private final class SheetRowExtractor: NSObject, XMLParserDelegate {
        private let sharedStrings: [String]
        private(set) var rows: [[String]] = []

        private var currentRowValues: [Int: String] = [:]
        private var maxColumnIndexInRow = -1
        private var nextImplicitColumnIndex = 0
        private var currentCellColumnIndex: Int?
        private var currentCellType: String?
        private var isInValue = false
        private var isInInlineText = false
        private var valueBuffer = ""

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "row":
                currentRowValues = [:]
                maxColumnIndexInRow = -1
                nextImplicitColumnIndex = 0
            case "c":
                currentCellType = attributeDict["t"]
                currentCellColumnIndex = attributeDict["r"].flatMap(Self.columnIndex(fromCellReference:)) ?? nextImplicitColumnIndex
            case "v":
                isInValue = true
                valueBuffer = ""
            case "t":
                if currentCellType == "inlineStr" {
                    isInInlineText = true
                    valueBuffer = ""
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInValue || isInInlineText else { return }
            valueBuffer += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "v":
                isInValue = false
                applyCellValue(valueBuffer)
            case "t":
                if isInInlineText {
                    isInInlineText = false
                    applyCellValue(valueBuffer)
                }
            case "c":
                if let columnIndex = currentCellColumnIndex {
                    nextImplicitColumnIndex = columnIndex + 1
                }
                currentCellColumnIndex = nil
                currentCellType = nil
            case "row":
                let columnCount = maxColumnIndexInRow + 1
                guard columnCount > 0 else {
                    rows.append([])
                    return
                }
                var rowValues = [String](repeating: "", count: columnCount)
                for (index, value) in currentRowValues {
                    rowValues[index] = value
                }
                rows.append(rowValues)
            default:
                break
            }
        }

        private func applyCellValue(_ raw: String) {
            guard let columnIndex = currentCellColumnIndex else { return }
            let resolved: String
            if currentCellType == "s", let sharedIndex = Int(raw), sharedStrings.indices.contains(sharedIndex) {
                resolved = sharedStrings[sharedIndex]
            } else {
                resolved = raw
            }
            currentRowValues[columnIndex] = resolved
            maxColumnIndexInRow = max(maxColumnIndexInRow, columnIndex)
        }

        /// "C5"のようなセル参照から列部分（"C"）だけを解釈し0始まりの列番号を返す。
        private static func columnIndex(fromCellReference ref: String) -> Int? {
            var index = 0
            var found = false
            for scalar in ref.unicodeScalars {
                guard scalar.value >= 65, scalar.value <= 90 else { break }
                found = true
                index = index * 26 + Int(scalar.value - 64)
            }
            guard found else { return nil }
            return index - 1
        }
    }
}
