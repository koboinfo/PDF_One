# PDF One — 開発状況引き継ぎメモ（2026-08-11 09:52時点）

## プロジェクトの場所
- **実体パス**: `~/Desktop/PDF_One`（2026-08-11に`MyFirstApp`からリネーム。旧名時代のバックアップが`~/Desktop/MyFirstApp_backup`に残っている・非gitフォルダ）
- **表示名（CFBundleDisplayName）**: PDF One
- **Xcodeプロジェクト/ターゲット/スキーム名/Swiftモジュール名**: `PDF_One`（表示名と統一。Swiftモジュール名はスペース不可のためアンダースコア表記）
- 個人開発のiOSアプリ。運営はオーナー1名。
- 8月に入ってからのApp開発はすべてこのプロジェクト1本。**複数のClaude Codeセッションを並行実行して同時に手を入れる運用**になっている（git履歴にも「concurrent session」という記録が複数残っている）。並行編集中に作業する場合は、着手前に`git status`で他セッションの変更が進行中でないか確認し、ファイルの変化が止まってから作業すること。

## 技術スタック
- iOS 17.0+ / Swift 5.9 / SwiftUI
- アーキテクチャ: MVVM（`@Observable`）+ Clean Services（View → ViewModel → `PDFServiceProtocol`の一方向依存）
- 依存管理: Swift Package Manager（外部ライブラリはなく、PDFKit/UIKit/Vision/VisionKit/PencilKit/StoreKit等の標準フレームワークのみ使用）
- ビルド生成: XcodeGen（`project.yml`から`.xcodeproj`を生成）+ `build.sh`でXcode GUIなしにビルド・テスト可能
  - シミュレータは`iPhone 15`が環境になく、`iPhone 17 Pro`を使用: `DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" ./build.sh`

## バージョン管理
- git初期化済み（`main`ブランチ）。Swift用`.gitignore`設定済み。
- **コミット済み18件**（baseline snapshotからの積み上げ、直近9件が今回2026-08-11 08:50〜09:04のセッションで追加）:
  1〜9. （8/11 01:21〜04:29）初期実装9件（結合・OCR進捗・並行処理isolate・ドラッグ&ドロップ・Privacy Manifest・パスワード/巨大ファイルテスト・キャッシュ管理テスト等。詳細は`git log`参照）
  10. Xcodeプロジェクト設定を更新: ファイル関連付け・StoreKitテスト設定
  11. 生成物の永続保存機能を追加
  12. StoreKit 2ベースのSubscriptionManagerを追加（課金ゲート未連携）
  13. Xcodeプロジェクト設定を更新: 新規ファイル参照・StoreKitTestを追加
  14. Office変換ロジックを強化し、OOXML Zip展開にzip bomb対策を追加
  15. Pro機能タグ付けとPaywall UIの土台を追加（機能ゲート未配線）
  16. プライバシーポリシー・利用規約にサブスクリプション条項を追加
  17. 永続保存機能・キャッシュ削除のテストを追加
  18. App Store提出用のデザイン資料・QAチェックリストを追加
- **未コミットの変更あり**（2026-08-11 09:07〜09:5x、並行セッションで追加。詳細は下記「サブスクリプション機能」節）:
  - `ToolsView.swift`ほか課金ゲート配線一式（`ToolsView`/`SettingsView`/Pro対象5View/`PDF_OneApp.swift`/`MainTabView.swift`）
  - `Tests/SubscriptionManagerTests.swift`（新規、StoreKitTestベース10件）
  - `docs/qa/subscription-verification-checklist.md`（新規）
  - `docs/qa/faq-support.md`・`docs/app-store-metadata.md`のサブスク関連更新
  - `project.pbxproj` / `project.yml`反映（`xcodegen generate`済み）
  - まだコミットしていない。次回セッションはコミットするかどうかの判断から。

## 実装済み機能（11ツール、すべて実ロジック実装済み）
1. PDF結合（MergeView）
2. 画像からPDF作成（ImageToPDFView）
3. PDF圧縮（CompressView、低/中/高の3段階）
4. ページ編集・並び替え・回転・削除（PageEditView）
5. PDF→JPG変換（PDFToJPGView）
6. PDF分割（SplitPDFView）
7. パスワード設定・解除（ProtectPDFView）
8. 電子署名（SignatureView）— **Pro限定。課金ゲート配線済み（後述、未コミット）**
9. OCR（OCRView）— **Pro限定。課金ゲート配線済み**
10. 透かし（WatermarkView）— **Pro限定。課金ゲート配線済み**
11. Office形式変換（OfficeConvertView=PDF→Office、OfficeToPDFView=Office→PDF、双方向で別画面）— **いずれもPro限定。課金ゲート配線済み**。リッチテキスト（bold/italic/フォントサイズ/配置）・表構造（tbl/tr/tc）のパースに対応し変換精度を向上。OOXML Zip展開にzip bomb対策（展開後サイズ上限・圧縮率上限）を追加。

その他: 設定・キャッシュ管理画面（SettingsView、サブディレクトリまで再帰的にキャッシュ削除）、ドキュメントスキャナ（ScannerView）、保存済みファイル一覧（FilesView、検索・並び替え）、プライバシーポリシー/利用規約画面（PrivacyPolicyView/TermsOfServiceView）。

