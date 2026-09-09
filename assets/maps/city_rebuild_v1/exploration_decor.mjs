import {TREE_SIZE_CLASSES} from './exploration_decor_plan.mjs';
/** Shared low-poly smooth clay shapes, instanced across the entire exploration map. */
export function createExplorationDecor({THREE,RoundedBoxGeometry,plan,chunkSize=128}={}) {
  if(!THREE||!plan?.objects)throw Error('Exploration decor needs THREE and an approved placement plan');
  const object=new THREE.Group();object.name='ExplorationCivicAndForest';
  const geometries={
    box:RoundedBoxGeometry?new RoundedBoxGeometry(1,1,1,2,.08):new THREE.BoxGeometry(1,1,1),
    cylinder:new THREE.CylinderGeometry(1,1,1,12),
    taper:new THREE.CylinderGeometry(.7,1,1,12),
    leaf:new THREE.SphereGeometry(1,10,7),
    sphere:new THREE.SphereGeometry(1,14,10),
    ring:new THREE.TorusGeometry(1,.075,6,28),
    pine:new THREE.LatheGeometry([new THREE.Vector2(0,-.5),new THREE.Vector2(.6,-.48),new THREE.Vector2(1,-.32),new THREE.Vector2(.84,-.12),new THREE.Vector2(.56,.13),new THREE.Vector2(.2,.42),new THREE.Vector2(0,.6)],12),
  };
  // Keep the original shapes at walking distance. Distant objects retain every
  // branch, crown, furniture part and instance transform; only tessellation changes.
  // Shared geometry swaps add neither batches nor per-frame instance uploads.
  const pineProfile=[new THREE.Vector2(0,-.5),new THREE.Vector2(.6,-.48),new THREE.Vector2(1,-.32),new THREE.Vector2(.84,-.12),new THREE.Vector2(.56,.13),new THREE.Vector2(.2,.42),new THREE.Vector2(0,.6)];
  const makeDistantGeometry=(far)=>({
    box:far?new THREE.BoxGeometry(1,1,1):(RoundedBoxGeometry?new RoundedBoxGeometry(1,1,1,1,.08):new THREE.BoxGeometry(1,1,1)),
    cylinder:new THREE.CylinderGeometry(1,1,1,far?6:8),
    taper:new THREE.CylinderGeometry(.7,1,1,far?6:8),
    leaf:new THREE.SphereGeometry(1,far?6:8,far?4:5),
    sphere:new THREE.SphereGeometry(1,far?8:10,far?5:7),
    ring:new THREE.TorusGeometry(1,.075,far?4:5,far?12:20),
    pine:new THREE.LatheGeometry(pineProfile,far?6:8),
  });
  const detailGeometries=[geometries,makeDistantGeometry(false),makeDistantGeometry(true)];
  // Different sphere segment counts need not sample the same extrema. Fit each
  // tessellation to the authored bounds so crowns/heights and culling stay valid.
  for(const [shape,reference]of Object.entries(geometries)){
    reference.computeBoundingBox();
    for(const level of detailGeometries.slice(1)){
      const geometry=level[shape];geometry.computeBoundingBox();
      const a=reference.boundingBox,b=geometry.boundingBox;
      const sx=(a.max.x-a.min.x)/(b.max.x-b.min.x),sy=(a.max.y-a.min.y)/(b.max.y-b.min.y),sz=(a.max.z-a.min.z)/(b.max.z-b.min.z);
      const tx=a.min.x-b.min.x*sx,ty=a.min.y-b.min.y*sy,tz=a.min.z-b.min.z*sz;
      geometry.scale(sx,sy,sz);geometry.translate(tx,ty,tz);geometry.computeBoundingBox();
    }
  }
  const materials={
    clay:new THREE.MeshStandardMaterial({color:0xffffff,roughness:.82,metalness:.02}),
    brass:new THREE.MeshStandardMaterial({color:0xffffff,roughness:.32,metalness:.7}),
    water:new THREE.MeshStandardMaterial({color:0xffffff,roughness:.2,metalness:.18,emissive:0x183c3d,emissiveIntensity:.16}),
    glow:new THREE.MeshStandardMaterial({color:0xffffff,roughness:.45,emissive:0xf6c781,emissiveIntensity:.6}),
  };
  const C={stone:0xd1c1a2,light:0xe6dbc3,edge:0xb6a586,teal:0x204d50,dark:0x263d3d,brass:0xb99b62,wood:0x815844,bark:0x685145,burgundy:0x744049,water:0x589c9b,cream:0xf1e2c1};
  const buckets=new Map(),parent=new THREE.Matrix4(),local=new THREE.Matrix4(),world=new THREE.Matrix4(),position=new THREE.Vector3(),size=new THREE.Vector3(),rotation=new THREE.Quaternion(),euler=new THREE.Euler(),up=new THREE.Vector3(0,1,0),color=new THREE.Color();
  let current;
  const bucketKey=(shape,material)=>`${Math.floor(current.x/chunkSize)},${Math.floor(current.z/chunkSize)}:${shape}:${material}`;
  function part(shape,p,s,tint,rot=[0,0,0],material='clay'){
    const key=bucketKey(shape,material);if(!buckets.has(key))buckets.set(key,[]);
    local.compose(position.fromArray(p),rotation.setFromEuler(euler.set(rot[0]||0,rot[1]||0,rot[2]||0)),size.fromArray(s));world.multiplyMatrices(parent,local);
    buckets.get(key).push({matrix:world.clone(),color:tint,id:current.id});
  }
  function beam(a,b,r,tint,shape='cylinder',material='clay'){
    const start=new THREE.Vector3(...a),end=new THREE.Vector3(...b),delta=end.clone().sub(start),length=delta.length();
    local.compose(start.add(end).multiplyScalar(.5),rotation.setFromUnitVectors(up,delta.normalize()),size.set(r,length,r));world.multiplyMatrices(parent,local);
    const key=bucketKey(shape,material);if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push({matrix:world.clone(),color:tint,id:current.id});
  }
  function plinth(radius=1.5,height=.8){part('cylinder',[0,.09,0],[radius,.18,radius],C.edge);part('taper',[0,height/2+.18,0],[radius*.83,height,radius*.83],C.stone);part('cylinder',[0,height+.19,0],[radius*.9,.16,radius*.9],C.light);}
  function foliage(x,y,z,s,tint){part('leaf',[x,y,z],s,tint);}
  function bench(variant=0){
    const seat=variant===1?C.burgundy:variant===2?C.teal:C.wood;
    for(const x of[-.95,.95]){part('box',[x,.27,0],[.22,.52,.65],C.stone);beam([x,.28,-.24],[x,1,-.3],.055,C.brass,'cylinder','brass');beam([x,.7,-.24],[x,.7,.31],.055,C.brass,'cylinder','brass');}
    for(const z of[-.24,-.08,.08,.24])part('box',[0,.55,z],[2.55,.12,.14],seat);
    for(const y of[.79,.99])part('box',[0,y,-.31],[2.55,.15,.11],seat,[-.09,0,0]);
    for(const x of[-1.12,1.12])part('sphere',[x,.73,.24],[.07,.07,.07],C.brass,[],'brass');
  }
  function tree(kind,variant){
    const treeColors=[0x52735b,0x698568,0x3d6558,0x7b9066],green=treeColors[variant%4];
    const size=TREE_SIZE_CLASSES[current.sizeClass||'adult'],crown=size.crown,trunk=size.trunk;
    const height=kind==='oak'?3.5:kind==='pine'?6.3:kind==='cedar'?5.5:4.6,r=(kind==='oak'?.27:kind==='birch'?.15:kind==='cedar'||kind==='willow'?.29:.22)*trunk;
    const leaf=(x,y,z,s,tint)=>foliage(x*crown,y,z*crown,[s[0]*crown,s[1],s[2]*crown],tint);
    const branch=(a,b,width,tint=C.bark)=>beam([a[0]*crown,a[1],a[2]*crown],[b[0]*crown,b[1],b[2]*crown],width*trunk,tint);
    part('taper',[0,height/2,0],[r,height,r],kind==='birch'?0xd9d5bf:C.bark);
    if(kind==='spruce'){
      for(let i=0;i<3;i++)part('pine',[0,3.25+i*1.5,0],[(1.85-i*.43)*crown,3-i*.22,(1.85-i*.43)*crown],variant%2?0x3f6656:0x527763,[0,i*1.3,0]);
      branch([0,2.35,0],[.9,3.15,.22],.09);branch([0,2.7,0],[-.75,3.7,.2],.08);
    }else if(kind==='pine'){
      // Tall exposed warm bark and a broad umbrella distinguish pine from spruce.
      for(const [x,z,y]of[[-1.35,.25,6.7],[1.3,.5,6.9],[.15,-1.3,6.6]]){branch([0,4.9,0],[x*.6,5.85,z*.6],.11);branch([x*.6,5.85,z*.6],[x,y,z],.075);leaf(x,y,z,[1.35,.8,1.15],green);}
      leaf(0,7,0,[1.75,1,1.55],0x547561);
      if(current.sizeClass!=='sapling')branch([0,3.55,0],[.65,3.75,-.3],.065);
    }else if(kind==='cypress'){
      leaf(0,4.7,0,[.84,2.6,.84],green);leaf(.18,3.3,.07,[.83,1.5,.86],green);
    }else if(kind==='birch'){
      branch([0,1.5,0],[.7,4.7,.2],.1,0xd9d5bf);branch([0,2.3,0],[-.6,4.8,-.35],.08,0xd9d5bf);
      leaf(.2,5.2,0,[1.15,1.6,1.1],0x829567);leaf(-.65,4.7,-.2,[.85,1.05,.9],0xa7ad7d);leaf(.85,4.5,.15,[.8,1.15,.8],0x829567);
      for(let i=0;i<5;i++)part('box',[.095*trunk,1+i*.62,.1*trunk],[.12*trunk,.06,.15*trunk],0x716d5f,[0,.8*i,0]);
    }else if(kind==='cedar'){
      for(let tier=0;tier<3;tier++){const y=3.8+tier*1.3,spread=1.28-tier*.27;for(let i=0;i<3;i++){const a=i*Math.PI*2/3+tier*.8,x=Math.cos(a)*spread,z=Math.sin(a)*spread;branch([0,y-.65,0],[x,y,z],.09);leaf(x,y,z,[1.2-tier*.16,.65,1-tier*.12],tier%2?0x476c59:green);}}
      leaf(0,7.15,0,[.8,.95,.8],0x6c886b);
    }else if(kind==='willow'){
      leaf(0,4.9,0,[1.9,1.35,1.7],0x839466);
      for(let i=0;i<6;i++){const a=i*Math.PI/3,x=Math.cos(a)*1.55,z=Math.sin(a)*1.55;branch([0,2.8,0],[x,4.6,z],.11);branch([x,4.6,z],[x*1.25,3.1,z*1.25],.045);leaf(x,4.15,z,[.95,.9,.85],i%2?0x829165:0x9aa471);leaf(x*1.18,2.85,z*1.18,[.52,1.27,.5],i%2?0x91a16f:0x708655);}
    }else{
      for(const [x,z]of[[-.9,.15],[.65,.55],[.2,-.8]]){branch([0,1.5,0],[x*.55,2.6,z*.5],.16);branch([x*.55,2.6,z*.5],[x,3.65,z],.12);}
      leaf(0,4.7,0,[1.65,1.65,1.65],green);leaf(-1,3.9,.15,[1.15,1.05,1.4],green);leaf(.95,4.2,.5,[1.35,1.15,1.2],0x6c8465);leaf(.15,3.9,-1,[1.3,1.15,1.1],green);
    }
    // Root swell remains inside the explicit trunk collider.
    part('taper',[0,.12,0],[r*1.25,.24,r*1.25],kind==='birch'?0xb7b3a0:C.bark);
  }
  function planter(){
    part('taper',[0,.38,0],[.68,.72,.68],C.burgundy);part('cylinder',[0,.76,0],[.73,.1,.73],C.edge);part('cylinder',[0,.81,0],[.61,.05,.61],0x54443a);
    for(let i=0;i<5;i++){const a=i*Math.PI*2/5;foliage(Math.cos(a)*.35,.93,Math.sin(a)*.35,[.27,.23,.27],0x628268);part('sphere',[Math.cos(a)*.39,1.11,Math.sin(a)*.39],[.13,.09,.13],i%2?0xdbad77:0xbd7276);}
  }
  function fountain(){
    part('cylinder',[0,.1,0],[2.7,.2,2.7],C.edge);part('cylinder',[0,.28,0],[2.5,.32,2.5],C.stone);
    part('ring',[0,.45,0],[2.37,2.37,1.8],C.light,[Math.PI/2,0,0]);part('cylinder',[0,.45,0],[2.22,.035,2.22],C.water,[],'water');
    part('taper',[0,1.05,0],[.32,1.6,.32],C.stone);part('cylinder',[0,1.73,0],[1.35,.2,1.35],C.stone);part('ring',[0,1.85,0],[1.32,1.32,1.3],C.light,[Math.PI/2,0,0]);part('cylinder',[0,1.83,0],[1.22,.025,1.22],C.water,[],'water');
    part('taper',[0,2.22,0],[.19,.9,.19],C.stone);part('cylinder',[0,2.67,0],[.65,.14,.65],C.light);part('sphere',[0,3,0],[.24,.34,.24],C.brass,[],'brass');
    for(let i=0;i<8;i++){const a=i*Math.PI/4,x=Math.cos(a),z=Math.sin(a);beam([x*1.2,1.84,z*1.2],[x*1.8,.49,z*1.8],.022,0xadd6cf,'cylinder','water');}
    beam([0,3.25,0],[0,3.65,0],.026,0xadd6cf,'cylinder','water');
  }
  function monument(){
    plinth(1.65,1.05);part('box',[0,2,0],[.85,1.6,.53],C.stone);part('taper',[0,2.58,0],[.58,1.28,.42],C.light);
    part('sphere',[0,3.64,0],[.3,.4,.28],C.light);part('cylinder',[0,3.99,0],[.47,.1,.39],C.stone);part('cylinder',[0,4.15,0],[.32,.28,.29],C.stone);
    beam([-.48,2.88,0],[-.72,2.14,.25],.17,C.stone);beam([.45,2.88,0],[.9,3.21,.25],.16,C.stone);part('box',[.93,3.29,.24],[.43,.55,.14],C.brass,[0,0,-.25],'brass');
    part('box',[0,.84,1.32],[.75,.35,.05],C.brass,[],'brass');for(let i=0;i<3;i++)part('box',[0,.93-i*.075,1.355],[.53-i*.05,.018,.009],C.dark);
    for(const x of[-.2,.2])part('box',[x,1.36,.2],[.29,.19,.57],C.edge);
  }
  function armillary(){
    plinth(1.5,.8);part('taper',[0,1.64,0],[.4,1.45,.4],C.stone);
    const y=3.16;part('sphere',[0,y,0],[.36,.36,.36],C.teal);
    for(const rot of[[.45,0,0],[Math.PI/2,0,.3],[0,Math.PI/2,0]])part('ring',[0,y,0],[1.3,1.3,1.3],C.brass,rot,'brass');
    beam([-.45,1.92,0],[.45,4.35,0],.055,C.brass,'cylinder','brass');part('sphere',[.45,4.35,0],[.12,.12,.12],C.brass,[],'brass');
    part('ring',[0,2.15,0],[.6,.6,.6],C.brass,[Math.PI/2,0,0],'brass');
  }
  function clock(){
    part('cylinder',[0,.14,0],[.55,.28,.55],C.stone);part('taper',[0,1.95,0],[.14,3.7,.14],C.teal);part('sphere',[0,4.64,0],[.13,.17,.13],C.brass,[],'brass');
    for(const side of[-1,1]){
      part('cylinder',[0,3.94,side*.06],[.63,.11,.63],C.brass,[Math.PI/2,0,0],'brass');part('cylinder',[0,3.94,side*.13],[.53,.035,.53],C.cream,[Math.PI/2,0,0]);
      for(let i=0;i<12;i++){const a=i*Math.PI/6;part('box',[Math.sin(a)*.43,3.94+Math.cos(a)*.43,side*.16],[.025,.08,.012],C.dark,[0,0,-a]);}
      beam([0,3.94,side*.18],[.22,4.12,side*.18],.018,C.dark);beam([0,3.94,side*.18],[-.15,4.27,side*.18],.012,C.dark);
    }
  }
  function kiosk(){
    part('cylinder',[0,.1,0],[1.28,.2,1.28],C.stone);part('cylinder',[0,1.34,0],[.9,2.45,.9],C.teal);part('cylinder',[0,2.55,0],[1.07,.2,1.07],C.brass,[],'brass');
    part('sphere',[0,2.61,0],[1.11,.35,1.11],C.burgundy);part('sphere',[0,2.98,0],[.12,.12,.12],C.brass,[],'brass');
    for(let i=0;i<6;i++){const a=i*Math.PI/3,x=Math.sin(a),z=Math.cos(a);part('box',[x*.9,1.38,z*.9],[.63,1.56,.045],i%2?C.cream:0xb6b3a0,[0,a,0]);for(let j=0;j<4;j++)part('box',[x*.935,1.83-j*.2,z*.935],[.42,j===0?.09:.035,.014],j===0?C.burgundy:C.teal,[0,a,0]);}
  }
  function bin(){part('cylinder',[0,.06,0],[.43,.12,.43],C.edge);part('cylinder',[0,.58,0],[.37,.94,.37],C.teal);part('ring',[0,1.04,0],[.39,.39,.39],C.brass,[Math.PI/2,0,0],'brass');part('cylinder',[0,1.03,0],[.28,.035,.28],C.dark);for(let i=0;i<8;i++){const a=i*Math.PI/4;part('box',[Math.sin(a)*.365,.61,Math.cos(a)*.365],[.035,.72,.04],C.brass,[0,a,0],'brass');}}
  function lamp(){part('cylinder',[0,.08,0],[.23,.16,.23],C.stone);part('taper',[0,1.65,0],[.075,3.15,.075],C.teal);part('cylinder',[0,3.05,0],[.24,.12,.24],C.brass,[],'brass');part('sphere',[0,3.36,0],[.24,.32,.24],C.cream,[],'glow');part('sphere',[0,3.61,0],[.34,.12,.34],C.teal);part('sphere',[0,3.79,0],[.065,.12,.065],C.brass,[],'brass');}
  function picnic(){
    for(const x of[-.85,.85]){beam([x,.08,-.85],[x,.76,.3],.09,C.teal);beam([x,.08,.85],[x,.76,-.3],.09,C.teal);}
    for(let i=0;i<5;i++)part('box',[0,.82,(i-2)*.16],[2.65,.14,.145],C.wood);
    for(const z of[-.8,.8]){part('box',[0,.43,z],[2.65,.14,.36],C.wood);beam([-.92,.35,z],[.92,.35,z],.08,C.teal);}
  }
  function sign(){part('taper',[0,1.12,0],[.075,2.24,.075],C.wood);part('sphere',[0,2.39,0],[.12,.12,.12],C.brass,[],'brass');for(let i=0;i<2;i++){part('box',[i?-.12:.12,2.13-i*.36,0],[1.4,.24,.13],i?C.burgundy:C.teal,[0,i*.7,0]);part('box',[i?-.3:.3,2.13-i*.36,.08],[.62,.034,.015],C.cream,[0,i*.7,0]);}}
  function telescope(){
    for(let i=0;i<3;i++){const a=i*Math.PI*2/3;beam([0,1.08,0],[Math.cos(a)*.57,.02,Math.sin(a)*.57],.045,C.brass,'cylinder','brass');}
    part('sphere',[0,1.16,0],[.17,.17,.17],C.teal);for(const x of[-.13,.13]){beam([x,1.35,-.33],[x,1.48,.42],.12,C.brass,'cylinder','brass');part('sphere',[x,1.5,.44],[.1,.1,.045],C.teal);}beam([0,.96,0],[0,1.36,0],.07,C.teal);
  }
  for(const item of plan.objects){
    current=item;parent.compose(position.set(item.x,item.y,item.z),rotation.setFromAxisAngle(up,item.yaw||0),size.setScalar(item.scale||1));
    switch(item.kind){
      case 'pine':case 'spruce':case 'oak':case 'birch':case 'cypress':case 'cedar':case 'willow':tree(item.kind,item.variant||0);break;
      case 'rock':part('leaf',[0,.48,0],[1.07,.77,.87],item.variant%2?0x9a9d8b:0xb3aa96,[.13,.4,.18]);part('leaf',[.48,.17,.35],[.52,.33,.44],0x8e9381);break;
      case 'shrub':for(let i=0;i<3;i++)foliage((i-1)*.36,.4,Math.sin(i*2)*.18,[.48,.46,.43],i%2?0x7e9169:0x526f59);break;
      case 'bench':bench(item.variant||0);break;
      case 'planter':planter();break;
      case 'fountain':fountain();break;
      case 'monument':monument();break;
      case 'armillary':armillary();break;
      case 'clock':clock();break;
      case 'kiosk':kiosk();break;
      case 'bin':bin();break;
      case 'lamp':lamp();break;
      case 'picnic':picnic();break;
      case 'sign':sign();break;
      case 'telescope':telescope();break;
      default:throw Error('Unknown exploration decoration: '+item.kind);
    }
  }
  let renderedInstances=0,triangles=0;
  const chunks=new Map(),meshes=[];
  for(const [key,parts]of buckets){
    const [chunkKey,shape,material]=key.split(':'),geometry=geometries[shape],mesh=new THREE.InstancedMesh(geometry,materials[material],parts.length);
    if(!chunks.has(chunkKey)){
      const [ix,iz]=chunkKey.split(',').map(Number),group=new THREE.Group();group.name='ExplorationChunk_'+chunkKey;
      group.userData.bounds={minX:ix*chunkSize-5,maxX:(ix+1)*chunkSize+5,minZ:iz*chunkSize-5,maxZ:(iz+1)*chunkSize+5};
      group.userData.triangles=0;group.userData.instances=0;group.userData.detailLevel=0;group.userData.detailTriangles=[0,0,0];chunks.set(chunkKey,group);object.add(group);
    }
    mesh.name='Exploration_'+key;mesh.receiveShadow=true;mesh.castShadow=false;mesh.userData.explorationDecor=true;
    mesh.userData.explorationShape=shape;
    mesh.userData.objectIds=parts.map(p=>p.id);
    for(let i=0;i<parts.length;i++){mesh.setMatrixAt(i,parts[i].matrix);mesh.setColorAt(i,color.setHex(parts[i].color));}
    mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();chunks.get(chunkKey).add(mesh);meshes.push(mesh);
    const bounds=chunks.get(chunkKey).userData.bounds;bounds.minX=Math.min(bounds.minX,mesh.boundingBox.min.x);bounds.maxX=Math.max(bounds.maxX,mesh.boundingBox.max.x);bounds.minZ=Math.min(bounds.minZ,mesh.boundingBox.min.z);bounds.maxZ=Math.max(bounds.maxZ,mesh.boundingBox.max.z);
    const partTriangles=(geometry.index?geometry.index.count:geometry.attributes.position.count)/3*parts.length;
    chunks.get(chunkKey).userData.triangles+=partTriangles;chunks.get(chunkKey).userData.instances+=parts.length;
    for(let level=0;level<detailGeometries.length;level++){
      const g=detailGeometries[level][shape];
      chunks.get(chunkKey).userData.detailTriangles[level]+=(g.index?g.index.count:g.attributes.position.count)/3*parts.length;
    }
    renderedInstances+=parts.length;triangles+=partTriangles;
  }
  const stats={...plan.stats,chunks:chunks.size,drawCalls:meshes.length,renderedInstances,triangles,dynamicLights:0,shadowCasters:0,visibleChunks:chunks.size,visibleDrawCalls:meshes.length,visibleTriangles:triangles,fullQualityVisibleTriangles:triangles,detailChunks:[chunks.size,0,0],lodNearDistance:64,lodFarDistance:180,lodHysteresis:8};object.userData.explorationDecor=stats;
  function update({focus,maxDistance=360}={}){
    if(!focus||!Number.isFinite(focus.x+focus.z))return;
    stats.visibleChunks=0;stats.visibleDrawCalls=0;stats.visibleTriangles=0;stats.fullQualityVisibleTriangles=0;stats.detailChunks.fill(0);
    for(const chunk of chunks.values()){
      const b=chunk.userData.bounds,d=Math.hypot(Math.max(b.minX-focus.x,0,focus.x-b.maxX),Math.max(b.minZ-focus.z,0,focus.z-b.maxZ));
      chunk.visible=d<=maxDistance;
      if(chunk.visible){
        // Nearest point of expanded geometry bounds (not centre) protects nearby
        // giants and whole compositions. Hysteresis avoids shimmering at a boundary.
        const previous=chunk.userData.detailLevel;
        const near=stats.lodNearDistance,far=stats.lodFarDistance,h=stats.lodHysteresis;
        const level=d<=near?0:d>far+h?2:previous===0&&d<=near+h?0:previous===2&&d>far?2:1;
        if(level!==previous){
          for(const mesh of chunk.children)mesh.geometry=detailGeometries[level][mesh.userData.explorationShape];
          chunk.userData.detailLevel=level;
        }
        stats.visibleChunks++;stats.visibleDrawCalls+=chunk.children.length;
        stats.visibleTriangles+=chunk.userData.detailTriangles[level];
        stats.fullQualityVisibleTriangles+=chunk.userData.triangles;stats.detailChunks[level]++;
      }
    }
  }
  return {object,colliders:plan.colliders,mapFeatures:plan.mapFeatures,stats,update,dispose(){for(const mesh of meshes)mesh.dispose();for(const level of detailGeometries)for(const geometry of Object.values(level))geometry.dispose();for(const material of Object.values(materials))material.dispose();object.clear();}};
}
