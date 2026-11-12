# PDF One — 開発状況引き継ぎメモ（2026-08-16時点）

## プロジェクトの場所
- **実体パス**: `~/Desktop/PDF_One`（2026-08-11に`MyFirstApp`からリネーム。旧名時代のバックアップが`~/Desktop/MyFirstApp_backup`に残っている・非gitフォルダ）
- **表示名（CFBundleDisplayName）**: PDF One
- **Xcodeプロジェクト/ターゲット/スキーム名/Swiftモジュール名**: `PDF_One`（表示名と統一。Swiftモジュール名はスペース不可のためアンダースコア表記）
- 個人開発のiOSアプリ。運営はオーナー1名。
- **複数のClaude Codeセッションを並行実行して同時に手を入れる運用**が続いている。着手前に`git status`で他セッションの変更が進行中でないか確認し、ファイルの変化が止まってから作業すること。

## 技術スタック
- iOS 17.0+ / Swift 5.9 / SwiftUI
- アーキテクチャ: MVVM（`@Observable`）+ Clean Services（View → ViewModel → `PDFServiceProtocol`の一方向依存）
- 依存管理: Swift Package Manager（外部ライブラリはなく、PDFKit/UIKit/Vision/VisionKit/PencilKit/StoreKit等の標準フレームワークのみ使用）
- ビルド生成: XcodeGen（`project.yml`から`.xcodeproj`を生成）+ `build.sh`でXcode GUIなしにビルド・テスト可能
  - シミュレータは`iPhone 15`が環境になく、`iPhone 17 Pro`を使用: `DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" ./build.sh`

## バージョン管理
- git初期化済み（`main`ブランチ）。Swift用`.gitignore`設定済み。
- **コミット済み29件**（最新: `9643999` 2026-08-13 09:33「アプリ内プライバシーポリシー画面を広告SDK/サインイン実装の実態に合わせて更新し、審査チェックリストを再レビュー」）。2026-08-11以降の主な追加分（詳細は`git log`参照）:
  - サブスクリプション課金ゲートの配線本体（`ToolsView`/各Pro画面/`SettingsView`）+ 購読テスト土台
  - PaywallViewのNavigationStack二重化・キーボード自動修正バグ（検索窓/パスワード欄/透かし入力）の修正
  - レイアウト基準値を`LayoutConstants`に一元化（タブバー/広告の被り解消）
  - サインイン画面（`SignInView`/`SignInViewModel`）、ネイティブ広告バナー（`AdBannerView`/`TopAdBannerView`/`NativeAdPlaceholderView`/`AdMobInterstitialManager`）、ホーム画面（`HomeView`/`HomeViewModel`、クイックアクション・最近のファイル）を新規追加し、課金ゲートに配線
  - 広告表示とShareSheetの同時presentation競合、結合ファイルの残存、Pro限定画面のデッドコードを修正
  - PDF結合結果の保存機能を追加、共有シートの競合とサブスクリプション監視タスクのリークを修正
  - プライバシーポリシー・アプリ説明文を広告SDK/サインイン実装の実態に合わせて修正し、GitHub Pagesで公開。審査チェックリストを再レビュー
- **未コミットの変更あり**（作業ツリー、着手時期・セッション不明 — 次回セッションはこれの確認から）:
  - `UITests/ScreenshotUITests.swift`（新規・未追跡）— App Store提出用スクリーンショット自動化と思われる
  - `Sources/Views/Components/ModernTabBar.swift`: 各タブに`accessibilityIdentifier`（`tab.home`/`tab.files`/`tab.tools`/`tab.scanner`/`tab.settings`）を追加（UIテスト用）
  - `Sources/ViewModels/CompressViewModel.swift`・`Sources/Views/OCRView.swift`: パーセント表示を`String(format:)`から`.formatted(.percent.precision(.fractionLength(0)))`にローカライズ対応で修正
  - `Sources/Views/OfficeConvertView.swift`・`Sources/Views/OfficeToPDFView.swift`: 軽微な変更（差分未精査）
  - `Sources/Localizable.xcstrings`: 上記に伴う文言更新
  - `PDF_One.xcodeproj/project.pbxproj`・`PDF_One.xcodeproj/xcshareddata/xcschemes/PDF_One.xcscheme`・`project.yml`: UITestsターゲット追加分の反映（`xcodegen generate`要確認）
  - まだコミットしていない。内容確認・ビルド確認の上でコミットするかどうかの判断から次回開始する。

