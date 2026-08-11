import AuthenticationServices
import Foundation
import LocalAuthentication

enum AuthError: Error {
    case biometryUnavailable
    case biometryFailed
    case appleSignInFailed
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .biometryUnavailable:
            return "Face ID/Touch IDが利用できません。デバイスの設定をご確認ください。"
        case .biometryFailed:
            return "認証に失敗しました。もう一度お試しください。"
        case .appleSignInFailed:
            return "Appleでのサインインに失敗しました。もう一度お試しください。"
        }
    }
}

/// アプリロック（ローカル）の状態管理。サーバー連携やアカウント基盤は持たず、
/// Face ID/Touch IDによる解錠と、表示用のApple ID識別子のローカル保持のみを行う。
@Observable
@MainActor
final class AuthService {

    private(set) var isUnlocked: Bool
    private(set) var signedInAppleUserID: String?

    private let userDefaults: UserDefaults
    private static let appleUserIDKey = "com.pdfone.auth.appleUserID"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isUnlocked = false
        self.signedInAppleUserID = userDefaults.string(forKey: Self.appleUserIDKey)
    }

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func unlockWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometryUnavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "PDF Oneのロックを解除します"
            )
            guard success else { throw AuthError.biometryFailed }
            isUnlocked = true
        } catch {
            throw AuthError.biometryFailed
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) throws {
        guard
            case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            throw AuthError.appleSignInFailed
        }

        signedInAppleUserID = credential.user
        userDefaults.set(credential.user, forKey: Self.appleUserIDKey)
        isUnlocked = true
    }

    func lock() {
        isUnlocked = false
    }
}
