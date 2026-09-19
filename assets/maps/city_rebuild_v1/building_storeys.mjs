import {BUILDING_STOREY_PROFILES} from './building_storey_profiles.mjs';
import {createFittedStaircase} from './oriented_staircase.mjs';
import {createRoofLadder} from './roof_ladder.mjs';
import {subtractBoxFromGeometry} from './building_entry.mjs';
import {planSpaciousFloor} from './interior_spacious_layout.mjs';
import {resolveBuildingPurpose} from './building_interior_purpose.mjs';

const inRect=(x,z,r,p=0)=>x>=r[0]-p&&x<=r[2]+p&&z>=r[1]-p&&z<=r[3]+p;
const intersect=(a,b)=>[Math.max(a[0],b[0]),Math.max(a[1],b[1]),Math.min(a[2],b[2]),Math.min(a[3],b[3])];
const variants=new WeakMap();
const storeyResourceCaches=new WeakMap(),storeyResourceRecords=new Set();let storeyResourceCacheHits=0,storeyResourceCacheMisses=0;
function acquire(source,key,build){let m=variants.get(source);if(!m)variants.set(source,m=new Map());let r=m.get(key);if(r){r.refs++;return r}r={geometry:build(),refs:1,m,key};m.set(key,r);return r}
function release(r){if(--r.refs===0){r.m.delete(r.key);r.geometry.dispose()}}
function acquireStoreyResources(T){
 let record=storeyResourceCaches.get(T);
 if(record){record.refs++;storeyResourceCacheHits++;}
 else {
  record={refs:1,materials:{wall:new T.MeshStandardMaterial({color:'#b7aaa0',roughness:.88,side:T.DoubleSide}),floor:new T.MeshStandardMaterial({color:'#68584b',roughness:.85}),trim:new T.MeshStandardMaterial({color:'#8b7051',roughness:.5,metalness:.25})},boxGeometry:new T.BoxGeometry(1,1,1)};
  storeyResourceCaches.set(T,record);storeyResourceRecords.add(record);storeyResourceCacheMisses++;
 }
 let released=false;
 return {...record,dispose(){if(released)return;released=true;if(--record.refs)return;record.boxGeometry.dispose();for(const material of Object.values(record.materials))material.dispose();storeyResourceCaches.delete(T);storeyResourceRecords.delete(record);}};
}
export function buildingStoreyResourceCacheStats(){return{entries:storeyResourceRecords.size,refs:[...storeyResourceRecords].reduce((sum,record)=>sum+record.refs,0),hits:storeyResourceCacheHits,misses:storeyResourceCacheMisses};}
function rectPieces(r,h){if(!h)return[r];const a=intersect(r,h);if(a[0]>=a[2]||a[1]>=a[3])return[r];return[[r[0],r[1],a[0],r[3]],[a[2],r[1],r[2],r[3]],[a[0],r[1],a[2],a[1]],[a[0],a[3],a[2],r[3]]].filter(p=>p[2]-p[0]>.001&&p[3]-p[1]>.001)}
// These audited narrow plans have the entry and habitable room on +Z. The
// original U turn faced that side, placing its half-height landing in front
// of the room doorway. Turn the entire stair system, not just its rendering,
// so full-height start/end landings connect to the existing front hall.
function faceStairTowardFront(T,source,core){
 const [a,b,c,d]=core,cx=(a+c)/2,cz=(b+d)/2;
 const point=p=>({...p,x:2*cx-p.x,z:2*cz-p.z}),rect=r=>[2*cx-r[2],2*cz-r[3],2*cx-r[0],2*cz-r[1]];
 const group=new T.Group();group.name='Front_Connected_Staircase';group.position.set(2*cx,0,2*cz);group.rotation.y=Math.PI;group.add(source.group);
 let disposed=false;
 return {...source,group,frontConnected:true,footprint:rect(source.footprint),holeRect:rect(source.holeRect),holeRects:source.holeRects.map(h=>({...h,rect:rect(h.rect)})),
  route:source.route.map(point),obstacles:source.obstacles.map(o=>({...o,rect:rect(o.rect)})),
  sampleFloor(x,z,y){return source.sampleFloor(2*cx-x,2*cz-z,y)},sampleCeiling(x,z,y){return source.sampleCeiling(2*cx-x,2*cz-z,y)},
  dispose(){if(disposed)return;disposed=true;group.removeFromParent();source.dispose()}};
}
function subtractRect(polygon,rect){let inside=polygon;const result=[];for(const[axis,boundary,sign]of[[0,rect[0],1],[0,rect[2],-1],[1,rect[1],1],[1,rect[3],-1]]){if(inside.length<3)break;const next=[],outside=[];for(let i=0;i<inside.length;i++){const a=inside[i],b=inside[(i+1)%inside.length],da=(a[axis]-boundary)*sign,db=(b[axis]-boundary)*sign;(da>=0?next:outside).push(a);if((da>=0)!==(db>=0)){const t=da/(da-db),p=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];next.push(p);outside.push(p)}}if(outside.length>=3)result.push(outside);inside=next}return result}

