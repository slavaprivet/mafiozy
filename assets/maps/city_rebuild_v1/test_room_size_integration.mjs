import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {cellsForRect,rectanglesOverlap as overlaps} from './building_placement.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {BUILDING_ROOM_PROFILES} from './building_room_profiles.mjs';
const dir=new URL('./',import.meta.url),read=f=>JSON.parse(fs.readFileSync(new URL(f,dir))),plan=read('buildings_placement.v1.json'),base=read('buildings_placement.before_room_sizes.v1.json'),top=read('topology_for_placement.json');
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
for(const i of plan.instances){
 for(const p of cellsForRect(i.footprint)){assert.equal(top.grid[p.r]?.[p.c],8,i.id+' exterior off grass');assert.equal(top.protectedMask[p.r]?.[p.c],0)}
 for(const p of cellsForRect(i.entryCorridor)){assert.ok([0,8,9].includes(top.grid[p.r]?.[p.c]),i.id+' approach dry');assert.equal(top.protectedMask[p.r]?.[p.c],0)}
 for(const j of plan.instances)if(i!==j){assert.equal(overlaps(i.clearance,j.clearance),false,i.id+' parcel overlap '+j.id);assert.equal(overlaps(i.footprint,j.entryCorridor),false,i.id+' blocked foreign entry')}
 assert.equal(i.gameplayActive,false);
}
for(const old of base.instances){const i=plan.instances.find(i=>i.id===old.id);assert.ok(i);assert.equal(i.gameplayId,old.gameplayId);assert.deepEqual(i.binding,old.binding);assert.equal(i.transform.uniformScale,1);assert.ok(i.transform.horizontalScale.every(s=>s>=1));}
const visible=n=>{for(let p=n;p;p=p.parent)if(!p.visible)return false;return true};
function inPoly(x,z,poly){let b=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],q=poly[j];if((a[1]>z)!==(q[1]>z)&&x<(q[0]-a[0])*(z-a[1])/(q[1]-a[1])+a[0])b=!b}return b}
for(const item of plan.instances.filter(i=>i.role==='bank_shell')){
 const bytes=fs.readFileSync(new URL('../../../'+item.binding.url.slice(1),dir)),visual=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,parent=new T.Group();parent.add(visual);parent.position.fromArray(item.transform.positionM);parent.rotation.y=item.transform.yawDegrees*Math.PI/180;parent.updateMatrixWorld(true);
 const {entry,roomReveals}=createWindowedBuildingEntry({THREE:T,visual,instance:item});assert.ok(entry,item.id);assert.equal(entry.report.sameScene,true);assert.equal(entry.contentRoot.children.length,0);
 const approach=entry.approachPoint();assert.equal(entry.interact(approach).accepted,true);for(let i=0;i<10;i++)entry.update(.1,approach);
 const bodies=entry.getCollisionBodies(),r=entry.report.room;assert.ok(bodies.some(b=>b.bankPartition?.startsWith('Bank_Vault_')));
 const pad=.32,step=.25,width=r.width,depth=r.usableDepth,nx=Math.floor(width/step),nz=Math.floor(depth/step),point=(c,z)=>visual.localToWorld(new T.Vector3(-width/2+(c+.5)*step,.1,-depth/2+(z+.5)*step));
 const allowed=(c,z)=>{if(c<0||z<0||c>=nx||z>=nz)return false;const p=point(c,z);for(const [dx,dz]of[[0,0],[pad,0],[-pad,0],[0,pad],[0,-pad]]){if(!top.walkableMask[Math.floor((p.z+dz)/4.1)]?.[Math.floor((p.x+dx)/4.1)])return false;if(bodies.some(b=>b.minYM<p.y+1.9&&b.maxYM>p.y+.05&&inPoly((p.x+dx)/4.1,(p.z+dz)/4.1,b.polygonCR)))return false}return true};
 const start=[Math.floor(nx/2),nz-3],queue=[start],key=(c,z)=>z*nx+c,parents=new Map([[key(...start),null]]);assert.ok(allowed(...start));
 for(let n=0;n<queue.length;n++){const [c,z]=queue[n];for(const p of[[c+1,z],[c-1,z],[c,z+1],[c,z-1]])if(allowed(...p)&&!parents.has(key(...p))){parents.set(key(...p),[c,z]);queue.push(p)}}
 for(const room of item.bankLayout.roomLabels){let cell=[Math.floor((room.center[0]+width/2)/step),Math.floor((room.center[2]+depth/2)/step)];assert.ok(parents.has(key(...cell)),item.id+' '+room.id+' blocked');
  while(parents.get(key(...cell))){const prior=parents.get(key(...cell)),a=point(...prior),b=point(...cell);a.y+=1.3;b.y+=1.3;const delta=b.clone().sub(a);assert.equal(new T.Raycaster(a,delta.clone().normalize(),.01,delta.length()-.01).intersectObject(visual,true).filter(h=>visible(h.object)).length,0,'visible partition disagrees with collision');cell=prior}
 }
 const empty=entry.roomCenterPoint(),outside=entry.approachPoint();assert.ok(entry.containsInterior(empty));assert.ok(!entry.containsInterior(outside));
 roomReveals.dispose();entry.dispose();console.log('PASS '+item.id+': seven rooms reachable through actual world colliders; partition mesh rays, physical E door and teardown');
}
assert.equal(plan.instances.filter(i=>i.role==='bank_shell').length,3);console.log('PASS '+plan.instances.length+' footprints, road approaches, unchanged original IDs/assets and metre heights');
