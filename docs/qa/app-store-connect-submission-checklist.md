# App Store Connect 提出メタデータ チェックリスト

制定日：2026年8月11日
対象: PDF One（初回申請 / v1.0）

> 画面仕様・必須項目はAppleが随時更新するため、本チェックリストの数値は2026年8月時点の目安。**申請直前に必ずApp Store Connect上の実際の入力画面・[App Store Connect ヘルプ](https://developer.apple.com/help/app-store-connect/)で最新要件を確認すること。**

## 1. App情報（App Information）

| 項目 | 内容 | 状態 |
|---|---|---|
| 名前（App名） | PDF One | ✅ [app-store-metadata.md](../app-store-metadata.md) |
| サブタイトル | 結合・分割・編集・OCR・署名 | ✅ |
| プライマリ言語 | 日本語 | ✅ |
| Bundle ID | `com.pdfone.PDFOne`（[project.yml](../../project.yml)と一致確認済み） | ✅ Apple Developer Portalでの事前登録要 |
| SKU | 未定（例: `pdfone-ios-001`、ASC内部管理用の任意文字列） | ⚠️ 要決定 |
| プライマリカテゴリ | 仕事効率化（Productivity） | ✅ |
| セカンダリカテゴリ | ビジネス（Business） | ✅ |
| Copyright | 例: `2026 [運営者名/屋号]` | ⚠️ 要記入（個人開発の場合は運営者名） |

## 2. 価格および配信状況（Pricing and Availability）

| 項目 | 内容 | 状態 |
|---|---|---|
| App本体の価格 | 無料（基本機能無料＋App内課金モデル） | ✅ 方針確定済み |
| 配信国・地域 | 全世界 or 日本のみ（要判断。日本語コンテンツのみのため日本先行も選択肢） | ⚠️ 要決定 |
| App内課金の配信国 | App本体と同一にするのが一般的 | ⚠️ App本体の配信国決定後に連動確認 |

## 3. スクリーンショット・プレビュー要件

> サイズ・必須点数はApple側の変更が多い領域。以下は目安、**申請直前に実際のアップロード画面の指定サイズを確認すること**。

| デバイスクラス | 目安解像度（縦向き） | 必須/任意 | 備考 |
|---|---|---|---|
| 6.9インチ iPhone（iPhone 16/17 Pro Max等） | 1320×2868 px | 実質必須（最大サイズを提出すると小型機は自動縮小表示される） | [screenshot-copy.md](../screenshot-copy.md)の構成案を使用 |
| 6.5インチ iPhone（旧機種、6.9インチ未提出時） | 1284×2778 px 相当 | 6.9インチ提出時は省略可なことが多い | 要ASC画面で確認 |
| iPad 13インチ（無印iPad/Pro等、`TARGETED_DEVICE_FAMILY`にiPad含むため必須） | 2064×2752 px 相当 | 必須（iPad対応アプリのため） | iPad用レイアウトでの撮影が必要（iPhone画面の引き伸ばしは審査リジェクト対象） |
| App Previewビデオ（任意） | 各サイズごとに15〜30秒 | 任意 | v1.0では省略可 |

- [ ] [screenshot-copy.md](../screenshot-copy.md)記載の5〜6枚構成で、実機/最新シミュレータのUIと突合してから撮影
- [ ] サブスクリプション機能を含めて申請する場合、Pro訴求のスクリーンショットを1枚追加するか検討（[app-store-metadata.md](../app-store-metadata.md)のサブスク節が確定してから）
- [ ] iPad用スクリーンショットをiPadレイアウトで別途撮影（iPhone用の使い回し不可）

## 4. 検索キーワード・プロモーション文言

| 項目 | 内容 | 状態 |
|---|---|---|
| キーワード（100文字） | [app-store-metadata.md](../app-store-metadata.md)記載の99/100文字案 | ✅ |
| プロモーションテキスト（170文字、随時更新可） | 未作成。初回は概要文冒頭の要約を流用可 | ⚠️ 要作成（審査不要で後から変更できるため優先度は中） |
| サポートURL | 未定（GitHub Pages等での公開が必要） | ⚠️ 要用意 |
| マーケティングURL（任意） | 未定 | ⚠️ 任意 |
| プライバシーポリシーURL | `docs/privacy-policy.html`は**未公開のローカルファイル**。公開URLが必須 | 🛑 **要対応**（[submission-readiness-report.md](submission-readiness-report.md)参照） |

## 5. 年齢制限分類（Age Rating）

App Store Connectの年齢制限アンケートは2026年時点で「コンテンツ記述子」形式。本アプリはユーザー生成コンテンツの閲覧・投稿機能や暴力表現等を含まないため、想定される回答は以下の通り。

| 質問カテゴリ | 想定回答 | 理由 |
|---|---|---|
| 暴力表現・恐怖表現 | なし | 該当コンテンツを含まない |
| 性的表現・ヌーディティ | なし | 該当コンテンツを含まない |
| 下品な表現・ブラックユーモア | なし | 該当コンテンツを含まない |
| ギャンブル表現・シミュレーション | なし | 該当コンテンツを含まない |
| アルコール・タバコ・薬物 | なし | 該当コンテンツを含まない |
| ユーザー生成コンテンツ（UGC） | なし | ユーザー間のコンテンツ共有・コミュニケーション機能なし |
| 未フィルタリングのWebアクセス | なし | Webビュー・ブラウザ機能なし |
| 医療・治療情報 | なし | 非該当 |
| 想定年齢区分 | **4+** | 上記いずれにも該当しないため最も低い区分が妥当 |

- [ ] 実際の質問文言・選択肢はASC画面上で毎回変わるため、申請時に上記想定と選択肢の対応関係を再確認すること
- [ ] サブスクリプション（App内課金）の有無を問う質問がある場合は「あり」で回答

## 6. App Privacy（プライバシー"栄養成分表示"）

[app-store-review-checklist.md](app-store-review-checklist.md)セクション1参照。想定される回答:

| データ種別 | 収集有無 |
|---|---|
| 連絡先情報・識別子・使用状況データ等 | 収集しない |
| ユーザーコンテンツ（写真・ファイル） | 収集しない（端末内処理のみ、外部送信なし） |
| **購入履歴（サブスクリプション導入後）** | Appleが処理するため開発者側の収集は発生しない想定だが、ASCのアンケートで「Appが購入情報を収集するか」を正確に回答すること |

- [ ] サブスクリプション実装確定後、「App Privacy」アンケートに購入関連の項目が追加で問われないか再確認

## 7. App内課金（サブスクリプション）設定 — [app-store-review-checklist.md セクション7](app-store-review-checklist.md)と連動

- [ ] サブスクリプショングループを新規作成（例: 「PDF One Pro」）
- [ ] `com.pdfone.pro.monthly` / `com.pdfone.pro.yearly` の2プロダクトを登録（Product IDは`Sources/Services/SubscriptionManager.swift`と完全一致させる）
- [ ] 各プロダクトの価格帯（Price Tier）・表示名・説明文（日本語ローカライズ）を入力
- [ ] レビュー用スクリーンショット（サブスクリプション購入画面のキャプチャ、ASCが要求する場合あり）を用意
- [ ] 無料トライアル/Introductory Offerの有無を決定・設定
- [ ] App内課金のApp Review情報にテスト手順（サンドボックスアカウントでの購入方法）を記載

## 8. App Review情報（審査担当者向け）

[app-store-review-checklist.md セクション8](app-store-review-checklist.md#8-審査ノートapp-review-information作成時の推奨記載事項)の内容に加え、サブスク導入により以下を追記:

- [ ] サンドボックステスト用Apple IDまたはサブスクリプション確認手順
- [ ] 「連絡先情報」（審査中に開発者へ連絡が必要な場合の氏名・電話番号・メールアドレス）
- [ ] デモアカウント欄: 本アプリはログイン不要のため「該当なし」

## 9. ビルドのアップロード

- [ ] `MARKETING_VERSION`（現在`1.0`）・`CURRENT_PROJECT_VERSION`（現在`1`）が申請するビルドと一致していることを確認（[project.yml](../../project.yml)）
- [ ] Xcode Organizer または `xcodebuild -exportArchive` + Transporter でビルドをアップロード
- [ ] アップロード後、ASC上でビルドの処理完了（Processing）を待ってからバージョンに紐付け
- [ ] 輸出コンプライアンス質問への回答（[app-store-review-checklist.md セクション5](app-store-review-checklist.md)参照）

## 10. TestFlight（推奨・任意）

- [ ] 実機検証（[device-verification-checklist.md](device-verification-checklist.md)）と並行して、TestFlightで自分の別端末や協力者に配布し、実際の購入/復元フローを含めて動作確認することを推奨
- [ ] 内部テスター（Apple Developer Programアカウントに紐づくメンバー）は審査不要ですぐ利用可能

## 11. 申請ボタンを押す前の最終確認

- [ ] [app-store-review-checklist.md セクション9](app-store-review-checklist.md#9-申請直前の最終チェック提出当日)をすべて完了
- [ ] [submission-readiness-report.md](submission-readiness-report.md)のブロッカー項目がすべて解消されている
