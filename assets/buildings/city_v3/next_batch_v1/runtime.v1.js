// Frozen accepted business art. The host owns map preflight, door identity and
// addressed legacy removal. No THREE import and no mutation before all 3 load.
export const NEXT_BUILDING_KEYS=Object.freeze(['gun_shop@1','bookmaker@1','strip_club@1']);
export const NEXT_REGISTRY_SHA256='079d45b10c4e7df5715be95a2b9632dc3baaff0892015f6016e55c250686f85c';
const GROUND=Object.freeze({
  'gun_shop@1':{node:'Limestone armored plinth',min:[-7.825,0,-4.875],max:[7.825,1.1,4.975]},
  'bookmaker@1':{node:'Stone plinth',min:[-8,0,-4.9],max:[8,1.1,4.9]},
  'strip_club@1':{node:'Club_Platform',min:[-6.6,0,-5.1],max:[6.6,.44,5.1]},
});
const check=(ok,message)=>{if(!ok)throw new Error(`city-v3-next:${message}`);};
const abort=signal=>{if(signal?.aborted)throw new DOMException('Next buildings cancelled','AbortError');};
const vector=(a,b,label,tolerance=.015)=>check(a.length===b.length&&a.every((n,i)=>Number.isFinite(n)&&Math.abs(n-b[i])<=tolerance),`${label}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
const sha=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
const decode=bytes=>JSON.parse(new TextDecoder().decode(bytes));
function dispose(root){
  const geometry=new Set(),materials=new Set(),textures=new Set();
  root?.traverse(o=>{if(o.geometry)geometry.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])materials.add(m);});
  materials.forEach(m=>{Object.values(m).forEach(v=>{if(v?.isTexture)textures.add(v);});m.dispose();});
  textures.forEach(t=>t.dispose());geometry.forEach(g=>g.dispose());
}
export function nextLocalToGrid(binding,recenter,[x,,z]){
  const a=binding.yaw_deg*Math.PI/180,s=binding.uniform_asset_scale/4.1;
  x-=recenter[0];z-=recenter[2];
  return [binding.center_grid_rc[0]+(-x*Math.sin(a)+z*Math.cos(a))*s,
    binding.center_grid_rc[1]+(x*Math.cos(a)+z*Math.sin(a))*s];
}
function groundRect(binding,recenter,ground){
  const points=[ground.min[0],ground.max[0]].flatMap(x=>[ground.min[2],ground.max[2]].map(z=>nextLocalToGrid(binding,recenter,[x,0,z])));
  return {minR:Math.min(...points.map(p=>p[0])),maxR:Math.max(...points.map(p=>p[0])),minC:Math.min(...points.map(p=>p[1])),maxC:Math.max(...points.map(p=>p[1]))};
}
export function nextBuildingContract(binding,manifest){
  check(NEXT_BUILDING_KEYS.includes(binding.key)&&manifest.key===binding.key,'contract-key');
  const recenter=manifest.geometry.horizontal_center_xyz_m,ground=GROUND[binding.key];
  const access=(data,local)=>{
    const rc=nextLocalToGrid(binding,recenter,local);vector(rc,data.exact_anchor_grid_rc,'anchor-recenter',.00001);
    return {anchorR:rc[0],anchorC:rc[1],corridors:data.approach_segments_rect_grid_rc,
      roadProbe:{r:data.road_probe.grid_rc[0],c:data.road_probe.grid_rc[1]},routeGridRC:data.route_grid_rc};
  };
  return {key:binding.key,instanceId:binding.instance_id,assetSha256:binding.asset_sha256,
    legacyStructureId:binding.legacy.structure_id,legacyTileBounds:binding.legacy.tile_bounds,
    legacyTileIds:binding.legacy.tile_ids,legacyDoorId:binding.legacy.door.id,legacyDoor:binding.legacy.door,
    gameplayPoi:null,centerGridRC:binding.center_grid_rc,uniformAssetScale:binding.uniform_asset_scale,yawDeg:binding.yaw_deg,
    footprint:groundRect(binding,recenter,ground),clearanceFootprint:binding.footprint_rect_grid_rc,pad:binding.pad_rect_grid_rc,
    groundCollisionNode:ground.node,groundCollisionBoundsLocal:{min:ground.min,max:ground.max},
    door:{...access(binding.public_door,manifest.geometry.public_anchor_local_xyz_m),
      anchorRole:binding.key==='strip_club@1'?'accepted-front-approach':'authored-door-threshold',
      visibleThresholdGridRC:nextLocalToGrid(binding,recenter,binding.key==='strip_club@1'?[0,0,4.93]:manifest.geometry.public_anchor_local_xyz_m)},
    service:access(binding.service_access,manifest.geometry.service_anchor_local_xyz_m)};
}
function rawGLB(bytes){
  const view=new DataView(bytes);
  check(view.byteLength>=20&&view.getUint32(0,true)===0x46546c67&&view.getUint32(4,true)===2&&view.getUint32(8,true)===bytes.byteLength,'glb-header');
  const length=view.getUint32(12,true);check(view.getUint32(16,true)===0x4e4f534a&&length+20<=bytes.byteLength,'glb-json-chunk');
  const raw=decode(bytes.slice(20,20+length));
  // All inputs are self-contained GLBs: no unverified secondary network loads.
  check(!(raw.buffers||[]).some(b=>b.uri)&&!(raw.images||[]).some(b=>b.uri),'external-glb-resource');
  return raw;
}
export async function prepareCityV3NextBuildings({THREE,GLTFLoader,signal,fetchImpl=fetch}={}){
  check(THREE?.Group&&THREE?.Box3&&typeof GLTFLoader==='function','host-three-required');
  const exact=async(record,base=import.meta.url)=>{
    abort(signal);check(record.url.startsWith('./')&&!record.url.includes('..'),'relative-asset-url');
    const response=await fetchImpl(new URL(record.url,base),{signal,cache:'no-store',credentials:'same-origin'});
    check(response.ok,'asset-http');const bytes=await response.arrayBuffer();abort(signal);
    check(bytes.byteLength===record.bytes,'asset-bytes');check(await sha(bytes)===record.sha256,'asset-sha');abort(signal);return bytes;
  };
  const registry=decode(await exact({url:'./registry.v1.json',bytes:4184,sha256:NEXT_REGISTRY_SHA256}));
  check(registry.schema==='mafiozi.city-v3-next-building-asset-registry/v1'&&registry.entries.length===3,'registry-schema');
  const bindings=decode(await exact(registry.bindings_candidate));
  check(bindings.world_units_per_contract_cell_m===4.1&&bindings.atomic_apply_policy.all_three_assets_required===true,'binding-policy');
  const prepared=[];
  try{
    // Sequential decode limits transient memory while all 3 are staged together.
    for(const key of NEXT_BUILDING_KEYS){
      const entries=registry.entries.filter(e=>e.key===key),rows=bindings.bindings.filter(b=>b.key===key);
      check(entries.length===1&&rows.length===1,'binding-cardinality');
      const entry=entries[0],binding=rows[0];
      const [manifestBytes,sidecarBytes,bytes]=await Promise.all([exact(entry.manifest),exact(entry.sidecar),exact(entry.asset)]);
      const manifest=decode(manifestBytes),sidecar=decode(sidecarBytes);
      check(manifest.key===key&&manifest.asset.sha256===entry.asset.sha256&&binding.asset_sha256===entry.asset.sha256,'asset-identity');
      check(manifest.asset.sidecar_sha256===entry.sidecar.sha256&&sidecar,'sidecar-identity');
      check(manifest.provenance.origin==='project_generated'&&manifest.provenance.external_sources.length===0,'asset-provenance');
      const raw=rawGLB(bytes),gltf=await new GLTFLoader().parseAsync(bytes,new URL('.',new URL(entry.asset.url,import.meta.url)).href);
      const scene=gltf.scene;
      try{
        abort(signal);check(scene?.isObject3D&&gltf.parser?.associations,'parsed-scene');scene.updateMatrixWorld(true);
        // GLTFLoader sanitizes spaces/dots in names. Resolve via raw node index.
        const node=name=>{
          const indexes=[];(raw.nodes||[]).forEach((n,i)=>{if(n.name===name)indexes.push(i);});check(indexes.length===1,`node-${name}`);
          const found=[];scene.traverse(o=>{if(gltf.parser.associations.get(o)?.nodes===indexes[0])found.push(o);});
          check(found.length===1,`runtime-node-${name}`);return found[0];
        };
        const asset=manifest.geometry.root_node?node(manifest.geometry.root_node):scene;
        const box=new THREE.Box3().setFromObject(asset);
        vector(box.min.toArray(),manifest.geometry.raw_bounds_m.min_xyz,'raw-min');vector(box.max.toArray(),manifest.geometry.raw_bounds_m.max_xyz,'raw-max');
        for(const kind of ['public','service']){
          if(key==='strip_club@1'&&kind==='public'){
            // Frozen sidecar calls the front approach [0,0,5.7] a door node.
            // Actual two-leaf geometry is 0.77m behind it; validate both leaves
            // independently instead of passing that sidecar error through.
            vector(node('Entrance_Door').getWorldPosition(new THREE.Vector3()).toArray(),[.72,1.8,4.93],'strip-public-leaf-right');
            vector(node('Entrance_Door.001').getWorldPosition(new THREE.Vector3()).toArray(),[-.72,1.8,4.93],'strip-public-leaf-left');
            continue;
          }
          const expected=manifest.geometry[`${kind}_door_local_xyz_m`],object=node(manifest.geometry[`${kind}_door_node`]);
          vector(object.getWorldPosition(new THREE.Vector3()).toArray(),expected,`${kind}-actual-door`);
        }
        const ground=GROUND[key],groundBox=new THREE.Box3().setFromObject(node(ground.node));
        vector(groundBox.min.toArray(),ground.min,'ground-min');vector(groundBox.max.toArray(),ground.max,'ground-max');
        let meshCount=0;asset.traverse(o=>{if(o.isMesh){meshCount++;o.castShadow=true;o.receiveShadow=true;}});check(meshCount>0,'empty-building');
        const contract=nextBuildingContract(binding,manifest),root=new THREE.Group(),rotation=new THREE.Group();
        root.name=`CITY_V3_NEXT_${binding.instance_id}`;rotation.rotation.y=binding.yaw_deg*Math.PI/180;
        const center=manifest.geometry.horizontal_center_xyz_m,scale=binding.uniform_asset_scale;
        asset.position.add(new THREE.Vector3(-center[0]*scale,0,-center[2]*scale));asset.scale.multiplyScalar(scale);
        rotation.add(asset);root.add(rotation);root.updateMatrixWorld(true);
        prepared.push({root,contract,visibleMeshCount:meshCount});
      }catch(error){dispose(scene);throw error;}
    }
    return prepared;
  }catch(error){prepared.forEach(p=>dispose(p.root));throw error;}
}
export async function installCityV3NextBuildings(options={}){
  const {scene,bridge,originR,originC,worldScale,signal,renderer}=options;
  check(scene?.isScene&&typeof bridge?.activateCityV3NextBuilding==='function'&&typeof bridge?.rollbackCityV3NextBuilding==='function','host-transaction-api');
  check([originR,originC,worldScale].every(Number.isFinite)&&worldScale>0,'host-transform');
  const prepared=await prepareCityV3NextBuildings(options),diagnostics=renderer?.domElement?.dataset;
  let activation=null,disposed=false;
  const remove=()=>prepared.forEach(p=>{scene.remove(p.root);dispose(p.root);});
  try{
    abort(signal);
    prepared.forEach(({root,contract})=>{
      root.scale.setScalar(worldScale/4.1);
      root.position.set((contract.centerGridRC[1]-originC)*worldScale,0,(contract.centerGridRC[0]-originR)*worldScale);
      scene.add(root);root.updateMatrixWorld(true);
    });
    abort(signal);
    const receipt={schema:'mafiozi.next-buildings-runtime-receipt/v1',registrySha256:NEXT_REGISTRY_SHA256,
      buildings:prepared.map(p=>({...p.contract,loaded:true,registered:p.root.parent===scene,eligible:true,
        visibleMeshCount:p.visibleMeshCount,doorAnchorGridRC:[p.contract.door.anchorR,p.contract.door.anchorC],
        serviceAnchorGridRC:[p.contract.service.anchorR,p.contract.service.anchorC],runtimeWorldScale:worldScale}))};
    activation=bridge.activateCityV3NextBuilding(receipt);
    check(activation?.ok===true&&activation.rollbackToken,'activation-'+(activation?.reason||'rejected'));
    if(diagnostics){diagnostics.cityV3NextBuildings='active:3';diagnostics.cityV3NextBuildingsReceipt=JSON.stringify(receipt);}
    return {roots:prepared.map(p=>p.root),receipt,activation,
      dispose(){if(disposed)return;check(bridge.rollbackCityV3NextBuilding(activation.rollbackToken)?.ok===true,'rollback-refused');remove();disposed=true;if(diagnostics)diagnostics.cityV3NextBuildings='rolled-back';},
    };
  }catch(error){
    if(activation?.rollbackToken)check(bridge.rollbackCityV3NextBuilding(activation.rollbackToken)?.ok===true,'rollback-refused');
    remove();if(diagnostics)diagnostics.cityV3NextBuildings=`failed:${error.message}`;throw error;
  }
}
