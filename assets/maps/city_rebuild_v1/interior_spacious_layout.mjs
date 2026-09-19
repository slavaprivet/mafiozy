// Plans in the existing storey metre frame. This is construction-time data:
// there is no scene traversal, random global state, or per-frame layout work.
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const area=r=>Math.max(0,r[2]-r[0])*Math.max(0,r[3]-r[1]);
const overlaps=(a,b,p=0)=>a[0]<b[2]+p&&a[2]>b[0]-p&&a[1]<b[3]+p&&a[3]>b[1]-p;
const contains=(r,p,inset=0)=>p.x>=r[0]+inset&&p.x<=r[2]-inset&&p.z>=r[1]+inset&&p.z<=r[3]-inset;
const inflate=(r,p)=>[r[0]-p,r[1]-p,r[2]+p,r[3]+p];
const intersect=(a,b)=>[Math.max(a[0],b[0]),Math.max(a[1],b[1]),Math.min(a[2],b[2]),Math.min(a[3],b[3])];
const hash=s=>{let h=2166136261;for(const c of String(s))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0};
const center=r=>({x:(r[0]+r[2])/2,z:(r[1]+r[3])/2});
function subtract(r,h){const q=intersect(r,h);if(!area(q))return[r];return[[r[0],r[1],q[0],r[3]],[q[2],r[1],r[2],r[3]],[q[0],r[1],q[2],q[1]],[q[0],q[3],q[2],r[3]]].filter(q=>area(q)>.01)}
function freeRects(rect,blocks){return blocks.reduce((rs,b)=>rs.flatMap(r=>subtract(r,b)),[rect.slice()])}
function largestClearRect(rect,blocks){
 const xs=[rect[0],rect[2]],zs=[rect[1],rect[3]];for(const b of blocks){xs.push(clamp(b[0],rect[0],rect[2]),clamp(b[2],rect[0],rect[2]));zs.push(clamp(b[1],rect[1],rect[3]),clamp(b[3],rect[1],rect[3]))}
 let best=[...rect],bestArea=-1;
 for(const a of xs)for(const c of xs)if(c-a>2)for(const b of zs)for(const d of zs)if(d-b>2){const r=[a,b,c,d],size=area(r);if(size>bestArea&&!blocks.some(q=>overlaps(r,q))){best=r;bestArea=size}}
 return best;
}
function functionalZoneCandidates(rect,blocks,role){
 const sizes=role==='kitchen'?[[4.4,3.8],[3.8,3.4],[3.2,3],[2.75,2.75]]:[[5.2,4.6],[4.4,3.8],[3.4,3.2],[2.75,2.75]],result=[];
 // Edge candidates can span adjoining free pieces. Sequential subtraction
 // alone fragments a large pocket when unrelated routes end beside it.
 for(const size of sizes){
  for(const [w,d]of[size,[size[1],size[0]]]){
   const axis=(start,end,length,i)=>[...new Set([start,end-length,...blocks.flatMap(b=>[b[i]-length-.005,b[i+2]+.005])].filter(v=>v>=start-1e-6&&v+length<=end+1e-6).map(v=>Math.round(v*1e6)/1e6))];
   for(const x of axis(rect[0],rect[2],w,0))for(const z of axis(rect[1],rect[3],d,1)){const rr=[x,z,x+w,z+d];if(!blocks.some(b=>overlaps(rr,b)))result.push(rr);}
  }
  if(result.length)break;
 }
 return result;
}

const NAMES={living_room:'Гостиная',banquet_hall:'Парадный зал',hotel_lobby:'Вестибюль отеля',hotel_lounge:'Гостевой зал',hospital_reception:'Приёмное отделение',hospital_ward:'Палата',dining_hall:'Обеденный зал',club_hall:'Клубный зал',vip_lounge:'Гостиная клуба',civic_hall:'Общественный зал',meeting_hall:'Зал собраний',print_hall:'Печатный зал',workshop:'Мастерская',shop_floor:'Торговый зал',office:'Рабочий зал',bedroom:'Спальня',study:'Кабинет',kitchen:'Кухня',dining_room:'Столовая',guest_bedroom:'Гостевой номер',treatment_room:'Процедурная',nurse_station:'Пост медсестры',pharmacy:'Медицинская кладовая',manager_office:'Кабинет управляющего',security_office:'Комната охраны',stockroom:'Склад',archive:'Архив',backstage:'Служебная комната',cash_office:'Касса',police_reception:'Дежурная часть',police_office:'Кабинет полиции',fire_station_hall:'Помещение пожарной части',dormitory:'Комната отдыха',warehouse:'Складской зал'};
const SAFE_ROLES=new Set(['study','manager_office','security_office','cash_office']);

