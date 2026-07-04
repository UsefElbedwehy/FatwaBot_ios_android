# iOS

SwiftUI, iOS 17+. Feature-first SPM modules (ADR-0010), MVVM + typed routers (ADR-0005), Factory DI (ADR-0006, added with the first feature in M1).

## Layout

```
Packages/FatwaBotKit/    shared foundation package
  Sources/CoreKit/           server contract models (mirror backend/openapi), JSONValue
  Sources/NetworkingKit/     APIClient + endpoint catalog (client context headers)
  Sources/DesignSystemKit/   design tokens: bundled defaults + server-theme overlay (ADR-0011)
App/                     app target (XcodeGen)
  project.yml                source of truth — the .xcodeproj is generated, not committed
  Sources/                   app entry, ThemeStore, 4-tab shell, localization (ar/en)
```

## Build

```sh
brew install xcodegen              # once
cd ios/App && xcodegen generate    # after target/file changes
xcodebuild -project FatwaBot.xcodeproj -scheme FatwaBot \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

cd ios/Packages/FatwaBotKit && swift test   # package tests
```

## Conventions

- Server payload models live in CoreKit and mirror `backend/openapi/api.v1.yaml`; update the contract first.
- Theme tokens: fixed schema, server-overridable values; bundled defaults must stay in sync with `backend/supabase/seed.sql`.
- Unknown Home section types are skipped (ADR-0011) — see `HomeLayout.renderableSections`.
- Arabic is the development language; every user-facing string goes through Localizable.strings (server string packs overlay in M1).
