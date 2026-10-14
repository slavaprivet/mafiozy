import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 WALK_MAP_EDITOR_CATEGORIES,
 WALK_MAP_EDITOR_PAGE_SIZE,
 canActivateWalkMapEditorPaletteItem,
 canRequestWalkMapEditorProtectedAction,
 filterWalkMapEditorItems,
 normalizeWalkMapEditorCatalogStatus,
 normalizeWalkMapEditorSaveState,
 nextWalkMapEditorActiveAsset,
 nextWalkMapEditorVisibleLimit,
 walkMapEditorHelp,
 windowWalkMapEditorItems
} from './walk_map_editor_ui.mjs';

const ids=new Set(WALK_MAP_EDITOR_CATEGORIES.map(item=>item.id));
for(const required of ['buildings','roads','parking','ground','lights','signs','monuments','decor','nature','railway','all'])assert.ok(ids.has(required),`missing ${required}`);
assert.match(walkMapEditorHelp({tool:'select',mode:'top'}),/ПКМ — удалить/);
assert.match(walkMapEditorHelp({tool:'select',mode:'top'}),/Ctrl\+Z — вернуть/);
assert.match(walkMapEditorHelp({tool:'move',mode:'fly',hasSelection:true}),/Enter — применить/);
assert.match(walkMapEditorHelp({tool:'move',mode:'fly',hasSelection:true}),/Зажмите ЛКМ и тяните сам объект/);
assert.doesNotMatch(walkMapEditorHelp({tool:'move',mode:'fly',hasSelection:true}),/стрелки/);
assert.doesNotMatch(walkMapEditorHelp({tool:'rotate',mode:'top',hasSelection:true}),/кольцо/);
assert.match(walkMapEditorHelp({tool:'paint',mode:'top'}),/Зажмите ЛКМ и рисуйте/);
assert.match(walkMapEditorHelp({tool:'select',locked:true,lockReason:'Связано с ограблением'}),/Связано с ограблением/);
assert.doesNotMatch(walkMapEditorHelp({tool:'select',locked:true}),/Разблокировать/);
assert.match(walkMapEditorHelp({tool:'select',locked:true,protectedActionAvailable:true}),/подтверждение доступно/);
assert.equal(canRequestWalkMapEditorProtectedAction({locked:true,protectedActions:['delete']},'delete'),true);
assert.equal(canRequestWalkMapEditorProtectedAction({locked:true,protectedActions:[]},'delete'),false);
assert.equal(canRequestWalkMapEditorProtectedAction({locked:false,protectedActions:['delete']},'delete'),false);

const inventory=Array.from({length:8000},(_,index)=>({key:`generated:${index}`,id:`object-${index}`,label:`Объект ${index}`,assetId:index%2?'lamp':'sign',category:index%3?'decor':'signs'}));
const all=filterWalkMapEditorItems(inventory,{category:'all'});assert.equal(all.length,8000);
let limit=WALK_MAP_EDITOR_PAGE_SIZE,windowed=windowWalkMapEditorItems(all,{limit});assert.equal(windowed.items.length,160);assert.equal(windowed.hasMore,true);assert.equal(windowed.items.length+Number(windowed.hasMore),161);
limit=nextWalkMapEditorVisibleLimit(limit,'show-more');windowed=windowWalkMapEditorItems(all,{limit});assert.equal(limit,320);assert.equal(windowed.items.length,320);assert.equal(windowed.items.length-160,160);assert.equal(windowed.items.length+Number(windowed.hasMore),321);
for(const action of ['search','category','scope','catalog','palette'])assert.equal(nextWalkMapEditorVisibleLimit(limit,action),160,`${action} must reset list window`);
assert.ok(filterWalkMapEditorItems(inventory,{category:'signs'}).every(item=>item.category==='signs'));
assert.deepEqual(filterWalkMapEditorItems(inventory,{category:'all',query:'Объект 7999'}).map(item=>item.id),['object-7999']);
const enabled={key:'asset:enabled',available:true},disabled={key:'asset:disabled',available:false,reason:'Нужен безопасный адаптер'};
assert.equal(canActivateWalkMapEditorPaletteItem(enabled),true);assert.equal(canActivateWalkMapEditorPaletteItem(disabled),false);
assert.equal(nextWalkMapEditorActiveAsset(null,{type:'set',item:disabled}),null);assert.equal(nextWalkMapEditorActiveAsset(null,{type:'set',item:enabled}),enabled);
for(const type of ['clear','close','cancel'])assert.equal(nextWalkMapEditorActiveAsset(enabled,{type}),null);
assert.deepEqual(normalizeWalkMapEditorSaveState({status:'dirty',dirty:true}),{status:'dirty',dirty:true,saving:false,message:'Есть несохранённые изменения'});
assert.deepEqual(normalizeWalkMapEditorSaveState({status:'saved',dirty:false}),{status:'saved',dirty:false,saving:false,message:'Сохранено'});
assert.equal(normalizeWalkMapEditorSaveState({status:'saving'}).saving,true);assert.equal(normalizeWalkMapEditorSaveState({status:'error',dirty:true,message:'Диск заполнен'}).message,'Диск заполнен');
assert.deepEqual(normalizeWalkMapEditorCatalogStatus({status:'loading',loaded:242,total:9659}),{status:'loading',loaded:242,total:9659,message:'Загружено объектов: 242 из 9659…',retry:false});assert.equal(normalizeWalkMapEditorCatalogStatus({status:'error'}).retry,true);

const source=await readFile(new URL('walk_map_editor_ui.mjs',import.meta.url),'utf8');
assert.match(source,/button\(doc,'На карте','scope:world'/);
assert.match(source,/button\(doc,'＋ Добавить новый','scope:palette'/);
assert.match(source,/scope==='palette'\?palette:catalog/);
assert.match(source,/if\(action\.startsWith\('scope:'\)\).*nextWalkMapEditorVisibleLimit\(visibleLimit,'scope'\)/);
assert.match(source,/scope==='palette'&&item\.available===false/);
assert.match(source,/scope==='palette'\?'Для этой категории пока нет готовых объектов\.'/);
assert.match(source,/aria-label',`Показать ещё объекты: сейчас/);
assert.match(source,/clearActiveAsset\('close',\{emit:true\}\)/);
assert.match(source,/cancelActiveAsset\(reason='cancel'\)/);
assert.match(source,/update\(\{render:false\}\)/);
assert.match(source,/filterCacheKey/);
assert.match(source,/className='wme-save-status'/);assert.match(source,/setSaveState/);assert.match(source,/Есть несохранённые изменения/);assert.match(source,/Сохранено/);
assert.match(source,/className='wme-catalog-status'/);assert.match(source,/aria-live','polite'/);assert.match(source,/appendCatalog\(items\)/);assert.match(source,/'retry-catalog'/);assert.match(source,/onAction\('catalog-category'/);
assert.match(source,/canRequestWalkMapEditorProtectedAction\(item,action\)/);assert.match(source,/Этот объект пока нельзя изменить безопасно/);
console.log('walk map editor UI contract: PASS');