/** The caller can supply its authoritative resolved purpose. The asset-only
 * fallback is deliberately conservative: a glazed residential tower is a home,
 * not an invented hotel. Explicit type/name metadata is supported for hosts
 * that already have named hotels and services outside the standalone fixture. */
export function spaciousFloorPurpose({purpose,assetId='',role='',name='',metadata={}}={}){
 const explicit=typeof purpose==='string'?purpose:purpose?.kind;if(explicit)return explicit;
 const text=[metadata.operationType,metadata.buildingType,metadata.businessType,metadata.type,metadata.name,name,role].filter(Boolean).join(' ').toLowerCase();
 for(const [kind,re]of[['hotel',/hotel|motel|отель|гостиниц/],['hospital',/hospital|clinic|больниц|клиник/],['restaurant',/restaurant|ресторан|кафе|столовая/],['police',/police|полици/],['fire_station',/fire_station|пожарн/],['warehouse',/warehouse|склад/],['mansion',/mansion|особняк/]])if(re.test(text))return kind;
 if(/bank/.test(assetId)||role==='bank_shell')return'bank';
 if(/hospital/.test(assetId))return'hospital';if(/civic/.test(assetId))return'civic';
 for(const kind of['nightclub','strip_club','pawnshop','print_shop','gun_shop','bookmaker'])if(assetId.includes(kind))return kind;
 return /glass_pavilion/.test(assetId)?'retail':'residential';
}
function rolesFor(purpose,level,seed){
 switch(purpose){
  case'hospital':return level===0?['hospital_reception','treatment_room','pharmacy']:['hospital_ward','treatment_room','nurse_station'];
  case'hotel':return level===0?['hotel_lobby','dining_room','kitchen']:['hotel_lounge','guest_bedroom','guest_bedroom'];
  case'restaurant':return ['dining_hall',level?'manager_office':'kitchen',level?'dining_room':'stockroom'];
  case'nightclub':case'strip_club':case'club':return [level?'vip_lounge':'club_hall','manager_office',level?'security_office':'backstage'];
  case'civic':case'office':return[level?'meeting_hall':'civic_hall','office',level?'archive':'manager_office'];
  case'print_shop':return[level?'workshop':'print_hall','stockroom','manager_office'];
  case'workshop':return['workshop','stockroom','manager_office'];
  case'warehouse':return['warehouse','stockroom','manager_office'];
  case'police':return[level?'police_office':'police_reception','security_office','archive'];
  case'fire_station':return['fire_station_hall',level?'dormitory':'workshop','office'];
  case'retail':case'shop':case'pawnshop':case'gun_shop':case'bookmaker':return[level?'office':'shop_floor',level?'stockroom':'cash_office',level?'manager_office':'stockroom'];
  case'mansion':return[level?'living_room':'banquet_hall',level?'bedroom':'study',level?'study':'dining_room'];
  default:return[level?'bedroom':'living_room',level?'study':(seed%2?'kitchen':'study'),level?'bedroom':(seed%2?'study':'kitchen')];
 }
}

