// Exact source continuation only: caller must run named and traffic stages first.
// Importing this module does not run initialization or create source entities.
import fs from 'node:fs';
import path from 'node:path';
import {repo,hash,worldSHA,boundary} from './npc_startup_source_vm.mjs';

export function installPolicePetsAndRun(s){
 if(!s||typeof s.run!=='function'||typeof s.installFunction!=='function'||typeof s.installDeclaration!=='function')throw Error('Actual source VM required');
 if(s.worldSHA!==worldSHA||s.boundary?.phase!==boundary.phase)throw Error('Explicit offline source boundary required');
 if(!s.installed.has('_placeSaidInCity')||!s.installed.has('initCars'))throw Error('Named/traffic source prerequisites must precede police/pets');
 if(s.run('typeof CARS')==='undefined'||s.run('typeof ALL_UNIQUE_NPCS')==='undefined')throw Error('Missing complete named/traffic source state');
 if(!s.run('ALL_UNIQUE_NPCS.every(n=>NPCS.includes(n))')||s.rng().draw_count!==6431||s.rng().state!==2019678698)throw Error('Exact executed named/traffic continuation boundary required');
 if(s.installed.has('__police_pets_callback_executed'))throw Error('Police/pets stage already executed');
 const start=s.receipts.length;
 for(const name of ['CITY_COPS_TARGET','cityCops','_cityCopId','PRISON_STAFF_ROUTES','PRISON_STAFF_LOOKS','_prisonStaffRespawnAt','_prisonStaffEnsureAt','_prisonAlarmState','worldCops','PETS','PETS_TARGET','PETS_HARD_CAP','PETS_CAT_CAP','_petsInitialized','_petIdSeq','_petsLastIntegrityAt','SPAWN_R','player'])s.installDeclaration(name);
 // Direct source functions, including actual optional-branch targets. The
 // selected URL disables previewpetstress; no missing function suppresses it.
 for(const name of ['npcPassableForSnitch','_policeCrewPassable','_policeCrewBodyPassable','spawnCityCop','pickCityCopWaypoint','_createPrisonStaffCop','_ensurePrisonStaffCops','initCityCops','_spawnPet','_pickPetWaypoint','_normalizePetPopulation','initPets','_ensureSpawnSafe'])s.installFunction(name);
 const before={rng:s.rng(),player:s.run('JSON.parse(JSON.stringify(player))'),npc_count:s.run('NPCS.length'),car_count:s.run('CARS.length'),map_sha256:hash(s.run('JSON.stringify(MAP)')+'\n')};
 if(s.run('worldCops.length')!==0)throw Error('BEFORE_ANY_SERVER_SNAPSHOT source boundary violated');
 if(s.run('cityCops.length!==0||PETS.length!==0||_petsInitialized'))throw Error('Original uninitialized police/pets pools required');
 const calls=[];
 for(const name of ['initCityCops','initPets','_ensureSpawnSafe']){
  const rng_before=s.rng();
  s.run(name+'();','actual_deferred_callback:'+name);
  calls.push({name,rng_before,rng_after:s.rng()});
 }
 s.installed.add('__police_pets_callback_executed');
 const result={schema:'mafiozi.npc-startup-police-pets/v1',provenance:'EXECUTED_OFFLINE_ORIGINAL_SOURCE_EXPLICIT_BOUNDARY',source_world_sha256:worldSHA,boundary:s.boundary,before,calls,after:{rng:s.rng(),player:s.run('JSON.parse(JSON.stringify(player))'),npc_count:s.run('NPCS.length'),car_count:s.run('CARS.length'),map_sha256:hash(s.run('JSON.stringify(MAP)')+'\n')},patrol_attempts:s.run('CITY_COPS_TARGET'),cityCops:s.run('JSON.parse(JSON.stringify(cityCops))'),worldCops:s.run('JSON.parse(JSON.stringify(worldCops))'),pets:s.run('JSON.parse(JSON.stringify(PETS))'),prison_staff:s.run('JSON.parse(JSON.stringify(cityCops.filter(c=>c.kind==="prison_staff")))'),pet_attempts:s.run('PETS_TARGET'),source_receipts:s.receipts.slice(start),limits:['Offline source initialization; not browser first-registration or authenticated server snapshot','worldCops empty is actual source declaration under explicitly approved BEFORE_ANY_SERVER_SNAPSHOT boundary','Caller must execute exact named and traffic continuation with the same VM/RNG before this stage','No navigation resolver or native physical admission is installed here']};
 result.pool_object_aliases=s.run('(()=>{const ids=new Map(),refs=[];for(const [pool,rows]of [["NPCS",NPCS],["cityCops",cityCops],["worldCops",worldCops],["PETS",PETS]])rows.forEach((row,index)=>{if(!ids.has(row))ids.set(row,ids.size);refs.push({pool,index,object_ref:ids.get(row),id:row.id});});return refs;})()');
 const out=path.join(repo,'outputs/astra21_npc_startup_police_pets');fs.mkdirSync(out,{recursive:true});
 fs.writeFileSync(path.join(out,'POLICE_PETS_RESULT.json'),JSON.stringify(result,null,2)+'\n');
 fs.writeFileSync(path.join(out,'SOURCE_RECEIPTS.json'),JSON.stringify({world_sha256:worldSHA,receipts:result.source_receipts},null,2)+'\n');
 return result;
}
