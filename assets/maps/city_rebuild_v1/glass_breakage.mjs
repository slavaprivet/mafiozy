// Presentation only. The host owns damage admission, HP, ownership and saves.
// faceIndex stays stable: broken triangles become degenerate in an instance-owned
// index buffer. No shared GLB geometry/material or sibling instance is changed.
export function isBreakableGlass(mesh,material){
 if(mesh?.userData?.breakableGlass===false||material?.userData?.breakableGlass===false)return false;
 if(mesh?.userData?.breakableGlass===true||material?.userData?.breakableGlass===true)return true;
 const label=String(material?.name||'');
 if(/glass|glazing|windshield|windscreen/i.test(label))return true;
 // Mixed meshes must opt in by material, never by their parent mesh's name.
 if(!Array.isArray(mesh?.material)&&/glass|glazing|windshield|windscreen/i.test(String(mesh?.name||'')))return true;
 return !!(material?.transmission>0&&material?.opacity!==0);
}

function faceMaterial(g,face){const offset=face*3;return g.groups.find(x=>offset>=x.start&&offset<x.start+x.count)?.materialIndex??0}
function materials(mesh){return Array.isArray(mesh.material)?mesh.material:[mesh.material]}
function visible(mesh){for(let n=mesh;n;n=n.parent)if(!n.visible)return false;return true}

// Shared edges connect a panel; a corner touching another pane does not. Welding
// discovers connectivity across authored UV/normal seams without modifying them.
export function discoverGlassPanels(mesh){
 const g=mesh.geometry,p=g?.attributes?.position;if(!p)return {panels:[],facePanel:new Map()};
 const ix=g.index,faceCount=Math.floor((ix?.count??p.count)/3),mats=materials(mesh),parents=new Int32Array(faceCount).fill(-1),edges=new Map(),vertexKeys=[];
 for(let i=0;i<p.count;i++)vertexKeys.push(`${Math.round(p.getX(i)*1e5)},${Math.round(p.getY(i)*1e5)},${Math.round(p.getZ(i)*1e5)}`);
 const vertex=i=>ix?ix.getX(i):i,materialAt=f=>Array.isArray(mesh.material)?faceMaterial(g,f):0;
 function find(i){let root=i;while(parents[root]!==root)root=parents[root];while(i!==root){const next=parents[i];parents[i]=root;i=next}return root}
 for(let f=0;f<faceCount;f++){
  const mi=materialAt(f);if(!isBreakableGlass(mesh,mats[mi]))continue;
  const ia=vertex(f*3),ib=vertex(f*3+1),ic=vertex(f*3+2),abx=p.getX(ib)-p.getX(ia),aby=p.getY(ib)-p.getY(ia),abz=p.getZ(ib)-p.getZ(ia),acx=p.getX(ic)-p.getX(ia),acy=p.getY(ic)-p.getY(ia),acz=p.getZ(ic)-p.getZ(ia),nx=aby*acz-abz*acy,ny=abz*acx-abx*acz,nz=abx*acy-aby*acx;
  // Runtime clipping can keep zero-area bookkeeping triangles. They are neither
  // ray-hittable panes nor independent glass components.
  if(nx*nx+ny*ny+nz*nz<1e-16)continue;parents[f]=f;
  for(let e=0;e<3;e++){const a=vertexKeys[vertex(f*3+e)],b=vertexKeys[vertex(f*3+(e+1)%3)];if(a===b)continue;const key=`${mi}:${a<b?a+'|'+b:b+'|'+a}`;if(edges.has(key))parents[find(f)]=find(edges.get(key));else edges.set(key,f)}
 }
 const grouped=new Map(),facePanel=new Map();
 for(let f=0;f<faceCount;f++)if(parents[f]>=0){const root=find(f);if(!grouped.has(root))grouped.set(root,{id:root,materialIndex:materialAt(f),faces:[]});const panel=grouped.get(root);panel.faces.push(f);facePanel.set(f,panel)}
 return {panels:[...grouped.values()],facePanel};
}

