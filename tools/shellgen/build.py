# ROX shell generator - build everything  (c) ROX Store
#   python3 build.py <workdir>     -> workdir/xml (CodeWalker XML + dds), workdir/out (.ydr/.ytd/.ytyp), workdir/preview (json)
import sys, os, json, subprocess, shutil
import houses
from kit import MATS

W = sys.argv[1]
TEX = os.path.join(W, 'tex')
XML = os.path.join(W, 'xml'); OUT = os.path.join(W, 'out'); PRE = os.path.join(W, 'preview')
for d in (XML, OUT, PRE):
    os.makedirs(d, exist_ok=True)
CW = ['dotnet', os.path.join(W, 'cwconv/bin/Release/net8.0/cwconv.dll')]
TXD = 'rox_shells_txd'
only = sys.argv[2:] or None

index = json.load(open(os.path.join(TEX, 'textures.json')))
shells, used = [], set()
for fn in houses.ALL:
    if only and fn.__name__ not in only:
        continue
    s = fn()
    s.finalize()
    st = s.write_xml(XML)
    s.write_preview(os.path.join(PRE, s.name + '.json'))
    for k in s.geo:
        M = MATS[k.split('|')[0]]
        used.add(M['tex'])
        if M['sh'] in ('ns', 'n'): used.add(M['tex'] + '_n')
        if M['sh'] in ('ns', 's'): used.add(M['tex'] + '_s')
    shells.append(s)
    print(s.name, st['verts'], 'verts', st['tris'], 'tris', st['mats'], 'materials', st['lights'], 'lights', st['cboxes'], 'col boxes')

if not only:
    # shared texture dictionary
    L = ['<?xml version="1.0" encoding="UTF-8"?>', '<TextureDictionary>']
    for t in sorted(used):
        assert t in index, 'missing texture ' + t
        w, h, lv = index[t]
        shutil.copy(os.path.join(TEX, 'dds', t + '.dds'), os.path.join(XML, t + '.dds'))
        L += [' <Item>', f'  <Name>{t}</Name>', '  <Unk32 value="0" />', '  <Usage>DEFAULT</Usage>', '  <UsageFlags>0</UsageFlags>', '  <ExtraFlags value="0" />',
              f'  <Width value="{w}" />', f'  <Height value="{h}" />', f'  <MipLevels value="{lv}" />', '  <Format>D3DFMT_DXT1</Format>', f'  <FileName>{t}.dds</FileName>', ' </Item>']
    L += ['</TextureDictionary>']
    open(os.path.join(XML, TXD + '.ytd.xml'), 'w').write('\n'.join(L) + '\n')
    # archetypes
    f = lambda v: ('%.6f' % v).rstrip('0').rstrip('.')
    L = ['<?xml version="1.0" encoding="UTF-8"?>', '<CMapTypes>', ' <extensions />', ' <archetypes>']
    for s in shells:
        st = s.stats
        L += ['  <Item type="CBaseArchetypeDef">', '   <lodDist value="300" />', '   <flags value="32" />', '   <specialAttribute value="0" />',
              f'   <bbMin x="{f(st["bbmin"][0])}" y="{f(st["bbmin"][1])}" z="{f(st["bbmin"][2])}" />', f'   <bbMax x="{f(st["bbmax"][0])}" y="{f(st["bbmax"][1])}" z="{f(st["bbmax"][2])}" />',
              f'   <bsCentre x="{f(st["center"][0])}" y="{f(st["center"][1])}" z="{f(st["center"][2])}" />', f'   <bsRadius value="{f(st["radius"])}" />',
              '   <hdTextureDist value="100" />', f'   <name>{s.name}</name>', f'   <textureDictionary>{TXD}</textureDictionary>', '   <clipDictionary />',
              '   <drawableDictionary />', '   <physicsDictionary />', '   <assetType>ASSET_TYPE_DRAWABLE</assetType>', f'   <assetName>{s.name}</assetName>', '   <extensions />', '  </Item>']
    L += [' </archetypes>', ' <name>rox_shells</name>', ' <dependencies />', ' <compositeEntityTypes />', '</CMapTypes>']
    open(os.path.join(XML, 'rox_shells.ytyp.xml'), 'w').write('\n'.join(L) + '\n')

def conv(xml, out):
    r = subprocess.run(CW + ['import', os.path.join(XML, xml), os.path.join(OUT, out)], capture_output=True, text=True)
    print(' ', (r.stdout + r.stderr).strip()[:400])
    assert r.returncode == 0, 'conversion failed: ' + xml
for s in shells:
    conv(s.name + '.ydr.xml', s.name + '.ydr')
if not only:
    conv(TXD + '.ytd.xml', TXD + '.ytd')
    conv('rox_shells.ytyp.xml', 'rox_shells.ytyp')
    json.dump([dict(name=s.name, label=s.label, labelAr=s.label_ar, entry=s.entry, rooms=len(s.rooms), stats=s.stats) for s in shells],
              open(os.path.join(W, 'shells.json'), 'w'), indent=1, ensure_ascii=False)
