# ROX Houses — مجلد رفع البيوت والصور

**© ROX Store – جميع الحقوق محفوظة.**

هذا الريسورس هو المكان اللي ترفع فيه **ملفات البيوت (الماب)** و **صورها**، و `rox_realestate` يتعرف عليها لحاله.

```
rox_houses/
├─ stream/      ← ملفات البيت: .ydr  .ytyp  .ytd  .ybn  (و .ymap للـ MLO)
├─ images/      ← صورة لكل بيت بنفس اسم الموديل: my_villa_shell.png  (jpg / png / webp)
└─ houses.json  ← (اختياري) اسم البيت بالعربي/الإنجليزي، عدد الغرف، نقطة الدخول، تصميم ROX
```

## التركيب
`server.cfg` — قبل السكربت:
```
ensure rox_houses
ensure rox_realestate
```

## خطوات إضافة بيت
1. حط ملفات البيت في `stream/` (تقدر تسوي مجلد لكل بيت داخل stream).
2. حط صورة البيت في `images/` **بنفس اسم الموديل** (مثال: `shell_villa.ydr` ← `shell_villa.png`).
3. ريستارت للريسورس، أو من الايباد: **إنشاء عقار ← Rescan** (أو الأمر `/realestate_scan`).
4. البيت يطلع في قائمة التصاميم مع صورته. ادخل البيت وقف عند الباب واكتب `/houseentry` لحفظ نقطة الدخول.

## houses.json (اختياري)
انسخ مثال من `_examples` إلى `houses` وعدّله (الأمثلة نفسها ما تنقرأ).

| الحقل | المعنى |
|---|---|
| `model` | اسم موديل البيت (اسم ملف الـ .ydr بدون الامتداد) |
| `label` / `labelAr` | الاسم بالإنجليزي / العربي |
| `rooms` | عدد الغرف (للعرض) |
| `tier` | `low` / `mid` / `high` / `luxury` |
| `image` | اسم الصورة داخل `images/` (إذا اسمها غير اسم الموديل) |
| `entry` | نقطة الدخول بالنسبة لمركز الموديل `{x,y,z,h}` — أو احفظها في اللعبة بـ `/houseentry` |
| `design` | `null` · `"warehouse"` (مخزن ROX بالتفاصيل) · `"hideout"` (وكر عصابة مهجور) |
| `gangOnly` | `true` = للعصابات فقط |

**بيت MLO** (ماب موجود في العالم): `"type": "mlo"` مع `key` و `spawn` (الإحداثيات اللي يطلع فيها اللاعب داخل الـ MLO).

كل بيت فيه غرف: السكربت يحط إضاءة في **كل غرفة** تلقائياً لما يكون له تصميم ROX.


## بيوت ROX الجاهزة (موديلات حقيقية)

داخل `stream/rox_shells/` خمس بيوت **موديلات GTA حقيقية** (ملفات `.ydr` فيها التصادم والإضاءة) مع ملف الخامات `rox_shells_txd.ytd` وملف التعريف `rox_shells.ytyp`:

| الموديل | الوصف |
|---|---|
| `rox_shell_apartment` | شقة مودرن: صالة، مطبخ مجهز، غرفتين نوم، حمام، ممر |
| `rox_shell_garage` | ورشة صناعية 3 أقسام: شبابيك حديد، باب رول، كمرات حديد |
| `rox_shell_office` | مكتب لوفت على شكل L: باركيه، شبابيك طويلة بستائر، سقف مربعات |
| `rox_shell_oldhouse` | بيت عائلي قديم: 7 غرف، بلاط، ورق جدران، مراوح سقف، شبابيك مسكّرة |
| `rox_shell_showroom` | صالة عرض كبيرة مع مدخل |

- الصور في `images/` والأسماء ونقاط الدخول في `houses.json` (تنقرأ تلقائياً).
- صور من داخل البيوت في `previews/`.
- المصدر اللي يولّد البيوت في `tools/shellgen/` (تقدر تضيف بيوت جديدة منه).

## ROX Open Houses (stream/rox_open)

8 two-storey walk-in interiors (stairs, open front door, see-through windows) made to sit inside real map houses.
In the iPad: Create Property > **Open House** > draw the zone > press **T** – the system measures the house and
places the design that fits best (T again = next design, arrows / PGUP / PGDN / Q / R to fine-tune).

| Model | Size (m) |
|---|---|
| rox_open_cottage | 8.0 x 8.0 |
| rox_open_craftsman | 8.8 x 8.6 |
| rox_open_townhouse | 7.6 x 10.6 |
| rox_open_beach | 9.6 x 10.0 |
| rox_open_family | 11.0 x 9.0 |
| rox_open_ranch | 12.8 x 8.6 |
| rox_open_villa | 14.6 x 10.6 |
| rox_open_mansion | 16.8 x 12.0 |
