# App Icon バリエーション仕様（iOS 18対応）

現行の `Sources/Views/Components/AppIconView.swift`（`AppIconGraphic`＝白背景＋レインボーグラデーションの
「P」リボン＋"PDF"ワードマーク）を単一ソースとして、iOS 18で追加された **Light / Dark / Tinted** の
3アピアランスに対応する構成案。現状の `AppIcon.appiconset` は `universal` 1枠のみ（Light相当）で、
Dark・Tinted未対応のため、このドキュメントでは3バリエーションの見た目・実装方針・書き出し手順を定義する。

## 1. 3バリエーションのビジュアル仕様

| バリエーション | 背景 | リボン | ワードマーク「PDF」 |
|---|---|---|---|
| **Light**（現行維持） | `#FFFFFF` | 6色レインボーグラデーション（既存のまま） | `#1C293D`（Ink Navy） |
| **Dark**（新規） | `#151517`（HSB 0.62, 0.10, 0.09。ブランド色相を残した漆黒） | 同じレインボーグラデーション（暗背景でも十分な彩度・コントラスト） | `#EDF0F7`（背景パレットのオフホワイト。純白は避ける＝Apple推奨） |
| **Tinted**（新規） | `#D2D4D9`（HSB 0.62, 0.03, 0.85。中明度ニュートラルグレー） | フラット単色 `#3A3B3D`（グラデーション廃止・ワードマーク省略） | なし（省略） |

`docs/design/assets/` に各バリエーションのSVGモックアップを配置（`icon-light.svg` / `icon-dark.svg` /
`icon-tinted.svg`）。ホーム画面での見え方を確認するための**プレビュー用**（角丸マスク付き）であり、
実際に書き出すPNGアセットは次項の通り角丸なしの正方形とすること。

### デザイン判断の理由

- **Dark**：Appleは「純黒の背景は穴が空いたように見える」ためNGとしており、ごくわずかに明度を残した
  ニュートラルダークを推奨。ブランドの背景色相（0.62 = 青みグレー）を最暗部まで一貫させることで、
  Light版と同じ「ブランドの世界観」を保つ。ワードマークも純白ではなく背景パレットのオフホワイト
  `#EDF0F7` を使い、既存の背景グラデーション色と地続きにする。
- **Tinted**：Tinted Iconはシステムがグレースケール（輝度）だけを見てユーザー選択のティントカラーを
  一律適用する仕組みのため、色相・グラデーションは意味を持たない。Appleのサンプルアイコンも
  グラデーションや細かい文字要素を廃し、単色・シンプルな形状に簡略化する方針を取っている。
  本アプリでも同様に、リボン形状のみをフラット単色で残し、"PDF"ワードマークは小サイズでの
  可読性低下を避けるため省略する。

## 2. アセット構成（Assets.xcassets）

現行の `Contents.json`（`AppIcon.appiconset`）：

```json
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Dark / Tinted 追加後の構成案：

```json
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    {
      "filename" : "AppIcon-Dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ]
    },
    {
      "filename" : "AppIcon-Tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024",
      "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ]
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- 3枚とも **1024×1024・アルファチャンネルなし** のPNG（既存の `generate_app_icon.swift` が
  `CGImageAlphaInfo.noneSkipLast` でフラット化しているのと同じ要件）。
- 3枚とも**角丸マスクをかけない**フルブリードの正方形で書き出す（角丸はXcode/App Store側が自動適用するため、
  事前に丸めるとエッジがにじむ／二重マスクになる）。既存スクリプトはこの要件を満たす実装になっている。
- iOS 17以前の端末では `appearances` 未対応のため、自動的に無印（Light）のみが使われる。
  最小対応OS（iOS 17+）を変更する必要はない。

## 3. 実装への引き継ぎメモ（コード変更は本タスクの対象外）

実際にSwift側へ反映する際は、`AppIconGraphic` を書き換えるのではなく、以下のように
バリエーションを切り替え可能な形に**将来のコーディングセッションで**拡張することを推奨する
（本タスクでは提案のみ、コード編集は行わない）：

1. `AppIconGraphic` に `enum Appearance { case light, dark, tinted }` を追加し、
   背景色・ワードマーク有無・グラデーション/フラット塗りを切り替え。
2. `Scripts/generate_app_icon.swift` を3回実行（またはループ実行）し、
   `AppIcon.png` / `AppIcon-Dark.png` / `AppIcon-Tinted.png` をそれぞれ書き出す。
3. `Contents.json` を上記構成案に更新し、3ファイルを `AppIcon.appiconset/` に配置する。

## 4. QAチェックリスト

- [ ] Dark版をダークモード端末のホーム画面で表示し、他アプリのDarkアイコンと並べて明度が浮かない/沈まないか確認
- [ ] Tinted版をコントロールセンターの「ホーム画面カスタマイズ」でグレー・レッド・ブルー等複数ティントに切り替えて視認性確認
- [ ] 3バリエーションとも1024×1024・アルファなしでApp Store Connectの検証を通過するか確認
- [ ] Light版は現行のままリグレッションがないことを確認（変更なし）