## 実装済み機能（11ツール、すべて実ロジック実装済み）
1. PDF結合（MergeView）— 結果の永続保存機能あり
2. 画像からPDF作成（ImageToPDFView）
3. PDF圧縮（CompressView、低/中/高の3段階）
4. ページ編集・並び替え・回転・削除（PageEditView）
5. PDF→JPG変換（PDFToJPGView）
6. PDF分割（SplitPDFView）
7. パスワード設定・解除（ProtectPDFView）
8. 電子署名（SignatureView）— **Pro限定**
9. OCR（OCRView）— **Pro限定**
10. 透かし（WatermarkView）— **Pro限定**
11. Office形式変換（OfficeConvertView=PDF→Office、OfficeToPDFView=Office→PDF）— **いずれもPro限定**。リッチテキスト・表構造パース対応、OOXML Zip展開にzip bomb対策済み。

その他: ホーム画面（HomeView、クイックアクション・最近のファイル・ネイティブ広告プレースホルダー）、サインイン画面（SignInView）、設定・キャッシュ管理画面（SettingsView）、ドキュメントスキャナ（ScannerView）、保存済みファイル一覧（FilesView、検索・並び替え）、プライバシーポリシー/利用規約画面（広告SDK・サインイン実装の実態に合わせて更新済み）。

## 生成物の永続保存
- `SavedFileStore`が`Documents/SavedPDFs`配下に各ツールの出力を永続保存する。全11ツール＋PDF結合結果が対応済み。
- `FilesView`/`FilesViewModel`で保存済みファイルの検索・並び替え（更新日/名前/サイズ）が可能。

## サブスクリプション機能（Pro プラン）
- `SubscriptionManager`（StoreKit 2）: `com.pdfone.pro.monthly`（月額480円） / `com.pdfone.pro.yearly`（年額4,800円）の2プロダクト、`Transaction.updates`監視。サブスクリプション監視タスクのリークは2026-08-13のコミットで修正済み。
- `Subscriptions.storekit`: 両プランに7日間の無料トライアルを設定済み。
- 課金ゲート配線済み（`ToolsView`＋Pro対象5View自身の二重ガード、`SettingsView`にサブスクリプションセクション）。

**StoreKitローカルテストのブロッカー（2026-08-11時点の記録）**: `Tests/SubscriptionManagerTests.swift`（10件）が`SKInternalErrorDomain Code=3`で全件実行不能だった。**この後の状況は本メモでは未確認** — Xcode GUIでの`Cmd+U`、App Store.appサインイン確認、Mac再起動、実機でのテストのいずれかで解消する見込みだったが、解消したかどうかは次回セッションで要確認。詳細は[docs/qa/subscription-verification-checklist.md](docs/qa/subscription-verification-checklist.md)。

## 次にやるべきこと（優先順）
1. **未コミットの変更を精査してコミット判断**: UITests追加・アクセシビリティID・パーセント表示修正の内容を確認し、ビルド通過を確認した上でコミットする。
2. **StoreKitローカルテストのブロッカーが解消したか確認**: 解消していれば10件のテストをPass、未解消なら実機での検証に切り替える。
3. **手動動作確認**: [docs/qa/subscription-verification-checklist.md](docs/qa/subscription-verification-checklist.md)の「4. 手動動作確認チェックリスト」（購入フロー・トライアル・キャンセル・復元・UI導線）、および広告・サインイン導線を含めて実機で消化する。
4. 実機での動作確認（これまでの確認はシミュレータのみの可能性が高い）。
5. App Store Connect側で実際の`com.pdfone.pro.monthly` / `com.pdfone.pro.yearly`商品とトライアルオファーを設定し、Sandboxアカウントでの実購入テスト。
6. 上記が完了したらApp Store Connectへの実際の申請作業。

## テスト状況
- 2026-08-11 09:5x時点で既存84件テスト全成功を確認済み（それ以降の追加コミット分の再テストは本メモでは未確認）。
- `SubscriptionManagerTests`（10件）はStoreKitローカルテストのブロッカーにより2026-08-11時点で未実行。以降の状況不明。
- UITests（`ScreenshotUITests.swift`）は未コミット・未実行。

## ブランディング・アセット
- アプリアイコン一式は生成済み（`AppIcon_Export/`配下にiOS/Android/汎用サイズを出力済み、ベクター定義は`AppIconView.swift`）。
- `docs/design/`にApp Storeスクリーンショット構成案・配色・SF Symbols方針・アイコンバリエーションのドキュメントあり（コミット済み）。
- `docs/qa/`に審査/提出/実機検証/異常系テスト/FAQ・サポートのチェックリストあり（コミット済み、2026-08-13に再レビュー済み）。

## 参考: リポジトリ内CLAUDE.md（このプロジェクト固有のClaude運用ルール）
- 出力形式: コード差分/ファイル優先、説明は最小限の箇条書き
- 基本的なSwift/SwiftUI構文の説明は明示的要求がない限り不要
- （別途 `~/CLAUDE.md` にホームディレクトリ全体向けの指示あり: 曖昧な指示は目的確認してから動く、破壊的操作は事前確認、作業前に一括提示→OK後は一括実行）
