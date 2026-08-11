# サブスクリプション機能 検証結果・動作確認チェックリスト

制定日：2026年8月11日
対象: PDF One / StoreKit 2ベースの「PDF One Pro」サブスクリプション

## 1. 実装内容サマリー

| 項目 | 内容 |
|---|---|
| 課金モデル | 自動更新サブスクリプション（`com.pdfone.pro.monthly` 480円/月、`com.pdfone.pro.yearly` 4,800円/年） |
| 無料トライアル | 月額・年額とも7日間（`Subscriptions.storekit`の`introductoryOffer`、`paymentMode: free` / `subscriptionPeriod: P1W` / `numberOfPeriods: 1`） |
| 無料機能 | 結合・画像→PDF・圧縮・ページ編集・PDF→JPG・分割・パスワード設定 |
| Pro限定機能 | 電子署名・OCR・透かし・PDF→Office変換・Office→PDF変換（`ToolItem.isPro`） |
| 購入導線 | `ToolsView`でPro機能タップ時に`PaywallView`をsheet表示、`SettingsView`に「Proにアップグレード」導線 |
| 機能ゲート | Pro対象の5画面（`SignatureView`/`OCRView`/`WatermarkView`/`OfficeConvertView`/`OfficeToPDFView`）それぞれが`SubscriptionManager.isSubscribed`を直接参照し、未購読なら`PaywallView`を表示（ツール一覧を経由しない直接遷移に対する二重ガード） |
| 復元 | `PaywallView`・`SettingsView`双方に「購入を復元」ボタン（`AppStore.sync()` → `Transaction.currentEntitlements`再計算） |
| 購読管理 | `SettingsView`に現在のプラン・トライアル状態・次回更新日を表示、「サブスクリプションを管理」から`https://apps.apple.com/account/subscriptions`へ遷移 |
| 法務対応 | `PrivacyPolicyView`・`TermsOfServiceView`にサブスク条項を追加、`docs/qa/faq-support.md`を課金内容に合わせて更新 |

## 2. 自動検証結果

### 2.1 ビルド
- `xcodegen generate` → `./build.sh`（`DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"`）で**ビルド成功**を確認済み。
- StoreKit 2 / StoreKitTestの型・メソッドシグネチャは、Xcode 26.6同梱SDKの`.swiftinterface`・ヘッダー（`SKTestSession.h`等）と突き合わせて実装しており、コンパイルエラーなし。

### 2.2 既存テスト（サブスク以外）
- 全94件中、サブスク以外の**84件はすべて成功**（PDFService・Office変換・保存済みファイル・設定画面・キャッシュ管理など）。今回の変更による既存機能への回帰は確認されていない。

### 2.3 新規追加: `Tests/SubscriptionManagerTests.swift`（StoreKitTestベース、10件）

| テスト | 検証内容 |
|---|---|
| `testLoadProductsPopulatesMonthlyAndYearlySortedByPrice` | プロダクト取得・価格順ソート |
| `testPurchaseGrantsEntitlementAndCachesLocally` | 購入 → `isSubscribed`反映 |
| `testFreeTrialAppliesIntroductoryOfferWithSevenDayExpiration` | 7日間トライアルの適用・失効日 |
| `testIsEligibleForIntroOfferBecomesFalseAfterSubscribingInSameGroup` | 同一グループ内でのトライアル対象外化 |
| `testAskToBuyPendingPurchaseThrowsPurchasePendingError` | Ask to Buy（保留）時のエラー分岐 |
| `testDisablingAutoRenewKeepsAccessUntilExpiration` | キャンセル後も期間終了までアクセス継続 |
| `testExpireSubscriptionRevokesAccess` | 期限切れでのアクセス剥奪 |
| `testRefundedTransactionRevokesAccess` | 返金・失効でのアクセス剥奪 |
| `testRestorePurchasesSyncsEntitlementsOnFreshInstall` | 再インストール相当の復元 |
| `testRestorePurchasesWithNoPurchaseHistoryLeavesUnsubscribed` | 購入履歴なしでの復元 |

**⚠️ 現時点でこの10件は本環境では実行不能（後述の環境要因により`SKInternalErrorDomain`エラーで全滅）。テストコード自体はSDKヘッダーに基づき実装しており、実行環境（実機/別Mac/Xcode GUI経由）が整えば動作する見込み。**

## 3. 既知の未解決事項：StoreKitローカルテストが本環境で動作しない

