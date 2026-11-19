/* ROX Store | live bridge: turns the 3D design into the real inventory (ox_inventory via rox_inventory_3d) */
(function () {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
  if (!RES) return;                                   // browser preview keeps the demo data
  const post = (n, d = {}) => fetch(`https://${RES}/${n}`, { method: 'POST', body: JSON.stringify(d) }).then(r => r.json()).catch(() => ({}));
  document.body.style.display = 'none';
  let L = null, IMG = '';
  const EQ = ['primary', 'secondary', 'vest', 'bag', 'head'];
  const slotOf = (list, i) => list === 'hot' ? L.hot[i] : list === 'pockets' ? L.pockets[0] + i : EQ.includes(list) ? L[list] : null;
  const guessEq = (n) => n.startsWith('WEAPON_') ? (/RIFLE|CARBINE|SHOTGUN|SNIPER|MG|RPG|LAUNCHER|MINIGUN|MUSKET|GUSENBERG/.test(n.slice(7)) ? 'primary' : 'secondary') : null;

  function load(st) {
    for (const k in D) delete D[k];
    for (const [n, d] of Object.entries(st.defs || {})) D[n] = { l: d.l, w: d.w, d: d.d, r: 'common', eq: guessEq(n) };
    const n = L.pockets[1] - L.pockets[0] + 1;
    S.pockets = Array(n).fill(null); S.hot = Array(5).fill(null); S.ground = Array(10).fill(null);
    EQ.forEach(e => S[e] = [null]);
    for (const it of st.items || []) {
      const key = it.name + (it.label ? '#' + it.slot : '');
      if (it.label) D[key] = Object.assign({}, D[it.name], { l: it.label });
      if (it.rarity && D[key]) D[key].r = it.rarity;
      IMGS[key] = it.image ? IMG + it.image + '.png' : IMG + it.name + '.png';
      const v = [key, it.count, it.durability != null ? Math.round(it.durability) : null];
      const h = L.hot.indexOf(it.slot);
      if (h >= 0) S.hot[h] = v;
      else if (it.slot >= L.pockets[0] && it.slot <= L.pockets[1]) S.pockets[it.slot - L.pockets[0]] = v;
      else for (const e of EQ) if (L[e] === it.slot) S[e][0] = v;
    }
    if (sel && !S[sel.l][sel.i]) sel = null;
    render();
  }

  const realSlot = () => sel && slotOf(sel.l, sel.i);
  window.act = function (a) {
    const it = sel && S[sel.l][sel.i]; if (!it) return;
    const n = Math.max(1, Math.min(it[1], +((document.getElementById('amt') || {}).value) || 1));
    if (a === 'use') post('use', { slot: realSlot() });
    else if (a === 'drop') post('drop', { slot: realSlot(), count: n });
    else if (a === 'give') post('give', { slot: realSlot(), count: n });
  };

  const _bind = window.bind;
  window.bind = function () {
    _bind();
    document.querySelectorAll('.slot').forEach(s => {
      const l = s.dataset.l, i = +s.dataset.i;
      s.ondrop = (e) => {
        e.preventDefault(); s.classList.remove('over'); if (!drag) return;
        if (l === 'ground') { const from = slotOf(drag.l, drag.i); const it = S[drag.l][drag.i]; post('drop', { slot: from, count: it ? it[1] : 1 }); return }
        const from = slotOf(drag.l, drag.i), to = slotOf(l, i);
        if (from && to && from !== to) { sel = { l, i }; post('move', { from, to, split: drag.split }) }
      };
    });
  };

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
      L = d.layout; IMG = d.imagepath;
      const p = d.player || {};
      const nm = document.querySelector('.name');
      if (nm) nm.innerHTML = `<b>${(p.name || '').trim() || 'CITIZEN'}</b><span>${p.cid || ''}</span>`;
      const chips = document.querySelectorAll('.top .chip span, .top .chip');
      const top = document.querySelector('.top');
      if (top) top.innerHTML = `<div class="chip money"><i class="fa-solid fa-sack-dollar"></i><span>$ ${(p.cash || 0).toLocaleString('en-US')}</span></div><div class="chip"><i class="fa-solid fa-id-badge"></i>ID ${p.id || ''}</div>${p.job ? `<div class="chip"><i class="fa-solid fa-briefcase"></i>${p.job}</div>` : ''}`;
      document.body.style.display = '';
      sel = null; load(d.state); setTimeout(links, 200);
    }
    if (d.action === 'state') { load(d.state); if (d.msg) toast(d.msg) }
    if (d.action === 'close') document.body.style.display = 'none';
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && document.body.style.display !== 'none') { document.body.style.display = 'none'; post('close') } });
})();
