const RAIL_SCHEMA='regional-rail-runtime-slice/1.0.0';
const BINDING_SCHEMA='regional-rail-main-native-binding/1.0.0';
const TIMETABLE_SCHEMA='regional-rail-runtime-timetable/1.0.0';
const SHA256=/^[a-f0-9]{64}$/;

export const CITY_V3_RAIL_FILES=Object.freeze({
  contract:Object.freeze({url:new URL('./v1/runtime_slice.contract.json',import.meta.url),bytes:4179,sha256:'bdab0b2c8ffc9243a86b1ca01dde7abfb4a3ec11c30957eb13899a4fc6e9fee2'}),
  binding:Object.freeze({url:new URL('./v1/runtime_slice.main_binding.json',import.meta.url),bytes:183287,sha256:'6667e473509717d50aa848d14c8781c17345ee04efd27c10353f9ff3169258d2'}),
  timetable:Object.freeze({url:new URL('./v1/runtime_slice.timetable.json',import.meta.url),bytes:1140,sha256:'2ef53e0badb2d87921b976aa3dc6e5e3a51fe2f1c0f0f90caaae451c68e80cb4'}),
  asset:Object.freeze({url:new URL('./v1/regional_train_and_track_tiles_v1.glb',import.meta.url),bytes:5981212,sha256:'fb63b5303a9c16ac94f7a52896ab30123ad6014aa675dc87bb7cca6df032c9cc'}),
});

export class CityV3RailAssetError extends Error{
  constructor(code,message){super(`${code}: ${message}`);this.name='CityV3RailAssetError';this.code=code;}
}
const fail=(code,message)=>{throw new CityV3RailAssetError(code,message);};
const assert=(condition,code,message)=>{if(!condition)fail(code,message);};
const lower=value=>String(value||'').toLowerCase();
const near=(a,b,e=1e-6)=>Number.isFinite(+a)&&Math.abs(+a-+b)<=e;

export function cityV3RailPreviewGate(params,hostname=location.hostname){
  const query=params instanceof URLSearchParams?params:new URLSearchParams(params||'');
  return (hostname==='127.0.0.1'||hostname==='localhost')&&query.get('preview')==='1'&&query.get('previewcityv3')==='stage-a'&&query.get('cityv3rail')==='1';
}

export async function cityV3RailSha256(bytes){
  const view=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes);
  const digest=await crypto.subtle.digest('SHA-256',view);
  return [...new Uint8Array(digest)].map(value=>value.toString(16).padStart(2,'0')).join('');
}

async function exactFile(record,code){
  assert(Number.isInteger(record.bytes)&&record.bytes>0,`${code}_bytes_contract`,'invalid byte count');
  assert(SHA256.test(lower(record.sha256)),`${code}_sha_contract`,'invalid SHA-256');
  const response=await fetch(record.url,{cache:'no-store',credentials:'same-origin'});
  assert(response.ok,`${code}_fetch`,`${response.status} ${response.statusText}`);
  const body=new Uint8Array(await response.arrayBuffer());
  assert(body.byteLength===record.bytes,`${code}_bytes`,`${body.byteLength} != ${record.bytes}`);
  const sha256=await cityV3RailSha256(body);
  assert(sha256===record.sha256,`${code}_sha`,`${sha256} != ${record.sha256}`);
  return {body,sha256};
}

function json(body,code){try{return JSON.parse(new TextDecoder().decode(body));}catch(error){fail(`${code}_json`,error?.message||'invalid JSON');}}

export function parseCityV3RailGlbJson(bytes){
  const view=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes),data=new DataView(view.buffer,view.byteOffset,view.byteLength);
  assert(view.byteLength>=20&&data.getUint32(0,true)===0x46546c67,'glb_magic','not binary glTF');
  assert(data.getUint32(4,true)===2&&data.getUint32(8,true)===view.byteLength,'glb_header','invalid glTF header');
  let offset=12,jsonChunk=null;
  while(offset+8<=view.byteLength){const length=data.getUint32(offset,true),type=data.getUint32(offset+4,true);offset+=8;assert(offset+length<=view.byteLength,'glb_chunk','chunk exceeds file');if(type===0x4e4f534a)jsonChunk=view.subarray(offset,offset+length);offset+=length;}
  assert(jsonChunk,'glb_json','JSON chunk missing');return json(jsonChunk,'glb');
}

