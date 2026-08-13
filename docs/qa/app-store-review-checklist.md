# App Store審査ガイドライン 事前適合チェックリスト

制定日：2026年8月11日
対象: PDF One（App Store Review Guidelines 2026年時点の版を前提）

> 本チェックリストはコードベース（`Sources/`）・既存ドキュメント（`docs/app-store-metadata.md`、`docs/privacy-policy.md`等）を突き合わせて作成した。`README.md`のOffice変換「Mock」・プライバシーポリシー「ダミー表示」という古い記述は2026-08-11に実装状況（`PDFService.convertToOffice`/`convertOfficeToPDF`は実変換ロジック、`PrivacyPolicyView`は実文面）に合わせて修正済み。
>
> **2026-08-13時点で再レビュー。** ペイウォールUI・機能ゲート・「購入を復元」ボタンは実装済み（セクション7参照、主要ブロッカーは解消）。一方、この間にGoogle Mobile Ads SDK（広告）・Apple IDでのサインイン機能が追加されており、セクション1・2の「データ収集なし」前提が成立しなくなっている点に注意（詳細は各項目参照）。

## 1. Guideline 5.1.1 — プライバシー（データ収集・保存）

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 1-1 | 個人情報・利用データを外部送信していないこと | PDF処理自体はPDFKit/Vision/VisionKit等Apple標準フレームワークのみで完結し外部送信なし。**ただし無料版はGoogle Mobile Ads SDK（広告）を組み込んでおり、ATT許可後は広告識別子（IDFA）等がGoogleに送信される** | ⚠️ PDF処理データは送信されないが「外部送信一切なし」は不正確。プライバシーポリシー（更新済み）・App Privacyアンケートで正確に開示すること |
| 1-2 | プライバシーポリシーの実文面がアプリ内に存在すること | `PrivacyPolicyView.swift`に実文面が実装済み（ダミーではない）。設定画面からアクセス可能。**広告SDK・サインイン機能に関する記載を2026-08-13に追記済み（アプリ内表示側の文言も同期が必要）** | ⚠️ アプリ内`PrivacyPolicyView`の文言が最新のプライバシーポリシーhtml/mdと一致しているか確認・同期すること |
| 1-3 | App Store Connect「App情報」に登録するプライバシーポリシーURLが**一般公開されたWebページ**であること | GitHub Pagesで公開済み: https://koboinfo.github.io/pdf-one-legal/privacy-policy.html （2026-08-13） | ✅ 対応済み。App Store ConnectのURL欄に設定すること |
| 1-4 | App Privacyアンケート（プライバシー"栄養成分表示"）が実態と一致していること | 広告SDK導入により「データは収集されません」は選択不可。広告識別子（Identifiers → Device ID等）を「トラッキングに使用」「広告に使用」として申告する必要がある | 🛑 **要対応**: ASC提出時にApp Privacyアンケートを広告SDKの実態に合わせて回答すること。誤った「データ収集なし」申告はガイドライン違反（虚偽申告）になる |
| 1-5 | Privacy Manifest（`PrivacyInfo.xcprivacy`）の存在とRequired Reason API宣言の網羅性 | `Sources/App/PrivacyInfo.xcprivacy`は存在し、`NSPrivacyAccessedAPICategoryFileTimestamp`（理由コード`C617.1`）を宣言済み | ⚠️ `PDFService.checkFileSize`等で`FileManager.attributesOfItem(...)[.size]`（ファイルサイズ属性）を取得している箇所があり、これがRequired Reason APIの別カテゴリ（File size / System boot time等）に該当しないか2026年時点の最新API一覧で再確認すること。該当する場合は理由コード追加が必要 |
| 1-6 | カメラ権限の使用目的説明文（`NSCameraUsageDescription`）が具体的であること | 「書類をスキャンしてPDFを作成するためにカメラを使用します。」— 目的が明確 | ✅ 問題なし |
| 1-7 | 写真ライブラリアクセスが`PhotosPicker`（システム標準ピッカー）経由であること | `import PhotosUI`使用を確認。`PHPhotoLibrary`への直接アクセスやフルライブラリ権限要求のコードは見当たらない | ✅ システム標準ピッカー使用のため`NSPhotoLibraryUsageDescription`不要な設計を維持できている（要件を満たす限り追加権限文言は不要） |
| 1-8 | 権限を拒否したユーザーへの動作継続性 | プライバシーポリシー記載通り「スキャン以外は通常利用可能」。実機での動作確認は`device-verification-checklist.md`4-1参照 | ⚠️ 実機で最終確認要 |

