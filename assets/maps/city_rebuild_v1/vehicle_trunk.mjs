// Metres, +Z forward and +X driver-left. This adapter preserves the existing
// four seat doors and converts the authored rear lid into an independent hinge.
export const VEHICLE_TRUNK_RULES=Object.freeze({
  interactionRange:1.45,maxInteractionSpeed:.5,autoCloseSpeed:2.5,
  openAngle:Math.PI*85/180,animationSeconds:.70,closedDetachSpeed:17,openDetachSpeed:9,
});
const clamp=(value,min=0,max=1)=>Math.max(min,Math.min(max,value));
const smooth=value=>{const t=clamp(value);return t*t*(3-2*t)};
const finitePoint=p=>p&&[p.x,p.y??0,p.z].every(Number.isFinite);

export function createTrunkState(){return{open:false,amount:0,velocity:0,target:0,detached:false,externalDebris:false,latchIntegrity:1,hingeIntegrity:1,revision:0,reason:null}}

// Exact critically damped spring: starts gently, follows mid-animation reversal
// continuously and settles without framerate-dependent hinge overshoot.
export function stepVehiclePanelMotion(amount,velocity,target,dt){
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid panel animation time');
  const h=Math.min(dt,.2),omega=18,offset=amount-target,blend=(velocity+omega*offset)*h,decay=Math.exp(-omega*h);
  let next=clamp(target+(offset+blend)*decay),speed=(velocity-omega*blend)*decay;
  if(Math.abs(next-target)<.0002&&Math.abs(speed)<.004){next=target;speed=0}
  return{amount:next,velocity:speed};
}

export function stepTrunkState(state,dt,{speed=0,disabled=false}={}){
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid trunk animation time');
  if(state.detached)return state;
  const target=disabled||Math.abs(speed)>VEHICLE_TRUNK_RULES.autoCloseSpeed?0:state.target;
  return{...state,target,open:target===1,...stepVehiclePanelMotion(state.amount,state.velocity||0,target,dt)};
}

// Only the rear approach sector owns a short E press. The side doors retain
// their existing 0.3-second hold; rear-seat passengers cannot open the trunk.
export function findTrunkInteraction(vehicle,hero,{state=createTrunkState(),profile={},occupied=false,transition=false,blocked=false,damageState=null,range=VEHICLE_TRUNK_RULES.interactionRange}={}){
  if(!vehicle||!finitePoint(hero)||![vehicle.x,vehicle.z,vehicle.yaw,vehicle.speed??0].every(Number.isFinite)||occupied||transition||blocked||state.detached||damageState?.destroying||damageState?.wrecked||Math.abs(vehicle.speed||0)>VEHICLE_TRUNK_RULES.maxInteractionSpeed)return null;
  const sin=Math.sin(vehicle.yaw),cos=Math.cos(vehicle.yaw),dx=hero.x-vehicle.x,dz=hero.z-vehicle.z;
  const side=dx*cos-dz*sin,front=dx*sin+dz*cos,rearZ=profile.rearZ??-2.21,width=profile.width??1.91,handleY=profile.handleY??1.02;
  if(front>rearZ-.10||Math.abs(side)>width/2+.32||Math.abs((hero.y??vehicle.y??0)-(vehicle.y??0))>1.8)return null;
  const near=Math.hypot(side,front-rearZ);if(near>range)return null;
  return{kind:'trunk',near,anchor:{x:vehicle.x+rearZ*sin,y:(vehicle.y??0)+handleY,z:vehicle.z+rearZ*cos},action:state.target?'close':'open',label:state.target?'Закрыть багажник':'Открыть багажник'};
}

