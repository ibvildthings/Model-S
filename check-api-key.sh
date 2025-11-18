#!/bin/bash

# Google Maps API Key Setup Verification Script
# Run this to check if your API key is properly configured

echo "🔍 Checking Google Maps Setup..."
echo ""

# Check if API key file exists
if [ ! -f "Model S/Core/Services/Map/MapServiceProtocols.swift" ]; then
    echo "❌ Cannot find MapServiceProtocols.swift"
    exit 1
fi

# Extract the API key
API_KEY=$(grep -A 1 "static let google = MapServiceConfiguration" "Model S/Core/Services/Map/MapServiceProtocols.swift" | grep "apiKey:" | sed 's/.*apiKey: "\(.*\)".*/\1/')

echo "📍 Location: Model S/Core/Services/Map/MapServiceProtocols.swift (line 146)"
echo ""

if [ "$API_KEY" = "YOUR_GOOGLE_MAPS_API_KEY" ]; then
    echo "❌ PROBLEM FOUND: API key is still the placeholder"
    echo ""
    echo "TO FIX:"
    echo "1. Open: Model S/Core/Services/Map/MapServiceProtocols.swift"
    echo "2. Go to line 146"
    echo "3. Replace: YOUR_GOOGLE_MAPS_API_KEY"
    echo "4. With your actual Google Maps API key (starts with 'AIza...')"
    echo ""
    echo "Example:"
    echo "  Before: apiKey: \"YOUR_GOOGLE_MAPS_API_KEY\""
    echo "  After:  apiKey: \"AIzaSyD...your-key-here...\""
    exit 1
elif [ -z "$API_KEY" ]; then
    echo "❌ PROBLEM FOUND: Could not find API key"
    exit 1
else
    KEY_PREFIX="${API_KEY:0:10}"
    KEY_LENGTH="${#API_KEY}"
    echo "✅ API Key Found!"
    echo "   First 10 chars: $KEY_PREFIX..."
    echo "   Length: $KEY_LENGTH characters"
    echo ""

    if [ $KEY_LENGTH -lt 30 ]; then
        echo "⚠️  WARNING: API key seems short (typical keys are 39 characters)"
        echo "   Make sure you copied the full key from Google Cloud Console"
    else
        echo "✅ API key length looks good"
    fi

    echo ""
    echo "NEXT STEPS:"
    echo "1. Build and run your app (Cmd + R)"
    echo "2. Check console output for: '✅ Google Maps SDK initialized'"
    echo "3. You should see Google Maps tiles in the app"
fi

echo ""
echo "📖 For more help, see: GOOGLE_MAPS_SETUP.md"
