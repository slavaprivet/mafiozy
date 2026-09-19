// Read-only actual native geometry vs existing source policy audit.
import fs from 'node:fs';import vm from 'node:vm';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box,s=f.source;
const declaration=(start,end)=>s.slice(s.indexOf(start),s.indexOf(end,s.indexOf(start)));
vm.runInContext('const JAIL_CENTER_R=76,JAIL_CENTER_C=76,JAIL_ISLAND_3D_ENABLED=true;'+declaration('const JAIL_ISLAND_LAYOUT =','const JAIL_POLICE_STATION_3D ='),b);
vm.runInContext('const POI=['+declaration('const POI = [','\n];').split('\n').filter(line=>/id:\s*'(arena|lair)'/.test(line)).join('\n')+'];',b);
vm.runInContext(declaration('const ARENA_POI =','// ── Захват районов'),b);
for(const name of ['_distToRaceSeg','_inPitCorridor','_inPrisonIslandRestrictedZone','_npcLifeEligible','_isRespawnableResident'])vm.runInContext(sourceFunction(s,name),b);
const total={physical:0,land:0,ordinaryBody:0,visitBody:0,excludedLand:0,ordinaryTiles:{},spawnTileRejected:0,reasons:{arena:0,lair:0,prison:0,pit:0,sand:0,other:0}},examples={};
const deny=(r,c)=>b._inPrisonIslandRestrictedZone(r,c,.35)?'prison':b.inArena(Math.floor(r),Math.floor(c))?'arena':b.inLair(Math.floor(r),Math.floor(c))?'lair':b.MAP[Math.floor(r)][Math.floor(c)]===14?(b._inPitCorridor(Math.floor(r)+.5,Math.floor(c)+.5)?'pit':'sand'):'other';
for(let r=1.5;r<b.MAP_ROWS-1;r++){
 f.nextFrame();
 for(let c=1.5;c<b.MAP_COLS-1;c++){
  const corners=[[r,c],[r-.18,c-.18],[r-.18,c+.18],[r+.18,c-.18],[r+.18,c+.18]];
  if(!corners.every(([rr,cc])=>{const q=f.pedestrian.query({r:rr,c:cc});return !q.blocked&&q.depth<=.025;})||f.pedestrian.query({mode:'sweep',from:{r,c},to:{r,c},radius:.18}).blocked)continue;
  total.physical++;const visit=b._npcBodyPassable(r,c,b.npcPassableForSnitch),ordinary=b._npcBodyPassable(r,c,(rr,cc)=>b.npcWaypointOk({},rr,cc));if(visit)total.visitBody++;if(ordinary){total.ordinaryBody++;const tile=b.MAP[Math.floor(r)][Math.floor(c)];total.ordinaryTiles[tile]=(total.ordinaryTiles[tile]||0)+1;if(![9,8,14].includes(tile)){total.spawnTileRejected++;(examples.spawn??=[]).length<4&&examples.spawn.push({r,c,tile});}}
  if(f.pedestrian.query({r,c}).surface!=='land')continue;total.land++;
  if(!ordinary){total.excludedLand++;const reason=corners.map(([rr,cc])=>deny(rr,cc)).find(x=>x!=='other')||'other';total.reasons[reason]++;(examples[reason]??=[]).length<4&&examples[reason].push({r,c,tile:b.MAP[Math.floor(r)][Math.floor(c)],visit});}
 }
}
const zoneBuildings=f.snapshot.buildings.map(x=>({id:x.id,asset:x.assetId,role:x.role,r:x.transform.positionM[2]/f.M,c:x.transform.positionM[0]/f.M})).filter(x=>['arena','lair','prison'].includes(deny(x.r,x.c))).map(x=>({...x,zone:deny(x.r,x.c)}));
const roles=['resident_worker','resident_bandit','world_person'];const identity=[];
for(const id of roles){const n={id,r:12,c:98,alive:true,hp:60,_arcKey:id.includes('bandit')?'bandit':'worker'};identity.push({id,visitEligible:b._residentCanVisitBuilding(n),planEligible:b._civilianPlanEligible(n)});}
const resumes=[];b.Math=Object.create(Math);b.Math.random=()=>0;
for(const id of ['resident_worker','resident_bandit','world_person']){
 const n={id,r:4.990913843951179,c:97.94314630350254,alive:true,hp:60,_arcKey:id.includes('bandit')?'bandit':'worker',_npcRoutine:'errands'};
 for(let i=0;i<12;i++){f.nextFrame();let checks=0;b._npcRouteWorkExpired=()=>++checks>2;b._maybePlanResidentBuildingVisit(n);}
 resumes.push({id,pending:!!n._routeSearchPending,restarts:n._routeSearchRestarts||0,frontierExpanded:n._npcDirectedSearch?.qi,frontierNodes:n._npcDirectedSearch?.nodes.size,phase:n._civilianPlan?.phase,doorId:n._civilianPlan?.doorId,status:n._residentVisitStatus});b._cancelNpcDirectedSearch(n);
}
const output={total,examples,zoneBuildings,identity,resumes,limits:'Actual current static snapshot plus one live print-shop GLB, source policy functions; not loaded scene or population census.'};
console.log(JSON.stringify(output,null,2));fs.writeFileSync('outputs/npc_policy_gate_audit18.json',JSON.stringify(output,null,2));