## 2. Guideline 5.1.2 — データの利用・共有

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 2-1 | 第三者への情報提供がないこと | 無料版はGoogle Mobile Ads SDK経由で広告識別子等をGoogleに提供する（プライバシーポリシーに開示済み）。それ以外の解析SDK等はなし | ⚠️ 「提供なし」ではなく「広告SDK経由の提供あり、開示済み」が正確な状態。App Privacyアンケートとの整合が必要（1-4参照） |
| 2-2 | ユーザーが処理したPDF/Office文書の内容が外部サーバーに送信されないこと | 全変換処理がオンデバイス（`OfficeDocumentBuilder`/`OfficeDocumentReader`等はローカルのZIP/XMLパーサー）。ネットワークコードは広告SDK関連を除き不在 | ✅ 問題なし。**審査担当者向けApp Review Notesに「PDF/Office文書の内容自体は通信を一切行わない」旨を明記することを推奨**（広告SDKの存在と混同されないため） |

## 3. Guideline 2.5.2 — アプリのパフォーマンス

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 3-1 | 端末の機能・性能に見合った動作であること（過度なリソース消費でOSやデバイスに悪影響を与えない） | `docs/qa/device-verification-checklist.md`のメモリ・発熱項目で実機検証必須。特にサイズ上限チェックのない機能（結合・圧縮・分割・透かし・ページ編集・パスワード保護・署名）への超大容量ファイル投入時のJetsam発生リスクあり | ⚠️ **実機検証結果待ち**。Jetsamが頻発する場合は審査でリジェクトされ得るため、ファイルサイズ上限ガードの追加を検討 |
| 3-2 | クラッシュ・フリーズがないこと | ユニットテスト23件は正常系・一部異常系をカバーするが、`docs/qa/edge-case-test-scenarios.md`記載の意地悪ケース（0バイト・破損ファイル・Zip Bomb等）は未検証 | ⚠️ 実機・意地悪テスト完了後に判定 |
| 3-3 | Office変換の進捗表示が実処理と乖離していないこと | `OfficeConvertViewModel.convert()`は実変換処理からのコールバック（`progressHandler`）で`progress`を更新する実装に変更済み。ダミー固定アニメーションは存在しない | ✅ 解消済み（2026-08-13確認） |
| 3-4 | `PDFService.inspect(url:)`が未実装（`fatalError`）のまま製品コードに残っていないこと | `nonisolated func inspect(url:)`は`PDFDocument`からページ数・ファイルサイズ・タイトルを返す実装になっており、`fatalError`は存在しない | ✅ 解消済み（2026-08-13確認） |
| 3-5 | バックグラウンド遷移時に処理が破綻しないこと | `scenePhase`監視・`beginBackgroundTask`が未実装。`device-verification-checklist.md`セクション3参照 | ⚠️ 実機検証必須。フリーズ・不整合UIが再現する場合は審査前に修正推奨 |

