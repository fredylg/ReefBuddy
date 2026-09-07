# ReefBuddy iOS App

Swift 6 / SwiftUI app, iOS 18.0+, bundle id `au.com.aethers.reefbuddy`.

## Working on the project

- `iOS/ReefBuddy.xcodeproj/project.pbxproj` is maintained by hand. **Never delete or regenerate it.**
  The procedure for adding files and the verification steps are in
  [`../CLAUDE.md`](../CLAUDE.md#ios-development-rules) (the only copy of these rules).
- Run `../verify-xcode-project.sh` before and after iOS changes; `../scripts/setup-hooks.sh` installs it
  as the pre-commit hook.
- Build from the command line:
  `xcodebuild -project ReefBuddy.xcodeproj -scheme ReefBuddy -destination 'generic/platform=iOS Simulator' build`
- DEBUG builds call `http://localhost:8787`; set `API_BASE_URL` in the scheme environment to use
  production (`https://api.reefbuddy.aethers.com.au`).
- `ReefBuddy.storekit` is the StoreKit configuration for local IAP testing.

## Source layout

See the file tree in [`../CLAUDE.md`](../CLAUDE.md#ios-source-files-39). In short: `App/` (app entry,
`AppState`), `Views/`, `Components/`, `Theme/`, `Models/`, `Store/` (`@Observable` stores persisting
JSON documents through `JSONFileStore`), `Networking/` (`APIClient`, `APIDates`).
