import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation,PRINT_SHOP_SERVICE_PILOT} from './native_print_shop_service_station.mjs';
import {advanceStationaryServiceActor} from './npc_stationary_service_adapter.mjs';
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),entry=f.entry,originalBodies=entry.getCollisionBodies.bind(entry),originalInstance=JSON.stringify(f.item);
const source=p=>({r:p.z/f.M,c:p.x/f.M});
const clear=p=>!f.pedestrian.query({mode:'sweep',from:source(p),to:source(p),radius:.18}).blocked;
const path=(a,b)=>!f.pedestrian.query({mode:'sweep',from:source(a),to:source(b),radius:.18}).blocked;
function overlap(a,b){
 for(const polygon of [a,b])for(let i=0;i<polygon.length;i++){
  const p=polygon[i],q=polygon[(i+1)%polygon.length],ax=-(q[1]-p[1]),az=q[0]-p[0],pa=a.map(v=>v[0]*ax+v[1]*az),pb=b.map(v=>v[0]*ax+v[1]*az);
  if(Math.max(...pa)<=Math.min(...pb)+1e-9||Math.max(...pb)<=Math.min(...pa)+1e-9)return false;
 }
 return true;
}
const baseBodies=f.bodies.slice(),overlapsOriginal=body=>baseBodies.some(b=>(b.maxYM??100)>body.minYM+.05&&(b.minYM??-100)<body.maxYM-.001&&overlap(body.polygonCR,b.polygonCR));
let validations=0;
const options={THREE:f.THREE,entry,siteRevision:'service-pilot-v1',validateLayout:({layout,counterRect,room})=>{
 validations++;const r=counterRect,polygonCR=[[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]].map(([x,z])=>{const p=entry.storeys.worldPoint({x,y:room.y,z});return[p.x/f.M,p.z/f.M];});
 return Object.values(layout).filter(p=>p&&typeof p==='object'&&'x'in p).every(clear)&&!overlapsOriginal({polygonCR,minYM:layout.work.y,maxYM:layout.work.y+1.34});
}};
const station=createPrintShopServiceStation(options),layout=station.layout;
assert.equal(createPrintShopServiceStation(options),station,'one station per entry');assert.equal(validations,1);
assert.throws(()=>createPrintShopServiceStation({...options,siteRevision:'changed'}));
assert.throws(()=>createPrintShopServiceStation({...options,entry:{...entry,instance:{...f.item,id:'another-print-shop'}}}));
entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies());
const refresh=()=>{f.refreshBodies();f.pedestrian.beginFrame();};refresh();
assert.equal(layout.buildingId,PRINT_SHOP_SERVICE_PILOT);assert.equal(JSON.stringify(f.item),originalInstance,'building metadata is untouched');
for(const key of ['spawn','doorInside','doorOutside','work','customer','customerVia'])assert(clear(layout[key]),key+' full .738m source capsule clear');
assert(path(layout.spawn,layout.doorInside));assert.equal(path(layout.doorInside,layout.doorOutside),false,'closed real leaf blocks travel');
assert.equal(path(layout.work,layout.customer),false,'counter is solid, not decorative');
const insideBody={position:layout.doorInside,radius:.18*f.M,height:1.9},outsideBody={position:layout.doorOutside,radius:.18*f.M,height:1.9};
assert(station.requestDoor(true,{actorPosition:layout.doorInside,occupants:[insideBody]}).accepted);
const cachedClosed=station.getCollisionBodies();for(let i=0;i<7;i++){station.update(.1,[insideBody]);for(const body of station.getCollisionBodies())assert(!overlapsOriginal(body),'new furniture/leaf/handles do not intersect existing physical geometry');}refresh();
assert(station.doorState.fraction>.999);assert.notEqual(station.getCollisionBodies(),cachedClosed);
assert(path(layout.doorInside,layout.doorOutside),'full NPC capsule passes opened door with handles');
assert(path(layout.doorOutside,layout.work),'seller reaches back of counter');
const access=f.box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===f.item.id),customerEntry={x:access.inside.c*f.M,y:layout.customer.y,z:access.inside.r*f.M};
assert(path(customerEntry,layout.customerVia),'customer clears the public doorway before turning');
assert(path(layout.customerVia,layout.customer),'customer reaches counter through the clear public lane');
const movementResults=[];
for(const hz of [60,15,7,5,3]){
 const host={identity:n=>({id:n.id,generation:n.generation}),hasControl:()=>true,canSweep:(a,b)=>f.box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isStationFloor:(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05};
 for(const [role,points] of [['staff',[layout.spawn,layout.doorInside,layout.doorOutside,layout.work]],['customer',[customerEntry,layout.customerVia,layout.customer]]]){
  const npc={id:role,generation:1,hp:100,r:points[0].z/f.M,c:points[0].x/f.M},start=performance.now();let steps=0,travel=0;
  for(const target of points.slice(1)){
   let result;
   do{
    f.pedestrian.beginFrame();
    const before={r:npc.r,c:npc.c};
    result=advanceStationaryServiceActor({actor:npc,target,actorId:role,generation:1,controlToken:'station-lease',dt:1/hz},host);
    assert.notEqual(result.status,'blocked',role+' path at '+hz+'Hz');assert.notEqual(result.status,'hold');
    assert(Math.hypot(npc.r-before.r,npc.c-before.c)*f.M<=1.25/hz+1e-8,'no teleports at low FPS');
    travel+=result.movedMetres;assert(++steps<1800);
   }while(result.status!=='arrived');
   assert(Math.hypot(npc.r-target.z/f.M,npc.c-target.x/f.M)*f.M<=.08,'precise physical service arrival');
  }
  movementResults.push({role,hz,steps,travelMetres:travel,cpuMs:performance.now()-start});
 }
}
const doorway=entry.storeys.worldPoint({x:station.local.doorInside.x,y:0,z:station.local.doorInside.z+1.15}),obstruction={position:doorway,radius:.36,height:1.9};
assert.equal(station.requestDoor(false,{actorPosition:layout.doorOutside,occupants:[outsideBody,obstruction]}).reason,'door-sweep-occupied');
assert(station.requestDoor(false,{actorPosition:layout.doorOutside,occupants:[outsideBody]}).accepted);
let stopped=false;for(let i=0;i<12;i++){if(!station.update(.1,[outsideBody,obstruction])){stopped=true;break;}}
assert(stopped&&station.doorState.fraction>0,'new obstruction stops the moving leaf before it can close through a body');refresh();
assert.equal(f.pedestrian.query({mode:'sweep',from:source(doorway),to:source(doorway),radius:.36/f.M}).blocked,false,'stopped leaf leaves the actual obstructing capsule clear');
for(let i=0;i<7;i++)station.update(.1,[outsideBody]);refresh();assert(station.doorState.fraction<1e-8);assert.equal(path(layout.doorInside,layout.doorOutside),false);
const stats=station.stats();assert(stats.draws<=4);assert(stats.triangles<1200);const idleBody=station.getCollisionBodies(),idle=[];
for(let i=0;i<400;i++){const at=performance.now();station.update(1/60,[outsideBody]);station.getCollisionBodies();if(i>=50)idle.push(performance.now()-at);}
assert.equal(station.getCollisionBodies(),idleBody,'closed idle returns cached colliders');idle.sort((a,b)=>a-b);
station.dispose();assert.equal(station.root.parent,null);assert.deepEqual(station.getCollisionBodies(),[]);entry.getCollisionBodies=originalBodies;refresh();entry.dispose();
const report={pass:true,buildingId:f.item.id,stats,layout,movementResults,checks:'Actual GLB, full source capsules, closed/open leaf, staff/customer paths, counter collision, dynamic door obstruction, duplicate construction, disposal',idleCpuMs:{p50:idle[175],p95:idle[332]},limits:'Single actual building/static city collision fixture. No stationary NPC source/renderer activation, camera occlusion certification, whole city LIVE or FPS acceptance.'};
fs.writeFileSync(new URL('../../../outputs/native_print_shop_service_station23.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
