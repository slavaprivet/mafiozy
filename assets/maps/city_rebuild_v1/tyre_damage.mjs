// New /walk tyre behavior requested by the user; tuning is preview-only.
export const TYRE_RULES=Object.freeze({deflatePerSecond:.7,detachDistance:60,sparkCapacity:64});
export const TYRE_IDS=Object.freeze(['front_left','front_right','rear_left','rear_right']);
export function createTyreState(){return TYRE_IDS.map(id=>({id,punctured:false,pressure:1,distance:0,detached:false}))}
export function punctureTyre(state,id){if(!TYRE_IDS.includes(id))return state;return state.map(t=>t.id===id&&!t.punctured?{...t,punctured:true}:t)}
export function stepTyres(state,dt,distance){
 if(!Number.isFinite(dt)||dt<0||!Number.isFinite(distance))throw Error('Invalid tyre motion');
 return state.map(t=>{if(!t.punctured||t.detached)return t;const pressure=Math.max(0,t.pressure-.7*dt),travel=t.distance+(pressure<.2?Math.abs(distance):0);return{...t,pressure,distance:travel,detached:travel>=60}});
}
export function tyreDriveEffects(state){
 const severity=t=>t.detached?1.7:1-t.pressure,front=state.filter(t=>t.id.startsWith('front')),rear=state.filter(t=>t.id.startsWith('rear'));
 const load=state.reduce((sum,t)=>sum+severity(t),0),axle=items=>Math.max(.26,1-items.reduce((sum,t)=>sum+severity(t),0)*.25);
 const drag=id=>severity(state.find(t=>t.id===id));
 return{speedFactor:Math.max(.22,1-load*.18),frontGrip:axle(front),rearGrip:axle(rear),pull:(drag('front_left')-drag('front_right'))*.11+(drag('rear_left')-drag('rear_right'))*.035};
}
export function wheelIdFromHit(object){for(let node=object;node;node=node.parent)if(TYRE_IDS.includes(node.userData?.vehicleWheelId))return node.userData.vehicleWheelId;return null}

