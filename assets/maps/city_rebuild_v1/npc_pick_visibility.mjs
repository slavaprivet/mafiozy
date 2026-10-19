// Opt-in CPU candidate, not a change to NPC visibility or simulation.
// Output equivalence is for consumers applying the existing ancestor-visible
// postfilter. Native unfiltered hit arrays intentionally contain hidden hits.
// Unknown callbacks anywhere in the query fall back: a later callback could
// otherwise unhide an NPC whose intersections were already skipped.
export function createNpcPickVisibility({THREE:T,getNpcRoots=()=>[],trustedRaycasts=new WeakSet()}={}){
 const objectPrototype=T?.Object3D?.prototype,meshPrototype=T?.Mesh?.prototype;
 const supported=String(T?.REVISION)==='180'&&!!objectPrototype&&!!meshPrototype;
 const containers=new Set([T?.Object3D?.prototype,T?.Group?.prototype,T?.Bone?.prototype,T?.Scene?.prototype]);
 const canonicalRaycaster=T?.Raycaster?.prototype?.intersectObjects;
 let enabled=false;
 const stats={enabled:false,queries:0,optimizedQueries:0,fallbackQueries:0,skippedRoots:0,auditedNodes:0,lastReason:'disabled',reasons:{}};
 function fallback(ray,roots,reason){stats.fallbackQueries++;stats.lastReason=reason;stats.reasons[reason]=(stats.reasons[reason]||0)+1;return ray.intersectObjects(roots,true);}
 function visible(node){for(let n=node;n;n=n.parent)if(n.visible===false)return false;return true;}
 const standard=(object,key,prototype)=>object?.[key]===prototype?.[key];
 function geometrySafe(geometry){
  if(!geometry?.isBufferGeometry)return false;
  for(const key of ['computeBoundingSphere','computeBoundingBox','getAttribute'])if(!standard(geometry,key,T.BufferGeometry.prototype))return false;
  const attributes=[geometry.index,...Object.values(geometry.attributes),...Object.values(geometry.morphAttributes).flat()].filter(Boolean);
  for(const attribute of attributes){const prototype=attribute.isInterleavedBufferAttribute?T.InterleavedBufferAttribute?.prototype:T.BufferAttribute?.prototype;
   if(!prototype||!['getX','getY','getZ','getW'].every(key=>standard(attribute,key,prototype)))return false;
  }
  return true;
 }
 function nodeReason(node){
  const prototype=Object.getPrototypeOf(node);
  // Reject accessors before reading fields used by the pure traversal contract.
  for(const key of ['visible','parent','children','raycast','geometry','material','layers','matrixWorld']){
   const descriptor=Object.getOwnPropertyDescriptor(node,key);if(descriptor&&!('value'in descriptor))return 'node-accessor';
  }
  if(!Array.isArray(node.children)||!standard(node.layers,'test',T.Layers.prototype))return 'node-traversal';
  if(node.isLOD||node.isBatchedMesh)return 'unsupported-node';
  const skinned=prototype===T.SkinnedMesh?.prototype,instanced=prototype===T.InstancedMesh?.prototype,mesh=prototype===meshPrototype;
  if(!mesh&&!skinned&&!instanced&&!containers.has(prototype))return 'unsupported-node';
  const expected=skinned?T.SkinnedMesh.prototype:instanced?T.InstancedMesh.prototype:mesh?meshPrototype:objectPrototype;
  // Trusted methods must be registered by their owner as side-effect-free:
  // no visibility/hierarchy/ray mutation and hits only for their own subtree.
  if(!standard(node,'raycast',expected)&&!trustedRaycasts.has(node.raycast))return 'custom-raycast';
  if(mesh||skinned||instanced){
   if(!standard(node,'getVertexPosition',skinned?T.SkinnedMesh.prototype:meshPrototype))return 'custom-vertex';
   if(!standard(node,'_computeIntersections',meshPrototype))return 'custom-intersections';
   if(!geometrySafe(node.geometry))return 'custom-geometry';
   if(skinned&&(!standard(node,'applyBoneTransform',T.SkinnedMesh.prototype)||!standard(node,'computeBoundingSphere',T.SkinnedMesh.prototype)))return 'custom-skin';
   if(instanced&&(!standard(node,'getMatrixAt',T.InstancedMesh.prototype)||!standard(node,'computeBoundingSphere',T.InstancedMesh.prototype)))return 'custom-instances';
  }
  return null;
 }
 function intersect(ray,roots){
  stats.queries++;
  if(!enabled)return fallback(ray,roots,'disabled');
  if(!supported)return fallback(ray,roots,'three-version');
  if(ray.intersectObjects!==canonicalRaycaster)return fallback(ray,roots,'custom-raycaster');
  const npcRoots=new Set(getNpcRoots()||[]);
  if(!npcRoots.size)return fallback(ray,roots,'no-npcs');
  // Fresh whole-query audit, not a cached scene-wide trust decision. Auditing
  // duplicates once does not deduplicate their subsequent intersections.
  const seen=new Set(),pending=roots.slice();let hasHidden=false;
  while(pending.length){const node=pending.pop();if(seen.has(node))continue;seen.add(node);stats.auditedNodes++;
   const reason=nodeReason(node);if(reason)return fallback(ray,roots,reason);
   if(npcRoots.has(node)&&!visible(node))hasHidden=true;
   for(const child of node.children)pending.push(child);
  }
  if(!hasHidden)return fallback(ray,roots,'no-hidden-npcs');
  const hits=[];
  // Three r180 core Raycaster.intersect, preserving root/child order, layers,
  // propagate=false, duplicate roots and the final stable distance sort.
  function visit(object){
   if(npcRoots.has(object)&&!visible(object)){stats.skippedRoots++;return;}
   let propagate=true;
   if(object.layers.test(ray.layers)){if(object.raycast(ray,hits)===false)propagate=false;}
   if(propagate){const children=object.children;for(let i=0,l=children.length;i<l;i++)visit(children[i]);}
  }
  for(let i=0,l=roots.length;i<l;i++)visit(roots[i]);
  hits.sort((a,b)=>a.distance-b.distance);stats.optimizedQueries++;stats.lastReason='optimized';return hits;
 }
 return {intersect,setEnabled(value){enabled=!!value;stats.enabled=enabled;return enabled;},stats};
}
