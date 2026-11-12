// node render_street.js <workdir> <outdir> label=x,y,z,tx,ty,tz[,fov] ...
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const W = process.argv[2], OUT = process.argv[3], jobs = process.argv.slice(4);
  const names = JSON.parse(fs.readFileSync(path.join(W, 'street.json'))).map((s) => s.name).join(',');
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
  const srv = http.createServer((q, r) => {
    const p = decodeURIComponent(q.url.split('?')[0]);
    const f = p === '/render_street.html' ? path.join(__dirname, 'render_street.html') : path.join(W, p);
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(d); } });
  }).listen(0);
  const port = srv.address().port;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const pg = await b.newPage({ viewport: { width: 1600, height: 900 } });
  pg.on('pageerror', (e) => console.log('pageerror', e.message));
  for (const j of jobs) {
    const [label, c] = j.split('='); const v = c.split(',');
    await pg.goto(`http://127.0.0.1:${port}/render_street.html?names=${names}&cam=${v.slice(0, 6).join(',')}&fov=${v[6] || 55}`);
    await pg.waitForFunction(() => window.__done, null, { timeout: 300000 });
    const out = path.join(OUT, `street_${label}.png`);
    await pg.screenshot({ path: out }); console.log('rendered', out);
  }
  await b.close(); srv.close();
})();
