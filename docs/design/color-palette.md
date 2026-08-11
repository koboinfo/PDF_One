# カラーパレット定義（PDF One）

既存実装（`AppBackground.swift` / `PrimaryButton.swift` / `ToolItem.swift` / `AppIconView.swift`）で
実際に使われているHSB/RGB値からHexコードを算出し、SwiftUI標準カテゴリ（Primary / Secondary /
Background / Accent）に整理したもの。新しい色相を追加するのではなく、**既存のパステル×インクの世界観を
体系化する**ことを目的とする。

## 1. コアパレット

| カテゴリ | 用途 | Hex | 元定義 |
|---|---|---|---|
| **Primary（Ink）** | メインCTAボタン、強調テキスト | `#0A0A0A` → `#383838`（縦グラデーション） | `PrimaryButton.swift` の `.prominent` 背景 |
| **Secondary（Slate）** | 補助テキスト、非選択タブ、キャプション | `#6E7380` | 背景と同じ色相0.62をS14%/B50%まで落として算出（新規提案） |
| **Background（上）** | 全画面背景グラデーション開始点 | `#EDF0F7` | `AppBackground.swift` HSB(0.62, 0.04, 0.97) |
| **Background（下）** | 全画面背景グラデーション終了点 | `#DFE3ED` | `AppBackground.swift` HSB(0.62, 0.06, 0.93) |
| **Surface / Card（Light）** | カード・シート等の前景面 | `#EDF1FA` または `.ultraThinMaterial` | 背景よりわずかに明るいトーン（新規提案。既存は`.ultraThinMaterial`使用） |
| **Accent（Brand Blue）** | リンク・選択状態・強調アイコン | `#2673F2` | `AppIconGraphic` のリボングラデーション先頭色 |

> Primary/Secondaryは「システム標準の `Color.primary` / `Color.secondary`」を代替するものではなく、
> ブランドカラーとして固定値が必要な場面（アイコン、マーケティング素材、オンボーディング等）向けの定義。
> アプリ内テキストは引き続き `Color.primary` / `Color.secondary`（Dynamic Type・ダークモード自動対応）を優先する。

## 2. ダークモード拡張（新規提案）

現状 `AppBackground` 等はダークモード分岐がなく、システムのライト/ダーク両方で同じパステル配色になっている。
将来ダークモード対応する場合の対応値：

| カテゴリ | Light | Dark |
|---|---|---|
| Background | `#EDF0F7` → `#DFE3ED` | `#151517`（HSB 0.62, 0.10, 0.09） |
| Surface / Card | `#EDF1FA` | `#1E2024`（HSB 0.62, 0.15, 0.14） |
| Primary（Ink） | `#0A0A0A` | `#F4F6FA`（明暗反転） |
| Secondary | `#6E7380` | `#9BA0AC` |

## 3. 機能別ティントカラー（Feature Tint Palette）

`ToolItem.swift` の `ToolIconType.tint` にすでに実装済みの12色。ツール一覧・カード背景などで
「淡い彩度を抑えたパステル」で統一感を持たせる設計であり、変更の必要はない。参照用に一覧化する。

| 機能 | SF Symbol | Hex | HSB |
|---|---|---|---|
| 結合（merge） | `doc.on.doc` | `#626E8C` | 0.62, 0.30, 0.55 |
| 画像→PDF（imageToPDF） | `photo.on.rectangle.angled` | `#AD8E71` | 0.08, 0.35, 0.68 |
| 圧縮（compress） | `arrow.down.right.and.arrow.up.left` | `#5C8066` | 0.38, 0.28, 0.50 |
| ページ編集（pageEdit） | `square.on.square` | `#7D6D8C` | 0.75, 0.22, 0.55 |
| PDF→JPG（pdfToJPG） | `photo` | `#9E7287` | 0.92, 0.28, 0.62 |
| 分割（splitPDF） | `square.split.2x1` | `#5F8579` | 0.45, 0.28, 0.52 |
| パスワード保護（protectPDF） | `lock.doc` | `#5D777A` | 0.52, 0.24, 0.48 |
| PDF→Word（pdfToWord） | `doc.text` | `#8C5F65` | 0.98, 0.32, 0.55 |
| 署名（signature） | `signature` | `#626080` | 0.68, 0.25, 0.50 |
| OCR | `text.viewfinder` | `#6B5C51` | 0.07, 0.24, 0.42 |
| 透かし（watermark） | `drop` | `#6B9199` | 0.53, 0.30, 0.60 |
| Office→PDF（officeToPDF） | `doc.badge.plus` | `#948D68` | 0.14, 0.30, 0.58 |

## 4. ブランドグラデーション（アイコン用レインボー）

App Iconの「P」リボンに使用中の6色グラデーション。Light版App Icon・キーアート・オンボーディングの
ヒーロービジュアル等、ブランドを象徴する箇所限定で使用する（UI全体の常用色ではない）。

| 順序 | Hex |
|---|---|
| 1（青） | `#2673F2` |
| 2（緑） | `#21B259` |
| 3（黄） | `#FFCC26` |
| 4（橙） | `#FF7A1A` |
| 5（赤） | `#E63333` |
| 6（紫） | `#592E8C` |

ワードマーク「PDF」文字色（Ink Navy）: `#1C293D`

## 5. セマンティックカラー（既存実装の棚卸し）

成功・エラー・警告は独自Hexを定義せず、**システム標準の動的カラーをそのまま使用**する方針を現状維持する
（Dynamic Type・ダークモード・アクセシビリティコントラスト設定に自動追従するため）。

| 用途 | 色 | 使用箇所 |
|---|---|---|
| 成功 | `Color.green`（システム標準） | `ToastNotificationView.swift`、`ImageToPDFView.swift`（スキャン枠） |
| エラー・破壊的操作 | `Color.red`（システム標準） | `ToastNotificationView.swift`、`SettingsView.swift`、`PageThumbnailCell.swift` |
| 警告 | `Color.orange`（システム標準） | `OfficeToPDFView.swift` |

固定Hexが必要になった場合（マーケティング素材等）は、システム色のライトモード基準値
（Success `#34C759` / Error `#FF3B30` / Warning `#FF9500`：iOS標準）を目安とする。

## 6. 使い分けの指針

- **UI実装**：テキスト・アイコンは `Color.primary` / `Color.secondary`（システム動的カラー）を優先。
  本パレットのPrimary/Secondary Hexは、Web・マーケティング資料等アプリ外で色を固定指定する場面用。
- **ツールごとの差別化**：セクション3の機能別ティントをそのまま維持。新機能追加時は同じHSB系列
  （彩度22〜35%・明度42〜68%の範囲）で色相のみ変えて追加すると統一感を保てる。
- **強調・CTA**：Primary（Ink）グラデーションのボタンを唯一の強い強調要素として使い、
  Accent Blueは将来的にリンクやセレクション状態など「タップ可能」を示す用途に予約する。
