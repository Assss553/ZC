/* ROX Store | rox_phone | All rights reserved. Remaining apps (design preview, data is local). */
const R = (fn) => ({ title: '', raw: true, html: '<div class="ph" id="ph"></div>', after: fn });
const PH = () => $('ph');
const bind = (el, map) => { el.onclick = (e) => { for (const k in map) { const x = e.target.closest(`[data-${k}]`); if (x) return map[k](x.dataset[k], x, e); } }; };
const stopKeys = (root) => root.querySelectorAll('input,textarea').forEach(i => i.onkeydown = (e) => e.stopPropagation());
const SCENES = ['linear-gradient(160deg,#ff9a5a,#6b2c5c 55%,#1d1b33)', 'linear-gradient(160deg,#2af598,#009efd)', 'linear-gradient(160deg,#f6d365,#fda085)', 'linear-gradient(160deg,#5ee7df,#b490ca)',
  'linear-gradient(160deg,#30cfd0,#330867)', 'linear-gradient(160deg,#ff0844,#ffb199)', 'linear-gradient(160deg,#434343,#000)', 'linear-gradient(160deg,#fa709a,#fee140)', 'linear-gradient(160deg,#0ba360,#3cba92)'];
const GALLERY = [{ bg: SCENES[0] }, { bg: SCENES[1] }, { bg: SCENES[2], v: 14 }, { bg: SCENES[3] }, { bg: SCENES[4] }, { bg: SCENES[5], v: 32 }, { bg: SCENES[7] }];

$('mynum').onclick = (e) => { e.stopPropagation(); toast2('Your number copied: (555) 348-8943'); };

/* ---------- Camera: photo / video / selfie ---------- */
APPVIEW.camera = () => ({ raw: true, html: `<div class="cam"><div class="vf" id="vf"><div class="sun"></div><div class="city"></div><div class="grid9"></div><div class="focus" id="foc"></div><div class="rec" id="rec">00:00</div></div>
  <div class="flash" id="fl"></div><div class="top4"><button data-fl><i class="fa-solid fa-bolt"></i></button><button data-gr class="on"><i class="fa-solid fa-table-cells"></i></button></div>
  <div class="modes" id="modes"><span data-m="video">VIDEO</span><span data-m="photo" class="on">PHOTO</span><span data-m="selfie">SELFIE</span></div>
  <div class="shut"><div class="thumb" id="thumb"></div><button class="sh" id="sh"><i></i></button><button class="flip" data-flip><i class="fa-solid fa-arrows-rotate"></i></button></div></div>`,
  after: () => { let mode = 'photo', rec = null, sec = 0; const vf = $('vf');
    const thumb = () => { const g = GALLERY[0]; $('thumb').style.background = g ? g.bg : '#222'; }; thumb();
    const flash = () => { const f = $('fl'); f.classList.remove('go'); void f.offsetWidth; f.classList.add('go'); };
    const save = (v) => { GALLERY.unshift({ bg: SCENES[Math.random() * SCENES.length | 0], v }); thumb(); };
    vf.onclick = (e) => { const r = vf.getBoundingClientRect(), f = $('foc'); f.style.left = (e.clientX - r.left) + 'px'; f.style.top = (e.clientY - r.top) + 'px'; f.classList.add('on'); setTimeout(() => f.classList.remove('on'), 700); };
    $('sh').onclick = () => { if (mode !== 'video') { flash(); save(); return toast2('Photo saved to gallery'); }
      if (!rec) { sec = 0; $('sh').classList.add('recording'); $('rec').classList.add('on'); rec = setInterval(() => { sec++; $('rec').textContent = `00:${String(sec).padStart(2, '0')}`; }, 1000); }
      else { clearInterval(rec); rec = null; $('sh').classList.remove('recording'); $('rec').classList.remove('on'); $('rec').textContent = '00:00'; save(Math.max(1, sec)); toast2(`Video saved (${sec}s)`); } };
    bind(document.querySelector('.cam'), {
      m: (m) => { if (rec) return; mode = m; document.querySelectorAll('#modes span').forEach(x => x.classList.toggle('on', x.dataset.m === m)); $('sh').classList.toggle('vid', m === 'video'); vf.classList.toggle('selfie', m === 'selfie'); },
      flip: () => { vf.classList.toggle('selfie'); }, fl: (_, b) => b.classList.toggle('on'), gr: (_, b) => { b.classList.toggle('on'); vf.querySelector('.grid9').style.display = b.classList.contains('on') ? '' : 'none'; } });
    $('thumb').onclick = () => { closeApp(); setTimeout(() => openApp('photos', 'Photos', document.querySelector('.app[data-app="photos"]') || $('hb')), 300); }; } });

/* ---------- Photos ---------- */
APPVIEW.photos = () => R(() => { const draw = () => { PH().innerHTML = head('PHOTOS', `${GALLERY.length} ITEMS · ${GALLERY.filter(g => g.v).length} VIDEOS`, '<i class="fa-solid fa-camera"></i>') +
  `<div class="ph-top"><div class="chips"><button class="on">ALL</button><button>FAVORITES</button><button>VIDEOS</button></div></div><div class="ph-body"><div class="grid3">${GALLERY.map((g, i) => `<div data-g="${i}" style="background:${g.bg};animation-delay:${i * 20}ms">${g.v ? `<i class="pl fa-solid fa-video"></i><em>0:${String(g.v).padStart(2, '0')}</em>` : ''}${g.f ? '<em><i class="fa-solid fa-heart"></i></em>' : ''}</div>`).join('')}</div></div>`;
  bind(PH(), { hb: () => { closeApp(); setTimeout(() => openApp('camera', 'Camera', $('hb')), 300); },
    g: (i) => { const g = GALLERY[i]; PH().insertAdjacentHTML('beforeend', `<div class="viewer" id="vw"><button class="sq x" data-x><i class="fa-solid fa-chevron-left"></i></button><div class="img" style="background:${g.bg}"></div>
      <div class="bar3"><button data-sh><i class="fa-solid fa-share-nodes"></i></button><button data-fv><i class="fa-solid fa-heart" style="color:${g.f ? '#ff2d55' : '#fff'}"></i></button><button data-del><i class="fa-solid fa-trash"></i></button></div></div>`);
      bind($('vw'), { x: () => draw(), sh: () => toast2('Shared to Pic-it'), fv: () => { g.f = !g.f; draw(); }, del: () => { GALLERY.splice(i, 1); draw(); toast2('Deleted'); } }); } }); }; draw(); });

/* ---------- Clips (short videos) ---------- */
const CLIPS = [{ u: 'abu_snow', c: 'Night drive through Vinewood 🌃 #lossantos #cars', s: 'Night Drive · ROX Beats', l: 12400, cm: 340, bg: SCENES[4], ic: 'car-side' },
  { u: 'sara.ls', c: 'Best tacos in the city, no cap 🌮', s: 'original sound · sara.ls', l: 8900, cm: 120, bg: SCENES[2], ic: 'utensils' },
  { u: 'lspd_official', c: 'Buckle up. Every ride. 🚓 #safety', s: 'Siren Remix · DJ Dispatch', l: 30500, cm: 1200, bg: SCENES[1], ic: 'shield-halved' },
  { u: 'abu5lf', c: 'When the mechanic says it is "just a small fix" 😂', s: 'funny moments · abu5lf', l: 4300, cm: 88, bg: SCENES[5], ic: 'wrench' }];
