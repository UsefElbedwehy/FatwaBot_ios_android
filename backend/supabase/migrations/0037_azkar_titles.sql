-- Titles for every azkar entry (94 rows), reviewed against docs/content/azkar-titles-review.md.
--
-- ## Why titles at all
-- A category like أذكار الصباح was 26 near-identical cards distinguished only by
-- a source line — impossible to scan for a specific dhikr, and search had nothing
-- to match but the matn.
--
-- ## Sourcing
-- Taken from the standard حصن المسلم headings and the conventional name for each
-- dhikr (سيد الاستغفار، آية الكرسي، تسبيح فاطمة، دعاء ذي النون). Where a text has
-- no conventional name, the title describes what it asks for rather than
-- inventing a label. Nothing here is an interpretation of meaning.
--
-- ## Why keyed on (slug, sort_order)
-- `gen_random_uuid()` ids differ per environment, which is how migration 0029
-- applied cleanly and updated zero rows. Verified before writing this: the live
-- corpus matches the seed entry-for-entry across all 8 categories, and
-- sort_order equals list position in every one.

create temporary table _azkar_titles (
    category_slug text not null,
    sort_order integer not null,
    title text not null
) on commit drop;

insert into _azkar_titles (category_slug, sort_order, title) values
    ('morning', 0, 'افتتاح الأذكار'),
    ('morning', 1, 'آية الكرسي'),
    ('morning', 2, 'سورة الإخلاص'),
    ('morning', 3, 'سورة الفلق'),
    ('morning', 4, 'سورة الناس'),
    ('morning', 5, 'أصبحنا وأصبح الملك لله'),
    ('morning', 6, 'اللهم بك أصبحنا'),
    ('morning', 7, 'سيد الاستغفار'),
    ('morning', 8, 'شهادة التوحيد'),
    ('morning', 9, 'شكر النعمة'),
    ('morning', 10, 'دعاء العافية'),
    ('morning', 11, 'حسبي الله لا إله إلا هو'),
    ('morning', 12, 'سؤال العفو والعافية'),
    ('morning', 13, 'اللهم عالم الغيب والشهادة'),
    ('morning', 14, 'بسم الله الذي لا يضر مع اسمه شيء'),
    ('morning', 15, 'رضيت بالله ربًا'),
    ('morning', 16, 'يا حي يا قيوم برحمتك أستغيث'),
    ('morning', 17, 'سؤال خير هذا اليوم'),
    ('morning', 18, 'أصبحنا على فطرة الإسلام'),
    ('morning', 19, 'سؤال العلم النافع والرزق الطيب'),
    ('morning', 20, 'التهليل عشرًا'),
    ('morning', 21, 'الصلاة على النبي ﷺ'),
    ('morning', 22, 'سبحان الله وبحمده عدد خلقه'),
    ('morning', 23, 'التهليل مئة مرة'),
    ('morning', 24, 'الاستغفار'),
    ('morning', 25, 'التسبيح'),
    ('evening', 0, 'افتتاح الأذكار'),
    ('evening', 1, 'آية الكرسي'),
    ('evening', 2, 'خواتيم سورة البقرة'),
    ('evening', 3, 'سورة الإخلاص'),
    ('evening', 4, 'سورة الفلق'),
    ('evening', 5, 'سورة الناس'),
    ('evening', 6, 'أمسينا وأمسى الملك لله'),
    ('evening', 7, 'اللهم بك أمسينا'),
    ('evening', 8, 'سيد الاستغفار'),
    ('evening', 9, 'شهادة التوحيد'),
    ('evening', 10, 'شكر النعمة'),
    ('evening', 11, 'دعاء العافية'),
    ('evening', 12, 'حسبي الله لا إله إلا هو'),
    ('evening', 13, 'سؤال العفو والعافية'),
    ('evening', 14, 'اللهم عالم الغيب والشهادة'),
    ('evening', 15, 'بسم الله الذي لا يضر مع اسمه شيء'),
    ('evening', 16, 'رضيت بالله ربًا'),
    ('evening', 17, 'يا حي يا قيوم برحمتك أستغيث'),
    ('evening', 18, 'سؤال خير هذه الليلة'),
    ('evening', 19, 'أمسينا على فطرة الإسلام'),
    ('evening', 20, 'التهليل عشرًا'),
    ('evening', 21, 'الصلاة على النبي ﷺ'),
    ('evening', 22, 'أعوذ بكلمات الله التامات'),
    ('evening', 23, 'التسبيح'),
    ('after_prayer', 0, 'الاستغفار والتسليم بعد الصلاة'),
    ('after_prayer', 1, 'التهليل ودعاء «لا مانع لما أعطيت»'),
    ('after_prayer', 2, 'لا حول ولا قوة إلا بالله'),
    ('after_prayer', 3, 'التسبيح والتحميد والتكبير ثلاثًا وثلاثين'),
    ('after_prayer', 4, 'المعوذات بعد الصلاة'),
    ('after_prayer', 5, 'آية الكرسي'),
    ('after_prayer', 6, 'التهليل عشرًا بعد المغرب والفجر'),
    ('after_prayer', 7, 'سؤال العلم النافع بعد الفجر'),
    ('sleep', 0, 'النفث بالمعوذات'),
    ('sleep', 1, 'آية الكرسي'),
    ('sleep', 2, 'خواتيم سورة البقرة'),
    ('sleep', 3, 'باسمك ربي وضعت جنبي'),
    ('sleep', 4, 'اللهم إنك خلقت نفسي'),
    ('sleep', 5, 'اللهم قني عذابك يوم تبعث عبادك'),
    ('sleep', 6, 'باسمك اللهم أموت وأحيا'),
    ('sleep', 7, 'تسبيح فاطمة'),
    ('sleep', 8, 'دعاء رب السموات السبع'),
    ('sleep', 9, 'حمد الله على الطعام والمأوى'),
    ('sleep', 10, 'اللهم عالم الغيب والشهادة'),
    ('sleep', 11, 'قراءة السجدة والملك'),
    ('sleep', 12, 'اللهم أسلمت نفسي إليك'),
    ('waking', 0, 'أول ما يقال عند الاستيقاظ'),
    ('waking', 1, 'ذكر من تعارّ من الليل'),
    ('waking', 2, 'شكر الله على رد الروح'),
    ('waking', 3, 'خواتيم آل عمران'),
    ('travel', 0, 'دعاء الركوب'),
    ('travel', 1, 'دعاء السفر'),
    ('travel', 2, 'التكبير في الصعود والتسبيح في النزول'),
    ('travel', 3, 'دعاء المسافر إذا أسحر'),
    ('travel', 4, 'الذكر عند الرجوع من السفر'),
    ('food', 0, 'التسمية عند الطعام'),
    ('food', 1, 'الدعاء عند الطعام والشراب'),
    ('food', 2, 'الدعاء بعد الفراغ من الطعام'),
    ('food', 3, 'حمد الله بعد الطعام'),
    ('food', 4, 'دعاء الضيف لمضيفه'),
    ('food', 5, 'إجابة الدعوة'),
    ('distress', 0, 'دعاء الهم والحزن'),
    ('distress', 1, 'الاستعاذة من الهم والعجز'),
    ('distress', 2, 'دعاء الكرب'),
    ('distress', 3, 'اللهم رحمتك أرجو'),
    ('distress', 4, 'دعاء ذي النون'),
    ('distress', 5, 'الله الله ربي لا أشرك به شيئًا'),
    ('distress', 6, 'دعاء قضاء الدين'),
    ('distress', 7, 'الاستعاذة من الهم والعجز');

update content.azkar_items i
   set title_translations = jsonb_build_object('ar', t.title),
       version = i.version + 1,
       updated_at = now()
  from _azkar_titles t
  join content.azkar_categories c
    on c.slug = t.category_slug
 where i.category_id = c.id
   and i.sort_order = t.sort_order;

-- A duplicate, not a title problem. الكرب والهم rows 1 and 7 hold the same dhikr
-- byte-for-byte, so the category renders the same card twice — verified against
-- the live rows before writing this.
--
-- Guarded rather than deleted outright: the subquery re-checks that the text
-- really is identical to the earlier row, so if the corpus has moved on since,
-- this deletes nothing instead of removing something unrelated.
delete from content.azkar_items dup
 using content.azkar_categories c
 where dup.category_id = c.id
   and c.slug = 'distress'
   and dup.sort_order = 7
   and exists (
       select 1
         from content.azkar_items keep
        where keep.category_id = dup.category_id
          and keep.sort_order = 1
          and keep.arabic_text = dup.arabic_text
   );

-- Bump the collection so devices actually pull this. The content sync is
-- version-gated: without it the server answers up_to_date and nobody sees a
-- single title.
update content.azkar_categories
   set version = version + 1, updated_at = now();
