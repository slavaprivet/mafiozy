import {findClearWeaponMount,weaponHeadClearance} from './hero_weapon_clearance.mjs';
// Presentation only: the host owns cover admission, body position and firing.
// gunPosition is the desired WORLD mount origin, not a muzzle or hand target.
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const restHands=new WeakMap();
const transitions=new WeakMap();
export const COVER_MODE_TRANSITION_DURATION=.32;
const transitionBones=['chest','neck','head','clavicle_l','clavicle_r'];
const finitePoint=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));
const concealmentBounds=new WeakMap(),concealmentStates=new WeakMap();
function headBounds(T,c){
  if(concealmentBounds.has(c.object))return concealmentBounds.get(c.object);
  c.object.updateMatrixWorld(true);const boxes={head:new T.Box3(),neck:new T.Box3()},inverse=Object.fromEntries(Object.keys(boxes).map(n=>[n,c.bones[n].matrixWorld.clone().invert()])),point=new T.Vector3();
  c.object.traverse(mesh=>{
    if(!mesh.isMesh||!mesh.geometry?.attributes?.position)return;
    const a=mesh.geometry.attributes;
    if(mesh.isSkinnedMesh&&a.skinWeight&&a.skinIndex){
      mesh.skeleton.update();for(let i=0;i<a.position.count;i++){
        const influence={head:0,neck:0};for(let j=0;j<4;j++){const n=mesh.skeleton.bones[a.skinIndex.getComponent(i,j)]?.name;if(n in influence)influence[n]+=a.skinWeight.getComponent(i,j);}
        if(!Object.values(influence).some(w=>w>.2))continue;
        point.fromBufferAttribute(a.position,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld);
        for(const n of ['head','neck'])if(influence[n]>.2)boxes[n].expandByPoint(point.clone().applyMatrix4(inverse[n]));
      }
    }else{
      let parent=mesh.parent;while(parent&&parent!==c.object&&!boxes[parent.name])parent=parent.parent;
      if(!boxes[parent?.name])return;
      for(let i=0;i<a.position.count;i++)boxes[parent.name].expandByPoint(point.fromBufferAttribute(a.position,i).applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse[parent.name]));
    }
  });
  const result=Object.entries(boxes).filter(([,box])=>!box.isEmpty()).map(([name,box])=>({name,points:[box.min.x,box.max.x].flatMap(x=>[box.min.y,box.max.y].flatMap(y=>[box.min.z,box.max.z].map(z=>new T.Vector3(x,y,z))))}));
  concealmentBounds.set(c.object,result);return result;
}
function headTop(T,c){let top=-Infinity;for(const {name,points}of headBounds(T,c))for(const p of points)top=Math.max(top,p.clone().applyMatrix4(c.bones[name].matrixWorld).y);return Number.isFinite(top)?top:Infinity;}
function reachCoverFoot(T,c,side,target,footQ){
  const upper='thigh_'+side,lower='shin_'+side,foot='foot_'+side,hip=c.worldPosition(upper),a=hip.distanceTo(c.worldPosition(lower)),b=c.worldPosition(lower).distanceTo(c.worldPosition(foot));
  const line=target.clone().sub(hip),distance=clamp(line.length(),Math.abs(a-b)+1e-6,a+b-1e-6);line.normalize();
  const q=c.visualPivot.getWorldQuaternion(new T.Quaternion()),forward=new T.Vector3(0,0,1).applyQuaternion(q),right=new T.Vector3(side==='r'?1:-1,0,0).applyQuaternion(q);
  const project=v=>v.addScaledVector(line,-v.dot(line)).normalize(),along=(a*a-b*b+distance*distance)/(2*distance),rise=Math.sqrt(Math.max(0,a*a-along*along));
  let pole=project(forward.clone()),knee=hip.clone().addScaledVector(line,along).addScaledVector(pole,rise);
  // A rearward stepping foot makes a fixed forward pole point below ground in
  // a deep squat. Open that knee outward/up instead of inverting the joint.
  if(knee.y<Math.min(hip.y,target.y)+.045*(c.targetHeight/1.9)){
    pole=project(right.multiplyScalar(.7).add(new T.Vector3(0,.9,0)).addScaledVector(forward,.15));
    knee=hip.clone().addScaledVector(line,along).addScaledVector(pole,rise);
  }
  const point=(name,end,to)=>{const origin=c.worldPosition(name),from=c.worldPosition(end).sub(origin).normalize(),direction=to.clone().sub(origin).normalize();c.worldRotation(name,new T.Quaternion().setFromUnitVectors(from,direction).multiply(c.bones[name].getWorldQuaternion(new T.Quaternion())));};
  point(upper,lower,knee);point(lower,foot,target);c.worldRotation(foot,footQ);
}
function adaptConcealedHeight(T,c,sample,blend){
  headBounds(T,c);
  if(!Number.isFinite(sample.coverHeight))return null;
  const target=c.object.position.y+sample.coverHeight-.065,unit=c.targetHeight/1.9,names=['pelvis','chest','neck','head'],base=Object.fromEntries(names.map(n=>[n,c.bones[n].matrix.clone()]));
  const feet=['l','r'].map(side=>({side,position:c.worldPosition('foot_'+side),q:c.bones['foot_'+side].getWorldQuaternion(new T.Quaternion())}));
  function apply(depth){
    for(const name of names){c.bones[name].matrix.copy(base[name]);c.bones[name].matrixWorldNeedsUpdate=true;}
    // Walking bob belongs to the feet/gait, not to the concealed silhouette.
    const bob=['hidden','blocked'].includes(sample.mode)?Math.max(0,c.scaled.position.y):0;
    c.bones.pelvis.matrix.elements[13]-=depth*(.16*unit+bob)/(c.targetHeight/c.sourceHeight);
    c.rotateAdd('chest',depth*(sample.mode==='blind'?.25:.915));c.rotateAdd('neck',depth*(sample.mode==='blind'?.18:.62));c.rotateAdd('head',depth*.04);c.object.updateMatrixWorld(true);
    return headTop(T,c);
  }
  let state=concealmentStates.get(c.object);
  if(!state||state.attachmentId!==sample.attachmentId){state={attachmentId:sample.attachmentId,depth:0};concealmentStates.set(c.object,state);}
  const key=[sample.mode,sample.coverHeight,c.visualPivot.position.y,c.scaled.position.y,c.offset.position.y,...names.flatMap(n=>base[n].elements)].map(v=>typeof v==='number'?Math.round(v*1e3):v).join(',');
  let minimum,hi;
  if(state.key===key){minimum=state.minimum==null?undefined:state.minimum+c.object.position.y;hi=state.target;}
  else{
    minimum=sample.mode==='aimed'?undefined:apply(1);let lo=0;hi=1;
    if(sample.mode==='aimed'||apply(0)<=target)hi=0;else if(minimum<=target)for(let i=0;i<6;i++){const mid=(lo+hi)/2;if(apply(mid)<=target)hi=mid;else lo=mid;}
    state.key=key;state.minimum=minimum==null?undefined:minimum-c.object.position.y;state.target=hi;
  }
  const desired=hi*blend;
  if(!Number.isFinite(sample.dt))state.depth=desired;else if(sample.dt>0)state.depth+=clamp(desired-state.depth,-sample.dt*2,sample.dt*2);
  apply(state.depth);
  if(state.depth>1e-8){
    const inverse=c.visualPivot.matrixWorld.clone().invert(),inverseQ=c.visualPivot.getWorldQuaternion(new T.Quaternion()).invert();
    const legNames=['thigh_l','shin_l','foot_l','thigh_r','shin_r','foot_r'];
    const legKey=[c.visualPivot.rotation.y,c.scaled.position.y,...c.bones.pelvis.matrix.elements,...feet.flatMap(({position,q})=>[...position.clone().applyMatrix4(inverse).toArray(),...inverseQ.clone().multiply(q).toArray()])].map(v=>Math.round(v*1e6)).join(',');
    if(state.legKey===legKey){for(const name of legNames){c.bones[name].matrix.copy(state.legs[name]);c.bones[name].matrixWorldNeedsUpdate=true;}}
    else{for(const {side,position,q}of feet)reachCoverFoot(T,c,side,position,q);state.legKey=legKey;state.legs=Object.fromEntries(legNames.map(name=>[name,c.bones[name].matrix.clone()]));}
  }
  c.object.updateMatrixWorld(true);
  return {minimumHeadTop:minimum,concealmentDepth:state.depth};
}
function concealmentResult(T,c,sample,result,adaptive){
  c.object.updateMatrixWorld(true);result.actualHeadTop=headTop(T,c);result.fullyConcealed=Number.isFinite(sample.coverHeight)&&result.actualHeadTop<=c.object.position.y+sample.coverHeight-.04;
  if(adaptive)Object.assign(result,adaptive);return result;
}


