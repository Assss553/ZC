# rox_police — ROX Store

> © **ROX Store** — جميع الحقوق محفوظة. صاحب الملفات: **ROX Store**. ممنوع إعادة البيع أو النشر بدون إذن.

سكربت شرطة كامل لـ FiveM: **iPad** فيه MDT + إدارة السجن + المخالفات + **Boss Menu**، وحجز السيارات بالعين الثالثة، ونزع الماسك.
يشتغل مع QBCore / Qbox / ESX، والبيانات تنحفظ في `data/db.json` (ما يحتاج قاعدة بيانات).

![home](docs/home.png)

## طرق الفتح
| من وين | وش يفتح |
|---|---|
| **F1 › Police** | MDT، iPad، Prison، Citations، Impound، Unmask، Management (كابتن وفوق) |
| **iPad** (`/tablet` أو آيتم `tablet`) | الشاشة الرئيسية وفيها كل التطبيقات |
| **العين الثالثة على سيارة** (ox_target / qb-target) | Impound / Depot Vehicle |
| **العين الثالثة على لاعب** | Remove Mask / Hat |
| أوامر | `/mdt` `/jail` `/fine` `/impound` `/unmask` `/policeboss` `/tablet` `/paybail` |

لما تفتح الـ iPad، الشخصية تمسك تابلت بحركة حقيقية.

## 1. Management — Boss Menu (كابتن وفوق)
![boss](docs/boss.png)
- **Dashboard**: عدد الموظفين، المتصلين، اللي في الدوام، رصيد الحساب، جدول المتصلين، والإشعارات
- **Employee List**: كل الموظفين (أونلاين وأوفلاين)، الرتبة، النداء (Callsign)، ساعات الدوام، المكافآت والإنذارات
- **Profile**: مكافأة / إنذار، **خريطة نشاط** لساعات الدوام لكل يوم وساعة، الشهادات، تغيير الرتبة، فصل، وملاحظات
- **Hire**: توظيف لاعب قريب منك برتبة تختارها
- **Certifications**: جدول الشهادات (Firearms، K9، SWAT، Air...)
- **Finance**: إيداع وسحب من حساب الشرطة (qb-banking / qb-management / Renewed-Banking / esx_society)
- **Activity Log**: كل شي سواه المدراء

![profile](docs/boss-prof.png)

الحماية: ما تقدر تعطي رتبة أعلى أو تساوي رتبتك، ولا تغير رتبتك، ولا تفصل نفسك.
الرتبة المطلوبة: `Config.BossMinGrade` (ومن عنده `isboss` يدخل دايم).

## 2. Impound / Depot — حجز السيارات
![impound](docs/imp1.png) ![depot](docs/imp2.png)
- **Impound**: تروح الحجز العادي، وصاحبها يطلعها بالسعر المحدد
- **Depot**: حجز شرطة، تحدد السعر ومدة الحجز بالساعات، والسبب
- الشرطي يكتب على لوح قبل الحجز، والسيارة تختفي
- السكربتات الثانية (القراج) تقدر تسأل: `exports.rox_police:IsVehicleHeld(plate)`
- صفحة **Impound** في الـ MDT فيها السيارات المحجوزة، الوقت الباقي، وزر الإفراج

## 3. Remove Accessories — نزع الماسك
![strip](docs/strip.png)
يطلع لك اللي حولك ووش لابسين (ماسك، كاب، نظارة، شنطة)، تختار وتنزعها.

## 4. Prison Management — إدارة السجن
![jail](docs/jail.png)
السجن أو الحجز، NEARBY، مؤبد، المدة تنحسب من التهم، كفالة (`/paybail`)، غرامة، قائمة المساجين، وسجن مدمج (نقل، منع هروب، عداد، إطلاق، الوقت محفوظ).

## 5. Citations — المخالفات
![fine](docs/fine.png)

## 6. MDT
![mdt](docs/mdt.png)
Dashboard، Citizens، Vehicles، **Impound**، Warrants، Reports، BOLO.

## التركيب
```
ensure rox_police
ensure rox_radialmenu
```
آيتم التابلت (اختياري) لـ QBCore في `qb-core/shared/items.lua`:
```lua
tablet = { name = 'tablet', label = 'Police iPad', weight = 500, type = 'item', image = 'tablet.png', unique = true, useable = true, shouldClose = true, description = 'Police iPad' },
```

## الإعدادات المهمة (`config.lua`)
`Config.PoliceJobs`، `Config.BossMinGrade`، `Config.Society`، `Config.Charges`، `Config.Jail.types`، `Config.Impound`، `Config.Accessories`، `Config.Certifications`، `Config.Tablet`

## الحماية
كل شي ينفحص في السيرفر: الوظيفة، الرتبة، المسافة، والمبالغ والمدد (ما ينفع أحد يغيرها من الواجهة).

## معاينة بالمتصفح
`html/index.html` (الـ iPad) — `?panel=boss` — `?panel=impound` — `?panel=strip` — `?panel=jail` — `?panel=mdt&hud=1`
