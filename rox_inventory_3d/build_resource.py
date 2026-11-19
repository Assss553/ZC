# ROX Store | builds html/index.html (game version) from template.html + bridge.js
import base64, os, re
H = os.path.dirname(os.path.abspath(__file__)); ZC = os.path.dirname(H)
fa = open(ZC + '/rox_radialmenu/html/fa/css/fontawesome.min.css').read() + open(ZC + '/rox_radialmenu/html/fa/css/solid.min.css').read()
def emb(m):
    f = os.path.normpath(os.path.join(ZC + '/rox_radialmenu/html/fa/css', m.group(1).split('?')[0].split('#')[0]))
    return 'url(data:font/woff2;base64,' + base64.b64encode(open(f, 'rb').read()).decode() + ')' if f.endswith('.woff2') and os.path.exists(f) else 'url(data:,)'
fa = re.sub(r'url\(["\']?([^)"\']+)["\']?\)', emb, fa)
h = open(H + '/template.html').read().replace('/*FA*/', fa).replace('"__IMGS__"', '{}').replace('__MANN__', 'mannequin.png')
h = h.replace('</body>', '<script>\n' + open(H + '/bridge.js').read() + '\n</script>\n</body>')
open(H + '/html/index.html', 'w').write(h); print('built html/index.html', len(h) // 1024, 'KB')
