import { cityV3BuildingPreviewGate, parseGlbJson, sha256Hex } from '../registry.v1.js';

const REGISTRY_SCHEMA='mafiozi.city-v3-accepted-building-registry/v1';
const MANIFEST_SCHEMA='mafiozi.city-v3-accepted-building/v1';
const BINDINGS_SCHEMA='mafiozi.city-v3-main-native-bindings/v1';
const DIRECT_VERSIONED_KEY=/^[a-z0-9][a-z0-9_-]*@[1-9][0-9]*$/;
const SHA256_HEX=/^[a-f0-9]{64}$/;
const EPSILON=.015;

export const CITY_V3_ACCEPTED_REGISTRY_URL=new URL('./registry.v1.json',import.meta.url);
export const CITY_V3_ACCEPTED_REGISTRY_SHA256='c1b79fe64b550b4898351155a1cd17dac2b23b64075a6e0f9b77d202b853635e';
export const CITY_V3_ACCEPTED_KEYS=Object.freeze(['pawnshop@1','print_shop@1']);

export class CityV3AcceptedBuildingError extends Error{
  constructor(code,message){super(`${code}: ${message}`);this.name='CityV3AcceptedBuildingError';this.code=code;}
}
const fail=(code,message)=>{throw new CityV3AcceptedBuildingError(code,message);};
const assert=(condition,code,message)=>{if(!condition)fail(code,message);};
const lower=value=>String(value||'').toLowerCase();
const near=(a,b,e=EPSILON)=>Number.isFinite(+a)&&Math.abs(+a-b)<=e;
const vector=(actual,expected,code,e=EPSILON)=>{
  assert(Array.isArray(actual)&&actual.length===expected.length,code,'vector shape mismatch');
  expected.forEach((value,index)=>assert(near(actual[index],value,e),code,`vector[${index}] mismatch`));
};
const boxValues=box=>({
  min:[box.min.x,box.min.y,box.min.z],max:[box.max.x,box.max.y,box.max.z],
  dimensions:[box.max.x-box.min.x,box.max.y-box.min.y,box.max.z-box.min.z],
});
const exactFile=async(url,bytes,sha,code)=>{
  assert(Number.isInteger(bytes)&&bytes>0,`${code}_bytes_contract`,'invalid byte contract');
  assert(SHA256_HEX.test(lower(sha)),`${code}_sha_contract`,'invalid hash contract');
  const response=await fetch(url,{cache:'no-store',credentials:'same-origin'});
  assert(response.ok,`${code}_fetch`,`${response.status} ${response.statusText}`);
  const body=new Uint8Array(await response.arrayBuffer());
  assert(body.byteLength===bytes,`${code}_bytes`,`${body.byteLength} != ${bytes}`);
  const actual=await sha256Hex(body);assert(actual===lower(sha),`${code}_sha`,`${actual} != ${sha}`);
  return {body,sha256:actual};
};
const json=(bytes,code)=>{try{return JSON.parse(new TextDecoder().decode(bytes));}catch(error){fail(`${code}_json`,error?.message||'invalid JSON');}};

export function resolveCityV3AcceptedAsset(registry,key){
  assert(registry?.schema===REGISTRY_SCHEMA&&registry?.revision===1,'registry_schema','unsupported registry');
  assert(registry?.activation_policy==='explicit_local_stage_a_preview_fail_closed','registry_policy','activation policy mismatch');
  assert(DIRECT_VERSIONED_KEY.test(String(key||'')),'resolver_key','direct versioned key required');
  const matches=(registry.entries||[]).filter(entry=>entry?.key===key);
  assert(matches.length===1,'resolver_cardinality',`expected one ${key}, got ${matches.length}`);
  const entry=matches[0];
  assert(entry.status==='main_native_preview_binding'&&entry.live_activation===false,'resolver_status','entry is not preview-only');
  for(const [name,record] of Object.entries({manifest:entry.manifest,asset:entry.asset,sidecar:entry.sidecar})){
    assert(record?.url?.startsWith('./'),`resolver_${name}_url`,'registry-relative URL required');
    assert(Number.isInteger(record.bytes)&&record.bytes>0,`resolver_${name}_bytes`,'invalid bytes');
    assert(SHA256_HEX.test(lower(record.sha256)),`resolver_${name}_sha`,'invalid SHA-256');
  }
  return entry;
}

