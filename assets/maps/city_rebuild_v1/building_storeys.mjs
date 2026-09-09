import {BUILDING_STOREY_PROFILES} from './building_storey_profiles.mjs';
import {createFittedStaircase} from './oriented_staircase.mjs';
import {createRoofLadder} from './roof_ladder.mjs';
import {subtractBoxFromGeometry} from './building_entry.mjs';

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
export function createBuildingStoreys({THREE:T,entry,visual,instance,metresPerCell=4.1}){
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
 const stairCore=floors.map(f=>f.rect).reduce(intersect),stairs=[];for(let i=0;i<floors.length-1;i++){const a=floors[i],b=floors[i+1];const stair=createFittedStaircase(T,{rect:stairCore,floorHeight:b.y-a.y,baseY:a.y,flightWidth:1.3});stair.lowerLevel=i;stair.upperLevel=i+1;stairs.push(stair)}
 if(['old_town_narrow_townhouse_v1','pawnshop'].includes(instance.assetId)&&stairs.length&&stairs.every(s=>!s.rotated)){
  // Storey heights may differ. A common pivot preserves the identical
  // full-floor landing line between levels instead of shifting it per flight.
  const core=stairs.map(s=>s.footprint).reduce((a,b)=>[Math.min(a[0],b[0]),Math.min(a[1],b[1]),Math.max(a[2],b[2]),Math.max(a[3],b[3])]);
  for(let i=0;i<stairs.length;i++)stairs[i]=faceStairTowardFront(T,stairs[i],core);
 }
 for(const stair of stairs)root.add(stair.group);
 const hidden=[],restores=[],records=[],geometry=[],bodies=[],rooms=[],boxes=[],movedNodes=[],storeyResources=acquireStoreyResources(T);
 const {wall,floor:floorMat,trim}=storeyResources.materials;
 const worldBody=(rect,minY,maxY,kind)=>{const pts=[[rect[0],rect[1]],[rect[2],rect[1]],[rect[2],rect[3]],[rect[0],rect[3]]].map(([x,z])=>root.localToWorld(new T.Vector3(x,0,z)));return{polygonCR:pts.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseY+minY,maxYM:baseY+maxY,buildingEntryId:instance.id,storeyPart:kind}};
 function box(name,rect,bottom,top,material=wall,collision=false){if(rect[2]-rect[0]<.001||rect[3]-rect[1]<.001||top-bottom<.001)return;if(collision)bodies.push(worldBody(rect,bottom,top,name));if(!name.startsWith('Entry_Interior_')){boxes.push({name,rect,bottom,top,material});return}const g=new T.BoxGeometry(rect[2]-rect[0],top-bottom,rect[3]-rect[1]);geometry.push(g);const n=new T.Mesh(g,material);n.name=name;n.position.set((rect[0]+rect[2])/2,(bottom+top)/2,(rect[1]+rect[3])/2);n.castShadow=n.receiveShadow=true;root.add(n);return n}
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
  // Reserve the whole stair strip and a continuous central circulation route.
  const reserved=stairs.filter(s=>s.lowerLevel===f.level||s.upperLevel===f.level).map(s=>s.footprint);
  const width=f.rect[2]-f.rect[0],depth=f.rect[3]-f.rect[1],midX=Math.min(f.rect[2]-1.4,Math.max(f.rect[0]+1.4,0));
  const hall=[midX-.75,f.rect[1],midX+.75,f.rect[3]],front=f.rect[3]-.5;
  for(const side of[-1,1]){const x0=side<0?f.rect[0]:hall[2],x1=side<0?hall[0]:f.rect[2];if(x1-x0<1.45)continue;const segments=depth>12?3:depth>6?2:1;
   for(let j=0;j<segments;j++){const z0=f.rect[1]+depth*j/segments+.08,z1=Math.min(front,f.rect[1]+depth*(j+1)/segments-.08),rr=[x0,z0,x1,z1];if(z1-z0<1.8||reserved.some(s=>{const a=intersect(rr,s);return a[2]>a[0]-.5&&a[3]>a[1]-.5}))continue;
    const x=side<0?x1:x0,door=(z0+z1)/2,doorHalf=.65;
    for(const[zA,zB]of[[z0,door-doorHalf],[door+doorHalf,z1]])box('Room_Partition',[x-.06,zA,x+.06,zB],f.y,f.ceiling,wall,true);
    box('Room_Door_Header',[x-.06,door-doorHalf,x+.06,door+doorHalf],f.y+2.15,f.ceiling,wall,true);
    for(const zz of[door-doorHalf,door+doorHalf])box('Room_Door_Frame',[x-.085,zz-.045,x+.085,zz+.045],f.y,f.y+2.18,trim);
    if(j>0)box('Room_Partition',[x0,z0-.06,x1,z0+.06],f.y,f.ceiling,wall,true);
    rooms.push({level:f.level,name:`Комната ${rooms.length+1}`,rect:rr,y:f.y,door:{x,y:f.y,z:door}});
   }
  }
  if(!rooms.some(r=>r.level===f.level)){
   const end=reserved.length?Math.max(...reserved.map(s=>s[3]))+.25:f.rect[1]+depth*.4;
   if(f.rect[3]-end>1.5){const mid=(f.rect[0]+f.rect[2])/2;for(const[a,b]of[[f.rect[0],mid-.65],[mid+.65,f.rect[2]]])box('Room_Partition',[a,end-.06,b,end+.06],f.y,f.ceiling,wall,true);box('Room_Door_Header',[mid-.65,end-.06,mid+.65,end+.06],f.y+2.15,f.ceiling,wall,true);rooms.push({level:f.level,name:'Комната',rect:[f.rect[0],end,f.rect[2],f.rect[3]],y:f.y,door:{x:mid,y:f.y,z:end}})}
   else rooms.push({level:f.level,name:'Зал и лестничная площадка',rect:f.rect.slice(),y:f.y});
  }
 }
 for(const s of stairs)for(const o of s.obstacles)bodies.push(worldBody(o.rect,o.minY,o.maxY,o.kind));
 let ladder=null,roof=null;
 const roofSelected=instance.role==='bank_shell'||(['pawnshop','gun_shop','bookmaker'].includes(instance.assetId)&&/001$/.test(instance.id));
 if(roofSelected&&profile.roof?.length){const surface=profile.roof[0],rr=metricRect([surface.min[0],surface.min[2],surface.max[0],surface.max[2]]),roofY=toMetric(0,surface.max[1],0).y;
  const sign=instance.role==='bank_shell'?1:-1,x=rr[2]-1.6,z=sign===1?rr[3]:rr[1],lower={x,y:-baseY,z:z+sign*.85},upper={x,y:roofY+.015,z:z-sign*1.05};
  ladder=createRoofLadder(T,{id:instance.id,lower,upper,outward:{x:0,z:sign}});root.add(ladder.object);roof={rect:rr,y:upper.y};
  // Open only the small parapet exit; the roof slab stays intact.
  const aperture=new T.Box3(new T.Vector3(x-.72,roofY+.01,z-1.2),new T.Vector3(x+.72,roofY+2.5,z+1.2));
  visual.updateWorldMatrix(true,true);visual.traverse(n=>{if(!n.isMesh||n.isInstancedMesh||!n.geometry?.attributes.position)return;for(let p=n;p&&p!==visual;p=p.parent)if(!p.visible||p===entry.object)return;const b=new T.Box3().setFromBufferAttribute(n.geometry.attributes.position).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,n.matrixWorld));if(b.intersectsBox(aperture))clipped(n,[aperture])});
  const descriptor=ladder.descriptor,worldPoint=p=>root.localToWorld(new T.Vector3(p.x,p.y,p.z));const normal=new T.Vector3(0,0,sign).transformDirection(root.matrixWorld),right=new T.Vector3(sign,0,0).transformDirection(root.matrixWorld);
  ladder.worldDescriptor={...descriptor,lower:worldPoint(descriptor.lower),upper:worldPoint(descriptor.upper),path:descriptor.path.map(worldPoint),normal:{x:normal.x,z:normal.z},right:{x:right.x,z:right.z},yaw:Math.atan2(-normal.x,-normal.z)};
  const[a,b,c,d]=rr;for(const edge of[[a,b,a+.08,d],[c-.08,b,c,d]])box('Roof_Edge_Rail',edge,roof.y,roof.y+.9,trim,true);
  for(const zz of[b,d]){const intervals=zz===z?[[a,x-.72],[x+.72,c]]:[[a,c]];for(const[l,h]of intervals)box('Roof_Edge_Rail',[l,zz-.04,h,zz+.04],roof.y,roof.y+.9,trim,true)}
 }
 const {boxGeometry}=storeyResources;
 for(const material of Object.values(storeyResources.materials)){const items=boxes.filter(b=>b.material===material);if(!items.length)continue;const mesh=new T.InstancedMesh(boxGeometry,material,items.length);mesh.name=material===floorMat?'Storey_Floors':material===trim?'Room_Door_Frames':'Storey_Walls_And_Ceilings';const m=new T.Matrix4(),q=new T.Quaternion();items.forEach((b,i)=>mesh.setMatrixAt(i,m.compose(new T.Vector3((b.rect[0]+b.rect[2])/2,(b.bottom+b.top)/2,(b.rect[1]+b.rect[3])/2),q,new T.Vector3(b.rect[2]-b.rect[0],b.top-b.bottom,b.rect[3]-b.rect[1]))));mesh.castShadow=mesh.receiveShadow=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();root.add(mesh)}
 root.updateWorldMatrix(true,true);
 const original={floor:entry.floorHeight.bind(entry),ceiling:entry.ceilingHeight.bind(entry),bodies:entry.getCollisionBodies.bind(entry),contains:entry.containsInterior.bind(entry),dispose:entry.dispose.bind(entry)};
 const local=(x,z,y=baseY)=>new T.Vector3(x,y,z).applyMatrix4(inverse);
 const bounds=new T.Box3().setFromObject(root);if(entry.sampleBounds)bounds.union(entry.sampleBounds);entry.sampleBounds=bounds;
 function samples(x,z,ref){const out=[];for(const f of floors){if(!inRect(x,z,f.rect))continue;const hole=stairs.find(s=>s.upperLevel===f.level)?.holeRect;if(!hole||!inRect(x,z,hole))out.push(f.y)}for(const s of stairs){const y=s.sampleFloor(x,z,ref);if(y!==null)out.push(y)}if(roof&&inRect(x,z,roof.rect,.001))out.push(roof.y);return out}
 entry.floorHeight=(x,z,referenceY=0)=>{if(x<bounds.min.x||x>bounds.max.x||z<bounds.min.z||z>bounds.max.z)return null;const p=local(x,z,referenceY),values=samples(p.x,p.z,p.y).filter(y=>y<=p.y+.28+1e-6);if(values.length)return baseY+Math.max(...values);return original.floor(x,z)};
 entry.ceilingHeight=point=>{const p=local(point.x,point.z,point.y??baseY);if(roof&&p.y>=roof.y-.2&&inRect(p.x,p.z,roof.rect))return null;const values=[];for(const f of floors)if(inRect(p.x,p.z,f.rect)){const next=floors[f.level+1],hole=stairs.find(s=>s.lowerLevel===f.level)?.holeRect;if(f.ceiling>p.y+.3&&(!next||!inRect(p.x,p.z,next.rect)))values.push(f.ceiling);if(next&&inRect(p.x,p.z,next.rect)&&(!hole||!inRect(p.x,p.z,hole))&&next.y-.14>p.y+.3)values.push(next.y-.14)}for(const s of stairs){const c=s.sampleCeiling(p.x,p.z,p.y);if(c!==null)values.push(c)}return values.length?baseY+Math.min(...values):original.contains(point)?null:original.ceiling(point)};
 entry.containsInterior=point=>{const p=local(point.x,point.z,point.y??baseY);return floors.some(f=>inRect(p.x,p.z,f.rect)&&p.y>=f.y-.3&&p.y<f.ceiling+.1)||original.contains(point)&&p.y<0.3};
 const localPolygon=body=>body.polygonCR.map(([c,r])=>{const p=local(c*metresPerCell,r*metresPerCell);return[p.x,p.z]});
 const worldPolygon=p=>p.map(([x,z])=>{const q=root.localToWorld(new T.Vector3(x,0,z));return[q.x/metresPerCell,q.z/metresPerCell]});
 let oldBodies=null,combined=null;entry.getCollisionBodies=()=>{const current=original.bodies();if(current!==oldBodies){oldBodies=current;let preserved=current;if(instance.assetId==='strip_club')preserved=current.flatMap(body=>{if(body.movingDoor)return[body];let polygons=[localPolygon(body)];for(const s of stairs)polygons=polygons.flatMap(p=>subtractRect(p,s.footprint));return polygons.map(p=>({...body,polygonCR:worldPolygon(p)}))});if(roof)preserved=preserved.flatMap(body=>{const roofWorld=baseY+roof.y-.025;if(body.movingDoor||(body.maxYM??0)<=roofWorld)return[body];return[{...body,maxYM:roofWorld},...subtractRect(localPolygon(body),[roof.rect[0]-.15,roof.rect[1]-.15,roof.rect[2]+.15,roof.rect[3]+.15]).map(p=>({...body,minYM:Math.max(body.minYM??0,roofWorld),polygonCR:worldPolygon(p)}))]});combined=preserved.concat(bodies)}return combined};
 let disposed=false;entry.dispose=()=>{if(disposed)return;disposed=true;for(const[n,v]of hidden)n.visible=v;for(const[n,p]of movedNodes)n.position.copy(p);for(const[n,g]of restores.slice().reverse())n.geometry=g;for(const rec of records)release(rec);for(const s of stairs)s.dispose();ladder?.dispose();root.removeFromParent();for(const g of geometry)g.dispose();storeyResources.dispose();original.dispose()};
 const report={floors:floors.length,rooms:rooms.length,stairs:stairs.length,roofAccess:!!ladder};entry.report.storeys=report;
 entry.storeys={root,floors,stairs,rooms,ladder,roof,report,worldPoint:p=>root.localToWorld(new T.Vector3(p.x,p.y,p.z))};return entry.storeys;
}
