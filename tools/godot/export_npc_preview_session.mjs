#!/usr/bin/env node
// Exact source-factory dependency checkpoint. Birth export fails closed until
// an independently admitted initialized source world/provider snapshot exists.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(repo,'outputs/astra21_npc_preview_session');
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const filename=path.join(repo,'world.html'),bytes=fs.readFileSync(filename),html=bytes.toString('utf8');
function sourceFunction(name){
 const start=html.indexOf('function '+name+'(');
 if(start<0)throw Error('Actual source function missing '+name);
 const brace=html.indexOf('{',start);let depth=0,state='code',end=-1;
 for(let i=brace;i<html.length;i++){
  const c=html[i],next=html[i+1];
  if(state==='line'){if(c==='\n')state='code';continue;}
  if(state==='block'){if(c==='*'&&next==='/'){state='code';i++;}continue;}
  if(state!=='code'){if(c==='\\'){i++;continue;}if(c===state)state='code';continue;}
  if(c==='/'&&next==='/'){state='line';i++;continue;}
  if(c==='/'&&next==='*'){state='block';i++;continue;}
  if(c==='"'||c==="'"||c==='`'){state=c;continue;}
  if(c==='{')depth++;
  if(c==='}'&&--depth===0){end=i+1;break;}
 }
 if(end<0)throw Error('Actual function boundary not found '+name);
 const code=html.slice(start,end);new vm.Script(code,{filename:'world.html:'+name});
 return {name,line:html.slice(0,start).split('\n').length,byte_length:Buffer.byteLength(code),sha256:sha(code),code};
}
const functions=['spawnNpc','_npcBodyPassable','npcPassable','_npcNavigationAt','_npcRouteWalkBlocked','inArena','inLair','_pickArchetype','_initNpcEmotions','getGameHour','_threeNpcEntityId','initNpcs','buildMap','isBlockedPed','isBlocked','_inPrisonIslandRestrictedZone','_inPitCorridor'].map(sourceFunction);
const sourceFiles=['assets/maps/city_rebuild_v1/npc_city_population_source.js','assets/maps/city_rebuild_v1/npc_native_navigation.mjs','assets/maps/city_rebuild_v1/npc_swept_footprint.mjs','assets/maps/city_rebuild_v1/npc_population.mjs','assets/maps/city_rebuild_v1/npc_appearance.mjs','assets/maps/city_rebuild_v1/npc_role_catalogue.mjs','assets/maps/city_rebuild_v1/npc_boss_art_direction.mjs','assets/maps/city_rebuild_v1/walk_preview.mjs'];
const sources=[{path:'world.html',bytes:bytes.length,sha256:sha(bytes)},...sourceFiles.map(p=>{const b=fs.readFileSync(path.join(repo,p));return {path:p,bytes:b.length,sha256:sha(b)}})];
const datasets=['topology_for_placement.json','buildings_placement.v1.json','decor_placement.v1.json'].map(name=>{const p='assets/maps/city_rebuild_v1/'+name,b=fs.readFileSync(path.join(repo,p)),j=JSON.parse(b);return {path:p,bytes:b.length,sha256:sha(b),status:j.status,pendingHostSnapshot:j.pendingHostSnapshot,map:j.map??null,actual_initialized_provider_state_present:false}});
const blockPath='godot/mafiozi_walk/data/block.json',blockBytes=fs.readFileSync(path.join(repo,blockPath)),block=JSON.parse(blockBytes);
const audit={schema:'mafiozi.npc-preview-session-source-audit/v1',status:'HOLD_SOURCE_WORLD_PROVIDER_SNAPSHOT_REQUIRED',mode:'NEW_SESSION_BOOTSTRAP',source_births_created:0,imported_existing_births_created:0,sources,datasets,block:{path:blockPath,sha256:sha(blockBytes),origin_m:block.originM,metres_per_cell:block.metresPerCell,buildings:block.buildings.length},functions:functions.map(({code,...receipt})=>receipt),factory:{native_initial_count:288,legacy_initial_count:96,serial_initial:0,ordinary_stage:'initNpcs ordinary loop before _placeSaidInCity',body_radius_source_cells:0.18,body_offsets:[[0,0],[-0.18,-0.18],[-0.18,0.18],[0.18,-0.18],[0.18,0.18]],candidate_map_tiles:[8,9,14],raw_identity:'resident_${++_residentSerial}',bridge_identity:'actual _threeNpcEntityId(rawRow), npc_ + unchanged raw id',crop:'AFTER complete ordinary source generation, never reroll/move/reseed to force a quarter spawn'},missing_fields:['Initialized source MAP, dimensions and source frame/clock/readiness','Actual npcPassable provider outputs for all factory queried center/corner positions, or complete source providers/state','Native collisionIndex polygons with min/maxY, support floor, water level/depth and terrainAllows','Dynamic railway/fleet/logical vehicle blocker states','Enabled prison/civic/accepted/next replacement/decor/rail/business collision registries','Explicit deterministic new-session RNG algorithm/seed, sessionID/generation/source clock/game minutes'],limits:['Candidate pendingHostSnapshot datasets do not authenticate initialized source world state','No missing provider is replaced by empty solids/always-passable callback/walkableMask','No actual new source resident created in this checkpoint','Not existing authenticated session, old-save or server roster capture']};
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'SOURCE_FACTORY_DEPENDENCIES.json'),JSON.stringify(audit,null,2)+'\n');
fs.writeFileSync(path.join(out,'SOURCE_FACTORY_SLICES.json'),JSON.stringify({schema:'mafiozi.npc-source-factory-slices/v1',world_sha256:sha(bytes),functions},null,2)+'\n');
const args=process.argv.slice(2);
if(args.includes('--audit')){console.log(JSON.stringify({status:audit.status,functions:functions.length,datasets:datasets.map(d=>({name:path.basename(d.path),pending:d.pendingHostSnapshot})),births:0,world_sha256:sha(bytes)}));process.exit(0);}
const configIndex=args.indexOf('--bootstrap');
if(configIndex<0||!args[configIndex+1])throw Error('Use --audit or --bootstrap explicit_config.json. No implicit seed/session/provider is admitted.');
const configPath=path.resolve(args[configIndex+1]),configBytes=fs.readFileSync(configPath),config=JSON.parse(configBytes);
if(config.schema!=='mafiozi.npc-preview-bootstrap-config/v1'||config.mode!=='NEW_SESSION_BOOTSTRAP'||config.phase!=='POST_BUILDMAP_BEFORE_NATIVE_RESOLVER')throw Error('Unsupported bootstrap provenance/phase');
if(config.startup_closure_revision!=='sync-business-cache-clock-garden-v2'||config.rng_boundary!=='BEFORE_ORDINARY_INIT_LOOP'||config.location_hostname!=='localhost')throw Error('HOLD_SOURCE_STARTUP_CLOSURE: corrected explicit closure revision, RNG boundary and source hostname required');
if(config.clock_override!=='INJECTED_NEW_SESSION_AFTER_SYNCHRONOUS_PREREQUISITES')throw Error('Explicit injected session clock provenance required');
if(typeof config.session_id!=='string'||!config.session_id||config.session_id.length>128)throw Error('Explicit session_id required');
if(config.rng?.algorithm!=='mulberry32/v1'||!Number.isInteger(config.rng.seed)||config.rng.seed<0||config.rng.seed>0xffffffff)throw Error('Explicit mulberry32/v1 uint32 seed required');
if(!Number.isFinite(config.clock?.source_now_ms)||config.clock.source_now_ms<0||!Number.isFinite(config.clock?.game_minutes)||config.clock.game_minutes<0||config.clock.game_minutes>=1440||config.clock.source_frame!==config.phase)throw Error('Explicit bounded source clock and matching source_frame required');
if(config.location_search!=='?render=3d&renderer=walk')throw Error('This source slice supports only explicit native fresh default registry phase');
const mapDir=path.join(repo,'outputs/coordinator21_npc_source_map'),mapManifest=JSON.parse(fs.readFileSync(path.join(mapDir,'manifest.json'))),mapBytes=fs.readFileSync(path.join(mapDir,'MAP.post_buildMap.json'));
if(config.world_html_sha256!==sha(bytes)||mapManifest.source.sha256!==sha(bytes)||config.map_sha256!==sha(mapBytes)||mapManifest.map_sha256!==sha(mapBytes))throw Error('Trusted source/MAP receipt mismatch');
const mapSlices=JSON.parse(fs.readFileSync(path.join(mapDir,'source_slices.json'))).slices;
for(const s of mapSlices)if(sha(s.code)!==s.sha256||html.slice(s.start,s.start+s.code.length)!==s.code)throw Error('Actual buildMap slice bytes changed: '+s.name);
// Select complete unchanged source declarations. No inert registry is fabricated:
// fresh defaults execute their actual declarations in the chosen source phase.
function statement(name){
 const hit=new RegExp('^(?:const|let) '+name+'\\b','m').exec(html);if(!hit)throw Error('Missing source declaration '+name);
 let depth=0,state='code',end=-1;
 for(let i=hit.index;i<html.length;i++){const c=html[i],n=html[i+1];
  if(state==='line'){if(c==='\n')state='code';continue;}if(state==='block'){if(c==='*'&&n==='/'){state='code';i++;}continue;}
  if(state!=='code'){if(c==='\\'){i++;continue;}if(c===state)state='code';continue;}
  if(c==='/'&&n==='/'){state='line';i++;continue;}if(c==='/'&&n==='*'){state='block';i++;continue;}if(c==='"'||c==="'"||c==='`'){state=c;continue;}
  if('([{'.includes(c))depth++;if(')]}'.includes(c))depth--;if(c===';'&&!depth){end=i+1;break;}
 }
 if(end<0)throw Error('Unclosed declaration '+name);const code=html.slice(hit.index,end);new vm.Script(code);
 return {name,kind:'declaration',line:html.slice(0,hit.index).split('\n').length,sha256:sha(code),code};
}
const declarations=['_UP','_LOCAL_PREVIEW','_cityV3GlassActive','_cityV3NextActive','_cityV3RailState','_cityV3DecorBodies','JAIL_ISLAND_3D_ENABLED','JAIL_ISLAND_LAYOUT','ARENA_POI','ARENA_R0','ARENA_C0','_LAIR_POI','_LAIR_R','_LAIR_C','_LAIR_RAD','NPCS','_residentSerial','_npcNavigationStats','_walkNpcNavigationResolver','RESIDENTS_INDOORS','TARGET_NPC_COUNT','_gameMinutes','NPC_ARCHETYPES','PASSABLE','_THREE_WHOLE_BUILDING_COLLISIONS','_threeBuildingBlockCache','_cityV3ActiveCivicPreview','_cityV3ActiveAcceptedBuildings','_businessExteriorCollisionCache','_businessExteriorPedCollisionEnabled','BUSINESS_POIS','BUSINESS_EXTERIOR_GEOMETRY_3D'].map(statement);
declarations.push(...['_walkTrafficNavigationResolver','_residentBuildingDoorsCache','_residentDoorByBuildingTile'].map(statement));
const neededFunctions=['_walkRendererActive','inArena','inLair','spawnNpc','_npcNavigationAt','_npcRouteWalkBlocked','npcPassable','_npcBodyPassable','_inPrisonIslandRestrictedZone','_pickArchetype','_initNpcEmotions','getGameHour','_threeNpcEntityId','_isPortContainerSolid','_connectedBuildingParts','_isThreeWholeBuildingBlocked','isBlocked','isBlockedPed','_openCityBridgeSurface','_isRaceWaterEdgeBlockedForPed','_businessExteriorPedBlocked','_businessExteriorDoorCorridorAt','_prisonIslandCollisionAt','_cityV3CivicSurfaceAt','_cityV3AcceptedSurfaceAt','_cityV3NextSurfaceAt','_cityV3GlassSurfaceAt','_cityV3DecorBlocked','_cityV3RailBlocksPed','_cityV3RailTrainBodyContains','_walkableEstablishmentAnchor','_cacheBusinessExteriorCollisions','_cityV3DecorGate','_prepareCityV3DecorGardens'].map(sourceFunction);
neededFunctions.push(sourceFunction('_residentBuildingDoors'));
const portStart=html.indexOf('const PORT_CONTAINER_PRESETS ='),portEnd=html.indexOf('function _isPortContainerSolid(',portStart),portCode=html.slice(portStart,portEnd);new vm.Script(portCode);
const populationPath=path.join(repo,'assets/maps/city_rebuild_v1/npc_city_population_source.js'),populationBytes=fs.readFileSync(populationPath),targetCode=populationBytes.toString('utf8').match(/^const NPC_NATIVE_CITY_TARGET=[^;]+;/m)?.[0];if(!targetCode)throw Error('Actual source population target missing');
const init=sourceFunction('initNpcs'),ordinaryStart=init.code.indexOf('  NPCS.length = 0;'),ordinaryEnd=init.code.indexOf('  _placeSaidInCity();');if(ordinaryStart<0||ordinaryEnd<0)throw Error('Actual ordinary init loop boundary changed');
const ordinaryCode=init.code.slice(ordinaryStart,ordinaryEnd);new vm.Script(ordinaryCode);
const configStart=html.indexOf('window.MAFIOZI_RENDERER_CONFIG = Object.freeze({'),configEnd=html.indexOf('});',configStart)+3;if(configStart<0||configEnd<3)throw Error('Actual renderer config statement missing');
const rendererConfigCode=html.slice(configStart,configEnd),clockTickCode='  _gameMinutes = (_gameMinutes + 1) % 1440;';if(!html.includes(clockTickCode))throw Error('Actual synchronous clock tick expression changed');
const doorInitCode='_residentBuildingDoorsCache=null;\r\n_residentBuildingDoors();';if(!html.includes(doorInitCode))throw Error('Actual synchronous resident door initializer statement changed');
new vm.Script(rendererConfigCode);new vm.Script(clockTickCode);
const extraSlices=[...declarations,...neededFunctions,...['_cacheBusinessExteriorCollisions();','_prepareCityV3DecorGardens();'].map(code=>{if(!html.includes(code))throw Error('Actual source call missing');return {name:'actual_call_'+code,sha256:sha(code),code};}),{name:'actual_resident_doors_initializer',sha256:sha(doorInitCode),code:doorInitCode},{name:'actual_port_container_layout',sha256:sha(portCode),code:portCode},{name:'actual_native_population_target',sha256:sha(targetCode),code:targetCode},{name:'actual_renderer_config_assignment',sha256:sha(rendererConfigCode),code:rendererConfigCode},{name:'actual_synchronous_clock_tick_expression',sha256:sha(clockTickCode),code:clockTickCode},{name:'actual_ordinary_init_loop',sha256:sha(ordinaryCode),code:ordinaryCode}];
function execute(){
 let rngState=config.rng.seed>>>0;const draws=[],birthCalls=[],queryLedger=[];
 const random=()=>{rngState=(rngState+0x6d2b79f5)>>>0;let t=rngState;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);const value=((t^(t>>>14))>>>0)/4294967296;draws.push(value);return value;};
 const sourceMath=Object.create(Math);sourceMath.random=random;
 const dataset=new Proxy({}, {set(){return true;},get(){throw Error('Unexpected DOM read in exact source slice');}});
 const sourceWindow={};const context=vm.createContext({Math:sourceMath,URLSearchParams,location:{search:config.location_search,hostname:config.location_hostname},window:sourceWindow,document:{documentElement:{dataset}},performance:{now:()=>config.clock.source_now_ms},__birthCalls:birthCalls,__queryLedger:queryLedger});
 vm.runInContext(mapSlices.map(s=>s.code).join('\n'),context,{timeout:5000});vm.runInContext('buildMap()',context,{timeout:5000});
 const reproduced=vm.runInContext('JSON.stringify(MAP)',context)+'\n';if(sha(reproduced)!==sha(mapBytes))throw Error('Actual MAP replay differs');
 vm.runInContext(extraSlices.filter(s=>!s.name.startsWith('actual_call_')&&!['actual_resident_doors_initializer','actual_ordinary_init_loop','actual_renderer_config_assignment','actual_synchronous_clock_tick_expression'].includes(s.name)).map(s=>s.code).join('\n'),context,{timeout:5000});
 if(Object.hasOwn(sourceWindow,'MAFIOZI_RENDERER_CONFIG'))throw Error('Pristine source cache must precede renderer config assignment');
 vm.runInContext(clockTickCode,context);const startup_game_minutes=vm.runInContext('_gameMinutes',context);
 vm.runInContext('_cacheBusinessExteriorCollisions();',context,{timeout:5000});
 const business_cache=JSON.parse(vm.runInContext('JSON.stringify([..._businessExteriorCollisionCache.values()])',context));
 if(!vm.runInContext('_businessExteriorPedCollisionEnabled',context)||business_cache.length!==10)throw Error('Actual synchronous business cache initialization missing');
 const collision_cache_before_doors=vm.runInContext('JSON.stringify([..._threeBuildingBlockCache])',context);
 vm.runInContext(doorInitCode,context);
 if(vm.runInContext('_residentBuildingDoorsCache',context)!==null||vm.runInContext('_residentDoorBySource.size',context)!==0||vm.runInContext('JSON.stringify([..._threeBuildingBlockCache])',context)!==collision_cache_before_doors)throw Error('Source native null-traffic door initializer must return [] before cache writes');
 vm.runInContext(rendererConfigCode,context);vm.runInContext('_prepareCityV3DecorGardens();',context);
 if(vm.runInContext('_cityV3DecorGate()',context)!==false||sha(vm.runInContext('JSON.stringify(MAP)',context)+'\n')!==sha(mapBytes))throw Error('Actual selected source garden phase must remain gated without MAP edits');
 if(draws.length!==0)throw Error('Prerequisite source closure unexpectedly consumed factory RNG seed');
 vm.runInContext('_gameMinutes='+JSON.stringify(config.clock.game_minutes),context);
 // Call-through instrumentation leaves source function bytes and decisions intact.
 vm.runInContext('const __sourcePassable=npcPassable; npcPassable=function(r,c){const result=__sourcePassable(r,c);__queryLedger.push([r,c,result]);return result;}; const __sourceSpawn=spawnNpc; spawnNpc=function(seed,opts){const row=__sourceSpawn(seed,opts);__birthCalls.push({seed,id:row?.id??null});return row;};',context);
 vm.runInContext(ordinaryCode,context,{timeout:10000});
 const result=JSON.parse(vm.runInContext('JSON.stringify({rows:NPCS,serial:_residentSerial,navigation_stats:_npcNavigationStats,native:_walkRendererActive(),registry_defaults:{next:_cityV3NextActive.size,accepted:_cityV3ActiveAcceptedBuildings.size,civic:_cityV3ActiveCivicPreview,glass:_cityV3GlassActive,rail:_cityV3RailState,decor:_cityV3DecorBodies.size,business_enabled:_businessExteriorPedCollisionEnabled,navigation:_walkNpcNavigationResolver,water:_walkNpcWaterResolver}})',context));
 if(!result.native||birthCalls.length!==288||draws.length===0||result.rows.some(r=>!r._npcInitialPlacementPending))throw Error('Source ordinary native invariant failed');
 return {...result,startup_game_minutes,injected_game_minutes:config.clock.game_minutes,business_cache,resident_doors_native_null_traffic_early_return:true,garden_gate:false,draws,birthCalls,queryLedger};
}
const first=execute(),second=execute();if(JSON.stringify(first)!==JSON.stringify(second))throw Error('Exact seeded source repetition differs');
if(sha(fs.readFileSync(filename))!==sha(bytes))throw Error('Source changed during bootstrap');
const rosterBytes=Buffer.from(JSON.stringify(first.rows)+'\n'),ledgerBytes=Buffer.from(JSON.stringify({rng_draws:first.draws,birth_calls:first.birthCalls,npc_passable_calls:first.queryLedger})+'\n');
const runDir=path.join(out,sha(configBytes));fs.mkdirSync(runDir,{recursive:true});
fs.writeFileSync(path.join(runDir,'full_roster.json'),rosterBytes);fs.writeFileSync(path.join(runDir,'source_execution_ledger.json'),ledgerBytes);fs.writeFileSync(path.join(runDir,'factory_slices.json'),JSON.stringify({world_sha256:sha(bytes),slices:extraSlices},null,2)+'\n');
const prerequisiteBytes=Buffer.from(JSON.stringify({schema:'mafiozi.npc-source-synchronous-prerequisites/v1',closure_revision:config.startup_closure_revision,location:{hostname:config.location_hostname,search:config.location_search},business_cache:first.business_cache,business_enabled:first.registry_defaults.business_enabled,resident_doors_native_null_traffic_early_return:first.resident_doors_native_null_traffic_early_return,renderer_config_order:'SOURCE_CACHE_UNDEFINED_CONFIG_FALLBACK4.1_THEN_SOURCE_ASSIGNMENT4.1',garden_gate:first.garden_gate,map_after_prerequisites_sha256:sha(mapBytes),startup_clock_minutes:first.startup_game_minutes,session_injected_game_minutes:first.injected_game_minutes,clock_override:config.clock_override,rng_boundary:config.rng_boundary,rng_prerequisite_draws:0},null,2)+'\n');
fs.writeFileSync(path.join(runDir,'synchronous_prerequisites.json'),prerequisiteBytes);
const crop=block.surface,quarter=first.rows.filter(r=>r.r>=crop.startRow&&r.r<crop.startRow+crop.rows&&r.c>=crop.startCol&&r.c<crop.startCol+crop.cols);
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c);}});
const {npcAppearanceFromWorld}=await import(pathToFileURL(path.join(repo,'assets/maps/city_rebuild_v1/npc_population.mjs')));
const bridgeIdContext=vm.createContext();vm.runInContext(sourceFunction('_threeNpcEntityId').code,bridgeIdContext);
const rows=quarter.map(raw=>{
 bridgeIdContext.__raw=raw;const bridge_id=vm.runInContext('_threeNpcEntityId(__raw)',bridgeIdContext);
 // Exact appearance-relevant expressions of fresh source bridge world.html:71568–71600.
 // This projection makes no offline full combat snapshot/AI execution claim.
 const role=String(raw._ambientTrafficRole||raw.role||raw.type||raw._arcKey||'civilian'),roleKey=role.toLowerCase();
 const gang=!!(raw.gang||raw._gang||raw.gangId||raw.gang_id||roleKey.includes('gang')||roleKey.includes('boss')||roleKey.includes('district_')||roleKey.includes('occupier'));
 const police=!!(raw.police||roleKey==='police'||roleKey==='cop'||roleKey.includes('police'));
 const bridge_row={id:bridge_id,r:raw.r,c:raw.c,role,look:raw.look||null,empireBoss:!!raw._empireBoss,bossColor:String(raw._empireColor||raw.look?.suit||''),bossAccent:String(raw._empireAccent||raw.look?.accent||''),police,visualRole:gang?'gang':police?'police':roleKey.includes('guard')?'guard':'civilian',prisonGear:raw.prisonGear||'',shield:!!raw.shield};
 const descriptor=npcAppearanceFromWorld(bridge_row),descriptor_json=JSON.stringify(descriptor);
 return {source_id:raw.id,bridge_id,source_raw:raw,bridge_row,descriptor_json,descriptor_sha256:sha(descriptor_json),placement:{pending:true,body_clear:false,support_known:false,source_body_clear:true}};
});
const queryBytes=Buffer.from(JSON.stringify(first.queryLedger)+'\n');fs.writeFileSync(path.join(runDir,'source_query_oracle.json'),queryBytes);
const packet={schema:'mafiozi.npc-preview-session/v1',mode:config.mode,session_id:config.session_id,rng:{...config.rng,draw_count:first.draws.length,boundary:config.rng_boundary},clock:config.clock,world:{map_rows:200,map_cols:180,map_sha256:sha(mapBytes),query_oracle_sha256:sha(queryBytes),provider_ready:false},bootstrap:{scope:'ordinary_native_init_loop',fresh_serial_start:0,init_attempts:288,factory_birth_count:first.rows.length,failed_attempts:first.birthCalls.filter(c=>c.id===null).length,resident_serial:first.serial,placement_cutoff:'BEFORE_NATIVE_RESOLVER'},coordinates:{origin:block.originM,scale:4.1,crop:{r_min:crop.startRow,r_max:crop.startRow+crop.rows,c_min:crop.startCol,c_max:crop.startCol+crop.cols,bounds:'half_open'}},full_roster_sha256:sha(rosterBytes),full_roster_count:first.rows.length,source_receipts:[...sources,{path:blockPath,sha256:sha(blockBytes)},{path:'outputs/coordinator21_npc_source_map/MAP.post_buildMap.json',sha256:sha(mapBytes)},{path:path.relative(repo,configPath).replaceAll('\\','/'),sha256:sha(configBytes)},{path:path.relative(repo,path.join(runDir,'synchronous_prerequisites.json')).replaceAll('\\','/'),sha256:sha(prerequisiteBytes)}],provenance:{kind:'NEW_SESSION_BOOTSTRAP',phase:config.phase,closure_revision:config.startup_closure_revision,location_search:config.location_search,location_hostname:config.location_hostname,clock_override:config.clock_override,startup_clock_game_minutes:first.startup_game_minutes,synchronous_prerequisites_sha256:sha(prerequisiteBytes),authority:'offline_new_source_session_only',full_page_rng_stream_reproduced:false,full_combat_snapshot_executed:false,existing_session_authenticated:false},rows,limits:['Fresh ordinary source factory; not an existing source session or old save','All rows hidden/pending until real native placement resolves body and support','No native_position/support_y inferred from source tile/map','Crop performed after complete source generation','Material/degenerate fidelity HOLD for downstream visual assets']};
const packetBytes=Buffer.from(JSON.stringify(packet,null,2)+'\n');fs.writeFileSync(path.join(runDir,'session_packet.json'),packetBytes);
const sessionAssets=path.join(repo,'assets/npc_visual/session');fs.mkdirSync(sessionAssets,{recursive:true});fs.writeFileSync(path.join(sessionAssets,sha(packetBytes)+'.json'),packetBytes);
const canonical={male:'8130dfb1f7eb91bff31e932feef1717672070a6767ccc726d7cb1ee23133fd00',female:'298d50e6244a7f17cf9cb66530fc34645fec0f19b575fe99d1df514709e90c40'};
const visualInput={schema:'mafiozi.npc-visual-source/v1',source_module_sha256:sha(fs.readFileSync(path.join(repo,'assets/maps/city_rebuild_v1/npc_population.mjs'))),appearance_module_sha256:sha(fs.readFileSync(path.join(repo,'assets/maps/city_rebuild_v1/npc_appearance.mjs'))),entries:rows.map(r=>({bridge_id:r.bridge_id,kind:'captured_appearance',fixture:false,provenance:{label:'NEW_SESSION_BOOTSTRAP:'+config.session_id+':'+sha(packetBytes),test_only:false},canonical_source_sha256:canonical[JSON.parse(r.descriptor_json).sex],source_row:r.bridge_row,descriptor_json:r.descriptor_json,descriptor_sha256:r.descriptor_sha256}))};
fs.writeFileSync(path.join(runDir,'visual_source_input.json'),JSON.stringify(visualInput,null,2)+'\n');
fs.writeFileSync(path.join(runDir,'BOOTSTRAP_RESULT.json'),JSON.stringify({schema:'mafiozi.npc-source-bootstrap-result/v1',status:'PENDING_BEFORE_NATIVE_RESOLVER',session_id:config.session_id,config_sha256:sha(configBytes),source_sha256:sha(bytes),map_sha256:sha(mapBytes),full_roster_sha256:sha(rosterBytes),full_roster_count:first.rows.length,resident_serial:first.serial,init_attempts:first.birthCalls.length,failed_attempts:first.birthCalls.filter(c=>c.id===null).length,rng:{...config.rng,draw_count:first.draws.length},execution_ledger_sha256:sha(ledgerBytes),npc_passable_calls:first.queryLedger.length,registry_defaults:first.registry_defaults,quarter_count:quarter.length,quarter_source_rows:quarter,limits:['Actual fresh source ordinary init loop; not existing-session authentication','Source null-resolver fallback decisions retained; all births pending','No native physical placement or guessed support Y','No imported-existing births']},null,2)+'\n');
console.log(JSON.stringify({status:'PENDING_BEFORE_NATIVE_RESOLVER',output:runDir,births:first.rows.length,quarter:quarter.length,draw_count:first.draws.length,full_roster_sha256:sha(rosterBytes),packet_sha256:sha(packetBytes),bridge_ids:rows.map(r=>r.bridge_id)}));
