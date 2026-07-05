import type { AppContext } from "../functions/api/types.ts";
import type {
  AzkarCollection,
  ContentRepo,
  DuaCollection,
  HadithCollectionDetail,
  HadithCollectionSummary,
  WirdTemplatesCollection,
} from "../functions/api/content_types.ts";

export class InMemoryContentRepo implements ContentRepo {
  azkar: AzkarCollection = {
    version: 3,
    categories: [
      {
        id: "cat-morning",
        slug: "morning",
        name: "أذكار الصباح",
        sortOrder: 0,
        items: [
          {
            id: "item-1",
            sortOrder: 0,
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: null,
            translation: "Glory be to Allah",
            virtueNote: null,
            source: "رواه مسلم",
            repeatCount: 100,
          },
        ],
      },
    ],
  };

  duas: DuaCollection = {
    version: 2,
    categories: [
      {
        id: "cat-quran",
        slug: "quran",
        name: "أدعية قرآنية",
        sortOrder: 0,
        duas: [
          {
            id: "dua-1",
            sortOrder: 0,
            title: "ربنا آتنا",
            arabicText: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً",
            transliteration: null,
            translation: "Our Lord, give us good",
            source: "البقرة: 201",
          },
        ],
      },
    ],
  };

  hadithSummaries: HadithCollectionSummary[] = [
    { id: "col-1", slug: "nawawi40", name: "الأربعون النووية", description: "...", entryCount: 3 },
  ];

  hadithDetails = new Map<string, HadithCollectionDetail>([
    ["nawawi40", {
      version: 5,
      slug: "nawawi40",
      name: "الأربعون النووية",
      description: "...",
      entries: [
        {
          id: "h-1",
          number: 1,
          arabicText: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ",
          translation: "Actions are but by intentions",
          grading: "متفق عليه",
          benefitNote: "النية أساس العمل",
          source: "رواه البخاري ومسلم",
        },
      ],
    }],
  ]);

  wird: WirdTemplatesCollection = {
    version: 1,
    templates: [
      {
        id: "wird-1",
        name: "الصلاة على النبي",
        description: "...",
        type: "salawat",
        defaultTarget: 100,
        defaultUnit: "times",
        defaultFrequency: "daily",
      },
    ],
  };

  azkarCollection(_ctx: AppContext) {
    return Promise.resolve(this.azkar);
  }
  duaCollection(_ctx: AppContext) {
    return Promise.resolve(this.duas);
  }
  hadithCollections(_ctx: AppContext) {
    return Promise.resolve(this.hadithSummaries);
  }
  hadithCollectionDetail(_ctx: AppContext, slug: string) {
    return Promise.resolve(this.hadithDetails.get(slug) ?? null);
  }
  wirdTemplates(_ctx: AppContext) {
    return Promise.resolve(this.wird);
  }
}