function stairLandings(stairs,level,y,rect){
 const result=[];
 for(const s of stairs){
  if(s.lowerLevel!==level&&s.upperLevel!==level)continue;
  const endpoint=s.lowerLevel===level?s.route?.[0]:s.route?.at(-1),r=s.footprint;
  if(!r)continue;
  const p=endpoint??{...center(r),y},candidates=[{x:r[0]-.62,z:p.z,axis:'x'},{x:r[2]+.62,z:p.z,axis:'x'},{x:p.x,z:r[1]-.62,axis:'z'},{x:p.x,z:r[3]+.62,axis:'z'}];
  // The landing can connect from its open side when the back edge is against
  // the exterior wall. Do not put a fictitious access point behind that wall.
  const obstacles=(s.obstacles??[]).filter(o=>o.maxY>y+.12&&o.minY<y+1.75);
  const clear=q=>{const rr=[Math.min(q.x,p.x)-.37,Math.min(q.z,p.z)-.37,Math.max(q.x,p.x)+.37,Math.max(q.z,p.z)+.37];return!obstacles.some(o=>overlaps(rr,o.rect))};
  const valid=candidates.filter(q=>contains(rect,q,.39)&&clear(q)).sort((a,b)=>Math.hypot(a.x-p.x,a.z-p.z)-Math.hypot(b.x-p.x,b.z-p.z));
  const q=valid[0]??{x:p.x,z:p.z,axis:'landing'};
  const access=intersect(rect,[Math.min(q.x,p.x)-1,Math.min(q.z,p.z)-1,Math.max(q.x,p.x)+1,Math.max(q.z,p.z)+1]);
  result.push({level,stairLevel:s.lowerLevel,point:{x:q.x,y,z:q.z},landing:{x:p.x,y,z:p.z},rect:access,width:2,axis:q.axis});
 }
 return result;
}

function stairNavigationBlocks(stairs,level,y){
 const result=[],rails=[];
 for(const s of stairs){
  if(s.lowerLevel!==level&&s.upperLevel!==level)continue;
  const first=s.route?.[0],last=s.route?.at(-1),r=s.footprint;if(!first||!last||!r)continue;
  // The open floor landing belongs to circulation. The entire stair AABB
  // would seal its entrance and reject valid upper-floor edge passages.
  const core=r.slice();if(Math.abs(first.x-last.x)>Math.abs(first.z-last.z)){if(first.z-r[1]<r[3]-first.z)core[1]=2*first.z-r[1];else core[3]=2*first.z-r[3]}else{if(first.x-r[0]<r[2]-first.x)core[0]=2*first.x-r[0];else core[2]=2*first.x-r[2]}
  result.push({rect:core,padding:.02});
  for(const o of s.obstacles??[])if(o.maxY>y+.12&&o.minY<y+1.75)rails.push(o.rect.slice());
 }
 // Consecutive authored railing segments share axes; merge them once rather
 // than adding hundreds of duplicate coordinates to the visibility graph.
 for(const r of rails){const same=result.find(b=>b.railing&&((Math.abs(b.rect[0]-r[0])<1e-5&&Math.abs(b.rect[2]-r[2])<1e-5&&b.rect[1]<=r[3]+.001&&b.rect[3]>=r[1]-.001)||(Math.abs(b.rect[1]-r[1])<1e-5&&Math.abs(b.rect[3]-r[3])<1e-5&&b.rect[0]<=r[2]+.001&&b.rect[2]>=r[0]-.001)));if(same){same.rect=[Math.min(r[0],same.rect[0]),Math.min(r[1],same.rect[1]),Math.max(r[2],same.rect[2]),Math.max(r[3],same.rect[3])]}else result.push({rect:r,padding:.365,railing:true})}
 return result;
}

// A tiny rectilinear visibility graph is built only once per floor. Every
// route centre keeps a .40m capsule margin from partitions/stair footprints.
// Its reserved furniture corridor is wider (2m), so tables cannot fill it.
function routeBetween(from,to,rect,blocks){
 blocks=blocks.map(b=>inflate(b.rect??b,b.padding??.4));
 const margin=.405,normalize=ns=>[...new Set(ns.map(v=>Math.round(v*1e6)/1e6))].sort((a,b)=>a-b);
 const xs=normalize([from.x,to.x,rect[0]+margin,rect[2]-margin,...blocks.flatMap(r=>[r[0]-.005,r[2]+.005])].filter(x=>x>=rect[0]+.39&&x<=rect[2]-.39));
 const zs=normalize([from.z,to.z,rect[1]+margin,rect[3]-margin,...blocks.flatMap(r=>[r[1]-.005,r[3]+.005])].filter(z=>z>=rect[1]+.39&&z<=rect[3]-.39));
 const w=xs.length,n=w*zs.length,valid=new Uint8Array(n),prev=new Int32Array(n).fill(-1),queue=new Int32Array(n),at=(x,z)=>zs.indexOf(Math.round(z*1e6)/1e6)*w+xs.indexOf(Math.round(x*1e6)/1e6);
 for(let j=0;j<zs.length;j++)for(let i=0;i<w;i++)valid[j*w+i]=!blocks.some(r=>xs[i]>r[0]&&xs[i]<r[2]&&zs[j]>r[1]&&zs[j]<r[3]);
 const start=at(from.x,from.z),end=at(to.x,to.z);if(start<0||end<0||!valid[start]||!valid[end])return null;
 let head=0,tail=0;queue[tail++]=start;prev[start]=start;
 while(head<tail&&prev[end]===-1){const a=queue[head++],ix=a%w,iz=Math.floor(a/w);for(const b of[ix?a-1:-1,ix+1<w?a+1:-1,iz?a-w:-1,iz+1<zs.length?a+w:-1]){if(b<0||!valid[b]||prev[b]!==-1)continue;const bx=b%w,bz=Math.floor(b/w),segment=[Math.min(xs[ix],xs[bx]),Math.min(zs[iz],zs[bz]),Math.max(xs[ix],xs[bx]),Math.max(zs[iz],zs[bz])];if(blocks.some(r=>overlaps(segment,r)))continue;prev[b]=a;queue[tail++]=b;}}
 if(prev[end]===-1)return null;
 const path=[];for(let i=end;;i=prev[i]){path.push({x:xs[i%w],z:zs[Math.floor(i/w)]});if(i===start)break}path.reverse();
 for(let i=path.length-2;i>0;i--)if((path[i-1].x===path[i].x&&path[i].x===path[i+1].x)||(path[i-1].z===path[i].z&&path[i].z===path[i+1].z))path.splice(i,1);
 return path;
}