export function resolveCityV3RuntimeNodeByRawIndex({scene,associations,rawIndex,rawName='',code='gltf_runtime_node'}={}){
  assert(scene&&typeof scene.traverse==='function'&&typeof associations?.get==='function','gltf_runtime_associations','runtime scene or associations missing');
  assert(Number.isInteger(rawIndex)&&rawIndex>=0,`${code}_index`,`${rawName} raw node index is invalid`);
  const matches=[];scene.traverse(object=>{if(associations.get(object)?.nodes===rawIndex)matches.push(object);});
  assert(matches.length===1,code,`${rawName} raw node ${rawIndex} resolved to ${matches.length} runtime objects`);
  return matches[0];
}

const validateManifest=(entry,manifest,binding,sidecar)=>{
  assert(manifest?.schema===MANIFEST_SCHEMA&&manifest?.key===entry.key,'manifest_identity','schema/key mismatch');
  assert(manifest.status==='preview_only_fail_closed','manifest_status','live activation is not allowed');
  assert(lower(manifest.asset?.sha256)===lower(entry.asset.sha256)&&+manifest.asset?.bytes===entry.asset.bytes,'manifest_asset','asset binding mismatch');
  assert(lower(manifest.asset?.sidecar_sha256)===lower(entry.sidecar.sha256)&&+manifest.asset?.sidecar_bytes===entry.sidecar.bytes,'manifest_sidecar','sidecar binding mismatch');
  assert(manifest.provenance?.origin==='project_generated'&&manifest.provenance?.usage==='internal_project_asset','provenance_rights','project provenance missing');
  assert(Array.isArray(manifest.provenance?.external_sources)&&manifest.provenance.external_sources.length===0,'provenance_sources','external sources are not allowed');
  assert(SHA256_HEX.test(lower(manifest.provenance?.generator_sha256)),'provenance_generator','generator hash missing');
  assert(lower(manifest.authority?.placement_v2_contract_sha256)==='e917883063d0dcc3326ed2ea508f4d3956e10688296d1f063a34c61378bc4c78'&&manifest.authority?.placement_v2_status==='superseded_do_not_apply','placement_v2','placement-v2 provenance is not explicitly superseded');
  assert(lower(manifest.authority?.placement_v3_contract_sha256)==='9a8ee4a98062c0b1e171cafc5552cfd1d65e91d2da167ee45f282c47a83787f7'&&lower(manifest.authority?.placement_v3_package_manifest_sha256)==='5b0cd9bc7ee0f9357dd8f21bb409569ac9dfc03cefc5d078ac7da94aaa6fdd48','placement_v3','wrong placement-v3 provenance');
  assert(manifest.authority?.placement_v3_status==='stage_a_topology_only_main_native_runtime_rollout_ready_false','placement_v3_status','placement-v3 must remain topology-only');
  assert(lower(manifest.authority?.main_native_bindings_sha256)==='af32124e3581fca1cc01bae31691f6ba17a0c381974638e4134457f7134ae297','main_binding_sha','wrong MAIN binding authority');
  assert(binding?.key===entry.key&&lower(binding?.asset_sha256)===lower(entry.asset.sha256),'binding_asset','MAIN binding mismatch');
  assert(binding?.replacement?.policy==='addressed_removal_only'&&binding?.replacement?.routing_preserved===true&&binding?.replacement?.zero_untracked_demolition===true,'binding_replacement','unsafe replacement policy');
  assert(typeof binding?.legacy_structure_id==='string'&&binding.legacy_structure_id.startsWith('legacy:procedural:'),'binding_legacy','exact runtime legacy ID missing');
  assert(binding?.legacy_tile_bounds?.tile_count===16,'binding_tiles','expected one exact 16-tile shell');
  assert(manifest.runtime_gate?.fail_closed===true&&manifest.runtime_gate?.failure_keeps_legacy===true,'runtime_policy','fail-closed policy missing');
  if(entry.key==='pawnshop@1'){
    assert(sidecar?.operation_type==='pawnshop'&&sidecar?.review_status==='user_pass'&&sidecar?.frozen===true,'sidecar_pawnshop','pawnshop sidecar mismatch');
    vector(binding.center_grid_rc,[7,67],'binding_center',1e-9);assert(near(binding.yaw_deg,0,1e-9),'binding_yaw','pawnshop yaw mismatch');
  }else if(entry.key==='print_shop@1'){
    assert(sidecar?.business_kind==='print_shop'&&sidecar?.owner_branding==='dynamic_not_baked','sidecar_print_shop','print-shop sidecar mismatch');
    vector(binding.center_grid_rc,[97,47],'binding_center',1e-9);assert(near(binding.yaw_deg,0,1e-9),'binding_yaw','print-shop yaw mismatch');
  }else fail('manifest_key','unsupported asset key');
};

