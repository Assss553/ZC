// إرسال الإيميلات للعملاء (تأكيد الطلب + تحديث الحالة) وتنبيه صاحب المتجر
import nodemailer from 'nodemailer';
import { run, getSettings } from './db.js';

const STATUS = ['جديد', 'قيد التجهيز', 'تم الشحن', 'تم التوصيل', 'ملغي'];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const clean = (s) => String(s ?? '').replace(/[\r\n]+/g, ' ').slice(0, 200); // يمنع حقن ترويسات الإيميل

let transport = null;
export function mailReady() { return !!process.env.SMTP_HOST; }
function tr() {
  if (!mailReady()) return null;
  return (transport ??= nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE) === 'true',
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    disableFileAccess: true,
    disableUrlAccess: true,
  }));
}

async function send(to, subject, html, text) {
  const t = tr();
  const at = Date.now();
  if (!t) {
    run('INSERT INTO email_log(recipient, subject, status, error, at) VALUES (?,?,?,?,?)', to, subject, 'skipped', 'SMTP غير مضبوط', at);
    console.log(`[mail:skipped] → ${to} | ${subject}`);
    return false;
  }
  try {
    await t.sendMail({ from: process.env.MAIL_FROM || process.env.SMTP_USER, to: clean(to), subject: clean(subject), html, text });
    run('INSERT INTO email_log(recipient, subject, status, at) VALUES (?,?,?,?)', to, subject, 'sent', at);
    return true;
  } catch (e) {
    run('INSERT INTO email_log(recipient, subject, status, error, at) VALUES (?,?,?,?,?)', to, subject, 'failed', String(e.message).slice(0, 300), at);
    console.error('[mail:failed]', e.message);
    return false;
  }
}

function layout(title, body) {
  const s = getSettings();
  return `<!doctype html><html lang="ar" dir="rtl"><body style="margin:0;background:#efeae2;font-family:Tahoma,Arial,sans-serif;color:#14110f">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#efeae2;padding:24px 0"><tr><td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;background:#ffffff">
<tr><td style="background:#000;padding:22px 26px;color:#efeae2;font:900 30px Impact,Arial,sans-serif;letter-spacing:1px" dir="ltr" align="right">RO<span style="color:#e1281c">X</span></td></tr>
<tr><td style="background:#e1281c;padding:16px 26px;color:#000;font-weight:900;font-size:20px">${esc(title)}</td></tr>
<tr><td style="padding:24px 26px;line-height:1.8;font-size:15px">${body}</td></tr>
<tr><td style="padding:16px 26px;border-top:1px solid #e5dfd5;color:#6b655e;font-size:12px">${esc(s.storeName)} — ${esc(s.tagline)}</td></tr>
</table></td></tr></table></body></html>`;
}

function itemsTable(o) {
  const rows = o.items.map((i) => `<tr><td style="padding:8px 0;border-bottom:1px solid #eee">${esc(i.name)}${i.size ? ` <small style="color:#6b655e">(${esc(i.size)})</small>` : ''} × ${i.qty}</td><td align="left" style="padding:8px 0;border-bottom:1px solid #eee;white-space:nowrap">${i.unit_price * i.qty} ر.س</td></tr>`).join('');
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:14px 0">${rows}
<tr><td style="padding:6px 0;color:#6b655e">الشحن</td><td align="left">${o.shipping ? o.shipping + ' ر.س' : 'مجاني'}</td></tr>
<tr><td style="padding:8px 0;font-weight:900;font-size:18px">الإجمالي</td><td align="left" style="font-weight:900;font-size:18px;color:#b81d12">${o.total} ر.س</td></tr></table>`;
}

const trackLink = (o) => process.env.PUBLIC_URL ? `<p><a href="${esc(new URL('/#track', process.env.PUBLIC_URL).href)}" style="display:inline-block;background:#000;color:#efeae2;padding:12px 22px;text-decoration:none;font-weight:700">تتبّع طلبك</a></p>` : '';

export function sendOrderConfirmation(o) {
  const s = getSettings();
  const pay = o.payment === 'bank'
    ? `<p style="background:#f6f2ec;padding:12px 14px"><b>الدفع بتحويل بنكي:</b><br>${esc(s.bankInfo || 'سيتم التواصل معك ببيانات التحويل.').replace(/\n/g, '<br>')}<br>اكتب رقم الطلب <b dir="ltr">${esc(o.code)}</b> في ملاحظة التحويل.</p>`
    : '<p>الدفع عند الاستلام.</p>';
  const body = `<p>هلا ${esc(o.customer_name)}، وصلنا طلبك وبنبدأ نجهّزه.</p>
<p>رقم الطلب: <b dir="ltr" style="font-size:18px">${esc(o.code)}</b></p>${itemsTable(o)}${pay}
<p style="color:#6b655e">العنوان: ${esc(o.city)} — ${esc(o.address)}</p>${trackLink(o)}`;
  const text = `طلبك ${o.code} وصلنا. الإجمالي ${o.total} ر.س.`;
  return send(o.email, `تأكيد طلبك ${o.code} — ${s.storeName}`, layout('شكرًا على طلبك', body), text);
}

export function sendStatusUpdate(o) {
  const s = getSettings();
  const msg = {
    1: 'بدأنا نجهّز طلبك.',
    2: 'طلبك انشحن وفي الطريق لك!',
    3: 'تم توصيل طلبك. نتمنى يعجبك!',
    4: 'تم إلغاء طلبك. إذا عندك أي استفسار رد على هذا الإيميل.',
  }[o.status];
  if (!msg) return Promise.resolve(false);
  const body = `<p>هلا ${esc(o.customer_name)}،</p><p style="font-size:18px;font-weight:700">${msg}</p>
<p>رقم الطلب: <b dir="ltr">${esc(o.code)}</b> — الحالة: <b>${STATUS[o.status]}</b></p>${trackLink(o)}`;
  return send(o.email, `تحديث طلبك ${o.code}: ${STATUS[o.status]}`, layout('تحديث على طلبك', body), `${msg} (${o.code})`);
}

export function notifyOwner(o) {
  const s = getSettings();
  const to = s.notifyEmail || process.env.ADMIN_NOTIFY_EMAIL;
  if (!to) return Promise.resolve(false);
  const body = `<p>طلب جديد من <b>${esc(o.customer_name)}</b> (${esc(o.phone)}) — ${esc(o.city)}</p>${itemsTable(o)}`;
  return send(to, `طلب جديد ${o.code} — ${o.total} ر.س`, layout('طلب جديد', body), `طلب جديد ${o.code}`);
}

export function sendTest(to) {
  return send(to, 'رسالة تجريبية من متجرك', layout('الإيميلات شغّالة ✓', '<p>إذا وصلتك هذه الرسالة فإعدادات SMTP صحيحة.</p>'), 'SMTP OK');
}

export { STATUS };
