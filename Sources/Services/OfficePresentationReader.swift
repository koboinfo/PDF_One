import CoreGraphics
import Foundation

/// pptxパッケージからスライド1枚ごとのシェイプ（テキストボックス・画像）と、その配置（EMU単位）を読み取る。
/// SmartArt・表・グラフ・アニメーション等の高度な要素は対象外（テキストと画像の位置関係のみ再現する）。
enum OfficePresentationReader {
    struct Slide {
        let elements: [Element]
    }

    /// 1つのラン（同一書式が続く区間）のテキストと文字書式。
    struct Run {
        let text: String
        let bold: Bool
        let italic: Bool
        /// ポイント単位のフォントサイズ。`a:rPr sz`（百分の一ポイント単位）から換算。未指定の場合は`nil`。
        let fontSizePt: CGFloat?
    }

    enum Element {
        case text(paragraphs: [[Run]], frameEMU: CGRect)
        case image(data: Data, frameEMU: CGRect)
    }

    /// スライドごとのXML解析・画像抽出は互いに独立しているため、スライド枚数が多いプレゼンテーション
    /// （大容量ファイル）ほど`TaskGroup`による並列解析の効果が大きい。各子タスクは`slideRelationshipIds`の
    /// インデックスを持ち回し、完了順に関わらず元のスライド順を復元する。
    static func readSlides(from pptxData: Data) async throws -> (slideSizeEMU: CGSize, slides: [Slide]) {
        let presentationXML = try OOXMLZipReader.extract(from: pptxData, path: "ppt/presentation.xml")
        let presentationExtractor = PresentationExtractor()
        let presentationParser = XMLParser(data: presentationXML)
        presentationParser.shouldProcessNamespaces = true
        presentationParser.delegate = presentationExtractor
        guard presentationParser.parse(), let slideSize = presentationExtractor.slideSizeEMU else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }

        let presentationRels = (try? OOXMLRelationships.read(from: pptxData, path: "ppt/_rels/presentation.xml.rels")) ?? [:]

