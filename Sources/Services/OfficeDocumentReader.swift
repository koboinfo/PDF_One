import Foundation

/// docx/xlsx/pptxパッケージ内のXMLパーツから、PDF描画に必要な最小限の内容（段落テキスト・セル・シェイプ）を読み取る。
/// XMLの走査には標準の`XMLParser`（SAXスタイル）を使い、要素名は名前空間を解決したローカル名で照合することで、
/// アプリごとに異なるプレフィックス表記（w:, a:等）の違いを吸収する。
enum OfficeDocumentReader {
    enum ReadError: Error {
        case malformedXML
    }

    /// docxの`word/document.xml`を段落単位のプレーンテキスト配列に変換する。
    static func readDocxParagraphs(from docxData: Data) throws -> [String] {
        let documentXML = try OOXMLZipReader.extract(from: docxData, path: "word/document.xml")
        let extractor = DocxTextExtractor()
        let parser = XMLParser(data: documentXML)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw ReadError.malformedXML
        }
        return extractor.paragraphs
    }

    private final class DocxTextExtractor: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [String] = []
        private var currentParagraph = ""
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
                currentParagraph = ""
            case "t":
                isInText = true
            case "tab":
                currentParagraph += "\t"
            case "br", "cr":
                currentParagraph += "\n"
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInText else { return }
            currentParagraph += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "t":
                isInText = false
            case "p":
                paragraphs.append(currentParagraph)
            default:
                break
            }
        }
    }
}
