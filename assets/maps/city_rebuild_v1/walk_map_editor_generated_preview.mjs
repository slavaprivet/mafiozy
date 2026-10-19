function finite(value){return typeof value==='number'&&Number.isFinite(value)}
function cloneTransform(value){return {positionM:[...value.positionM],yawDegrees:value.yawDegrees}}
function abortError(){const error=new Error('Generated preview was cancelled');error.name='AbortError';error.code='EDITOR_GENERATED_PREVIEW_CANCELLED';return error}

function normalizeProxy(proxy){
 if(!proxy||!finite(proxy.x)||!finite(proxy.z))return null;
 const radius=proxy.radius===undefined?0:proxy.radius,halfWidth=proxy.halfWidth===undefined?radius:proxy.halfWidth,halfDepth=proxy.halfDepth===undefined?radius:proxy.halfDepth;
 if(!finite(radius)||radius<0||!finite(halfWidth)||halfWidth<0||!finite(halfDepth)||halfDepth<0)return null;
 return {type:proxy.type==='rect'||proxy.halfWidth!==undefined||proxy.halfDepth!==undefined?'rect':'circle',x:proxy.x,z:proxy.z,radius,halfWidth,halfDepth};
}
function initialTransform(record,proxy,groundHeight){
 const x=finite(record?.x)?record.x:proxy.x,z=finite(record?.z)?record.z:proxy.z,y=finite(record?.y)?record.y:(groundHeight(x,z)||0);
 const yawDegrees=finite(record?.transform?.yawDegrees)?record.transform.yawDegrees:finite(record?.yawDegrees)?record.yawDegrees:finite(record?.yaw)?record.yaw*180/Math.PI:0;
 return {positionM:[x,y,z],yawDegrees};
}
function outlinePositions(proxy,segments){
 if(proxy.type==='rect')return new Float32Array([-proxy.halfWidth,0,-proxy.halfDepth,proxy.halfWidth,0,-proxy.halfDepth,proxy.halfWidth,0,proxy.halfDepth,-proxy.halfWidth,0,proxy.halfDepth]);
 const radius=Math.max(.12,proxy.radius),values=new Float32Array(segments*3);for(let index=0;index<segments;index++){const angle=index/segments*Math.PI*2;values[index*3]=Math.cos(angle)*radius;values[index*3+2]=Math.sin(angle)*radius}return values;
}

/**
 * Editor-only staged transform for generated semantic objects. The controller
 * owns one constant-cost outline and never mutates or traverses the live root.
 */
export function createWalkMapEditorGeneratedPreview({THREE,scene,adapter,groundHeight=()=>0,color=0x35e5ff,heightOffsetM=.08,circleSegments=32}={}){
 if(!THREE?.Group||!THREE?.BufferGeometry||!THREE?.BufferAttribute||!THREE?.LineBasicMaterial||!THREE?.LineLoop||!scene?.add||!scene?.remove)throw new Error('Generated preview requires THREE outline primitives and a scene');
 if(typeof adapter?.transformCommand!=='function')throw new Error('Generated preview requires transformCommand capability');
 if(typeof groundHeight!=='function'||!finite(heightOffsetM)||!Number.isSafeInteger(circleSegments)||circleSegments<8||circleSegments>128)throw new Error('Invalid generated preview options');
 let state=null,disposed=false,revision=0;
 const active=()=>{if(disposed)throw new Error('Generated preview is disposed')};
 function recognizes({proxy,record}={}){return !!normalizeProxy(proxy??record?.proxy)}
 function canHandle({item,proxy,record,operation='move'}={}){if(disposed||!recognizes({proxy,record})||item?.locked)return false;return operation==='rotate'?item?.capabilities?.rotate===true:item?.capabilities?.move===true}
 function releaseOutline(current){if(!current)return;scene.remove(current.root);current.geometry.dispose?.();current.material.dispose?.()}
 function begin({key,item,proxy,record,operation='move'}={}){
  active();const descriptor=normalizeProxy(proxy??record?.proxy);if(!key||!descriptor||!canHandle({item,proxy:descriptor,record,operation}))return false;
  if(state?.key===key)return state.root;
  cancel('replace-preview');
  const geometry=new THREE.BufferGeometry(),material=new THREE.LineBasicMaterial({color,transparent:true,opacity:.95,depthTest:false,depthWrite:false,toneMapped:false}),root=new THREE.Group();
  geometry.setAttribute('position',new THREE.BufferAttribute(outlinePositions(descriptor,circleSegments),3));
  const outline=new THREE.LineLoop(geometry,material);outline.frustumCulled=false;outline.renderOrder=10010;root.add(outline);root.userData.editorTransient=true;root.userData.editorGeneratedPreviewKey=key;
  const transform=initialTransform(record,descriptor,groundHeight);root.position.set(transform.positionM[0],transform.positionM[1]+heightOffsetM,transform.positionM[2]);root.rotation.y=transform.yawDegrees*Math.PI/180;scene.add(root);
  state={key,item,descriptor,root,geometry,material,transform,validating:false,ticket:++revision};return root;
 }
 function update({positionM,yawDegrees}={}){
  active();if(!state||state.validating)return false;
  if(positionM!==undefined){if(!Array.isArray(positionM)||positionM.length!==3||!positionM.every(finite))throw new Error('Generated preview position must contain three finite values');state.transform.positionM=[...positionM];state.root.position.set(positionM[0],positionM[1]+heightOffsetM,positionM[2])}
  if(yawDegrees!==undefined){if(!finite(yawDegrees))throw new Error('Generated preview yaw must be finite');state.transform.yawDegrees=yawDegrees;state.root.rotation.y=yawDegrees*Math.PI/180}
  return true;
 }
 function rotate(degrees){active();if(!state||!finite(degrees)||state.validating)return false;return update({yawDegrees:state.transform.yawDegrees+degrees})}
 async function commit(){
  active();if(!state||state.validating)return false;const current=state,ticket=current.ticket;current.validating=true;
  try{
   let rejectCancellation;const cancellation=new Promise((resolve,reject)=>{rejectCancellation=reject});current.rejectCommit=rejectCancellation;
   const command=await Promise.race([Promise.resolve(adapter.transformCommand(current.key,cloneTransform(current.transform))),cancellation]);
   if(disposed||state!==current||revision!==ticket)throw abortError();
   releaseOutline(current);state=null;revision++;return Object.freeze({command,dependencies:Object.freeze([...(adapter.dependenciesFor?.(current.key)||[])])});
  }catch(error){if(state===current){releaseOutline(current);state=null;revision++;try{adapter.cancelPreview?.(current.key)}catch{}}throw error}
  finally{current.rejectCommit=null}
 }
 function cancel(reason='cancel'){
  if(!state)return false;const current=state;state=null;revision++;const reject=current.rejectCommit;current.rejectCommit=null;reject?.(abortError());try{adapter.cancelPreview?.(current.key)}catch{}releaseOutline(current);return true;
 }
 function dispose(){if(disposed)return;cancel('dispose');disposed=true}
 return Object.freeze({
  get active(){return !!state},get key(){return state?.key??null},get transform(){return state?Object.freeze(cloneTransform(state.transform)):null},
  recognizes,canHandle,begin,update,rotate,commit,cancel,dispose
 });
}
