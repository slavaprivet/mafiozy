// Artist13 appearance, locomotion only. Host THREE/loader; no controls/server/combat.
export const HERO_ASSET=Object.freeze({url:new URL('./hero_models/player_male.8130dfb1f7eb.glb',import.meta.url).href,bytes:652732,sha256:'8130dfb1f7eb91bff31e932fEEF1717672070a6767ccc726d7cb1ee23133fd00'.toLowerCase()});
const required=['chest','thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r','upperarm_l','upperarm_r','forearm_l','forearm_r'];
export function createHeroWalker({THREE,scene,targetHeight=1.9}){
  if(!THREE||!scene||!Number.isFinite(targetHeight)||targetHeight<1||targetHeight>3)throw Error('Invalid hero host/height');
  scene.updateMatrixWorld(true);
  const bones={},rest={};scene.traverse(o=>{if(o.isBone){bones[o.name]=o;const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();o.matrix.decompose(p,q,s);rest[o.name]={matrix:o.matrix.clone(),p,q,s};o.matrixAutoUpdate=false;}
    if(o.isMesh){o.castShadow=true;o.receiveShadow=true;o.frustumCulled=false;}});
  for(const name of required)if(!bones[name])throw Error('Missing Artist13 rest node '+name);
  const box=new THREE.Box3().setFromObject(scene),size=box.getSize(new THREE.Vector3()),sourceHeight=size.y;
  if(!Number.isFinite(sourceHeight)||sourceHeight<=0)throw Error('Empty hero bounds');
  const object=new THREE.Group(),scaled=new THREE.Group(),offset=new THREE.Group();object.name='Artist13_Walk_Hero';scaled.scale.setScalar(targetHeight/sourceHeight);
  offset.position.set(-(box.min.x+box.max.x)/2,-box.min.y,-(box.min.z+box.max.z)/2);offset.add(scene);scaled.add(offset);object.add(scaled);
  let phase=0,gait=0,disposed=false;
  const euler=new THREE.Euler(),delta=new THREE.Quaternion(),posed=new THREE.Quaternion();
  const restore=()=>{for(const[name,bone]of Object.entries(bones)){bone.matrix.copy(rest[name].matrix);bone.matrixWorldNeedsUpdate=true;}};
  const rotate=(name,x=0,y=0,z=0)=>{const bone=bones[name],r=rest[name];if(!bone)return;delta.setFromEuler(euler.set(x,y,z));posed.copy(r.q).multiply(delta);bone.matrix.compose(r.p,posed,r.s);bone.matrixWorldNeedsUpdate=true;};
  const reset=()=>{phase=0;gait=0;scaled.position.y=0;restore();object.updateMatrixWorld(true);};
  function update(dt,moving=false,running=false){
    if(disposed)return;dt=Math.min(.1,Math.max(0,Number.isFinite(dt)?dt:0));
    gait+=(Number(moving)-gait)*(1-Math.exp(-10*dt));if(!moving&&gait<.0001)gait=0;
    phase+=dt*(moving?(running?5.8:3.2)*2.3:3);restore();
    if(gait){rotate('chest',0,0,Math.sin(phase)*gait*.018);for(const[side,sign]of[['l',1],['r',-1]]){
      const step=Math.sin(phase)*sign*gait;rotate('thigh_'+side,step*.56);rotate('shin_'+side,Math.max(0,-step)*.52);rotate('foot_'+side,-step*.22);
      rotate('upperarm_'+side,-step*.38);rotate('forearm_'+side,-Math.max(0,step)*.12);
    }}
    scaled.position.y=Math.abs(Math.sin(phase))*gait*.026;object.updateMatrixWorld(true);
  }
  function dispose(){if(disposed)return;disposed=true;object.removeFromParent();const gs=new Set(),ms=new Set(),ts=new Set();scene.traverse(o=>{if(o.geometry)gs.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])ms.add(m);});for(const m of ms){for(const v of Object.values(m))if(v?.isTexture)ts.add(v);m.dispose();}for(const t of ts)t.dispose();for(const g of gs)g.dispose();}
  reset();return{object,height:targetHeight,sourceHeight,scale:targetHeight/sourceHeight,frontAxis:'+Z',update,reset,dispose,
    diagnostics:()=>({gait,phase,disposed,boneCount:Object.keys(bones).length,sourceBounds:{min:box.min.toArray(),max:box.max.toArray()},requiredNodes:[...required]})};
}
export async function loadHeroWalker({THREE,loader,targetHeight=1.9,signal}={}){
  if(!loader)throw Error('Host GLTFLoader instance required');
  const response=await fetch(HERO_ASSET.url,{signal});if(!response.ok)throw Error('Hero fetch HTTP '+response.status);
  const bytes=await response.arrayBuffer();if(bytes.byteLength!==HERO_ASSET.bytes)throw Error('Hero bytes mismatch');
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
  if(digest!==HERO_ASSET.sha256)throw Error('Hero SHA256 mismatch');
  if(signal?.aborted)throw new DOMException('Aborted','AbortError');
  const gltf=loader.parseAsync?await loader.parseAsync(bytes,HERO_ASSET.url.slice(0,HERO_ASSET.url.lastIndexOf('/')+1)):await new Promise((resolve,reject)=>loader.parse(bytes,'',resolve,reject));
  return createHeroWalker({THREE,scene:gltf.scene,targetHeight});
}
