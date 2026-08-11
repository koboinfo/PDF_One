import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private static let effectiveDate = "2026年8月11日"
    private static let contactEmail = "info.kobo.jp@gmail.com"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("制定日：\(Self.effectiveDate)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    section(
                        title: "はじめに",
                        body: """
                        PDF One（以下「本アプリ」といいます）は、個人開発により提供されるPDF編集・変換アプリです。本ポリシーは、本アプリにおける利用者情報の取り扱いについて説明するものです。
                        """
                    )

                    section(
                        title: "1. 取得する情報",
                        body: """
                        本アプリは、利用者を識別する個人情報をサーバー等の外部に送信・収集することはありません。本アプリが取り扱う情報は次のとおりです。

                        ・PDFファイル、画像ファイル：結合・圧縮・変換・署名などの処理のため、利用者が選択したファイルを端末内でのみ処理します。
                        ・カメラ：書類スキャン機能の利用時にのみ、OS標準の権限確認を経てアクセスします。撮影した画像は端末内でPDF化する目的にのみ使用し、外部送信は行いません。
                        ・キャッシュデータ：処理中に一時的に生成されるファイルです。設定画面から手動で削除できます。
                        """
                    )

                    section(
                        title: "2. 情報の利用目的",
                        body: """
                        取得した情報は、本アプリが提供する機能（PDFの結合・分割・圧縮・変換・編集・署名・OCR等）を実行する目的にのみ使用し、上記目的以外での利用は行いません。
                        """
                    )

                    section(
                        title: "3. 第三者への提供",
                        body: """
                        本アプリは広告配信SDK・解析（アナリティクス）SDKを組み込んでおらず、利用者の情報を第三者に提供・共有することはありません。

                        ※将来的に広告表示や利用状況分析などの機能を追加する場合は、事前に本ポリシーを改定し、取得する情報の範囲・利用目的・提供先を明記します。
                        """
                    )

                    section(
                        title: "4. データの保存場所と削除",
                        body: """
                        利用者が処理したファイルおよび一時キャッシュは、いずれも利用者の端末内にのみ保存されます。本アプリの外部（クラウド等）に保存されることはありません。

                        設定画面の「キャッシュを削除」から、端末内に保存された一時ファイルをいつでも削除できます。
                        """
                    )

                    section(
                        title: "5. 権限について",
                        body: """
                        本アプリは書類スキャン機能のためにカメラへのアクセス権限を要求します。カメラへのアクセスはOSの設定からいつでも変更・取り消しが可能です。権限を許可しない場合でも、スキャン以外の機能は通常どおりご利用いただけます。
                        """
                    )

                    section(
                        title: "6. サブスクリプション（アプリ内課金）について",
                        body: """
                        本アプリは、一部の機能を利用するための有料サブスクリプション（自動更新型）を提供する場合があります。

                        ・決済処理：お支払いはApple（App Store）が処理し、クレジットカード番号等の決済情報を本アプリまたは開発者が取得・保存することはありません。
                        ・保存する情報：購読の有効・無効といったごく簡易な状態のみを、機能利用可否の判定のために端末内（アプリのローカル設定領域）に保存します。この情報が外部に送信されることはありません。
                        ・更新と解約：サブスクリプションは期間終了の24時間以上前にキャンセルしない限り自動的に更新されます。管理・解約は端末の「設定」アプリ内のApple ID＞サブスクリプションからいつでも行えます。
                        ・購入の復元：機種変更等の際は、アプリ内の「購入を復元」操作によりApple IDに紐づく購読状態を再取得できます。
                        """
                    )

                    section(
                        title: "7. 本ポリシーの変更",
                        body: """
                        法令の変更や本アプリの機能追加に伴い、本ポリシーの内容を予告なく変更する場合があります。変更後の内容は本画面に反映された時点で効力を生じるものとします。
                        """
                    )

                    section(
                        title: "8. お問い合わせ",
                        body: """
                        本ポリシーに関するお問い合わせは、下記の連絡先までお願いいたします。

                        運営：PDF One
                        連絡先：\(Self.contactEmail)
                        """
                    )
                }
                .padding()
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PrivacyPolicyView()
}
