import AuthenticationServices
import SwiftUI

struct SignInView: View {
    private enum Mode {
        case signIn, signUp

        var actionTitle: String { self == .signIn ? "Sign In" : "Create Account" }
        var toggleTitle: String {
            self == .signIn ? "Don't have an account? Sign up" : "Already have an account? Sign in"
        }
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var isValid: Bool {
        email.contains("@") && password.count >= 8
    }

    var body: some View {
        ZStack {
            KadenceTheme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Kadence")
                    .font(KadenceTheme.displayFont(40))
                    .foregroundStyle(KadenceTheme.textPrimary)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(KadenceTheme.surface)
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    SecureField("Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .padding(12)
                        .background(KadenceTheme.surface)
                        .foregroundStyle(KadenceTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if mode == .signUp {
                        Text("At least 8 characters")
                            .font(KadenceTheme.bodyFont(12))
                            .foregroundStyle(KadenceTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 320)

                Button(action: submit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(mode.actionTitle)
                                .font(KadenceTheme.bodyFont(16))
                        }
                    }
                    .frame(maxWidth: 320, minHeight: 44)
                }
                .background(isValid ? KadenceTheme.piscesTeal : KadenceTheme.surface)
                .foregroundStyle(isValid ? KadenceTheme.bg : KadenceTheme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!isValid || isSubmitting)

                Button(mode.toggleTitle) {
                    mode = mode == .signIn ? .signUp : .signIn
                    errorMessage = nil
                    infoMessage = nil
                }
                .font(KadenceTheme.bodyFont(13))
                .foregroundStyle(KadenceTheme.textMuted)

                if AuthFeatureFlags.appleSignInEnabled {
                    SignInWithAppleButton(.signIn) { request in
                        AuthService.shared.prepareAppleRequest(request)
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .frame(maxWidth: 280)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.ariesEmber)
                        .multilineTextAlignment(.center)
                }
                if let infoMessage {
                    Text(infoMessage)
                        .font(KadenceTheme.bodyFont(12))
                        .foregroundStyle(KadenceTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                switch mode {
                case .signIn:
                    try await AuthService.shared.signIn(email: email, password: password)
                case .signUp:
                    try await AuthService.shared.signUp(email: email, password: password)
                    infoMessage = "Check your email to confirm your account."
                }
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await AuthService.shared.completeAppleSignIn(authorization)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SignInView()
}
