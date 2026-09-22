// ISOLATED prototype: no gameplay import and no corpse/root/HP writes.
// Geometry CPU buffers are immutable leased inputs. Snapshot matrices/morphs and
// clone material handles at admission; actor disposal cannot invalidate the job.
// Times are seconds on ONE monotonic host clock. eventAt is absolute, not receipt time.
import {createNpcBlastGround20,stepNpcBlastGround20} from './npc_blast_ground20.mjs';
const regions=['torso','head','arm_l','arm_r','leg_l','leg_r'];
const regionOf=name=>/head|neck/.test(name)?1:/upperarm_l|forearm_l|hand_l|clavicle_l/.test(name)?2:/upperarm_r|forearm_r|hand_r|clavicle_r/.test(name)?3:/thigh_l|shin_l|foot_l/.test(name)?4:/thigh_r|shin_r|foot_r/.test(name)?5:0;
const validId=id=>typeof id==='string'&&id.trim().length>0;
const finitePoint=p=>p&&[p.x,p.y,p.z].every(Number.isFinite);
export function createNpcBlastPartsPrototype20(THREE,scene,{maxVictims=2,lifetime=8,maxMeshesPerVictim=36,maxTrianglesPerVictim=20000,maxTopologyEntries=32,maxReceipts=256,budgetMs=1.25,maxVerticesPerStep=2048,maxWorkPerStep=2048,clock=()=>performance.now(),groundHeight}={}){
 if(![maxVictims,maxMeshesPerVictim,maxTrianglesPerVictim,maxTopologyEntries,maxReceipts,maxVerticesPerStep,maxWorkPerStep].every(n=>Number.isSafeInteger(n)&&n>0)||maxVictims>2||!Number.isFinite(lifetime)||lifetime<=0||lifetime>8||!Number.isFinite(budgetMs)||budgetMs<=0||budgetMs>2)throw Error('Invalid bounded parts budget');
 if(groundHeight!=null&&typeof groundHeight!=='function')throw Error('Invalid ground height provider');
 const pending=[],active=[],preparing=[],receipts=new Map(),deaths=new Map(),topologies=new WeakMap(),topologyEntries=[],materialCache=new Map();
 let disposed=false,admitted=0,cacheHits=0,cacheMisses=0,verifiedCloneShares=0,bakedVertices=0,lastNow=-Infinity,allocatedGeometries=0,geometryBytes=0,maxSliceMs=0,lastSliceMs=0,lastWork=0,lastVertices=0;
 const groundQueryBudget=192;let groundCursor=0,groundQueriesLast=0,groundVisitsLast=0;
 function leaseMaterial(source){
  let lease=materialCache.get(source);if(lease){lease.refs++;return lease;}
  const value=source.clone(),textures=[];for(const key of Object.keys(value))if(value[key]?.isTexture){value[key]=value[key].clone();textures.push(value[key]);}
  lease={source,value,textures,refs:1};materialCache.set(source,lease);return lease;
 }
 function release(job,status){
  job.group.removeFromParent();job.iterator?.return();job.iterator=null;
  for(const geometry of job.geometries){geometryBytes-=geometry.userData.blastBytes20||0;geometry.dispose();allocatedGeometries--;}
  for(const lease of job.materials)if(--lease.refs===0){lease.value.dispose();for(const texture of lease.textures)texture.dispose();materialCache.delete(lease.source);}
  job.geometries.length=0;job.materials.length=0;job.sources.length=0;job.meshes.length=0;job.group.clear();job.ticket.status=status;
 }
 // Shared by immutable geometry identity + bone-region signature. The bounded
 // ring contains no geometry key; invalidating an entry releases its arrays.
 function signatureOf(source){return source.labels?.join(',')??`rigid:${source.region}`;}
 function* partition(source){
  const geometry=source.frozen.geometry,signature=signatureOf(source);
  const cached=topologies.get(geometry);if(cached?.layouts&&cached.signature===signature){cacheHits++;return cached.layouts;}cacheMisses++;
  const skin=geometry.attributes.skinIndex,weight=geometry.attributes.skinWeight,index=geometry.index,count=index?.count??geometry.attributes.position.count;
  const layouts=Array.from({length:6},()=>({vertexCount:0,indices:[]})),remaps=Array.from({length:6},()=>new Map()),scores=new Float64Array(6);
  // Dense six-region lookup avoids one tiny JS array allocation per vertex.
  layouts.destinations=new Int32Array(geometry.attributes.position.count*6).fill(-1);
  for(let i=0;i<count;i+=3){
   const a=index?index.getX(i):i,b=index?index.getX(i+1):i+1,c=index?index.getX(i+2):i+2;let best=source.region;
   if(source.labels){scores.fill(0);for(let corner=0;corner<3;corner++){const v=corner===0?a:corner===1?b:c;for(let j=0;j<4;j++)scores[source.labels[skin.getComponent(v,j)]??0]+=weight.getComponent(v,j);}best=0;for(let r=1;r<6;r++)if(scores[r]>scores[best])best=r;}
   const layout=layouts[best],remap=remaps[best];for(let corner=0;corner<3;corner++){const v=corner===0?a:corner===1?b:c;let target=remap.get(v);if(target===undefined){target=remap.size;remap.set(v,target);layout.vertexCount++;layouts.destinations[v*6+best]=target;}layout.indices.push(target);}yield 0;
  }
  for(const layout of layouts){layout.indices=layout.vertexCount>65535?new Uint32Array(layout.indices):new Uint16Array(layout.indices);yield 0;}
  if(topologyEntries.length>=maxTopologyEntries)topologyEntries.shift().layouts=null;
  const entry={signature,layouts};topologyEntries.push(entry);topologies.set(geometry,entry);return layouts;
 }
 // Optional loading/actor-preparation API. Sharing is explicit, then verified
 // incrementally by exact index/skin values. Position/UV/color may differ because
 // these are read fresh from the destination geometry when the death is baked.
 function prepare({geometry,boneNames,rigidBoneName,sharedFrom}={}){
  if(disposed||!geometry?.attributes.position)return {ok:false,reason:'preparation-unavailable'};
  const count=geometry.index?.count??geometry.attributes.position.count;if(!Number.isSafeInteger(count)||count<=0||count%3||count/3>maxTrianglesPerVictim||geometry.attributes.position.count>maxTrianglesPerVictim*3)return {ok:false,reason:'geometry-capacity'};
  const skinned=!!geometry.attributes.skinIndex;
  if(skinned&&(!Array.isArray(boneNames)||!boneNames.every(n=>typeof n==='string')||!geometry.attributes.skinWeight)||!skinned&&typeof rigidBoneName!=='string')return {ok:false,reason:'invalid-layout'};
  const source={frozen:{geometry},labels:skinned?boneNames.map(regionOf):null,region:skinned?0:regionOf(rigidBoneName)},signature=signatureOf(source),ticket={status:'pending',shared:false};
  const cached=topologies.get(geometry);if(cached?.layouts&&cached.signature===signature){ticket.status='ready';ticket.shared=true;return {ok:true,ticket};}
  const queued=preparing.find(job=>job.geometry===geometry&&job.signature===signature);if(queued)return {ok:true,ticket:queued.ticket};
  if(preparing.length>=maxTopologyEntries)return {ok:false,reason:'preparation-unavailable'};
  function* work(){
   const candidate=sharedFrom&&topologies.get(sharedFrom);
   if(candidate?.layouts&&candidate.signature===signature&&geometry.attributes.position.count===sharedFrom.attributes.position.count){
    let equal=true;for(const name of ['index','skinIndex','skinWeight']){
     const a=name==='index'?geometry.index:geometry.attributes[name],b=name==='index'?sharedFrom.index:sharedFrom.attributes[name];
     if(!a&&!b)continue;if(!a||!b||a.count!==b.count||a.itemSize!==b.itemSize){equal=false;break;}
     for(let i=0;i<a.count;i++){for(let j=0;j<a.itemSize;j++)if(a.getComponent(i,j)!==b.getComponent(i,j)){equal=false;break;}yield 0;if(!equal)break;}if(!equal)break;
    }
    // A candidate may be evicted while verification yields. Never publish an
    // invalidated or unverified entry; fall back to its own exact partition.
    if(equal&&candidate.layouts){topologies.set(geometry,candidate);verifiedCloneShares++;ticket.shared=true;return;}
   }
   yield* partition(source);
  }
  preparing.push({iterator:work(),ticket,geometry,signature});return {ok:true,ticket};
 }
 function* build(job){
  const point=new THREE.Vector3(),a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3(),cross=new THREE.Vector3(),edge=new THREE.Vector3();
  const bounds=regions.map(()=>new THREE.Box3());
  for(const source of job.sources){
   const mesh=source.frozen,g=mesh.geometry,layouts=yield* partition(source),fragments=Array(6).fill(null),sourceUv=g.attributes.uv,sourceColor=g.attributes.color;
   for(let r=0;r<6;r++){
    const {vertexCount,indices}=layouts[r];if(!indices.length)continue;if(job.meshes.length>=maxMeshesPerVictim)throw Error('layout-capacity');
    const geometry=new THREE.BufferGeometry();job.geometries.push(geometry);allocatedGeometries++;
    const position=new THREE.BufferAttribute(new Float32Array(vertexCount*3),3),normal=new THREE.BufferAttribute(new Float32Array(vertexCount*3),3);
    geometry.setAttribute('position',position);geometry.setAttribute('normal',normal);geometry.setIndex(new THREE.BufferAttribute(indices.slice(),1));yield 0;
    const uv=sourceUv?new THREE.BufferAttribute(new Float32Array(vertexCount*2),2):null,color=sourceColor?new THREE.BufferAttribute(new Float32Array(vertexCount*3),3):null;
    if(uv)geometry.setAttribute('uv',uv);if(color)geometry.setAttribute('color',color);
    geometry.userData.blastBytes20=Object.values(geometry.attributes).reduce((n,attr)=>n+attr.array.byteLength,geometry.index.array.byteLength);geometryBytes+=geometry.userData.blastBytes20;
    geometry.boundingBox=new THREE.Box3();fragments[r]={position,normal,uv,color,geometry};
    const fragment=new THREE.Mesh(geometry,source.material.value);job.parts[r].add(fragment);job.meshes.push(fragment);
    yield 0;
   }
   // One source vertex bake also writes all its exact fragment destinations and
   // bounds. No intermediate posed array or second vertex-copy pass is needed.
   for(let v=0;v<g.attributes.position.count;v++){
    yield 1;mesh.getVertexPosition(v,point).applyMatrix4(mesh.matrixWorld);bakedVertices++;
    for(let r=0;r<6;r++){const target=layouts.destinations[v*6+r];if(target<0)continue;const f=fragments[r];f.position.setXYZ(target,point.x,point.y,point.z);if(f.uv)f.uv.setXY(target,sourceUv.getX(v),sourceUv.getY(v));if(f.color)f.color.setXYZ(target,sourceColor.getX(v),sourceColor.getY(v),sourceColor.getZ(v));a.fromBufferAttribute(f.position,target);f.geometry.boundingBox.expandByPoint(a);bounds[r].expandByPoint(a);}
   }
   for(let r=0;r<6;r++){
    const f=fragments[r];if(!f)continue;const {position,normal}=f,indices=layouts[r].indices;
    for(let i=0;i<indices.length;i+=3){const ia=indices[i],ib=indices[i+1],ic=indices[i+2];a.fromBufferAttribute(position,ia);b.fromBufferAttribute(position,ib);c.fromBufferAttribute(position,ic);cross.subVectors(c,b);edge.subVectors(a,b);cross.cross(edge);for(let corner=0;corner<3;corner++){const v=corner===0?ia:corner===1?ib:ic;point.fromBufferAttribute(normal,v).add(cross);normal.setXYZ(v,point.x,point.y,point.z);}yield 0;}
   }
  }
  for(let r=0;r<6;r++){
   const part=job.parts[r];if(!part.children.length)continue;const center=bounds[r].getCenter(new THREE.Vector3());
   // Sync reference normalizes once in computeVertexNormals and again in
   // geometry.translate's identity normalMatrix, with Float32 rounding between.
   // Fusing both passes preserves that rounding; this is not an accidental repeat.
   for(const mesh of part.children){const p=mesh.geometry.attributes.position,n=mesh.geometry.attributes.normal;for(let v=0;v<p.count;v++){p.setXYZ(v,p.getX(v)-center.x,p.getY(v)-center.y,p.getZ(v)-center.z);point.fromBufferAttribute(n,v).normalize();n.setXYZ(v,point.x,point.y,point.z);point.fromBufferAttribute(n,v).normalize();n.setXYZ(v,point.x,point.y,point.z);yield 0;}mesh.geometry.boundingBox.translate(center.clone().negate());}
   part.position.copy(center);const direction=center.clone().sub(job.receipt.origin);direction.y=Math.max(.3,direction.y);if(direction.lengthSq()<1e-8)direction.set(0,1,0);direction.normalize();
   const motion={part,start:center,velocity:direction.multiplyScalar(Math.min(8,job.receipt.impulse)*(1+r*.04)),spin:new THREE.Vector3(.4+r*.17,.3-r*.08,.15+r*.12)};
   if(groundHeight){const localBounds=bounds[r].clone().translate(center.clone().negate());motion.ground=createNpcBlastGround20({position:center,velocity:motion.velocity,angularVelocity:motion.spin,localBounds,eventAt:job.receipt.eventAt,lifetime});motion.groundProbed=false;motion.groundVisits=0;motion.groundQueries=0;}
   job.motion.push(motion);
  }
  return true;
 }
 function pruneLedger(now){
  for(const ledger of [receipts,deaths])for(const [key,expiresAt]of ledger)if(now>=expiresAt)ledger.delete(key);
  for(const list of [pending,active])for(let i=list.length-1;i>=0;i--)if(now-list[i].receipt.eventAt>=lifetime){release(list[i],'expired');list.splice(i,1);}
 }
 function admit({receipt,actor,now}={}){
  if(disposed||!Number.isFinite(now)||now<lastNow||!receipt||receipt.confirmed!==true||receipt.deathConfirmed!==true||receipt.cause!=='blast'||!validId(receipt.eventId)||!validId(receipt.deathKey)||!validId(receipt.actorId)||receipt.actorId!==actor?.id||!finitePoint(receipt.origin)||!Number.isFinite(receipt.impulse)||receipt.impulse<0||!Number.isFinite(receipt.eventAt)||receipt.eventAt>now)return {ok:false,reason:'unconfirmed-or-invalid-blast'};
  pruneLedger(now);lastNow=now;
  // Stale packets cannot recreate a history entry after its TTL has been pruned.
  // eventAt is immutable source time; the host must never rebase it on retries.
  const expiresAt=receipt.eventAt+8;if(now>=expiresAt||now-receipt.eventAt>=lifetime)return {ok:false,reason:'expired'};
  const key=JSON.stringify([receipt.actorId,receipt.deathKey,receipt.eventId]),death=JSON.stringify([receipt.actorId,receipt.deathKey]);
  if(receipts.has(key))return {ok:false,reason:'duplicate'};if(deaths.has(death))return {ok:false,reason:'death-already-presented'};
  // A full victim pool is transient: no ledger entry, retry until source TTL.
  if(active.length+pending.length>=maxVictims)return {ok:false,reason:'capacity'};
  if(receipts.size>=maxReceipts)return {ok:false,reason:'receipt-capacity'};
  const root=actor.walker?.artistContext?.().scene;if(!root)return {ok:false,reason:'rig-unavailable'};
  root.updateWorldMatrix(true,true);const sources=[];let triangles=0;
  root.traverse(mesh=>{if(!mesh.isMesh||!mesh.geometry?.attributes.position||mesh.userData.bulletWound)return;for(let n=mesh;n;n=n.parent)if(n.visible===false||n===actor.weapon)return;sources.push(mesh);triangles+=(mesh.geometry.index?.count??mesh.geometry.attributes.position.count)/3;});
  if(!sources.length||triangles>maxTrianglesPerVictim)return {ok:false,reason:'geometry-capacity'};
  if(sources.some(mesh=>Array.isArray(mesh.material)||mesh.isSkinnedMesh&&(!mesh.geometry.attributes.skinIndex||!mesh.geometry.attributes.skinWeight)))return {ok:false,reason:'layout-unsupported'};
  const group=new THREE.Group(),parts=regions.map(name=>{const p=new THREE.Group();p.name='BlastPart20_'+name;group.add(p);return p;});
  const ticket={status:'pending',group,parts:0,meshes:0,triangles},job={group,parts,meshes:[],materials:[],sources:[],geometries:[],motion:[],ticket,receipt:{...receipt,origin:{...receipt.origin}}};
  const skeletons=new Map();
  try{for(const mesh of sources){
   const frozen=Object.create(mesh.isSkinnedMesh?THREE.SkinnedMesh.prototype:THREE.Mesh.prototype);frozen.geometry=mesh.geometry;frozen.matrixWorld=mesh.matrixWorld.clone();frozen.morphTargetInfluences=mesh.morphTargetInfluences?.slice();let labels=null,region=0;
   if(mesh.isSkinnedMesh){let skeleton=skeletons.get(mesh.skeleton);if(!skeleton){skeleton={bones:mesh.skeleton.bones.map(b=>({matrixWorld:b.matrixWorld.clone()})),boneInverses:mesh.skeleton.boneInverses.map(m=>m.clone())};skeletons.set(mesh.skeleton,skeleton);}frozen.skeleton=skeleton;frozen.bindMatrix=mesh.bindMatrix.clone();frozen.bindMatrixInverse=mesh.bindMatrixInverse.clone();labels=mesh.skeleton.bones.map(b=>regionOf(b.name));}
   else{let bone=mesh.parent;while(bone&&!bone.isBone)bone=bone.parent;if(!bone)throw Error('layout-unsupported');region=regionOf(bone.name);}
   const material=leaseMaterial(mesh.material);job.materials.push(material);job.sources.push({frozen,labels,region,material});
  }}catch(error){release(job,'failed');return {ok:false,reason:error.message};}
  job.iterator=build(job);pending.push(job);receipts.set(key,expiresAt);deaths.set(death,expiresAt);admitted++;return {ok:true,ticket};
 }
 function animate(job,now){const age=Math.max(0,now-job.receipt.eventAt);for(const m of job.motion){m.part.position.copy(m.start).addScaledVector(m.velocity,age);m.part.position.y-=4.905*age*age;m.part.rotation.set(m.spin.x*age,m.spin.y*age,m.spin.z*age);}}
 function groundStep(now){
  groundQueriesLast=0;groundVisitsLast=0;const parts=active.flatMap(job=>job.motion);if(!parts.length){groundCursor=0;return;}
  groundCursor%=parts.length;let idle=0;
  // 18 = one revalidation sample + at least one progress/contact sample.
  // The last <18 queries stay unused. Rotate the next starting part across
  // frames: 12 flying parts cannot all receive 18 within a shared cap of 192.
  while(groundQueryBudget-groundQueriesLast>=18&&idle<parts.length){
   const m=parts[groundCursor];groundCursor=(groundCursor+1)%parts.length;
   if(m.ground.status!=='flying'||m.groundProbed&&m.ground.elapsed>=Math.max(0,now-m.ground.eventAt)-1e-9){idle++;continue;}
   idle=0;const next=stepNpcBlastGround20(m.ground,{now,maxQueries:18,groundHeight:(x,z)=>{try{return groundHeight(x,z,m.ground.position.y);}catch{return NaN;}}});
   m.ground=next;m.groundProbed=true;m.groundVisits++;m.groundQueries+=next.queries;groundQueriesLast+=next.queries;groundVisitsLast++;
   m.part.position.copy(next.position);m.part.quaternion.set(next.quaternion.x,next.quaternion.y,next.quaternion.z,next.quaternion.w);
  }
 }
 function update(now){
  if(disposed||!Number.isFinite(now)||now<lastNow)return [];lastNow=now;
  const start=clock(),ready=[];lastWork=0;lastVertices=0;
  pruneLedger(now);
  while(pending.length&&lastWork<maxWorkPerStep&&clock()-start<budgetMs){
   const job=pending[0];try{job.step??=job.iterator.next();if(job.step.value===1&&lastVertices>=maxVerticesPerStep)break;lastWork++;lastVertices+=job.step.value===1?1:0;const step=job.step=job.iterator.next();if(step.done){pending.shift();job.iterator=null;job.sources.length=0;job.ticket.status='ready';job.ticket.parts=job.motion.length;job.ticket.meshes=job.meshes.length;if(!groundHeight)animate(job,now);scene.add(job.group);active.push(job);ready.push(job.ticket);}}
   catch(error){pending.shift();job.ticket.reason=error.message;release(job,'failed');}
  }
  // Death jobs have priority; preparation uses only this same update budget.
  while(!pending.length&&preparing.length&&lastWork<maxWorkPerStep&&clock()-start<budgetMs){const job=preparing[0];try{const step=job.iterator.next();lastWork++;if(step.done){job.ticket.status='ready';preparing.shift();}}catch(error){job.iterator.return();job.ticket.status='failed';job.ticket.reason=error.message;preparing.shift();}}
  if(groundHeight)groundStep(now);else for(const job of active)animate(job,now);
  lastSliceMs=clock()-start;maxSliceMs=Math.max(maxSliceMs,lastSliceMs);return ready;
 }
 function cull(actorId,deathKey){let count=0;for(const list of [pending,active])for(let i=list.length-1;i>=0;i--)if(list[i].receipt.actorId===actorId&&list[i].receipt.deathKey===deathKey){release(list[i],'culled');list.splice(i,1);count++;}return count;}
 return {admit,update,cull,prepare,groundDiagnostics:()=>active.flatMap(job=>job.motion.filter(m=>m.ground).map(m=>({actorId:job.receipt.actorId,deathKey:job.receipt.deathKey,part:m.part.name,status:m.ground.status,reason:m.ground.reason,elapsed:m.ground.elapsed,pendingSeconds:m.ground.status==='flying'?Math.max(0,lastNow-m.ground.eventAt-m.ground.elapsed):0,visits:m.groundVisits,queries:m.groundQueries,position:{...m.ground.position},quaternion:{...m.ground.quaternion}}))),stats:()=>({pendingVictims:pending.length,activeVictims:active.length,pendingPreparations:preparing.length,parts:active.reduce((n,j)=>n+j.motion.length,0),meshes:active.reduce((n,j)=>n+j.meshes.length,0),groundEnabled:!!groundHeight,groundQueryBudget,groundQueriesLast,groundVisitsLast,topologyEntries:topologyEntries.length,topologyBytes:topologyEntries.reduce((n,entry)=>n+(entry.layouts?entry.layouts.destinations.byteLength+entry.layouts.reduce((sum,l)=>sum+l.indices.byteLength,0):0),0),materialLeases:materialCache.size,textureHandles:[...materialCache.values()].reduce((n,l)=>n+l.textures.length,0),receipts:receipts.size,deathReceipts:deaths.size,admitted,cacheHits,cacheMisses,verifiedCloneShares,bakedVertices,allocatedGeometries,geometryBytes,maxSliceMs,lastSliceMs,lastWork,lastVertices}),dispose(){if(disposed)return;disposed=true;for(const job of [...pending,...active])release(job,'disposed');for(const job of preparing){job.iterator.return();job.ticket.status='disposed';}preparing.length=0;pending.length=0;active.length=0;receipts.clear();deaths.clear();for(const entry of topologyEntries)entry.layouts=null;topologyEntries.length=0;groundQueriesLast=0;groundVisitsLast=0;}};
}