function validateContracts(contract,binding,timetable){
  assert(contract?.schema===RAIL_SCHEMA,'contract_schema','unsupported rail contract');
  assert(binding?.schema===BINDING_SCHEMA,'binding_schema','unsupported MAIN-native binding');
  assert(timetable?.schema===TIMETABLE_SCHEMA,'timetable_schema','unsupported timetable');
  assert(contract.classification==='dev-only runtime integration proof; not a finished game','contract_classification','slice must remain development-only');
  assert(contract.trackGraph?.bindingRouteId==='MAIN-NATIVE-SOUTH-COAST-RL-01'&&binding.route?.id===contract.trackGraph.bindingRouteId,'route_identity','route binding mismatch');
  assert(binding.route.closed===true&&near(binding.route.lengthM,1062.88)&&binding.route.pointsRc?.length===12,'route_geometry','closed route geometry mismatch');
  assert(lower(contract.mainBinding?.sha256)===CITY_V3_RAIL_FILES.binding.sha256,'binding_hash_contract','contract points to a different binding');
  assert(lower(contract.sourceAsset?.sha256)===CITY_V3_RAIL_FILES.asset.sha256,'asset_hash_contract','contract points to a different GLB');
  assert(binding.map?.worldScaleMPerTile===2.8,'binding_scale','expected 2.8 metres per MAIN tile');
  assert(binding.stations?.length===8&&contract.stations?.length===8&&timetable.stops?.length===8,'station_count','expected exactly eight candidate stops');
  const ids=contract.stations.map(station=>station.id);
  assert(new Set(ids).size===8&&binding.stations.every((station,index)=>station.id===ids[index]&&near(station.progress,contract.stations[index].progress)),'station_binding','station ids/progress mismatch');
  assert(timetable.stops.every((stop,index)=>stop.stationId===ids[index]&&stop.nominalDwellMs===4000),'timetable_stops','timetable stop mismatch');
  const dwell=timetable.dwellProfile;
  assert(dwell?.openMs===400&&dwell.holdMs===3200&&dwell.closeMs===400&&dwell.nominalTotalMs===4000,'dwell_profile','exact 4.0 second dwell missing');
  assert(contract.stationPlatform?.clearLengthM===64&&contract.consist?.lengthM===55.2&&contract.stationPlatform.clearLengthM>=contract.consist.lengthM,'platform_clearance','full consist clearance missing');
  assert(contract.consist.headAlignmentM===27.6&&contract.consist.tailAlignmentM===-27.6&&Math.max(Math.abs(contract.consist.headAlignmentM),Math.abs(contract.consist.tailAlignmentM))<=contract.stationPlatform.clearLengthM/2,'platform_alignment','head/tail alignment falls outside platform');
  assert(binding.protectedCrossings?.length===2&&binding.protectedCrossings.every(crossing=>crossing.roadCarInterlock===true),'crossing_binding','protected crossing interlock missing');
  assert(binding.geometry?.preserve?.includes('police')&&binding.geometry.preserve.includes('premium_red_suspension_bridge'),'preserve_contract','police or red bridge preservation missing');
}

function rawNodeIndex(glb){
  const byName=new Map();(glb.nodes||[]).forEach((node,index)=>{if(!node?.name)return;const found=byName.get(node.name)||[];found.push(index);byName.set(node.name,found);});return byName;
}

function vector(object){return [object.x,object.y,object.z];}
function boxValues(THREE,object){const box=new THREE.Box3().setFromObject(object),size=new THREE.Vector3(),center=new THREE.Vector3();box.getSize(size);box.getCenter(center);return {center:vector(center),size:vector(size)};}

