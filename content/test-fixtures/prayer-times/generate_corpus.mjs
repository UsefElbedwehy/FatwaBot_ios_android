// Golden-corpus generator (M0 spike, ADR-0003).
// Reference implementation: adhan-js (Batoul Apps). The Swift/Kotlin ports must
// reproduce these UTC timestamps within ±90s in golden-file tests on both platforms.
// Regenerate: deno run --allow-write generate_corpus.mjs
// M1 TODO: spot-validate corpus rows against official published timetables
// (Umm al-Qura, Egyptian General Authority, Diyanet) before release.

import adhan from "npm:adhan@4.4.3";

const CITIES = [
  { name: "Makkah", lat: 21.4225, lng: 39.8262, tz: "Asia/Riyadh", method: "UmmAlQura", country: "SA" },
  { name: "Cairo", lat: 30.0444, lng: 31.2357, tz: "Africa/Cairo", method: "Egyptian", country: "EG" },
  { name: "Riyadh", lat: 24.7136, lng: 46.6753, tz: "Asia/Riyadh", method: "UmmAlQura", country: "SA" },
  { name: "Dubai", lat: 25.2048, lng: 55.2708, tz: "Asia/Dubai", method: "Dubai", country: "AE" },
  { name: "Istanbul", lat: 41.0082, lng: 28.9784, tz: "Europe/Istanbul", method: "Turkey", country: "TR" },
  { name: "Karachi", lat: 24.8607, lng: 67.0011, tz: "Asia/Karachi", method: "Karachi", country: "PK", madhab: "hanafi" },
  { name: "Jakarta", lat: -6.2088, lng: 106.8456, tz: "Asia/Jakarta", method: "Singapore", country: "ID" },
  { name: "Kuala Lumpur", lat: 3.139, lng: 101.6869, tz: "Asia/Kuala_Lumpur", method: "Singapore", country: "MY" },
  { name: "London", lat: 51.5074, lng: -0.1278, tz: "Europe/London", method: "MoonsightingCommittee", country: "GB" },
  // ≥48°N: explicit high-latitude rule REQUIRED — library defaults diverge across
  // ports (spike finding: Paris June fajr differed by 2.8h between js and swift
  // with defaults). config.prayer_defaults must always set the rule for these.
  { name: "Paris", lat: 48.8566, lng: 2.3522, tz: "Europe/Paris", method: "MuslimWorldLeague", country: "FR", highLat: true },
  { name: "New York", lat: 40.7128, lng: -74.006, tz: "America/New_York", method: "NorthAmerica", country: "US" },
  { name: "Toronto", lat: 43.6532, lng: -79.3832, tz: "America/Toronto", method: "NorthAmerica", country: "CA" },
  { name: "Oslo", lat: 59.9139, lng: 10.7522, tz: "Europe/Oslo", method: "MuslimWorldLeague", country: "NO", highLat: true },
  { name: "Stockholm", lat: 59.3293, lng: 18.0686, tz: "Europe/Stockholm", method: "MuslimWorldLeague", country: "SE", highLat: true },
  { name: "Sydney", lat: -33.8688, lng: 151.2093, tz: "Australia/Sydney", method: "MuslimWorldLeague", country: "AU" },
  { name: "Johannesburg", lat: -26.2041, lng: 28.0473, tz: "Africa/Johannesburg", method: "MuslimWorldLeague", country: "ZA" },
  { name: "Casablanca", lat: 33.5731, lng: -7.5898, tz: "Africa/Casablanca", method: "MuslimWorldLeague", country: "MA" },
  { name: "Dhaka", lat: 23.8103, lng: 90.4125, tz: "Asia/Dhaka", method: "Karachi", country: "BD", madhab: "hanafi" },
  { name: "Lagos", lat: 6.5244, lng: 3.3792, tz: "Africa/Lagos", method: "MuslimWorldLeague", country: "NG" },
  { name: "Kuwait City", lat: 29.3759, lng: 47.9774, tz: "Asia/Kuwait", method: "Kuwait", country: "KW" },
];

// Solstices, equinoxes, a DST-transition week (EU + US), and Ramadan 1447.
const DATES = [
  [2026, 3, 20], [2026, 6, 21], [2026, 9, 23], [2026, 12, 21],
  [2026, 3, 29], [2026, 11, 1], [2026, 2, 18],
];

const rows = [];
for (const city of CITIES) {
  const params = adhan.CalculationMethod[city.method]();
  params.madhab = city.madhab === "hanafi" ? adhan.Madhab.Hanafi : adhan.Madhab.Shafi;
  if (city.highLat) params.highLatitudeRule = adhan.HighLatitudeRule.TwilightAngle;
  const coords = new adhan.Coordinates(city.lat, city.lng);

  for (const [y, m, d] of DATES) {
    const date = new Date(Date.UTC(y, m - 1, d));
    const pt = new adhan.PrayerTimes(coords, date, params);
    rows.push({
      city: city.name,
      country: city.country,
      latitude: city.lat,
      longitude: city.lng,
      timezone: city.tz,
      method: city.method,
      madhab: city.madhab ?? "shafi",
      high_latitude_rule: city.highLat ? "twilight_angle" : null,
      date: `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`,
      times_utc: {
        fajr: pt.fajr.toISOString(),
        sunrise: pt.sunrise.toISOString(),
        dhuhr: pt.dhuhr.toISOString(),
        asr: pt.asr.toISOString(),
        maghrib: pt.maghrib.toISOString(),
        isha: pt.isha.toISOString(),
      },
    });
  }
}

const corpus = {
  generator: "adhan-js 4.4.3",
  tolerance_seconds: 90,
  note: "Cross-implementation golden corpus (ADR-0003). Swift/Kotlin ports must match within tolerance.",
  entries: rows,
};

await Deno.writeTextFile(
  new URL("./corpus.json", import.meta.url).pathname,
  JSON.stringify(corpus, null, 2) + "\n",
);
console.log(`wrote ${rows.length} entries`);
