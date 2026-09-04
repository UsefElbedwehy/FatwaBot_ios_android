import { assertEquals } from "jsr:@std/assert@1";

/**
 * The seeded theme and the two bundled client palettes must agree.
 *
 * ## Why this exists
 * ADR-0011 makes the bundled client palettes the offline fallback for whatever
 * `/v1/config/theme` serves, so the two are supposed to be identical — a user
 * should not see the app change colour the first time it syncs.
 *
 * They were not identical. `seed.sql` still carried the original `#D08770`
 * salmon dark palette long after both clients had moved off it, including
 * `color.on_primary: #2B1B17` — dark text on the maroon fill, which is backwards
 * for a fill colour and is exactly what the client comment had been rewritten to
 * warn against. Nothing caught it because nothing compared the two, and the live
 * project happens to have no published theme, so the mismatch never surfaced at
 * runtime. The moment anyone publishes one, every dark-mode user gets the
 * rejected palette pushed over the top of the approved one.
 *
 * This reads the three sources of truth and asserts they match. It is deliberately
 * a text-level comparison rather than a shared constant: the whole point is to
 * catch someone editing one file and not the others.
 */

const ROOT = new URL("../../", import.meta.url).pathname;

const SEED = `${ROOT}backend/supabase/seed.sql`;
const SWIFT = `${ROOT}ios/Packages/FatwaBotKit/Sources/DesignSystemKit/DesignTokens.swift`;
const KOTLIN =
  `${ROOT}android/core/designsystem/src/main/kotlin/com/fatwabot/core/designsystem/DesignTokens.kt`;

/** Maps the seed's wire keys to the clients' field names. */
const FIELDS: ReadonlyArray<[wire: string, field: string]> = [
  ["color.primary", "primary"],
  ["color.primary_container", "primaryContainer"],
  ["color.accent", "accent"],
  ["color.surface", "surface"],
  ["color.surface_elevated", "surfaceElevated"],
  ["color.on_surface", "onSurface"],
  ["color.on_surface_secondary", "onSurfaceSecondary"],
  ["color.on_primary", "onPrimary"],
  ["color.outline", "outline"],
];

type Palette = Record<string, string>;

/** The `"light"` / `"dark"` object out of the seeded theme JSON. */
function seedPalette(source: string, scheme: "light" | "dark"): Palette {
  const start = source.indexOf("insert into config.themes");
  if (start < 0) throw new Error("no config.themes insert in seed.sql");
  const open = source.indexOf("'{", start);
  const close = source.indexOf("}'::jsonb", open);
  if (open < 0 || close < 0) throw new Error("could not delimit the theme JSON");
  const theme = JSON.parse(source.slice(open + 1, close + 1));
  const block = theme[scheme];
  if (!block) throw new Error(`seed theme has no "${scheme}" block`);

  const palette: Palette = {};
  for (const [wire, field] of FIELDS) {
    const value = block[wire];
    if (typeof value !== "string") throw new Error(`seed ${scheme} is missing ${wire}`);
    palette[field] = value.toUpperCase();
  }
  return palette;
}

/**
 * Swift: `light: ColorTokens(` … `)` with `field: "#RRGGBB"` entries.
 * Anchored on the scheme label so the light block cannot be read as the dark one.
 */
function swiftPalette(source: string, scheme: "light" | "dark"): Palette {
  const start = source.indexOf(`${scheme}: ColorTokens(`);
  if (start < 0) throw new Error(`no ${scheme} ColorTokens in DesignTokens.swift`);
  const block = source.slice(start, source.indexOf("),", start));

  const palette: Palette = {};
  for (const [, field] of FIELDS) {
    const match = block.match(new RegExp(`\\b${field}:\\s*"(#[0-9A-Fa-f]{6})"`));
    if (!match) throw new Error(`Swift ${scheme} is missing ${field}`);
    palette[field] = match[1].toUpperCase();
  }
  return palette;
}

/**
 * Kotlin: `val DarkTokens = ColorTokens(` … `)` with `field = Color(0xFFRRGGBB)`.
 * The leading `0xFF` is the opaque alpha channel and is dropped for comparison.
 */
function kotlinPalette(source: string, scheme: "light" | "dark"): Palette {
  const name = scheme === "light" ? "LightTokens" : "DarkTokens";
  const start = source.indexOf(`val ${name} = ColorTokens(`);
  if (start < 0) throw new Error(`no ${name} in DesignTokens.kt`);
  const block = source.slice(start, source.indexOf("\n)", start));

  const palette: Palette = {};
  for (const [, field] of FIELDS) {
    const match = block.match(new RegExp(`\\b${field}\\s*=\\s*Color\\(0x([0-9A-Fa-f]{8})\\)`));
    if (!match) throw new Error(`Kotlin ${scheme} is missing ${field}`);
    const argb = match[1].toUpperCase();
    assertEquals(argb.slice(0, 2), "FF", `${name}.${field} must be fully opaque`);
    palette[field] = `#${argb.slice(2)}`;
  }
  return palette;
}

for (const scheme of ["light", "dark"] as const) {
  Deno.test(`seeded ${scheme} theme matches the bundled iOS palette`, async () => {
    const seed = seedPalette(await Deno.readTextFile(SEED), scheme);
    const swift = swiftPalette(await Deno.readTextFile(SWIFT), scheme);
    assertEquals(
      seed,
      swift,
      `seed.sql and DesignTokens.swift disagree on the ${scheme} palette — a client ` +
        `syncing the server theme would see different colours than it ships with`,
    );
  });

  Deno.test(`bundled iOS and Android ${scheme} palettes match`, async () => {
    const swift = swiftPalette(await Deno.readTextFile(SWIFT), scheme);
    const kotlin = kotlinPalette(await Deno.readTextFile(KOTLIN), scheme);
    assertEquals(
      swift,
      kotlin,
      `DesignTokens.swift and DesignTokens.kt disagree on the ${scheme} palette — ` +
        `iOS and Android would not look the same`,
    );
  });
}