/** Return spacious rooms, authored wall descriptors and furniture exclusions.
 * Rectangles are [minX,minZ,maxX,maxZ]. Broad public connections are open
 * portals; hosts must not insert a fixed-width 1.2m door into a 1.8m opening.
 * Banks explicitly keep the accepted authored layout untouched. */
export function planSpaciousFloor({assetId='',instanceId='',level=0,rect,y=0,ceiling=3,stairs=[],purpose,role,name,metadata,bankLayout,entry:sourceEntry}={}){
 if(!rect||rect.length!==4||!rect.every(Number.isFinite)||area(rect)<=0||rect[2]<=rect[0]||rect[3]<=rect[1]||!Number.isFinite(y)||!Number.isFinite(ceiling)||ceiling<=y)throw Error('Invalid spacious floor dimensions');
 const theme=spaciousFloorPurpose({purpose,assetId,role,name,metadata}),seed=hash(`${instanceId}/${level}`),[a,b,c,d]=rect,width=c-a,depth=d-b;
 if(theme==='bank'||bankLayout)return{theme:'bank',preserveExisting:true,rooms:[],partitions:[],reservedPaths:[],stairAccess:[],entry:null,metrics:{floorArea:area(rect),partitionCount:0}};
 const home=['residential','mansion'].includes(theme),roles=rolesFor(theme,level,seed),mainRole=roles[0],entry={x:clamp(sourceEntry?.x??0,a+.46,c-.46),y,z:clamp(sourceEntry?.z??d-.55,b+.46,d-.46)};
 const relevant=stairs.filter(s=>s.lowerLevel===level||s.upperLevel===level),stairRects=relevant.map(s=>s.footprint).filter(Boolean),stairAccess=stairLandings(stairs,level,y,rect),navigationBlocks=stairNavigationBlocks(stairs,level,y),serviceRooms=[],partitions=[];
 // Upper floors are entered from their stairs. The usual front-centre hub can
 // fall in the opening of a rotated flight; it is then not a floor position.
 // Preserve explicit entrance contracts and every obstacle, and replace only
 // that invalid synthetic hub with the incoming stair's actual floor approach.
 const blockedPoint=p=>navigationBlocks.some(b=>contains(inflate(b.rect,b.padding),p));
 if(level>0&&!sourceEntry&&blockedPoint(entry)){
  const incoming=stairAccess.find(a=>relevant.some(s=>s.upperLevel===level&&s.lowerLevel===a.stairLevel));
  if(incoming&&contains(rect,incoming.point,.39)&&!blockedPoint(incoming.point)){entry.x=incoming.point.x;entry.z=incoming.point.z;}
 }
 const entryClear=intersect(rect,[entry.x-1.1,entry.z-1.6,entry.x+1.1,d]),usable=freeRects(rect,stairRects).reduce((n,r)=>n+area(r),0);
 // A large shared room is the default. Private rooms occupy deep corners,
 // never two thin strips along a mandatory central corridor.
 const roomMin=home?2.75:3.1,guestFloor=theme==='hotel'&&level>0,roomDepth=Math.min(home?4.1:6.7,guestFloor?Math.max(4.25,depth*.37):depth*(home?.34:.37)),roomWidth=Math.min(home?4.25:7,width*.35),canPartition=width>=6.4&&depth>=7.4&&area(rect)>=65;
 if(canPartition&&roomDepth>=roomMin&&roomWidth>=roomMin){
  const corners=seed%2?[-1,1]:[1,-1];
  for(const side of corners){
   const rr=side<0?[a,b,a+roomWidth,b+roomDepth]:[c-roomWidth,b,c,b+roomDepth],privateIndex=serviceRooms.length+1;
   if(stairRects.some(s=>overlaps(rr,s,.55))||stairAccess.some(s=>overlaps(rr,s.rect,.06))||overlaps(rr,entryClear,.1))continue;
   const existing=serviceRooms.map(r=>r.rect),future=existing.concat([rr]),mainRect=largestClearRect(rect,future),remaining=usable-future.reduce((n,r)=>n+area(r),0);
   if(remaining<usable*.55||area(mainRect)<area(rect)*.53)continue;
   const doorWidth=home?1.65:(theme==='hospital'||theme==='hotel'?2:1.8),doorX=clamp((rr[0]+rr[2])/2,rr[0]+doorWidth/2+.17,rr[2]-doorWidth/2-.17),door={x:doorX,y,z:rr[3],width:doorWidth,height:Math.min(2.35,ceiling-y-.12),axis:'x',open:true};
   const approach={x:door.x,z:door.z+.65};
   if(!routeBetween(entry,approach,rect,future.concat(navigationBlocks)))continue;
   const roomRole=roles[privateIndex]??'stockroom';serviceRooms.push({id:`${instanceId}:floor:${level}:room:${privateIndex}`,level,y,rect:rr,role:roomRole,name:NAMES[roomRole]??'Комната',door,openPlan:false,eligibleSafe:SAFE_ROLES.has(roomRole),furnishingZones:[{rect:rr.slice(),role:roomRole}]});
  }
 }
 const privateRects=serviceRooms.map(r=>r.rect),mainRect=largestClearRect(rect,privateRects),openRegions=freeRects(rect,privateRects),mainZones=freeRects(mainRect,stairRects.map(r=>inflate(r,.3))).filter(r=>r[2]-r[0]>=1.9&&r[3]-r[1]>=1.9);
 const main={id:`${instanceId}:floor:${level}:main`,level,y,rect:mainRect,role:mainRole,name:NAMES[mainRole]??'Зал',openPlan:true,eligibleSafe:home&&level>0,regions:openRegions,furnishingZones:mainZones.map((r,i)=>({rect:r,role:(!serviceRooms.length&&home&&i>0)?roles[Math.min(i,roles.length-1)]:mainRole}))};
 const rooms=[main,...serviceRooms],reservedPaths=[{kind:'entry',rect:entryClear,width:2.2,points:[entry]}],blocks=privateRects.concat(navigationBlocks),unreachable=[];
 const reserveRoute=(id,target,kind,doorWidth=2)=>{const points=routeBetween(entry,target,rect,blocks);if(!points){unreachable.push(id);return}if(points.length===1)reservedPaths.push({id,kind,points,rect:intersect(rect,inflate([target.x,target.z,target.x,target.z],1)),width:2});for(let i=1;i<points.length;i++){const p=points[i-1],q=points[i],rr=intersect(rect,[Math.min(p.x,q.x)-1,Math.min(p.z,q.z)-1,Math.max(p.x,q.x)+1,Math.max(p.z,q.z)+1]);reservedPaths.push({id,kind,rect:rr,width:2,points:[{...p,y},{...q,y}]})}};
 for(const room of serviceRooms){
  const r=room.rect,door=room.door,axisX=r[0]===a?r[2]:r[0],half=door.width/2;
  const add=(name,rr,bottom,top,material='wall',collision=true)=>{if(area(rr)>.00001&&top>bottom+.001)partitions.push({name,rect:rr,bottom,top,material,collision,roomId:room.id})};
  add('Room_Partition',[axisX-.06,r[1],axisX+.06,r[3]],y,ceiling);
  add('Room_Partition',[r[0],r[3]-.06,door.x-half,r[3]+.06],y,ceiling);
  add('Room_Partition',[door.x+half,r[3]-.06,r[2],r[3]+.06],y,ceiling);
  add('Room_Door_Header',[door.x-half,r[3]-.06,door.x+half,r[3]+.06],y+door.height,ceiling);
  for(const x of[door.x-half-.025,door.x+half+.025])add('Room_Door_Frame',[x-.025,door.z-.085,x+.025,door.z+.085],y,y+door.height+.045,'trim',false);
  reserveRoute(room.id,{x:door.x,z:door.z+.65},'room',door.width);
  reservedPaths.push({id:room.id,kind:'door',rect:[door.x-half-.12,door.z-1.35,door.x+half+.12,door.z+1.35],width:door.width,points:[{x:door.x,y,z:door.z-1},{x:door.x,y,z:door.z+1}]});
 }
 for(const s of stairAccess){reserveRoute(`stair:${s.stairLevel}`,s.point,'stair');reservedPaths.push({id:`stair:${s.stairLevel}`,kind:'landing',rect:s.rect,width:2,points:[s.point,s.landing]})}
 // The middle of an open room stays traversable even when no private rooms
 // were needed. Furnishing can occupy islands on either side of this route.
 const hubCandidates=mainZones.slice().sort((a,b)=>area(b)-area(a)).map(center);for(const hub of hubCandidates){const path=routeBetween(entry,hub,rect,blocks);if(path){reserveRoute('main',hub,'main');break}}
 if(theme==='hotel'){
  // A small upper storey is a whole guest suite, not a lounge with no beds.
  if(level>0&&!serviceRooms.length){main.role='guest_bedroom';main.name=NAMES.guest_bedroom;main.furnishingZones=main.furnishingZones.map(zone=>({...zone,role:main.role}));}
  if(level===0){
   // A rear stair can consume the second service-room corner. Keep the missing
   // hotel function in a real, connected open zone; its rectangle is reserved
   // from lobby furniture and never adds another wall across circulation.
   const missing=['dining_room','kitchen'].filter(role=>!serviceRooms.some(r=>r.role===role)),zoneRects=[];
   for(const zoneRole of missing){
    const excluded=stairRects.map(r=>inflate(r,.3)).concat(partitions.filter(p=>p.collision).map(p=>inflate(p.rect,.04)),reservedPaths.map(p=>inflate(p.rect,.08)),zoneRects.map(r=>inflate(r,.25)));
    const free=functionalZoneCandidates(mainRect,excluded,zoneRole).sort((a,b)=>{const pa=center(a),pb=center(b);return Math.hypot(pb.x-entry.x,pb.z-entry.z)-Math.hypot(pa.x-entry.x,pa.z-entry.z)});
    let selected=null;
    for(const candidate of free){
     const points=routeBetween(entry,center(candidate),rect,blocks);
     if(points){selected={rect:candidate,points};break;}
    }
    if(!selected)continue;
    const rr=selected.rect,id=`${instanceId}:floor:${level}:zone:${zoneRole}`;
    reserveRoute(id,center(rr),'functional');
    rooms.push({id,level,y,rect:rr,role:zoneRole,name:NAMES[zoneRole],openPlan:true,functionalZone:true,parentRoomId:main.id,eligibleSafe:false,furnishingZones:[{rect:rr.slice(),role:zoneRole}],reservedPaths:reservedPaths.slice()});
    zoneRects.push(rr);
   }
   if(zoneRects.length){
    main.reservedPaths=reservedPaths.concat(zoneRects.map((r,i)=>({id:`${main.id}:function:${i}`,kind:'functional-zone',rect:inflate(r,.07),points:[],width:0})));
    main.furnishingZones=freeRects(main.rect,zoneRects).map(r=>({rect:r,role:main.role}));
   }
  }
 }
 return{theme,preserveExisting:false,rooms,partitions,reservedPaths,stairAccess,entry,metrics:{floorArea:area(rect),usableArea:usable,openArea:usable-privateRects.reduce((n,r)=>n+area(r),0),mainRoomArea:area(mainRect),mainRoomShare:area(mainRect)/area(rect),partitionCount:partitions.filter(p=>p.collision).length,rooms:rooms.length,unreachable}};
}
