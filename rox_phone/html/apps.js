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
      ${tab === 'disc' ? ['#lossantos', '#carmeet', '#lspd', '#foodtok', '#heist'].map((h, n) => `<div class="th"><div class="mono">#</div><div><b>${h}</b><span>${(n + 1) * 37}K videos</span></div><div class="r">${n + 1}</div></div>`).join('')
        : COMMENTS.map(([u, t]) => `<div class="th"><div class="mono">${u[0].toUpperCase()}</div><div><b>${u}</b><span>commented: ${t}</span></div><div class="r">${2 + u.length}m</div></div>`).join('')}</div></div>${nav()}`;
    bind(el, { t: (t) => { if (t === 'plus') { closeApp(); return setTimeout(() => openApp('camera', 'Camera', $('hb')), 300); } tab = t; draw(); },
      like: (n) => { const c = CLIPS[n]; c.liked = !c.liked; c.l += c.liked ? 1 : -1; draw(); }, sv: (n) => { CLIPS[n].sv = !CLIPS[n].sv; draw(); toast2(CLIPS[n].sv ? 'Saved' : 'Removed'); },
      share: () => toast2('Link copied'), cm: (n) => { el.insertAdjacentHTML('beforeend', `<div class="sheet" id="sht"><h4>${k(CLIPS[n].cm)} comments<i class="fa-solid fa-xmark" data-cx></i></h4><div class="cl2" id="cl2">${COMMENTS.map(([u, t]) => `<div class="cm"><div class="mono" style="width:30px;height:30px;border-radius:50%">${u[0].toUpperCase()}</div><div><b>${u}</b>${t}</div></div>`).join('')}</div><div class="comp2"><input id="ci" placeholder="Add comment…"><button id="cs"><i class="fa-solid fa-paper-plane"></i></button></div></div>`);
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
