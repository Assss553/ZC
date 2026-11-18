# ROX Store | All rights reserved
# Converts textures to DDS next to each .ydr.xml and writes rox_diner.ytyp.xml / .ymap.xml
import re, os, sys
from PIL import Image
st = sys.argv[1]; TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")
X, Y, Z = 232.0, 300.0, 105.6
NAMES = ("rox_diner_ext", "rox_diner_int", "rox_diner_hq", "rox_secret_wall")
PLACED = NAMES[:3]   # secret wall is spawned + animated by client.lua
arch, ents = [], []
for n in NAMES:
    t = open(f"{st}/{n}.ydr.xml").read()
    os.makedirs(f"{st}/{n}", exist_ok=True)
    for x in sorted(set(re.findall(r"<Name>(rox_[a-z_]+)</Name>", t)) - set(NAMES)):
        im = Image.open(f"{TEX}/{x}.png").convert("RGBA")
        if im.width > 512: im = im.resize((512, 512 * im.height // im.width), Image.LANCZOS)
        im.save(f"{st}/{n}/{x}.dds", pixel_format="DXT5")
    g = lambda tag: [float(v) for v in re.search(rf'<{tag} x="([-\d.e]+)" y="([-\d.e]+)" z="([-\d.e]+)"', t).groups()]
    mn, mx = g("BoundingBoxMin"), g("BoundingBoxMax")
    c = [(a + b) / 2 for a, b in zip(mn, mx)]; r = max(b - a for a, b in zip(mn, mx)) * 0.87
    arch.append(f'''  <Item type="CBaseArchetypeDef">
   <lodDist value="300.0"/><flags value="0"/><specialAttribute value="0"/>
   <bbMin x="{mn[0]}" y="{mn[1]}" z="{mn[2]}"/><bbMax x="{mx[0]}" y="{mx[1]}" z="{mx[2]}"/>
   <bsCentre x="{c[0]}" y="{c[1]}" z="{c[2]}"/><bsRadius value="{r}"/>
   <hdTextureDist value="100.0"/><name>{n}</name><textureDictionary/>
   <clipDictionary/><drawableDictionary/><physicsDictionary/><assetType>ASSET_TYPE_DRAWABLE</assetType><assetName>{n}</assetName>
   <extensions/>
  </Item>''')
    if n in PLACED: ents.append(f'''  <Item type="CEntityDef">
   <archetypeName>{n}</archetypeName><flags value="32"/><guid value="0"/>
   <position x="{X}" y="{Y}" z="{Z}"/><rotation x="0.0" y="0.0" z="0.0" w="1.0"/>
   <scaleXY value="1.0"/><scaleZ value="1.0"/><parentIndex value="-1"/><lodDist value="300.0"/><childLodDist value="0.0"/>
   <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel><numChildren value="0"/><priorityLevel>PRI_REQUIRED</priorityLevel>
   <extensions/><ambientOcclusionMultiplier value="255"/><artificialAmbientOcclusion value="255"/><tintValue value="0"/>
  </Item>''')
open(f"{st}/rox_diner.ytyp.xml", "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<CMapTypes>\n <extensions/>\n <archetypes>\n'
    + "\n".join(arch) + "\n </archetypes>\n <name>rox_diner</name>\n <dependencies/>\n <compositeEntityTypes/>\n</CMapTypes>\n")
open(f"{st}/rox_diner.ymap.xml", "w").write(f'''<?xml version="1.0" encoding="UTF-8"?>
<CMapData>
 <name>rox_diner</name><parent/><flags value="0"/><contentFlags value="1"/>
 <streamingExtentsMin x="{X-60}" y="{Y-60}" z="{Z-20}"/><streamingExtentsMax x="{X+60}" y="{Y+60}" z="{Z+30}"/>
 <entitiesExtentsMin x="{X-30}" y="{Y-25}" z="{Z-8}"/><entitiesExtentsMax x="{X+30}" y="{Y+25}" z="{Z+10}"/>
 <entities>
{chr(10).join(ents)}
 </entities>
 <containerLods/><boxOccluders/><occludeModels/><physicsDictionaries/>
 <instancedData><ImapLink/><PropInstanceList/><GrassInstanceList/></instancedData>
 <timeCycleModifiers/><carGenerators/><LODLightsSOA/><DistantLODLightsSOA/>
 <block><version value="0"/><flags value="0"/><name>rox_diner</name><exportedBy>ROX Store</exportedBy><owner/><time/></block>
</CMapData>
''')
print("packaged", sorted(os.listdir(st)))
