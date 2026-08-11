# SF Symbols 選定リスト（PDF One）

iOS 17+ / SF Symbols 5系で利用可能なシンボルのみを使用。既存実装（`ToolItem.swift`,
`AppTab.swift`, 各種コンポーネント）の棚卸しと、改善余地がある箇所への代替案をまとめる。

## 1. 機能アイコン（ツール一覧グリッド）

`Sources/Models/ToolItem.swift` の `ToolIconType.systemImage` に対応。実装済み・現状維持を基本とし、
△印のみ代替候補を併記。

| 機能タイトル | 現行シンボル | 評価 | 代替候補（任意） |
|---|---|---|---|
| PDF結合 | `doc.on.doc` | ◎ 直感的（書類を重ねる＝結合） | — |
| 画像→PDF | `photo.on.rectangle.angled` | ◎ 画像→書類の変換が一目瞭然 | — |
| 圧縮 | `arrow.down.right.and.arrow.up.left` | ◎ 「縮小」を表す標準シンボル | — |
| ページ編集 | `square.on.square` | △ 「PDF結合」と視覚的に近く紛らわしい | `rectangle.stack`（ページの束）または `square.grid.2x2`（グリッド編集画面と一致） |
| PDF→JPG | `photo` | △ 汎用的すぎ、他画面のプレースホルダーとも重複 | `photo.badge.arrow.down`（書き出しを明示、iOS16+） |
| PDF分割 | `square.split.2x1` | ◎ 「分割」が直接的 | — |
| パスワード設定 | `lock.doc` | ◎ 保護対象が書類であることが明確 | — |
| 電子署名 | `signature` | ◎ 最も直接的な標準シンボル | — |
| OCR | `text.viewfinder` | ◎ スキャン＋テキスト化を的確に表現 | — |
| 透かし | `drop` | ○ 抽象的だが「重ねる/滲ませる」を示す定番選択 | `drop.fill`（塗りつぶしで視認性向上） |
| PDF→Office | `doc.text` | ○ 無難だが変換であることは伝わりにくい | `arrow.triangle.2.circlepath.doc.on.clipboard`（双方向変換を強調、やや複雑） |
| Office→PDF | `doc.badge.plus` | ◎ Office文書からPDFが生成される様子を表現 | — |

**推奨対応：** 「ページ編集」のみ `rectangle.stack` への変更を推奨（結合アイコンとの混同回避）。他は変更不要。

## 2. タブバー

`Sources/Models/AppTab.swift` に対応。5タブとも標準的で変更不要。

| タブ | シンボル |
|---|---|
| ホーム | `house` |
| ファイル | `folder` |
| ツール | `wrench.and.screwdriver` |
| スキャナー | `camera.viewfinder` |
| 設定 | `gearshape` |

選択状態は `.regular`、非選択は `.thin` ウェイトで区別（`ModernTabBar.swift` 実装済み、変更不要）。

## 3. 汎用UIアイコン

画面共通コンポーネントで使用中のシンボル。機能アイコンとは独立した「操作」を表すため、
上記の機能アイコンと重複しないシンボルを選ぶ方針を維持。

| 用途 | シンボル | 使用箇所 |
|---|---|---|
| 戻る | `chevron.left` | `BaseToolView.swift`（ヘッダー） |
| ヘルプ | `questionmark.circle` | `BaseToolView.swift`, `SettingsView.swift` |
| 実行ボタン | `play.fill` | `BaseToolView.swift` |
| 追加/選択 | `plus.circle.fill` | `PrimaryButton` 経由（`EmptyStateView.swift`） |
| 共有 | `square.and.arrow.up` | `PrimaryButton.swift`（Preview例） |
| ページ削除 | `xmark.circle.fill` | `PageThumbnailCell.swift` |
| ページ回転 | `rotate.right` | `PageThumbnailCell.swift` |
| ページ汎用サムネイル | `doc.text` | `PageThumbnailCell.swift` |
| 画像プレースホルダー | `photo` | `ImageThumbnailRow.swift` |
| 成功トースト | `checkmark.circle.fill` | `ToastNotificationView.swift`（`.green`） |
| エラートースト | `xmark.octagon.fill` | `ToastNotificationView.swift`（`.red`） |
| データ削除 | `trash` | `SettingsView.swift` |
| バージョン情報 | `info.circle` | `SettingsView.swift` |
| プライバシーポリシー | `hand.raised` | `SettingsView.swift` |
| 遷移矢印 | `chevron.right` | `SettingsView.swift` |

## 4. 命名・選定ルール（今後の機能追加時）

1. **具象優先**：`doc.text` のような汎用シンボルより、`lock.doc` `text.viewfinder` のように
   動作対象＋操作が一体化した複合シンボルを優先する（SF Symbolsは組み合わせ語彙が豊富）。
2. **重複回避**：同一画面内・同一ナビゲーション階層内で同じシンボルを2つ以上の異なる意味に使わない
   （例：「ページ編集」を`rectangle.stack`に変更するのはこの原則に基づく）。
3. **ウェイト統一**：機能アイコン（ツールグリッド）は `.regular`、ヘッダー操作は `.regular`、
   非選択タブのみ `.thin` という現行ルールを維持。
4. **塗り指定**：トースト・警告など強い意味を持つものは `.fill` バリアントを使い、
   通常操作は無地バリアントを使う（既存実装と整合）。
