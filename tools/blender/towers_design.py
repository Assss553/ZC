# ROX Towers interior design renders: loads the real game pieces (shellgen preview json + textures) and places
# stand-in furniture at the exact positions of the GTA props from rox_towers/data/interior.json.  (c) ROX Store
#   PIECE=rox_towers_f_ops SHELLS=<work dir> PH=<poly haven dir> OUT=<dir> SAMPLES=48 python towers_design.py
import bpy, json, os, sys, math, random
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from phlib import ph
PIECE = os.environ['PIECE']; W = os.environ['SHELLS']; OUT = os.environ.get('OUT', '/tmp/design'); os.makedirs(OUT, exist_ok=True)
DATA = json.load(open(os.environ.get('DATAFILE', os.path.join(os.path.dirname(__file__), '..', '..', 'rox_towers', 'data', 'interior.json'))))
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = int(os.environ.get('SAMPLES', '48')); sc.cycles.use_denoising = True
sc.cycles.max_bounces = 6; sc.cycles.sample_clamp_indirect = 4.0
sc.render.resolution_x, sc.render.resolution_y = int(os.environ.get('W', '1600')), int(os.environ.get('H', '900'))
names = [i.identifier for i in sc.view_settings.bl_rna.properties['view_transform'].enum_items]
sc.view_settings.view_transform = 'AgX' if 'AgX' in names else 'Filmic'; sc.view_settings.exposure = float(os.environ.get('EXPO', '0.4'))
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.01, 0.015, 0.03, 1)

_mats = {}
def piece_mat(m):
    key = m['tex'] + m['sh']
    if key in _mats: return _mats[key]
    mt = bpy.data.materials.new(m['mat']); mt.use_nodes = True; t = mt.node_tree; b = t.nodes['Principled BSDF']
    if m['sh'] == 'g':
        b.inputs['Base Color'].default_value = (0.85, 0.92, 0.96, 1); b.inputs['Roughness'].default_value = 0.02
        b.inputs['Transmission Weight' if 'Transmission Weight' in b.inputs else 'Transmission'].default_value = 1.0; b.inputs['IOR'].default_value = 1.05
        _mats[key] = mt; return mt
    png = os.path.join(W, 'tex', 'png', m['tex'] + '.png')
    if os.path.exists(png):
        im = t.nodes.new('ShaderNodeTexImage'); im.image = bpy.data.images.load(png)
        t.links.new(im.outputs['Color'], b.inputs['Base Color'])
        if m['sh'] == 'e':
            t.links.new(im.outputs['Color'], b.inputs['Emission Color' if 'Emission Color' in b.inputs else 'Emission'])
            b.inputs['Emission Strength'].default_value = 3.0 if 'led' in m['tex'] else 1.6
        nrm = os.path.join(W, 'tex', 'png', m['tex'] + '_n.png')
        if os.path.exists(nrm) and m['sh'] in ('n', 'ns'):
            n = t.nodes.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(nrm); n.image.colorspace_settings.name = 'Non-Color'
            nm = t.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = 0.6
            t.links.new(n.outputs['Color'], nm.inputs['Color']); t.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    sp = m.get('spec', 0.1); b.inputs['Roughness'].default_value = max(0.08, 0.75 - sp * 0.65)
    if 'glass' in m['tex']: b.inputs['Roughness'].default_value = 0.05
    _mats[key] = mt; return mt

def load_piece(name, z=0.0):
    d = json.load(open(os.path.join(W, 'preview', name + '.json')))
    for k, m in enumerate(d['meshes']):
        if m['tag'] == 'hull': continue
        P = m['P']; V = [(P[i], P[i + 1], P[i + 2] + z) for i in range(0, len(P), 3)]; I = m['I']
        F = [(I[i], I[i + 1], I[i + 2]) for i in range(0, len(I), 3)]
        me = bpy.data.meshes.new(f'{name}_{k}'); me.from_pydata(V, [], F); me.update()
        uv = me.uv_layers.new(); UV = m['UV']
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index; uv.data[li].uv = (UV[vi * 2], 1.0 - UV[vi * 2 + 1])
        ob = bpy.data.objects.new(me.name, me); ob.data.materials.append(piece_mat(m)); sc.collection.objects.link(ob)
    for l in d['lights']:
        L = bpy.data.lights.new('l', 'POINT'); L.energy = l['i'] * 45.0; L.shadow_soft_size = 0.3
        c = l['c']; L.color = tuple(v / 255.0 for v in c[:3]) if max(c[:3]) > 1.0 else tuple(c[:3])
        o = bpy.data.objects.new('l', L); o.location = (l['p'][0], l['p'][1], l['p'][2] + z); sc.collection.objects.link(o)

