import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {glassRuntimeContract} from './runtime.v1.js';
const world=fs.readFileSync(new URL('../../../../world.html',import.meta.url),'utf8');
const renderer=fs.readFileSync(new URL('../../../../three_preview.js',import.meta.url),'utf8');
const fn=name=>{const s=world.indexOf(`function ${name}(`);assert(s>=0,name);let i=world.indexOf('{',s),depth=0;for(;i<world.length;i++){if(world[i]==='{')depth++;if(world[i]==='}'&&!--depth)return world.slice(s,i+1);}throw Error(name);};
// Compile every classic inline script: catches whole-host parse errors too.
for(const m of world.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/g))if(!/\btype\s*=/.test(m[1])&&m[2].trim())new vm.Script(m[2]);
const MAP=Array.from({length:200},(_,r)=>Array.from({length:180},(_,c)=>r%10<=3||c%10<=3?0:r%10===4||r%10===9||c%10===4||c%10===9?9:1));
const context=vm.createContext({MAP,MAP_ROWS:200,MAP_COLS:180,BLOCK:10,Map,Set,Math,Number,JSON,Object,
 document:{documentElement:{dataset:{}}},_LOCAL_PREVIEW:true,_UP:new URLSearchParams('preview=1&previewcityv3=stage-a&cityv3buildings=1'),
 _bankTileSet:new Set(),POI_BY_RC:new Map(),BUSINESS_BY_RC:new Map(),MAJOR_CASINO_WORLD_TILES:new Set(),
 NPC_EMPIRE_HQ_BLOCK_KEYS:new Set(['2,1','8,2','5,7','2,5','9,5','2,6','6,2','8,4','4,7','12,7','5,6','1,7','9,3','6,7','5,4','3,3','12,1','7,5','13,6']),
 DISTRICTS:[],DIST_ACTION_RAD:2.8,inRaceTrack:()=>false,_cityV3ActiveArtistInstances:new Map(),_businessExteriorCollisionCache:new Map(),
 _cityV3GlassActive:null,_cityV3ActiveAcceptedBuildings:new Map(),_cityV3ActiveCivicPreview:null,_cityV3DecorPreparedCells:new Set(),player:{r:49,c:66.9390243902439}});
const names=['_connectedBuildingParts','_cityV3RectContains','_cityV3RectsOverlap','_cityV3RectCellBounds','_cityV3BuildingPreviewGateRequested',
 '_cityV3AcceptedLegacyPart','_cityV3AcceptedGameplayAnchorConflict','_cityV3AcceptedOrdinaryRoadAt','_cityV3AcceptedPreflight','_cityV3AcceptedCorridorAt',
 '_cityV3AcceptedDoorApproachAt','_cityV3AcceptedInteractionFor3D','_cityV3UpdateBuildingDiagnostics','_cityV3GlassContract','_cityV3GlassDoorApproachAt','_cityV3GlassOwnsLegacyDoor','_cityV3GlassDoorDiagnostics','_cityV3GlassSurfaceAt','_cityV3GlassPreflight','_activateCityV3GlassBuilding','_rollbackCityV3GlassBuilding','_cityV3SuppressLegacyPart','_cityV3SuppressLegacyDoor'];
vm.runInContext(names.map(fn).join('\n')+'\nfunction isBlockedPed(r,c){const surface=_cityV3GlassSurfaceAt(r,c);return surface?surface.blocked:![0,7,8,9].includes(MAP[Math.floor(r)]?.[Math.floor(c)]);}',context);
const run=s=>vm.runInContext(s,context),contract=glassRuntimeContract();
// Exercise the real resident-door generator, not a fabricated wall coordinate.
Object.assign(context,{_residentBuildingDoorsCache:null,_residentDoorByBuildingTile:new Map(),_residentDoorBySource:new Map(),
  _npcBodyPassable:(r,c)=>[0,7,8,9].includes(MAP[Math.floor(r)]?.[Math.floor(c)]),npcPassable:(r,c)=>[0,7,8,9].includes(MAP[Math.floor(r)]?.[Math.floor(c)]),
  inArena:()=>false,inLair:()=>false,_prisonIslandCollisionAt:()=>null,window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}}});
vm.runInContext(fn('_residentBuildingDoors'),context);
const generatedDoor=run('_residentBuildingDoors().find(d=>d.id==="door_45_65_0")');
assert(generatedDoor,'Actual source generator must yield the owned generic door');
context.generatedDoor=generatedDoor;
console.log('Actual-source GALLERIA legacy door:',JSON.stringify(generatedDoor));
for(const k of ['key','instanceId','legacyStructureId','glbSha256','centerGridRC','uniformAssetScale','yawDeg','footprint','pad','door','service','dimensionsM','groundSizeXZ','collisionSourceAxes'])assert.equal(JSON.stringify(run('_cityV3GlassContract()')[k]),JSON.stringify(contract[k]),k);
run("_UP.set('cityv3glassrevision','original')");assert.equal(run('_cityV3GlassContract().glbSha256'),glassRuntimeContract('original').glbSha256);run("_UP.delete('cityv3glassrevision')");
context.receipt={...contract,assetSha256:contract.glbSha256,loaded:true,eligible:true,registered:true,visibleMeshCount:149,
 doorAnchorGridRC:[contract.door.anchorR,contract.door.anchorC],serviceAnchorGridRC:[contract.service.anchorR,contract.service.anchorC]};
