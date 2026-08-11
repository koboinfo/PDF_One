# 申請準備レポート — Signing & Capabilities確認／実機検証・ストア申請に向けて

制定日：2026年8月11日
対象: PDF One（`PDF_One.xcodeproj`、[project.yml](../../project.yml)から`xcodegen generate`で生成）

## 1. Signing & Capabilities 確認結果

`project.yml` / `PDF_One.xcodeproj/project.pbxproj`を読み取り専用で確認した。**Team固有の値（Apple Developer Team ID）は本レポート作成者側では把握できないため設定していない。以下はXcodeのGUI操作またはご自身の情報を用いた`project.yml`編集が必要。**

| 項目 | 現状 | 判定 |
|---|---|---|
| `DEVELOPMENT_TEAM` | 未設定（`project.yml`・`project.pbxproj`のいずれにも記載なし） | 🛑 **要設定**。Xcode → `PDF_One`ターゲット → Signing & Capabilities → Teamでご自身のApple Developer Teamを選択する必要がある |
| `CODE_SIGN_STYLE` | 明示指定なし（Xcodeデフォルト＝Automaticの可能性が高いが未確認） | ⚠️ `project.yml`に明示していないため、Xcode GUIで一度設定してもTeamが空だと機能しない |
| `CODE_SIGN_IDENTITY` | `"iPhone Developer"`（Debug/Release両方） | ⚠️ これは旧世代（Xcode 10以前相当）の識別子文字列。現行XcodeではAutomatic Signing時に`Apple Development` / `Apple Distribution`が使われるのが通常。XcodeGenのデフォルトテンプレートに由来する値とみられ、実害は小さいが古い値のまま残っている |
| Entitlementsファイル | 存在しない（`find . -iname "*.entitlements"`で0件） | ✅ 現状使用しているCapability（In-App Purchase含む）はentitlementsファイルを必要としないため問題なし |
| In-App Purchase Capability | Xcode上で明示的に追加されていない | ℹ️ StoreKit 2の基本的な購入・Transaction監視コードはCapability追加なしでビルド可能。ただし**App Store Connect側でサブスクリプションプロダクトを作成し、Apple Developer Programの「有料アプリ契約（Paid Apps Agreement）」を締結していないと、審査提出時にIAPが機能しない** |
| Bundle ID | `com.pdfone.PDFOne`（`project.yml`と`project.pbxproj`で一致） | ✅ 問題なし。ただしApple Developer Portalに同一Bundle IDのApp IDが事前登録されている必要あり（未確認） |
| `TARGETED_DEVICE_FAMILY` | `"1,2"`（iPhone + iPad） | ✅ 意図通り。iPad対応のため[app-store-connect-submission-checklist.md](app-store-connect-submission-checklist.md)のiPad用スクリーンショットが必須になる点に注意 |

### 推奨アクション（`project.yml`への追記例、Team ID判明後に反映）

`xcodegen generate`は`project.pbxproj`を都度再生成するため、**Xcode GUIだけでTeamを設定しても次回`xcodegen generate`実行時に消える可能性がある**。恒久的に反映するには`project.yml`のtarget設定に追記するのが安全。

```yaml
# project.yml の targets.PDF_One.settings.base に追加（例、YOUR_TEAM_IDは実際の値に置換）
DEVELOPMENT_TEAM: YOUR_TEAM_ID
CODE_SIGN_STYLE: Automatic
```

この変更はTeam IDが必要なため、今回は適用していない。ご提供いただければ反映する。

## 2. ビルドターゲット設定の確認

| 項目 | 現状 | 判定 |
|---|---|---|
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `1.0` / `1` | ✅ 初回申請として妥当 |
| `SWIFT_VERSION` | `5.9` | ✅ |
| デプロイターゲット | iOS 17.0 | ✅ README/HANDOFFと一致 |
| `SUPPORTS_MACCATALYST` | `false` | ✅ 意図通り（Mac Catalyst非対応） |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `AppIcon`（`AppIcon_Export/`にアセット生成済み） | ✅ |
| スキームのStoreKit設定 | `Subscriptions.storekit`をRun設定に紐付け済み | ✅ ローカルテスト環境は準備済み（実装後にテスト可能） |
| テストターゲット | `PDF_OneTests`、`PDF_One`をホストに設定済み | ✅ |

