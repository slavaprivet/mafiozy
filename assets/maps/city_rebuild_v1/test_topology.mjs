import assert from 'node:assert/strict';
import fs from 'node:fs';
import {compileTopology,pointInPolygon,segmentDistance} from './topology.mjs';
const rectangle=(x0,y0,x1,y1)=>[[x0,y0],[x1,y0],[x1,y1],[x0,y1]];
const host={policeProtectedCells:[{r:76,c:76,tile:3},{r:76,c:77,tile:3}]};
const fixture=()=>({schema:'mafiozy.city-masterplan/v3',version:'test',map:{rows:200,cols:180},
 immutable:{police_jail:{center_rc:[76,76],moved:false,security_envelope_grid:6},bridge:{rows:[47,56],canal_c:[80,100],centerline_grid:[[78.25,51.5],[101.75,51.5]],moved:false}},
 water:{waterbodies:[{id:'canal',polygon_grid:rectangle(80,0,100,200)}],islets:[{id:'island',polygon_grid:rectangle(86,180,94,188)}]},
 green_public:{parks:[{id:'plaza',kind:'plaza',polygon_grid:rectangle(8,60,15,70)}],big_beach:{id:'beach',polygon_grid:rectangle(100,175,110,200)}},
 transport:{arterials:[{id:'A-RED',points_grid:[[0,51.5],[179,51.5]],width_grid:3,sidewalk_width_grid:1}],collectors:[],local_roads:[],alleys_service:[],
 crossings:[{id:'XR-RED-01',kind:'immutable_premium_red_suspension_bridge',mode:'car',points_grid:[[78.25,51.5],[101.75,51.5]]}]}});
