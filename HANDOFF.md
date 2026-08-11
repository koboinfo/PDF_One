# PDF One — 開発状況引き継ぎメモ（2026-08-11 09:06時点）

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
- **未コミットの変更なし**（本ファイルの更新を除く）。

## 実装済み機能（11ツール、すべて実ロジック実装済み）
1. PDF結合（MergeView）
2. 画像からPDF作成（ImageToPDFView）
3. PDF圧縮（CompressView、低/中/高の3段階）
4. ページ編集・並び替え・回転・削除（PageEditView）
5. PDF→JPG変換（PDFToJPGView）
6. PDF分割（SplitPDFView）
7. パスワード設定・解除（ProtectPDFView）
8. 電子署名（SignatureView）— **Pro候補としてタグ付け済み（後述）**
9. OCR（OCRView）— **Pro候補としてタグ付け済み**
10. 透かし（WatermarkView）— **Pro候補としてタグ付け済み**
11. Office形式変換（OfficeConvertView、PDF↔Word/Excel/PowerPoint双方向）— **Pro候補としてタグ付け済み**。リッチテキスト（bold/italic/フォントサイズ/配置）・表構造（tbl/tr/tc）のパースに対応し変換精度を向上。OOXML Zip展開にzip bomb対策（展開後サイズ上限・圧縮率上限）を追加。

その他: 設定・キャッシュ管理画面（SettingsView、サブディレクトリまで再帰的にキャッシュ削除）、ドキュメントスキャナ（ScannerView）、保存済みファイル一覧（FilesView、検索・並び替え）、プライバシーポリシー/利用規約画面（PrivacyPolicyView/TermsOfServiceView）。

## 生成物の永続保存
- `SavedFileStore`が`Documents/SavedPDFs`配下に各ツールの出力を永続保存する（従来はtemporaryDirectoryのみでOS/キャッシュクリアにより消失していた）。全11ツールのViewModelが対応済み。
- `FilesView`/`FilesViewModel`で保存済みファイルの検索・並び替え（更新日/名前/サイズ）が可能。

## サブスクリプション機能（Pro プラン）— ⚠️ 未完成・機能ゲート未配線
次回セッションはここから着手すること。

- `SubscriptionManager`（StoreKit 2）: `com.pdfone.pro.monthly` / `com.pdfone.pro.yearly`の2プロダクト、`Transaction.updates`監視、現在有効なプランID・失効日・トライアル中かどうかの状態管理まで実装済み。
- `Subscriptions.storekit`: 両プランに1週間の無料トライアルを設定済み。Testターゲットのスキームにも紐付け済み（`StoreKitTest.framework`参照あり）。
- `ToolItem.isPro`: 電子署名/OCR/透かし/Office変換の4ツールをPro候補としてマーク済み。
- `ToolCardView`: `isLocked`パラメータとProバッジ（クラウンアイコン）のUIは実装済み。
- `PaywallView`/`PaywallViewModel`: プラン選択・購入・復元導線のUI一式は実装済み。

**しかし以下が未接続で、実質すべての機能が無料で使える状態のまま**:
- `ToolsView.swift`が`tool.isPro`・`isLocked`を一切参照していない（Proバッジが表示されない）
- ツールタップ時に`SubscriptionManager.isSubscribed`をチェックする処理がなく、`PaywallView`もどこからも呼ばれていない
- アプリのどこにも`PaywallView`・`SubscriptionManager`への参照経路がない（`grep -rl "Paywall\|SubscriptionManager" Sources`で確認済み）

## 次にやるべきこと（優先順）
1. **課金ゲートの配線**: `ToolsView.swift`で`tool.isPro && !subscriptionManager.isSubscribed`の場合に`PaywallView`をシート表示し、購読済みなら通常通り遷移するようにする。`ToolCardView`への`isLocked: tool.isPro && !isSubscribed`の受け渡しも必要。
2. **StoreKitテスト設定の動作確認**: `Subscriptions.storekit`をXcodeスキームで実行し、ローカルStoreKitテスト環境で購入・復元・トライアルフローが正しく動くか確認する。
3. **`docs/app-store-metadata.md`のサブスクリプション節を確定**: 価格（月額/年額）・無料トライアル日数（`Subscriptions.storekit`は1週間で設定済みなのでこれに合わせるか要確認）をApp Store Connect側の設定と一致させ、概要文に反映する。`docs/qa/submission-readiness-report.md`に詳細あり。
4. `PDFService.inspect(url:)`の実装要否の判断（未使用なら削除、使うなら実装。`fatalError`のまま）
5. 実機での動作確認（これまでの確認はシミュレータのみ）
6. 上記が完了したらApp Store Connectへの実際の申請作業（`docs/app-store-metadata.md`・`docs/qa/`配下は準備が進んでいる状態）。

## テスト状況
- 直近の確認済みビルド: 2026-08-11 09:05、`xcodegen generate` → `DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" ./build.sh`によりビルド成功・**全84件テスト成功**を確認済み（コミット18件すべて反映後の状態）。

## ブランディング・アセット
- アプリアイコン一式は生成済み（`AppIcon_Export/`配下にiOS/Android/汎用サイズを出力済み、ベクター定義は`AppIconView.swift`）。
- `docs/design/`にApp Storeスクリーンショット構成案・配色・SF Symbols方針・アイコンバリエーションのドキュメントあり（コミット済み）。
- `docs/qa/`に審査/提出/実機検証/異常系テスト/FAQ・サポートのチェックリストあり（コミット済み）。

## 参考: リポジトリ内CLAUDE.md（このプロジェクト固有のClaude運用ルール）
- 出力形式: コード差分/ファイル優先、説明は最小限の箇条書き
- 基本的なSwift/SwiftUI構文の説明は明示的要求がない限り不要
- （別途 `~/CLAUDE.md` にホームディレクトリ全体向けの指示あり: 曖昧な指示は目的確認してから動く、破壊的操作は事前確認、作業前に一括提示→OK後は一括実行）
