// Opt-in QA controls only. The host maps these callbacks to its real input path.
// No second vehicle simulation, synthetic DOM keys or hidden production controls.
export function initCarPhysicsQa({document,onInput,onRelease,onReset,onEntryHold}){
 if(!document?.body||![onInput,onRelease,onReset,onEntryHold].every(fn=>typeof fn==='function'))throw Error('Car QA requires document and input callbacks');
 const view=document.defaultView,timers=view||globalThis;
 const panel=document.createElement('section');panel.id='car-physics-qa';
 panel.setAttribute('aria-label','Проверка физики машины');
 panel.style.cssText='position:absolute;left:12px;bottom:100px;z-index:20;max-width:430px;display:flex;flex-wrap:wrap;gap:6px;padding:10px;border-radius:10px;background:#172b2eed;color:#f6ead0;font:12px system-ui;pointer-events:auto';
 const status=document.createElement('span');status.setAttribute('role','status');status.setAttribute('aria-live','polite');status.style.cssText='flex-basis:100%';status.textContent='Проверка машины · готово';panel.append(status);
 let timer=null,disposed=false;const listeners=[];
 function release(message='Действие завершено'){
  if(timer!==null){timers.clearTimeout(timer);timer=null}
  onRelease();onEntryHold(false);status.textContent=message;
 }
 function timed(label,milliseconds,start){
  release();status.textContent=label;
  try{start();timer=timers.setTimeout(()=>{timer=null;if(!disposed)release()},milliseconds)}
  catch(error){release('Ошибка действия');throw error}
 }
 function button(label,action){
  const element=document.createElement('button');element.type='button';element.textContent=label;element.setAttribute('aria-label',label);
  element.style.cssText='padding:7px 9px;border:1px solid #b5a77d;border-radius:6px;background:#efe1bf;color:#203135;cursor:pointer';
  const click=()=>{if(!disposed)action()};element.addEventListener('click',click);listeners.push([element,'click',click]);panel.append(element);return element;
 }
 const buttons={
  reset:button('QA: сбросить машину',()=>{release('Машина сброшена');onReset()}),
  accelerate:button('QA: газ 3 секунды',()=>timed('Газ · 3 с',3000,()=>onInput({forward:true}))),
  brake:button('QA: тормоз 1 секунду',()=>timed('Тормоз · 1 с',1000,()=>onInput({reverse:true}))),
  handbrake:button('QA: поворот и ручник 1 секунду',()=>timed('Поворот влево + ручник · 1 с',1000,()=>onInput({left:true,handbrake:true}))),
  shortEntry:button('QA: короткое E 0,2 секунды',()=>timed('Короткое E · 0,2 с',200,()=>onEntryHold(true))),
  entryExit:button('QA: сесть или выйти — E 0,7 секунды',()=>timed('Посадка / выход · E 0,7 с',700,()=>onEntryHold(true))),
  release:button('QA: отпустить управление',()=>release('Управление отпущено')),
 };
 const blur=()=>release('Проверка остановлена: окно неактивно');
 const visibility=()=>{if(document.hidden)release('Проверка остановлена: вкладка скрыта')};
 if(view){view.addEventListener('blur',blur);listeners.push([view,'blur',blur])}
 document.addEventListener('visibilitychange',visibility);listeners.push([document,'visibilitychange',visibility]);
 document.body.append(panel);
 return{panel,status,buttons,dispose(){if(disposed)return;disposed=true;release('Проверка закрыта');for(const [target,event,listener]of listeners)target.removeEventListener(event,listener);panel.remove()}};
}
