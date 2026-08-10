# PDF One — 開発状況引き継ぎメモ（2026-08-11時点）

## プロジェクトの場所
- **実体パス**: `~/Desktop/PDF_One`（2026-08-11に`MyFirstApp`からリネーム。旧名時代のバックアップが`~/Desktop/MyFirstApp_backup`に残っている）
- **表示名（CFBundleDisplayName）**: PDF One
- **Xcodeプロジェクト/ターゲット/スキーム名/Swiftモジュール名**: `PDF_One`（表示名と統一。Swiftモジュール名はスペース不可のためアンダースコア表記）
- 個人開発のiOSアプリ。運営はオーナー1名。

## 技術スタック
- iOS 17.0+ / Swift 5.9 / SwiftUI
- アーキテクチャ: MVVM（`@Observable`）+ Clean Services（View → ViewModel → `PDFServiceProtocol`の一方向依存）
- 依存管理: Swift Package Manager（外部ライブラリはなく、PDFKit/UIKit/Vision/VisionKit/PencilKit等の標準フレームワークのみ使用）
- ビルド生成: XcodeGen（`project.yml`から`.xcodeproj`を生成）+ `build.sh`でXcode GUIなしにビルド・テスト可能

## バージョン管理
- git初期化済み（`main`ブランチ、コミット履歴あり）。Swift用`.gitignore`設定済み。

## 実装済み機能（11ツール、うち10は実ロジック実装済み）
1. PDF結合（MergeView）
2. 画像からPDF作成（ImageToPDFView）
3. PDF圧縮（CompressView、低/中/高の3段階）
4. ページ編集・並び替え・回転・削除（PageEditView）
5. PDF→JPG変換（PDFToJPGView）
6. PDF分割（SplitPDFView、ページ範囲指定）
7. パスワード設定・解除（ProtectPDFView）
8. 電子署名（SignatureView、指描画）
9. OCR（OCRView、Visionフレームワークで日本語/英語認識）
10. 透かし（WatermarkView、ベクター再描画で画質劣化なし）
11. Office形式変換（OfficeConvertView、PDF↔Word/Excel/PowerPoint双方向、実変換ロジック実装済み）

その他: 設定・キャッシュ管理画面（SettingsView）、ドキュメントスキャナ（ScannerView、VisionKit）。

## 既知の制約・未実装事項
- `PDFService.inspect(url:)` — 未実装（`fatalError("not implemented")`）。現状呼び出し箇所はないため実害はないが、将来使う場合は実装が必要。
- 設定画面のプライバシーポリシーはダミー表示。

## テスト状況
- `Tests/PDFServiceTests.swift`（結合・作成・圧縮・並び替え・回転・削除・分割・保護・透かし・Office変換の主要パス＋異常系、38件）
- `Tests/SettingsViewModelTests.swift`（キャッシュサイズ計算・クリア処理、6件）
- 2026-08-11時点で `xcodegen generate` → `./build.sh`（`DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"`、iPhone 15シミュレータは環境になし）によりビルド成功・全44件テスト成功を確認済み。

## ブランディング・アセット
- アプリアイコン一式は生成済み（`AppIcon_Export/`配下にiOS/Android/汎用サイズを出力済み、ベクター定義は`AppIconView.swift`）。

## 次にやるべきこと（引き継ぎ先エージェントへの示唆）
1. `PDFService.inspect(url:)`の実装要否の判断（未使用なら削除、使うなら実装）
2. 実機での動作確認（これまでの確認はシミュレータのみ）
3. App Store Connectへの実際の申請作業（`docs/app-store-metadata.md`・`docs/release-notes.md`は申請可能な状態）

## 参考: リポジトリ内CLAUDE.md（このプロジェクト固有のClaude運用ルール）
- 出力形式: コード差分/ファイル優先、説明は最小限の箇条書き
- 基本的なSwift/SwiftUI構文の説明は明示的要求がない限り不要
- （別途 `~/CLAUDE.md` にホームディレクトリ全体向けの指示あり: 曖昧な指示は目的確認してから動く、破壊的操作は事前確認）
