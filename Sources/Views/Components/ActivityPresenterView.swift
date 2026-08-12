import SwiftUI

/// `UIActivityViewController`は本来モーダル`present`前提のView Controllerであり、
/// `.sheet`のコンテンツとして直接埋め込むと共有アクションが正しく完了しない/シートが閉じないことがある。
/// このViewは自身のUIViewControllerから`present`することで、共有ボタンが確実に動作するようにする。
struct ActivityPresenterView: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented, uiViewController.presentedViewController == nil {
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = uiViewController.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: uiViewController.view.bounds.midX,
                y: uiViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            uiViewController.present(activityVC, animated: true)
        } else if !isPresented, uiViewController.presentedViewController != nil {
            uiViewController.dismiss(animated: true)
        }
    }
}
