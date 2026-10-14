import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {
 WALK_MAP_TOPOLOGY_PAINT_DEPENDENCIES,
 compileWalkMapTopologyPaint,
 createWalkMapTopologyPaintOperation,
 createWalkMapTopologyRestoreOperation,
 createWalkMapTopologyPaintRebuilder,
 walkMapTopologySourceRevision
} from './walk_map_editor_topology_paint.mjs';

const here=new URL('.',import.meta.url),readJson=async name=>JSON.parse(await readFile(new URL(name,here),'utf8'));
const [topology,buildingsPlacement]=await Promise.all([readJson('topology_for_placement.json'),readJson('buildings_placement.v1.json')]);
const inventory=(overrides={})=>({complete:{buildings:true,parking:true,roadAccess:true},buildings:buildingsPlacement.instances,parkingKeepouts:[],roadAccessCells:[],...overrides});
const cell=(predicate)=>{for(let r=0;r<200;r++)for(let c=0;c<180;c++)if(predicate(r,c))return [r,c];throw new Error('fixture cell not found')};
const protectedCell=cell((r,c)=>[0,8].includes(topology.grid[r][c])&&(topology.protectedMask[r][c]||topology.policeMask[r][c]||topology.bridgeDeckMask[r][c]));
const sidewalkCell=cell((r,c)=>topology.grid[r][c]===9),sandCell=cell((r,c)=>topology.grid[r][c]===14),waterCell=cell((r,c)=>topology.grid[r][c]===16);

function compileCandidate(r,c){const operation=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'asphalt',id:'real-adjacent-road'});try{return compileWalkMapTopologyPaint({topology,operation,inventory:inventory()})}catch{return null}}
let roadExtension=null;for(let r=0;r<200&&!roadExtension;r++)for(let c=0;c<180;c++)if(topology.grid[r][c]===8&&!topology.protectedMask[r][c]&&[[-1,0],[1,0],[0,-1],[0,1]].some(([dr,dc])=>topology.roadMask[r+dr]?.[c+dc])){roadExtension=compileCandidate(r,c);if(roadExtension)break}
assert.ok(roadExtension,'real snapshot must contain one safe grass cell adjacent to the connected road network');
const extensionCell=[roadExtension.edits[0].r,roadExtension.edits[0].c];

test('real 200x180 snapshot has a deterministic guarded revision and only proven materials',()=>{
 assert.equal(topology.map.rows,200);assert.equal(topology.map.cols,180);assert.equal(topology.map.worldUnitsPerCell,4.1);const first=walkMapTopologySourceRevision(topology),second=walkMapTopologySourceRevision(structuredClone(topology));assert.equal(first,second);assert.match(first,/^topology-v1:200x180:[a-f0-9]{16}$/);
 assert.throws(()=>createWalkMapTopologyPaintOperation({topology,cells:[[0,0]],materialId:'earth'}),error=>error.code==='TOPOLOGY_MATERIAL_UNSUPPORTED'&&/только асфальт и трава/.test(error.message));
 assert.throws(()=>createWalkMapTopologyPaintOperation({topology,cells:[[0,0]],materialId:'dirt-road'}),error=>error.code==='TOPOLOGY_MATERIAL_UNSUPPORTED');
});

test('single real cell paint is lossless, reversible and updates exact derived fields',()=>{
 const before=structuredClone(topology),[r,c]=extensionCell,operation=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'asphalt',id:'single-cell'}),compiled=compileWalkMapTopologyPaint({topology,operation,inventory:inventory()});
 assert.equal(compiled.changed,true);assert.equal(compiled.topology.grid[r][c],0);assert.equal(compiled.topology.roadMask[r][c],1);assert.equal(compiled.topology.walkableMask[r][c],1);assert.deepEqual(compiled.dependencies,[...WALK_MAP_TOPOLOGY_PAINT_DEPENDENCIES.base,...WALK_MAP_TOPOLOGY_PAINT_DEPENDENCIES.road]);assert.equal(compiled.fullRebuild,true);assert.deepEqual(topology,before,'compiler must not mutate real topology');
 assert.equal(compiled.topology.validation.counts['8'],topology.validation.counts['8']-1);assert.equal(compiled.topology.validation.counts['0'],topology.validation.counts['0']+1);assert.equal(compiled.topology.validation.connectedRoadCells,topology.validation.connectedRoadCells+1);
 const undone=compileWalkMapTopologyPaint({topology:compiled.topology,operation:compiled.receipt.inverseOperation,inventory:inventory()});assert.deepEqual(undone.topology,topology);assert.equal(undone.resultRevision,operation.sourceRevision);
});

