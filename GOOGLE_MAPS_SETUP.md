# Google Maps SDK Integration Guide

## Current Issue
**Error:** `No such module 'GoogleMaps'`

This means the Google Maps SDK isn't properly linked to your Xcode project yet.

## Solution Options

### Option 1: Swift Package Manager (Recommended)

**Step 1:** In Xcode, go to:
```
File → Add Package Dependencies...
```

**Step 2:** Add Google Maps SDK URLs:
```
https://github.com/googlemaps/ios-maps-sdk
```

**OR** (Better - Official package):
```
https://github.com/googlemaps/google-maps-ios-utils
```

**Step 3:** Select your target "Model S" and add these packages:
- GoogleMaps
- GoogleMapsBase
- GoogleMapsCore

**Step 4:** In your target's "Frameworks, Libraries, and Embedded Content":
- Verify GoogleMaps.framework is present
- Set to "Do Not Embed"

**Step 5:** Clean build folder:
```
Product → Clean Build Folder (Shift + Cmd + K)
```

**Step 6:** Rebuild project

---

### Option 2: CocoaPods (Alternative)

**Step 1:** Create `Podfile` in project root:
```ruby
platform :ios, '15.0'

target 'Model S' do
  use_frameworks!

  # Google Maps
  pod 'GoogleMaps', '~> 8.4.0'
  pod 'GooglePlaces', '~> 8.4.0'
end
```

**Step 2:** Install pods:
```bash
cd "/path/to/Model-S"
pod install
```

**Step 3:** Close Xcode

**Step 4:** Open `Model S.xcworkspace` (NOT .xcodeproj!)

**Step 5:** Build project

---

### Option 3: Manual Framework (Not Recommended)

Download from: https://developers.google.com/maps/documentation/ios-sdk/start

---

## Verify Integration

After adding the package, verify it works:

**Test 1:** Build the project
```
Cmd + B
```
Should build without "No such module 'GoogleMaps'" error

**Test 2:** Check imports in Xcode
```swift
import GoogleMaps  // Should autocomplete
```

**Test 3:** Run the app
- Console should show: "✅ Google Maps SDK initialized"
- Map should display Google Maps tiles

---

## Troubleshooting

### Problem: Package added but still getting error

**Solution:**
1. In Xcode: `Product → Clean Build Folder`
2. Close Xcode completely
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen project
5. Rebuild

### Problem: "Framework not found GoogleMaps"

**Solution:**
1. Go to Target → Build Settings
2. Search for "Framework Search Paths"
3. Verify paths are correct
4. Add if needed: `$(PROJECT_DIR)/path/to/GoogleMaps`

### Problem: Using CocoaPods but opening wrong file

**Solution:**
- Always open `Model S.xcworkspace`
- NOT `Model S.xcodeproj`

---

## Current Workaround

Until the SDK is properly integrated, the code will use Apple Maps automatically.

The architecture supports this - when Google Maps SDK is not available:
- Services use Google APIs (search, geocoding, routes)
- Map display falls back to Apple Maps
- Everything still works!

---

## Verification Checklist

- [ ] Package added via SPM or CocoaPods
- [ ] Clean build folder
- [ ] Project builds without errors
- [ ] `import GoogleMaps` autocompletes
- [ ] App runs and shows Google Maps
- [ ] Console shows "✅ Google Maps SDK initialized"

---

## Next Steps

1. Add the package using Option 1 (SPM) above
2. Clean and rebuild
3. If still having issues, let me know which step failed
4. I can help debug the specific issue

The code is ready - you just need to complete the Xcode package integration!
