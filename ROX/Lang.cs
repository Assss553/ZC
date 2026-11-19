namespace ROX;

public static class Lang
{
    public static string Code = "en";
    public static bool Rtl => Code == "ar";

    static readonly Dictionary<string, (string en, string ar)> T = new()
    {
        ["start"] = ("START", "تشغيل"),
        ["stop"] = ("STOP", "إيقاف"),
        ["settings"] = ("SETTINGS", "الإعدادات"),
        ["running"] = ("● LIVE", "● شغال"),
        ["idle"] = ("● OFFLINE", "● متوقف"),
        ["hint"] = ("Open Settings to pick your mic and outputs, then press START.", "افتح الإعدادات واختر الميك والسماعات ثم اضغط تشغيل."),
        ["mixer"] = ("MIXER", "المكسر"),
        ["mic"] = ("MIC", "الميك"), ["line"] = ("LINE IN", "مدخل 2"), ["music"] = ("MUSIC", "الموسيقى"), ["sfx"] = ("SAMPLES", "المؤثرات"),
        ["effects"] = ("VOICE FX", "مؤثرات الصوت"),
        ["presets"] = ("PRESETS", "القوالب"),
        ["presetTip"] = ("Click = load · Right-click = save current", "كليك = تحميل · كليك يمين = حفظ الحالي"),
        ["reverb"] = ("Reverb", "صدى القاعة"), ["pitch"] = ("Pitch", "طبقة الصوت"), ["echo"] = ("Echo", "الإيكو"), ["noise"] = ("Noise Kill", "عزل الضوضاء"),
        ["mictune"] = ("MIC TUNE", "ضبط الميك"),
        ["gain"] = ("Gain", "تكبير"), ["comp"] = ("Compressor", "الضغط"), ["bass"] = ("Bass", "باس"), ["mid"] = ("Mid", "وسط"), ["treble"] = ("Treble", "حدة"),
        ["megaphone"] = ("Megaphone", "مكبر"), ["robot"] = ("Robot", "روبوت"), ["deep"] = ("Deep", "عميق"), ["fx"] = ("FX", "FX"),
        ["sampler"] = ("SAMPLER", "الأصوات السريعة"),
        ["samplerTip"] = ("Click = play · Right-click = assign sound", "كليك = تشغيل · كليك يمين = اختيار صوت"),
        ["clear"] = ("CLEAR", "إيقاف"),
        ["empty"] = ("empty", "فارغ"),
        ["load"] = ("Load", "أغنية"),
        ["bleep"] = ("BLEEP", "تصفير"),
        ["mute"] = ("MUTE", "كتم"),
        ["micmuted"] = ("MIC MUTED", "الميك مكتوم"),
        ["monitor"] = ("Hear myself", "اسمع صوتي"),
        ["output"] = ("OUTPUT", "الإخراج"),
        // settings
        ["sTitle"] = ("ROX Settings", "إعدادات ROX"),
        ["tAudio"] = ("Audio", "الصوت"), ["tLook"] = ("Appearance", "المظهر"), ["tLang"] = ("Language", "اللغة"),
        ["dMic"] = ("Microphone", "الميك"), ["dLine"] = ("Second input", "مدخل ثاني"),
        ["dOut1"] = ("Output 1 — Headphones", "إخراج 1 — السماعة"),
        ["dOut2"] = ("Output 2 — Stream / Discord (VB-Cable)", "إخراج 2 — البث / ديسكورد"),
        ["dOut3"] = ("Output 3 — Extra speaker", "إخراج 3 — سماعة إضافية"),
        ["none"] = ("— none —", "— بدون —"),
        ["volume"] = ("Volume", "الصوت"),
        ["themes"] = ("Theme presets", "ثيمات جاهزة"),
        ["custom"] = ("Custom colors (hex)", "ألوان مخصصة (hex)"),
        ["cA1"] = ("Main accent", "اللون الرئيسي"), ["cA2"] = ("Second accent", "اللون الثاني"),
        ["cBg"] = ("Background", "الخلفية"), ["cPanel"] = ("Panel", "اللوحة"), ["cText"] = ("Text", "النص"),
        ["apply"] = ("Apply", "تطبيق"), ["close"] = ("Close", "إغلاق"),
        ["langPick"] = ("Interface language", "لغة الواجهة"),
        ["navBoard"] = ("Board", "اللوحة"), ["navFx"] = ("Effects", "المؤثرات"), ["navTrans"] = ("Transitions", "الانتقالات"),
        ["fxLib"] = ("VOICE EFFECTS LIBRARY", "مكتبة مؤثرات الصوت"),
        ["fxLibTip"] = ("Combine any effects. They apply live to your mic.", "تقدر تجمع أكثر من مؤثر. تشتغل مباشرة على الميك."),
        ["radio"] = ("Radio", "راديو"), ["telephone"] = ("Telephone", "تلفون"), ["alien"] = ("Alien", "فضائي"),
        ["distortion"] = ("Distortion", "تشويش"), ["underwater"] = ("Underwater", "تحت الماء"), ["chorus"] = ("Chorus", "جماعي"),
        ["chipmunk"] = ("Chipmunk", "سنجاب"), ["monster"] = ("Monster", "وحش"), ["cave"] = ("Cave", "كهف"), ["announcer"] = ("Announcer", "مذيع"),
        ["reset"] = ("Reset all", "إعادة الكل"),
        ["trans"] = ("STREAM TRANSITIONS", "انتقالات البث"),
        ["transTip"] = ("Add a video clip (mp4/webm/mov). Click to play it on the ROX Stage window + its sound goes to your stream.", "أضف مقطع فيديو (mp4/webm/mov). اضغط عليه يشتغل في نافذة ROX Stage وصوته يروح للبث."),
        ["obsTip"] = ("OBS: add Window Capture → \"ROX Stage\", then add a Chroma Key filter (green) or Color Key (black).", "OBS: أضف Window Capture ← \"ROX Stage\" ثم فلتر Chroma Key للأخضر أو Color Key للأسود."),
        ["addClip"] = ("+ Add clip", "+ أضف مقطع"), ["openStage"] = ("Open stage window", "افتح نافذة البث"),
        ["stageBg"] = ("Stage background", "خلفية النافذة"), ["green"] = ("Green", "أخضر"), ["black"] = ("Black", "أسود"), ["magenta"] = ("Magenta", "وردي"),
        ["withSound"] = ("Play clip sound", "شغّل صوت المقطع"), ["stopAll"] = ("Stop", "إيقاف"), ["remove"] = ("Remove", "حذف"),
        ["error"] = ("Error: ", "خطأ: "),
    };

    public static string L(string key) => T.TryGetValue(key, out var v) ? (Rtl ? v.ar : v.en) : key;
}
