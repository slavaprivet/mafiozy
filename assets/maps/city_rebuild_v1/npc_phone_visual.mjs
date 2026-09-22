// Lightweight visual-only phone for NPC call states. The host owns behaviour,
// animation and timing; this module only follows an existing rig anchor.

const RIGHT_HAND_NAMES=Object.freeze([
 'socket_hand_r','hand_r','right_hand','r_hand','RightHand','Hand_R',
 'mixamorigRightHand','Bip001_R_Hand','Bip01_R_Hand'
]);
const HEAD_NAMES=Object.freeze(['head','Head','head_joint','mixamorigHead','Bip001_Head','Bip01_Head']);
const defaultPools=new WeakMap();
const noRaycast=()=>{};
const normalName=value=>String(value||'').replace(/[^a-z0-9]/gi,'').toLowerCase();
const isNode=value=>!!value&&typeof value.add==='function'&&typeof value.getWorldPosition==='function';
const clamp01=value=>Math.max(0,Math.min(1,value));
const smooth=(a,b,value)=>{const t=clamp01((value-a)/(b-a));return t*t*(3-2*t);};

function findNode(root,names){
 if(!root)return null;
 for(const name of names){const exact=root.getObjectByName?.(name);if(isNode(exact))return exact;}
 const wanted=new Set(names.map(normalName));let found=null;
 root.traverse?.(node=>{if(!found&&isNode(node)&&wanted.has(normalName(node.name)))found=node;});
 return found;
}

function suppliedNode(value){
 try{const node=typeof value==='function'?value():value;return isNode(node)?node:null;}
 catch{return null;}
}

export function isNpcPhoneCalling(value={}){
 if(value===true)return true;
 const life=value?.life&&typeof value.life==='object'?value.life:value;
 if(!life||typeof life!=='object')return false;
 if(life.phoneCalling===true||life.callingPolice===true)return true;
 const state=[life.state,life.lifeState,life.gesture,life.activity?.kind].filter(v=>typeof v==='string').join(' ').toLowerCase();
 return /(?:^|[\s_-])(?:phone(?:calling)?|calling[_-]?police)(?:$|[\s_-])/.test(state)
  ||state==='phonecalling'||state==='callingpolice';
}

export function createNpcPhoneVisualPool({THREE,color=0x6f9fa6}={}){
 if(!THREE?.BoxGeometry||!THREE?.MeshBasicMaterial||!THREE?.Mesh)throw Error('NPC phone THREE dependency required');
 let geometry=null,material=null,disposed=false,created=0;
 const idle=[],active=new Set();
 function ensure(){
  if(disposed)throw Error('NPC phone pool disposed');
  geometry??=new THREE.BoxGeometry(.105,.215,.021);
  material??=new THREE.MeshBasicMaterial({color,toneMapped:false});
 }
 function acquire(){
  ensure();const mesh=idle.pop()||new THREE.Mesh(geometry,material);if(!mesh.userData.npcPhoneVisual)created++;
  mesh.name='NPC_Phone_Visual';mesh.visible=false;mesh.castShadow=false;mesh.receiveShadow=false;mesh.frustumCulled=true;mesh.raycast=noRaycast;
  mesh.userData={...mesh.userData,npcPhoneVisual:true,npcPickIgnore:true,mercenaryPickIgnore:true,visualOnly:true};active.add(mesh);return mesh;
 }
 function release(mesh){
  if(!active.delete(mesh))return false;
  mesh.visible=false;mesh.removeFromParent();idle.push(mesh);return true;
 }
 function dispose(){
  if(disposed)return;disposed=true;for(const mesh of [...active])release(mesh);idle.length=0;geometry?.dispose();material?.dispose();geometry=material=null;
 }
 return {acquire,release,dispose,stats:()=>({disposed,created,active:active.size,idle:idle.length,geometry:!!geometry,material:!!material})};
}

function sharedPool(THREE){
 let record=defaultPools.get(THREE);
 if(!record){record={pool:createNpcPhoneVisualPool({THREE}),owners:0};defaultPools.set(THREE,record);}
 record.owners++;
 let released=false;
 return {pool:record.pool,release(){if(released)return;released=true;if(--record.owners===0){record.pool.dispose();defaultPools.delete(THREE);}}};
}

