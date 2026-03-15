//
//  ServerConfig.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 1 - Setup: Server configuration for OpenSCAD REST API
//

import Foundation

/// Configuration for OpenSCAD server URL
struct ServerConfig {
    /// Base URL for OpenSCAD REST API server
    ///
    /// - Development: Uses localhost for local testing
    /// - Production: Uses user-configured server URL from Settings
    ///
    /// Users can self-host OpenSCAD server or use a trusted instance
    static var openSCADBaseURL: URL {
        #if DEBUG
        // Local development server for testing
        // Start local server with: `docker run -p 8080:8080 openscad-server`
        if let urlString = ProcessInfo.processInfo.environment["OPENSCAD_SERVER_URL"],
           let url = URL(string: urlString) {
            return url
        }
        return URL(string: "http://localhost:8080/api")!
        #else
        // Production: User-configured server URL
        if let urlString = UserDefaults.standard.string(forKey: "openscadServerURL"),
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }

        // Default fallback (user should configure in Settings)
        // This is a placeholder - users must set their own server
        return URL(string: "https://openscad.example.com/api")!
        #endif
    }

    /// Timeout interval for OpenSCAD API requests (in seconds)
    ///
    /// - Typical STL generation: 2-5 seconds for 5-15 compartments
    /// - Edge case (50 compartments): Up to 30 seconds
    static let apiTimeoutInterval: TimeInterval = 30

    /// Maximum retry attempts for failed API requests
    static let maxRetryAttempts: Int = 3

    /// Delay between retry attempts (exponential backoff: 1s, 2s, 4s)
    static func retryDelay(for attempt: Int) -> TimeInterval {
        return pow(2.0, Double(attempt - 1)) // 1s, 2s, 4s
    }
}

// MARK: - Server Configuration Settings

extension ServerConfig {
    /// Validates if the configured server URL is reachable
    /// - Returns: `true` if server responds to health check, `false` otherwise
    static func validateServerURL(_ url: URL) async -> Bool {
        do {
            let healthURL = url.appendingPathComponent("/health")
            let (_, response) = try await URLSession.shared.data(from: healthURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return httpResponse.statusCode == 200
        } catch {
            print("❌ Server validation failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates the OpenSCAD server URL in UserDefaults
    /// - Parameter urlString: New server URL (must be valid HTTPS or localhost HTTP)
    /// - Returns: `true` if URL is valid and saved, `false` otherwise
    @discardableResult
    static func updateServerURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        // Security check: Only allow HTTPS in production (except localhost)
        let isLocalhost = url.host == "localhost" || url.host == "127.0.0.1"

        #if !DEBUG
        if url.scheme != "https" && !isLocalhost {
            print("⚠️ Only HTTPS URLs are allowed in production (except localhost)")
            return false
        }
        #endif

        UserDefaults.standard.set(urlString, forKey: "openscadServerURL")
        print("✅ OpenSCAD server URL updated: \(urlString)")
        return true
    }

    /// Resets server URL to default
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "openscadServerURL")
        print("♻️ OpenSCAD server URL reset to default")
    }
}
