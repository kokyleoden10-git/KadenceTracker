import Foundation

/// Sign in with Apple needs a configured Apple Developer Services ID + a
/// matching Supabase Auth provider before it works end to end (see
/// README). Flip this on once that's done — the button and its wiring stay
/// in place either way, just hidden until then.
enum AuthFeatureFlags {
    static let appleSignInEnabled = false
}
