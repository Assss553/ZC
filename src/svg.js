// محرّك صور المنتجات.
// الذكاء الاصطناعي ما يكتب SVG مباشرة: يرجّع قائمة أشكال (JSON) ونحن نبني الـSVG بأنفسنا
// من قائمة بيضاء صارمة. كذا يستحيل حقن سكربت أو روابط خارجية داخل الصور.

export const TYPES = {
  hood: { ar: 'هودي', en: 'HOODIE' },
  tee: { ar: 'تيشيرت', en: 'TEE' },
  crew: { ar: 'سويت شيرت', en: 'CREWNECK' },
  cap: { ar: 'كاب', en: 'CAP' },
  tote: { ar: 'شنطة قماش', en: 'TOTE' },
  pad: { ar: 'ماوس باد', en: 'MOUSEPAD' },
};

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const num = (v, min, max, d = 0) => { const n = Number(v); return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n * 10) / 10)) : d; };
const col = (v, d = 'none') => (/^#[0-9a-f]{6}$/i.test(String(v)) ? String(v).toLowerCase() : v === 'none' ? 'none' : d);
const PATH_OK = /^[MmLlHhVvCcSsQqTtAaZz0-9.,\s-]{1,4000}$/;

// يحوّل أشكال الذكاء الاصطناعي (لوحة 200×200) إلى عناصر SVG آمنة
export function renderArt(shapes) {
  if (!Array.isArray(shapes)) return '';
  let out = '';
  for (const s of shapes.slice(0, 60)) {
    if (!s || typeof s !== 'object') continue;
    const fill = col(s.fill, '#000000');
    const stroke = col(s.stroke, 'none');
    const sw = num(s.strokeWidth, 0, 30);
    const op = num(s.opacity, 0, 1, 1);
    const rot = num(s.rotate, -360, 360);
    const common = `fill="${fill}"${stroke !== 'none' && sw > 0 ? ` stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="round"` : ''}${op < 1 ? ` opacity="${op}"` : ''}`;
    const x = num(s.x, -50, 250), y = num(s.y, -50, 250);
    const tr = rot ? ` transform="rotate(${rot} ${x} ${y})"` : '';
    if (s.kind === 'path' && typeof s.d === 'string' && PATH_OK.test(s.d)) {
      out += `<path d="${s.d.replace(/\s+/g, ' ').trim()}" ${common}${rot ? ` transform="rotate(${rot} 100 100)"` : ''}/>`;
    } else if (s.kind === 'circle') {
      out += `<circle cx="${x}" cy="${y}" r="${num(s.r, 0.5, 150, 10)}" ${common}/>`;
    } else if (s.kind === 'text' && s.text) {
      const t = String(s.text).replace(/[\u0000-\u001f]/g, '').slice(0, 40);
      const fs = num(s.fontSize, 4, 120, 20);
      const latin = /^[\x20-\x7e]+$/.test(t);
      out += `<text x="${x}" y="${y}" font-size="${fs}" text-anchor="middle" dominant-baseline="middle" font-family="${latin ? "'Bebas Neue',Impact,'Arial Narrow',sans-serif" : 'Tajawal,Tahoma,sans-serif'}" font-weight="900"${latin ? ' letter-spacing="1"' : ' direction="rtl"'} ${common}${tr}>${esc(t)}</text>`;
    }
  }
  return out;
}

// رسومات القطع (لوحة 400×400) + منطقة الطباعة لكل نوع
const G = {
  tee: {
    body: 'M146 58 L104 70 L38 112 L64 176 L106 158 L106 350 Q200 364 294 350 L294 158 L336 176 L362 112 L296 70 L254 58 Q200 98 146 58 Z',
    extra: (c) => `<path d="M146 58 Q200 104 254 58" fill="none" stroke="${c.dark}" stroke-width="9"/><path d="M106 158 L96 118 M294 158 L304 118" stroke="${c.dark}" stroke-width="2" opacity=".5"/>`,
    print: [140, 120, 0.6],
  },
  crew: {
    body: 'M142 62 L98 76 L44 140 L40 306 L80 312 L100 186 L102 344 Q200 360 298 344 L300 186 L320 312 L360 306 L356 140 L302 76 L258 62 Q200 96 142 62 Z',
    extra: (c) => `<path d="M142 62 Q200 106 258 62" fill="none" stroke="${c.dark}" stroke-width="12"/><path d="M102 334 Q200 350 298 334" fill="none" stroke="${c.dark}" stroke-width="10"/><path d="M40 296 L80 302" stroke="${c.dark}" stroke-width="12"/><path d="M360 296 L320 302" stroke="${c.dark}" stroke-width="12"/>`,
    print: [140, 122, 0.6],
  },
  hood: {
    body: 'M126 80 L84 96 L38 160 L44 302 L82 306 L98 198 L104 354 Q200 368 296 354 L302 198 L318 306 L356 302 L362 160 L316 96 L274 80 Q270 20 200 16 Q130 20 126 80 Z',
    extra: (c) => `<path d="M148 84 Q200 150 252 84 Q244 46 200 44 Q156 46 148 84 Z" fill="${c.dark}"/><path d="M184 118 L178 186 M216 118 L222 186" stroke="${c.light}" stroke-width="4" stroke-linecap="round"/><circle cx="178" cy="190" r="4" fill="${c.light}"/><circle cx="222" cy="190" r="4" fill="${c.light}"/><path d="M142 270 L258 270 L278 330 L122 330 Z" fill="${c.dark}" opacity=".45"/><path d="M104 344 Q200 358 296 344" fill="none" stroke="${c.dark}" stroke-width="10"/><path d="M44 292 L82 296 M356 292 L318 296" stroke="${c.dark}" stroke-width="12"/>`,
    print: [143, 140, 0.57],
  },
  cap: {
    body: 'M78 252 Q76 112 200 104 Q324 112 322 252 Z',
    extra: (c) => `<path d="M200 252 L364 252 Q384 262 356 280 Q290 300 200 274 Z" fill="${c.dark}"/><path d="M200 104 L200 252 M140 116 Q120 180 124 252 M260 116 Q280 180 276 252" fill="none" stroke="${c.dark}" stroke-width="2" opacity=".6"/><circle cx="200" cy="104" r="7" fill="${c.dark}"/>`,
    print: [152, 140, 0.48],
  },
  tote: {
    body: 'M96 150 L304 150 L324 360 L76 360 Z',
    extra: (c) => `<path d="M140 152 Q138 62 200 60 Q262 62 260 152" fill="none" stroke="${c.dark}" stroke-width="14" stroke-linecap="round"/><path d="M96 170 L304 170" stroke="${c.dark}" stroke-width="2" opacity=".5"/>`,
    print: [130, 186, 0.7],
  },
  pad: {
    body: 'M48 110 H352 Q370 110 370 128 V272 Q370 290 352 290 H48 Q30 290 30 272 V128 Q30 110 48 110 Z',
    extra: (c) => `<path d="M48 110 H352 Q370 110 370 128 V272 Q370 290 352 290 H48 Q30 290 30 272 V128 Q30 110 48 110 Z" fill="none" stroke="${c.dark}" stroke-width="4"/>`,
    print: [118, 118, 0.82],
  },
};

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const ch = [n >> 16, (n >> 8) & 255, n & 255].map((v) => Math.round(amt < 0 ? v * (1 + amt) : v + (255 - v) * amt));
  return '#' + ch.map((v) => v.toString(16).padStart(2, '0')).join('');
}

