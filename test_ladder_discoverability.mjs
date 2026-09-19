import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import path from 'node:path';
import {createLadderClimbController,roofLadderDescriptor,createRoofLadder} from './assets/maps/city_rebuild_v1/roof_ladder.mjs';
import {createSurfaceMotion} from './assets/maps/city_rebuild_v1/surface_motion.mjs';
const root=path.dirname(fileURLToPath(import.meta.url)),base=root+'/assets/maps/city_rebuild_v1',vendor=(process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor').replace(/[\\/]+$/,'')+'/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const {createWindowedBuildingEntry}=await import(pathToFileURL(base+'/building_window_integration.mjs')),{createBuildingStoreys}=await import(pathToFileURL(base+'/building_storeys.mjs'));
const {BUILDING_STOREY_PROFILES}=await import(pathToFileURL(base+'/building_storey_profiles.mjs'));
const plan=JSON.parse(fs.readFileSync(base+'/buildings_placement.v1.json')),results=[];
const inside=(x,z,poly)=>{let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])hit=!hit}return hit};
const visible=n=>{for(let p=n;p;p=p.parent)if(!p.visible||p.userData.ladderDecor||(process.env.ROOF_IGNORE_PARAPET&&/parapet/i.test(p.name)))return false;return true};
const vec=p=>new T.Vector3(p.x,p.y,p.z);
// One representative of every authored building type with a storey profile.
// The runtime applies the same rear ladder/roof-cover policy to every instance;
// keeping the audit representative-based makes the GLB traversal check fast.
const selectedAssets=new Set(),roofInstances=[];
for(const item of plan.instances){if(!BUILDING_STOREY_PROFILES[item.assetId]?.floors?.length||(!process.env.LADDER_APPROACH_ALL&&selectedAssets.has(item.assetId)))continue;selectedAssets.add(item.assetId);roofInstances.push(item)}
const routeAudited=new Set(['pawnshop','gun_shop','bookmaker','bank_large_shell_v1','bank_medium_shell_v1','bank_small_shell_v1','strip_club']);
for(const item of roofInstances){
 const record={id:item.id,status:'RUNNING',bodyBlockers:[],meshBlockers:[],samples:0};results.push(record);let applied,storeys;
 try{
 const bytes=fs.readFileSync(root+item.binding.url),loader=new GLTFLoader().register(()=>({name:'ROOF_TEST_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())})),visual=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 visual.traverse(n=>{if(/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name)||(item.hideNodeNames??[]).includes(n.name))n.visible=false});
 const parent=new T.Group(),t=item.transform;parent.add(visual);visual.position.fromArray(t.modelLocalOffsetM??[0,0,0]);parent.position.fromArray(t.positionM);parent.rotation.y=t.yawDegrees*Math.PI/180;parent.scale.setScalar(t.uniformScale??1);parent.updateMatrixWorld(true);
 applied=createWindowedBuildingEntry({THREE:T,visual,instance:item,metresPerCell:4.1});const entry=applied.entry;storeys=entry.storeys??createBuildingStoreys({THREE:T,entry,visual,instance:item,metresPerCell:4.1});parent.updateMatrixWorld(true);let d=storeys.ladder?.worldDescriptor;assert(d,'selected roof descriptor');if(process.env.ROOF_REAR&&item.role!=='bank_shell'){const rr=storeys.roof.rect,frame=storeys.root,baseY=frame.getWorldPosition(new T.Vector3()).y,x=rr[2]-1.6,local=roofLadderDescriptor({id:item.id,lower:{x,y:-baseY,z:rr[1]-.85},upper:{x,y:storeys.roof.y,z:rr[1]+1.05},outward:{x:0,z:-1}}),world=p=>frame.localToWorld(vec(p)),normal=new T.Vector3(0,0,-1).transformDirection(frame.matrixWorld),right=new T.Vector3(-1,0,0).transformDirection(frame.matrixWorld);d={...local,lower:world(local.lower),upper:world(local.upper),path:local.path.map(world),normal,right,yaw:Math.atan2(-normal.x,-normal.z)}}if(process.env.ROOF_OFFSET&&item.role!=='bank_shell'){const shift=Number(process.env.ROOF_OFFSET);for(const p of [d.lower,d.path[0],d.path[1]]){p.x+=d.normal.x*shift;p.z+=d.normal.z*shift}}record.lower=d.lower;record.upper=d.upper; const original=storeys.ladder.object;const ancestorVisible=n=>{for(let p=n;p;p=p.parent)if(!p.visible)return false;return true};assert(ancestorVisible(original),'actual ladder ancestors visible');record.actualRenderMeshes=original.children.length;record.actualVisible=original.children.every(ancestorVisible);const decorated=createRoofLadder(T,{...storeys.ladder.descriptor,outward:storeys.ladder.descriptor.normal});storeys.root.add(decorated.object);parent.updateMatrixWorld(true);assert.deepEqual(decorated.descriptor.path,storeys.ladder.descriptor.path,'route unchanged');record.stagedRenderMeshes=decorated.object.children.length;assert.equal(record.stagedRenderMeshes,3);assert(decorated.object.getObjectByName('RoofAccessSigns'));const box=new T.Box3().setFromObject(decorated.object),camera=new T.PerspectiveCamera(55,1.5,.1,100);camera.position.copy(vec(d.lower)).add(new T.Vector3(d.normal.x*8,2,d.normal.z*8));camera.lookAt(box.getCenter(new T.Vector3()));camera.updateMatrixWorld(true);const frustum=new T.Frustum().setFromProjectionMatrix(new T.Matrix4().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse));record.camera=camera.position.toArray();record.lookAt=box.getCenter(new T.Vector3()).toArray();assert(decorated.object.children.every(mesh=>frustum.intersectsObject(mesh)),'instanced bounds visible to exterior camera');record.visibleFromExterior=true;record.stagedBounds=[box.min.toArray(),box.max.toArray()];
 const bodies=entry.getCollisionBodies(),near=(a,b)=>Math.abs(a-b)<.08;
 const positionAllowed=(p,ctx={})=>{
   record.samples++;
   const body=bodies.find(b=>(b.minYM??0)<p.y+1.9&&(b.maxYM??100)>p.y+.08&&[[0,0],[.33,0],[-.33,0],[0,.33],[0,-.33]].some(([dx,dz])=>inside((p.x+dx)/4.1,(p.z+dz)/4.1,b.polygonCR)));
   if(body){if(record.bodyBlockers.length<8)record.bodyBlockers.push({point:p,kind:body.storeyPart??body.kind??body.id,minY:body.minYM,maxY:body.maxYM,body});if(!process.env.ROOF_IGNORE_BODIES||body.storeyPart)return false;}
   const probes=[{origin:vec(p).add(new T.Vector3(0,.18,0)),direction:new T.Vector3(0,1,0),far:1.7}];
   for(const y of [.2,.95,1.7])for(const [x,z]of[[1,0],[-1,0],[0,1],[0,-1]])probes.push({origin:vec(p).add(new T.Vector3(0,y,0)),direction:new T.Vector3(x,0,z),far:.33});
   for(const probe of probes){const hit=new T.Raycaster(probe.origin,probe.direction,.001,probe.far).intersectObject(parent,true).find(h=>visible(h.object));if(hit){if(record.meshBlockers.length<8)record.meshBlockers.push({point:p,mesh:hit.object.name,hit:hit.point.toArray()});return false;}}
   if(ctx.mode==='landing'){const floor=entry.floorHeight(p.x,p.z,p.y);return near(floor,p.y)||near(p.y,d.lower.y);}
   return true;
 };
 const segmentAllowed=(a,b)=>{const count=Math.max(1,Math.ceil(vec(a).distanceTo(vec(b))/.14));for(let i=0;i<=count;i++)if(!positionAllowed(vec(a).lerp(vec(b),i/count)))return false;return true};
 const c=createLadderClimbController({validatePosition:positionAllowed,validateSegment:segmentAllowed});
 if(process.env.LADDER_APPROACH_ALL){
  const approach=storeys.ladder.approachWorld??[{x:d.lower.x+d.normal.x*2,y:0,z:d.lower.z+d.normal.z*2},d.lower];
  let feet=approach[0].y,previous=vec(approach[0]);const motion=createSurfaceMotion();motion.reset(previous);
  for(let i=1;i<approach.length;i++){const start=approach[i-1],end=approach[i],steps=Math.ceil(vec(start).distanceTo(vec(end))/.06);for(let j=0;j<=steps;j++){
   const p=vec(start).lerp(vec(end),j/steps),sample=(x,z)=>entry.floorHeight(x,z,feet)??0;assert(motion.canMove(previous,p,sample,feet),'walking step limit');const floor=sample(p.x,p.z);feet=floor;p.y=feet;previous=p;
   assert(positionAllowed(p),'walk approach capsule blocked');
  }}
  assert(Math.abs(feet-d.lower.y)<.08,'approach reaches mount height');assert.equal(c.prompt(previous,[d])?.end,'lower','walking reaches E prompt');record.approachAudit='PASS';
 }
 record.roofFloor=entry.floorHeight(d.upper.x,d.upper.z,d.upper.y);assert(near(record.roofFloor,d.upper.y),'roof support selects roof');
 const roofHit=new T.Raycaster(vec(d.upper).add(new T.Vector3(0,.3,0)),new T.Vector3(0,-1,0),.001,.6).intersectObject(parent,true).find(h=>visible(h.object));assert(roofHit,'physical roof landing mesh');record.roofMesh=roofHit.object.name;
 const roofCoverBodies=entry.getCollisionBodies().filter(body=>String(body.storeyPart||'').startsWith('Roof_Cover_'));assert(roofCoverBodies.length>=1,'roof cover collision bodies');record.roofCoverBodies=roofCoverBodies.length;record.roofCoverIds=roofCoverBodies.map(body=>body.storeyPart);
 if(routeAudited.has(item.assetId)){assert.equal(c.prompt(d.lower,[d]).end,'lower');assert(c.begin(d.lower,d),'up route clearance');for(let i=0;i<10000&&c.locked;i++)c.update(1/30);assert(!c.locked,'up completes');assert.equal(c.prompt(d.upper,[d]).end,'upper');assert(c.begin(d.upper,d),'down route clearance');for(let i=0;i<10000&&c.locked;i++)c.update(1/30);assert(!c.locked,'down completes');record.routeAudit='PASS'}else record.routeAudit='landing-and-cover-only';record.status='PASS';
 }catch(e){record.status='FAIL';record.error=e.message;}finally{try{applied?.entry?.dispose();applied?.roomReveals?.dispose();applied?.windows?.dispose();}catch{}}
 console.log(JSON.stringify(record));
}
fs.mkdirSync(path.join(root,'outputs/interiors_resume'),{recursive:true});
fs.writeFileSync(path.join(root,'outputs/interiors_resume/ladder-discoverability-results.json'),JSON.stringify({diagnostic:{rear:!!process.env.ROOF_REAR,ignoreSourceBodies:!!process.env.ROOF_IGNORE_BODIES,ignoreParapet:!!process.env.ROOF_IGNORE_PARAPET,offset:process.env.ROOF_OFFSET??null},bindings:plan.instances.length,selected:results.length,results},null,2));
if(!process.env.LADDER_APPROACH_ALL)assert.equal(results.length,selectedAssets.size,'one representative per profiled asset');assert(results.length>=12,'nearly every building type has roof access');assert(results.every(r=>r.status==='PASS'),'roof integration failures');









