// node render.js <workdir> <outdir> name[:view[:query]] ...
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const W = process.argv[2], OUT = process.argv[3], jobs = process.argv.slice(4);
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
  const srv = http.createServer((q, r) => {
    let p = decodeURIComponent(q.url.split('?')[0]);
    let f = p === '/render.html' ? path.join(__dirname, 'render.html') : path.join(W, p);
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(d); } });
  }).listen(0);
  const port = srv.address().port;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const pg = await b.newPage({ viewport: { width: 1600, height: 900 } });
  pg.on('pageerror', (e) => console.log('pageerror', e.message));
  for (const j of jobs) {
    const [name, view = 'iso', q = ''] = j.split(':');
    await pg.goto(`http://127.0.0.1:${port}/render.html?name=${name}&view=${view}&${q}`);
    await pg.waitForFunction(() => window.__done, null, { timeout: 180000 });
    const out = path.join(OUT, `${name}${view === 'iso' ? '' : '_' + view}${q ? '_' + q.replace(/[^a-z0-9]+/gi, '') : ''}.png`);
    await pg.screenshot({ path: out }); console.log('rendered', out);
  }
  await b.close(); srv.close();
})();
