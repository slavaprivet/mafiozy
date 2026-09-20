// Visual-only cash hand-off. The host owns robbery state, interaction and money.

const LEFT_HAND_NAMES=Object.freeze(['socket_hand_l','hand_l','left_hand','l_hand','LeftHand','Hand_L','mixamorigLeftHand','Bip001_L_Hand','Bip01_L_Hand']);
const RIGHT_HAND_NAMES=Object.freeze(['socket_hand_r','hand_r','right_hand','r_hand','RightHand','Hand_R','mixamorigRightHand','Bip001_R_Hand','Bip01_R_Hand']);
const defaultPools=new WeakMap(),noRaycast=()=>{};
const isNode=value=>!!value&&typeof value.add==='function'&&typeof value.getWorldPosition==='function';
const normalName=value=>String(value||'').replace(/[^a-z0-9]/gi,'').toLowerCase();
const clamp01=value=>Math.max(0,Math.min(1,value));
const smooth=(a,b,value)=>{const t=clamp01((value-a)/(b-a));return t*t*(3-2*t);};

function suppliedNode(value){try{const node=typeof value==='function'?value():value;return isNode(node)?node:null;}catch{return null;}}
function findNode(root,names){
 if(!root)return null;for(const name of names){const exact=root.getObjectByName?.(name);if(isNode(exact))return exact;}
 const wanted=new Set(names.map(normalName));let result=null;root.traverse?.(node=>{if(!result&&isNode(node)&&wanted.has(normalName(node.name)))result=node;});return result;
}

export function isNpcCashOffering(value={}){
 const life=value?.life&&typeof value.life==='object'?value.life:value;
 return !!life&&typeof life==='object'&&life.cashOffering===true;
}

export function createNpcCashOfferVisualPool({THREE,color=0x8aa56b}={}){
 if(!THREE?.BoxGeometry||!THREE?.MeshBasicMaterial||!THREE?.Mesh)throw Error('NPC cash offer THREE dependency required');
 let geometry=null,material=null,disposed=false,created=0;const idle=[],active=new Set();
 function ensure(){if(disposed)throw Error('NPC cash offer pool disposed');geometry??=new THREE.BoxGeometry(.145,.014,.072);material??=new THREE.MeshBasicMaterial({color,toneMapped:false});}
 function acquire(){
  ensure();const mesh=idle.pop()||new THREE.Mesh(geometry,material);if(!mesh.userData.npcCashOfferVisual)created++;
  mesh.name='NPC_Cash_Offer';mesh.visible=false;mesh.castShadow=false;mesh.receiveShadow=false;mesh.frustumCulled=true;mesh.raycast=noRaycast;
  mesh.userData={...mesh.userData,npcCashOfferVisual:true,npcPickIgnore:true,mercenaryPickIgnore:true,visualOnly:true};active.add(mesh);return mesh;
 }
 function release(mesh){if(!active.delete(mesh))return false;mesh.visible=false;mesh.removeFromParent();idle.push(mesh);return true;}
 function dispose(){if(disposed)return;disposed=true;for(const mesh of [...active])release(mesh);idle.length=0;geometry?.dispose();material?.dispose();geometry=material=null;}
 return {acquire,release,dispose,stats:()=>({disposed,created,active:active.size,idle:idle.length,geometry:!!geometry,material:!!material})};
}

function sharedPool(THREE){
 let record=defaultPools.get(THREE);if(!record){record={pool:createNpcCashOfferVisualPool({THREE}),owners:0};defaultPools.set(THREE,record);}record.owners++;
 let released=false;return {pool:record.pool,release(){if(released)return;released=true;if(--record.owners===0){record.pool.dispose();defaultPools.delete(THREE);}}};
}

