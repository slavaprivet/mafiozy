function finite(value){return typeof value==='number'&&Number.isFinite(value);}
function cloneVector(vector){return vector?.clone?.()??null;}
function clamp(value,min,max){return Math.min(max,Math.max(min,value));}

export function createWalkMapEditorCamera({THREE,camera,controls,bounds={minX:0,minZ:0,maxX:738,maxZ:820},groundHeight=()=>0,onChanged=()=>{}}={}){
 if(!THREE||!camera?.position||!camera?.quaternion)throw new Error('Editor camera requires THREE and a camera');
 if(![bounds.minX,bounds.minZ,bounds.maxX,bounds.maxZ].every(finite)||bounds.minX>bounds.maxX||bounds.minZ>bounds.maxZ)throw new Error('Editor camera bounds are invalid');
 let mode='top',saved=null,lookGesture=null,panGesture=null,flySpeed=18;
 const held=new Set(),flyEuler=new THREE.Euler(0,0,0,'YXZ'),direction=new THREE.Vector3(),right=new THREE.Vector3(),delta=new THREE.Vector3(),worldUp=new THREE.Vector3(0,1,0);
 const center=()=>new THREE.Vector3((bounds.minX+bounds.maxX)/2,0,(bounds.minZ+bounds.maxZ)/2);
 const width=()=>Math.max(1,bounds.maxX-bounds.minX),depth=()=>Math.max(1,bounds.maxZ-bounds.minZ);
 function capture(){
  if(saved)return saved;
  saved={position:cloneVector(camera.position),quaternion:camera.quaternion.clone(),up:cloneVector(camera.up),zoom:camera.zoom,near:camera.near,far:camera.far,controls:controls?{target:cloneVector(controls.target),enabled:controls.enabled,minDistance:controls.minDistance,maxDistance:controls.maxDistance,minPolarAngle:controls.minPolarAngle,maxPolarAngle:controls.maxPolarAngle}:null};return saved;
 }
 function notify(){camera.updateProjectionMatrix?.();camera.updateMatrixWorld?.(true);onChanged({mode,position:camera.position,quaternion:camera.quaternion,target:controls?.target});}
 function moveTop(dx,dz){
  const target=controls?.target;
  const minDx=Math.max(bounds.minX-camera.position.x,target?bounds.minX-target.x:-Infinity),maxDx=Math.min(bounds.maxX-camera.position.x,target?bounds.maxX-target.x:Infinity);
  const minDz=Math.max(bounds.minZ-camera.position.z,target?bounds.minZ-target.z:-Infinity),maxDz=Math.min(bounds.maxZ-camera.position.z,target?bounds.maxZ-target.z:Infinity);
  delta.set(clamp(dx,minDx,maxDx),0,clamp(dz,minDz,maxDz));camera.position.add(delta);target?.add(delta);
 }
 function clampFlyPosition(){camera.position.x=clamp(camera.position.x,bounds.minX-80,bounds.maxX+80);camera.position.z=clamp(camera.position.z,bounds.minZ-80,bounds.maxZ+80);camera.position.y=clamp(camera.position.y,(groundHeight(camera.position.x,camera.position.z)||0)+1,900)}
 function fitTop(){
  if(!saved)return false;
  const target=center(),fov=(camera.fov||50)*Math.PI/180,aspect=Math.max(.2,camera.aspect||1),height=Math.max(depth(),width()/aspect)/(2*Math.tan(fov/2))*1.08;
  target.y=groundHeight(target.x,target.z)||0;camera.up.set(0,0,-1);camera.position.set(target.x,target.y+clamp(height,45,1800),target.z+.001);camera.lookAt(target);if(controls?.target)controls.target.copy(target);notify();return true;
 }
 function enter(nextMode='top'){capture();if(controls)controls.enabled=false;held.clear();lookGesture=panGesture=null;mode=nextMode==='fly'?'fly':'top';if(mode==='top')fitTop();else{camera.up.copy(worldUp);clampFlyPosition();flyEuler.setFromQuaternion(camera.quaternion,'YXZ');notify()}return mode;}
 function setMode(nextMode){const value=nextMode==='fly'?'fly':'top';if(value===mode)return mode;mode=value;held.clear();lookGesture=panGesture=null;if(!saved)return mode;if(mode==='top')fitTop();else{flyEuler.setFromQuaternion(camera.quaternion,'YXZ');camera.up.copy(worldUp);clampFlyPosition();notify()}return mode;}
 function restore(){
  held.clear();lookGesture=panGesture=null;if(!saved)return false;
  camera.position.copy(saved.position);camera.quaternion.copy(saved.quaternion);camera.up.copy(saved.up);if(finite(saved.zoom))camera.zoom=saved.zoom;if(finite(saved.near))camera.near=saved.near;if(finite(saved.far))camera.far=saved.far;
  if(controls&&saved.controls){controls.target?.copy(saved.controls.target);for(const key of ['enabled','minDistance','maxDistance','minPolarAngle','maxPolarAngle'])if(saved.controls[key]!==undefined)controls[key]=saved.controls[key]}
  saved=null;notify();return true;
 }
 function update(dt){
  const seconds=clamp(finite(dt)?dt:0,0,.1);if(!seconds||!held.size)return false;
  const boost=held.has('ShiftLeft')||held.has('ShiftRight'),speed=(mode==='fly'?flySpeed:Math.max(8,camera.position.y*.35))*(boost?3:1)*seconds;delta.set(0,0,0);
  if(mode==='fly'){
   direction.set(0,0,-1).applyQuaternion(camera.quaternion).normalize();right.crossVectors(direction,worldUp).normalize();
   if(held.has('KeyW'))delta.add(direction);if(held.has('KeyS'))delta.sub(direction);if(held.has('KeyD'))delta.add(right);if(held.has('KeyA'))delta.sub(right);if(held.has('Space'))delta.y+=1;if(held.has('ControlLeft')||held.has('ControlRight'))delta.y-=1;
   if(delta.lengthSq())camera.position.add(delta.normalize().multiplyScalar(speed));clampFlyPosition();
  }else{
   if(held.has('KeyW'))delta.z-=1;if(held.has('KeyS'))delta.z+=1;if(held.has('KeyD'))delta.x+=1;if(held.has('KeyA'))delta.x-=1;if(delta.lengthSq()){delta.normalize().multiplyScalar(speed);moveTop(delta.x,delta.z)}
  }
  notify();return true;
 }
 function handleAction(action,event={}){
  const name=action?.action;
  if(name==='clear-input'){held.clear();lookGesture=panGesture=null;return true}
  if(!saved)return false;
  if(name==='navigate'){action.pressed?held.add(action.code):held.delete(action.code);return true}
  if(name==='navigate-vertical'){const code=action.direction>0?'Space':'ControlLeft';action.pressed?held.add(code):held.delete(code);return true}
  if(name==='modifier'){for(const code of ['ShiftLeft','ShiftRight'])held.delete(code);if(action.pressed)held.add('ShiftLeft');return true}
  if(name==='fit'){if(mode==='top')fitTop();return true}
  if(name==='fly-speed'){if(!finite(action.delta))return false;flySpeed=clamp(flySpeed*Math.exp(clamp(-action.delta*.001,-2,2)),3,120);return true}
  if(name==='zoom'&&mode==='top'){if(!finite(action.delta))return false;const target=controls?.target||center(),offset=camera.position.clone().sub(target),factor=Math.exp(clamp(action.delta*.001,-2,2));camera.position.copy(target).add(offset.multiplyScalar(factor));camera.position.x=clamp(camera.position.x,bounds.minX,bounds.maxX);camera.position.z=clamp(camera.position.z,bounds.minZ,bounds.maxZ);camera.position.y=clamp(camera.position.y,(groundHeight(target.x,target.z)||0)+18,1800);notify();return true}
  if(name==='camera-look-start'&&mode==='fly'){lookGesture={x:finite(event.clientX)?event.clientX:0,y:finite(event.clientY)?event.clientY:0};return true}
  if(name==='camera-look-move'&&lookGesture&&mode==='fly'){const x=finite(event.clientX)?event.clientX:lookGesture.x,y=finite(event.clientY)?event.clientY:lookGesture.y;flyEuler.setFromQuaternion(camera.quaternion,'YXZ');flyEuler.y-=(x-lookGesture.x)*.004;flyEuler.x=clamp(flyEuler.x-(y-lookGesture.y)*.004,-Math.PI/2+.02,Math.PI/2-.02);camera.quaternion.setFromEuler(flyEuler);lookGesture={x,y};notify();return true}
  if(name==='camera-look-end'){lookGesture=null;return true}
  if(name==='camera-pan-start'&&mode==='top'){panGesture={x:finite(event.clientX)?event.clientX:0,y:finite(event.clientY)?event.clientY:0};return true}
  if(name==='camera-pan-move'&&panGesture&&mode==='top'){const x=finite(event.clientX)?event.clientX:panGesture.x,y=finite(event.clientY)?event.clientY:panGesture.y,scale=Math.max(1,camera.position.y)*.0015;moveTop(-(x-panGesture.x)*scale,-(y-panGesture.y)*scale);panGesture={x,y};notify();return true}
  if(name==='camera-pan-end'){panGesture=null;return true}
  return false;
 }
 return {get mode(){return mode},get active(){return !!saved},get speed(){return flySpeed},capture,enter,setMode,fitTop,update,handleAction,restore,dispose:restore};
}
