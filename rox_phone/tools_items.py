from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np
F='/usr/share/fonts/opentype/inter/'
import glob
def font(w,s):
    c=glob.glob(F+f'Inter-{w}.otf') or glob.glob('/usr/share/fonts/**/*Bold*.ttf',recursive=True); return ImageFont.truetype(c[0],s)
def rr(sz,r): m=Image.new('L',sz,0); ImageDraw.Draw(m).rounded_rectangle([0,0,sz[0]-1,sz[1]-1],r,fill=255); return m
def screen(W,H,wall,portrait):
    im=Image.open(wall).convert('RGB'); iw,ih=im.size
    # cover
    s=max(W/iw,H/ih); im=im.resize((int(iw*s)+1,int(ih*s)+1),Image.LANCZOS); x=(im.width-W)//2; y=(im.height-H)//2; im=im.crop((x,y,x+W,y+H)).convert('RGBA')
    d=ImageDraw.Draw(im); u=W/100 if not portrait else W/60
    d.text((u*4,u*6 if not portrait else u*22),'10:08',font=font('Bold',int(u*10)),fill='white')
    d.text((u*4.3,u*17 if not portrait else u*33),'Thursday, 12 November',font=font('SemiBold',int(u*2.2)),fill=(255,255,255,220))
    d.rounded_rectangle([W-u*12,u*2.5,W-u*3,u*6],u*2,fill=(0,0,0,120)); d.ellipse([W-u*11.3,u*3.3,W-u*9.5,u*5.1],fill=(255,77,77)); d.text((W-u*9,u*2.7),'$42,347',font=font('Bold',int(u*2)),fill='white')
    cols=[(255,122,61),(59,130,246),(46,229,157),(150,150,160),(255,90,31),(169,139,255)]
    n=len(cols); sz=u*6; g=u*1.6; tw=n*sz+(n-1)*g; x0=(W-tw)/2; y0=H-sz-u*4
    d.rounded_rectangle([x0-g,y0-g,x0+tw+g,y0+sz+g],u*3,fill=(255,255,255,45))
    for i,c in enumerate(cols):
        x=x0+i*(sz+g); d.rounded_rectangle([x,y0,x+sz,y0+sz],sz*.28,fill=c); d.rounded_rectangle([x+sz*.3,y0+sz*.3,x+sz*.7,y0+sz*.7],sz*.1,fill=(255,255,255,230))
    d.rounded_rectangle([W/2-u*7,H-u*1.6,W/2+u*7,H-u*1],u*.3,fill=(255,255,255,200))
    return im
def device(W,H,r,bez,wall,portrait):
    shot=Image.open(wall).convert('RGBA').resize((W,H),Image.LANCZOS)
    D=Image.new('RGBA',(W+2*bez,H+2*bez),(0,0,0,0)); body=Image.new('RGBA',D.size,(12,12,14,255))
    ImageDraw.Draw(body).rounded_rectangle([2,2,D.width-3,D.height-3],r,outline=(70,70,78,255),width=6)
    D.paste(body,(0,0),rr(D.size,r)); D.paste(shot,(bez,bez),rr((W,H),max(10,r-bez)))
    # camera
    dd=ImageDraw.Draw(D); cx=D.width//2 if not portrait else D.width//2; cy=bez//2
    dd.ellipse([cx-8,cy-8,cx+8,cy+8],fill=(30,30,36)); dd.ellipse([cx-3,cy-3,cx+3,cy+3],fill=(40,70,120))
    # gloss
    gl=Image.new('RGBA',D.size,(0,0,0,0)); ImageDraw.Draw(gl).polygon([(0,0),(D.width*.6,0),(D.width*.25,D.height),(0,D.height)],fill=(255,255,255,22))
    D=Image.alpha_composite(D,Image.composite(gl,Image.new('RGBA',D.size,(0,0,0,0)),rr(D.size,r)))
    return D
def coeffs(dst,src):
    A=[];B=[]
    for (x,y),(X,Y) in zip(dst,src):
        A+=[[x,y,1,0,0,0,-X*x,-X*y],[0,0,0,x,y,1,-Y*x,-Y*y]];B+=[X,Y]
    return np.linalg.solve(np.array(A,float),np.array(B,float)).tolist()
def tilt(D,out=2048,quad=None):
    w,h=D.size; src=[(0,0),(w,0),(w,h),(0,h)]
    c=coeffs(quad,src); T=D.transform((out,out),Image.PERSPECTIVE,c,Image.BICUBIC)
    sh=Image.new('RGBA',(out,out),(0,0,0,0)); m=T.split()[3].point(lambda a:150 if a>0 else 0)
    sh.putalpha(m); sh=sh.filter(ImageFilter.GaussianBlur(40)); shp=Image.new('RGBA',(out,out),(0,0,0,0)); shp.paste(sh,(30,60))
    return Image.alpha_composite(shp,T)
wall='/home/user/ZC/rox_phone/html/img/wall_golden.webp'
import os
w2=glob.glob('/home/user/ZC/rox_police/html/img/wallpapers/street.jpg'); wl=w2[0] if w2 else wall
ip=device(2000,1148,150,90,'/tmp/claude-0/-home-user-ZC/3eac5cd8-a0c6-5bdc-9017-57c8f915549a/scratchpad/scr_ipad.png',False)
ipt=tilt(ip,2048,[(560,230),(1880,800),(1500,1760),(170,1190)])
ph=device(800,1750,130,40,'/tmp/claude-0/-home-user-ZC/3eac5cd8-a0c6-5bdc-9017-57c8f915549a/scratchpad/scr_phone.png',True)
pht=tilt(ph,2048,[(780,170),(1560,450),(1250,1880),(470,1600)])
os.makedirs('/home/user/ZC/release/items',exist_ok=True)
for n,im in (('ipad',ipt),('tablet',ipt),('phone',pht)):
    bb=im.getbbox(); im=im.crop(bb); s=max(im.size); c=Image.new('RGBA',(s,s),(0,0,0,0)); c.paste(im,((s-im.width)//2,(s-im.height)//2))
    c.resize((512,512),Image.LANCZOS).save(f'/home/user/ZC/release/items/{n}.png'); c.resize((100,100),Image.LANCZOS).save(f'/home/user/ZC/release/items/{n}_100.png')
