import json, numpy as np
from PIL import Image
from final import F
BOX={'border8':(0.22,0.40,0.78,0.70),'border6':(0.22,0.40,0.78,0.70),'shamsa':(0.12,0.45,0.88,0.78),'corners':(0.15,0.36,0.85,0.68),'field8':(0.15,0.36,0.85,0.68),'field6':(0.15,0.36,0.85,0.68),'headfoot':(0.12,0.38,0.88,0.66)}
def lin(c):
    c=c/255; return np.where(c<=0.03928,c/12.92,((c+0.055)/1.055)**2.4)
def L(rgb): r,g,b=lin(np.array(rgb,float)); return float(0.2126*r+0.7152*g+0.0722*b)
out=[]; bad=[]
for rid,mat,col,style,fin,tone,cell in F:
    im=np.asarray(Image.open(f'out/{rid}.webp').convert('RGB'),float)
    h,w,_=im.shape; x0,y0,x1,y1=BOX[style]
    box=im[int(y0*h):int(y1*h),int(x0*w):int(x1*w)].reshape(-1,3)
    bl=L(box.mean(0)); light=bl>0.18
    worst=L(np.percentile(box,5,axis=0)) if light else L(np.percentile(box,95,axis=0))
    ink=(0x1A,0x12,0x0A) if light else (0xF3,0xE6,0xC4)
    accent={'gold':(0x8A,0x63,0x1C) if light else (0xE2,0xBF,0x63),'bronze':(0x7A,0x4E,0x22),'silver':(0x4A,0x50,0x58) if light else (0xD5,0xDA,0xE0),'rose':(0x8A,0x4E,0x3C) if light else (0xEA,0xBE,0xA6),None:(0x6E,0x55,0x2A) if light else (0xE2,0xBF,0x63)}[tone]
    li=L(ink); cr=(max(li,worst)+0.05)/(min(li,worst)+0.05)
    if cr<4.5: bad.append((rid,round(cr,2)))
    out.append(dict(id=rid,style=style.rstrip('86') if style!='headfoot' else style,light=bool(light),ink='%02X%02X%02X'%ink,accent='%02X%02X%02X'%accent,bg=col.lstrip('#').upper(),contrast=round(cr,2)))
json.dump(out,open('meta.json','w'))
print('bad',bad,min(o['contrast'] for o in out),sum(o['light'] for o in out),len(out))
