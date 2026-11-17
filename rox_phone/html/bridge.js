/* ROX Store | rox_phone | All rights reserved. Game bridge: real data in FiveM, demo data only in the browser preview. */
const post2 = (n, d = {}) => fetch(`https://${window.GetParentResourceName ? GetParentResourceName() : 'rox_phone'}/${n}`, { method: 'POST', body: JSON.stringify(d) }).then(r => r.json()).catch(() => null);
const GAME = !!window.invokeNative;
const dig = (s) => String(s || '').replace(/\D/g, '');
const fmtPhone = (s) => { const d = dig(s); return d.length === 10 ? `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}` : d.length === 7 ? `${d.slice(0, 3)}-${d.slice(3)}` : (s || ''); };
const nameFor = (num) => { const c = CONTACTS.find(x => dig(x[1]) === dig(num)); return c ? c[0] : fmtPhone(num); };
const hhmm = (at) => { const d = new Date(at * 1000), n = new Date(); return d.toDateString() === n.toDateString() ? d.toTimeString().slice(0, 5) : d.toLocaleDateString('en-US', { weekday: 'short' }); };
const ago = (at) => { const m = (Date.now() / 1000 - at) / 60 | 0; return m < 1 ? 'now' : m < 60 ? m + 'm' : m < 1440 ? (m / 60 | 0) + 'h' : (m / 1440 | 0) + 'd'; };

const RX = {
  me: {}, rpc: (name, args) => GAME ? post2('rpc', { name, args }) : Promise.resolve(null), post: (n, d) => GAME ? post2(n, d) : Promise.resolve(null),
  msg: (t, body, kind) => { if (GAME && t.num) RX.rpc('sendMessage', { to: t.num, body, kind }); },
  read: (t) => { if (GAME && t.num) RX.rpc('readThread', { with: t.num }); RX.badges(); },
  call: (num) => RX.rpc('call', { number: num }), answer: (id) => RX.rpc('answer', { id }), hang: (id) => RX.rpc('hang', { id }),
  photo: () => post2('photo'), where: () => GAME ? post2('whereami') : Promise.resolve({ street: 'Mission Row' }),
  saveSettings: () => {}, msgRedraw: () => {}, msgCur: () => null, svcRedraw: () => {},
  mapTweet: (t) => ({ id: t.id, n: t.name, h: t.handle, t: t.body || '', img: t.img, l: t.likes || 0, r: 0, rt: 0, ago: ago(t.at), lkd: !!t.liked }),
  mapPost: (p) => ({ id: p.id, u: p.user, loc: p.loc || '', img: p.img, c: p.caption || '', l: p.likes || 0, cm: (p.comments || []).map(c => [c.user, c.body]), t: ago(p.at).toUpperCase() + ' AGO', liked: !!p.liked }),
  applyCrypto: (w) => { if (!w) return; CW.code = w.code || CW.code; CW.coins.forEach(c => c.h = +(w.h && w.h[c.s] || 0)); CW.tx = (w.tx || []).map(([k, s, a, l, at]) => [k, s, a, l, ago(at)]); },
  badges: () => {},
};

