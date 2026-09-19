// Doors use the entrance's existing E API, including animated collider refresh.
export function createInteriorRoomDoors(T,{root,entry,metresPerCell=4.1}){
 const doors=[],geo=new T.BoxGeometry(1,1,1),materials=new Map(),brass=new T.MeshStandardMaterial({color:'#ad8b4c',metalness:.7,roughness:.3}),bodiesCache={version:-1,value:[]},partBuckets=new Map(),batchMeshes=[],transform=new T.Matrix4(),composed=new T.Matrix4();let version=0,disposed=false,active=false,idleUpdates=0,finalized=false;
 function create({x,z,y,axis='x',inward=1,name='Комната',color='#665043'}){
  if(disposed)throw Error('Interior doors disposed');if(![x,y,z].every(Number.isFinite)||!['x','z'].includes(axis)||![1,-1].includes(inward))throw Error('Invalid interior door');
  const hinge=new T.Group();hinge.position.set(x,y,z);hinge.rotation.y=axis==='z'?Math.PI/2:0;const baseYaw=hinge.rotation.y;
  // Origin at doorway centre; leaf pivot is 0.60m to its left.
  const pivot=new T.Group();pivot.position.x=-.60;hinge.add(pivot);root.add(hinge);
  const colorKey=new T.Color(color).getHex();let material=materials.get(colorKey);if(!material){material=new T.MeshStandardMaterial({color,roughness:.68});materials.set(colorKey,material)}
  const d={hinge,pivot,x,z,y,axis,inward,name,fraction:0,target:0,baseYaw,parts:[]};doors.push(d);const identity=new T.Quaternion();
  const add=(size,p,mat)=>{let bucket=partBuckets.get(mat);if(!bucket){bucket={material:mat,parts:[],mesh:null};partBuckets.set(mat,bucket)}const part={bucket,local:new T.Matrix4().compose(new T.Vector3(...p),identity,new T.Vector3(...size)),index:-1};bucket.parts.push(part);d.parts.push(part)};
  add([1.18,2.06,.065],[.60,1.04,0],material);
  for(const yy of[.58,1.49])for(const side of[-1,1])add([.92,.7,.022],[.6,yy,side*.043],material);
  for(const side of[-1,1]){add([.045,.19,.025],[1.05,1.04,side*.062],brass);add([.13,.036,.045],[1.005,1.08,side*.084],brass)}
  version++;root.updateWorldMatrix(true,true);return d;
 }
 function updateDoorMatrices(d){if(!finalized)return;d.hinge.updateMatrix();d.pivot.updateMatrix();transform.multiplyMatrices(d.hinge.matrix,d.pivot.matrix);for(const part of d.parts){composed.multiplyMatrices(transform,part.local);part.bucket.mesh.setMatrixAt(part.index,composed);part.bucket.mesh.instanceMatrix.needsUpdate=true}}
 function finalize(){if(disposed||finalized)return;for(const bucket of partBuckets.values()){const mesh=new T.InstancedMesh(geo,bucket.material,bucket.parts.length);mesh.name=bucket.material===brass?'InteriorDoorBrass':'InteriorDoorWood';mesh.castShadow=mesh.receiveShadow=true;bucket.parts.forEach((part,index)=>{part.index=index});bucket.mesh=mesh;root.add(mesh);batchMeshes.push(mesh)}finalized=true;for(const d of doors)updateDoorMatrices(d);for(const mesh of batchMeshes){mesh.computeBoundingBox();mesh.computeBoundingSphere()}}
 function near(point){const p=root.worldToLocal(new T.Vector3(point.x,point.y,point.z));let best=null;for(const d of doors){const distance=Math.hypot(p.x-d.x,p.z-d.z);if(Math.abs(p.y-d.y)<.65&&distance<1.65&&(!best||distance<best.distance))best={door:d,distance,anchor:root.localToWorld(new T.Vector3(d.x,d.y+1.65,d.z)),action:(d.target?'Закрыть · ':'Открыть · ')+d.name,opening:!!d.target,fraction:d.fraction,instanceId:entry.instance.id}}return best}
 const eased=f=>f*f*(3-2*f),angle=(d,f)=>d.inward*eased(f)*Math.PI/2;
 function sweepContains(d,point,from,to){if(!point)return false;const p=d.hinge.worldToLocal(new T.Vector3(point.x,point.y,point.z));if(p.y>=2.08||p.y+1.9<=0)return false;
  const a=angle(d,from),b=angle(d,to),steps=Math.max(1,Math.ceil(Math.abs(b-a)/.04));
  // Sample the swept leaf rectangle against a hero capsule. Extra 3 cm covers
  // the angular sampling gap and the protruding handle on either leaf face.
  for(let i=0;i<=steps;i++){const t=a+(b-a)*i/steps,c=Math.cos(t),s=Math.sin(t),x=c*(p.x+.6)-s*p.z,z=s*(p.x+.6)+c*p.z,dx=Math.max(.01-x,0,x-1.19),dz=Math.max(0,Math.abs(z)-.11);if(Math.hypot(dx,dz)<.36)return true;}return false;
 }
 function interact(point){if(disposed)return{accepted:false,reason:'disposed'};const n=near(point);if(!n)return{accepted:false,reason:'out-of-range'};const d=n.door,target=d.target?0:1;if(sweepContains(d,point,d.fraction,target))return{accepted:false,reason:'door-sweep-occupied'};d.target=target;active=doors.some(item=>item.fraction!==item.target);return{accepted:true,opening:!!d.target}}
 function update(dt,point){if(disposed)return;if(!active){idleUpdates++;return}dt=Number.isFinite(dt)?Math.max(0,Math.min(.1,dt)):0;active=false;for(const d of doors){const old=d.fraction,next=old+Math.max(-dt/.6,Math.min(dt/.6,d.target-old));if(next!==old&&!sweepContains(d,point,old,next)){d.fraction=next;d.pivot.rotation.y=angle(d,next);updateDoorMatrices(d);version++}if(d.fraction!==d.target)active=true}if(version!==bodiesCache.version)root.updateWorldMatrix(true,true)}
 function bodies(){if(bodiesCache.version===version)return bodiesCache.value;bodiesCache.version=version;bodiesCache.value=doors.map(d=>{const points=[[.01,-.05],[1.19,-.05],[1.19,.05],[.01,.05]].map(([x,z])=>d.pivot.localToWorld(new T.Vector3(x,0,z)));return{polygonCR:points.map(p=>[p.x/metresPerCell,p.z/metresPerCell]),minYM:points[0].y,maxYM:points[0].y+2.08,buildingEntryId:entry.instance.id,movingDoor:true,interiorDoor:true}});return bodiesCache.value}
 return{create,finalize,near,interact,update,bodies,doors,get active(){return active},stats:()=>({doors:doors.length,draws:batchMeshes.length,active,idleUpdates}),dispose(){if(disposed)return;disposed=true;for(const mesh of batchMeshes)mesh.removeFromParent();batchMeshes.length=0;for(const d of doors)d.hinge.removeFromParent();doors.length=0;version++;geo.dispose();brass.dispose();for(const m of materials.values())m.dispose();materials.clear();partBuckets.clear()}};
}
