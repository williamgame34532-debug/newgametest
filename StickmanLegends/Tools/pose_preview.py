# Предпросмотр поз из Body.cs без Unity: python3 Tools/pose_preview.py [ИмяПозы ...]
# Рисует позы (красный — передние конечности, тёмно-красный — задние) в poses_preview.png.
# Нужен Pillow: pip install pillow
import math, re
from PIL import Image, ImageDraw
import os, sys
src=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','Assets','Scripts','Body.cs'),encoding='utf-8').read()
poses={}
for m in re.finditer(r'public static readonly Pose (\w+) = new Pose\(([^)]*)\)', src):
    poses[m.group(1)]=[float(x.strip().rstrip('f')) for x in m.group(2).split(',')]
# пропорции = Skel в Body.cs (Torso, Upper, Fore, Thigh, Shin, HeadR, Width)
T,U,F,TH,SH,HR,W=0.93,0.48,0.46,0.62,0.62,0.29,0.21
def down(d,f): r=math.radians(d); return (math.sin(r)*f,-math.cos(r))
def comp(p,f=1):
    lean,a1,a2,b1,b2,f1,f2,k1,k2=p
    t1=down(f1,f);t2=down(f2,f);u1=down(k1,f);u2=down(k2,f)
    drop=max(-(t1[1]*TH+t2[1]*SH),-(u1[1]*TH+u2[1]*SH),0.25)
    hip=(0,drop); d=down(lean,f); up=(d[0],-d[1])
    neck=(hip[0]+up[0]*T,hip[1]+up[1]*T)
    hd=down(lean*1.25,f); head=(neck[0]+hd[0]*HR*1.1,neck[1]-hd[1]*HR*1.1)
    sh=(neck[0]-up[0]*.06,neck[1]-up[1]*.06)
    add=lambda a,v,l:(a[0]+v[0]*l,a[1]+v[1]*l)
    e1=add(sh,down(a1,f),U);h1=add(e1,down(a2,f),F);e2=add(sh,down(b1,f),U);h2=add(e2,down(b2,f),F)
    kn1=add(hip,t1,TH);ft1=add(kn1,t2,SH);kn2=add(hip,u1,TH);ft2=add(kn2,u2,SH)
    return dict(hip=hip,neck=neck,head=head,sh=sh,e1=e1,h1=h1,e2=e2,h2=h2,k1=kn1,f1=ft1,k2=kn2,f2=ft2)
def run(p,ninja=False):
    s=math.sin(p);c=math.cos(p);th1=42*s+5;th2=-42*s+5;kb1=20+55*max(0,-c);kb2=20+55*max(0,c)
    if ninja: return [28,-70,-55,-75,-60,th1,th1-kb1,th2,th2-kb2]
    return [15,-35*s+25,-35*s+105,35*s+25,35*s+105,th1,th1-kb1,th2,th2-kb2]
names=sys.argv[1:] or ['Guard','GuardBlade','GuardGun','Block','Hurt','Victory','Cast','PunchS','KickS','SlashW','SlashS','SmashW','StabS','ThrowW','Dash','AirUp','AirDown']
items=[(n,poses[n]) for n in names]+[('Run0',run(0)),('Run1.5',run(1.5)),('Run3',run(3)),('Ninja',run(1,True))]
cols=7; cw=200; ch=230; img=Image.new('RGB',(cols*cw,((len(items)+cols-1)//cols)*ch),(240,238,230)); dr=ImageDraw.Draw(img)
S=70
for i,(n,p) in enumerate(items):
    ox=(i%cols)*cw+cw//2; oy=(i//cols)*ch+ch-30
    J=comp(p)
    P=lambda q:(ox+q[0]*S, oy-q[1]*S)
    dr.line([(ox-80,oy),(ox+80,oy)],fill=(0,0,0),width=2)
    w=int(W*S)
    def L(pts,c): 
        dr.line([P(q) for q in pts],fill=c,width=w,joint='curve')
        for q in pts: x,y=P(q); dr.ellipse([x-w/2,y-w/2,x+w/2,y+w/2],fill=c)
    L([J['hip'],J['k2'],J['f2']],(140,40,40)); L([J['sh'],J['e2'],J['h2']],(140,40,40))
    L([J['hip'],J['neck']],(210,20,20)); x,y=P(J['head']); r=HR*S; dr.ellipse([x-r,y-r,x+r,y+r],fill=(210,20,20))
    L([J['hip'],J['k1'],J['f1']],(210,20,20)); L([J['sh'],J['e1'],J['h1']],(210,20,20))
    # weapon along forearm
    e,h=J['e1'],J['h1']; dx,dy=h[0]-e[0],h[1]-e[1]; l=math.hypot(dx,dy); 
    if n.startswith(('GuardBlade','Slash','Smash')): dr.line([P(h),P((h[0]+dx/l*1.0,h[1]+dy/l*1.0))],fill=(120,120,140),width=5)
    dr.text((ox-90,oy-ch+40),n+' (facing ->)',fill=(0,0,0))
img.save('poses_preview.png'); print('ok')
