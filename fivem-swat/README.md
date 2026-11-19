# SWAT Uniform – FiveM (Addon Clothing)

ألوان: زيتي / أسود / تمويه صحراوي — قميص تكتيكي + فيست (Plate Carrier) بباتشات S.W.A.T و D-1.

## الملفات
- `textures/` تكسشرات جاهزة (1024px): `swat_shirt_*_diff.png`, `swat_vest_*_diff.png` + باتشات PNG شفافة.
- `tools/generate_textures.py` يعيد توليد التكسشرات (`python3 tools/generate_textures.py`).
- `fxmanifest.lua` ريسورس FiveM.

## التركيب (خطوات)
1. **المودل (.ydd):** صدّر قميص Combat Shirt و Plate Carrier من Blender (إضافة Sollumz) أو خذ قاعدة من ملابس Freemode.
   - القميص في سلوت `jbib` (Torso 2 / ID 11)، الفيست في `task` (Body Armor / ID 9).
2. **التكسشر (.ytd):** افتح OpenIV / Texture Toolkit وحوّل كل PNG إلى YTD:
   - `jbib_000_a_uni.ytd` = olive، `_b_` = black، `_c_` = desert (نفس الشي للـ `task_000_*`).
   - الباتش الدائري `patch_arm_swat.png` ضعه على الكم الأيسر في الـUV.
3. ضع ملفات `.ydd/.ytd/.ymt` في `stream/mp_m_freemode_01_swat/` (استخدم Durty Cloth Tool لبناء الـ ymt و meta تلقائياً).
4. في `server.cfg`:  `ensure swat_uniform`
5. داخل اللعبة اختر الملابس من EUP / qb-clothing / illenium-appearance.
