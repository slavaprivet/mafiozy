import {markingPolygon,roadSignalPhase} from './city_road_dressing_plan.mjs';
/** Spatially batched paint and instanced street equipment, without local lights. */
export function createCityRoadDressing({THREE,plan,chunkSize=128}={}){
  if(!THREE||!plan?.markings)throw Error('City road dressing requires THREE and plan');
  const object=new THREE.Group();object.name='CityRoadDressing';const meshes=[],ownedGeometry=[],ownedMaterials=[];
  const C={stone:0xcdbd9e,brass:0xb79965,dark:0x233739,red:0xb83c3e,blue:0x285a83,white:0xf1eadb,black:0x1d292b,yellow:0xe4bc55};
  const materials={clay:new THREE.MeshStandardMaterial({color:0xffffff,roughness:.74,metalness:.04}),paint:new THREE.MeshStandardMaterial({color:0xe9e5d5,roughness:.9,metalness:0,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1}),warmPaint:new THREE.MeshStandardMaterial({color:0xe0bb68,roughness:.9,metalness:0,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1})};ownedMaterials.push(...Object.values(materials));
  const geometry={box:new THREE.BoxGeometry(1,1,1),cylinder:new THREE.CylinderGeometry(1,1,1,16),triangle:new THREE.CylinderGeometry(1,1,1,3),sphere:new THREE.SphereGeometry(1,12,8),ring:new THREE.TorusGeometry(1,.095,8,24)};ownedGeometry.push(...Object.values(geometry));
  const paintBuckets=new Map();for(const mark of plan.markings){const key=`${Math.floor(mark.x/chunkSize)},${Math.floor(mark.z/chunkSize)}:${mark.color}`,vertices=paintBuckets.get(key)||[];const p=markingPolygon(mark);for(const i of[0,1,2,0,2,3])vertices.push(p[i][0],mark.y,p[i][1]);paintBuckets.set(key,vertices)}
  for(const [key,vertices]of paintBuckets){const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));g.computeVertexNormals();g.computeBoundingBox();g.computeBoundingSphere();ownedGeometry.push(g);const mesh=new THREE.Mesh(g,key.endsWith(':warm')?materials.warmPaint:materials.paint);mesh.name='RoadPaint:'+key;mesh.receiveShadow=true;object.add(mesh);meshes.push(mesh)}
  const buckets=new Map(),parent=new THREE.Matrix4(),local=new THREE.Matrix4(),matrix=new THREE.Matrix4(),position=new THREE.Vector3(),scale=new THREE.Vector3(),rotation=new THREE.Quaternion(),euler=new THREE.Euler(),color=new THREE.Color();let current;
  function part(shape,p,s,tint,angles=[0,0,0]){const key=`${Math.floor(current.x/chunkSize)},${Math.floor(current.z/chunkSize)}:${shape}`;if(!buckets.has(key))buckets.set(key,[]);local.compose(position.fromArray(p),rotation.setFromEuler(euler.fromArray(angles)),scale.fromArray(s));matrix.multiplyMatrices(parent,local);buckets.get(key).push({matrix:matrix.clone(),tint})}
  function stroke(a,b,width=.035,tint=C.black,z=.09){const dx=b[0]-a[0],dy=b[1]-a[1];part('box',[(a[0]+b[0])/2,(a[1]+b[1])/2,z],[width,Math.hypot(dx,dy),.026],tint,[0,0,-Math.atan2(dx,dy)])}
  function signFace(kind,y=2.5,size=1){
    const front=.10;
    if(kind==='speed'){
      part('cylinder',[0,y,0],[.46*size,.07,.46*size],C.white,[Math.PI/2,0,0]);part('ring',[0,y,.048],[.418*size,.418*size,.45],C.red);
      const s=size;for(const [a,b]of[[[-.20,.20],[-.20,-.01]],[[-.20,-.01],[.015,-.01]],[[-.035,.20],[-.035,-.22]],[[.11,.2],[.26,.2]],[[.11,.2],[.11,-.22]],[[.26,.2],[.26,-.22]],[[.11,-.22],[.26,-.22]]])stroke([a[0]*s,y+a[1]*s],[b[0]*s,y+b[1]*s],.044*s,C.black,front);
    }else if(kind==='yield'){
      part('triangle',[0,y,0],[.58*size,.08,.58*size],C.red,[Math.PI/2,0,0]);part('triangle',[0,y+.035*size,.06],[.435*size,.023,.435*size],C.white,[Math.PI/2,0,0]);
    }else if(kind==='priority'){
      part('box',[0,y,0],[.66*size,.66*size,.06],C.white,[0,0,Math.PI/4]);part('box',[0,y,.045],[.53*size,.53*size,.045],C.yellow,[0,0,Math.PI/4]);
    }else if(kind==='rail'){const dir=current.direction||1;
      part('box',[0,y,0],[1.25*size,.68*size,.07],C.white);part('box',[0,y,.045],[1.15*size,.58*size,.025],C.blue);
      part('box',[-.23*size*dir,y,front],[.36*size,.29*size,.028],C.white);for(const x of[-.32,-.14])part('sphere',[x*size*dir,y-.18*size,front],[.053*size,.053*size,.025],C.white);part('box',[-.23*size*dir,y+.03*size,front+.025],[.24*size,.11*size,.02],C.blue);
      stroke([.07*size*dir,y],[.43*size*dir,y],.045*size,C.white,front);stroke([.30*size*dir,y+.12*size],[.43*size*dir,y],.045*size,C.white,front);stroke([.30*size*dir,y-.12*size],[.43*size*dir,y],.045*size,C.white,front);
    }else{
      part('box',[0,y,0],[.82*size,.82*size,.065],C.white);part('box',[0,y,.045],[.71*size,.71*size,.025],C.blue);
      // Standard pedestrian pictogram; the white crossing remains readable at street scale.
      part('sphere',[.04*size,y+.21*size,front],[.062*size,.062*size,.027],C.white);
      for(const [a,b]of[[[.02,.13],[-.04,-.06]],[[-.04,-.06],[-.18,-.24]],[[-.04,-.06],[.13,-.23]],[[.0,.08],[-.17,.0]],[[.0,.08],[.16,.01]]])stroke([a[0]*size,y+a[1]*size],[b[0]*size,y+b[1]*size],.052*size,C.white,front);
      for(const x of[-.24,0,.24])part('box',[x*size,y-.3*size,front],[.14*size,.035*size,.024],C.white);
    }
  }
  for(const item of [...plan.signs,...plan.signals]){current=item;parent.compose(position.set(item.x,item.y,item.z),rotation.setFromAxisAngle(new THREE.Vector3(0,1,0),item.yaw),scale.set(1,1,1));
    const signal=item.kind==='traffic_signal',height=signal?3.4:2.7;part('cylinder',[0,height/2,0],[.066,height,.066],C.dark);part('cylinder',[0,.09,0],[.20,.18,.20],C.stone);part('cylinder',[0,.29,0],[.085,.09,.085],C.brass);
    if(signal){part('box',[0,3.15,.08],[.40,1.08,.29],C.dark);part('box',[0,3.15,-.082],[.32,.99,.025],C.brass);for(const y of[3.47,3.15,2.83]){part('cylinder',[0,y,.243],[.134,.06,.134],C.black,[Math.PI/2,0,0]);part('box',[0,y+.15,.29],[.32,.042,.28],C.dark)}if(item.crosswalk)signFace('crosswalk',2.12,.75)}else signFace(item.kind,2.5,item.faceScale??1);
  }
  // All sign/equipment pieces use the same clay shader, but were previously
  // split into a separate draw for every spatial bucket.  Keep those exact
  // bucket spheres for range culling, while put their immutable instances into
  // one BatchedMesh per primitive shape.  This retains every sign, its colour,
  // shadows and the old 360m cut-off; it only removes repeated material binds.
  const equipmentGroups=[],equipmentTotals=new Map();
  for(const [key,parts]of buckets){
    const shape=key.split(':').at(-1),probe=new THREE.InstancedMesh(geometry[shape],materials.clay,parts.length);
    for(let i=0;i<parts.length;i++)probe.setMatrixAt(i,parts[i].matrix);
    probe.computeBoundingSphere();const group={key,shape,parts,sphere:probe.boundingSphere?.clone()||null,visible:null,ids:[]};probe.dispose();
    equipmentGroups.push(group);equipmentTotals.set(shape,(equipmentTotals.get(shape)||0)+parts.length);
  }
  const batchedEquipment=new Map();
  if(THREE.BatchedMesh){
    for(const [shape,total]of equipmentTotals){
      const source=geometry[shape],vertices=source.attributes.position.count,indices=source.index?.count||vertices*2,mesh=new THREE.BatchedMesh(total,vertices,indices,materials.clay),geometryId=mesh.addGeometry(source);
      mesh.name='RoadEquipment_Batched:'+shape;mesh.userData.roadEquipmentBatched=true;mesh.userData.roadEquipmentInstances=total;mesh.castShadow=true;mesh.receiveShadow=true;mesh.visible=false;object.add(mesh);meshes.push(mesh);batchedEquipment.set(shape,{mesh,geometryId,visibleInstances:0});
    }
    for(const group of equipmentGroups){
      const batch=batchedEquipment.get(group.shape);
      for(const part of group.parts){const id=batch.mesh.addInstance(batch.geometryId);batch.mesh.setMatrixAt(id,part.matrix);batch.mesh.setColorAt(id,color.setHex(part.tint));group.ids.push(id);}
    }
    for(const batch of batchedEquipment.values())batch.mesh.computeBoundingSphere();
  }else{
    // Three r180 is required by /walk and has BatchedMesh.  The small fallback
    // keeps the same picture for isolated older renderer tests.
    for(const group of equipmentGroups){const mesh=new THREE.InstancedMesh(geometry[group.shape],materials.clay,group.parts.length);for(let i=0;i<group.parts.length;i++){mesh.setMatrixAt(i,group.parts[i].matrix);mesh.setColorAt(i,color.setHex(group.parts[i].tint))}mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.needsUpdate=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();mesh.name='RoadEquipment:'+group.key;mesh.castShadow=true;mesh.receiveShadow=true;object.add(mesh);meshes.push(mesh);group.mesh=mesh;}
  }
  const glowGeometry=new THREE.SphereGeometry(1,12,8);ownedGeometry.push(glowGeometry);const glowMeshes={};
  for(const [phase,tint]of Object.entries({red:0xed433d,amber:0xffbd43,green:0x69d986})){const material=new THREE.MeshStandardMaterial({color:tint,emissive:tint,emissiveIntensity:1.6,roughness:.32});ownedMaterials.push(material);const mesh=new THREE.InstancedMesh(glowGeometry,material,plan.signals.length);mesh.name='TrafficBulbs:'+phase;mesh.frustumCulled=false;glowMeshes[phase]=mesh;object.add(mesh);meshes.push(mesh)}
  let time=0,previous=[],lastFocusX=NaN,lastFocusZ=NaN,lastHadFocus=null;const up=new THREE.Vector3(0,1,0);
  function updateBatchedEquipment(focus,hasFocus){
   if(!batchedEquipment.size)return;
   const changed=new Set();
   for(const group of equipmentGroups){
    const sphere=group.sphere,show=!hasFocus||!sphere||Math.hypot(sphere.center.x-focus.x,sphere.center.z-focus.z)<360+sphere.radius;
    if(group.visible===show)continue;group.visible=show;const batch=batchedEquipment.get(group.shape);for(const id of group.ids)batch.mesh.setVisibleAt(id,show);batch.visibleInstances+=show?group.ids.length:-group.ids.length;changed.add(batch);
   }
   for(const batch of changed)batch.mesh.visible=batch.visibleInstances>0;
  }
  function update(dt=0,{focus=null,time:absoluteTime}={}){time=Number.isFinite(absoluteTime)?absoluteTime:time+Math.max(0,Number.isFinite(dt)?dt:0);
   // Road placement is immutable after construction.  The old loop repeated
   // the same distance comparison for every static road mesh at idle; cache
   // only an identical focus point.  A moving player still takes the exact
   // legacy visibility path in the very next frame.
   const hasFocus=Number.isFinite(focus?.x)&&Number.isFinite(focus?.z);
   if(lastHadFocus!==hasFocus||hasFocus&&(focus.x!==lastFocusX||focus.z!==lastFocusZ)){
    for(const mesh of meshes){if(mesh.name.startsWith('TrafficBulbs:')||mesh.userData.roadEquipmentBatched)continue;const sphere=mesh.boundingSphere||mesh.geometry.boundingSphere;mesh.visible=!hasFocus||!sphere||Math.hypot(sphere.center.x-focus.x,sphere.center.z-focus.z)<360+sphere.radius}
    updateBatchedEquipment(focus,hasFocus);
    lastHadFocus=hasFocus;lastFocusX=hasFocus?focus.x:NaN;lastFocusZ=hasFocus?focus.z:NaN;
   }
   let changed=false;for(let i=0;i<plan.signals.length;i++){const signal=plan.signals[i],phase=roadSignalPhase(time,signal.axis,signal.offset);if(previous[i]===phase)continue;previous[i]=phase;changed=true;for(const [name,mesh]of Object.entries(glowMeshes)){const y=name==='red'?3.47:name==='amber'?3.15:2.83;position.set(signal.x+Math.sin(signal.yaw)*.285,signal.y+y,signal.z+Math.cos(signal.yaw)*.285);rotation.setFromAxisAngle(up,signal.yaw);scale.set(.103,.103,.044).multiplyScalar(name===phase?1:0);matrix.compose(position,rotation,scale);mesh.setMatrixAt(i,matrix)}}if(changed)for(const mesh of Object.values(glowMeshes))mesh.instanceMatrix.needsUpdate=true;return {time,phases:previous}}
  update(0);object.updateMatrixWorld(true);
  let triangles=0,instances=0;for(const mesh of meshes){const count=mesh.userData.roadEquipmentInstances??(mesh.isInstancedMesh?mesh.count:1);instances+=mesh.isBatchedMesh||mesh.isInstancedMesh?count:0;triangles+=(mesh.geometry.index?mesh.geometry.index.count:mesh.geometry.attributes.position.count)/3*count}
  const stats={...plan.stats,paintDraws:paintBuckets.size,equipmentDraws:batchedEquipment.size||buckets.size,equipmentSourceChunks:buckets.size,signalDraws:3,totalDraws:meshes.length,triangles,instances,pointLights:0,get visibleDraws(){return meshes.filter(mesh=>mesh.visible).length}};
  return {object,update,colliders:plan.colliders,mapFeatures:plan.mapFeatures,stats,dispose(){for(const mesh of meshes)if(mesh.isInstancedMesh)mesh.dispose();for(const g of ownedGeometry)g.dispose();for(const m of ownedMaterials)m.dispose();object.clear()}};
}
