# ROX Store | builds ROX_Inventory_3D.html (single file, all assets embedded)
import base64, io, os, re, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ZC = '/home/user/ZC'
IMG = ZC + '/ox_inventory/web/images/'

def b64(path, size=None):
    im = Image.open(path).convert('RGBA')
    if size: im.thumbnail((size, size))
    buf = io.BytesIO(); im.save(buf, 'PNG')
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()

fa = open(ZC + '/rox_radialmenu/html/fa/css/fontawesome.min.css').read() + open(ZC + '/rox_radialmenu/html/fa/css/solid.min.css').read()
def emb(m):
    f = os.path.normpath(os.path.join(ZC + '/rox_radialmenu/html/fa/css', m.group(1).split('?')[0].split('#')[0]))
    return 'url(data:font/woff2;base64,' + base64.b64encode(open(f, 'rb').read()).decode() + ')' if f.endswith('.woff2') and os.path.exists(f) else 'url(data:,)'
fa = re.sub(r'url\(["\']?([^)"\']+)["\']?\)', emb, fa)

names = ['rox_vest', 'rox_oxygen', 'rox_radio', 'rox_baton', 'rox_taser', 'rox_cuffs', 'rox_ammo', 'rox_idcard', 'rox_box', 'rox_pills',
         'rox_transparency_red', 'rox_transparency_blue', 'rox_transparency_amber', 'WEAPON_PISTOL', 'WEAPON_CARBINERIFLE', 'parachute',
         'phone', 'burger', 'water', 'money', 'lockpick', 'bandage']
imgs = {n: b64(IMG + n + '.png', 200) for n in names}
mann = b64(os.path.join(HERE, 'mannequin.png'))

html = open(os.path.join(HERE, 'template.html')).read()
html = html.replace('/*FA*/', fa).replace('"__IMGS__"', '{' + ','.join('"%s":"%s"' % (k, v) for k, v in imgs.items()) + '}').replace('__MANN__', mann)
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'ROX_Inventory_3D.html')
open(out, 'w').write(html)
print('built', out, len(html) // 1024, 'KB')