## 3. 実機検証（④）に向けた準備状況

**前提条件が未達のため、実機検証はまだ開始できない状態。** [HANDOFF.md](../../HANDOFF.md)記載の通り:

1. 🛑 **未コミットの変更（`SubscriptionManager`・`SavedFileStore`・Office変換強化など）が一度も`xcodegen generate` → `./build.sh`でビルド確認されていない。** シミュレータビルドが通ることを先に確認しないまま実機に進むと、切り分けが困難になる。
2. 🛑 上記1が通った後でなければ、[device-verification-checklist.md](device-verification-checklist.md)のメモリ・発熱・バックグラウンドライフサイクル検証は着手できない。
3. ⚠️ Signing（本レポート セクション1）が未設定のため、実機ビルドはそもそも実行できない（シミュレータビルドはTeam不要で可能）。

**実機検証の前提が整う順序**: `xcodegen generate` & `./build.sh`成功 → 意味のある単位でコミット → Signing設定（Team ID反映） → 実機ビルド → [device-verification-checklist.md](device-verification-checklist.md)着手。

## 4. ストア申請（⑤）に向けた準備状況

| ブロッカー | 内容 | 解消の見込み |
|---|---|---|
| 🛑 サブスクリプションのペイウォールUI・機能ゲート・復元ボタン未実装 | [app-store-review-checklist.md セクション7](app-store-review-checklist.md)参照。v1.0はサブスク込みで申請する方針のため必須実装 | 別途実装作業が必要（本レポートのスコープ外） |
| 🛑 未コミット変更のビルド・テスト未検証 | 本レポート セクション3参照 | `xcodegen generate` → `./build.sh`の実行で解消可能 |
| 🛑 Signing未設定（Team ID） | 本レポート セクション1参照 | ユーザーからのTeam ID提供＋Xcode/`project.yml`設定で解消可能 |
| ⚠️ プライバシーポリシーが未公開（ローカルファイルのみ） | `docs/privacy-policy.html`をGitHub Pages等でホスティングし、公開URLをASCに登録する必要あり | ホスティング先の選定が必要 |
| ⚠️ 実機検証・意地悪テスト未実施 | [device-verification-checklist.md](device-verification-checklist.md) / [edge-case-test-scenarios.md](edge-case-test-scenarios.md) | セクション3の順序で対応 |
| ⚠️ App Store Connect側のサブスクリプショングループ・価格未設定 | [app-store-connect-submission-checklist.md セクション7](app-store-connect-submission-checklist.md) | ASC作業（ペイウォール実装と並行可能） |
| ⚠️ 有料アプリ契約（Paid Apps Agreement）の締結状況未確認 | ASCの「契約/税金/口座情報」で確認 | ASC上で確認・締結 |

## 5. 推奨対応順序（まとめ）

1. `xcodegen generate` → `./build.sh`で未コミット変更のビルド・テストを確認し、通ればコミット
2. サブスクリプションのペイウォールUI・機能ゲート・復元ボタンを実装（[app-store-review-checklist.md セクション7](app-store-review-checklist.md)の7-2〜7-4）
3. Apple Developer Team IDを本プロジェクトに設定（本レポート セクション1の推奨アクション）
4. `Subscriptions.storekit`でのローカル購入/復元フロー動作確認
5. 実機ビルド＆[device-verification-checklist.md](device-verification-checklist.md)実施
6. App Store Connectでサブスクリプション・スクリーンショット・メタデータ一式を登録（[app-store-connect-submission-checklist.md](app-store-connect-submission-checklist.md)）
7. [app-store-review-checklist.md セクション9](app-store-review-checklist.md#9-申請直前の最終チェック提出当日)を完了させて申請
