# Contributing

## Ground rules

1. **Contract-first.** API changes start in `backend/openapi/*.yaml`; client models mirror the contract (iOS `CoreKit`, Android `core:common`). Never let the three drift.
2. **Configurable-by-default** (ADR-0015). Before hardcoding a value/rule/list/text in mobile code, check [docs/guides/CONFIGURABILITY.md](docs/guides/CONFIGURABILITY.md); claim an exemption there or make it backend-driven.
3. **Feature specs before feature code.** Each feature gets `docs/features/<feature>.md` (domain model, use cases, screen states, analytics events) implemented identically on both platforms.
4. **ADR for every decision with alternatives.** `docs/adr/`, sequential numbering, statuses maintained.
5. **Keep the changelog and implementation notes current** (`CHANGELOG.md`, `docs/notes/`).
6. **No feature → feature module dependencies** (ADR-0010). Cross-feature flows compose at app level.

## Per-platform quick reference

| Platform | Build | Test | Docs |
|---|---|---|---|
| Backend | — | `cd backend && deno task test && deno task lint` | [backend/README.md](backend/README.md) |
| iOS | `cd ios/App && xcodegen generate && xcodebuild …` | `cd ios/Packages/<Pkg> && swift test` | [ios/README.md](ios/README.md) |
| Android | `cd android && ./gradlew build` | `./gradlew test` | android module READMEs |
| Dashboard | `cd dashboard && npm run build` | `npm run lint && npm run typecheck` | dashboard/README.md |

## Commit style

Conventional commits (`feat(scope):`, `fix:`, `chore:`, `docs:`, `ci:`). One logical change per commit. Reference ADRs in bodies where relevant.

## Machine setup (macOS)

```sh
brew install deno supabase/tap/supabase xcodegen openjdk@21 gradle
brew install --cask android-commandlinetools
sdkmanager --licenses && sdkmanager platform-tools "platforms;android-35" "build-tools;35.0.0"
echo "sdk.dir=$HOME/Library/Android/sdk" > android/local.properties
cd dashboard && npm install
```
