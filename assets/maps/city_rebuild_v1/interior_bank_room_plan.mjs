// Pure furnishing-space plan in ORIGINAL GLB VISUAL LOCAL METRES. Room borders
// use named authored partitions, including their thickness, never rays through
// a doorway. This module does not build or modify walls, doors or bank gameplay.
const ROLES=Object.freeze({public_lobby:'civic_hall',staff_office:'office',archive_manager:'archive',security_approach:'security_office',vault:'vault',staff_lounge:'living_room',meeting_room:'meeting_hall'});
const EPS=1e-7;
const validRect=r=>Array.isArray(r)&&r.length===4&&r.every(Number.isFinite)&&r[2]>r[0]&&r[3]>r[1];
const inside=(p,r)=>p[0]>=r[0]-EPS&&p[0]<=r[2]+EPS&&p[2]>=r[1]-EPS&&p[2]<=r[3]+EPS;
const overlap=(a,b)=>a[0]<b[2]-EPS&&a[2]>b[0]+EPS&&a[1]<b[3]-EPS&&a[3]>b[1]+EPS;
const clip=(a,b)=>[Math.max(a[0],b[0]),Math.max(a[1],b[1]),Math.min(a[2],b[2]),Math.min(a[3],b[3])];

export function planBankRooms({instance,bankLayout=instance?.bankLayout,bankRoomProfile=instance?.bankRoomProfile,floorBounds,minimumPathWidth=1.5,approachDepth=1.1,entryDoor}={}){
 if(!bankLayout)return null;
 if(!Number.isFinite(minimumPathWidth)||minimumPathWidth<1.5||!Number.isFinite(approachDepth)||approachDepth<.75)throw new TypeError('Invalid bank furnishing path dimensions');
 const walls=bankLayout.wallRects,labels=bankLayout.roomLabels;
 if(!Array.isArray(walls)||!Array.isArray(labels))throw new TypeError('Missing authored bank walls/room labels');
 if(walls.some(w=>!w||typeof w.name!=='string'||!validRect(w.rect)))throw new TypeError('Invalid authored bank wall rectangle');
 const wallMap=new Map(walls.map(w=>[w.name,w.rect]));
 const get=name=>{const rect=wallMap.get(name);if(!rect)throw new Error('Missing authored bank partition: '+name);return rect};
 const profile=bankRoomProfile?.bounds,inset=bankRoomProfile?.inset??0;
 let bounds=validRect(profile)&&Number.isFinite(inset)&&inset>=0?[profile[0]+inset,profile[1]+inset,profile[2]-inset,profile[3]-inset]:null;
 if(floorBounds!==undefined){if(!validRect(floorBounds))throw new TypeError('floorBounds must be in original GLB visual coordinates');bounds=bounds?clip(bounds,floorBounds):floorBounds.slice()}
 if(!validRect(bounds))throw new TypeError('Missing bank clear floor bounds');
 const archs=walls.filter(w=>/^Bank_Partition_Arch_(?:\d+|End)$/.test(w.name)).map(w=>({name:w.name,rect:w.rect})).sort((a,b)=>a.rect[0]-b.rect[0]);
 if(archs.length!==4)throw new Error('Expected the four authored bank arch wall segments');
 const arch=archs[0].rect;
 if(archs.some(w=>Math.abs(w.rect[1]-arch[1])>EPS||Math.abs(w.rect[3]-arch[3])>EPS))throw new Error('Bank arch wall segments are not aligned');
 const staff=get('Bank_Partition_Staff_Security'),lounge=get('Bank_Partition_Security_Lounge');
 const rearStaff=[get('Bank_Partition_Staff_Rear_L'),get('Bank_Partition_Staff_Rear_R')],rearLounge=[get('Bank_Partition_Lounge_Rear_L'),get('Bank_Partition_Lounge_Rear_R')],vaultFront=[get('Bank_Vault_Front_L'),get('Bank_Vault_Front_R')];
 for(const [a,b]of[rearStaff,rearLounge,vaultFront])if(Math.abs(a[1]-b[1])>EPS||Math.abs(a[3]-b[3])>EPS||a[2]>=b[0])throw new Error('Invalid authored bank rear doorway');
 const [left,back,right,front]=bounds;
 const rects={
  public_lobby:[left,arch[3],right,front],
  staff_office:[left,rearStaff[0][3],staff[0],arch[1]],
  archive_manager:[left,back,staff[0],rearStaff[0][1]],
  security_approach:[staff[2],vaultFront[0][3],lounge[0],arch[1]],
  vault:[staff[2],back,lounge[0],vaultFront[0][1]],
  staff_lounge:[lounge[2],rearLounge[0][3],right,arch[1]],
  meeting_room:[lounge[2],back,right,rearLounge[0][1]],
 };
 const roomMap=new Map(),rooms=[];
 for(const id of Object.keys(ROLES)){
  const label=labels.find(l=>l.id===id),rect=rects[id];
  if(!label||!Array.isArray(label.center)||label.center.length!==3||!label.center.every(Number.isFinite))throw new Error('Missing authored bank room label: '+id);
  if(!validRect(rect)||!inside(label.center,rect))throw new Error('Bank room does not contain its authored label: '+id);
  if(walls.some(w=>overlap(rect,w.rect)))throw new Error('Bank room overlaps an authored partition: '+id);
  const room={id,name:label.label,role:ROLES[id],level:0,y:label.center[1],center:label.center.slice(),rect,doors:[],preserveExisting:id==='vault',reservedPaths:[]};
  rooms.push(room);roomMap.set(id,room);
 }
 const doors=[],reservedPaths=[];
 function doorway(id,x0,x1,z0,z1,between,{external=false}={}){
  if(x1<=x0)throw new Error('Closed authored bank doorway: '+id);
  const door={id,x:(x0+x1)/2,z:(z0+z1)/2,y:rooms[0].y,width:x1-x0,axis:'x',open:true,between,external,rect:[x0,z0,x1,z1],authored:true};
  doors.push(door);for(const roomId of between){const room=roomMap.get(roomId);if(room)room.doors.push(door)}
  reservedPaths.push({id:id+':threshold',kind:'doorway',doorId:id,roomIds:between.slice(),rect:door.rect.slice(),width:door.width,actualWidth:door.width,axis:'z'});return door;
 }
 for(let i=0;i<3;i++)doorway(['lobby_staff','lobby_security','lobby_lounge'][i],archs[i].rect[2],archs[i+1].rect[0],arch[1],arch[3],['public_lobby',['staff_office','security_approach','staff_lounge'][i]]);
 doorway('staff_archive',rearStaff[0][2],rearStaff[1][0],rearStaff[0][1],rearStaff[0][3],['staff_office','archive_manager']);
 doorway('lounge_meeting',rearLounge[0][2],rearLounge[1][0],rearLounge[0][1],rearLounge[0][3],['staff_lounge','meeting_room']);
 doorway('security_vault',vaultFront[0][2],vaultFront[1][0],vaultFront[0][1],vaultFront[0][3],['security_approach','vault']);
 // Existing generator-authored double leaves span 2.82m. Hosts may supply the
 // measured live entry aperture instead; neither value changes its geometry.
 const entry=entryDoor||{},entryX=Number.isFinite(entry.x)?entry.x:instance?.entry?.authoredLocalXYZ?.[0]??0,entryZ=Number.isFinite(entry.z)?entry.z:instance?.entry?.authoredLocalXYZ?.[2]??front,entryWidth=Number.isFinite(entry.width)?entry.width:2.82;
 doorway('public_entry',entryX-entryWidth/2,entryX+entryWidth/2,front,Math.max(front+.01,entryZ+.15),['outside','public_lobby'],{external:true});
 function reserve(room,rect,{id,kind,width,doorId,axis}){
  const limited=clip(rect,room.rect);if(!validRect(limited))return;
  const path={id,kind,roomId:room.id,roomIds:[room.id],rect:limited,width,doorId,axis};room.reservedPaths.push(path);reservedPaths.push(path);
 }
 const primary={public_lobby:'public_entry',staff_office:'lobby_staff',archive_manager:'staff_archive',security_approach:'lobby_security',vault:'security_vault',staff_lounge:'lobby_lounge',meeting_room:'lounge_meeting'};
 for(const room of rooms){
  room.door=room.doors.find(d=>d.id===primary[room.id]);
  const hub={x:room.center[0],z:room.center[2]},r=room.rect;
  for(const door of room.doors){
   const towardBack=door.z>hub.z,edge=towardBack?r[3]:r[1],sign=towardBack?-1:1,width=Math.max(minimumPathWidth,door.width),depth=Math.min(approachDepth,(r[3]-r[1])/2),anchor={x:door.x,z:edge+sign*depth};
   reserve(room,[door.x-width/2,Math.min(edge,anchor.z),door.x+width/2,Math.max(edge,anchor.z)],{id:door.id+':'+room.id+':approach',kind:'door_approach',width,doorId:door.id,axis:'z'});
   // L-shaped links join every doorway to its room's actual authored centre.
   // Both legs stay inside a convex room rectangle, so no wall ray can escape
   // through a gap and assign furniture to a neighbouring room.
   const half=minimumPathWidth/2;
   reserve(room,[Math.min(anchor.x,hub.x)-half,anchor.z-half,Math.max(anchor.x,hub.x)+half,anchor.z+half],{id:door.id+':'+room.id+':link-x',kind:'room_connection',width:minimumPathWidth,doorId:door.id,axis:'x'});
   reserve(room,[hub.x-half,Math.min(anchor.z,hub.z)-half,hub.x+half,Math.max(anchor.z,hub.z)+half],{id:door.id+':'+room.id+':link-z',kind:'room_connection',width:minimumPathWidth,doorId:door.id,axis:'z'});
  }
 }
 for(const path of reservedPaths)if(walls.some(w=>overlap(path.rect,w.rect)))throw new Error('Bank furnishing path crosses an authored wall: '+path.id);
 return {coordinateSpace:'original GLB visual local metres',preserveExisting:true,bounds,rooms,doors,reservedPaths,
  report:{rooms:rooms.length,internalDoorways:doors.filter(d=>!d.external).length,reservedPaths:reservedPaths.length,minimumPathWidth,narrowExistingDoors:doors.filter(d=>d.width<minimumPathWidth-EPS).map(d=>({id:d.id,width:d.width,requiredApproachWidth:minimumPathWidth})),vaultPreserved:true}};
}