export async function loadCityV3RailCandidate({THREE,params,hostname=location.hostname}={}){
  assert(THREE?.Box3&&THREE?.Group,'three_api','Three.js API missing');
  assert(cityV3RailPreviewGate(params,hostname),'preview_gate','explicit local Stage A rail gate is closed');
  const [contractFile,bindingFile,timetableFile,assetFile]=await Promise.all([
    exactFile(CITY_V3_RAIL_FILES.contract,'contract'),exactFile(CITY_V3_RAIL_FILES.binding,'binding'),
    exactFile(CITY_V3_RAIL_FILES.timetable,'timetable'),exactFile(CITY_V3_RAIL_FILES.asset,'asset'),
  ]);
  const contract=json(contractFile.body,'contract'),binding=json(bindingFile.body,'binding'),timetable=json(timetableFile.body,'timetable');
  validateContracts(contract,binding,timetable);
  const glbJson=parseCityV3RailGlbJson(assetFile.body),byName=rawNodeIndex(glbJson);
  const required=[contract.sourceAsset.requiredTrainRoot,...contract.consist.lodRoots,contract.sourceAsset.requiredCollisionRoot,...contract.collisionAndAuthority.requiredBodyNodes];
  for(const name of required)assert(byName.get(name)?.length===1,'glb_required_node',`${name} missing or duplicated`);
  const rawDoors=[...byName.keys()].filter(name=>name.startsWith('DoorPivot_'));
  assert(rawDoors.length===24&&rawDoors.every(name=>byName.get(name).length===1),'glb_door_pivots','expected 24 unique exported door pivots');
  const {GLTFLoader}=await import('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/loaders/GLTFLoader.js/+esm');
  const loader=new GLTFLoader(),buffer=assetFile.body.buffer.slice(assetFile.body.byteOffset,assetFile.body.byteOffset+assetFile.body.byteLength);
  const gltf=await new Promise((resolve,reject)=>loader.parse(buffer,new URL('.',CITY_V3_RAIL_FILES.asset.url).href,resolve,reject));
  const trainRoot=gltf?.scene?.getObjectByName?.(contract.sourceAsset.requiredTrainRoot);
  assert(trainRoot,'gltf_train_root','train root did not resolve');
  trainRoot.removeFromParent();trainRoot.position.set(0,0,0);trainRoot.rotation.set(0,0,0);trainRoot.scale.set(1,1,1);trainRoot.updateMatrixWorld(true);
  const lodRoots=contract.consist.lodRoots.map(name=>trainRoot.getObjectByName(name));
  assert(lodRoots.every(Boolean),'gltf_lods','runtime LOD roots missing');
  lodRoots.forEach((root,index)=>{root.visible=index===0;root.traverse(object=>{if(object.isMesh){object.castShadow=true;object.receiveShadow=true;object.frustumCulled=false;}});});
  const collisionRoot=trainRoot.getObjectByName(contract.sourceAsset.requiredCollisionRoot);
  const carRoots=[0,1,2].map(index=>{const object=lodRoots[0].getObjectByName(`TRAIN_LOD0_CAR0${index}_ROOT`);assert(object,'gltf_car_root',`car ${index} missing`);return {object,index,offsetM:object.position.x};});
  const collisionBodies=contract.collisionAndAuthority.requiredBodyNodes.map(name=>{const object=collisionRoot?.getObjectByName(name);assert(object,'gltf_collision_body',`${name} missing`);return {name,...boxValues(THREE,object)};});
  collisionRoot.traverse(object=>{if(object.isMesh)object.visible=false;});
  const doorPivots=[];lodRoots[0].traverse(object=>{if(!object.name.startsWith('DoorPivot_'))return;const position=new THREE.Vector3();object.getWorldPosition(position);doorPivots.push({name:object.name,object,local:vector(position),side:object.name.includes('_L_')?1:-1,direction:object.name.endsWith('_A')?1:-1,baseRotationY:object.rotation.y});});
  assert(doorPivots.length===24,'gltf_door_pivots',`resolved ${doorPivots.length} door pivots`);
  const visibleMeshes=[];trainRoot.traverse(object=>{if(object.isMesh&&object.visible!==false)visibleMeshes.push(object);});
  assert(visibleMeshes.length>0,'gltf_visible_train','train has no visible meshes');
  return {contract,binding,timetable,trainRoot,lodRoots,carRoots,collisionRoot,collisionBodies,doorPivots,visibleMeshes,
    hashes:{contract:contractFile.sha256,binding:bindingFile.sha256,timetable:timetableFile.sha256,asset:assetFile.sha256},installed:false};
}