const validateRawNodes=(glb,manifest)=>{
  const nodes=Array.isArray(glb?.nodes)?glb.nodes:[],byName=new Map();
  nodes.forEach((node,index)=>{if(!node?.name)return;const values=byName.get(node.name)||[];values.push(index);byName.set(node.name,values);});
  for(const name of manifest.geometry.required_nodes)assert(byName.get(name)?.length===1,'glb_required_node',`${name} missing or duplicated`);
  if(manifest.geometry.root_node){
    const root=byName.get(manifest.geometry.root_node);assert(root?.length===1,'glb_root','runtime root missing or duplicated');
    assert(Array.isArray(nodes[root[0]].children)&&nodes[root[0]].children.length>0,'glb_root_empty','runtime root has no children');
  }
  for(const [kind,nodeName,expected] of [
    ['public_door',manifest.geometry.public_door_node,manifest.geometry.public_door_local_xyz_m],
    ['service_door',manifest.geometry.service_door_node,manifest.geometry.service_door_local_xyz_m],
  ]){
    const matches=byName.get(nodeName);assert(matches?.length===1,`glb_${kind}_node`,`${nodeName} missing or duplicated`);
    vector(nodes[matches[0]].translation||[0,0,0],expected,`glb_${kind}_translation`,.015);
  }
  return byName;
};

