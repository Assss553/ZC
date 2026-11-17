/* ROX Laundry minigame · © ROX Store */
const $ = (q) => document.querySelector(q);
const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rox_laundry';
const post = (n, d = {}) => fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d) }).catch(() => {});
const T = {
  ar: { washer: 'الغسالة', dryer: 'النشافة', fold: 'طاولة الطي', load: 'حط التيشيرت', loadH: 'اسحب التيشيرت الوسخ لداخل الغسالة', soap: 'المنظف', soapH: 'اضغط مطوّل على العلبة وفك عند المنطقة الخضراء',
    prog: 'اختر البرنامج', progH: 'شوف علامة التيشيرت واختر الحرارة، وحط الفلوس', start: 'تشغيل', wash: 'جاري الغسيل', washH: 'انتبه للتنبيهات!', unbalanced: 'الغسيل مو متوازن!', fix: 'عدّل',
    take: 'طلّع التيشيرت', clean: 'نظيف', wet: 'مبلول', dryLoad: 'حط التيشيرت المبلول في النشافة', heat: 'اختر حرارة التنشيف', low: 'منخفضة', med: 'متوسطة', high: 'عالية',
    drying: 'جاري التنشيف', lint: 'الفلتر انسد! نظّف الوبر', foldH: 'اطوِ التيشيرت: اضغط على الجزء المضيء بالترتيب', done: 'تم!', finish: 'استلم', care: 'علامة العناية', coins: 'حط العملات', paid: 'تم الدفع',
    score: 'الجودة', tooMuch: 'منظف كثير! رغوة', tooLittle: 'منظف قليل', perfect: 'ممتاز!' },
  en: { washer: 'Washer', dryer: 'Dryer', fold: 'Folding table', load: 'Load the T-shirt', loadH: 'Drag the dirty T-shirt into the washer', soap: 'Detergent', soapH: 'Hold the bottle and let go in the green zone',
    prog: 'Pick the program', progH: 'Check the care tag, pick the temperature and pay', start: 'Start', wash: 'Washing', washH: 'Watch out for alerts!', unbalanced: 'Load unbalanced!', fix: 'Fix',
    take: 'Take the T-shirt out', clean: 'Clean', wet: 'Wet', dryLoad: 'Put the wet T-shirt in the dryer', heat: 'Pick the heat', low: 'Low', med: 'Medium', high: 'High',
    drying: 'Drying', lint: 'Lint filter clogged! Clean it', foldH: 'Fold the T-shirt: click the glowing part in order', done: 'Done!', finish: 'Collect', care: 'Care tag', coins: 'Insert coins', paid: 'Paid',
    score: 'Quality', tooMuch: 'Too much! Foam', tooLittle: 'Too little', perfect: 'Perfect!' },
};
let L = T.ar, S = null;

const shirt = (state) => {   // state: dirty | wet | clean
  const c = state === 'wet' ? '#4e86c4' : '#ff6a2a', o = state === 'wet' ? '#3a6aa0' : '#d9480f';
  const stains = state === 'dirty' ? '<ellipse cx="78" cy="92" rx="16" ry="11" fill="#6b4a2a" opacity=".75"/><ellipse cx="128" cy="130" rx="12" ry="9" fill="#5a3d22" opacity=".7"/><ellipse cx="96" cy="150" rx="9" ry="6" fill="#7a5530" opacity=".7"/>' : '';
  const drops = state === 'wet' ? '<circle cx="70" cy="170" r="4" fill="#9fd0ff"/><circle cx="130" cy="176" r="3" fill="#9fd0ff"/>' : '';
  const shine = state === 'clean' ? '<path d="M60 70l8 -8M150 100l10-6" stroke="#fff" stroke-width="5" stroke-linecap="round"/>' : '';
  return `<svg viewBox="0 0 200 200"><path d="M70 20 L40 32 L8 66 L32 92 L50 78 L50 182 L150 182 L150 78 L168 92 L192 66 L160 32 L130 20 Q100 44 70 20Z" fill="${c}" stroke="${o}" stroke-width="5" stroke-linejoin="round"/>
    <text x="100" y="128" text-anchor="middle" font-size="34" font-weight="900" fill="#fff" opacity=".9">ROX</text>${stains}${drops}${shine}</svg>`;
};
const machine = (dry) => `<div class="machine ${dry ? 'dry' : ''}" id="mach"><div class="top"><div class="drawer" id="drawer"></div><div class="disp" id="disp">--:--</div><div class="knob"></div></div>
  <div class="door"><div class="drum" id="drum"><div class="holes"></div><div class="water"></div><div class="load" id="dload"></div><div class="glass"></div></div></div></div>`;
