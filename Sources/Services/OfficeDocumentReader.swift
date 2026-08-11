import CoreGraphics
import Foundation

/// docx/xlsx/pptxパッケージ内のXMLパーツから、PDF描画に必要な最小限の内容（段落テキスト・セル・シェイプ）を読み取る。
/// XMLの走査には標準の`XMLParser`（SAXスタイル）を使い、要素名は名前空間を解決したローカル名で照合することで、
/// アプリごとに異なるプレフィックス表記（w:, a:等）の違いを吸収する。
enum OfficeDocumentReader {
    enum ReadError: Error {
        case malformedXML
    }

    enum DocxAlignment: Equatable {
        case left
        case center
        case right
        case justify
    }

    /// 1つのラン（同一書式が続く区間）のテキストと文字書式。
    struct DocxRun {
        let text: String
        let bold: Bool
        let italic: Bool
        /// ポイント単位のフォントサイズ。`w:sz`（半ポイント単位）から換算。未指定の場合は`nil`。
        let fontSizePt: CGFloat?
    }

    struct DocxParagraph {
        let runs: [DocxRun]
        let alignment: DocxAlignment
    }

    /// 表の1セル。セル内には通常1つ以上の段落が入る。
    struct DocxTableCell {
        let paragraphs: [DocxParagraph]
    }

    /// `w:tbl`（表）を行×セルのグリッドとして表す。
    struct DocxTable {
        let rows: [[DocxTableCell]]
    }

    /// 本文を構成する要素。段落と表が任意の順序で混在する。
    enum DocxBlock {
        case paragraph(DocxParagraph)
        case table(DocxTable)
    }