function addBox(THREE,parent,material,size,position,yaw=0){const mesh=new THREE.Mesh(new THREE.BoxGeometry(...size),material);mesh.position.set(...position);mesh.rotation.y=yaw;mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);return mesh;}

function routePoint(binding,progress){
  const points=binding.route.pointsRc,wrapped=((progress%1)+1)%1,target=wrapped*binding.route.lengthTiles;let walked=0;
  for(let index=0;index<points.length;index++){const a=points[index],b=points[(index+1)%points.length],length=Math.hypot(b.r-a.r,b.c-a.c);if(target<=walked+length||index===points.length-1){const t=length?Math.max(0,Math.min(1,(target-walked)/length)):0;return {r:a.r+(b.r-a.r)*t,c:a.c+(b.c-a.c)*t,dr:length?(b.r-a.r)/length:0,dc:length?(b.c-a.c)/length:1};}walked+=length;}
  return {r:points[0].r,c:points[0].c,dr:0,dc:1};
}
export function cityV3RailPlatformPose(binding,station){
  const sample=routePoint(binding,station.progress),side=station.platformSide==='L'?1:-1,offset=side*5.25/binding.map.worldScaleMPerTile;
  return {r:station.r+sample.dc*offset,c:station.c-sample.dr*offset,yaw:Math.atan2(-sample.dr,sample.dc),side};
}

