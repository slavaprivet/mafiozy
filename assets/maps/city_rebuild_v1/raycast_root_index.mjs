// Conservative ray broadphase for long-lived world roots. It deliberately
// returns roots, not synthetic hits: Three still performs the authoritative
// recursive triangle/instance raycast, preserving exact hit identities.
export function createRaycastRootIndex({THREE,roots=[],padding=3}={}){
 if(!THREE?.Box3||!THREE?.Ray)throw Error('Raycast root index requires THREE');
 const all=[...new Set((Array.isArray(roots)?roots:[roots]).filter(root=>root?.traverse))];
 const entries=[],box=new THREE.Box3();
 const extra=Math.max(0,Number.isFinite(padding)?padding:0);
 for(const root of all){
  root.updateWorldMatrix?.(true,true);box.setFromObject(root);
  // Empty groups may receive geometry after the index is assembled. Keep them
  // in the exact path rather than risking a missed future interaction.
  entries.push({root,bounds:box.isEmpty()?null:box.clone().expandByScalar(extra)});
 }
 const ray=new THREE.Ray(),hit=new THREE.Vector3(),empty=Object.freeze([]);
 function query(origin,direction,distance=Infinity){
  if(!origin?.isVector3||!direction?.isVector3||!Number.isFinite(direction.lengthSq?.())||direction.lengthSq()<1e-12)return all;
  const far=Math.max(0,Number.isFinite(distance)?distance:Infinity),farSq=far*far;
  ray.set(origin,direction);
  const candidates=[];
  for(const entry of entries){
   const bounds=entry.bounds;
   if(!bounds||bounds.containsPoint(origin)){candidates.push(entry.root);continue}
   if(ray.intersectBox(bounds,hit)&&origin.distanceToSquared(hit)<=farSq)candidates.push(entry.root);
  }
  return candidates.length?candidates:empty;
 }
 return {query,stats(){return {roots:entries.length,padding:extra}},dispose(){entries.length=0;all.length=0}};
}
