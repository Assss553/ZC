# ROX Play (Windows)
تطبيق ROX للعب ألعاب PS4/PS5 على الكمبيوتر بفريمات الكمبيوتر. مبني على **chiaki-ng** المفتوح المصدر (ترخيص AGPL-3.0).

- **المصدر الأصلي:** chiaki-ng مثبّت على إصدار محدد هو `CHIAKI_COMMIT` في ملف `.github/workflows/rox-play-windows.yml`.
- **تعديلات ROX:** موجودة كلها في `apply-rox-branding.ps1`، وتشمل الاسم والألوان. التعريب الكامل للواجهة من مهام المرحلة القادمة.
- **البناء:** يتم تلقائيًا على GitHub Actions بوصفة بناء chiaki-ng الرسمية لنظام Windows، ثم يُنشر ملف `ROX-Play-win64.zip`.
- **الترخيص:** هذا المجلد مع chiaki-ng يشكّلان كامل الكود المصدري لـ ROX Play، وهو متاح للعامة كما يشترط ترخيص AGPL.
