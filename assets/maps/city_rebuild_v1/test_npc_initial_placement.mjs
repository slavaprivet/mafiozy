import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const code=fs.readFileSync(new URL('./npc_initial_placement_source.js',import.meta.url),'utf8');
const resident={id:'resident-original',r:10,c:10,look:{hat:3},_route:[{r:20,c:20}]},cop={id:'police-original',y:10,x:10,_policeFootRoute:[1]},worldCop={id:'world-police',r:10,c:10},rider={id:'rider-original',r:10,c:10,_civilianTripRiding:true},indoors={id:'interior-original',r:10,c:10,_residentIndoors:true},owner={id:'boss-original',r:10,c:10,_empireBoss:true};const NPCS=[resident,rider,indoors,owner],cityCops=[cop],worldCops=[worldCop];let clears=0;
const free=(r,c)=>!(r>8&&r<12&&c>8&&c<12),body=(r,c)=>[[-.24,-.24],[-.24,.24],[.24,-.24],[.24,.24],[0,0]].every(([dr,dc])=>free(r+dr,c+dc));
const box={performance:{now:()=>0},NPCS,cityCops,worldCops,_walkNpcNavigationResolver:()=>({blocked:true,depth:0}),_npcBodyPassable:body,npcWaypointOk:()=>true,_policeCrewBodyPassable:body,_clearNpcRoute:n=>{n._route=null;clears++;},_clearPoliceFootRoute:n=>{n._policeFootRoute=null;clears++;},_buildingInt:null,_bankInt:null};vm.createContext(box);vm.runInContext(code+'\nglobalThis.api={run:_npcInitialSafePlacement,stats:_npcInitialPlacementStats,step:_npcInitialPlacementStep};',box);box.api.run();for(let i=0;i<1000&&box.api.stats.pending;i++)box.api.step();
assert(body(resident.r,resident.c));assert(body(cop.y,cop.x));assert(body(worldCop.r,worldCop.c));assert.equal(NPCS[0],resident);assert.equal(cityCops[0],cop);assert.equal(resident.id,'resident-original');assert.deepEqual(resident.look,{hat:3});assert.equal(resident._route,null);assert.equal(cop._policeFootRoute,null);assert.equal(NPCS.length,4);assert.equal(cityCops.length,1);assert.equal(worldCops.length,1);for(const n of [rider,indoors,owner])assert.deepEqual([n.r,n.c],[10,10]);
resident.r=10;resident.c=10;cop.x=10;cop.y=10;box._walkNpcNavigationResolver=null;box.api.run();box._walkNpcNavigationResolver=()=>({blocked:true,depth:0});box.api.run();assert.deepEqual([resident.r,resident.c,cop.y,cop.x],[10,10,10,10],'later reconnect never relocates active actors');assert.equal(box.api.stats.moved,3);assert(box.api.stats.pending===0);
const local={...box,_buildingInt:{npcs:[resident]}};vm.createContext(local);vm.runInContext(code+'\n_npcInitialSafePlacement();',local);assert.deepEqual([resident.r,resident.c],[10,10],'local interior has no world-space relocation');
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),start=world.indexOf('// NPC_NATIVE_INITIAL_PLACEMENT_START'),end=world.indexOf('// NPC_NATIVE_INITIAL_PLACEMENT_END',start)+'// NPC_NATIVE_INITIAL_PLACEMENT_END'.length;assert.equal(world.slice(start,end).replaceAll('\r','').trim(),code.replaceAll('\r','').trim());assert(world.includes('_walkNpcNavigationResolver=resolver;if(resolver)_npcInitialSafePlacement();return true;'));
console.log('PASS initial-only placement: existing residents r/c, police y/x and r/c; dry full body; identity/appearance conserved; riders/indoors/boss excluded; no repeat on reconnect; bounded search; exact live source');

// More than the old global 3200-candidate cap: every unresolved person resumes.
const many=Array.from({length:24},(_,i)=>({id:'pending_'+i,r:10,c:10,look:{body:i%3}}));
const crowded={...box,NPCS:many,cityCops:[],worldCops:[],MAP_ROWS:50,MAP_COLS:50,_buildingInt:null,
 _npcBodyPassable:(r,c)=>r>18&&r<45&&c>1&&c<45};
vm.createContext(crowded);vm.runInContext(code+'\nglobalThis.api={run:_npcInitialSafePlacement,step:_npcInitialPlacementStep,stats:_npcInitialPlacementStats};',crowded);
crowded.api.run();assert(crowded.api.stats.pending>0);assert(many.some(n=>n._npcInitialPlacementPending));
let slices=0;for(;slices<10000&&crowded.api.stats.pending;slices++){const before=crowded.api.stats.searchChecks;crowded.api.step();assert(crowded.api.stats.searchChecks-before<=96);}
assert.equal(crowded.api.stats.pending,0);assert.equal(crowded.api.stats.moved,24);assert(crowded.api.stats.searchChecks>3200);
for(const n of many){assert(n.r>18);assert.equal(n._npcInitialPlacementPending,undefined);}
for(let i=0;i<many.length;i++)for(let j=i+1;j<many.length;j++)assert(Math.hypot(many[i].r-many[j].r,many[i].c-many[j].c)>=.55);
assert(world.includes('if(n._npcInitialPlacementPending)continue;'));
assert(world.includes('x._npcInitialPlacementPending||x._actionRef?._npcInitialPlacementPending'));
console.log('PASS resumed initial placement: '+slices+' bounded slices, '+crowded.api.stats.searchChecks+' candidates, 24/24 safe before presentation, no reused IDs or active relocation');

const life=world.match(/^function _npcLifeEligible\([^]*?^}/m)[0];
const lifeBox={};vm.createContext(lifeBox);vm.runInContext(life+'\nglobalThis.eligible=_npcLifeEligible;',lifeBox);
assert.equal(lifeBox.eligible({id:'resident_53',_npcInitialPlacementPending:true}),false);
assert.equal(lifeBox.eligible({id:'resident_53'}),true);
assert(world.match(/^function _civilianPlanEligible.*$/m)[0].includes('_npcLifeEligible(n)'));
console.log('PASS pending source residents excluded from life/bench/trip planning until initial placement');