const COMMENTS = [['abu_ibrahim', 'This is fire 🔥'], ['sara.ls', 'where is this?'], ['faisal', 'Legend'], ['abu_kayan', '😂😂😂']];
APPVIEW.clips = () => ({ raw: true, html: '<div class="clips" id="clp"></div>', after: () => { let i = 0, tab = 'home';
  const k = (n) => n >= 1000 ? (n / 1000).toFixed(1).replace('.0', '') + 'K' : n;
  const nav = () => `<div class="cnav">${[['home', 'house', 'Home'], ['disc', 'compass', 'Discover'], ['plus'], ['earn', 'coins', 'Earnings'], ['me', 'user', 'Profile']].map(([t, ic, l]) => t === 'plus' ? '<div class="plus" data-t="plus"><i class="fa-solid fa-plus"></i></div>' : `<span class="${tab === t ? 'on' : ''}" data-t="${t}"><i class="fa-solid fa-${ic}"></i>${l}</span>`).join('')}</div>`;
  function draw() { const el = $('clp'); if (!el) return;
    if (tab === 'home') el.innerHTML = `<div class="ctop"><span>Following</span><span class="on">For You</span><i class="fa-solid fa-magnifying-glass"></i></div><div class="feed" id="feed" style="transform:translateY(${-i * 100}%)">${CLIPS.map((c, n) => `<div class="clip" style="top:${n * 100}%"><div class="bg" style="background:${c.bg}"></div><i class="big3 fa-solid fa-${c.ic}"></i><div class="shade"></div>
      <div class="rail"><div><div class="av2" style="background:${SCENES[(n + 3) % 9]}">${c.u[0].toUpperCase()}</div></div><div data-like="${n}" class="${c.liked ? 'liked' : ''}"><i class="fa-solid fa-heart"></i>${k(c.l)}</div><div data-cm="${n}"><i class="fa-solid fa-comment-dots"></i>${k(c.cm)}</div><div data-sv="${n}"><i class="fa-solid fa-bookmark" style="${c.sv ? 'color:#ffd36b' : ''}"></i>Save</div><div data-share><i class="fa-solid fa-share"></i>Share</div><div><div class="disc"></div></div></div>
      <div class="cap"><b>@${c.u}</b><p>${c.c}</p><span><i class="fa-solid fa-music"></i>${c.s}</span></div></div>`).join('')}</div>${nav()}`;
    else if (tab === 'me') el.innerHTML = `<div class="cprof"><div class="avb">RP</div><b>@rox_player</b><div class="nums"><div><b>182</b><span>Following</span></div><div><b>4.2K</b><span>Followers</span></div><div><b>39K</b><span>Likes</span></div></div>
      <button class="go2" style="width:140px;height:34px;margin-bottom:14px">EDIT PROFILE</button><div class="grid3" style="padding:0 2px">${GALLERY.map(g => `<div style="background:${g.bg};aspect-ratio:3/4"><em><i class="fa-solid fa-play"></i> ${(Math.random() * 9 + 1).toFixed(1)}K</em></div>`).join('')}</div></div>${nav()}`;
    else if (tab === 'earn') el.innerHTML = earnView() + nav();
    else el.innerHTML = `<div class="cprof" style="text-align:left"><div class="ph-top"><div class="ph-h"><div><h1>${tab === 'disc' ? 'DISCOVER' : 'INBOX'}</h1><small>${tab === 'disc' ? 'TRENDING IN LOS SANTOS' : 'ACTIVITY'}</small></div></div></div><div class="ph-body">
      ${tab === 'disc' ? `<div class="lbl" style="margin:0 0 6px">LIVE NOW</div>${LIVES.map((l, n) => `<div class="live-card" data-watch="${n}" style="background:${l.bg}"><span class="badge">LIVE</span><span class="vw"><i class="fa-solid fa-eye"></i> ${l.v}</span><b>@${l.u}</b><span class="s">${l.t}</span></div>`).join('')}<div class="lbl" style="margin:10px 0 6px">TRENDING</div>` + ['#lossantos', '#carmeet', '#lspd', '#foodtok', '#heist'].map((h, n) => `<div class="th"><div class="mono">#</div><div><b>${h}</b><span>${(n + 1) * 37}K videos</span></div><div class="r">${n + 1}</div></div>`).join('')
        : COMMENTS.map(([u, t]) => `<div class="th"><div class="mono">${u[0].toUpperCase()}</div><div><b>${u}</b><span>commented: ${t}</span></div><div class="r">${2 + u.length}m</div></div>`).join('')}</div></div>${nav()}`;
    bind(el, { t: (t) => { if (t === 'plus') return Live.setup(el); tab = t; draw(); },
      like: (n) => { const c = CLIPS[n]; c.liked = !c.liked; c.l += c.liked ? 1 : -1; draw(); }, sv: (n) => { CLIPS[n].sv = !CLIPS[n].sv; draw(); toast2(CLIPS[n].sv ? 'Saved' : 'Removed'); },
      wd: () => { if (!WALLET.bal) return toast2('Nothing to withdraw'); BANK.bank += WALLET.bal; BANK.tx.unshift(['in', 'Clips earnings', WALLET.bal, 'NOW', 'coins']); toast2(`$${WALLET.bal.toLocaleString('en-US')} sent to your bank`); WALLET.hist.unshift(['Withdraw to bank', -WALLET.bal]); WALLET.bal = 0; draw(); }, golive: () => Live.setup(el), share: () => toast2('Link copied'), watch: (n) => Live.watch(el, n), cm: (n) => { el.insertAdjacentHTML('beforeend', `<div class="sheet" id="sht"><h4>${k(CLIPS[n].cm)} comments<i class="fa-solid fa-xmark" data-cx></i></h4><div class="cl2" id="cl2">${COMMENTS.map(([u, t]) => `<div class="cm"><div class="mono" style="width:30px;height:30px;border-radius:50%">${u[0].toUpperCase()}</div><div><b>${u}</b>${t}</div></div>`).join('')}</div><div class="comp2"><input id="ci" placeholder="Add comment…"><button id="cs"><i class="fa-solid fa-paper-plane"></i></button></div></div>`);
        stopKeys($('sht')); const send = () => { const v = $('ci').value.trim(); if (!v) return; COMMENTS.push(['rox_player', v]); CLIPS[n].cm++; $('cl2').insertAdjacentHTML('beforeend', `<div class="cm"><div class="mono" style="width:30px;height:30px;border-radius:50%">R</div><div><b>rox_player</b>${v.replace(/</g, '&lt;')}</div></div>`); $('ci').value = ''; };
        $('cs').onclick = send; $('ci').onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter') send(); }; $('sht').querySelector('[data-cx]').onclick = () => $('sht').remove(); } });
    const feed = $('feed'); if (feed) { feed.ondblclick = (e) => { const r = el.getBoundingClientRect(); el.insertAdjacentHTML('beforeend', `<i class="bigheart fa-solid fa-heart" style="left:${e.clientX - r.left}px;top:${e.clientY - r.top}px"></i>`); setTimeout(() => el.querySelector('.bigheart')?.remove(), 800); const c = CLIPS[i]; if (!c.liked) { c.liked = true; c.l++; setTimeout(draw, 500); } };
      let lock = false; feed.onwheel = (e) => { if (lock) return; lock = true; setTimeout(() => lock = false, 600); i = Math.max(0, Math.min(CLIPS.length - 1, i + (e.deltaY > 0 ? 1 : -1))); feed.style.transform = `translateY(${-i * 100}%)`; }; } }
  draw(); document.onkeydown2 = null; } });
document.addEventListener('keydown', (e) => { const feed = $('feed'); if (!feed || e.target.tagName === 'INPUT') return; const n = feed.children.length, cur = Math.round(-parseFloat(feed.style.transform.replace(/[^\d.-]/g, '')) / 100) || 0;
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') { const j = Math.max(0, Math.min(n - 1, cur + (e.key === 'ArrowDown' ? 1 : -1))); feed.style.transform = `translateY(${-j * 100}%)`; } });

/* ---------- Twitter ---------- */
const TWEETS = [['LSPD', 'lspd', 'Road closure on Vinewood Blvd tonight 20:00–23:00. Plan your route.', 312, 88], ['Abu Snow', 'abusnow', 'Car meet at the docks tonight 🔥 bring your best build', 120, 40], ['Sara', 'sara', 'Pillbox nurses are the real heroes. That is the tweet.', 540, 61], ['Weazel News', 'weazel', 'BREAKING: Fleeca bank on Route 68 closed after attempted robbery.', 980, 402]];
APPVIEW.twitter = () => R(() => { const draw = () => { PH().innerHTML = head('TWITTER', 'LOS SANTOS FEED', '<i class="fa-solid fa-bell"></i>') + `<div class="ph-top"><div class="chips"><button class="on">FOR YOU</button><button>FOLLOWING</button></div></div><div class="ph-body">${TWEETS.map(([n, h, t, l, r, liked], i) => `<div class="card2" style="animation-delay:${i * 40}ms"><div class="hd2"><div class="mono">${n[0]}</div><div><b>${n}</b> <span>@${h} · ${i * 7 + 2}m</span></div></div><p>${t}</p>
  <div class="acts2"><span><i class="fa-regular fa-comment"></i><i class="fa-solid fa-comment"></i> ${r}</span><span><i class="fa-solid fa-retweet"></i> ${r >> 1}</span><span data-lk="${i}" class="${liked ? 'on' : ''}"><i class="fa-solid fa-heart"></i> ${l}</span></div></div>`).join('')}</div><button class="fab" data-new><i class="fa-solid fa-feather"></i></button>`;
  bind(PH(), { lk: (i) => { const t = TWEETS[i]; t[5] = !t[5]; t[3] += t[5] ? 1 : -1; draw(); }, new: () => { PH().insertAdjacentHTML('beforeend', `<div class="sheet" id="sht"><h4>New tweet<i class="fa-solid fa-xmark" data-cx></i></h4><div class="cl2"><textarea class="ta" id="tw" maxlength="200" placeholder="What is happening in Los Santos?"></textarea><button class="go2" id="twp">POST</button></div></div>`);
    stopKeys($('sht')); $('sht').querySelector('[data-cx]').onclick = () => $('sht').remove(); $('twp').onclick = () => { const v = $('tw').value.trim(); if (v) { TWEETS.unshift(['Rox Player', 'roxplayer', v.replace(/</g, '&lt;'), 0, 0]); draw(); toast2('Tweet posted'); } }; } }); }; draw(); });
// the double <i> for comment: regular icons are not bundled, hide the first
document.head.insertAdjacentHTML('beforeend', '<style>.fa-regular{display:none}</style>');

/* ---------- Calculator ---------- */
APPVIEW.calculator = () => ({ raw: true, html: `<div class="ph" id="ph" style="justify-content:flex-end"><div class="calc"><div class="his" id="ch"></div><div class="disp" id="cd">0</div><div class="ks">${[['AC', 'fn'], ['±', 'fn'], ['%', 'fn'], ['÷', 'op'], ['7'], ['8'], ['9'], ['×', 'op'], ['4'], ['5'], ['6'], ['−', 'op'], ['1'], ['2'], ['3'], ['+', 'op'], ['0', 'z'], ['.'], ['=', 'op']].map(([k, c]) => `<button class="${c || ''}" data-c="${k}">${k}</button>`).join('')}</div></div></div>`,
  after: () => { let cur = '0', acc = null, op = null, fresh = false; const show = () => { $('cd').textContent = (+cur).toLocaleString('en-US', { maximumFractionDigits: 8 }) + (cur.endsWith('.') ? '.' : ''); };
    const calc = (a, b, o) => o === '+' ? a + b : o === '−' ? a - b : o === '×' ? a * b : b === 0 ? 0 : a / b;
    bind(PH(), { c: (k) => { if (/\d/.test(k)) { cur = fresh || cur === '0' ? k : cur + k; fresh = false; } else if (k === '.') { if (!cur.includes('.')) cur += '.'; }
      else if (k === 'AC') { cur = '0'; acc = op = null; $('ch').textContent = ''; } else if (k === '±') cur = String(-cur); else if (k === '%') cur = String(cur / 100);
      else if (k === '=') { if (op) { $('ch').textContent = `${acc} ${op} ${cur} =`; cur = String(calc(acc, +cur, op)); op = null; fresh = true; } }
      else { if (op && !fresh) cur = String(calc(acc, +cur, op)); acc = +cur; op = k; fresh = true; $('ch').textContent = `${acc} ${op}`; } show(); } }); } });

/* ---------- Notes ---------- */
const NOTES = [{ t: 'Shopping list', b: 'Bread\nWater\nRepair kit\nBandages', c: '#ffb020', pin: 1, d: Date.now() - 36e5, todo: [['Bread', 1], ['Water', 0], ['Repair kit', 0], ['Bandages', 1]] },
  { t: 'Crew meeting', b: 'Meet at 21:00 near the pier. Bring the van and two radios.', c: '#ff5a1f', d: Date.now() - 864e5 },
  { t: 'Plates to check', b: '06HBT193\n5UB26785\n33ROX777', c: '#3ddc84', d: Date.now() - 2 * 864e5 },
  { t: 'Ideas', b: 'Open a taco truck at Vespucci beach. Hire Sara as chef.', c: '#7aa7ff', d: Date.now() - 5 * 864e5 }];
const NCOL = ['#ffb020', '#ff5a1f', '#3ddc84', '#7aa7ff', '#ff5ea8', '#a78bfa'];
document.head.insertAdjacentHTML('beforeend', `<style>
.nt2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; } .open .nt2 { grid-template-columns: repeat(3, 1fr); }
.nc { position: relative; padding: 12px; border-radius: 14px; min-height: 120px; cursor: pointer; overflow: hidden; background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.02)); border: 1px solid rgba(255,255,255,.07); animation: fadeUp .3s backwards; transition: transform .15s; }
.nc:hover { transform: translateY(-2px); } .nc::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--c); } .nc::after { content: ''; position: absolute; right: -30px; top: -30px; width: 90px; height: 90px; border-radius: 50%; background: var(--c); opacity: .12; }
.nc b { display: block; font-size: 13px; margin-bottom: 5px; } .nc p { font-size: 10.5px; color: rgba(255,255,255,.55); line-height: 1.45; white-space: pre-line; display: -webkit-box; -webkit-line-clamp: 4; -webkit-box-orient: vertical; overflow: hidden; }
.nc small { position: absolute; left: 12px; bottom: 9px; font-size: 8px; font-weight: 800; letter-spacing: 1px; color: rgba(255,255,255,.35); } .nc .pin { position: absolute; right: 10px; top: 10px; color: var(--c); font-size: 10px; z-index: 1; }
.nc.wide { grid-column: span 2; } .nsrch { display: flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px; border-radius: 10px; background: rgba(255,255,255,.06); margin-bottom: 12px; } .nsrch input { flex: 1; min-width: 0; background: none; border: 0; outline: 0; color: #fff; font: 600 12px 'Plus Jakarta Sans'; } .nsrch i { color: rgba(255,255,255,.4); font-size: 11px; }
.ned { display: flex; flex-direction: column; height: 100%; } .ned .tb2 { display: flex; align-items: center; gap: 6px; padding: 38px 14px 10px; } .ned .tb2 .sp { flex: 1; }
.ned .tb2 button { height: 30px; min-width: 30px; padding: 0 9px; border-radius: 8px; border: 0; background: rgba(255,255,255,.07); color: #fff; cursor: pointer; font: 700 10.5px 'Plus Jakarta Sans'; } .ned .tb2 .sv { background: var(--a); }
.ned .cols { display: flex; gap: 6px; padding: 0 16px 8px; } .ned .cols i { width: 18px; height: 18px; border-radius: 50%; cursor: pointer; border: 2px solid transparent; } .ned .cols i.on { border-color: #fff; }
.ned input.tt { background: none; border: 0; outline: 0; color: #fff; font: 800 22px 'Plus Jakarta Sans'; padding: 4px 16px; letter-spacing: -.4px; } .ned .meta { padding: 0 16px 8px; font-size: 9px; font-weight: 800; letter-spacing: 1.2px; color: rgba(255,255,255,.35); }
.ned textarea { flex: 1; background: none; border: 0; outline: 0; resize: none; color: rgba(255,255,255,.88); font: 500 13px/1.6 'Plus Jakarta Sans'; padding: 4px 16px; }
.ned .todo { padding: 0 16px 6px; } .ned .todo div { display: flex; align-items: center; gap: 9px; padding: 6px 0; font-size: 12.5px; cursor: pointer; } .ned .todo i.bx { width: 17px; height: 17px; border-radius: 5px; border: 1.5px solid rgba(255,255,255,.3); display: grid; place-items: center; font-size: 9px; font-style: normal; }
.ned .todo div.dn { color: rgba(255,255,255,.35); text-decoration: line-through; } .ned .todo div.dn i.bx { background: var(--nc); border-color: var(--nc); color: #111; }
.ned .bot { display: flex; justify-content: space-between; align-items: center; padding: 10px 16px 24px; font-size: 9.5px; color: rgba(255,255,255,.4); border-top: 1px solid rgba(255,255,255,.06); }
</style>`);
APPVIEW.notes = () => R(() => { let q = '';
  const ago = (t) => { const m = (Date.now() - t) / 6e4 | 0; return m < 60 ? (m || 1) + 'm ago' : m < 1440 ? (m / 60 | 0) + 'h ago' : (m / 1440 | 0) + 'd ago'; };
  const list = () => { const L = NOTES.map((n, i) => [n, i]).filter(([n]) => !q || (n.t + n.b).toLowerCase().includes(q.toLowerCase())).sort((a, b) => (b[0].pin || 0) - (a[0].pin || 0) || b[0].d - a[0].d);
    PH().innerHTML = head('NOTES', `${NOTES.length} NOTES · ${NOTES.filter(n => n.pin).length} PINNED`, '<i class="fa-solid fa-plus"></i>') + `<div class="ph-body"><div class="nsrch"><i class="fa-solid fa-magnifying-glass"></i><input id="nq" placeholder="Search notes" value="${q}"></div>
      <div class="nt2">${L.map(([n, i], k) => `<div class="nc ${k === 0 && n.pin ? 'wide' : ''}" style="--c:${n.c};animation-delay:${k * 40}ms" data-n="${i}">${n.pin ? '<i class="pin fa-solid fa-thumbtack"></i>' : ''}<b>${n.t}</b><p>${n.todo ? n.todo.map(([x, d]) => (d ? '☑ ' : '☐ ') + x).join('\n') : n.b}</p><small>${ago(n.d).toUpperCase()}</small></div>`).join('') || '<div class="dec" style="grid-column:span 2;text-align:center;padding:30px">NO NOTES</div>'}</div></div>`;
    const nq = $('nq'); nq.onkeydown = (e) => e.stopPropagation(); nq.oninput = () => { q = nq.value; const p = nq.selectionStart; list(); $('nq').focus(); $('nq').setSelectionRange(p, p); };
    bind(PH(), { n: (i) => edit(+i), hb: () => { NOTES.unshift({ t: '', b: '', c: NCOL[NOTES.length % NCOL.length], d: Date.now() }); edit(0); } }); };
  const edit = (i) => { const n = NOTES[i];
    PH().innerHTML = `<div class="ned" style="--nc:${n.c}"><div class="tb2"><button data-bk><i class="fa-solid fa-chevron-left"></i></button><span class="sp"></span><button data-pin title="Pin"><i class="fa-solid fa-thumbtack" style="color:${n.pin ? n.c : '#fff'}"></i></button><button data-td title="Checklist"><i class="fa-solid fa-list-check"></i></button><button data-sh title="Share"><i class="fa-solid fa-share-nodes"></i></button><button data-dl title="Delete"><i class="fa-solid fa-trash"></i></button><button class="sv" data-sv>Done</button></div>
      <div class="cols">${NCOL.map(c => `<i style="background:${c}" class="${c === n.c ? 'on' : ''}" data-c="${c}"></i>`).join('')}</div>
      <input class="tt" id="nt" placeholder="Title" value="${n.t.replace(/"/g, '&quot;')}"><div class="meta">EDITED ${ago(n.d).toUpperCase()}</div>
      ${n.todo ? `<div class="todo">${n.todo.map(([x, d], k) => `<div class="${d ? 'dn' : ''}" data-tk="${k}"><i class="bx">${d ? '✓' : ''}</i>${x}</div>`).join('')}<div data-add style="color:rgba(255,255,255,.45)"><i class="fa-solid fa-plus" style="width:17px;text-align:center"></i>Add item</div></div>` : ''}
      <textarea id="nb" placeholder="Start writing…">${n.todo ? '' : n.b}</textarea><div class="bot"><span id="wc">${(n.b.match(/\S+/g) || []).length} words</span><span>${new Date(n.d).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}</span></div></div>`;
    stopKeys(PH()); $('nb').oninput = () => $('wc').textContent = ($('nb').value.match(/\S+/g) || []).length + ' words'; if (!n.t) $('nt').focus();
    const save = () => { n.t = $('nt').value.trim() || 'Untitled'; if (!n.todo) n.b = $('nb').value; n.d = Date.now(); };
    bind(PH(), { bk: () => { save(); if (!n.b && n.t === 'Untitled' && !n.todo) NOTES.splice(i, 1); list(); }, sv: () => { save(); toast2('Note saved'); list(); },
      pin: () => { save(); n.pin = !n.pin; edit(i); }, c: (c) => { save(); n.c = c; edit(i); }, dl: () => { NOTES.splice(i, 1); toast2('Note deleted'); list(); },
      sh: () => { save(); toast2('Note shared to nearby player'); }, td: () => { save(); n.todo = n.todo ? null : (n.b.split('\n').filter(Boolean).map(x => [x, 0]).concat(n.b ? [] : [['New item', 0]])); edit(i); },
      tk: (k) => { save(); n.todo[k][1] ^= 1; edit(i); }, add: () => { save(); const v = prompt('Item'); if (v) n.todo.push([v, 0]); edit(i); } }); };
  list(); });

/* ---------- Clock ---------- */
const ALARMS = [['07:00', 'Work', 1], ['18:00', 'LSPD shift', 1], ['23:30', 'Car meet', 0]];
APPVIEW.clock = () => R(() => { let sw = 0, swt = null; const draw = () => { PH().innerHTML = head('CLOCK', 'ALARMS & STOPWATCH') + `<div class="ph-body"><div class="bigclock"><b id="ck"></b><small>LOS SANTOS TIME</small></div>
  <div class="lbl" style="margin:6px 0">ALARMS</div>${ALARMS.map(([t, l, on], i) => `<div class="alarm ${on ? '' : 'off'}"><div><b>${t}</b><span>${l}</span></div><i class="tg ${on ? 'on' : ''}" data-a="${i}"></i></div>`).join('')}
  <div class="lbl" style="margin:16px 0 6px">STOPWATCH</div><div class="bigclock" style="padding:6px"><b id="sw" style="font-size:36px">00:00.0</b></div><div style="display:flex;gap:8px"><button class="go2" data-sw>START / STOP</button><button class="go2" data-rs style="background:rgba(255,255,255,.1)">RESET</button></div></div>`;
  bind(PH(), { a: (i) => { ALARMS[i][2] ^= 1; draw(); }, sw: () => { if (swt) { clearInterval(swt); swt = null; } else swt = setInterval(() => { sw += .1; if ($('sw')) $('sw').textContent = `${String(sw / 60 | 0).padStart(2, '0')}:${(sw % 60).toFixed(1).padStart(4, '0')}`; }, 100); }, rs: () => { sw = 0; $('sw').textContent = '00:00.0'; } }); tick(); };
  const tick = () => { if ($('ck')) { $('ck').textContent = new Date().toLocaleTimeString('en-GB'); setTimeout(tick, 1000); } }; draw(); });

/* ---------- Maps ---------- */
const PLACES = [['Pillbox Medical', 38, 35, 'hospital'], ['Mission Row PD', 60, 48, 'shield-halved'], ['Legion Square', 47, 62, 'tree'], ['Benny\'s', 26, 74, 'wrench'], ['Fleeca Bank', 72, 70, 'building-columns']];
APPVIEW.maps = () => R(() => { PH().innerHTML = head('MAPS', 'LOS SANTOS') + `<div class="ph-top"><div class="fld"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search places"></div></div>
  <div class="mapv"><svg viewBox="0 0 100 100" preserveAspectRatio="none"><g stroke="#262b33" stroke-width="5" fill="none"><path d="M0 30H100M0 65H100M30 0V100M70 0V100M0 100L100 10"/></g><g stroke="#3a414c" stroke-width="1.2" fill="none"><path d="M0 30H100M0 65H100M30 0V100M70 0V100M0 100L100 10"/><path d="M0 48H100M50 0V100M15 0V100M85 0V100" stroke-width=".6"/></g><path d="M58 0Q40 40 62 100" stroke="#2f7cf6" stroke-width="2.5" fill="none" opacity=".25"/></svg>
  <div class="me"></div>${PLACES.map(([n, x, y, ic], i) => `<div class="pin" style="left:${x}%;top:${y}%" data-p="${i}"><i class="fa-solid fa-location-dot"></i></div>`).join('')}</div>
  <div class="ph-body" style="flex:none;max-height:150px">${PLACES.map(([n, , , ic], i) => `<div class="th" data-p="${i}"><div class="mono"><i class="fa-solid fa-${ic}"></i></div><div><b>${n}</b><span>${((i + 1) * 0.6).toFixed(1)} km · ${i + 2} min</span></div><button class="cb" data-p="${i}"><i class="fa-solid fa-location-arrow"></i></button></div>`).join('')}</div>`;
  stopKeys(PH()); bind(PH(), { p: (i) => { toast2('GPS set: ' + PLACES[i][0]); PH().querySelectorAll('.pin').forEach((p, k) => p.innerHTML = `<i class="fa-solid fa-location-dot"></i>${k == i ? `<span>${PLACES[i][0]}</span>` : ''}`); } }); });

/* ---------- Music ---------- */
const SONGS = [['Night Drive', 'ROX Beats', 214, SCENES[4]], ['Vinewood Lights', 'Sara K', 187, SCENES[7]], ['Siren Remix', 'DJ Dispatch', 201, SCENES[5]], ['Pier Sunset', 'Abu Snow', 240, SCENES[0]]];
APPVIEW.music = () => R(() => { let i = 0, play = false, pos = 0, t; const draw = () => { const s = SONGS[i]; PH().innerHTML = head('ROXMUSIC', play ? 'NOW PLAYING' : 'PAUSED') + `<div class="ph-body"><div class="player"><div class="art2" style="background:${s[3]}"></div><b>${s[0]}</b><span>${s[1]}</span>
  <div class="prog"><i id="pg" style="width:${pos / s[2] * 100}%"></i></div><div style="display:flex;justify-content:space-between;font-size:9.5px;color:rgba(255,255,255,.45)"><span id="pt">${fmt(pos)}</span><span>${fmt(s[2])}</span></div>
  <div class="ctl2"><button data-pv><i class="fa-solid fa-backward-step"></i></button><button class="pp" data-pp><i class="fa-solid fa-${play ? 'pause' : 'play'}"></i></button><button data-nx><i class="fa-solid fa-forward-step"></i></button></div></div>
  <div class="lbl" style="margin:8px 0 4px">UP NEXT</div>${SONGS.map((x, k) => `<div class="th" data-sg="${k}"><div class="mono" style="background:${x[3]};border:0"></div><div><b style="${k === i ? 'color:var(--a)' : ''}">${x[0]}</b><span>${x[1]}</span></div><div class="r">${fmt(x[2])}</div></div>`).join('')}</div>`;
  bind(PH(), { pp: () => { play = !play; run(); draw(); }, nx: () => { i = (i + 1) % SONGS.length; pos = 0; draw(); }, pv: () => { i = (i + SONGS.length - 1) % SONGS.length; pos = 0; draw(); }, sg: (k) => { i = +k; pos = 0; play = true; run(); draw(); } }); };
  const fmt = (x) => `${x / 60 | 0}:${String(x % 60 | 0).padStart(2, '0')}`;
  const run = () => { clearInterval(t); if (play) t = setInterval(() => { pos++; if (!$('pg')) return clearInterval(t); if (pos >= SONGS[i][2]) { i = (i + 1) % SONGS.length; pos = 0; draw(); } $('pg').style.width = pos / SONGS[i][2] * 100 + '%'; $('pt').textContent = fmt(pos); }, 1000); }; draw(); });

/* ---------- Garage ---------- */
const CARS = [['Pfister Comet', '06HBT193', 'OUT', 92, 64, 100], ['Karin Sultan RS', '5UB26785', 'GARAGE', 70, 30, 85], ['Vapid Dominator', '33ROX777', 'IMPOUND', 40, 10, 55]];
APPVIEW.garage = () => R(() => { const draw = () => { PH().innerHTML = head('GARAGE', `${CARS.length} VEHICLES`) + `<div class="ph-body">${CARS.map(([n, p, s, e, f, b], i) => `<div class="car" style="animation-delay:${i * 50}ms"><div><b>${n}</b><span class="plate">${p}</span></div><span class="st3 ${s === 'OUT' ? 'g' : s === 'GARAGE' ? 'o' : 'r'}">${s}</span>
  <div class="bars4"><div>ENGINE<i style="--v:${e}%"></i></div><div>FUEL<i style="--v:${f}%;--c:#ffb020"></i></div><div>BODY<i style="--v:${b}%;--c:#2f7cf6"></i></div></div>
  <div style="grid-column:span 2;display:grid;grid-template-columns:1fr 1fr;gap:6px">${s === 'OUT' ? `<button class="pay" data-gps="${i}" style="height:30px">TRACK GPS</button><button class="pay" data-lk="${i}" style="height:30px">LOCK / UNLOCK</button>` : s === 'GARAGE' ? `<button class="pay" data-gps="${i}" style="height:30px;grid-column:span 2">SET GPS TO GARAGE</button>` : `<button class="pay" data-imp="${i}" style="height:30px;grid-column:span 2">PAY IMPOUND $500</button>`}</div></div>`).join('')}</div>`;
  bind(PH(), { gps: (i) => toast2('GPS set to ' + CARS[i][0]), lk: (i) => toast2(CARS[i][0] + ' toggled lock'), imp: (i) => { CARS[i][2] = 'GARAGE'; toast2('Impound paid'); draw(); } }); }; draw(); });

/* ---------- Crypto ---------- */
const COINS = [['ROX', 'Rox Coin', 128.4, 4.2, '#ff5a1f'], ['BTC', 'Bitcoin', 64210, -1.3, '#f7931a'], ['ETH', 'Ethereum', 3120, 2.1, '#8c8cff'], ['LSC', 'Santos Coin', 0.84, 12.5, '#3ddc84']];
APPVIEW.crypto = () => R(() => { const spark = (up) => { let y = 13, d = 'M0 ' + y; for (let x = 7; x <= 70; x += 7) { y = Math.max(2, Math.min(24, y + (Math.random() - (up ? .62 : .38)) * 8)); d += ` L${x} ${y.toFixed(1)}`; } return `<svg viewBox="0 0 70 26"><path d="${d}" fill="none" stroke="${up ? '#3ddc84' : '#ff4d4d'}" stroke-width="1.6"/></svg>`; };
  PH().innerHTML = head('CRYPTO', 'PORTFOLIO') + `<div class="ph-body"><div class="bk-card"><div class="t1"><span>PORTFOLIO VALUE</span><b>+3.8% 24H</b></div><div class="bal2">$8,402<small>.17</small></div><div class="split"><div>ROX<b>42.0</b></div><div>BTC<b>0.051</b></div></div></div>
  <div class="qt" style="grid-template-columns:repeat(3,1fr)"><button data-x="buy"><i class="fa-solid fa-plus"></i>BUY</button><button data-x="sell"><i class="fa-solid fa-minus"></i>SELL</button><button data-x="send"><i class="fa-solid fa-paper-plane"></i>SEND</button></div>
  <div class="lbl" style="margin:0 0 4px">MARKETS</div>${COINS.map(([s, n, p, c, col]) => `<div class="coin"><div class="ci" style="background:${col}22;color:${col}">${s[0]}</div><div><b>${s}</b><span>${n}</span></div>${spark(c > 0)}<div class="pr">$${p.toLocaleString('en-US')}<small style="color:${c > 0 ? '#3ddc84' : '#ff4d4d'}">${c > 0 ? '+' : ''}${c}%</small></div></div>`).join('')}</div>`;
  bind(PH(), { x: (x) => toast2(x.toUpperCase() + ' — connect to the server to trade') }); });

/* ---------- simple list apps ---------- */
const listApp = (title, sub, rows, btn) => R(() => { PH().innerHTML = head(title, sub) + `<div class="ph-body">${rows.map(([a, b, c, ic], i) => `<div class="card2" style="animation-delay:${i * 40}ms"><div class="hd2"><div class="mono">${ic ? `<i class="fa-solid fa-${ic}"></i>` : a[0]}</div><div style="flex:1"><b>${a}</b><br><span>${b}</span></div>${c ? `<span class="st3 o">${c}</span>` : ''}</div></div>`).join('')}</div>${btn ? `<button class="fab" data-f><i class="fa-solid fa-${btn}"></i></button>` : ''}`;
  bind(PH(), { f: () => toast2('Coming with the server version') }); });
APPVIEW.mail = () => listApp('MAIL', '3 UNREAD', [['Pillbox Medical', 'Your bill of $600 is ready', 'NEW', 'kit-medical'], ['LSPD', 'Speeding ticket #4471', 'NEW', 'shield-halved'], ['Dynasty 8', 'Your rent is due in 2 days', 'NEW', 'house'], ['Benny\'s', 'Thanks for your order', '', 'wrench']], 'pen');
APPVIEW.doj = () => listApp('DOJ', 'COURT & LAWYERS', [['Judge Al-Harbi', 'On duty · Courtroom 1', 'ONLINE', 'gavel'], ['Faisal Law', 'Defense lawyer · (555) 448-2290', 'ONLINE', 'scale-balanced'], ['Case #2231', 'Hearing tomorrow 19:00', 'SOON', 'folder-open']], 'phone');
APPVIEW.racing = () => listApp('RACING', 'STREET RACES', [['Vinewood Sprint', '4 laps · $2,000 buy-in · 5/8 racers', 'OPEN', 'flag-checkered'], ['Docks Drift', 'Drift · $500 buy-in · 2/6', 'OPEN', 'car-side'], ['Mount Chiliad Run', 'Point to point · Starts 22:00', 'LATER', 'mountain']], 'plus');
APPVIEW.houses = () => listApp('HOUSES', 'YOUR PROPERTIES', [['4 Integrity Way', 'Apartment · Owned', 'OWNED', 'building'], ['Alta St 12', 'Rent · next payment in 2 days', 'RENT', 'house']], 'key');
APPVIEW.crew = () => listApp('CREW', 'NIGHT RIDERS · 6 MEMBERS', [['Abu Snow', 'Leader · online', 'LEADER', ''], ['Abu5lf', 'Member · online', '', ''], ['Sara', 'Member · offline', '', '']], 'location-crosshairs');
APPVIEW.pigeon = () => listApp('PIGEON', 'ANONYMOUS MESSAGES', [['Anonymous', 'Someone is watching the Fleeca…', '2M', 'mask'], ['Anonymous', 'Drop at the pier, 23:00', '1H', 'mask']], 'feather');
APPVIEW.vibe = () => listApp('VIBE', 'VOICE ROOMS', [['Car Meet Talk', '12 listening', 'LIVE', 'microphone'], ['Night Chill', '5 listening', 'LIVE', 'headphones']], 'plus');
APPVIEW.drop = () => listApp('DROP', 'NEARBY', [['Abu Ibrahim', '3 m away', 'NEAR', 'user'], ['Sara', '12 m away', '', 'user']], 'share-nodes');


/* ---------- Camera v2 ---------- */
const FILTERS = [['none', 'Normal'], ['warm', 'Warm'], ['cool', 'Cool'], ['vivid', 'Vivid'], ['fade', 'Fade'], ['noir', 'Noir'], ['night', 'Night']];
const camView = (extra = '') => `<div class="vf" id="vf"><div class="sun"></div><div class="city"></div><div class="grid9"></div><div class="focus" id="foc"></div><div class="rec" id="rec">00:00</div>${extra}</div>`;
APPVIEW.camera = () => ({ raw: true, html: `<div class="cam2" id="cam2"><div class="tb"><button data-fl><i class="fa-solid fa-bolt"></i></button><button data-hdr>HDR</button><button data-tm><i class="fa-solid fa-stopwatch"></i> <span id="tmv">OFF</span></button><button data-ar>4:3</button><button data-fx><i class="fa-solid fa-wand-magic-sparkles"></i></button></div>
  <div style="position:relative;flex:1;display:flex;flex-direction:column;justify-content:center;background:#000">${camView('<div class="live-tag" id="ltag"><b>1x</b> · AUTO</div>')}<div class="ev"><i class="fa-solid fa-sun"></i><input type="range" min="-2" max="2" step=".1" value="0" id="ev"></div>
  <div class="zoom" id="zm"><span data-z=".5">.5</span><span data-z="1" class="on">1x</span><span data-z="2">2</span><span data-z="5">5</span></div><div class="tmr" id="tmr"></div></div>
  <div class="filters" id="flt" style="display:none">${FILTERS.map(([k, n], i) => `<div data-f="${k}" class="${i ? '' : 'on'}"><i class="f-${k}"></i>${n}</div>`).join('')}</div>
  <div class="modes" id="modes">${['LAPSE', 'VIDEO', 'PHOTO', 'PORTRAIT', 'SELFIE'].map(m => `<span data-m="${m}" class="${m === 'PHOTO' ? 'on' : ''}">${m}</span>`).join('')}</div>
  <div class="shut"><div class="thumb" id="thumb"></div><button class="sh" id="sh"><svg viewBox="0 0 80 80"><circle cx="40" cy="40" r="36"/></svg><i></i></button><button class="flip" data-flip><i class="fa-solid fa-arrows-rotate"></i></button></div></div>`,
  after: () => { let mode = 'PHOTO', rec = null, sec = 0, timer = 0, zoom = 1, filt = 'none', ar = 0, ev = 0; const vf = $('vf'), root = $('cam2');
    const look = () => { vf.style.transform = `scale(${zoom < 1 ? 1 : 1 + (zoom - 1) * .12})${vf.classList.contains('selfie') ? ' scaleX(-1)' : ''}`; vf.className = 'vf f-' + filt + (vf.classList.contains('selfie') ? ' selfie' : '') + ['', ' r11', ' r169'][ar];
      vf.style.filter = (getComputedStyle(vf).filter === 'none' ? '' : '') + ` brightness(${1 + ev * .18})${mode === 'PORTRAIT' ? ' contrast(1.05)' : ''}`; $('ltag').innerHTML = `<b>${zoom}x</b> · ${mode === 'PORTRAIT' ? 'DEPTH' : 'AUTO'}${ev ? ' · ' + (ev > 0 ? '+' : '') + ev.toFixed(1) + ' EV' : ''}`; };
    const thumb = () => { $('thumb').style.background = GALLERY[0] ? GALLERY[0].bg : '#222'; }; thumb();
    const flash = () => { root.insertAdjacentHTML('beforeend', '<div class="flash go" style="z-index:9"></div>'); setTimeout(() => root.querySelector('.flash')?.remove(), 400); };
    const save = (v) => { GALLERY.unshift({ bg: SCENES[Math.random() * SCENES.length | 0], v, f: 0 }); thumb(); $('thumb').animate([{ transform: 'scale(1.3)' }, { transform: 'scale(1)' }], 250); };
    const shoot = () => { if (mode === 'VIDEO' || mode === 'LAPSE') return toggleRec(); flash(); save(); toast2(mode === 'PORTRAIT' ? 'Portrait saved' : 'Photo saved to gallery'); };
    const toggleRec = () => { const sh = $('sh'); if (!rec) { sec = 0; sh.classList.add('recording'); $('rec').classList.add('on'); rec = setInterval(() => { sec++; $('rec').textContent = `00:${String(sec).padStart(2, '0')}`; if (sec >= 30) toggleRec(); }, 1000); }
      else { clearInterval(rec); rec = null; sh.classList.remove('recording'); $('rec').classList.remove('on'); $('rec').textContent = '00:00'; save(Math.max(1, sec)); toast2(`${mode === 'LAPSE' ? 'Time-lapse' : 'Video'} saved · ${sec}s`); } };
    $('sh').onclick = () => { if (rec || !timer) return shoot(); let n = timer; $('tmr').textContent = n; const t = setInterval(() => { n--; $('tmr').textContent = n || ''; if (!n) { clearInterval(t); shoot(); } }, 1000); };
    vf.onclick = (e) => { const r = vf.getBoundingClientRect(), f = $('foc'); f.style.left = (e.clientX - r.left) + 'px'; f.style.top = (e.clientY - r.top) + 'px'; f.classList.add('on'); setTimeout(() => f.classList.remove('on'), 700); };
    $('ev').oninput = (e) => { ev = +e.target.value; look(); };
    bind(root, { m: (m) => { if (rec) return; mode = m; root.querySelectorAll('#modes span').forEach(x => x.classList.toggle('on', x.dataset.m === m)); $('sh').classList.toggle('vid', m === 'VIDEO' || m === 'LAPSE'); vf.classList.toggle('selfie', m === 'SELFIE'); look(); },
      z: (z) => { zoom = +z; root.querySelectorAll('#zm span').forEach(x => { x.classList.toggle('on', x.dataset.z === z); x.textContent = x.dataset.z === z ? z + 'x' : x.dataset.z; }); look(); },
      f: (f) => { filt = f; root.querySelectorAll('#flt div').forEach(x => x.classList.toggle('on', x.dataset.f === f)); look(); },
      fx: (_, b) => { b.classList.toggle('on'); $('flt').style.display = b.classList.contains('on') ? 'flex' : 'none'; },
      tm: (_, b) => { timer = timer === 0 ? 3 : timer === 3 ? 10 : 0; $('tmv').textContent = timer ? timer + 's' : 'OFF'; b.classList.toggle('on', !!timer); },
      ar: (_, b) => { ar = (ar + 1) % 3; b.textContent = ['4:3', '1:1', '9:16'][ar]; look(); },
      hdr: (_, b) => b.classList.toggle('on'), fl: (_, b) => b.classList.toggle('on'), flip: () => { vf.classList.toggle('selfie'); look(); } });
    $('thumb').onclick = () => { closeApp(); setTimeout(() => openApp('photos', 'Photos', $('hb')), 300); }; } });

/* ---------- LIVE streaming ---------- */
const LIVES = [{ u: 'abu_snow', t: 'Car meet at the docks 🔥', v: 214, bg: SCENES[4] }, { u: 'sara.ls', t: 'Late night cooking 🍳', v: 87, bg: SCENES[2] }];
const GIFTS = [['🌹', 'Rose', 1], ['❤️', 'Heart', 5], ['🍩', 'Donut', 10], ['🔥', 'Fire', 25], ['🎉', 'Party', 50], ['👑', 'Crown', 100], ['🚗', 'Supercar', 500], ['🚁', 'Heli', 1000]];
const FANS = ['abu_ibrahim', 'faisal', 'abu_kayan', 'abu5lf', 'sara.ls', 'nora_ls', 'turki88', 'mshari', 'reem.x', 'hamad'];
const CHATS2 = ['🔥🔥🔥', 'Hi from Vinewood!', 'Where is this?', 'Legend', 'Follow back pls', '😂😂', 'Nice car', 'First time here', 'GG', 'Love the stream ❤️', 'What music is that?'];
const Live = (() => { let st = null;
  function setup(host) { host.insertAdjacentHTML('beforeend', `<div class="setup" id="setup"><div class="box"><h3>Create</h3><p>Post a video or go live to the city.</p>
    <div class="opt"><div data-o="post"><i class="fa-solid fa-video"></i>Post video</div><div data-o="live" class="on"><i class="fa-solid fa-tower-broadcast" style="color:#ff2d55"></i>Go LIVE</div></div>
    <div class="fld" id="tf"><i class="fa-solid fa-pen"></i><input id="ltitle" placeholder="Live title" value="Cruising Los Santos 🚗"></div>
    <div class="chips" style="margin-bottom:12px">${['Chatting', 'Driving', 'Gaming', 'Music', 'Food'].map((c, i) => `<button class="${i === 1 ? 'on' : ''}" data-cat="${c}">${c.toUpperCase()}</button>`).join('')}</div>
    <button class="golive" id="gl"><i class="fa-solid fa-tower-broadcast"></i> GO LIVE</button><button class="go2" style="margin-top:8px;background:rgba(255,255,255,.08)" data-cx>CANCEL</button></div></div>`);
    const sp = $('setup'); stopKeys(sp); let o = 'live';
    bind(sp, { o: (v) => { o = v; sp.querySelectorAll('[data-o]').forEach(x => x.classList.toggle('on', x.dataset.o === v)); $('tf').style.display = v === 'live' ? '' : 'none'; $('gl').innerHTML = v === 'live' ? '<i class="fa-solid fa-tower-broadcast"></i> GO LIVE' : '<i class="fa-solid fa-camera"></i> OPEN CAMERA'; },
      cat: (c, b) => sp.querySelectorAll('[data-cat]').forEach(x => x.classList.toggle('on', x === b)), cx: () => sp.remove() });
    $('gl').onclick = () => { const t = $('ltitle').value || 'LIVE'; sp.remove(); if (o === 'post') { closeApp(); return setTimeout(() => openApp('camera', 'Camera', $('hb')), 300); } start(host, t, true); }; }
  function screen(host, me, title, who) { host.insertAdjacentHTML('beforeend', `<div class="live" id="live"><div class="stage">${camView()}</div>
    <div class="lt"><div class="host"><div class="mono">${(who || 'R')[0].toUpperCase()}</div><div><b>${who || 'rox_player'}</b><span>${title}</span></div></div><span class="badge">LIVE</span><span class="vw"><i class="fa-solid fa-eye"></i> <span id="lv">0</span></span><button class="x2" data-end><i class="fa-solid fa-xmark"></i></button></div>
    <div class="earn"><span id="lt2"><i class="fa-solid fa-clock"></i>00:00</span><span id="le"><i class="fa-solid fa-coins"></i>$0</span><span id="ll"><i class="fa-solid fa-heart" style="color:#ff2d55"></i>0</span></div>
    <div class="chat" id="lc"></div><div class="hearts" id="lh"></div>
    <div class="lb"><input id="li" placeholder="${me ? 'Say something…' : 'Add comment…'}"><button data-hrt><i class="fa-solid fa-heart" style="color:#ff2d55"></i></button>${me ? '<button data-flipl><i class="fa-solid fa-arrows-rotate"></i></button>' : '<button class="gb" data-gift><i class="fa-solid fa-gift"></i></button>'}</div></div>`);
    const L = $('live'); stopKeys(L); return L; }
  const say = (cls, html) => { const c = $('lc'); if (!c) return; c.insertAdjacentHTML('beforeend', `<div class="cmsg ${cls}">${html}</div>`); while (c.children.length > 14) c.firstElementChild.remove(); };
  const heart = () => { const h = $('lh'); if (!h) return; const i = document.createElement('i'); i.className = 'fa-solid fa-heart'; i.style.color = ['#ff2d55', '#ff5a1f', '#ffd36b', '#ff7ad9', '#25f4ee'][Math.random() * 5 | 0]; i.style.setProperty('--dx', (Math.random() * 60 - 40) + 'px'); h.appendChild(i); setTimeout(() => i.remove(), 2400); };
  const gift = (from, g) => { const L = $('live'); if (!L) return; st.earn += g[2]; st.gifts[from] = (st.gifts[from] || 0) + g[2]; st.giftN++;
    L.insertAdjacentHTML('beforeend', `<div class="gpop"><div class="mono">${from[0].toUpperCase()}</div><div><b>${from}</b><span>sent ${g[1]}</span></div><em>${g[0]}</em><strong>x1</strong></div>`); setTimeout(() => L.querySelector('.gpop')?.remove(), 2600);
    if (g[2] >= 100) { L.insertAdjacentHTML('beforeend', `<div class="bigg">${g[0]}</div>`); setTimeout(() => L.querySelector('.bigg')?.remove(), 2200); }
    say('gift', `<b>${from}</b>sent ${g[0]} ${g[1]} · $${g[2]}`); const e = $('le'); e.innerHTML = `<i class="fa-solid fa-coins"></i>$${st.earn.toLocaleString('en-US')}`; e.classList.remove('pulse'); void e.offsetWidth; e.classList.add('pulse'); };
  function start(host, title, me, who) { const L = screen(host, me, title, who); st = { t0: Date.now(), v: me ? 0 : 200, peak: 0, total: 0, likes: 0, earn: 0, gifts: {}, giftN: 0, me };
    const tick = setInterval(() => { if (!$('live')) return clearInterval(tick); const s = (Date.now() - st.t0) / 1000 | 0; $('lt2').innerHTML = `<i class="fa-solid fa-clock"></i>${String(s / 60 | 0).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
      if (Math.random() < .55) { const d = Math.random() < .75 ? 1 + (Math.random() * 3 | 0) : -1; st.v = Math.max(0, st.v + d); if (d > 0) { st.total += d; say('join', `${FANS[Math.random() * FANS.length | 0]} joined`); } st.peak = Math.max(st.peak, st.v); $('lv').textContent = st.v; }
      if (Math.random() < .5) say('', `<b>${FANS[Math.random() * FANS.length | 0]}</b>${CHATS2[Math.random() * CHATS2.length | 0]}`);
      if (Math.random() < .6) { st.likes += 1 + (Math.random() * 6 | 0); heart(); $('ll').innerHTML = `<i class="fa-solid fa-heart" style="color:#ff2d55"></i>${st.likes}`; }
      if (me && Math.random() < .22) gift(FANS[Math.random() * FANS.length | 0], GIFTS[Math.random() < .85 ? Math.random() * 5 | 0 : 5 + (Math.random() * 3 | 0)]); }, 900);
    say('join', me ? 'You are LIVE. Welcome your viewers!' : `You joined @${who}'s live`);
    const send = () => { const v = $('li').value.trim(); if (!v) return; say('', `<b>${me ? 'rox_player (host)' : 'rox_player'}</b>${v.replace(/</g, '&lt;')}`); $('li').value = ''; };
    $('li').onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter') send(); };
    L.querySelector('.stage').onclick = () => { heart(); st.likes++; };
    bind(L, { hrt: () => { for (let i = 0; i < 5; i++) setTimeout(heart, i * 90); st.likes += 5; }, flipl: () => L.querySelector('.vf').classList.toggle('selfie'),
      gift: () => { L.insertAdjacentHTML('beforeend', `<div class="gifts" id="gs"><h4>Send a gift <span><i class="fa-solid fa-building-columns"></i> $${Math.floor(BANK.bank).toLocaleString('en-US')}</span></h4><div class="gg">${GIFTS.map((g, i) => `<div data-g="${i}"><em>${g[0]}</em>${g[1]}<br><small>$${g[2]}</small></div>`).join('')}</div></div>`);
        bind($('gs'), { g: (i) => { const g = GIFTS[i]; if (BANK.bank < g[2]) return toast2('Not enough money'); BANK.bank -= g[2]; BANK.tx.unshift(['out', `Gift to @${who}`, g[2], 'NOW', 'gift']); $('gs').remove(); gift('rox_player', g); } }); },
      end: () => { clearInterval(tick); me ? summary(host) : (L.remove(), toast2('Left the live')); } }); }
  function summary(host) { $('live')?.remove(); const dur = (Date.now() - st.t0) / 1000 | 0, top = Object.entries(st.gifts).sort((a, b) => b[1] - a[1]).slice(0, 3);
    host.insertAdjacentHTML('beforeend', `<div class="sum" id="sum"><h2>LIVE ended</h2><p>Great stream! Here is how it went.</p><div class="big4"><small>YOU COLLECTED</small>$${st.earn.toLocaleString('en-US')}</div>
      <div class="g4"><div>DURATION<b>${String(dur / 60 | 0).padStart(2, '0')}:${String(dur % 60).padStart(2, '0')}</b></div><div>PEAK VIEWERS<b>${st.peak}</b></div><div>TOTAL VIEWERS<b>${st.total}</b></div><div>LIKES<b>${st.likes}</b></div><div>GIFTS<b>${st.giftN}</b></div><div>NEW FOLLOWERS<b>${Math.round(st.total * .3)}</b></div></div>
      <div class="top3g"><div class="lbl" style="margin:0 0 4px">TOP SUPPORTERS</div>${top.map(([n, v], i) => `<div class="th"><div class="mono">${['🥇', '🥈', '🥉'][i]}</div><div><b>${n}</b><span>sent gifts</span></div><div class="r" style="color:#ffd36b;font-size:12px">$${v}</div></div>`).join('') || '<span style="font-size:11px;color:rgba(255,255,255,.4)">No gifts this time</span>'}</div>
      <button class="golive" id="wd"><i class="fa-solid fa-coins"></i> VIEW EARNINGS</button><button class="go2" style="margin-top:8px;background:rgba(255,255,255,.08)" id="sd">DONE</button></div>`);
    WALLET.bal += st.earn; WALLET.total += st.earn; WALLET.lives.push(st.earn); WALLET.gifts += st.giftN; WALLET.hist.unshift([`LIVE · ${String(dur / 60 | 0).padStart(2, '0')}:${String(dur % 60).padStart(2, '0')}`, st.earn]);
    $('wd').onclick = () => { $('sum').remove(); host.querySelector('[data-t="earn"]')?.click(); };
    $('sd').onclick = () => $('sum').remove(); }
  return { setup, start, watch: (host, n) => start(host, LIVES[n].t, false, LIVES[n].u) };
})();