const freeze=o=>{if(o&&typeof o==='object'){Object.freeze(o);Object.values(o).forEach(freeze);}return o;};
const has=(result,code)=>result.validation.errors.some(e=>e.code===code);
const poly=rectangle(1,1,4,4);assert(pointInPolygon([1,2],poly));assert(pointInPolygon([4,4],poly));assert(pointInPolygon([2,2],poly));assert(!pointInPolygon([4.001,2],poly));
assert(pointInPolygon([.5,.5],[[0,0],[4,0],[4,1],[1,1],[1,4],[0,4]]));assert(!pointInPolygon([2,2],[[0,0],[4,0],[4,1],[1,1],[1,4],[0,4]]));
assert.equal(segmentDistance([2,3],[0,0],[4,0]),3);assert.equal(segmentDistance([3,4],[0,0],[0,0]),5);
const source=freeze(fixture()),before=JSON.stringify(source),ledger=freeze(structuredClone(host));
const result=compileTopology(source,ledger);assert.equal(result.status,'CANDIDATE_TOPOLOGY_ONLY',JSON.stringify(result.validation.errors));
assert.deepEqual(result,compileTopology(source,ledger));assert.equal(JSON.stringify(source),before);
assert.equal(result.grid.length,200);assert(result.grid.every(row=>row.length===180));
assert.equal(Object.values(result.validation.counts).reduce((a,b)=>a+b,0),36000);
assert.equal(result.grid[76][76],3);assert.equal(result.grid[77][76],8,'no invented police radius');
assert.equal(result.grid[183][90],8,'islet overrides water');assert.equal(result.grid[190][105],14);assert.equal(result.grid[64][10],9);
assert.equal(result.validation.connectivity.length,1);
for(let r=47;r<=56;r++)for(let c=80;c<=100;c++)assert.equal(result.grid[r][c],19);
assert.equal(result.grid[90][90],16);assert.equal(result.grid[51][40],0);
let s=fixture();delete s.transport.arterials[0].width_grid;assert(has(compileTopology(s,host),'ROAD_WIDTH_REQUIRED'));
s=fixture();s.transport.local_roads.push({id:'illegal',width_grid:2,points_grid:[[70,100],[110,100]]});
let rejected=compileTopology(s,host);assert.equal(rejected.grid,null);assert(has(rejected,'ROAD_CENTERLINE_UNAUTHORIZED_WATER'));assert(has(rejected,'ROAD_FOOTPRINT_UNAUTHORIZED_WATER'));
s=fixture();s.transport.local_roads.push({id:'edge-overhang',width_grid:4,points_grid:[[79,45],[79,65]]});
assert(has(compileTopology(s,host),'ROAD_FOOTPRINT_UNAUTHORIZED_WATER'),'finite width must fail even when centerline stays dry');
s=fixture();s.transport.collectors.push({id:'south',width_grid:3,sidewalk_width_grid:1,points_grid:[[20,51.5],[20,132],[179,132]]});
s.transport.crossings.push({id:'south-bridge',mode:'car',kind:'bridge',points_grid:[[79,132],[101,132]],envelope_polygon_grid:rectangle(79,130,102,134),road_ids:['south']});
const bridgeResult=compileTopology(s,host);assert.equal(bridgeResult.status,'CANDIDATE_TOPOLOGY_ONLY',JSON.stringify(bridgeResult.validation.errors));assert.equal(bridgeResult.grid[132][90],19);assert.equal(bridgeResult.grid[51][19],0,'sidewalk never overwrites existing road');
s.transport.local_roads.push({id:'unbound',width_grid:1,points_grid:[[75,132],[105,132]]});assert(has(compileTopology(s,host),'ROAD_CENTERLINE_UNAUTHORIZED_WATER'),'another road cannot borrow bridge binding');
s=fixture();s.transport.crossings.push({id:'tunnel',mode:'car',kind:'submerged_tunnel',points_grid:[[70,22],[110,22]]});assert(has(compileTopology(s,host),'MULTILAYER_TUNNEL_UNSUPPORTED'));
s=fixture();s.transport.local_roads.push({id:'isolated',width_grid:2,points_grid:[[10,100],[20,100]]});assert(has(compileTopology(s,host),'ROAD_GRID_DISCONNECTED'));
s=fixture();s.transport.local_roads.push({id:'police',width_grid:2,points_grid:[[70,76.5],[79,76.5]]});assert(has(compileTopology(s,host),'ROAD_POLICE_PROTECTION_CONFLICT'));
assert(has(compileTopology(fixture()),'EXACT_POLICE_CELLS_REQUIRED'));
s=fixture();s.water.waterbodies[0].polygon_grid[0]=[-1,0];assert(has(compileTopology(s,host),'POLYGON_BOUNDS'));
s=fixture();s.water.waterbodies[0].polygon_grid=[[1,1],[8,1],[2,8],[7,8],[1,4]];assert(has(compileTopology(s,host),'POLYGON_SELF_INTERSECTION'));
s=fixture();s.immutable.bridge.rows=[48,57];assert(has(compileTopology(s,host),'IMMUTABLE_RED_BRIDGE_CHANGED'));
const sourcePath=process.argv[2];
if(sourcePath){
 const actual=JSON.parse(fs.readFileSync(sourcePath,'utf8'));const snapshot=JSON.stringify(actual);
 const audited=compileTopology(freeze(actual));assert.equal(audited.status,'REJECTED');assert.equal(audited.grid,null);
 assert.equal(audited.validation.errors.filter(e=>e.code==='ROAD_WIDTH_REQUIRED').length,207);
 assert(has(audited,'ROAD_CENTERLINE_UNAUTHORIZED_WATER'));assert(has(audited,'EXACT_POLICE_CELLS_REQUIRED'));
 assert.deepEqual(audited,compileTopology(actual));assert.equal(JSON.stringify(actual),snapshot);
 console.log('ACTUAL SOURCE REJECTED:',JSON.stringify(audited.validation.errors.reduce((a,e)=>(a[e.code]=(a[e.code]||0)+1,a),{})));
}
console.log('PASS: pure deterministic 36000-cell compiler, exact police/red bridge, polygons/bounds/islets, finite widths, bridge bindings, water conflicts, 4-neighbor connectivity and fail-closed source rejection.');
