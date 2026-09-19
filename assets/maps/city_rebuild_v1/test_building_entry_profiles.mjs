import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
import {createBuildingEntry} from './building_entry.mjs';
import {applyBuildingSizeTransform} from './building_size_policy.mjs';
import {ADDITIONAL_ENTRY_PROFILES} from './building_entry_profiles.mjs';
import {circleFits,movePedestrian} from './walk_motion.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const read=file=>JSON.parse(fs.readFileSync(path.join(here,file)));
const placement=read('buildings_placement.v1.json'),decor=read('decor_placement.v1.json'),topology=read('topology_for_placement.json');
const before=JSON.stringify(placement);
const isVisible=node=>{for(let n=node;n;n=n.parent)if(!n.visible)return false;return true};
function inside(x,z,poly){let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])hit=!hit}return hit}
let passed=0;
for(const[assetId,profile]of Object.entries(ADDITIONAL_ENTRY_PROFILES)){
  const items=placement.instances.filter(i=>i.assetId===assetId),bytes=fs.readFileSync(path.join(root,items[0].binding.url.slice(1)));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),profile.sha256);
  // No DOM image decoder in Node. Textures are inert placeholders; all pinned
  // geometry, hierarchy and PBR associations are parsed by the real GLTFLoader.
  const loader=new GLTFLoader().register(()=>({name:'ENTRY_TEST_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new THREE.Texture())}));
  const source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
  source.traverse(n=>{if(/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name)||(items[0].hideNodeNames??[]).some(name=>name.replace(/\./g,'')===n.name))n.visible=false});
  const geometryBefore=new Map();source.traverse(n=>{if(n.isMesh)geometryBefore.set(n.geometry,Array.from(n.geometry.attributes.position.array))});
  for(const item of items){
    const group=new THREE.Group(),visual=source.clone(true),t=item.transform;visual.position.fromArray(t.modelLocalOffsetM);group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale??1);group.add(visual);group.updateMatrixWorld(true);
    applyBuildingSizeTransform(visual,item,THREE);
    const [sx,sz]=t.horizontalScale??[1,1],base=t.uniformScale??1;
    assert.deepEqual(group.scale.toArray(),[base*sx,base,base*sz],item.id+' authored building scale');
    const transforms=new Map();group.traverse(n=>transforms.set(n,{parent:n.parent,position:n.position.toArray(),quaternion:n.quaternion.toArray(),scale:n.scale.toArray(),geometry:n.geometry}));
    const entry=createBuildingEntry({THREE,visual,instance:item,sizeApplied:true});assert(entry,item.id);
    const approach=entry.approachPoint(),target=entry.roomPoint();approach.y=entry.floorHeight(approach.x,approach.z)??0;
    const other=[...placement.instances,...decor.instances].filter(i=>i.id!==item.id).flatMap(i=>i.collision?.worldBodies??[]);
    const allowed=(x,z)=>{if(!topology.walkableMask[Math.floor(z/4.1)]?.[Math.floor(x/4.1)])return false;const floor=entry.floorHeight(x,z)??0;return ![...other,...entry.getCollisionBodies()].some(b=>(b.maxYM??100)>=floor+.05&&(b.minYM??0)<=floor+1.9&&inside(x/4.1,z/4.1,b.polygonCR))};
    assert(circleFits(approach.x,approach.z,allowed),item.id+' approach blocked');
    let walked=movePedestrian(approach,target.clone().sub(approach),allowed);
    assert(Math.hypot(walked.x-target.x,walked.z-target.z)>.4,item.id+' closed door fails');
    assert(entry.interact(approach).accepted,item.id+' E outside failed');
    for(let i=0;i<50;i++)entry.update(1/60,approach);
    group.updateMatrixWorld(true);
    const rayStart=approach.clone();rayStart.y=entry.report.floorY+1.2;
    const rayEnd=target.clone();rayEnd.y=rayStart.y;
    const ray=new THREE.Raycaster(rayStart,rayEnd.clone().sub(rayStart).normalize(),0,rayEnd.distanceTo(rayStart));
    const hits=ray.intersectObject(visual,true).filter(h=>isVisible(h.object));
    assert.equal(hits.length,0,item.id+' visual corridor blocked: '+hits.map(h=>h.object.name).join(','));
    const across=new THREE.Vector3().crossVectors(ray.ray.direction,new THREE.Vector3(0,1,0)).multiplyScalar(.27);
    for(const sign of [-1,1]){const shoulder=new THREE.Raycaster(rayStart.clone().addScaledVector(across,sign),ray.ray.direction,0,rayEnd.distanceTo(rayStart));assert.equal(shoulder.intersectObject(visual,true).filter(h=>isVisible(h.object)).length,0,item.id+' shoulder hits geometry')}
    walked=movePedestrian(approach,target.clone().sub(approach),allowed);
    assert(Math.hypot(walked.x-target.x,walked.z-target.z)<1e-5,item.id+' open passage blocked');
    assert(entry.containsInterior(walked));
    const side=entry.object.localToWorld(new THREE.Vector3(entry.report.room.halfWidth+1.5,0,-2));
    const wall=movePedestrian(walked,side.clone().sub(target),allowed);
    assert(Math.hypot(wall.x-side.x,wall.z-side.z)>.4,item.id+' side wall not solid');
    assert(entry.proximity({...walked,y:entry.report.floorY}),item.id+' no inside E candidate');
    assert(entry.interact({...walked,y:entry.report.floorY}).accepted,item.id+' cannot close from inside');
    for(let i=0;i<50;i++)entry.update(1/60,{...walked,y:entry.report.floorY});
    assert.equal(entry.report.openFraction,0,item.id+' inside close did not complete');
    assert(entry.interact({...walked,y:entry.report.floorY}).accepted);
    for(let i=0;i<50;i++)entry.update(1/60,{...walked,y:entry.report.floorY});
    const returned=movePedestrian(walked,approach.clone().sub(target),allowed);
    assert(Math.hypot(returned.x-approach.x,returned.z-approach.z)<1e-5,item.id+' return blocked');
    entry.dispose();for(const[n,t]of transforms){assert.equal(n.parent,t.parent,item.id+' restore parent');assert.deepEqual(n.position.toArray(),t.position,item.id+' restore position');assert.deepEqual(n.quaternion.toArray(),t.quaternion,item.id+' restore rotation');assert.deepEqual(n.scale.toArray(),t.scale,item.id+' restore scale');assert.equal(n.geometry,t.geometry,item.id+' restore geometry')}passed++;
  }
  for(const[geometry,array]of geometryBefore)assert.deepEqual(Array.from(geometry.attributes.position.array),array,assetId+' shared geometry changed');
  console.log('PASS '+assetId+' ('+items.length+' placements): closed/open, real mesh corridor, topology, walk in/out, original geometry');
}
assert.equal(JSON.stringify(placement),before);
console.log(passed+' additional physical entrances passed. Live visuals remain pending.');
