// node render_thumbs.js <workdir> <outdir> <prefix>   -> small jpg thumbnail per model (shop pictures)
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
(async () => {
  const W = process.argv[2], OUT = process.argv[3], prefix = process.argv[4];
  const names = fs.readdirSync(path.join(W, 'preview')).filter((f) => f.startsWith(prefix) && f.endsWith('.json')).map((f) => f.slice(0, -5));
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
  const srv = http.createServer((q, r) => {
    const p = decodeURIComponent(q.url.split('?')[0]);
    const f = p === '/render.html' ? path.join(__dirname, 'render.html') : path.join(W, p);
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'max-age=3600' }); r.end(d); } });
  }).listen(0);
  const port = srv.address().port;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const N = 6; let i = 0, done = 0;
  await Promise.all([...Array(N)].map(async () => {
    const pg = await b.newPage({ viewport: { width: 320, height: 240 } });
    while (i < names.length) {
      const name = names[i++];
      await pg.goto(`http://127.0.0.1:${port}/render.html?name=${name}&view=iso&w=320&h=240&az=35&el=28&bg=eef0f2`);
      await pg.waitForFunction(() => window.__done, null, { timeout: 120000 });
      await pg.screenshot({ path: path.join(OUT, name + '.jpg'), type: 'jpeg', quality: 82 }); done++;
    }
  }));
  console.log('thumbnails', done);
  await b.close(); srv.close();
})();