/* ---------- Clips earnings wallet ---------- */
const WALLET = { bal: 1240, total: 3870, gifts: 214, lives: [320, 540, 180, 910, 680, 1240], hist: [['LIVE · 42:10', 1240], ['Withdraw to bank', -2630], ['LIVE · 31:05', 680]] };
function earnView() { const mx = Math.max(...WALLET.lives.slice(-7), 1);
  return `<div class="earnv"><div class="ph-h" style="margin:0 0 12px"><div><h1>Earnings</h1><small>CLIPS CREATOR WALLET</small></div></div>
  <div class="ew"><small>AVAILABLE TO WITHDRAW</small><b>$${WALLET.bal.toLocaleString('en-US')}</b><div class="r2"><button data-wd><i class="fa-solid fa-building-columns"></i> WITHDRAW</button><button class="g" data-golive><i class="fa-solid fa-tower-broadcast"></i> GO LIVE</button></div></div>
  <div class="est"><div>TOTAL EARNED<b>$${WALLET.total.toLocaleString('en-US')}</b></div><div>LIVES<b>${WALLET.lives.length}</b></div><div>GIFTS<b>${WALLET.gifts}</b></div></div>
  <div class="lbl" style="margin:0 0 6px">LAST LIVES</div><div class="bars5">${WALLET.lives.slice(-7).map((v, i) => `<div style="height:${Math.max(6, v / mx * 100)}%;animation-delay:${i * 60}ms"><span>$${v >= 1000 ? (v / 1000).toFixed(1) + 'K' : v}</span></div>`).join('')}</div>
  <div class="lbl" style="margin:14px 0 4px">HISTORY</div>${WALLET.hist.map(([n, v]) => `<div class="th"><div class="mono"><i class="fa-solid fa-${v > 0 ? 'tower-broadcast' : 'building-columns'}"></i></div><div><b>${n}</b><span>${v > 0 ? 'Gifts received' : 'Sent to ROX Bank'}</span></div><div class="r" style="font-size:12px;color:${v > 0 ? '#3ddc84' : 'rgba(255,255,255,.6)'}">${v > 0 ? '+' : '-'}$${Math.abs(v).toLocaleString('en-US')}</div></div>`).join('')}</div>`; }
