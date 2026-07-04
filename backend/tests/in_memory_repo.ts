// Test double mirroring seed.sql shapes.
import type {
  AppContext,
  ConfigRepo,
  FeatureFlag,
  HomeLayout,
  LocaleInfo,
  PrayerDefaults,
  RemoteConfigEntry,
  StringPack,
  Theme,
} from "../functions/api/types.ts";

export class InMemoryConfigRepo implements ConfigRepo {
  config: RemoteConfigEntry[] = [{ key: "hijri.default_offset_days", value: 0 }];
  flags: FeatureFlag[] = [
    { key: "module.prayer", enabled: true, rollout: {} },
    { key: "module.ai_ask", enabled: false, rollout: {} },
  ];
  locales: LocaleInfo[] = [
    { locale: "ar", display_name: "العربية", direction: "rtl", digits: "eastern" },
    { locale: "en", display_name: "English", direction: "ltr", digits: "western" },
  ];
  theme: Theme | null = { version: 1, tokens: { light: { "color.primary": "#7A2A2A" } } };
  packs: StringPack[] = [
    { locale: "ar", version: 3, strings: { "home.ask.placeholder": "ما حكم...؟" } },
  ];
  layout: HomeLayout | null = {
    version: 1,
    sections: [
      { id: "prayer", type: "prayer_hero", props: {} },
      { id: "ask", type: "ask_ai", props: { state: "coming_soon" } },
    ],
  };
  defaults: PrayerDefaults[] = [
    { country_code: "*", method: "mwl", params: { madhab: "shafi" } },
    { country_code: "SA", method: "umm_al_qura", params: { madhab: "shafi" } },
  ];

  remoteConfig(_ctx: AppContext) {
    return Promise.resolve(this.config);
  }
  featureFlags(_ctx: AppContext) {
    return Promise.resolve(this.flags);
  }
  enabledLocales(_ctx: AppContext) {
    return Promise.resolve(this.locales);
  }
  publishedTheme(_ctx: AppContext) {
    return Promise.resolve(this.theme);
  }
  publishedStringPack(_ctx: AppContext, locale: string, sinceVersion: number | null) {
    const pack = this.packs.find((p) => p.locale === locale) ?? null;
    if (pack && sinceVersion !== null && pack.version <= sinceVersion) return Promise.resolve(null);
    return Promise.resolve(pack);
  }
  publishedHomeLayout(_ctx: AppContext) {
    return Promise.resolve(this.layout);
  }
  prayerDefaults(_ctx: AppContext, countryCode: string) {
    const hit = this.defaults.find((d) => d.country_code === countryCode) ??
      this.defaults.find((d) => d.country_code === "*")!;
    return Promise.resolve(hit);
  }
}
