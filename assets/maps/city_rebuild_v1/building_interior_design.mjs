import {planResidentialRoom} from './residential_furnishing.mjs';
import {planCommercialRoom} from './commercial_furnishing.mjs';
import {planPublicRoom} from './public_furnishing.mjs';
import {createInteriorMeshPool} from './interior_mesh_pool.mjs';
import {acquireInteriorFinish} from './interior_finishes.mjs';
import {createInteriorRoomDoors} from './interior_room_doors.mjs';

const overlap=(a,b,p=0)=>a[0]<b[2]+p&&a[2]>b[0]-p&&a[1]<b[3]+p&&a[3]>b[1]-p;
const contained=(a,b,p=0)=>a[0]>=b[0]+p&&a[2]<=b[2]-p&&a[1]>=b[1]+p&&a[3]<=b[3]-p;
function roomFrame(room){const r=room.rect,cx=(r[0]+r[2])/2,cz=(r[1]+r[3])/2;let yaw=0;if(room.door){if(Math.abs(room.door.x-r[0])<.15)yaw=-Math.PI/2;else if(Math.abs(room.door.x-r[2])<.15)yaw=Math.PI/2;else if(Math.abs(room.door.z-r[1])<.15)yaw=Math.PI;}const sideways=Math.abs(Math.sin(yaw))>.5;return{cx,cz,yaw,width:sideways?r[3]-r[1]:r[2]-r[0],depth:sideways?r[2]-r[0]:r[3]-r[1]};}
function choosePlan(id){return /hospital|civic|print_shop|bank_/.test(id)?planPublicRoom:/pawnshop|gun_shop|bookmaker|nightclub|strip_club|glass_pavilion/.test(id)?planCommercialRoom:planResidentialRoom;}
function finishCode(text,fallback){const s=String(text).toLowerCase();return /brick|кирпич/.test(s)?'brick':/wallpaper|обо/.test(s)?'wallpaper':/concrete|бетон/.test(s)?'concrete':/parquet|wood|панел|дерев|паркет/.test(s)?'wood':/tile|stone|известняк|плит|камен/.test(s)?'tile':fallback;}
export function createBuildingInteriorDesign({THREE:T,entry,visual,instance,metresPerCell=4.1}){
 if(!entry?.storeys||entry.interiorDesign)return entry?.interiorDesign;
 const storeys=entry.storeys,frame=storeys.root,root=new T.Group();root.name='Themed_Building_Interior';frame.add(root);frame.updateWorldMatrix(true,true);
 const inverse=frame.matrixWorld.clone().invert(),local=p=>p.clone().applyMatrix4(inverse),baseY=frame.getWorldPosition(new T.Vector3()).y;
 const pool=createInteriorMeshPool(T,root),doors=createInteriorRoomDoors(T,{root:frame,entry,metresPerCell}),restores=[],ownedFinishes=[],furnitureBodies=[],accepted=[],reports=[];
 const original={proximity:entry.proximity.bind(entry),interact:entry.interact.bind(entry),update:entry.update.bind(entry),bodies:entry.getCollisionBodies.bind(entry),dispose:entry.dispose.bind(entry),needsUpdate:Object.getOwnPropertyDescriptor(entry,'needsUpdate')};
 const originalBodies=original.bodies(),staticBounds=originalBodies.filter(b=>!b.movingDoor).map(b=>{const pts=b.polygonCR.map(([x,z])=>local(new T.Vector3(x*metresPerCell,baseY,z*metresPerCell)));return{rect:[Math.min(...pts.map(p=>p.x)),Math.min(...pts.map(p=>p.z)),Math.max(...pts.map(p=>p.x)),Math.max(...pts.map(p=>p.z))],min:(b.minYM??baseY)-baseY,max:(b.maxYM??100)-baseY}});
 const rooms=storeys.rooms.map(r=>({...r,rect:r.rect.slice()}));
 // Bank rooms come from the accepted authored partitions; never replace them.
 if(instance.bankLayout){rooms.length=0;const f=storeys.floors[0];for(const label of instance.bankLayout.roomLabels){const c=local(visual.localToWorld(new T.Vector3(...label.center))),r=f.rect.slice();for(const b of staticBounds){if(b.max<f.y+.4||b.min>f.y+1.8)continue;const q=b.rect;if(c.z>q[1]&&c.z<q[3]){if(q[2]<c.x)r[0]=Math.max(r[0],q[2]);if(q[0]>c.x)r[2]=Math.min(r[2],q[0]);}if(c.x>q[0]&&c.x<q[2]){if(q[3]<c.z)r[1]=Math.max(r[1],q[3]);if(q[1]>c.z)r[3]=Math.min(r[3],q[1]);}}if(r[2]-r[0]>1.2&&r[3]-r[1]>1.2)rooms.push({name:label.label,id:label.id,level:0,y:f.y,rect:r});}}
 const planner=choosePlan(instance.assetId),first=planner({assetId:instance.assetId,level:0,roomIndex:0,width:4,depth:5,seed:instance.id}),wallLease=acquireInteriorFinish(T,{color:first.palette.wall,finish:finishCode(first.finish,'plaster')}),floorLease=acquireInteriorFinish(T,{color:first.palette.floor,finish:finishCode(first.floorFinish,'wood'),floor:true}),wallFinish=wallLease.material,floorFinish=floorLease.material;ownedFinishes.push(wallLease,floorLease);
 // Geometry is already window-clipped; changing its surface cannot cover a pane.
 entry.object.traverse(n=>{if(!n.isMesh||n===root)return;for(let p=n.parent;p;p=p.parent)if(p===root)return;if(/^(Entry_Interior_(Left|Right|Rear|Front)|Storey_Walls_And_Ceilings|Interior_(Left|Right|Rear|Front)|Bank_.*(Wall|Partition))/.test(n.name)){restores.push([n,n.material]);n.material=wallFinish;}else if(/^(Storey_Floors|Entry_Interior_Floor|Interior_Floor)$/.test(n.name)){restores.push([n,n.material]);n.material=floorFinish;}});
 const transform=new T.Matrix4(),rotation=new T.Quaternion(),axis=new T.Vector3(0,1,0);
 const compose=(x,y,z,yaw)=>new T.Matrix4().compose(new T.Vector3(x,y,z),new T.Quaternion().setFromAxisAngle(axis,yaw),new T.Vector3(1,1,1));
 function addBox(p,s,color,matrix){pool.add({shape:'box',position:p,size:s,color},matrix)}
 const bodyFor=(bounds,y,h)=>{const points=[[bounds[0],bounds[1]],[bounds[2],bounds[1]],[bounds[2],bounds[3]],[bounds[0],bounds[3]]].map(([x,z])=>frame.localToWorld(new T.Vector3(x,y,z)));return{polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:baseY+y,maxYM:baseY+y+h,buildingEntryId:instance.id,interiorFurniture:true};};
 for(let ri=0;ri<rooms.length;ri++){
  const room=rooms[ri],f=storeys.floors[room.level],rf=roomFrame(room),plan=planner({assetId:instance.assetId,level:room.level,roomIndex:ri,width:rf.width,depth:rf.depth,seed:instance.id});
  const report={level:room.level,name:instance.bankLayout?room.name:plan.name,rect:room.rect,items:[],rejected:0,door:!!room.door};reports.push(report);
  const roomMatrix=compose(rf.cx,room.y,rf.cz,rf.yaw),reserved=storeys.stairs.filter(s=>s.lowerLevel===room.level||s.upperLevel===room.level).map(s=>s.footprint);
  // Real skirting/cornices catch grazing light; doorway spans stay open.
  for(const side of[-1,1])for(const h of[.065,f.ceiling-room.y-.065])addBox([side*(rf.width/2-.028),h,0],[.045,.1,rf.depth],plan.palette.wood,roomMatrix);
  for(const zz of[-rf.depth/2+.028,rf.depth/2-.028]){const spans=room.door&&zz>0?[[-rf.width/2,-.67],[.67,rf.width/2]]:[[-rf.width/2,rf.width/2]];for(const[a,b]of spans)if(b-a>.08)for(const h of[.065,f.ceiling-room.y-.065])addBox([(a+b)/2,h,zz],[b-a,.1,.045],plan.palette.wood,roomMatrix);}
  if(room.door){
   const stripWidth=rf.width/2-.72,back=rf.depth/2-.055;
   // Panelling/art sit on an existing interior partition, never across windows.
   for(const side of[-1,1])if(stripWidth>.2){const cx=side*(.72+stripWidth/2);addBox([cx,.43,back],[stripWidth,.7,.035],plan.palette.accent,roomMatrix);addBox([cx,.79,back-.018],[stripWidth,.035,.055],plan.palette.metal,roomMatrix);}
   if(stripWidth>.6){const ax=-.72-stripWidth/2,aw=Math.min(.65,stripWidth-.14);addBox([ax,1.48,back-.04],[aw,.74,.055],plan.palette.wood,roomMatrix);addBox([ax,1.48,back-.073],[aw-.07,.66,.014],'#d8ccb3',roomMatrix);addBox([ax-.07,1.48,back-.084],[(aw-.14)*.48,.43,.013],plan.palette.accent,roomMatrix);addBox([ax+.09,1.39,back-.096],[(aw-.14)*.45,.25,.012],plan.palette.metal,roomMatrix);}
  }
  // Reserve a pedestrian route through an authored room door plus its full swing.
  let entrance=null;if(room.door){const d=room.door,onX=Math.abs(d.x-room.rect[0])<.15||Math.abs(d.x-room.rect[2])<.15,inward=onX?(d.x<rf.cx?-1:1):(d.z<rf.cz?-1:1),sweep=new T.Box3(new T.Vector3(-.77,0,inward===1?-1.37:-.2),new T.Vector3(.77,2.1,inward===1?.2:1.37)).applyMatrix4(compose(d.x,room.y,d.z,onX?Math.PI/2:0));entrance=[sweep.min.x,sweep.min.z,sweep.max.x,sweep.max.z];}
  function place(item){
   transform.multiplyMatrices(roomMatrix,compose(item.x,0,item.z,item.yaw??0));const box=new T.Box3(new T.Vector3(-item.width/2,0,-item.depth/2),new T.Vector3(item.width/2,item.height,item.depth/2)).applyMatrix4(transform),bounds=[box.min.x,box.min.z,box.max.x,box.max.z];
   if(!contained(bounds,room.rect,.05)||box.max.y>f.ceiling-.12||reserved.some(s=>overlap(bounds,s,.25))||entrance&&overlap(bounds,entrance)||staticBounds.some(b=>b.max>room.y+.12&&b.min<box.max.y&&overlap(bounds,b.rect,.04))||accepted.some(a=>Math.abs(a.y-room.y)<.3&&overlap(bounds,a.bounds,.07))){report.rejected++;return false}
   for(const part of item.parts)pool.add(part,transform);accepted.push({y:room.y,bounds,kind:item.kind});report.items.push(item.kind);if(item.height>.2)furnitureBodies.push(bodyFor(bounds,room.y,item.height));return true;
  }
  for(const item of plan.furniture)place(item);
  // Small rooms still get useful furniture, located against a free wall.
  if(!report.items.length){const fallback={kind:'niche_console',width:.65,depth:.28,height:.95,parts:[{shape:'box',position:[0,.43,0],size:[.62,.84,.25],color:plan.palette.wood},{shape:'box',position:[0,.875,0],size:[.65,.05,.28],color:plan.palette.accent},{shape:'box',position:[0,.6,.133],size:[.14,.03,.022],color:plan.palette.metal},{shape:'box',position:[-.15,.925,0],size:[.23,.05,.18],color:'#dfd4bd'}]};outer:for(const x of[-rf.width/2+.4,rf.width/2-.4,0])for(const z of[-rf.depth/2+.22,rf.depth/2-.22,0])if(place({...fallback,x,z,yaw:0}))break outer;}
  // Thin rugs and perimeter mouldings make each room read as an intentional space.
  const rw=Math.min(rf.width-.3,2.2),rd=Math.min(rf.depth-.3,2.6),rugCenter=new T.Vector3(0,.012,-.1).applyMatrix4(roomMatrix),rug=[rugCenter.x-rw/2,rugCenter.z-rd/2,rugCenter.x+rw/2,rugCenter.z+rd/2];
  if(rw>1&&rd>1&&!reserved.some(s=>overlap(rug,s,.08))&&contained(rug,room.rect,.05)){addBox([0,.009,-.1],[rw,.014,rd],plan.palette.accent,roomMatrix);addBox([0,.018,-.1],[rw-.12,.008,rd-.12],plan.palette.floor,roomMatrix);}
  if(room.door){const d=room.door,onX=Math.abs(d.x-room.rect[0])<.15||Math.abs(d.x-room.rect[2])<.15,doorAxis=onX?'z':'x';doors.create({x:d.x,z:d.z,y:room.y,axis:doorAxis,inward:onX?(d.x<rf.cx?-1:1):(d.z<rf.cz?-1:1),name:report.name,color:plan.palette.wood});
   // Brass-edged plaque is geometry, without unreadable tiny generated text.
   const signMatrix=compose(d.x,room.y,d.z,onX?Math.PI/2:0);addBox([-.88,1.57,.085],[.27,.32,.022],plan.palette.metal,signMatrix);addBox([-.88,1.57,.103],[.22,.26,.018],plan.palette.accent,signMatrix);
  }
 }
 // Every door keeps its own hinge and exact sweep collider, while the visible
 // wood/brass panels share one dynamic instance draw per material in this
 // building. Finalise only after all room plans have contributed their leaves.
 doors.finalize();const statistics=pool.flush();root.updateWorldMatrix(true,true);
 let oldBase=null,oldDoors=null,combined=null,disposed=false;
 entry.getCollisionBodies=()=>{const a=original.bodies(),b=doors.bodies();if(a!==oldBase||b!==oldDoors){oldBase=a;oldDoors=b;combined=a.concat(furnitureBodies,b)}return combined};
 entry.proximity=(point,distance)=>{const a=original.proximity(point,distance),b=doors.near(point);return b&&(!a||b.distance<a.distance)?b:a};
 entry.interact=point=>{const n=entry.proximity(point);return n?.door?doors.interact(point):original.interact(point)};
 entry.update=(dt,point)=>{original.update(dt,point);doors.update(Math.max(0,Math.min(.1,dt)),point)};
 Object.defineProperty(entry,'needsUpdate',{configurable:true,get(){return doors.active||(original.needsUpdate?.get?.call(entry)??false)}});
 entry.dispose=()=>{if(disposed)return;disposed=true;doors.dispose();pool.dispose();root.removeFromParent();for(const[n,m]of restores)n.material=m;for(const finish of ownedFinishes)finish.dispose();original.dispose()};
 const doorStatistics=doors.stats(),api={root,rooms:reports,doors:doors.doors,report:{rooms:reports.length,furnishedRooms:reports.filter(r=>r.items.length).length,furniture:accepted.length,doors:doors.doors.length,doorDraws:doorStatistics.draws,...statistics},dispose:entry.dispose};entry.interiorDesign=api;entry.report.interiorDesign=api.report;return api;
}
