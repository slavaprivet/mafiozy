from PIL import Image,ImageDraw
import json,math
rows=json.load(open('docs/ai/bruiser_visual18_geometry.json'))
im=Image.new('RGB',(1280,1000),(30,38,37));d=ImageDraw.Draw(im)
for i,row in enumerate(rows):
 for view in range(2):
  cx=i*320+160;cy=view*500+460;d.text((i*320+20,view*500+15),row['name']+(' / front' if view==0 else ' / side'),fill=(235,225,201));tris=[]
  for tri in row['triangles']:
   ps=[(p[0] if view==0 else -p[2],p[1],p[2] if view==0 else p[0]) for p in tri['p']];a=[ps[1][j]-ps[0][j] for j in range(3)];b=[ps[2][j]-ps[0][j] for j in range(3)];n=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];mag=math.sqrt(sum(x*x for x in n)) or 1
   if n[2]<0:continue
   light=.55+.45*max(0,(n[0]*-.25+n[1]*.55+n[2]*.8)/mag);color=tuple(max(0,min(255,round(c*255*light))) for c in tri['c']);tris.append((sum(p[2] for p in ps),[(cx+p[0]*210,cy-p[1]*210) for p in ps],color))
  for _,ps,color in sorted(tris,key=lambda x:x[0]):d.polygon(ps,fill=color)
im.save('docs/ai/BRUISER_VISUAL18_FRONT_SIDE.png')
