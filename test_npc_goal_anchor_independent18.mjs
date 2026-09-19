// Independent review of the staged goal preflight. Never edits production.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {stageNativeGoalAnchors} from './test_npc_native_fast_path18_goal_candidate.mjs';
const baseline=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8');
const candidate=baseline.includes('search.goalStartProbe')?baseline:stageNativeGoalAnchors(baseline);
const fixture=code=>{const b={Math,Map,MAP_COLS:100,_walkNpcNavigationResolver:()=>({swept:true,blocked:false}),_npcRouteWorkExpired:()=>false,_setNpcRoute:(n,p)=>{n._route=p;return p.length>0;}};vm.createContext(b);vm.runInContext(code,b);return b;};
const corridor=(r,c)=>Math.abs(r-10.1)<.12&&c>=2&&c<=12.3;
const narrow=[];
for(const [label,code]of [['baseline',baseline],['candidate',candidate]]){
 const b=fixture(code),n={r:10.1,c:2.1};let checks=0,slices=0,ok=false;
 b._npcRouteWorkExpired=()=>++checks>2;
 do{checks=0;n._routeSearchPending=false;ok=b._npcPlanNativeVisitRoute(n,10.1,12.1,corridor,.8,1200,'building_entry');slices++;}while(n._routeSearchPending&&slices<200);
 assert(ok,`${label}: existing isolated fine-grid corridor cannot be rejected just because all coarse goal centres are blocked`);
 assert.equal(n._route.at(-1).r,10.1);assert.equal(n._route.at(-1).c,12.1);
 assert(n._route.every(p=>corridor(p.r,p.c)));assert.equal(n._routeSearchRestarts||0,0);
 narrow.push({label,slices,expanded:n._routeSearchExpanded,visited:n._routeSearchVisited});
}
const invalidations=[];
for(const changed of ['origin','goal','pass','resolver']){
 const b=fixture(candidate),n={r:2.1,c:2.1};let checks=0,goalR=12.1;
 let pass=(r,c)=>r>0&&c>0&&r<30&&c<30;
 b._npcRouteWorkExpired=()=>++checks>2;
 assert.equal(b._npcPlanNativeVisitRoute(n,goalR,12.1,pass,.8,1200,'building_entry'),false);
 assert(n._routeSearchPending);const search=n._npcDirectedSearch;
 if(changed==='origin')n.r+=.02;
 if(changed==='goal')goalR+=.02;
 if(changed==='pass')pass=(r,c)=>r>0&&c>0&&r<30&&c<30;
 if(changed==='resolver')b._walkNpcNavigationResolver=()=>({swept:true,blocked:false});
 checks=0;n._routeSearchPending=false;b._npcPlanNativeVisitRoute(n,goalR,12.1,pass,.8,1200,'building_entry');
 assert.notEqual(n._npcDirectedSearch,search,changed+' invalidates pending goal discovery');assert.equal(n._routeSearchRestarts,1);
 b._npcRouteWorkExpired=()=>false;n._routeSearchPending=false;
 assert(b._npcPlanNativeVisitRoute(n,goalR,12.1,pass,.8,1200,'building_entry'));assert.equal(n._route.at(-1).r,goalR);
 invalidations.push(changed);
}
console.log(JSON.stringify({pass:true,narrow,invalidations,limit:'CPU staged module only; no production edits, no GPU.'},null,2));
