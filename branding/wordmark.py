import sys
from PIL import Image, ImageDraw, ImageFilter
G = {  # штрихи в единичном боксе (x вправо, y вниз); w — ширина глифа
 'N': (1.0, [[(0,1),(0,0),(0.84,0.86)], [(1,0),(1,1)]]),
 'E': (0.9, [[(0,0),(0,1)], [(0.17,0),(0.9,0)], [(0.17,0.5),(0.75,0.5)], [(0.17,1),(0.9,1)]]),
 'T': (1.0, [[(0,0),(1,0)], [(0.5,0.17),(0.5,1)]]),
 'W': (1.3, [[(0,0),(0.32,1),(0.6,0.3)], [(0.7,0.3),(0.98,1),(1.3,0)]]),
 'O': (1.0, [[(0,0.3),(0,0.85),(0.15,1),(0.85,1),(1,0.85),(1,0.15),(0.85,0),(0.17,0)]]),
 'R': (1.0, [[(0,0),(0,1)], [(0.17,0),(0.85,0),(1,0.13),(1,0.37),(0.85,0.5),(0.17,0.5)], [(0.55,0.64),(1,1)]]),
 'K': (1.0, [[(0,0),(0,1)], [(1,0),(0.17,0.5)], [(0.42,0.64),(1,1)]]),
 'H': (1.0, [[(0,0),(0,1)], [(1,0),(1,1)], [(0.17,0.5),(0.83,0.5)]]),
 'A': (1.0, [[(0,1),(0.5,0),(1,1)]]),
 'L': (0.85,[[(0,0),(0,1)], [(0.17,1),(0.85,1)]]),
 'F': (0.85,[[(0,0),(0,1)], [(0.17,0),(0.85,0)], [(0.17,0.5),(0.7,0.5)]]),
 'I': (0.0, [[(0,0),(0,1)]]),
 'Y': (1.0, [[(0,0),(0.42,0.42)], [(1,0),(0.5,0.5),(0.5,1)]]),
 'X': (1.0, [[(0,0),(1,1)], [(1,0),(0.6,0.4)], [(0.4,0.6),(0,1)]]),
 'P': (1.0, [[(0,1),(0,0)], [(0.17,0),(0.85,0),(1,0.13),(1,0.37),(0.85,0.5),(0.17,0.5)]]),
 '-': (0.5, [[(0,0.5),(0.5,0.5)]]),
 ':': (0.0, [[(0,0.28),(0,0.36)], [(0,0.64),(0,0.72)]]),
 ' ': (0.6, []),
}
def text_w(s, h, track):
    return sum(G[c][0]*h for c in s) + track*h*(len(s)-1)
def draw_text(d, s, x, y, h, track, stroke, col):
    for c in s:
        w, polys = G[c]
        for p in polys:
            pts = [(x+u*h, y+v*h) for u,v in p]
            d.line(pts, fill=col, width=max(1,int(stroke)), joint="curve")
        x += w*h + track*h
    return x

def wordmark(W, Hh, top="HALF-LIFE : ALYX", big="NETWORK", sk=1.0):
    K = 4; im = Image.new("RGBA", (W*K, Hh*K), (0,0,0,0)); d = ImageDraw.Draw(im)
    pad = 0.06*W*K
    bh = Hh*K*0.36; btrack = 1.05
    bw = text_w(big, bh, btrack)
    s = min(1, (W*K-2*pad)/bw); bh*=s; bw=text_w(big,bh,btrack)
    sh = bh*0.30; strack = 0.75
    sw = text_w(top, sh, strack)
    cx = W*K/2
    ty = (Hh*K - (sh + bh*1.42))/2; by = ty + sh + bh*0.42
    col = (232,234,236,255)
    draw_text(d, top, cx-sw/2, ty, sh, strack, sh*0.16*sk, col)
    gap = sh*1.3; lw = sh*0.14*sk; ly = ty+sh/2
    d.line([(cx-bw/2, ly),(cx-sw/2-gap, ly)], fill=col, width=int(lw))
    d.line([(cx+sw/2+gap, ly),(cx+bw/2, ly)], fill=col, width=int(lw))
    draw_text(d, big, cx-bw/2, by, bh, btrack, bh*0.085*sk, col)
    # мягкая тень для читаемости на светлом фоне
    a = im.split()[3].filter(ImageFilter.GaussianBlur(K*2.5))
    shadow = Image.new("RGBA", im.size, (0,0,0,0)); shadow.putalpha(a.point(lambda v: min(255, v*0.9)))
    out = Image.new("RGBA", im.size, (0,0,0,0)); out.alpha_composite(shadow); out.alpha_composite(im)
    return out.resize((W,Hh), Image.LANCZOS)

o = sys.argv[1]
wordmark(1024, 200).save(f"{o}/watermark.png")
wordmark(288, 128, sk=1.9).save(f"{o}/logo.png")