test('brush/stroke cells are deduplicated, sorted and compile atomically',()=>{
 const [r,c]=extensionCell,neighbour=cell((rr,cc)=>topology.grid[rr][cc]===8&&Math.abs(rr-r)+Math.abs(cc-c)===1),operation=createWalkMapTopologyPaintOperation({topology,cells:[neighbour,[r,c],[r,c]],materialId:'asphalt',id:'stroke'});assert.deepEqual(operation.edits.map(({r,c})=>[r,c]),[...operation.edits].sort((a,b)=>a.r-b.r||a.c-b.c).map(({r,c})=>[r,c]));assert.equal(operation.edits.length,2);
 const compiled=compileWalkMapTopologyPaint({topology,operation,inventory:inventory()});assert.equal(compiled.edits.length,2);assert.ok(compiled.edits.every(edit=>compiled.topology.grid[edit.r][edit.c]===0));
});

test('bounds and tile 9/14/water semantics fail closed instead of becoming earth',()=>{
 assert.throws(()=>createWalkMapTopologyPaintOperation({topology,cells:[[-1,0]],materialId:'grass'}),error=>error.code==='TOPOLOGY_CELL_OUT_OF_BOUNDS');assert.throws(()=>createWalkMapTopologyPaintOperation({topology,cells:[[200,0]],materialId:'grass'}),error=>error.code==='TOPOLOGY_CELL_OUT_OF_BOUNDS');
 for(const [fixture,tile,phrase] of [[sidewalkCell,9,/тротуар\/бордюр/],[sandCell,14,/песок/],[waterCell,16,/воде/]]){const operation=createWalkMapTopologyPaintOperation({topology,cells:[fixture],materialId:'grass'});assert.throws(()=>compileWalkMapTopologyPaint({topology,operation,inventory:inventory()}),error=>error.code==='TOPOLOGY_SOURCE_TILE_LOCKED'&&error.details.tile===tile&&phrase.test(error.message))}
});

test('protected, building and parking cells block the whole paint operation',()=>{
 const [pr,pc]=protectedCell,protectedMaterial=topology.grid[pr][pc]===0?'grass':'asphalt',protectedOperation=createWalkMapTopologyPaintOperation({topology,cells:[[pr,pc]],materialId:protectedMaterial});assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:protectedOperation,inventory:inventory()}),error=>error.code==='TOPOLOGY_CELL_PROTECTED');assert.equal(topology.grid[pr][pc],protectedMaterial==='grass'?0:8,'a rejected stroke must be atomic');
 let buildingFixture=null;for(const building of buildingsPlacement.instances){const box=building.footprint;if(!box)continue;for(let r=Math.max(0,Math.floor(box.minR));r<Math.min(200,Math.ceil(box.maxR))&&!buildingFixture;r++)for(let c=Math.max(0,Math.floor(box.minC));c<Math.min(180,Math.ceil(box.maxC));c++)if([0,8].includes(topology.grid[r][c])&&!topology.protectedMask[r][c]){buildingFixture=[r,c];break}if(buildingFixture)break}assert.ok(buildingFixture);
 const buildingMaterial=topology.grid[buildingFixture[0]][buildingFixture[1]]===0?'grass':'asphalt',buildingOperation=createWalkMapTopologyPaintOperation({topology,cells:[buildingFixture],materialId:buildingMaterial});assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:buildingOperation,inventory:inventory()}),error=>error.code==='TOPOLOGY_BUILDING_OVERLAP');
 const [r,c]=extensionCell,parkingOperation=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'asphalt'}),parkingKeepout={id:'parking-test',rectCR:{minR:r,minC:c,maxR:r+1,maxC:c+1}};assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:parkingOperation,inventory:inventory({parkingKeepouts:[parkingKeepout]})}),error=>error.code==='TOPOLOGY_PARKING_OVERLAP');
});

