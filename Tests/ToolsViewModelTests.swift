import XCTest
@testable import PDF_One

/// `ToolsView`のグリッドに描画される`ToolItem`データの整合性を検証する。
/// `ToolCardView`は`tool.isComingSoon`（`route == nil`）のときのみ`.disabled`になるため、
/// 「画面内でタップ可能」という要件は「`availableTools`は全て非nilの`route`を持つ」という
/// データ契約に還元できる。
@MainActor
final class ToolsViewModelTests: XCTestCase {

    // MARK: - availableTools はすべてタップ可能（route を持つ）

    func testAvailableToolsAreAllNotComingSoonAndTappable() {
        let viewModel = ToolsViewModel()

        for tool in viewModel.availableTools {
            XCTAssertFalse(
                tool.isComingSoon,
                "\(tool.title) はavailableToolsに含まれているのに route が nil で isComingSoon になっている（ToolCardViewが.disabledになりタップ不可）"
            )
            XCTAssertNotNil(tool.route, "\(tool.title) の route が nil のためタップしても遷移できない")
        }
    }

    func testComingSoonToolsAreAllMarkedAsComingSoon() {
        let viewModel = ToolsViewModel()

        for tool in viewModel.comingSoonTools {
            XCTAssertTrue(tool.isComingSoon, "\(tool.title) は comingSoonTools にあるが route が設定されており isComingSoon が false になっている")
        }
    }

    // MARK: - 重複がない（同じツールが二重に描画されない）

    func testAvailableToolsHaveNoDuplicateRoutesOrTitles() {
        let viewModel = ToolsViewModel()
        let routes = viewModel.availableTools.compactMap(\.route)
        let titles = viewModel.availableTools.map(\.title)

        XCTAssertEqual(routes.count, Set(routes).count, "availableTools に同じ route を持つツールが重複している")
        XCTAssertEqual(titles.count, Set(titles).count, "availableTools に同じタイトルのツールが重複している")
    }

    // MARK: - 全ルートが画面上のどこかのツールから到達可能（取りこぼしがない）

    func testEveryToolRouteIsReachableFromAvailableTools() {
        let viewModel = ToolsViewModel()
        let reachableRoutes = Set(viewModel.availableTools.compactMap(\.route))
        let allRoutes = Set(ToolRoute.allCases)

        XCTAssertEqual(
            reachableRoutes, allRoutes,
            "ToolRouteに定義されているのにavailableToolsのどのツールからも遷移できないケースがある: \(allRoutes.subtracting(reachableRoutes))"
        )
    }

    // MARK: - タップ操作 = open(_:) が正しくナビゲーションスタックへ積まれる

    func testOpeningToolAppendsItsRouteToNavigationPath() {
        let viewModel = ToolsViewModel()
        XCTAssertTrue(viewModel.path.isEmpty)

        viewModel.open(.merge)

        XCTAssertEqual(viewModel.path, [.merge])
    }

    func testOpeningComingSoonToolWithNilRouteDoesNothing() {
        let viewModel = ToolsViewModel()

        viewModel.open(nil)

        XCTAssertTrue(viewModel.path.isEmpty, "route が nil のツールをタップしても遷移スタックは変化しないべき")
    }

    // MARK: - Pro ツールのタグ付け（ペイウォール導線の前提データ）

    func testProTaggedToolsMatchExpectedRoutes() {
        let viewModel = ToolsViewModel()
        let proRoutes = Set(viewModel.availableTools.filter(\.isPro).compactMap(\.route))

        XCTAssertEqual(
            proRoutes,
            [.signature, .ocr, .watermark, .officeConvert, .officeToPDF],
            "Pro候補としてタグ付けされているツールの集合が想定と異なる（ToolCardViewのProバッジ表示に影響する）"
        )
    }
}