function poseSnapshot(THREE,c,weapon){
  return {yaw:c.visualPivot.rotation.y,origin:weapon?.getWorldPosition(new THREE.Vector3()),weaponQ:weapon?.getWorldQuaternion(new THREE.Quaternion()),
    bones:Object.fromEntries(transitionBones.filter(n=>c.bones[n]).map(n=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();c.bones[n].matrix.decompose(p,q,s);return [n,q];}))};
}

function modeTransition(THREE,c,weapon,sample){
  // Omitted dt keeps the stateless API useful for isolated pose samples. The
  // host advances once per frame; its post-combat dt=0 pass reuses that time.
  if(!Number.isFinite(sample.dt))return null;
  let state=transitions.get(c.object);
  const anchor=c.visualPivot.getWorldPosition(new THREE.Vector3());anchor.y+=c.scaled.position.y+c.bones.pelvis.matrix.elements[13]*(c.targetHeight/c.sourceHeight);
  if(state?.anchor){const shift=anchor.clone().sub(state.anchor);if(shift.lengthSq()>1e-20){for(const snapshot of new Set([state.from,state.last,state.previousPose]))snapshot?.origin?.add(shift);state.previousOrigin?.add(shift);}}
  if(!state||state.attachmentId!==sample.attachmentId){
    const initial=poseSnapshot(THREE,c,weapon);
    state={attachmentId:sample.attachmentId,mode:sample.mode,elapsed:0,from:initial,last:initial,previousOrigin:initial.origin?.clone(),previousPose:initial,frameDt:sample.dt};transitions.set(c.object,state);
  }else if(state.mode!==sample.mode){state.mode=sample.mode;state.elapsed=0;state.from=state.last;state.previousOrigin=state.last.origin?.clone();state.previousPose=state.last;state.frameDt=sample.dt;}
  else if(sample.dt>0){state.previousOrigin=state.last.origin?.clone();state.previousPose=state.last;state.frameDt=sample.dt;}
  state.anchor=anchor;
  state.duration=COVER_MODE_TRANSITION_DURATION;
  state.elapsed=Math.min(state.duration,state.elapsed+clamp(sample.dt,0,.1));
  const t=state.elapsed/state.duration;state.weight=t*t*(3-2*t);
  return state;
}

