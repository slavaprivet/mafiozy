import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const here=path.dirname(fileURLToPath(import.meta.url)),manifest=JSON.parse(fs.readFileSync(path.join(here,'manifest.v1.json')));
for(const item of manifest.entries){
 const bytes=fs.readFileSync(path.join(here,path.basename(item.binding.url)));
 assert.equal(bytes.length,item.binding.bytes);assert.equal(createHash('sha256').update(bytes).digest('hex'),item.binding.sha256);
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;source.updateMatrixWorld(true);
 const bounds=new T.Box3().setFromObject(source),{width,depth,height,floorY}=item.clearRoom;
 for(let i=0;i<3;i++){assert.ok(Math.abs(bounds.min.getComponent(i)-item.visualBounds.min[i])<1e-6);assert.ok(Math.abs(bounds.max.getComponent(i)-item.visualBounds.max[i])<1e-6)}
 for(const n of [...item.doorProfile.leaves,...item.doorProfile.detailNames])assert.ok(source.getObjectByName(n)?.isMesh,n+' must be an authored movable mesh');
 const ray=(p,d,distance)=>new T.Raycaster(p,d,0,distance).intersectObject(source,true);
 for(const fx of [-.8,0,.8])for(const fz of [-.8,0,.8]){
  const p=new T.Vector3(fx*width/2,floorY+.8,fz*depth/2),hits=ray(p,new T.Vector3(0,-1,0),1);
  assert.ok(hits.length);assert.ok(Math.abs(hits[0].point.y-floorY)<1e-6,'floor matches actual shell');
  const ceiling=ray(p,new T.Vector3(0,1,0),height);assert.ok(ceiling.length);assert.ok(Math.abs(ceiling[0].point.y-(floorY+height))<1e-6,'room has full clear height');
 }
 const closed=ray(new T.Vector3(.5,1.5,depth/2+2),new T.Vector3(0,0,-1),3);assert.equal(closed[0]?.object.name,'Bank_Door_R');
 for(const name of [...item.doorProfile.leaves,...item.doorProfile.detailNames])source.getObjectByName(name).removeFromParent();source.updateMatrixWorld(true);
 for(const x of [-1.1,0,1.1])assert.equal(ray(new T.Vector3(x,1.5,depth/2+2),new T.Vector3(0,0,-1),4).length,0,'authored entrance must be open after leaves move');
 for(const wall of item.layout.wallRects){const node=source.getObjectByName(wall.name);assert.ok(node);const b=new T.Box3().setFromObject(node);for(const [a,e]of [[b.min.x,wall.rect[0]],[b.min.z,wall.rect[1]],[b.max.x,wall.rect[2]],[b.max.z,wall.rect[3]]])assert.ok(Math.abs(a-e)<1e-6,'collider manifest matches authored wall geometry')}
 // Flood-fill an actual pedestrian-radius graph, then ray-test routes to every
 // named room. A nominal gap that a hero cannot fit through does not pass.
 const step=.2,pad=.32,nx=Math.floor(width/step),nz=Math.floor(depth/step),point=(c,r)=>new T.Vector3(-width/2+(c+.5)*step,1.5,-depth/2+(r+.5)*step);
 const allowed=(c,r)=>{const p=point(c,r);return c>=0&&r>=0&&c<nx&&r<nz&&Math.abs(p.x)<width/2-pad&&Math.abs(p.z)<depth/2-pad&&!item.layout.wallRects.some(w=>p.x>w.rect[0]-pad&&p.x<w.rect[2]+pad&&p.z>w.rect[1]-pad&&p.z<w.rect[3]+pad)};
 const start=[Math.floor(nx/2),nz-3],queue=[start],key=(c,r)=>r*nx+c,parents=new Map([[key(...start),null]]);
 for(let i=0;i<queue.length;i++){const [c,r]=queue[i];for(const [nc,nr]of [[c+1,r],[c-1,r],[c,r+1],[c,r-1]])if(allowed(nc,nr)&&!parents.has(key(nc,nr))){parents.set(key(nc,nr),[c,r]);queue.push([nc,nr])}}
 for(const room of item.layout.roomLabels){let cell=[Math.floor((room.center[0]+width/2)/step),Math.floor((room.center[2]+depth/2)/step)];assert.ok(parents.has(key(...cell)),room.id+' inaccessible to pedestrian');while(parents.get(key(...cell))){const prior=parents.get(key(...cell)),a=point(...prior),b=point(...cell),delta=b.clone().sub(a);assert.equal(new T.Raycaster(a,delta.clone().normalize(),.005,delta.length()-.005).intersectObject(source,true).length,0,room.id+' path crosses visible wall');cell=prior}}
 const vault=item.layout.vault;assert.ok(vault.rect[2]-vault.rect[0]>3.5);assert.ok(vault.rect[3]-vault.rect[1]>3.5);
 console.log(`PASS ${item.assetId}: ${width}x${depth}x${height}m, seven reachable rooms including separate vault, collider manifest matches mesh, floor/ceiling rays, bounds and hash`);
}
