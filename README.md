# PDF One

PDFの結合・作成・圧縮・編集・保護・署名・OCR・透かしをオンデバイスで完結させるiOSユーティリティアプリ。

> アプリ表示名（CFBundleDisplayName）・Xcodeプロジェクト/ターゲット名・スキーム名はいずれも「PDF One」（識別子は `PDF_One`）に統一。

- **対応OS**: iOS 17.0+
- **言語**: Swift 5.9
- **UI**: SwiftUI
- **アーキテクチャ**: MVVM (`@Observable`) + Clean Services

## 機能一覧

### 1. PDF結合（[MergeView](Sources/Views/MergeView.swift) / [MergeViewModel](Sources/ViewModels/MergeViewModel.swift)）
複数のPDFファイルを`UIDocumentPickerViewController`（[DocumentPickerView](Sources/Views/Components/DocumentPickerView.swift)）経由で選択し、選択順に1つのPDFへ結合する。結合結果は`ActivityView`（`UIActivityViewController`）から共有可能。

### 2. 画像からPDF作成（[ImageToPDFView](Sources/Views/ImageToPDFView.swift) / [ImageToPDFViewModel](Sources/ViewModels/ImageToPDFViewModel.swift)）
`PhotosPicker`で選択した複数枚の画像を1枚1ページとしてPDF化する。`PDFPreviewView`（`PDFKit.PDFView`ラッパー）で生成結果をその場でプレビューできる。

### 3. PDF圧縮（[CompressView](Sources/Views/CompressView.swift) / [CompressViewModel](Sources/ViewModels/CompressViewModel.swift)）
選択したPDFの各ページをJPEGに再エンコードして再構成することでファイルサイズを圧縮する。圧縮強度は低・中・高の3段階から選択でき、圧縮前後のファイルサイズと削減率を表示する。

### 4. ページ編集・並び替え・回転・削除（[PageEditView](Sources/Views/PageEditView.swift) / [PageEditViewModel](Sources/ViewModels/PageEditViewModel.swift)）
PDFの各ページをグリッド表示し、ページ単位での回転・削除・選択ページの抽出・並び替えを行い、編集結果を新しいPDFとして保存・共有する。

### 5. PDF→JPG変換（[PDFToJPGView](Sources/Views/PDFToJPGView.swift) / [PDFToJPGViewModel](Sources/ViewModels/PDFToJPGViewModel.swift)）
PDFの各ページをJPEG画像として書き出し、グリッド表示から個別・一括で共有できる。

### 6. PDF分割（[SplitPDFView](Sources/Views/SplitPDFView.swift) / [SplitPDFViewModel](Sources/ViewModels/SplitPDFViewModel.swift)）
指定したページ範囲ごとに元PDFを複数のPDFファイルへ分割する。

### 7. パスワード設定・解除（[ProtectPDFView](Sources/Views/ProtectPDFView.swift) / [ProtectPDFViewModel](Sources/ViewModels/ProtectPDFViewModel.swift)）
PDFにユーザー/オーナーパスワードを設定して暗号化する。ロックされたPDFの解除にも対応。

### 8. 電子署名（[SignatureView](Sources/Views/SignatureView.swift) / [SignatureViewModel](Sources/ViewModels/SignatureViewModel.swift)）
指でキャンバスに描いた署名をPDFページ上の任意位置に配置して保存する。

### 9. OCR（[OCRView](Sources/Views/OCRView.swift) / [OCRViewModel](Sources/ViewModels/OCRViewModel.swift)）
`Vision`フレームワークでPDF各ページの画像から日本語/英語テキストを認識・抽出する。

### 10. 透かし（[WatermarkView](Sources/Views/WatermarkView.swift) / [WatermarkViewModel](Sources/ViewModels/WatermarkViewModel.swift)）
入力したテキストを全ページ中央に45度回転・半透明で描画し、透かし入りPDFとして保存する。ページ内容はベクターのまま再描画されるため画質劣化がない。

