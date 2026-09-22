import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const source=fs.readFileSync('world.html','utf8');
const snapshot=JSON.parse(gunzipSync(fs.readFileSync('assets/maps/city_rebuild_v1/test_fixtures/native_static_collision19.json.gz')));
const f=await createCivilianNativeFixture({snapshot}),b=f.box;
const row=JSON.parse(fs.readFileSync('outputs/npc19_live_pending_walk_20260920.json','utf8')).rows.find(r=>r[0]==='resident_12');
assert(row);
const [id,r,c,speed,startR,startC,,,]=row;
const initial={id,r,c,speed,hp:100,_beach:true,_routeStartR:startR,_routeStartC:startC};
assert.equal(b.MAP[Math.floor(r)][Math.floor(c)],8);
assert.equal(f.pedestrian.query({r,c}).surface,'land');
assert.equal(b._npcBodyPassable(r,c,b.npcPassable),true);
const fixed=sourceFunction(source,'npcWaypointOk');
const nativeClause="  const nativeSurface=typeof _walkNpcNavigationResolver==='function'?_walkNpcNavigationResolver({r,c})?.surface:null;\n  if(nativeSurface==='land'||nativeSurface==='road')return nativeSurface!=='road';\n";
const normalized=fixed.replace(/\r\n/g,'\n');
assert(normalized.includes(nativeClause));
const old=normalized.replace(nativeClause,'').replace('  return (t === 9 || t === 8);',nativeClause+'  return (t === 9 || t === 8);');
vm.runInContext(old,b);
assert.equal(b.npcWaypointOk(initial,r,c),false,'old beach rule rejects actual dry sidewalk');
vm.runInContext(fixed,b);
assert.equal(b.npcWaypointOk(initial,r,c),true,'native dry sidewalk accepted');
b._npcAgendaPick=()=> 'wander';
vm.runInContext(sourceFunction(source,'pickNpcWaypoint'),b);
const n={...initial};b.NPCS.push(n);
let frames=0;
for(;frames<420&&!n._route?.length;frames++){f.nextFrame(1/7);b.pickNpcWaypoint(n);assert.equal(n.r,r,'planning cannot teleport');assert.equal(n.c,c);}
assert(n._route?.length,'actual native planner finds a route from stranded beach resident');
let previous={r,c};
for(const p of n._route){assert(b._npcPathPassable(previous.r,previous.c,p.r,p.c,b.npcPassable),'all route edges physically clear');assert(!f.pedestrian.query({r:p.r,c:p.c}).blocked);previous=p;}
const pathLength=n._route.length;
let travelled=0;
for(let frame=0;frame<140&&travelled<3;frame++){
 f.nextFrame(1/7);const pr=n.r,pc=n.c;b._npcAdvanceRoute(n,1/7,speed,b.npcPassable);
 const step=Math.hypot(n.r-pr,n.c-pc);assert(step<=speed/7+.00001,'movement is speed bounded');
 assert(b._npcPathPassable(pr,pc,n.r,n.c,b.npcPassable),'movement retains physical sweep');travelled+=step;
}
assert(travelled>2,'actual resident walks away rather than only receiving a route');

// Decision boundary tests leave prison/arena/lair/pit restrictions ahead of
// native land, and retain all legacy sand permissions without a Walk resolver.
let tile=8,blocked=false,surface='land',restricted=null;
const box={MAP_ROWS:200,MAP_COLS:200,MAP:new Proxy([],{get:()=>new Proxy([],{get:()=>tile})}),
 _inPrisonIslandRestrictedZone:()=>restricted==='prison',inArena:()=>restricted==='arena',inLair:()=>restricted==='lair',_inPitCorridor:()=>restricted==='pit',
 _npcRouteWalkBlocked:()=>blocked,_walkNpcNavigationResolver:()=>({surface}),_uniqueNpcCityPassable:()=>false};
vm.createContext(box);vm.runInContext(fixed,box);
const beach={_beach:true};
assert(box.npcWaypointOk(beach,160.5,90.5));
for(const zone of ['prison','arena','lair']){restricted=zone;assert.equal(box.npcWaypointOk(beach,160.5,90.5),false,zone);}restricted=null;
blocked=true;assert.equal(box.npcWaypointOk(beach,160.5,90.5),false,'native solid/water rejection');blocked=false;
surface='road';assert.equal(box.npcWaypointOk(beach,160.5,90.5),false);surface='land';
tile=14;restricted='pit';assert.equal(box.npcWaypointOk(beach,160.5,90.5),false);restricted=null;
assert(box.npcWaypointOk({},160.5,90.5),'actual native land supersedes old sand permission');
assert.equal(box.npcWaypointOk({_uniqueNpc:true},160.5,90.5),false,'unique NPC authority unchanged');
box._walkNpcNavigationResolver=null;tile=8;assert.equal(box.npcWaypointOk(beach,160.5,90.5),false);
assert(box.npcWaypointOk({},160.5,90.5));tile=14;assert(box.npcWaypointOk(beach,160.5,90.5));
assert.equal(box.npcWaypointOk(beach,130.5,90.5),false);assert.equal(box.npcWaypointOk({},160.5,90.5),false);assert(box.npcWaypointOk({_allowBeach:true},160.5,90.5));
console.log(JSON.stringify({pass:true,id,planningFrames:frames,pathLength,travelledCells:travelled,limits:f.limits+' Single actual resident regression; does not reproduce or resolve the live 211-owner backlog.'},null,2));
