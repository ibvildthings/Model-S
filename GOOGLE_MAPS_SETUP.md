# Google Maps Setup (optional)

The app works with Apple Maps out of the box. Google Maps adds Google
Places search, Geocoding and Directions.

## 1. SDK

The project already references the Google Maps SDK via Swift Package Manager
(`https://github.com/googlemaps/ios-maps-sdk`). If Xcode reports
`No such module 'GoogleMaps'`, use **File → Packages → Resolve Package Versions**.

## 2. API key

1. In [Google Cloud Console](https://console.cloud.google.com/), enable
   **Maps SDK for iOS**, **Places API**, **Geocoding API** and **Directions API**,
   then create an API key (restrict it to your bundle ID).
2. Copy the template and add your key:

   ```bash
   cp "Model S/Core/Configuration/Secrets.example.plist" "Model S/Core/Configuration/Secrets.plist"
   ```

   Set `GoogleMapsAPIKey` in `Secrets.plist`. The file is gitignored. Never
   commit it.
3. Build and run. Google Maps appears in the map switcher and in
   **Home → ⚙︎ Map settings**.

Without a key, Google Maps shows as "Not configured" and Apple Maps is used.