## 4. Guideline 2.1 / 2.3.1 — アプリの完成度・メタデータの正確性

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 4-1 | 説明文・スクリーンショットが実際の機能と一致していること | `docs/app-store-metadata.md`は「PDF ↔ Office変換」をタイトルに含める前提で書かれている。**現在は実装済みのため、この文言をそのまま使ってよい**（旧メモの「Mockのまま申請するとリジェクトリスク」という注記はもはや該当しない） | ⚠️ `app-store-metadata.md`内の「提出前の確認事項」セクションが古いままなので、実装完了を反映して更新すること |
| 4-2 | プレースホルダー・仮テキスト・デバッグ表示が製品ビルドに残っていないこと | `PrivacyPolicyView`は実文面化済み。他画面（ヘルプ文言等）にダミーテキストが残っていないか全画面を目視レビュー | ⚠️ 未確認。QA工程で全画面のUIレビューを実施すること |
| 4-3 | スクリーンショット（`docs/screenshot-copy.md`）が最新UIと一致していること | ファイルは存在するが、実機/最新シミュレータでの見た目と乖離していないか未確認 | ⚠️ 申請直前に実機スクリーンショットで再撮影・突合すること |
| 4-4 | リリースノート（`docs/release-notes.md`）の内容が実際の変更点と一致していること | 内容未突合 | ⚠️ 申請前に最終確認 |
| 4-5 | 広告SDKが本番用の設定になっていること | `project.yml`の`GADApplicationIdentifier`がGoogle公式のテスト用サンプルID（`ca-app-pub-3940256099942544~1458002511`）のまま（2026-08-13確認） | 🛑 **要対応**: Google AdMobで実際のアプリ・広告ユニットを作成し、本番のApp ID・広告ユニットIDに差し替えること。テストID・テスト広告ユニットのまま申請するとGoogleポリシー違反・審査リジェクトのリスクがある |

## 5. Guideline 2.3.9 / 輸出コンプライアンス（暗号化）

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 5-1 | `ITSAppUsesNonExemptEncryption`の設定妥当性 | 現状`false`（輸出コンプライアンス上「対象外」を申告）に設定。しかし本アプリはPDFのパスワード保護機能（PDFKitの暗号化API）を実装しており、**標準的な公開された暗号化アルゴリズムを使い、かつユーザー自身のファイル保護のみに用いる**用途は多くの場合Appleの輸出コンプライアンス上「exempt（適用除外）」に該当するが、自己判断せずApp Store Connect提出時の輸出コンプライアンス質問（暗号化の有無・自己分類）に正確に回答すること | ⚠️ **要最終確認**。誤った申告は審査遅延・アカウントリスクに直結するため、提出直前に最新のApple輸出コンプライアンスガイド（Encryption and Export Compliance）と照合すること |

## 6. Guideline 4.2 — 最小限の機能性

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 6-1 | Webビューのラッパーに留まらない、ネイティブ機能を持つこと | PDFKit/Vision/VisionKit/PencilKitを用いたネイティブ機能が12種実装済み | ✅ 問題なし |
| 6-2 | 既存アプリと差別化される独自価値があること | PDF↔Office双方向変換・OCR・電子署名・透かし等を単一アプリで完結、かつオンデバイス処理を強みとして訴求 | ✅ 問題なし（マーケティング上の訴求ポイントとしても有効） |

## 7. Guideline 3.1.1 / 3.1.2 — 自動更新サブスクリプション（PDF One Pro）

> v1.0はサブスクリプション（`com.pdfone.pro.monthly` / `com.pdfone.pro.yearly`）込みで申請する方針。**2026-08-13時点で7-1〜7-5（コード側）は実装済みを確認。残るはASC側の設定（7-6〜7-8）と実機でのフロー確認（7-7）。**

