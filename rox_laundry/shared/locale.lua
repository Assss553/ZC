Locales = {
    ar = {
        washer = 'غسالة', dryer = 'نشافة', fold = 'طاولة الطي', cashier = 'الكاشير',
        use = '~INPUT_CONTEXT~ استخدام %s', busy = 'هذي الآلة مشغولة', no_money = 'ما عندك فلوس كافية',
        need_wash = 'لازم تغسل التيشيرت أول', need_dry = 'لازم تنشف التيشيرت أول', have_load = 'عندك غسيل ما خلص',
        no_item = 'ما عندك تيشيرت وسخ', done = 'خلصت! حصلت %s', placed = 'تم وضع المغسلة هنا', cashier_info = 'غسيل %s · تنشيف %s · المكافأة حتى %s',
        too_fast = 'استعجلت! خلي الآلة تكمل', cancelled = 'تم الإلغاء',
    },
    en = {
        washer = 'Washer', dryer = 'Dryer', fold = 'Folding table', cashier = 'Cashier',
        use = '~INPUT_CONTEXT~ Use %s', busy = 'This machine is busy', no_money = 'Not enough money',
        need_wash = 'Wash the T-shirt first', need_dry = 'Dry the T-shirt first', have_load = 'You still have laundry running',
        no_item = 'You have no dirty T-shirt', done = 'Done! You earned %s', placed = 'Laundromat placed here', cashier_info = 'Wash %s · Dry %s · Reward up to %s',
        too_fast = 'Too fast! Let the machine finish', cancelled = 'Cancelled',
    },
}
function L(k, ...) local s = (Locales[Config.Locale] or Locales.en)[k] or k; if select('#', ...) > 0 then return s:format(...) end return s end
