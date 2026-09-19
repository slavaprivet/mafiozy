import {createInteriorMeshPool} from './interior_mesh_pool.mjs';
import {acquireInteriorFinish} from './interior_finishes.mjs';
import {createInteriorRoomDoors} from './interior_room_doors.mjs';
import {planFunctionalRoom} from './interior_functional_furnishing.mjs';
import {resolveBuildingPurpose} from './building_interior_purpose.mjs';
import {createInteriorSafe} from './interior_interactive_safe.mjs';
import {registerInteriorSafe,requestInteriorSafeAction} from './interior_safe_registry.mjs';
import {planBankRooms} from './interior_bank_room_plan.mjs';

const overlap=(a,b,p=0)=>a[0]<b[2]+p&&a[2]>b[0]-p&&a[1]<b[3]+p&&a[3]>b[1]-p;
const contained=(a,b,p=0)=>a[0]>=b[0]+p&&a[2]<=b[2]-p&&a[1]>=b[1]+p&&a[3]<=b[3]-p;
function roomFrame(room){const r=room.rect,cx=(r[0]+r[2])/2,cz=(r[1]+r[3])/2;let yaw=0;if(room.door){if(Math.abs(room.door.x-r[0])<.15)yaw=-Math.PI/2;else if(Math.abs(room.door.x-r[2])<.15)yaw=Math.PI/2;else if(Math.abs(room.door.z-r[1])<.15)yaw=Math.PI;}const sideways=Math.abs(Math.sin(yaw))>.5;return{cx,cz,yaw,width:sideways?r[3]-r[1]:r[2]-r[0],depth:sideways?r[2]-r[0]:r[3]-r[1]};}
function finishCode(text,fallback){const s=String(text).toLowerCase();return /brick|кирпич/.test(s)?'brick':/wallpaper|обо/.test(s)?'wallpaper':/concrete|бетон/.test(s)?'concrete':/parquet|wood|панел|дерев|паркет/.test(s)?'wood':/tile|stone|известняк|плит|камен/.test(s)?'tile':fallback;}
export function createBuildingInteriorDesign({THREE:T,entry,visual,instance,metresPerCell=4.1}){
 if(!entry?.storeys||entry.interiorDesign)return entry?.interiorDesign;
 const storeys=entry.storeys,frame=storeys.root,root=new T.Group();root.name='Themed_Building_Interior';frame.add(root);frame.updateWorldMatrix(true,true);
 const inverse=frame.matrixWorld.clone().invert(),local=p=>p.clone().applyMatrix4(inverse),baseY=frame.getWorldPosition(new T.Vector3()).y;
 const pool=createInteriorMeshPool(T,root),doors=createInteriorRoomDoors(T,{root:frame,entry,metresPerCell}),restores=[],ownedFinishes=[],furnitureBodies=[],accepted=[],reports=[],safes=[],unregisterSafes=[],purpose=resolveBuildingPurpose(instance);
 const original={proximity:entry.proximity.bind(entry),interact:entry.interact.bind(entry),update:entry.update.bind(entry),bodies:entry.getCollisionBodies.bind(entry),dispose:entry.dispose.bind(entry),needsUpdate:Object.getOwnPropertyDescriptor(entry,'needsUpdate')};
 const originalBodies=original.bodies(),staticBounds=originalBodies.filter(b=>!b.movingDoor).map(b=>{const pts=b.polygonCR.map(([x,z])=>local(new T.Vector3(x*metresPerCell,baseY,z*metresPerCell)));return{rect:[Math.min(...pts.map(p=>p.x)),Math.min(...pts.map(p=>p.z)),Math.max(...pts.map(p=>p.x)),Math.max(...pts.map(p=>p.z))],min:(b.minYM??baseY)-baseY,max:(b.maxYM??100)-baseY}});
 const rooms=storeys.rooms.map(r=>({...r,rect:r.rect.slice()}));
 // Read the seven actual bank rectangles from named authored partitions;
 // a ray through an open doorway must never merge neighbouring rooms.
 if(instance.bankLayout){rooms.length=0;const bank=planBankRooms({instance}),metricRect=r=>{const points=[[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]].map(([x,z])=>local(visual.localToWorld(new T.Vector3(x,0,z))));return[Math.min(...points.map(p=>p.x)),Math.min(...points.map(p=>p.z)),Math.max(...points.map(p=>p.x)),Math.max(...points.map(p=>p.z))]},metricDoor=d=>{const p=local(visual.localToWorld(new T.Vector3(d.x,d.y,d.z)));return{...d,x:p.x,y:p.y,z:p.z}};
  for(const room of bank.rooms)rooms.push({...room,y:storeys.floors[0].y,rect:metricRect(room.rect),door:metricDoor(room.door),doors:room.doors.map(metricDoor),reservedPaths:room.reservedPaths.map(p=>({...p,rect:metricRect(p.rect)})),openPlan:room.id==='public_lobby'});
 }
 const planner=planFunctionalRoom,first=planner({purpose,assetId:instance.assetId,level:0,roomIndex:0,width:4,depth:5,seed:instance.id}),wallLease=acquireInteriorFinish(T,{color:first.palette.wall,finish:finishCode(first.finish,'plaster')}),floorLease=acquireInteriorFinish(T,{color:first.palette.floor,finish:finishCode(first.floorFinish,'wood'),floor:true}),wallFinish=wallLease.material,floorFinish=floorLease.material;ownedFinishes.push(wallLease,floorLease);
 // Geometry is already window-clipped; changing its surface cannot cover a pane.
 entry.object.traverse(n=>{if(!n.isMesh||n===root)return;for(let p=n.parent;p;p=p.parent)if(p===root)return;if(/^(Entry_Interior_(Left|Right|Rear|Front)|Storey_Walls_And_Ceilings|Interior_(Left|Right|Rear|Front)|Bank_.*(Wall|Partition))/.test(n.name)){restores.push([n,n.material]);n.material=wallFinish;}else if(/^(Storey_Floors|Entry_Interior_Floor|Interior_Floor)$/.test(n.name)){restores.push([n,n.material]);n.material=floorFinish;}});
 const transform=new T.Matrix4(),rotation=new T.Quaternion(),axis=new T.Vector3(0,1,0);
 const compose=(x,y,z,yaw)=>new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromAxisAngle(axis,yaw),new T.Vector3(1,1,1));
 function addBox(p,s,color,matrix){pool.add({shape:'box',position:p,size:s,color},matrix)}
 const bodyFor=(bounds,y,h)=>{const points=[[bounds[0],bounds[1]],[bounds[2],bounds[1]],[bounds[2],bounds[3]],[bounds[0],bounds[3]]].map(([x,z])=>frame.localToWorld(new T.Vector3(x,y,z)));return{polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseY+y,maxYM:baseY+y+h,buildingEntryId:instance.id,interiorFurniture:true};};
 for(let ri=0;ri<rooms.length;ri++){
  const room=rooms[ri],f=storeys.floors[room.level],rf=roomFrame(room),floorPlan=storeys.floorPlans?.find(p=>p.level===room.level);
  const roomMatrix=compose(rf.cx,room.y,rf.cz,rf.yaw),roomInverse=roomMatrix.clone().invert(),reserved=storeys.stairs.filter(s=>s.lowerLevel===room.level||s.upperLevel===room.level).map(s=>s.footprint),paths=(room.reservedPaths??floorPlan?.reservedPaths??[]).map(p=>p.rect);
  const roomRect=rect=>{const b=new T.Box3(new T.Vector3(rect[0],room.y,rect[1]),new T.Vector3(rect[2],room.y,rect[3])).applyMatrix4(roomInverse);return[b.min.x,b.min.z,b.max.x,b.max.z]};
  const toDoor=d=>{const p=new T.Vector3(d.x,room.y,d.z).applyMatrix4(roomInverse);return{x:p.x,z:p.z,width:d.width??1.3}};
  // Reserve a pedestrian route through an authored room door plus its full swing.
  let entrance=null;if(room.door){const d=room.door,onX=Math.abs(d.x-room.rect[0])<.15||Math.abs(d.x-room.rect[2])<.15,inward=onX?(d.x<rf.cx?-1:1):(d.z<rf.cz?-1:1),half=(d.width??1.3)/2+.12,reach=d.open?1.35:(d.width??1.3)+.15,sweep=new T.Box3(new T.Vector3(-half,0,inward===1?-reach:-.2),new T.Vector3(half,2.1,inward===1?.2:reach)).applyMatrix4(compose(d.x,room.y,d.z,onX?Math.PI/2:0));entrance=[sweep.min.x,sweep.min.z,sweep.max.x,sweep.max.z];}
  const plan=planner({purpose,role:room.role,assetId:instance.assetId,level:room.level,roomIndex:ri,width:rf.width,depth:rf.depth,seed:instance.id,door:room.door?toDoor(room.door):null,connections:room.doors?.filter(d=>d!==room.door).map(toDoor)??[],reserved:reserved.map(r=>[r[0]-.25,r[1]-.25,r[2]+.25,r[3]+.25]).concat(paths,entrance?[entrance]:[],staticBounds.filter(b=>b.max>room.y+.12&&b.min<Math.min(f.ceiling-.12,room.y+1.8)).map(b=>[b.rect[0]-.04,b.rect[1]-.04,b.rect[2]+.04,b.rect[3]+.04]),accepted.filter(a=>Math.abs(a.y-room.y)<.3).map(a=>[a.bounds[0]-.07,a.bounds[1]-.07,a.bounds[2]+.07,a.bounds[3]+.07])).map(roomRect)});
  const report={id:room.id,level:room.level,name:room.name??plan.name,role:room.role??plan.role,purpose:purpose.kind,rect:room.rect,openPlan:!!room.openPlan,items:[],placements:[],rejected:0,omitted:plan.statistics?.omitted??[],door:!!room.door,portalWidth:room.door?.width??null};reports.push(report);
  // Real skirting/cornices catch grazing light; doorway spans stay open.
  const trimOnEdge=(x,z)=>{if(!room.openPlan)return true;const p=new T.Vector3(x,0,z).applyMatrix4(roomMatrix);return Math.min(Math.abs(p.x-f.rect[0]),Math.abs(p.x-f.rect[2]),Math.abs(p.z-f.rect[1]),Math.abs(p.z-f.rect[3]))<.08};
  const connections=(room.doors??(room.door?[room.door]:[])).map(toDoor),trimSpans=(axis,edge,length)=>{let spans=[[-length/2,length/2]];for(const d of connections){if(Math.abs((axis==='x'?d.x:d.z)-edge)>.2)continue;const center=axis==='x'?d.z:d.x,half=d.width/2+.025;spans=spans.flatMap(([a,b])=>[[a,Math.min(b,center-half)],[Math.max(a,center+half),b]].filter(([x,z])=>z-x>.08))}return spans};
  for(const side of[-1,1])if(trimOnEdge(side*rf.width/2,0))for(const[a,b]of trimSpans('x',side*rf.width/2,rf.depth))for(const h of[.065,f.ceiling-room.y-.065])addBox([side*(rf.width/2-.028),h,(a+b)/2],[.045,.1,b-a],plan.palette.wood,roomMatrix);
  const portalHalf=(room.door?.width??1.3)/2+.025;
  for(const zz of[-rf.depth/2+.028,rf.depth/2-.028]){if(!trimOnEdge(0,zz))continue;for(const[a,b]of trimSpans('z',zz,rf.width))for(const h of[.065,f.ceiling-room.y-.065])addBox([(a+b)/2,h,zz],[b-a,.1,.045],plan.palette.wood,roomMatrix);}
  if(room.door&&!instance.bankLayout){
   const edge=portalHalf+.07,stripWidth=rf.width/2-edge,back=rf.depth/2-.055;
   // Panelling/art sit on an existing interior partition, never across windows.
   for(const side of[-1,1])if(stripWidth>.2){const cx=side*(edge+stripWidth/2);addBox([cx,.43,back],[stripWidth,.7,.035],plan.palette.accent,roomMatrix);addBox([cx,.79,back-.018],[stripWidth,.035,.055],plan.palette.metal,roomMatrix);}
   if(stripWidth>.6){const ax=-edge-stripWidth/2,aw=Math.min(.65,stripWidth-.14);addBox([ax,1.48,back-.04],[aw,.74,.055],plan.palette.wood,roomMatrix);addBox([ax,1.48,back-.073],[aw-.07,.66,.014],'#d8ccb3',roomMatrix);addBox([ax-.07,1.48,back-.084],[(aw-.14)*.48,.43,.013],plan.palette.accent,roomMatrix);addBox([ax+.09,1.39,back-.096],[(aw-.14)*.45,.25,.012],plan.palette.metal,roomMatrix);}
  }
  function place(item){
   if(instance.bankLayout&&item.kind==='functional_safe')return false;
   transform.multiplyMatrices(roomMatrix,compose(item.x,0,item.z,item.yaw??0));const box=new T.Box3(new T.Vector3(-item.width/2,0,-item.depth/2),new T.Vector3(item.width/2,item.height,item.depth/2)).applyMatrix4(transform),bounds=[box.min.x,box.min.z,box.max.x,box.max.z];
   if(!contained(bounds,room.rect,.05)||box.max.y>f.ceiling-.12||reserved.some(s=>overlap(bounds,s,.25))||paths.some(s=>overlap(bounds,s,.03))||entrance&&overlap(bounds,entrance)||staticBounds.some(b=>b.max>room.y+.12&&b.min<box.max.y&&overlap(bounds,b.rect,.04))||accepted.some(a=>Math.abs(a.y-room.y)<.3&&overlap(bounds,a.bounds,.07))){report.rejected++;return false}
   if(item.kind==='functional_safe'){
    const roomId=room.id??`${instance.id}:floor:${room.level}:room:${ri}`,id=`interior-safe:${roomId}`,p=new T.Vector3().setFromMatrixPosition(transform),safe=createInteriorSafe(T,{id,buildingId:instance.id,roomId,position:p,yaw:rf.yaw+(item.yaw??0),metresPerCell,onUnlock:(id,detail)=>requestInteriorSafeAction('unlock',id,detail),onCollect:(id,detail)=>requestInteriorSafeAction('collect',id,detail)});
    root.add(safe.object);root.updateWorldMatrix(true,true);safes.push(safe);const world=safe.object.getWorldPosition(new T.Vector3());unregisterSafes.push(registerInteriorSafe(safe,{purpose:purpose.kind,position:world.toArray()}));
   }else{
    for(const part of item.parts)pool.add(part,transform);
    if(item.collisionParts)for(const body of item.collisionParts){const q=body.rect,points=[[q[0],q[1]],[q[2],q[1]],[q[2],q[3]],[q[0],q[3]]].map(([x,z])=>frame.localToWorld(new T.Vector3(x,body.minY,z).applyMatrix4(transform)));furnitureBodies.push({polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseY+room.y+body.minY,maxYM:baseY+room.y+body.maxY,buildingEntryId:instance.id,interiorFurniture:true,furnitureKind:item.kind,cover:!!body.cover,coverKind:body.kind})}
    else if(item.height>.2)furnitureBodies.push(bodyFor(bounds,room.y,item.height));
   }
   accepted.push({y:room.y,bounds,kind:item.kind});report.items.push(item.kind);report.placements.push({kind:item.kind,bounds,y:room.y,height:item.height});return true;
  }
  for(const item of plan.furniture)place(item);
  // Small rooms still get useful furniture, located against a free wall.
  if(instance.bankLayout&&!report.items.length){const fallback={kind:'niche_console',width:.65,depth:.28,height:.95,parts:[{shape:'box',position:[0,.43,0],size:[.62,.84,.25],color:plan.palette.wood},{shape:'box',position:[0,.875,0],size:[.65,.05,.28],color:plan.palette.accent},{shape:'box',position:[0,.6,.133],size:[.14,.03,.022],color:plan.palette.metal},{shape:'box',position:[-.15,.925,0],size:[.23,.05,.18],color:'#dfd4bd'}]};outer:for(const x of[-rf.width/2+.4,rf.width/2-.4,0])for(const z of[-rf.depth/2+.22,rf.depth/2-.22,0])if(place({...fallback,x,z,yaw:0}))break outer;}
  // Thin rugs and perimeter mouldings make each room read as an intentional space.
  const rw=Math.min(rf.width-.3,rf.width*rf.depth>65?4.8:3),rd=Math.min(rf.depth-.3,rf.width*rf.depth>65?5.8:3.6),rugBox=new T.Box3(new T.Vector3(-rw/2,0,-.1-rd/2),new T.Vector3(rw/2,0,-.1+rd/2)).applyMatrix4(roomMatrix),rug=[rugBox.min.x,rugBox.min.z,rugBox.max.x,rugBox.max.z];
  if(rw>1&&rd>1&&!reserved.some(s=>overlap(rug,s,.08))&&contained(rug,room.rect,.05)){addBox([0,.009,-.1],[rw,.014,rd],plan.palette.accent,roomMatrix);addBox([0,.018,-.1],[rw-.12,.008,rd-.12],plan.palette.floor,roomMatrix);}
  // Decorative luminaires use the already budgeted floor light. Their arms,
  // shades and ceiling rose are static instances, not additional GPU lights.
  if(room.openPlan&&f.ceiling-room.y>2.8){const candidates=report.placements.filter(p=>/coffee_table|dining_set|meeting_table|reception/.test(p.kind)),candidate=candidates[0],cx=candidate?(candidate.bounds[0]+candidate.bounds[2])/2:rf.cx,cz=candidate?(candidate.bounds[1]+candidate.bounds[3])/2:rf.cz;
   if(!reserved.some(r=>overlap([cx-.8,cz-.8,cx+.8,cz+.8],r,.2))){const ceiling=Math.min(f.ceiling,storeys.floors[room.level+1]?.y-.14||Infinity)-room.y,lightMatrix=compose(cx,room.y,cz,0),ornate=['nightclub','strip_club','restaurant','hotel','residential'].includes(purpose.kind),drop=Math.min(.7,ceiling-2.25),stem=ceiling-drop;
    pool.add({shape:'cylinder',position:[0,ceiling-.04,0],size:[.32,.065,.32],color:plan.palette.metal,metalness:.6},lightMatrix);pool.add({shape:'cylinder',position:[0,ceiling-drop/2,0],size:[.035,drop,.035],color:plan.palette.metal,metalness:.6},lightMatrix);
    if(ornate){for(let i=0;i<6;i++){const a=i*Math.PI/3,x=Math.sin(a)*.58,z=Math.cos(a)*.58;pool.add({shape:'box',position:[x/2,stem,z/2],size:[.035,.035,.6],yaw:a,color:plan.palette.metal,metalness:.6},lightMatrix);pool.add({shape:'cylinder',position:[x,stem+.085,z],size:[.22,.18,.22],color:'#d9c5a0'},lightMatrix);pool.add({shape:'sphere',position:[x,stem-.11,z],size:[.07,.18,.07],color:'#c8d4cf',metalness:.6},lightMatrix)}}else addBox([0,stem,0],[1.1,.075,.46],'#ddd9c9',lightMatrix);
   }
  }
  if(room.door&&!room.door.open){const d=room.door,onX=Math.abs(d.x-room.rect[0])<.15||Math.abs(d.x-room.rect[2])<.15,doorAxis=onX?'z':'x';doors.create({x:d.x,z:d.z,y:room.y,axis:doorAxis,width:d.width,inward:onX?(d.x<rf.cx?-1:1):(d.z<rf.cz?-1:1),name:report.name,color:plan.palette.wood});
   // Brass-edged plaque is geometry, without unreadable tiny generated text.
   const signMatrix=compose(d.x,room.y,d.z,onX?Math.PI/2:0);addBox([-.88,1.57,.085],[.27,.32,.022],plan.palette.metal,signMatrix);addBox([-.88,1.57,.103],[.22,.26,.018],plan.palette.accent,signMatrix);
  }
 }
 // Every door keeps its own hinge and exact sweep collider, while the visible
 // wood/brass panels share one dynamic instance draw per material in this
 // building. Finalise only after all room plans have contributed their leaves.
 doors.finalize();const statistics=pool.flush();root.updateWorldMatrix(true,true);
 let oldBase=null,oldDoors=null,oldSafes=[],combined=null,disposed=false;
 entry.getCollisionBodies=()=>{const a=original.bodies(),b=doors.bodies(),c=safes.map(s=>s.getCollisionBodies());if(a!==oldBase||b!==oldDoors||c.some((v,i)=>v!==oldSafes[i])){oldBase=a;oldDoors=b;oldSafes=c;combined=a.concat(furnitureBodies,b,...c)}return combined};
 entry.proximity=(point,distance)=>{const a=original.proximity(point,distance),b=doors.near(point);return b&&(!a||b.distance<a.distance)?b:a};
 entry.interact=point=>{const n=entry.proximity(point);return n?.door?doors.interact(point):original.interact(point)};
 entry.update=(dt,point)=>{original.update(dt,point);doors.update(Math.max(0,Math.min(.1,dt)),point);for(const safe of safes)if(safe.needsUpdate)safe.update(dt)};
 Object.defineProperty(entry,'needsUpdate',{configurable:true,get(){return doors.active||safes.some(s=>s.needsUpdate)||(original.needsUpdate?.get?.call(entry)??false)}});
 entry.dispose=()=>{if(disposed)return;disposed=true;for(const unregister of unregisterSafes)unregister();for(const safe of safes)safe.dispose();doors.dispose();pool.dispose();root.removeFromParent();for(const[n,m]of restores)n.material=m;for(const finish of ownedFinishes)finish.dispose();original.dispose()};
 const doorStatistics=doors.stats(),api={root,purpose,rooms:reports,safes,doors:doors.doors,report:{purpose:purpose.kind,rooms:reports.length,furnishedRooms:reports.filter(r=>r.items.length).length,furniture:accepted.length,safes:safes.length,doors:doors.doors.length,doorDraws:doorStatistics.draws,...statistics},dispose:entry.dispose};entry.interiorDesign=api;entry.report.interiorDesign=api.report;return api;
}
