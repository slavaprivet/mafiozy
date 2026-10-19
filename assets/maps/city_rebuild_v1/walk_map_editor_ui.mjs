export const WALK_MAP_EDITOR_MODES=Object.freeze({TOP:'top',FLY:'fly'});
export const WALK_MAP_EDITOR_TOOLS=Object.freeze({SELECT:'select',MOVE:'move',ROTATE:'rotate',PLACE:'place',PAINT:'paint'});
export const WALK_MAP_EDITOR_PAGE_SIZE=160;

export const WALK_MAP_EDITOR_CATEGORIES=Object.freeze([
 {id:'buildings',label:'Дома и здания',icon:'▦'},
 {id:'roads',label:'Дороги',icon:'═'},
 {id:'parking',label:'Парковки',icon:'P'},
 {id:'ground',label:'Земля и трава',icon:'▧'},
 {id:'lights',label:'Фонари',icon:'♧'},
 {id:'signs',label:'Дорожные знаки',icon:'⚑'},
 {id:'monuments',label:'Памятники',icon:'◆'},
 {id:'decor',label:'Городские объекты',icon:'●'},
 {id:'nature',label:'Деревья и природа',icon:'♣'},
 {id:'railway',label:'Железная дорога',icon:'╫'},
 {id:'all',label:'Все объекты',icon:'⌘'}
]);

const TOOL_LABELS={select:'Выбор',move:'Перемещение',rotate:'Поворот',place:'Установка',paint:'Рисование покрытия'};

export function filterWalkMapEditorItems(items,{category='all',query=''}={}){const needle=String(query??'').trim().toLocaleLowerCase('ru'),result=[];for(const item of Array.isArray(items)?items:[])if((category==='all'||item.category===category)&&(!needle||`${item.label||''} ${item.assetId||''} ${item.id||''}`.toLocaleLowerCase('ru').includes(needle)))result.push(item);return result;}
export function windowWalkMapEditorItems(items,{limit=WALK_MAP_EDITOR_PAGE_SIZE}={}){const safeLimit=Math.max(0,Number.isFinite(limit)?Math.floor(limit):WALK_MAP_EDITOR_PAGE_SIZE),source=Array.isArray(items)?items:[];return Object.freeze({items:source.slice(0,safeLimit),total:source.length,visibleCount:Math.min(source.length,safeLimit),hasMore:source.length>safeLimit,nextLimit:safeLimit+WALK_MAP_EDITOR_PAGE_SIZE});}
export function nextWalkMapEditorVisibleLimit(current,action){return action==='show-more'?Math.max(WALK_MAP_EDITOR_PAGE_SIZE,Number.isFinite(current)?Math.floor(current):WALK_MAP_EDITOR_PAGE_SIZE)+WALK_MAP_EDITOR_PAGE_SIZE:WALK_MAP_EDITOR_PAGE_SIZE;}
export function canActivateWalkMapEditorPaletteItem(item){return !!item&&item.available!==false;}
export function canRequestWalkMapEditorProtectedAction(item,action){return !!item?.locked&&Array.isArray(item.protectedActions)&&item.protectedActions.includes(action);}
export function nextWalkMapEditorActiveAsset(current,{type,item=null}={}){if(['clear','close','cancel'].includes(type))return null;if(type==='set')return canActivateWalkMapEditorPaletteItem(item)?item:null;return current??null;}
export function normalizeWalkMapEditorSaveState(value={}){const allowed=new Set(['saved','dirty','saving','error']),status=allowed.has(value?.status)?value.status:'saved',dirty=!!value?.dirty,message=typeof value?.message==='string'&&value.message.trim()?value.message:status==='dirty'?'Есть несохранённые изменения':status==='saving'?'Сохранение…':status==='error'?'Не удалось сохранить':'Сохранено';return Object.freeze({status,dirty,saving:status==='saving'||!!value?.saving,message});}
export function normalizeWalkMapEditorCatalogStatus(value={}){const allowed=new Set(['idle','loading','ready','error','cancelled']),status=allowed.has(value?.status)?value.status:'idle',loaded=Number.isSafeInteger(value?.loaded)&&value.loaded>=0?value.loaded:0,total=Number.isSafeInteger(value?.total)&&value.total>=0?value.total:null,message=typeof value?.message==='string'&&value.message.trim()?value.message:status==='loading'?(total===null?`Загружено объектов: ${loaded}…`:`Загружено объектов: ${loaded} из ${total}…`):status==='error'?'Не удалось загрузить дополнительные объекты.':' ';return Object.freeze({status,loaded,total,message,retry:status==='error'});}

