"""Offline z-buffer sheet of actual game geometry; not a browser screenshot."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root=Path('docs/city-rebuild/artist15-cast-qa')
rows=json.loads((root/'meshes.json').read_text(encoding='utf-8'))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)

def raster(row,bust=False):
    w,h=260,340
    v=np.array(row['vertices']).reshape(-1,3)
    colors=np.array(row['colors']).reshape(-1,3)
    tris=np.array(row['triangles']).reshape(-1,3)
    yaw=.10
    x=v[:,0]*np.cos(yaw)+v[:,2]*np.sin(yaw)
    z=v[:,2]*np.cos(yaw)-v[:,0]*np.sin(yaw)
    if bust:
        floor=v[:,1].min()+(v[:,1].max()-v[:,1].min())*.48
        scale=min((h-22)/(v[:,1].max()-floor),(w-26)/(x[v[:,1]>=floor].max()-x[v[:,1]>=floor].min()))
    else:
        floor=-.04
        scale=(h-24)/2.2
    px=x*scale+w/2
    py=h-12-(v[:,1]-floor)*scale
    depth=np.full((h,w),-np.inf)
    image=np.empty((h,w,3)); image[:]=[.105,.13,.15]
    light=np.array([-.40,.75,.8]); light/=np.linalg.norm(light)
    for tri in tris:
        tx,ty=px[tri],py[tri]
        xa,xb=max(0,int(np.floor(tx.min()))),min(w-1,int(np.ceil(tx.max())))
        ya,yb=max(0,int(np.floor(ty.min()))),min(h-1,int(np.ceil(ty.max())))
        if xa>xb or ya>yb:continue
        den=(ty[1]-ty[2])*(tx[0]-tx[2])+(tx[2]-tx[1])*(ty[0]-ty[2])
        if abs(den)<1e-8:continue
        yy,xx=np.mgrid[ya:yb+1,xa:xb+1]
        a=((ty[1]-ty[2])*(xx-tx[2])+(tx[2]-tx[1])*(yy-ty[2]))/den
        b=((ty[2]-ty[0])*(xx-tx[2])+(tx[0]-tx[2])*(yy-ty[2]))/den
        c=1-a-b
        zz=a*z[tri[0]]+b*z[tri[1]]+c*z[tri[2]]
        target=depth[ya:yb+1,xa:xb+1]
        mask=(a>=-.002)&(b>=-.002)&(c>=-.002)&(zz>target)
        if not mask.any():continue
        normal=np.cross(v[tri[1]]-v[tri[0]],v[tri[2]]-v[tri[0]])
        normal/=max(1e-10,np.linalg.norm(normal))
        shade=.55+.45*abs(np.dot(normal,light))
        rgb=(a[...,None]*colors[tri[0]]+b[...,None]*colors[tri[1]]+c[...,None]*colors[tri[2]])*shade
        image[ya:yb+1,xa:xb+1][mask]=rgb[mask]
        target[mask]=zz[mask]
    return Image.fromarray(np.uint8(np.clip(image,0,1)*255))

for bust,name in [(False,'cast'),(True,'portraits')]:
    sheet=Image.new('RGB',(5*280,4*398+54),'#141d22')
    draw=ImageDraw.Draw(sheet)
    draw.text((18,17),'ХУДОЖНИК 15 / '+('ПОРТРЕТЫ' if bust else '19 БОССОВ / ОБЩИЙ МАСШТАБ'),font=font,fill='#d9c89f')
    for i,row in enumerate(rows):
        x,y=(i%5)*280+10,(i//5)*398+50
        shot=raster(row,bust)
        shot.save(root/(row['leaderId']+('-portrait.png' if bust else '-full.png')))
        sheet.paste(shot,(x,y))
        draw.text((x+2,y+346),row['name'],font=font,fill='#f2ead9')
        draw.text((x+2,y+369),str(row['height'])+' м',font=small,fill='#b3bdbd')
    sheet.save(root/(name+'.png'))
    print('Saved',name,flush=True)
