import {WALK_MAP_AUTHORED_LABELS} from './walk_map_editor_authored_adapter.mjs';
import {WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT} from './walk_map_editor_city_schema.mjs';
import {walkMapRoadControlAssetState} from './walk_map_editor_signal_placement.mjs';
import {walkMapVerifiedModuleAssetState} from './walk_map_editor_module_placement.mjs';
import {EXPLORATION_DECOR_TYPES} from './exploration_decor_plan.mjs';
import {WALK_MAP_EXPLORATION_FURNITURE_KINDS,WALK_MAP_EXPLORATION_LANDMARK_KINDS,WALK_MAP_EXPLORATION_TREE_KINDS} from './walk_map_editor_exploration_addition.mjs';

const TOKEN_LABELS=Object.freeze({
 civic:'городской',central:'центральный',district:'районный',park:'парковый',small:'малый',medium:'средний',large:'большой',
 fountain:'фонтан',bench:'скамья',bin:'урна',planter:'клумба',lamp:'фонарь',traffic:'дорожный',signal:'светофор',sign:'знак',
 pedestrian:'пешеходный',bridge:'мост',plaza:'площадь',tile:'плитка',edge:'бордюр',straight:'прямой',corner:'угловой',
 kiosk:'киоск',shelter:'навес',beach:'пляжный',rural:'сельский',forest:'лесной',path:'путь',waterfront:'набережная',
 planting:'озеленение',cycling:'велодорожка',transition:'переход',house:'дом',building:'здание',station:'станция',shop:'магазин',
 rect:'прямоугольная',bike:'велосипедная',rack:'стойка',transit:'остановочный',ped:'пешеходный',crossing:'переход',no:'запрет',
 parking:'парковки',wayfinding:'указатель',light:'сигнал',bollard:'тумба',double:'двойной','4way':'четырёхсторонний',
 t:'Т-образный',junction:'перекрёсток',arm:'консольный',dirt:'грунтовый',gravel:'гравийный',curve:'поворот',slope:'уклон',
 up:'вверх',down:'вниз',boardwalk:'настил',fishing:'рыбацкий',pier:'пирс',short:'короткий',marina:'пристань',dock:'причал',connector:'соединитель',
 lookout:'смотровая',deck:'площадка',sand:'песок',grass:'трава',rock:'камень',stream:'через ручей',footbridge:'пешеходный мост',
 mini:'малый',vehicle:'автомобильный',lifeguard:'спасательная',tower:'вышка',shower:'душ',changing:'переодевальная',cabin:'кабина',
 sun:'солнечный',lounger:'лежак',umbrella:'зонт',picnic:'пикниковый',table:'стол',trail:'туристический',signpost:'указатель',
 fence:'ограда',gate:'ворота','4m':'4 м'
});
const EXCLUDED_ROLES=new Set(['collection_not_single_placement','building_catalog_only']);
const ADAPTER_ROLES=new Set(['signal_adapter_required','walkable_surface_adapter_required']);
const CATEGORY_LABELS=Object.freeze({buildings:'Дома и здания',roads:'Дороги',ground:'Земля и покрытия',lights:'Фонари',signs:'Дорожные знаки',monuments:'Памятники и фонтаны',decor:'Городские объекты',nature:'Деревья и природа',railway:'Железная дорога'});