| # | 項目 | 現状確認 | 判定 |
|---|---|---|---|
| 7-1 | `SubscriptionManager`（StoreKit 2）の実装状況 | `Transaction.updates`監視・購読状態の即時反映ロジックを実装済み。監視タスクの明示的キャンセル（リーク対策）も2026-08-13に追加しコミット済み | ✅ 実装済み |
| 7-2 | ペイウォールUI・購入導線の実装 | `ToolsView`が`tool.isPro && !isProUser`判定でタップ時に`PaywallView`をシート表示。Pro対象5View自身も直接ガードする二重構成 | ✅ 実装済み |
| 7-3 | 機能ゲート（無料/Pro機能の切り分け）の実装 | 電子署名・OCR・透かし・PDF→Office・Office→PDFの5ツールを`ToolItem.isPro`でPro指定、残り6ツールは無料 | ✅ 実装済み |
| 7-4 | 「購入を復元」ボタンの実装（Guideline必須要件） | `PaywallViewModel`・`SettingsView`に復元導線を実装済み | ✅ 実装済み |
| 7-5 | サブスクリプション利用規約（Appleひな形＋自社利用規約へのリンク） | `docs/terms-of-service.md`第11条に購読条項を記載済み（利用規約は2026-08-13にGitHub Pagesで公開: https://koboinfo.github.io/pdf-one-legal/terms-of-service.html ） | ✅ 実装済み。App概要文からのリンク設置はASC入力時に対応 |
| 7-6 | App Store Connect側のサブスクリプショングループ・価格・ローカライズ設定 | 未作成（ASC作業、Team ID確定後にASCへアクセス可能になり次第着手） | ⚠️ ASC側で「サブスクリプショングループ」作成、月額/年額プロダクトの価格・表示名・説明文（日本語）を登録する必要あり |
| 7-7 | `Subscriptions.storekit`でのローカル購入/復元フロー動作確認 | コードは実装済みだが、この開発環境では`SKTestSession`が`SKInternalErrorDomain Code=3`で機能せず、`SubscriptionManagerTests`（10件）が実行不能（2026-08-13再確認）。ビルド・他101件のテストは成功 | ⚠️ Xcode GUIでの`Cmd+U`実行、Mac再起動、または実機での確認が必要（HANDOFF.md記載の既知の環境問題） |
| 7-8 | 有料アプリ契約（Paid Apps Agreement）の締結状況 | App Store Connect「契約/税金/口座情報」で未確認（Developer Program登録完了後に確認可能） | ⚠️ 未締結の場合、IAPを含むビルドが審査に出せないため要確認 |

## 8. 審査ノート（App Review Information）作成時の推奨記載事項

審査担当者がオフライン動作・全機能を迷わず確認できるよう、App Store Connectの「レビュー用メモ」に以下を明記することを推奨する。

- 本アプリは通信を一切行わず、すべての処理が端末内で完結すること
- ログイン・アカウント作成が不要であること（該当する場合）
- Office変換機能（PDF↔Word/Excel/PowerPoint）の検証用サンプルファイルの案内（`SampleFiles/`を参考に審査用テストファイルを用意し、審査メモに使用手順を記載）
- カメラ・写真ライブラリへのアクセスが必要な機能とその代替手段（権限拒否時も他機能は利用可能である旨）

## 9. 申請直前の最終チェック（提出当日）

- [ ] `docs/app-store-metadata.md`・`README.md`・`HANDOFF.md`の実装状況記載を最新化した
- [ ] プライバシーポリシーを公開URLでホスティングし、App Store ConnectのURL欄に設定した
- [ ] App Privacyアンケートの回答が実態と一致していることを提出画面上で再確認した（サブスク導入後は「データは収集されません」に加え、購読状態のローカル保存についても実態と齟齬がないか再確認）
- [ ] 輸出コンプライアンスの質問に正確に回答した（セクション5参照）
- [ ] 実機（`device-verification-checklist.md`）でのクラッシュ・フリーズ・過度な発熱がないことを確認した
- [ ] 意地悪テスト（`edge-case-test-scenarios.md`）で重大なクラッシュが解消されていることを確認した
- [ ] スクリーンショット・説明文が最新UI/機能と一致していることを確認した
- [ ] **（サブスク関連・セクション7）** ペイウォールUI・機能ゲート・復元ボタンが実装され、実機で購入/復元フローの動作確認が完了した
- [ ] **（サブスク関連）** App Store Connectでサブスクリプショングループ・価格・ローカライズ説明文を設定した
- [ ] **（サブスク関連）** 有料アプリ契約（Paid Apps Agreement）が締結済みであることを確認した
- [ ] **（サブスク関連）** `docs/terms-of-service.md`に購読条項を追記し、App概要文からリンクした
- [ ] AdMobの本番App ID・広告ユニットIDに差し替えた（テストIDのまま申請しない）
- [ ] App Privacyアンケートで広告識別子（IDFA）のトラッキング利用を正確に申告した（「データ収集なし」は選択しない）
