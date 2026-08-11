import AuthenticationServices
import LocalAuthentication
import SwiftUI

/// アプリロック画面。サーバー連携やアカウント基盤は持たず、Face ID/Touch IDでの解錠と
/// Sign in with Appleでのローカル識別のみを提供する。
struct SignInView: View {
    @Environment(AuthService.self) private var authService

    @State private var viewModel: SignInViewModel?
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        ScrollView {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .padding(.top, 80)
            }
        }
        .background(AppBackground())
        .task {
            if viewModel == nil {
                viewModel = SignInViewModel(authService: authService)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: SignInViewModel) -> some View {
        VStack(spacing: 24) {
            header

            VStack(spacing: 12) {
                TextField("メールアドレス", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )

                SecureField("パスワード", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.password)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .padding(.horizontal, 20)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            biometricButton(viewModel)

            appleSignInButton(viewModel)
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }
            Text("PDF One")
                .font(.title2.weight(.bold))
            Text("ロックを解除してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func biometricButton(_ viewModel: SignInViewModel) -> some View {
        PrimaryButton(
            title: biometricTitle,
            systemImage: biometricSystemImage,
            isProcessing: viewModel.isAuthenticating
        ) {
            Task { await viewModel.unlockWithBiometrics() }
        }
        .padding(.horizontal, 20)
    }

    private var biometricTitle: String {
        LAContext().biometryType == .faceID ? "Face IDでロック解除" : "Touch IDでロック解除"
    }

    private var biometricSystemImage: String {
        LAContext().biometryType == .faceID ? "faceid" : "touchid"
    }

    private func appleSignInButton(_ viewModel: SignInViewModel) -> some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = []
        } onCompletion: { result in
            viewModel.handleAppleSignIn(result: result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(Capsule(style: .continuous))
        .padding(.horizontal, 20)
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
