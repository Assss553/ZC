import sys,glob
from PIL import Image,ImageDraw,ImageFont,ImageFilter,ImageChops
W,H=3840,2160
F=[p for p in glob.glob('/usr/share/fonts/**/InterDisplay-BlackItalic*',recursive=True)+glob.glob('/usr/share/fonts/**/*Display*Black*Italic*',recursive=True)][0]
ft=ImageFont.truetype(F,1150)
def mask(ch,x,y):
    m=Image.new('L',(W,H),0);ImageDraw.Draw(m).text((x,y),ch,font=ft,fill=255,anchor='ms');return m
base=1580
sizes=[ft.getlength(c) for c in 'VC2']
ov=260
total=sum(sizes)-2*ov
x=(W-total)/2
ms=[]
for c,s in zip('VC2',sizes): ms.append(mask(c,x,base)); x+=s-ov
bb=ImageChops.lighter(ImageChops.lighter(ms[0],ms[1]),ms[2]).getbbox()
V,C,T=[ImageChops.offset(m,int(W/2-(bb[0]+bb[2])/2),0) for m in ms]
gap=lambda m,r: m.filter(ImageFilter.MaxFilter(r))
# interlock: C over V on top half, V over C on bottom half; 2 over C bottom, C over 2 top
top=Image.new('L',(W,H),0);ImageDraw.Draw(top).rectangle([0,0,W,H//2+80],fill=255)
bot=ImageChops.invert(top)
def cut(under,over,region):  # remove from 'under' a gap around 'over' within region
    g=ImageChops.multiply(gap(over,41),region); return ImageChops.subtract(under,g)
V2=cut(V,C,top); C2=cut(C,V,bot)
C3=cut(C2,T,bot); T2=cut(T,C,top)
def grad(c1,c2):
    g=Image.new('RGB',(W,H));d=ImageDraw.Draw(g)
    for yy in range(H):
        t=yy/H; d.line([(0,yy),(W,yy)],fill=tuple(int(a+(b-a)*t) for a,b in zip(c1,c2)))
    return g
img=Image.new('RGB',(W,H),(0,0,0))
# subtle vignette glow
glow=Image.new('L',(W,H),0);ImageDraw.Draw(glow).ellipse([W*0.2,H*0.15,W*0.8,H*0.85],fill=60)
img=Image.composite(Image.new('RGB',(W,H),(25,0,4)),img,glow.filter(ImageFilter.GaussianBlur(300)))
allm=ImageChops.lighter(ImageChops.lighter(V2,C3),T2)
red=Image.new('RGB',(W,H),(255,20,50))
img=Image.composite(red,img,allm.filter(ImageFilter.GaussianBlur(60)).point(lambda p:p*0.55))
silver=grad((255,255,255),(140,140,150)); redg=grad((255,60,80),(150,0,20))
for m,fill in ((V2,silver),(C3,redg),(T2,silver)):
    img=Image.composite(fill,img,m)
# thin inner edge highlight
edge=ImageChops.subtract(allm,allm.filter(ImageFilter.MinFilter(9)))
img=Image.composite(Image.new('RGB',(W,H),(255,255,255)),img,edge.point(lambda p:p*0.35))
d=ImageDraw.Draw(img)
sf=ImageFont.truetype(F.replace('BlackItalic','Bold') if 'BlackItalic' in F else F,90)
t='P E R F O R M A N C E   ·   T W E A K'
d.text((W/2,base+230),t,font=sf,fill=(170,170,175),anchor='ms')
d.line([(W/2-900,base+110),(W/2+900,base+110)],fill=(255,30,60),width=6)
img.save(sys.argv[1]); img.resize((1280,720),Image.LANCZOS).save(sys.argv[2])
