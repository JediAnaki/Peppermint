import Foundation
import LocalAuthentication

class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private init() {}

    enum BiometricType {
        case none
        case touchID
        case faceID
    }

    /// Determines what type of biometric authentication is available
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            return .none
        }
    }

    /// Checks if biometric authentication is available
    var isBiometricAvailable: Bool {
        return biometricType != .none
    }

    /// Authenticates the user using biometrics
    /// - Parameters:
    ///   - reason: The reason for requesting authentication
    ///   - completion: Callback with success/failure result
    func authenticate(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }

        // Perform authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                             localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                completion(success, authError)
            }
        }
    }

    /// Authenticates using either biometrics or device passcode
    /// - Parameters:
    ///   - reason: The reason for requesting authentication
    ///   - completion: Callback with success/failure result
    func authenticateWithFallback(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        var error: NSError?

        // Check if authentication is available (biometrics or passcode)
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false, error)
            return
        }

        // Perform authentication with passcode fallback
        context.evaluatePolicy(.deviceOwnerAuthentication,
                             localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                completion(success, authError)
            }
        }
    }
}