Sett.apply();

/* ---------- phone number formatting ---------- */
function fmtN(n) { return String(n || '').replace(/^\((\d+)\)\s*/, '<em>($1)</em> '); }

/* ---------- share my contact with people nearby ---------- */
const NEARBY = [['Abu Ibrahim', 3], ['Sara', 7], ['Faisal', 12], ['Abu Snow', 18]];
function shareNearby(host) {
  const root = host.closest('.av') || $('scr');
  root.insertAdjacentHTML('beforeend', `<div class="near" id="near"><div class="box"><h3>Share my number<button class="sq" data-cx><i class="fa-solid fa-xmark"></i></button></h3><p>Tap a person near you to send ${ME.name} · ${ME.number}</p>
    <div class="radar"><div class="me2">${ME.name.split(' ').map(w => w[0]).join('').slice(0, 2)}</div>${NEARBY.map(([n, d], i) => { const a = i * 1.7 + .6, r = 30 + d * 2.4; return `<div class="pp2" data-send="${i}" style="left:${50 + Math.cos(a) * r / 1.6}%;top:${50 + Math.sin(a) * r / 2.2}%;animation-delay:${i * 120}ms"><i>${n.split(' ').map(w => w[0]).join('')}</i>${n.split(' ').slice(-1)[0]}</div>`; }).join('')}</div>
    ${NEARBY.map(([n, d], i) => `<div class="bk" data-send="${i}"><div class="mono">${n.split(' ').map(w => w[0]).join('')}</div><b>${n}</b><span>${d} m away</span><button class="cb" style="margin-left:8px"><i class="fa-solid fa-paper-plane"></i></button></div>`).join('')}</div></div>`);
  const nr = $('near'); nr.onclick = (e) => { if (e.target === nr || e.target.closest('[data-cx]')) return nr.remove(); const s = e.target.closest('[data-send]'); if (!s) return;
    const i = s.dataset.send; nr.querySelectorAll(`[data-send="${i}"]`).forEach(x => { x.classList.add('sent'); const b = x.querySelector('.cb'); if (b) b.innerHTML = '<i class="fa-solid fa-check"></i>'; });
    toast2(`Your number was sent to ${NEARBY[i][0]}`);
    if (window.invokeNative) fetch(`https://${GetParentResourceName()}/shareContact`, { method: 'POST', body: JSON.stringify({ to: NEARBY[i][0] }) }); };
}