export function installCityV3RailCandidate(candidate,{THREE,scene,bridge,renderer,originR,originC,worldScale}={}){
  assert(candidate&&!candidate.installed,'install_candidate','candidate missing or already installed');
  assert(scene?.isScene&&bridge&&renderer?.domElement,'install_runtime','scene, bridge or renderer missing');
  const root=new THREE.Group();root.name='CITY_V3_RAIL_STAGE_A_ROOT';
  const scale=worldScale/candidate.binding.map.worldScaleMPerTile,toWorld=(r,c,y=0)=>[(c-originC)*worldScale,y,(r-originR)*worldScale];
  const mats={ballast:new THREE.MeshStandardMaterial({color:0x6c665d,roughness:.96}),rail:new THREE.MeshStandardMaterial({color:0x30383b,roughness:.38,metalness:.48}),sleeper:new THREE.MeshStandardMaterial({color:0x594536,roughness:.9}),platform:new THREE.MeshStandardMaterial({color:0xbeb5a5,roughness:.92}),edge:new THREE.MeshStandardMaterial({color:0xe7bc55,roughness:.76}),signal:new THREE.MeshStandardMaterial({color:0xb6473d,roughness:.55,emissive:0x54110e,emissiveIntensity:.7})};
  const points=candidate.binding.route.pointsRc,sleeperTransforms=[];
  for(let index=0;index<points.length;index++){
    const a=points[index],b=points[(index+1)%points.length],dr=b.r-a.r,dc=b.c-a.c,lengthTiles=Math.hypot(dr,dc);if(lengthTiles<1e-6)continue;
    const yaw=Math.atan2(-dr,dc),center=toWorld((a.r+b.r)/2,(a.c+b.c)/2,.08*scale),length=lengthTiles*worldScale;
    addBox(THREE,root,mats.ballast,[length,.24*scale,2.5*scale],center,yaw);
    const normal={r:dc/lengthTiles,c:-dr/lengthTiles};
    for(const side of [-1,1]){const offset=side*candidate.contract.trackGraph.railGaugeM/2/candidate.binding.map.worldScaleMPerTile;addBox(THREE,root,mats.rail,[length,.18*scale,.13*scale],toWorld((a.r+b.r)/2+normal.r*offset,(a.c+b.c)/2+normal.c*offset,.27*scale),yaw);}
    const sleepers=Math.max(1,Math.floor(lengthTiles*candidate.binding.map.worldScaleMPerTile/.9));for(let n=0;n<sleepers;n++){const t=(n+.5)/sleepers;sleeperTransforms.push({position:toWorld(a.r+dr*t,a.c+dc*t,.12*scale),yaw});}
  }
  const sleeperGeometry=new THREE.BoxGeometry(.17*scale,.13*scale,3.35*scale),sleeperBatch=new THREE.InstancedMesh(sleeperGeometry,mats.sleeper,sleeperTransforms.length),sleeperMatrix=new THREE.Matrix4(),sleeperPosition=new THREE.Vector3(),sleeperRotation=new THREE.Quaternion(),sleeperScale=new THREE.Vector3(1,1,1),sleeperEuler=new THREE.Euler();
  sleeperTransforms.forEach((entry,index)=>{sleeperPosition.set(...entry.position);sleeperEuler.set(0,entry.yaw,0);sleeperRotation.setFromEuler(sleeperEuler);sleeperMatrix.compose(sleeperPosition,sleeperRotation,sleeperScale);sleeperBatch.setMatrixAt(index,sleeperMatrix);});sleeperBatch.instanceMatrix.needsUpdate=true;sleeperBatch.castShadow=sleeperBatch.receiveShadow=true;sleeperBatch.name='CITY_V3_RAIL_SLEEPERS_BATCH';root.add(sleeperBatch);
  const stationRoots=[],signals=[];
  for(const station of candidate.binding.stations){
    const pose=cityV3RailPlatformPose(candidate.binding,station),side=pose.side;
    const stationRoot=new THREE.Group();stationRoot.name=`${station.id}_STAGE_A_PLATFORM`;stationRoot.position.set(...toWorld(pose.r,pose.c,.28*scale));stationRoot.rotation.y=pose.yaw;
    addBox(THREE,stationRoot,mats.platform,[candidate.contract.stationPlatform.clearLengthM*scale,.52*scale,candidate.contract.stationPlatform.widthM*scale],[0,0,0]);
    addBox(THREE,stationRoot,mats.edge,[candidate.contract.stationPlatform.clearLengthM*scale,.12*scale,.38*scale],[0,.34*scale,-side*2.49*scale]);
    for(const marker of [candidate.contract.consist.tailAlignmentM,candidate.contract.consist.headAlignmentM])addBox(THREE,stationRoot,mats.edge,[.18*scale,.08*scale,1.05*scale],[marker*scale,.36*scale,-side*2.05*scale]);
    for(const x of [-24,-8,8,24]){addBox(THREE,stationRoot,mats.rail,[.2*scale,3.2*scale,.2*scale],[x*scale,1.9*scale,side*.85*scale]);addBox(THREE,stationRoot,mats.platform,[10*scale,.18*scale,3.2*scale],[x*scale,3.52*scale,side*.85*scale]);}
    const signal=addBox(THREE,stationRoot,mats.signal.clone(),[.55*scale,.75*scale,.55*scale],[31.0*scale,2.1*scale,-side*2.2*scale]);signal.userData.stationId=station.id;signals.push(signal);
    stationRoots.push(stationRoot);root.add(stationRoot);
  }
  const crossingRoots=[];
  for(const crossing of candidate.binding.protectedCrossings){const sample=routePoint(candidate.binding,crossing.progress),crossingRoot=new THREE.Group();crossingRoot.name=crossing.id;crossingRoot.position.set(...toWorld(crossing.r,crossing.c,.1*scale));crossingRoot.rotation.y=Math.atan2(-sample.dr,sample.dc);const pivots=[];for(const side of [-1,1]){addBox(THREE,crossingRoot,mats.platform,[.28*scale,2.2*scale,.28*scale],[2.8*scale,1.1*scale,side*5.1*scale]);const pivot=new THREE.Group();pivot.position.set(2.8*scale,2.05*scale,side*5.1*scale);addBox(THREE,pivot,mats.signal,[6.2*scale,.18*scale,.18*scale],[-3*scale,0,0]);crossingRoot.add(pivot);pivots.push({pivot,side});}crossingRoot.userData.pivots=pivots;crossingRoots.push(crossingRoot);root.add(crossingRoot);}
  candidate.trainRoot.scale.setScalar(scale);root.add(candidate.trainRoot);scene.add(root);
  const receipt={routeId:candidate.binding.route.id,assetSha256:candidate.hashes.asset,bindingSha256:candidate.hashes.binding,contractSha256:candidate.hashes.contract,timetableSha256:candidate.hashes.timetable,stationCount:candidate.binding.stations.length,crossingCount:candidate.binding.protectedCrossings.length,visibleMeshCount:candidate.visibleMeshes.length,doorPivots:candidate.doorPivots.map(p=>({name:p.name,local:p.local,side:p.side})),collisionBodies:candidate.collisionBodies,registered:root.parent===scene,eligible:true};
  let activation=null;
  try{activation=bridge.activateCityV3RailPreview?.(receipt);assert(activation?.ok===true&&activation.rollbackToken,'world_activation',activation?.reason||'activation rejected');candidate.installed=true;candidate.root=root;candidate.stationRoots=stationRoots;candidate.crossingRoots=crossingRoots;candidate.signals=signals;candidate.scale=scale;candidate.activation=activation;renderer.domElement.dataset.cityV3RailActivation=`active:${candidate.binding.route.id}`;return candidate;}
  catch(error){if(activation?.rollbackToken)bridge.rollbackCityV3RailPreview?.(activation.rollbackToken);scene.remove(root);candidate.trainRoot.removeFromParent();throw error;}
}

