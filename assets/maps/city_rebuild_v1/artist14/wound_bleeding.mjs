import {surfaceMeshRecord,validateSurfaceMesh} from '../npc_surface_state.mjs';

// Cosmetic, bounded emitters. Coordinates remain attached to skin/bones, never
// to the receipt's old world point. No health, ground decals or damage timers.
export function createWoundBleeding(THREE,{root,bones,unit=1,height=1.8}={}){
 const rows=[],point=new THREE.Vector3(),a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3(),rootPoint=new THREE.Vector3(),lastRoot=new THREE.Vector3();
 const boneEntries=Object.entries(bones||{}).filter(([,bone])=>bone?.isBone),boneSet=new Set(boneEntries.map(([,bone])=>bone));
 let nextEmission=0,lastTime=null,hasRoot=false,emittedDrops=0;
 const finite=v=>v&&[v.x,v.y,v.z].every(Number.isFinite);
 const weightsOk=w=>Array.isArray(w)&&w.length===3&&w.every(x=>Number.isFinite(x)&&x>=-.0001&&x<=1.0001)&&Math.abs(w.reduce((s,x)=>s+x,0)-1)<.0001;
 const indicesOk=(mesh,indices)=>mesh?.isMesh&&Array.isArray(indices)&&indices.length===3&&indices.every(i=>Number.isInteger(i)&&i>=0&&i<mesh.geometry.attributes.position.count);
 function skinPoint(binding,out){
  // Host has updated bone world matrices. Three's getVertexPosition reads the
  // three vertices' bone transforms directly: no full skeleton update/raycast.
  const mesh=binding.mesh;mesh.updateMatrixWorld(true);
  mesh.getVertexPosition(binding.indices[0],a).applyMatrix4(mesh.matrixWorld);
  mesh.getVertexPosition(binding.indices[1],b).applyMatrix4(mesh.matrixWorld);
  mesh.getVertexPosition(binding.indices[2],c).applyMatrix4(mesh.matrixWorld);
  return out.set(0,0,0).addScaledVector(a,binding.weights[0]).addScaledVector(b,binding.weights[1]).addScaledVector(c,binding.weights[2]);
 }
 function skinBinding(event){
  const anchor=event.anchor;
  if(anchor?.version===1&&anchor.actorUuid===root.uuid&&Array.isArray(anchor.meshPath)&&anchor.meshPath.length<=64){
   let mesh=root;
   for(const part of anchor.meshPath){
    if(!part||!Number.isInteger(part.ordinal)||part.ordinal<0)return null;
    mesh=mesh?.children.filter(child=>child.name===part.name&&child.type===part.type)[part.ordinal];
   }
   if(mesh?.uuid===anchor.meshUuid&&mesh.geometry?.uuid===anchor.geometryUuid&&indicesOk(mesh,anchor.indices)&&weightsOk(anchor.weights)){
    const binding={kind:'skin',mesh,indices:[...anchor.indices],weights:[...anchor.weights]};
    if(skinPoint(binding,point).distanceTo(event.point)<=.15*unit)return binding;
   }
  }
  const mesh=event.object,face=event.face;
  if(mesh?.isMesh&&face&&root.getObjectById(mesh.id)===mesh){
   const indices=[face.a,face.b,face.c];if(!indicesOk(mesh,indices))return null;
   mesh.skeleton?.update();mesh.getVertexPosition(indices[0],a).applyMatrix4(mesh.matrixWorld);mesh.getVertexPosition(indices[1],b).applyMatrix4(mesh.matrixWorld);mesh.getVertexPosition(indices[2],c).applyMatrix4(mesh.matrixWorld);
   const weights=THREE.Triangle.getBarycoord(event.point,a,b,c,new THREE.Vector3())?.toArray();
   if(weightsOk(weights))return {kind:'skin',mesh,indices,weights};
  }
  return null;
 }
 function boneBinding(event){
  let selected=boneEntries.find(([key,bone])=>key===event.boneName||bone.name===event.boneName),best=Infinity;
  if(!selected)for(const entry of boneEntries){
   const bone=entry[1];bone.getWorldPosition(a);let distance=a.distanceToSquared(event.point);
   for(const child of bone.children){
    if(!boneSet.has(child))continue;child.getWorldPosition(b);c.subVectors(b,a);
    const t=Math.max(0,Math.min(1,point.copy(event.point).sub(a).dot(c)/Math.max(1e-12,c.lengthSq())));
    distance=Math.min(distance,point.copy(a).addScaledVector(c,t).distanceToSquared(event.point));
   }
   if(distance<best){best=distance;selected=entry;}
  }
  if(!selected||best!==Infinity&&best>(1.2*unit)**2)return null;
  const [boneName,bone]=selected,local=bone.worldToLocal(new THREE.Vector3(event.point.x,event.point.y,event.point.z));
  return {kind:'bone',boneName,bone,local};
 }
 function add(event,now){
  if(event?.confirmed!==true||event.blocked===true||event.id===undefined||event.id===null||!finite(event.point)||!Number.isFinite(now)||rows.some(row=>row.id===String(event.id)))return false;
  root.updateWorldMatrix(true,false);root.updateMatrixWorld(true);
  const binding=skinBinding(event)||boneBinding(event);if(!binding)return false;
  if(!hasRoot){root.getWorldPosition(lastRoot);hasRoot=true;}
  const heavy=event.heavy===true;
  rows.push({...binding,id:String(event.id),expiresAt:now+(heavy?12:8),nextAt:now+.18,interval:heavy?.32:.45});
  while(rows.length>4)rows.shift();return true;
 }
 function update(now,emit){
  if(!Number.isFinite(now))return {teleported:false,emitted:0};
  if(lastTime!==null&&now<lastTime)reset();lastTime=now;
  root.getWorldPosition(rootPoint);const teleported=hasRoot&&rootPoint.distanceTo(lastRoot)>Math.max(1,height*4);
  lastRoot.copy(rootPoint);hasRoot=true;
  for(let i=rows.length-1;i>=0;i--)if(rows[i].expiresAt<=now)rows.splice(i,1);
  let visible=true;for(let node=root;node;node=node.parent)if(!node.visible){visible=false;break;}
  if(!visible||teleported){nextEmission=now+.1;for(const row of rows)row.nextAt=now+row.interval;return {teleported,emitted:0};}
  if(!rows.length||now<nextEmission)return {teleported,emitted:0};
  // One emission per update, ten per second globally, with no catch-up burst.
  const due=rows.filter(row=>row.nextAt<=now).sort((x,y)=>x.nextAt-y.nextAt)[0];
  if(!due)return {teleported,emitted:0};
  if(due.kind==='skin')skinPoint(due,point);else point.copy(due.local).applyMatrix4(due.bone.matrixWorld);
  due.nextAt=now+due.interval;nextEmission=now+.1;
  if(finite(point)){emit(point);emittedDrops++;return {teleported,emitted:1};}
  return {teleported,emitted:0};
 }
 function reset(){rows.length=0;nextEmission=0;lastTime=null;hasRoot=false;emittedDrops=0;}
 function snapshot(now){return {version:1,rows:rows.filter(row=>row.expiresAt>now).map(row=>({id:row.id,kind:row.kind,remaining:row.expiresAt-now,interval:row.interval,...(row.kind==='skin'?{mesh:surfaceMeshRecord(root,row.mesh),indices:[...row.indices],weights:[...row.weights]}:{boneName:row.boneName,local:row.local.toArray()})}))};}
 function validateSnapshot(data,receipts){
  if(data===undefined)return [];
  if(data?.version!==1||!Array.isArray(data.rows)||data.rows.length>4)throw Error('Invalid bleeding state');
  const ids=new Set();return data.rows.map(row=>{
   if(typeof row.id!=='string'||!row.id||row.id.length>1024||ids.has(row.id)||receipts&&!receipts.includes(row.id)||!Number.isFinite(row.remaining)||row.remaining<0||row.remaining>12||![.32,.45].includes(row.interval))throw Error('Invalid bleeding lifetime/receipt');ids.add(row.id);
   if(row.kind==='skin'){
    const mesh=validateSurfaceMesh(root,row.mesh);if(!indicesOk(mesh,row.indices)||!weightsOk(row.weights))throw Error('Invalid bleeding skin anchor');
    return {...row,mesh,indices:[...row.indices],weights:[...row.weights]};
   }
   const bone=bones?.[row.boneName];
   if(row.kind!=='bone'||!bone?.isBone||!Array.isArray(row.local)||row.local.length!==3||row.local.some(v=>!Number.isFinite(v)||Math.abs(v)>100))throw Error('Invalid bleeding bone anchor');
   return {...row,bone,local:new THREE.Vector3(...row.local)};
  });
 }
 function restore(data,{now,elapsedSeconds=0,receipts}={}){
  const prepared=validateSnapshot(data,receipts);reset();
  for(const row of prepared)if(row.remaining>elapsedSeconds)rows.push({...row,expiresAt:now+row.remaining-elapsedSeconds,nextAt:now+row.interval});
  nextEmission=now+.1;lastTime=now;
 }
 return {add,update,reset,snapshot,validateSnapshot,restore,get count(){return rows.length;},get emittedDrops(){return emittedDrops;}};
}
