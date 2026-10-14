import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {createWalkMapEditorPalette,createWalkMapExplorationAdditionPalette,createWalkMapSurfacePalette,walkMapEditorRussianAssetLabel} from './walk_map_editor_palette.mjs';

const here=new URL('.',import.meta.url),read=async file=>JSON.parse(await readFile(new URL(file,here),'utf8'));
const [buildingCatalog,decorCatalog,buildingPlacement,detentionPlacement,decorPlacement]=await Promise.all([
 read('buildings_catalog.v1.json'),read('decor_catalog.v1.json'),read('buildings_placement.v1.json'),read('detention_native_sites.v1.json'),read('decor_placement.v1.json')
]);
const currentRecords=[...buildingPlacement.instances,...detentionPlacement.instances,...decorPlacement.instances];
const palette=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords}),surfaces=createWalkMapSurfacePalette();
const byAsset=new Map(palette.map(item=>[item.assetId,item])),catalogAssetIds=new Set([...buildingCatalog.entries,...decorCatalog.entries].map(entry=>entry.assetId));
const currentAssetIds=[...new Set(currentRecords.map(record=>record.assetId))].sort();
const acceptance=entry=>typeof entry.artAcceptance==='string'?entry.artAcceptance:entry.artAcceptance?.status||entry.sourceAcceptance||'unknown';

test('actual palette has the reviewed availability totals',()=>{
 assert.equal(currentRecords.length,242);assert.equal(currentAssetIds.length,33);
 assert.equal(palette.length,68);assert.equal(palette.filter(item=>item.available).length,42);assert.equal(palette.filter(item=>!item.available).length,26);
 assert.deepEqual(Object.fromEntries(['buildings','lights','signs','monuments','nature','ground','decor'].map(category=>[category,{total:palette.filter(item=>item.category===category).length,available:palette.filter(item=>item.category===category&&item.available).length,unavailable:palette.filter(item=>item.category===category&&!item.available).length}])),{
  buildings:{total:23,available:23,unavailable:0},lights:{total:4,available:4,unavailable:0},signs:{total:8,available:2,unavailable:6},monuments:{total:3,available:3,unavailable:0},nature:{total:2,available:2,unavailable:0},ground:{total:23,available:3,unavailable:20},decor:{total:5,available:5,unavailable:0}
 });
});

test('every currently placed asset is represented and available',()=>{
 for(const assetId of currentAssetIds){const item=byAsset.get(assetId);assert.ok(item,`current asset missing from palette: ${assetId}`);assert.equal(item.available,true,`current asset unavailable: ${assetId}`)}
 const absentFromBothCatalogs=currentAssetIds.filter(assetId=>!catalogAssetIds.has(assetId));
 assert.deepEqual(absentFromBothCatalogs,['bank_large_shell_v1','bank_medium_shell_v1','bank_small_shell_v1']);
 for(const assetId of absentFromBothCatalogs){const item=byAsset.get(assetId);assert.equal(item.source,'current-placement');assert.equal(item.category,'buildings');assert.equal(item.placementMode,'building');assert.ok(item.binding?.url)}
});

test('actual building and decor placements map to the intended categories',()=>{
 for(const record of [...buildingPlacement.instances,...detentionPlacement.instances])assert.equal(byAsset.get(record.assetId)?.category,'buildings',record.assetId);
 for(const record of decorPlacement.instances){const expected=/^lamp_/.test(record.assetId)?'lights':/^fountain_/.test(record.assetId)?'monuments':record.assetId.startsWith('planter_')?'nature':'decor';assert.equal(byAsset.get(record.assetId)?.category,expected,record.assetId)}
});

test('approved catalog objects are placeable and unreviewed loose objects stay hidden',()=>{
 const approved=decorCatalog.entries.filter(entry=>acceptance(entry)==='approved_civic_kit'&&!['collection_not_single_placement','building_catalog_only'].includes(entry.assetRole));
 assert.equal(approved.length,18);for(const entry of approved){const item=byAsset.get(entry.assetId);assert.ok(item,entry.assetId);assert.equal(item.available,entry.kind!=='road_sign',entry.assetId)}
 for(const assetId of ['fire_station','stream_footbridge','beach_umbrella','rural_gate'])assert.equal(byAsset.has(assetId),false,`${assetId} needs visual acceptance`);
});

test('module and road-control adapter assets remain visible but disabled without their runtime compilers',()=>{
 const adapters=decorCatalog.entries.filter(entry=>['walkable_surface_adapter_required','signal_adapter_required'].includes(entry.assetRole));
 assert.equal(adapters.length,23);
 for(const entry of adapters){const item=byAsset.get(entry.assetId);assert.ok(item,`adapter entry hidden: ${entry.assetId}`);assert.equal(item.available,false,entry.assetId);if(entry.assetRole==='walkable_surface_adapter_required'){assert.equal(item.category,'ground');assert.equal(item.placementMode,'module');assert.equal(item.reason,'Нужен адаптер модульных дорожек и настилов')}else{assert.equal(item.category,'signs');assert.equal(item.placementMode,'road-control');assert.equal(item.reason,'Требуется дорожный адаптер привязки')}}
 assert.equal(adapters.filter(entry=>entry.assetRole==='walkable_surface_adapter_required').length,20);assert.equal(adapters.filter(entry=>entry.assetRole==='signal_adapter_required').length,3);
});