export function walkMapEditorHelp({tool='select',mode='top',hasSelection=false,locked=false,lockReason='',protectedActionAvailable=false}={}){
 const view=mode==='fly'?'WASD — лететь · Shift+WASD — быстрее · средняя кнопка — смотреть':'WASD — двигать карту · средняя кнопка — панорама · колесо — масштаб';
 if(locked)return protectedActionAvailable?`Объект защищён · подтверждение доступно только для разрешённого действия · ${view}`:`Объект защищён · ${lockReason||'безопасное изменение пока недоступно'} · ${view}`;
 if(tool==='move')return hasSelection?`Зажмите ЛКМ и тяните сам объект · Enter — применить · Esc — отменить · ${view}`:`Сначала выберите дом или объект · ${view}`;
 if(tool==='rotate')return hasSelection?`Q / E — поворот на 15° · Enter — применить · Esc — отменить · ${view}`:`Сначала выберите дом или объект · ${view}`;
 if(tool==='place')return `ЛКМ — поставить объект · R — повернуть · [ / ] — размер · Esc — отменить · ${view}`;
 if(tool==='paint')return `Зажмите ЛКМ и рисуйте · [ / ] — размер кисти · Shift+ЛКМ — прямая линия · ПКМ — стереть покрытие · ${view}`;
 return `ЛКМ — выбрать · ПКМ — удалить · Ctrl+Z — вернуть · ${view}`;
}

function button(doc,text,action,title=''){
 const node=doc.createElement('button');node.type='button';node.textContent=text;node.dataset.editorAction=action;if(title)node.title=title;return node;
}

