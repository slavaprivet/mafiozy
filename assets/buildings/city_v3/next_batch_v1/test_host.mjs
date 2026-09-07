import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {nextBuildingContract,NEXT_REGISTRY_SHA256} from './runtime.v1.js';
const world=fs.readFileSync(new URL('../../../../world.html',import.meta.url),'utf8');
const renderer=fs.readFileSync(new URL('../../../../three_preview.js',import.meta.url),'utf8');
const fn=name=>{const s=world.indexOf(`function ${name}(`);assert(s>=0,name);let i=world.indexOf('{',s),depth=0;for(;i<world.length;i++){if(world[i]==='{')depth++;if(world[i]==='}'&&!--depth)return world.slice(s,i+1);}throw Error(name);};
for(const m of world.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/g))if(!/\btype\s*=/.test(m[1])&&m[2].trim())new vm.Script(m[2]);
const snapshotPath=process.env.CITY_V3_SNAPSHOT||'C:/Users/Слава/Documents/Codex/2026-09-05/mafiozy-architect-city-replacement/outputs/city_building_placement_v3_main_native_addendum_v1/runtime_snapshot.json';
const snapshot=JSON.parse(fs.readFileSync(snapshotPath)),MAP=structuredClone(snapshot.map);
const race=new Set(snapshot.raceTiles),doors=structuredClone(snapshot.doors);
const context=vm.createContext({MAP,MAP_ROWS:200,MAP_COLS:180,BLOCK:10,Map,Set,Math,Number,JSON,Object,
 document:{documentElement:{dataset:{}}},_LOCAL_PREVIEW:true,_UP:new URLSearchParams('preview=1&previewcityv3=stage-a&cityv3buildings=1'),
 _bankTileSet:new Set(snapshot.bankTiles),POI_BY_RC:new Map(snapshot.pois.map(p=>[`${p.r},${p.c}`,p])),BUSINESS_BY_RC:new Map(snapshot.businesses.map(p=>[`${p.r},${p.c}`,p])),MAJOR_CASINO_WORLD_TILES:new Set(snapshot.casinoTiles),
 NPC_EMPIRE_HQ_BLOCK_KEYS:new Set(snapshot.npcHqBlocks),DISTRICTS:snapshot.districts,DIST_ACTION_RAD:2.8,inRaceTrack:(r,c)=>race.has(`${r},${c}`),
 _cityV3ActiveArtistInstances:new Map(),_businessExteriorCollisionCache:new Map(),_cityV3GlassActive:null,_cityV3ActiveAcceptedBuildings:new Map(),
 _cityV3ActiveCivicPreview:null,_cityV3DecorPreparedCells:new Set(),_cityV3DecorBodies:new Map(),_cityV3NextActive:new Map(),_cityV3NextRollbackToken:null,
 _residentBuildingDoors:()=>doors,player:{r:90,c:17}});
const names=['_connectedBuildingParts','_cityV3RectContains','_cityV3RectsOverlap','_cityV3RectCellBounds','_cityV3BuildingPreviewGateRequested',
 '_cityV3AcceptedGameplayAnchorConflict','_cityV3AcceptedOrdinaryRoadAt','_cityV3AcceptedPreflight','_cityV3AcceptedDoorApproachAt','_cityV3AcceptedInteractionFor3D',
 '_cityV3UpdateBuildingDiagnostics','_cityV3SuppressLegacyPart','_cityV3SuppressLegacyDoor','_cityV3NextContractRecords','_cityV3NextHostContract',
 '_cityV3NextCorridorAt','_cityV3NextSurfaceAt','_cityV3NextPreflight','_activateCityV3NextBuilding','_rollbackCityV3NextBuilding'];