export function createNpcCashOfferVisual({THREE,walker=null,root=null,anchors={},pool=null,height=null}={}){
 if(!THREE?.Vector3||!THREE?.Quaternion)throw Error('NPC cash offer THREE dependency required');
 let context=null;try{context=walker?.artistContext?.()||null;}catch{/* Alternate rigs can inject root and anchors. */}
 const bones=context?.bones||{},rigRoot=root||context?.object||walker?.object||null,searchRoot=context?.scene||rigRoot;
 if(!isNode(rigRoot)&&!isNode(searchRoot))throw Error('NPC cash offer rig root required');
 // Anchor lookup happens once. update() never traverses the actor or world.
 const left=suppliedNode(anchors.leftHand)||suppliedNode(anchors.cash)||LEFT_HAND_NAMES.map(name=>bones[name]).find(isNode)||findNode(searchRoot,LEFT_HAND_NAMES);
 const right=suppliedNode(anchors.rightHand)||RIGHT_HAND_NAMES.map(name=>bones[name]).find(isNode)||findNode(searchRoot,RIGHT_HAND_NAMES);
 const parent=isNode(rigRoot)?rigRoot:(left?.parent||right?.parent||searchRoot);if(!isNode(parent))throw Error('NPC cash offer visual parent required');
 const shared=pool?null:sharedPool(THREE),meshPool=pool||shared.pool;if(typeof meshPool.acquire!=='function'||typeof meshPool.release!=='function')throw Error('NPC cash offer pool acquire/release required');
 const worldPoint=new THREE.Vector3(),actorPosition=new THREE.Vector3(),forward=new THREE.Vector3(),side=new THREE.Vector3(),parentScale=new THREE.Vector3();
 const pocket=new THREE.Vector3(),offered=new THREE.Vector3(),returnTarget=new THREE.Vector3(),handTarget=new THREE.Vector3(),currentHand=new THREE.Vector3(),raisedTarget=new THREE.Vector3(),currentRaised=new THREE.Vector3();
 const actorQ=new THREE.Quaternion(),parentQ=new THREE.Quaternion(),inverseParentQ=new THREE.Quaternion(),handQ=new THREE.Quaternion(),raisedQ=new THREE.Quaternion(),bundleQ=new THREE.Quaternion(),bundleTilt=new THREE.Quaternion(),bundleEuler=new THREE.Euler();
 // A supplied right-hand socket still owns the prop even when an alternate rig
 // cannot expose enough arm bones for IK. Left-hand fallback is visual-only.
 const bundleHand=right||left,offerSide=right?'r':'l',offerBone=bones['hand_'+offerSide],raisedHand=offerSide==='r'?left:right,raisedSide=offerSide==='r'?'l':'r',raisedBone=bones['hand_'+raisedSide];
 const poseApi=!!(context?.offset&&typeof context.rotateAdd==='function'&&typeof context.reachPalm==='function'),poseReady=!!(poseApi&&bundleHand&&offerBone),raisedPoseReady=!!(poseApi&&raisedHand&&raisedBone);
 const rigUnits=(Number.isFinite(context?.sourceHeight)&&context.sourceHeight>0?context.sourceHeight:5.12)/5.12,actorHeight=Number.isFinite(height)?height:Number.isFinite(walker?.height)?walker.height:Number.isFinite(context?.targetHeight)?context.targetHeight:1.9;
 let mesh=null,disposed=false,active=false,phase='idle',localAge=0,stowAge=0,lastExtend=0,poseBlend=0,updates=0,poseApplications=0;

 function hide(){if(!mesh)return false;const old=mesh;mesh=null;return meshPool.release(old);}
 function offerAge(snapshot,life,dt){
  const started=Number(life.cashOfferStartedAt),sourceNow=Number(snapshot.sourceNowMs);
  if(Number.isFinite(started)&&started>=0&&Number.isFinite(sourceNow))return Math.max(0,(sourceNow-started)/1000);
  const time=Number(snapshot.time??life.time);if(Number.isFinite(started)&&started>=0&&Number.isFinite(time))return Math.max(0,time-started/1000);
  localAge+=dt;return localAge;
 }
 function advance(wantsOffer,dt,timed,snapshot,life){
  if(wantsOffer){if(!active){active=true;localAge=0;stowAge=0;}const age=offerAge(snapshot,life,dt);phase=age<.34?'draw':age<1.02?'extend':'offer';lastExtend=phase==='draw'?smooth(.12,.34,age)*.08:phase==='extend'?smooth(.34,1.02,age):1;poseBlend+=(1-poseBlend)*(1-Math.exp(-dt*10));return true;}
  if(!timed){active=false;phase='idle';localAge=stowAge=lastExtend=poseBlend=0;return false;}
  if(active){active=false;phase='return';stowAge=0;}stowAge+=dt;
  if(phase==='return'&&stowAge<.36){poseBlend=1;return true;}
  phase='idle';localAge=stowAge=lastExtend=poseBlend=0;return false;
 }
 function applyPose(){
  if(!poseReady||phase==='idle')return false;
  const returning=phase==='return',returnWeight=returning?smooth(0,.34,stowAge):0,extend=lastExtend,weight=poseBlend,sign=offerSide==='r'?1:-1;
  context.rotateAdd('chest',.045*extend*weight,-sign*.055*extend*weight,sign*.012*extend*weight);context.rotateAdd('head',.018*extend*weight,sign*.035*extend*weight,0);context.object.updateMatrixWorld?.(true);
  // Keep the free hand visibly surrendered while only the cash hand lowers.
  // A tiny breath/tremor avoids a rigid mannequin silhouette without adding a
  // second state machine or allocating objects in update().
  if(raisedPoseReady){
   const age=returning?localAge+stowAge:localAge,breathe=Math.sin(age*2.15)*.022,tremor=Math.sin(age*7.3)*.010;
   raisedTarget.set(-sign*.78,4.06+breathe,.50+tremor*sign).multiplyScalar(rigUnits);context.offset.localToWorld(raisedTarget);
   raisedHand.updateWorldMatrix?.(true,false);raisedHand.getWorldPosition(currentRaised);raisedBone.getWorldQuaternion(raisedQ);currentRaised.lerp(raisedTarget,weight);context.reachPalm(raisedSide,currentRaised,raisedQ);context.object.updateMatrixWorld?.(true);
  }
  pocket.set(sign*.42,2.78,.36).multiplyScalar(rigUnits);offered.set(sign*.50,3.30,.96).multiplyScalar(rigUnits);
  if(returning){returnTarget.set(sign*.77,4.13,.49).multiplyScalar(rigUnits);handTarget.lerpVectors(offered,returnTarget,returnWeight);}else handTarget.lerpVectors(pocket,offered,extend);context.offset.localToWorld(handTarget);
  bundleHand.updateWorldMatrix?.(true,false);bundleHand.getWorldPosition(currentHand);offerBone.getWorldQuaternion(handQ);currentHand.lerp(handTarget,weight);context.reachPalm(offerSide,currentHand,handQ);
  context.object.updateMatrixWorld?.(true);poseApplications++;return true;
 }
 function place(){
  parent.updateWorldMatrix?.(true,false);rigRoot?.updateWorldMatrix?.(true,false);const orientationRoot=isNode(rigRoot)?rigRoot:parent;orientationRoot.getWorldPosition(actorPosition);orientationRoot.getWorldQuaternion(actorQ);forward.set(0,0,1).applyQuaternion(actorQ);side.set(1,0,0).applyQuaternion(actorQ);
  if(bundleHand){bundleHand.updateWorldMatrix?.(true,false);bundleHand.getWorldPosition(worldPoint);worldPoint.addScaledVector(forward,.032).addScaledVector(side,offerSide==='r'?-.018:.018);}else worldPoint.copy(actorPosition).addScaledVector(forward,.72*actorHeight/1.9).addScaledVector(side,.12).setY(actorPosition.y+actorHeight*.57);
  parent.worldToLocal(worldPoint);mesh.position.copy(worldPoint);parent.getWorldQuaternion(parentQ);inverseParentQ.copy(parentQ).invert();bundleTilt.setFromEuler(bundleEuler.set(-.08,0,offerSide==='r'?-.10:.10));bundleQ.copy(inverseParentQ).multiply(actorQ).multiply(bundleTilt);mesh.quaternion.copy(bundleQ);
  parent.getWorldScale(parentScale);mesh.scale.set(1/Math.max(.001,Math.abs(parentScale.x)),1/Math.max(.001,Math.abs(parentScale.y)),1/Math.max(.001,Math.abs(parentScale.z)));mesh.updateMatrix?.();mesh.visible=true;updates++;
 }
 function update(dtOrSnapshot={},maybeSnapshot={}){
  if(disposed)return false;const timed=typeof dtOrSnapshot==='number',dt=timed?Math.min(.1,Math.max(0,Number.isFinite(dtOrSnapshot)?dtOrSnapshot:0)):0,snapshot=timed?(maybeSnapshot||{}):(dtOrSnapshot||{}),life=snapshot?.life&&typeof snapshot.life==='object'?snapshot.life:snapshot;
  if(snapshot?.visible===false||life?.visible===false||snapshot?.cashOfferHidden===true){active=false;phase='idle';localAge=stowAge=lastExtend=poseBlend=0;hide();return false;}
  const showing=advance(isNpcCashOffering(life)&&snapshot?.cashOfferBlocked!==true&&life?.cashOfferBlocked!==true,dt,timed,snapshot,life);if(!showing){hide();return false;}
  if(phase==='return'){hide();applyPose();return true;}
  if(!mesh){mesh=meshPool.acquire();parent.add(mesh);}applyPose();place();return true;
 }
 function dispose(){if(disposed)return;hide();disposed=true;shared?.release();}
 return {update,apply:update,hide,dispose,get object(){return mesh;},get visible(){return !!mesh?.visible;},get phase(){return phase;},diagnostics:()=>({disposed,visible:!!mesh?.visible,phase,poseReady,raisedPoseReady,offerSide,poseApplications,updates,pool:meshPool.stats?.()||null})};
}
