import {findClearWeaponMount,weaponHeadClearance} from './hero_weapon_clearance.mjs';
// Presentation only: the host owns cover admission, body position and firing.
// gunPosition is the desired WORLD mount origin, not a muzzle or hand target.
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const restHands=new WeakMap();
const transitions=new WeakMap();
const transitionBones=['chest','neck','head','clavicle_l','clavicle_r'];
const finitePoint=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));

function poseSnapshot(THREE,c,weapon){
  return {yaw:c.visualPivot.rotation.y,origin:weapon?.getWorldPosition(new THREE.Vector3()),weaponQ:weapon?.getWorldQuaternion(new THREE.Quaternion()),
    bones:Object.fromEntries(transitionBones.filter(n=>c.bones[n]).map(n=>{const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();c.bones[n].matrix.decompose(p,q,s);return [n,q];}))};
}

function modeTransition(THREE,c,weapon,sample){
  // Omitted dt keeps the stateless API useful for isolated pose samples. The
  // host advances once per frame; its post-combat dt=0 pass reuses that time.
  if(!Number.isFinite(sample.dt))return null;
  let state=transitions.get(c.object);
  if(!state||state.attachmentId!==sample.attachmentId){
    const initial=poseSnapshot(THREE,c,weapon);
    state={attachmentId:sample.attachmentId,mode:sample.mode,elapsed:0,from:initial,last:initial,previousOrigin:initial.origin?.clone(),frameDt:sample.dt};transitions.set(c.object,state);
  }else if(state.mode!==sample.mode){state.mode=sample.mode;state.elapsed=0;state.from=state.last;state.previousOrigin=state.last.origin?.clone();state.frameDt=sample.dt;}
  else if(sample.dt>0){state.previousOrigin=state.last.origin?.clone();state.frameDt=sample.dt;}
  state.elapsed=Math.min(.16,state.elapsed+clamp(sample.dt,0,.1));
  const t=state.elapsed/.16;state.weight=t*t*(3-2*t);
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

/** Call after hero.update. Never translates the root/pelvis or changes leg
 * joints. Concealed visual yaw aligns with the host's outward body heading.
 * {applied, requestedReachable, reachCorrection, gunPosition} reports the actual
 * mount so the host can reject blind fire when a ledge is beyond arm reach.
 * Pass the mounted weapon Object3D; omission resolves socket_weapon's child.
 * Optional dt + attachmentId animate mode changes over .16 seconds and expose
 * transitionReady. Advance dt once per frame; repeat after combat with dt=0.
 */
export function applyCoverPose(THREE,c,sample){
  if(!THREE||!c?.bones||!c.reachPalm||!['hidden','aimed','blind','blocked'].includes(sample?.mode))return {applied:false};
  const blend=clamp(Number.isFinite(sample.blend)?sample.blend:1,0,1);
  const weapon=sample.weapon?.isObject3D?sample.weapon:c.bones.socket_weapon.children.find(n=>!n.isBone);
  const transition=modeTransition(THREE,c,weapon,sample);
  const result={applied:true,requestedReachable:true,transitionReady:!transition||transition.elapsed>=.16,reachCorrection:0,gunPosition:weapon?.getWorldPosition(new THREE.Vector3())||null};
  // The normal aiming pose already includes recoil, reload and both grips.
  if(blend===0){if(transition)transition.last=poseSnapshot(THREE,c,weapon);return result;}
  const unit=c.targetHeight/1.9,side=sample.side===-1?-1:1,low=!!sample.low;
  if(sample.mode!=='aimed'){
    // The input aiming pose faces the crosshair; a concealed torso keeps its
    // back against the surface while the arms aim independently.
    c.visualPivot.rotation.y*=1-blend;
    c.object.updateMatrixWorld(true);
  }
  const baseOrigin=weapon?.getWorldPosition(new THREE.Vector3());
  const baseQ=weapon?.getWorldQuaternion(new THREE.Quaternion());
  if(sample.mode!=='aimed'){
    c.rotateAdd('chest',(low?.50:.055)*blend,side*.08*blend,0);
    if(low){c.rotateAdd('neck',-.18*blend);c.rotateAdd('head',-.15*blend);}
    c.rotateAdd('neck',.035*blend,-side*.06*blend,0);
    c.rotateAdd('head',.035*blend,0,0);
    if(sample.mode==='blind'&&low){
      // Lift the shoulder chain while ducking the oversized authored head.
      // This is an upper-body reach, so the hidden hips and planted feet stay.
      const duck=blend;
      c.rotateAdd('chest',-.30*duck);
      c.rotateAdd('neck',1.50*duck);
      c.rotateAdd('head',.25*duck);
      c.rotateAdd('clavicle_r',0,0,.80*duck);
      c.rotateAdd('clavicle_l',0,0,-.80*duck);
    }
  }
  c.object.updateMatrixWorld(true);
  if(!weapon){
    for(const s of ['l','r']){c.rotateAdd('upperarm_'+s,-.25*blend);c.rotateAdd('forearm_'+s,-.8*blend);}
    blendBody(THREE,c,transition);c.object.updateMatrixWorld(true);
    if(transition)transition.last=poseSnapshot(THREE,c,weapon);return result;
  }
  const rootQ=c.object.getWorldQuaternion(new THREE.Quaternion());
  const normal=new THREE.Vector3(sample.normal?.x||0,0,sample.normal?.z||0);
  if(normal.lengthSq()<1e-8)normal.set(0,0,1).applyQuaternion(rootQ).setY(0);
  normal.normalize();
  const right=new THREE.Vector3(normal.z,0,-normal.x);
  const yaw=Number.isFinite(sample.aimYaw)?sample.aimYaw:Math.atan2(normal.x,normal.z);
  const firing=['blind','aimed'].includes(sample.mode)&&finitePoint(sample.gunPosition);
  const pitch=firing?clamp(Number.isFinite(sample.aimPitch)?sample.aimPitch:0,-1.28,1.28):-.65;
  const weaponQ=new THREE.Quaternion().setFromEuler(new THREE.Euler(-pitch,firing?yaw:Math.atan2(normal.x,normal.z),0,'YXZ'));
  const origin=firing?new THREE.Vector3(sample.gunPosition.x,sample.gunPosition.y,sample.gunPosition.z)
    :c.worldPosition('upperarm_r').add(c.worldPosition('upperarm_l')).multiplyScalar(.5)
      .addScaledVector(normal,.27*unit).addScaledVector(right,.12*unit).add(new THREE.Vector3(0,-(low?.10:.16)*unit,0));
  origin.lerp(baseOrigin,1-blend);weaponQ.slerp(baseQ,1-blend);
  // Carry the weapon around the outside shoulder while the head ducks; a
  // straight interpolation would cut through the large authored head.
  if(firing&&low&&sample.mode==='blind')origin.addScaledVector(right,(Math.sin(Math.PI*blend)*.30+.18*blend)*unit);
  if(!firing&&!(weapon.twoHanded??weapon.userData?.twoHanded))origin.addScaledVector(right,Math.sin(Math.PI*blend)*.28*unit);
  if(sample.mode==='aimed'&&!firing){origin.copy(baseOrigin);weaponQ.copy(baseQ);}
  const desired=origin.clone(),scale=c.targetHeight/c.sourceHeight,data=weapon.userData||{};
  const long=Boolean(weapon.twoHanded??data.twoHanded),id=weapon.weaponId??weapon.id??data.weaponId;
  const support=data.supportGrip??({uzi:[0,-.01,.5],golden_uzi:[0,-.01,.5],tommy_gun:[0,-.1,.62],sawn_off:[0,.1,.42],rpg:[0,.09,.62]}[id])??[0,.1,.62];
  const rest=handRest(THREE,c),turn=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2);
  const palmQ=s=>weaponQ.clone().multiply(turn).multiply(rest[s]);
  const grip=point=>new THREE.Vector3(...point).multiplyScalar(scale).applyQuaternion(weaponQ).add(origin);
  const constraintsForPose=()=>[['r',[0,-.13,-.02]],...(long?[['l',support]]:[])].map(([s,point])=>{
    const shoulder=c.worldPosition('upperarm_'+s);
    const radius=shoulder.distanceTo(c.worldPosition('forearm_'+s))+c.worldPosition('forearm_'+s).distanceTo(c.worldPosition('hand_'+s))-.008*unit;
    const center=shoulder.sub(new THREE.Vector3(...point).multiplyScalar(scale).applyQuaternion(weaponQ))
      .add(c.rest['socket_hand_'+s].p.clone().multiplyScalar(scale).applyQuaternion(palmQ(s)));
    return {center,radius};
  });
  if(transition){
    // Animate toward a valid endpoint. Interpolating an unsafe requested mount
    // first makes the clearance search switch sides of the head near the end.
    const endpoint=findClearWeaponMount(THREE,c,weapon,{origin,quaternion:weaponQ,constraints:constraintsForPose(),preferredSide:side});
    origin.copy(endpoint.origin);
    const {from,weight}=transition;
    blendBody(THREE,c,transition);
    if(from.origin)origin.lerpVectors(from.origin,origin.clone(),weight);
    if(from.weaponQ)weaponQ.copy(from.weaponQ.clone().slerp(weaponQ,weight));
    c.object.updateMatrixWorld(true);
    if(transition.previousOrigin){
      const travel=origin.clone().sub(transition.previousOrigin),limit=4*transition.frameDt*unit;
      if(travel.length()>limit)origin.copy(transition.previousOrigin).add(travel.setLength(limit));
    }
  }
  const constraints=constraintsForPose();
  // Project the mount into both reach spheres. Limbs retain authored lengths.
  for(let i=0;i<24;i++)for(const {center,radius}of constraints){const d=origin.clone().sub(center);if(d.length()>radius)origin.copy(center).add(d.setLength(radius));}
  const safe=findClearWeaponMount(THREE,c,weapon,{origin,quaternion:weaponQ,constraints,preferredSide:side,previousOrigin:transition?.previousOrigin});origin.copy(safe.origin);
  result.selfClear=safe.clear;result.reachCorrection=origin.distanceTo(desired);
  result.requestedReachable=safe.clear&&(!firing||result.reachCorrection<.75*unit)&&constraints.every(({center,radius})=>origin.distanceTo(center)<=radius+.001);
  c.reachPalm('r',grip([0,-.13,-.02]),palmQ('r'));
  if(long)c.reachPalm('l',grip(support),palmQ('l'));
  else{
    // The free hand needs no planted world target; local folding avoids an
    // elbow-pole flip when a deep crouch carries the shoulder over its wrist.
    c.rotateAdd('upperarm_l',-.12*blend);
    c.rotateAdd('forearm_l',-.50*blend);
  }
  c.object.updateMatrixWorld(true);
  weapon.position.copy(weapon.parent.worldToLocal(origin.clone()));
  weapon.quaternion.copy(weapon.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(weaponQ));
  c.object.updateMatrixWorld(true);
  result.gunPosition=weapon.getWorldPosition(new THREE.Vector3());
  if(transition)transition.last=poseSnapshot(THREE,c,weapon);
  return result;
}