function styleText(){return `
 #walk-map-editor{position:fixed;inset:0;z-index:24000;pointer-events:none;color:#f8ead1;font:500 14px/1.35 system-ui,Segoe UI,sans-serif;--panel:#14252eef;--line:#d2a84c66;--gold:#efc66b;--active:#5b887a}
 #walk-map-editor[hidden]{display:none}
 #walk-map-editor *{box-sizing:border-box}
 #walk-map-editor button,#walk-map-editor input,#walk-map-editor select{font:inherit}
 #walk-map-editor .wme-panel{pointer-events:auto;position:absolute;top:14px;bottom:68px;left:14px;width:min(370px,calc(100vw - 28px));display:flex;flex-direction:column;background:linear-gradient(180deg,#182e37f5,#101d24f5);border:1px solid var(--line);border-radius:14px;box-shadow:0 16px 46px #0009;overflow:hidden}
 #walk-map-editor .wme-head{display:grid;grid-template-columns:1fr auto;gap:4px 10px;padding:14px 14px 11px;border-bottom:1px solid var(--line)}
 #walk-map-editor h2{margin:0;font:800 20px/1.1 Georgia,serif;color:#fff3d6}
 #walk-map-editor .wme-subtitle{grid-column:1/-1;color:#c7d5d5;font-size:12px}
 #walk-map-editor .wme-close{grid-column:2;grid-row:1;width:34px;height:34px;padding:0;border-radius:9px}
 #walk-map-editor .wme-toolbar{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;padding:10px;border-bottom:1px solid #ffffff14}
 #walk-map-editor button{min-height:36px;padding:7px 9px;color:#f8ead1;background:#203a43;border:1px solid #ffffff1d;border-radius:8px;cursor:pointer}
 #walk-map-editor button:hover{background:#2b4d55;border-color:#efc66b77}
 #walk-map-editor button[aria-pressed=true],#walk-map-editor button[data-active=true]{background:#527b70;color:white;border-color:#f2d184}
 #walk-map-editor button:disabled{opacity:.42;cursor:default}
 #walk-map-editor .wme-views{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding:10px 10px 0}
 #walk-map-editor .wme-views button{min-height:42px;font-weight:750}
 #walk-map-editor .wme-search{margin:10px;width:calc(100% - 20px);padding:10px 11px;color:white;background:#0b171d;border:1px solid #ffffff28;border-radius:9px;outline:none}
 #walk-map-editor .wme-search:focus{border-color:var(--gold)}
 #walk-map-editor .wme-scope{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding:0 10px 10px}
 #walk-map-editor .wme-scope button{min-height:38px;font-weight:750}
 #walk-map-editor .wme-catalog-status{display:flex;align-items:center;gap:8px;min-height:30px;padding:3px 10px 8px;color:#bfd1d1;font-size:12px}
 #walk-map-editor .wme-catalog-status[hidden]{display:none}
 #walk-map-editor .wme-catalog-status button{min-height:28px;margin-left:auto;padding:3px 8px}
 #walk-map-editor .wme-body{display:grid;grid-template-columns:146px minmax(0,1fr);min-height:0;flex:1;border-top:1px solid #ffffff12}
 #walk-map-editor .wme-categories{overflow:auto;padding:7px;border-right:1px solid #ffffff12}
 #walk-map-editor .wme-categories button{display:block;width:100%;min-height:35px;margin-bottom:5px;text-align:left;padding:7px;font-size:12px}
 #walk-map-editor .wme-list{overflow:auto;padding:8px}
 #walk-map-editor .wme-card{display:block;width:100%;text-align:left;margin-bottom:6px;min-height:48px}
 #walk-map-editor .wme-card strong,#walk-map-editor .wme-card small{display:block}
 #walk-map-editor .wme-card small{margin-top:2px;color:#b9c9c9}
 #walk-map-editor .wme-empty{padding:20px 10px;text-align:center;color:#b7c4c4}
 #walk-map-editor .wme-selection{padding:10px 12px;border-top:1px solid var(--line);background:#0c1a20}
 #walk-map-editor .wme-selection strong{display:block;color:#ffe0a3}
 #walk-map-editor .wme-selection span{display:block;color:#b9c9c9;font-size:12px;margin-top:2px}
 #walk-map-editor .wme-save-status{margin:0;padding:7px 12px 0;color:#a9cfb4;font-size:12px}
 #walk-map-editor .wme-save-status[data-state=dirty],#walk-map-editor .wme-save-status[data-state=error]{color:#ffd58a}
 #walk-map-editor .wme-actions{display:grid;grid-template-columns:1fr 1fr 1fr;gap:6px;padding:9px 10px 11px}
 #walk-map-editor .wme-danger{color:#ffd9d5;border-color:#d85f5666;background:#552c2a}
 #walk-map-editor .wme-save{background:#80642f;font-weight:800}
 #walk-map-editor .wme-help{pointer-events:auto;position:absolute;left:14px;right:14px;bottom:12px;min-height:46px;display:flex;align-items:center;gap:12px;padding:10px 14px;background:#101d24ee;border:1px solid var(--line);border-radius:12px;box-shadow:0 8px 24px #0008}
 #walk-map-editor .wme-help b{flex:none;color:var(--gold)}
 #walk-map-editor .wme-help span{min-width:0}
 #walk-map-editor .wme-toast{pointer-events:none;position:absolute;left:50%;top:24px;transform:translateX(-50%);max-width:min(560px,80vw);padding:10px 16px;background:#102a22f2;border:1px solid #91c89d;border-radius:10px;box-shadow:0 8px 30px #0008;font-weight:750;opacity:0;transition:opacity .18s}
 #walk-map-editor .wme-toast[data-visible=true]{opacity:1}
 #walk-map-editor dialog{pointer-events:auto;color:#f8ead1;background:#14252e;border:1px solid var(--line);border-radius:14px;box-shadow:0 18px 60px #000c;max-width:440px;padding:18px}
 #walk-map-editor dialog::backdrop{background:#0008}
 #walk-map-editor dialog h3{margin:0 0 8px;color:#ffe0a3}
 #walk-map-editor dialog p{margin:0 0 14px;color:#d5dddd}
 #walk-map-editor dialog menu{display:flex;justify-content:flex-end;gap:8px;margin:0;padding:0}
 @media(max-width:720px){#walk-map-editor .wme-panel{bottom:76px;width:calc(100vw - 28px)}#walk-map-editor .wme-help{font-size:12px}}
 `;}