const ring = (p) => { const C = 2 * Math.PI * 48; return `<svg class="ring" viewBox="0 0 110 110"><circle class="bg" cx="55" cy="55" r="48"/><circle class="fg" cx="55" cy="55" r="48" stroke-dasharray="${C}" stroke-dashoffset="${C * (1 - p)}" transform="rotate(-90 55 55)"/></svg>`; };
const sfx = (n) => post('sound', { name: n });

function steps(n, i) { $('#steps').innerHTML = Array.from({ length: n }, (_, k) => `<b class="${k === i ? 'on' : k < i ? 'done' : ''}"></b>`).join(''); }
function hint(t) { $('#hint').textContent = t; }
function score() { $('#score').textContent = S ? `${L.score}: ${Math.round(S.score * 100)}%` : ''; }

// drag & drop helper: drag `src` and drop on `target`
function dragTo(src, target, html, onDrop) {
  target.classList.add('drop');
  src.onmousedown = (e) => {
    const g = document.createElement('div'); g.className = 'drag'; g.innerHTML = html; document.body.appendChild(g);
    const mv = (ev) => { g.style.left = ev.clientX + 'px'; g.style.top = ev.clientY + 'px'; }; mv(e); src.style.opacity = .25;
    const up = (ev) => {
      document.removeEventListener('mousemove', mv); document.removeEventListener('mouseup', up); g.remove(); src.style.opacity = 1;
      const r = target.getBoundingClientRect();
      if (ev.clientX > r.left && ev.clientX < r.right && ev.clientY > r.top && ev.clientY < r.bottom) { target.classList.remove('drop'); sfx('click'); onDrop(); }
    };
    document.addEventListener('mousemove', mv); document.addEventListener('mouseup', up);
  };
}

function coins(n, done) {
  return { html: `<div class="col"><div class="muted">${L.coins}</div><div class="coins">${Array.from({ length: n }, () => `<div class="coin">$1</div>`).join('')}</div></div>`,
    bind: () => { let left = n; if (!n) return done(); document.querySelectorAll('.coin').forEach((c) => c.onclick = () => { if (c.classList.contains('used')) return; c.classList.add('used'); sfx('coin'); if (--left === 0) done(); }); } };
}

