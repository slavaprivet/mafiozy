// Opt-in, exact-geometry skin picking. GPU buffers/poses/materials are untouched.
// Memo lifetime is ONE canonical _computeIntersections invocation, never a frame.
export function createNpcSkinPickMemo({THREE:T}={}){
 const skin=T?.SkinnedMesh?.prototype,meshPrototype=T?.Mesh?.prototype,attributePrototype=T?.BufferAttribute?.prototype;
 const canonical={raycast:skin?.raycast,vertex:skin?.getVertexPosition,bone:skin?.applyBoneTransform,compute:meshPrototype?._computeIntersections,bounds:skin?.computeBoundingSphere,getAttribute:T?.BufferGeometry?.prototype?.getAttribute};
 const versionSupported=String(T?.REVISION)==='180'&&!!canonical.compute;
 const bindings=new Map(),scopes=new Map();let enabled=false,disposed=false,query=null;
 const counters={queries:0,cachedMeshes:0,vertexRequests:0,skinEvaluations:0,cacheHits:0,nestedFallbacks:0,guardFallbacks:0,admissionRejected:0,lostOwnership:0};
 const own=(o,k)=>Object.getOwnPropertyDescriptor(o,k);
 function replaceable(o,key){const d=own(o,key);return d?'value'in d&&(d.configurable||d.writable):Object.isExtensible(o);}
 function install(o,key,value){const d=own(o,key);Object.defineProperty(o,key,d?{...d,value}:{value,writable:true,configurable:true,enumerable:true});}
 function restore(o,key,d){if(d)Object.defineProperty(o,key,d);else delete o[key];}
 function supported(mesh,compute=canonical.compute){
  if(!versionSupported||Object.getPrototypeOf(mesh)!==skin)return false;
  for(const key of ['raycast','getVertexPosition','applyBoneTransform','_computeIntersections','geometry','material']){const d=own(mesh,key);if(d&&!('value'in d))return false;}
  if(mesh.raycast!==canonical.raycast||mesh.getVertexPosition!==canonical.vertex||mesh.applyBoneTransform!==canonical.bone||mesh._computeIntersections!==compute||mesh.computeBoundingSphere!==canonical.bounds||!replaceable(mesh,'getVertexPosition'))return false;
  const g=mesh.geometry,count=g?.attributes?.position?.count;
  if(!g?.index||g.getAttribute!==canonical.getAttribute||!Number.isInteger(count)||count<=0||count>1000000)return false;
  for(const a of [g.index,...Object.values(g.attributes),...Object.values(g.morphAttributes).flat()]){
   if(!a?.isBufferAttribute||a.isInterleavedBufferAttribute||!['getX','getY','getZ','getW','getComponent'].every(k=>a[k]===attributePrototype[k]))return false;
  }
  for(const material of Array.isArray(mesh.material)?mesh.material:[mesh.material]){const d=material&&own(material,'side');if(!d||!('value'in d))return false;}
  return true;
 }
 function suspend(binding,run){
  const scope=scopes.get(binding);if(!scope)return run();counters.nestedFallbacks++;
  // A reentrant native ray must not consume another invocation's cached values.
  const owns=binding.mesh.getVertexPosition===scope.wrapper;
  if(owns)restore(binding.mesh,'getVertexPosition',scope.descriptor);
  scopes.delete(binding);
  try{return run();}finally{
   scope.seen.fill(0);
   if(owns&&binding.mesh.getVertexPosition===canonical.vertex){install(binding.mesh,'getVertexPosition',scope.wrapper);scopes.set(binding,scope);}
  }
 }
 function compute(binding,ray,hits,localRay){
  const mesh=binding.mesh;
  if(scopes.has(binding))return suspend(binding,()=>canonical.compute.call(mesh,ray,hits,localRay));
  if(disposed||!enabled||!query||query.ray!==ray)return canonical.compute.call(mesh,ray,hits,localRay);
  if(!supported(mesh,binding.wrapper)){counters.guardFallbacks++;return canonical.compute.call(mesh,ray,hits,localRay);}
  const count=mesh.geometry.attributes.position.count,descriptor=own(mesh,'getVertexPosition');
  const scope={descriptor,seen:new Uint8Array(count),values:new Float64Array(count*3),wrapper:null,requests:0,evaluations:0,hits:0};
  scope.wrapper=function(index,target){
   // Preserve borrowed-method behavior; only this mesh owns these cached vertices.
   if(this!==mesh)return canonical.vertex.call(this,index,target);
   scope.requests++;
   if(scope.seen[index]){scope.hits++;return target.fromArray(scope.values,index*3);}
   scope.evaluations++;canonical.vertex.call(this,index,target);
   target.toArray(scope.values,index*3);scope.seen[index]=1;return target;
  };
  install(mesh,'getVertexPosition',scope.wrapper);scopes.set(binding,scope);counters.cachedMeshes++;
  try{return canonical.compute.call(mesh,ray,hits,localRay);}finally{
   scopes.delete(binding);
   if(mesh.getVertexPosition===scope.wrapper)restore(mesh,'getVertexPosition',descriptor);else counters.lostOwnership++;
   counters.vertexRequests+=scope.requests;counters.skinEvaluations+=scope.evaluations;counters.cacheHits+=scope.hits;
  }
 }
 function release(binding){
  const mesh=binding.mesh;if(mesh._computeIntersections===binding.wrapper)restore(mesh,'_computeIntersections',binding.descriptor);
  else counters.lostOwnership++;
  bindings.delete(mesh);
 }
 function syncNpcRoots(roots=[]){
  // OFF is the original baseline: no hierarchy walk and no installed hooks.
  // Re-enabling admits the next fresh root snapshot supplied by the caller.
  if(disposed||!enabled)return stats();
  const selected=new Set(),visited=new Set(),pending=[...roots];
  while(pending.length){const node=pending.pop();if(!node||visited.has(node))continue;visited.add(node);
   if(node.isSkinnedMesh)selected.add(node);for(const child of node.children||[])pending.push(child);
  }
  for(const [mesh,binding]of bindings)if(!selected.has(mesh)||mesh._computeIntersections!==binding.wrapper)release(binding);
  for(const mesh of selected){
   if(bindings.has(mesh))continue;
   if(!supported(mesh)||!replaceable(mesh,'_computeIntersections')){counters.admissionRejected++;continue;}
   const binding={mesh,descriptor:own(mesh,'_computeIntersections'),wrapper:null};
   binding.wrapper=function(ray,hits,localRay){if(this!==mesh)return canonical.compute.call(this,ray,hits,localRay);return compute(binding,ray,hits,localRay);};
   install(mesh,'_computeIntersections',binding.wrapper);bindings.set(mesh,binding);
  }
  return stats();
 }
 function intersect(ray,roots){
  if(disposed||!enabled)return ray.intersectObjects(roots,true);
  // Suspend outer scopes before even the nested native broadphase: a cold
  // bounding sphere must also see canonical, freshly posed vertex evaluation.
  const suspended=[...scopes.keys()];
  function run(index){if(index<suspended.length)return suspend(suspended[index],()=>run(index+1));
   const previous=query;query={ray};counters.queries++;
   try{return ray.intersectObjects(roots,true);}finally{query=previous;}
  }
  return run(0);
 }
 function stats(){return{enabled,disposed,versionSupported,trackedMeshes:bindings.size,...counters};}
 return{syncNpcRoots,intersect,setEnabled(value){if(!disposed){enabled=!!value&&versionSupported;if(!enabled)for(const binding of [...bindings.values()])release(binding);}return enabled;},stats,dispose(){if(disposed)return;disposed=true;enabled=false;for(const binding of [...bindings.values()])release(binding);}};
}
