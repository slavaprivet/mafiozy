import {walkMapEditorEntityKey,makeWalkMapObjectTransformCommand,makeWalkMapObjectDeleteCommand} from './walk_map_editor_document.mjs';

const LABELS=Object.freeze({
 civic_hall:'Общественный зал',hospital:'Больница',nightclub:'Ночной клуб',police_station:'Районный изолятор',
 old_town_narrow_townhouse_v1:'Узкий городской дом',eastside_garden_walkup_v1:'Дом с садом',eastside_stepped_apartment_v1:'Ступенчатый многоквартирный дом',
 coastal_orchard_house_v1:'Прибрежный дом с садом',garden_lane_house_v1:'Дом на Садовой улице',hillstep_chalet_v1:'Шале на склоне',
 pine_ridge_cottage_v1:'Сосновый коттедж',veranda_bungalow_v1:'Бунгало с верандой',woodland_crosswing_house_v1:'Лесной дом с поперечным крылом',
 compact_podium_glass_tower_v1:'Стеклянная башня на подиуме',pawnshop:'Ломбард',print_shop:'Типография',gun_shop:'Оружейный магазин',
 bookmaker:'Букмекерская',strip_club:'Стрип-клуб',glass_pavilion_small_v1:'Малый стеклянный павильон',
 bank_large_shell_v1:'Большой банк',bank_medium_shell_v1:'Средний банк',bank_small_shell_v1:'Малый банк',
 bench_civic:'Городская скамья',fountain_central:'Центральный фонтан',fountain_district:'Районный фонтан',fountain_park:'Парковый фонтан',
 planter_round:'Круглая клумба',bin_civic:'Городская урна',lamp_pine_v1:'Сосновый фонарь',lamp_bellini_v1:'Фонарь Беллини',
 lamp_civic_double_v1:'Двойной городской фонарь',lamp_foundry_v1:'Промышленный фонарь'
});

const LOCKED_ASSETS=new Set(['civic_hall','hospital','police_station','bank_large_shell_v1','bank_medium_shell_v1','bank_small_shell_v1']);
const LAMP=/^lamp_/;
const BANK=/^bank_/;

function clone(value){return structuredClone(value);}
function recordTransform(record,metresPerCell){const transform=record.transform||{};return {positionM:[...(transform.positionM||[record.c*metresPerCell,0,record.r*metresPerCell])],yawDegrees:transform.yawDegrees||0,uniformScale:transform.uniformScale??1,horizontalScale:[...(transform.horizontalScale||[1,1])],modelLocalOffsetM:[...(transform.modelLocalOffsetM||[0,0,0])],preserveSiteBounds:transform.preserveSiteBounds===true};}
function applyGroupTransform(group,transform){group.position?.fromArray?.(transform.positionM);if(group.position&&!group.position.fromArray){group.position.x=transform.positionM[0];group.position.y=transform.positionM[1];group.position.z=transform.positionM[2]}if(group.rotation)group.rotation.y=transform.yawDegrees*Math.PI/180;const horizontal=transform.horizontalScale||[1,1],x=transform.uniformScale*(horizontal[0]??1),y=transform.uniformScale,z=transform.uniformScale*(horizontal[1]??1);if(group.scale?.set)group.scale.set(x,y,z);else if(group.scale){group.scale.x=x;group.scale.y=y;group.scale.z=z}if(group.updateWorldMatrix)group.updateWorldMatrix(true,false);else group.updateMatrixWorld?.(true);}
function categoryFor(record,isBuilding){if(isBuilding)return 'buildings';if(LAMP.test(record.assetId||''))return 'lights';if(/^fountain_/.test(record.assetId||''))return 'monuments';return 'decor';}
function subtitleFor(record,isBuilding,sourceFile){const details=[];if(isBuilding)details.push('Здание целиком');else details.push('Объект на карте');if(record.entry||record.gameplayActive)details.push('есть игровые привязки');if(record.collision?.worldBodies?.length)details.push('есть коллизия');details.push(sourceFile);return details.join(' · ');}
function labelFor(record){if(record.assetId==='police_station'&&record.districtId)return `${LABELS.police_station} · ${record.districtId}`;return LABELS[record.assetId]||record.name||record.assetId||record.id;}

