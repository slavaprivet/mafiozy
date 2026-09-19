// Conservative, render-only rejection of directional vehicle shadows. A caster
// outside the view is NOT enough: its complete shadow ray volume must miss it.
export const vehicleShadowCullingEnabled=(search='')=>new URLSearchParams(search).get('vehicleshadowcull')!=='0';

export function shadowVolumeOutsideView(planes,center,radius,direction,length,padding=0){
 if(!Number.isFinite(radius)||radius<0||!Number.isFinite(length)||length<0||!Number.isFinite(padding)||padding<0)return false;
 const r=radius+padding;
 for(const plane of planes){
  const n=plane.normal,distance=n.x*center.x+n.y*center.y+n.z*center.z+plane.constant;
  const advance=(n.x*direction.x+n.y*direction.y+n.z*direction.z)*length;
  if(distance+Math.max(0,advance)<-r)return true;
 }
 return false;
}

export function createVehicleShadowCulling({THREE:T,renderer,scene,sun,enabled=true,onSample}={}){
 if(!renderer?.shadowMap?.render||!renderer.renderBufferDirect||!sun?.isDirectionalLight)throw Error('Directional vehicle shadow culling requires renderer and sun');
 const originalShadow=renderer.shadowMap.render,originalDirect=renderer.renderBufferDirect;
 const frustum=new T.Frustum(),matrix=new T.Matrix4(),direction=new T.Vector3(),center=new T.Vector3(),lightPosition=new T.Vector3(),target=new T.Vector3(),batchSphere=new T.Sphere();
 const stamps=new WeakMap();let context=null,disposed=false,frames=0,prunedMap=false;
 const stats={enabled:!!enabled,tested:0,culled:0,unsupported:0,padding:0};
 const unsupportedMaterial=m=>!m?.isMeshStandardMaterial||m.displacementMap||m.onBeforeCompile!==T.Material.prototype.onBeforeCompile;
 const vehicle=object=>{for(let node=object;node;node=node.parent)if(node.userData?.vehicleFleetId||node.userData?.sourceVehicleId)return true;return false;};
 function getSphere(object,geometry){
  if(object.isSkinnedMesh||object.customDepthMaterial||object.customDistanceMaterial)return null;
  if(object.onBeforeShadow!==T.Object3D.prototype.onBeforeShadow&&(!object.isBatchedMesh||object.onBeforeShadow!==T.BatchedMesh.prototype.onBeforeShadow))return null;
  if(Array.isArray(object.material)?object.material.some(unsupportedMaterial):unsupportedMaterial(object.material))return null;
  if(object.isInstancedMesh)return null;
  if(object.isBatchedMesh)return object.userData?.vehicleRenderBatch&&object.onBeforeRender===T.BatchedMesh.prototype.onBeforeRender&&object.boundingBox?object.boundingBox.getBoundingSphere(batchSphere):null;
  if(Object.keys(geometry.morphAttributes||{}).length)return null;
  const a=geometry.attributes?.position;if(!a||a.isInterleavedBufferAttribute||a.isGLBufferAttribute)return null;
  const stamp=stamps.get(geometry);
  if(!stamp||stamp.attribute!==a||stamp.version!==a.version||stamp.array!==a.array||stamp.count!==a.count){geometry.computeBoundingSphere();stamps.set(geometry,{attribute:a,version:a.version,array:a.array,count:a.count});}
  return geometry.boundingSphere;
 }
 function outside(object,geometry){
  const sphere=getSphere(object,geometry);if(!sphere){stats.unsupported++;return false;}
  center.copy(sphere.center).applyMatrix4(object.matrixWorld);
  // Largest absolute row sum of A^T A bounds its maximum eigenvalue. Unlike
  // a shear epsilon shortcut, this remains conservative at every scale.
  const e=object.matrixWorld.elements,a=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],b=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],c=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];
  const ab=Math.abs(e[0]*e[4]+e[1]*e[5]+e[2]*e[6]),ac=Math.abs(e[0]*e[8]+e[1]*e[9]+e[2]*e[10]),bc=Math.abs(e[4]*e[8]+e[5]*e[9]+e[6]*e[10]);
  const radius=sphere.radius*Math.sqrt(Math.max(a+ab+ac,b+ab+bc,c+ac+bc));
  // Every shadow receiver lies before the existing shadow camera's far plane.
  // Include the caster radius so the entire sphere, not just its centre, fits.
  const depth=(center.x-context.lightPosition.x)*context.direction.x+(center.y-context.lightPosition.y)*context.direction.y+(center.z-context.lightPosition.z)*context.direction.z;
  const length=Math.max(0,context.far-depth+radius+context.padding);
  stats.tested++;return shadowVolumeOutsideView(context.planes,center,radius,context.direction,length,context.padding);
 }
 const wrappedDirect=function(camera,renderScene,geometry,material,object,group){
  if(context&&camera===sun.shadow.camera&&object?.isMesh&&vehicle(object)&&outside(object,geometry)){stats.culled++;return;}
  return originalDirect.call(this,camera,renderScene,geometry,material,object,group);
 };
 const wrappedShadow=function(lights,renderScene,camera){
  const previous=context;context=null;
  stats.tested=stats.culled=stats.unsupported=0;
  const automatic=renderer.shadowMap.autoUpdate!==false&&sun.shadow.autoUpdate!==false;
  if(!automatic&&prunedMap){renderer.shadowMap.needsUpdate=true;sun.shadow.needsUpdate=true;prunedMap=false;}
  const sc=sun.shadow.camera,ordinaryShadowCamera=sc.isOrthographicCamera&&sc.matrixAutoUpdate!==false&&sc.matrixWorldAutoUpdate!==false&&!sc.parent&&!sc.view?.enabled&&sc.scale.x===1&&sc.scale.y===1&&sc.scale.z===1;
  if(!previous&&!disposed&&stats.enabled&&automatic&&ordinaryShadowCamera&&renderScene===scene&&renderer.shadowMap.enabled!==false&&renderer.shadowMap.type===T.PCFSoftShadowMap&&lights.includes(sun)&&!camera.isArrayCamera&&!camera.reversedDepth&&camera.coordinateSystem!==T.WebGPUCoordinateSystem){
   matrix.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);frustum.setFromProjectionMatrix(matrix);
   lightPosition.setFromMatrixPosition(sun.matrixWorld);target.setFromMatrixPosition(sun.target.matrixWorld);direction.subVectors(target,lightPosition).normalize();
   const s=sun.shadow,cam=s.camera;
   const maxTextureSize=renderer.capabilities?.maxTextureSize||Infinity;
   const texel=Math.max(Math.abs(cam.right-cam.left)/Math.min(s.mapSize.x,maxTextureSize),Math.abs(cam.top-cam.bottom)/Math.min(s.mapSize.y,maxTextureSize))/Math.abs(cam.zoom||1);
   // Four texels conservatively cover PCFSoft filtering; normal/depth biases
   // can move a receiver across the view edge and are included in world units.
   const padding=4*texel+Math.abs(s.normalBias||0)+Math.abs(s.bias||0)*(cam.far-cam.near)+.01;
   if(Number.isFinite(padding)&&direction.lengthSq()>.99&&cam.far>0){context={planes:frustum.planes,direction,lightPosition,far:cam.far,padding};stats.padding=padding;}
  }
  try{return originalShadow.call(this,lights,renderScene,camera);}finally{if(stats.culled)prunedMap=true;context=previous;if(onSample&&++frames%60===1)onSample(stats);}
 };
 renderer.renderBufferDirect=wrappedDirect;renderer.shadowMap.render=wrappedShadow;
 const refreshMap=()=>{if(prunedMap){renderer.shadowMap.needsUpdate=true;sun.shadow.needsUpdate=true;prunedMap=false;}};
 return {stats,setEnabled(value){if(stats.enabled!==!!value)refreshMap();stats.enabled=!!value;},dispose(){if(disposed)return;refreshMap();disposed=true;context=null;if(renderer.renderBufferDirect===wrappedDirect)renderer.renderBufferDirect=originalDirect;if(renderer.shadowMap.render===wrappedShadow)renderer.shadowMap.render=originalShadow;}};
}
