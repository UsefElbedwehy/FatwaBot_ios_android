// Domain types shared by handlers and repositories. Mirrors backend/openapi/api.v1.yaml.

export interface AppContext {
  appId: string;
  platform: "ios" | "android" | "all";
  appVersion: string | null;
  locale: string;
}

export interface FeatureFlag {
  key: string;
  enabled: boolean;
  rollout: Record<string, unknown>;
}

export interface RemoteConfigEntry {
  key: string;
  value: unknown;
}

export interface LocaleInfo {
  locale: string;
  display_name: string;
  direction: "ltr" | "rtl";
  digits: "western" | "eastern";
}

export interface Theme {
  version: number;
  tokens: Record<string, unknown>;
}

export interface StringPack {
  locale: string;
  version: number;
  strings: Record<string, string>;
}

export interface HomeSection {
  id: string;
  type: string;
  props: Record<string, unknown>;
}

export interface HomeLayout {
  version: number;
  sections: HomeSection[];
}

export interface PrayerDefaults {
  country_code: string;
  method: string;
  params: Record<string, unknown>;
}

/** Read-side repository the config handlers depend on. Implemented by
 *  SupabaseConfigRepo (production) and InMemoryConfigRepo (tests). */
export interface ConfigRepo {
  remoteConfig(ctx: AppContext): Promise<RemoteConfigEntry[]>;
  featureFlags(ctx: AppContext): Promise<FeatureFlag[]>;
  enabledLocales(ctx: AppContext): Promise<LocaleInfo[]>;
  publishedTheme(ctx: AppContext): Promise<Theme | null>;
  publishedStringPack(
    ctx: AppContext,
    locale: string,
    sinceVersion: number | null,
  ): Promise<StringPack | null>;
  publishedHomeLayout(ctx: AppContext): Promise<HomeLayout | null>;
  prayerDefaults(ctx: AppContext, countryCode: string): Promise<PrayerDefaults>;
}