### 11. Office形式変換（[OfficeConvertView](Sources/Views/OfficeConvertView.swift) / [OfficeConvertViewModel](Sources/ViewModels/OfficeConvertViewModel.swift)）
PDFをWord/Excel/PowerPoint形式へ変換する。双方向（PDF↔Word/Excel/PowerPoint）の実変換ロジック（OOXML Zipリーダー/ライター等）が実装済み。XCTestの変換テスト（異常系含む）は全件Pass。

### 12. 設定・キャッシュ管理（[SettingsView](Sources/Views/SettingsView.swift) / [SettingsViewModel](Sources/ViewModels/SettingsViewModel.swift)）
処理中に一時ディレクトリへ生成されるPDF/JPEGファイルのサイズを計算・表示し、まとめて削除できる。アプリバージョン表示、使い方ヘルプ、プライバシーポリシー（実文面、[PrivacyPolicyView](Sources/Views/PrivacyPolicyView.swift)）へのアクセスも提供する。

## 共通コンポーネント

| コンポーネント | 役割 |
|---|---|
| [PrimaryButton](Sources/Views/Components/PrimaryButton.swift) | アプリ全体で使う統一デザインのボタン。`isProcessing`中はインジケータを表示し二重タップを防止 |
| [EmptyStateView](Sources/Views/Components/EmptyStateView.swift) | ファイル未選択時に表示する共通プレースホルダー |
| [ToastNotificationView](Sources/Views/Components/ToastNotificationView.swift) | 成功・エラーの一時通知（トースト）表示 |
| [ActivityView](Sources/Views/Components/ActivityView.swift) | `UIActivityViewController`のSwiftUIラッパー（共有シート） |
| [DocumentPickerView](Sources/Views/Components/DocumentPickerView.swift) | `UIDocumentPickerViewController`のSwiftUIラッパー（PDF複数選択） |
| [PDFPreviewView](Sources/Views/Components/PDFPreviewView.swift) | `PDFKit.PDFView`のSwiftUIラッパー |
| [AppBackground](Sources/Views/Components/AppBackground.swift) | 全画面で共有するパステルグラデーション背景。`appBackground()`でForm/Listの標準背景を透過して重ねる |
| [ToolCardView](Sources/Views/Components/ToolCardView.swift) | [ToolsView](Sources/Views/ToolsView.swift)のグリッドで使うツールカード |

### PDFService / OCRService

[Sources/Services/PDFService.swift](Sources/Services/PDFService.swift) と [Sources/Services/OCRService.swift](Sources/Services/OCRService.swift) が全機能のコアロジックを担う。それぞれ`PDFServiceProtocol` / `OCRServiceProtocol`に準拠し、各ViewModelはプロトコル経由で依存するためテスト時にモックへ差し替え可能。

- `mergePDFs` — 複数PDFのページを順に結合
- `createPDF` — 画像配列から1画像1ページのPDFを生成
- `compressPDF` — ページをJPEG再エンコードして圧縮
- `generateEditedPDF` / `extractPages` — ページの並び替え・回転・抽出を反映した新規PDFを生成
- `reorderPages` / `rotatePage` / `deletePages` — ページ単位の編集プリミティブ
- `exportAsImages` — 各ページをJPEG化用のビットマップとして取得
- `splitPDF` — ページ範囲ごとに複数PDFへ分割
- `protectPDF` / `unlockPDF` — パスワードによる暗号化・解除
- `addWatermark` — 全ページへテキスト透かしをベクターのまま合成
- `convertToOffice` / `convertOfficeToPDF` — Word/Excel/PowerPoint双方向変換（OOXML Zipリーダー/ライターによる実変換ロジック実装済み）

`Tests/PDFServiceTests.swift`にXCTestによるユニットテストを収録（結合・変換・圧縮・並び替え・回転・削除・分割・保護・透かし・Office変換の主要パスと異常系を網羅）。

