import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {buildCatalog,localPosition,sourceAssetPath,serializeCatalog,ROOT} from './export_map_editor_catalog.mjs';
const catalog=await buildCatalog();
test('full semantic map inventory is complete; LIVE crop remains explicitly separate',()=>{
 assert.deepEqual({...catalog.counts,importedResources:0,liveAuthoredObjects:0},{authoredBuildings:75,detention:3,authoredDecor:164,generated:9659,objects:9901,resources:196,importedResources:0,liveAuthoredObjects:0});
 assert.equal(catalog.counts.importedResources,catalog.resources.filter(v=>v.resPath).length);
 assert.equal(catalog.counts.liveAuthoredObjects,catalog.objects.filter(v=>v.livePresent).length);
 assert.equal(new Set(catalog.objects.map(v=>v.key)).size,9901);
 assert.equal(catalog.objects.filter(v=>v.status==='pending-native-generator').length,9659);
 assert.ok(catalog.objects.filter(v=>v.dataset==='detention').every(v=>v.sourceRecord.role==='district_detention'));
});
test('source authored object metadata, exact collision flags and all special anchors survive',async()=>{
 for(const [file,dataset] of [['buildings_placement.v1.json','buildings'],['decor_placement.v1.json','decor'],['detention_native_sites.v1.json','detention']]){
  const source=JSON.parse(await readFile(resolve(ROOT,'assets/maps/city_rebuild_v1',file),'utf8'));
  for(const record of source.instances){const object=catalog.objects.find(v=>v.key===`${dataset}:${record.id}`);assert.deepEqual(object.sourceRecord,record);assert.deepEqual(object.positionLocalM,localPosition(record.transform.positionM,catalog.originM));}
 }
 assert.ok(catalog.objects.filter(v=>v.dataset==='detention').every(v=>v.sourceRecord.collision.worldBodies.some(b=>b.carOnly)));
});
test('generated original plans survive in addition to lean semantic summaries',()=>{
 assert.equal(catalog.generatedPlans.roadDressing.markings.length,6449);
 assert.equal(catalog.generatedPlans.parking.lots.length,39);
 assert.equal(catalog.generatedPlans.explorationDecor.objects.length,2440);
 assert.equal(catalog.generatedPlans.railway.points.length,1021);
 assert.ok(catalog.objects.some(v=>v.category==='monuments'));
 assert.ok(catalog.surface.sourceDocument.policeMask&&catalog.surface.sourceDocument.protectedMask);
});
test('unchanged mesh/material resources are hash deduplicated; no made-up native resources',()=>{
 assert.equal(new Set(catalog.resources.map(v=>v.sha256)).size,catalog.resources.length);
 for(const resource of catalog.resources){assert.match(resource.sha256,/^[a-f0-9]{64}$/);assert.ok(resource.bytes>20);if(resource.resPath)assert.match(resource.resPath,/^res:\/\/assets\/.*\.glb$/);else assert.equal(resource.status,'pending-import');}
 for(const object of catalog.objects.filter(v=>v.resourceId))assert.ok(catalog.resources.find(v=>v.id===object.resourceId));
 assert.ok(catalog.assets.some(v=>v.assetId==='bank_large_shell_v1'));
});
test('conversion preserves native metre coordinates; path traversal is rejected',()=>{
 assert.equal(catalog.metresPerCell,4.1);
 assert.deepEqual(localPosition([400,1,50],[395,0,45]),[5,1,5]);
 assert.throws(()=>sourceAssetPath('/assets/../../private.glb'),/outside/);
 assert.throws(()=>sourceAssetPath('https://example.org/model.glb'),/Unsafe/);
 assert.throws(()=>localPosition([Infinity,0,0],[0,0,0]),/Invalid/);
});
test('machine output matches checked-in reproducible catalog',async()=>{
 const raw=await readFile(resolve(ROOT,'godot/mafiozi_walk/data/map_editor/catalog.json'),'utf8');
 assert.equal(raw,serializeCatalog(catalog));
 assert.ok(catalog.sources.every(v=>v.path&&!v.path.includes('\\')&&/^[a-f0-9]{64}$/.test(v.sha256)));
});
