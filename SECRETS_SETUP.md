# 🔐 Secrets Management Setup

This app uses a secure secrets management system to prevent API keys from being committed to git.

## ⚠️ IMMEDIATE ACTION IF YOU LEAKED A KEY

If you accidentally committed an API key to GitHub:

1. **Revoke the key immediately**: https://console.cloud.google.com/apis/credentials
2. **Delete or regenerate the exposed key**
3. **Create a new API key**
4. **Follow the setup instructions below**
5. **Clean up git history** (see instructions at bottom)

## 🚀 First Time Setup

### Step 1: Create Secrets.plist

```bash
# Copy the example file
cp "Model S/Core/Configuration/Secrets.example.plist" "Model S/Core/Configuration/Secrets.plist"
```

### Step 2: Add Your API Keys

1. Open `Model S/Core/Configuration/Secrets.plist`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual Google Maps API key
3. Save the file

### Step 3: Verify .gitignore

Make sure `Secrets.plist` is in your `.gitignore`:

```gitignore
# Secrets and API Keys
Model S/Core/Configuration/Secrets.plist
```

### Step 4: Never Commit Secrets.plist

The `Secrets.plist` file is **gitignored** and will never be committed to version control.

## 📝 How It Works

- **Secrets.plist**: Contains your actual API keys (gitignored, never committed)
- **Secrets.example.plist**: Template file (committed to git, no real keys)
- **SecretsManager.swift**: Loads keys from Secrets.plist at runtime

## 🔑 Getting a Google Maps API Key

1. Go to: https://console.cloud.google.com/
2. Create or select a project
3. Enable these APIs:
   - Maps SDK for iOS
   - Directions API
   - Places API
   - Geocoding API
4. Go to Credentials → Create Credentials → API Key
5. Copy the key (starts with `AIza...`)
6. Add it to your `Secrets.plist`

## 🧹 Cleaning Up Git History (If You Leaked a Key)

If you already committed a key, you need to remove it from git history:

### Option 1: Using git filter-repo (Recommended)

```bash
# Install git-filter-repo
brew install git-filter-repo

# Remove the sensitive file from all history
git filter-repo --path Model\ S/Core/Services/Map/MapServiceProtocols.swift --invert-paths

# Force push to remote (⚠️ WARNING: This rewrites history!)
git push origin --force --all
```

### Option 2: Using BFG Repo-Cleaner

```bash
# Install BFG
brew install bfg

# Replace the API key in all history
bfg --replace-text <(echo "AIzaSyBia66kN2xuED5s6Vx6F-NeSdrjxD7xLC0==>REMOVED")

# Clean up and force push
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push origin --force --all
```

### Option 3: Nuclear Option (Start Fresh)

If the repository is not important yet:

```bash
# Remove git history
rm -rf .git

# Start fresh
git init
git add .
git commit -m "Initial commit with secure secrets management"
git remote add origin <your-repo-url>
git push -u origin main --force
```

## ✅ Best Practices

1. ✅ **Never** hardcode API keys in source code
2. ✅ **Always** use Secrets.plist for API keys
3. ✅ **Always** keep Secrets.plist in .gitignore
4. ✅ **Commit** Secrets.example.plist as a template
5. ✅ **Revoke** any keys that were exposed
6. ✅ **Rotate** API keys regularly
7. ✅ **Restrict** API keys in Google Cloud Console

## 🤝 Team Setup

When a new developer joins:

1. They clone the repo
2. They copy `Secrets.example.plist` → `Secrets.plist`
3. You share the API key securely (Slack DM, password manager, etc.)
4. They add the key to their local `Secrets.plist`
5. They never commit `Secrets.plist`

## 🔒 Production Security

For production apps, consider:

- **GitHub Secrets**: For CI/CD pipelines
- **AWS Secrets Manager**: For cloud-based secrets
- **1Password** or **Bitwarden**: For team secret sharing
- **Fastlane Match**: For certificate management
