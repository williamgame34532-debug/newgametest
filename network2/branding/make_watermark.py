import math, sys
from PIL import Image, ImageDraw, ImageFont
F='/usr/share/fonts/opentype/inter/'
OUT=sys.argv[1] if len(sys.argv)>1 else 'out2'
SS=4
W,H=1024*SS,256*SS
COL=(225,232,238,255); CY=(64,190,240,255)

def glyphs(d, x, y, h, t, ch):
    """thin geometric letters; returns advance width"""
    w=h*0.82
    L=lambda a,b: d.line([a,b],fill=COL,width=int(t))
    def bar(x0,y0,x1,y1): d.rectangle([x0,y0,x1,y1],fill=COL)
    if ch=='N':
        bar(x,y,x+t,y+h); bar(x+w-t,y,x+w,y+h)
        d.polygon([(x,y),(x+t*1.4,y),(x+w,y+h),(x+w-t*1.4,y+h)],fill=COL)
    elif ch=='E':
        bar(x,y,x+w,y+t); bar(x+w*0.12,y+h/2-t/2,x+w,y+h/2+t/2); bar(x,y+h-t,x+w,y+h)
    elif ch=='T':
        bar(x,y,x+w,y+t); bar(x+w/2-t/2,y,x+w/2+t/2,y+h)
    elif ch=='W':
        w=h*1.15
        pts=[(x,y),(x+w*0.25,y+h),(x+w*0.5,y+h*0.25),(x+w*0.75,y+h),(x+w,y)]
        for a,b in zip(pts,pts[1:]):
            d.polygon([(a[0]-t*0.6,a[1]),(a[0]+t*0.6,a[1]),(b[0]+t*0.6,b[1]),(b[0]-t*0.6,b[1])],fill=COL)
    elif ch=='O':
        d.rounded_rectangle([x,y,x+w,y+h],radius=h*0.18,outline=COL,width=int(t))
    elif ch=='R':
        bar(x,y,x+t,y+h)
        d.rounded_rectangle([x,y,x+w,y+h*0.55],radius=h*0.16,outline=COL,width=int(t))
        d.rectangle([x+t,y+t,x+w*0.5,y+h*0.55-t],fill=(0,0,0,0))
        d.polygon([(x+w*0.45,y+h*0.55-t),(x+w*0.45+t*1.5,y+h*0.55-t),(x+w,y+h),(x+w-t*1.5,y+h)],fill=COL)
    elif ch=='K':
        bar(x,y,x+t,y+h)
        d.polygon([(x+t,y+h*0.5-t*0.7),(x+t,y+h*0.5+t*0.7),(x+w,y),(x+w-t*1.6,y)],fill=COL)
        d.polygon([(x+w*0.30,y+h*0.40),(x+w*0.30+t*1.3,y+h*0.40-t*0.6),(x+w,y+h),(x+w-t*1.6,y+h)],fill=COL)
    return w

im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
h=H*0.38; t=h*0.095; gap=h*0.6
word='NETWORK'
# measure
tmp=Image.new('RGBA',(10,10)); td=ImageDraw.Draw(tmp)
widths=[ (h*1.15 if c=='W' else h*0.82) for c in word]
total=sum(widths)+gap*(len(word)-1)
x=W-total-H*0.03; y=H*0.36
for c,wc in zip(word,widths):
    glyphs(d,x,y,h,t,c); x+=wc+gap
left=W-total-H*0.03
# top line with CLOSED BETA
small=ImageFont.truetype(F+'Inter-Light.otf' if __import__('os').path.exists(F+'Inter-Light.otf') else F+'Inter-Regular.otf',int(H*0.105))
label='C L O S E D   B E T A'
lw=small.getlength(label)
ly=H*0.19
cx=left+total*0.66
d.text((cx-lw/2,ly-H*0.06),label,font=small,fill=COL)
lt=max(2,int(SS*1.5))
d.rectangle([left,ly-lt/2,cx-lw/2-H*0.05,ly+lt/2],fill=COL)
# a cyan tick where the top line starts
d.rectangle([left,ly-lt*1.5,left+H*0.22,ly+lt*1.5],fill=CY)
d.rectangle([cx+lw/2+H*0.05,ly-lt/2,W-H*0.03,ly+lt/2],fill=COL)
# bottom: WORK IN PROGRESS, right, cyan accent
sub=ImageFont.truetype(F+'Inter-SemiBold.otf',int(H*0.10))
s2='W O R K   I N   P R O G R E S S'
sw=sub.getlength(s2)
by=H*0.80
# a dark plate under the subtitle so it reads on bright scenes too
d.rectangle([W-H*0.03-sw-H*0.05,by-H*0.005,W-H*0.01,by+H*0.135],fill=(10,14,18,150))
d.text((W-H*0.03-sw,by),s2,font=sub,fill=(242,246,250,255))
d.rectangle([W-H*0.03-sw-H*0.24,by+H*0.055,W-H*0.03-sw-H*0.08,by+H*0.055+lt*2],fill=CY)
# the letters a touch lighter at the top (a soft vertical gradient)
import numpy as np
from PIL import ImageFilter
arr=np.asarray(im).astype(np.float32)
grad=np.linspace(1.0,0.82,H)[:,None]
white=(arr[...,0]>200)&(arr[...,2]>200)
for c in range(3):
    arr[...,c]=np.where(white,arr[...,c]*grad,arr[...,c])
im=Image.fromarray(arr.clip(0,255).astype(np.uint8),'RGBA')
# a soft dark shadow under everything: readable on bright scenes
shadow=Image.new('RGBA',(W,H),(0,0,0,0))
sa=im.split()[3].filter(ImageFilter.GaussianBlur(SS*6)).point(lambda v:int(v*0.55))
shadow.putalpha(sa)
im=Image.alpha_composite(shadow,im)
im=im.resize((1024,256),Image.LANCZOS)
# overall translucency like the reference
a=im.split()[3].point(lambda v:int(v*0.88)); im.putalpha(a)
im.save(OUT+'/watermark.png')
bg=Image.open('/tmp/claude-0/-home-user/f9cb79b8-f8d0-5996-8358-b117c21f9226/images/ref.png').convert('RGBA') if False else Image.new('RGBA',(1280,720),(30,32,40,255))
g=ImageDraw.Draw(bg)
for yy in range(720): g.line([(0,yy),(1280,yy)],fill=(25+yy//40,27+yy//40,36+yy//30,255))
k=1280*0.42/1024; m=im.resize((int(1024*k),int(256*k)),Image.LANCZOS)
bg.alpha_composite(m,(1280-m.width-10,720-m.height-12)); bg.save(OUT+'/watermark_mock.png')
