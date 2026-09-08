import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createBuildingEntry} from './building_entry.mjs';
import {BUILDING_ROOM_PROFILES} from './building_room_profiles.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';
import {movePedestrian,circleFits} from './walk_motion.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),read=f=>JSON.parse(fs.readFileSync(path.join(here,f))),placement=read('buildings_placement.v1.json'),topology=read('topology_for_placement.json'),rows=[];
const visible=n=>{for(let p=n;p;p=p.parent)if(!p.visible)return false;return true};
function inside(x,z,poly){let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])hit=!hit}return hit}
for(const assetId of Object.keys(BUILDING_ROOM_PROFILES)){
 const items=placement.instances.filter(i=>i.assetId===assetId),bytes=fs.readFileSync(path.join(root,items[0].binding.url.slice(1))),loader=new GLTFLoader().register(()=>({name:'ROOM_TEST_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())})),source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 let area=0;
 for(const item of items){
  const group=new T.Group(),visual=source.clone(true),t=item.transform;visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);group.add(visual);group.updateMatrixWorld(true);
  visual.traverse(n=>{if(/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name)||(item.hideNodeNames??[]).some(name=>name.replace(/\./g,'')===n.name))n.visible=false});
  const facadeGeometry=new Map();visual.traverse(n=>{if(/^Small_Interior_/.test(n.name)||/^CANON_WINDOW.*(?:INTERIO|FURNITUR|WARM_)/.test(n.name))facadeGeometry.set(n,n.geometry)});
  const entry=createBuildingEntry({THREE:T,visual,instance:item}),r=entry.report.room;area=r.area;
  assert.ok(entry.contentRoot);assert.equal(entry.contentRoot.children.length,0);assert.equal(entry.contentRoot.userData.buildingInstanceId,item.id);assert.equal(entry.contentRoot.name,`Building_Content_${item.id}`);
  for(const [n,g]of facadeGeometry)assert.equal(n.geometry,g,'authored facade interior must be retained '+n.name);
  const firstBodies=entry.getCollisionBodies();assert.equal(entry.getCollisionBodies(),firstBodies,'cache stable at rest');const approach=entry.approachPoint();assert.equal(entry.interact(approach).accepted,true);
  entry.update(.1,approach);assert.notEqual(entry.getCollisionBodies(),firstBodies,'cache invalidates on door movement');for(let i=0;i<10;i++)entry.update(.1,approach);
  const openBodies=entry.getCollisionBodies();entry.update(.1,approach);assert.equal(entry.getCollisionBodies(),openBodies,'cache stable when fully open');
  const floor=(x,z)=>entry.floorHeight(x,z)??0,allowed=(x,z)=>!!topology.walkableMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)]&&!entry.getCollisionBodies().some(b=>(b.maxYM??1e6)>=floor(x,z)+.05&&(b.minYM??0)<=floor(x,z)+1.9&&inside(x/4.1,z/4.1,b.polygonCR));
  const center=entry.roomCenterPoint(),start=entry.roomPoint();assert.ok(entry.containsInterior(center));assert.ok(circleFits(center.x,center.z,allowed));
  const move=(a,b)=>{const result=movePedestrian(a,b.clone().sub(a),allowed);assert.ok(Math.hypot(result.x-b.x,result.z-b.z)<1e-5,`${item.id} room route blocked`)};move(start,center);
  for(const fx of [.2,.5,.8])for(const fz of [.2,.5,.8]){
   const p=entry.object.localToWorld(new T.Vector3(r.minX+(r.maxX-r.minX)*fx,assetId==='strip_club'?.45:0,r.minZ+(r.maxZ-r.minZ)*fz));
   assert.ok(entry.containsInterior(p),item.id+' room bounds');assert.ok(circleFits(p.x,p.z,allowed),item.id+' room cell');move(center,p);move(p,center);
   const y=floor(p.x,p.z);assert.ok(Math.abs(y-center.y)<1e-5,item.id+' room floor discontinuity');
   const ray=new T.Raycaster(new T.Vector3(p.x,y+.7,p.z),new T.Vector3(0,-1,0),0,1.2),hit=ray.intersectObject(visual,true).find(h=>visible(h.object));assert.ok(hit,item.id+' floor has no mesh');assert.ok(Math.abs(hit.point.y-y)<.015,item.id+' floor sample does not match actual geometry '+hit.object.name);
   const origin=center.clone();origin.y+=1.3;const end=p.clone();end.y=origin.y;const distance=end.distanceTo(origin);if(distance>.01){const ray=new T.Raycaster(origin,end.clone().sub(origin).normalize(),.01,distance-.015),hits=ray.intersectObject(visual,true).filter(h=>visible(h.object));assert.equal(hits.length,0,item.id+' room hidden visual wall '+hits.map(h=>h.object.name).join(','))}
  }
  // Sample the actual ramp in source entry coordinates across exact endpoint
  // boundaries, including translated/yaw-rotated instances.
  const strip=assetId==='strip_club',z0=strip?5.1:0,z1=strip?7.4:Math.max(2.2,entry.report.floorY*4.5),support=createSurfaceMotion();
  const point=z=>entry.object.localToWorld(new T.Vector3(0,0,z));let top=point(z0);top.y=floor(top.x,top.z);support.reset(top);let previous=top.y;
  for(let i=1;i<=90;i++){const p=point(z0+(z1-z0+.05)*i/90),next=support.update({x:p.x,z:p.z,dt:1/60,floorHeight:floor});assert.equal(next.blocked,false);assert.ok(next.y<=previous+.015,item.id+' downhill surface bumps');assert.ok(Math.abs(next.y-previous)<.065,item.id+' ramp pop');previous=next.y}
  for(let i=89;i>=0;i--){const p=point(z0+(z1-z0+.05)*i/90),next=support.update({x:p.x,z:p.z,dt:1/60,floorHeight:floor});assert.equal(next.blocked,false,item.id+' uphill blocked');assert.ok(Math.abs(next.y-previous)<.065,item.id+' uphill pop');previous=next.y}
  if(strip)for(const [x,z]of [[6.55,0],[-6.55,0],[6.5,5],[-6.5,-5]]){
   const p=entry.object.localToWorld(new T.Vector3(x,0,z)),y=entry.floorHeight(p.x,p.z);assert.ok(y!==null,'authored platform bevel is supported');
   const ray=new T.Raycaster(new T.Vector3(p.x,y+.5,p.z),new T.Vector3(0,-1,0),0,1),hit=ray.intersectObject(visual,true).find(h=>visible(h.object));assert.ok(hit);assert.ok(Math.abs(hit.point.y-y)<1e-5,'bevel floor sampler equals actual GLB triangle');
  }
  entry.dispose();assert.equal(visual.getObjectByName(`Building_Content_${item.id}`),undefined);
 }
 rows.push({assetId,placements:items.length,roomAreaM2:+area.toFixed(2)});console.log(`PASS ${assetId}: ${items.length} rooms, ${area.toFixed(2)} m2, deep navigation/floor rays, ramp both directions, cache and facade preserved`);
}
console.log(JSON.stringify(rows));console.log('PASS all 72 rooms / 19 types. LIVE visual review remains separate.');
