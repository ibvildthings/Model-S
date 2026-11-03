//
//  SecretsManager.swift
//  Model S
//
//  Secure secrets management - reads API keys from Secrets.plist (gitignored)
//  This prevents API keys from being committed to source control
//

import Foundation

enum SecretsManager {

    /// Loads secrets from Secrets.plist file
    private static let secrets: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            AppLog.info("Secrets.plist not found – create it from Secrets.example.plist to enable Google Maps")
            return nil
        }
        return plist
    }()

    /// Google Maps API key, or nil when Secrets.plist is missing or still has a placeholder.
    /// Resolved once; read freely (it is checked on every search keystroke).
    static let googleMapsAPIKey: String? = {
        let placeholders: Set<String> = ["YOUR_GOOGLE_MAPS_API_KEY", "YOUR_GOOGLE_MAPS_API_KEY_HERE", "YOUR_NEW_API_KEY_HERE"]
        if let key = secrets?["GoogleMapsAPIKey"] as? String,
           !key.isEmpty, !placeholders.contains(key) {
            return key
        }
        AppLog.info("Google Maps API key not configured – copy Secrets.example.plist to Secrets.plist and add GoogleMapsAPIKey")
        return nil
    }()
}