if (GAME) {
  document.body.classList.remove('preview'); $('pos').classList.add('hide');
  // ---- remove every demo item ----
  const DEMO_APPS = ['mail', 'doj', 'racing', 'houses', 'crew', 'pigeon', 'vibe', 'drop', 'music'];
  for (let i = CATALOG.length - 1; i >= 0; i--) { if (DEMO_APPS.includes(CATALOG[i][1])) CATALOG.splice(i, 1); else CATALOG[i][5] = undefined; }
  INSTALLED = INSTALLED.filter(a => !DEMO_APPS.includes(a));
  [CONTACTS, LOG, THREADS, TW, NOTES, GALLERY, CLIPS, COMMENTS, LIVES, BANK.tx, BANK.bills, CW.tx, PLACES, NEARBY].forEach(a => a.length = 0);
  STARRED.clear(); IG.posts.length = 0; IG.stories.length = 0; IG.acc = null; CW.wallets = {};
  Object.assign(WALLET, { bal: 0, total: 0, gifts: 0, lives: [], hist: [] }); Object.values(SVC2).forEach(d => { d.alerts = []; d.duty = 0; });
  DOCK.forEach(d => d[2] = undefined);
  const W = document.querySelectorAll('.home .w'); if (W[1]) W[1].remove();
  RX.badges = () => { const un = THREADS.reduce((a, t) => a + (t.u || 0), 0); const m = DOCK.find(d => d[1] === 'messages'); if (m) m[2] = un || undefined;
    const al = (SVC2.lspd.alerts.length + SVC2.ems.alerts.length) || undefined; CATALOG.forEach(c => { if (c[1] === (ME.job === 'police' ? 'lspd' : 'ems')) c[5] = al; });
    const w = document.querySelector('.home .w.n'); if (w) { const last = THREADS.filter(t => t.u).slice(0, 2);
      w.innerHTML = `<h5><i class="fa-solid fa-bell"></i>Notifications${un ? `<em>${un}</em>` : ''}</h5>` + (last.length ? last.map(t => `<div class="nt"><i style="background:#2f7cf6"><i class="fa-solid fa-comment"></i></i><div><b>${t.n}</b><span>${String(t.m[t.m.length - 1][0]).slice(0, 40)}</span></div></div>`).join('') : '<div class="nt"><div><span>No new notifications</span></div></div>'); }
    drawApps(); };

  const applyMe = (m) => { if (!m) return; RX.me = m; ME.name = m.name || ME.name; ME.number = fmtPhone(m.number) || ME.number; ME.job = m.job; ME.jobLabel = m.jobLabel; ME.grade = m.grade;
    BANK.bank = m.bank; BANK.cash = m.cash; const n = $('mynum'); if (n) n.innerHTML = `<i class="fa-solid fa-phone"></i>${ME.number}`;
    const w = document.querySelectorAll('.home .w'); const sim = [...w].find(x => x.querySelector('.fa-sim-card')); if (sim) sim.querySelector('b').textContent = ME.number; };
  const threadFor = (num) => { let t = THREADS.find(x => dig(x.num) === dig(num)); if (!t) { t = { n: nameFor(num), num: dig(num), m: [], u: 0 }; THREADS.unshift(t); } return t; };
  const msgBody = (b, k) => k === 'img' ? `url('${b}') center/cover` : k === 'loc' ? String(b).split('|')[0] : b;
  const svcApply = (s) => { if (!s) return; SVC2.lspd.duty = s.counts.police || 0; SVC2.ems.duty = s.counts.ambulance || 0;
    const k = ME.job === 'police' ? 'lspd' : ME.job === 'ambulance' ? 'ems' : null;
    if (k) { const D = SVC2[k]; D.st = { duty: s.duty, dnd: s.dnd, snd: (D.st || {}).snd !== false }; D.alerts = (s.alerts || []).map(a => [a.reason, a.street || 'Unknown', Math.max(0, (Date.now() / 1000 - a.at) / 60 | 0), '#ff4d4d', k === 'lspd' ? '10-00' : 'CODE 3', 0, a.x, a.y]); }
    RX.svcRedraw(); RX.badges(); };

  let loaded = false;
  async function load() {
    const d = await RX.rpc('init'); if (!d) return; loaded = true; const me = dig(d.me);
    (d.contacts || []).forEach(c => { CONTACTS.push([c.n, c.p]); if (c.s) STARRED.add(c.n); });
    // messages -> threads
    [...(d.messages || [])].reverse().forEach(m => { const mine = dig(m.sender) === me; const t = threadFor(mine ? m.receiver : m.sender);
      t.m.push([msgBody(m.body, m.kind), mine ? 1 : 0, hhmm(m.at), m.kind === 'text' || m.kind === 'ct' ? undefined : m.kind]); t.last = m.at; if (!mine && !m.seen) t.u = (t.u || 0) + 1; });
    THREADS.sort((a, b) => (b.last || 0) - (a.last || 0));
    (d.calls || []).forEach(c => { const out = dig(c.caller) === me; LOG.push([hhmm(c.at), out ? 'out' : c.status === 'answered' ? 'in' : c.status === 'declined' ? 'decl' : 'miss', nameFor(out ? c.callee : c.caller), c.duration || 0]); });
    (d.tweets || []).forEach(t => TW.push(RX.mapTweet(t)));
    if (d.ig) IG.acc = { user: d.ig.user, name: d.ig.name, bio: d.ig.bio, followers: 0, following: 0 };
    (d.igPosts || []).forEach(p => IG.posts.push(RX.mapPost(p)));
    (d.gallery || []).forEach(g => GALLERY.push({ id: g.id, url: g.url, bg: `url('${g.url}') center/cover` }));
    (d.bank || []).forEach(b => BANK.tx.push([b.kind, b.label, b.amount, ago(b.at).toUpperCase(), /crypto|Bought|Sold/.test(b.label) ? 'bitcoin-sign' : /Gift/.test(b.label) ? 'gift' : /Clips/.test(b.label) ? 'coins' : b.kind === 'in' ? 'arrow-down' : 'paper-plane']));
    CW.coins.length = 0; (d.prices || []).forEach(c => CW.coins.push({ s: c.s, n: c.n, p: c.p, c: 0, h: 0, col: c.col })); RX.applyCrypto(d.crypto);
    const pr = await RX.rpc('prices'); (pr || []).forEach(p => { const c = CW.coins.find(x => x.s === p.s); if (c) { c.p = Math.round(p.p * 100) / 100; c.c = +((p.p / p.base - 1) * 100).toFixed(1); } });
    Object.assign(WALLET, d.wallet || {}); WALLET.hist = (WALLET.hist || []).map(h => Array.isArray(h) ? h : [h[1], h[2]]);
    (d.clips || []).forEach(c => CLIPS.push({ id: c.id, u: c.user, c: c.caption || '', s: 'original sound · ' + c.user, l: c.likes || 0, cm: 0, bg: `url('${c.img}') center/cover`, ic: 'play', liked: !!c.liked }));
    (d.lives || []).forEach(l => LIVES.push({ u: l.user, t: l.title, v: l.viewers, bg: SCENES[0], host: l.host }));
    (d.notes || []).forEach(n => NOTES.push(n));
    const pl = await post2('places'); (pl || []).forEach(p => PLACES.push([p.label, Math.min(95, Math.max(5, (p.x + 4000) / 8500 * 100)), Math.min(95, Math.max(5, (8000 - p.y) / 12000 * 100)), p.icon, p.x, p.y]));
    const gf = await post2('gifts'); if (gf) { GIFTS.length = 0; gf.forEach(g => GIFTS.push([g.e, g.n, g.price])); }
    if (d.settings && Object.keys(d.settings).length) Object.assign(Sett.st, d.settings);
    if (d.apps && d.apps.installed) { INSTALLED = d.apps.installed.filter(a => CATALOG.some(c => c[1] === a)); ORDER = d.apps.order || null; }
    const pf = d.profile || {};
    if (pf.setup) { $('ob')?.remove(); PIN = pf.pin || PIN; ME.email = pf.email; if (pf.wall !== undefined && !(d.settings || {}).wall) Sett.st.wall = pf.wall; try { localStorage.setItem('rox_setup', '1'); } catch (e) {} }
    else Onboard.reset();
    Sett.apply(); svcApply(d.svc); RX.badges(); Phone.render && $('ph') && Phone.render();
    // ---- save changes back to the server ----
    const snap = { c: '', n: '', s: '', a: '' };
    setInterval(() => {
      const c = JSON.stringify(CONTACTS.map(([n, p]) => ({ n, p, s: STARRED.has(n) ? 1 : 0 }))); if (c !== snap.c) { if (snap.c) RX.rpc('save_contacts', JSON.parse(c)); snap.c = c; }
      const n = JSON.stringify(NOTES); if (n !== snap.n) { if (snap.n) RX.rpc('save_notes', NOTES); snap.n = n; }
      const st = { ...Sett.st }; const s = JSON.stringify(st); if (s !== snap.s) { if (snap.s) RX.rpc('save_settings', st); snap.s = s; }
      const a = JSON.stringify({ installed: INSTALLED, order: ORDER }); if (a !== snap.a) { if (snap.a) RX.rpc('save_apps', JSON.parse(a)); snap.a = a; }
    }, 2000);
  }

  window.addEventListener('message', (e) => { const d = e.data || {};
    if (d.action === 'open') { applyMe(d.me); if (d.open && !loaded) load(); $('pos').classList.toggle('hide', !d.open); if (!d.open && !Call.active()) closeApp(); }
    if (d.action === 'me') applyMe(d.me);
    if (d.action === 'shoot') $('pos').style.visibility = d.on ? 'hidden' : '';
    if (d.action !== 'push') return; const t = d.type, x = d.data || {};
    if (t === 'msg') { const th = threadFor(x.sender); th.m.push([msgBody(x.body, x.kind), 0, hhmm(x.at), x.kind === 'text' || x.kind === 'ct' ? undefined : x.kind]); th.last = x.at;
      THREADS.splice(THREADS.indexOf(th), 1); THREADS.unshift(th); if (RX.msgCur() === th) RX.read(th); else th.u = (th.u || 0) + 1; RX.msgRedraw(); RX.badges(); }
    if (t === 'call:incoming') { $('pos').classList.remove('hide'); Call.incoming(x.service ? `${x.name} (${x.service === 'police' ? '911' : '912'})` : nameFor(x.from), fmtPhone(x.from), x.id); }
    if (t === 'call:accepted') Call.accept();
    if (t === 'call:ended') { Call.localEnd(); const out = dig(x.caller) === dig(RX.me.number); LOG.unshift([hhmm(x.at), out ? 'out' : x.status === 'answered' ? 'in' : x.status === 'declined' ? 'decl' : 'miss', nameFor(out ? x.callee : x.caller), x.dur || 0]); if ($('ph') && $('av').dataset.app === 'phone') Phone.render(); }
    if (t === 'tweet') TW.unshift(RX.mapTweet(x));
    if (t === 'igpost') IG.posts.unshift(RX.mapPost(x));
    if (t === 'bank') { BANK.tx.unshift([x.kind, x.label, x.amount, 'NOW', 'arrow-down']); BANK.bank += x.amount; }
    if (t === 'crypto') RX.applyCrypto(x);
    if (t === 'contact') { if (!CONTACTS.some(c => dig(c[1]) === dig(x.number))) CONTACTS.push([x.name, x.number]); toast2(`${x.name} shared their number with you`); }
    if (t === 'svc') svcApply(x);
    if (t === 'alert') { const k = x.job === 'police' ? 'lspd' : 'ems'; SVC2[k].alerts.unshift([x.reason, x.street || 'Unknown', 0, '#ff4d4d', k === 'lspd' ? '10-00' : 'CODE 3', 0, x.x, x.y]); RX.svcRedraw(); RX.badges(); toast2(`${k.toUpperCase()} · ${x.reason}`); }
    if (t === 'lives') { LIVES.length = 0; x.forEach(l => LIVES.push({ u: l.user, t: l.title, v: l.viewers, bg: SCENES[0], host: l.host })); }
    if (t === 'live:viewers') { const s = Live.st(); if (s) { s.v = x; s.peak = Math.max(s.peak, x); s.total = Math.max(s.total, x); } if ($('lv')) $('lv').textContent = x; }
    if (t === 'live:chat') Live.say(x.join ? 'join' : '', x.join ? `${x.user} joined` : `<b>${x.user}</b>${String(x.body).replace(/</g, '&lt;')}`);
    if (t === 'live:heart') { const s = Live.st(); if (s) { s.likes++; if ($('ll')) $('ll').innerHTML = `<i class="fa-solid fa-heart" style="color:#ff2d55"></i>${s.likes}`; } Live.heart(); }
    if (t === 'live:gift') { const g = GIFTS[x.gift - 1]; if (g) Live.gift(x.user, g); }
    if (t === 'live:ended') { if ($('live') && !(Live.st() || {}).me) { $('live').remove(); toast2('The live has ended'); } }
  });
  document.addEventListener('keydown', (e) => { if (e.key !== 'Escape' || $('pos').classList.contains('hide')) return; if (!$('av').classList.contains('on') && !Call.active()) post2('close'); });
  const _setMode = setMode; setMode = function (n) { _setMode(n); post2('fold', { mode: n }); };
}
