import math, random, sys
C, S_ = math.cos(math.radians(30)), math.sin(math.radians(30))

def make(variant, W, D, H, seed, title):
    random.seed(seed)
    scale = 560 / (W + D) * 1.55
    ox, oy = 600 + (D - W) * C * scale / 2, 185
    def P(x, y, z):
        return (ox + (x - y) * C * scale, oy + (x + y) * S_ * scale - z * scale)
    def poly(pts, fill, stroke='none', sw=0, op=1, extra=''):
        return f'<polygon points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in pts)}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}" {extra}/>'
    def shade(hexc, f):
        h = hexc.lstrip('#'); r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        return '#%02x%02x%02x' % tuple(max(0, min(255, int(v * f))) for v in (r, g, b))
    items = []  # (depth, svg)
    def box(x, y, z, w, d, h, col, top=None, edge='#00000055'):
        t = top or shade(col, 1.18)
        s = ''
        s += poly([P(x, y, z + h), P(x + w, y, z + h), P(x + w, y + d, z + h), P(x, y + d, z + h)], t, edge, 0.6)
        s += poly([P(x, y + d, z), P(x + w, y + d, z), P(x + w, y + d, z + h), P(x, y + d, z + h)], shade(col, 0.82), edge, 0.6)
        s += poly([P(x + w, y, z), P(x + w, y + d, z), P(x + w, y + d, z + h), P(x + w, y, z + h)], shade(col, 0.62), edge, 0.6)
        return s
    def add(x, y, depthz, svg): items.append((x + y + depthz * 0.001, svg))

    out = []
    out.append('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="675" viewBox="0 0 1200 675">')
    out.append('''<defs>
      <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#16171b"/><stop offset="1" stop-color="#0a0a0c"/></linearGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5d6066"/><stop offset="1" stop-color="#3a3c41"/></linearGradient>
      <linearGradient id="wallL" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c3037"/><stop offset="1" stop-color="#40454d"/></linearGradient>
      <linearGradient id="wallR" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#23262c"/><stop offset="1" stop-color="#353940"/></linearGradient>
      <radialGradient id="glow"><stop offset="0" stop-color="#fff3d6" stop-opacity=".95"/><stop offset=".25" stop-color="#ffd9a0" stop-opacity=".35"/><stop offset="1" stop-color="#ffb070" stop-opacity="0"/></radialGradient>
      <linearGradient id="cone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe9c4" stop-opacity=".22"/><stop offset="1" stop-color="#ffe9c4" stop-opacity="0"/></linearGradient>
      <linearGradient id="vig" x1="0" y1="0" x2="0" y2="1"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".75"/></linearGradient>
      <pattern id="haz" width="14" height="14" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="7" height="14" fill="#f2b705"/><rect x="7" width="7" height="14" fill="#1b1b1b"/></pattern>
    </defs>''')
    out.append('<rect width="1200" height="675" fill="url(#bg)"/>')
    # walls
    out.append(poly([P(0, 0, 0), P(0, D, 0), P(0, D, H), P(0, 0, H)], 'url(#wallL)'))
    out.append(poly([P(0, 0, 0), P(W, 0, 0), P(W, 0, H), P(0, 0, H)], 'url(#wallR)'))
    for i in range(1, int(W * 2)):  # corrugation
        x = i * 0.5
        a, b = P(x, 0, 0.2), P(x, 0, H)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#ffffff" stroke-opacity="{0.05 if i % 2 else 0.02}" stroke-width="1"/>')
    for i in range(1, int(D * 2)):
        y = i * 0.5
        a, b = P(0, y, 0.2), P(0, y, H)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#ffffff" stroke-opacity="{0.05 if i % 2 else 0.02}" stroke-width="1"/>')
    # wall trim + orange safety band
    out.append(poly([P(0, 0, 1.0), P(W, 0, 1.0), P(W, 0, 1.25), P(0, 0, 1.25)], '#ff5a1f', op=.85))
    out.append(poly([P(0, 0, 1.0), P(0, D, 1.0), P(0, D, 1.25), P(0, 0, 1.25)], '#e04a14', op=.85))
    # roller doors on the right wall
    for dx in ([W * 0.55, W * 0.78] if W > 16 else [W * 0.62]):
        out.append(poly([P(dx, 0, 0), P(dx + 3.4, 0, 0), P(dx + 3.4, 0, 4.2), P(dx, 0, 4.2)], '#4a4f58', '#000', 1))
        for k in range(1, 14):
            a, b = P(dx, 0, k * 0.3), P(dx + 3.4, 0, k * 0.3)
            out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#000" stroke-opacity=".35"/>')
        out.append(poly([P(dx - 0.25, 0, 0), P(dx, 0, 0), P(dx, 0, 4.4), P(dx - 0.25, 0, 4.4)], 'url(#haz)'))
        out.append(poly([P(dx + 3.4, 0, 0), P(dx + 3.65, 0, 0), P(dx + 3.65, 0, 4.4), P(dx + 3.4, 0, 4.4)], 'url(#haz)'))
        g = P(dx + 1.7, 0, 4.8)
        out.append(f'<circle cx="{g[0]:.1f}" cy="{g[1]:.1f}" r="4" fill="#5cff7a"/><circle cx="{g[0]:.1f}" cy="{g[1]:.1f}" r="14" fill="#5cff7a" opacity=".18"/>')
    # ROX logo on left wall (skewed text)
    lx, ly = P(0, D * 0.42, H * 0.62)
    out.append(f'<g transform="translate({lx:.1f},{ly:.1f}) skewY(30)"><text x="0" y="0" font-family="Arial Black,Arial" font-weight="900" font-size="{scale*2.2:.0f}" fill="#ff5a1f" text-anchor="middle" letter-spacing="4">ROX</text>'
               f'<text x="0" y="{scale*0.75:.0f}" font-family="Arial" font-weight="700" font-size="{scale*0.42:.0f}" fill="#d7d7dc" text-anchor="middle" letter-spacing="6">LOGISTICS</text></g>')
    # floor
    out.append(poly([P(0, 0, 0), P(W, 0, 0), P(W, D, 0), P(0, D, 0)], 'url(#floor)'))
    for i in range(1, int(W)):
        a, b = P(i, 0, 0), P(i, D, 0)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#000" stroke-opacity=".08"/>')
    for j in range(1, int(D)):
        a, b = P(0, j, 0), P(W, j, 0)
        out.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#000" stroke-opacity=".08"/>')
    # reflections / stains
    for _ in range(18):
        x, y = random.uniform(1, W - 1), random.uniform(1, D - 1)
        c = P(x, y, 0)
        out.append(f'<ellipse cx="{c[0]:.1f}" cy="{c[1]:.1f}" rx="{random.uniform(8,28):.0f}" ry="{random.uniform(3,9):.0f}" fill="#000" opacity="{random.uniform(.04,.1):.2f}"/>')
    # yellow aisle lines + dock hazard zone
    def lane(y0):
        out.append(poly([P(0.6, y0, 0.01), P(W - 0.6, y0, 0.01), P(W - 0.6, y0 + 0.12, 0.01), P(0.6, y0 + 0.12, 0.01)], '#f2c200', op=.9))
    dockX = W * 0.74
    if not variant.startswith('empty'):
        out.append(poly([P(dockX, 0.4, 0.01), P(dockX + 0.5, 0.4, 0.01), P(dockX + 0.5, D - 0.4, 0.01), P(dockX, D - 0.4, 0.01)], 'url(#haz)', op=.9))
    # racks
    rackRows = []
    y = 0.6
    while y + 1.1 < D - 4.0:
        rackRows.append(y); y += 1.1 + (2.6 if variant != 'vehicle' else 4.0)
    def rack(x, y0, L, levels=3):
        s = ''
        dep = 1.1
        for lv in range(levels):
            z = lv * 1.25
            s += box(x, y0, z + 0.05, L, dep, 0.09, '#ff6a2a')  # beam
            # goods
            gx = x + 0.08
            while gx < x + L - 0.4:
                gw = random.uniform(0.55, 0.95)
                if gx + gw > x + L - 0.05: break
                if random.random() < 0.88:
                    gh = random.uniform(0.55, 1.0)
                    col = random.choice(['#b88655', '#c99a63', '#a6764a', '#7d8ea3', '#d8d2c4', '#5f7f64'])
                    s += box(gx, y0 + 0.08, z + 0.14, gw, dep - 0.16, gh, col)
                gx += gw + 0.06
        for px in (x, x + L / 2, x + L - 0.1):
            s += box(px, y0, 0, 0.1, 0.1, levels * 1.25 + 0.2, '#2f6fd6')
            s += box(px, y0 + dep - 0.1, 0, 0.1, 0.1, levels * 1.25 + 0.2, '#2f6fd6')
        return s
    EMPTY = variant.startswith('empty')
    def flat(pts, fill, op=1):
        out.append(poly([P(x, y, 0.012) for x, y in pts], fill, op=op))
    def fline(x0, y0, x1, y1, w, col, op=.95):
        dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy); nx, ny = -dy / L * w / 2, dx / L * w / 2
        flat([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], col, op)
    def frect(x0, y0, x1, y1, w, col, op=.95):
        fline(x0, y0, x1, y0, w, col, op); fline(x1, y0, x1, y1, w, col, op); fline(x1, y1, x0, y1, w, col, op); fline(x0, y1, x0, y0, w, col, op)
    if EMPTY:
        m = 0.9
        frect(m, m, W - m, D - m, 0.12, '#f2c200'); frect(m + 0.9, m + 0.9, W - m - 0.9, D - m - 0.9, 0.08, '#f2c200')
        c = D / 2; lw = min(4.0, D * 0.28)
        fline(4.5, c - lw / 2, W - 1.8, c - lw / 2, 0.14, '#f2c200'); fline(4.5, c + lw / 2, W - 1.8, c + lw / 2, 0.14, '#f2c200')
        u = 5.0
        while u < W - 3.5:
            fline(u, c - 0.45, u + 1.4, c, 0.12, '#e8e8e8'); fline(u + 1.4, c, u, c + 0.45, 0.12, '#e8e8e8'); u += 3.0
        bayD = (D - lw) / 2 - m - 1.3; bayL = max(2.4, min(3.6, bayD * 0.9)); u = 5.0
        n = 1
        while u + bayL < W - m - 1.2:
            for (y0, y1) in ((m + 1.15, m + 1.15 + bayD), (D - m - 1.15 - bayD, D - m - 1.15)):
                frect(u, y0, u + bayL, y1, 0.08, '#e9e9e9', .85)
                tp = P(u + bayL / 2, (y0 + y1) / 2, 0.02)
                out.append(f'<text x="{tp[0]:.1f}" y="{tp[1]:.1f}" font-family="Arial" font-weight="800" font-size="{scale*0.42:.0f}" fill="#ffffff" fill-opacity=".35" text-anchor="middle" transform="rotate(0)">{"A" if y0 < c else "B"}{n:02d}</text>')
            u += bayL + 0.25; n += 1
        y = m + 0.9
        while y < D - m - 1.4:
            flat([(1.2, y), (1.8, y + 0.25), (1.8, y + 0.5), (1.2, y + 0.25)], '#f2c200')
            flat([(1.2, y + 0.25), (1.8, y + 0.5), (1.8, y + 0.75), (1.2, y + 0.5)], '#151515')
            y += 0.5
        frect(0.2, c - 1.4, 2.6, c + 1.4, 0.1, '#d23a2a'); fline(0.4, c - 1.2, 2.4, c + 1.2, 0.08, '#d23a2a'); fline(0.4, c + 1.2, 2.4, c - 1.2, 0.08, '#d23a2a')
        frect(W - m - 4.2, c - lw / 2 + 0.3, W - m - 1.1, c + lw / 2 - 0.3, 0.12, '#2fbf6a')
        # wall details: right wall (y=0) and left wall (x=0)
        def wallbox_r(x, z, w, h, col, depth=0.25):
            add(x, 0, 5, box(x, 0, z, w, depth, h, col))
        def wallbox_l(y, z, w, h, col, depth=0.25):
            add(0, y, 5, box(0, y, z, depth, w, h, col))
        for k, x in enumerate([2.0, 3.1]):
            wallbox_r(x, 0.9, 0.8, 1.0, '#7d828b'); wallbox_r(x + 0.15, 1.4, 0.5, 0.06, '#f2c200', 0.27)
        add(0, 2, 5, box(0, 2.2, 0, 0.18, 0.18, H - 1.4, '#c62828'))
        wallbox_l(3.4, 1.0, 0.8, 0.8, '#b71c1c')
        for x in [6 + i * 8 for i in range(int((W - 6) / 8) + 1)]:
            if x > W - 2: break
            wallbox_r(x + 1.0, 0.0, 0.3, 0.55, '#d32f2f', 0.3)
            wallbox_r(x + 1.0, 1.5, 0.2, 0.2, '#ff3b30', 0.1)
            wallbox_r(x, H - 1.6, 0.6, 0.25, '#fff1cc', 0.12)
            wallbox_r(x + 2.0, H - 2.6, 1.2, 0.8, '#5c626b', 0.2)
        for y in [D * 0.3, D * 0.7]:
            wallbox_l(y, H - 2.4, 1.4, 0.9, '#5c626b', 0.2)
        # pipes along the ceiling edge of both walls
        out.append(poly([P(0, 0.05, H - 0.9), P(W, 0.05, H - 0.9), P(W, 0.05, H - 0.75), P(0, 0.05, H - 0.75)], '#8c939c'))
        out.append(poly([P(0.05, 0, H - 1.2), P(0.05, D, H - 1.2), P(0.05, D, H - 1.05), P(0.05, 0, H - 1.05)], '#2b6fd6'))
        # cleaning corner, bins
        add(0.8, D - 1.0, 5, box(0.9, D - 1.4, 0, 0.5, 0.5, 0.5, '#f2c200'))
        add(W - 1.4, 0.9, 5, box(W - 1.6, 0.8, 0, 0.6, 0.6, 0.9, '#2e7d32'))
    if EMPTY:
        pass
    elif variant != 'vehicle':
        for ry in rackRows:
            x = 5.5
            while x + 3.2 < dockX - 0.8:
                if abs(x - (5.5 + dockX) / 2) < 1.5: x += 2.6; continue
                add(x, ry, 1, rack(x, ry, 3.0, 3 if H > 7 else 2))
                x += 3.15
            lane(ry + 1.25)
    else:
        # vehicle warehouse: parked cars under covers in bays
        for i, ry in enumerate(rackRows[:3]):
            for k in range(int((dockX - 6) / 3.2)):
                x = 6 + k * 3.2
                col = random.choice(['#c4c9d2', '#20232a', '#b3121b', '#1f4fa3', '#e8e8e8'])
                s = box(x, ry + 0.2, 0.25, 2.6, 1.6, 0.7, col) + box(x + 0.6, ry + 0.35, 0.95, 1.5, 1.3, 0.55, shade(col, .9))
                for wx in (x + 0.4, x + 2.0):
                    w = P(wx, ry + 1.8, 0.25)
                    s += f'<ellipse cx="{w[0]:.1f}" cy="{w[1]:.1f}" rx="7" ry="4" fill="#0b0b0b"/>'
                add(x, ry, 1, s)
            lane(ry + 2.1)
    if not EMPTY:
        # dock pallets
        for gx in [dockX + 1.0 + i * 1.5 for i in range(int((W - dockX - 1.5) / 1.5))]:
            for gy in [0.8 + j * 1.6 for j in range(int((D - 1.2) / 1.6))]:
                if abs(gy - D / 2) < 1.6 or random.random() < 0.25: continue
                s = box(gx, gy, 0, 1.2, 1.2, 0.14, '#9a7348')
                h = random.uniform(0.6, 1.6)
                col = random.choice(['#c3925c', '#b78450', '#d0a06a', '#8aa0b5'])
                s += box(gx + 0.04, gy + 0.04, 0.14, 1.12, 1.12, h, col)
                a, b = P(gx + 0.04, gy + 1.16, 0.3), P(gx + 1.16, gy + 1.16, 0.14 + h)
                s += f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#fff" stroke-opacity=".25" stroke-width="2"/>'
                add(gx, gy, 2, s)
        # forklift
        fx, fy = dockX - 0.2 + (W - dockX) * 0.35, D / 2 - 0.6
        s = box(fx, fy, 0.25, 1.6, 1.1, 0.8, '#f2b705') + box(fx + 0.2, fy + 0.15, 1.05, 0.9, 0.8, 0.9, '#262626', '#3a3a3a')
        s += box(fx + 0.3, fy + 0.1, 1.9, 1.1, 0.9, 0.08, '#f2b705')
        s += box(fx - 0.2, fy + 0.1, 0, 0.12, 0.9, 2.4, '#333333') + box(fx - 1.1, fy + 0.2, 0.1, 0.9, 0.1, 0.06, '#888888') + box(fx - 1.1, fy + 0.8, 0.1, 0.9, 0.1, 0.06, '#888888')
        for wx, wy in ((fx + 0.3, fy + 1.1), (fx + 1.3, fy + 1.1)):
            w = P(wx, wy, 0.25); s += f'<ellipse cx="{w[0]:.1f}" cy="{w[1]:.1f}" rx="{scale*0.32:.0f}" ry="{scale*0.2:.0f}" fill="#111"/>'
        add(fx, fy, 3, s)
        # cones on the dock line
        for cy in [D / 2 - 1.8, D / 2 - 0.6, D / 2 + 0.6, D / 2 + 1.8]:
            b = P(dockX - 0.3, cy, 0); t = P(dockX - 0.3, cy, 0.7)
            add(dockX - 0.3, cy, 4, f'<polygon points="{b[0]-6:.1f},{b[1]:.1f} {b[0]+6:.1f},{b[1]:.1f} {t[0]:.1f},{t[1]:.1f}" fill="#ff5a1f"/><line x1="{b[0]-3:.1f}" y1="{b[1]-6:.1f}" x2="{b[0]+3:.1f}" y2="{b[1]-6:.1f}" stroke="#fff" stroke-width="2"/>')
        # glass office in the front-left corner
        ox_, oy_ = 0.4, D - 4.6
        s = box(ox_, oy_, 0, 4.2, 4.2, 0.08, '#2a2d33')
        s += box(ox_ + 0.6, oy_ + 1.0, 0, 1.8, 0.8, 0.78, '#6b4b33') + box(ox_ + 1.2, oy_ + 1.1, 0.78, 0.6, 0.08, 0.45, '#101215', '#2c7be5')
        s += box(ox_ + 3.2, oy_ + 0.3, 0, 0.6, 0.5, 1.3, '#7b808a') + box(ox_ + 0.3, oy_ + 3.2, 0, 0.5, 0.5, 0.9, '#3b7d4a')
        s += poly([P(ox_ + 4.2, oy_, 0), P(ox_ + 4.2, oy_ + 4.2, 0), P(ox_ + 4.2, oy_ + 4.2, 3.0), P(ox_ + 4.2, oy_, 3.0)], '#9fd3ff', '#cde9ff', 1, .16)
        s += poly([P(ox_, oy_ + 4.2, 0), P(ox_ + 4.2, oy_ + 4.2, 0), P(ox_ + 4.2, oy_ + 4.2, 3.0), P(ox_, oy_ + 4.2, 3.0)], '#9fd3ff', '#cde9ff', 1, .12)
        s += poly([P(ox_, oy_, 3.0), P(ox_ + 4.2, oy_, 3.0), P(ox_ + 4.2, oy_ + 4.2, 3.0), P(ox_, oy_ + 4.2, 3.0)], '#cfe6ff', '#e6f3ff', 1.2, .14)
        add(ox_ + 2, oy_ + 2, 0, s)
        # workshop corner: bench, tool chest, barrels
        wx_, wy_ = 0.4, 0.4
        s = box(wx_, wy_, 0, 2.6, 0.8, 0.9, '#5a5f68') + box(wx_ + 2.9, wy_, 0, 0.7, 0.5, 1.1, '#c0151f')
        for i in range(3):
            b = P(wx_ + 0.6 + i * 0.7, wy_ + 1.6, 0)
            s += f'<ellipse cx="{b[0]:.1f}" cy="{b[1]-scale*0.45:.1f}" rx="{scale*0.3:.0f}" ry="{scale*0.16:.0f}" fill="#1d4f9c"/><rect x="{b[0]-scale*0.3:.1f}" y="{b[1]-scale*0.45:.1f}" width="{scale*0.6:.1f}" height="{scale*0.45:.1f}" fill="#163f7e"/><ellipse cx="{b[0]:.1f}" cy="{b[1]-scale*0.45:.1f}" rx="{scale*0.3:.0f}" ry="{scale*0.16:.0f}" fill="#2660bd"/>'
        add(wx_ + 1, wy_ + 1, 0, s)

    for _, svg in sorted(items, key=lambda t: t[0]):
        out.append(svg)
    # lights
    grid = [(x, y) for x in [3.0 + i * 6.0 for i in range(int((W - 4) / 6) + 1)] for y in ([D * 0.25, D * 0.5, D * 0.75] if D > 13 else [D * 0.3, D * 0.7])] if variant.startswith('empty') else [(x, y) for x in [W * f for f in (0.2, 0.45, 0.7, 0.92)] for y in [D * f for f in (0.3, 0.7)]]
    for lx_, ly_ in grid:
        if True:
            c = P(lx_, ly_, H - 0.4); f = P(lx_, ly_, 0)
            out.append(f'<polygon points="{c[0]-6:.1f},{c[1]:.1f} {c[0]+6:.1f},{c[1]:.1f} {f[0]+scale*2.2:.1f},{f[1]:.1f} {f[0]-scale*2.2:.1f},{f[1]:.1f}" fill="url(#cone)"/>')
            out.append(f'<rect x="{c[0]-16:.1f}" y="{c[1]-3:.1f}" width="32" height="5" rx="2" fill="#fff6e0"/><circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="38" fill="url(#glow)"/>')
            out.append(f'<ellipse cx="{f[0]:.1f}" cy="{f[1]:.1f}" rx="{scale*2.4:.0f}" ry="{scale*1.2:.0f}" fill="#ffe3b0" opacity=".07"/>')
    out.append('<rect width="1200" height="675" fill="url(#vig)"/>')
    out.append('</svg>')
    return '\n'.join(out)

outdir = sys.argv[1]
for key, args in {
    'rox_wh_small':   ('empty', 16, 11, 6.5, 3, 'SMALL WAREHOUSE'),
    'rox_wh_medium':  ('empty', 22, 14, 7.5, 5, 'MEDIUM WAREHOUSE'),
    'rox_wh_large':   ('empty', 30, 18, 9.0, 7, 'LARGE WAREHOUSE'),
    'rox_wh_vehicle': ('empty_vehicle', 26, 16, 8.0, 9, 'VEHICLE WAREHOUSE'),
}.items():
    open(f'{outdir}/{key}.svg', 'w').write(make(*args))
print('ok')