export function createVehicleTrunk(T,RoundedBox,car,{scene=null,groundHeight=()=>0,lid:providedLid=null,sealedCore:providedCore=null,profile:profileOverride={},onDetach=()=>{}}={}){
  if(!car?.object)throw Error('Trunk requires a vehicle object');
  const spec=car.trunkSpec||{},lid=providedLid||spec.lid||car.object.getObjectByName('Trunk_lid');
  // A pickup bed or an artist model without a separate lid needs its own
  // authored tailgate contract. Never rotate an entire unsplit vehicle mesh.
  let bodyMesh=null;lid?.traverse(node=>{if(!bodyMesh&&node.isMesh&&node.geometry?.attributes?.position)bodyMesh=node});
  if(!bodyMesh)return{enabled:false,reason:'no-separate-trunk-lid',interaction:()=>null,toggle:()=>({accepted:false,reason:'no-separate-trunk-lid'}),setOpen:()=>({accepted:false,reason:'no-separate-trunk-lid'}),update(){},contactImpact:()=>false,detach:()=>false,reset(){},clearDebris:()=>0,dispose(){},stats:()=>({enabled:false,detached:false,amount:0,debris:0})};
  const core=providedCore||spec.core||car.object.getObjectByName('Trunk_core'),coreVisible=core?.visible,createCavity=spec.createCavity!==false;
  const original={parent:lid.parent,position:lid.position.clone(),quaternion:lid.quaternion.clone(),scale:lid.scale.clone(),visible:lid.visible,geometry:lid.geometry};
  const ownMeshes=[],ownMaterials=new Set(),shellAdditions=[],struts=[],debris=[];
  let state=createTrunkState(),disposed=false,time=0,lastContact=-Infinity,lastAngle=-1,idleUpdates=0;
  car.object.updateWorldMatrix(true,true);
  const localBounds=node=>{
    const bounds=new T.Box3(),point=new T.Vector3(),inverse=car.object.matrixWorld.clone().invert();
    node.traverse(mesh=>{const p=mesh.geometry?.attributes?.position;if(!p)return;for(let i=0;i<p.count;i++)bounds.expandByPoint(point.fromBufferAttribute(p,i).applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse))});
    return bounds;
  };
  let lidBounds=localBounds(lid);const coreBounds=core?localBounds(core):null;
  // The demo's old 17cm slab blocked a 30cm object even when fully raised.
  // Keep its painted top surface and footprint, thinning only its underside.
  if(createCavity&&lid.isMesh&&lidBounds.max.y-lidBounds.min.y>.105){
    lid.geometry=lid.geometry.clone();const positions=lid.geometry.attributes.position,toCar=car.object.matrixWorld.clone().invert().multiply(lid.matrixWorld),toMesh=toCar.clone().invert(),point=new T.Vector3(),factor=.065/(lidBounds.max.y-lidBounds.min.y);
    for(let i=0;i<positions.count;i++){point.fromBufferAttribute(positions,i).applyMatrix4(toCar);point.y=lidBounds.max.y-(lidBounds.max.y-point.y)*factor;point.applyMatrix4(toMesh);positions.setXYZ(i,point.x,point.y,point.z)}positions.needsUpdate=true;lid.geometry.computeVertexNormals();lid.geometry.computeBoundingBox();lid.geometry.computeBoundingSphere();lidBounds=localBounds(lid);
  }
  const width=lidBounds.max.x-lidBounds.min.x,depth=lidBounds.max.z-lidBounds.min.z;
  const mode=spec.mode||'trunk',requestedAngle=Number.isFinite(spec.openAngle)?spec.openAngle:mode==='tailgate'?-Math.PI/2:VEHICLE_TRUNK_RULES.openAngle;
  const openAngle=Math.sign(requestedAngle)*clamp(Math.abs(requestedAngle),Math.PI*80/180,Math.PI*85/180);
  const defaultHinge=[(lidBounds.min.x+lidBounds.max.x)/2,mode==='tailgate'?lidBounds.min.y:lidBounds.max.y,mode==='trunk'?lidBounds.max.z+.012:(lidBounds.min.z+lidBounds.max.z)/2];
  const hingePoint=Array.isArray(spec.hingePoint)&&spec.hingePoint.length===3&&spec.hingePoint.every(Number.isFinite)?spec.hingePoint:defaultHinge;
  const profile={width,rearZ:Math.min(lidBounds.min.z-.06,-(car.profile?.halfLength||0)-.025),handleY:mode==='trunk'?lidBounds.max.y-.055:lidBounds.min.y+(lidBounds.max.y-lidBounds.min.y)*.35,mode,...profileOverride};
  const hinge=new T.Group();hinge.name='Trunk_hinge';hinge.userData.vehiclePartId='trunk';
  hinge.position.fromArray(hingePoint);car.object.add(hinge);hinge.updateWorldMatrix(true,false);hinge.attach(lid);
  const closed={position:lid.position.clone(),quaternion:lid.quaternion.clone(),scale:lid.scale.clone()};
  const cavity=new T.Group();cavity.name='Trunk_cavity';car.object.add(cavity);if(core&&createCavity)core.visible=false;
  const material=options=>{const m=new T.MeshStandardMaterial(options);ownMaterials.add(m);return m};
  const felt=material({color:'#282b2c',roughness:.98}),rubber=material({color:'#151a1a',roughness:.91}),metal=material({color:'#a8a79b',metalness:.62,roughness:.42});
  const paint=Array.isArray(bodyMesh.material)?bodyMesh.material[0]:bodyMesh.material;
  function box(name,w,h,d,x,y,z,mat,parent=cavity,shell=false){
    const mesh=new T.Mesh(new RoundedBox(w,h,d,2,Math.min(.012,w/4,h/4,d/4)),mat);mesh.name=name;mesh.position.set(x,y,z);mesh.castShadow=mesh.receiveShadow=true;mesh.userData.vehiclePartId='trunk';parent.add(mesh);ownMeshes.push(mesh);
    if(shell&&car.shell){car.shell.push(mesh);shellAdditions.push(mesh)}return mesh;
  }
  const cavityMinX=Math.max(lidBounds.min.x+.13,coreBounds?.min.x??-width*.36),cavityMaxX=Math.min(lidBounds.max.x-.13,coreBounds?.max.x??width*.36);
  const cavityMinZ=lidBounds.min.z+.038,cavityMaxZ=lidBounds.max.z-.036,cavityWidth=cavityMaxX-cavityMinX,cavityDepth=cavityMaxZ-cavityMinZ;
  const cx=(cavityMinX+cavityMaxX)/2,cz=(cavityMinZ+cavityMaxZ)/2,bottom=coreBounds?.min.y??Math.max(.38,lidBounds.min.y-.48),rimY=lidBounds.min.y+.022,wallHeight=Math.max(.08,rimY-bottom),wallY=bottom+wallHeight/2;
  if(createCavity){
  box('Trunk_cargo_floor',cavityWidth,.035,cavityDepth,cx,bottom+.0175,cz,felt,cavity,true);
  for(const x of [cavityMinX,cavityMaxX])box('Trunk_cargo_side',.036,wallHeight,cavityDepth,x,wallY,cz,felt,cavity,true);
  for(const z of [cavityMinZ,cavityMaxZ])box('Trunk_cargo_bulkhead',cavityWidth,wallHeight,.032,cx,wallY,z,felt,cavity,true);
  for(const x of [cavityMinX,cavityMaxX])box('Trunk_weatherseal_side',.023,.020,cavityDepth+.03,x,rimY+.011,cz,rubber);
  for(const z of [cavityMinZ,cavityMaxZ])box('Trunk_weatherseal_cross',cavityWidth+.03,.020,.023,cx,rimY+.011,z,rubber);
  for(const x of [cx-cavityWidth*.33,cx+cavityWidth*.33])box('Trunk_cargo_tie_down',.045,.015,.036,x,bottom+.043,cavityMaxZ+.002,metal);
  }
  // The visible handle and lid underside move with the original paint panel,
  // including when the existing destruction adapter copies that assembly.
  const rootToLid=point=>lid.worldToLocal(car.object.localToWorld(point));
  const handlePosition=rootToLid(new T.Vector3(cx,profile.handleY,lidBounds.min.z-.019));
  box('Trunk_handle',Math.min(.24,width*.16),.035,.034,handlePosition.x,handlePosition.y,handlePosition.z,metal,lid);
  if(createCavity){
  const linerPosition=rootToLid(new T.Vector3(cx,lidBounds.min.y-.006,cz));
  box('Trunk_lid_inner_liner',width*.73,.012,depth*.73,linerPosition.x,linerPosition.y,linerPosition.z,felt,lid);
  const latchPosition=rootToLid(new T.Vector3(cx,lidBounds.min.y-.027,lidBounds.min.z+.015));
  box('Trunk_latch',.065,.044,.038,latchPosition.x,latchPosition.y,latchPosition.z,metal,lid);
  for(const side of [-1,1]){
    const x=cx+side*(cavityWidth*.5+.04),base=new T.Vector3(x,bottom+wallHeight*.35,cavityMaxZ-.025),tip=rootToLid(new T.Vector3(x,lidBounds.min.y-.009,lidBounds.min.z+depth*.23));
    const mesh=new T.Mesh(new T.CylinderGeometry(.011,.011,1,8),metal);mesh.name='Trunk_gas_strut';mesh.castShadow=true;cavity.add(mesh);ownMeshes.push(mesh);struts.push({mesh,base,tip});
    box('Trunk_hinge_bracket',.075,.037,.067,x,rimY-.018,cavityMaxZ,paint);
  }
  cavity.userData.cargoBounds={min:[cavityMinX+.02,bottom+.04,cavityMinZ+.02],max:[cavityMaxX-.02,Math.min(rimY,lidBounds.min.y-.026),cavityMaxZ-.02]};
  }else if(spec.cavityBounds)cavity.userData.cargoBounds=spec.cavityBounds;
  hinge.userData.originalLid=lid.name;
  const cargoBounds=cavity.userData.cargoBounds?{min:[...cavity.userData.cargoBounds.min],max:[...cavity.userData.cargoBounds.max]}:null;
  const cargoColliders=[];
  if(cargoBounds){
    // The exported volume is the free space INSIDE the visible liners, not
    // their centre-lines. Physical colliders use the actual mesh extents.
    const lo=cargoBounds.min,hi=cargoBounds.max,center=lo.map((v,i)=>(v+hi[i])*.5);
    car.object.updateWorldMatrix(true,true);
    car.object.traverse(mesh=>{
      if(!mesh.isMesh)return;for(let n=mesh;n;n=n.parent)if(n===lid||!n.visible)return;
      const floor=/^(Trunk_cargo_floor|Trunk_floor|Cargo_floor)$|_BedFloor$/.test(mesh.name),wall=/^(Trunk_cargo_side|Trunk_cargo_bulkhead|Trunk_liner_side|Trunk_liner_front|Cargo_liner_side|Cargo_bulkhead)$|_Bed(Side|Rail|Front)/.test(mesh.name);
      if(!floor&&!wall)return;const b=localBounds(mesh),min=b.min.toArray(),max=b.max.toArray();if(b.isEmpty())return;
      cargoColliders.push({id:mesh.name+'_'+cargoColliders.length,meshName:mesh.name,meshUUID:mesh.uuid,role:floor?'floor':'wall',min,max});
      if(floor){lo[1]=Math.max(lo[1],max[1]);for(const axis of [0,2]){lo[axis]=Math.max(lo[axis],min[axis]+.003);hi[axis]=Math.min(hi[axis],max[axis]-.003)}}
      else{const axis=max[0]-min[0]<max[2]-min[2]?0:2;
        if((min[axis]+max[axis])*.5<center[axis])lo[axis]=Math.max(lo[axis],max[axis]+.003);
        else hi[axis]=Math.min(hi[axis],min[axis]-.003);
      }
    });
    cavity.userData.cargoBounds=cargoBounds;
  }
  const pointValues=value=>Array.isArray(value)?value:[value?.x,value?.y,value?.z];
  const toCargoLocal=world=>{const a=pointValues(world);return car.object.worldToLocal(new T.Vector3(...a))};
  const toCargoWorld=local=>{const a=pointValues(local);return car.object.localToWorld(new T.Vector3(...a))};
  function localItemBounds(position,halfExtents,{world=false}={}){
    const p=pointValues(position),half=pointValues(halfExtents);if(![...p,...half].every(Number.isFinite)||half.some(v=>v<0))return null;
    car.object.updateWorldMatrix(true,false);const point=new T.Vector3(),box=new T.Box3();
    for(const x of [-1,1])for(const y of [-1,1])for(const z of [-1,1]){point.set(p[0]+x*half[0],p[1]+y*half[1],p[2]+z*half[2]);if(world)car.object.worldToLocal(point);box.expandByPoint(point)}return box;
  }
  function containsItem(position,halfExtents,options={}){
    if(!cargoBounds)return false;const box=localItemBounds(position,halfExtents,options);return!!box&&box.min.toArray().every((v,i)=>v>=cargoBounds.min[i]-1e-7)&&box.max.toArray().every((v,i)=>v<=cargoBounds.max[i]+1e-7);
  }
  function acceptsItem(position,halfExtents,options={}){
    if(disposed||!cargoColliders.some(c=>c.role==='floor')||(!state.detached&&state.amount<.85)||!containsItem(position,halfExtents,options))return false;
    // There must be a large enough opening beside the raised lid as well as
    // room at the final placement. An item may enter at the rear and slide
    // forward; it need not drop vertically onto its exact final coordinate.
    // This conservative projection runs only for placement queries, not frames.
    if(!state.detached&&lid.visible){
      car.object.updateWorldMatrix(true,true);const item=localItemBounds(position,halfExtents,options),cover=localBounds(lid),size=item.getSize(new T.Vector3()),lo=cargoBounds.min,hi=cargoBounds.max;
      const span=mode==='trunk'?Math.min(hi[2],cover.min.z)-lo[2]:mode==='hatch'?Math.min(hi[1],cover.min.y)-lo[1]:hi[1]-Math.max(lo[1],cover.max.y);
      if((mode==='trunk'?size.z:size.y)>span+.001)return false;
    }
    // Placement eligibility only; no inventory, item motion or teleportation.
    return true;
  }
  function worldCargoBounds(){
    if(!cargoBounds)return null;car.object.updateWorldMatrix(true,false);const corners=[];for(const x of [cargoBounds.min[0],cargoBounds.max[0]])for(const y of [cargoBounds.min[1],cargoBounds.max[1]])for(const z of [cargoBounds.min[2],cargoBounds.max[2]])corners.push(toCargoWorld([x,y,z]).toArray());const box=new T.Box3().setFromPoints(corners.map(p=>new T.Vector3(...p)));return{corners,min:box.min.toArray(),max:box.max.toArray()};
  }
  function worldCargoColliders(){car.object.updateWorldMatrix(true,false);return cargoColliders.map(c=>{const center=new T.Vector3(...c.min).add(new T.Vector3(...c.max)).multiplyScalar(.5),halfExtents=new T.Vector3(...c.max).sub(new T.Vector3(...c.min)).multiplyScalar(.5),scale=car.object.getWorldScale(new T.Vector3());return{...c,center:toCargoWorld(center).toArray(),halfExtents:halfExtents.multiply(scale).toArray(),quaternion:car.object.getWorldQuaternion(new T.Quaternion()).toArray()}})}

  function pose(){
    const angle=smooth(state.amount)*openAngle;
    if(angle===lastAngle&&struts.every(item=>item.mesh.visible===!state.detached))return;
    lastAngle=angle;hinge.rotation.x=angle;car.object.updateWorldMatrix(true,true);
    for(const {mesh,base,tip}of struts){mesh.visible=!state.detached;if(state.detached)continue;const end=car.object.worldToLocal(lid.localToWorld(tip.clone())),delta=end.clone().sub(base);mesh.position.copy(base).addScaledVector(delta,.5);mesh.scale.set(1,delta.length(),1);mesh.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),delta.normalize())}
  }
  function eligibility(context={}){
    if(disposed)return'disposed';if(state.detached||!lid.visible)return'detached';
    if(context.occupied)return'occupied';if(context.transition)return'transition';if(context.blocked)return'blocked';
    if(context.damageState?.destroying||context.damageState?.wrecked)return'destroyed';
    if(!context.vehicleState||!Number.isFinite(context.vehicleState.speed??0))return'missing-vehicle-state';
    if(Math.abs(context.vehicleState.speed||0)>VEHICLE_TRUNK_RULES.maxInteractionSpeed)return'moving';
    if(!interaction(context.hero,context.vehicleState,context))return'out-of-range';return null;
  }
  function interaction(hero,vehicleState,context={}){
    if(disposed||!lid.visible)return null;
    const pose={...vehicleState,y:car.object.getWorldPosition(new T.Vector3()).y};
    const result=findTrunkInteraction(pose,hero,{...context,state,profile});
    if(result){car.object.updateWorldMatrix(true,false);const anchor=car.object.localToWorld(new T.Vector3(cx,profile.handleY,profile.rearZ));result.anchor={x:anchor.x,y:anchor.y,z:anchor.z}}
    return result;
  }
  function setOpen(open,context={}){
    const reason=eligibility(context);if(reason)return{accepted:false,reason};
    state={...state,open:!!open,target:open?1:0,revision:state.revision+1,reason:null};return{accepted:true,open:state.open,action:open?'open':'close'};
  }
  const toggle=context=>setOpen(!state.target,context);
  function releaseDebris(part){part.mesh.removeFromParent();const geometries=new Set(),materials=new Set();part.mesh.traverse(node=>{if(node.geometry)geometries.add(node.geometry);for(const m of Array.isArray(node.material)?node.material:[node.material])if(m)materials.add(m)});for(const g of geometries)g.dispose();for(const m of materials)m.dispose()}
  function clearDebris(){const count=debris.length;for(const part of debris)releaseDebris(part);debris.length=0;return count}
  function worldPose(part){
    part.host.updateWorldMatrix(true,false);const matrix=new T.Matrix4().compose(part.position,part.quaternion,part.scale).premultiply(part.host.matrixWorld.clone().invert());matrix.decompose(part.mesh.position,part.mesh.quaternion,part.mesh.scale);
  }
  function detach({contact=null,vehicleState=null,reason='crash'}={}){
    if(disposed||state.detached)return false;
    // vehicle_damage may already have released this original into its own
    // persistent debris pool; do not create a second lid for the same wreck.
    if(!lid.visible){state={...state,detached:true,externalDebris:true,target:0,open:false,reason,revision:state.revision+1};pose();return true}
    const host=scene||car.object.parent;if(!host)return false;
    car.object.updateWorldMatrix(true,true);host.updateWorldMatrix(true,false);
    const mesh=lid.clone(true);mesh.name='Trunk_detached_lid';mesh.userData.vehicleDetachedPart=true;
    mesh.traverse(node=>{if(node.geometry)node.geometry=node.geometry.clone();if(node.material)node.material=Array.isArray(node.material)?node.material.map(m=>m.clone()):node.material.clone();node.raycast=()=>{}});
    const position=new T.Vector3(),quaternion=new T.Quaternion(),scale=new T.Vector3();lid.matrixWorld.decompose(position,quaternion,scale);host.add(mesh);
    const yaw=vehicleState?.travelYaw??vehicleState?.yaw??car.object.rotation.y,speed=Number(vehicleState?.speed)||0,impactSpeed=Math.max(0,Number(contact?.impactSpeed)||0);
    const direction=contact?.normal&&finitePoint(contact.normal)?new T.Vector3(contact.normal.x,contact.normal.y||0,contact.normal.z):new T.Vector3(0,0,-1).transformDirection(car.object.matrixWorld);if(direction.lengthSq()<1e-8)direction.set(0,0,-1);direction.normalize();
    const velocity=new T.Vector3(Math.sin(yaw)*speed,1.2+Math.min(4,impactSpeed*.16),Math.cos(yaw)*speed).addScaledVector(direction,1.3+Math.min(4,impactSpeed*.12));
    const part={mesh,host,position,quaternion,scale,velocity,spin:new T.Vector3(2.5+(impactSpeed*.08),.8,-1.4),settled:false,age:0,groundTime:0,bounds:null};worldPose(part);mesh.updateWorldMatrix(true,true);
    const inverse=mesh.matrixWorld.clone().invert(),bounds=new T.Box3(),vertex=new T.Vector3();mesh.traverse(node=>{const p=node.geometry?.attributes?.position;if(p)for(let i=0;i<p.count;i++)bounds.expandByPoint(vertex.fromBufferAttribute(p,i).applyMatrix4(node.matrixWorld).applyMatrix4(inverse))});part.bounds=bounds;
    debris.push(part);lid.visible=false;state={...state,detached:true,open:false,target:0,hingeIntegrity:0,latchIntegrity:0,reason,revision:state.revision+1};pose();onDetach({partId:'trunk',mesh,reason,contact});return true;
  }
  function contactImpact(contact,vehicleState=null){
    if(disposed||state.detached||time-lastContact<.2||!finitePoint(contact?.point))return false;
    const speed=Number(contact.impactSpeed);if(!Number.isFinite(speed)||speed<5)return false;
    car.object.updateWorldMatrix(true,false);const local=car.object.worldToLocal(new T.Vector3(contact.point.x,contact.point.y??0,contact.point.z));
    if(local.z>lidBounds.max.z+.30||Math.abs(local.x)>width/2+.45||local.y>lidBounds.max.y+1)return false;
    lastContact=time;const threshold=state.amount>.18?VEHICLE_TRUNK_RULES.openDetachSpeed:VEHICLE_TRUNK_RULES.closedDetachSpeed;
    const wear=clamp((speed-5)/(threshold*1.2),0,.85),hingeIntegrity=Math.max(0,state.hingeIntegrity-wear),latchIntegrity=Math.max(0,state.latchIntegrity-wear*1.15);
    state={...state,hingeIntegrity,latchIntegrity};
    if(speed>=threshold||hingeIntegrity<.22)return detach({contact,vehicleState,reason:'rear-impact'});
    if(latchIntegrity<.3){state={...state,target:1,open:true,reason:'broken-latch',revision:state.revision+1};return true}return wear>0;
  }
  function stepDebris(part,dt){
    if(part.settled)return;const steps=Math.max(1,Math.ceil(dt/(1/120))),h=dt/steps,point=new T.Vector3();
    for(let step=0;step<steps;step++){
      part.age+=h;part.velocity.y-=9.81*h;part.velocity.multiplyScalar(Math.exp(-.10*h));part.position.addScaledVector(part.velocity,h);
      const angle=part.spin.length()*h;if(angle)part.quaternion.premultiply(new T.Quaternion().setFromAxisAngle(part.spin.clone().normalize(),angle));
      let penetration=-Infinity;
      for(const x of [part.bounds.min.x,part.bounds.max.x])for(const y of [part.bounds.min.y,part.bounds.max.y])for(const z of [part.bounds.min.z,part.bounds.max.z]){point.set(x,y,z).multiply(part.scale).applyQuaternion(part.quaternion).add(part.position);const height=groundHeight(point.x,point.z);penetration=Math.max(penetration,(Number.isFinite(height)?height:0)+.018-point.y)}
      if(penetration>=0){part.position.y+=penetration;part.groundTime+=h;if(part.velocity.y<0)part.velocity.y=-part.velocity.y*.16;const friction=Math.exp(-8*h);part.velocity.x*=friction;part.velocity.z*=friction;part.spin.multiplyScalar(Math.exp(-10*h));if(part.groundTime>.35&&part.velocity.lengthSq()<.08&&part.spin.lengthSq()<.08){part.settled=true;part.velocity.set(0,0,0);part.spin.set(0,0,0)}}
    }
    worldPose(part);
  }
  function update(dt,{vehicleState=null,damageState=null}={}){
    if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid trunk update time');
    // A detached lid cannot receive interactions. Once its real debris has
    // reached the ground, preserve that exact pose without any more work.
    if(state.detached&&debris.every(part=>part.settled)){idleUpdates++;return}time+=dt;
    if(!state.detached&&!lid.visible)detach({vehicleState,reason:'external-destruction'});
    else if(!state.detached&&(damageState?.destroying||damageState?.wrecked))detach({vehicleState,reason:'destruction'});
    state=stepTrunkState(state,dt,{speed:vehicleState?.speed||0,disabled:damageState?.destroying||damageState?.wrecked});pose();
    for(const part of debris)stepDebris(part,Math.min(dt,.2));
  }
  function reset(){
    if(disposed)return;clearDebris();state=createTrunkState();time=0;lastContact=-Infinity;lastAngle=-1;idleUpdates=0;lid.visible=original.visible;lid.position.copy(closed.position);lid.quaternion.copy(closed.quaternion);lid.scale.copy(closed.scale);if(core&&createCavity)core.visible=false;pose();
  }
  function dispose(){
    if(disposed)return;clearDebris();disposed=true;
    for(const mesh of ownMeshes){mesh.removeFromParent();mesh.geometry.dispose()}for(const m of ownMaterials)m.dispose();
    original.parent.add(lid);lid.position.copy(original.position);lid.quaternion.copy(original.quaternion);lid.scale.copy(original.scale);lid.visible=original.visible;if(core)core.visible=coreVisible;
    if(original.geometry&&lid.geometry!==original.geometry){lid.geometry.dispose();lid.geometry=original.geometry}
    if(car.shell)for(const mesh of shellAdditions){const index=car.shell.indexOf(mesh);if(index>=0)car.shell.splice(index,1)}hinge.removeFromParent();cavity.removeFromParent();
  }
  pose();
  return{enabled:true,hinge,lid,cavity,profile,cargoBounds,cargoColliders,containsItem,acceptsItem,toCargoLocal,toCargoWorld,worldCargoBounds,worldCargoColliders,interaction,toggle,setOpen,update,contactImpact,detach,reset,clearDebris,dispose,get state(){return state},stats:()=>({enabled:true,open:state.open,amount:state.amount,angle:hinge.rotation.x,detached:state.detached,externalDebris:state.externalDebris,latchIntegrity:state.latchIntegrity,hingeIntegrity:state.hingeIntegrity,debris:debris.length,settledDebris:debris.filter(part=>part.settled).length,idleUpdates,cargoBounds,cargoColliderCount:cargoColliders.length,reason:state.reason,revision:state.revision})};
}
