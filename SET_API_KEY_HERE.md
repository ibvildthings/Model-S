# 🔑 Set Your Google Maps API Key Here

## Current Status
❌ API key is still set to placeholder `"YOUR_GOOGLE_MAPS_API_KEY"`

## Where to Add Your API Key

**File:** `Model S/Core/Services/Map/MapServiceProtocols.swift`
**Line:** 146

### Current Code (line 144-147):
```swift
static let google = MapServiceConfiguration(
    provider: .google,
    apiKey: "YOUR_GOOGLE_MAPS_API_KEY" // Replace with actual API key
)
```

### Change it to:
```swift
static let google = MapServiceConfiguration(
    provider: .google,
    apiKey: "AIzaSyD...your-actual-key-here..." // Your Google Maps API key
)
```

## How to Get Your API Key

1. Go to: https://console.cloud.google.com/
2. Select your project (or create one)
3. Click "APIs & Services" → "Credentials"
4. Click "Create Credentials" → "API Key"
5. Copy the key (it starts with `AIza`)

## Required APIs to Enable

Make sure these are enabled in your Google Cloud project:

- ✅ Maps SDK for iOS
- ✅ Places API
- ✅ Geocoding API
- ✅ Directions API

Enable them at: https://console.cloud.google.com/apis/library

## Steps to Add Your Key

### In Xcode:

1. **Open the file:**
   - In Xcode's Project Navigator
   - Navigate to: `Model S` → `Core` → `Services` → `Map` → `MapServiceProtocols.swift`
   - Or press `Cmd + Shift + O` and type "MapServiceProtocols"

2. **Go to line 146:**
   - Press `Cmd + L` to open "Go to Line"
   - Type `146` and press Enter

3. **Replace the placeholder:**
   - Find: `"YOUR_GOOGLE_MAPS_API_KEY"`
   - Replace with: `"AIza...your-key..."`
   - Keep the quotes!

4. **Save the file:**
   - Press `Cmd + S`

5. **Build and run:**
   - Press `Cmd + B` to build
   - Press `Cmd + R` to run

## Verify It Works

After running the app, check the console (Cmd + Shift + Y):

### ✅ Success - You'll see:
```
✅ Google Maps SDK initialized with key: AIzaSyD...
```

### ❌ Still not working - You'll see:
```
⚠️ Google Maps API key not configured - using Apple Maps
💡 Add your API key in MapServiceProtocols.swift line 146
```

## Example

**Before:**
```swift
apiKey: "YOUR_GOOGLE_MAPS_API_KEY"
```

**After:**
```swift
apiKey: "AIzaSyBdVl-cTICSwYKrNQGpZUWW4CwTW7xXxXx"
```
(This is an example - use your own key!)

## Security Note

⚠️ **Important:** Don't commit your API key to public repositories!

For production:
- Use environment variables
- Restrict your API key to your bundle ID
- Set up billing alerts

## Still Having Issues?

1. Make sure you saved the file after editing
2. Clean build folder: `Product` → `Clean Build Folder` (Shift + Cmd + K)
3. Rebuild: `Product` → `Build` (Cmd + B)
4. Check the console output when app launches

## Need More Help?

See: `GOOGLE_MAPS_SETUP.md` for complete setup instructions
