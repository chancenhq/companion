# Companion TestFlight Assets

Package: `companion`
Identifier: `tech.chancen.companion`
Team: same as existing app (`C8WT3YC922`)

## Required build inputs

- `APP_BUNDLE_IDENTIFIER=tech.chancen.companion`
- `APP_DISPLAY_NAME=Companion`
- `app_icon.png` (build source for launcher/icon generation)

## Apple/TestFlight signing assets

- App Store Distribution certificate (`.p12` + password)
- Distribution certificate private key importable on CI runner keychain
- App Store provisioning profile scoped to `tech.chancen.companion`
- App Store Connect API key (`.p8`) + key ID + issuer ID
- App Store icon (1024x1024 PNG) uploaded in App Store Connect for the Companion app listing

## Recommended metadata/operational files in GitHub secrets

- `IOS_DISTRIBUTION_P12_BASE64`
- `IOS_DISTRIBUTION_P12_PASSWORD`
- `IOS_KEYCHAIN_PASSWORD`
- `IOS_DISTRIBUTION_CERT_NAME`
- `IOS_PROVISIONING_PROFILE_NAME`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_API_ISSUER_ID`

## App Store Connect items to verify per upload

- Bundle ID set to `tech.chancen.companion`
- App name and subtitle are final for this product
- Privacy/permissions text is accurate
- Screenshots and marketing metadata for this brand are set (if you publish the storefront page)
- Version/build number is incrementing (TestFlight/App Store Connect requirement)

## Suggested local build command

```bash
cd /Users/jjmata/.codex/worktrees/53b2/companion/mobile
APP_BUNDLE_IDENTIFIER=tech.chancen.companion \
APP_DISPLAY_NAME="Companion" \
flutter build ios --release --no-codesign
```