## 生成物の永続保存
- `SavedFileStore`が`Documents/SavedPDFs`配下に各ツールの出力を永続保存する（従来はtemporaryDirectoryのみでOS/キャッシュクリアにより消失していた）。全11ツールのViewModelが対応済み。
- `FilesView`/`FilesViewModel`で保存済みファイルの検索・並び替え（更新日/名前/サイズ）が可能。

## サブスクリプション機能（Pro プラン）— 課金ゲート配線済み（未コミット）、StoreKitローカルテストが環境要因でブロック中

2026-08-11 09:07〜09:5xの並行セッションで、以前ここに書かれていた「機能ゲート未配線」は解消済み。以下がすべて実装され、ビルド・既存84件テストは独立検証済み（本セッションで再実行し確認）:

- `SubscriptionManager`（StoreKit 2）: `com.pdfone.pro.monthly`（月額480円） / `com.pdfone.pro.yearly`（年額4,800円）の2プロダクト、`Transaction.updates`監視、現在有効なプランID・失効日・トライアル中かどうかの状態管理。
- `Subscriptions.storekit`: 両プランに7日間の無料トライアルを設定済み。
- `ToolItem.isPro`: 電子署名/OCR/透かし/PDF→Office/Office→PDFの計5ツールをPro指定。
- `ToolCardView`: `isLocked`パラメータとProバッジ（クラウンアイコン）のUI。
- `PaywallView`/`PaywallViewModel`: プラン選択・購入・復元導線のUI一式。
- **配線本体**: `ToolsView.swift`がタップ時に`tool.isPro && !isSubscribed`を判定し`PaywallView`をシート表示、購読済みならそのまま遷移。加えてPro対象5View自身も`isSubscribed`を直接参照し、未購読なら`body`をまるごと`PaywallView`に差し替える二重ガード（`ToolsView`を経由しない直接遷移が将来増えても安全なように）。
- `SettingsView.swift`: サブスクリプションセクション新設（プラン名・トライアル状態・次回更新日表示、「サブスクリプションを管理」→App Store設定、「購入を復元」、「Proにアップグレード」）。
- `docs/app-store-metadata.md`: 概要文にPro節を追記、価格・トライアル日数を確定として記載（本セッションで反映）。

**ブロッカー**: `Tests/SubscriptionManagerTests.swift`（`StoreKitTest`ベース、購入/トライアル/キャンセル/失効/返金/復元を検証する10件）を新規作成したが、この実行環境では`SKTestSession`生成時に`SKInternalErrorDomain Code=3`が発生し**全件実行不能**。調査の結果、macOS側の`storekitagent`/`amsengagementd`デーモンがサンドボックス拒否を受けており、アプリ側コード・テストコード・`Subscriptions.storekit`の設定には問題がないことを確認済み（詳細・再現手順は[docs/qa/subscription-verification-checklist.md](docs/qa/subscription-verification-checklist.md)）。Xcode GUIでの`Cmd+U`実行、またはApp Store.appでのサインイン確認・Mac再起動・実機でのテストのいずれかで解消する見込み。

## 次にやるべきこと（優先順）
1. **未コミットの変更をコミットするか判断**: 課金ゲート配線一式・新規テスト・ドキュメント更新（本ファイル冒頭の一覧参照）がまだ未コミット。内容確認後にコミットする。
2. **StoreKitローカルテストの実行環境を解消**: 上記ブロッカーの対応（Xcode GUIで`Cmd+U`、Mac再起動、または実機）。10件のテストをPassさせる。
3. **手動動作確認**: [docs/qa/subscription-verification-checklist.md](docs/qa/subscription-verification-checklist.md)の「4. 手動動作確認チェックリスト」（購入フロー・トライアル・キャンセル・復元・UI導線）をXcode GUIまたは実機で消化する。
4. 実機での動作確認（これまでの確認はシミュレータのみ）。
5. App Store Connect側で実際の`com.pdfone.pro.monthly` / `com.pdfone.pro.yearly`商品とトライアルオファーを設定し、Sandboxアカウントでの実購入テスト。
6. 上記が完了したらApp Store Connectへの実際の申請作業（`docs/app-store-metadata.md`・`docs/qa/`配下は準備が進んでいる状態）。

## テスト状況
- 2026-08-11 09:5x、`xcodegen generate` → `xcodebuild build` → `xcodebuild -skip-testing:PDF_OneTests/SubscriptionManagerTests test`でビルド成功・**既存84件テスト全成功**を独立確認済み（未コミットの課金ゲート配線反映後の状態）。
- `SubscriptionManagerTests`（新規10件）は上記ブロッカーによりこの環境では未実行。

## ブランディング・アセット
- アプリアイコン一式は生成済み（`AppIcon_Export/`配下にiOS/Android/汎用サイズを出力済み、ベクター定義は`AppIconView.swift`）。
- `docs/design/`にApp Storeスクリーンショット構成案・配色・SF Symbols方針・アイコンバリエーションのドキュメントあり（コミット済み）。
- `docs/qa/`に審査/提出/実機検証/異常系テスト/FAQ・サポートのチェックリストあり（コミット済み）。

## 参考: リポジトリ内CLAUDE.md（このプロジェクト固有のClaude運用ルール）
- 出力形式: コード差分/ファイル優先、説明は最小限の箇条書き
- 基本的なSwift/SwiftUI構文の説明は明示的要求がない限り不要
- （別途 `~/CLAUDE.md` にホームディレクトリ全体向けの指示あり: 曖昧な指示は目的確認してから動く、破壊的操作は事前確認、作業前に一括提示→OK後は一括実行）
