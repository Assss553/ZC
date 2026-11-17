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
  const nav = () => `<div class="cnav">${[['home', 'house', 'Home'], ['disc', 'compass', 'Discover'], ['plus'], ['inbox', 'message', 'Inbox'], ['me', 'user', 'Profile']].map(([t, ic, l]) => t === 'plus' ? '<div class="plus" data-t="plus"><i class="fa-solid fa-plus"></i></div>' : `<span class="${tab === t ? 'on' : ''}" data-t="${t}"><i class="fa-solid fa-${ic}"></i>${l}</span>`).join('')}</div>`;
  function draw() { const el = $('clp'); if (!el) return;
    if (tab === 'home') el.innerHTML = `<div class="ctop"><span>Following</span><span class="on">For You</span><i class="fa-solid fa-magnifying-glass"></i></div><div class="feed" id="feed" style="transform:translateY(${-i * 100}%)">${CLIPS.map((c, n) => `<div class="clip" style="top:${n * 100}%"><div class="bg" style="background:${c.bg}"></div><i class="big3 fa-solid fa-${c.ic}"></i><div class="shade"></div>
      <div class="rail"><div><div class="av2" style="background:${SCENES[(n + 3) % 9]}">${c.u[0].toUpperCase()}</div></div><div data-like="${n}" class="${c.liked ? 'liked' : ''}"><i class="fa-solid fa-heart"></i>${k(c.l)}</div><div data-cm="${n}"><i class="fa-solid fa-comment-dots"></i>${k(c.cm)}</div><div data-sv="${n}"><i class="fa-solid fa-bookmark" style="${c.sv ? 'color:#ffd36b' : ''}"></i>Save</div><div data-share><i class="fa-solid fa-share"></i>Share</div><div><div class="disc"></div></div></div>
      <div class="cap"><b>@${c.u}</b><p>${c.c}</p><span><i class="fa-solid fa-music"></i>${c.s}</span></div></div>`).join('')}</div>${nav()}`;
    else if (tab === 'me') el.innerHTML = `<div class="cprof"><div class="avb">RP</div><b>@rox_player</b><div class="nums"><div><b>182</b><span>Following</span></div><div><b>4.2K</b><span>Followers</span></div><div><b>39K</b><span>Likes</span></div></div>
      <button class="go2" style="width:140px;height:34px;margin-bottom:14px">EDIT PROFILE</button><div class="grid3" style="padding:0 2px">${GALLERY.map(g => `<div style="background:${g.bg};aspect-ratio:3/4"><em><i class="fa-solid fa-play"></i> ${(Math.random() * 9 + 1).toFixed(1)}K</em></div>`).join('')}</div></div>${nav()}`;
    else el.innerHTML = `<div class="cprof" style="text-align:left"><div class="ph-top"><div class="ph-h"><div><h1>${tab === 'disc' ? 'DISCOVER' : 'INBOX'}</h1><small>${tab === 'disc' ? 'TRENDING IN LOS SANTOS' : 'ACTIVITY'}</small></div></div></div><div class="ph-body">
      ${tab === 'disc' ? `<div class="lbl" style="margin:0 0 6px">LIVE NOW</div>${LIVES.map((l, n) => `<div class="live-card" data-watch="${n}" style="background:${l.bg}"><span class="badge">LIVE</span><span class="vw"><i class="fa-solid fa-eye"></i> ${l.v}</span><b>@${l.u}</b><span class="s">${l.t}</span></div>`).join('')}<div class="lbl" style="margin:10px 0 6px">TRENDING</div>` + ['#lossantos', '#carmeet', '#lspd', '#foodtok', '#heist'].map((h, n) => `<div class="th"><div class="mono">#</div><div><b>${h}</b><span>${(n + 1) * 37}K videos</span></div><div class="r">${n + 1}</div></div>`).join('')
        : COMMENTS.map(([u, t]) => `<div class="th"><div class="mono">${u[0].toUpperCase()}</div><div><b>${u}</b><span>commented: ${t}</span></div><div class="r">${2 + u.length}m</div></div>`).join('')}</div></div>${nav()}`;
    bind(el, { t: (t) => { if (t === 'plus') return Live.setup(el); tab = t; draw(); },
      like: (n) => { const c = CLIPS[n]; c.liked = !c.liked; c.l += c.liked ? 1 : -1; draw(); }, sv: (n) => { CLIPS[n].sv = !CLIPS[n].sv; draw(); toast2(CLIPS[n].sv ? 'Saved' : 'Removed'); },
      share: () => toast2('Link copied'), watch: (n) => Live.watch(el, n), cm: (n) => { el.insertAdjacentHTML('beforeend', `<div class="sheet" id="sht"><h4>${k(CLIPS[n].cm)} comments<i class="fa-solid fa-xmark" data-cx></i></h4><div class="cl2" id="cl2">${COMMENTS.map(([u, t]) => `<div class="cm"><div class="mono" style="width:30px;height:30px;border-radius:50%">${u[0].toUpperCase()}</div><div><b>${u}</b>${t}</div></div>`).join('')}</div><div class="comp2"><input id="ci" placeholder="Add comment…"><button id="cs"><i class="fa-solid fa-paper-plane"></i></button></div></div>`);
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
const NOTES = [['Shopping', 'Bread, water, repair kit', 'Today'], ['Meeting', 'Crew meet at 21:00 near the pier', 'Yesterday'], ['Plates', '06HBT193 · 5UB26785', 'Mon']];
APPVIEW.notes = () => R(() => { const list = () => { PH().innerHTML = head('NOTES', `${NOTES.length} NOTES`) + `<div class="ph-body">${NOTES.map(([t, b, d], i) => `<div class="card2" data-n="${i}" style="cursor:pointer;animation-delay:${i * 40}ms;border-left:3px solid #ffb800"><b style="font-size:13px">${t}</b><p style="font-size:11.5px;color:rgba(255,255,255,.55);margin-top:3px">${b}</p><span style="font-size:9px;font-weight:800;letter-spacing:1px;color:rgba(255,255,255,.35)">${d.toUpperCase()}</span></div>`).join('')}</div><button class="fab" data-n="new"><i class="fa-solid fa-plus"></i></button>`;
  bind(PH(), { n: (i) => edit(i) }); };
  const edit = (i) => { const n = i === 'new' ? ['', '', 'Today'] : NOTES[i]; PH().innerHTML = head('NOTE', 'EDITING') + `<div class="ph-body"><div class="back" style="margin:0 -16px 12px"><button data-bk><i class="fa-solid fa-chevron-left"></i>NOTES</button>${i !== 'new' ? '<button class="sq" data-dl><i class="fa-solid fa-trash"></i></button>' : ''}</div>
    <div class="fld"><input id="nt" placeholder="Title" value="${n[0]}"></div><textarea class="ta" id="nb" style="min-height:220px" placeholder="Write something…">${n[1]}</textarea><button class="go2" data-sv>SAVE</button></div>`; stopKeys(PH());
    bind(PH(), { bk: () => list(), dl: () => { NOTES.splice(i, 1); list(); }, sv: () => { const v = [$('nt').value || 'Untitled', $('nb').value, 'Today']; if (i === 'new') NOTES.unshift(v); else NOTES[i] = v; toast2('Note saved'); list(); } }); }; list(); });

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
APPVIEW.picit = () => R(() => { PH().innerHTML = head('PIC-IT', 'CITY FEED', '<i class="fa-solid fa-plus"></i>') + `<div class="ph-body">${GALLERY.slice(0, 5).map((g, i) => `<div class="card2" style="padding:0;overflow:hidden"><div class="hd2" style="padding:9px 11px 0"><div class="mono">${'ASFRL'[i]}</div><b>${['abu_snow', 'sara.ls', 'faisal', 'rox_player', 'lspd'][i]}</b></div><div style="height:220px;background:${g.bg};margin:8px 0"></div><div class="acts2" style="padding:0 11px 10px;margin:0"><span><i class="fa-solid fa-heart"></i> ${120 + i * 31}</span><span><i class="fa-solid fa-comment"></i> ${i * 4 + 2}</span></div></div>`).join('')}</div>`; bind(PH(), { hb: () => openApp('camera', 'Camera', $('hb')) }); });


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
      <button class="golive" id="wd" ${st.earn ? '' : 'disabled style="opacity:.4"'}><i class="fa-solid fa-building-columns"></i> WITHDRAW $${st.earn.toLocaleString('en-US')} TO BANK</button><button class="go2" style="margin-top:8px;background:rgba(255,255,255,.08)" id="sd">DONE</button></div>`);
    $('wd').onclick = () => { if (!st.earn) return; BANK.bank += st.earn; BANK.tx.unshift(['in', 'Clips LIVE earnings', st.earn, 'NOW', 'tower-broadcast']); toast2(`$${st.earn.toLocaleString('en-US')} added to your bank`); st.earn = 0; $('sum').remove(); };
    $('sd').onclick = () => $('sum').remove(); }
  return { setup, start, watch: (host, n) => start(host, LIVES[n].t, false, LIVES[n].u) };
})();
