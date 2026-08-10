import Foundation

/// OOXMLの`.rels`パーツ（`Id -> Target`のリレーションシップ定義）を読み取る共通ヘルパー。
/// workbook.xml.rels、presentation.xml.rels、slideN.xml.rels等、形式はすべて共通のため一箇所にまとめる。
enum OOXMLRelationships {
    static func read(from packageData: Data, path: String) throws -> [String: String] {
        let data = try OOXMLZipReader.extract(from: packageData, path: path)
        let extractor = RelationshipExtractor()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }
        return extractor.relationships
    }

    /// `.rels`ファイル内の`Target`（多くは`../media/image1.png`のような相対パス）を、
    /// パッケージルートからの絶対パスへ解決する。`base`は`.rels`が置かれているディレクトリの親（例: "xl/"、"ppt/slides/"）。
    static func resolvePath(base: String, target: String) -> String {
        if target.hasPrefix("/") {
            return String(target.dropFirst())
        }

        var baseComponents = base.split(separator: "/").map(String.init)
        for component in target.split(separator: "/") {
            if component == ".." {
                if !baseComponents.isEmpty { baseComponents.removeLast() }
            } else if component != "." {
                baseComponents.append(String(component))
            }
        }
        return baseComponents.joined(separator: "/")
    }

    private final class RelationshipExtractor: NSObject, XMLParserDelegate {
        private(set) var relationships: [String: String] = [:]

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard elementName == "Relationship",
                  let id = attributeDict["Id"],
                  let target = attributeDict["Target"] else { return }
            relationships[id] = target
        }
    }
}