test('road access and connected network remain mandatory',()=>{
 const probe=buildingsPlacement.instances.find(item=>item.entry?.roadProbeRC)?.entry.roadProbeRC,r=Math.floor(probe.r),c=Math.floor(probe.c);assert.equal(topology.grid[r][c],0);const removeAccess=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'grass'}),minimalInventory=inventory({buildings:[],roadAccessCells:[{id:'required-access',r,c}]});assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:removeAccess,inventory:minimalInventory}),error=>error.code==='TOPOLOGY_ROAD_ACCESS_BLOCKED');
 const isolated=cell((rr,cc)=>topology.grid[rr][cc]===8&&!topology.protectedMask[rr][cc]&&[[-1,0],[1,0],[0,-1],[0,1]].every(([dr,dc])=>!topology.roadMask[rr+dr]?.[cc+dc])),isolatedOperation=createWalkMapTopologyPaintOperation({topology,cells:[isolated],materialId:'asphalt'});assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:isolatedOperation,inventory:inventory()}),error=>error.code==='TOPOLOGY_ROAD_NETWORK_DISCONNECTED');
});

test('stale source, stale cell, duplicate edits and incomplete inventory fail closed',()=>{
 const operation=createWalkMapTopologyPaintOperation({topology,cells:[extensionCell],materialId:'asphalt'}),changed=structuredClone(topology);changed.grid[199][179]=changed.grid[199][179]===8?0:8;changed.roadMask[199][179]=changed.grid[199][179]===0?1:0;assert.throws(()=>compileWalkMapTopologyPaint({topology:changed,operation,inventory:inventory()}),error=>error.code==='TOPOLOGY_SOURCE_STALE');
 const cellStale={...operation,sourceRevision:walkMapTopologySourceRevision(topology),edits:operation.edits.map(edit=>({...edit,from:0}))};assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:cellStale,inventory:inventory()}),error=>error.code==='TOPOLOGY_CELL_STALE');
 const duplicate={...operation,edits:[operation.edits[0],operation.edits[0]]};assert.throws(()=>compileWalkMapTopologyPaint({topology,operation:duplicate,inventory:inventory()}),error=>error.code==='TOPOLOGY_CELL_DUPLICATE');assert.throws(()=>compileWalkMapTopologyPaint({topology,operation,inventory:{complete:{}}}),error=>error.code==='TOPOLOGY_INVENTORY_INCOMPLETE');
});

test('no-op is allocation-free, deterministic and has no rebuild dependencies',()=>{
 const [r,c]=extensionCell,operation=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'grass',id:'no-op'}),first=compileWalkMapTopologyPaint({topology,operation,inventory:inventory()}),second=compileWalkMapTopologyPaint({topology,operation,inventory:inventory()});assert.equal(first.changed,false);assert.equal(first.topology,topology);assert.deepEqual(first.dependencies,[]);assert.equal(first.fullRebuild,false);assert.equal(first.receipt.inverseOperation,null);assert.deepEqual(first,second);
});

test('erase restores only trusted base asphalt or grass and never invents a tile',()=>{
 const [r,c]=extensionCell,paint=createWalkMapTopologyPaintOperation({topology,cells:[[r,c]],materialId:'asphalt',id:'paint-before-erase'}),painted=compileWalkMapTopologyPaint({topology,operation:paint,inventory:inventory()}),restore=createWalkMapTopologyRestoreOperation({topology:painted.topology,baseTopology:topology,cells:[[r,c]],id:'trusted-restore'}),restored=compileWalkMapTopologyPaint({topology:painted.topology,operation:restore,inventory:inventory()});assert.equal(restored.topology.grid[r][c],topology.grid[r][c]);assert.deepEqual(restored.topology,topology);assert.equal(restore.edits[0].to,8);
 for(const [fixture,tile] of [[sidewalkCell,9],[sandCell,14],[waterCell,16]])assert.throws(()=>createWalkMapTopologyRestoreOperation({topology,baseTopology:topology,cells:[fixture]}),error=>error.code==='TOPOLOGY_RESTORE_TILE_LOCKED'&&error.details.tile===tile);
});

test('failed atomic install restores the exact prior topology and exposes undo receipt',async()=>{
 const operation=createWalkMapTopologyPaintOperation({topology,cells:[extensionCell],materialId:'asphalt',id:'rollback'}),calls=[],rebuilder=createWalkMapTopologyPaintRebuilder({getTopology:()=>topology,inventory:inventory(),installTopology:async(value,meta)=>{calls.push({value:structuredClone(value),meta:structuredClone(meta)});if(calls.length===1)throw new Error('render rebuild failed')}});await assert.rejects(()=>rebuilder({operation,label:'real topology paint'}),/render rebuild failed/);assert.equal(calls.length,2);assert.equal(calls[0].meta.committed,true);assert.equal(calls[1].meta.rollback,true);assert.deepEqual(calls[1].value,topology);assert.ok(calls[0].meta.receipt.inverseOperation);
});
