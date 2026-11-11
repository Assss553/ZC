/* ROX — محرك فحص إيصالات التحويل البنكي
   يشتغل كله داخل المتصفح بدون إرسال الإيصال لأي خدمة خارجية.
   يأخذ النص المقروء من صورة الإيصال ويقارنه ببيانات الطلب، ويطلع حكم مع الأسباب.
   تنبيه: الفحص مساعد للمراجعة وليس إثباتًا. التأكيد النهائي من كشف الحساب البنكي. */
(function (root) {
  const AR_DIGITS = '٠١٢٣٤٥٦٧٨٩', FA_DIGITS = '۰۱۲۳۴۵۶۷۸۹';
  const MONTHS = { jan:1, feb:2, mar:3, apr:4, may:5, jun:6, jul:7, aug:8, sep:9, oct:10, nov:11, dec:12,
    'يناير':1, 'فبراير':2, 'مارس':3, 'ابريل':4, 'مايو':5, 'يونيو':6, 'يوليو':7, 'اغسطس':8, 'سبتمبر':9, 'اكتوبر':10, 'نوفمبر':11, 'ديسمبر':12 };
  const KEYWORDS = ['تحويل', 'حواله', 'عمليه', 'ناجح', 'المستفيد', 'المبلغ', 'ايصال', 'الايبان', 'transfer', 'successful', 'beneficiary', 'amount', 'receipt', 'iban', 'transaction', 'reference'];
  const EDITORS = ['photoshop', 'canva', 'picsart', 'gimp', 'snapseed', 'pixelmator', 'lightroom', 'inshot', 'photopea'];

  /* توحيد النص: أرقام عربية ← لاتينية، وتوحيد أشكال الحروف */
  function norm(s) {
    return String(s || '')
      .replace(/[٠-٩]/g, d => AR_DIGITS.indexOf(d)).replace(/[۰-۹]/g, d => FA_DIGITS.indexOf(d))
      .replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, '').replace(/٫/g, '.').replace(/٬/g, ',')
      .replace(/[ً-ْـ]/g, '').replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي')
      .toLowerCase();
  }
  const num = s => parseFloat(String(s).replace(/,/g, ''));
  const digits = s => String(s || '').replace(/\D/g, '');
  function diff(a, b) { if (a.length !== b.length) return 99; let d = 0; for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) d++; return d; }

  function findAmounts(t) {
    const strong = [], weak = [], re = /\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?/g; let m;
    while ((m = re.exec(t))) {
      const v = num(m[0]); if (!(v > 0) || v > 5e6 || digits(m[0]).length > 9) continue;
      const before = t.slice(Math.max(0, m.index - 28), m.index), after = t.slice(m.index + m[0].length, m.index + m[0].length + 12);
      const cur = /(sar|s\.?r\.?|ر\.?\s?س|ريال|﷼)\s*$/.test(before) || /^\s*(sar|s\.?r\.?\b|ر\.?\s?س|ريال|﷼)/.test(after);
      // في الإيصالات العربية القارئ يطلّع اسم الحقل قبل الرقم أو بعده
      const lab = /(المبلغ|مبلغ|الاجمالي|amount|total)[^\d]{0,14}$/.test(before) || /^[^\d\n]{0,6}(المبلغ|مبلغ|الاجمالي)/.test(after);
      if (cur || lab) strong.push(v); else if (/\.\d{2}$/.test(m[0])) weak.push(v);
    }
    return { strong: [...new Set(strong)], weak: [...new Set(weak)] };
  }
  function findIbans(t) { return [...new Set((t.match(/sa(?:[\s-]?\d){22}/g) || []).map(x => 'SA' + digits(x)))]; }
  /* أرقام حسابات مكتوبة كمجموعات (مثل 3450 1605 6080 …). القارئ يعكس ترتيب المجموعات في النص العربي، فنرجّع الترتيبين */
  function findGrouped(t) {
    const out = [];
    (t.match(/(?:\d{2,4}[ \t]){3,6}\d{2,4}/g) || []).forEach(x => { const g = x.trim().split(/\s+/), n = g.join('').length;
      if (n >= 18 && n <= 26) out.push(g.join(''), g.slice().reverse().join('')); });
    return [...new Set(out)];
  }
  function findMasked(t) { return [...new Set((t.match(/[*x•×]{2,}[\s-]?\d{4}\b/g) || []).map(x => digits(x).slice(-4)))]; }
  function findDates(t) {
    const out = [], add = (y, mo, d) => { y = +y; mo = +mo; d = +d; if (y >= 2020 && y <= 2100 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) out.push(Date.UTC(y, mo - 1, d)); };
    let m, re = /\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b/g; while ((m = re.exec(t))) add(m[1], m[2], m[3]);
    re = /\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b/g; while ((m = re.exec(t))) add(m[3], m[2], m[1]);
    re = /\b(\d{1,2})\s*[-,]?\s*([a-z]{3,9}|[ء-ي]{4,7})\.?\s*[-,]?\s*(\d{4})\b/g;
    while ((m = re.exec(t))) { const k = MONTHS[m[2]] || MONTHS[m[2].slice(0, 3)]; if (k) add(m[3], k, m[1]); }
    return [...new Set(out)];
  }
  function findRef(t) {
    const m = t.match(/(?:reference|ref\.?|المرجع|المرجعي|رقم العمليه|transaction(?: id| no\.?| number)?)\s*(?:number|no\.?|رقم)?\s*[:#-]?\s*([a-z0-9]{6,24})/);
    return m && /\d/.test(m[1]) ? m[1].toUpperCase() : '';
  }

  /* التحليل: text نص الإيصال، ctx بيانات الطلب والحساب */
  function analyze(text, ctx) {
    const t = norm(text), checks = [], add = (k, label, st, detail) => checks.push({ k, label, st, detail });
    const fmt = n => (+n).toFixed(2), day = 864e5, now = ctx.now || Date.now();
    const readable = t.replace(/\s/g, '').length;

    // 1) وضوح الصورة
    if (readable < 25) add('read', 'قراءة الإيصال', 'fail', 'ما قدرنا نقرأ نص من الصورة. اطلب من العميل صورة أوضح.');
    else { const k = KEYWORDS.filter(w => t.includes(w)).length;
      add('read', 'شكل الإيصال', k >= 2 ? 'ok' : 'warn', k >= 2 ? 'النص فيه مصطلحات إيصال تحويل بنكي.' : 'النص ما يشبه إيصال تحويل بنكي.'); }

    // 2) المبلغ
    const am = findAmounts(t), exp = +ctx.expectedSar, cand = am.strong.length ? am.strong : am.weak;
    const near = v => Math.abs(v - exp) <= 0.05, close = v => Math.abs(v - exp) <= 1 || (v > exp && v <= exp * 1.02);
    if (!cand.length) add('amount', 'المبلغ', 'warn', `ما لقينا مبلغ واضح. المطلوب ${fmt(exp)} ريال.`);
    else if (cand.some(near)) add('amount', 'المبلغ', 'ok', `${fmt(cand.find(near))} ريال — مطابق للمطلوب.`);
    else if (cand.some(close)) add('amount', 'المبلغ', 'ok', `${fmt(cand.find(close))} ريال — قريب من المطلوب ${fmt(exp)}.`);
    else if (ctx.expectedUsd && cand.some(v => Math.abs(v - ctx.expectedUsd) <= 0.05) && /usd|\$|دولار/.test(t)) add('amount', 'المبلغ', 'ok', `${fmt(ctx.expectedUsd)} دولار — مطابق.`);
    else add('amount', 'المبلغ', am.strong.length ? 'fail' : 'warn', `المبلغ في الإيصال ${cand.slice(0, 3).map(fmt).join(' / ')} والمطلوب ${fmt(exp)} ريال.`);

    // 3) حساب المستفيد
    const iban = String(ctx.iban || '').replace(/\s/g, '').toUpperCase(), acc = digits(ctx.account), masked = findMasked(t), allDigits = digits(t);
    const cands = [...findIbans(t).map(digits), ...findGrouped(t)], tail = digits(iban).slice(-16);
    const nearTail = c => { if (!tail || c.length < 16) return 99; let best = 99; for (let k = 0; k + 16 <= c.length; k++) best = Math.min(best, diff(c.substr(k, 16), tail)); return best; };
    if (!iban && !acc) add('iban', 'حساب المستفيد', 'warn', 'ما حددت الآيبان في الإعدادات.');
    else if (tail && cands.some(c => c.includes(tail))) add('iban', 'حساب المستفيد', 'ok', 'الآيبان مطابق لحسابك.');
    else if (acc && acc.length >= 8 && (allDigits.includes(acc) || cands.some(c => c.includes(acc)))) add('iban', 'حساب المستفيد', 'ok', 'رقم الحساب مطابق لحسابك.');
    else if (cands.some(c => nearTail(c) <= 2)) add('iban', 'حساب المستفيد', 'warn', 'الآيبان قريب جدًا من حسابك لكن فيه خانة أو خانتين مختلفة. تأكد بنفسك.');
    else if (masked.some(x => (iban && iban.endsWith(x)) || (acc && acc.endsWith(x)))) add('iban', 'حساب المستفيد', 'ok', 'آخر 4 أرقام من الحساب مطابقة (الحساب مخفي جزئيًا).');
    else if (cands.length) add('iban', 'حساب المستفيد', 'fail', 'رقم الحساب في الإيصال مو حسابك.');
    else add('iban', 'حساب المستفيد', 'warn', 'ما لقينا آيبان أو رقم حساب في الإيصال.');

    // 4) اسم المستفيد
    const toks = norm(ctx.holder).split(/\s+/).filter(x => x.length >= 2);
    if (!toks.length) add('name', 'اسم المستفيد', 'info', 'ما حددت اسم المستفيد في الإعدادات، فما انفحص.');
    else { const hit = toks.filter(x => t.includes(x)).length;
      if (hit === toks.length || hit >= Math.max(2, Math.ceil(toks.length * .6))) add('name', 'اسم المستفيد', 'ok', 'الاسم موجود في الإيصال.');
      else add('name', 'اسم المستفيد', 'warn', hit ? 'جزء من الاسم فقط موجود في الإيصال.' : 'اسمك مو ظاهر في الإيصال.'); }

    // 5) التاريخ
    const dates = findDates(t), from = (ctx.orderAt || now) - 1.5 * day, to = now + day;
    if (!dates.length) add('date', 'تاريخ التحويل', 'warn', 'ما لقينا تاريخ واضح.');
    else if (dates.some(d => d >= from - day && d <= to)) add('date', 'تاريخ التحويل', 'ok', 'التاريخ بعد إنشاء الطلب.');
    else add('date', 'تاريخ التحويل', 'fail', `تاريخ الإيصال (${new Date(Math.max(...dates)).toISOString().slice(0, 10)}) ما يوافق وقت الطلب.`);

    // 6) التكرار
    const ref = findRef(t);
    if (ctx.dupHashOrder) add('dup', 'التكرار', 'fail', `نفس الصورة مرفوعة في الطلب #${ctx.dupHashOrder}.`);
    else if (ref && (ctx.usedRefs || []).includes(ref)) add('dup', 'التكرار', 'fail', `رقم العملية ${ref} مستخدم في طلب ثاني.`);
    else add('dup', 'التكرار', 'ok', ref ? `رقم العملية ${ref} ما انستخدم من قبل.` : 'الصورة ما انرفعت في طلب ثاني.');

    // 7) ملف الصورة
    if (ctx.software) add('file', 'ملف الصورة', 'warn', `الصورة مرّت على برنامج تعديل (${ctx.software}).`);
    else if (ctx.imgW && Math.min(ctx.imgW, ctx.imgH) < 380) add('file', 'ملف الصورة', 'warn', 'الصورة صغيرة جدًا، وممكن تكون مقصوصة.');
    else add('file', 'ملف الصورة', 'ok', 'ما فيه علامات تعديل ظاهرة في الملف.');

    const fails = checks.filter(c => c.st === 'fail').length, warns = checks.filter(c => c.st === 'warn').length;
    const st = k => (checks.find(c => c.k === k) || {}).st, core = st('amount') === 'ok' && (st('iban') === 'ok' || st('name') === 'ok');
    const verdict = fails ? 'sus' : core && warns <= 1 ? 'ok' : 'review';
    return { verdict, score: Math.max(0, 100 - fails * 35 - warns * 12), checks, ref, at: now,
      label: { ok: 'مطابق', review: 'يحتاج مراجعة', sus: 'مشكوك فيه' }[verdict] };
  }

  /* يبحث في بيانات الملف عن اسم برنامج تعديل صور */
  function fileSoftware(buf) {
    const b = new Uint8Array(buf, 0, Math.min(buf.byteLength, 131072)); let s = '';
    for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    s = s.toLowerCase(); return EDITORS.find(e => s.includes(e)) || '';
  }
  async function sha256(buf) {
    const h = await crypto.subtle.digest('SHA-256', buf);
    return [...new Uint8Array(h)].map(x => x.toString(16).padStart(2, '0')).join('');
  }

  root.RoxReceipt = { analyze, norm, findAmounts, findIbans, findGrouped, findDates, findRef, fileSoftware, sha256 };
})(typeof window !== 'undefined' ? window : globalThis);
