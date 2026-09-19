// Explicit local QA controls; all gameplay orders still use the normal X path.
export function createMercenaryShowcaseUI({document,parent=document.body,prepare,inspect,wound,getState}){
 const root=document.createElement('aside');root.dataset.walkHud='mercenary-showcase';root.setAttribute('aria-label','Площадка профессий');root.style.cssText='position:fixed;left:12px;top:190px;z-index:10015;max-width:290px;padding:9px;background:#192a23ee;color:#e4efdd;border:1px solid #8ca782;border-radius:6px;font:13px system-ui;pointer-events:auto';
 const button=label=>{const b=document.createElement('button');b.type='button';b.textContent=label;b.style.cssText='margin:3px;padding:6px';return b;};
 const start=button('Подготовить площадку и отряд'),view=button('Осмотреть объект'),patient=button('Подготовить раненого'),select=document.createElement('select'),status=document.createElement('p');
 select.setAttribute('aria-label','Объект профессии');for(const[value,label]of[['overview','Вся площадка'],['cage','Сетчатый забор'],['power','Электрощиток'],['safe','Сейф'],['door','Запертая дверь'],['vehicle','Машина'],['patient','Раненый боец']]){const o=document.createElement('option');o.value=value;o.textContent=label;select.append(o);}
 status.setAttribute('role','status');status.textContent='X на объекте — работа специалиста. X на земле — отмена и движение.';root.append(start,select,view,patient,status);parent.append(root);
 let disposed=false,pending=false,elapsed=0;
 async function run(fn){if(disposed||pending)return;pending=true;start.disabled=view.disabled=patient.disabled=true;try{const r=await fn();if(!disposed)status.textContent=r?.message||(r?.ok?'Готово. Наведитесь на объект и нажмите X.':r?.reason||'Не удалось подготовить площадку.');}catch(error){if(!disposed)status.textContent=error?.message||'Не удалось выполнить действие.';}finally{pending=false;if(!disposed)start.disabled=view.disabled=patient.disabled=false;}}
 start.addEventListener('click',()=>run(prepare));view.addEventListener('click',()=>run(()=>inspect(select.value)));patient.addEventListener('click',()=>run(wound));
 for(const type of['pointerdown','pointerup','mousedown','mouseup','click','wheel'])root.addEventListener(type,e=>e.stopPropagation());
 return{update(dt){elapsed+=Math.max(0,dt||0);if(!disposed&&elapsed>=1){elapsed=0;document.body.dataset.mercenaryShowcase=JSON.stringify(getState?.()||{});}},dispose(){disposed=true;root.remove();delete document.body.dataset.mercenaryShowcase;}};
}