### 3.1 症状
`SKTestSession`生成直後から`Error saving configuration file: Error Domain=SKInternalErrorDomain Code=3`が発生し、`Product.products(for:)`が常に空配列を返す。

### 3.2 切り分け結果（すべて再現）
- シミュレータの`erase`、別シミュレータ（iPhone 17e）への切り替え → 変化なし
- `CoreSimulatorService`の再起動 → 変化なし
- ネットワークアクセスの許可有無 → 変化なし
- `Subscriptions.storekit`を購入前の状態（`introductoryOffer: null`）に戻す → 変化なし（今回追加した設定内容が原因ではないことを確認）
- **Xcode/シミュレータを一切介さない、macOSネイティブの最小Swiftスクリプトで`SKTestSession(contentsOf:)`を直接実行 → 同種のエラーを再現**（xcodebuildやXCTestの問題ではないことを確認）

### 3.3 根本原因
`log show`でシステムログを確認したところ、以下が記録されていた。

```
storekitagent: Error initializing client from XPC connection: 操作を完了できませんでした（storekitagent.Client.ClientError エラー0）
(Sandbox) Sandbox: amsengagementd(...) deny(1) mach-lookup com.apple.coreservices.launchservicesd
(Sandbox) Sandbox: amsengagementd(...) deny(1) file-write-create /Users/.../Library/HTTPStorages/com.apple.amsengagementd
```

macOS側のApp Store関連システムデーモン（`storekitagent`・`amsengagementd`）がこのユーザーアカウント上でサンドボックス拒否を受けており、StoreKitテスト用のローカルXPC接続を初期化できていない。**アプリのコード・`Subscriptions.storekit`の設定・テストコードの不備ではなく、この実行環境（Mac/ユーザーアカウント）側でStoreKitテストデーモンが未整備であることに起因する。**

### 3.4 推奨対応
- **Xcode GUIから`Cmd+U`でテストを実行**（GUI経由のXcodeは完全な権限でこれらのデーモンと通信できるため、動作する可能性が高い）
- それでも同じエラーが出る場合は、一度App Store.appを開いてApple IDでのサインイン状態を確認する、またはMacを再起動してからXcodeで再実行する
- 上記のいずれでも解消しない場合は、実機でのローカルテスト（Xcode ▶ Product ▶ Scheme ▶ Edit Scheme ▶ Test ▶ Options でStoreKit Configurationを指定）を試す

## 4. 手動動作確認チェックリスト（Xcode/シミュレータで`Cmd+U`実行が可能になった後、または実機で）

### 4.1 購入フロー
- [ ] Pro限定ツール（OCR等）をタップ → ペイウォールが表示される
- [ ] 月額・年額それぞれの価格・「7日間無料トライアル付き」表示が正しい
- [ ] 「7日間無料で始める」→ 購入後、自動的にツール画面へ遷移する
- [ ] 購入後、Pro限定の5ツールすべてがロック解除される
- [ ] 設定画面に現在のプラン・トライアル状態・トライアル終了日が表示される

### 4.2 トライアル・キャンセル・期限切れ
- [ ] StoreKitテスト設定でトランザクションの自動更新をOFFにしても、期間終了までPro機能が使える（`disableAutoRenewForTransaction`相当）
- [ ] `Manage Transactions`から`Expire Subscription`を実行 → 次回`refreshEntitlements`後にPro機能がロックされる
- [ ] `Manage Transactions`から`Refund Transaction`を実行 → 同様にロックされる

### 4.3 復元
- [ ] アプリを削除・再インストール（またはStoreKitテストのトランザクションをクリア後、既存Apple IDで購入だけ残す）→「購入を復元」でPro状態が復帰する
- [ ] 購入履歴がない状態で「購入を復元」→ エラーなくトースト表示のみで完了する

### 4.4 UI/導線
- [ ] ペイウォールに閉じる（×）ボタンがあり、購入せずに閉じられる
- [ ] ペイウォールから「利用規約」「プライバシーポリシー」がそれぞれ開ける
- [ ] 設定画面「サブスクリプションを管理」タップでApp Storeのサブスクリプション管理ページへ遷移する

### 4.5 App Store申請前の追加確認（別途）
- [ ] App Store Connect側で実際のサブスクリプション商品（`com.pdfone.pro.monthly` / `com.pdfone.pro.yearly`）とトライアルオファーを設定
- [ ] Sandboxアカウントでの実購入テスト
- [ ] `docs/qa/app-store-review-checklist.md`のサブスク関連項目との突き合わせ