// ---------------------------------------------------------------- WASHER
function washer() {
  $('#title').textContent = L.washer; S.score = 1;
  const care = [30, 40, 60][Math.floor(Math.random() * 3)];
  const st1 = () => { steps(5, 0); hint(L.loadH);
    $('#stage').innerHTML = `${machine(false)}<div class="col"><h3>${L.load}</h3><div class="basket"><div class="shirt" id="sh">${shirt('dirty')}</div></div><div class="tag">🏷 ${L.care}: ${care}°</div></div>`;
    dragTo($('#sh'), $('#mach .door'), shirt('dirty'), () => { $('#dload').innerHTML = `<div style="width:150px">${shirt('dirty')}</div>`; $('#sh').remove(); setTimeout(st2, 500); }); };
  const st2 = () => { steps(5, 1); hint(L.soapH);
    const zl = 45 + Math.random() * 25, zh = zl + 16;
    $('#stage').innerHTML = `${machine(false)}<div class="col"><h3>${L.soap}</h3><div style="display:flex;gap:30px;align-items:center"><div class="bottle" id="bt"><span>ROX<br>SOAP</span></div>
      <div class="meter"><div class="zone" style="bottom:${zl}%;height:${zh - zl}%"></div><div class="fill" id="fill"></div></div></div><div class="muted" id="msg"></div></div>`;
    $('#dload').innerHTML = `<div style="width:150px">${shirt('dirty')}</div>`;
    let v = 0, iv = null; const bt = $('#bt');
    bt.onmousedown = () => { bt.classList.add('pour'); iv = setInterval(() => { v = Math.min(100, v + 1.1); $('#fill').style.height = v + '%'; }, 30); };
    const rel = () => { if (!iv) return; clearInterval(iv); iv = null; bt.classList.remove('pour');
      let q = 1, m = L.perfect; if (v < zl) { q = Math.max(0.2, 1 - (zl - v) / 40); m = L.tooLittle; } else if (v > zh) { q = Math.max(0.2, 1 - (v - zh) / 40); m = L.tooMuch; }
      S.soap = q; S.score = q; score(); $('#msg').textContent = m; sfx(q > .9 ? 'done' : 'click'); bt.onmousedown = null; setTimeout(st3, 900); };
    document.onmouseup = rel; };
  const st3 = () => { steps(5, 2); hint(L.progH); let temp = null;
    const c = coins(S.data.prices.wash, () => { $('#go').disabled = false; $('#go').style.opacity = 1; $('#paid').textContent = '✓ ' + L.paid; });
    $('#stage').innerHTML = `${machine(false)}<div class="col"><h3>${L.prog}</h3><div class="tag">🏷 ${L.care}: ${care}°</div>
      <div class="opts">${[30, 40, 60, 90].map((t) => `<button class="btn ghost tmp" data-t="${t}">${t}°</button>`).join('')}</div>${c.html}<div class="muted" id="paid"></div>
      <button class="btn" id="go" disabled style="opacity:.4">${L.start} ▶</button></div>`;
    $('#dload').innerHTML = `<div style="width:150px">${shirt('dirty')}</div>`; c.bind();
    document.querySelectorAll('.tmp').forEach((b) => b.onclick = () => { document.querySelectorAll('.tmp').forEach((x) => x.classList.remove('sel')); b.classList.add('sel'); temp = +b.dataset.t; sfx('click'); $('#disp').textContent = temp + '°C'; });
    $('#go').onclick = () => { if (!temp) return sfx('error'); S.temp = temp === care ? 1 : Math.abs(temp - care) <= 20 ? 0.7 : 0.4; st4(); }; };
  const st4 = () => { steps(5, 3); hint(L.washH);
    $('#stage').innerHTML = `${machine(false)}<div class="col"><h3>${L.wash}</h3><div id="rg">${ring(0)}</div><div class="muted" id="msg"></div></div>`;
    $('#dload').innerHTML = `<div style="width:150px">${shirt('dirty')}</div>`;
    const drum = $('#drum'); drum.classList.add('wet');
    setTimeout(() => drum.classList.add('spin'), 800);
    for (let i = 0; i < 9; i++) { const b = document.createElement('div'); b.className = 'bub'; const s = 8 + Math.random() * 18; Object.assign(b.style, { width: s + 'px', height: s + 'px', left: 20 + Math.random() * 160 + 'px', bottom: '10px', animationDelay: Math.random() * 2.4 + 's' }); drum.appendChild(b); }
    const dur = S.data.times.wash * 1000, t0 = Date.now(); let paused = 0, pAt = 0, ev = 0.35 + Math.random() * 0.35, evDone = false, fixQ = 1;
    const tick = setInterval(() => {
      const el = Date.now() - t0 - paused - (pAt ? Date.now() - pAt : 0), p = Math.min(1, el / dur);
      $('#rg').innerHTML = ring(p); const left = Math.max(0, Math.ceil((dur - el) / 1000)); $('#disp').textContent = `00:${String(left).padStart(2, '0')}`;
      if (p > 0.6) $('#dload').innerHTML = `<div style="width:150px">${shirt('clean')}</div>`;
      if (!evDone && p >= ev) { evDone = true; pAt = Date.now(); $('#mach').classList.add('shake'); sfx('error');
        const a = document.createElement('div'); a.className = 'alert'; a.innerHTML = `⚠ ${L.unbalanced} <button class="btn ghost" id="fx">${L.fix}</button>`; $('#stage').appendChild(a);
        const t1 = Date.now(); const to = setTimeout(() => fixIt(0.5), 3000);
        const fixIt = (q) => { clearTimeout(to); fixQ = q; a.remove(); $('#mach').classList.remove('shake'); paused += Date.now() - pAt; pAt = 0; };
        $('#fx').onclick = () => { sfx('click'); fixIt(Date.now() - t1 < 1500 ? 1 : 0.8); }; }
      if (p >= 1) { clearInterval(tick); drum.classList.remove('spin', 'wet'); sfx('done');
        S.score = S.soap * 0.45 + S.temp * 0.35 + fixQ * 0.2; score(); st5(); }
    }, 100); };
  const st5 = () => { steps(5, 4);
    $('#stage').innerHTML = `${machine(false)}<div class="col result"><h3>${L.clean} ✓</h3><div class="basket" id="bk"></div><div class="muted">${L.take}</div></div>`;
    $('#dload').innerHTML = `<div style="width:150px" id="wl">${shirt('wet')}</div>`; hint(L.take);
    dragTo($('#mach .door'), $('#bk'), shirt('wet'), () => { $('#wl').remove(); $('#bk').innerHTML = `<div class="shirt">${shirt('wet')}</div>`; finish(); }); };
  st1();
}

