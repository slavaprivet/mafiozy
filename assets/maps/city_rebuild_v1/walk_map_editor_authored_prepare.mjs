import {deriveMovedBuilding,DIRTY_BUILDING_DEPENDENCIES} from './walk_map_editor_building_derive.mjs';
import {makeWalkMapObjectDeleteCommand,makeWalkMapObjectTransformCommand} from './walk_map_editor_document.mjs';

function clone(value){return structuredClone(value);}
function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function stable(value){if(Array.isArray(value))return value.map(stable);if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value;}
function equal(a,b){return JSON.stringify(stable(a))===JSON.stringify(stable(b));}
function values(value){return typeof value==='function'?value():value;}
function unique(items){return [...new Set(items.filter(item=>typeof item==='string'&&item))];}

/**
 * Turns the authored adapter's visual transform preview into an authoritative
 * building command. Derived placement fields are rebuilt from the current
 * trusted record; callers must not commit the raw preview command directly.
 */
export function createWalkMapAuthoredCommandPreparer({
 resolveCurrentEntity,
 topology=null,
 otherInstances=[],
 parkingKeepouts=[],
 metresPerCell=4.1,
 allowSpecialFullRebuild=false,
 deriveBuilding=deriveMovedBuilding,
 prepareSpecialBuildingCommand=null,
 prepareOtherCommand=null
}={}){
 if(typeof resolveCurrentEntity!=='function')throw new Error('Authored command preparation requires a trusted current-entity resolver');
 if(typeof deriveBuilding!=='function')throw new Error('Authored command preparation requires a building derivation compiler');
 return async function prepareCommands(commands,{dependencies=[]}={}){
  if(!Array.isArray(commands)||!commands.length)throw new Error('Authored command preparation requires commands');
  const prepared=[],dirty=[...dependencies];
  for(const raw of commands){
   const patch=raw?.type==='object.set-patch'?raw.patch:null;
   if(patch?.source?.dataset==='buildings'){
    const current=await resolveCurrentEntity(clone(patch.source));
    if(!isObject(current)||!current.id||String(current.id)!==String(patch.source.id))throw new Error(`Trusted building is missing: ${patch.source.id}`);
    if(!equal(patch.before,current))throw new Error(`Stale authored building preview: ${patch.source.id}`);
    if(typeof prepareSpecialBuildingCommand==='function'){const special=await prepareSpecialBuildingCommand(clone(raw),{current:clone(current),dependencies:[...dependencies]});if(special){prepared.push(special.command||special);dirty.push(...(special.dependencies||[]));continue}}
    if(patch.action==='delete'){
     const deleteDependencies=unique([...(patch.metadata?.dependencies||[]),...DIRTY_BUILDING_DEPENDENCIES]);
     prepared.push(makeWalkMapObjectDeleteCommand({source:patch.source,before:current,metadata:{...clone(patch.metadata||{}),adapter:'authored-placement-derived-v1',dependencies:deleteDependencies}}));
     dirty.push(...deleteDependencies);continue;
    }
    if(patch.action!=='modify'||!patch.after?.transform)throw new Error('Authored building preparation only accepts transform modifications or deletion');
    const result=await deriveBuilding({trustedBase:current,nextTransform:patch.after.transform,topology:values(topology),otherInstances:values(otherInstances)||[],parkingKeepouts:values(parkingKeepouts)||[],metresPerCell,allowSpecialFullRebuild});
    if(!result?.ok)throw new Error(`${result?.code||'BUILDING_DERIVE_FAILED'}: ${result?.message||'Building derivation failed'}`);
    prepared.push(makeWalkMapObjectTransformCommand({source:patch.source,before:current,after:result.record,metadata:{...clone(patch.metadata||{}),adapter:'authored-placement-derived-v1',dependencies:unique([...(patch.metadata?.dependencies||[]),...(result.dirty||[])])}}));
    dirty.push(...(result.dirty||[]));continue;
   }
   if(typeof prepareOtherCommand!=='function')throw new Error(`No trusted preparer for editor command: ${raw?.type||'unknown'}`);
   const result=await prepareOtherCommand(clone(raw));if(!result)throw new Error('Trusted command preparation rejected an editor command');prepared.push(result.command||result);dirty.push(...(result.dependencies||[]));
  }
  return {commands:prepared,dependencies:unique(dirty)};
 };
}