// Add storeys to the existing physical entrance; no replacement of IDs or doors.
// Geometry is in world metres under an inverse-scaled child, including stairs.
export function createBuildingStoreys({THREE:T,entry,visual,instance,metresPerCell=4.1,windows=null}){
 if(!entry||entry.storeys)return entry?.storeys??null;
 const profile=BUILDING_STOREY_PROFILES[instance.assetId];if(!profile)return null;
 const root=new T.Group();root.name='Runtime_Building_Storeys';entry.object.add(root);
 if(instance.assetId==='strip_club')root.position.y=.45;
 entry.object.updateWorldMatrix(true,true);const scale=entry.object.getWorldScale(new T.Vector3());root.scale.set(1/scale.x,1/scale.y,1/scale.z);root.updateWorldMatrix(true,true);
 const inverse=root.matrixWorld.clone().invert(),baseY=root.getWorldPosition(new T.Vector3()).y;
 const toMetric=(x,y,z)=>visual.localToWorld(new T.Vector3(x,y,z)).applyMatrix4(inverse);
 const metricRect=r=>{const b=new T.Box3();for(const[x,z]of[[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]])b.expandByPoint(toMetric(x,profile.floors[0].y,z));return[b.min.x,b.min.z,b.max.x,b.max.z]};
 const floors=profile.floors.map((f,level)=>({level,y:(f.y-profile.floors[0].y)*scale.y,ceiling:(f.ceiling-profile.floors[0].y)*scale.y,rect:metricRect(f.rect)}));
 // Keep the accepted ground room and entry alignment, including the legacy club.
 const r=entry.report.room;floors[0].rect=[r.minX*scale.x,r.minZ*scale.z,r.maxX*scale.x,r.maxZ*scale.z];
 const stairCore=floors.map(f=>f.rect).reduce(intersect),stairs=[];for(let i=0;i<floors.length-1;i++){const a=floors[i],b=floors[i+1];const stair=createFittedStaircase(T,{rect:stairCore,floorHeight:b.y-a.y,baseY:a.y,flightWidth:1.3,side:'left',orientation:instance.assetId==='eastside_stepped_apartment_v1'?'unrotated':'auto'});stair.lowerLevel=i;stair.upperLevel=i+1;stairs.push(stair)}
 if(['old_town_narrow_townhouse_v1','pawnshop','eastside_stepped_apartment_v1'].includes(instance.assetId)&&stairs.length&&stairs.every(s=>!s.rotated)){
  // Storey heights may differ. A common pivot preserves the identical
  // full-floor landing line between levels instead of shifting it per flight.
  const core=stairs.map(s=>s.footprint).reduce((a,b)=>[Math.min(a[0],b[0]),Math.min(a[1],b[1]),Math.max(a[2],b[2]),Math.max(a[3],b[3])]);
  for(let i=0;i<stairs.length;i++)stairs[i]=faceStairTowardFront(T,stairs[i],core);
 }
 for(const stair of stairs)root.add(stair.group);
 const hidden=[],restores=[],records=[],geometry=[],bodies=[],rooms=[],floorPlans=[],boxes=[],movedNodes=[],ownedInstances=[],storeyResources=acquireStoreyResources(T);
 const {wall,floor:floorMat,trim}=storeyResources.materials;
 const worldBody=(rect,minY,maxY,kind)=>{const pts=[[rect[0],rect[1]],[rect[2],rect[1]],[rect[2],rect[3]],[rect[0],rect[3]]].map(([x,z])=>root.localToWorld(new T.Vector3(x,0,z)));return{polygonCR:pts.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseY+minY,maxYM:baseY+maxY,buildingEntryId:instance.id,storeyPart:kind,cover:kind.startsWith('Roof_Cover_')}};
 function box(name,rect,bottom,top,material=wall,collision=false){if(rect[2]-rect[0]<.001||rect[3]-rect[1]<.001||top-bottom<.001)return;if(collision)bodies.push(worldBody(rect,bottom,top,name));if(!name.startsWith('Entry_Interior_')){boxes.push({name,rect,bottom,top,material});return}const g=new T.BoxGeometry(rect[2]-rect[0],top-bottom,rect[3]-rect[1]);geometry.push(g);const n=new T.Mesh(g,material);n.name=name;n.position.set((rect[0]+rect[2])/2,(bottom+top)/2,(rect[1]+rect[3])/2);n.castShadow=n.receiveShadow=true;root.add(n);return n}
 const collisionBox=(name,rect,bottom,top)=>{if(rect[2]-rect[0]<.001||rect[3]-rect[1]<.001||top-bottom<.001)return;bodies.push(worldBody(rect,bottom,top,name))};
 function clipped(node,cuts){const matrix=new T.Matrix4().multiplyMatrices(inverse,node.matrixWorld),key=matrix.elements.map(v=>v.toFixed(5)).join(',')+'|'+cuts.map(b=>b.min.toArray().concat(b.max.toArray()).map(v=>v.toFixed(5)).join(',')).join('|');const rec=acquire(node.geometry,key,()=>{let g=node.geometry;for(const cut of cuts){const next=subtractBoxFromGeometry(T,g,matrix,cut);if(g!==node.geometry)g.dispose();g=next}return g});restores.push([node,node.geometry]);records.push(rec);node.geometry=rec.geometry}
 visual.updateWorldMatrix(true,true);
 if(floors.length>1){
  // Hollow the upper authored solid volumes only within the audited footprint.
  // The ground adapter already owns its cut and is restored after this layer.
  const cuts=floors.slice(1).map(f=>new T.Box3(new T.Vector3(f.rect[0],f.y-.22,f.rect[1]),new T.Vector3(f.rect[2],f.ceiling+.02,f.rect[3])));
  visual.traverse(n=>{if(!n.isMesh||n.isInstancedMesh||!n.geometry?.attributes.position)return;for(let p=n;p&&p!==visual;p=p.parent)if(!p.visible||p===entry.object)return;if(/CANON_WINDOW.*(?:INTERIO|FURNITUR|WARM_)/.test(n.name))return;const bounds=new T.Box3().setFromBufferAttribute(n.geometry.attributes.position).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,n.matrixWorld));const selected=cuts.filter(b=>b.intersectsBox(bounds));if(selected.length)clipped(n,selected)});
 }
 // Remove obsolete flat ceiling; new plates below have actual stair openings.
 entry.object.traverse(n=>{if(n===root)return;if(/^(Entry_Interior_Ceiling|Interior_Ceiling)$/.test(n.name)){hidden.push([n,n.visible]);n.visible=false}});
 const safeLamp=f=>{const [a,b,c,d]=f.rect,candidates=[];for(let i=1;i<6;i++)for(let j=1;j<6;j++){const x=a+(c-a)*i/6,z=b+(d-b)*j/6;if(!stairs.some(s=>(s.lowerLevel===f.level||s.upperLevel===f.level)&&inRect(x,z,s.footprint,.25)))candidates.push({x,z})}return candidates.sort((p,q)=>(p.x*p.x+(p.z-d+1)**2)-(q.x*q.x+(q.z-d+1)**2))[0]??{x:(a+c)/2,z:d-.35}};
 const groundLamp=safeLamp(floors[0]),groundLampY=Math.min(floors[0].ceiling,floors[1]?.y-.14||Infinity)-.24;
 entry.object.traverse(n=>{for(let p=n;p&&p!==entry.object;p=p.parent)if(p===root)return;if(!n.isPointLight&&!/^(Entry_Warm_Fixture|Interior_Pendant)/.test(n.name))return;movedNodes.push([n,n.position.clone()]);const position=n.getWorldPosition(new T.Vector3()).applyMatrix4(inverse);position.y=groundLampY+(n.isPointLight?0:.1);if(stairs.some(s=>inRect(position.x,position.z,s.footprint,.2))){position.x=groundLamp.x;position.z=groundLamp.z}n.position.copy(n.parent.worldToLocal(root.localToWorld(position)))});
 for(const f of floors){
  const stairBelow=stairs.find(s=>s.upperLevel===f.level),hole=stairBelow?.holeRect;
  if(f.level>0)for(const p of rectPieces(f.rect,hole))box('Storey_Floor',p,f.y-.14,f.y,floorMat);
  const above=floors[f.level+1],aboveStair=stairs.find(s=>s.lowerLevel===f.level);
  // Non-overlapped roof area gets its own ceiling (e.g. tower setbacks).
  const ceilingRects=above?rectPieces(f.rect,above.rect):[f.rect];
  for(const p of ceilingRects)box('Storey_Ceiling',p,f.ceiling,f.ceiling+.12,wall);
  if(f.level>0){const[a,b,c,d]=f.rect;box('Entry_Interior_Left',[a-.10,b,a,d],f.y,f.ceiling,wall,true);box('Entry_Interior_Right',[c,b,c+.10,d],f.y,f.ceiling,wall,true);box('Entry_Interior_Rear',[a,b-.10,c,b],f.y,f.ceiling,wall,true);box('Entry_Interior_Front',[a,d,c,d+.10],f.y,f.ceiling,wall,true)}
  if(f.level>0){const p=safeLamp(f),light=new T.PointLight('#ffd2a0',8,Math.max(7,Math.min(18,f.rect[2]-f.rect[0])),2);light.position.set(p.x,Math.min(f.ceiling,above?.y-.14||Infinity)-.22,p.z);root.add(light);box('Storey_Lamp',[p.x-.17,p.z-.17,p.x+.17,p.z+.17],light.position.y+.07,light.position.y+.16,trim)}
  if(instance.role==='bank_shell'){rooms.push({level:f.level,name:'Сохранённая планировка банка',rect:f.rect.slice(),y:f.y});continue}
  const plan=planSpaciousFloor({assetId:instance.assetId,instanceId:instance.id,purpose:resolveBuildingPurpose(instance),role:instance.role,level:f.level,rect:f.rect,y:f.y,ceiling:f.ceiling,stairs});
  for(const room of plan.rooms)if(room.door&&['bedroom','guest_bedroom','study','manager_office','cash_office','security_office'].includes(room.role))room.door={...room.door,open:false};
  floorPlans.push({...plan,level:f.level});
  for(const part of plan.partitions)box(part.name,part.rect,part.bottom,part.top,part.material==='trim'?trim:wall,part.collision);
  rooms.push(...plan.rooms);
 }
 for(const s of stairs)for(const o of s.obstacles)bodies.push(worldBody(o.rect,o.minY,o.maxY,o.kind));
 let ladder=null,roof=null;const ladderApproachFloors=[];
 // Nearly every authored building gets a rear roof route.  A few profiles have
 // an explicit roof slab; the rest use the top storey envelope as a conservative
 // roof surface so houses, shops and apartments all share the same traversal
 // affordance instead of silently stopping at the six originally audited shells.
 // The public entrance is normally on +Z, therefore the ladder stays on the
 // opposite/rear (-Z) edge and never consumes the doorway approach.
 const roofSelected=instance.role!=='roadside_lamp'&&instance.role!=='decor'&&profile.floors?.length>0;
 if(roofSelected){const topFloor=profile.floors.at(-1),surface=profile.roof?.[0]??{name:'DerivedRoof',min:[topFloor.rect[0],topFloor.ceiling,topFloor.rect[1]],max:[topFloor.rect[2],topFloor.ceiling+.22,topFloor.rect[3]]},rr=metricRect([surface.min[0],surface.min[2],surface.max[0],surface.max[2]]),roofY=toMetric(0,surface.max[1],0).y;
  // Stand the lower rung clear of the authored ground apron.  The extra
  // outward reach matters on porches, civic plinths and house foundations;
  // the upper endpoint still lands one metre inside the roof edge.
  const sign=-1,z=rr[1],verticalEdgeZ=Math.min(rr[1],...floors.map(f=>f.rect[1]));
  // Residential window extraction already knows the exact authored pane
  // bounds. Reuse those bounds in root-local metres so the ladder can choose a
  // blank rear-wall bay instead of masking a window with its rails.
  const openingBoxes=[];
  if(windows?.panes?.length)for(const pane of windows.panes){const q=pane.cut,points=[];for(const xx of [q.min.x,q.max.x])for(const yy of [q.min.y,q.max.y])for(const zz of [q.min.z,q.max.z])points.push(toMetric(xx,yy,zz));const bounds=new T.Box3().setFromPoints(points);openingBoxes.push(bounds)}
  const doorPoint=instance.publicDoorLocalXYZ&&Array.isArray(instance.publicDoorLocalXYZ)?toMetric(instance.publicDoorLocalXYZ[0],instance.publicDoorLocalXYZ[1]??1,instance.publicDoorLocalXYZ[2]):null;
  const ladderBayClear=x=>!openingBoxes.some(box=>box.max.y>.4&&box.min.y<roofY+.7&&x>box.min.x-.62&&x<box.max.x+.62&&z>box.min.z-.7&&z<box.max.z+.7)&&(!doorPoint||Math.hypot(x-doorPoint.x,z-doorPoint.z)>1.5);
  const pointInside=(px,pz,poly)=>{let hit=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const aa=poly[i],bb=poly[j];if((aa[1]>pz)!==(bb[1]>pz)&&px<(bb[0]-aa[0])*(pz-aa[1])/(bb[1]-aa[1])+aa[0])hit=!hit}return hit};
  // Collision polygons are world cells. Convert once to the same metre frame
  // as the ladder, including building yaw and the entrance-root translation.
  const groundBodies=entry.getCollisionBodies().map(body=>({...body,localPolygon:body.polygonCR.map(([c,r])=>{const p=new T.Vector3(c*metresPerCell,0,r*metresPerCell).applyMatrix4(inverse);return[p.x,p.z]})})),xCandidates=[rr[2]-1.6,rr[0]+1.6,(rr[0]+rr[2])/2,rr[0]+(rr[2]-rr[0])*.32,rr[0]+(rr[2]-rr[0])*.68].map(v=>Math.max(rr[0]+.65,Math.min(rr[2]-.65,v)));
  const isLowSite=body=>body.authoredSitePart&&(body.maxYM??Infinity)<=1.2&&(body.minYM??0)<.1;
  const lowerOffsetFor=cx=>{const clearLower=oz=>!groundBodies.some(body=>{if(isLowSite(body)||(body.minYM??0)>1.9||(body.maxYM??0)<.08)return false;for(let s=0;s<=2.001;s+=.2)for(let a=0;a<12;a++){const dx=Math.cos(a*Math.PI/6)*.4,dz=Math.sin(a*Math.PI/6)*.4;if(pointInside(cx+dx,verticalEdgeZ+sign*(oz+s)+dz,body.localPolygon))return true}return false});for(let oz=.85;oz<=12;oz+=.25)if(clearLower(oz))return oz;return Infinity};
  const bays=xCandidates.map(cx=>({x:cx,offset:ladderBayClear(cx)?lowerOffsetFor(cx):Infinity})).sort((a,b)=>a.offset-b.offset),bay=bays[0],x=bay.x,lowerOffset=(Number.isFinite(bay.offset)?bay.offset:5.25)+.15,lower={x,y:-baseY,z:verticalEdgeZ+sign*lowerOffset},upper={x,y:roofY+.015,z:z-sign*1.05};
  // A civic plinth is a floor, but its .5–.6 m edge exceeds the walking step
  // limit. Add a narrow, visible service stair and landing outside that edge.
  const pads=groundBodies.filter(body=>isLowSite(body)&&Math.min(...body.localPolygon.map(p=>p[0]))<=x+.9&&Math.max(...body.localPolygon.map(p=>p[0]))>=x-.9);
  let approachLocal=[{x,y:-baseY,z:lower.z-2},lower];
  if(pads.length){const top=Math.max(...pads.map(p=>p.maxYM)),edge=Math.min(lower.z,...pads.flatMap(p=>p.localPolygon.map(v=>v[1])))-.55,count=Math.ceil(top/.15),tread=.5;
   lower.y=top-baseY;
   const landing=[x-.9,edge,x+.9,lower.z+.25];box('Ladder_Approach_Landing',landing,top-baseY-.12,top-baseY,wall);ladderApproachFloors.push({rect:landing,y:top-baseY});
   for(let i=1;i<=count;i++){const rect=[x-.9,edge-(count-i+1)*tread,x+.9,edge-(count-i)*tread],y=top*i/count-baseY;box('Ladder_Approach_Step',rect,-baseY,y,wall);ladderApproachFloors.push({rect,y})}
   approachLocal=[{x,y:-baseY,z:edge-count*tread-1},lower];
  }
  ladder=createRoofLadder(T,{id:instance.id,lower,upper,outward:{x:0,z:sign},wallTieDepth:Math.max(.48,lowerOffset-.38),wallSignDepths:{lower:lowerOffset,upper:1.05}});root.add(ladder.object);roof={rect:rr,y:upper.y};
  ladder.approachWorld=approachLocal.map(p=>root.localToWorld(new T.Vector3(p.x,p.y,p.z)));
  // Thin rail colliders keep the player from jumping through the ladder sides
  // and getting wedged under the rungs, while the .33 m traversal probes still
  // fit cleanly between the .8 m rail span.
  const railZ=lower.z-sign*.38,railHalf=.4;
  for(const side of[-1,1]){const railX=x+sign*railHalf*side;collisionBox(`Roof_Ladder_Rail_Collision_${side<0?'Left':'Right'}`,[railX-.045,railZ-.045,railX+.045,railZ+.045],lower.y+.05,upper.y+1.05)}
  // Open only the small parapet exit; the roof slab stays intact.
  const aperture=new T.Box3(new T.Vector3(x-.72,roofY+.01,z-1.2),new T.Vector3(x+.72,roofY+2.5,z+1.2));
  visual.updateWorldMatrix(true,true);visual.traverse(n=>{if(!n.isMesh||n.isInstancedMesh||!n.geometry?.attributes.position)return;for(let p=n;p&&p!==visual;p=p.parent)if(!p.visible||p===entry.object)return;const b=new T.Box3().setFromBufferAttribute(n.geometry.attributes.position).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,n.matrixWorld));if(b.intersectsBox(aperture))clipped(n,[aperture])});
  const descriptor=ladder.descriptor,worldPoint=p=>root.localToWorld(new T.Vector3(p.x,p.y,p.z));const normal=new T.Vector3(0,0,sign).transformDirection(root.matrixWorld),right=new T.Vector3(sign,0,0).transformDirection(root.matrixWorld);
  ladder.worldDescriptor={...descriptor,lower:worldPoint(descriptor.lower),upper:worldPoint(descriptor.upper),path:descriptor.path.map(worldPoint),normal:{x:normal.x,z:normal.z},right:{x:right.x,z:right.z},yaw:Math.atan2(-normal.x,-normal.z)};
  const[a,b,c,d]=rr;for(const edge of[[a,b,a+.08,d],[c-.08,b,c,d]])box('Roof_Edge_Rail',edge,roof.y,roof.y+.9,trim,true);
  for(const zz of[b,d]){const intervals=zz===z?[[a,x-.72],[x+.72,c]]:[[a,c]];for(const[l,h]of intervals)box('Roof_Edge_Rail',[l,zz-.04,h,zz+.04],roof.y,roof.y+.9,trim,true)}
  // Roof cover is real 3D geometry and collision, intentionally low enough for
  // a crouched hero.  Layout is normalized to each roof footprint so narrow
  // townhouses still get cover while broad roofs get two pieces of cover.
  // Keep a generous exclusion corridor around the ladder and auto step-off.
  const coverIds=[],width=c-a,depth=d-b,ladderKeepOut=[x-.95,z-.35,x+.95,z+2.25],overlap=(u,v)=>u[0]<v[2]&&u[2]>v[0]&&u[1]<v[3]&&u[3]>v[1];
  const addRoofCover=(id,rect,height,material=wall)=>{const clipped=[Math.max(a+.35,rect[0]),Math.max(b+.35,rect[1]),Math.min(c-.35,rect[2]),Math.min(d-.35,rect[3])];if(clipped[2]-clipped[0]<.7||clipped[3]-clipped[1]<.55||overlap(clipped,ladderKeepOut))return false;box(id,clipped,roof.y+.02,roof.y+.02+height,material,true);coverIds.push(id);return true};
  const candidates=[
   ['Roof_Cover_Utility_Left',[a+width*.08,b+depth*.25,a+width*.34,b+depth*.55],1.25,wall],
   ['Roof_Cover_Utility_Front',[a+width*.54,b+depth*.62,a+width*.80,b+depth*.90],1.38,wall],
   ['Roof_Cover_Parapet_Rear',[a+width*.10,b+depth*.07,a+width*.48,b+depth*.16],1.08,trim],
   ['Roof_Cover_Utility_Right',[a+width*.64,b+depth*.20,a+width*.90,b+depth*.48],1.2,trim]
  ];
  const targetCount=width>=3.4&&depth>=2.4?2:1;for(const candidate of candidates){if(coverIds.length>=targetCount)break;addRoofCover(...candidate)}
  roof.coverIds=coverIds;roof.coverCount=coverIds.length;
 }
 const {boxGeometry}=storeyResources;
 for(const material of Object.values(storeyResources.materials)){const items=boxes.filter(b=>b.material===material);if(!items.length)continue;const mesh=new T.InstancedMesh(boxGeometry,material,items.length);mesh.name=material===floorMat?'Storey_Floors':material===trim?'Room_Door_Frames':'Storey_Walls_And_Ceilings';const m=new T.Matrix4(),q=new T.Quaternion();items.forEach((b,i)=>mesh.setMatrixAt(i,m.compose(new T.Vector3((b.rect[0]+b.rect[2])/2,(b.bottom+b.top)/2,(b.rect[1]+b.rect[3])/2),q,new T.Vector3(b.rect[2]-b.rect[0],b.top-b.bottom,b.rect[3]-b.rect[1]))));mesh.castShadow=mesh.receiveShadow=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();mesh.userData.worldBlastStaticBounds=true;mesh.userData.staticRenderMaterialImmutable=true;root.add(mesh);ownedInstances.push(mesh)}
 root.updateWorldMatrix(true,true);
 const original={floor:entry.floorHeight.bind(entry),ceiling:entry.ceilingHeight.bind(entry),bodies:entry.getCollisionBodies.bind(entry),contains:entry.containsInterior.bind(entry),dispose:entry.dispose.bind(entry)};
 const local=(x,z,y=baseY)=>new T.Vector3(x,y,z).applyMatrix4(inverse);
 const bounds=new T.Box3().setFromObject(root);if(entry.sampleBounds)bounds.union(entry.sampleBounds);entry.sampleBounds=bounds;
 function samples(x,z,ref){const out=[];for(const f of floors){if(!inRect(x,z,f.rect))continue;const hole=stairs.find(s=>s.upperLevel===f.level)?.holeRect;if(!hole||!inRect(x,z,hole))out.push(f.y)}for(const s of stairs){const y=s.sampleFloor(x,z,ref);if(y!==null)out.push(y)}for(const f of ladderApproachFloors)if(inRect(x,z,f.rect))out.push(f.y);if(roof&&inRect(x,z,roof.rect,.001))out.push(roof.y);return out}
 entry.floorHeight=(x,z,referenceY=0)=>{if(x<bounds.min.x||x>bounds.max.x||z<bounds.min.z||z>bounds.max.z)return null;const p=local(x,z,referenceY),values=samples(p.x,p.z,p.y).filter(y=>y<=p.y+.28+1e-6);if(values.length)return baseY+Math.max(...values);return original.floor(x,z)};
 entry.ceilingHeight=point=>{const p=local(point.x,point.z,point.y??baseY);if(roof&&p.y>=roof.y-.2&&inRect(p.x,p.z,roof.rect))return null;const values=[];for(const f of floors)if(inRect(p.x,p.z,f.rect)){const next=floors[f.level+1],hole=stairs.find(s=>s.lowerLevel===f.level)?.holeRect;if(f.ceiling>p.y+.3&&(!next||!inRect(p.x,p.z,next.rect)))values.push(f.ceiling);if(next&&inRect(p.x,p.z,next.rect)&&(!hole||!inRect(p.x,p.z,hole))&&next.y-.14>p.y+.3)values.push(next.y-.14)}for(const s of stairs){const c=s.sampleCeiling(p.x,p.z,p.y);if(c!==null)values.push(c)}return values.length?baseY+Math.min(...values):original.contains(point)?null:original.ceiling(point)};
 entry.containsInterior=point=>{const p=local(point.x,point.z,point.y??baseY);return floors.some(f=>inRect(p.x,p.z,f.rect)&&p.y>=f.y-.3&&p.y<f.ceiling+.1)||original.contains(point)&&p.y<0.3};
 const localPolygon=body=>body.polygonCR.map(([c,r])=>{const p=local(c*metresPerCell,r*metresPerCell);return[p.x,p.z]});
 const worldPolygon=p=>p.map(([x,z])=>{const q=root.localToWorld(new T.Vector3(x,0,z));return[q.x/metresPerCell,q.z/metresPerCell]});
 let oldBodies=null,combined=null;entry.getCollisionBodies=()=>{const current=original.bodies();if(current!==oldBodies){oldBodies=current;let preserved=current;if(instance.assetId==='strip_club')preserved=current.flatMap(body=>{if(body.movingDoor)return[body];let polygons=[localPolygon(body)];for(const s of stairs)polygons=polygons.flatMap(p=>subtractRect(p,s.footprint));return polygons.map(p=>({...body,polygonCR:worldPolygon(p)}))});if(roof)preserved=preserved.flatMap(body=>{const roofWorld=baseY+roof.y-.025;if(body.movingDoor||(body.maxYM??0)<=roofWorld)return[body];return[{...body,maxYM:roofWorld},...subtractRect(localPolygon(body),[roof.rect[0]-.15,roof.rect[1]-.15,roof.rect[2]+.15,roof.rect[3]+.15]).map(p=>({...body,minYM:Math.max(body.minYM??0,roofWorld),polygonCR:worldPolygon(p)}))]});combined=preserved.concat(bodies)}return combined};
 let disposed=false;entry.dispose=()=>{if(disposed)return;disposed=true;for(const[n,v]of hidden)n.visible=v;for(const[n,p]of movedNodes)n.position.copy(p);for(const[n,g]of restores.slice().reverse())n.geometry=g;for(const rec of records)release(rec);for(const s of stairs)s.dispose();ladder?.dispose();root.removeFromParent();for(const mesh of ownedInstances)mesh.dispose();ownedInstances.length=0;for(const g of geometry)g.dispose();storeyResources.dispose();original.dispose()};
 const report={floors:floors.length,rooms:rooms.length,stairs:stairs.length,roofAccess:!!ladder};entry.report.storeys=report;
 entry.storeys={root,floors,stairs,rooms,floorPlans,ladder,roof,report,worldPoint:p=>root.localToWorld(new T.Vector3(p.x,p.y,p.z))};return entry.storeys;
}
