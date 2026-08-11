import AuthenticationServices
import Foundation

@Observable
@MainActor
final class SignInViewModel {

    var email: String = ""
    var password: String = ""
    var errorMessage: String?
    var isAuthenticating = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func unlockWithBiometrics() async {
        errorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await authService.unlockWithBiometrics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        do {
            try authService.handleAppleSignIn(result: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
