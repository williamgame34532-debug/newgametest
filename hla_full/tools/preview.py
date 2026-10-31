from check import run,lib,L
from PIL import Image, ImageDraw, ImageFont
import ctypes, pathlib
fontsizes={'cfr_hdr':26,'cfr_xs':14,'cfr_xxs':11,'cfr_s':17,'cfr_m':22,'cfr_row':21,'cfr_l':32,'cfr_num':42,'cfr_big':46}
fonts={k:ImageFont.truetype('garrysmod/addons/hla_fabricator_content/resource/fonts/RobotoCondensed-Bold.ttf',v) for k,v in fontsizes.items()}
lib.lua_pushnumber.argtypes=[ctypes.c_void_p,ctypes.c_double]
lib.lua_pushcclosure.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int]
lib.lua_setglobal.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
@ctypes.CFUNCTYPE(ctypes.c_int,ctypes.c_void_p)
def measure(state):
 s=lib.lua_tolstring(state,1,None).decode();font=lib.lua_tolstring(state,2,None).decode()
 lib.lua_pushnumber(state,fonts[font].getlength(s));lib.lua_pushnumber(state,fontsizes[font]);return 2
lib.lua_pushcclosure(L,measure,0);lib.lua_setglobal(L,b'fontmeasure')
pathlib.Path('qa').mkdir(exist_ok=True)
run('''
local file=assert(io.open('qa/ui.tsv','w'))
local function emit(kind,...)
 local a={kind,...}; for i,v in ipairs(a) do a[i]=tostring(v) end
 file:write(table.concat(a,'\\t')..'\\n')
end
local function col(c) return table.concat(c,',') end
local D={size=fontmeasure}
function D.rect(x,y,w,h,c) emit('rect',x,y,w,h,col(c)) end
function D.outline(x,y,w,h,c,t) emit('outline',x,y,w,h,col(c),t or 1) end
function D.line(x,y,a,b,c) emit('line',x,y,a,b,col(c)) end
function D.poly(p,c) local a={} for _,v in ipairs(p) do a[#a+1]=v[1] a[#a+1]=v[2] end emit('poly',table.concat(a,','),col(c)) end
function D.text(s,f,x,y,c,ax,ay) emit('text',s,f,x,y,col(c),ax or 0,ay or 0) end
function D.barcode(x,y,w,h,c) emit('barcode',x,y,w,h,col(c)) end
for i,ctx in ipairs({
 {stage=1,tab=2,hover={id='select',arg=6}},
 {stage=2,paid=18,cost=35},
 {stage=3,printFrac=0.56},
 {stage=4},
 {stage=1,boot=0.6},
 {stage=2,paid=35,cost=35}
}) do
 emit('page',i)
 ctx.t=1.5;ctx.resin=85;ctx.sel=6;ctx.tab=ctx.tab or 2
 CFRework.UI.Draw(D,ctx)
end
file:close()
''')
imgs=[];im=None
for line in pathlib.Path('qa/ui.tsv').read_text().splitlines():
 a=line.split('\t');kind=a.pop(0)
 if kind=='page':
  im=Image.new('RGBA',(1024,512));imgs.append(im);continue
 overlay=Image.new('RGBA',im.size);d=ImageDraw.Draw(overlay)
 def color(s):return tuple(max(0,min(255,round(float(x)))) for x in s.split(','))
 if kind in ['rect','outline','line','barcode']:
  x,y,w,h=map(float,a[:4]);c=color(a[4])
  if kind=='rect':d.rectangle((x,y,x+w,y+h),fill=c)
  elif kind=='outline':d.rectangle((x,y,x+w,y+h),outline=c,width=int(float(a[5])))
  elif kind=='line':d.line((x,y,w,h),fill=c)
  else:
   bc=Image.open('garrysmod/addons/hla_fabricator_content/materials/cf_rework/ui/barcode.png').convert('RGBA').resize((int(w),int(h)));overlay.paste(bc,(int(x),int(y)),bc)
 elif kind=='poly':
  vals=list(map(float,a[0].split(',')));d.polygon(list(zip(vals[::2],vals[1::2])),fill=color(a[1]))
 elif kind=='text':
  s,f=a[:2];x,y=map(float,a[2:4]);ax,ay=map(int,a[5:7]);font=fonts[f];w=font.getlength(s);h=fontsizes[f]
  d.text((x-w*ax/2,y-h*ay/2),s,font=font,fill=color(a[4]),anchor='lt')
 im.alpha_composite(overlay)
board=Image.new('RGB',(1280,3*350),(12,19,24));d=ImageDraw.Draw(board)
labels=['01 / КАТАЛОГ','02 / ЗАГРУЗКА СМОЛЫ','03 / СИНТЕЗ','04 / ГОТОВО К ВЫДАЧЕ','05 / ЗАПУСК','06 / СМОЛА ЗАГРУЖЕНА']
for i,im in enumerate(imgs):
 x=i%2*640;y=i//2*350;board.paste(im.convert('RGB').resize((614,307)),(x+13,y+30));d.text((x+14,y+8),labels[i],font=fonts['cfr_xs'],fill=(136,208,222))
board.save('qa/fabricator_screens.png')
for i,im in enumerate(imgs): im.save('qa/page_%d.png'%(i+1))
