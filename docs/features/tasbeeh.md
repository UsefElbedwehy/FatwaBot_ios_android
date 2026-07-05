# Feature Spec: Digital Tasbeeh (M2)

> No backend dependency — fully local, ships independent of the content pipeline. Presets are bundled constants in M2 (a `wird_templates`-style backend list is a natural M3+ extension, not required now).

## Domain model
- `DhikrPreset` — id, arabicText, isCustom (bundled: سبحان الله، الحمد لله، الله أكبر، لا إله إلا الله، سبحان الله وبحمده، أستغفر الله + a "custom text" entry).
- `TasbeehSet` — id, presetId or customText, target (default 33; common alternates 33/99/100/1000), count, startedAt, completedAt?.
- `TasbeehHistoryEntry` — completed sets, for the stats view (total count, sets completed, per-preset breakdown).

## Use cases
`SelectPreset(preset)` · `Increment` (haptic tick every count, distinct haptic at target reached) · `Reset` (confirms if count > 0) · `ChangeTarget(value)` · `CompleteSet` (records to history, offers "start another set") · `ListHistory`.

## Screens & states
1. **Tasbeeh screen** (from the concept demo, refined per design direction): large count display, current preset text, preset chip row (horizontally scrollable if more than fit), large circular tap target (the primary interaction — must be reachable one-handed), target + reset controls below.
2. **Target-reached state**: gentle completion feedback (not confetti — see ADR-0007 tone), count keeps incrementing past target if the user continues (does not hard-stop).
3. **History** (reachable from Journey tab per design direction, and a compact entry point from the Tasbeeh screen): total lifetime count, sets completed, simple per-day list.

## Widget (M1 infra reuse)
Tasbeeh Glance/WidgetKit widget: shows the last-used preset's current count with a tap target that deep-links into the app to continue counting (widgets can't run haptics/taps-to-increment themselves — this is a "resume" affordance, not a standalone counter).

## Events
`tasbeeh_set_started {preset_id}`, `tasbeeh_set_completed {preset_id, target, actual_count}` (reserved for M3 streak vocabulary).

## Tests
- Increment past target does not reset or block; distinct haptic fires exactly once at target crossing.
- Reset with count=0 does not prompt confirmation; reset with count>0 does.
- History total is the sum of all completed sets' actual counts, not target counts.
- Custom dhikr text persists for the session but is not saved as a preset (scope: M2 keeps this simple; a saved-custom-presets list is a future improvement).