function clone(value){return structuredClone(value);}
function acceptance(entry){const value=entry?.artAcceptance;return typeof value==='string'?value:value?.status||entry?.sourceAcceptance||'unknown';}
function russianLabel(assetId){
 if(WALK_MAP_AUTHORED_LABELS[assetId])return WALK_MAP_AUTHORED_LABELS[assetId];
 const tokens=String(assetId||'объект').replace(/_v\d+$/,'').split('_'),translated=tokens.map(token=>TOKEN_LABELS[token]||token);
 return translated.join(' ').replace(/^./,letter=>letter.toLocaleUpperCase('ru'));
}
function decorCategory(entry){
 const id=entry.assetId||'',kind=entry.kind||'';
 if(/^lamp_/.test(id))return 'lights';
 if(/signal|sign/.test(`${id} ${kind}`)||kind==='pedestrian_light')return 'signs';
 if(kind==='fountain'||/^monument_/.test(id))return 'monuments';
 if(['plaza_module','curb_module','surface_transition','forest_path'].includes(kind)||entry.assetRole==='walkable_surface_adapter_required')return 'ground';
 if(['planting','rural_prop'].includes(kind))return 'nature';
 if(/rail/.test(`${id} ${kind}`))return 'railway';
 return 'decor';
}
function placementStatus(entry,currentAssetIds,{roadControlAdapterAvailable=false,roadSignAdapterAvailable=roadControlAdapterAvailable,modulePlacementAdapterAvailable=false}={}){
 const current=currentAssetIds.has(entry.assetId),status=acceptance(entry),hasModel=Array.isArray(entry.lods)&&entry.lods.some(lod=>lod?.lod===0&&typeof lod.url==='string'&&/^[a-f0-9]{64}$/i.test(lod.sha256||''));
 if(!hasModel)return {available:false,reason:'Нет проверенной 3D-модели'};
 if(EXCLUDED_ROLES.has(entry.assetRole))return {available:false,reason:'Это набор деталей, а не отдельный объект'};
 if(entry.assetRole==='signal_adapter_required'||entry.kind==='road_sign'){const state=walkMapRoadControlAssetState(entry,{adapterAvailable:entry.kind==='road_sign'?roadSignAdapterAvailable:roadControlAdapterAvailable});return {available:state.available,reason:state.reason}}
 if(entry.assetRole==='walkable_surface_adapter_required'){const state=walkMapVerifiedModuleAssetState(entry,{adapterAvailable:modulePlacementAdapterAvailable});return {available:state.available,reason:state.reason}}
 if(current||status==='approved_civic_kit')return {available:true,reason:current?'Уже используется на этой карте':'Проверенный городской набор'};
 return {available:false,reason:'Требуется визуальная приёмка'};
}
function verifiedBinding(binding){return !!(binding&&typeof binding.url==='string'&&/^[a-f0-9]{64}$/i.test(binding.sha256||''));}
function looksLikeBuilding(record){return !!(record?.footprint||record?.entry||record?.role==='district_detention'||record?.role==='bank_shell'||record?.role==='civic_building');}

export function createWalkMapEditorPalette({buildingCatalog={},decorCatalog={},currentRecords=[],roadControlAdapterAvailable=false,roadSignAdapterAvailable=roadControlAdapterAvailable,modulePlacementAdapterAvailable=false}={}){
 const currentAssetIds=new Set(currentRecords.map(record=>record?.assetId).filter(Boolean)),catalogAssetIds=new Set(),items=[];
 for(const entry of buildingCatalog.entries||[]){
  catalogAssetIds.add(entry.assetId);
  const state=placementStatus(entry,currentAssetIds,{roadControlAdapterAvailable,roadSignAdapterAvailable,modulePlacementAdapterAvailable});if(!state.available&&!currentAssetIds.has(entry.assetId))continue;
  items.push({key:`asset:building:${entry.assetId}`,assetId:entry.assetId,label:russianLabel(entry.assetId),subtitle:`Дом или здание · ${state.reason}`,category:'buildings',categoryLabel:CATEGORY_LABELS.buildings,available:state.available,reason:state.reason,placementMode:'building',binding:clone(entry.lods.find(lod=>lod.lod===0)),raw:entry});
 }
 for(const entry of decorCatalog.entries||[]){
  if(EXCLUDED_ROLES.has(entry.assetRole))continue;
  catalogAssetIds.add(entry.assetId);
  const state=placementStatus(entry,currentAssetIds,{roadControlAdapterAvailable,roadSignAdapterAvailable,modulePlacementAdapterAvailable}),category=decorCategory(entry);if(!state.available&&!currentAssetIds.has(entry.assetId)&&!ADAPTER_ROLES.has(entry.assetRole)&&entry.kind!=='road_sign')continue;
  items.push({key:`asset:decor:${entry.assetId}`,assetId:entry.assetId,label:russianLabel(entry.assetId),subtitle:`${category==='monuments'?'Памятник или фонтан':'Объект карты'} · ${state.reason}`,category,categoryLabel:CATEGORY_LABELS[category],available:state.available,reason:state.reason,placementMode:entry.assetRole==='walkable_surface_adapter_required'?'module':entry.assetRole==='signal_adapter_required'||entry.kind==='road_sign'?'road-control':'decor',binding:clone(entry.lods.find(lod=>lod.lod===0)),raw:entry});
 }
 for(const record of currentRecords){
  if(!record?.assetId||catalogAssetIds.has(record.assetId))continue;catalogAssetIds.add(record.assetId);
  const building=looksLikeBuilding(record),category=building?'buildings':decorCategory(record),binding=clone(record.binding),available=verifiedBinding(binding),reason=available?'Уже используется на этой карте':'Нет проверенной 3D-модели';
  items.push({key:`asset:${building?'building':'decor'}:${record.assetId}`,assetId:record.assetId,label:russianLabel(record.assetId),subtitle:`${building?'Дом или здание':'Объект карты'} · ${reason}`,category,categoryLabel:CATEGORY_LABELS[category],available,reason,placementMode:building?'building':'decor',binding,raw:record,source:'current-placement'});
 }
 return items.sort((a,b)=>a.category.localeCompare(b.category)||a.label.localeCompare(b.label,'ru'));
}

