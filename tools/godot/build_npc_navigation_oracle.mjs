// Executes unmodified source modules and extracted current source scheduler/setter.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {createNpcNativeNavigation} from '../../assets/maps/city_rebuild_v1/npc_native_navigation.mjs';
import {createWalkCollisionIndex} from '../../assets/maps/city_rebuild_v1/walk_collision_index.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const paths=['assets/maps/city_rebuild_v1/npc_native_navigation.mjs','assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','assets/maps/city_rebuild_v1/npc_swept_footprint.mjs','world.html','godot/mafiozi_walk/data/printshop_interior.json','assets/maps/city_rebuild_v1/walk_collision_index.mjs'];
const read=p=>fs.readFileSync(path.join(root,p),'utf8'),sha=p=>createHash('sha256').update(read(p)).digest('hex');
const world=read('world.html'),planner=read(paths[1]);
const scheduler=world.slice(world.indexOf('let _npcRouteWorkFrame=null'),world.indexOf('function _planNpcRouteTo('));
const setter=world.slice(world.indexOf('function _setNpcRoute('),world.indexOf('\n}',world.indexOf('function _setNpcRoute('))+2);
if(!scheduler.endsWith('\n')||!setter.endsWith('}'))throw Error('source extraction changed');
const rect=(c0,r0,c1,r1,minYM=0,maxYM=3)=>({polygonCR:[[c0,r0],[c1,r0],[c1,r1],[c0,r1]],minYM,maxYM});
const cases=[];
function add(name,options={}){cases.push({name,start:{r:2.5,c:2.5},goal:{r:2.5,c:13.5},bounds:[0,0,18,18],bodies:[],floor:0,scale:1,cost:20,radius:.8,limit:18000,maxFrames:200,...options});}
add('open_long');add('short_direct',{goal:{r:5.5,c:6.5}});
add('short_without_sweep',{goal:{r:5.5,c:6.5},noSweep:true});
add('wall_detour',{bodies:[rect(7,0,7.02,6)]});
add('sealed_wall',{bodies:[rect(7,-1,7.1,19)],limit:450});
add('limited_frontier',{bodies:[rect(7,0,7.02,6)],limit:10});
add('fine_corridor',{start:{r:2.02,c:2.02},goal:{r:2.02,c:12.02},corridor:[1.80,2.24],radius:.3,limit:900});
add('fine_deadend',{start:{r:2.02,c:2.02},goal:{r:3.02,c:12.02},corridor:[1.80,2.24],radius:.3,limit:180});
add('water_detour',{water:[7,0,8,6],waterLevel:1});
add('dry_bridge',{water:[7,0,8,18],waterLevel:1,floor:1.2});
add('headroom_clear',{bodies:[rect(7,0,8,18,2,3)]});
add('headroom_blocked',{bodies:[rect(7,0,8,18,2,3)],floor:.2,limit:300});
add('support_top',{bodies:[rect(7,0,8,18,0,3)],floor:3});
add('moving_door_resume',{bodies:[rect(7,0,7.02,6)],changeFrame:2,afterBodies:[rect(7,-1,7.02,19)],cost:90,limit:400});
add('goal_restart',{bodies:[rect(7,0,7.02,6)],changeGoalFrame:2,afterGoal:{r:12.5,c:13.5},cost:90});
add('provider_restart',{bodies:[rect(7,0,7.02,6)],restartFrame:2,cost:90});
add('cancel_pending',{bodies:[rect(7,0,7.02,6)],cancelFrame:2,cost:90});
add('same_frame_deferral',{goal:{r:5.5,c:6.5},cost:1000,repeatFrame:true});
add('dynamic_vehicle',{dynamic:[7,0,8,6]});
add('terrain_refusal',{terrain:[7,0,8,6]});
add('direct_water_changes_source_edge',{goal:{r:2.5,c:9.5},cost:200,changeWaterFrame:2,afterWater:[2.5,2,4,3],waterLevel:1});
add('zero_distance',{goal:{r:2.5,c:2.5}});
add('limit_overshoot',{limit:2,noSweep:true,goal:{r:2.5,c:15.5}});
add('cohort12',{actors:12,bodies:[rect(7,0,7.02,6)],cost:75,maxFrames:600});
// Real source-authored footprint poses; no invented residents or source snapshot.
const layout=JSON.parse(read(paths[4]));
const actual=[...layout.staticBodies,...Object.values(layout.doors).flatMap(d=>d.bodies)].map(b=>({polygonCR:b.polygonCR,minYM:b.minYM,maxYM:b.maxYM}));
const origin=layout.originM||[395.65,0,45.1];
const local=xyz=>({r:(xyz[2]+origin[2])/4.1,c:(xyz[0]+origin[0])/4.1});
const approach=local([7.405199844360425,0,5.649446760199837]);
add('actual_printshop_closed_entry',{start:{r:approach.r+2,c:approach.c},goal:local([.5843,.39,3.750446662925057]),bounds:[93,8,101,16],bodies:actual,scale:4.1,floor:.39,cost:10,limit:700,origin:'current authored printshop, closed door leaves; uniform support fixture'});
add('actual_printshop_outside_approach',{start:{r:approach.r+2,c:approach.c+1},goal:approach,bounds:[93,8,101,16],bodies:actual,scale:4.1,cost:10,limit:700,origin:'current authored printshop exterior footprint'});
for(const spec of cases.filter(s=>s.name.startsWith('actual_printshop'))){spec.broadphase='index';spec.cellSize=.5;cases.push({...spec,name:spec.name+'_linear',broadphase:'linear'});}
const inside=(area,c,r)=>area&&c>=area[0]&&r>=area[1]&&c<=area[2]&&r<=area[3];
function contains(body,r,c){let hit=false;const p=body.polygonCR;for(let i=0,j=p.length-1;i<p.length;j=i++){const a=p[i],b=p[j];if((a[1]>r)!==(b[1]>r)&&c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0])hit=!hit;}return hit;}
const measured=[];
for(const spec of cases){
 let us=0,frame=0,passCalls=0,sweepCalls=0,bodies=spec.bodies,waterArea=spec.water;
 const boxes=new Map([...bodies,...(spec.afterBodies||[])].map(b=>[b,[Math.min(...b.polygonCR.map(p=>p[0])),Math.min(...b.polygonCR.map(p=>p[1])),Math.max(...b.polygonCR.map(p=>p[0])),Math.max(...b.polygonCR.map(p=>p[1]))]]));
 const broad=(c0,r0,c1,r1)=>bodies.filter(b=>{const a=boxes.get(b);return a[2]>=c0&&a[0]<=c1&&a[3]>=r0&&a[1]<=r1});
 const index=spec.broadphase==='index'?createWalkCollisionIndex([bodies],spec.cellSize):null;
 const nav=createNpcNativeNavigation({worldScale:spec.scale,groundHeight:()=>spec.floor,waterAt:(x,z)=>inside(waterArea,x/spec.scale,z/spec.scale)?{level:spec.waterLevel}:null,bodiesAt:index||(spec.broadphase==='linear'?()=>bodies:(c,r)=>broad(c,r,c,r)),bodiesInBounds:spec.noSweep?null:index?.queryBounds||(spec.broadphase==='linear'?()=>bodies:broad),containsBody:contains,terrainAllows:(x,z)=>!inside(spec.terrain,x/spec.scale,z/spec.scale),blocksDynamic:(x,z,ctx)=>inside(spec.dynamic,x/spec.scale,z/spec.scale)&&ctx.ignoreId!=='own',surfaceAt:()=> 'land'});
 const resolve=q=>{sweepCalls++;us+=spec.cost;return nav.query(q)};
 const makePass=()=>((r,c)=>{passCalls++;us+=spec.cost;if(!inside(spec.bounds,c,r)||spec.corridor&&(r<spec.corridor[0]||r>spec.corridor[1]))return false;const q=nav.query({r,c});return !q.blocked&&q.depth<=.025;});
 let pass=makePass();
 const box={MAP_COLS:180,performance:{now:()=>us/1000},prevT:0,_walkNpcNavigationResolver:resolve};vm.createContext(box);vm.runInContext(scheduler+'\n'+setter+'\n'+planner,box);
 const actors=Array.from({length:spec.actors||1},(_,i)=>({id:'fixture:'+i,...spec.start})),done=new Set();
 let goal=spec.goal;spec.steps=[];
 for(frame=1;frame<=spec.maxFrames&&done.size<actors.length;frame++){
  us+=10000;box.prevT=frame;nav.beginFrame();
  if(frame===spec.changeFrame)bodies=spec.afterBodies;
  if(frame===spec.changeGoalFrame)goal=spec.afterGoal;
  if(frame===spec.changeWaterFrame)waterArea=spec.afterWater;
  if(frame===spec.restartFrame)pass=makePass();
  for(let id=0;id<actors.length;id++){
   if(done.has(id))continue;const npc=actors[id];
   if(frame===spec.cancelFrame){box._cancelNpcDirectedSearch(npc);done.add(id);spec.steps.push({frame,id,status:'CANCELLED',retained:0});continue;}
   for(let attempt=0;attempt<(spec.repeatFrame?2:1);attempt++){
    const before=us,pc=passCalls,sw=sweepCalls;npc._routeSearchPending=false;
    const admitted=box._npcReserveRouteWork(undefined,npc);let ok=false;
    if(admitted){const t=performance.now();try{ok=box._npcPlanNativeVisitRoute(npc,goal.r,goal.c,pass,spec.radius,spec.limit,'building_entry')}finally{box._npcFinishRouteWork();measured.push({name:spec.name,us:(performance.now()-t)*1000})}}
    else npc._routeSearchPending=true;
    const status=ok?'READY':npc._routeSearchPending?'PENDING':'NO_PATH';
    let cost=0,from=spec.start;if(ok)for(const to of npc._route){cost+=Math.hypot(to.r-from.r,to.c-from.c);from=to;}
    spec.steps.push({frame,id,status,admitted,passCalls:passCalls-pc,sweepCalls:sweepCalls-sw,cpuUs:us-before,expanded:admitted&&!npc._routeSearchPending?(npc._routeSearchExpanded||0):0,visited:admitted&&!npc._routeSearchPending?(npc._routeSearchVisited||0):0,restarts:npc._routeSearchRestarts||0,retained:npc._npcDirectedSearch?.nodes.size||0,path:ok?npc._route:null,cost});
    if(status!=='PENDING'){done.add(id);break;}
   }
  }
 }
 if(done.size!==actors.length)throw Error('fixture did not terminate: '+spec.name);
 spec.geometryCounts=nav.diagnostics();
}
const sweep=(fr,fc,r,c,radius=.18)=>({mode:'sweep',from:{r:fr,c:fc},to:{r,c},radius});
const geometryCases=[
 {name:'height_and_frame_cache',floor:0,scale:1,bodies:[rect(2,2,4,4,2,3)],ops:[{q:{r:3,c:3}},{floor:.2},{q:{r:3,c:3}},{reset:true},{q:{r:3,c:3}},{q:sweep(3,1,3,5)},{q:sweep(3,1,3,5)},{floor:3},{reset:true},{q:sweep(3,1,3,5)}]},
 {name:'water_invalid_support',floor:0,scale:1,bodies:[],water:[0,0,10,10],waterLevel:1,ops:[{q:{r:3,c:3}},{floor:1.2},{reset:true},{q:{r:3,c:3}},{floor:NaN},{reset:true},{q:{r:3,c:3}},{q:{r:NaN,c:3}}]},
 {name:'vehicle_identity',floor:0,scale:1,bodies:[],dynamic:[0,0,10,10],ops:[{q:{r:3,c:3}},{q:{r:3,c:3,ignoreVehicleId:'own'}},{q:{r:3,c:3,ignoreVehicleId:'other'}},{q:{r:3,c:3,ignoreVehicleId:'own'}},{q:{r:3,c:3,ignoreVehicleId:''}}]},
 {name:'sloping_contact',floor:.61,scale:1,slope:.51,bodies:[rect(-.3,1,.3,2,.54,.61)],duplicateFirst:true,ops:[{q:sweep(.7,0,1.2,0)},{q:sweep(.7,0,1.2,0)},{q:sweep(.7,0,1.2,0,0)},{q:sweep(NaN,0,1.2,0)}]},
 {name:'no_sweep_provider',floor:0,scale:1,bodies:[],noSweep:true,ops:[{q:sweep(0,0,1,1)}]},
 {name:'cache_limits',floor:0,scale:1,bodies:[],ops:[{points:30005},{sweeps:4005},{reset:true}]}
];
for(const s of geometryCases){let floor=s.floor;const bodies=s.duplicateFirst?[...s.bodies,s.bodies[0]]:s.bodies;
 const nav=createNpcNativeNavigation({worldScale:s.scale,groundHeight:(_x,z)=>floor+(s.slope||0)*(z-1),waterAt:(x,z)=>inside(s.water,x,z)?{level:s.waterLevel}:null,bodiesAt:()=>bodies,bodiesInBounds:s.noSweep?null:()=>bodies,containsBody:contains,blocksDynamic:(x,z,ctx)=>inside(s.dynamic,x,z)&&ctx.ignoreId!=='own',surfaceAt:()=> 'land'});
 for(const op of s.ops){if('floor'in op)floor=op.floor;if(op.reset)nav.beginFrame();if(op.q)op.expected=nav.query(op.q);if(op.points)for(let i=0;i<op.points;i++)nav.query({r:i,c:0});if(op.sweeps)for(let i=0;i<op.sweeps;i++)nav.query(sweep(i,0,i,1));op.counts=nav.diagnostics();}
}
function encode(v){if(typeof v==='number'){const b=Buffer.alloc(8);b.writeDoubleLE(v);return{$f64le:b.toString('hex')};}if(Array.isArray(v))return v.map(encode);if(v&&typeof v==='object')return Object.fromEntries(Object.entries(v).map(([k,w])=>[k,encode(w)]));return v;}
const indexCases=[.5,4].map(cellSize=>{const bodies=[rect(-.6,-.6,.6,.6),rect(3.998,3.6,4.002,4.5),rect(8,0,11,3)];const collections=[[bodies[0],bodies[1],bodies[0]],[bodies[2]]],index=createWalkCollisionIndex(collections,cellSize);const queries=[{point:[0,0]},{point:[4,4]},{point:[-.5,-.5]},{bounds:[-1,-1,5,5]},{bounds:[4,4,4,4]},{bounds:[0,0,12,8]},{bounds:[2,0,1,1]},{bounds:[NaN,0,1,1]}];for(const q of queries)q.expected=(q.point?index(...q.point):index.queryBounds(...q.bounds)).map(b=>bodies.indexOf(b));return {cellSize,bodies,queries};});
const result={schema:'mafiozi.npc-navigation-oracle/v1',numericEncoding:'ieee754-f64le-hex',sources:paths.map(p=>({path:p,sha256:sha(p)})),schedulerSha256:createHash('sha256').update(scheduler).digest('hex'),cases:encode(cases),geometryCases:encode(geometryCases),indexCases:encode(indexCases)};
const destination=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/npc_navigation_oracle.json');fs.writeFileSync(destination,JSON.stringify(result));
console.log(JSON.stringify({destination,cases:cases.length,steps:cases.reduce((n,c)=>n+c.steps.length,0),routes:cases.reduce((n,c)=>n+c.steps.filter(s=>s.status==='READY').length,0),bytes:fs.statSync(destination).size}));
const times=measured.map(x=>x.us).sort((a,b)=>a-b);console.log(JSON.stringify({sourceModuleCpuUs:{samples:times.length,p50:times[Math.floor(times.length*.5)],p95:times[Math.floor(times.length*.95)],max:times.at(-1)},limits:'CPU fixture providers with AABB broadphase; not FPS'}));
