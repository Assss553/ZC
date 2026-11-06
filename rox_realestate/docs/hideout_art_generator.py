import math, random, sys
C, S_ = math.cos(math.radians(30)), math.sin(math.radians(30))

def shade(hexc, f):
    h = hexc.lstrip('#'); r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return '#%02x%02x%02x' % tuple(max(0, min(255, int(v * f))) for v in (r, g, b))

def make(W, D, H, seed, gang, wallA, wallB, brick, graffiti):
    random.seed(seed)
    scale = 560 / (W + D) * 1.5
    ox, oy = 600 + (D - W) * C * scale / 2, 200
    P = lambda x, y, z: (ox + (x - y) * C * scale, oy + (x + y) * S_ * scale - z * scale)
    def poly(pts, fill, stroke='none', sw=0, op=1):
        return f'<polygon points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"/>'
    def box(x, y, z, w, d, h, col, edge='#00000066'):
        return (poly([P(x, y, z + h), P(x + w, y, z + h), P(x + w, y + d, z + h), P(x, y + d, z + h)], shade(col, 1.15), edge, .6) +
                poly([P(x, y + d, z), P(x + w, y + d, z), P(x + w, y + d, z + h), P(x, y + d, z + h)], shade(col, .8), edge, .6) +
                poly([P(x + w, y, z), P(x + w, y + d, z), P(x + w, y + d, z + h), P(x + w, y, z + h)], shade(col, .6), edge, .6))
    g = 'rgb(%d,%d,%d)' % tuple(gang)
    o = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="675" viewBox="0 0 1200 675">',
         f'''<defs><radialGradient id="fire"><stop offset="0" stop-color="#ffd27a" stop-opacity=".95"/><stop offset=".3" stop-color="#ff7a1a" stop-opacity=".45"/><stop offset="1" stop-color="#ff5a00" stop-opacity="0"/></radialGradient>
         <radialGradient id="gang"><stop offset="0" stop-color="{g}" stop-opacity=".55"/><stop offset="1" stop-color="{g}" stop-opacity="0"/></radialGradient>
         <radialGradient id="tv"><stop offset="0" stop-color="#9fd8ff" stop-opacity=".5"/><stop offset="1" stop-color="#9fd8ff" stop-opacity="0"/></radialGradient>
         <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d0c0d"/><stop offset="1" stop-color="#050505"/></linearGradient>
         <linearGradient id="vig" x1="0" y1="0" x2="0" y2="1"><stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".8"/></linearGradient>
         <pattern id="brick" width="26" height="14" patternUnits="userSpaceOnUse"><rect width="26" height="14" fill="{wallA}"/><path d="M0 7h26M13 0v7M0 7v7M26 7v7" stroke="#000" stroke-opacity=".35" stroke-width="1.2"/></pattern>
         <pattern id="plank" width="40" height="9" patternUnits="userSpaceOnUse"><rect width="40" height="9" fill="{wallA}"/><path d="M0 8.5h40" stroke="#000" stroke-opacity=".4"/></pattern></defs>''',
         '<rect width="1200" height="675" fill="url(#bg)"/>']
    fill = 'url(#brick)' if brick else 'url(#plank)'
    o.append(poly([P(0, 0, 0), P(0, D, 0), P(0, D, H), P(0, 0, H)], fill))
    o.append(poly([P(0, 0, 0), P(0, D, 0), P(0, D, H), P(0, 0, H)], '#000', op=.35))
    o.append(poly([P(0, 0, 0), P(W, 0, 0), P(W, 0, H), P(0, 0, H)], fill))
    o.append(poly([P(0, 0, 0), P(W, 0, 0), P(W, 0, H), P(0, 0, H)], '#000', op=.5))
    # peeling patches + water stains on walls
    for _ in range(14):
        x, z = random.uniform(0.5, W - 1), random.uniform(0.5, H - 1)
        w, h = random.uniform(.4, 1.4), random.uniform(.3, 1.2)
        o.append(poly([P(x, 0, z), P(x + w, 0, z + .1), P(x + w, 0, z + h), P(x, 0, z + h * .9)], wallB, op=random.uniform(.25, .55)))
    for _ in range(6):
        y = random.uniform(1, D - 1)
        a, b = P(0, y, H), P(0, y + random.uniform(.2, .6), random.uniform(1, H * .6))
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#2a1c10" stroke-opacity=".5" stroke-width="{random.uniform(3,9):.0f}"/>')
    # boarded windows on right wall
    for wx in [W * .3, W * .68]:
        o.append(poly([P(wx, 0, 1.3), P(wx + 1.8, 0, 1.3), P(wx + 1.8, 0, 2.7), P(wx, 0, 2.7)], '#0b0f14'))
        for k in range(4):
            z = 1.35 + k * .36 + random.uniform(-.05, .05)
            o.append(poly([P(wx - .2, 0.02, z), P(wx + 2.0, 0.02, z + random.uniform(-.25, .25)), P(wx + 2.0, 0.02, z + .22), P(wx - .2, 0.02, z + .22)], random.choice(['#6b4a2b', '#7a5532', '#5c3f24']), '#000', .8))
        sl = P(wx + 0.9, 0, 2.0)
        o.append(f'<line x1="{sl[0]-20:.0f}" y1="{sl[1]-30:.0f}" x2="{sl[0]+60:.0f}" y2="{sl[1]+80:.0f}" stroke="#bcd7ff" stroke-opacity=".07" stroke-width="26"/>')
    # graffiti on the left wall
    gx, gy = P(0, D * .45, H * .55)
    tags = graffiti
    o.append(f'<g transform="translate({gx:.0f},{gy:.0f}) skewY(30)"><text x="0" y="0" font-family="Arial Black,Arial,sans-serif" font-weight="900" font-style="italic" font-size="{scale*2.3:.0f}" fill="{g}" stroke="#000" stroke-width="3" text-anchor="middle" transform="rotate(-6)">{tags[0]}</text>'
             f'<text x="{scale*2.6:.0f}" y="{scale*1.3:.0f}" font-family="Arial Black,Arial,sans-serif" font-weight="900" font-style="italic" font-size="{scale*0.9:.0f}" fill="#f2f2f2" fill-opacity=".8" text-anchor="middle" transform="rotate(4)">{tags[1]}</text>'
             f'<path d="M{-scale*3:.0f} {scale*1.6:.0f} q{scale:.0f} -{scale*.8:.0f} {scale*2:.0f} 0 t{scale*2:.0f} 0" stroke="{g}" stroke-width="5" fill="none" opacity=".7"/></g>')
    gx2, gy2 = P(W * .5, 0, H * .62)
    o.append(f'<g transform="translate({gx2:.0f},{gy2:.0f}) skewY(-30)"><text font-family="Arial Black,Arial,sans-serif" font-weight="900" font-style="italic" font-size="{scale*1.1:.0f}" fill="#f5f5f5" fill-opacity=".55" text-anchor="middle">{tags[2]}</text></g>')
    # floor (dirty concrete / wood)
    o.append(poly([P(0, 0, 0), P(W, 0, 0), P(W, D, 0), P(0, D, 0)], '#2b2724'))
    for i in range(1, int(W * 2)):
        a, b = P(i / 2, 0, 0), P(i / 2, D, 0)
        o.append(f'<line x1="{a[0]:.0f}" y1="{a[1]:.0f}" x2="{b[0]:.0f}" y2="{b[1]:.0f}" stroke="#000" stroke-opacity=".18"/>')
    for _ in range(26):
        x, y = random.uniform(.5, W - .5), random.uniform(.5, D - .5); c = P(x, y, 0)
        col = random.choice(['#120e0b', '#120e0b', '#3a0808'])
        o.append(f'<ellipse cx="{c[0]:.0f}" cy="{c[1]:.0f}" rx="{random.uniform(10,40):.0f}" ry="{random.uniform(4,14):.0f}" fill="{col}" opacity="{random.uniform(.25,.6):.2f}"/>')
    items = []
    add = lambda x, y, svg: items.append((x + y, svg))
    # trash bags + mattress + planks along walls
    for _ in range(int(W * 1.1)):
        x = random.uniform(.6, W - .6); y = random.choice([random.uniform(.3, .9), random.uniform(D - 1.0, D - .4)])
        c = P(x, y, 0); r = scale * random.uniform(.28, .42)
        add(x, y, f'<ellipse cx="{c[0]:.0f}" cy="{c[1]-r*.5:.0f}" rx="{r:.0f}" ry="{r*.75:.0f}" fill="#111214"/><ellipse cx="{c[0]-r*.3:.0f}" cy="{c[1]-r*.8:.0f}" rx="{r*.3:.0f}" ry="{r*.15:.0f}" fill="#fff" opacity=".12"/>')
    add(1.5, D - 2.2, box(1.0, D - 2.6, 0, 2.0, 1.4, .25, '#b8ab8a') + poly([P(1.5, D - 2.3, .26), P(2.4, D - 2.2, .26), P(2.2, D - 1.6, .26), P(1.4, D - 1.8, .26)], '#6d2a1a', op=.6))
    for k in range(3):
        add(W - .5, .9 + k * .5, box(W - .4, .6 + k * .55, 0, .15, .35, 2.2 - k * .2, '#6b4a2b'))
    for k in range(3):
        add(.7 + k * .7, .7, box(.4 + k * .75, .4, 0, .6, .6, .22 + .22 * k, '#1a1a1a') )
    # hangout: couch, crate table w/ bottles, barrel fire, tv on crate, chair
    hx, hy = W * .55, D * .52
    add(hx, hy - 2.2, box(hx - 1.2, hy - 2.4, 0, 2.4, .9, .45, '#5b3d2e') + box(hx - 1.2, hy - 2.4, .45, 2.4, .25, .55, '#4d3326') + box(hx - 1.35, hy - 2.4, 0, .25, .9, .75, '#4d3326') + box(hx + 1.1, hy - 2.4, 0, .25, .9, .75, '#4d3326'))
    add(hx + 1.2, hy - .9, box(hx + .9, hy - 1.2, 0, .8, .8, .55, '#8a6a42'))
    for bx_ in (hx + 1.0, hx + 1.25, hx + 1.45):
        b = P(bx_, hy - .9, .55); add(hx + 1.3, hy - .8, f'<rect x="{b[0]-2:.0f}" y="{b[1]-14:.0f}" width="5" height="14" rx="2" fill="#2f6b2a"/>')
    add(hx, hy, box(hx - .35, hy - .35, 0, .7, .7, 1.0, '#3c3f44'))
    fc = P(hx, hy, 1.05)
    flames = f'<ellipse cx="{fc[0]:.0f}" cy="{fc[1]:.0f}" rx="{scale*.32:.0f}" ry="{scale*.14:.0f}" fill="#ff8a1a"/><path d="M{fc[0]-10:.0f} {fc[1]:.0f} q6 -30 10 -46 q6 22 12 6 q4 20 -4 40z" fill="#ffcf5a"/>'
    add(hx + .1, hy + .1, flames)
    add(hx, hy + 2.3, box(hx - .4, hy + 2.0, 0, .8, .6, .55, '#8a6a42') + box(hx - .35, hy + 2.05, .55, .7, .45, .55, '#1b1b1d'))
    add(hx + 1.8, hy + .6, box(hx + 1.6, hy + .4, 0, .6, .6, .45, '#3a2a20') + box(hx + 1.6, hy + .4, .45, .1, .6, .55, '#3a2a20'))
    # tyres
    for k in range(3):
        c = P(W - 2.2, D - .9, .2 + k * .22)
        add(W - 2.2, D - .9 + k * .01, f'<ellipse cx="{c[0]:.0f}" cy="{c[1]:.0f}" rx="{scale*.42:.0f}" ry="{scale*.22:.0f}" fill="#0d0d0d" stroke="#222" stroke-width="2"/>')
    # drug table (far corner) + gang light
    add(W - 1.8, 1.4, box(W - 2.8, .9, 0, 1.8, .9, .78, '#6b5440') + box(W - 2.5, 1.0, .78, .35, .3, .18, '#e8e4d8') + box(W - 2.0, 1.1, .78, .3, .25, .14, '#4e8a3a') + box(W - 1.5, 1.0, .78, .35, .3, .12, '#2f6b2a'))
    # bottles litter
    for _ in range(int(W * D / 5)):
        x, y = random.uniform(1, W - 1), random.uniform(1, D - 1); c = P(x, y, 0)
        add(x, y, f'<rect x="{c[0]-2:.0f}" y="{c[1]-9:.0f}" width="4" height="9" rx="1.5" fill="{random.choice(["#2f6b2a","#6b3e1f","#cfcfcf","#b22"])}" transform="rotate({random.uniform(-80,80):.0f} {c[0]:.0f} {c[1]:.0f})"/>')
    for _, svg in sorted(items, key=lambda t: t[0]):
        o.append(svg)
    # lights
    o.append(f'<circle cx="{fc[0]:.0f}" cy="{fc[1]-20:.0f}" r="{scale*3.2:.0f}" fill="url(#fire)"/>')
    tl = P(hx, hy + 2.3, .8); o.append(f'<circle cx="{tl[0]:.0f}" cy="{tl[1]:.0f}" r="{scale*1.8:.0f}" fill="url(#tv)"/>')
    dl = P(W - 1.9, 1.3, 2.0); o.append(f'<circle cx="{dl[0]:.0f}" cy="{dl[1]:.0f}" r="{scale*3.5:.0f}" fill="url(#gang)"/>')
    ml = P(W * .4, D * .4, H - .6); o.append(f'<circle cx="{ml[0]:.0f}" cy="{ml[1]:.0f}" r="{scale*5:.0f}" fill="url(#gang)" opacity=".7"/>')
    bl = P(2.0, D * .5, H - .4)
    o.append(f'<line x1="{bl[0]:.0f}" y1="{bl[1]-60:.0f}" x2="{bl[0]:.0f}" y2="{bl[1]:.0f}" stroke="#111" stroke-width="2"/><circle cx="{bl[0]:.0f}" cy="{bl[1]+4:.0f}" r="6" fill="#fff1c4"/><circle cx="{bl[0]:.0f}" cy="{bl[1]+4:.0f}" r="{scale*2:.0f}" fill="url(#fire)" opacity=".45"/>')
    o.append('<rect width="1200" height="675" fill="url(#vig)"/></svg>')
    return '\n'.join(o)

out = sys.argv[1]
V = {
    'rox_hideout_bar':   (18, 12, 5.5, 11, (220, 40, 30), '#6e3b2c', '#a78e7a', True, ('ROX', 'NO RULES', 'BLOOD')),
    'rox_hideout_den':   (20, 13, 6.0, 12, (150, 40, 220), '#4c4540', '#8f8577', True, ('ROX', 'KINGS', 'OG')),
    'rox_hideout_shack': (12, 9, 4.2, 13, (240, 190, 20), '#5b4630', '#8a7357', False, ('ROX', 'SANDY', '420')),
    'rox_hideout_house': (14, 10, 4.6, 14, (40, 200, 70), '#4a4f3e', '#9b9a7c', False, ('ROX', 'GROVE', 'HOOD')),
}
for k, a in V.items():
    open(f'{out}/{k}.svg', 'w').write(make(*a))
print('ok')
