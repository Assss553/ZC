/* ROX Store | rox_police | All rights reserved. */
/* Division emblems + app icons, drawn as SVG (no images needed). */
const Emblem = (() => {
    let uid = 0;
    const SHIELD = 'M32 2 L60 11 V33 C60 52 47 64 32 70 C17 64 4 52 4 33 V11 Z';
    const GLOSS = 'M9 13.5 L32 6 L55 13.5 V28 C42 24 22 24 9 28 Z';
    const F = (d) => `<path d="${d}" fill="#fff" stroke="none"/>`;

    // symbols, drawn in the shield (64 x 72), white stroke
    const G = {
        swat: `<circle cx="32" cy="34" r="12.5"/><path d="M32 15.5v8M32 44.5v8M13.5 34h8M42.5 34h8"/><circle cx="32" cy="34" r="3" fill="#fff" stroke="none"/>
               <path d="M23 25l3 3M41 25l-3 3M23 43l3-3M41 43l-3-3" stroke-width="2"/>`,
        air: `<path d="M13 21.5h38"/><path d="M32 21.5v6"/><path d="M19 35.5c0-4.5 4.5-8 11.5-8h4c6 0 10.5 3.5 10.5 8.5s-4.2 7-10.5 7H25.5C21.5 43 19 40.5 19 35.5z"/>
              <path d="M45.5 35.5h8l2-4.5"/><path d="M23 49h20M27 43.5v5.5M39 43.5v5.5"/><path d="M22 34.5h9" stroke-width="2"/>`,
        ops: `<path d="M32 23l-7 27M32 23l7 27M26.6 43.5h10.8M28.4 36.5h7.2"/><circle cx="32" cy="21.5" r="2.6" fill="#fff" stroke="none"/>
              <path d="M24.5 14.5q-4 7 0 14M39.5 14.5q4 7 0 14M19 11q-6.5 10.5 0 21M45 11q6.5 10.5 0 21"/>`,
        k9: `${F('M32 32c-6.5 0-11.5 6.5-11.5 11.5 0 4 3 5.5 6 5.5 2.2 0 3.6-1.2 5.5-1.2s3.3 1.2 5.5 1.2c3 0 6-1.5 6-5.5C43.5 38.5 38.5 32 32 32z')}
             <ellipse cx="21.5" cy="28.5" rx="3.4" ry="4.3" fill="#fff" stroke="none" transform="rotate(-20 21.5 28.5)"/><ellipse cx="28" cy="21.5" rx="3.4" ry="4.5" fill="#fff" stroke="none"/>
             <ellipse cx="36" cy="21.5" rx="3.4" ry="4.5" fill="#fff" stroke="none"/><ellipse cx="42.5" cy="28.5" rx="3.4" ry="4.3" fill="#fff" stroke="none" transform="rotate(20 42.5 28.5)"/>`,
        traffic: `<path d="M16.5 45a15.5 15.5 0 1 1 31 0"/><path d="M32 29.5v3.5M20.5 34.5l2.6 2.4M43.5 34.5l-2.6 2.4M17.5 45h3.5M43 45h3.5" stroke-width="2.2"/>
                  <path d="M32 45L41 33.5" stroke-width="3.2"/><circle cx="32" cy="45" r="3" fill="#fff" stroke="none"/><path d="M22 51h20" stroke-width="2"/>`,
        detective: `<circle cx="29" cy="31" r="10"/><path d="M36.5 38.5l9.5 9.5" stroke-width="5"/><path d="M24 28a6 6 0 0 1 5-4" stroke-width="2"/>
                    <path d="M25.5 34.5c1-2 2-3 3.5-3s2.5 1 3.5 3" stroke-width="1.8"/>`,
        marine: `<circle cx="32" cy="17.5" r="3.2"/><path d="M32 21v28"/><path d="M24.5 27.5h15"/><path d="M17.5 38.5c0 7.5 6.5 11.5 14.5 11.5s14.5-4 14.5-11.5"/>
                 <path d="M14 42.5l3.5-4.5 3.5 4.5M43 42.5l3.5-4.5 3.5 4.5"/>`,
        motor: `<circle cx="20" cy="42" r="6.5"/><circle cx="44" cy="42" r="6.5"/><path d="M20 42l8-11h9l7 11"/><path d="M28 31l-2.5-4h-4.5M37 31l3-6h5"/><path d="M30.5 36.5h6" stroke-width="2"/>`,
        gang: `<path d="M27.5 37.5l9-9"/><path d="M24 31.5l-4.5 4.5a5.5 5.5 0 0 0 7.8 7.8l4.5-4.5"/><path d="M40 36.5l4.5-4.5a5.5 5.5 0 0 0-7.8-7.8L32.2 28.7"/>
               <path d="M18 20l4 4M46 48l-4-4" stroke-width="2"/>`,
        fto: `<path d="M13 29.5L32 21l19 8.5L32 38z"/><path d="M21.5 33.5v8c0 3.2 4.7 5.5 10.5 5.5s10.5-2.3 10.5-5.5v-8"/><path d="M51 29.5v10.5"/><circle cx="51" cy="42" r="1.8" fill="#fff" stroke="none"/>`,
        ia: `<path d="M32 19v29M23.5 49h17M17 25.5h30"/><circle cx="32" cy="18" r="2.4" fill="#fff" stroke="none"/>
             <path d="M17 25.5l-5 10.5h10zM47 25.5l-5 10.5h10z" stroke-width="2.2"/><path d="M11.5 36c0 3 2.5 4.5 5.5 4.5s5.5-1.5 5.5-4.5M41.5 36c0 3 2.5 4.5 5.5 4.5s5.5-1.5 5.5-4.5" stroke-width="2.2"/>`,
        gold: `<path d="M32 18l4 8.5 9.5 1.2-7 6.4 1.8 9.4L32 39l-8.3 4.5 1.8-9.4-7-6.4 9.5-1.2z" fill="#fff" stroke="none"/>`,
    };

    const shade = (hex, f) => {
        const m = /^#?([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(hex || '') || [0, 'ff', '5a', '1f'];
        return '#' + [m[1], m[2], m[3]].map(x => Math.max(0, Math.min(255, Math.round(parseInt(x, 16) * f + (f > 1 ? 18 : 0)))).toString(16).padStart(2, '0')).join('');
    };
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    /* shield emblem: badge('swat', '#ff4d5e', { size: 64, label: 'SWAT' }) */
    function badge(glyph, color, o = {}) {
        const id = 'em' + (uid++), size = o.size || 56, c = color || '#ff5a1f';
        const ribbon = o.label ? `<path d="M3 55.5h58l-4 5 4 5H3l4-5z" fill="#0c0c0f" stroke="${shade(c, 1.15)}" stroke-width="1.3"/>
            <text x="32" y="63" text-anchor="middle" font-family="'Barlow Condensed','Rajdhani',sans-serif" font-style="italic" font-weight="800" font-size="${o.label.length > 6 ? 7 : 8.4}" letter-spacing=".8" fill="#fff">${esc(o.label.toUpperCase())}</text>` : '';
        return `<svg class="emblem" width="${size}" height="${Math.round(size * 72 / 64)}" viewBox="0 0 64 72" aria-hidden="true">
            <defs>
                <linearGradient id="${id}g" x1="0" y1="0" x2=".35" y2="1"><stop offset="0" stop-color="${shade(c, 1.25)}"/><stop offset=".55" stop-color="${c}"/><stop offset="1" stop-color="${shade(c, .42)}"/></linearGradient>
                <linearGradient id="${id}r" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5a5a62"/><stop offset=".5" stop-color="#1b1b20"/><stop offset="1" stop-color="#3a3a42"/></linearGradient>
                <linearGradient id="${id}h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".5"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
            </defs>
            <path d="${SHIELD}" fill="url(#${id}r)"/>
            <path d="${SHIELD}" fill="url(#${id}g)" transform="translate(32 36) scale(.88) translate(-32 -36)"/>
            <path d="${SHIELD}" fill="none" stroke="#fff" stroke-opacity=".38" stroke-width="1.3" transform="translate(32 36) scale(.76) translate(-32 -36)"/>
            <path d="${GLOSS}" fill="url(#${id}h)" opacity=".55"/>
            <g fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="filter:drop-shadow(0 1.5px 1.5px rgba(0,0,0,.45))">${G[glyph] || G.gold}</g>
            ${ribbon}
        </svg>`;
    }

    /* app icons (rounded square) */
    function star(cx, cy, r1, r2, n) {
        let d = '';
        for (let i = 0; i < n * 2; i++) {
            const r = i % 2 ? r2 : r1, a = Math.PI / n * i - Math.PI / 2;
            d += (i ? 'L' : 'M') + (cx + r * Math.cos(a)).toFixed(2) + ' ' + (cy + r * Math.sin(a)).toFixed(2);
        }
        return d + 'Z';
    }
    const APP = {
        mdt: ['#ff7a3d', '#c93a0c', `<circle cx="32" cy="32" r="19" fill="none" stroke="#fff" stroke-width="2.6" opacity=".9"/>
              <path d="${star(32, 32, 15.5, 7.2, 6)}" fill="#fff"/><circle cx="32" cy="32" r="4.6" fill="#d8400f"/><circle cx="32" cy="32" r="2" fill="#fff"/>`],
        boss: ['#9b7bff', '#4a24cf', `<path d="M17 25l15-8 15 8M17 34l15-8 15 8M17 43l15-8 15 8" fill="none" stroke="#fff" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round"/>
               <path d="${star(32, 49.5, 4.6, 2, 5)}" fill="#ffd36b"/>`],
    };
    function app(kind) {
        const a = APP[kind]; if (!a) return '';
        const id = 'ap' + (uid++);
        return `<svg class="app-svg" viewBox="0 0 64 64" aria-hidden="true"><defs>
            <linearGradient id="${id}" x1="0" y1="0" x2=".4" y2="1"><stop offset="0" stop-color="${a[0]}"/><stop offset="1" stop-color="${a[1]}"/></linearGradient>
            <linearGradient id="${id}h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>
            <rect width="64" height="64" rx="15" fill="url(#${id})"/><rect width="64" height="64" rx="15" fill="url(#${id}h)"/>
            <g style="filter:drop-shadow(0 2px 2px rgba(0,0,0,.3))">${a[2]}</g></svg>`;
    }

    return { badge, app, glyphs: Object.keys(G) };
})();