function convexHull(points){
 const sorted=[...new Map(points.map(p=>[`${p.x.toFixed(5)}:${p.y.toFixed(5)}`,p])).values()].sort((a,b)=>a.x-b.x||a.y-b.y);
 if(sorted.length<3)return sorted;const cross=(a,b,c)=>(b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x),lo=[],hi=[];
 for(const p of sorted){while(lo.length>1&&cross(lo.at(-2),lo.at(-1),p)<=0)lo.pop();lo.push(p)}for(const p of sorted.slice().reverse()){while(hi.length>1&&cross(hi.at(-2),hi.at(-1),p)<=0)hi.pop();hi.push(p)}lo.pop();hi.pop();return lo.concat(hi);
}
function generator(seed){let state=seed>>>0;return()=>{state=(1664525*state+1013904223)>>>0;return state/4294967296}}

export function createGlassBreakage(THREE,scene,options={}){
 const T=THREE;if(!T?.Mesh||!scene?.add)throw Error('THREE and scene required');
 const limits={shards:Math.max(8,Math.min(512,options.maxShards??192)),panels:Math.max(1,Math.min(256,options.maxDecoratedPanels??80)),perHit:Math.max(6,Math.min(64,options.shardsPerHit??28))};
 const registry=new Map(),decorations=[],pendingFractures=new Set(),activeShardSlots=new Set(),group=new T.Group();group.name='World_Glass_Shards';group.userData.breakableGlass=false;scene.add(group);
 const shardGeometry=new T.BufferGeometry();shardGeometry.setAttribute('position',new T.Float32BufferAttribute([-.5,-.35,0,.5,-.32,0,-.12,.58,0,-.5,-.35,.028,-.12,.58,.028,.5,-.32,.028,-.5,-.35,0,-.5,-.35,.028,.5,-.32,0,.5,-.32,0,-.5,-.35,.028,.5,-.32,.028,.5,-.32,0,.5,-.32,.028,-.12,.58,0,-.12,.58,0,.5,-.32,.028,-.12,.58,.028,-.12,.58,0,-.12,.58,.028,-.5,-.35,0,-.5,-.35,0,-.12,.58,.028,-.5,-.35,.028],3));shardGeometry.computeVertexNormals();
 const shardMaterial=new T.MeshPhysicalMaterial({color:0xb4dfdc,metalness:.23,roughness:.12,transparent:true,opacity:.73,depthWrite:false,side:T.DoubleSide,clearcoat:1});
 const particles=new T.InstancedMesh(shardGeometry,shardMaterial,limits.shards);particles.name='Flying_Glass_Shards';particles.userData.breakableGlass=false;particles.frustumCulled=false;particles.raycast=()=>{};group.add(particles);
 const zero=new T.Matrix4().makeScale(0,0,0),matrix=new T.Matrix4(),q=new T.Quaternion(),scale=new T.Vector3(),sceneInverse=new T.Matrix4();
 // Shards are a fixed-size GPU pool.  Keep their simulation records equally
 // fixed-size, so a vehicle blast that emits a full pane does not allocate 28
 // vectors, Euler objects and wrapper objects at the exact impact frame.
 const shards=Array.from({length:limits.shards},()=>({source:null,position:new T.Vector3(),velocity:new T.Vector3(),rotation:new T.Euler(),spin:new T.Vector3(),size:0,life:0})),shardNormal=new T.Vector3(),shardSide=new T.Vector3(),shardUp=new T.Vector3(),shardDirection=new T.Vector3(),shardUv=new T.Vector2(),shardPosition=new T.Vector3(),shardColor=new T.Color();for(let i=0;i<limits.shards;i++)particles.setMatrixAt(i,zero);
 const crackMaterial=new T.LineBasicMaterial({color:0xd8f2e9,transparent:true,opacity:.89,depthWrite:false,toneMapped:true}),rimMaterial=new T.MeshPhysicalMaterial({color:0x82b5b1,transparent:true,opacity:.68,roughness:.2,metalness:.18,side:T.DoubleSide,depthWrite:false});
 let cursor=0,totalBroken=0,disposed=false;
 function prepare(root){if(disposed)return 0;let count=0;root?.traverse?.(mesh=>{if(!mesh.isMesh||mesh.isSkinnedMesh||mesh.userData.glassEffect||registry.has(mesh)||!materials(mesh).some(m=>isBreakableGlass(mesh,m)))return;registry.set(mesh,{mesh,geometry:mesh.geometry,instanceMatrix:null,replacements:new Map(),ownedGeometry:null,analysis:null,broken:new Set()});count++});return count}
 function analysis(record){return record.analysis??=discoverGlassPanels(record.mesh)}
 function targetFor(record,instanceId){
  if(!record.mesh.isInstancedMesh){if(!record.ownedGeometry){record.ownedGeometry=record.geometry.clone();if(!record.ownedGeometry.index)record.ownedGeometry.setIndex(Array.from({length:record.geometry.attributes.position.count},(_,i)=>i));record.mesh.geometry=record.ownedGeometry}return record.mesh}
  if(record.replacements.has(instanceId))return record.replacements.get(instanceId);
  if(!record.instanceMatrix){record.instanceMatrix=record.mesh.instanceMatrix;record.mesh.dispose();record.mesh.instanceMatrix=record.instanceMatrix.clone()}
  const transform=new T.Matrix4();record.mesh.getMatrixAt(instanceId,transform);const geometry=record.geometry.clone();if(!geometry.index)geometry.setIndex(Array.from({length:geometry.attributes.position.count},(_,i)=>i));
  const target=new T.Mesh(geometry,record.mesh.material);target.name=`${record.mesh.name}_BrokenInstance_${instanceId}`;target.userData.glassEffect=true;target.matrixAutoUpdate=false;target.matrix.copy(transform);target.castShadow=record.mesh.castShadow;target.receiveShadow=record.mesh.receiveShadow;record.mesh.add(target);record.mesh.setMatrixAt(instanceId,zero);record.mesh.instanceMatrix.needsUpdate=true;record.replacements.set(instanceId,target);return target;
 }
 function surface(record,panel,localPoint,normal){
  const geometry=record.geometry,p=geometry.attributes.position,ix=geometry.index,triangles=[],vertices=[];normal.normalize();const u=new T.Vector3().crossVectors(Math.abs(normal.y)<.9?new T.Vector3(0,1,0):new T.Vector3(1,0,0),normal).normalize(),v=new T.Vector3().crossVectors(normal,u).normalize();
  for(const f of panel.faces){const tri=[];for(let j=0;j<3;j++){const pos=new T.Vector3().fromBufferAttribute(p,ix?ix.getX(f*3+j):f*3+j);tri.push(pos);vertices.push(new T.Vector2(pos.clone().sub(localPoint).dot(u),pos.clone().sub(localPoint).dot(v)))}triangles.push(tri)}
  const hull=convexHull(vertices),bounds=new T.Box3().setFromPoints(triangles.flat()),depth=Math.max(.1,bounds.getSize(new T.Vector3()).length()),ray=new T.Ray(),scratch=new T.Vector3(),plane=new T.Vector3(),origin=new T.Vector3(),rayDirection=normal.clone().negate(),pointScratch=new T.Vector3();
  // decorate() projects many rim and crack endpoints on the very same pane.
  // They are consumed immediately into typed arrays, so its plane/origin/result
  // vectors can be reused without changing any projected coordinate.
  function point(uv,out=pointScratch){plane.copy(localPoint).addScaledVector(u,uv.x).addScaledVector(v,uv.y);origin.copy(plane).addScaledVector(normal,depth);ray.set(origin,rayDirection);let distance=Infinity,best=false;for(const tri of triangles){if(ray.intersectTriangle(...tri,false,scratch)){const d=scratch.distanceToSquared(origin);if(d<distance){distance=d;out.copy(scratch);best=true}}}return (best?out:out.copy(plane)).addScaledVector(normal,.002)}
  return {hull,point,normal,u,v,triangles};
 }
 function decorate(record,target,panel,localPoint,normal,key,random){
  const s=surface(record,panel,localPoint,normal),hull=s.hull;if(hull.length<3)return null;
  const root=new T.Group();root.name='Broken_Glass_Edges';root.userData.glassEffect=true;root.userData.breakableGlass=false;target.add(root);
  const centroid=hull.reduce((a,b)=>a.add(b),new T.Vector2()).multiplyScalar(1/hull.length),center=new T.Vector2(0,0),segments=[],rim=[];
  // If an impact sits exactly at the outer edge, keep fracture spokes inside.
  center.lerp(centroid,.025);
  const addLine=(a,b)=>{segments.push(...s.point(a).toArray(),...s.point(b).toArray())};
  const spokes=[];
  for(let i=0;i<hull.length;i++){
   const a=hull[i],b=hull[(i+1)%hull.length],length=a.distanceTo(b),steps=Math.min(12,Math.max(2,Math.ceil(length/.22)));
   for(let j=0;j<steps;j++){
    const outerA=a.clone().lerp(b,j/steps),outerB=a.clone().lerp(b,(j+1)/steps),innerA=outerA.clone().lerp(center,.012+random()*.045),innerB=outerB.clone().lerp(center,.012+random()*.045);
    for(const uv of [outerA,outerB,innerA,innerA,outerB,innerB])rim.push(...s.point(uv).toArray());
    if(spokes.length<42){const end=outerA.clone().lerp(outerB,.2+random()*.6),mid=center.clone().lerp(end,.30+random()*.27);mid.lerp(centroid,random()*.035);addLine(center,mid);addLine(mid,end);const branch=mid.clone().lerp(end,.30);branch.lerp(outerB,.12);addLine(mid,branch);spokes.push(end)}
   }
  }
  for(const fraction of [.13,.29,.51,.76])for(let i=0;i<spokes.length;i++){const a=center.clone().lerp(spokes[i],fraction*(.86+random()*.22)),b=center.clone().lerp(spokes[(i+1)%spokes.length],fraction*(.86+random()*.22));addLine(a,b)}
  const cg=new T.BufferGeometry();cg.setAttribute('position',new T.Float32BufferAttribute(segments,3));const cracks=new T.LineSegments(cg,crackMaterial);cracks.raycast=()=>{};root.add(cracks);
  const rg=new T.BufferGeometry();rg.setAttribute('position',new T.Float32BufferAttribute(rim,3));rg.computeVertexNormals();const edges=new T.Mesh(rg,rimMaterial);edges.userData.breakableGlass=false;edges.raycast=()=>{};root.add(edges);edges.visible=false;
  const entry={root,cracks,edges,geometries:[cg,rg],age:0,target,panel,key,record,fractured:false,surface:s};decorations.push(entry);pendingFractures.add(entry);while(decorations.length>limits.panels){const old=decorations.shift();pendingFractures.delete(old);fracture(old);removeDecoration(old)}return entry;
 }
 function removeDecoration(d){d.root.removeFromParent();for(const g of d.geometries)g.dispose()}
 function fracture(d){if(d.fractured)return;d.fractured=true;const index=d.target.geometry.index;for(const f of d.panel.faces){const first=index.getX(f*3);index.setX(f*3+1,first);index.setX(f*3+2,first)}index.needsUpdate=true;d.edges.visible=true;d.cracks.visible=false}
 function spawnShards(d,point,direction,impulse,random,velocity){
  d.target.updateWorldMatrix(true,false);const world=d.target.matrixWorld,normal=shardNormal.copy(d.surface.normal).transformDirection(world),side=shardSide.copy(d.surface.u).transformDirection(world),up=shardUp.copy(d.surface.v).transformDirection(world),dir=direction?.isVector3?shardDirection.copy(direction).normalize():shardDirection.copy(normal).negate(),power=Math.max(.5,Math.min(4,Math.sqrt(Math.max(1,Number(impulse)||20))/3));
  const hull=d.surface.hull,count=limits.perHit;for(let j=0;j<count;j++){
   const a=hull[j%hull.length],b=hull[(j+1)%hull.length],uv=shardUv.copy(a).lerp(b,random()).multiplyScalar(Math.sqrt(random())),position=d.surface.point(uv,shardPosition).applyMatrix4(world),size=.028+random()*.11;
   const slot=cursor++%limits.shards,particle=shards[slot];particle.source=d.record.mesh;particle.position.copy(position);particle.velocity.copy(dir).multiplyScalar(power*(.6+random())).addScaledVector(side,(random()-.5)*power*2).addScaledVector(up,(random()-.4)*power*1.8);particle.rotation.set(random()*6,random()*6,random()*6);particle.spin.set((random()-.5)*18,(random()-.5)*18,(random()-.5)*18);particle.size=size;particle.life=2.2+random()*1.2;if(velocity?.isVector3)particle.velocity.add(velocity);activeShardSlots.add(slot);particles.setColorAt(slot,shardColor.setHSL(.47+random()*.04,.16+random()*.12,.58+random()*.27));
  }if(particles.instanceColor)particles.instanceColor.needsUpdate=true;return count;
 }
 function resolve(hit){
  let mesh=hit?.object,record=registry.get(mesh),instanceId=hit?.instanceId;
  if(!record){for(const r of registry.values())for(const [id,replacement]of r.replacements)if(replacement===mesh){record=r;instanceId=id;break}}
  if(!record){prepare(mesh);record=registry.get(mesh)}
  if(!record)return null;if(record.mesh.isInstancedMesh&&(!Number.isInteger(instanceId)||instanceId<0||instanceId>=record.mesh.count))return null;
  const panel=analysis(record).facePanel.get(hit.faceIndex);if(!panel)return null;return {record,panel,instanceId,key:`${instanceId??'mesh'}:${panel.id}`};
 }
 function hit(intersection,settings={}){
  if(disposed||!intersection?.point?.isVector3||!visible(intersection.object))return {broken:false,reason:'invalid-hit'};const found=resolve(intersection);if(!found)return {broken:false,reason:'not-glass-panel'};const {record,panel,instanceId,key}=found;
  if(record.broken.has(key))return {broken:false,reason:'already-broken',panelId:key};record.broken.add(key);
  const target=targetFor(record,instanceId);target.updateWorldMatrix(true,false);const localPoint=target.worldToLocal(intersection.point.clone()),normal=intersection.face?.normal?.clone()??new T.Vector3(0,0,1),random=generator((panel.id+1)*7919+(instanceId??0)*113+totalBroken*601),d=decorate(record,target,panel,localPoint,normal,key,random);
  if(!d){const ix=target.geometry.index;for(const f of panel.faces){ix.setX(f*3+1,ix.getX(f*3));ix.setX(f*3+2,ix.getX(f*3))}ix.needsUpdate=true}
  totalBroken++;const count=d?spawnShards(d,intersection.point,settings.direction,settings.impulse,random,settings.velocity):0;
  return {broken:true,panelId:key,mesh:record.mesh,instanceId,triangles:panel.faces.length,shards:count,weaponId:settings.weaponId??null};
 }
 function shatterAll(root,settings={}){
  prepare(root);const descendants=new Set();root.traverse(n=>descendants.add(n));let broken=0;
  for(const record of registry.values())if(descendants.has(record.mesh)&&visible(record.mesh)){
   const {mesh,geometry:g}=record,p=g.attributes.position;for(let id=0;id<(mesh.isInstancedMesh?mesh.count:1);id++)for(const panel of analysis(record).panels){const faceIndex=panel.faces[0],a=new T.Vector3().fromBufferAttribute(p,g.index?g.index.getX(faceIndex*3):faceIndex*3),b=new T.Vector3().fromBufferAttribute(p,g.index?g.index.getX(faceIndex*3+1):faceIndex*3+1),c=new T.Vector3().fromBufferAttribute(p,g.index?g.index.getX(faceIndex*3+2):faceIndex*3+2),normal=new T.Vector3().subVectors(b,a).cross(new T.Vector3().subVectors(c,a)).normalize(),point=a.add(b).add(c).multiplyScalar(1/3);mesh.updateWorldMatrix(true,false);if(mesh.isInstancedMesh){const transform=record.replacements.get(id)?.matrix??new T.Matrix4().fromArray((record.instanceMatrix??mesh.instanceMatrix).array,id*16);point.applyMatrix4(transform)}point.applyMatrix4(mesh.matrixWorld);if(hit({object:mesh,instanceId:mesh.isInstancedMesh?id:undefined,faceIndex,point,face:{normal}},settings).broken)broken++}
  }return {broken};
 }
 function update(dt){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('dt must be finite and non-negative');dt=Math.min(dt,.1);
  // In the normal intact/settled state both collections are empty. Avoid even
  // constructing an empty Set iterator on every render frame; this does not
  // bypass timestep validation or any live fracture/shard simulation.
  if(!pendingFractures.size&&!activeShardSlots.size)return;
  for(const d of pendingFractures){d.age+=dt;if(d.age>=.085){fracture(d);pendingFractures.delete(d)}}
  // Broken panes and empty particle slots are terminal state. Keep only the
  // short-lived fracture queue and live shard slots on the hot path.
  if(!activeShardSlots.size)return;
  const gravity=9.81*dt,velocityDrag=Math.exp(-dt*8),spinDrag=Math.exp(-dt*9),groundSampler=typeof options.groundHeight==='function'?options.groundHeight:null,defaultGround=options.groundY??.035;
  group.updateWorldMatrix(true,false);sceneInverse.copy(group.matrixWorld).invert();for(const i of activeShardSlots){
   const s=shards[i];if(s.life<=0){s.source=null;activeShardSlots.delete(i);particles.setMatrixAt(i,zero);continue}s.life-=dt;if(s.life<=0){s.source=null;activeShardSlots.delete(i);particles.setMatrixAt(i,zero);continue}s.velocity.y-=gravity;s.position.addScaledVector(s.velocity,dt);const floor=groundSampler?groundSampler(s.position.x,s.position.z):defaultGround;
   if(s.position.y<floor+s.size*.1){s.position.y=floor+s.size*.1;if(Math.abs(s.velocity.y)>.4)s.velocity.y=-s.velocity.y*.24;else s.velocity.y=0;s.velocity.x*=velocityDrag;s.velocity.z*=velocityDrag;s.spin.multiplyScalar(spinDrag)}
   s.rotation.x+=s.spin.x*dt;s.rotation.y+=s.spin.y*dt;s.rotation.z+=s.spin.z*dt;q.setFromEuler(s.rotation);scale.setScalar(s.size*Math.min(1,Math.max(0,s.life)/.3));matrix.compose(s.position,q,scale).premultiply(sceneInverse);particles.setMatrixAt(i,matrix);
  }particles.instanceMatrix.needsUpdate=true;
 }
 function reset(root=null){
  const selected=new Set();if(root)root.traverse(n=>selected.add(n));else for(const mesh of registry.keys())selected.add(mesh);
  for(let i=decorations.length-1;i>=0;i--)if(selected.has(decorations[i].record.mesh)){pendingFractures.delete(decorations[i]);removeDecoration(decorations[i]);decorations.splice(i,1)}
  for(const r of registry.values())if(selected.has(r.mesh)){if(r.ownedGeometry){if(r.mesh.geometry===r.ownedGeometry)r.mesh.geometry=r.geometry;r.ownedGeometry.dispose();r.ownedGeometry=null}for(const replacement of r.replacements.values()){replacement.removeFromParent();replacement.geometry.dispose()}r.replacements.clear();if(r.instanceMatrix){r.mesh.dispose();r.mesh.instanceMatrix=r.instanceMatrix;r.mesh.instanceMatrix.needsUpdate=true;r.instanceMatrix=null}r.broken.clear()}
  for(let i=0;i<limits.shards;i++)if(shards[i].source&&selected.has(shards[i].source)){shards[i].source=null;shards[i].life=0;activeShardSlots.delete(i);particles.setMatrixAt(i,zero)}particles.instanceMatrix.needsUpdate=true;totalBroken=[...registry.values()].reduce((sum,r)=>sum+r.broken.size,0);
 }
 function dispose(){if(disposed)return;reset();disposed=true;registry.clear();group.removeFromParent();particles.dispose();shardGeometry.dispose();shardMaterial.dispose();crackMaterial.dispose();rimMaterial.dispose()}
 function stats(){return {registeredMeshes:registry.size,brokenPanels:totalBroken,decoratedPanels:decorations.length,activeShards:activeShardSlots.size,limits:{...limits}}}
 return {prepare,hit,onHit:hit,shatterAll,update,reset,dispose,stats};
}
