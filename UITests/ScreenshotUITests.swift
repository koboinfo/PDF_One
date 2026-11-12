import XCTest

/// App Store提出用スクリーンショットの仮撮影。各テストは独立してアプリを起動し、
/// 目的の画面まで遷移してスクリーンショットを`.keepAlways`で添付する。
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test01_Tools() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["PDF結合"].waitForExistence(timeout: 10))
        attachScreenshot(app, name: "01_tools")
    }

    func test02_OfficeConvert() {
        let app = launchApp()
        let card = app.buttons["PDF→Office"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(1)
        attachScreenshot(app, name: "02_office_convert")
    }

    func test03_OCR() {
        let app = launchApp()
        let card = app.buttons["OCR"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(1)
        attachScreenshot(app, name: "03_ocr")
    }

    func test04_Signature() {
        let app = launchApp()
        let card = app.buttons["電子署名"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(1)
        attachScreenshot(app, name: "04_signature")
    }

    func test05_Settings() {
        let app = launchApp()
        let tab = app.buttons["tab.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        sleep(1)
        attachScreenshot(app, name: "05_settings")
    }

    func test06_Merge() {
        let app = launchApp()
        let card = app.buttons["PDF結合"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(1)
        attachScreenshot(app, name: "06_merge")
    }
}