def bmat(name, col, rough=0.4, metal=0.0, emit=0.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if emit: b.inputs['Emission Color' if 'Emission Color' in b.inputs else 'Emission'].default_value = (*col, 1); b.inputs['Emission Strength'].default_value = emit
    return m

def obox(name, x, y, z, sx, sy, sz, h, m, bev=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1); o = bpy.context.object; o.name = name; o.scale = (sx, sy, sz)
    a = math.radians(h); o.rotation_euler.z = a; o.location = (x, y, z + sz / 2)
    o.data.materials.append(m)
    if bev: md = o.modifiers.new('b', 'BEVEL'); md.width = bev; md.segments = 2
    return o

def local(x, y, h, dx, dy):     # offset in the prop's own frame (front = -Y)
    a = math.radians(h); return x + dx * math.cos(a) - dy * math.sin(a), y + dx * math.sin(a) + dy * math.cos(a)

WHITE = bmat('desk_white', (0.9, 0.9, 0.88), 0.3); BLACK = bmat('black_metal', (0.03, 0.03, 0.035), 0.3, 0.8)
SCREEN = bmat('screen', (0.12, 0.3, 0.7), 0.2, 0, 1.0); WOOD = bmat('walnut', (0.25, 0.13, 0.07), 0.35); GREY = bmat('grey', (0.4, 0.42, 0.45), 0.5, 0.6)
CARD = bmat('card', (0.55, 0.42, 0.25), 0.8); RED = bmat('red', (0.7, 0.05, 0.05), 0.4); NAVY = bmat('navy', (0.05, 0.1, 0.3), 0.6)
STEEL = bmat('steel', (0.75, 0.76, 0.78), 0.2, 1.0); GLASSD = bmat('door_glass', (0.06, 0.07, 0.08), 0.05, 0.6); RUG = bmat('rug', (0.32, 0.3, 0.28), 1.0)
PLANTS = ['potted_plant_01', 'potted_plant_02', 'potted_plant_04', 'pachira_aquatica_01', 'calathea_orbifolia_01']
TOPS = {}

LEATHER = bmat('leather', (0.05, 0.045, 0.04), 0.35)
MESH = bmat('mesh', (0.03, 0.03, 0.035), 0.6)
CHROME = bmat('chrome', (0.8, 0.8, 0.82), 0.12, 1.0)
def office_chair(x, y, z, h, exec_=False):
    """swivel office chair stand-in: 5-star chrome base, gas lift, seat, (high) back, arms"""
    for k in range(5):
        a = math.radians(h + k * 72); obox('leg', x + 0.18 * math.sin(a), y - 0.18 * math.cos(a), z + 0.04, 0.05, 0.36, 0.04, h + k * 72, CHROME)
    obox('lift', x, y, z + 0.08, 0.05, 0.05, 0.36, h, CHROME)
    obox('seat', x, y, z + 0.44, 0.52, 0.5, 0.09, h, LEATHER if exec_ else MESH, 0.03)
    bx, by = local(x, y, h, 0, 0.27); bh = 0.85 if exec_ else 0.6
    obox('back', bx, by, z + 0.55, 0.5, 0.07, bh, h, LEATHER if exec_ else MESH, 0.03)
    for dx in (-0.27, 0.27):
        ax, ay = local(x, y, h, dx, 0.05); obox('arm', ax, ay, z + 0.6, 0.05, 0.36, 0.04, h, BLACK); obox('armp', ax, ay, z + 0.5, 0.03, 0.04, 0.1, h, BLACK)

def car(x, y, z, h, m):
    col = {'riot': (0.1, 0.1, 0.11), 'fbi2': (0.02, 0.02, 0.02), 'fbi': (0.02, 0.02, 0.02)}.get(m, (0.9, 0.9, 0.9))
    big = m in ('riot', 'policet'); L, W_, H_ = (6.0, 2.4, 1.6) if big else (4.9, 2.0, 0.9)
    obox('car', x, y, z + 0.35, W_, L, H_, h + 90 - 90, bmat('car_' + m, col, 0.25, 0.5), 0.12)
    cx, cy = local(x, y, h, 0, 0.3 if not big else 0.0)
    obox('cab', cx, cy, z + 0.35 + H_, W_ - 0.2, L * (0.45 if not big else 0.8), 0.65 if not big else 0.9, h, bmat('cab_' + m, col if big else (0.05, 0.06, 0.07), 0.1, 0.3), 0.1)
    for dx in (-W_ / 2, W_ / 2):
        for dy in (-L * 0.32, L * 0.32):
            wx, wy = local(x, y, h, dx, dy); obox('wh', wx, wy, z, 0.3, 0.75, 0.75, h, BLACK, 0.1)
    lx, ly = local(x, y, h, 0, -0.2); obox('bar', lx, ly, z + 0.35 + H_ + (0.65 if not big else 0.9), 1.2, 0.25, 0.1, h, bmat('lightbar', (0.2, 0.3, 1.0), 0.3, 0, 3.0))

def furniture(items, z0):
    rr = random.Random(5)
    for f in items:
        m, x, y, h = f['m'], f['x'], f['y'], f.get('h', 0.0); z = z0 + f.get('z', 0.0)
        if 'on' in f and f['on'] in TOPS: z = TOPS[f['on']]
        if m in ('h4_prop_office_desk_01',):
            obox('desk', x, y, z + 0.72, 1.6, 0.8, 0.04, h, WHITE, 0.01)
            for dx in (-0.75, 0.75): lx, ly = local(x, y, h, dx, 0); obox('leg', lx, ly, z, 0.05, 0.72, 0.72, h, BLACK)
            if 'name' in f: TOPS[f['name']] = z + 0.76
        elif m in ('prop_monitor_01a', 'hei_prop_hei_monitor_police_01', 'ch_prop_ch_security_monitor_01a'):
            lx, ly = local(x, y, h, 0, 0.15); obox('scr', lx, ly, z + 0.12, 0.56, 0.03, 0.34, h, SCREEN); obox('st', lx, ly, z, 0.05, 0.05, 0.14, h, BLACK)
        elif m == 'prop_keyboard_01b': obox('kb', x, y, z, 0.45, 0.14, 0.015, h, BLACK)
        elif m in ('ex_prop_offchair_exec_01',): office_chair(x, y, z, h, True)
        elif m in ('ex_prop_offchair_exec_04',): office_chair(x, y, z, h, False)
        elif m in ('prop_off_chair_04',): office_chair(x, y, z, h, False)
        elif m in ('prop_off_chair_01', 'apa_mp_h_din_chair_04', 'apa_mp_h_din_chair_12'): ph('dining_chair_02', (x, y, z), h, 0.95)
        elif m == 'apa_mp_h_acc_plant_tall_01': ph(rr.choice(PLANTS), (x, y, z), rr.uniform(0, 360), rr.uniform(1.3, 1.9))
        elif m in ('v_med_cor_filingcab',): ph('drawer_cabinet', (x, y, z), h, 1.25)
        elif m == 'apa_mp_h_str_shelffloorm_02': ph('steel_frame_shelves_03', (x, y, z), h, 1.8)
        elif m in ('ex_mp_h_off_sofa_01', 'ex_mp_h_off_sofa_02', 'apa_mp_h_stn_sofacorn_05'): ph('sofa_03', (x, y, z), h, 0.85)
        elif m in ('apa_mp_h_stn_chairarm_12', 'apa_mp_h_stn_chairarm_23', 'ex_mp_h_off_easychair_01'): ph('mid_century_lounge_chair', (x, y, z), h, 0.85)
        elif m == 'apa_mp_h_tab_coffee_07': ph('modern_coffee_table_01', (x, y, z), h, 0.42)
        elif m == 'apa_mp_h_din_table_04': ph('coffee_table_round_01', (x, y, z), h, 0.75)
        elif m == 'v_corp_conftable': obox('ct', x, y, z + 0.72, 2.4, 1.2, 0.05, h, WOOD, 0.01); obox('cb', x, y, z, 1.6, 0.5, 0.72, h, BLACK)
        elif m in ('prop_tv_flat_01', 'prop_tv_flat_02', 'prop_tv_flat_michael', 'xm_prop_x17_tv_ceiling_01'):
            obox('tv', x, y, z, 1.5, 0.05, 0.85, h, SCREEN)
        elif m in ('v_corp_servercln',): obox('srv', x, y, z, 0.6, 1.0, 2.0, h, BLACK); lx, ly = local(x, y, h, 0, -0.51); obox('srvled', lx, ly, z + 0.2, 0.4, 0.01, 1.6, h, bmat('srvl', (0.2, 0.6, 1.0), 0.3, 0, 3.0))
        elif m in ('prop_elecbox_01a',): obox('el', x, y, z, 0.9, 0.35, 1.9, h, GREY)
        elif m in ('p_cs_locker_01_s',): obox('lk', x, y, z, 0.6, 0.5, 1.9, h, GREY, 0.01)
        elif m in ('prop_box_wood02a', 'v_ind_cs_box01'): obox('bx', x, y, z, 0.8, 0.6, 0.6, h + rr.uniform(-10, 10), CARD)
        elif m in ('prop_vend_coffe_01', 'prop_vend_soda_01', 'v_ret_ml_fridge', 'ba_prop_battle_bar_fridge_01'):
            obox('vend', x, y, z, 0.9, 0.8, 1.9 if 'bar' not in m else 0.9, h, RED if 'soda' in m else BLACK); lx, ly = local(x, y, h, 0, -0.41); obox('vf', lx, ly, z + 0.9, 0.6, 0.01, 0.7, h, SCREEN)
        elif m == 'prop_watercooler': obox('wc', x, y, z, 0.35, 0.35, 1.2, h, WHITE)
        elif m in ('prop_flag_us', 'prop_flag_lsservices'):
            obox('pole', x, y, z, 0.04, 0.04, 2.5, h, bmat('gold', (0.8, 0.6, 0.3), 0.2, 1.0)); lx, ly = local(x, y, h, 0.45, 0); obox('flag', lx, ly, z + 1.3, 0.85, 0.01, 1.0, h, NAVY)
        elif m == 'ch_prop_ch_metal_detector_01a':
            for dx in (-0.45, 0.45): lx, ly = local(x, y, h, dx, 0); obox('md', lx, ly, z, 0.12, 0.5, 2.1, h, GREY)
            obox('mdt', x, y, z + 2.1, 1.02, 0.5, 0.15, h, GREY)
        elif m == 'ch_prop_baggage_scanner_01a': obox('bs', x, y, z, 2.2, 0.85, 1.25, h, GREY, 0.02)
        elif m == 'prop_sec_barier_01a': obox('bar', x, y, z, 0.15, 0.15, 1.0, h, STEEL)
        elif m == 'v_ilev_ph_bench': obox('bench', x, y, z + 0.4, 2.0, 0.5, 0.06, h, WOOD); obox('benchl', x, y, z, 1.8, 0.1, 0.4, h, BLACK)
        elif m == 'v_ilev_cd_lampal': obox('lect', x, y, z, 0.6, 0.5, 1.15, h, WOOD)
        elif m == 'ex_prop_ex_laptop_01a': ph('classic_laptop', (x, y, z), h, 0.25)
        elif m == 'apa_mp_h_acc_rugwoolm_03': obox('rug', x, y, z, 3.0, 2.2, 0.01, h, RUG)
        elif m == 'apa_mp_h_floorlamp_c': obox('fl', x, y, z, 0.04, 0.04, 1.6, h, BLACK); obox('fls', x, y, z + 1.5, 0.35, 0.35, 0.3, h, bmat('lampshade', (1, 0.85, 0.6), 0.5, 0, 4.0))
        elif m == 'prop_toilet_01': obox('wc', x, y, z, 0.4, 0.6, 0.42, h, WHITE, 0.05)
        elif m in ('bkr_prop_gunlocker_01a', 'gr_prop_gr_gunlocker_01a'): obox('gl', x, y, z, 1.4, 0.6, 2.0, h, BLACK, 0.01); lx, ly = local(x, y, h, 0, -0.31); obox('glf', lx, ly, z + 0.2, 1.2, 0.01, 1.6, h, GREY)
        elif m in ('gr_prop_gr_bench_04a', 'prop_table_03'): obox('wb', x, y, z + 0.85, 2.4, 1.0, 0.08, h, GREY); obox('wbl', x, y, z, 2.2, 0.8, 0.85, h, BLACK)
        elif m in ('prop_box_ammo04a', 'prop_gun_case_01'): obox('ammo', x, y, z, 0.5, 0.25, 0.22, h, bmat('ammo', (0.2, 0.22, 0.14), 0.5, 0.3), 0.01); lx_, ly_ = local(x, y, h, 0, 0); obox('lid', lx_, ly_, z + 0.22, 0.12, 0.05, 0.03, h, BLACK)
        elif m in ('v_med_bed1',): obox('bed', x, y, z + 0.5, 0.9, 2.0, 0.15, h, WHITE, 0.03); obox('bedb', x, y, z, 0.8, 1.8, 0.5, h, GREY)
        elif m in ('v_med_trolley',): obox('tr', x, y, z, 0.5, 0.4, 0.9, h, STEEL)
        elif m in ('xm_base_cia_server_01',): obox('srv', x, y, z, 0.6, 1.0, 2.0, h, BLACK); lx, ly = local(x, y, h, 0, -0.51); obox('srvled', lx, ly, z + 0.2, 0.4, 0.01, 1.6, h, bmat('srvl', (0.2, 0.6, 1.0), 0.3, 0, 3.0))
        elif m in ('ba_prop_battle_hacker_screen',): obox('hs', x, y, z, 1.6, 0.05, 0.7, h, bmat('green', (0.1, 0.9, 0.3), 0.3, 0, 2.0))
        elif m in ('xm_prop_x17_laptop_mrsr', 'hei_prop_hst_laptop', 'prop_cs_tablet'): ph('classic_laptop', (x, y, z), h, 0.22)
        elif m in ('xm_prop_x17_computer_01',): obox('pc', x, y, z, 0.2, 0.45, 0.45, h, BLACK)
        elif m.startswith('gr_prop_gr_target'): obox('tg', x, y, z, 0.05, 0.6, 1.8, h, WHITE); obox('tgr', x, y, z + 1.1, 0.06, 0.3, 0.3, h, RED)
        elif m in ('prop_weight_bench_02', 'prop_muscle_bench_03'): obox('wb', x, y, z + 0.4, 0.35, 1.3, 0.12, h, BLACK); obox('bar', x, y, z + 1.1, 1.8, 0.04, 0.04, h, STEEL)
        elif m in ('prop_weight_squat',): obox('sq', x, y, z, 1.4, 1.4, 2.3, h, GREY)
        elif m in ('prop_beach_punchbag',): obox('pb', x, y, z + 0.6, 0.4, 0.4, 1.2, h, RED, 0.1)
        elif m in ('apa_p_apdlc_treadmill_s',): obox('tm', x, y, z, 0.8, 1.9, 0.25, h, BLACK); lx, ly = local(x, y, h, 0, -0.85); obox('tmc', lx, ly, z, 0.8, 0.1, 1.3, h, GREY)
        elif m in ('prop_toolchest_05', 'imp_prop_tool_chest_01a'): obox('tc', x, y, z, 1.0, 0.5, 1.1, h, RED)
        elif 'trophy' in m: obox('tro', x, y, z, 0.18, 0.18, 0.35, h, bmat('gold', (0.8, 0.6, 0.3), 0.2, 1.0))
        elif m.startswith('prop_bodyarmour'):
            V = bmat('vest', (0.06, 0.065, 0.07), 0.8); P = bmat('pouch', (0.1, 0.105, 0.1), 0.8)
            obox('vest', x, y, z, 0.48, 0.22, 0.6, h, V, 0.05)
            for dx in (-0.15, 0.0, 0.15): px, py = local(x, y, h, dx, -0.13); obox('pouch', px, py, z + 0.12, 0.12, 0.07, 0.18, h, P, 0.02)
            for dx in (-0.14, 0.14): sx, sy = local(x, y, h, dx, 0); obox('strap', sx, sy, z + 0.6, 0.08, 0.2, 0.12, h, V)
            px, py = local(x, y, h, 0, -0.115); obox('patch', px, py, z + 0.42, 0.22, 0.01, 0.07, h, bmat('patch', (0.85, 0.8, 0.6), 0.6))
        elif m == 'prop_mask_ballistic': obox('mask', x, y, z, 0.2, 0.12, 0.25, h, BLACK, 0.06)
        elif m in ('prop_ballistic_shield', 'prop_riot_shield'): obox('sh', x, y, z, 0.6, 0.06, 1.2, h, BLACK, 0.04); vx, vy = local(x, y, h, 0, -0.035); obox('shv', vx, vy, z + 0.85, 0.3, 0.01, 0.12, h, bmat('visor', (0.02, 0.02, 0.03), 0.05, 0.8)); obox('shp', vx, vy, z + 0.5, 0.36, 0.01, 0.1, h, bmat('patch', (0.85, 0.8, 0.6), 0.6))
        elif m == 'ch_prop_whiteboard': obox('wbd', x, y, z + 0.8, 1.8, 0.04, 1.1, h, WHITE)
        elif m in ('prop_copier_01',): obox('cop', x, y, z, 0.7, 0.6, 1.1, h, GREY)
        elif m in ('prop_printer_01',): obox('prn', x, y, z, 0.45, 0.4, 0.3, h, GREY)
        elif m == 'prop_cs_walkie_talkie': obox('wt', x, y, z, 0.06, 0.035, 0.17, h, BLACK, 0.01); obox('ant', x + 0.02, y, z + 0.17, 0.01, 0.01, 0.08, h, BLACK)
        elif m in ('prop_shower_rack_01', 'prop_fire_exting_1a'): obox('ex', x, y, z, 0.15, 0.15, 0.5, h, RED)
        elif m in ('gr_prop_gr_rsply_crate01a', 'xm_prop_crates_rifles_01a', 'prop_box_guncase_02a'): obox('crate', x, y, z, 1.2, 0.6, 0.5, h, bmat('olive', (0.25, 0.28, 0.15), 0.6))
        elif m in ('p_v_43_safe_s',): obox('safe', x, y, z, 0.8, 0.8, 1.4, h, GREY, 0.02)
        elif m == 'p_ld_heist_bag_s': obox('bag', x, y, z, 0.7, 0.35, 0.32, h, BLACK, 0.1); obox('handle', x, y, z + 0.32, 0.3, 0.04, 0.08, h, BLACK)
        elif m == 'prop_tv_cam_02': obox('cam', x, y, z + 1.4, 0.3, 0.5, 0.3, h, BLACK); obox('tri', x, y, z, 0.05, 0.05, 1.4, h, BLACK)
        elif m == 'h4_prop_battle_sports_helmet':
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(x, y, z + 0.02)); hm = bpy.context.object; hm.scale = (1, 1.15, 0.85); bpy.ops.object.shade_smooth(); hm.data.materials.append(bmat('helmet', (0.05, 0.055, 0.05), 0.55))
            gx, gy = local(x, y, h, 0, -0.14); obox('visor', gx, gy, z + 0.02, 0.22, 0.03, 0.06, h, bmat('visor', (0.02, 0.02, 0.03), 0.05, 0.8))
        elif m == 'ex_prop_ex_tv_flat_01': obox('tv', x, y, z, 1.9, 0.05, 1.1, h, SCREEN)
        elif m == 'apa_mp_h_str_sideboardl_06': obox('sb', x, y, z, 2.2, 0.5, 0.75, h, WOOD, 0.01)
        elif m == 'apa_mp_h_str_shelfwallm_01': obox('ws', x, y, z, 1.4, 0.3, 0.04, h, WOOD)
        elif m == 'ex_office_citymodel_01': obox('cm', x, y, z, 1.6, 1.0, 0.75, h, WOOD); obox('cmb', x, y, z + 0.75, 1.4, 0.8, 0.3, h, WHITE)
        elif m == 'apa_mp_h_lit_lightpendant_01': obox('pend', x, y, z, 0.4, 0.4, 0.25, h, bmat('pendant', (1, 0.8, 0.5), 0.4, 0, 6.0)); obox('cord', x, y, z + 0.25, 0.01, 0.01, 1.0, h, BLACK)
        elif m == 'apa_mp_h_acc_vase_06': ph('ceramic_vase_01', (x, y, z), h, 0.35)
        elif m == 'prop_sink_02': obox('sink', x, y, z + 0.9, 0.5, 0.4, 0.06, h, WHITE)

