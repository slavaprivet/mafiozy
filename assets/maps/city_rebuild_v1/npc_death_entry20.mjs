// ISOLATED OUTPUT CANDIDATE ONLY. The host must establish a fresh, physical
// vehicle-seat pose before render(..., seated=true). This module then adds a
// bounded fatal slump in bone-local space without writing the actor world root,
// visual pivot, transport state, HP, reservations, weapon, or fire pose.
export function createNpcDeathEntry20(THREE,getContext){
 const duration=.28,releaseDuration=.32,p=new THREE.Vector3(),q=new THREE.Quaternion(),targetQ=new THREE.Quaternion(),s=new THREE.Vector3(),delta=new THREE.Quaternion(),euler=new THREE.Euler();
 const proneStrength={bullet:.04,melee:.06,super:.08,kick:.06,dropkick:.08,blast:.10};
 let entries=null,buffer=null,lastAt=-Infinity,eligible=false,active=null,clearance=0,ungroundedContext=null,vehicleBound=false,vehicleReleaseAt=null,lastRawAge=0;
 function make(){
  const c=getContext();entries??=Object.entries(c.bones);
  return {bones:Object.fromEntries(entries.map(([name])=>[name,{p:new THREE.Vector3(),q:new THREE.Quaternion(),s:new THREE.Vector3()}])),pivotP:new THREE.Vector3(),pivotQ:new THREE.Quaternion(),scaledP:new THREE.Vector3()};
 }
 function captureInto(target,origin,c){
  target.origin=origin;
  for(const[name,bone]of entries){const value=target.bones[name];bone.matrix.decompose(value.p,value.q,value.s);}
  target.pivotP.copy(c.visualPivot.position);target.pivotQ.copy(c.visualPivot.quaternion);target.scaledP.copy(c.scaled.position);
 }
 function capture(origin,at){
  eligible=origin==='vehicle'||origin==='prone';if(!eligible)return;const c=getContext();buffer??=make();captureInto(buffer,origin,c);lastAt=at;
 }
 function begin(at){
  active=eligible&&at>=lastAt&&at-lastAt<=.25?buffer:null;eligible=false;vehicleBound=false;vehicleReleaseAt=null;lastRawAge=0;
  if(active){
   const c=getContext();
   if(active.origin==='vehicle')clearance=0;
   else{const y=c.visualPivot.position.y;c.groundPose();clearance=Math.max(0,y-c.visualPivot.position.y);c.visualPivot.position.y=y;c.object.updateMatrixWorld(true);}
   try{prepare(save(),true);}catch{active=null;}
  }
 }
 const seatAngle=(name,side)=>{
  if(name==='pelvis')return[.025,0,.025*side];
  if(name==='chest')return[.18,0,.065*side];
  if(name==='neck')return[.10,0,.025*side];
  if(name==='head')return[.16,.035*side,.035*side];
  if(name==='upperarm_l')return[.11,0,-.055];
  if(name==='upperarm_r')return[.11,0,.055];
  if(name==='forearm_l'||name==='forearm_r')return[.055,0,0];
  return null;
 };
 function seatQuaternion(name,value,weight,side){
  q.copy(value.q);const angle=seatAngle(name,side);if(angle)q.multiply(delta.setFromEuler(euler.set(angle[0]*weight,angle[1]*weight,angle[2]*weight)));return q;
 }
 function applyCurrentVehicle(rawAge,c,side){
  // c already contains this frame's complete car-relative pose. Never restore
  // an old pivot here: doing so drops vertical/pitch/roll/translation motion.
  entries??=Object.entries(c.bones);const weight=THREE.MathUtils.smoothstep(rawAge,.02,.42);
  for(const[name,bone]of entries){bone.matrix.decompose(p,q,s);const angle=seatAngle(name,side);if(angle)q.multiply(delta.setFromEuler(euler.set(angle[0]*weight,angle[1]*weight,angle[2]*weight)));bone.matrix.compose(p,q,s);bone.matrixWorldNeedsUpdate=true;}
  c.object.updateMatrixWorld(true);
  // Reuse one immutable-for-release buffer. This also initializes a cold actor
  // that arrived already confirmed-dead and had no prior live capture.
  buffer??=make();captureInto(buffer,'vehicle',c);active=buffer;vehicleBound=true;vehicleReleaseAt=null;
 }
 function applyVehicleRelease(rawAge,c,side){
  const weight=THREE.MathUtils.smoothstep(Math.max(0,rawAge-vehicleReleaseAt),0,releaseDuration);
  if(weight>=1){active=null;vehicleReleaseAt=null;return;}
  for(const[name,bone]of entries){bone.matrix.decompose(p,targetQ,s);const value=active.bones[name];q.copy(value.q).slerp(targetQ,weight);p.lerpVectors(value.p,p,weight);s.lerpVectors(value.s,s,weight);bone.matrix.compose(p,q,s);bone.matrixWorldNeedsUpdate=true;}
  c.visualPivot.position.lerpVectors(active.pivotP,c.visualPivot.position,weight);q.copy(c.visualPivot.quaternion);c.visualPivot.quaternion.copy(active.pivotQ).slerp(q,weight);c.scaled.position.lerpVectors(active.scaledP,c.scaled.position,weight);c.object.updateMatrixWorld(true);
 }
 function apply(rawAge,c){
  if(!active)return;const weight=THREE.MathUtils.smoothstep(rawAge,0,duration);
  if(weight>=1){active=null;return;}
  for(const[name,bone]of entries){bone.matrix.decompose(p,q,s);const value=active.bones[name];targetQ.copy(q);q.copy(value.q).slerp(targetQ,weight);p.lerpVectors(value.p,p,weight);s.lerpVectors(value.s,s,weight);bone.matrix.compose(p,q,s);bone.matrixWorldNeedsUpdate=true;}
  c.visualPivot.position.lerpVectors(active.pivotP,c.visualPivot.position,weight);q.copy(c.visualPivot.quaternion);c.visualPivot.quaternion.copy(active.pivotQ).slerp(q,weight);c.scaled.position.lerpVectors(active.scaledP,c.scaled.position,weight);c.object.updateMatrixWorld(true);
  if(rawAge>0){c.groundPose();c.visualPivot.position.y+=clearance*(1-weight);c.object.updateMatrixWorld(true);}
 }
 function applyProne(rawAge,c,profile){
  const weight=THREE.MathUtils.smoothstep(rawAge,0,.45),strength=profile?.known?(proneStrength[profile.cause]||.04):.04;
  for(const[name,bone]of entries){const value=active.bones[name];q.copy(value.q);const angle=-(name==='head'?strength:name==='neck'?strength*.3:name==='upperarm_l'||name==='upperarm_r'?strength*.5:name==='forearm_l'||name==='forearm_r'?strength*.7:0);if(angle)q.multiply(delta.setFromEuler(euler.set(angle*weight,0,0)));bone.matrix.compose(value.p,q,value.s);bone.matrixWorldNeedsUpdate=true;}
  c.visualPivot.position.copy(active.pivotP);c.visualPivot.quaternion.copy(active.pivotQ);c.scaled.position.copy(active.scaledP);c.object.updateMatrixWorld(true);
  if(rawAge>0){c.groundPose();c.visualPivot.position.y+=clearance*(1-weight);c.object.updateMatrixWorld(true);}
 }
 function save(){
  if(!active)return null;
  return {version:2,origin:active.origin,clearance,vehicleBound,vehicleReleaseAt,lastRawAge,bones:Object.fromEntries(Object.entries(active.bones).map(([name,value])=>[name,[...value.p.toArray(),...value.q.toArray(),...value.s.toArray()]])),pivotP:active.pivotP.toArray(),pivotQ:active.pivotQ.toArray(),scaledP:active.scaledP.toArray()};
 }
 function prepare(data,dead){
  if(data==null)return null;const c=getContext(),names=Object.keys(c.bones),vector=(a,n)=>Array.isArray(a)&&a.length===n&&a.every(Number.isFinite),quat=a=>vector(a,4)&&Math.abs(a.reduce((r,x)=>r+x*x,0)-1)<1e-5;
  // v1 and old vehicle saves predate origin/seat-release metadata. Normalize a
  // validated copy, never mutate the payload before the actor's atomic restore.
  const legacy=data.version===1,origin=data.origin===undefined?'vehicle':data.origin;
  const validBone=name=>{const a=data.bones[name],r=c.rest[name],pronePelvis=origin==='prone'&&name==='pelvis';return vector(a,10)&&quat(a.slice(3,7))&&Math.abs(a[0]-r.p.x)<=1e-5&&Math.abs(a[1]-(pronePelvis?.86-r.p.z:r.p.y))<=1e-5&&Math.abs(a[2]-(pronePelvis?r.p.y-1.46:r.p.z))<=1e-5&&a[7]>0&&a[8]>0&&a[9]>0&&Math.abs(a[7]-r.s.x)<=1e-5&&Math.abs(a[8]-r.s.y)<=1e-5&&Math.abs(a[9]-r.s.z)<=1e-5;};
  const bounded=(a,n,limit)=>vector(a,n)&&a.every(x=>Math.abs(x)<=limit),optionalClock=value=>value===undefined||value===null||Number.isFinite(value)&&value>=0;
  if(!dead||typeof data!=='object'||Array.isArray(data)||!legacy&&data.version!==2||(origin!=='vehicle'&&origin!=='prone')||!Number.isFinite(data.clearance)||data.clearance<0||data.clearance>c.targetHeight*4||!legacy&&(typeof data.vehicleBound!=='boolean'||!optionalClock(data.vehicleReleaseAt)||!optionalClock(data.lastRawAge))||!bounded(data.pivotP,3,c.targetHeight*(legacy?4:16))||!bounded(data.scaledP,3,c.sourceHeight)||!quat(data.pivotQ)||!data.bones||typeof data.bones!=='object'||Array.isArray(data.bones)||Object.keys(data.bones).length!==names.length||names.some(name=>!validBone(name)))throw Error('Invalid death entry pose');
  return legacy?{...data,version:2,origin,vehicleBound:false,vehicleReleaseAt:null,lastRawAge:0}:data.origin===undefined?{...data,origin}:data;
 }
 function restore(data){
  eligible=false;active=null;vehicleBound=false;vehicleReleaseAt=null;lastRawAge=0;if(!data)return;clearance=data.clearance;buffer??=make();buffer.origin=data.origin;
  for(const[name,value]of Object.entries(data.bones)){const target=buffer.bones[name];target.p.fromArray(value);target.q.fromArray(value,3);target.s.fromArray(value,7);}
  buffer.pivotP.fromArray(data.pivotP);buffer.pivotQ.fromArray(data.pivotQ);buffer.scaledP.fromArray(data.scaledP);active=buffer;vehicleBound=data.vehicleBound;vehicleReleaseAt=data.vehicleReleaseAt??null;lastRawAge=data.lastRawAge??0;
 }
 function render(presented,c,profile,renderer,seated=false){
  lastRawAge=presented.rawAge;
  if(presented.kind==='dead'&&seated){applyCurrentVehicle(presented.rawAge,c,presented.side||1);return;}
  if(presented.kind==='dead'&&active?.origin==='vehicle'&&vehicleBound){vehicleBound=false;vehicleReleaseAt=presented.rawAge;}
  if(presented.kind==='dead'&&active?.origin==='vehicle'&&vehicleReleaseAt!==null){renderer.reaction(presented,c,profile);applyVehicleRelease(presented.rawAge,c,presented.side||1);return;}
  if(presented.kind==='dead'&&active?.origin==='prone'){applyProne(presented.rawAge,c,profile);return;}
  if(presented.kind!=='dead'||!active||presented.rawAge>=duration){renderer.reaction(presented,c,profile);if(presented.kind==='dead')apply(presented.rawAge,c);return;}
  ungroundedContext??={...c,groundPose(){}};renderer.reaction(presented,ungroundedContext,profile);apply(presented.rawAge,c);
 }
 return {capture,begin,render,save,prepare,restore,reset(){eligible=false;active=null;vehicleBound=false;vehicleReleaseAt=null;lastRawAge=0;}};
}
