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
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isPulsing = false

    private var passwordsMatch: Bool { password == confirmPassword }

    private var isValid: Bool {
        guard email.contains("@"), password.count >= 8 else { return false }
        return mode == .signIn || passwordsMatch
    }

    var body: some View {
        ZStack {
            KadenceTheme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(KadenceTheme.piscesTeal.opacity(isPulsing ? 0.5 : 0.22))
                            .frame(width: 176, height: 176)
                            .blur(radius: 22)
                            .scaleEffect(isPulsing ? 1.08 : 0.9)

                        Image("KadenceMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 148, height: 148)
                            .clipShape(Circle())
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }

                    Text("Kadence")
                        .font(KadenceTheme.displayFont(30))
                        .foregroundStyle(KadenceTheme.textPrimary)
                }
                .padding(.bottom, 8)

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

                    PasswordField(
                        placeholder: "Password",
                        text: $password,
                        textContentType: mode == .signUp ? .newPassword : .password
                    )

                    if mode == .signUp {
                        PasswordField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            textContentType: .newPassword
                        )

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords don't match")
                                .font(KadenceTheme.bodyFont(12))
                                .foregroundStyle(KadenceTheme.ariesEmber)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("At least 8 characters")
                                .font(KadenceTheme.bodyFont(12))
                                .foregroundStyle(KadenceTheme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
                    confirmPassword = ""
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
                    // If email confirmation is required, signUp succeeds but
                    // no session is issued yet — otherwise the auth state
                    // listener already flips ContentView over to HomeView.
                    if AuthService.shared.session == nil {
                        infoMessage = "Check your email to confirm your account."
                    }
                }
                password = ""
                confirmPassword = ""
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

/// SecureField with a standard eye-icon reveal toggle. Swaps to a plain
/// TextField while revealed — SwiftUI has no built-in "show password" mode
/// on SecureField itself.
private struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    var textContentType: UITextContentType?

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(textContentType)
            .foregroundStyle(KadenceTheme.textPrimary)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(KadenceTheme.textMuted)
            }
        }
        .padding(12)
        .background(KadenceTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SignInView()
}