const prepareCandidate=async({THREE,loader,entry,binding,registryUrl})=>{
  const manifestUrl=new URL(entry.manifest.url,registryUrl),assetUrl=new URL(entry.asset.url,registryUrl),sidecarUrl=new URL(entry.sidecar.url,registryUrl);
  const [mf,sf,af]=await Promise.all([
    exactFile(manifestUrl,entry.manifest.bytes,entry.manifest.sha256,`${entry.key}_manifest`),
    exactFile(sidecarUrl,entry.sidecar.bytes,entry.sidecar.sha256,`${entry.key}_sidecar`),
    exactFile(assetUrl,entry.asset.bytes,entry.asset.sha256,`${entry.key}_asset`),
  ]);
  const manifest=json(mf.body,'manifest'),sidecar=json(sf.body,'sidecar');
  validateManifest(entry,manifest,binding,sidecar);const rawNodeIndexes=validateRawNodes(parseGlbJson(af.body),manifest);
  const buffer=af.body.buffer.slice(af.body.byteOffset,af.body.byteOffset+af.body.byteLength);
  const gltf=await new Promise((resolve,reject)=>loader.parse(buffer,new URL('.',assetUrl).href,resolve,reject));
  const loadedScene=gltf?.scene,associations=gltf?.parser?.associations;
  assert(loadedScene&&typeof associations?.get==='function','gltf_runtime_scene','loaded scene or node associations missing');
  const runtimeObjectForRawName=(name,code)=>{
    const rawMatches=rawNodeIndexes.get(name);assert(rawMatches?.length===1,`${code}_raw`,`${name} raw node is not unique`);
    return resolveCityV3RuntimeNodeByRawIndex({scene:loadedScene,associations,rawIndex:rawMatches[0],rawName:name,code});
  };
  const assetRoot=manifest.geometry.root_node?runtimeObjectForRawName(manifest.geometry.root_node,'gltf_runtime_root'):loadedScene;
  assert(assetRoot,'gltf_runtime_root','loaded scene root missing');assetRoot.updateMatrixWorld(true);
  // Resolve every authored public-door object while the complete parsed scene
  // is still attached. Pawnshop uses a named child as assetRoot; reparenting
  // that child empties loadedScene, so a later association traversal would
  // correctly find zero objects and fail closed.
  const hiddenDoorNodes=manifest.geometry.public_door_visual_nodes;
  assert(Array.isArray(hiddenDoorNodes)&&hiddenDoorNodes.length>0&&new Set(hiddenDoorNodes).size===hiddenDoorNodes.length,'gltf_public_door_visuals','exact public door visual list missing or duplicated');
  const hiddenDoorObjects=hiddenDoorNodes.map(name=>runtimeObjectForRawName(name,'gltf_public_door_visual'));
  const rawBox=boxValues(new THREE.Box3().setFromObject(assetRoot)),expected=manifest.geometry.raw_bounds_m;
  vector(rawBox.min,expected.min_xyz,'gltf_raw_min');vector(rawBox.max,expected.max_xyz,'gltf_raw_max');
  const placementRoot=new THREE.Group();placementRoot.name=`CITY_V3_INSTANCE_${binding.instance_id}`;
  const recenter=manifest.geometry.pre_rotation_recenter_xyz_m;
  // Object3D composes T*R*S, so a translation on the same node is not scaled.
  // Apply the recenter in already-scaled metres; this keeps the visible AABB
  // centred on the collision OBB before the renderer-profile wrapper scale.
  assetRoot.position.x+=recenter[0]*binding.uniform_asset_scale;assetRoot.position.z+=recenter[2]*binding.uniform_asset_scale;assetRoot.scale.setScalar(binding.uniform_asset_scale);
  placementRoot.add(assetRoot);placementRoot.rotation.y=THREE.MathUtils.degToRad(binding.yaw_deg);placementRoot.updateMatrixWorld(true);
  const correctedBox=boxValues(new THREE.Box3().setFromObject(placementRoot));
  vector(correctedBox.dimensions,binding.key==='pawnshop@1'?[9.452,7.803,7.477]:[13.791,8.323,10.88],'gltf_scaled_dimensions');
  assert(near((correctedBox.min[0]+correctedBox.max[0])*.5,0)&&near((correctedBox.min[2]+correctedBox.max[2])*.5,0),'gltf_recenter','horizontal AABB is not centered');
  for(const object of hiddenDoorObjects){object.visible=false;object.userData.cityV3DoorLeafHidden=true;}
  const meshes=[];assetRoot.traverse(object=>{if(!object?.isMesh)return;assert(object.geometry?.attributes?.position,'gltf_geometry',`${object.name||'mesh'} has no positions`);let visible=true;for(let current=object;current;current=current.parent)if(current.visible===false){visible=false;break;}if(!visible)return;object.castShadow=true;object.receiveShadow=true;meshes.push(object);});
  assert(meshes.length>0,'gltf_empty','asset has no visible non-door meshes');
  const localAnchorToGrid=local=>{
    const x=(local[0]-manifest.geometry.horizontal_center_xyz_m[0])*binding.uniform_asset_scale/4.1,z=(local[2]-manifest.geometry.horizontal_center_xyz_m[2])*binding.uniform_asset_scale/4.1,t=THREE.MathUtils.degToRad(binding.yaw_deg);
    return [binding.center_grid_rc[0]-x*Math.sin(t)+z*Math.cos(t),binding.center_grid_rc[1]+x*Math.cos(t)+z*Math.sin(t)];
  };
  vector(localAnchorToGrid(manifest.geometry.public_door_local_xyz_m),binding.public_door.actual_anchor_grid_rc,'binding_public_door',1e-5);
  vector(localAnchorToGrid(manifest.geometry.service_door_local_xyz_m),binding.service_access.actual_anchor_grid_rc,'binding_service_door',1e-5);
  return {key:entry.key,entry,manifest,binding,sidecar,placementRoot,assetRoot,visibleMeshes:meshes,registrySha256:CITY_V3_ACCEPTED_REGISTRY_SHA256,manifestSha256:mf.sha256,sidecarSha256:sf.sha256,assetSha256:af.sha256,correctedBox,installed:false};
};

