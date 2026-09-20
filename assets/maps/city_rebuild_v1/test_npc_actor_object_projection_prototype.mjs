// Actual-source getter comparison; no actor mutation or GPU dependency.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('./npc_population.mjs',import.meta.url),'utf8');
const expression=source.match(/getActors:\(\)=>((?:(?!,getActor:)[\s\S])*),getActor:/)?.[1];
assert(expression,'actual getActors getter anchor must exist');
const actual=new Function('latest','actors',`return (${expression}).map(row=>row.object);`);
const candidateBody=source.match(/ function getActorObjects\(\)\{([^\n]+)\}/)?.[1];
assert(candidateBody,'actual new getter must exist');
assert(source.includes('return {sync,update,getActorObjects,'),'new getter must be exposed');
const candidate=new Function('latest','actors',candidateBody);
let cases=0;
function check(latest,actors){const before=[...actors];const a=actual(latest,actors),b=candidate(latest,actors);assert.deepEqual(b,a);for(let i=0;i<a.length;i++)assert.equal(a[i],b[i]);assert.deepEqual([...actors],before);cases++;return b;}
const latest=Array.from({length:72},(_,i)=>({id:`npc:${i}`,name:`Person${i}`,role:'civilian',r:i,c:0}));
const actors=new Map(latest.map((r,i)=>[r.id,{actor:{object:{id:r.id,visible:i%2===0}}}]));
const retained=check(latest,actors);check([],actors);check(latest.slice().reverse(),actors);check([latest[0],latest[0],latest[2]],actors);
actors.delete(latest[1].id);check(latest,actors);actors.set('cached-not-in-snapshot',{actor:{object:{id:'cached'}}});check(latest,actors);
const replacement={id:'replacement'};actors.set(latest[0].id,{actor:{object:replacement}});check(latest,actors);assert.notEqual(retained[0],replacement,'previous returned arrays retain their old object references');
const output=check(latest,actors);output.length=0;assert(candidate(latest,actors).length>0,'caller owns its output array');
// Allocation units are structural counts of the extracted getter, not bytes or
// measured GC. It constructs one row per admitted NPC, then caller projects it.
const admitted=actual(latest,actors).length;
const values={actual:[],candidate:[]};let checksum=0;
for(let warm=0;warm<2000;warm++){checksum+=actual(latest,actors).length;checksum+=candidate(latest,actors).length;}
for(let batch=0;batch<40;batch++)for(const name of batch%2?['candidate','actual']:['actual','candidate']){
 const fn=name==='actual'?actual:candidate,start=performance.now();for(let i=0;i<500;i++)checksum+=fn(latest,actors).length;values[name].push((performance.now()-start)/500);
}
const timings=Object.fromEntries(Object.entries(values).map(([key,v])=>{v.sort((a,b)=>a-b);return[key,{p50Ms:v[19],p95Ms:v[37]}];}));
console.log(JSON.stringify({cases,admitted,allocationsPerCall:{actual:{rowObjects:admitted,arrays:3},candidate:{rowObjects:0,arrays:1}},timings,checksum,scope:'actual extracted getter, 72-row fixture; CPU only, no LIVE or GC/FPS claim'}));
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8'),hook=walk.split('\n').find(line=>line.includes('if(!mercenaryWalk&&hero'));
assert.equal(hook.split('npcPopulation?.getActorObjects()').length-1,2,'only two target projection consumers');
assert(hook.includes('getNpcs:()=>npcPopulation?.getActors()||[]'),'full NPC data consumer unchanged');