// ---------------------------------------------------------------- DRYER
function dryer() {
  $('#title').textContent = L.dryer; const care = ['low', 'med'][Math.floor(Math.random() * 2)];
  const st1 = () => { steps(4, 0); hint(L.dryLoad);
    $('#stage').innerHTML = `${machine(true)}<div class="col"><h3>${L.dryLoad}</h3><div class="basket"><div class="shirt" id="sh">${shirt('wet')}</div></div></div>`;
    dragTo($('#sh'), $('#mach .door'), shirt('wet'), () => { $('#dload').innerHTML = `<div style="width:150px">${shirt('wet')}</div>`; $('#sh').remove(); setTimeout(st2, 400); }); };
  const st2 = () => { steps(4, 1); hint(L.heat); let heat = null;
    const c = coins(S.data.prices.dry, () => { $('#go').disabled = false; $('#go').style.opacity = 1; });
    $('#stage').innerHTML = `${machine(true)}<div class="col"><h3>${L.heat}</h3><div class="tag">🏷 ${L.care}: ${L[care]}</div><div class="opts">${['low', 'med', 'high'].map((h) => `<button class="btn ghost ht" data-h="${h}">${L[h]}</button>`).join('')}</div>${c.html}
      <button class="btn" id="go" disabled style="opacity:.4">${L.start} ▶</button></div>`;
    $('#dload').innerHTML = `<div style="width:150px">${shirt('wet')}</div>`; c.bind();
    document.querySelectorAll('.ht').forEach((b) => b.onclick = () => { document.querySelectorAll('.ht').forEach((x) => x.classList.remove('sel')); b.classList.add('sel'); heat = b.dataset.h; sfx('click'); $('#disp').textContent = L[heat]; });
    $('#go').onclick = () => { if (!heat) return sfx('error'); S.heat = heat === care ? 1 : heat === 'high' ? 0.4 : 0.7; st3(); }; };
  const st3 = () => { steps(4, 2); hint(L.drying);
    $('#stage').innerHTML = `${machine(true)}<div class="col"><h3>${L.drying}</h3><div id="rg">${ring(0)}</div><div class="muted" id="msg"></div></div>`;
    $('#dload').innerHTML = `<div style="width:150px">${shirt('wet')}</div>`; $('#drum').classList.add('tumble');
    const dur = S.data.times.dry * 1000, t0 = Date.now(); let paused = 0, pAt = 0, ev = 0.3 + Math.random() * 0.4, evDone = false, lintQ = 1;
    const tick = setInterval(() => {
      const el = Date.now() - t0 - paused - (pAt ? Date.now() - pAt : 0), p = Math.min(1, el / dur);
      $('#rg').innerHTML = ring(p); $('#disp').textContent = `00:${String(Math.max(0, Math.ceil((dur - el) / 1000))).padStart(2, '0')}`;
      if (p > 0.5) $('#dload').innerHTML = `<div style="width:150px">${shirt('clean')}</div>`;
      if (!evDone && p >= ev) { evDone = true; pAt = Date.now(); sfx('error'); $('#drum').classList.remove('tumble');
        const a = document.createElement('div'); a.className = 'alert'; a.textContent = '⚠ ' + L.lint; $('#stage').appendChild(a);
        let n = 5; const t1 = Date.now(); const m = $('#mach').getBoundingClientRect(), st = $('#stage').getBoundingClientRect();
        for (let i = 0; i < 5; i++) { const l = document.createElement('div'); l.className = 'lint'; l.style.left = (m.left - st.left + 40 + Math.random() * 240) + 'px'; l.style.top = (m.top - st.top + 120 + Math.random() * 240) + 'px';
          l.onclick = () => { l.remove(); sfx('click'); if (--n === 0) { a.remove(); lintQ = Date.now() - t1 < 4000 ? 1 : 0.75; paused += Date.now() - pAt; pAt = 0; $('#drum').classList.add('tumble'); } }; $('#stage').appendChild(l); } }
      if (p >= 1) { clearInterval(tick); $('#drum').classList.remove('tumble'); sfx('done'); S.score = S.heat * 0.6 + lintQ * 0.4; score(); st4(); }
    }, 100); };
  const st4 = () => { steps(4, 3);
    $('#stage').innerHTML = `${machine(true)}<div class="col result"><h3>✓</h3><div class="basket" id="bk"></div><div class="muted">${L.take}</div></div>`;
    $('#dload').innerHTML = `<div style="width:150px" id="wl">${shirt('clean')}</div>`; hint(L.take);
    dragTo($('#mach .door'), $('#bk'), shirt('clean'), () => { $('#wl').remove(); $('#bk').innerHTML = `<div class="shirt">${shirt('clean')}</div>`; finish(); }); };
  st1();
}