export function createWalkMapAuthoredAdapter({buildingRecords=[],detentionRecords=[],decorRecords=[],groups=[],protectedEntityIds=[],metresPerCell=4.1,suspendPlacement=()=>null,restorePlacement=()=>{},onPreview=()=>{},onCommit=()=>{},capabilityForRecord=null}={}){
 const records=new Map(),roots=new Map(),activePreviews=new Map();
 if(capabilityForRecord!==null&&typeof capabilityForRecord!=='function')throw new Error('Authored adapter capabilityForRecord must be a function');
 const protectedKeys=new Set([...protectedEntityIds].map(String)),baseLocked=(record,key='')=>protectedKeys.has(String(key))||protectedKeys.has(String(record?.id))||!!record?.gameplayActive||LOCKED_ASSETS.has(record?.assetId)||record?.role==='district_detention';
 function lockState(record,key=''){const fallback=baseLocked(record,key),value=capabilityForRecord?.(record,{key,baseLocked:fallback});if(!value||typeof value!=='object')return {locked:fallback,reason:fallback?'Требуется защищённая полная пересборка':null,warning:null,capabilities:{move:!fallback,rotate:!fallback,delete:!fallback,paint:false}};const isLocked=value.locked!==false,capabilities={move:!isLocked,rotate:!isLocked,delete:!isLocked,paint:false,...clone(value.capabilities||{})},reason=typeof value.reason==='string'&&value.reason?value.reason:(isLocked?'Требуется защищённая полная пересборка':'Изменение выполняется атомарной полной пересборкой');return {locked:isLocked,reason,warning:reason,capabilities}}
 const locked=(record,key='')=>lockState(record,key).locked;
 function add(record,dataset,sourceFile,isBuilding){const source={dataset,id:String(record.id),sourceFile},key=walkMapEditorEntityKey(source);records.set(key,{key,source,record,isBuilding,sourceFile,active:true,visibleBeforeDeactivate:true});}
 for(const record of buildingRecords)add(record,'buildings','buildings_placement.v1.json',true);
 for(const record of detentionRecords)add(record,'buildings','detention_native_sites.v1.json',true);
 for(const record of decorRecords)add(record,'decor','decor_placement.v1.json',false);
 for(const group of groups){const instance=group?.userData?.instance;if(!instance?.id)continue;for(const entry of records.values())if(entry.record===instance||entry.record.id===instance.id){roots.set(entry.key,group);group.userData.editorKey=entry.key;group.userData.editorDataset=entry.source.dataset;group.userData.editorId=entry.source.id;break}}
 function entryFor(key,{allowInactive=false}={}){const entry=records.get(key);if(!entry||!allowInactive&&!entry.active)throw new Error(`Unknown authored map object: ${key}`);return entry;}
 function rootFor(key){return roots.get(key)||null;}
 function enumerate(){return [...records.values()].filter(entry=>entry.active).map(entry=>{const {record,isBuilding,sourceFile,key,source}=entry,{locked:isLocked,reason,warning,capabilities}=lockState(record,key);return {key,id:record.id,source,assetId:record.assetId,label:labelFor(record),subtitle:subtitleFor(record,isBuilding,sourceFile),category:categoryFor(record,isBuilding),categoryLabel:isBuilding?'Дом или здание':LAMP.test(record.assetId||'')?'Фонарь':'Городской объект',locked:isLocked,lockReason:isLocked?reason:null,capabilities,derivedWarning:warning||(isLocked?reason:isBuilding?'После перемещения будут пересчитаны вход, участок и коллизии':'После перемещения будут пересчитаны коллизия и освещение'),raw:record};});}
 function resolveIntersection(intersection){let node=intersection?.object;while(node){if(node.userData?.editorKey){const found=records.get(node.userData.editorKey);if(found?.active)return {key:found.key,entry:found,root:rootFor(found.key),point:intersection.point,distance:intersection.distance};}const instance=node.userData?.instance;if(instance?.id){const found=[...records.values()].find(entry=>entry.active&&entry.record.id===instance.id);if(found)return {key:found.key,entry:found,root:node,point:intersection.point,distance:intersection.distance}}node=node.parent}return null;}
 function beginPreview(key){if(activePreviews.has(key))return activePreviews.get(key);const entry=entryFor(key);if(locked(entry.record,key))throw new Error(`Authored object requires protected full rebuild: ${key}`);const root=rootFor(key),before=clone(entry.record),token=root?suspendPlacement(root,key):null,preview={key,before,after:clone(before),root,token,visible:root?.visible!==false};activePreviews.set(key,preview);return preview;}
 function updatePreview(key,transform){const preview=beginPreview(key),next={...recordTransform(preview.after,metresPerCell),...clone(transform)};preview.after.transform={...clone(preview.after.transform||{}),positionM:[...next.positionM],yawDegrees:next.yawDegrees,uniformScale:next.uniformScale,horizontalScale:[...next.horizontalScale],modelLocalOffsetM:[...next.modelLocalOffsetM],preserveSiteBounds:next.preserveSiteBounds};if(preview.root){preview.root.visible=true;applyGroupTransform(preview.root,next)}onPreview({key,before:preview.before,after:preview.after,root:preview.root});return clone(preview.after);}
 function cancelPreview(key){const preview=activePreviews.get(key);if(!preview)return false;if(preview.root){applyGroupTransform(preview.root,recordTransform(preview.before,metresPerCell));preview.root.visible=preview.visible}restorePlacement(preview.token,preview.root,key);activePreviews.delete(key);return true;}
 function cancelAllPreviews(){let cancelled=0;for(const key of [...activePreviews.keys()])if(cancelPreview(key))cancelled++;return cancelled;}
 function replaceRecord(key,record,root=rootFor(key)){
  const entry=entryFor(key,{allowInactive:true});if(!record||String(record.id)!==entry.source.id)throw new Error(`Replacement authored object does not match: ${key}`);
  cancelPreview(key);entry.record=record;entry.active=true;if(root){roots.set(key,root);root.userData??={};root.userData.instance=record;root.userData.editorKey=key;root.userData.editorDataset=entry.source.dataset;root.userData.editorId=entry.source.id;root.visible=entry.visibleBeforeDeactivate!==false}return record;
 }
 function deactivate(key){
  const entry=entryFor(key,{allowInactive:true});if(!entry.active)return false;cancelPreview(key);const root=rootFor(key);if(root){entry.visibleBeforeDeactivate=root.visible!==false;root.visible=false}entry.active=false;return true;
 }
 function commitPreview(key){const preview=activePreviews.get(key);if(!preview)return null;restorePlacement(preview.token,preview.root,key);activePreviews.delete(key);const command=makeWalkMapObjectTransformCommand({source:entryFor(key).source,before:preview.before,after:preview.after,metadata:{adapter:'authored-placement-v1'}});onCommit({key,command,before:preview.before,after:preview.after,root:preview.root,dependencies:dependenciesFor(key)});return command;}
 function deleteCommand(key){const entry=entryFor(key),state=lockState(entry.record,key);if(state.locked)throw new Error(`Authored object requires protected full rebuild: ${key}`);if(state.capabilities.delete!==true)throw new Error(`Authored object cannot be deleted safely: ${key}`);const preview=activePreviews.get(key),before=clone(preview?.after||entry.record);return makeWalkMapObjectDeleteCommand({source:entry.source,before,metadata:{adapter:'authored-placement-v1'}});}
 function suppress(key,value=true){const root=rootFor(key);if(root)root.visible=!value;return !!root;}
 function dependenciesFor(key){const entry=entryFor(key);return entry.isBuilding?['placement-derived','building-entry','walk-collision','vehicle-collision','parking','road-access','decor-keepouts','grass','minimap','static-batches']:['decor-collision','street-lighting','decor-keepouts','grass','minimap','static-batches'];}
 return {id:'authored-placement-v1',datasets:Object.freeze(['buildings','decor']),hasKey:key=>records.get(key)?.active===true,enumerate,resolveIntersection,beginPreview,updatePreview,cancelPreview,cancelAllPreviews,disposePreview:cancelAllPreviews,commitPreview,deleteCommand,suppress,dependenciesFor,rootFor,recordFor:key=>entryFor(key).record,replaceRecord,deactivate,dispose(){cancelAllPreviews();records.clear();roots.clear();}};
}

export {LABELS as WALK_MAP_AUTHORED_LABELS};
