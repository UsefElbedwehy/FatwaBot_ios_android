# Feature Spec: Config Sync (M1)

> The client half of ADR-0011. Single-source spec — implement identically on iOS and Android.

## Purpose
Fetch, cache, and apply the four config layers (remote config/flags, theme, string packs, Home layout) plus prayer defaults, with offline-first semantics: **rendering never waits on the network.**

## Domain model
- `ConfigSnapshot` — the currently *applied* set: `AppConfig`, `DesignTokens` (resolved), string overlay for active locale, `HomeLayout`, fetch metadata (etag/version, fetched_at).
- Source precedence: **cached snapshot → bundled defaults**; network refresh replaces the cache, application policy below.

## Use cases
| Use case | Behavior |
|---|---|
| `LoadConfigSnapshot` | Synchronous read of cache (or bundled defaults) at launch — feeds first frame |
| `RefreshConfig` | Background fetch of all layers (parallel); validate; persist; emit updated snapshot |
| `ResolveString(key)` | Server pack overlay → bundled Localizable fallback → key itself (never crash on missing) |
| `IsFeatureEnabled(flag)` | Flag lookup honoring rollout gates (version, platform); unknown flag = false |

## Application policy (when fetched config takes effect)
- Flags, remote config values, strings, prayer defaults: applied **immediately** on successful refresh.
- Theme, Home layout: applied on next foreground/launch (avoid mid-session visual jumps), unless the snapshot is the first ever (then immediate).

## Triggers
Launch (async), foreground after >6h staleness, silent config-refresh push (M3), manual (Settings ▸ debug).

## Failure semantics
Network/validation failures are silent (log + keep current snapshot). A malformed layer never corrupts the cache: validate the full payload before persisting; layers are cached independently.

## Storage
- iOS: JSON files in Application Support (app group container so widgets read the same snapshot) + version metadata.
- Android: DataStore (proto or JSON) in app storage; widget access via the same store.

## Analytics events
`config_refresh_succeeded {layers_changed}`, `config_refresh_failed {layer, reason}`, `config_snapshot_version` as user property.

## Tests (both platforms)
1. First launch, no network → bundled defaults render; no error surfaced.
2. Refresh with changed theme → applied per policy (not mid-session), persisted, identical resolved tokens as iOS/Android counterpart (parity fixture).
3. Malformed layer payload → cache untouched, other layers still applied.
4. `since_version` string-pack delta: up-to-date response leaves overlay unchanged.
5. Unknown Home section type in payload → skipped, remaining sections render in order.