export async function loadCityV3AcceptedCandidates({THREE,params,hostname=location.hostname,keys=CITY_V3_ACCEPTED_KEYS}={}){
  assert(THREE?.Box3&&THREE?.Group,'three_api','Three.js API missing');
  assert(cityV3BuildingPreviewGate(params,hostname),'preview_gate','explicit local Stage A gate is closed');
  assert(Array.isArray(keys)&&keys.length>0&&keys.every(key=>CITY_V3_ACCEPTED_KEYS.includes(key))&&new Set(keys).size===keys.length,'keys','unsupported or duplicate keys');
  const rf=await exactFile(CITY_V3_ACCEPTED_REGISTRY_URL,1552,CITY_V3_ACCEPTED_REGISTRY_SHA256,'registry'),registry=json(rf.body,'registry');
  const br=registry.bindings,bf=await exactFile(new URL(br.url,CITY_V3_ACCEPTED_REGISTRY_URL),br.bytes,br.sha256,'bindings'),bindings=json(bf.body,'bindings');
  assert(bindings?.schema===BINDINGS_SCHEMA&&bindings?.revision===1,'bindings_schema','unsupported MAIN binding schema');
  assert(bindings?.planning_authority?.superseded_v2?.status==='superseded_do_not_apply','bindings_v2','v2 must remain superseded');
  assert(lower(bindings?.planning_authority?.superseding_v3?.contract_sha256)==='9a8ee4a98062c0b1e171cafc5552cfd1d65e91d2da167ee45f282c47a83787f7'&&bindings?.planning_authority?.superseding_v3?.status==='stage_a_topology_only_main_native_runtime_rollout_ready_false','bindings_v3','v3 topology status mismatch');
  assert(bindings?.planning_authority?.runtime_transform_authority==='this_main_native_binding_after_current_main_preflight_only','bindings_authority','MAIN preview transform authority missing');
  assert((bindings.bindings||[]).length===2,'bindings_count','expected exactly two MAIN bindings');
  const {GLTFLoader}=await import('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/loaders/GLTFLoader.js/+esm');
  assert(typeof GLTFLoader==='function','gltf_loader','GLTFLoader export missing');const loader=new GLTFLoader();
  const settled=await Promise.allSettled(keys.map(key=>{
    const entry=resolveCityV3AcceptedAsset(registry,key),matches=bindings.bindings.filter(binding=>binding.key===key);
    assert(matches.length===1,'binding_cardinality',`expected one ${key} MAIN binding`);
    return prepareCandidate({THREE,loader,entry,binding:matches[0],registryUrl:CITY_V3_ACCEPTED_REGISTRY_URL});
  }));
  const candidates=[],errors=[];settled.forEach((result,index)=>result.status==='fulfilled'?candidates.push(result.value):errors.push({key:keys[index],error:result.reason}));
  return {candidates,errors,registrySha256:rf.sha256,bindingsSha256:bf.sha256};
}

