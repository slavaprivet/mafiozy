// User-approved GALLERIA, immutable authored GLB; host THREE only.
export const GLASS_ORIGINAL_SHA256='0dfd79a8d670568aa4aa572ea13fd2584abfaaaed2df1f574ca7b7fcd15ef33c';
export const GLASS_ASSET_SHA256='ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873';
export const GLASS_ASSET_BYTES=3773048;
const revisionInfo=revision=>revision==='original'?{id:'original',sha:GLASS_ORIGINAL_SHA256,bytes:2108880,file:'glass_pavilion_small.0dfd79a8d670.glb'}:{id:'ao-v1',sha:GLASS_ASSET_SHA256,bytes:GLASS_ASSET_BYTES,file:'glass_pavilion_small_ao.ecae5f97bd53.glb'};
const defaultRevision=()=>new URLSearchParams(globalThis.location?.search||'').get('cityv3glassrevision')==='original'?'original':'ao-v1';
// Reusable visual candidates only: no new placement or collision registration.
export const GLASS_VISUAL_PRESETS=Object.freeze(Object.fromEntries([
  ['standard',1],['compact',.85],['small',.72],
].map(([id,scale])=>[id,Object.freeze({id,scale,placementReady:false,
  dimensionsM:Object.freeze([13.5,12.2,11.24].map(v=>v*scale)),
  publicLeafWidthM:1.405*scale,publicClearLaneWidthM:1.375*scale,
  publicDoorHeightM:3.25*scale,serviceLeafWidthM:1.55*scale,serviceDoorHeightM:2.8*scale,
  requires:'Independent parcel, entrance and collision preflight before placement',
})])));
export const GLASS_BINDING=Object.freeze({
  key:'glass_pavilion_small@1',instanceId:'MAIN-GLASS-GALLERIA-01',
  legacyStructureId:'legacy:procedural:40:60:45:65:48:68',
  centerGridRC:[47,67],uniformAssetScale:1,yawDeg:0,
  block:{r0:40,c0:60,r1:50,c1:70},legacy:{minR:45,maxR:49,minC:65,maxC:69},
  recenterXYZ:[-.25,0,-.325],
  // Author's COLLISION_BODY extras are Blender XYZ despite their *_gltf label.
  // Verified against actual Small_Base_Pad vertices: width13, depth10, height12.
  collisionSourceAxes:'blender_xyz_mislabeled_gltf',groundSizeXZ:[13,10],
});
const fail=message=>{throw new Error(`city-v3-glass:${message}`);};
const check=(condition,message)=>{if(!condition)fail(message);};
const near=(a,b)=>Number.isFinite(a)&&Math.abs(a-b)<.002;
const abort=signal=>{if(signal?.aborted)throw new DOMException('Glass installation cancelled','AbortError');};
const countMeshes=root=>{let n=0;root.traverse(o=>{if(o.isMesh)n++;});return n;};
function destroy(root){
  const geometries=new Set(),materials=new Set(),textures=new Set(),images=new Set();
  root?.traverse(o=>{if(o.geometry)geometries.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])materials.add(m);});
  materials.forEach(m=>{for(const value of Object.values(m))if(value?.isTexture)textures.add(value);});
  textures.forEach(t=>{if(t.image)images.add(t.image);t.dispose();});images.forEach(i=>i.close?.());
  geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose());
}
export function glassRuntimeContract(revision=defaultRevision()){
  const [r,c]=GLASS_BINDING.centerGridRC,toRC=([x,,z])=>[r+(z-.325)/4.1,c+(x-.25)/4.1];
  const rect=(x0,x1,z0,z1)=>({minR:r+(z0-.325)/4.1,maxR:r+(z1-.325)/4.1,minC:c+(x0-.25)/4.1,maxC:c+(x1-.25)/4.1});
  const door=toRC([0,0,5.05]),service=toRC([4.35,0,-4.55]);
  return {...GLASS_BINDING,glbSha256:revisionInfo(revision).sha,
    footprint:rect(-6.5,6.5,-5,5),pad:rect(-6.5,7,-5.295,5.945),
    door:{anchorR:door[0],anchorC:door[1],corridor:{minR:door[0]-.06,maxR:50.25,minC:door[1]-.4,maxC:door[1]+.4},roadProbe:{r:50.5,c:door[1]}},
    service:{anchorR:service[0],anchorC:service[1],corridor:{minR:43.75,maxR:service[0]+.06,minC:service[1]-.35,maxC:service[1]+.35},roadProbe:{r:43.5,c:service[1]}},
    dimensionsM:[13.5,12.2,11.24],
  };
}
export async function prepareCityV3GlassBuilding({THREE,GLTFLoader,signal,fetchImpl=fetch,revision=defaultRevision()}={}){
  check(THREE?.Box3&&THREE?.Group&&typeof GLTFLoader==='function','host-three-loader-required');
  abort(signal);
  const info=revisionInfo(revision),url=new URL(`./${info.file}`,import.meta.url);
  const response=await fetchImpl(url,{signal});check(response.ok,'asset-http');
  const bytes=await response.arrayBuffer();abort(signal);
  check(bytes.byteLength===info.bytes,'asset-bytes');
  const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(x=>x.toString(16).padStart(2,'0')).join('');
  check(hash===info.sha,'asset-hash');abort(signal);
  const gltf=await new GLTFLoader().parseAsync(bytes,new URL('.',url).href);
  const asset=gltf.scene;
  try{
    abort(signal);check(asset?.isObject3D,'asset-scene');asset.updateMatrixWorld(true);
    const node=name=>{const found=[];asset.traverse(o=>{if(o.name===name)found.push(o);});check(found.length===1,`unique-node-${name}`);return found[0];};
    const lods=[0,1,2].map(i=>node(`LOD${i}`));
    [150,2,1].forEach((n,i)=>check(countMeshes(lods[i])===n,`lod-meshes-${i}`));
    // The source has separate extruded text, not a signboard. Keep the
    // immutable asset and explicit original rollback, hide only this mesh.
    const lettering=node('Small_Galleria_Sign');check(lettering.isMesh,'lettering-mesh');
    lettering.visible=info.id==='original';
    const visibleMeshCounts=[lettering.visible?150:149,2,1];
    // No catalogue translations are permitted; all LODs share authored origin.
    lods.forEach((o,i)=>{check(o.position.length()<1e-6&&o.scale.distanceTo(new THREE.Vector3(1,1,1))<1e-6,`lod-transform-${i}`);o.visible=i===0;});
    const box=new THREE.Box3().setFromObject(lods[0]),size=box.getSize(new THREE.Vector3());
    check(size.toArray().every((v,i)=>near(v,[13.5,12.2,11.24][i])),'actual-lod0-bounds');
    check(near((box.min.x+box.max.x)/2,.25)&&near((box.min.z+box.max.z)/2,.325),'actual-recenter');
    const ground=new THREE.Box3().setFromObject(node('Small_Base_Pad'));
    check(near(ground.min.x,-6.5)&&near(ground.max.x,6.5)&&near(ground.min.z,-5)&&near(ground.max.z,5)&&near(ground.min.y,0),'ground-contact-bounds');
    const collision=node('COLLISION_BODY');
    check(JSON.stringify(collision.userData.size_xyz_gltf)==='[13,10,12]'&&near(collision.getWorldPosition(new THREE.Vector3()).y,6),'collision-source-axis-contract');
    for(const [name,xyz] of [['SOCKET_PUBLIC_DOOR',[0,0,5.05]],['SOCKET_SERVICE',[4.35,0,-4.55]]]){
      check(node(name).getWorldPosition(new THREE.Vector3()).toArray().every((v,i)=>near(v,xyz[i])),`socket-${name}`);
    }
    for(const name of ['COLLISION_BODY','PARCEL_PAD','PUBLIC_DOOR_OPENING_BOUNDS','PUBLIC_DOOR_APPROACH','SERVICE_DOOR_APPROACH','SOCKET_PUBLIC_DOOR','SOCKET_SERVICE'])node(name).visible=false;
    const materials=new Set();asset.traverse(o=>{if(o.isMesh)for(const m of Array.isArray(o.material)?o.material:[o.material])materials.add(m);});
    const aoMaterials=[...materials].filter(m=>m.aoMap);let aoMeshCount=0;
    if(info.id==='ao-v1'){
      check(aoMaterials.length===8,'ao-material-count');
      const canonical=aoMaterials[0].aoMap;
      check(canonical.image?.width===2048&&canonical.image?.height===2048,'ao-image-not-decoded');
      for(const m of aoMaterials){
        const texture=m.aoMap;
        check(m.name!=='Smoky teal architectural glass'&&m.name!=='Warm occupied interior','ao-excluded-material');
        check(texture.channel===1&&texture.colorSpace===THREE.NoColorSpace,'ao-linear-uv1');
        check(texture.image===canonical.image&&texture.wrapS===canonical.wrapS&&texture.wrapT===canonical.wrapT&&texture.minFilter===canonical.minFilter,'ao-shared-image-sampler');
        if(texture!==canonical){m.aoMap=canonical;texture.dispose();}
      }
      asset.traverse(o=>{if(!o.isMesh)return;const ms=Array.isArray(o.material)?o.material:[o.material];if(!ms.some(m=>m.aoMap))return;aoMeshCount++;const uv=o.geometry.attributes.uv1;check(uv&&uv.count===o.geometry.attributes.position.count,'ao-uv1-missing');for(let i=0;i<uv.count;i++)check(Number.isFinite(uv.getX(i))&&Number.isFinite(uv.getY(i)),'ao-uv1-nonfinite');});
      check(aoMeshCount===122,'ao-mesh-count');
    }else check(aoMaterials.length===0,'original-ao-unexpected');
    for(const material of materials){
      if(material.name!=='Smoky teal architectural glass')continue;
      // Source Blender explicitly uses show_transparent_back=False. glTF's
      // doubleSided:true loses that glass-specific flag; two Three passes do
      // not match the approved front-surface-only alpha glass proof.
      material.side=THREE.FrontSide;material.forceSinglePass=true;
      material.depthWrite=false;
      // Neutral proof lighting is not the city's bright cyan sky cubemap.
      // Keep authored color/opacity/roughness/metalness; bound reflected sky.
      material.envMapIntensity=.35;
      material.userData.cityV3GlassReferenceProfile='front-surface-bounded-sky-v1';
      material.needsUpdate=true;
    }
    asset.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
    const root=new THREE.Group();root.name='CITY_V3_GLASS_GALLERIA_01';
    asset.position.add(new THREE.Vector3(-.25,0,-.325));root.add(asset);root.updateMatrixWorld(true);
    return {root,asset,lods,materials:[...materials],contract:glassRuntimeContract(info.id),visibleMeshCount:visibleMeshCounts[0],visibleMeshCounts,
      revision:info.id,aoEvidence:{imageLoaded:aoMaterials.length>0,materialCount:aoMaterials.length,meshCount:aoMeshCount,textureCount:new Set(aoMaterials.map(m=>m.aoMap)).size,uvAttribute:aoMaterials.length?'uv1':null,width:aoMaterials.length?2048:0,height:aoMaterials.length?2048:0,estimatedRgba8MipBytes:aoMaterials.length?22369620:0}};
  }catch(e){destroy(asset);throw e;}
}
export async function installCityV3GlassBuilding(options={}){
  const {THREE,scene,bridge,renderer,originR,originC,worldScale,signal}=options;
  check(scene?.isScene&&typeof bridge?.activateCityV3GlassBuilding==='function'&&typeof bridge?.rollbackCityV3GlassBuilding==='function','host-transaction-api');
  check([originR,originC,worldScale].every(Number.isFinite)&&worldScale>0,'host-transform');
  const prepared=await prepareCityV3GlassBuilding(options);let activation=null,disposed=false;
  const {root,contract,lods}=prepared,ratio=worldScale/4.1;
  const diagnostics=renderer?.domElement?.dataset;
  try{
    abort(signal);root.scale.setScalar(ratio);
    root.position.set((contract.centerGridRC[1]-originC)*worldScale,0,(contract.centerGridRC[0]-originR)*worldScale);
    scene.add(root);root.updateMatrixWorld(true);abort(signal);
    const receipt={...contract,assetSha256:contract.glbSha256,loaded:true,registered:root.parent===scene,eligible:true,visibleMeshCount:prepared.visibleMeshCount,
      doorAnchorGridRC:[contract.door.anchorR,contract.door.anchorC],serviceAnchorGridRC:[contract.service.anchorR,contract.service.anchorC],
      groundCollisionBoundsLocal:{min:[-6.5,0,-5],max:[6.5,12,5]},runtimeWorldScale:worldScale};
    activation=bridge.activateCityV3GlassBuilding(receipt);
    check(activation?.ok===true&&activation?.rollbackToken,'activation-'+(activation?.reason||'rejected'));
    if(diagnostics){diagnostics.cityV3Glass=`active:glass-pavilion:${prepared.visibleMeshCount}-meshes:LOD0`;diagnostics.cityV3GlassBranding=JSON.stringify({hiddenNodes:prepared.revision==='original'?[]:['Small_Galleria_Sign'],label:'Стеклянный павильон',placedScale:1,variantPresetsOnly:true});diagnostics.cityV3GlassReceipt=JSON.stringify(receipt);diagnostics.cityV3GlassAO=JSON.stringify({revision:prepared.revision,sha256:contract.glbSha256,...prepared.aoEvidence});}
    let activeLOD=0;
    return {root,receipt,activation,
      update({distanceM=0}={}){
        if(disposed)return;
        if(diagnostics)diagnostics.cityV3GlassMaterialAudit=JSON.stringify({
          profile:'front-surface-bounded-sky-v1',activeLOD,scale:root.scale.x,exposure:renderer.toneMappingExposure,
          environmentIntensity:scene.environmentIntensity,materials:prepared.materials.map(m=>({name:m.name,type:m.type,color:m.color.toArray(),opacity:m.opacity,side:m.side,roughness:m.roughness,metalness:m.metalness,envMapIntensity:m.envMapIntensity,depthWrite:m.depthWrite,transmission:m.transmission||0})),
        });
        const next=distanceM>170?2:distanceM>70?1:0;
        if(next===activeLOD)return;activeLOD=next;lods.forEach((o,i)=>{o.visible=i===next;});
        if(diagnostics)diagnostics.cityV3Glass=`active:glass-pavilion:${prepared.visibleMeshCounts[next]}-meshes:LOD${next}`;
      },
      dispose(){
        if(disposed)return;const result=bridge.rollbackCityV3GlassBuilding(activation.rollbackToken);
        check(result?.ok===true,'rollback-refused');scene.remove(root);destroy(root);disposed=true;
        if(diagnostics)diagnostics.cityV3Glass='rolled-back';
      },
    };
  }catch(e){
    if(activation?.rollbackToken){const result=bridge.rollbackCityV3GlassBuilding(activation.rollbackToken);check(result?.ok===true,'rollback-refused');}
    scene.remove(root);destroy(root);if(diagnostics)diagnostics.cityV3Glass=`failed:${e.message}`;throw e;
  }
}
