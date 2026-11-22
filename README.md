# Byline Times for iPhone and iPad

Native SwiftUI reader for bylinetimes.com. iOS 17 and later.

## What is here

| Path | What it is |
|---|---|
| `Sources/App.swift` | App entry, colours and type, story model, bylinetimes.com API, app state |
| `Sources/Views.swift` | Tabs: Latest, Library, Saved, Account |
| `Sources/Reader.swift` | Story reader, paywall, article styling |
| `Sources/Masthead.swift` | The masthead image, stored in code |
| `Sources/Assets.xcassets` | App icon (placeholder) |
| `project.yml` | Project description, turned into an Xcode project by XcodeGen |
| `ExportOptions.plist` | Upload settings for App Store Connect |
| `.github/workflows/testflight.yml` | Cloud build that sends the app to TestFlight |

## Building

No Mac is needed. In GitHub, open **Actions**, choose **Build and send to TestFlight**, and press **Run workflow**. The build appears in TestFlight a few minutes after it finishes.

The build needs three repository secrets (Settings, Secrets and variables, Actions):

- `ASC_KEY_ID`: the App Store Connect API key's Key ID
- `ASC_ISSUER_ID`: the Issuer ID shown above the list of keys
- `ASC_KEY_P8`: the full text of the downloaded `AuthKey_XXXX.p8` file

On a Mac, run `brew install xcodegen && xcodegen generate` and open `BylineTimes.xcodeproj`.

## Status

Preview build. Stories, reader, saved stories and the three-free-stories paywall work against the live site. Subscriber sign-in, PDF editions and Apple payments are not connected yet; they depend on the Byline App Bridge plugin for the WooCommerce shop.
