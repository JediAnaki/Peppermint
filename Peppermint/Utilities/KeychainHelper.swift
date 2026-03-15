//
//  KeychainHelper.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 1 - Setup: Secure token storage using iOS Keychain
//

import Foundation
import Security

/// Helper for secure storage of sensitive data in iOS Keychain
///
/// **Use Case**: Store Apple Sign In identity tokens for alternative cloud providers
/// (Firebase, AWS S3) if user opts out of CloudKit
///
/// **Note**: For CloudKit-only implementation, this is used for future extensibility
struct KeychainHelper {

    // MARK: - Keychain Operations

    /// Saves a string value securely to Keychain
    /// - Parameters:
    ///   - value: The string to store (e.g., API token, identity token)
    ///   - key: Unique identifier for this value (e.g., "appleIdentityToken")
    /// - Returns: `true` if save succeeded, `false` otherwise
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ Failed to encode value for key: \(key)")
            return false
        }

        // Delete existing value if present (prevents duplicate key errors)
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // Available after device unlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ Keychain: Saved value for key '\(key)'")
            return true
        } else {
            print("❌ Keychain: Failed to save key '\(key)' (status: \(status))")
            return false
        }
    }

    /// Retrieves a string value from Keychain
    /// - Parameter key: Unique identifier for the value
    /// - Returns: The stored string, or `nil` if not found
    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true, // Return the actual data
            kSecMatchLimit as String: kSecMatchLimitOne // Only return first match
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("⚠️ Keychain: Failed to retrieve key '\(key)' (status: \(status))")
            }
            return nil
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            print("❌ Keychain: Failed to decode value for key '\(key)'")
            return nil
        }

        return value
    }

    /// Deletes a value from Keychain
    /// - Parameter key: Unique identifier for the value to delete
    /// - Returns: `true` if deletion succeeded or item didn't exist, `false` on error
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            if status == errSecSuccess {
                print("🗑️ Keychain: Deleted key '\(key)'")
            }
            return true
        } else {
            print("❌ Keychain: Failed to delete key '\(key)' (status: \(status))")
            return false
        }
    }

    /// Updates an existing Keychain value
    /// - Parameters:
    ///   - value: New value to store
    ///   - key: Unique identifier for the value
    /// - Returns: `true` if update succeeded, `false` otherwise
    @discardableResult
    static func update(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ Failed to encode value for key: \(key)")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            print("✅ Keychain: Updated value for key '\(key)'")
            return true
        } else if status == errSecItemNotFound {
            // Item doesn't exist, create it instead
            return save(value, forKey: key)
        } else {
            print("❌ Keychain: Failed to update key '\(key)' (status: \(status))")
            return false
        }
    }

    /// Checks if a value exists in Keychain
    /// - Parameter key: Unique identifier for the value
    /// - Returns: `true` if value exists, `false` otherwise
    static func exists(forKey key: String) -> Bool {
        return get(forKey: key) != nil
    }

    /// Clears all Keychain items stored by this app
    /// ⚠️ **Warning**: This is destructive and cannot be undone
    /// - Returns: `true` if successful, `false` otherwise
    @discardableResult
    static func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            print("🗑️ Keychain: Cleared all stored values")
            return true
        } else {
            print("❌ Keychain: Failed to clear all values (status: \(status))")
            return false
        }
    }
}

// MARK: - Predefined Keys

extension KeychainHelper {
    /// Predefined Keychain keys for this app
    enum Keys {
        /// Apple Sign In identity token (JWT)
        /// Used for authenticating with alternative cloud providers (Firebase, AWS)
        static let appleIdentityToken = "appleIdentityToken"

        /// Apple Sign In user identifier
        /// Persistent ID that doesn't change between app reinstalls
        static let appleUserIdentifier = "appleUserIdentifier"

        /// OpenSCAD API key (if server requires authentication)
        /// Optional: Only used if self-hosted server has auth enabled
        static let openscadAPIKey = "openscadAPIKey"
    }
}

// MARK: - Convenience Methods

extension KeychainHelper {
    /// Saves Apple Sign In credentials
    /// - Parameters:
    ///   - identityToken: JWT token from ASAuthorizationAppleIDCredential
    ///   - userIdentifier: User ID from ASAuthorizationAppleIDCredential
    static func saveAppleSignInCredentials(identityToken: String, userIdentifier: String) {
        save(identityToken, forKey: Keys.appleIdentityToken)
        save(userIdentifier, forKey: Keys.appleUserIdentifier)
        print("✅ Saved Apple Sign In credentials to Keychain")
    }

    /// Retrieves Apple Sign In identity token
    /// - Returns: JWT token if available, `nil` otherwise
    static func getAppleIdentityToken() -> String? {
        return get(forKey: Keys.appleIdentityToken)
    }

    /// Retrieves Apple Sign In user identifier
    /// - Returns: User ID if available, `nil` otherwise
    static func getAppleUserIdentifier() -> String? {
        return get(forKey: Keys.appleUserIdentifier)
    }

    /// Clears all Apple Sign In credentials (e.g., on sign out)
    static func clearAppleSignInCredentials() {
        delete(forKey: Keys.appleIdentityToken)
        delete(forKey: Keys.appleUserIdentifier)
        print("🗑️ Cleared Apple Sign In credentials from Keychain")
    }
}
