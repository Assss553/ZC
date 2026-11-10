// منتجات افتتاحية تظهر أول مرة فقط (تقدر تحذفها من لوحة التحكم)
import { one, run } from './db.js';
import { randomToken } from './security.js';

const S = (kind, o) => ({ kind, d: '', x: 0, y: 0, r: 0, text: '', fontSize: 0, fill: '#000000', stroke: 'none', strokeWidth: 0, opacity: 1, rotate: 0, ...o });

const ART = {
  slash: [
    S('path', { d: 'M78 20 L132 20 L118 180 L64 180 Z', fill: '#e1281c' }),
    S('text', { x: 100, y: 104, text: 'ROX', fontSize: 92, fill: '#efeae2' }),
    S('path', { d: 'M30 160 H170', stroke: '#efeae2', strokeWidth: 4, fill: 'none' }),
    S('text', { x: 100, y: 176, text: 'EST. 2022', fontSize: 14, fill: '#efeae2' }),
  ],
  diamond: [
    S('path', { d: 'M100 14 L186 100 L100 186 L14 100 Z', fill: '#e1281c' }),
    S('path', { d: 'M100 34 L166 100 L100 166 L34 100 Z', fill: 'none', stroke: '#0b0a09', strokeWidth: 4 }),
    S('path', { d: 'M62 62 L138 138 M138 62 L62 138', stroke: '#0b0a09', strokeWidth: 18, fill: 'none' }),
    S('path', { d: 'M62 62 L138 138 M138 62 L62 138', stroke: '#efeae2', strokeWidth: 4, fill: 'none' }),
  ],
  sun: [
    S('circle', { x: 100, y: 92, r: 62, fill: '#e1281c' }),
    S('path', { d: 'M30 96 H170 V104 H30 Z M30 116 H170 V126 H30 Z M30 138 H170 V150 H30 Z', fill: '#14110f' }),
    S('text', { x: 100, y: 178, text: 'NO LIMITS', fontSize: 26, fill: '#14110f' }),
  ],
  chapter: [
    S('text', { x: 100, y: 64, text: 'THE NEXT', fontSize: 34, fill: '#efeae2' }),
    S('text', { x: 100, y: 112, text: 'CHAPTER', fontSize: 52, fill: '#e1281c' }),
    S('path', { d: 'M40 140 L160 140 L150 152 L30 152 Z', fill: '#efeae2' }),
    S('circle', { x: 100, y: 176, r: 6, fill: '#e1281c' }),
  ],
};

export function seed() {
  if (one('SELECT COUNT(*) AS n FROM products').n > 0) return;
  const now = Date.now();
  const CL = JSON.stringify(['S', 'M', 'L', 'XL', 'XXL']);
  const items = [
    ['هودي ROX سلاش', 'هودي ثقيل بقصّة واسعة وطباعة سلاش ROX الحمراء على الصدر. دافي، ناعم، ويثبت حضورك.', 'hood', 279, 0, '#e1281c', '#0b0a09', ART.slash, CL, [['الخامة', 'قطن 80% / بوليستر 20%'], ['الوزن', '400 جرام'], ['القصّة', 'أوفر سايز'], ['الطباعة', 'سكرين برنت']]],
    ['تيشيرت الماسة', 'تيشيرت قطن ثقيل عليه علامة الماسة من هوية ROX. قطعة يومية تمشي مع كل شي.', 'tee', 139, 0, '#14110f', '#efeae2', ART.diamond, CL, [['الخامة', 'قطن 100%'], ['الوزن', '240 جرام'], ['القصّة', 'بوكسي']]],
    ['سويت شيرت بلا حدود', 'سويت شيرت بشمس حمراء وخطوط أفق. للي يشوفون أبعد.', 'crew', 219, 249, '#efeae2', '#d9d2c5', ART.sun, CL, [['الخامة', 'قطن مُمشّط'], ['الوزن', '360 جرام'], ['إصدار', 'محدود']]],
    ['ماوس باد الفصل الجاي', 'ماوس باد كبير بسطح ناعم وقاعدة مطاط ما تنزلق.', 'pad', 89, 0, '#2a2725', '#0b0a09', ART.chapter, '[]', [['المقاس', '90×40 سم'], ['السماكة', '4 ملم']]],
  ];
  for (const [name, desc, type, price, cmp, bg, fg, art, sizes, specs] of items) {
    run(`INSERT INTO products(slug, name, description, type, price, compare_price, bg, fg, art_svg, sizes, specs, tags, status, created_at, updated_at)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?, 'published', ?, ?)`,
      randomToken(6).toLowerCase().replace(/[^a-z0-9]/g, 'x'), name, desc, type, price, cmp || null, bg, fg,
      JSON.stringify(art), sizes, JSON.stringify(specs.map(([label, value]) => ({ label, value }))), '["ROX"]', now, now);
  }
}
