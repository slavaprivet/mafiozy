// Current placement + actual building GLB/controller. No browser or renderer.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {createNativeSiteCatalog,nativeSiteId} from './native_site_control.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const bytes=fs.readFileSync(new URL('buildings_placement.v1.json',import.meta.url));
const placement=JSON.parse(bytes),manifestRevision=crypto.createHash('sha256').update(bytes).digest('hex');
const selected=[placement.instances.find(b=>b.assetId==='old_town_narrow_townhouse_v1'),placement.instances.find(b=>b.gameplayId==='bank:small')];
const rows=[];
for(const instance of selected){
 assert(instance);const original=JSON.stringify(instance),buffer=fs.readFileSync(new URL('../../..'+instance.binding.url,import.meta.url));
 const visual=(await new GLTFLoader().parseAsync(buffer.buffer.slice(buffer.byteOffset,buffer.byteOffset+buffer.byteLength),'')).scene;
 visual.traverse(node=>{if(instance.hideNodeNames?.includes(node.name))node.visible=false;});
 const group=new THREE.Group(),transform=instance.transform;visual.position.fromArray(transform.modelLocalOffsetM);group.add(visual);
 group.position.fromArray(transform.positionM);group.rotation.y=transform.yawDegrees*Math.PI/180;group.scale.setScalar(transform.uniformScale);group.updateMatrixWorld(true);
 applyBuildingDoorsGlass(visual,instance);
 const {entry}=createWindowedBuildingEntry({THREE,visual,instance,metresPerCell:4.1});assert(entry);group.updateMatrixWorld(true);
 const catalog=createNativeSiteCatalog({manifestRevision,entries:[entry],policies:instance.role==='residence'?[{instanceId:instance.id,capturable:true,headquartersEligible:true}]:[]});
 const id=nativeSiteId(instance.id),inside=entry.roomPoint(),outside=entry.approachPoint();
 assert(catalog.contains(id,inside),'actual interior accepted: '+instance.id);
 const baseFloor=entry.floorHeight(inside.x,inside.z,inside.y),baseCeiling=entry.ceilingHeight(inside);
 assert(Number.isFinite(baseFloor)&&Number.isFinite(baseCeiling));
 assert(!catalog.contains(id,new THREE.Vector3(inside.x,baseFloor-.2,inside.z)),'actual below-floor point rejected');
 assert(!catalog.contains(id,new THREE.Vector3(inside.x,baseFloor+.5,inside.z)),'unsupported airborne feet rejected');
 const buildingTop=new THREE.Box3().setFromObject(group).max.y;
 assert(!catalog.contains(id,new THREE.Vector3(inside.x,buildingTop+10,inside.z)),'actual above-building projection rejected');
 const floorChecks=[];
 for(const floor of entry.storeys?.floors||[]){
  // Find a point on each real floor, avoiding authored stair holes. Samples use
  // current controller geometry and referenceY; they never replace its result.
  let found=null;
  for(let ix=1;ix<10&&!found;ix++)for(let iz=1;iz<10&&!found;iz++){
   const p=entry.storeys.worldPoint({x:floor.rect[0]+(floor.rect[2]-floor.rect[0])*ix/10,y:floor.y,z:floor.rect[1]+(floor.rect[3]-floor.rect[1])*iz/10});
   const support=entry.floorHeight(p.x,p.z,p.y),ceiling=entry.ceilingHeight(p);
   if(entry.containsInterior(p)&&Number.isFinite(support)&&Math.abs(support-p.y)<1e-5&&Number.isFinite(ceiling)&&ceiling>p.y+.5)found=p;
  }
  assert(found,'supported actual floor sample found: '+instance.id+' level '+floor.level);
  assert(catalog.contains(id,found),'actual storey accepted: '+instance.id+' level '+floor.level);
  floorChecks.push({level:floor.level,feet:found.toArray()});
 }
 let roofCheck=null;
 if(entry.storeys?.roof){
  const roof=entry.storeys.roof,p=entry.storeys.worldPoint({x:(roof.rect[0]+roof.rect[2])/2,y:roof.y,z:(roof.rect[1]+roof.rect[3])/2});
  assert.equal(entry.ceilingHeight(p),null,'actual open roof has no interior ceiling');
  assert(!catalog.contains(id,p),'actual roof standing point rejected');roofCheck=p.toArray();
 }else{
  assert(!catalog.contains(id,new THREE.Vector3(inside.x,buildingTop,inside.z)),'top of non-storey building is not interior');
 }
 assert(!catalog.contains(id,outside),'actual outside approach is not entry: '+instance.id);
 assert.deepEqual(catalog.approach(id),{x:outside.x,y:outside.y,z:outside.z});
 assert.equal(catalog.get(id).capturable,instance.role==='residence');
 assert.equal(JSON.stringify(instance),original,'native manifest was not rewritten');
 rows.push({instanceId:instance.id,inside:inside.toArray(),outside:outside.toArray(),baseFloor,baseCeiling,floorChecks,roofCheck,capturable:catalog.get(id).capturable});
 entry.dispose?.();visual.traverse(node=>{node.geometry?.dispose();for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])material.dispose?.();});
}
console.log(JSON.stringify({status:'PASS',manifestRevision,rows,limits:'Current actual GLB and entry boundary only. No combat, server authority, NPC route, LIVE or full-scene FPS tested.'},null,2));