> **既知の制約**:
> - `PDFService.inspect(url:)`は未実装（`fatalError`）。呼び出し箇所は現状なし。

## アーキテクチャ

```
Sources/
├── App/                   # @main エントリポイント
│   └── PDF_OneApp.swift
├── Models/                # ドメインモデル（ToolItem/ToolRoute等）
├── Services/               # ビジネスロジック（PDFKit / UIKit / Vision 依存）
│   ├── PDFService.swift
│   ├── OCRService.swift
│   └── SignatureService.swift
├── ViewModels/              # @Observable ViewModel（画面ごとの状態・非同期処理）
│   ├── MergeViewModel.swift
│   ├── ImageToPDFViewModel.swift
│   ├── CompressViewModel.swift
│   ├── PageEditViewModel.swift
│   ├── PDFToJPGViewModel.swift
│   ├── SplitPDFViewModel.swift
│   ├── ProtectPDFViewModel.swift
│   ├── SignatureViewModel.swift
│   ├── OCRViewModel.swift
│   ├── WatermarkViewModel.swift
│   ├── OfficeConvertViewModel.swift
│   ├── ToolsViewModel.swift
│   └── SettingsViewModel.swift
└── Views/                  # SwiftUI View
    ├── MainTabView.swift    # タブ構成のルートView
    ├── ToolsView.swift      # ツール一覧グリッド（各機能への入口）
    ├── MergeView.swift
    ├── ImageToPDFView.swift
    ├── CompressView.swift
    ├── PageEditView.swift
    ├── PDFToJPGView.swift
    ├── SplitPDFView.swift
    ├── ProtectPDFView.swift
    ├── SignatureView.swift
    ├── OCRView.swift
    ├── WatermarkView.swift
    ├── OfficeConvertView.swift
    ├── SettingsView.swift
    ├── FilesView.swift
    └── Components/          # 画面横断で再利用するView
Tests/
└── PDFServiceTests.swift
```

各画面は `View → @Observable ViewModel → PDFServiceProtocol` の一方向依存で構成され、ViewModelはUIKit/PDFKitの詳細をServiceに隠蔽している。

## ビルド・テスト手順（Xcode GUIなし）

このプロジェクトは [project.yml](project.yml)（[XcodeGen](https://github.com/yonaskolb/XcodeGen)仕様）と [build.sh](build.sh) により、Xcodeを起動せずターミナルからビルド・テストできる構成になっている。

```bash
# 1. XcodeGenで .xcodeproj を生成（初回・project.yml変更時のみ）
brew install xcodegen   # 未インストールの場合
xcodegen generate

# 2. ビルド & テストを実行
./build.sh
```

`build.sh`は同ディレクトリ内の`.xcworkspace`（優先）または`.xcodeproj`を自動検出し、`xcodebuild build`→`xcodebuild test`をiOSシミュレータ向けに実行する。スキーム名・destinationは環境変数で上書き可能。

```bash
SCHEME=PDF_One DESTINATION='platform=iOS Simulator,name=iPhone 15' ./build.sh
```

### 動作要件

- **Xcode本体**（Command Line Toolsのみでは`xcodebuild`は動作しない）
- **XcodeGen**（`.xcodeproj`が存在しない場合、`project.yml`から生成する場合のみ必要）
- ソースは全面的に`UIKit`/`PDFKit`/`PhotosUI`に依存しているため、macOS単体（`swift build`）ではビルドできず、iOSシミュレータまたは実機向けビルドが必須。

> `xcodegen generate` → `./build.sh`（iPhone 17 Proシミュレータ）でビルド・全23件のユニットテストの成功を確認済み（2026-08-10時点）。Homebrewが無い環境では[XcodeGenのリリースzip](https://github.com/yonaskolb/XcodeGen/releases)を展開してバイナリを直接実行することでも代替可能。