function blendBody(THREE,c,transition){
  if(!transition)return;
  const {from,weight}=transition,yaw=c.visualPivot.rotation.y;
  c.visualPivot.rotation.y=from.yaw+Math.atan2(Math.sin(yaw-from.yaw),Math.cos(yaw-from.yaw))*weight;
  for(const name of transitionBones){
    const bone=c.bones[name],saved=from.bones[name];if(!bone||!saved)continue;
    const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);
    bone.matrix.compose(p,saved.clone().slerp(q,weight),s);bone.matrixWorldNeedsUpdate=true;
  }
  c.object.updateMatrixWorld(true);
}

function handRest(THREE,c){
  if(restHands.has(c.object))return restHands.get(c.object);
  const result={};
  for(const side of ['l','r']){
    const chain=[];
    for(let node=c.bones['hand_'+side];node&&node!==c.object;node=node.parent)chain.unshift(node);
    const q=new THREE.Quaternion();
    for(const node of chain)if(node!==c.visualPivot)q.multiply(c.rest[node.name]?.q||node.quaternion);
    result[side]=q;
  }
  restHands.set(c.object,result);return result;
}

const mountCache=new WeakMap();
function clearMount(THREE,c,weapon,options,slot){
  // One bounded cache entry per actor. Exact pose keys invalidate on any
  // meaningful head/neck/chest motion, weapon switch, root motion or reach
  // change. Quantized cache hits are always rechecked against the exact pose.
  let cache=mountCache.get(c.object);if(!cache){cache={};mountCache.set(c.object,cache);}
  const key=[weapon.uuid,options.checkMuzzle,...options.origin.toArray(),...options.quaternion.toArray(),options.preferredSide,...(options.previousOrigin?.toArray()||[]),
    ...['head','neck','chest'].flatMap(n=>c.bones[n]?.matrixWorld.elements||[]),...(options.constraints||[]).flatMap(({center,radius,minRadius=0})=>[...center.toArray(),radius,minRadius])].map(value=>typeof value==='number'?Math.round(value*1e5):value).join(',');
  if(cache[slot]?.key===key){const cached=cache[slot].value;if((options.constraints||[]).every(({center,radius,minRadius=0})=>cached.origin.distanceTo(center)<=radius+.001&&cached.origin.distanceTo(center)>=minRadius-.001)&&weaponHeadClearance(THREE,c,weapon,{origin:cached.origin,quaternion:options.quaternion,padding:options.padding,checkMuzzle:options.checkMuzzle}).clear)return {...cached,clear:true,origin:cached.origin.clone()};}
  const value=findClearWeaponMount(THREE,c,weapon,options);cache[slot]={key,value:{...value,origin:value.origin.clone()}};return value;
}

