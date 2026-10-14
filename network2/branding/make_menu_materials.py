"""Main menu materials for network2 (materials/network2/menu/*.png): button backgrounds (normal,
hover) - a dark plate fading out to the left with a cyan edge on the right - and a vignette."""
import sys, os, math
import numpy as np
from PIL import Image
OUT=sys.argv[1]; os.makedirs(OUT, exist_ok=True)
W,H=512,64
x=np.linspace(0,1,W)[None,:].repeat(H,0)
y=np.linspace(0,1,H)[:,None].repeat(W,1)
def button(hover):
    a=(x**1.6)*(200 if hover else 150)
    rgb=np.zeros((H,W,3)); rgb[...]= (14,18,23)
    if hover:
        tint=(x**2)[...,None]*np.array([40,120,160])*0.35
        rgb=rgb+tint
    # thin lines top / bottom
    a[0:1,:]=np.maximum(a[0:1,:],(x[0]**1.2)*(110 if hover else 50))
    a[H-1:,:]=np.maximum(a[H-1:,:],(x[0]**1.2)*(110 if hover else 50))
    img=np.dstack([rgb,a]).clip(0,255).astype(np.uint8)
    im=Image.fromarray(img,'RGBA').copy()
    # cyan edge bar on the right
    bw=6 if hover else 3
    px=im.load()
    for yy in range(6,H-6):
        for xx in range(W-bw,W):
            px[xx,yy]=(64,190,240,255 if hover else 200)
    return im
button(False).save(OUT+'/button.png'); button(True).save(OUT+'/button_hover.png')
S=256
yy,xx=np.mgrid[0:S,0:S]
r=np.sqrt(((xx-S/2)/(S/2))**2+((yy-S/2)/(S/2))**2)
a=(np.clip((r-0.45)/0.75,0,1)**1.6*230).astype(np.uint8)
v=np.zeros((S,S,4),np.uint8); v[...,3]=a
Image.fromarray(v,'RGBA').save(OUT+'/vignette.png')
# preview
bg=Image.new('RGBA',(640,260),(90,96,104,255))
b=button(False); h=button(True)
for i,im in enumerate((b,h,b)):
    bg.alpha_composite(im.resize((420,52)),(640-420,40+i*64))
bg.save(OUT+'/preview.png')