/* ---------- first-time setup ---------- */
const Onboard = (() => { const D = { first: '', last: '', mail: '', pin: '', wall: 0 }; let step = 0;
  const store = (k, v) => { try { v === undefined ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch (e) {} };
  const done = () => { try { return localStorage.getItem('rox_setup') === '1'; } catch (e) { return false; } };
  const dots = () => `<div class="dots2">${[0, 1, 2, 3, 4].map(i => `<i class="${i <= step ? 'on' : ''}"></i>`).join('')}</div>`;
  const S = [
    () => `<div class="st4"><div class="logo">ROX</div><h2>Welcome to<br>your ROX phone</h2><p>Let's set it up. It only takes a minute: your name, your ROX Mail, a passcode and a wallpaper.</p><button class="nxt" data-next>Get started</button></div>`,
    () => `<div class="st4"><h2>What's your name?</h2><p>This is shown on your contact card and when you call people.</p>
      <div class="fld"><i class="fa-solid fa-user"></i><input id="obF" placeholder="First name" value="${D.first}"></div><div class="fld"><i class="fa-solid fa-user"></i><input id="obL" placeholder="Last name" value="${D.last}"></div>
      <button class="nxt" data-next id="obN">Continue</button><button class="bk2" data-back>Back</button></div>`,
    () => `<div class="st4"><h2>Create your<br>ROX Mail</h2><p>Pick an email address. You will use it for apps, bills and messages.</p>
      <div class="fld"><i class="fa-solid fa-at"></i><input id="obM" placeholder="username" value="${D.mail}"><span>@roxmail.ls</span></div><div class="hint2" id="obH">Letters, numbers, dots and _ only.</div>
      <button class="nxt" data-next id="obN">Continue</button><button class="bk2" data-back>Back</button></div>`,
    () => `<div class="st4"><h2>Set a passcode</h2><p>4 digits to unlock your phone.</p><div class="pinbox">${[0, 1, 2, 3].map(i => `<i class="${D.pin.length > i ? 'on' : ''}">${D.pin[i] ? '•' : ''}</i>`).join('')}</div>
      <div class="pad">${['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'].map(k => k ? `<button class="${k === 'del' ? 't' : ''}" data-k="${k}">${k === 'del' ? '<i class="fa-solid fa-delete-left"></i>' : k}</button>` : '<span></span>').join('')}</div>
      <button class="nxt" data-next ${D.pin.length === 4 ? '' : 'disabled'} style="margin-top:16px">Continue</button><button class="bk2" data-back>Back</button></div>`,
    () => `<div class="st4"><h2>Choose a wallpaper</h2><p>You can change it any time in Settings.</p><div class="wg">${[0, 1, 2, 3, 4, 5, 6, 7].map(i => `<i style="background:${RoxWalls.list[i]}" class="${i === D.wall ? 'on' : ''}" data-w="${i}"></i>`).join('')}</div>
      <button class="nxt" data-next style="margin-top:16px">Continue</button><button class="bk2" data-back>Back</button></div>`,
    () => `<div class="st4"><div class="done2"><i class="fa-solid fa-check"></i></div><h2 style="text-align:center">You're all set!</h2><p style="text-align:center">Your ROX phone is ready.</p>
      <div class="sumc"><div><span>Name</span><b>${D.first} ${D.last}</b></div><div><span>Number</span><b class="pn">${fmtN(ME.number)}</b></div><div><span>Email</span><b>${D.mail}@roxmail.ls</b></div></div>
      <button class="nxt" data-finish>Start using ROX</button></div>`];
  function draw() { const o = $('ob'); o.innerHTML = (step < 5 ? dots() : '') + S[step](); o.querySelectorAll('input').forEach(i => i.onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter') o.querySelector('[data-next]')?.click(); });
    const val = () => { const n = $('obN'); if (!n) return; if (step === 1) n.disabled = !($('obF').value.trim() && $('obL').value.trim());
      if (step === 2) { const ok = /^[a-z0-9._]{3,20}$/i.test($('obM').value.trim()); n.disabled = !ok; $('obH').className = 'hint2' + (ok || !$('obM').value ? '' : ' bad'); $('obH').textContent = ok ? $('obM').value.trim().toLowerCase() + '@roxmail.ls is available ✓' : 'Letters, numbers, dots and _ only (3–20).'; } };
    o.querySelectorAll('input').forEach(i => i.oninput = val); val(); setTimeout(() => o.querySelector('input')?.focus(), 60); }
  function open() { if ($('ob')) return; $('scr').insertAdjacentHTML('beforeend', '<div class="ob" id="ob"></div>'); step = 0; draw();
    $('ob').onclick = (e) => { const x = e.target.closest('[data-next],[data-back],[data-k],[data-w],[data-finish]'); if (!x || x.disabled) return;
      if (x.dataset.back !== undefined) { step--; return draw(); }
      if (x.dataset.k) { D.pin = x.dataset.k === 'del' ? D.pin.slice(0, -1) : (D.pin + x.dataset.k).slice(0, 4); return draw(); }
      if (x.dataset.w) { D.wall = +x.dataset.w; Sett.st.wall = D.wall; Sett.apply(); return draw(); }
      if (x.dataset.finish !== undefined) return finish();
      if (step === 1) { D.first = $('obF').value.trim(); D.last = $('obL').value.trim(); } if (step === 2) D.mail = $('obM').value.trim().toLowerCase();
      step++; draw(); }; }
  function finish() { ME.name = `${D.first} ${D.last}`; ME.email = `${D.mail}@roxmail.ls`; PIN = D.pin; store('rox_setup', '1'); store('rox_me', JSON.stringify({ n: ME.name, e: ME.email, p: PIN, w: D.wall }));
    $('ob').remove(); $('scr').classList.replace('locked', 'unlocked'); drawApps(); toast2(`Welcome, ${D.first}!`);
    if (window.invokeNative) fetch(`https://${GetParentResourceName()}/setup`, { method: 'POST', body: JSON.stringify({ name: ME.name, email: ME.email, pin: PIN, wallpaper: D.wall }) }); }
  try { const m = JSON.parse(localStorage.getItem('rox_me') || 'null'); if (m) { ME.name = m.n; ME.email = m.e; PIN = m.p; Sett.st.wall = m.w; } } catch (e) {}
  if (!done()) open();
  return { open, reset: () => { store('rox_setup'); store('rox_me'); D.first = D.last = D.mail = D.pin = ''; lock(); open(); } };
})();

/* =================== Messages v2 =================== */
document.head.insertAdjacentHTML('beforeend', `<style>
.m2 { display: flex; height: 100%; background: linear-gradient(180deg, #0e0e11, #09090b); font-family: 'Plus Jakarta Sans', sans-serif; }
.m2 .side { width: 100%; display: flex; flex-direction: column; min-width: 0; } .open .m2 .side { width: 300px; flex: none; border-right: 1px solid rgba(255,255,255,.06); } .m2 .main { display: none; flex: 1; min-width: 0; } .open .m2 .main { display: flex; }
.m2 .chatting .side { display: none; } .m2 .chatting .main { display: flex; } .open .m2 .chatting .side { display: flex; } .open .mh .bk3 { display: none; }
.m2-h { padding: 40px 16px 8px; display: flex; align-items: center; } .m2-h h1 { font-size: 26px; font-weight: 800; letter-spacing: -.6px; flex: 1; } .m2-h button { width: 34px; height: 34px; border-radius: 50%; border: 0; background: rgba(255,255,255,.08); color: #fff; cursor: pointer; margin-left: 6px; }
.m2-h button.acc { background: var(--a); }
.m2-s { margin: 4px 16px 10px; height: 36px; border-radius: 12px; background: rgba(255,255,255,.07); display: flex; align-items: center; gap: 8px; padding: 0 12px; } .m2-s input { flex: 1; min-width: 0; background: none; border: 0; outline: 0; color: #fff; font: 600 12.5px 'Plus Jakarta Sans'; } .m2-s i { color: rgba(255,255,255,.4); font-size: 11px; }
.pins2 { display: flex; gap: 12px; padding: 4px 16px 12px; overflow-x: auto; } .pins2 div { text-align: center; font-size: 10px; font-weight: 600; color: rgba(255,255,255,.7); cursor: pointer; width: 54px; flex: none; }
.av3 { width: 46px; height: 46px; border-radius: 50%; display: grid; place-items: center; font-weight: 800; font-size: 15px; color: #fff; position: relative; flex: none; } .av3.on::after { content: ''; position: absolute; right: 1px; bottom: 1px; width: 11px; height: 11px; border-radius: 50%; background: #3ddc84; border: 2.5px solid #0e0e11; }
.pins2 .av3 { width: 52px; height: 52px; margin: 0 auto 5px; box-shadow: 0 0 0 2px #0e0e11, 0 0 0 4px var(--a); }
.m2-l { flex: 1; overflow-y: auto; padding: 0 8px; } .th3 { display: flex; gap: 11px; align-items: center; padding: 10px 8px; border-radius: 14px; cursor: pointer; animation: fadeUp .3s backwards; } .th3:hover, .th3.sel { background: rgba(255,255,255,.05); }
.th3 .tx4 { flex: 1; min-width: 0; } .th3 b { display: flex; white-space: nowrap; gap: 6px; justify-content: space-between; font-size: 13.5px; } .th3 b small { font-size: 10px; font-weight: 600; color: rgba(255,255,255,.4); } .th3 span { display: flex; justify-content: space-between; gap: 6px; margin-top: 3px; font-size: 11.5px; color: rgba(255,255,255,.5); }
.th3 span em { font-style: normal; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; } .th3.un b { color: #fff; } .th3.un span em { color: #fff; font-weight: 700; } .th3 .ub { min-width: 19px; height: 19px; padding: 0 5px; border-radius: 10px; background: var(--a); color: #fff; font-size: 10px; font-weight: 800; display: grid; place-items: center; font-style: normal; }
.main { flex-direction: column; } .mh { display: flex; align-items: center; gap: 10px; padding: 38px 12px 10px; border-bottom: 1px solid rgba(255,255,255,.06); background: rgba(14,14,17,.8); backdrop-filter: blur(10px); }
.mh .tx4 { flex: 1; min-width: 0; } .mh b { display: block; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; } .mh small { display: block; } .mh small { font-size: 10px; color: #3ddc84; font-weight: 700; } .mh .av3 { width: 36px; height: 36px; font-size: 12px; }
.mh button { width: 32px; height: 32px; border-radius: 50%; border: 0; background: rgba(255,255,255,.07); color: #fff; cursor: pointer; font-size: 11px; } .mh .bk3 { background: none; font-size: 15px; width: 24px; }
.ms { flex: 1; overflow-y: auto; padding: 14px 12px; display: flex; flex-direction: column; gap: 3px; background: radial-gradient(circle at 80% 10%, rgba(255,90,31,.06), transparent 50%); }
.ms .dy { align-self: center; font-size: 9.5px; font-weight: 700; color: rgba(255,255,255,.4); padding: 3px 10px; border-radius: 10px; background: rgba(255,255,255,.05); margin: 8px 0; }
.bb { max-width: 76%; padding: 8px 12px 6px; font-size: 13px; line-height: 1.4; border-radius: 18px; background: #222228; align-self: flex-start; animation: pop .25s; position: relative; } .bb small { display: block; text-align: right; font-size: 9px; opacity: .55; margin-top: 2px; }
.bb.me { align-self: flex-end; background: linear-gradient(135deg, #ff7a3d, #e8450f); } .bb.me small i { margin-left: 3px; color: #fff; }
.bb.tail { margin-bottom: 6px; } .bb.tail:not(.me) { border-bottom-left-radius: 5px; } .bb.me.tail { border-bottom-right-radius: 5px; }
.bb.img { padding: 4px; } .bb.img .pic { width: 190px; height: 140px; border-radius: 14px; } .bb.loc { padding: 4px; } .bb.loc .mp { width: 200px; height: 110px; border-radius: 14px; background: repeating-linear-gradient(35deg, #2b2b33 0 3px, #1d1d22 3px 16px); position: relative; } .bb.loc .mp i { position: absolute; left: 50%; top: 45%; transform: translate(-50%,-50%); color: #ff3b30; font-size: 24px; } .bb.loc p { padding: 5px 8px 0; font-size: 12px; }
.bb.pay { padding: 12px; min-width: 170px; background: linear-gradient(135deg, #1f6b44, #0f3a25); } .bb.pay b { display: block; font-size: 22px; } .bb.pay span { font-size: 10px; opacity: .8; }
.typing { align-self: flex-start; padding: 10px 14px; border-radius: 18px; background: #222228; display: flex; gap: 4px; } .typing i { width: 6px; height: 6px; border-radius: 50%; background: rgba(255,255,255,.5); animation: tp 1s infinite; } .typing i:nth-child(2) { animation-delay: .15s; } .typing i:nth-child(3) { animation-delay: .3s; } @keyframes tp { 50% { transform: translateY(-4px); opacity: 1; } }
.cmp { display: flex; align-items: center; gap: 7px; padding: 8px 10px 20px; } .cmp .plus { width: 34px; height: 34px; border-radius: 50%; border: 0; background: rgba(255,255,255,.08); color: #fff; cursor: pointer; transition: transform .2s; } .cmp .plus.on { transform: rotate(45deg); background: var(--a); }
.cmp .in { flex: 1; display: flex; align-items: center; height: 38px; border-radius: 20px; background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.06); padding: 0 6px 0 14px; } .cmp input { flex: 1; min-width: 0; background: none; border: 0; outline: 0; color: #fff; font: 500 13px 'Plus Jakarta Sans'; }
.cmp .snd { width: 30px; height: 30px; border-radius: 50%; border: 0; background: var(--a); color: #fff; cursor: pointer; font-size: 11px; }
.att { display: none; gap: 8px; padding: 0 10px 6px; } .att.on { display: flex; animation: fadeUp .2s; } .att button { flex: 1; height: 56px; border-radius: 14px; border: 0; background: rgba(255,255,255,.06); color: #fff; font: 700 9.5px 'Plus Jakarta Sans'; cursor: pointer; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 5px; } .att i { font-size: 15px; }
.emp3 { flex: 1; display: grid; place-items: center; color: rgba(255,255,255,.35); font-size: 12px; text-align: center; } .emp3 i { font-size: 36px; display: block; margin-bottom: 10px; }
</style>`);
const COLS3 = ['#ff5a1f', '#2f7cf6', '#a855f7', '#22c55e', '#eab308', '#ec4899', '#14b8a6'];
const avc = (n) => COLS3[[...n].reduce((a, c) => a + c.charCodeAt(0), 0) % COLS3.length];
const avi = (n, cls = '') => `<div class="av3 ${cls}" style="background:linear-gradient(145deg, ${avc(n)}, ${avc(n)}aa)">${/^[\d(]/.test(n) ? '<i class="fa-solid fa-user"></i>' : n.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()}</div>`;
THREADS.forEach((t, i) => t.on = i % 2 === 0);
APPVIEW.messages = () => ({ raw: true, html: '<div class="m2" id="m2"></div>', after: () => { let cur = isOpen() ? 0 : null, q = '', att = false;
  const last = (t) => { const l = t.m[t.m.length - 1]; return (l[1] ? 'You: ' : '') + (l[3] === 'loc' ? '📍 Location' : l[3] === 'img' ? '📷 Photo' : l[3] === 'pay' ? '💵 ' + l[0] : l[0]); };
  const bubble = (m, i, arr) => { const [x, me, tm, k] = m, tail = !arr[i + 1] || arr[i + 1][1] !== me, f = `<small>${tm}${me ? '<i class="fa-solid fa-check-double"></i>' : ''}</small>`;
    if (k === 'loc') return `<div class="bb loc ${me ? 'me' : ''} ${tail ? 'tail' : ''}"><div class="mp"><i class="fa-solid fa-location-dot"></i></div><p>${x}</p>${f}</div>`;
    if (k === 'img') return `<div class="bb img ${me ? 'me' : ''} ${tail ? 'tail' : ''}"><div class="pic" style="background:${x}"></div>${f}</div>`;
    if (k === 'pay') return `<div class="bb pay ${me ? '' : ''} ${tail ? 'tail' : ''}" style="align-self:${me ? 'flex-end' : 'flex-start'}"><span>${me ? 'YOU SENT' : 'YOU RECEIVED'}</span><b>${x}</b><span>ROX Bank transfer</span>${f}</div>`;
    return `<div class="bb ${me ? 'me' : ''} ${tail ? 'tail' : ''}">${String(x).replace(/</g, '&lt;')}${f}</div>`; };
  function draw() { const el = $('m2'); if (!el) return; const L = THREADS.map((t, i) => [t, i]).filter(([t]) => !q || t.n.toLowerCase().includes(q.toLowerCase()));
    const t = cur !== null ? THREADS[cur] : null;
    el.innerHTML = `<div class="${t && !isOpen() ? 'chatting' : ''}" style="display:flex;width:100%;height:100%"><div class="side"><div class="m2-h"><h1>Messages</h1><button data-new class="acc"><i class="fa-solid fa-pen-to-square"></i></button></div>
      <div class="m2-s"><i class="fa-solid fa-magnifying-glass"></i><input id="mq" placeholder="Search" value="${q}"></div>
      <div class="pins2">${THREADS.slice(0, 4).map((x, i) => `<div data-k="${i}">${avi(x.n, x.on ? 'on' : '')}${x.n.split(' ').slice(-1)[0]}</div>`).join('')}</div>
      <div class="m2-l">${L.map(([x, i], k) => `<div class="th3 ${x.u ? 'un' : ''} ${i === cur && isOpen() ? 'sel' : ''}" data-k="${i}" style="animation-delay:${k * 30}ms">${avi(x.n, x.on ? 'on' : '')}<div class="tx4"><b>${x.n}<small>${x.m[x.m.length - 1][2]}</small></b><span><em>${last(x)}</em>${x.u ? `<i class="ub">${x.u}</i>` : ''}</span></div></div>`).join('')}</div></div>
      <div class="main">${t ? `<div class="mh"><button class="bk3" data-back><i class="fa-solid fa-chevron-left"></i></button>${avi(t.n, t.on ? 'on' : '')}<div class="tx4"><b>${t.n}</b><small style="color:${t.on ? '#3ddc84' : 'rgba(255,255,255,.4)'}">${t.on ? 'Online' : 'Last seen recently'}</small></div><button data-callc><i class="fa-solid fa-phone"></i></button><button data-vid><i class="fa-solid fa-video"></i></button></div>
        <div class="ms" id="msgs"><div class="dy">Today</div>${t.m.map(bubble).join('')}</div>
        <div class="att ${att ? 'on' : ''}"><button data-a="img"><i class="fa-solid fa-image" style="color:#a855f7"></i>Photo</button><button data-a="loc"><i class="fa-solid fa-location-dot" style="color:#ff3b30"></i>Location</button><button data-a="pay"><i class="fa-solid fa-dollar-sign" style="color:#3ddc84"></i>Money</button><button data-a="ct"><i class="fa-solid fa-address-card" style="color:#2f7cf6"></i>Contact</button></div>
        <div class="cmp"><button class="plus ${att ? 'on' : ''}" data-att><i class="fa-solid fa-plus"></i></button><div class="in"><input id="mi" placeholder="Message"><button class="snd" id="ms2"><i class="fa-solid fa-arrow-up"></i></button></div></div>`
        : '<div class="emp3"><div><i class="fa-regular fa-comments"></i><i class="fa-solid fa-comments"></i>Select a conversation</div></div>'}</div></div>`;
    const mq = $('mq'); mq.onkeydown = (e) => e.stopPropagation(); mq.oninput = () => { q = mq.value; const p = mq.selectionStart; draw(); $('mq').focus(); $('mq').setSelectionRange(p, p); };
    if (t) { $('msgs').scrollTop = 1e6; const mi = $('mi'); mi.onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter') send(); }; $('ms2').onclick = send; }
    bind(el, { k: (k) => { cur = +k; THREADS[cur].u = 0; att = false; draw(); }, back: () => { cur = null; draw(); }, att: () => { att = !att; draw(); },
      callc: () => Call.out(t.n, t.n), vid: () => toast2('Video call coming with the server version'),
      a: (a) => { const now = new Date().toTimeString().slice(0, 5); att = false;
        if (a === 'img') t.m.push([SCENES[Math.random() * SCENES.length | 0], 1, now, 'img']); if (a === 'loc') t.m.push(['Mission Row · Atlee St', 1, now, 'loc']);
        if (a === 'pay') { const v = +prompt('Amount to send ($)', '100'); if (!v || v > BANK.bank) return draw(); BANK.bank -= v; BANK.tx.unshift(['out', 'To ' + t.n, v, 'NOW', 'paper-plane']); t.m.push(['$' + v.toLocaleString('en-US'), 1, now, 'pay']); }
        if (a === 'ct') t.m.push([`${ME.name} · ${ME.number}`, 1, now]); draw(); },
      new: () => { const n = prompt('Send to (name or number)'); if (!n) return; THREADS.unshift({ n, m: [['Hi!', 1, new Date().toTimeString().slice(0, 5)]] }); cur = 0; draw(); } }); }
  function send() { const v = $('mi').value.trim(); if (!v) return; const t = THREADS[cur], now = new Date().toTimeString().slice(0, 5); t.m.push([v, 1, now]); draw();
    setTimeout(() => { if (!$('msgs') || THREADS[cur] !== t) return; $('msgs').insertAdjacentHTML('beforeend', '<div class="typing" id="typ"><i></i><i></i><i></i></div>'); $('msgs').scrollTop = 1e6; }, 600);
    setTimeout(() => { t.m.push([['👍', 'Ok!', 'On it', 'Haha', 'See you soon', 'Where?'][Math.random() * 6 | 0], 0, new Date().toTimeString().slice(0, 5)]); if (THREADS[cur] === t) draw(); }, 2000); }
  draw(); } });

/* =================== Pic-it (Instagram style) =================== */
document.head.insertAdjacentHTML('beforeend', `<style>
.ig { position: relative; height: 100%; display: flex; flex-direction: column; background: #000; font-family: 'Plus Jakarta Sans', sans-serif; }
.ig-top { display: flex; align-items: center; gap: 14px; padding: 38px 14px 8px; } .ig-top .lg { flex: 1; font: italic 800 24px 'Plus Jakarta Sans'; letter-spacing: -.8px; background: linear-gradient(90deg, #ffb020, #ff2d6f, #a855f7); -webkit-background-clip: text; color: transparent; }
.ig-top i { font-size: 18px; cursor: pointer; position: relative; } .ig-top i em { position: absolute; top: -5px; right: -7px; min-width: 15px; height: 15px; border-radius: 8px; background: #ff2d55; font: 800 8.5px 'Plus Jakarta Sans'; display: grid; place-items: center; font-style: normal; }
.ig-body { flex: 1; overflow-y: auto; } .open .ig-body .feed2 { max-width: 420px; margin: 0 auto; }
.stories { display: flex; gap: 12px; padding: 6px 12px 12px; overflow-x: auto; border-bottom: 1px solid rgba(255,255,255,.08); } .stories div { flex: none; width: 64px; text-align: center; font-size: 10px; color: rgba(255,255,255,.85); cursor: pointer; }
.ring3 { width: 62px; height: 62px; border-radius: 50%; padding: 2.5px; margin: 0 auto 4px; background: conic-gradient(#ffb020, #ff2d6f, #a855f7, #ffb020); } .ring3.seen { background: rgba(255,255,255,.2); } .ring3 > div { width: 100%; height: 100%; border-radius: 50%; border: 3px solid #000; display: grid; place-items: center; font-weight: 800; font-size: 18px; }
.ring3.add { background: none; position: relative; } .ring3.add::after { content: '+'; position: absolute; right: 0; bottom: 0; width: 20px; height: 20px; border-radius: 50%; background: #2f7cf6; border: 2.5px solid #000; font-size: 15px; line-height: 15px; font-weight: 800; }
.post { padding-bottom: 14px; animation: fadeUp .35s backwards; } .post .ph3 { display: flex; align-items: center; gap: 9px; padding: 10px 12px; } .post .ph3 .r { width: 32px; height: 32px; padding: 2px; } .post .ph3 .r > div { border-width: 2px; font-size: 11px; }
.post .ph3 b { font-size: 12.5px; display: block; } .post .ph3 span { font-size: 10px; color: rgba(255,255,255,.55); } .post .ph3 .sp { flex: 1; }
.post .im { position: relative; aspect-ratio: 1; background-size: cover !important; } .post .im .bh { position: absolute; left: 50%; top: 50%; font-size: 90px; color: #fff; transform: translate(-50%,-50%) scale(0); filter: drop-shadow(0 6px 20px rgba(0,0,0,.4)); } .post .im .bh.go { animation: bh2 .9s; } @keyframes bh2 { 15% { transform: translate(-50%,-50%) scale(1.2); } 30%,70% { transform: translate(-50%,-50%) scale(1); opacity: 1; } to { transform: translate(-50%,-50%) scale(0); opacity: 0; } }
.post .ac { display: flex; gap: 16px; padding: 10px 12px 6px; font-size: 21px; } .post .ac i { cursor: pointer; transition: transform .15s; } .post .ac i:active { transform: scale(.8); } .post .ac .sv { margin-left: auto; } .post .ac .lk { color: #ff2d55; animation: popHeart .35s; }
.post .tx3 { padding: 0 12px; font-size: 12.5px; line-height: 1.45; } .post .tx3 b { margin-right: 5px; } .post .tx3 .mu { color: rgba(255,255,255,.5); font-size: 11.5px; margin-top: 3px; cursor: pointer; } .post .tx3 .tm { color: rgba(255,255,255,.4); font-size: 9.5px; margin-top: 4px; letter-spacing: .5px; }
.ig-nav { display: flex; justify-content: space-around; padding: 10px 0 22px; border-top: 1px solid rgba(255,255,255,.1); background: #000; font-size: 20px; } .ig-nav i { cursor: pointer; opacity: .6; } .ig-nav i.on { opacity: 1; } .ig-nav .me4 { width: 24px; height: 24px; border-radius: 50%; font: 800 9px 'Plus Jakarta Sans'; display: grid; place-items: center; cursor: pointer; opacity: .7; } .ig-nav .me4.on { opacity: 1; box-shadow: 0 0 0 2px #fff; }
.prof2 { padding: 0 14px; } .prof2 .row4 { display: flex; align-items: center; gap: 18px; margin: 6px 0 10px; } .prof2 .ring3 { width: 82px; height: 82px; margin: 0; } .prof2 .ring3 > div { font-size: 26px; }
.prof2 .nums4 { flex: 1; display: flex; justify-content: space-around; text-align: center; } .prof2 .nums4 b { display: block; font-size: 16px; } .prof2 .nums4 span { font-size: 11px; color: rgba(255,255,255,.7); }
.prof2 .bio b { font-size: 13px; } .prof2 .bio p { font-size: 12px; color: rgba(255,255,255,.85); margin: 2px 0; white-space: pre-line; } .prof2 .bio a { font-size: 12px; color: #7aa7ff; }
.prof2 .btns { display: flex; gap: 6px; margin: 12px 0; } .prof2 .btns button { flex: 1; height: 32px; border-radius: 8px; border: 0; background: rgba(255,255,255,.12); color: #fff; font: 700 12px 'Plus Jakarta Sans'; cursor: pointer; } .prof2 .btns .bl { background: #2f7cf6; }
.ptabs { display: flex; border-top: 1px solid rgba(255,255,255,.1); } .ptabs i { flex: 1; text-align: center; padding: 10px 0; font-size: 16px; opacity: .45; border-bottom: 1.5px solid transparent; cursor: pointer; } .ptabs i.on { opacity: 1; border-bottom-color: #fff; }
.grid4 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 2px; } .grid4 div { aspect-ratio: 1; cursor: pointer; background-size: cover !important; position: relative; } .grid4 div em { position: absolute; left: 6px; bottom: 5px; font-style: normal; font-size: 10px; font-weight: 800; text-shadow: 0 1px 3px #000; }
.ig-auth { position: absolute; inset: 0; z-index: 5; display: flex; flex-direction: column; padding: 70px 28px 30px; background: radial-gradient(circle at 20% 0%, rgba(255,45,111,.3), transparent 50%), radial-gradient(circle at 100% 100%, rgba(168,85,247,.25), transparent 50%), #000; }
.open .ig-auth { padding: 70px 30% 30px; } .ig-auth .lg { text-align: center; font: italic 800 38px 'Plus Jakarta Sans'; letter-spacing: -1px; background: linear-gradient(90deg, #ffb020, #ff2d6f, #a855f7); -webkit-background-clip: text; color: transparent; margin-bottom: 6px; }
.ig-auth p { text-align: center; font-size: 12.5px; color: rgba(255,255,255,.6); margin-bottom: 24px; } .ig-auth input { width: 100%; height: 44px; margin-bottom: 9px; padding: 0 14px; border-radius: 10px; border: 1px solid rgba(255,255,255,.12); background: rgba(255,255,255,.05); color: #fff; font: 600 13px 'Plus Jakarta Sans'; outline: 0; } .ig-auth input:focus { border-color: #ff2d6f; }
.ig-auth .go4 { width: 100%; height: 44px; border-radius: 10px; border: 0; background: linear-gradient(90deg, #ff6a3d, #ff2d6f, #a855f7); color: #fff; font: 800 13px 'Plus Jakarta Sans'; cursor: pointer; margin-top: 6px; } .ig-auth .go4:disabled { opacity: .4; }
.ig-auth .alt { text-align: center; font-size: 12px; color: rgba(255,255,255,.55); margin-top: auto; } .ig-auth .alt b { color: #fff; cursor: pointer; } .ig-auth .er { font-size: 11px; color: #ff6b6b; min-height: 15px; }
.ig-auth .ava { width: 96px; height: 96px; border-radius: 50%; margin: 0 auto 16px; display: grid; place-items: center; font-size: 34px; font-weight: 800; cursor: pointer; position: relative; } .ig-auth .ava::after { content: '\\f030'; font-family: 'Font Awesome 6 Free'; font-weight: 900; position: absolute; right: 0; bottom: 0; width: 30px; height: 30px; border-radius: 50%; background: #2f7cf6; font-size: 12px; display: grid; place-items: center; border: 3px solid #000; }
.story-v { position: absolute; inset: 0; z-index: 6; background: #000; } .story-v .img4 { position: absolute; inset: 0; } .story-v .bars6 { position: absolute; top: 38px; left: 8px; right: 8px; display: flex; gap: 3px; } .story-v .bars6 i { flex: 1; height: 2.5px; border-radius: 2px; background: rgba(255,255,255,.35); overflow: hidden; } .story-v .bars6 i b { display: block; height: 100%; width: 0; background: #fff; }
.story-v .bars6 i.dn b { width: 100%; } .story-v .bars6 i.go b { animation: sbar 4s linear forwards; } @keyframes sbar { to { width: 100%; } } .story-v .who { position: absolute; top: 50px; left: 12px; display: flex; align-items: center; gap: 8px; font-size: 12.5px; font-weight: 700; } .story-v .who .av3 { width: 30px; height: 30px; font-size: 11px; }
.story-v .x5 { position: absolute; top: 52px; right: 12px; font-size: 18px; cursor: pointer; } .story-v .rp { position: absolute; left: 12px; right: 12px; bottom: 24px; display: flex; gap: 10px; align-items: center; } .story-v .rp input { flex: 1; height: 40px; border-radius: 20px; border: 1px solid rgba(255,255,255,.6); background: none; color: #fff; padding: 0 16px; font: 500 12.5px 'Plus Jakarta Sans'; outline: 0; } .story-v .rp i { font-size: 20px; cursor: pointer; }
.np { padding: 0 14px; } .np .prev { aspect-ratio: 1; border-radius: 12px; margin-bottom: 10px; } .np .pick { display: grid; grid-template-columns: repeat(5, 1fr); gap: 5px; margin-bottom: 12px; } .np .pick i { aspect-ratio: 1; border-radius: 6px; cursor: pointer; border: 2px solid transparent; } .np .pick i.on { border-color: #fff; }
.np textarea { width: 100%; height: 70px; border-radius: 10px; border: 1px solid rgba(255,255,255,.12); background: rgba(255,255,255,.05); color: #fff; padding: 10px; font: 500 12.5px 'Plus Jakarta Sans'; resize: none; outline: 0; }
.notif3 .th { border: 0; padding: 9px 0; } .notif3 .pic5 { width: 40px; height: 40px; border-radius: 4px; }
</style>`);
const IG = { acc: null, tab: 'home', posts: [
  { u: 'abu_snow', loc: 'Vinewood Hills', img: 'img/wall_vinewood.webp', c: 'Night views never get old 🌃 #lossantos', l: 1243, cm: [['sara.ls', 'Wow 😍'], ['faisal', 'Where is this exactly?']], t: '2 HOURS AGO' },
  { u: 'sara.ls', loc: 'Del Perro Pier', img: 'img/wall_pier.webp', c: 'Sunset ride with the girls 🎡', l: 864, cm: [['abu_ibrahim', 'Beautiful']], t: '5 HOURS AGO' },
  { u: 'lspd_official', loc: 'Route 68', img: 'img/wall_desert.webp', c: 'Patrol in Sandy Shores today. Drive safe. 🚓', l: 3120, cm: [], t: '1 DAY AGO' }],
  stories: [['abu_snow', 'img/wall_neon.webp'], ['sara.ls', 'img/wall_golden.webp'], ['faisal', 'img/wall_ocean.webp'], ['abu_kayan', 'img/wall_chiliad.webp']] };
try { IG.acc = JSON.parse(localStorage.getItem('rox_ig') || 'null'); } catch (e) {}
const igimg = (u) => /^img\/|^https?:|^data:/.test(u) ? `url('${u}') center/cover` : u;
APPVIEW.picit = () => ({ raw: true, html: '<div class="ig" id="ig"></div>', after: () => { const el = $('ig'); let ptab = 'grid', sel = 0;
  const ring = (n, cls = '', sz = '') => `<div class="ring3 ${cls}" ${sz}><div style="background:linear-gradient(145deg, ${avc(n)}, #111)">${n[0].toUpperCase()}</div></div>`;
  const mine = () => IG.posts.filter(p => p.u === IG.acc.user);
  const nav = () => `<div class="ig-nav">${[['home', 'house'], ['search', 'magnifying-glass'], ['new', 'square-plus'], ['act', 'heart']].map(([t, i]) => `<i class="fa-solid fa-${i} ${IG.tab === t ? 'on' : ''}" data-t="${t}"></i>`).join('')}<div class="me4 ${IG.tab === 'me' ? 'on' : ''}" data-t="me" style="background:${avc(IG.acc.user)}">${IG.acc.user[0].toUpperCase()}</div></div>`;
  const post = (p, i) => `<div class="post" style="animation-delay:${i * 60}ms"><div class="ph3"><div class="r">${ring(p.u, '', 'style="width:32px;height:32px;padding:2px"')}</div><div><b>${p.u}</b><span>${p.loc || ''}</span></div><div class="sp"></div><i class="fa-solid fa-ellipsis"></i></div>
    <div class="im" data-dbl="${i}" style="background:${igimg(p.img)}"><i class="bh fa-solid fa-heart"></i></div>
    <div class="ac"><i class="fa-solid fa-heart ${p.liked ? 'lk' : ''}" data-lk="${i}"></i><i class="fa-solid fa-comment" data-cmt="${i}"></i><i class="fa-solid fa-paper-plane" data-shr></i><i class="fa-solid fa-bookmark sv" data-sv="${i}" style="${p.sv ? 'color:#ffd36b' : ''}"></i></div>
    <div class="tx3"><b>${p.l.toLocaleString('en-US')} likes</b><div><b>${p.u}</b>${p.c}</div>${p.cm.length ? `<div class="mu" data-cmt="${i}">View all ${p.cm.length} comments</div>` : ''}<div class="tm">${p.t}</div></div></div>`;
  function auth(mode) { el.innerHTML = mode === 'up' ? `<div class="ig-auth"><div class="lg">Pic-it</div><p>Sign up to share photos with Los Santos.</p><div class="ava" id="ava" style="background:${avc(ME.name)}">${ME.name[0]}</div>
      <input id="aN" placeholder="Full name" value="${ME.name}"><input id="aU" placeholder="Username"><input id="aP" type="password" placeholder="Password (6+ characters)"><input id="aB" placeholder="Bio (optional)"><div class="er" id="aE"></div><button class="go4" id="aGo" disabled>Sign up</button>
      <div class="alt">Have an account? <b data-mode="in">Log in</b></div></div>`
    : `<div class="ig-auth"><div class="lg">Pic-it</div><p>Welcome back.</p><input id="aU" placeholder="Username"><input id="aP" type="password" placeholder="Password"><div class="er" id="aE"></div><button class="go4" id="aGo">Log in</button><div class="alt">Don't have an account? <b data-mode="up">Sign up</b></div></div>`;
    stopKeys(el); const u = $('aU'), pw = $('aP');
    const val = () => { const ok = /^[a-z0-9._]{3,20}$/.test(u.value) && pw.value.length >= 6; if (mode === 'up') $('aGo').disabled = !ok; $('aE').textContent = u.value && !/^[a-z0-9._]{3,20}$/.test(u.value) ? 'Username: lowercase letters, numbers, . and _ only' : ''; };
    u.oninput = () => { u.value = u.value.toLowerCase().replace(/\s/g, ''); val(); }; pw.oninput = val;
    $('aGo').onclick = () => { if (mode === 'in') { const s = JSON.parse(localStorage.getItem('rox_ig_saved') || 'null'); if (!s || s.user !== u.value || s.pw !== pw.value) return $('aE').textContent = 'Wrong username or password'; IG.acc = s; }
      else IG.acc = { user: u.value, pw: pw.value, name: $('aN').value || ME.name, bio: $('aB').value || 'Living in Los Santos 🌴', followers: 0, following: 12 };
      try { localStorage.setItem('rox_ig', JSON.stringify(IG.acc)); localStorage.setItem('rox_ig_saved', JSON.stringify(IG.acc)); } catch (e) {} IG.tab = 'home'; toast2(mode === 'up' ? 'Welcome to Pic-it, @' + IG.acc.user : 'Logged in'); draw(); };
    bind(el, { mode: (m) => auth(m) }); }
  function draw() { if (!IG.acc) return auth('up'); let body = '';
    if (IG.tab === 'home') body = `<div class="stories"><div data-t="new">${ring(IG.acc.user, 'add')}Your story</div>${IG.stories.map(([n], i) => `<div data-st="${i}">${ring(n, IG.seen?.[i] ? 'seen' : '')}${n}</div>`).join('')}</div><div class="feed2">${IG.posts.map(post).join('')}</div>`;
    if (IG.tab === 'search') body = `<div style="padding:0 12px 10px"><div class="m2-s" style="margin:0"><i class="fa-solid fa-magnifying-glass"></i><input placeholder="Search"></div></div><div class="grid4">${['wall_golden', 'wall_neon', 'wall_ocean', 'wall_pier', 'wall_vinewood', 'wall_chiliad', 'wall_desert', 'wall_roxabs', 'wall_golden'].map((w, i) => `<div style="background:${igimg('img/' + w + '.webp')};${i === 1 ? 'grid-row:span 2;aspect-ratio:auto' : ''}"></div>`).join('')}</div>`;
    if (IG.tab === 'act') body = `<div class="np notif3"><h3 style="font-size:15px;margin:4px 0 8px">Activity</h3>${[['sara.ls', 'liked your photo.', '2m'], ['abu_snow', 'started following you.', '1h'], ['faisal', 'commented: Legend 🔥', '3h'], ['abu_kayan', 'liked your story.', '1d']].map(([u, t, a]) => `<div class="th">${avi(u)}<div style="flex:1;font-size:12px"><b>${u}</b> ${t} <span style="color:rgba(255,255,255,.4)">${a}</span></div>${t.includes('following') ? '<button class="pay" style="background:#2f7cf6;color:#fff;border:0">Follow</button>' : `<div class="pic5" style="background:${igimg('img/wall_pier.webp')}"></div>`}</div>`).join('')}</div>`;
    if (IG.tab === 'new') body = `<div class="np"><h3 style="font-size:15px;margin:4px 0 10px">New post</h3><div class="prev" id="pv" style="background:${GALLERY[sel] ? GALLERY[sel].bg : SCENES[0]}"></div><div class="pick">${GALLERY.slice(0, 10).map((g, i) => `<i style="background:${g.bg}" class="${i === sel ? 'on' : ''}" data-pk="${i}"></i>`).join('')}</div>
      <textarea id="cap" placeholder="Write a caption…"></textarea><div class="fld" style="margin-top:8px"><i class="fa-solid fa-location-dot"></i><input id="loc" placeholder="Add location" value="Los Santos"></div><button class="go4" style="width:100%;height:42px;border:0;border-radius:10px;background:linear-gradient(90deg,#ff6a3d,#ff2d6f,#a855f7);color:#fff;font:800 13px 'Plus Jakarta Sans';cursor:pointer" data-share2>Share</button></div>`;
    if (IG.tab === 'me') { const m = mine(); body = `<div class="prof2"><div class="row4">${ring(IG.acc.user, '')}<div class="nums4"><div><b>${m.length}</b><span>Posts</span></div><div><b>${IG.acc.followers}</b><span>Followers</span></div><div><b>${IG.acc.following}</b><span>Following</span></div></div></div>
      <div class="bio"><b>${IG.acc.name}</b><p>${IG.acc.bio}</p><a>${ME.email || 'roxmail.ls'}</a></div><div class="btns"><button data-ed>Edit profile</button><button data-shr>Share profile</button><button data-out style="flex:none;width:36px"><i class="fa-solid fa-right-from-bracket"></i></button></div></div>
      <div class="ptabs"><i class="fa-solid fa-table-cells on"></i><i class="fa-solid fa-clapperboard"></i><i class="fa-solid fa-user-tag"></i></div>
      <div class="grid4">${m.map(p => `<div style="background:${igimg(p.img)}"><em><i class="fa-solid fa-heart"></i> ${p.l}</em></div>`).join('') || '<div style="grid-column:span 3;aspect-ratio:auto;padding:40px;text-align:center;color:rgba(255,255,255,.4);font-size:12px"><i class="fa-solid fa-camera" style="font-size:30px;display:block;margin-bottom:8px"></i>Share your first photo</div>'}</div>`; }
    el.innerHTML = `<div class="ig-top"><span class="lg">${IG.tab === 'me' ? '' : 'Pic-it'}</span>${IG.tab === 'me' ? `<b style="flex:1;font-size:17px;margin-left:-14px"><i class="fa-solid fa-lock" style="font-size:12px"></i> ${IG.acc.user}</b>` : ''}<i class="fa-solid fa-heart" data-t="act"><em>4</em></i><i class="fa-solid fa-paper-plane" data-dm><em>2</em></i></div><div class="ig-body">${body}</div>${nav()}`;
    el.querySelectorAll('input,textarea').forEach(i => i.onkeydown = (e) => e.stopPropagation());
    el.querySelectorAll('[data-dbl]').forEach(d => d.ondblclick = () => { const p = IG.posts[d.dataset.dbl], h = d.querySelector('.bh'); h.classList.remove('go'); void h.offsetWidth; h.classList.add('go'); if (!p.liked) { p.liked = true; p.l++; setTimeout(draw, 700); } });
    bind(el, { t: (t) => { IG.tab = t; draw(); }, lk: (i) => { const p = IG.posts[i]; p.liked = !p.liked; p.l += p.liked ? 1 : -1; draw(); }, sv: (i) => { IG.posts[i].sv = !IG.posts[i].sv; draw(); toast2(IG.posts[i].sv ? 'Saved' : 'Removed from saved'); },
      shr: () => toast2('Link copied'), dm: () => { closeApp(); setTimeout(() => openApp('messages', 'Messages', $('hb')), 300); }, pk: (i) => { sel = +i; draw(); },
      cmt: (i) => { const p = IG.posts[i]; el.insertAdjacentHTML('beforeend', `<div class="sheet" id="sht"><h4>Comments<i class="fa-solid fa-xmark" data-cx></i></h4><div class="cl2" id="cl2">${p.cm.map(([u, t]) => `<div class="cm">${avi(u)}<div><b>${u}</b>${t}</div></div>`).join('') || '<div style="text-align:center;color:rgba(255,255,255,.4);font-size:12px;padding:20px">No comments yet</div>'}</div><div class="comp2"><input id="ci" placeholder="Add a comment for ${p.u}…"><button id="cs"><i class="fa-solid fa-paper-plane"></i></button></div></div>`);
        stopKeys($('sht')); const send = () => { const v = $('ci').value.trim(); if (!v) return; p.cm.push([IG.acc.user, v]); $('sht').remove(); draw(); }; $('cs').onclick = send; $('ci').onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter') send(); }; $('sht').querySelector('[data-cx]').onclick = () => $('sht').remove(); },
      st: (i) => story(+i), share2: () => { IG.posts.unshift({ u: IG.acc.user, loc: $('loc').value, img: (GALLERY[sel] || {}).bg || SCENES[0], c: $('cap').value || '', l: 0, cm: [], t: 'JUST NOW' }); IG.tab = 'home'; toast2('Posted!'); draw(); },
      ed: () => { const b = prompt('Bio', IG.acc.bio); if (b !== null) { IG.acc.bio = b; try { localStorage.setItem('rox_ig', JSON.stringify(IG.acc)); } catch (e) {} draw(); } },
      out: () => { IG.acc = null; try { localStorage.removeItem('rox_ig'); } catch (e) {} draw(); } }); }
  function story(i) { if (i >= IG.stories.length) return draw(); IG.seen = IG.seen || {}; IG.seen[i] = 1; const [n, img] = IG.stories[i];
    el.insertAdjacentHTML('beforeend', `<div class="story-v" id="sv"><div class="img4" style="background:${igimg(img)}"></div><div class="bars6">${IG.stories.map((_, k) => `<i class="${k < i ? 'dn' : k === i ? 'go' : ''}"><b></b></i>`).join('')}</div><div class="who">${avi(n)}${n} <span style="opacity:.6;font-weight:500">2h</span></div><i class="x5 fa-solid fa-xmark" data-x></i>
      <div class="rp"><input placeholder="Send message"><i class="fa-solid fa-heart"></i><i class="fa-solid fa-paper-plane"></i></div></div>`);
    const sv = $('sv'); stopKeys(sv); const t = setTimeout(() => { sv.remove(); story(i + 1); }, 4000);
    sv.querySelector('[data-x]').onclick = () => { clearTimeout(t); sv.remove(); draw(); }; sv.querySelector('.img4').onclick = () => { clearTimeout(t); sv.remove(); story(i + 1); }; }
  draw(); } });

$('bSetup').onclick = () => Onboard.reset();
Sett.apply();