export function createNpcPhoneVisual({THREE,walker=null,root=null,anchors={},pool=null,height=null}={}){
 if(!THREE?.Vector3||!THREE?.Quaternion||!THREE?.Euler)throw Error('NPC phone THREE dependency required');
 let context=null;
 try{context=walker?.artistContext?.()||null;}catch{/* An alternate rig can supply root/anchors directly. */}
 const bones=context?.bones||{},rigRoot=root||context?.object||walker?.object||null,searchRoot=context?.scene||rigRoot;
 if(!isNode(rigRoot)&&!isNode(searchRoot))throw Error('NPC phone rig root required');
 const hand=suppliedNode(anchors.rightHand)||suppliedNode(anchors.phone)||RIGHT_HAND_NAMES.map(name=>bones[name]).find(isNode)||findNode(searchRoot,RIGHT_HAND_NAMES);
 const head=suppliedNode(anchors.head)||HEAD_NAMES.map(name=>bones[name]).find(isNode)||findNode(searchRoot,HEAD_NAMES);
 const parent=isNode(rigRoot)?rigRoot:(hand?.parent||head?.parent||searchRoot);
 if(!isNode(parent))throw Error('NPC phone visual parent required');
 const shared=pool?null:sharedPool(THREE),meshPool=pool||shared.pool;
 if(typeof meshPool.acquire!=='function'||typeof meshPool.release!=='function')throw Error('NPC phone pool acquire/release required');
 const worldPoint=new THREE.Vector3(),actorPosition=new THREE.Vector3(),right=new THREE.Vector3(),forward=new THREE.Vector3(),worldUp=new THREE.Vector3(0,1,0),parentScale=new THREE.Vector3(),meshScale=new THREE.Vector3();
 const actorQ=new THREE.Quaternion(),parentQ=new THREE.Quaternion(),inverseParentQ=new THREE.Quaternion(),baseQ=new THREE.Quaternion().setFromEuler(new THREE.Euler(0,-Math.PI/2,0));
 const poseReady=!!(context?.offset&&typeof context.rotateAdd==='function'&&typeof context.reachPalm==='function'&&hand&&bones.hand_r);
 const currentRight=new THREE.Vector3(),currentLeft=new THREE.Vector3(),rightTarget=new THREE.Vector3(),leftTarget=new THREE.Vector3(),pocketTarget=new THREE.Vector3(),earTarget=new THREE.Vector3(),handQ=new THREE.Quaternion(),leftQ=new THREE.Quaternion();
 const rigUnits=(Number.isFinite(context?.sourceHeight)&&context.sourceHeight>0?context.sourceHeight:5.12)/5.12;
 const actorHeight=Number.isFinite(height)?height:Number.isFinite(walker?.height)?walker.height:Number.isFinite(context?.targetHeight)?context.targetHeight:1.9;
 let mesh=null,disposed=false,anchorKind=hand?'rightHand':head?'head':'root',updates=0,callActive=false,phase='idle',phaseTime=0,poseApplications=0;

 function hide(){if(!mesh)return false;const old=mesh;mesh=null;return meshPool.release(old);}
 function place(){
  parent.updateWorldMatrix?.(true,false);rigRoot?.updateWorldMatrix?.(true,false);
  const orientationRoot=isNode(rigRoot)?rigRoot:parent;orientationRoot.getWorldPosition(actorPosition);orientationRoot.getWorldQuaternion(actorQ);
  right.set(1,0,0).applyQuaternion(actorQ);forward.set(0,0,1).applyQuaternion(actorQ);
  if(hand){hand.updateWorldMatrix?.(true,false);hand.getWorldPosition(worldPoint);worldPoint.addScaledVector(right,.018).addScaledVector(worldUp,.028).addScaledVector(forward,.008);}
  else if(head){head.updateWorldMatrix?.(true,false);head.getWorldPosition(worldPoint);const size=actorHeight/1.9;worldPoint.addScaledVector(right,.105*size).addScaledVector(worldUp,.055*size).addScaledVector(forward,.012*size);}
  else{worldPoint.copy(actorPosition).addScaledVector(right,.16*actorHeight/1.9).addScaledVector(worldUp,actorHeight*.86).addScaledVector(forward,.03);}
  parent.worldToLocal(worldPoint);mesh.position.copy(worldPoint);
  parent.getWorldQuaternion(parentQ);inverseParentQ.copy(parentQ).invert();mesh.quaternion.copy(inverseParentQ).multiply(actorQ).multiply(baseQ);
  parent.getWorldScale(parentScale);meshScale.set(1/Math.max(.001,Math.abs(parentScale.x)),1/Math.max(.001,Math.abs(parentScale.y)),1/Math.max(.001,Math.abs(parentScale.z)));mesh.scale.copy(meshScale);
  mesh.updateMatrix?.();mesh.visible=true;updates++;
 }
 function advance(wantsCall,dt,timed){
  if(wantsCall){
   if(!callActive){callActive=true;phaseTime=0;}phaseTime+=dt;
   phase=phaseTime<.28?'draw':phaseTime<.78?'raise':'hold';return true;
  }
  if(!timed){callActive=false;phase='idle';phaseTime=0;return false;}
  if(callActive){callActive=false;phase='stow';phaseTime=0;}phaseTime+=dt;
  if(phase==='stow'&&phaseTime<.56)return true;
  phase='idle';phaseTime=0;return false;
 }
 function applyPose(time=0){
  if(!poseReady||phase==='idle')return false;
  const t=phaseTime,wave=Math.sin(time*3.6),entry=phase==='stow'?1-smooth(.38,.56,t):smooth(0,.2,t),raising=phase==='draw'?0:phase==='raise'?smooth(.28,.78,t):phase==='hold'?1:1-smooth(.04,.46,t);
  const leftWeight=entry*smooth(.48,.92,raising)*(phase==='stow'?1-smooth(.04,.32,t):1);
  context.rotateAdd('chest',.025*entry,-.045*entry,.012*wave*leftWeight);context.rotateAdd('head',-.018*entry,-.10*entry,.018*entry);context.object.updateMatrixWorld?.(true);
  pocketTarget.set(.54,1.68,.02).multiplyScalar(rigUnits);earTarget.set(.70,4.10,.13).multiplyScalar(rigUnits);rightTarget.lerpVectors(pocketTarget,earTarget,raising);context.offset.localToWorld(rightTarget);
  hand.updateWorldMatrix?.(true,false);hand.getWorldPosition(currentRight);bones.hand_r.getWorldQuaternion(handQ);currentRight.lerp(rightTarget,entry);context.reachPalm('r',currentRight,handQ);
  if(leftWeight>1e-4&&bones.socket_hand_l&&bones.hand_l){
   // The off hand alternates between shielding the mouth and a restrained
   // conversational gesture. Its amplitude stays small to avoid crowd noise.
   leftTarget.set(-.54+wave*.08,3.12+wave*.10,.48+Math.cos(time*2.7)*.05).multiplyScalar(rigUnits);context.offset.localToWorld(leftTarget);
   bones.socket_hand_l.updateWorldMatrix?.(true,false);bones.socket_hand_l.getWorldPosition(currentLeft);bones.hand_l.getWorldQuaternion(leftQ);currentLeft.lerp(leftTarget,leftWeight*.82);context.reachPalm('l',currentLeft,leftQ);
  }
  context.object.updateMatrixWorld?.(true);poseApplications++;return true;
 }
 function update(dtOrSnapshot={},maybeSnapshot={}){
  if(disposed)return false;
  const timed=typeof dtOrSnapshot==='number',dt=timed?Math.min(.1,Math.max(0,Number.isFinite(dtOrSnapshot)?dtOrSnapshot:0)):0,snapshot=timed?(maybeSnapshot||{}):(dtOrSnapshot||{}),life=snapshot?.life&&typeof snapshot.life==='object'?snapshot.life:snapshot;
  const visible=snapshot?.visible!==false&&snapshot?.life?.visible!==false;
  const blocked=snapshot?.phoneBlocked===true||life?.phoneBlocked===true;
  if(!visible){callActive=false;phase='idle';phaseTime=0;hide();return false;}
  const showing=advance(isNpcPhoneCalling(snapshot)&&!blocked,dt,timed);
  if(!showing){hide();return false;}
  if(!mesh){mesh=meshPool.acquire();parent.add(mesh);}
  const poseTime=Number.isFinite(snapshot?.time)?snapshot.time:Number.isFinite(life?.time)?life.time:phaseTime;
  applyPose(poseTime);
  place();return true;
 }
 function dispose(){if(disposed)return;hide();disposed=true;shared?.release();}
 return {update,apply:update,hide,dispose,get object(){return mesh;},get visible(){return !!mesh?.visible;},get anchorKind(){return anchorKind;},get phase(){return phase;},diagnostics:()=>({disposed,visible:!!mesh?.visible,anchor:anchorKind,phase,phaseTime,poseReady,poseApplications,updates,pool:meshPool.stats?.()||null})};
}
