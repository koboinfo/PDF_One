import Foundation

/// PDFから抽出したテキストを、規格上有効なdocx/xlsx/pptxパッケージへ変換する。
/// 表計算・スライドの本格的なレイアウト再現は`PDFService`側の専用ロジック（PDFTableExtractor等）が担い、
/// ここでは共通のOOXMLパーツ（Content_Types、リレーションシップ、各フォーマットの本体XML）の組み立てのみを担当する。
enum OfficeDocumentBuilder {

    // MARK: - Word (.docx)

    static func makeDocx(pageTexts: [String]) -> Data {
        var bodyXML = ""
        for (pageIndex, pageText) in pageTexts.enumerated() {
            let lines = pageText.isEmpty ? [""] : pageText.components(separatedBy: .newlines)
            for line in lines {
                bodyXML += "<w:p><w:r><w:t xml:space=\"preserve\">\(xmlEscape(line))</w:t></w:r></w:p>"
            }
            if pageIndex < pageTexts.count - 1 {
                bodyXML += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
        }

        let documentXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>\(bodyXML)<w:sectPr/></w:body>
        </w:document>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        return OOXMLZipWriter.write(entries: [
            .init(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            .init(path: "_rels/.rels", data: Data(rootRels.utf8)),
            .init(path: "word/document.xml", data: Data(documentXML.utf8))
        ])
    }

    // MARK: - Excel (.xlsx)

    /// `sheets`は1シートごとの行×列の文字列グリッド。
    static func makeXlsx(sheets: [[[String]]]) -> Data {
        let sheetNames = sheets.indices.map { "Sheet\($0 + 1)" }

        var contentTypeOverrides = ""
        var workbookSheetsXML = ""
        var workbookRelsXML = ""
        var entries: [OOXMLZipWriter.Entry] = []

        for (sheetIndex, rows) in sheets.enumerated() {
            let sheetNumber = sheetIndex + 1
            let sheetXML = makeSheetXML(rows: rows)
            entries.append(.init(path: "xl/worksheets/sheet\(sheetNumber).xml", data: Data(sheetXML.utf8)))

            contentTypeOverrides += "<Override PartName=\"/xl/worksheets/sheet\(sheetNumber).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
            workbookSheetsXML += "<sheet name=\"\(xmlEscape(sheetNames[sheetIndex]))\" sheetId=\"\(sheetNumber)\" r:id=\"rId\(sheetNumber)\"/>"
            workbookRelsXML += "<Relationship Id=\"rId\(sheetNumber)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(sheetNumber).xml\"/>"
        }
        workbookRelsXML += "<Relationship Id=\"rId\(sheets.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"

        let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\(workbookSheetsXML)</sheets>
        </workbook>
        """

        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(workbookRelsXML)
        </Relationships>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        \(contentTypeOverrides)
        </Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """

        entries.append(contentsOf: [
            .init(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            .init(path: "_rels/.rels", data: Data(rootRels.utf8)),
            .init(path: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            .init(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8)),
            .init(path: "xl/styles.xml", data: Data(Self.stylesXML.utf8))
        ])

        return OOXMLZipWriter.write(entries: entries)
    }

    /// セルスタイルの定義。`cellXfs`のインデックス1（全辺に細い罫線）を各セルの`s`属性から参照する。
    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
    <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
    <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border>
    <left style="thin"><color rgb="FFB7B7B7"/></left>
    <right style="thin"><color rgb="FFB7B7B7"/></right>
    <top style="thin"><color rgb="FFB7B7B7"/></top>
    <bottom style="thin"><color rgb="FFB7B7B7"/></bottom>
    <diagonal/>
    </border>
    </borders>
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
    <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
    </cellXfs>
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """

    private static func makeSheetXML(rows: [[String]]) -> String {
        var rowsXML = ""
        for (rowIndex, row) in rows.enumerated() {
            let rowNumber = rowIndex + 1
            var cellsXML = ""
            for (colIndex, value) in row.enumerated() {
                let cellRef = "\(columnLetter(for: colIndex))\(rowNumber)"
                let truncated = String(value.prefix(32_000))
                if let numericValue = numericCellValue(truncated) {
                    cellsXML += "<c r=\"\(cellRef)\" s=\"1\"><v>\(numericValue)</v></c>"
                } else {
                    cellsXML += "<c r=\"\(cellRef)\" s=\"1\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(truncated))</t></is></c>"
                }
            }
            rowsXML += "<row r=\"\(rowNumber)\">\(cellsXML)</row>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>\(rowsXML)</sheetData>
        </worksheet>
        """
    }

    /// セルの文字列がExcel上で数値として扱えるかを判定し、数値なら`<v>`にそのまま書ける正規化済み文字列を返す。
    /// 先頭ゼロ（"0123"等、郵便番号やコードの可能性が高い）は数値化せず文字列のまま保持する。
    private static func numericCellValue(_ value: String) -> String? {
        guard !value.isEmpty, Double(value) != nil else { return nil }
        if value.count > 1, value.hasPrefix("0"), !value.hasPrefix("0.") {
            return nil
        }
        if value.count > 2, value.hasPrefix("-0"), !value.hasPrefix("-0.") {
            return nil
        }
        return value
    }

    private static func columnLetter(for zeroBasedIndex: Int) -> String {
        var index = zeroBasedIndex
        var letters = ""
        repeat {
            let remainder = index % 26
            letters = String(UnicodeScalar(UInt8(65 + remainder))) + letters
            index = index / 26 - 1
        } while index >= 0
        return letters
    }

    // MARK: - PowerPoint (.pptx)

    /// スライド1枚分の内容。`.text`は段落テキスト、`.image`はスライド全面に配置する画像（PDFページのラスタライズ結果など）を表す。
    enum SlideContent {
        case text(String)
        case image(data: Data, pixelWidth: Int, pixelHeight: Int)
    }

    private static let slideWidthEMU = 12_192_000
    private static let slideHeightEMU = 6_858_000

    static func makePptx(slides: [SlideContent]) -> Data {
        var entries: [OOXMLZipWriter.Entry] = []
        var contentTypeOverrides = ""
        var presentationSlideIdsXML = ""
        var presentationRelsXML = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>"

        var mediaIndex = 1
        for (slideIndex, slide) in slides.enumerated() {
            let slideNumber = slideIndex + 1
            let relationshipId = slideNumber + 1

            var slideRelsXML = "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>"
            let slideXML: String

            switch slide {
            case .text(let text):
                slideXML = makeTextSlideXML(text: text)
            case .image(let data, let pixelWidth, let pixelHeight):
                let mediaFileName = "image\(mediaIndex).png"
                mediaIndex += 1
                entries.append(.init(path: "ppt/media/\(mediaFileName)", data: data))
                slideRelsXML += "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/\(mediaFileName)\"/>"
                slideXML = makeImageSlideXML(imageRelationshipId: "rId2", pixelWidth: pixelWidth, pixelHeight: pixelHeight)
            }

            entries.append(.init(path: "ppt/slides/slide\(slideNumber).xml", data: Data(slideXML.utf8)))
            entries.append(.init(
                path: "ppt/slides/_rels/slide\(slideNumber).xml.rels",
                data: Data("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(slideRelsXML)</Relationships>".utf8)
            ))

            contentTypeOverrides += "<Override PartName=\"/ppt/slides/slide\(slideNumber).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
            presentationSlideIdsXML += "<p:sldId id=\"\(256 + slideIndex)\" r:id=\"rId\(relationshipId)\"/>"
            presentationRelsXML += "<Relationship Id=\"rId\(relationshipId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(slideNumber).xml\"/>"
        }

        let presentationXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
        <p:sldIdLst>\(presentationSlideIdsXML)</p:sldIdLst>
        <p:sldSz cx="\(slideWidthEMU)" cy="\(slideHeightEMU)"/>
        </p:presentation>
        """

        let presentationRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(presentationRelsXML)</Relationships>"

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Default Extension="png" ContentType="image/png"/>
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        \(contentTypeOverrides)
        </Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """

        entries.append(contentsOf: [
            .init(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            .init(path: "_rels/.rels", data: Data(rootRels.utf8)),
            .init(path: "ppt/presentation.xml", data: Data(presentationXML.utf8)),
            .init(path: "ppt/_rels/presentation.xml.rels", data: Data(presentationRels.utf8)),
            .init(path: "ppt/slideMasters/slideMaster1.xml", data: Data(Self.slideMasterXML.utf8)),
            .init(path: "ppt/slideMasters/_rels/slideMaster1.xml.rels", data: Data(Self.slideMasterRels.utf8)),
            .init(path: "ppt/slideLayouts/slideLayout1.xml", data: Data(Self.slideLayoutXML.utf8)),
            .init(path: "ppt/slideLayouts/_rels/slideLayout1.xml.rels", data: Data(Self.slideLayoutRels.utf8)),
            .init(path: "ppt/theme/theme1.xml", data: Data(Self.themeXML.utf8))
        ])

        return OOXMLZipWriter.write(entries: entries)
    }

    private static func makeTextSlideXML(text: String) -> String {
        let lines = text.isEmpty ? [""] : text.components(separatedBy: .newlines)
        let paragraphsXML = lines.map { "<a:p><a:r><a:t>\(xmlEscape($0))</a:t></a:r></a:p>" }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:cSld><p:spTree>
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr/>
        <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="TextBox 1"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
        <p:spPr>
        <a:xfrm><a:off x="457200" y="274638"/><a:ext cx="\(slideWidthEMU - 914_400)" cy="\(slideHeightEMU - 549_276)"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        <p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>\(paragraphsXML)</p:txBody>
        </p:sp>
        </p:spTree></p:cSld>
        <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    private static func makeImageSlideXML(imageRelationshipId: String, pixelWidth: Int, pixelHeight: Int) -> String {
        let (cx, cy) = fittedSize(pixelWidth: pixelWidth, pixelHeight: pixelHeight, boundsWidth: slideWidthEMU, boundsHeight: slideHeightEMU)
        let offsetX = (slideWidthEMU - cx) / 2
        let offsetY = (slideHeightEMU - cy) / 2

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:cSld><p:spTree>
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr/>
        <p:pic>
        <p:nvPicPr><p:cNvPr id="2" name="Picture 1"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
        <p:blipFill><a:blip r:embed="\(imageRelationshipId)"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
        <p:spPr>
        <a:xfrm><a:off x="\(offsetX)" y="\(offsetY)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
        </p:pic>
        </p:spTree></p:cSld>
        <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    /// `boundsWidth`×`boundsHeight`（EMU）に収まるよう、アスペクト比を保ったまま縮小したサイズ（EMU）を返す。
    private static func fittedSize(pixelWidth: Int, pixelHeight: Int, boundsWidth: Int, boundsHeight: Int) -> (Int, Int) {
        guard pixelWidth > 0, pixelHeight > 0 else { return (boundsWidth, boundsHeight) }
        let scale = min(Double(boundsWidth) / Double(pixelWidth), Double(boundsHeight) / Double(pixelHeight))
        return (Int(Double(pixelWidth) * scale), Int(Double(pixelHeight) * scale))
    }

    private static let slideMasterXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
    <p:cSld>
    <p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>
    <p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr/>
    </p:spTree>
    </p:cSld>
    <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
    <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
    </p:sldMaster>
    """

    private static let slideMasterRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
    </Relationships>
    """

    private static let slideLayoutXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
    <p:cSld name="Blank">
    <p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr/>
    </p:spTree>
    </p:cSld>
    <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
    </p:sldLayout>
    """

    private static let slideLayoutRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
    </Relationships>
    """

    private static let themeXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="PDFOneTheme">
    <a:themeElements>
    <a:clrScheme name="PDFOne">
    <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
    <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
    <a:dk2><a:srgbClr val="1F1F1F"/></a:dk2>
    <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
    <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
    <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
    <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
    <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
    <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
    <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
    <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
    <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="PDFOne">
    <a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
    <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="PDFOne">
    <a:fillStyleLst>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    </a:fillStyleLst>
    <a:lnStyleLst>
    <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
    <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
    <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
    </a:lnStyleLst>
    <a:effectStyleLst>
    <a:effectStyle><a:effectLst/></a:effectStyle>
    <a:effectStyle><a:effectLst/></a:effectStyle>
    <a:effectStyle><a:effectLst/></a:effectStyle>
    </a:effectStyleLst>
    <a:bgFillStyleLst>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
    </a:bgFillStyleLst>
    </a:fmtScheme>
    </a:themeElements>
    </a:theme>
    """

    // MARK: - Shared

    private static func xmlEscape(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}