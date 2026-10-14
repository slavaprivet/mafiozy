import {createInteriorMeshPool} from './interior_mesh_pool.mjs';

export const PRINT_SHOP_SERVICE_PILOT='REBUILD-VISUAL-print_shop-001';
const finitePoint=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));
const smooth=n=>n*n*(3-2*n);
const stations=new WeakMap();
// Explicit one-building addition. No generic floor plan, GLB or world registry
// changes. The host must register returned colliders, source actors and service.
export function createPrintShopServiceStation({THREE:T,entry,siteRevision,validateLayout,metresPerCell=4.1}={}){
 if(entry?.instance?.id!==PRINT_SHOP_SERVICE_PILOT||entry.instance.assetId!=='print_shop'||!entry.storeys||typeof siteRevision!=='string'||!siteRevision||typeof validateLayout!=='function'||!Number.isFinite(metresPerCell)||metresPerCell<=0)throw Error('Explicit print-shop pilot required');
 const existing=stations.get(entry);if(existing){if(existing.layout.revision!==siteRevision)throw Error('Dispose old service station before revision replacement');return existing;}
 const room=entry.storeys.rooms.find(r=>r.level===0&&r.role==='stockroom'),hall=entry.storeys.rooms.find(r=>r.level===0&&r.role==='print_hall');
 if(!room?.door||!hall||room.door.axis!=='x'||room.door.width<1.7||room.door.width>2.1)throw Error('Pilot stockroom geometry unavailable');
 const d=room.door,counter={x:hall.rect[0]+4.5,y:room.y,z:d.z+3.9},local={spawn:{x:(room.rect[0]+room.rect[2])/2,y:room.y,z:(room.rect[1]+room.rect[3])/2},doorInside:{x:d.x+.08,y:room.y,z:d.z-1.15},doorOutside:{x:d.x+.08,y:room.y,z:d.z+2.55},work:{x:counter.x,y:room.y,z:counter.z-1.24},customer:{x:counter.x,y:room.y,z:counter.z+1.24}};
 // Finish walking straight through the public doorway before turning toward
 // the counter. A diagonal from the old inside stop clips the existing jamb.
 const publicApproach=entry.storeys.root.worldToLocal(entry.approachPoint());
 local.customerVia={x:publicApproach.x,y:room.y,z:local.customer.z};
 const world=p=>{const v=entry.storeys.worldPoint(p);return{x:v.x,y:v.y,z:v.z};};
 const layout={buildingId:PRINT_SHOP_SERVICE_PILOT,revision:siteRevision,stationId:PRINT_SHOP_SERVICE_PILOT+':news-counter',roomId:room.id,doorId:PRINT_SHOP_SERVICE_PILOT+':stockroom-service-door',...Object.fromEntries(Object.entries(local).map(([k,p])=>[k,world(p)]))};
 const counterRect=[counter.x-.87,counter.z-.43,counter.x+.87,counter.z+.43];
 if(validateLayout({layout,local,counter,counterRect,room,hall})!==true)throw Error('Pilot service anchors not certified');
 const frame=entry.storeys.root,root=new T.Group();root.name='PrintShop_Service_Pilot';frame.add(root);
 const half=(d.width-.12)/2,leafEnd=d.width-.11,pool=createInteriorMeshPool(T,root),doorHinge=new T.Group(),doorPivot=new T.Group();doorHinge.position.set(d.x,room.y,d.z);doorPivot.position.x=-half;doorHinge.add(doorPivot);root.add(doorHinge);
 const doorPool=createInteriorMeshPool(T,doorPivot);
 const box=(target,position,size,color,metalness=0)=>target.add({shape:'box',position,size,color,metalness});
 // Solid counter, brass foot rail, drawer, paper stacks and a compact register.
 box(pool,[counter.x,.46+room.y,counter.z],[1.6,.92,.7],'#594337');
 box(pool,[counter.x,.96+room.y,counter.z],[1.74,.08,.86],'#322b27');
 box(pool,[counter.x,.09+room.y,counter.z+.37],[1.48,.045,.035],'#b69a65',.65);
 box(pool,[counter.x,.68+room.y,counter.z-.36],[1.42,.30,.025],'#765944');
 box(pool,[counter.x,.68+room.y,counter.z-.39],[.25,.03,.035],'#b69a65',.65);
 box(pool,[counter.x+.4,1.055+room.y,counter.z-.04],[.45,.11,.35],'#343c3a');
 box(pool,[counter.x+.4,1.22+room.y,counter.z+.015],[.32,.22,.13],'#343c3a');
 box(pool,[counter.x+.4,1.235+room.y,counter.z-.058],[.25,.09,.015],'#afc4a9');
 for(let i=0;i<4;i++)box(pool,[counter.x-.4,1.018+room.y+i*.013,counter.z+.08],[.42,.011,.30],i%2?'#ded6c4':'#ece4d3');
 // Opaque technical door opens outward. The staff inside anchor is outside
 // its swept leaf; automatic closing waits until all bodies clear the sweep.
 box(doorPool,[half,1.04,0],[d.width-.12,2.06,.065],'#5b564b');
 for(const y of [.58,1.49])for(const sign of [-1,1])box(doorPool,[half,y,sign*.043],[d.width-.38,.7,.022],'#716b5d');
 for(const sign of [-1,1]){box(doorPool,[leafEnd-.14,1.04,sign*.062],[.045,.19,.025],'#b69a65',.65);box(doorPool,[leafEnd-.185,1.08,sign*.084],[.13,.036,.045],'#b69a65',.65);}
 const counterStats=pool.flush(),doorStats=doorPool.flush();
 for(const mesh of doorPivot.children){mesh.userData.worldBlastStaticBounds=false;mesh.userData.serviceMovingDoor=true;}
 root.updateWorldMatrix(true,true);
 let fraction=0,target=0,disposed=false,version=0,cachedVersion=-1,cachedBodies=null;
 const scratch=new T.Vector3(),inverse=new T.Matrix4(),worldMin=world({x:counter.x,y:room.y,z:counter.z}).y;
 const polygon=(points,parent)=>points.map(([x,z])=>{scratch.set(x,0,z);parent.localToWorld(scratch);return[scratch.x/metresPerCell,scratch.z/metresPerCell];});
 const counterBody={polygonCR:polygon([[counterRect[0],counterRect[1]],[counterRect[2],counterRect[1]],[counterRect[2],counterRect[3]],[counterRect[0],counterRect[3]]],frame),minYM:worldMin,maxYM:worldMin+1.34,buildingEntryId:PRINT_SHOP_SERVICE_PILOT,interiorFurniture:true,serviceStation:true};
 function sweptClear(from,to,occupants){
  if(!Array.isArray(occupants)||occupants.length>64)return false;
  doorHinge.updateWorldMatrix(true,false);inverse.copy(doorHinge.matrixWorld).invert();
  const a=-smooth(from)*Math.PI/2,b=-smooth(to)*Math.PI/2,steps=Math.max(1,Math.ceil(Math.abs(b-a)/.035));
  for(const body of occupants){
   if(!finitePoint(body?.position)||!Number.isFinite(body.radius)||body.radius<=0||!Number.isFinite(body.height)||body.height<=0)return false;
   scratch.set(body.position.x,body.position.y,body.position.z).applyMatrix4(inverse);
   if(scratch.y>=2.1||scratch.y+body.height<=0)continue;
   for(let i=0;i<=steps;i++){
    const angle=a+(b-a)*i/steps,c=Math.cos(angle),s=Math.sin(angle),x=c*(scratch.x+half)-s*scratch.z,z=s*(scratch.x+half)+c*scratch.z;
    const dx=Math.max(.01-x,0,x-leafEnd),dz=Math.max(0,Math.abs(z)-.12);
    if(Math.hypot(dx,dz)<body.radius+.03)return false;
   }
  }
  return true;
 }
 function requestDoor(open,{actorPosition,occupants}={}){
  if(disposed||typeof open!=='boolean'||!finitePoint(actorPosition))return{accepted:false,reason:'invalid-door-request'};
  if(open&&Math.hypot(actorPosition.x-layout.doorInside.x,actorPosition.y-layout.doorInside.y,actorPosition.z-layout.doorInside.z)>.25)return{accepted:false,reason:'staff-not-at-door'};
  const next=open?1:0;if(!sweptClear(fraction,next,occupants))return{accepted:false,reason:'door-sweep-occupied'};
  target=next;return{accepted:true,open};
 }
 function update(dt,occupants){
  if(disposed||fraction===target)return false;
  if(!Number.isFinite(dt)||dt<=0)return false;
  const next=fraction+Math.max(-Math.min(dt,.1)/.6,Math.min(Math.min(dt,.1)/.6,target-fraction));
  if(!sweptClear(fraction,next,occupants))return false;
  fraction=next;doorPivot.rotation.y=-smooth(fraction)*Math.PI/2;root.updateWorldMatrix(true,true);version++;return true;
 }
 function bodies(){
  if(disposed)return[];if(cachedVersion===version)return cachedBodies;cachedVersion=version;
  const descriptor={buildingEntryId:PRINT_SHOP_SERVICE_PILOT,movingDoor:true,interiorDoor:true,serviceDoorId:layout.doorId};
  const doorBody={...descriptor,polygonCR:polygon([[0,-.055],[leafEnd,-.055],[leafEnd,.055],[0,.055]],doorPivot),minYM:worldMin,maxYM:worldMin+2.1};
  const handles={...descriptor,polygonCR:polygon([[leafEnd-.25,-.11],[leafEnd-.075,-.11],[leafEnd-.075,.11],[leafEnd-.25,.11]],doorPivot),minYM:worldMin+.93,maxYM:worldMin+1.16};
  cachedBodies=[counterBody,doorBody,handles];return cachedBodies;
 }
 const api={root,layout,local,requestDoor,update,getCollisionBodies:bodies,sweptClear,
  get doorState(){return{id:layout.doorId,fraction,open:target===1}},get needsUpdate(){return fraction!==target},
  stats:()=>({parts:counterStats.parts+doorStats.parts,draws:counterStats.draws+doorStats.draws,triangles:counterStats.triangles+doorStats.triangles}),
  dispose(){if(disposed)return;disposed=true;pool.dispose();doorPool.dispose();root.removeFromParent();cachedBodies=null;stations.delete(entry);}
 };
 stations.set(entry,api);return api;
}
