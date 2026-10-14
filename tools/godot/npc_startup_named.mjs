// Exact named remainder for the authorized offline source VM. No VM is created on import.
import {html,hash,sourceFunction,sourceDeclaration} from './npc_startup_source_vm.mjs';

const registry=['SAID_NPC','UNIQUE_NPC_BLUEPRINTS','MAFIA_BOSS_NAMES','MAFIA_BOSS_GANGS','MAFIA_BOSS_VISUALS','NPC_EMPIRE_WEAPON_PROFILES','NPC_EMPIRE_DOCTRINES','SPECIALIST_NPCS','EMPIRE_CREW_NPCS','EMPIRE_HOLDING_GUARDS','ALL_UNIQUE_NPCS','UNIQUE_NPC_BY_ID'];
const definitions=['npcPassableForSnitch','_uniqueNpcCityPassable','_uniqueNpcSafeCityPoint','_placeUniqueNpcsInCity','_placeSaidInCity','pickNpcWaypoint','_npcBodyPassable','npcWaypointOk','_clearNpcRoute','_setNpcRoute','_npcFinishRouteWork','_npcReserveRouteWork','_npcRouteWorkExpired','_npcLifeEligible','_npcRoutineFor','_isRespawnableResident','_civilianPlanEligible','_civilianPlanNext','_maybePlanResidentBuildingVisit','_residentCanVisitBuilding'];
const routeState=['_npcRouteWorkFrame','_npcRouteWorkUsedMs','_npcRouteWorkQueue','_npcRouteWorkBatchCount','_npcRouteWorkStats'];

export function installNamedAndRun(s){
 if(!s||typeof s.run!=='function'||!(s.installed instanceof Set)||typeof s.installReceipt!=='function')throw Error('Actual source VM API required');
 if(s.run('typeof _walkNpcNavigationResolver')==='function')throw Error('Named startup must precede native resolver');
 if(s.rng().draw_count!==6356||s.rng().state!==2091196195)throw Error('Named continuation must begin at exact ordinary RNG boundary');
 if(hash(s.run('JSON.stringify(NPCS)')+'\n')!==hash(s.ordinary))throw Error('Ordinary source rows changed before named continuation');
 for(const name of ['_npcPlanRoadExit','_npcAgendaPick'])if(s.run('typeof '+name)!=='function')throw Error('Actual classic dependency missing: '+name);
 const override='for(const def of UNIQUE_NPC_BLUEPRINTS)def.name=MAFIA_BOSS_NAMES[def.id]||def.name;';
 const start=html.indexOf(override);if(start<0)throw Error('Original named override missing');
 const units=[...registry.map(sourceDeclaration),...routeState.map(sourceDeclaration),...definitions.map(sourceFunction),{name:'actual_named_name_override',start,end:start+override.length,line:html.slice(0,start).split('\n').length,code:override,sha256:hash(override)}].sort((a,b)=>a.start-b.start);
 for(const unit of units)s.installReceipt(unit);
 const queryCode='const __startupNamedQueries=__namedLedgerArray;const __startupNamedCityPassable=_uniqueNpcCityPassable;_uniqueNpcCityPassable=function(r,c){const result=__startupNamedCityPassable(r,c);__startupNamedQueries.push(["_uniqueNpcCityPassable",r,c,result]);return result;};const __startupNamedWaypoint=npcWaypointOk;npcWaypointOk=function(n,r,c){const result=__startupNamedWaypoint(n,r,c);__startupNamedQueries.push(["npcWaypointOk",n.id,r,c,result]);return result;};';
 s.namedQueries=[];s.context.__namedLedgerArray=s.namedQueries;
 s.run(queryCode,'observational named query ledger');
 (s.instrumentationReceipts??=[]).push({name:'named_observational_query_instrumentation',label:'observational_named_query_ledger',code:queryCode,sha256:hash(queryCode),provenance:'CALL_THROUGH_OBSERVATION_NOT_SOURCE_FUNCTION_BYTES',source_policy_modified:false,policy:'Call original source functions unchanged; observe function/entity/point/result only'});
 const before={rng:s.rng(),receipt_count:s.receipts.length,queries:s.queries.length,birth_calls:s.birthCalls.length};
 s.run('_placeSaidInCity();','actual named remainder');
 const alias=s.run('ALL_UNIQUE_NPCS.every(n=>NPCS.includes(n)&&UNIQUE_NPC_BY_ID.get(String(n.id))===n)&&ALL_UNIQUE_NPCS[0]===SAID_NPC&&SPECIALIST_NPCS.every((n,i)=>ALL_UNIQUE_NPCS[i+1]===n)');
 if(!alias)throw Error('Original named object aliases not preserved');
 const result={schema:'mafiozi.source-named-startup-stage/v1',phase:'AFTER_NAMED_BEFORE_INITCARS_BEFORE_NATIVE_RESOLVER',source_world_sha256:s.worldSHA,before,after:{rng:s.rng(),receipt_count:s.receipts.length,queries:s.queries.length,birth_calls:s.birthCalls.length},named_query_count:s.run('__startupNamedQueries.length'),named_query_sha256:hash(s.run('JSON.stringify(__startupNamedQueries)')+'\n'),query_instrumentation_sha256:hash(queryCode),named_count:s.run('ALL_UNIQUE_NPCS.length'),npc_count:s.run('NPCS.length'),source_object_aliases_verified:true,named_rows:JSON.parse(s.run('JSON.stringify(ALL_UNIQUE_NPCS)')),all_npcs_sha256:hash(s.run('JSON.stringify(NPCS)')+'\n'),source_receipts:units.map(({code,...r})=>r),limits:['Only exact named remainder; cars/cops/pets/player startup not executed by this stage','Explicit offline source boundary, not actual browser/native/server admission','Observational query wrappers invoke original functions unchanged; ledger is not a native physical query']};
 if(hash(s.run('JSON.stringify(NPCS.slice(0,288))')+'\n')!==hash(s.ordinary))throw Error('Named remainder changed ordinary rows');
 return result;
}