export function createWalkMapEditorUi({document:doc=globalThis.document,parent=doc?.body,onAction=()=>{},onOpenChange=()=>{}}={}){
 if(!doc||!parent)throw new Error('Map editor UI requires a document and parent');
 const root=doc.createElement('section');root.id='walk-map-editor';root.hidden=true;root.dataset.walkHud='map-editor';root.setAttribute('aria-label','Редактор карты');
 const style=doc.createElement('style');style.textContent=styleText();
 const panel=doc.createElement('div');panel.className='wme-panel';panel.tabIndex=-1;panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','false');panel.setAttribute('aria-labelledby','walk-map-editor-title');panel.setAttribute('aria-describedby','walk-map-editor-help-text');
 const head=doc.createElement('header');head.className='wme-head';head.innerHTML='<h2 id="walk-map-editor-title">Редактор карты</h2><div class="wme-subtitle">K — открыть или закрыть · все изменения можно отменить</div>';
 const close=button(doc,'×','close','Закрыть редактор (K)');close.className='wme-close';close.setAttribute('aria-label','Закрыть редактор');head.append(close);
 const views=doc.createElement('div');views.className='wme-views';
 const topView=button(doc,'1 · Вид сверху','mode:top');const flyView=button(doc,'2 · Свободный полёт','mode:fly');views.append(topView,flyView);
 const toolbar=doc.createElement('div');toolbar.className='wme-toolbar';
 for(const [id,label] of [['select','Выбрать'],['move','Двигать'],['rotate','Повернуть'],['place','Поставить'],['paint','Покрытие'],['undo','↶ Отмена'],['redo','↷ Повтор'],['fit','Показать всё']])toolbar.append(button(doc,label,id));
 const search=doc.createElement('input');search.className='wme-search';search.type='search';search.placeholder='Найти дом, фонарь, знак…';search.setAttribute('aria-label','Поиск объектов карты');
 const scopeTabs=doc.createElement('div');scopeTabs.className='wme-scope';scopeTabs.setAttribute('aria-label','Что показать в списке');
 const worldScope=button(doc,'На карте','scope:world','Текущие объекты — их можно выбрать, передвинуть или удалить');
 const paletteScope=button(doc,'＋ Добавить новый','scope:palette','Каталог объектов, которые можно поставить на карту');scopeTabs.append(worldScope,paletteScope);
 const catalogStatus=doc.createElement('div');catalogStatus.className='wme-catalog-status';catalogStatus.setAttribute('role','status');catalogStatus.setAttribute('aria-live','polite');catalogStatus.hidden=true;const catalogStatusText=doc.createElement('span'),catalogRetry=button(doc,'Повторить','retry-catalog');catalogRetry.hidden=true;catalogStatus.append(catalogStatusText,catalogRetry);
 const body=doc.createElement('div');body.className='wme-body';
 const categories=doc.createElement('nav');categories.className='wme-categories';categories.setAttribute('aria-label','Категории объектов');
 for(const category of WALK_MAP_EDITOR_CATEGORIES){const node=button(doc,`${category.icon} ${category.label}`,`category:${category.id}`);node.dataset.category=category.id;categories.append(node)}
 const list=doc.createElement('div');list.className='wme-list';list.setAttribute('aria-label','Объекты выбранной категории');body.append(categories,list);
 const selection=doc.createElement('div');selection.className='wme-selection';selection.setAttribute('role','status');selection.setAttribute('aria-live','polite');selection.innerHTML='<strong>Ничего не выбрано</strong><span>Щёлкните по объекту на карте или выберите его из списка.</span>';
 const saveStatus=doc.createElement('p');saveStatus.className='wme-save-status';saveStatus.setAttribute('role','status');saveStatus.setAttribute('aria-live','polite');
 const actions=doc.createElement('div');actions.className='wme-actions';
 const remove=button(doc,'Удалить','delete','Удалить выбранное; также можно нажать ПКМ по объекту');remove.className='wme-danger';remove.disabled=true;
 const save=button(doc,'Сохранить','save');save.className='wme-save';
 const more=button(doc,'Экспорт / импорт','files');actions.append(remove,save,more);
 panel.append(head,views,toolbar,search,scopeTabs,catalogStatus,body,selection,saveStatus,actions);
 const help=doc.createElement('div');help.className='wme-help';help.innerHTML='<b>Подсказка</b><span id="walk-map-editor-help-text"></span>';
 const toast=doc.createElement('div');toast.className='wme-toast';toast.setAttribute('role','status');toast.setAttribute('aria-live','polite');
 const confirm=doc.createElement('dialog');confirm.setAttribute('aria-labelledby','walk-map-editor-confirm-title');confirm.setAttribute('aria-describedby','walk-map-editor-confirm-text');confirm.innerHTML='<h3 id="walk-map-editor-confirm-title">Защищённый объект</h3><p id="walk-map-editor-confirm-text"></p><menu></menu>';
 root.append(style,panel,help,toast,confirm);parent.append(root);

 let open=false,mode='top',tool='select',category='buildings',scope='world',catalog=[],catalogKeys=new Set(),palette=[],selected=null,activeAsset=null,saveState=normalizeWalkMapEditorSaveState(),catalogLoadState=normalizeWalkMapEditorCatalogStatus(),visibleLimit=WALK_MAP_EDITOR_PAGE_SIZE,toastTimer=0,priorFocus=null,catalogVersion=0,paletteVersion=0,filterCacheKey='',filterCache=[];
 const controls=[topView,flyView,...toolbar.querySelectorAll('button')];
 function update({render=true}={}){
  topView.setAttribute('aria-pressed',String(mode==='top'));flyView.setAttribute('aria-pressed',String(mode==='fly'));
  for(const node of toolbar.querySelectorAll('button')){const active=node.dataset.editorAction===tool;node.dataset.active=String(active);if(['select','move','rotate','place','paint'].includes(node.dataset.editorAction))node.setAttribute('aria-pressed',String(active))}
  for(const node of categories.querySelectorAll('button')){const active=node.dataset.category===category;node.dataset.active=String(active);node.setAttribute('aria-pressed',String(active))}
  worldScope.setAttribute('aria-pressed',String(scope==='world'));paletteScope.setAttribute('aria-pressed',String(scope==='palette'));
  remove.disabled=!selected;
  const strong=selection.querySelector('strong'),detail=selection.querySelector('span');
  strong.textContent=selected?.label||(activeAsset?`Новый объект: ${activeAsset.label}`:'Ничего не выбрано');
  detail.textContent=selected?(selected.locked?`Защищённый объект · ${selected.lockReason||selected.derivedWarning||'безопасное изменение пока недоступно'}`:`${selected.categoryLabel||'Объект'} · ${selected.derivedWarning||'можно двигать, поворачивать или удалить'}`):activeAsset?'ЛКМ по карте — поставить · R — повернуть · Esc — отменить':'Щёлкните по объекту на карте или выберите его из списка.';
  help.querySelector('span').textContent=walkMapEditorHelp({tool,mode,hasSelection:!!selected,locked:!!selected?.locked,lockReason:selected?.lockReason||selected?.derivedWarning,protectedActionAvailable:canRequestWalkMapEditorProtectedAction(selected,'delete')});
  if(render)renderList();
 }
 function filteredItems(){const query=search.value.trim().toLocaleLowerCase('ru'),version=scope==='palette'?paletteVersion:catalogVersion,key=`${scope}\u0000${version}\u0000${category}\u0000${query}`;if(key!==filterCacheKey){filterCacheKey=key;filterCache=filterWalkMapEditorItems(scope==='palette'?palette:catalog,{category,query});}return filterCache;}
 function renderList(){
  const filtered=filteredItems(),windowed=windowWalkMapEditorItems(filtered,{limit:visibleLimit});
  list.replaceChildren();
  if(!filtered.length){const empty=doc.createElement('div');empty.className='wme-empty';empty.textContent=scope==='palette'?'Для этой категории пока нет готовых объектов.':'В этой категории пока нет объектов.';list.append(empty);return;}
  for(const item of windowed.items){const key=item.key||item.id||item.assetId,node=button(doc,'',scope==='palette'?`place:${key}`:`select:${key}`);node.className='wme-card';node.setAttribute('aria-pressed',String(scope==='palette'?activeAsset?.key===key:selected?.key===key));if(scope==='palette'&&item.available===false){node.disabled=true;node.title=item.reason||'Этот объект пока нельзя установить безопасно';node.setAttribute('aria-disabled','true')}const title=doc.createElement('strong');title.textContent=(item.locked?'🔒 ':'')+item.label;const small=doc.createElement('small');small.textContent=item.subtitle||item.reason||item.assetId||item.id||'';node.append(title,small);list.append(node)}
  if(windowed.hasMore){const more=button(doc,`Показать ещё · ${windowed.visibleCount} из ${windowed.total}`,'show-more');more.className='wme-card';more.title='Список подгружается частями, чтобы редактор не тормозил';more.setAttribute('aria-label',`Показать ещё объекты: сейчас ${windowed.visibleCount} из ${windowed.total}`);list.append(more)}
 }
 function clearActiveAsset(reason,{emit=false}={}){if(!activeAsset)return false;const asset=activeAsset;activeAsset=nextWalkMapEditorActiveAsset(activeAsset,{type:reason==='close'?'close':'cancel'});if(tool==='place')tool='select';if(emit)onAction('cancel-place',{asset,reason});return true;}
 function setOpen(value){
  open=!!value;
  if(open){priorFocus=doc.activeElement;root.hidden=false;update();panel.focus({preventScroll:true})}
  else{clearActiveAsset('close',{emit:true});if(confirm.open)confirm.close();clearTimeout(toastTimer);toast.dataset.visible='false';root.hidden=true;if(priorFocus&&!root.contains(priorFocus))priorFocus.focus?.({preventScroll:true});priorFocus=null}
  onOpenChange(open);
 }
 function showToast(message){toast.textContent=message;toast.dataset.visible='true';clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.dataset.visible='false',2600);}
 function setSaveState(value){saveState=normalizeWalkMapEditorSaveState(value);saveStatus.textContent=saveState.message;saveStatus.dataset.state=saveState.status;root.dataset.dirty=String(saveState.dirty);save.disabled=saveState.saving;save.textContent=saveState.saving?'Сохраняю…':saveState.status==='saved'?'Сохранено':'Сохранить';return saveState;}
 function setCatalogStatus(value){catalogLoadState=normalizeWalkMapEditorCatalogStatus(value);catalogStatus.hidden=['idle','ready','cancelled'].includes(catalogLoadState.status);catalogStatusText.textContent=catalogLoadState.message;catalogRetry.hidden=!catalogLoadState.retry;return catalogLoadState;}
 function requestProtected(action,item=selected){
  if(!item?.locked){onAction(action,{item});return;}
  if(!canRequestWalkMapEditorProtectedAction(item,action)){showToast(item.lockReason||item.derivedWarning||'Этот объект пока нельзя изменить безопасно');return;}
  confirm.querySelector('p').textContent=`«${item.label}» защищён от случайного изменения. Разблокировать только для этого действия?`;
  const menu=confirm.querySelector('menu');menu.replaceChildren();const cancel=button(doc,'Отмена','confirm-cancel'),accept=button(doc,'Разблокировать','confirm-accept');accept.className='wme-danger';menu.append(cancel,accept);
  cancel.onclick=()=>confirm.close();accept.onclick=()=>{confirm.close();onAction(action,{item,confirmed:true})};confirm.showModal();
 }
 function activate(action){
  if(action==='close'){setOpen(false);return;}
  if(action.startsWith('mode:')){mode=action.slice(5);onAction('mode',{mode});update({render:false});return;}
  if(action.startsWith('scope:')){scope=action.slice(6);if(scope!=='palette')clearActiveAsset('scope-change',{emit:true});visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'scope');update();return;}
  if(action.startsWith('category:')){category=action.slice(9);visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'category');onAction('catalog-category',{category});update();return;}
  if(action==='retry-catalog'){onAction('retry-catalog',{category});return;}
  if(action==='show-more'){visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'show-more');renderList();return;}
  if(action.startsWith('select:')){clearActiveAsset('selection',{emit:true});selected=catalog.find(item=>(item.key||item.id)===action.slice(7))||null;onAction('select',{item:selected});update();return;}
  if(action.startsWith('place:')){const key=action.slice(6),asset=palette.find(item=>(item.key||item.id||item.assetId)===key)||null;if(!canActivateWalkMapEditorPaletteItem(asset)){if(asset)showToast(asset.reason||'Этот объект пока нельзя установить безопасно');return;}activeAsset=nextWalkMapEditorActiveAsset(activeAsset,{type:'set',item:asset});if(activeAsset){selected=null;tool='place';onAction('place-asset',{asset:activeAsset})}update();return;}
  if(action==='cancel'){const changed=clearActiveAsset('cancel',{emit:true});if(changed)update();return;}
  if(['select','move','rotate','place','paint'].includes(action)){const cleared=action!=='place'&&clearActiveAsset('tool-change',{emit:true});tool=action;onAction('tool',{tool});update({render:!!cleared});return;}
  if(action==='delete'){requestProtected('delete');return;}
  onAction(action,{item:selected,mode,tool,category});
 }
 root.addEventListener('pointerdown',event=>event.stopPropagation());root.addEventListener('contextmenu',event=>{event.preventDefault();event.stopPropagation()});root.addEventListener('click',event=>{const node=event.target.closest?.('[data-editor-action]');if(node){event.preventDefault();activate(node.dataset.editorAction)}});
 search.addEventListener('input',()=>{visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'search');renderList()});
 setSaveState(saveState);setCatalogStatus(catalogLoadState);update();
 return {
  root,
  get open(){return open},get mode(){return mode},get tool(){return tool},get selected(){return selected},get scope(){return scope},get category(){return category},get activeAsset(){return activeAsset},get saveState(){return saveState},get catalogStatus(){return catalogLoadState},
  setOpen,toggle(){setOpen(!open)},
  setCatalog(items){catalogKeys=new Set();catalog=[];for(const item of Array.isArray(items)?items:[]){const key=item?.key||item?.id;if(typeof key!=='string'||!key||catalogKeys.has(key))continue;catalogKeys.add(key);catalog.push({...item,key})}catalogVersion++;visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'catalog');update({render:open})},
  appendCatalog(items){let added=0;for(const item of Array.isArray(items)?items:[]){const key=item?.key||item?.id;if(typeof key!=='string'||!key||catalogKeys.has(key))continue;catalogKeys.add(key);catalog.push({...item,key});added++}if(added){catalogVersion++;update({render:open})}return added},
  setPalette(items){const seen=new Set();palette=[];for(const item of Array.isArray(items)?items:[]){const key=item?.key||item?.id||item?.assetId;if(typeof key!=='string'||!key||seen.has(key))continue;seen.add(key);palette.push({...item,key})}paletteVersion++;visibleLimit=nextWalkMapEditorVisibleLimit(visibleLimit,'palette');update({render:open})},
  setSelection(item){selected=item||null;if(selected)clearActiveAsset('selection',{emit:true});update({render:open})},
  setActiveAsset(item){activeAsset=nextWalkMapEditorActiveAsset(activeAsset,{type:item?'set':'clear',item});if(activeAsset)selected=null;else if(tool==='place')tool='select';update({render:open})},cancelActiveAsset(reason='cancel'){const changed=clearActiveAsset(reason,{emit:true});if(changed)update({render:open});return changed;},
  setMode(value){if(Object.values(WALK_MAP_EDITOR_MODES).includes(value)){mode=value;update({render:false})}},
  setTool(value){if(Object.values(WALK_MAP_EDITOR_TOOLS).includes(value)){const cleared=value!=='place'&&clearActiveAsset('tool-change',{emit:true});tool=value;update({render:!!cleared&&open})}},
  setHistory({canUndo=false,canRedo=false}={}){toolbar.querySelector('[data-editor-action=undo]').disabled=!canUndo;toolbar.querySelector('[data-editor-action=redo]').disabled=!canRedo},
  setSaveState,
  setCatalogStatus,
  notify:showToast,
  confirmDelete(item=selected){requestProtected('delete',item)},
  dispose(){clearTimeout(toastTimer);confirm.close?.();root.remove()}
 };
}
