// Explicit local QA only: invites one existing eligible resident; never grants recruits/items.
(function(){
 if(!['localhost','127.0.0.1','[::1]'].includes(location.hostname)||new URL(location.href).searchParams.get('mercenaryqa')!=='1')return;
 const root=document.createElement('div');root.id='mercenary-qa';root.style.cssText='position:fixed;left:330px;top:110px;z-index:10003;padding:8px;max-width:320px;background:#30262ef2;color:#eee6d7;border:1px solid #ad9360;font:12px system-ui;pointer-events:auto';
 const select=document.createElement('select');select.setAttribute('aria-label','Профессия для проверки');
 for(const[id,label]of [['medic','Медик'],['bruiser','Громила'],['safecracker','Медвежатник'],['engineer','Электрик-резчик'],['demolitions','Подрывник']]){const option=document.createElement('option');option.value=id;option.textContent=label;select.append(option);}
 const button=document.createElement('button');button.type='button';button.textContent='Проверка: пригласить специалиста';const status=document.createElement('p');status.setAttribute('role','status');
 button.addEventListener('click',()=>{const result=window.MafioziMercenaries?.qaInvite?.(select.value);status.textContent=result?.message||result?.reason||'Источник мира ещё загружается';});
 root.addEventListener('pointerdown',e=>e.stopPropagation());root.append(select,button,status);document.body.append(root);
})();
