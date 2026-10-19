process.env.INCOMING_MELEE_BENCH='1';
const {run,costs}=await import('./test_npc_incoming_melee_host19.mjs');
const result=[];
for(const type of ['punch','kick','heavy','dropkick'])run({type,budget:true});
for(const fps of [5,60])for(const attackerCount of [1,4]){
 costs.length=0;let hits=0,deferrals=0;
 for(let repeat=0;repeat<3;repeat++)for(const sex of ['male','female'])for(const type of ['punch','kick','heavy','dropkick']){const r=run({sex,type,fps,attackerCount,budget:true});hits+=r.hits;deferrals+=r.budgetDeferred;}
 costs.sort((a,b)=>a-b);result.push({fps,attackerCount,hits,expectedHits:24*attackerCount,deferrals,p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)],max:costs.at(-1)});
}
console.log(JSON.stringify({scope:'CPU incoming host only; warm JIT, fresh hero/attackers, exact target skin shared; soft4ms budget between indivisible contacts; no LIVE FPS claim',result},null,2));