export function createTyreDamage(T,car,{groundHeight=()=>0,onDetach=()=>{}}={}){
 let state=createTyreState(),disposed=false,sparkCursor=0;const emitted=new Set(),wheelRest=new Map();
 const object=new T.Group();object.name='Detached_tyres_and_rim_sparks';(car.object.parent||car.object).add(object);
 const rubber=new T.MeshStandardMaterial({color:'#292b26',roughness:.95,transparent:true}),loose=new Map();
 for(const wheel of car.wheels){wheelRest.set(wheel.id,{y:wheel.pivot.position.y,scale:wheel.tire.scale.clone(),visible:wheel.tire.visible});const mesh=new T.Mesh(new T.TorusGeometry(.31,.09,8,20),rubber.clone());mesh.visible=false;mesh.raycast=()=>{};object.add(mesh);loose.set(wheel.id,{mesh,age:0,origin:new T.Vector3(),velocity:new T.Vector3()})}
 const sparkGeometry=new T.BoxGeometry(.016,.016,.07),sparkMaterial=new T.MeshBasicMaterial({color:'#ffcf73',toneMapped:false}),sparks=new T.InstancedMesh(sparkGeometry,sparkMaterial,64);sparks.name='Bare_rim_sparks';sparks.frustumCulled=false;sparks.raycast=()=>{};sparks.instanceMatrix.setUsage(T.DynamicDrawUsage);object.add(sparks);
 const particles=Array.from({length:64},()=>({life:0,p:new T.Vector3(),v:new T.Vector3()})),matrix=new T.Matrix4(),q=new T.Quaternion(),scale=new T.Vector3(),zero=new T.Matrix4().makeScale(0,0,0),inverse=new T.Matrix4();for(let i=0;i<64;i++)sparks.setMatrixAt(i,zero);
 function hit(payload){if(disposed)return false;const mesh=payload.object||payload.hit?.object;let belongs=false;for(let node=mesh;node;node=node.parent)if(node===car.object)belongs=true;if(!belongs)return false;const id=wheelIdFromHit(mesh);if(!id)return false;const before=state;state=punctureTyre(state,id);return state.some((t,i)=>t!==before[i])}
 function update(carState,dt){
  if(disposed)return;const before=state;state=stepTyres(state,dt,carState?.distance||0);car.object.updateWorldMatrix(true,true);object.updateWorldMatrix(true,false);inverse.copy(object.matrixWorld).invert();
  state.forEach((t,i)=>{
   const wheel=car.wheels.find(w=>w.id===t.id),rest=wheelRest.get(t.id);wheel.pivot.position.y=rest.y-(t.detached?.16:(1-t.pressure)*.1);wheel.rollingRadius=t.detached?.24:.4*(.75+.25*t.pressure);wheel.tire.scale.x=rest.scale.x*(.65+.35*t.pressure);wheel.tire.visible=rest.visible&&!t.detached;
   if(t.detached&&!before[i].detached&&!emitted.has(t.id)){emitted.add(t.id);const item=loose.get(t.id),side=t.id.endsWith('left')?1:-1;item.age=0;item.mesh.visible=true;item.origin.copy(wheel.pivot.getWorldPosition(new T.Vector3()));item.velocity.set(side*1.4,2.2,-1).transformDirection(car.object.matrixWorld).multiplyScalar(2.4);item.velocity.y=2.2;onDetach({wheelId:t.id,point:item.origin.clone()})}
   if(t.detached&&Math.abs(carState?.distance||0)>.002){
    const count=Math.min(6,Math.max(1,Math.ceil(Math.abs(carState.distance)/.16)));
    for(let n=0;n<count;n++){const particle=particles[sparkCursor++%64],contact=wheel.pivot.getWorldPosition(new T.Vector3());particle.life=.18+(sparkCursor%4)*.05;particle.p.copy(contact);particle.p.y=groundHeight(contact.x,contact.z)+.035;particle.v.set(Math.sin(sparkCursor*2.4)*1.5,.6+(sparkCursor%3)*.2,Math.cos(sparkCursor*2.4)*1.5);particle.v.x-=Math.sin(carState.yaw)*Math.sign(carState.speed)*2;particle.v.z-=Math.cos(carState.yaw)*Math.sign(carState.speed)*2}
   }
  });
  for(const item of loose.values()){if(!item.mesh.visible)continue;item.age+=dt;const age=item.age,p=item.origin.clone().addScaledVector(item.velocity,Math.min(age,2));p.y=Math.max(groundHeight(p.x,p.z)+.34,item.origin.y+2.2*age-4.9*age*age);item.mesh.position.copy(p.applyMatrix4(inverse));item.mesh.rotation.set(age*3,age*2,age*4);item.mesh.material.opacity=Math.min(1,5-age);if(age>=5)item.mesh.visible=false}
  for(let i=0;i<64;i++){const particle=particles[i];particle.life=Math.max(0,particle.life-dt);if(!particle.life){sparks.setMatrixAt(i,zero);continue}particle.v.y-=9.8*dt;particle.p.addScaledVector(particle.v,dt);particle.p.y=Math.max(groundHeight(particle.p.x,particle.p.z)+.012,particle.p.y);scale.setScalar(Math.min(1,particle.life/.1));q.setFromUnitVectors(new T.Vector3(0,0,1),particle.v.clone().normalize());matrix.compose(particle.p,q,scale).premultiply(inverse);sparks.setMatrixAt(i,matrix)}sparks.instanceMatrix.needsUpdate=true;
 }
 function reset(){state=createTyreState();emitted.clear();sparkCursor=0;for(const wheel of car.wheels){const rest=wheelRest.get(wheel.id);wheel.pivot.position.y=rest.y;wheel.rollingRadius=.4;wheel.tire.scale.copy(rest.scale);wheel.tire.visible=rest.visible}for(const item of loose.values())item.mesh.visible=false;for(let i=0;i<64;i++){particles[i].life=0;sparks.setMatrixAt(i,zero)}sparks.instanceMatrix.needsUpdate=true}
 function dispose(){if(disposed)return;reset();disposed=true;object.removeFromParent();for(const item of loose.values()){item.mesh.geometry.dispose();item.mesh.material.dispose()}sparks.dispose();sparkGeometry.dispose();sparkMaterial.dispose();rubber.dispose()}
 return{object,hit,update,reset,dispose,get state(){return state},get effects(){return tyreDriveEffects(state)},stats:()=>({wheels:state.map(t=>({...t})),sparks:particles.filter(p=>p.life>0).length,looseTyres:[...loose.values()].filter(t=>t.mesh.visible).length})};
}