/** Call after hero.update. The host retains the collision root. Adaptive
 * concealment lowers the visual pelvis and bends knees without changing bone
 * lengths or grounded foot targets. Concealed yaw follows the surface.
 * {applied, requestedReachable, reachCorrection, gunPosition} reports the actual
 * mount so the host can reject blind fire when a ledge is beyond arm reach.
 * Pass the mounted weapon Object3D; omission resolves socket_weapon's child.
 * Optional dt + attachmentId animate modes over .32 seconds.
 * Exposes transitionReady plus measured head height
 * and fullyConcealed. Advance dt once; repeat after combat with dt=0.
 */
export function applyCoverPose(THREE,c,sample){
  if(!THREE||!c?.bones||!c.reachPalm||!['hidden','aimed','blind','blocked'].includes(sample?.mode))return {applied:false};
  const blend=clamp(Number.isFinite(sample.blend)?sample.blend:1,0,1);
  const weapon=sample.weapon?.isObject3D?sample.weapon:c.bones.socket_weapon.children.find(n=>!n.isBone);
  // Start from the outward cover stance; aimed exit rotates the stance
  // through the timed transition, with only modest blind-fire upper-body twist.
  c.visualPivot.rotation.y=0;c.object.updateMatrixWorld(true);
  let transition=null;
  const result={applied:true,requestedReachable:true,transitionReady:!transition||transition.elapsed>=transition.duration,reachCorrection:0,gunPosition:weapon?.getWorldPosition(new THREE.Vector3())||null};
  // The normal aiming pose already includes recoil, reload and both grips.
  if(blend===0){concealmentStates.delete(c.object);transition=modeTransition(THREE,c,weapon,sample);result.transitionReady=!transition||transition.elapsed>=transition.duration;if(transition)transition.last=poseSnapshot(THREE,c,weapon);return result;}
  const unit=c.targetHeight/1.9,side=sample.side===-1?-1:1,low=!!sample.low;
  if(sample.mode!=='aimed'){
    // The input aiming pose faces the crosshair; a concealed torso keeps its
    // back against the surface while the arms aim independently.
    c.visualPivot.rotation.y*=1-blend;
    c.object.updateMatrixWorld(true);
  }
  const baseOrigin=weapon?.getWorldPosition(new THREE.Vector3());
  const baseQ=weapon?.getWorldQuaternion(new THREE.Quaternion());
  if(Number.isFinite(sample.coverHeight)&&['hidden','blocked'].includes(sample.mode)){
    const crouch=clamp((c.rest.pelvis.p.y-c.bones.pelvis.matrix.elements[13])*(c.targetHeight/c.sourceHeight)/(.24*unit),0,1);
    c.rotate('chest',crouch*.32);c.rotate('neck',-crouch*.14);c.rotate('head',-crouch*.18);
  }
  if(sample.mode!=='aimed'){
    const uprightHidden=low&&(sample.mode==='hidden'||sample.mode==='blocked');
    c.rotateAdd('chest',(low?(uprightHidden?0:.50):.055)*blend,side*.08*blend,0);
    if(low){c.rotateAdd('neck',(uprightHidden?0:-.18)*blend);c.rotateAdd('head',(uprightHidden?0:-.15)*blend);}
    c.rotateAdd('neck',.035*blend,-side*.06*blend,0);
    c.rotateAdd('head',.035*blend,0,0);
    if(sample.mode==='blind'&&low){
      // Lift the shoulder chain while ducking the oversized authored head.
      // This is an upper-body reach, so the hidden hips and planted feet stay.
      const duck=blend;
      c.rotateAdd('chest',.40*duck);
      c.rotateAdd('neck',.75*duck);
      c.rotateAdd('clavicle_r',0,0,.80*duck);
      c.rotateAdd('clavicle_l',0,0,-.80*duck);
    }
  }
  if(['aimed','blind'].includes(sample.mode)){
    const heading=Math.atan2(sample.normal?.x??0,sample.normal?.z??1),angle=Math.atan2(Math.sin((sample.aimYaw??heading)-heading),Math.cos((sample.aimYaw??heading)-heading));
    const edge=sample.carrySide<0?-1:1;
    if(sample.mode==='aimed'){
      // Exiting cover turns the whole stance toward the target. The mode
      // transition below carries hips and planted boot height continuously;
      // the neck must not compensate for a backwards-facing chest.
      c.visualPivot.rotation.y=(Math.abs(angle)>Math.PI-.05?-edge*Math.abs(angle):angle)*blend;
    }else{
      // Blind fire exposes the arms while the body stays against the wall.
      // Chest, neck and head share at most 76 degrees, never a stacked 180.
      const turn=low?0:(Math.abs(angle)>Math.PI/2?edge*1.05:clamp(angle,-1.05,1.05));
      c.rotateAdd('chest',0,turn*blend,0);c.rotateAdd('neck',0,turn*.15*blend,0);c.rotateAdd('head',0,turn*.10*blend,0);
    }
  }else if(sample.carrySide){
    c.rotateAdd('chest',0,-sample.carrySide*.10*blend,0);c.rotateAdd('neck',0,sample.carrySide*.06*blend,0);
  }
  c.object.updateMatrixWorld(true);
  const adaptive=adaptConcealedHeight(THREE,c,sample,blend);
  transition=modeTransition(THREE,c,weapon,sample);result.transitionReady=!transition||transition.elapsed>=transition.duration;
  if(!weapon){
    for(const s of ['l','r']){c.rotateAdd('upperarm_'+s,-.25*blend);c.rotateAdd('forearm_'+s,-.8*blend);}
    blendBody(THREE,c,transition);c.object.updateMatrixWorld(true);
    if(transition)transition.last=poseSnapshot(THREE,c,weapon);return concealmentResult(THREE,c,sample,result,adaptive);
  }
  const rootQ=c.object.getWorldQuaternion(new THREE.Quaternion());
  const normal=new THREE.Vector3(sample.normal?.x||0,0,sample.normal?.z||0);
  if(normal.lengthSq()<1e-8)normal.set(0,0,1).applyQuaternion(rootQ).setY(0);
  normal.normalize();
  const right=new THREE.Vector3(normal.z,0,-normal.x);
  const yaw=Number.isFinite(sample.aimYaw)?sample.aimYaw:Math.atan2(normal.x,normal.z);
  const firing=['blind','aimed'].includes(sample.mode)&&finitePoint(sample.gunPosition);
  const pitch=firing?clamp(Number.isFinite(sample.aimPitch)?sample.aimPitch:0,-1.28,1.28):((weapon.twoHanded??weapon.userData?.twoHanded)?(adaptive&&low?-.15:-.65):-1.35);
  const launcherCarry=!firing&&low&&(weapon.weaponId??weapon.userData?.weaponId)==='rpg';
  const acrossBody=!firing&&adaptive&&low&&(weapon.twoHanded??weapon.userData?.twoHanded)?1:0;
  const carryYaw=Math.atan2(normal.x,normal.z)-Math.PI/2*Math.max(launcherCarry?1:0,acrossBody);
  const weaponQ=new THREE.Quaternion().setFromEuler(new THREE.Euler(-pitch,firing?yaw:carryYaw,0,'YXZ'));
  const origin=firing?new THREE.Vector3(sample.gunPosition.x,sample.gunPosition.y,sample.gunPosition.z)
    :c.worldPosition('upperarm_r').add(c.worldPosition('upperarm_l')).multiplyScalar(.5)
      .addScaledVector(normal,.27*unit).addScaledVector(right,.12*unit).add(new THREE.Vector3(0,-(low?.10:.16)*unit,0));
  if(sample.mode==='aimed'){
    // Use the authored aimed carry beside the shoulder after the stance turns.
    // The host checks the resulting real muzzle against the cover geometry.
    const pivot=c.visualPivot.getWorldPosition(new THREE.Vector3()),held=baseOrigin.clone().sub(pivot);
    if(!(weapon.twoHanded??weapon.userData?.twoHanded)&&sample.carrySide<0)held.addScaledVector(right,-2*held.dot(right));
    origin.copy(held.applyAxisAngle(new THREE.Vector3(0,1,0),c.visualPivot.rotation.y).add(pivot));
    if(low&&Number.isFinite(sample.coverHeight))origin.y=Math.max(origin.y,c.object.position.y+sample.coverHeight+.12);
  }
  origin.lerp(baseOrigin,1-blend);weaponQ.slerp(baseQ,1-blend);
  // Carry the weapon around the outside shoulder while the head ducks; a
  // straight interpolation would cut through the large authored head.
  if(firing&&low&&sample.mode==='blind')origin.addScaledVector(right,(Math.sin(Math.PI*blend)*.30+.18*blend)*unit);
  if(!firing&&!(weapon.twoHanded??weapon.userData?.twoHanded))origin.addScaledVector(right,Math.sin(Math.PI*blend)*.28*unit);
  if(sample.mode==='aimed'&&!firing){origin.copy(baseOrigin);weaponQ.copy(baseQ);}
  const desired=origin.clone(),scale=c.targetHeight/c.sourceHeight,data=weapon.userData||{};
  const long=Boolean(weapon.twoHanded??data.twoHanded),id=weapon.weaponId??weapon.id??data.weaponId;
  const handSide=sample.carrySide||1;
  const shootingHand=!long&&handSide<0?'l':'r';result.shootingHand=shootingHand;
  const support=data.supportGrip??({uzi:[0,-.01,.5],golden_uzi:[0,-.01,.5],tommy_gun:[0,-.1,.62],sawn_off:[0,.1,.42],rpg:[0,.09,.62]}[id])??[0,.1,.62];
  const rest=handRest(THREE,c),turn=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2);
  const palmQ=s=>weaponQ.clone().multiply(turn).multiply(rest[s]);
  const grip=point=>new THREE.Vector3(...point).multiplyScalar(scale).applyQuaternion(weaponQ).add(origin);
  const constraintsForPose=()=>[[shootingHand,[0,-.13,-.02]],...(long?[['l',support]]:[])].map(([s,point])=>{
    const shoulder=c.worldPosition('upperarm_'+s);
    const upperLength=shoulder.distanceTo(c.worldPosition('forearm_'+s)),foreLength=c.worldPosition('forearm_'+s).distanceTo(c.worldPosition('hand_'+s)),radius=upperLength+foreLength-.008*unit,minRadius=Math.abs(upperLength-foreLength)+.008*unit;
    const center=shoulder.sub(new THREE.Vector3(...point).multiplyScalar(scale).applyQuaternion(weaponQ))
      .add(c.rest['socket_hand_'+s].p.clone().multiplyScalar(scale).applyQuaternion(palmQ(s)));
    return {center,radius,minRadius};
  });
  if(transition){
    // Interpolate the body and requested mount once. One clearance solve then
    // resolves that frame; bounded whole-pose backtracking below prevents a
    // safe solver endpoint from becoming a visible weapon teleport.
    const {from,weight}=transition;
    blendBody(THREE,c,transition);
    const bodyTurn=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),(sample.mode==='blind'?0:c.visualPivot.rotation.y-from.yaw)),pivot=c.visualPivot.getWorldPosition(new THREE.Vector3());
    if(from.origin)origin.lerpVectors(from.origin.clone().sub(pivot).applyQuaternion(bodyTurn).add(pivot),origin.clone(),weight);
    if(from.weaponQ)weaponQ.copy(bodyTurn.clone().multiply(from.weaponQ).slerp(weaponQ,weight));
    if(!firing&&long&&adaptive&&low){const arc=Math.sin(Math.PI*weight);origin.addScaledVector(right,arc*.35*unit);weaponQ.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),arc*.65));}
    if(!long&&!firing){const lower=Math.sin(Math.PI*weight);origin.y-=lower*.18*unit;weaponQ.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),lower*.85));}
    c.object.updateMatrixWorld(true);
  }
  let previousOrigin=transition?.previousOrigin,previousPose=transition?.previousPose;
  if(previousOrigin&&previousPose){
    const bodyTurn=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),(sample.mode==='blind'?0:c.visualPivot.rotation.y-previousPose.yaw)),pivot=c.visualPivot.getWorldPosition(new THREE.Vector3());
    previousOrigin=previousOrigin.clone().sub(pivot).applyQuaternion(bodyTurn).add(pivot);
    previousPose={...previousPose,yaw:c.visualPivot.rotation.y,origin:previousOrigin,weaponQ:bodyTurn.multiply(previousPose.weaponQ)};
  }
  const constraints=constraintsForPose();
  // Project the mount into both reach spheres. Limbs retain authored lengths.
  for(let i=0;i<24;i++)for(const {center,radius,minRadius}of constraints){const d=origin.clone().sub(center),length=d.length();if(length>radius||length<minRadius)origin.copy(center).add(d.setLength(clamp(length,minRadius,radius)));}
  const safe=clearMount(THREE,c,weapon,{origin,quaternion:weaponQ,constraints,preferredSide:side,previousOrigin,padding:.020,checkMuzzle:firing},'current');origin.copy(safe.origin);
  if(transition&&previousOrigin&&previousPose){
    const previous=previousPose,limit=6*transition.frameDt*unit;
    if(origin.distanceTo(previousOrigin)>limit+.000001){
      // A safe mount is not necessarily reachable in this animation frame.
      // Step the whole shoulder/head/weapon pose back together. Clamping only
      // the gun after IK makes its hand detach or forces it through the head.
      const goal=poseSnapshot(THREE,c,weapon),targetOrigin=origin.clone(),targetQ=weaponQ.clone();
      goal.origin=targetOrigin;goal.weaponQ=targetQ;
      let admitted=false;
      const stepWeight=Math.min(.5,limit/origin.distanceTo(previousOrigin));
      for(const weight of [1,stepWeight,stepWeight*.5,stepWeight*.25,0]){
        // The grounded stance finishes its timed turn independently of arm clearance.
        c.visualPivot.rotation.y=goal.yaw;
        for(const name of transitionBones){const bone=c.bones[name],from=previous.bones[name],to=goal.bones[name];if(!bone||!from||!to)continue;
          const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);bone.matrix.compose(p,from.clone().slerp(to,weight),s);bone.matrixWorldNeedsUpdate=true;}
        c.object.updateMatrixWorld(true);weaponQ.copy(previous.weaponQ).slerp(targetQ,weight);
        origin.copy(previousOrigin).lerp(targetOrigin,weight);
        if(origin.distanceTo(previousOrigin)>limit)origin.sub(previousOrigin).setLength(limit).add(previousOrigin);
        const currentConstraints=constraintsForPose();
        for(let i=0;i<32;i++)for(const {center,radius,minRadius}of currentConstraints){const d=origin.clone().sub(center),length=d.length();if(length>radius||length<minRadius)origin.copy(center).add(d.setLength(clamp(length,minRadius,radius)));}
        const admits=point=>point.distanceTo(previousOrigin)<=limit+.000001&&currentConstraints.every(({center,radius,minRadius})=>point.distanceTo(center)<=radius+.001&&point.distanceTo(center)>=minRadius-.001)&&weaponHeadClearance(THREE,c,weapon,{origin:point,quaternion:weaponQ,padding:.020,checkMuzzle:firing}).clear;
        if((!admits(origin)||weight===0)&&limit>0){
          // A straight segment may cross the head even when both endpoints
          // are safe. Try a fixed local ring around the previous mount, so a
          // returning pistol can pass below/around the cheek without jumping
          // to the other side of the clearance search's global solution.
          const candidates=[],up=new THREE.Vector3(0,1,0);
          for(const [a,b,d] of [[0,-1,0],[side,0,0],[-side,0,0],[0,1,0],[0,0,1],[0,0,-1],[side,-1,0],[-side,-1,0],[0,-1,1],[0,-1,-1]]){
            const delta=right.clone().multiplyScalar(a).addScaledVector(up,b).addScaledVector(normal,d).normalize().multiplyScalar(limit*.82),point=previousOrigin.clone().add(delta);
            for(let i=0;i<16;i++)for(const {center,radius,minRadius}of currentConstraints){const v=point.clone().sub(center),length=v.length();if(length>radius||length<minRadius)point.copy(center).add(v.setLength(clamp(length,minRadius,radius)));}
            candidates.push({point,distance:point.distanceToSquared(targetOrigin)});
          }
          candidates.sort((a,b)=>a.distance-b.distance);
          const best=candidates.find(candidate=>admits(candidate.point));if(best)origin.copy(best.point);
        }
        if(admits(origin)){constraints.splice(0,constraints.length,...currentConstraints);admitted=true;break;}
      }
      result.transitionReady=admitted&&transition.elapsed>=transition.duration&&weaponQ.angleTo(targetQ)<.025;
      // The previously accepted pose is the final bounded fallback. A host
      // posture/root change can invalidate it; suppress fire in that case.
      safe.clear=admitted;
    }
  }
  result.selfClear=safe.clear;result.reachCorrection=origin.distanceTo(desired);
  result.requestedReachable=safe.clear&&(!firing||result.reachCorrection<.75*unit)&&constraints.every(({center,radius,minRadius})=>origin.distanceTo(center)<=radius+.001&&origin.distanceTo(center)>=minRadius-.001);
  c.reachPalm(shootingHand,grip([0,-.13,-.02]),palmQ(shootingHand));
  if(long)c.reachPalm('l',grip(support),palmQ('l'));
  else{
    // The free hand needs no planted world target; local folding avoids an
    // elbow-pole flip when a deep crouch carries the shoulder over its wrist.
    const freeHand=shootingHand==='r'?'l':'r';
    c.rotateAdd('upperarm_'+freeHand,-.12*blend);
    c.rotateAdd('forearm_'+freeHand,-.50*blend);
  }
  c.object.updateMatrixWorld(true);
  weapon.position.copy(weapon.parent.worldToLocal(origin.clone()));
  weapon.quaternion.copy(weapon.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(weaponQ));
  c.object.updateMatrixWorld(true);
  result.gunPosition=weapon.getWorldPosition(new THREE.Vector3());
  if(transition)transition.last=poseSnapshot(THREE,c,weapon);
  return concealmentResult(THREE,c,sample,result,adaptive);
}
