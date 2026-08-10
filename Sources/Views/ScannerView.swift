import SwiftUI
import VisionKit

struct ScannerView: View {
    @State private var viewModel = ScannerViewModel()
    @State private var isShowingCamera = false
    @State private var isShowingShareSheet = false

    private var isCameraSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        NavigationStack {
            Group {
                if let outputURL = viewModel.outputURL {
                    resultView(outputURL: outputURL)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("スキャナー")
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            DocumentCameraView(
                onFinish: { scan in
                    isShowingCamera = false
                    Task { await viewModel.savePDF(from: scan) }
                },
                onCancel: { isShowingCamera = false },
                onError: { error in
                    isShowingCamera = false
                    viewModel.errorMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let outputURL = viewModel.outputURL {
                ActivityView(activityItems: [outputURL])
            }
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "camera.viewfinder",
            title: "書類をスキャンしてPDFを作成します",
            message: isCameraSupported ? nil : "このデバイスではスキャナーを利用できません。",
            actionTitle: isCameraSupported ? "スキャンを開始" : nil
        ) {
            isShowingCamera = true
        }
    }

    private func resultView(outputURL: URL) -> some View {
        VStack(spacing: 0) {
            PDFPreviewView(url: outputURL)

            VStack(spacing: 12) {
                PrimaryButton(title: "共有する", systemImage: "square.and.arrow.up", style: .bordered) {
                    isShowingShareSheet = true
                }
                PrimaryButton(title: "再スキャン", systemImage: "camera.viewfinder") {
                    isShowingCamera = true
                }
            }
            .padding()
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("PDFを作成中…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ScannerView()
}
