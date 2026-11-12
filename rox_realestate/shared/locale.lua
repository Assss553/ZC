--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

Locales = {
    ar = {
        no_access          = 'ليس لديك صلاحية',
        help_lock          = '~INPUT_CONTEXT~ قفل باب %s',
        help_unlock        = '~INPUT_CONTEXT~ فتح باب %s',
        help_knock         = '~INPUT_CONTEXT~ طرق باب %s',
        knocked            = 'طرقت الباب',
        zone_aim_door      = 'صوّب على باب (مجسم) أولاً',
        zone_door_main     = 'تم تحديد الباب الرئيسي',
        zone_door_inner    = 'تم تحديد باب داخلي',
        zone_door_unset    = 'تم إلغاء تحديد الباب',
        zone_removed       = 'تم حذف الباب %s',
        zone_restored      = 'تم إرجاع الباب',
        zone_entry_set     = 'تم تحديد نقطة المدخل',
        zone_need_corners  = 'حدد ٣ زوايا على الأقل حول البيت',
        zone_need_entry    = 'قف عند المدخل واضغط E لتحديد نقطة المدخل',
        zone_max_corners   = 'الحد الأقصى %s زاوية',
        zone_max_doors     = 'الحد الأقصى %s باب',
        open_only          = 'هذا العقار ليس منزلاً مفتوحاً',
        zone_interior      = 'تم تركيب التصميم: %s',
        zone_interior_off  = 'تم إزالة التصميم الداخلي',
        zone_no_interiors  = 'تصاميم ROX غير محمّلة (شغّل rox_houses)',
        not_realtor        = 'هذا التطبيق للعقاريين فقط',
        no_money           = 'رصيدك غير كافي',
        invalid_data       = 'بيانات غير صحيحة',
        target_offline     = 'اللاعب غير متصل',
        too_far_door       = 'أنت بعيد عن موقع الباب',
        property_created   = 'تم إنشاء العقار #%s',
        contract_sent      = 'تم إرسال العقد إلى %s',
        contract_received  = 'وصلك عقد عقاري جديد من %s',
        contract_signed    = 'تم توقيع العقد، مبروك العقار!',
        contract_signed_r  = '%s وقّع العقد على %s، عمولتك %s',
        contract_declined  = 'تم رفض العقد',
        contract_declined_r= '%s رفض العقد على %s',
        contract_expired   = 'انتهت صلاحية العقد',
        not_available      = 'العقار غير متاح',
        locked             = 'الباب مقفل',
        door_locked        = 'تم قفل الباب',
        door_unlocked      = 'تم فتح الباب',
        key_given          = 'تم إعطاء مفتاح لـ %s',
        key_received       = 'استلمت مفتاح %s',
        key_removed        = 'تم سحب المفتاح',
        max_keys           = 'وصلت الحد الأقصى للمفاتيح',
        rent_paid          = 'تم دفع الإيجار %s',
        rent_auto          = 'تم خصم إيجار %s: %s',
        rent_overdue       = 'إيجار %s متأخر! ادفعه من الايباد',
        evicted            = 'تم إخلاؤك من %s',
        lease_ended        = 'تم إنهاء عقد الإيجار',
        listed             = 'تم عرض العقار في السوق بـ %s',
        unlisted           = 'تم إلغاء العرض',
        market_bought      = 'اشتريت %s من السوق',
        market_sold        = 'تم بيع عقارك %s، وصلك %s',
        payout             = 'وصلك %s من بيع عقار أثناء غيابك',
        order_done         = 'تم شراء %s قطعة أثاث',
        max_furniture      = 'وصلت الحد الأقصى للأثاث (%s)',
        furniture_placed   = 'تم وضع القطعة',
        furniture_stored   = 'تم إرجاع القطعة للمخزن',
        furniture_sold     = 'تم بيع القطعة بـ %s',
        not_inside         = 'لازم تكون داخل البيت',
        too_far_place      = 'المكان بعيد جداً',
        property_updated   = 'تم تحديث العقار',
        property_deleted   = 'تم حذف العقار',
        property_evicted   = 'تم إخلاء العقار',
        help_enter         = '~INPUT_CONTEXT~ دخول %s',
        help_view          = '~INPUT_CONTEXT~ عرض %s',
        help_exit          = '~INPUT_CONTEXT~ خروج  ~INPUT_DETONATE~ الأثاث',
        aim_help           = 'صوّب على الباب ~INPUT_CONTEXT~ تأكيد  ~INPUT_FRONTEND_RRIGHT~ إلغاء',
        knock              = 'أحد يطرق باب %s',
        blip_available     = 'عقار متاح',
        gang_only          = 'هذا الوكر للعصابات فقط',
        scan_done          = 'تم الفحص: %s تصميم',
        entry_saved        = 'تم حفظ نقطة الدخول للشل %s',
        furniture_hint     = 'اضغط O لترتيب الأثاث',
        help_exit_only     = '~INPUT_CONTEXT~ خروج',
        auto_entry         = 'نقطة دخول تلقائية. وقف عند الباب واكتب /%s لحفظها',
        not_inside         = 'لازم تكون داخل البيت',
        shell_missing      = 'الشل "%s" غير محمّل في السيرفر',
        blip_market        = 'عقار للبيع',
        waypoint_set       = 'تم تحديد الموقع على الخريطة',
    },
    en = {
        no_access          = 'You have no access',
        help_lock          = '~INPUT_CONTEXT~ Lock %s',
        help_unlock        = '~INPUT_CONTEXT~ Unlock %s',
        help_knock         = '~INPUT_CONTEXT~ Knock on %s',
        knocked            = 'You knocked on the door',
        zone_aim_door      = 'Aim at a door object first',
        zone_door_main     = 'Main door set',
        zone_door_inner    = 'Inner door set',
        zone_door_unset    = 'Door unmarked',
        zone_removed       = 'Door %s removed.',
        zone_restored      = 'Door restored',
        zone_entry_set     = 'Entry point set',
        zone_need_corners  = 'Click at least 3 corners around the house',
        zone_need_entry    = 'Stand at the entrance and press E to set the entry point',
        zone_max_corners   = 'Maximum %s corners',
        zone_max_doors     = 'Maximum %s doors',
        open_only          = 'This property is not an open house',
        zone_interior      = 'Interior placed: %s',
        zone_interior_off  = 'Interior removed',
        zone_no_interiors  = 'ROX interiors are not streamed (start rox_houses)',
        not_realtor        = 'Realtors only',
        no_money           = 'Not enough money',
        invalid_data       = 'Invalid data',
        target_offline     = 'Player is offline',
        too_far_door       = 'You are too far from the door',
        property_created   = 'Property #%s created',
        contract_sent      = 'Contract sent to %s',
        contract_received  = 'You received a property contract from %s',
        contract_signed    = 'Contract signed, enjoy your new property!',
        contract_signed_r  = '%s signed the contract for %s, commission %s',
        contract_declined  = 'Contract declined',
        contract_declined_r= '%s declined the contract for %s',
        contract_expired   = 'Contract expired',
        not_available      = 'Property not available',
        locked             = 'The door is locked',
        door_locked        = 'Door locked',
        door_unlocked      = 'Door unlocked',
        key_given          = 'Key given to %s',
        key_received       = 'You received a key for %s',
        key_removed        = 'Key removed',
        max_keys           = 'Maximum keys reached',
        rent_paid          = 'Rent paid %s',
        rent_auto          = 'Rent for %s charged: %s',
        rent_overdue       = 'Rent for %s is overdue! Pay it from the iPad',
        evicted            = 'You were evicted from %s',
        lease_ended        = 'Lease ended',
        listed             = 'Property listed on the marketplace for %s',
        unlisted           = 'Listing removed',
        market_bought      = 'You bought %s from the marketplace',
        market_sold        = 'Your property %s was sold, you received %s',
        payout             = 'You received %s from a property sale while away',
        order_done         = 'Purchased %s furniture pieces',
        max_furniture      = 'Furniture limit reached (%s)',
        furniture_placed   = 'Piece placed',
        furniture_stored   = 'Piece stored',
        furniture_sold     = 'Piece sold for %s',
        not_inside         = 'You must be inside the property',
        too_far_place      = 'Too far away',
        property_updated   = 'Property updated',
        property_deleted   = 'Property deleted',
        property_evicted   = 'Property evicted',
        help_enter         = '~INPUT_CONTEXT~ Enter %s',
        help_view          = '~INPUT_CONTEXT~ View %s',
        help_exit          = '~INPUT_CONTEXT~ Exit  ~INPUT_DETONATE~ Furniture',
        aim_help           = 'Aim at the door ~INPUT_CONTEXT~ confirm  ~INPUT_FRONTEND_RRIGHT~ cancel',
        knock              = 'Someone is knocking at %s',
        blip_available     = 'Property Available',
        gang_only          = 'This hideout is for gang members only',
        scan_done          = 'Scan done: %s interiors',
        entry_saved        = 'Entry point saved for shell %s',
        furniture_hint     = 'Press O to arrange your furniture',
        help_exit_only     = '~INPUT_CONTEXT~ Exit',
        auto_entry         = 'Automatic entry point. Stand at the door and type /%s to save it',
        shell_missing      = 'Shell "%s" is not streamed on this server',
        blip_market        = 'Property For Sale',
        waypoint_set       = 'Waypoint set',
    },
}

PlayerLang = {}      -- server: [src] = 'en' | 'ar'
CurrentLangSrc = nil -- server: set while a callback runs
ClientLang = nil     -- client: chosen in the iPad settings

function CurrentLang(src)
    if IsDuplicityVersion() then
        src = src or CurrentLangSrc
        return (src and PlayerLang[src]) or Config.Locale
    end
    return ClientLang or Config.Locale
end

local function translate(lang, key, ...)
    local dict = Locales[lang] or Locales.en
    local str = dict[key] or Locales.en[key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

function L(key, ...) return translate(CurrentLang(), key, ...) end

-- server: translate for a specific player
function LP(src, key, ...) return translate(CurrentLang(src), key, ...) end

function FormatMoney(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if s:sub(1, 1) == ',' then s = s:sub(2) end
    return Config.Currency .. s
end
