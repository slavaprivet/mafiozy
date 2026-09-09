import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {planBuildings,cellsForRect,rectanglesOverlap} from './building_placement.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
// Original planner regression; enlarged placement and bank shells are covered
// by test_room_size_integration.mjs against the current production preview JSON.
const catalog=read(path.join(here,'buildings_catalog.v1.json')),plan=read(path.join(here,'buildings_placement.before_room_sizes.v1.json'));
const topology=read(path.join(here,'topology_for_placement.json')),source=read(plan.inputs[1].path),ledger=read(path.join(root,'docs/city-rebuild/rebuild-ledger.generated.json'));
let count=0;const test=(n,fn)=>{fn();console.log('PASS '+n);count++;};
test('catalog includes all latest ten homes plus eleven repo business/civic assets',()=>{
  assert.equal(catalog.entries.length,21);assert.equal(new Set(catalog.entries.map(a=>a.assetId)).size,21);
  assert.equal(catalog.entries.filter(a=>a.role==='residence').length,9);assert.equal(catalog.entries.filter(a=>a.role==='glass_tower').length,1);
  assert.ok(catalog.entries.every(a=>a.artAcceptance==='needs_visual_review'&&a.sourceHashVerified));
});
test('all 35 copied GLBs match pinned bytes/hash and valid GLB header',()=>{
  let n=0;for(const a of catalog.entries)for(const l of a.lods){const b=fs.readFileSync(path.join(root,l.url.slice(1)));
    assert.equal(b.length,l.bytes);assert.equal(createHash('sha256').update(b).digest('hex'),l.sha256);assert.equal(b.readUInt32LE(0),0x46546c67);assert.equal(b.readUInt32LE(8),b.length);n++;}
  assert.equal(n,35);
});
test('actual visual bounds and actual/authored entrance evidence present',()=>{
  for(const a of catalog.entries){assert.ok(a.measuredVisualVertices>0&&a.measuredVisualTriangles>0);assert.ok(a.dimensionsXYZ.every(n=>n>0&&Number.isFinite(n)));
    assert.equal(a.dimensionsXYZ[1],a.visualBounds.max[1]-a.visualBounds.min[1]);assert.ok(a.publicDoorLocalXYZ);assert.ok(!a.publicDoorEvidence.includes('missing'));}
});
test('real count and diverse silhouettes, not fake 518 procedural boxes',()=>{
  assert.equal(plan.counts.instances,plan.instances.length);assert.equal(plan.counts.assetTypesPlaced,new Set(plan.instances.map(i=>i.assetId)).size);
  assert.ok(plan.instances.length>30&&plan.instances.length<220);assert.ok(plan.counts.assetTypesPlaced>=15);
  assert.equal(new Set(plan.instances.map(i=>i.id)).size,plan.instances.length);
});
test('every complete footprint is grass, never road/water/protected cells',()=>{
  for(const i of plan.instances)for(const p of cellsForRect(i.footprint)){assert.equal(topology.grid[p.r]?.[p.c],8,i.id);assert.equal(topology.protectedMask[p.r]?.[p.c],0,i.id);}
});
test('every complete entry corridor is dry and reaches a real native road',()=>{
  for(const i of plan.instances){for(const p of cellsForRect(i.entryCorridor)){assert.ok([0,8,9].includes(topology.grid[p.r]?.[p.c]),i.id);assert.equal(topology.protectedMask[p.r]?.[p.c],0,i.id);}
    const p=i.entry.roadProbeRC;assert.equal(topology.grid[Math.floor(p.r)][Math.floor(p.c)],0,i.id);}
});
test('full envelopes and approach corridors never overlap other buildings',()=>{
  for(let a=0;a<plan.instances.length;a++)for(let b=a+1;b<plan.instances.length;b++){const i=plan.instances[a],j=plan.instances[b];
    assert.equal(rectanglesOverlap(i.clearance,j.clearance),false,`${i.id}/${j.id}`);
    assert.equal(rectanglesOverlap(i.footprint,j.entryCorridor),false);assert.equal(rectanglesOverlap(j.footprint,i.entryCorridor),false);}
});
test('police not replaced; protected bridge/police envelopes clear',()=>{
  assert.ok(!plan.instances.some(i=>i.assetId==='police_station'));
  assert.ok(plan.unresolved.some(i=>i.id==='poi:police'&&i.reason.includes('unchanged')));
  for(const i of plan.instances)for(const p of plan.protectedRects){assert.equal(rectanglesOverlap(i.footprint,p),false);assert.equal(rectanglesOverlap(i.entryCorridor,p),false);}
});
test('common renderer transform is metres and scale1; catalog offset aligns bounds',()=>{
  for(const i of plan.instances){const a=catalog.entries.find(a=>a.assetId===i.assetId);assert.equal(i.transform.uniformScale,1);assert.equal(i.transform.positionM[1],0);assert.deepEqual(i.transform.modelLocalOffsetM,a.recenterXYZ);
    assert.ok([0,90,180,270].includes(i.transform.yawDegrees));assert.deepEqual(i.binding,a.lods.find(l=>l.lod===0));
    const r=(i.footprint.minR+i.footprint.maxR)/2,c=(i.footprint.minC+i.footprint.maxC)/2;
    assert.ok(Math.abs(i.transform.positionM[0]-c*4.1)<1e-6);assert.ok(Math.abs(i.transform.positionM[2]-r*4.1)<1e-6);}
});
test('colliders exclude approach strip and stay within footprint',()=>{
  for(const i of plan.instances)for(const body of i.collision.worldBodies){const q=body.rectangleRC;assert.ok(q.minR>=i.footprint.minR-1e-7&&q.maxR<=i.footprint.maxR+1e-7&&q.minC>=i.footprint.minC-1e-7&&q.maxC<=i.footprint.maxC+1e-7);
    assert.equal(rectanglesOverlap(q,i.entryCorridor),false);assert.equal(body.polygonCR.length,4);assert.ok(body.maxYM>body.minYM);}
});
test('fixed business/bank identities not invented by visual facade names',()=>{
  assert.ok(plan.instances.every(i=>i.gameplayActive===false));
  for(const id of ['bank:small','bank:medium','bank:large','business:coffee','business:port'])assert.ok(plan.unresolved.some(x=>x.id===id));
  assert.ok(plan.instances.filter(i=>i.role==='business_facade').every(i=>i.gameplayId===null));
});
test('invalid or unprotected topology rejected, water-only topology places zero',()=>{
  assert.equal(planBuildings({topology:{status:'REJECTED'},catalog,source,ledger}).status,'REJECTED');
  const wet={...topology,grid:topology.grid.map(r=>r.map(()=>16))};assert.equal(planBuildings({topology:wet,catalog,source,ledger}).instances.length,0);
});
test('planner deterministic and does not mutate topology/catalog/ledger',()=>{
  const before=JSON.stringify({topology,catalog,source,ledger});const again=planBuildings({topology,catalog,source,ledger});
  assert.deepEqual(again.instances,plan.instances);assert.equal(JSON.stringify({topology,catalog,source,ledger}),before);
});
console.log(`${count} building placement tests passed`);
