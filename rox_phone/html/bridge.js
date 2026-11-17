/* ROX Store | rox_phone | All rights reserved. Game bridge (only active inside FiveM). */
const post2 = (n, d = {}) => fetch(`https://${window.GetParentResourceName ? GetParentResourceName() : 'rox_phone'}/${n}`, { method: 'POST', body: JSON.stringify(d) }).then(r => r.json()).catch(() => null);
if (window.invokeNative) {
  document.body.classList.remove('preview'); $('pos').classList.add('hide');
  const applyMe = (m) => { if (!m) return; ME.name = m.name || ME.name; ME.number = m.number || ME.number; ME.job = m.job; ME.jobLabel = m.jobLabel; ME.grade = m.grade;
    BANK.bank = m.bank; BANK.cash = m.cash; const n = document.getElementById('mynum'); if (n) n.innerHTML = `<i class="fa-solid fa-phone"></i>${ME.number}`; };
  window.addEventListener('message', (e) => { const d = e.data || {};
    if (d.action === 'open') { applyMe(d.me); $('pos').classList.toggle('hide', !d.open); if (!d.open) { closeApp(); } }
    if (d.action === 'me') applyMe(d.me); });
  document.addEventListener('keydown', (e) => { if (e.key !== 'Escape' || $('pos').classList.contains('hide')) return; if (!$('av').classList.contains('on')) post2('close'); });
  const _setMode = setMode; setMode = function (n) { _setMode(n); post2('fold', { mode: n }); };
}
