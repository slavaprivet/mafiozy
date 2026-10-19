// Same GLBs, target, source bridge and four attacks on both paths. Legacy means
// the old endpoint-only host admission; current contact helper is shared.
process.env.MELEE_BENCH='1';
const {scenario,costs}=await import('./test_melee_lowfps_contact19.mjs');
const results=[];
for(const fps of [5,8,15,60])for(const legacy of [true,false]){
 for(const type of ['punch','kick','heavy','dropkick'])scenario({type,fps,legacy});
 costs.legacy.length=costs.sampled.length=0;let hits=0,total=0;
 for(let repetition=0;repetition<3;repetition++)for(const sex of ['male','female'])for(const type of ['punch','kick','heavy','dropkick']){hits+=Number(scenario({sex,type,fps,legacy}).hit);total++;}
 const values=costs[legacy?'legacy':'sampled'].sort((a,b)=>a-b);
 results.push({fps,legacy,hits,total,p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)],max:values.at(-1)});
}
console.log(JSON.stringify({scope:'CPU host.update only; fresh hero per attack includes first-use bounds; one stationary NPC; no scene/GPU FPS claim',results},null,2));
