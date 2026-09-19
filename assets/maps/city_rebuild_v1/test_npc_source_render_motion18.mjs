// Actual source foot branch/native sweep -> sampled bridge -> actual GLB pose.
// CPU-only: measures motion delivery, not GPU frame rate or route scheduling.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createNpcPopulation} from './npc_population.mjs';
import {explorationNpcMapMarkers} from './exploration_minimap.mjs';

const f=await createCivilianNativeFixture(),b=f.box,T=f.THREE;
const {GLTFLoader}=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/addons/loaders/GLTFLoader.js'));
let start;
for(let r=3;r<b.MAP_ROWS-8&&!start;r+=2)for(let c=3;c<b.MAP_COLS-8&&!start;c+=2){
 if(![8,9].includes(b.MAP[r][c]))continue;
 if(b._npcBodyPassable(r+.5,c+.5,b.npcPassable)&&b._npcPathPassable(r+.5,c+.5,r+6.5,c+.5,b.npcPassable))start={r:r+.5,c:c+.5};
}
assert(start,'real native dry route required');
const reports=[];
for(const config of [{sourceHz:10,renderHz:60,focusOffset:0},{sourceHz:10,renderHz:10,focusOffset:0},{sourceHz:10,renderHz:5,focusOffset:0},{sourceHz:4,renderHz:10,focusOffset:45},{sourceHz:4,renderHz:5,focusOffset:45}]){
 const ns=[0,1].map(sex=>({id:'resident_render18_'+sex,...start,tr:start.r+6,tc:start.c,hp:100,max_hp:100,speed:1.2,walkPhase:0,walking:false,idleUntil:0,look:{gender:sex},role:'civilian',weapon:'fists'}));
 let time=1,sourceClock=1000,bridgeCalls=0;
 const bridge={getWorldClock:()=>sourceClock,getDynamicEntities:()=>{bridgeCalls++;return{npcs:ns.map(n=>({...n}))};}};
 const population=await createNpcPopulation({THREE:T,scene:new T.Scene(),loader:new GLTFLoader(),cloneSkeleton:clone,bridge,maxActors:2,getFocus:()=>({x:start.c*f.M+config.focusOffset,z:start.r*f.M}),renderLOD:true});
 population.update(1/config.renderHz,time);
 const previous=ns.map(n=>population.getActor(n.id).object.position.z),phases=ns.map(()=>new Set()),gaitDistances=[0,0],stationary=[0,0],maxStationary=[0,0];
 for(let i=0;i<ns.length;i++){const actor=population.getActor(ns[i].id),update=actor.update;actor.update=(dt,snapshot)=>{gaitDistances[i]+=snapshot.gaitDistance||0;phases[i].add(actor.walker.diagnostics().phase);return update(dt,snapshot);};}
 const dt=1/config.renderHz,sourceStep=1/config.sourceHz;let sourceDebt=0,maxLagM=0,steadyDistance=0,steadyTime=0;
 for(let frame=1;frame<=Math.round(10/dt);frame++){
  time=1+frame*dt;sourceDebt+=dt;
  while(sourceDebt+1e-9>=sourceStep){sourceDebt-=sourceStep;sourceClock+=sourceStep*1000;f.nextFrame(sourceStep);for(const n of ns){if(time<=9+1e-9)b.actualFootTick(n,sourceStep,f.now);else n.walking=false;}}
  population.update(Math.min(.1,dt),time);
  const markers=explorationNpcMapMarkers(population.getActors());assert.equal(markers.length,2);
  for(let i=0;i<ns.length;i++){
   const actor=population.getActor(ns[i].id),z=actor.object.position.z,sourceZ=ns[i].r*f.M;
   assert(z>=previous[i]-1e-8&&z<=sourceZ+1e-8,'renderer must not reverse or extrapolate through native collision');
   maxLagM=Math.max(maxLagM,sourceZ-z);
   assert.equal(markers[i].position,actor.object.position,'minimap uses the exact presented transform');
   if(time>3&&time<8){stationary[i]=z-previous[i]<1e-7?stationary[i]+dt:0;maxStationary[i]=Math.max(maxStationary[i],stationary[i]);if(i===0){steadyDistance+=z-previous[i];steadyTime+=dt;}}
   previous[i]=z;
  }
 }
 const result={...config,bridgeCalls,actors:ns.map((n,i)=>{const rendered=population.getActor(n.id).object.position.z-start.r*f.M,source=(n.r-start.r)*f.M;assert(source>13,'actual source made progress '+JSON.stringify({config,start,source,n}));assert(Math.abs(rendered-source)<1e-6,'renderer finishes source distance after final packet');assert(Math.abs(gaitDistances[i]-rendered)<1e-5,'gait consumes rendered metres');assert(phases[i].size>10,'real GLB gait phase advances');assert(maxStationary[i]<=sourceStep+dt+1e-7,'no extra presentation freeze');return{sex:i?'female':'male',sourceM:source,renderedM:rendered,gaitM:gaitDistances[i],uniquePhases:phases[i].size,maxStationarySeconds:maxStationary[i]};})};
 result.maxLagM=maxLagM;result.steadyRenderedMps=steadyDistance/steadyTime;
 assert(result.steadyRenderedMps>1.5,'steady presentation must not silently reduce walking speed');
 reports.push(result);population.dispose();
}
console.log(JSON.stringify({pass:true,reports,limit:'CPU actual source foot branch and native geometry, real male/female GLBs, actual snapshot sampling/interpolation/LOD/minimap. Excludes scheduling pending routes, GPU and LIVE prevalence.'},null,2));
