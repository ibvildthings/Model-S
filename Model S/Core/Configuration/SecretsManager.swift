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
    private static var secrets: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("⚠️ WARNING: Secrets.plist not found!")
            print("   Create it from Secrets.example.plist and add your API keys")
            return nil
        }
        return plist
    }()

    /// Google Maps API Key
    static var googleMapsAPIKey: String? {
        if let key = secrets?["GoogleMapsAPIKey"] as? String,
           !key.isEmpty && key != "YOUR_GOOGLE_MAPS_API_KEY_HERE" && key != "YOUR_NEW_API_KEY_HERE" {
            return key
        }

        print("⚠️ Google Maps API key not configured")
        print("   1. Copy Secrets.example.plist to Secrets.plist")
        print("   2. Add your Google Maps API key to Secrets.plist")
        print("   3. Secrets.plist is gitignored and won't be committed")
        return nil
    }
}