export function createWalkMapSurfacePalette({groundOverlayAdapterAvailable=false,topologyPaintAdapterAvailable=true}={}){
 const disabledOverlayReason=materialId=>`Нужен отдельный overlay-адаптер поверхности: ${WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT[materialId].reason}; tile 9/14 не подменяются`;
 const nativeReason=topologyPaintAdapterAvailable?'Проверенная покраска topology с пересборкой навигации':'Нужен полный topology paint adapter и inventory карты';
 return [
  {key:'surface:asphalt',assetId:'asphalt',label:'Асфальт',subtitle:'Дорожное покрытие · tile 0',category:'roads',categoryLabel:'Дороги',available:topologyPaintAdapterAvailable&&WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.asphalt.available,reason:nativeReason,placementMode:'paint',materialId:'asphalt'},
  {key:'surface:dirt-road',assetId:'dirt-road',label:'Просёлочная дорога',subtitle:`Грунтовая дорога · ${groundOverlayAdapterAvailable?'редакторский overlay':'нужен overlay-адаптер'}`,category:'roads',categoryLabel:'Дороги',available:groundOverlayAdapterAvailable,reason:groundOverlayAdapterAvailable?'Проверенный overlay без подмены tile 9/14':disabledOverlayReason('dirt-road'),placementMode:'overlay',materialId:'dirt-road'},
  {key:'surface:earth',assetId:'earth',label:'Земля',subtitle:`Открытый грунт · ${groundOverlayAdapterAvailable?'редакторский overlay':'нужен overlay-адаптер'}`,category:'ground',categoryLabel:'Земля и трава',available:groundOverlayAdapterAvailable,reason:groundOverlayAdapterAvailable?'Проверенный overlay без подмены tile 9/14':disabledOverlayReason('earth'),placementMode:'overlay',materialId:'earth'},
  {key:'surface:grass',assetId:'grass',label:'Трава',subtitle:'Травяное покрытие · tile 8',category:'ground',categoryLabel:'Земля и трава',available:topologyPaintAdapterAvailable&&WALK_MAP_EDITOR_CITY_SURFACE_SUPPORT.grass.available,reason:nativeReason,placementMode:'paint',materialId:'grass'}
 ];
}

/** Only procedural kinds with a proven renderer are exposed for new placement. */
export function createWalkMapExplorationAdditionPalette({adapterAvailable=false}={}){
 const groups=[
  [WALK_MAP_EXPLORATION_TREE_KINDS,'nature','Деревья и природа','Дерево'],
  [WALK_MAP_EXPLORATION_LANDMARK_KINDS,'monuments','Памятники и фонтаны','Памятник или фонтан'],
  [WALK_MAP_EXPLORATION_FURNITURE_KINDS,'decor','Городские объекты','Городской объект']
 ],reason=adapterAvailable?'Проверенный procedural renderer и spatial validation':'Нужен полный exploration addition adapter';
 return groups.flatMap(([kinds,category,categoryLabel,subtitle])=>kinds.map(kind=>Object.freeze({
  key:`exploration-add:${kind}`,assetId:`exploration-${kind}`,explorationKind:kind,label:EXPLORATION_DECOR_TYPES[kind].label,
  subtitle:`${subtitle} · ${reason}`,category,categoryLabel,available:adapterAvailable,reason,placementMode:'exploration',
  variant:0,zone:'city',...(WALK_MAP_EXPLORATION_TREE_KINDS.includes(kind)?{sizeClass:'adult'}:{})
 })));
}

export {russianLabel as walkMapEditorRussianAssetLabel};