    /// docxの`word/document.xml`を、段落と表（`w:tbl`）を区別したブロック列に変換する。
    /// セル内に入れ子になった表（まれなケース）は、セルのテキストとして親セルへ平坦化する
    /// （入れ子構造の再現は行わないが、テキスト内容自体は失わない）。
    static func readDocxBlocks(from docxData: Data) throws -> [DocxBlock] {
        let documentXML = try OOXMLZipReader.extract(from: docxData, path: "word/document.xml")
        let extractor = DocxBlockExtractor()
        let parser = XMLParser(data: documentXML)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw ReadError.malformedXML
        }
        return extractor.blocks
    }

    /// docxの`word/document.xml`を段落単位のプレーンテキスト配列に変換する。
    static func readDocxParagraphs(from docxData: Data) throws -> [String] {
        try readDocxStructuredParagraphs(from: docxData).map { paragraph in
            paragraph.runs.map(\.text).joined()
        }
    }

    /// docxの`word/document.xml`を、ラン単位の文字書式（太字・斜体・フォントサイズ）と
    /// 段落の配置（左揃え・中央揃え等）を保持した構造体の配列に変換する。
    static func readDocxStructuredParagraphs(from docxData: Data) throws -> [DocxParagraph] {
        let documentXML = try OOXMLZipReader.extract(from: docxData, path: "word/document.xml")
        let extractor = DocxParagraphExtractor()
        let parser = XMLParser(data: documentXML)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw ReadError.malformedXML
        }
        return extractor.paragraphs
    }

    private final class DocxParagraphExtractor: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [DocxParagraph] = []

        private var currentRuns: [DocxRun] = []
        private var currentAlignment: DocxAlignment = .left

        private var currentRunText = ""
        private var currentRunBold = false
        private var currentRunItalic = false
        private var currentRunFontSizePt: CGFloat?

        private var isInText = false

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "p":
                currentRuns = []
                currentAlignment = .left
            case "jc":
                currentAlignment = Self.alignment(from: attributeDict["w:val"] ?? attributeDict["val"])
            case "r":
                currentRunText = ""
                currentRunBold = false
                currentRunItalic = false
                currentRunFontSizePt = nil
            case "b":
                currentRunBold = Self.isFlagEnabled(attributeDict["w:val"] ?? attributeDict["val"])
            case "i":
                currentRunItalic = Self.isFlagEnabled(attributeDict["w:val"] ?? attributeDict["val"])
            case "sz":
                if let raw = attributeDict["w:val"] ?? attributeDict["val"], let halfPoints = Double(raw) {
                    currentRunFontSizePt = CGFloat(halfPoints / 2)
                }
            case "t":
                isInText = true
            case "tab":
                currentRunText += "\t"
            case "br", "cr":
                currentRunText += "\n"
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInText else { return }
            currentRunText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "t":
                isInText = false
            case "r":
                currentRuns.append(DocxRun(
                    text: currentRunText,
                    bold: currentRunBold,
                    italic: currentRunItalic,
                    fontSizePt: currentRunFontSizePt
                ))
            case "p":
                paragraphs.append(DocxParagraph(runs: currentRuns, alignment: currentAlignment))
            default:
                break
            }
        }

        /// `w:b`/`w:i`は要素が存在するだけで有効（値省略時はtrue扱い）。`w:val="0"/"false"`の場合のみ無効化される。
        private static func isFlagEnabled(_ rawValue: String?) -> Bool {
            guard let rawValue else { return true }
            return !(rawValue == "0" || rawValue.lowercased() == "false")
        }

        private static func alignment(from rawValue: String?) -> DocxAlignment {
            switch rawValue {
            case "center": return .center
            case "right", "end": return .right
            case "both", "distribute": return .justify
            default: return .left
            }
        }
    }

    /// `w:tbl`/`w:tr`/`w:tc`のネストをスタックで追跡しつつ、段落（`w:p`）を現在のコンテキスト
    /// （本文直下 or 表セル内）に応じて振り分ける。表がセル内にネストする場合（まれ）は、
    /// 内側の表の各セルのテキストを親セルへ平坦化して取り込み、データを失わずに構造だけ簡略化する。
    private final class DocxBlockExtractor: NSObject, XMLParserDelegate {
        private(set) var blocks: [DocxBlock] = []

        private struct TableBuilder {
            var rows: [[DocxTableCell]] = []
            var currentRowCells: [DocxTableCell] = []
        }

        private var tableStack: [TableBuilder] = []
        private var cellParagraphStack: [[DocxParagraph]] = []

        private var currentRuns: [DocxRun] = []
        private var currentAlignment: DocxAlignment = .left
        private var currentRunText = ""
        private var currentRunBold = false
        private var currentRunItalic = false
        private var currentRunFontSizePt: CGFloat?
        private var isInText = false

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "tbl":
                tableStack.append(TableBuilder())
            case "tc":
                cellParagraphStack.append([])
            case "p":
                currentRuns = []
                currentAlignment = .left
            case "jc":
                currentAlignment = Self.alignment(from: attributeDict["w:val"] ?? attributeDict["val"])
            case "r":
                currentRunText = ""
                currentRunBold = false
                currentRunItalic = false
                currentRunFontSizePt = nil
            case "b":
                currentRunBold = Self.isFlagEnabled(attributeDict["w:val"] ?? attributeDict["val"])
            case "i":
                currentRunItalic = Self.isFlagEnabled(attributeDict["w:val"] ?? attributeDict["val"])
            case "sz":
                if let raw = attributeDict["w:val"] ?? attributeDict["val"], let halfPoints = Double(raw) {
                    currentRunFontSizePt = CGFloat(halfPoints / 2)
                }
            case "t":
                isInText = true
            case "tab":
                currentRunText += "\t"
            case "br", "cr":
                currentRunText += "\n"
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInText else { return }
            currentRunText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "t":
                isInText = false
            case "r":
                currentRuns.append(DocxRun(
                    text: currentRunText,
                    bold: currentRunBold,
                    italic: currentRunItalic,
                    fontSizePt: currentRunFontSizePt
                ))
            case "p":
                let paragraph = DocxParagraph(runs: currentRuns, alignment: currentAlignment)
                if !cellParagraphStack.isEmpty {
                    cellParagraphStack[cellParagraphStack.count - 1].append(paragraph)
                } else {
                    blocks.append(.paragraph(paragraph))
                }
            case "tc":
                let paragraphs = cellParagraphStack.popLast() ?? []
                let cell = DocxTableCell(paragraphs: paragraphs)
                if !tableStack.isEmpty {
                    tableStack[tableStack.count - 1].currentRowCells.append(cell)
                }
            case "tr":
                guard !tableStack.isEmpty else { break }
                let cells = tableStack[tableStack.count - 1].currentRowCells
                tableStack[tableStack.count - 1].currentRowCells = []
                tableStack[tableStack.count - 1].rows.append(cells)
            case "tbl":
                guard let finished = tableStack.popLast() else { break }
                if !cellParagraphStack.isEmpty {
                    let flattened = finished.rows.flatMap { row in
                        row.map { cell in
                            DocxParagraph(runs: cell.paragraphs.flatMap(\.runs), alignment: .left)
                        }
                    }
                    cellParagraphStack[cellParagraphStack.count - 1].append(contentsOf: flattened)
                } else {
                    blocks.append(.table(DocxTable(rows: finished.rows)))
                }
            default:
                break
            }
        }

        private static func isFlagEnabled(_ rawValue: String?) -> Bool {
            guard let rawValue else { return true }
            return !(rawValue == "0" || rawValue.lowercased() == "false")
        }

        private static func alignment(from rawValue: String?) -> DocxAlignment {
            switch rawValue {
            case "center": return .center
            case "right", "end": return .right
            case "both", "distribute": return .justify
            default: return .left
            }
        }
    }
}
