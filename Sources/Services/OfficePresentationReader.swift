import CoreGraphics
import Foundation

/// pptxパッケージからスライド1枚ごとのシェイプ（テキストボックス・画像）と、その配置（EMU単位）を読み取る。
/// SmartArt・表・グラフ・アニメーション等の高度な要素は対象外（テキストと画像の位置関係のみ再現する）。
enum OfficePresentationReader {
    struct Slide {
        let elements: [Element]
    }

    enum Element {
        case text(paragraphs: [String], frameEMU: CGRect)
        case image(data: Data, frameEMU: CGRect)
    }

    static func readSlides(from pptxData: Data) throws -> (slideSizeEMU: CGSize, slides: [Slide]) {
        let presentationXML = try OOXMLZipReader.extract(from: pptxData, path: "ppt/presentation.xml")
        let presentationExtractor = PresentationExtractor()
        let presentationParser = XMLParser(data: presentationXML)
        presentationParser.shouldProcessNamespaces = true
        presentationParser.delegate = presentationExtractor
        guard presentationParser.parse(), let slideSize = presentationExtractor.slideSizeEMU else {
            throw OfficeDocumentReader.ReadError.malformedXML
        }

        let presentationRels = (try? OOXMLRelationships.read(from: pptxData, path: "ppt/_rels/presentation.xml.rels")) ?? [:]

        var slides: [Slide] = []
        for relationshipId in presentationExtractor.slideRelationshipIds {
            guard let target = presentationRels[relationshipId] else { continue }
            let slidePath = OOXMLRelationships.resolvePath(base: "ppt/", target: target)
            guard let slide = try? readSlide(from: pptxData, slidePath: slidePath) else { continue }
            slides.append(slide)
        }

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
                return .text(paragraphs: paragraphs, frameEMU: frame)
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
        case text(paragraphs: [String], frameEMU: CGRect)
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
        private var currentParagraphs: [String] = []
        private var currentParagraphText = ""
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
                if currentShapeKind == .text { currentParagraphText = "" }
            case "t":
                if currentShapeKind == .text { isInText = true }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard isInText else { return }
            currentParagraphText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "t":
                isInText = false
            case "p":
                if currentShapeKind == .text {
                    currentParagraphs.append(currentParagraphText)
                }
            case "sp":
                if let frame = currentFrame, !currentParagraphs.isEmpty {
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
