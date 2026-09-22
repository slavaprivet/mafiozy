// Presentation-only inheritance of the last displayed vehicle/prone pose. Source
// death state and time remain authoritative; no transport trip is fabricated.
export function createNpcDeathEntry20(THREE,getContext){
 const duration=.28,p=new THREE.Vector3(),q=new THREE.Quaternion(),targetQ=new THREE.Quaternion(),s=new THREE.Vector3(),delta=new THREE.Quaternion(),euler=new THREE.Euler();
 const proneStrength={bullet:.04,melee:.06,super:.08,kick:.06,dropkick:.08,blast:.10};
 let entries=null,buffer=null,lastAt=-Infinity,eligible=false,active=null,clearance=0,ungroundedContext=null;
 function make(){
  const c=getContext();entries??=Object.entries(c.bones);
  return {bones:Object.fromEntries(entries.map(([name])=>[name,{p:new THREE.Vector3(),q:new THREE.Quaternion(),s:new THREE.Vector3()}])),pivotP:new THREE.Vector3(),pivotQ:new THREE.Quaternion(),scaledP:new THREE.Vector3()};
 }
 function capture(origin,at){
  eligible=origin==='vehicle'||origin==='prone';if(!eligible)return;const c=getContext();buffer??=make();buffer.origin=origin;
  for(const[name,bone]of entries){const value=buffer.bones[name];bone.matrix.decompose(value.p,value.q,value.s);}
  buffer.pivotP.copy(c.visualPivot.position);buffer.pivotQ.copy(c.visualPivot.quaternion);buffer.scaledP.copy(c.scaled.position);lastAt=at;
 }
 function begin(at){
  active=eligible&&at>=lastAt&&at-lastAt<=.25?buffer:null;eligible=false;
  if(active){const c=getContext(),y=c.visualPivot.position.y;c.groundPose();clearance=Math.max(0,y-c.visualPivot.position.y);c.visualPivot.position.y=y;c.object.updateMatrixWorld(true);
   // Bad remote root/seat offsets must not create a save that cannot restore.
   // This validation runs once at the event, never in the crowd pose loop.
   try{prepare(save(),true);}catch{active=null;}
  }
 }
 function apply(rawAge,c){
  if(!active)return;const weight=THREE.MathUtils.smoothstep(rawAge,0,duration);
  if(weight>=1){active=null;return;}
  for(const[name,bone]of entries){
   bone.matrix.decompose(p,q,s);const value=active.bones[name];targetQ.copy(q);q.copy(value.q).slerp(targetQ,weight);p.lerpVectors(value.p,p,weight);s.lerpVectors(value.s,s,weight);bone.matrix.compose(p,q,s);bone.matrixWorldNeedsUpdate=true;
  }
  c.visualPivot.position.lerpVectors(active.pivotP,c.visualPivot.position,weight);q.copy(c.visualPivot.quaternion);c.visualPivot.quaternion.copy(active.pivotQ).slerp(q,weight);c.scaled.position.lerpVectors(active.scaledP,c.scaled.position,weight);c.object.updateMatrixWorld(true);
  if(rawAge>0){c.groundPose();c.visualPivot.position.y+=clearance*(1-weight);c.object.updateMatrixWorld(true);}
 }
 function applyProne(rawAge,c,profile){
  const weight=THREE.MathUtils.smoothstep(rawAge,0,.45),strength=profile?.known?(proneStrength[profile.cause]||.04):.04;
  for(const[name,bone]of entries){
   const value=active.bones[name];q.copy(value.q);
   const angle=-(name==='head'?strength:name==='neck'?strength*.3:name==='upperarm_l'||name==='upperarm_r'?strength*.5:name==='forearm_l'||name==='forearm_r'?strength*.7:0);
   if(angle)q.multiply(delta.setFromEuler(euler.set(angle*weight,0,0)));bone.matrix.compose(value.p,q,value.s);bone.matrixWorldNeedsUpdate=true;
  }
  c.visualPivot.position.copy(active.pivotP);c.visualPivot.quaternion.copy(active.pivotQ);c.scaled.position.copy(active.scaledP);c.object.updateMatrixWorld(true);
  if(rawAge>0){c.groundPose();c.visualPivot.position.y+=clearance*(1-weight);c.object.updateMatrixWorld(true);}
 }
 function save(){
  if(!active)return null;
  return {version:1,origin:active.origin,clearance,bones:Object.fromEntries(Object.entries(active.bones).map(([name,value])=>[name,[...value.p.toArray(),...value.q.toArray(),...value.s.toArray()]])),pivotP:active.pivotP.toArray(),pivotQ:active.pivotQ.toArray(),scaledP:active.scaledP.toArray()};
 }
 function prepare(data,dead){
  if(data==null)return null;const c=getContext(),names=Object.keys(c.bones),vector=(a,n)=>Array.isArray(a)&&a.length===n&&a.every(Number.isFinite),quat=a=>vector(a,4)&&Math.abs(a.reduce((r,x)=>r+x*x,0)-1)<1e-5;
  const origin=data.origin===undefined?'vehicle':data.origin;
  // Vehicle P stays rest. Full authored prone moves only pelvis around the
  // hip y1.46, then lowers it .60. Both origins preserve actual rest scale.
  const validBone=name=>{const a=data.bones[name],r=c.rest[name],pronePelvis=origin==='prone'&&name==='pelvis';return vector(a,10)&&quat(a.slice(3,7))&&Math.abs(a[0]-r.p.x)<=1e-5&&Math.abs(a[1]-(pronePelvis?.86-r.p.z:r.p.y))<=1e-5&&Math.abs(a[2]-(pronePelvis?r.p.y-1.46:r.p.z))<=1e-5&&a[7]>0&&a[8]>0&&a[9]>0&&Math.abs(a[7]-r.s.x)<=1e-5&&Math.abs(a[8]-r.s.y)<=1e-5&&Math.abs(a[9]-r.s.z)<=1e-5;};
  const bounded=(a,n,limit)=>vector(a,n)&&a.every(x=>Math.abs(x)<=limit);
  if(!dead||typeof data!=='object'||Array.isArray(data)||data.version!==1||(origin!=='vehicle'&&origin!=='prone')||!Number.isFinite(data.clearance)||data.clearance<0||data.clearance>c.targetHeight*4||!bounded(data.pivotP,3,c.targetHeight*4)||!bounded(data.scaledP,3,c.sourceHeight)||!quat(data.pivotQ)||!data.bones||typeof data.bones!=='object'||Array.isArray(data.bones)||Object.keys(data.bones).length!==names.length||names.some(name=>!validBone(name)))throw Error('Invalid death entry pose');
  return data;
 }
 function restore(data){
  eligible=false;active=null;if(!data)return;clearance=data.clearance;buffer??=make();buffer.origin=data.origin===undefined?'vehicle':data.origin;
  for(const[name,value]of Object.entries(data.bones)){const target=buffer.bones[name];target.p.fromArray(value);target.q.fromArray(value,3);target.s.fromArray(value,7);}
  buffer.pivotP.fromArray(data.pivotP);buffer.pivotQ.fromArray(data.pivotQ);buffer.scaledP.fromArray(data.scaledP);active=buffer;
 }
 function render(presented,c,profile,renderer){
  if(presented.kind==='dead'&&active?.origin==='prone'){applyProne(presented.rawAge,c,profile);return;}
  if(presented.kind!=='dead'||!active||presented.rawAge>=duration){renderer.reaction(presented,c,profile);if(presented.kind==='dead')apply(presented.rawAge,c);return;}
  // Defer grounding until after interpolation, so only one skinned scan runs.
  // Once the blend ends the caller's settled-death memo context is untouched.
  ungroundedContext??={...c,groundPose(){}};renderer.reaction(presented,ungroundedContext,profile);apply(presented.rawAge,c);
 }
 return {capture,begin,render,save,prepare,restore,reset(){eligible=false;active=null;}};
}