def doors(items, z0):
    for d in items:
        a = math.radians(d['h']); cx, cy = d['x'] + math.cos(a) * d['w'] / 2, d['y'] + math.sin(a) * d['w'] / 2
        obox('door', cx, cy, z0, d['w'] - 0.02, 0.05, 2.28, d['h'], GLASSD if d['kind'] == 'glass' else (STEEL if d['kind'] == 'sec' else WOOD), 0.004)

cam_d = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_d); sc.collection.objects.link(cam); sc.camera = cam
tgt = bpy.data.objects.new('t', None); sc.collection.objects.link(tgt)
tr = cam.constraints.new('TRACK_TO'); tr.target = tgt; tr.track_axis = 'TRACK_NEGATIVE_Z'; tr.up_axis = 'UP_Y'
def shot(tag, pos, look, lens=18):
    cam.location = pos; tgt.location = look; cam_d.lens = lens
    sc.render.filepath = os.path.join(OUT, f'{PIECE}_{tag}.png'); bpy.ops.render.render(write_still=True); print('SHOT', tag, flush=True)

load_piece(PIECE, float(os.environ.get('PZ', '0')))
if PIECE == 'rox_towers_lobby': load_piece('rox_towers_base')
def place_piece(name, x, y, z, rz=0.0):
    before = set(bpy.data.objects); load_piece(name, 0.0)
    a = math.radians(rz); c, sn = math.cos(a), math.sin(a)
    for o in bpy.data.objects:
        if o not in before:
            if o.type == 'MESH':
                for v in o.data.vertices: v.co = (v.co.x * c - v.co.y * sn, v.co.x * sn + v.co.y * c, v.co.z)
            else:
                o.location = (o.location.x * c - o.location.y * sn, o.location.x * sn + o.location.y * c, o.location.z)
            o.location = (o.location.x + x, o.location.y + y, o.location.z + z)