test('verified module and road-control adapters make the exact 68-item palette available',()=>{
 const enabled=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords,roadControlAdapterAvailable:true,modulePlacementAdapterAvailable:true});assert.equal(enabled.length,68);assert.equal(enabled.filter(item=>item.available).length,68);assert.equal(enabled.filter(item=>!item.available).length,0);
 const modules=enabled.filter(item=>item.raw?.assetRole==='walkable_surface_adapter_required');assert.equal(modules.length,20);assert.ok(modules.every(item=>item.placementMode==='module'&&/spatial contract/i.test(item.reason)));
 const roadControls=enabled.filter(item=>item.placementMode==='road-control');assert.equal(roadControls.length,6);assert.ok(roadControls.every(item=>item.available));
});

test('collection GLBs and duplicate building-only decor entries are excluded',()=>{
 assert.equal(byAsset.has('street_furniture_v1'),false);
 for(const entry of decorCatalog.entries.filter(entry=>['collection_not_single_placement','building_catalog_only'].includes(entry.assetRole)))assert.equal(palette.some(item=>item.key===`asset:decor:${entry.assetId}`),false,entry.assetId);
 assert.equal(byAsset.get('civic_hall')?.key,'asset:building:civic_hall');
});

test('keys, bindings and Russian labels are stable and unique',()=>{
 assert.equal(new Set(palette.map(item=>item.key)).size,palette.length);assert.equal(new Set(palette.map(item=>item.assetId)).size,palette.length);
 assert.equal(new Set([...palette,...surfaces].map(item=>item.key)).size,palette.length+surfaces.length);
 assert.ok(palette.every(item=>item.binding?.url&&/^[a-f0-9]{64}$/i.test(item.binding.sha256)),`invalid binding: ${palette.find(item=>!item.binding?.url||!/^[a-f0-9]{64}$/i.test(item.binding?.sha256||''))?.assetId}`);
 assert.ok(palette.every(item=>item.label&&!/[a-z]/i.test(item.label)),`non-Russian label: ${palette.find(item=>/[a-z]/i.test(item.label))?.label}`);
 assert.ok(palette.every(item=>item.categoryLabel&&!/^(buildings|ground|lights|signs|monuments|decor|nature|railway)$/i.test(item.categoryLabel)));
 assert.match(walkMapEditorRussianAssetLabel('fountain_central'),/фонтан/i);assert.equal(walkMapEditorRussianAssetLabel('traffic_signal_4way_v1'),'Дорожный светофор четырёхсторонний');
});

test('surface palette exposes only the two proven topology mappings',()=>{
 assert.deepEqual(surfaces.map(item=>item.label),['Асфальт','Просёлочная дорога','Земля','Трава']);
 assert.deepEqual(surfaces.map(item=>item.available),[true,false,false,true]);
 assert.deepEqual(surfaces.map(item=>item.placementMode),['paint','overlay','overlay','paint']);
 for(const item of surfaces.filter(item=>!item.available)){assert.match(item.reason,/overlay-адаптер/i);assert.match(item.reason,/tile 9\/14/i)}
 assert.match(surfaces[0].subtitle,/tile 0/);assert.match(surfaces[3].subtitle,/tile 8/);
 assert.deepEqual(surfaces.map(item=>item.category),['roads','roads','ground','ground']);
 const withoutNative=createWalkMapSurfacePalette({topologyPaintAdapterAvailable:false});for(const materialId of ['asphalt','grass']){const item=withoutNative.find(value=>value.materialId===materialId);assert.equal(item.available,false);assert.match(item.reason,/topology paint adapter/i)}
});

test('exploration addition palette exposes exactly 7 trees, 4 monuments and 10 furniture kinds only with its adapter',()=>{
 const locked=createWalkMapExplorationAdditionPalette(),enabled=createWalkMapExplorationAdditionPalette({adapterAvailable:true});assert.equal(enabled.length,21);assert.equal(new Set(enabled.map(item=>item.explorationKind)).size,21);assert.deepEqual(Object.fromEntries(['nature','monuments','decor'].map(category=>[category,enabled.filter(item=>item.category===category).length])),{nature:7,monuments:4,decor:10});assert.ok(locked.every(item=>item.available===false));assert.ok(enabled.every(item=>item.available===true&&item.placementMode==='exploration'&&!item.binding));assert.equal(enabled.some(item=>/glb|custom/i.test(item.explorationKind)),false);
});
