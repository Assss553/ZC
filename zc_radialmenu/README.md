# zc_radialmenu 5D — قائمة F1 دائرية

قائمة دائرية (Radial Menu) لـ FiveM بتصميم ثلاثي الأبعاد: طبقات بعمق حقيقي، قطع مجسّمة تطلع لبرا، أيقونات طايرة، ميلان مع الماوس، جزيئات متوهجة وأصوات.

![preview](docs/preview-main.png)
![police](docs/preview-police.png)
![vehicle](docs/preview-vehicle.png)

## القوائم
| الزر | القائمة | تفتح لـ |
|---|---|---|
| **F1** | القائمة الرئيسية (ZC MENU) | الكل |
| **F6** | قائمة الشرطة (POLICE) | وظائف `police / sheriff / bcso / sasp` |
| **F6** | قائمة الإسعاف (EMS) | وظائف `ambulance / ems` |
| **F3** | قائمة السيارة (VEHICLE) | بس وأنت داخل سيارة |

- كل قائمة لها زر خاص (يتغير من `key` أو من إعدادات اللعبة)، ولون خاص لو تبي (`color`)
- القائمة الرئيسية فيها اختصار يحولك لقائمة الشرطة/السيارة (`type = 'menu'`) — ويختفي إذا ما تقدر تفتحها
- تقدر تضيف قوائم جديدة بسهولة في `Config.Menus`
- أمر `/radial <name>` يفتح أي قائمة، مثل `/radial vehicle`

## المميزات
- **5D**: القائمة تميل مع الماوس، القطعة المختارة ترتفع وتطلع لبرا، والطبقات تتجمع بحركة لما تفتح
- حلقات هولوغرام تدور، ودائرة نص زجاجية بإطار متوهج يلف، وخط مسح
- جزيئات (Particles) تطلع من القطعة المختارة
- أصوات خفيفة (تقدر تطفيها `Config.Sound = false`)
- عجلة الماوس تتنقل بين الخيارات، وEnter يختار
- تفتح بزر **F1** (يقدر اللاعب يغيره من إعدادات GTA > Key Bindings > FiveM)
- اختيار بالماوس من أي مكان في الشاشة حسب الاتجاه، مع مؤشر يدور على الحلقة
- قوائم فرعية بلا حد + مسار (ZC MENU › Police) وزر رجوع في النص
- قوائم خاصة بالوظيفة (police / ambulance ...) — يتعرف تلقائياً على QBCore / Qbox / ESX، ويشتغل بدونهم
- `canInteract` لإخفاء عناصر حسب الحالة (مثلاً قائمة السيارة تظهر بس وأنت داخلها)
- أوامر سيارة جاهزة: مكينة، كبوت، شنطة، كل باب لحاله، كل دريشة لحالها، المقاعد، الأنوار، قلب السيارة
- `Config.KeepInput` يخلّيك تمشي/تسوق والقائمة مفتوحة
- Font Awesome مضمّن داخل السكربت (ما يحتاج إنترنت)

## التركيب
1. انسخ مجلد `zc_radialmenu` إلى `resources`
2. أضف في `server.cfg`:
   ```
   ensure zc_radialmenu
   ```

## الإعدادات (`config.lua`)
```lua
Config.Color = '#ff5a1f'   -- اللون الافتراضي

Config.Menus.police = {
    key = 'F6', title = 'POLICE',
    jobs = { 'police', 'sheriff' },
    -- color = '#2f7bff',
    items = { ... }
}

{ label = 'Police', icon = 'shield-halved', type = 'menu', menu = 'police' }  -- يحول لقائمة ثانية

{ label = 'GPS', icon = 'map-location-dot', type = 'command', command = 'gps' }
{ label = 'Cuff', icon = 'handcuffs', type = 'client', event = 'police:client:CuffPlayer' }
{ label = 'Bill', icon = 'receipt', type = 'server', event = 'myjob:server:bill', args = { amount = 500 } }
```
أسماء الأيقونات من https://fontawesome.com/search?o=r&m=free&s=solid

## التحكم
| الزر | الوظيفة |
|---|---|
| F1 / F6 / F3 | فتح / إغلاق القائمة |
| كليك يسار / Enter | اختيار |
| عجلة الماوس | تنقل بين الخيارات |
| كليك يمين / Backspace | رجوع |
| ESC | إغلاق |

## معاينة بالمتصفح
افتح `html/index.html` في المتصفح مباشرة يطلع لك عرض تجريبي — اضغط `1` الرئيسية، `2` الشرطة، `3` السيارة.

## Exports
```lua
exports.zc_radialmenu:Open('vehicle')
exports.zc_radialmenu:IsOpen()
exports.zc_radialmenu:Close()
```