        let indexedSlides: [(index: Int, slide: Slide)] = await withTaskGroup(of: (index: Int, slide: Slide)?.self) { group in
            for (index, relationshipId) in presentationExtractor.slideRelationshipIds.enumerated() {
                guard let target = presentationRels[relationshipId] else { continue }
                let slidePath = OOXMLRelationships.resolvePath(base: "ppt/", target: target)
                group.addTask {
                    guard let slide = try? readSlide(from: pptxData, slidePath: slidePath) else { return nil }
                    return (index, slide)
                }
            }

            var results: [(index: Int, slide: Slide)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }

        let slides = indexedSlides.sorted { $0.index < $1.index }.map(\.slide)
        guard !slides.isEmpty else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }
        return (slideSize, slides)
    }

    private static func readSlide(from pptxData: Data, slidePath: String) throws -> Slide {
        let slideXML = try OOXMLZipReader.extract(from: pptxData, path: slidePath)
        let extractor = SlideShapeExtractor()
        let parser = XMLParser(data: slideXML)
        parser.shouldProcessNamespaces = true
        parser.delegate = extractor
        guard parser.parse() else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }

        let slideDirectory = (slidePath as NSString).deletingLastPathComponent
        let slideFileName = (slidePath as NSString).lastPathComponent
        let slideRelsPath = "\(slideDirectory)/_rels/\(slideFileName).rels"
        let slideRels = (try? OOXMLRelationships.read(from: pptxData, path: slideRelsPath)) ?? [:]

        let elements: [Element] = extractor.shapes.compactMap { shape in
            switch shape {
            case .text(let paragraphs, let frame):
                return Element.text(paragraphs: paragraphs, frameEMU: frame)
            case .image(let relationshipId, let frame):
                guard let target = slideRels[relationshipId],
                      let imageData = try? OOXMLZipReader.extract(
                          from: pptxData,
                          path: OOXMLRelationships.resolvePath(base: slideDirectory + "/", target: target)
                      ) else { return nil }
                return .image(data: imageData, frameEMU: frame)
            }
        }

        return Slide(elements: elements)
    }

    // MARK: - presentation.xml

    private final class PresentationExtractor: NSObject, XMLParserDelegate {
        private(set) var slideSizeEMU: CGSize?
        private(set) var slideRelationshipIds: [String] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "sldSz":
                guard let cx = attributeDict["cx"].flatMap(Double.init),
                      let cy = attributeDict["cy"].flatMap(Double.init) else { return }
                slideSizeEMU = CGSize(width: cx, height: cy)
            case "sldId":
                guard let relationshipId = attributeDict["r:id"] ?? attributeDict["id"] else { return }
                slideRelationshipIds.append(relationshipId)
            default:
                break
            }
        }
    }

    // MARK: - slideN.xml

    private enum RawShape {
        case text(paragraphs: [[Run]], frameEMU: CGRect)
        case image(relationshipId: String, frameEMU: CGRect)
    }

    private final class SlideShapeExtractor: NSObject, XMLParserDelegate {
        private(set) var shapes: [RawShape] = []

        private enum ShapeKind { case text, picture }

        private var currentShapeKind: ShapeKind?
        private var currentOffsetX: Double?
        private var currentOffsetY: Double?
        private var currentExtentCX: Double?
        private var currentExtentCY: Double?
        private var currentEmbedRelationshipId: String?
        private var currentParagraphs: [[Run]] = []
        private var currentRuns: [Run] = []
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
            case "sp":
                currentShapeKind = .text
                resetShapeState()
            case "pic":
                currentShapeKind = .picture
                resetShapeState()
            case "off":
                currentOffsetX = attributeDict["x"].flatMap(Double.init)
                currentOffsetY = attributeDict["y"].flatMap(Double.init)
            case "ext":
                currentExtentCX = attributeDict["cx"].flatMap(Double.init)
                currentExtentCY = attributeDict["cy"].flatMap(Double.init)
            case "blip":
                currentEmbedRelationshipId = attributeDict["r:embed"] ?? attributeDict["embed"]
            case "p":
                if currentShapeKind == .text { currentRuns = [] }
            case "r":
                if currentShapeKind == .text {
                    currentRunText = ""
                    currentRunBold = false
                    currentRunItalic = false
                    currentRunFontSizePt = nil
                }
            case "rPr":
                if currentShapeKind == .text {
                    if let b = attributeDict["b"] { currentRunBold = (b == "1" || b.lowercased() == "true") }
                    if let i = attributeDict["i"] { currentRunItalic = (i == "1" || i.lowercased() == "true") }
                    if let sz = attributeDict["sz"], let hundredthsPt = Double(sz) {
                        currentRunFontSizePt = CGFloat(hundredthsPt / 100)
                    }
                }
            case "t":
                if currentShapeKind == .text { isInText = true }
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
                if currentShapeKind == .text {
                    currentRuns.append(Run(
                        text: currentRunText,
                        bold: currentRunBold,
                        italic: currentRunItalic,
                        fontSizePt: currentRunFontSizePt
                    ))
                }
            case "p":
                if currentShapeKind == .text {
                    currentParagraphs.append(currentRuns)
                }
            case "sp":
                if let frame = currentFrame, currentParagraphs.contains(where: { !$0.isEmpty }) {
                    shapes.append(.text(paragraphs: currentParagraphs, frameEMU: frame))
                }
                currentShapeKind = nil
            case "pic":
                if let frame = currentFrame, let relationshipId = currentEmbedRelationshipId {
                    shapes.append(.image(relationshipId: relationshipId, frameEMU: frame))
                }
                currentShapeKind = nil
            default:
                break
            }
        }

        private var currentFrame: CGRect? {
            guard let x = currentOffsetX, let y = currentOffsetY,
                  let cx = currentExtentCX, let cy = currentExtentCY else { return nil }
            return CGRect(x: x, y: y, width: cx, height: cy)
        }

        private func resetShapeState() {
            currentOffsetX = nil
            currentOffsetY = nil
            currentExtentCX = nil
            currentExtentCY = nil
            currentEmbedRelationshipId = nil
            currentParagraphs = []
        }
    }
}
