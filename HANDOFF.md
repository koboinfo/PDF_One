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
- **git未初期化**（`.git`なし）。コミット履歴・変更履歴は存在しない。継続開発する場合はまずgit initを検討する必要あり。

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
11. **Office形式変換（OfficeConvertView）— 未実装。数秒待機後にダミーファイルを返すMockのみ**

その他: 設定・キャッシュ管理画面（SettingsView）、ドキュメントスキャナ（ScannerView、VisionKit）。

## 既知の制約・未実装事項
- `PDFService.convertToOffice` — Mock実装。Word/Excel/PowerPointへの実変換ロジックは未着手（呼び出し元のOfficeConvertViewModelはMockを叩いているだけ）。
- `PDFService.inspect(url:)` — 未実装（`fatalError("not implemented")`）。現状呼び出し箇所はないため実害はないが、将来使う場合は実装が必要。
- 設定画面のプライバシーポリシーはダミー表示。

## テスト状況
- `Tests/PDFServiceTests.swift`にXCTestで23件のユニットテストを収録（結合・作成・圧縮・並び替え・回転・削除・分割・保護・透かし・Office変換の主要パス＋異常系）。
- 2026-08-10時点で `xcodegen generate` → `./build.sh`（iPhone 17 Proシミュレータ）によりビルド成功・23件全テスト成功を確認済み。

## ブランディング・アセット
- アプリアイコン一式は生成済み（`AppIcon_Export/`配下にiOS/Android/汎用サイズを出力済み、ベクター定義は`AppIconView.swift`）。

## 次にやるべきこと（引き継ぎ先エージェントへの示唆）
1. Office形式変換の実ロジック実装（現状最大の機能ギャップ）
2. git初期化とコミット履歴の開始（バージョン管理が全くない状態）
3. プライバシーポリシーの実文面作成（App Store申請前に必須）
4. `PDFService.inspect(url:)`の実装要否の判断（未使用なら削除、使うなら実装）
5. 実機での動作確認（これまでの確認はシミュレータのみ）

## 参考: リポジトリ内CLAUDE.md（このプロジェクト固有のClaude運用ルール）
- 出力形式: コード差分/ファイル優先、説明は最小限の箇条書き
- 基本的なSwift/SwiftUI構文の説明は明示的要求がない限り不要
- （別途 `~/CLAUDE.md` にホームディレクトリ全体向けの指示あり: 曖昧な指示は目的確認してから動く、破壊的操作は事前確認）
