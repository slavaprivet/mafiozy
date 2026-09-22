// ISOLATED presentation helper. Not imported by gameplay. Metres and seconds.
// No actor/scene/source mutation; walls and footprint solids remain host-owned.
const point=p=>p&&[p.x,p.y,p.z].every(Number.isFinite),quat=q=>q&&[q.x,q.y,q.z,q.w].every(Number.isFinite);
const copy=p=>({x:p.x,y:p.y,z:p.z});
function normalize(q){const l=Math.hypot(q.x,q.y,q.z,q.w);if(l<1e-12)throw Error('Invalid part quaternion');return {x:q.x/l,y:q.y/l,z:q.z/l,w:q.w/l};}
function rotated(p,q){const ix=q.w*p.x+q.y*p.z-q.z*p.y,iy=q.w*p.y+q.z*p.x-q.x*p.z,iz=q.w*p.z+q.x*p.y-q.y*p.x,iw=-q.x*p.x-q.y*p.y-q.z*p.z;return {x:ix*q.w-iw*q.x-iy*q.z+iz*q.y,y:iy*q.w-iw*q.y-iz*q.x+ix*q.z,z:iz*q.w-iw*q.z-ix*q.y+iy*q.x};}
function multiply(a,b){return {x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w,w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z};}
export function createNpcBlastGround20({position,quaternion={x:0,y:0,z:0,w:1},velocity,angularVelocity={x:0,y:0,z:0},localBounds,eventAt,lifetime=8,gravity=9.81}={}){
 if(!point(position)||!point(velocity)||!point(angularVelocity)||!quat(quaternion)||!point(localBounds?.min)||!point(localBounds?.max)||!Number.isFinite(eventAt)||!Number.isFinite(lifetime)||lifetime<=0||lifetime>8||!Number.isFinite(gravity)||gravity<=0||['x','y','z'].some(k=>localBounds.min[k]>localBounds.max[k]))throw Error('Invalid ballistic part state');
 const corners=[];for(const x of [localBounds.min.x,localBounds.max.x])for(const y of [localBounds.min.y,localBounds.max.y])for(const z of [localBounds.min.z,localBounds.max.z])corners.push({x,y,z});
 const radius=Math.max(.001,...corners.map(p=>Math.hypot(p.x,p.y,p.z))),q=normalize(quaternion),p=copy(position);
 return {version:1,eventAt,lifetime,gravity,origin:p,initialQuaternion:q,velocity:copy(velocity),angularVelocity:copy(angularVelocity),corners,radius,elapsed:0,lastNow:eventAt,position:copy(p),quaternion:{...q},status:'flying',contact:null,queries:0,pendingSeconds:0};
}
function poseAt(s,t){const spin=s.angularVelocity,speed=Math.hypot(spin.x,spin.y,spin.z),a=speed*t*.5,k=speed>1e-12?Math.sin(a)/speed:0;return {position:{x:s.origin.x+s.velocity.x*t,y:s.origin.y+s.velocity.y*t-s.gravity*t*t*.5,z:s.origin.z+s.velocity.z*t},quaternion:multiply(s.initialQuaternion,{x:spin.x*k,y:spin.y*k,z:spin.z*k,w:Math.cos(a)})};}
export function stepNpcBlastGround20(state,{now,groundHeight,maxQueries=32}={}){
 if(state?.version!==1||!Number.isFinite(now)||now<state.lastNow||typeof groundHeight!=='function'||!Number.isInteger(maxQueries)||maxQueries<9||maxQueries>192)throw Error('Invalid bounded ground step');
 const s={...state,position:copy(state.position),quaternion:{...state.quaternion},contact:state.contact?{...state.contact}:null,lastNow:now,queries:0};
 const target=Math.max(0,now-s.eventAt);if(target>=s.lifetime){s.status='expired';s.pendingSeconds=0;return s;}
 if(s.status!=='flying'){s.pendingSeconds=0;return s;}
 const sample=pose=>{
  if(s.queries+9>maxQueries)return null;
  const offsets=s.corners.map(p=>rotated(p,pose.quaternion));let minY=Infinity,gap=Infinity;
  for(const p of offsets)minY=Math.min(minY,p.y);
  // The centre sample catches a slope/crest below the middle of a broad part.
  offsets.push({x:0,y:minY,z:0});let valid=true;
  for(const p of offsets){const y=groundHeight(pose.position.x+p.x,pose.position.z+p.z);s.queries++;if(!Number.isFinite(y)){valid=false;continue;}gap=Math.min(gap,pose.position.y+p.y-y);}
  return {gap,valid};
 };
 const previous=sample(s);if(!previous.valid||previous.gap<-.002){s.status='blocked';s.reason=previous.valid?'ground-above-safe-pose':'unknown-ground';s.pendingSeconds=0;return s;}
 let lowGap=previous.gap;
 while(s.elapsed<target-1e-9){
  if(s.contact){
   // Each continuation samples the retained safe pose again. No ground-query
   // results survive a host frame; new upper floors cannot teleport the part.
   const mid=(s.elapsed+s.contact.high)*.5,pose=poseAt(s,mid),probe=sample(pose);if(!probe)break;
   if(!probe.valid){s.status='blocked';s.reason='unknown-ground';break;}
   if(probe.gap<0)s.contact.high=mid;else{s.elapsed=mid;s.position=pose.position;s.quaternion=pose.quaternion;lowGap=probe.gap;}
   s.contact.iterations++;
   if(s.contact.high-s.elapsed<=1e-5||s.contact.iterations>=10){s.status='settled';s.contact=null;s.groundGap=lowGap;break;}
   continue;
  }
  const speed=Math.hypot(s.velocity.x,s.velocity.y-s.gravity*s.elapsed,s.velocity.z),spin=Math.hypot(s.angularVelocity.x,s.angularVelocity.y,s.angularVelocity.z);
  // A sampled heightfield cannot guarantee arbitrary infinitesimal features.
  // Bound each segment by time, corner travel and rotation; never skip pending
  // segments just because the renderer supplied one very large elapsed time.
  const distance=Math.max(.025,Math.min(.18,s.radius*.35)),dt=Math.min(target-s.elapsed,1/30,distance/Math.max(.001,speed+spin*s.radius+s.gravity/30),.08/Math.max(.001,spin));
  const next=s.elapsed+dt,pose=poseAt(s,next),probe=sample(pose);if(!probe)break;
  if(!probe.valid){s.status='blocked';s.reason='unknown-ground';break;}
  if(probe.gap<0){s.contact={high:next,iterations:0};continue;}
  s.elapsed=next;s.position=pose.position;s.quaternion=pose.quaternion;lowGap=probe.gap;
 }
 s.pendingSeconds=s.status==='flying'?Math.max(0,target-s.elapsed):0;return s;
}
