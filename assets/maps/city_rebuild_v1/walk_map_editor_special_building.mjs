import {deriveMovedBuilding,DIRTY_BUILDING_DEPENDENCIES} from './walk_map_editor_building_derive.mjs';
import {makeWalkMapObjectTransformCommand,walkMapEditorEntityKey} from './walk_map_editor_document.mjs';

export const WALK_MAP_SPECIAL_BUILDING_ADAPTER_ID='special-building-full-rebuild-v1';
export const WALK_MAP_SPECIAL_BUILDING_DEPENDENCIES=Object.freeze([...new Set([
 ...DIRTY_BUILDING_DEPENDENCIES,'building-render','building-physics','interior-render','interior-collision','door-runtime',
 'road-navigation','walk-navigation','vehicle-navigation','minimap-poi','parking-access','npc-site-registry','gameplay-site-registry'
])]);

const BANK_ASSET=/^bank_/;
const CIVIC_ASSETS=new Set(['civic_hall','hospital']);
const trustedPlans=new WeakSet();

export class WalkMapSpecialBuildingError extends Error{
 constructor(code,message,details={}){super(message);this.name='WalkMapSpecialBuildingError';this.code=code;this.details=structuredClone(details)}
}
function fail(code,message,details){throw new WalkMapSpecialBuildingError(code,message,details)}
function clone(value){return structuredClone(value)}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)}
function stable(value){if(Array.isArray(value))return value.map(stable);if(plain(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value}
function equal(a,b){return JSON.stringify(stable(a))===JSON.stringify(stable(b))}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(plain(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value)}
function unique(values){return [...new Set(values.filter(value=>typeof value==='string'&&value))]}
function protectedRecord(record,protectedEntityIds){
 const values=new Set([...protectedEntityIds].map(String)),source={dataset:'buildings',id:String(record?.id||'')};
 return values.has(source.id)||values.has(walkMapEditorEntityKey(source));
}
function hasProvableGeometry(record){return !!(record?.footprint&&record?.entry?.anchorRC&&record?.entry?.roadProbeRC&&Array.isArray(record?.collision?.worldBodies)&&record.collision.worldBodies.length)}
function typeDependencies(kind){
 if(kind==='bank')return ['bank-interior','bank-door-runtime','bank-vault-runtime','safe-registry'];
 if(kind==='civic')return ['civic-interior','public-building-entry'];
 if(kind==='hospital')return ['hospital-interior','hospital-public-access'];
 if(kind==='detention')return ['detention-runtime','detention-stop-lane','police-spawn-registry'];
 return [];
}

export function classifyWalkMapSpecialBuilding(record,{protectedEntityIds=[]}={}){
 const protectedByOwner=!!record?.id&&protectedRecord(record,protectedEntityIds),gameplayActive=record?.gameplayActive===true;
 let kind=null;if(record?.role==='district_detention'||record?.assetId==='police_station')kind='detention';else if(BANK_ASSET.test(record?.assetId||''))kind='bank';else if(record?.assetId==='civic_hall')kind='civic';else if(record?.assetId==='hospital')kind='hospital';else if(gameplayActive)kind='gameplay';else if(protectedByOwner)kind='protected';
 if(!kind)return {special:false,visible:true,locked:false,kind:null,reason:'Обычное здание использует частичный пересчёт',capabilities:{move:true,rotate:true,delete:true,paint:false},requiresAuthorization:false,dependencies:clone(DIRTY_BUILDING_DEPENDENCIES)};
 let code=null,reason=null;
 if(gameplayActive){code='GAMEPLAY_ACTIVE_BINDINGS_UNMODELED';reason='Здание участвует в активных игровых механиках; внешние игровые якоря пока нельзя безопасно перенести';}
 else if(kind==='detention'){code='DETENTION_RUNTIME_COORDINATES_UNMODELED';reason='Изолятор использует отдельные stopFootprint, stopLane и точки задержания; их безопасный пересчёт ещё не подключён';}
 else if(kind==='bank'){code='BANK_GAMEPLAY_ANCHOR_MIGRATION_PENDING';reason='Банк видим, но перенос заблокирован до миграции игровых и исходных банковских якорей';}
 else if(!hasProvableGeometry(record)){code='SPECIAL_BUILDING_GEOMETRY_INCOMPLETE';reason='Для безопасного переноса не хватает footprint, входа с дорогой или доказанных коллизий';}
 const dependencies=unique([...WALK_MAP_SPECIAL_BUILDING_DEPENDENCIES,...typeDependencies(kind)]),locked=!!code;
 return {special:true,visible:true,locked,kind,code,reason:reason??'Нужна явная авторизация и полная пересборка здания',capabilities:{move:!locked,rotate:!locked,delete:false,paint:false},requiresAuthorization:true,protectedByOwner,dependencies};
}

export function auditWalkMapSpecialBuildings({buildingRecords=[],detentionRecords=[],protectedEntityIds=[]}={}){
 const records=[...buildingRecords,...detentionRecords],items=[];
 for(const record of records){const classification=classifyWalkMapSpecialBuilding(record,{protectedEntityIds});if(classification.special)items.push({id:record.id,assetId:record.assetId,role:record.role,sourceFile:detentionRecords.includes(record)?'detention_native_sites.v1.json':'buildings_placement.v1.json',...classification});}
 return {items,counts:{total:items.length,movable:items.filter(item=>!item.locked).length,locked:items.filter(item=>item.locked).length},lockedReasons:Object.fromEntries(items.filter(item=>item.locked).map(item=>[item.id,item.reason]))};
}

function assertCompleteInventory(inventory){
 if(!plain(inventory)||inventory.complete?.buildings!==true||inventory.complete?.parking!==true||!Array.isArray(inventory.otherInstances)||!Array.isArray(inventory.parkingKeepouts))fail('FULL_REBUILD_INVENTORY_INCOMPLETE','Полная пересборка требует полный список зданий и парковок');
}
function assertTopology(topology){if(!plain(topology)||!Array.isArray(topology.grid)||!Array.isArray(topology.roadMask))fail('FULL_REBUILD_TOPOLOGY_REQUIRED','Полная пересборка требует доверенную topology с дорожным графом')}
function validateAuthorization(value){
 if(!plain(value)||value.allowed!==true||typeof value.approvalId!=='string'||!value.approvalId.trim()||value.approvalId.length>512||value.actor!==undefined&&(typeof value.actor!=='string'||!value.actor.trim()||value.actor.length>512))fail('SPECIAL_BUILDING_AUTHORIZATION_REQUIRED','Для специального здания нужна явная защищённая авторизация');
 return {approvalId:value.approvalId.trim(),actor:value.actor?.trim()||'host',reason:typeof value.reason==='string'?value.reason:''};
}

export async function compileWalkMapSpecialBuildingFullRebuild({
 trustedBase,nextTransform,topology,inventory,protectedEntityIds=[],authorizeProtected,metresPerCell=4.1,deriveBuilding=deriveMovedBuilding
}={}){
 if(!trustedBase?.id)fail('BASE_BUILDING_REQUIRED','Не найдена исходная запись специального здания');
 const classification=classifyWalkMapSpecialBuilding(trustedBase,{protectedEntityIds});
 if(!classification.special)fail('NOT_SPECIAL_BUILDING','Здание не требует специального full-rebuild пути');
 if(classification.locked)fail(classification.code,classification.reason,{id:trustedBase.id,kind:classification.kind});
 if(typeof authorizeProtected!=='function')fail('SPECIAL_BUILDING_AUTHORIZATION_REQUIRED','Для специального здания нужна явная защищённая авторизация');
 if(typeof deriveBuilding!=='function')fail('FULL_REBUILD_COMPILER_REQUIRED','Не подключён доверенный компилятор здания');
 assertTopology(topology);assertCompleteInventory(inventory);
 const derived=await deriveBuilding({trustedBase:clone(trustedBase),nextTransform:clone(nextTransform),topology,otherInstances:inventory.otherInstances,parkingKeepouts:inventory.parkingKeepouts,metresPerCell,allowSpecialFullRebuild:true});
 if(!derived?.ok)fail(derived?.code||'SPECIAL_BUILDING_DERIVE_FAILED',derived?.message||'Не удалось пересчитать специальное здание',derived?.details||{});
 if(derived.record?.id!==trustedBase.id||derived.record?.assetId!==trustedBase.assetId||derived.record?.gameplayId!==trustedBase.gameplayId)fail('SPECIAL_BUILDING_IDENTITY_CHANGED','Full rebuild не может менять идентичность специального здания');
 const dependencies=unique([...classification.dependencies,...(derived.dirty||[])]),request=deepFreeze({schema:'mafiozi.walk-map-editor.special-building-authorization/v1',operation:'move-special-building',source:{dataset:'buildings',id:String(trustedBase.id)},kind:classification.kind,protectedByOwner:classification.protectedByOwner,beforeTransform:clone(trustedBase.transform),afterTransform:clone(derived.record.transform),dependencies:clone(dependencies),visualOnly:false,protectionPolicyStillRequired:true});
 const approval=validateAuthorization(await authorizeProtected(request)),authorization=deepFreeze({schema:'mafiozi.walk-map-editor.special-building-approval/v1',...approval,source:clone(request.source),kind:classification.kind,preflightOnly:true,protectionPolicyStillRequired:true});
 const plan={schema:'mafiozi.walk-map-editor.special-building-full-rebuild/v1',adapter:WALK_MAP_SPECIAL_BUILDING_ADAPTER_ID,source:clone(request.source),before:clone(trustedBase),record:clone(derived.record),exact:clone(derived.exact),classification:clone(classification),authorization:clone(authorization),dependencies:clone(dependencies),mode:'full',visualOnly:false,requiresProtectionPolicy:true};
 trustedPlans.add(plan);return plan;
}

function validateBindingReceipt(receipt,dependencies){
 if(!plain(receipt)||receipt.accepted!==true||receipt.mode!=='full'||receipt.visualOnly!==false||typeof receipt.executorId!=='string'||!receipt.executorId.trim()||!Array.isArray(receipt.dependencies)||dependencies.some(value=>!receipt.dependencies.includes(value)))fail('FULL_REBUILD_EXECUTOR_REQUIRED','Команда запрещена без полного runtime rebuild executor и всех зависимостей');
 return {accepted:true,mode:'full',visualOnly:false,executorId:receipt.executorId.trim(),dependencies:unique(receipt.dependencies)};
}

export function createWalkMapSpecialBuildingCommandPreparer({
 resolveCurrentEntity,topology,inventory,protectedEntityIds=[],authorizeProtected,bindFullRebuild,metresPerCell=4.1,deriveBuilding=deriveMovedBuilding
}={}){
 if(typeof resolveCurrentEntity!=='function')throw new Error('Special building preparation requires a trusted current-entity resolver');
 if(typeof bindFullRebuild!=='function')throw new Error('Special building preparation requires a full rebuild executor binding');
 return async function prepareSpecialBuildingCommands(commands,{dependencies=[]}={}){
  if(!Array.isArray(commands)||commands.length!==1)fail('SPECIAL_BUILDING_SINGLE_COMMAND_REQUIRED','Специальное здание изменяется одной атомарной командой');
  const patch=commands[0]?.type==='object.set-patch'?commands[0].patch:null;
  if(patch?.source?.dataset!=='buildings'||patch.action!=='modify'||!patch.after?.transform)fail('SPECIAL_BUILDING_TRANSFORM_REQUIRED','Разрешено только перемещение специального здания');
  const current=await resolveCurrentEntity(clone(patch.source));
  if(!plain(current)||String(current.id)!==String(patch.source.id))fail('TRUSTED_SPECIAL_BUILDING_MISSING',`Не найдена доверенная запись ${patch.source.id}`);
  if(!equal(current,patch.before))fail('STALE_SPECIAL_BUILDING_PREVIEW',`Устаревшее состояние ${patch.source.id}`);
  const plan=await compileWalkMapSpecialBuildingFullRebuild({trustedBase:current,nextTransform:patch.after.transform,topology:typeof topology==='function'?topology():topology,inventory:typeof inventory==='function'?inventory():inventory,protectedEntityIds,authorizeProtected,metresPerCell,deriveBuilding});
  if(!trustedPlans.has(plan))fail('UNTRUSTED_FULL_REBUILD_PLAN','Full rebuild plan не является доверенным');
  const publicPlan=deepFreeze(clone(plan)),binding=validateBindingReceipt(await bindFullRebuild(publicPlan),plan.dependencies);
  const allDependencies=unique([...dependencies,...plan.dependencies]),metadata={...clone(patch.metadata||{}),adapter:WALK_MAP_SPECIAL_BUILDING_ADAPTER_ID,fullRebuild:true,visualOnly:false,requiresProtectionPolicy:true,protectedApproval:clone(plan.authorization),executor:{id:binding.executorId,mode:'full'},dependencies:allDependencies};
  const command=makeWalkMapObjectTransformCommand({source:patch.source,before:current,after:plan.record,metadata});
  return {commands:[command],dependencies:allDependencies,rebuildPlans:[publicPlan],requiresProtectionPolicy:true};
 };
}
