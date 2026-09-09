import {surfaceMeshRecord,validateSurfaceMesh,validateSurfaceReceipts} from '../npc_surface_state.mjs';
// Presentation only: consume confirmed impact receipts; never decide damage here.
// Surface anchors follow the actual deformed triangle, including blended skin weights.
export function createBulletWounds(THREE,{worldScale=1}={}) {
  const unit=Math.max(.001,worldScale);
  const states=new WeakMap(),MAX_MARKS=24,MAX_RECEIPTS=512;
  const materials=[0x241b19,0x806a57,0x672323,0x96362d].map(color=>new THREE.MeshStandardMaterial({color,roughness:1,side:THREE.DoubleSide,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2}));
  const rootOf=model=>model.root||model;
  const finite=v=>v&&Number.isFinite(v.x)&&Number.isFinite(v.y)&&Number.isFinite(v.z);
  function attach(model){
    if(states.has(model))return states.get(model).group;
    const root=rootOf(model),surfaces=[];
    root.traverse(o=>{if(o.isMesh&&o.geometry?.attributes?.position&&!o.userData.bulletWound)surfaces.push(o);});
    const group=new THREE.Group();group.name='PersistentBulletWounds';group.userData.bulletWound=true;root.add(group);
    states.set(model,{root,surfaces,group,marks:[],receipts:new Set()});return group;
  }
  function vertex(mesh,index){return mesh.getVertexPosition(index,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld);}
  function anchorAt(state,point,normal){
    const ray=new THREE.Raycaster(point.clone().addScaledVector(normal,.35*unit),normal.clone().negate(),0,.70*unit);
    const hits=ray.intersectObjects(state.surfaces,false);
    const hit=hits.find(h=>h.face&&Math.abs(h.distance-.35*unit)<.20*unit);
    if(!hit)return null;
    const {a,b,c}=hit.face,A=vertex(hit.object,a),B=vertex(hit.object,b),C=vertex(hit.object,c);
    const weights=THREE.Triangle.getBarycoord(hit.point,A,B,C,new THREE.Vector3());
    if(!weights)return null;
    const outward=new THREE.Vector3().subVectors(B,A).cross(new THREE.Vector3().subVectors(C,A)).normalize();
    return {mesh:hit.object,a,b,c,weights,sign:outward.dot(normal)<0?-1:1};
  }
  function add(model,event={}){
    if(event.confirmed!==true||event.id===undefined||event.id===null||!finite(event.point)||!finite(event.normal)||event.normal.lengthSq()<1e-10)return false;
    attach(model);const state=states.get(model),id=String(event.id);
    if(state.receipts.has(id))return false;
    state.root.updateWorldMatrix(true,true);for(const mesh of state.surfaces)if(mesh.isSkinnedMesh){mesh.skeleton.update();mesh.computeBoundingSphere();if(mesh.boundingBox)mesh.computeBoundingBox();}
    const n=event.normal.clone().normalize(),center=anchorAt(state,event.point,n);if(!center)return false;
    // Prefer an explicit hit-zone classification from integration. This fallback is only visual.
    const clothing=event.clothing??!(/head|neck|hand/i.test(event.boneName||''));
    const u=new THREE.Vector3().crossVectors(Math.abs(n.y)<.9?new THREE.Vector3(0,1,0):new THREE.Vector3(1,0,0),n).normalize(),v=new THREE.Vector3().crossVectors(n,u);
    let seed=2166136261;for(const char of id)seed=Math.imul(seed^char.charCodeAt(0),16777619)>>>0;
    const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
    const count=11,radius=(clothing?.105:.075)*unit,edge=Array.from({length:count},(_,i)=>{const a=i/count*Math.PI*2;return [Math.cos(a)*radius*(.65+random()*.55),Math.sin(a)*radius*(.65+random()*.55)];});
    const anchors=[],positions=[],groups=[];
    function triangle(points,material,offset){
      const bound=points.map(([x,y])=>anchorAt(state,event.point.clone().addScaledVector(u,x).addScaledVector(v,y),n));
      if(bound.some(x=>!x))return;
      groups.push({start:anchors.length,count:3,material});for(const anchor of bound){anchors.push({...anchor,offset:offset*unit});positions.push(0,0,0);}
    }
    for(let i=0;i<count;i++){
      const p=edge[i],q=edge[(i+1)%count];
      triangle([[0,0],p,q],clothing?0:2,.010);
      if(clothing){const outer=[p[0]*1.24,p[1]*1.24],next=[q[0]*1.10,q[1]*1.10];triangle([p,outer,q],1,.012);if(i%2===0)triangle([outer,next,q],1,.012);}
      // Broken burgundy fragments inside the tear; no floating sphere or opaque red disk.
      if(i%3!==0)triangle([[0,0],[p[0]*.60,p[1]*.60],[q[0]*.54,q[1]*.54]],3,.014);
    }
    if(!anchors.length)return false;
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));for(const g of groups)geometry.addGroup(g.start,g.count,g.material);
    const mesh=new THREE.Mesh(geometry,materials);mesh.name=clothing?'RaggedBulletTear':'BulletSkinWound';mesh.userData.bulletWound=true;mesh.frustumCulled=false;mesh.renderOrder=2;state.group.add(mesh);
    state.marks.push({mesh,anchors,id});state.receipts.add(id);
    while(state.receipts.size>MAX_RECEIPTS)state.receipts.delete(state.receipts.values().next().value);
    while(state.marks.length>MAX_MARKS){const old=state.marks.shift();old.mesh.removeFromParent();old.mesh.geometry.dispose();}
    update(model);return true;
  }
  function update(model){
    const state=states.get(model);if(!state||!state.marks.length)return;
    state.root.updateWorldMatrix(true,true);for(const mesh of state.surfaces)if(mesh.isSkinnedMesh)mesh.skeleton.update();
    const inverse=state.group.matrixWorld.clone().invert(),cache=new Map();
    const get=(mesh,index)=>{let map=cache.get(mesh);if(!map){map=new Map();cache.set(mesh,map);}if(!map.has(index))map.set(index,vertex(mesh,index));return map.get(index);};
    for(const mark of state.marks){const position=mark.mesh.geometry.attributes.position;
      mark.anchors.forEach((a,i)=>{const A=get(a.mesh,a.a),B=get(a.mesh,a.b),C=get(a.mesh,a.c),normal=new THREE.Vector3().subVectors(B,A).cross(new THREE.Vector3().subVectors(C,A)).normalize().multiplyScalar(a.sign);
        const p=new THREE.Vector3().addScaledVector(A,a.weights.x).addScaledVector(B,a.weights.y).addScaledVector(C,a.weights.z).addScaledVector(normal,a.offset).applyMatrix4(inverse);position.setXYZ(i,p.x,p.y,p.z);});
      position.needsUpdate=true;mark.mesh.geometry.computeVertexNormals();
    }
  }
  function reset(model){const state=states.get(model);if(!state)return;for(const mark of state.marks){mark.mesh.removeFromParent();mark.mesh.geometry.dispose();}state.marks.length=0;state.receipts.clear();}
  function snapshot(model){
    attach(model);const state=states.get(model),meshes=[],index=new Map();
    const meshId=mesh=>{if(!index.has(mesh)){index.set(mesh,meshes.length);meshes.push(surfaceMeshRecord(state.root,mesh));}return index.get(mesh);};
    const marks=state.marks.map(mark=>({id:mark.id,name:mark.mesh.name,groups:mark.mesh.geometry.groups.map(g=>({...g})),anchors:mark.anchors.map(a=>({mesh:meshId(a.mesh),a:a.a,b:a.b,c:a.c,weights:a.weights.toArray(),sign:a.sign,offset:a.offset}))}));
    return {version:1,unit,meshes,marks,receipts:[...state.receipts]};
  }
  function validateSnapshot(model,data){
    attach(model);const state=states.get(model);
    if(data?.version!==1||!Number.isFinite(data.unit)||Math.abs(data.unit-unit)>1e-9||!Array.isArray(data.meshes)||data.meshes.length>128||!Array.isArray(data.marks)||data.marks.length>MAX_MARKS)throw Error('Invalid wound state version/scale/limits');
    validateSurfaceReceipts(data.receipts);const meshes=data.meshes.map(m=>validateSurfaceMesh(state.root,m));if(new Set(meshes).size!==meshes.length)throw Error('Duplicate wound mesh');
    const seen=new Set();return data.marks.map(mark=>{
      if(typeof mark.id!=='string'||!data.receipts.includes(mark.id)||seen.has(mark.id)||!['RaggedBulletTear','BulletSkinWound'].includes(mark.name)||!Array.isArray(mark.anchors)||!mark.anchors.length||mark.anchors.length>1024||mark.anchors.length%3||!Array.isArray(mark.groups)||mark.groups.length!==mark.anchors.length/3)throw Error('Invalid wound mark');seen.add(mark.id);
      const anchors=mark.anchors.map(a=>{const mesh=Number.isInteger(a.mesh)?meshes[a.mesh]:null,count=mesh?.geometry.attributes.position.count;
        if(!mesh||!state.surfaces.includes(mesh)||[a.a,a.b,a.c].some(i=>!Number.isInteger(i)||i<0||i>=count)||!Array.isArray(a.weights)||a.weights.length!==3||a.weights.some(w=>!Number.isFinite(w)||w<-.001||w>1.001)||Math.abs(a.weights.reduce((sum,w)=>sum+w,0)-1)>.001||![1,-1].includes(a.sign)||!Number.isFinite(a.offset)||a.offset<0||a.offset>unit*.1)throw Error('Invalid wound triangle anchor');
        return {...a,mesh,weights:new THREE.Vector3(...a.weights)};
      });
      const groups=mark.groups.map((g,i)=>{if(g.start!==i*3||g.count!==3||!Number.isInteger(g.materialIndex)||g.materialIndex<0||g.materialIndex>=materials.length)throw Error('Invalid wound geometry groups');return {...g};});
      return {...mark,anchors,groups};
    });
  }
  function restore(model,data){
    const prepared=validateSnapshot(model,data);reset(model);const state=states.get(model);
    for(const mark of prepared){const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(new Float32Array(mark.anchors.length*3),3));for(const g of mark.groups)geometry.addGroup(g.start,g.count,g.materialIndex);const mesh=new THREE.Mesh(geometry,materials);mesh.name=mark.name;mesh.userData.bulletWound=true;mesh.frustumCulled=false;mesh.renderOrder=2;state.group.add(mesh);state.marks.push({id:mark.id,anchors:mark.anchors,mesh});}
    for(const id of data.receipts)state.receipts.add(id);update(model);
  }
  return {attach,add,reset,update,snapshot,validateSnapshot,restore};
}


