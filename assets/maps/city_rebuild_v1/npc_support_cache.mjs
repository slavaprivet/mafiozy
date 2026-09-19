// Opt-in cache for the current walk host's static support at referenceY=0.
// It never stores water, terrain admission, solids, cars or train collisions.
export function createNpcSupportCache({sample,getEnvironment,maxPoints=30000}={}){
 if(typeof sample!=='function'||typeof getEnvironment!=='function')throw new TypeError('NPC support cache requires sample and environment');
 if(!Number.isInteger(maxPoints)||maxPoints<1)throw new RangeError('Invalid NPC support cache size');
 const rows=new Map(),xs=new Float64Array(maxPoints),zs=new Float64Array(maxPoints),entries=[],floors=[],entryRevisions=[];
 const keys=['scene','buildingIndex','railway','railPlan','landscape','topology','revision'],providers=[];
 const stats={hits:0,misses:0,invalidations:0,evictions:0};let size=0,head=0,initialized=false;
 function invalidate(){rows.clear();size=0;head=0;stats.invalidations++;}
 function beginFrame(){
  const environment=getEnvironment(),current=environment.entries||[];let changed=!initialized||entries.length!==current.length;
  for(let i=0;i<keys.length;i++)if(providers[i]!==environment[keys[i]])changed=true;
  // Entry floor replacement/reordering is uncommon, but must not retain old
  // support. In-place future floor edits publish npcSupportRevision explicitly.
  for(let i=0;i<current.length;i++)if(entries[i]!==current[i]||floors[i]!==current[i].floorHeight||entryRevisions[i]!==current[i].npcSupportRevision)changed=true;
  if(changed){invalidate();for(let i=0;i<keys.length;i++)providers[i]=environment[keys[i]];
   entries.length=floors.length=entryRevisions.length=current.length;
   for(let i=0;i<current.length;i++){entries[i]=current[i];floors[i]=current[i].floorHeight;entryRevisions[i]=current[i].npcSupportRevision;}
  }
  initialized=true;
 }
 function query(x,z){
  if(!initialized)beginFrame();
  if(!Number.isFinite(x)||!Number.isFinite(z))return sample(x,z);
  const cached=rows.get(x)?.get(z);if(cached!==undefined){stats.hits++;return cached;}
  stats.misses++;const value=sample(x,z);if(!Number.isFinite(value))return value;
  if(size===maxPoints){const old=rows.get(xs[head]);old.delete(zs[head]);if(!old.size)rows.delete(xs[head]);head=(head+1)%maxPoints;size--;stats.evictions++;}
  const slot=(head+size)%maxPoints;xs[slot]=x;zs[slot]=z;size++;
  let row=rows.get(x);if(!row)rows.set(x,row=new Map());row.set(z,value);return value;
 }
 return {sample:query,beginFrame,invalidate,diagnostics:()=>({...stats,size,maxPoints})};
}
