// Explicit local world session: one normal resident, canonical hitNpc/AI/death.
// No alternate HP, damage handler, renderer actor or persistent game state.
(() => {
  if (!['127.0.0.1', 'localhost'].includes(location.hostname) ||
      new URLSearchParams(location.search).get('npccombatqa') !== '1' ||
      typeof _LOCAL_PREVIEW === 'undefined' || !_LOCAL_PREVIEW) return;
  const panel = document.createElement('aside');
  panel.id = 'npc-combat-session';
  panel.setAttribute('aria-label', 'Проверка NPC');
  panel.style.cssText = 'position:fixed;right:12px;top:12px;z-index:10020;width:260px;padding:12px;border:1px solid #ad9564;border-radius:8px;background:#172322ee;color:#f4efe1;font:13px/1.45 system-ui;pointer-events:auto';
  const title = document.createElement('strong'), status = document.createElement('div');
  const respawn = document.createElement('button'), fold = document.createElement('button');
  title.textContent = 'Проверка NPC · локальный мир';
  status.style.cssText = 'white-space:pre-line;margin:8px 0';
  status.setAttribute('aria-live', 'polite');
  respawn.type = 'button'; respawn.textContent = 'Новый NPC передо мной';
  fold.type = 'button'; fold.textContent = 'Свернуть';
  for (const b of [respawn, fold]) b.style.cssText = 'padding:6px;margin:3px 4px 0 0;cursor:pointer';
  panel.append(title, status, respawn, fold); document.body.append(panel);
  for (const event of ['pointerdown','pointerup','mousedown','mouseup','click','keydown','keyup','wheel'])
    panel.addEventListener(event, e => e.stopPropagation());
  let target = null, originalSpeed = 0, autoAttempted = false, lastText = '', serial = 0;
  let message = 'Ожидаем загрузки города…';
  const ready = () => document.documentElement.dataset.worldWalkReady === 'first-populated-frame' &&
    typeof _walkNpcNavigationResolver === 'function';
  function place() {
    if (!ready()) { message = 'Город ещё загружается.'; return false; }
    if (myDead || myDrivingCarId || _buildingInt || _bankInt) {
      message = 'Выйдите живым героем на улицу.'; return false;
    }
    let point = null;
    // Prefer the direction the player faces. All candidates use native body
    // clearance and a clear route, so the target is not behind a wall.
    for (const distance of [1.5,2,2.5,3,4,6,8]) {
      for (const offset of [0,.25,-.25,.5,-.5,.8,-.8,1.2,-1.2,1.6,-1.6,2.2,-2.2,Math.PI]) {
        const angle = player.ang + offset;
        const r = player.r + Math.sin(angle) * distance;
        const c = player.c + Math.cos(angle) * distance;
        if (!_npcBodyPassable(r,c) || !_npcPathPassable(player.r,player.c,r,c,npcPassableForSnitch)) continue;
        if (NPCS.some(n => n !== target && !n.dead && Math.hypot(n.r-r,n.c-c)<.55)) continue;
        point={r,c}; break;
      }
      if(point) break;
    }
    if (!point) { message = 'Впереди мало места. Повернитесь к открытому тротуару и повторите.'; return false; }
    const next = spawnNpc(160000 + ++serial, {cityOnly:true});
    if (!next) { message = 'Не удалось создать жителя. Повторите.'; return false; }
    // Reuse the existing civilian archetype and model, with its normal 60 HP.
    const arc = NPC_ARCHETYPES.worker || NPC_ARCHETYPES[Object.keys(NPC_ARCHETYPES).find(k=>k!=='bandit')];
    if (arc) { next._arc=arc; next._arcKey=Object.keys(NPC_ARCHETYPES).find(k=>NPC_ARCHETYPES[k]===arc); Object.assign(next.look,arc.look||{}); }
    next.look.gender=0; next.look.swim=false;
    next.name='Проверка урона';
    Object.assign(next,point,{tr:point.r,tc:point.c,ang:Math.atan2(player.r-point.r,player.c-point.c),
      idleUntil:performance.now()+300000,_buildingVisitCooldownUntil:performance.now()+300000});
    originalSpeed=next.speed; next.speed=0;
    // The target waits for the first hit; afterwards ordinary panic, injury,
    // ambulance and death behavior are untouched.
    if(target) { const index=NPCS.indexOf(target); if(index>=0) NPCS.splice(index,1); }
    target=next; NPCS.push(target);
    delete panel.dataset.confirmedShot;delete panel.dataset.confirmedDamage;delete panel.dataset.contact;
    message='ПКМ — прицел · ЛКМ — огонь · R — перезарядка';
    return true;
  }
  respawn.addEventListener('click',()=>{place();update();});
  for(const [label,action] of [['Навести прицел','aim'],['Выстрел ЛКМ','fire'],['Перезарядить R','reload']]){
    const button=document.createElement('button');button.type='button';button.textContent=label;
    button.style.cssText='padding:6px;margin:3px 4px 0 0;cursor:pointer';
    button.onclick=()=>window.dispatchEvent(new CustomEvent('npccombatqa:input',{detail:{action,id:target?`npc_${target.id}`:null}}));panel.append(button);
  }
  const confirmed=e=>{if(String(e.detail?.npcId)!==`npc_${target?.id}`)return;panel.dataset.confirmedShot=e.detail.shotId||'';panel.dataset.confirmedDamage=String(e.detail.damage);panel.dataset.contact=JSON.stringify(e.detail.point);};
  window.addEventListener('artist14:confirmed-hit',confirmed);
  fold.addEventListener('click',()=>{status.hidden=!status.hidden;respawn.hidden=status.hidden;fold.textContent=status.hidden?'Развернуть':'Свернуть';});
  function update() {
    if (!autoAttempted && ready()) { autoAttempted=true; place(); }
    if(target && target.hp<target.max_hp && target.speed===0) target.speed=originalSpeed;
    const state=target?.dead?'Мёртв':target?._medicalDowned?'Тяжело ранен (жив)':target?'Жив':'Не создан';
    const distance=target?Math.hypot(target.r-player.r,target.c-player.c)*4.1:0;
    const actor=target?window.MafioziWalkNpcs?.getActor?.(`npc_${target.id}`):null;
    const text=target?`${target.name}: ${Math.max(0,target.hp)} / ${target.max_hp} HP\n${state} · ${distance.toFixed(1)} м\n${message}\nПри тяжёлом ранении NPC ещё жив.`:message;
    if(text!==lastText){status.textContent=text;lastText=text;}
    panel.dataset.npcId=target?.id||''; panel.dataset.hp=String(target?.hp??'');
    panel.dataset.state=state; panel.dataset.actorVisible=String(!!actor?.object?.visible);
    panel.dataset.surfaceReaction=actor?.surface?.state?.kind||'';
    panel.dataset.sourceDown=String(actor?.diagnostics?.().sourceDown===true);
    panel.dataset.bloodParticles=String(actor?.surface?.particles?.count||0);
    const bleeding=actor?.surface?.bleedingStats?.();
    panel.dataset.bleedingWounds=String(bleeding?.activeWounds||0);
    panel.dataset.bloodDrops=String(bleeding?.emittedDrops||0);
    panel.dataset.woundGroups=String(actor?.object?.getObjectByName('PersistentBulletWounds')?.children?.length||0);
    respawn.disabled=!ready();
  }
  update(); const timer=setInterval(update,250);
  window.addEventListener('pagehide',()=>{clearInterval(timer);window.removeEventListener('artist14:confirmed-hit',confirmed);},{once:true});
})();