assert.equal(run('_cityV3GlassSurfaceAt(47,67)'),null);
assert.equal(run('_cityV3GlassPreflight().part.tiles.length'),16);
let activation=run('_activateCityV3GlassBuilding(receipt)');assert.equal(activation.ok,true,activation.reason);context.token=activation.rollbackToken;
assert.equal(run('_cityV3SuppressLegacyDoor(generatedDoor)'),true);
run('_cityV3GlassDoorDiagnostics([generatedDoor],[generatedDoor].filter(d=>!_cityV3SuppressLegacyDoor(d)))');
assert.equal(JSON.parse(context.document.documentElement.dataset.cityV3GlassDoors).legacyVisibleCount,0);
assert.equal(run('isBlockedPed(47,67)'),true);
assert.equal(run('isBlockedPed(48.3,67)'),false); // old box apron now walkable.
assert.equal(run('isBlockedPed(receipt.door.anchorR,receipt.door.anchorC)'),false);
assert.equal(run('isBlockedPed(receipt.service.anchorR,receipt.service.anchorC)'),false);
assert.equal(run('_cityV3SuppressLegacyPart({minR:45,maxR:48,minC:65,maxC:68})'),true);
assert.equal(run('_cityV3SuppressLegacyPart({minR:45,maxR:48,minC:75,maxC:78})'),false);
assert.equal(run('_cityV3SuppressLegacyDoor({id:"door_45_65_0",buildingR:48,buildingC:68,wallR:48.5,wallC:69})'),true);
assert.equal(run('_cityV3SuppressLegacyDoor({id:"different-door",buildingR:48,buildingC:68,wallR:49,wallC:68.5})'),true);
assert.equal(run('_cityV3SuppressLegacyDoor({id:"neighbor",buildingR:48,buildingC:75,wallR:48.5,wallC:74.95})'),false);
assert.equal(run('_cityV3AcceptedInteractionFor3D().name'),'Стеклянный павильон');
run('player.c+=1.1');assert.equal(run('_cityV3AcceptedInteractionFor3D().name'),'Стеклянный павильон');run('player.c-=1.1');
assert.equal(run('_rollbackCityV3GlassBuilding({}).ok'),false);
assert.equal(run('_rollbackCityV3GlassBuilding(token).ok'),true);
assert.equal(run('isBlockedPed(48.3,67)'),true);
assert.equal(run('_cityV3SuppressLegacyPart({minR:45,maxR:48,minC:65,maxC:68})'),false);
run("POI_BY_RC.set('46,66',{})");assert.equal(run('_activateCityV3GlassBuilding(receipt).reason'),'legacy-ownership');run('POI_BY_RC.clear()');
run("NPC_EMPIRE_HQ_BLOCK_KEYS.add('4,6')");assert.equal(run('_activateCityV3GlassBuilding(receipt).reason'),'legacy-ownership');run("NPC_EMPIRE_HQ_BLOCK_KEYS.delete('4,6')");
run('MAP[49][67]=16');assert.match(run('_activateCityV3GlassBuilding(receipt).reason'),/water/);run('MAP[49][67]=9');
run("_businessExteriorCollisionCache.set('test',{center:{r:47,c:67},halfDepth:1,halfWidth:1})");assert.equal(run('_activateCityV3GlassBuilding(receipt).reason'),'business-exterior-overlap');run('_businessExteriorCollisionCache.clear()');
run('receipt.footprint.maxR+=.1');assert.equal(run('_activateCityV3GlassBuilding(receipt).reason'),'receipt-footprint');
assert(world.indexOf('let _cityV3GlassActive=null;')<world.indexOf('function buildMap()'));
assert(renderer.indexOf('cityV3GlassInstance=await Promise.race')<renderer.indexOf('const worldSnapshot=bridge?.getWorldSnapshot'));
assert(renderer.includes('glassTimeout=setTimeout')&&renderer.includes('},20000)')&&renderer.includes('cityV3GlassAbort.signal.aborted'));
console.log('PASS: host scripts compile; exact adapter/host contract; 16-tile fixture preflight; physical ground+door corridors; exact legacy suppression; GALLERIA interaction; rollback; POI/HQ/water/exterior/receipt rejection; early-state + pre-snapshot bounded load. Actual generated-map live gate remains required.');