// ---------------------------------------------------------------- FOLD
function fold() {
  $('#title').textContent = L.fold; hint(L.foldH); steps(4, 0);
  const parts = [   // shirt pieces folded in order: left sleeve, right sleeve, left half, bottom
    { d: 'M70 20 L40 32 L8 66 L32 92 L50 78 Z', mirror: 'translate(100,0) scale(-1,1) translate(-100,0)' },
    { d: 'M130 20 L160 32 L192 66 L168 92 L150 78 Z' },
    { d: 'M50 40 L100 40 L100 182 L50 182 Z' },
    { d: 'M50 120 L150 120 L150 182 L50 182 Z' },
  ];
  let step = 0, t0 = Date.now(), miss = 0;
  const draw = () => {
    const done = parts.slice(0, step).map((p, i) => i < 2 ? `<path d="${p.d}" fill="#d9480f" transform="${i === 0 ? 'translate(42,0)' : 'translate(-42,0)'}" opacity=".9"/>` : '').join('');
    const scaleY = step >= 4 ? 0.55 : 1, scaleX = step >= 3 ? 0.55 : 1;
    $('#stage').innerHTML = `<div class="fold"><svg viewBox="0 0 200 200"><g transform="translate(${100 - 100 * scaleX},${20 * (1 - scaleY)}) scale(${scaleX},${scaleY})">
      <path d="M70 20 ${step < 1 ? 'L40 32 L8 66 L32 92 L50 78' : 'L50 40'} L50 182 L150 182 L150 ${step < 2 ? '78 L168 92 L192 66 L160 32' : '40'} L130 20 Q100 44 70 20Z" fill="#ff6a2a" stroke="#d9480f" stroke-width="4" stroke-linejoin="round"/>
      <text x="100" y="128" text-anchor="middle" font-size="30" font-weight="900" fill="#fff">ROX</text>${done}
      ${step < 4 ? `<g class="hot" id="hot"><path d="${parts[step].d}"/></g>` : ''}</g></svg></div>
      <div class="col"><h3>${step < 4 ? `${step + 1} / 4` : L.done}</h3><div class="muted">${L.foldH}</div></div>`;
    steps(4, Math.min(step, 3));
    const svg = $('.fold svg');
    svg.onclick = (e) => { if (step >= 4) return; if (e.target.closest('#hot')) { step++; sfx('click'); if (step === 4) { S.score = Math.max(0.3, 1 - miss * 0.1 - Math.max(0, (Date.now() - t0) / 1000 - 8) * 0.02); score(); draw(); setTimeout(finish, 600); } else draw(); } else { miss++; sfx('error'); } };
  };
  draw();
}

// ---------------------------------------------------------------- result
function finish() {
  const st = Math.round(S.score * 5);
  const r = document.createElement('div'); r.className = 'alert'; r.style.background = '#1f9d5a';
  r.innerHTML = `<span class="stars" style="font-size:28px">${'★'.repeat(st)}${'☆'.repeat(5 - st)}</span><button class="btn ghost" id="ok">${L.finish}</button>`;
  $('#stage').appendChild(r);
  for (let i = 0; i < 40; i++) { const c = document.createElement('div'); c.className = 'confetti'; Object.assign(c.style, { left: Math.random() * 1080 + 'px', background: ['#ff5a1f', '#ffb08a', '#fff', '#3ddc84'][i % 4], animationDelay: Math.random() * .6 + 's' }); $('.panel').appendChild(c); }
  $('#ok').onclick = () => { post('finish', { score: S.score }); close(); };
}
function close() { $('#app').classList.add('hidden'); document.querySelectorAll('.confetti').forEach((c) => c.remove()); S = null; }
$('#close').onclick = () => { post('cancel'); close(); };
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S) { post('cancel'); close(); } });

window.addEventListener('message', (e) => {
  const m = e.data; if (m.action !== 'open') return;
  L = T[m.lang] || T.en; document.dir = m.lang === 'ar' ? 'rtl' : 'ltr';
  S = { kind: m.kind, data: m.data || {}, score: 1 }; S.data.prices = S.data.prices || { wash: 4, dry: 3 }; S.data.times = S.data.times || { wash: 22, dry: 16 };
  $('#app').classList.remove('hidden'); score();
  ({ washer, dryer, fold })[m.kind]();
});
if (location.protocol === 'file:') window.postMessage({ action: 'open', kind: new URLSearchParams(location.search).get('k') || 'washer', lang: 'ar', data: { prices: { wash: 4, dry: 3 }, times: { wash: 6, dry: 5 } } }, '*');
