import math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT=sys.argv[1]; os.makedirs(OUT, exist_ok=True)
F='/usr/share/fonts/opentype/inter/'
WHITE=(238,243,247,255); CYAN=(64,190,240,255); DIMW=(238,243,247,70)

def hexpts(cx,cy,r,rot=30):
    return [(cx+r*math.cos(math.radians(rot+60*k)), cy+r*math.sin(math.radians(rot+60*k))) for k in range(6)]

def emblem(size, ss=4, glow=True):
    S=size*ss; im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    c=S/2; R=S*0.44; w=int(S*0.04)
    P=hexpts(c,c,R)
    # outer hex drawn as 6 segments with gaps at the corners (Combine plating)
    gap=0.16
    for k in range(6):
        a=P[k]; b=P[(k+1)%6]
        ax=a[0]+(b[0]-a[0])*gap; ay=a[1]+(b[1]-a[1])*gap
        bx=a[0]+(b[0]-a[0])*(1-gap); by=a[1]+(b[1]-a[1])*(1-gap)
        d.line([(ax,ay),(bx,by)],fill=WHITE,width=w)
    # corner ticks
    for k,p in enumerate(P):
        v=((p[0]-c)/R,(p[1]-c)/R)
        q1=(c+v[0]*R*1.06,c+v[1]*R*1.06); q2=(c+v[0]*R*0.94,c+v[1]*R*0.94)
        d.line([q2,q1],fill=CYAN if k in (0,3) else WHITE,width=int(w*0.8))
    # inner thin hex
    d.polygon(hexpts(c,c,R*0.78), outline=DIMW, width=int(S*0.01))
    # N of nodes, slanted stem
    s=R*0.40
    pts=[(c-s,c+s*1.05),(c-s,c-s*1.05),(c+s,c+s*1.05),(c+s,c-s*1.05)]
    lw=int(S*0.055)
    for a,b in zip(pts,pts[1:]): d.line([a,b],fill=WHITE,width=lw)
    for i,p in enumerate(pts):
        r=S*0.062
        d.ellipse([p[0]-r,p[1]-r,p[0]+r,p[1]+r],fill=WHITE)
        if i in (1,2):
            r2=r*0.55; d.ellipse([p[0]-r2,p[1]-r2,p[0]+r2,p[1]+r2],fill=CYAN)
    m=((pts[1][0]+pts[2][0])/2,(pts[1][1]+pts[2][1])/2); r=S*0.04
    d.ellipse([m[0]-r,m[1]-r,m[0]+r,m[1]+r],fill=CYAN)
    im=im.resize((size,size),Image.LANCZOS)
    if glow:
        g=im.filter(ImageFilter.GaussianBlur(size*0.03))
        a=g.split()[3].point(lambda v:int(v*0.45)); g.putalpha(a)
        tint=Image.new('RGBA',im.size,(64,190,240,0)); tint.putalpha(a)
        base=Image.new('RGBA',im.size,(0,0,0,0)); base.alpha_composite(tint); base.alpha_composite(im); im=base
    return im

def tracked(d,xy,s,font,fill,track):
    x,y=xy
    for ch in s:
        d.text((x,y),ch,font=font,fill=fill); x+=font.getlength(ch)+track
    return x

def banner(w,h,ss=3,bg=True,emb=True,tag=True):
    W,H=w*ss,h*ss
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    if bg:
        g=Image.new('RGBA',(W,H)); gd=ImageDraw.Draw(g)
        for x in range(W):
            t=x/W; gd.line([(x,0),(x,H)],fill=(int(9+10*t),int(12+16*t),int(16+24*t),255))
        # diagonal stripes on the right
        for k in range(14):
            x0=W*0.70+k*H*0.11
            gd.polygon([(x0,H),(x0+H*0.05,H),(x0+H*0.05+H*0.6,0),(x0+H*0.6,0)],fill=(64,190,240,10+k))
        # thin frame lines
        gd.line([(H*0.1,H*0.1),(W*0.35,H*0.1)],fill=(238,243,247,40),width=ss)
        gd.line([(W*0.65,H*0.9),(W-H*0.1,H*0.9)],fill=(64,190,240,90),width=ss)
        for y in range(0,H,3*ss): gd.line([(0,y),(W,y)],fill=(0,0,0,35),width=ss)
        im=Image.alpha_composite(im,g)
    d=ImageDraw.Draw(im)
    x0=H*0.14
    if emb:
        e=emblem(int(H*0.74),3); im.alpha_composite(e,(int(x0),int((H-e.size[1])/2))); x0+=e.size[0]+H*0.10
    big=ImageFont.truetype(F+'InterDisplay-Bold.otf',int(H*0.34))
    small=ImageFont.truetype(F+'Inter-SemiBold.otf',int(H*0.10))
    tf=ImageFont.truetype(F+'Inter-Bold.otf',int(H*0.085))
    tracked(d,(x0,H*0.20),'NETWORK',big,WHITE,H*0.04)
    y2=H*0.62
    end=tracked(d,(x0,y2),'HALF-LIFE: ALYX ROLEPLAY',small,(196,208,218,255),H*0.028)
    if tag:
        tx=end+H*0.08; tw=tf.getlength('CLOSED BETA')+H*0.02*10+H*0.10
        d.rounded_rectangle([tx,y2-H*0.005,tx+tw,y2+H*0.125],radius=H*0.02,outline=CYAN,width=ss*2)
        tracked(d,(tx+H*0.05,y2+H*0.012),'CLOSED BETA',tf,CYAN,H*0.02)
    return im.resize((w,h),Image.LANCZOS)

emblem(512).save(OUT+'/logo.png')
banner(1024,256).save(OUT+'/banner.png')
m=banner(1300,256,bg=False,emb=False,tag=False); m=m.crop(m.getbbox()); k=min(272/m.width,112/m.height)
m=m.resize((int(m.width*k),int(m.height*k)),Image.LANCZOS); ml=Image.new('RGBA',(288,128),(0,0,0,0))
ml.alpha_composite(m,((288-m.width)//2,(128-m.height)//2)); ml.save(OUT+'/menu_logo.png')
emblem(24,8,glow=False).save(OUT+'/icon24.png')
sheet=Image.new('RGBA',(1100,620),(40,44,50,255))
sheet.alpha_composite(Image.open(OUT+'/banner.png'),(38,20)); sheet.alpha_composite(emblem(256),(38,320))
sheet.alpha_composite(Image.open(OUT+'/menu_logo.png'),(360,380)); sheet.save(OUT+'/preview.png')
