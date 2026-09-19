// Immutable-plan indexes. Build once after road dressing has assigned its final
// phases and signs; no per-vehicle scans of the complete city turn collection.
const cache=new WeakMap();
function pointSegment(p,a,b){const x=b.x-a.x,z=b.z-a.z,l=x*x+z*z,t=l?Math.max(0,Math.min(1,((p.x-a.x)*x+(p.z-a.z)*z)/l)):0;return (p.x-a.x-x*t)**2+(p.z-a.z-z*t)**2}
function segmentDistance(a,b,c,d){const x=b.x-a.x,z=b.z-a.z,u=d.x-c.x,v=d.z-c.z,den=x*v-z*u;if(Math.abs(den)>1e-9){const dx=c.x-a.x,dz=c.z-a.z,t=(dx*v-dz*u)/den,s=(dx*z-dz*x)/den;if(t>=0&&t<=1&&s>=0&&s<=1)return 0}return Math.min(pointSegment(a,c,d),pointSegment(b,c,d),pointSegment(c,a,b),pointSegment(d,a,b))}
function bounds(points,pad=0){return {x0:Math.min(...points.map(p=>p.x))-pad,z0:Math.min(...points.map(p=>p.z))-pad,x1:Math.max(...points.map(p=>p.x))+pad,z1:Math.max(...points.map(p=>p.z))+pad}}
function overlaps(a,b){return a.x0<=b.x1&&a.x1>=b.x0&&a.z0<=b.z1&&a.z1>=b.z0}
function pathsNear(a,b,radius){const r2=radius*radius;for(let i=1;i<a.length;i++)for(let j=1;j<b.length;j++)if(segmentDistance(a[i-1],a[i],b[j-1],b[j])<r2)return true;return false}
export function createTrafficControlIndex(plan,prepared=null){
 if(cache.has(plan))return cache.get(plan);
 const approachById=new Map(),turnById=new Map(),turnsByApproach=new Map(),conflicts=new Map(),crosswalks=new Map(),boxes=new Map(),buckets=new Map();
 for(const junction of plan.junctionRules||plan.junctions||[])for(const a of junction.approaches)approachById.set(a.id,{...a,junctionId:junction.id});
 for(const turn of plan.turns||[]){turnById.set(turn.id,turn);if(!turnsByApproach.has(turn.fromApproachId))turnsByApproach.set(turn.fromApproachId,[]);turnsByApproach.get(turn.fromApproachId).push(turn);conflicts.set(turn.id,new Set());crosswalks.set(turn.id,new Set());if(prepared)continue;const box=bounds(turn.points,2.2);boxes.set(turn.id,box);for(let x=Math.floor(box.x0/24);x<=Math.floor(box.x1/24);x++)for(let z=Math.floor(box.z0/24);z<=Math.floor(box.z1/24);z++){const key=x+','+z;if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(turn)}}
 const tested=new Set();let conflictPairs=0;
 if(prepared){for(const [id,ids]of prepared.conflicts||[])if(conflicts.has(id))conflicts.set(id,new Set(ids));for(const [id,ids]of prepared.crosswalks||[])if(crosswalks.has(id))crosswalks.set(id,new Set(ids));conflictPairs=prepared.stats.conflictPairs;}
 else{
  for(const group of buckets.values())for(let i=0;i<group.length;i++)for(let j=i+1;j<group.length;j++){const a=group[i],b=group[j];if(a.fromApproachId===b.fromApproachId)continue;const key=a.id<b.id?a.id+'|'+b.id:b.id+'|'+a.id;if(tested.has(key))continue;tested.add(key);if(overlaps(boxes.get(a.id),boxes.get(b.id))&&pathsNear(a.points,b.points,2.2)){conflicts.get(a.id).add(b.id);conflicts.get(b.id).add(a.id);conflictPairs++}}
  for(const c of [...(plan.crosswalks||[]),...(plan.serviceCrossings||[])]){const segment=c.roadStart&&c.roadEnd?[c.roadStart,c.roadEnd]:c.endpoints;if(!segment?.length)continue;const box=bounds(segment,2.8);for(const turn of turnById.values()){if(c.approachId===turn.fromApproachId||c.approachId===turn.toApproachId||overlaps(box,boxes.get(turn.id))&&pathsNear(turn.points,segment,2.8))crosswalks.get(turn.id).add(c.id)}}
 }
 const result={approachById,turnById,turnsByApproach,conflicts,crosswalks,stats:{turns:turnById.size,conflictPairs,pairCandidates:tested.size},crosswalkIdsForTurn:id=>[...(crosswalks.get(id)||[])],conflictIdsForTurn:id=>[...(conflicts.get(id)||[])]};cache.set(plan,result);return result;
}