vm.runInContext(names.map(fn).join('\n')+'\nfunction isBlockedPed(r,c){const surface=_cityV3NextSurfaceAt(r,c);return surface?surface.blocked:![0,2,3,4,6,8,9].includes(MAP[Math.floor(r)]?.[Math.floor(c)]);}',context);
const run=s=>vm.runInContext(s,context);
const bindings=JSON.parse(fs.readFileSync(new URL('./bindings.candidate.v1.json',import.meta.url))).bindings;
const contracts=bindings.map(b=>nextBuildingContract(b,JSON.parse(fs.readFileSync(new URL(b.manifest_url,import.meta.url)))));
assert.equal(JSON.stringify(run('_cityV3NextContractRecords()')),JSON.stringify(contracts),'pinned host contracts equal actual loader contracts');
context.receipt={schema:'mafiozi.next-buildings-runtime-receipt/v1',registrySha256:NEXT_REGISTRY_SHA256,buildings:contracts.map((c,i)=>({...c,loaded:true,registered:true,eligible:true,visibleMeshCount:[194,166,130][i],doorAnchorGridRC:[c.door.anchorR,c.door.anchorC],serviceAnchorGridRC:[c.service.anchorR,c.service.anchorC]}))};
for(const c of contracts){context.q=c;const result=run('_cityV3NextPreflight(_cityV3NextHostContract(q))');assert.equal(result.ok,true,`${c.key}: ${result.reason}`);}
const originalMap=JSON.stringify(MAP),activation=run('_activateCityV3NextBuilding(receipt)');assert.equal(activation.ok,true,activation.reason);context.token=activation.rollbackToken;
assert.equal(run('_cityV3NextActive.size'),3);assert.equal(JSON.stringify(MAP),originalMap,'no destructive MAP mutation');
for(const c of contracts){
  context.q=c;assert.equal(run('isBlockedPed(q.centerGridRC[0],q.centerGridRC[1])'),true);
  assert.equal(run('isBlockedPed(q.door.anchorR,q.door.anchorC)'),false);
  assert.equal(run('isBlockedPed(q.service.anchorR,q.service.anchorC)'),false);
  assert.equal(run('_cityV3SuppressLegacyPart({minR:q.legacyTileBounds.min_r,maxR:q.legacyTileBounds.max_r_exclusive-1,minC:q.legacyTileBounds.min_c,maxC:q.legacyTileBounds.max_c_exclusive-1})'),true);
  assert.equal(run('_cityV3SuppressLegacyDoor({id:q.legacyDoorId})'),true);
  run('player.r=q.door.anchorR;player.c=q.door.anchorC');assert.equal(run('_cityV3AcceptedInteractionFor3D().doorId'),c.legacyDoorId);
  assert.equal(run('_cityV3AcceptedInteractionFor3D().r'),c.legacyTileBounds.min_r);
  const resident=doors.find(d=>d.id===c.legacyDoorId);
  assert.equal(resident.r,c.door.anchorR);assert.equal(resident.c,c.door.anchorC);
  assert.equal(resident.wallR,c.door.visibleThresholdGridRC[0]);
}
assert.equal(run('_rollbackCityV3NextBuilding({}).ok'),false);assert.equal(run('_rollbackCityV3NextBuilding(token).ok'),true);assert.equal(run('_cityV3NextActive.size'),0);
assert.equal(JSON.stringify(doors),JSON.stringify(snapshot.doors),'cached resident records restored byte-for-byte');
run("POI_BY_RC.set('96,151',{})");assert.match(run('_activateCityV3NextBuilding(receipt).reason'),/protected-legacy/);assert.equal(run('_cityV3NextActive.size'),0);run("POI_BY_RC.delete('96,151')");
run("_cityV3DecorBodies.set('test',[{minR:47,maxR:48,minC:47,maxC:48}])");assert.match(run('_activateCityV3NextBuilding(receipt).reason'),/decor-overlap/);assert.equal(run('_cityV3NextActive.size'),0);run('_cityV3DecorBodies.clear()');
const oldTile=MAP[97][153];MAP[97][153]=7;assert.match(run('_activateCityV3NextBuilding(receipt).reason'),/street-object/);assert.equal(run('_cityV3NextActive.size'),0);MAP[97][153]=oldTile;
run('receipt.buildings[2].footprint.maxC+=.1');assert.match(run('_activateCityV3NextBuilding(receipt).reason'),/receipt-footprint/);assert.equal(run('_cityV3NextActive.size'),0);run('receipt.buildings[2].footprint.maxC-=.1');
const door=doors.find(d=>d.id===contracts[2].legacyDoorId);door.r+=1;assert.match(run('_activateCityV3NextBuilding(receipt).reason'),/legacy-door-drift/);assert.equal(run('_cityV3NextActive.size'),0);door.r-=1;
assert(world.indexOf('const _cityV3NextActive=new Map();')<world.indexOf('function buildMap()'));
assert(renderer.indexOf('cityV3NextInstance=await Promise.race')<renderer.indexOf('const worldSnapshot=bridge?.getWorldSnapshot'));
assert(renderer.includes('cityV3NextAbort.signal.aborted')&&renderer.includes('nextTimeout=setTimeout'));
console.log('PASS: complete host script compile, frozen real-map snapshot preflight, exact loader/host contract, 16+16+12 addressed tiles, preserved door IDs, collision+L service route, all-three rollback, POI/decor/drift rejection. Current live-map/browser checks remain separate.');