export function installCityV3AcceptedCandidate(candidate,{THREE,scene,bridge,renderer,originR,originC,worldScale}={}){
  assert(candidate&&!candidate.installed&&CITY_V3_ACCEPTED_KEYS.includes(candidate.key),'install_candidate','candidate missing or already installed');
  assert(scene?.isScene&&bridge&&typeof bridge.rollbackCityV3AcceptedBuildingPreview==='function'&&renderer?.domElement,'install_runtime','scene, bridge, rollback API or renderer missing');
  assert(Number.isFinite(+originR)&&Number.isFinite(+originC)&&Number.isFinite(+worldScale)&&+worldScale>=3&&+worldScale<=5,'install_world_scale','runtime world scale outside 3..5');
  const binding=candidate.binding,ratio=+worldScale/4.1;
  candidate.placementRoot.scale.setScalar(ratio);
  candidate.placementRoot.position.set((binding.center_grid_rc[1]-originC)*worldScale,0,(binding.center_grid_rc[0]-originR)*worldScale);
  scene.add(candidate.placementRoot);candidate.placementRoot.updateMatrixWorld(true);
  const registered=candidate.placementRoot.parent===scene&&scene.getObjectByName(candidate.placementRoot.name)===candidate.placementRoot;
  const worldBox=boxValues(new THREE.Box3().setFromObject(candidate.placementRoot)),centerX=(worldBox.min[0]+worldBox.max[0])*.5,centerZ=(worldBox.min[2]+worldBox.max[2])*.5;
  const eligible=registered&&candidate.visibleMeshes.length>0&&near(centerX,(binding.center_grid_rc[1]-originC)*worldScale)&&near(centerZ,(binding.center_grid_rc[0]-originR)*worldScale);
  const receipt={key:candidate.key,instanceId:binding.instance_id,legacyStructureId:binding.legacy_structure_id,registrySha256:candidate.registrySha256,manifestSha256:candidate.manifestSha256,sidecarSha256:candidate.sidecarSha256,glbSha256:candidate.assetSha256,bindingsSha256:candidate.manifest.authority.main_native_bindings_sha256,loaded:true,registered,eligible,visibleMeshCount:candidate.visibleMeshes.length,centerGridRC:[...binding.center_grid_rc],uniformAssetScale:binding.uniform_asset_scale,yawDeg:binding.yaw_deg,runtimeWorldScale:+worldScale,runtimeScaleRatio:ratio,dimensionsM:[...candidate.correctedBox.dimensions],doorAnchorGridRC:[...binding.public_door.actual_anchor_grid_rc],serviceAnchorGridRC:[...binding.service_access.actual_anchor_grid_rc]};
  let activation=null;
  try{
    assert(eligible,'install_eligibility','scene registration or world transform failed');
    activation=bridge.activateCityV3AcceptedBuildingPreview?.(receipt);assert(activation?.ok===true&&activation?.active===candidate.key&&activation?.rollbackToken,'install_activation',activation?.reason||'world activation rejected');
    candidate.installed=true;candidate.placementRoot.userData.cityV3Building=true;candidate.placementRoot.userData.cityV3Key=candidate.key;
    renderer.domElement.dataset.cityV3AcceptedBuildings=[...(renderer.domElement.dataset.cityV3AcceptedBuildings||'').split(',').filter(Boolean),candidate.key].join(',');
    return Object.assign(candidate,{activation,receipt,worldBox});
  }catch(error){
    if(activation?.rollbackToken){
      let rollback;
      try{rollback=bridge.rollbackCityV3AcceptedBuildingPreview(activation.rollbackToken);assert(rollback?.ok===true&&rollback?.rolledBack===candidate.key,'install_rollback','world rollback rejected');}
      catch(rollbackError){candidate.installed=true;const fatal=new CityV3AcceptedBuildingError('install_rollback',rollbackError?.message||'world rollback failed');fatal.cause=error;throw fatal;}
    }
    scene.remove(candidate.placementRoot);candidate.installed=false;throw error;
  }
}

export function rollbackCityV3AcceptedCandidate(instance,{scene,bridge,renderer}={}){
  assert(instance?.installed&&CITY_V3_ACCEPTED_KEYS.includes(instance.key),'rollback_candidate','installed instance missing');
  assert(scene?.isScene&&typeof bridge?.rollbackCityV3AcceptedBuildingPreview==='function','rollback_runtime','scene or rollback API missing');
  const token=instance.activation?.rollbackToken;assert(token,'rollback_token','activation rollback token missing');
  const rollback=bridge.rollbackCityV3AcceptedBuildingPreview(token);assert(rollback?.ok===true&&rollback?.rolledBack===instance.key,'rollback_activation',rollback?.reason||'world rollback rejected');
  scene.remove(instance.placementRoot);instance.installed=false;
  try{if(renderer?.domElement?.dataset)renderer.domElement.dataset.cityV3AcceptedBuildings=(renderer.domElement.dataset.cityV3AcceptedBuildings||'').split(',').filter(key=>key&&key!==instance.key).join(',');}catch(_error){}
  return rollback;
}