// صورة المنتج النهائية (تُخدم كملف SVG مستقل عبر <img>، فلا تنفّذ أي سكربت)
export function renderMockup(p) {
  const g = G[p.type] || G.tee;
  const bg = col(p.bg, '#0b0a09'), fg = col(p.fg, '#efeae2');
  const c = { dark: shade(fg, -0.22), light: shade(fg, 0.55) };
  let art = '';
  try { art = renderArt(JSON.parse(p.art_svg || '[]')); } catch { art = ''; }
  const [px, py, sc] = g.print;
  const label = TYPES[p.type]?.en || '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="800" height="800">
<defs><linearGradient id="s" x1="0" x2="1"><stop offset="0" stop-color="#000" stop-opacity=".28"/><stop offset=".35" stop-color="#fff" stop-opacity=".10"/><stop offset=".65" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".32"/></linearGradient>
<clipPath id="b"><path d="${g.body}"/></clipPath><filter id="d" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#000" flood-opacity=".35"/></filter></defs>
<rect width="400" height="400" fill="${bg}"/>
<path d="M262 -20 L318 -20 L238 420 L182 420 Z" fill="#000" opacity=".12"/>
<text x="200" y="388" text-anchor="middle" font-family="'Bebas Neue',Impact,sans-serif" font-size="64" fill="none" stroke="${fg}" stroke-opacity=".18" stroke-width="1.2" letter-spacing="4">${esc(label)}</text>
<g filter="url(#d)"><path d="${g.body}" fill="${fg}"/></g>
${g.extra(c)}
<g clip-path="url(#b)"><g transform="translate(${px} ${py}) scale(${sc})">${art}</g></g>
<path d="${g.body}" fill="url(#s)" pointer-events="none"/>
</svg>`;
}