for e in json.loads(os.environ.get('EXTRA', '[]')): place_piece(*e)
if os.environ.get('GROUND'):
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02)); gp = bpy.context.object; gp.data.materials.append(bmat('asphalt', (0.06, 0.06, 0.065), 0.8))
    for i in range(-6, 7, 3):
        if abs(i) > 1: obox('stripe', i * 1.0 + 0.0, -40, 0.0, 0.15, 80, 0.01, 0, bmat('lane', (0.8, 0.8, 0.8), 0.6)) if False else None
    sun = bpy.data.lights.new('moon', 'SUN'); sun.energy = 0.3; sun.color = (0.6, 0.7, 1.0); so = bpy.data.objects.new('moon', sun); so.rotation_euler = (0.9, 0.2, 0.6); sc.collection.objects.link(so)
if isinstance(DATA['furniture'], dict):
    fk = os.environ.get('FURNKEY', PIECE); furniture(DATA['furniture'].get(fk, []), 0.0); doors(DATA['doors'].get(fk, []), 0.0)

else:
    pz = float(os.environ.get('PZ', '0')); furniture(DATA['furniture'], pz); doors(DATA['doors'], pz)
SHOTS = {
    'rox_towers_lobby': [('entrance', (0, -23.6, 1.7), (0, -6, 2.4), 16), ('security', (-9, -18.5, 2.2), (1, -12, 1.0), 18),
                         ('reception', (11, -9.5, 2.0), (0, -3, 2.6), 18), ('atrium', (22, -21, 9), (-4, -5, 1.5), 16)],
    'rox_towers_f_ops': [('ops_wall', (13.5, -4.6, 2.7), (-4, -13.5, 1.2), 16), ('ops_rows', (0, -4.6, 2.4), (0, -14, 1.0), 16)],
    'rox_towers_f_cnf': [('boardroom', (-6.6, -4.6, 2.4), (-15, -10, 0.8), 16)],
    'rox_towers_f_cmd': [('chief', (-6.6, -4.6, 2.3), (-14, -11, 1.0), 16), ('reception', (5.4, -4.6, 2.2), (0, -11, 1.0), 16)],
    'rox_towers_f_inv': [('interrogation', (19.4, -4.6, 2.3), (15.5, -10, 0.8), 16), ('detectives', (3.6, -4.6, 2.3), (-2, -12, 0.8), 16)],
    'rox_towers_f_adm': [('corridor', (-19, -2.0, 1.7), (10, -2.0, 1.3), 18), ('open_office', (3.6, -4.6, 2.3), (-2, -12, 0.8), 16)],
    'rox_towers_f_svc': [('breakroom', (7.6, -4.6, 2.3), (1, -11, 0.8), 16), ('servers', (-19.5, 14.0, 2.3), (-12, 9, 0.8), 16)],
}
SHOTS.update(json.loads(os.environ.get('SHOTS', '{}')))
for tag, p, l, lens in SHOTS.get(PIECE, []): shot(tag, p, l, lens)
print('DONE')