export function updateCityV3RailCandidate(candidate,snapshot,{originR,originC,worldScale}={}){
  if(!candidate?.installed||!snapshot)return;
  const train=snapshot.position||routePoint(candidate.binding,snapshot.progress||0);candidate.trainRoot.position.set((train.c-originC)*worldScale,.34*candidate.scale,(train.r-originR)*worldScale);candidate.trainRoot.rotation.y=+train.yaw||0;
  if(train.cars?.length===3){
    // Car centers and collision poses come from the same world sampler.
    // Keep root translation for renderer diagnostics but rotate each car independently.
    candidate.trainRoot.rotation.y=0;
    for(const car of candidate.carRoots){const pose=train.cars.find(item=>item.name===`COLLISION_TRAIN_BODY_CAR0${car.index}`);if(!pose)continue;car.object.position.set((pose.c-train.c)*worldScale/candidate.scale,0,(pose.r-train.r)*worldScale/candidate.scale);car.object.rotation.y=pose.yaw;}
    // Couplers are authored relative to the old rigid middle carriage.
    // Hide them during articulation until flexible couplers are supplied.
    candidate.lodRoots[0].children.forEach(object=>{if(object.name.includes('_COUPLER_'))object.visible=false;});
  }
  candidate.activeLOD=0;candidate.lodReason='lod1-lod2-transform-validation-pending';
  const side=snapshot.platformSide==='L'?1:-1;
  for(const pivot of candidate.doorPivots){const active=snapshot.phase==='dwell'&&pivot.side===side;pivot.object.rotation.y=pivot.baseRotationY+(active?(+snapshot.doors?.amount||0)*pivot.direction*pivot.side*1.24:0);}
  candidate.crossingRoots.forEach((root,index)=>{const crossing=snapshot.crossings?.[index],closed=+crossing?.gateClosedAmount||0;root.userData.pivots.forEach(({pivot,side:pivotSide})=>{pivot.rotation.z=pivotSide*(1-closed)*Math.PI*.48;});});
  candidate.signals.forEach(signal=>{const red=snapshot.signals?.find(item=>item.stationId===signal.userData.stationId)?.aspect!=='green';signal.material.color.setHex(red?0xb6473d:0x58bd76);signal.material.emissive.setHex(red?0x54110e:0x154d27);});
}

export function rollbackCityV3RailCandidate(candidate,{scene,bridge,renderer}={}){
  assert(candidate?.installed&&candidate.activation?.rollbackToken,'rollback_candidate','installed rail candidate missing');
  const result=bridge.rollbackCityV3RailPreview?.(candidate.activation.rollbackToken);assert(result?.ok===true,'rollback_world',result?.reason||'world rollback rejected');scene.remove(candidate.root);candidate.installed=false;if(renderer?.domElement?.dataset)renderer.domElement.dataset.cityV3RailActivation='inactive:rolled-back';return result;
}
