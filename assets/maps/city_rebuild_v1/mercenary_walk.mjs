import {createMercenarySelectionView} from './mercenary_selection_view.mjs';
import {createMercenaryBadges} from './mercenary_badges.mjs';
import {createMercenaryRecruitDialog} from './mercenary_recruit_dialog.mjs';
import {createMercenaryCommandUI} from './mercenary_command_ui.mjs';
import {createMercenaryTargets} from './mercenary_targets.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {createMercenaryChargeView} from './mercenary_charge_view.mjs';
import {createMercenarySafeBinding} from './mercenary_safe_source.mjs';
import {createMercenaryPickingProbe} from './mercenary_picking_probe.mjs';
import {createNativePickingQa} from './native_picking_qa.mjs';
import {createNpcSkinPickMemo} from './npc_skin_pick_memo.mjs';
import {createNpcSkinPickingQa} from './npc_skin_picking_qa.mjs';
import {createMercenaryActionTimers} from './mercenary_action_timers.mjs';
import {createMercenaryTaskMarkers} from './mercenary_task_markers.mjs';
import {createMercenaryActionMenu} from './mercenary_action_menu.mjs';
import {createMercenaryChatter} from './mercenary_chatter.mjs';
import {createMercenarySpeechBubble} from './mercenary_speech_bubble.mjs';

// Presentation adapter. The source host owns recruitment, inventory, HP and orders.
export function createMercenaryWalk({THREE,document,parent=document.body,camera,scene,getHost,getFleet,getTraffic,getNpcs,getBuildings,getRoots,getPickRoots,getFocus=()=>null,getHero=()=>null,canMove,groundHeight=()=>0,isBlocked=()=>false,onOpenChange=()=>{},onFollowGesture=()=>{},onExplosion=()=>{},createDamage=createVehicleDamage}){
 const trafficDamage=new Map();let host=null,chatter=null,disposed=false,talkId=null,aimElapsed=0,nextAimAt=0,diagnosticElapsed=0;const pickingStats={samples:0,lastMs:0,maxMs:0};
 const pickingQaParams=new URLSearchParams(document.defaultView?.location?.search||globalThis.location?.search||'');
 const pickingProbe=createMercenaryPickingProbe({THREE,enabled:pickingQaParams.get('perfqa')==='1'&&pickingQaParams.get('mercenarypickqa')==='1',document});
 const nativePickingQa=createNativePickingQa({document});
 const npcSkinPickingQa=createNpcSkinPickingQa({document,createMemo:()=>createNpcSkinPickMemo({THREE})});
 const trafficActor=id=>{const traffic=getTraffic();return traffic?.getActor?.(id)||traffic?.getActors?.().find(r=>String(r.id)===String(id))?.actor||null;};
 const badges=createMercenaryBadges({THREE,document,parent,scene:null,camera,getActors:getNpcs,getRoots,getOcclusionRoots:getPickRoots,getFocus,getTalkId:()=>talkId});
 const speechBubble=createMercenarySpeechBubble({THREE,document,parent,camera,getBadgeAnchor:id=>badges.getSpeakerAnchor(id),getHero,getFocus});
 const safeBinding=createMercenarySafeBinding({getHost,getRegistry:()=>globalThis.MafioziInteriorSafeTargets});
 const callbacks=target=>target.object?.userData?.mercenaryTarget||{};
 const targets=createMercenaryTargets({THREE,camera,getRoots,getPickRoots,getFleet,getTraffic,getNpcs,getBuildings,pickingProbe,skinPickingMemo:npcSkinPickingQa?.memo,getVehicleLock:id=>globalThis.MafioziMercenaryVehicleLocks?.get(id),
  onVehicleBlast(target,effect){
   if(!host)return {ok:false,reason:'Источник мира ещё загружается'};
   if(target.id.startsWith('fleet:')){
    if(host.canUseLocalEffects?.()!==true)return {ok:false,reason:'Нужно подтверждение игрового сервера'};
    const record=getFleet()?.records?.find(r=>String(r.id)===String(target.sourceId));
    if(!record?.damage||record.damage.state.wrecked)return {ok:false,reason:'Машина недоступна'};
    const applied=record.damage.blastImpact({damage:record.damage.state.maxHp*4,eventId:`mercenary:${effect.actionId}`});return applied===true||applied?.ok===true?{ok:true}:{ok:false,reason:'Взрыв отклонён машиной'};
   }
   const receipt=host.blastVehicle?.(target.sourceId,effect);
   const confirmed=value=>{
    if(value!==true&&value?.ok!==true)return value||{ok:false,reason:'Взрыв не подтверждён миром'};
    // A completed source explosion stays successful if its renderer was evicted.
    const actor=trafficActor(target.sourceId);if(disposed||!actor)return {ok:true,presentationUnavailable:true};
    const key=String(target.sourceId);let record=trafficDamage.get(key);
    if(record&&record.actor!==actor){record.damage.dispose();trafficDamage.delete(key);record=null;}
    try{if(!record){record={actor,damage:createDamage(THREE,actor,{scene,groundHeight,onExplosion})};trafficDamage.set(key,record);}
     record.damage.blastImpact({damage:record.damage.state.maxHp*4,eventId:`mercenary:${effect.actionId}`});
     return {ok:true};
    }catch{return {ok:true,presentationUnavailable:true};}
   };
   return receipt&&typeof receipt.then==='function'?Promise.resolve(receipt).then(confirmed):confirmed(receipt);
  },
  onDoorBreach(target,effect){if(host?.canUseLocalEffects?.()!==true)return {ok:false,reason:'Нужно подтверждение игрового сервера'};const breakOpen=callbacks(target).breakOpen;return typeof breakOpen==='function'?breakOpen({...effect,targetId:target.id,requestId:`mercenary:${effect.actionId}`}):{ok:false,reason:'Эту дверь нельзя выбить'};},
  onDoorBlast(target,effect){if(host?.canUseLocalEffects?.()!==true)return {ok:false,reason:'Нужно подтверждение игрового сервера'};const blast=callbacks(target).blast;return typeof blast==='function'?blast({...effect,targetId:target.id,requestId:`mercenary:${effect.actionId}`}):{ok:false,reason:'Эту дверь нельзя подорвать'};},
  onUnlock(target,effect){if(target.kind==='vehicle')return globalThis.MafioziMercenaryVehicleLocks?.unlock(target,effect)||{ok:false,reason:'Замок автомобиля недоступен'};const data=callbacks(target),unlock=data.unlock||target.object?.userData?.unlock;return typeof unlock==='function'?unlock({...effect,requestId:`mercenary:${effect.actionId}`,targetId:target.id,getOperatorPosition:id=>host?.getMember?.(id)?.position}):{ok:false,reason:'У этого замка ещё нет игрового действия'};},
  onFenceCut(target,effect){const cut=callbacks(target).cut||target.object?.userData?.cut;return typeof cut==='function'?cut({...effect,requestId:`mercenary:${effect.actionId}`}):{ok:false,reason:'Это ограждение пока нельзя разрезать'};},
  onDisablePower(target,effect){if(host?.canUseLocalEffects?.()!==true)return {ok:false,reason:'Нужно подтверждение игрового сервера'};const disable=callbacks(target).disablePower||target.object?.userData?.disablePower;return typeof disable==='function'?disable({...effect,requestId:`mercenary:${effect.actionId}`}):{ok:false,reason:'Этот электрощит пока нельзя отключить'};},
  onIntimidate(target,effect){return host?.intimidate?.(target.sourceId,effect)||{ok:false,reason:'Цель недоступна'};}
 });
 function target(id,reuseRegistry=false){const live=host?.getMember?.(id)||host?.getTarget?.(id);if(live)return live;const value=targets.get(id,{reuseRegistry});if(value?.kind==='npc'){const source=host?.getTarget?.(value.sourceId);return source?{...value,...source,id:value.id}:value;}return value;}
 function pick(){const value=targets.pick();if(!value)return null;const live=target(value.id,true);const result=live?{...value,...live,object:value.object,valid:value.valid!==false&&live.valid!==false}:value;pickingProbe?.mark('sourceResolveMs');return result;}
 const charges=createMercenaryChargeView({THREE,scene,getTarget:id=>targets.get(id),getCharges:()=>host?.getCharges?.()||[],nowSeconds:()=>Date.now()/1000});
 const actorKey=id=>String(id||'').replace(/^npc:/,'').replace(/^npc_/,'').replace(/^crew_/,'');
 const actionTimers=createMercenaryActionTimers({THREE,document,parent,camera,getHost:()=>host,getFocus,getTarget:id=>{const value=target(id);if(!value||value.object)return value;const key=actorKey(id),actor=(getNpcs()||[]).find(a=>actorKey(a.id)===key);return{...value,object:actor?.object||actor?.actor?.object};}});
 const candidate=id=>host?.getRoster?.().candidates?.find(c=>String(c.id)===String(id))||null;
 const talkPoint=new THREE.Vector3();
 function ownMember(id,cachedRow=null){const row=cachedRow||host?.getRoster?.().members?.find(m=>String(m.id)===String(id));if(!row)return null;const live=host?.getMember?.(row.id),focus=getFocus(),p=live?.position;return {...row,...live,distanceMeters:focus&&p?Math.hypot(p.x-focus.x,p.z-focus.z):Infinity};}
 function nearestOwnMember(){
  const focus=getFocus();if(!focus)return null;camera.updateWorldMatrix(true,false);const candidates=[];
  for(const row of (host?.getRoster?.().members||[]).slice(0,5)){const m=ownMember(row.id,row),p=m?.position;if(!p||m.distanceMeters>2.5||Math.abs(p.y-focus.y)>1.5||m.hp<=0||m.dead||m.downed||m.available===false||m.status==='hospital')continue;const actor=(getNpcs()||[]).find(a=>actorKey(a.id)===actorKey(m.id)),object=actor?.object||actor?.actor?.object;if(!object)continue;let visible=true;for(let n=object;n;n=n.parent)if(n.visible===false)visible=false;if(!visible)continue;talkPoint.set(p.x,p.y+1.2,p.z).project(camera);if(talkPoint.z< -1||talkPoint.z>1||Math.abs(talkPoint.x)>.72||Math.abs(talkPoint.y)>.9)continue;candidates.push({m,actor,score:Math.abs(talkPoint.x)*2+m.distanceMeters});}
  candidates.sort((a,b)=>a.score-b.score);for(const c of candidates)if(targets.hasLineOfSight(focus,c.m.position,'npc:'+c.actor.id))return {...c.m,talkActorId:c.actor.id};return null;
 }
 let conversationId=null,greetingClock=0,greetingId=null,greetingSince=0,greetingIssued=false;
 function updateGreeting(available){const selected=available?badges.stats().selectedId:null,m=selected!=null?ownMember(actorKey(selected)):null,action=m&&host?.getAction?.(m.id),eligible=m&&m.hp>0&&!m.dead&&!m.downed&&m.available!==false&&m.distanceMeters<=2.5&&!m.defending&&!host?.isDefending?.(m.id)&&(!action||['completed','cancelled'].includes(action.phase))&&badges.getSpeakerAnchor(m.id);if(!eligible){greetingId=null;greetingIssued=false;return;}if(String(m.id)!==greetingId){greetingId=String(m.id);greetingSince=greetingClock;greetingIssued=false;}if(!greetingIssued&&greetingClock-greetingSince>=.45){greetingIssued=true;host?.greetMember?.(m.id);}}

 const dialogue=createMercenaryRecruitDialog({document,parent,getCandidate:candidate,getMember:ownMember,onRecruit:id=>host?.recruit?.(id),onDismiss:id=>host?.dismiss?.(id),onClose:()=>{if(conversationId!=null)host?.endConversation?.(conversationId);conversationId=null;},onOpenChange});
 const selection=createMercenarySelectionView({THREE,scene});
 const taskMarkers=createMercenaryTaskMarkers({THREE,scene,document,parent,camera,getFocus,getRoots,getOcclusionRoots:getPickRoots,getActors:getNpcs});
 function taskRows(aimed=null){
  const rows=[],members=host?.getRoster?.().members||[];
  for(const m of members.slice(0,5)){const action=host?.getAction?.(m.id),active=action&&!['completed','cancelled'].includes(action.phase);if(active)rows.push({...action,memberName:m.name,number:1,queued:false});const queue=host?.getQueue?.(m.id)||m.queued||[];queue.slice(0,8).forEach((q,i)=>rows.push({...q,memberName:m.name,number:i+(active?2:1),queued:true}));}
  for(const a of host?.getCharges?.()||[])if(!rows.some(r=>r.targetId===a.targetId&&!r.queued))rows.push({...a,number:1,queued:false});
  rows.sort((a,b)=>Number(a.queued)-Number(b.queued)||a.number-b.number);const aimedIndex=aimed?rows.findIndex(r=>String(r.targetId)===String(aimed.id)):-1;if(aimedIndex>=10){const row=rows.splice(aimedIndex,1)[0];rows.splice(9,0,row);}const seen=new Set(),visible=[];
  for(const row of rows){const id=String(row.targetId);if(seen.has(id))continue;seen.add(id);let t=targets.get(id,{reuseRegistry:true});if(!t?.object){const source=host?.getMember?.(id)||host?.getTarget?.(id),actor=(getNpcs()||[]).find(a=>actorKey(a.id)===actorKey(id));if(source)t={...source,object:actor?.object||actor?.actor?.object};}if(!t?.object||t.valid===false)continue;visible.push({...row,target:t});if(visible.length>=10)break;}
  return visible;
 }
 let promptElapsed=.2,nearLoot=null,lootPending=false,contextPending=false;
 const commandReticle=document.createElement('span');commandReticle.setAttribute('aria-hidden','true');commandReticle.setAttribute('style','position:fixed;left:50%;top:50%;width:5px;height:5px;box-sizing:border-box;border:1px solid #fff;border-radius:50%;transform:translate(-50%,-50%);box-shadow:0 0 2px 1px #0008;pointer-events:none;z-index:9997;display:none');parent.append(commandReticle);
 const actionPrompt=document.createElement('p');actionPrompt.dataset.walkHud='mercenary-action';actionPrompt.hidden=true;actionPrompt.setAttribute('role','status');actionPrompt.setAttribute('style','position:fixed;left:50%;top:59%;transform:translateX(-50%);z-index:10003;padding:8px 14px;border:1px solid #89c49b;border-radius:5px;background:#153326eb;color:#def8df;font:600 14px system-ui;pointer-events:none;display:none');parent.append(actionPrompt);
 const actionPriority=['revive','unlock_safe','cut_fence','disable_power','breach_door','plant_bomb','unlock_door','eliminate','intimidate'];
 async function issueCommand(id,t){const result=await host?.command?.(id,t);if(!result?.queued)return result;const number=(Number(result.queuePosition)||1)+(host?.getAction?.(result.memberId)?1:0);return{...result,message:'Добавлено задание №'+number};}
 function contextActions(aimed){if(!aimed?.valid)return [];const seen=new Set();return(host?.getActions?.(aimed)||[]).filter(a=>a.enabled!==false&&a.available!==false&&!a.disabledReason).sort((a,b)=>{const rank=a=>{const i=actionPriority.indexOf(a.id||a.kind);return i<0?99:i;};return rank(a)-rank(b)||Number(a.willQueue)-Number(b.willQueue)||(a.queuedCount||0)-(b.queuedCount||0);}).filter(a=>{const id=a.id||a.kind;if(seen.has(id))return false;seen.add(id);return true;});}
 async function dispatchAction(id,t){const result=await issueCommand(id,t);if(!disposed){if(result?.ok)selection.setRally(null);ui.showNotice(result?.message||result?.reason||(result?.ok?'Приказ принят.':'Не удалось выполнить приказ.'));}return result;}
 const actionMenu=createMercenaryActionMenu({document,parent,getTarget:id=>{const t=target(id);return t&&{...t,valid:t.valid!==false};},getActions:contextActions,onChoose:dispatchAction,onOpenChange});
 function showActionPrompt(action){const visible=!!action&&!contextPending&&!actionMenu.isOpen;actionPrompt.hidden=!visible;actionPrompt.style.display=visible?'block':'none';const text=action?'X — '+(action.willQueue?'В очередь · ':'')+(action.label||action.id||action.kind):'';if(actionPrompt.textContent!==text)actionPrompt.textContent=text;}
 const lootPosition=new THREE.Vector3(),lootPrompt=document.createElement('p');lootPrompt.dataset.walkHud='mercenary-loot';lootPrompt.hidden=true;lootPrompt.setAttribute('role','status');lootPrompt.setAttribute('style','position:fixed;left:50%;bottom:18%;transform:translateX(-50%);z-index:10003;padding:8px 14px;background:#242224e8;color:#f0cf83;font:14px system-ui;pointer-events:none');parent.append(lootPrompt);
 function findNearbyLoot(){const focus=getFocus();if(!focus)return null;let best=null,bestDistance=9;for(const loot of globalThis.MafioziInteriorSafeTargets?.getLootTargets?.()||[]){const state=typeof loot.state==='function'?loot.state():loot.state;if(!state?.opened||state.collected||state.opening||!loot.object||typeof loot.collect!=='function')continue;const position=loot.object.getWorldPosition?.(lootPosition)||loot.object.position;if(!position||Math.abs(position.y-focus.y)>1.8)continue;const distance=(position.x-focus.x)**2+(position.z-focus.z)**2;if(distance<=bestDistance){best=loot;bestDistance=distance;}}return best;}
 function collectNearbyLoot(){const loot=findNearbyLoot();if(!loot)return false;if(lootPending)return true;lootPending=true;Promise.resolve().then(()=>loot.collect({kind:'player_collect'})).then(result=>{if(!disposed)ui.showNotice(result?.ok?'Подобран мешок с деньгами'+(Number.isFinite(result.gained)?' · $'+result.gained:''):result?.reason||result?.message||'Не удалось подобрать деньги.');},error=>{if(!disposed)ui.showNotice(error?.message||'Не удалось подобрать деньги.');}).finally(()=>{lootPending=false;nearLoot=null;lootPrompt.hidden=true;});return true;}
 function updateAimSelection(){
  const nativeSample=nativePickingQa?.begin();
  const skinSample=npcSkinPickingQa?.begin();
  const pickStarted=performance.now();pickingProbe?.begin(pickStarted);let blocked=false,failed=true,sampledTargetId=null;
  try{
   const canPick=!isBlocked()&&!ui.isOpen&&!dialogue.isOpen&&!actionMenu.isOpen;blocked=!canPick;pickingProbe?.mark('guardAndRosterMs');
   const aimed=actionMenu.isOpen?target(actionMenu.targetId):canPick?pick():null;pickingStats.lastMs=performance.now()-pickStarted;pickingStats.maxMs=Math.max(pickingStats.maxMs,pickingStats.lastMs);pickingStats.samples++;
   sampledTargetId=aimed?.id??null;
   const working=aimed?.valid&&(host?.getRoster?.().members||[]).some(member=>{const action=host?.getAction?.(member.id);return action&&String(action.targetId)===String(aimed.id)&&(action.armed||['working','awaiting','retreat','countdown'].includes(action.phase));});
   const completed=aimed&&(aimed.opened||aimed.cut||aimed.kind==='safe'&&aimed.locked===false||aimed.kind==='power_panel'&&(aimed.disabled||aimed.powered===false));
   const marked=taskMarkers.sync(taskRows(aimed),aimed?.valid&&!completed?aimed:null);
   commandReticle.style.display=canPick?'block':'none';selection.setTarget(aimed?.valid&&!completed&&!marked.has(String(aimed.id))?{...aimed,working}:null);const actions=completed?[]:contextActions(aimed);showActionPrompt(actions.length>1?{label:'Выбрать действие'}:actions[0]);pickingProbe?.mark('hostActionsAndSelectionMs');failed=false;
  }finally{const ended=nativeSample||skinSample?performance.now():0;pickingProbe?.finish({blocked,failed});nativePickingQa?.finish(nativeSample,{started:pickStarted,ended,blocked,failed});npcSkinPickingQa?.finish(skinSample,{started:pickStarted,ended,blocked,failed,targetId:sampledTargetId});}
 }
 const ui=createMercenaryCommandUI({document,parent,getTarget:pick,getRoster:()=>host?.getRoster?.()||{members:[],candidates:[],weapons:[]},getActions:t=>host?.getActions?.(target(t.id)||t)||[],
  onFollow:()=>{const result=host?.follow?.();if(result?.ok){selection.setRally(null);onFollowGesture();}return result;},getActiveCommand:()=>{for(const m of host?.getRoster?.().members||[]){const a=host?.getAction?.(m.id);if(a)return {...a,memberId:m.id,cancelable:!a.armed&&a.phase!=='awaiting'};}return null;},onCancel:a=>host?.cancelCommand?.(a.memberId),onCommand:(id,t)=>issueCommand(id,target(t.id)||t),onEquip:(id,weapon)=>host?.equip?.(id,weapon),onUpgrade:(id,skill)=>host?.upgrade?.(id,skill),onDismiss:id=>host?.dismiss?.(id),isBlocked:()=>isBlocked()||dialogue.isOpen||actionMenu.isOpen,onOpenChange});
 function update(dt=0){
  if(disposed)return;const next=getHost();if(next&&next!==host){chatter?.dispose();host=next;chatter=createMercenaryChatter({host,document,window:document.defaultView||globalThis.window,onCaption:line=>speechBubble.setLine(line)});host.bindTargets({get:id=>targets.get(id),performEffect:e=>targets.performEffect(e),canMove,groundHeight,playerPosition:()=>getFocus(),hasLineOfSight:(from,to,id)=>targets.hasLineOfSight(from,to,id)});}
  greetingClock+=Math.max(0,dt);ui.update();dialogue.update();actionMenu.update(dt);chatter?.update();promptElapsed+=Math.max(0,dt);
  if(promptElapsed>=.2){promptElapsed=0;const available=!isBlocked()&&!ui.isOpen&&!dialogue.isOpen&&!actionMenu.isOpen;nearLoot=available&&!lootPending?findNearbyLoot():null;lootPrompt.hidden=!nearLoot;if(nearLoot&&lootPrompt.textContent!=='E — поднять мешок с деньгами')lootPrompt.textContent='E — поднять мешок с деньгами';const own=available&&!nearLoot?nearestOwnMember():null,id=own?.id||(available&&!nearLoot&&host?.nearestCandidate?.()),person=own||(id?candidate(id):null);talkId=person?(own?.talkActorId||id):null;updateGreeting(available&&!nearLoot);}
  aimElapsed+=Math.max(0,dt);const aimNow=performance.now();if(aimNow>=nextAimAt||aimElapsed>=.12){aimElapsed=0;nextAimAt=aimNow+120;updateAimSelection();}diagnosticElapsed+=Math.max(0,dt);if(diagnosticElapsed>=1){diagnosticElapsed=0;if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryPicking=JSON.stringify(pickingStats);}
  charges.update();if(!isBlocked())safeBinding.update();for(const [id,record]of trafficDamage){if(trafficActor(id)!==record.actor){record.damage.dispose();trafficDamage.delete(id);continue;}record.damage.update(Math.min(.1,Math.max(0,dt)));}
 }
 async function commandAtAim(){
  if(contextPending)return;contextPending=true;
  try{
   // Resolve again at the actual key press: never dispatch an old hover target.
   const aimed=pick();
   if(aimed){const actions=contextActions(aimed);if(!actions.length){ui.showNotice('Нет свободного специалиста для этого объекта.');return;}if(actions.length>1){actionMenu.open(aimed);return;}const action=actions[0];await dispatchAction(action.id||action.kind,aimed);return;}
   const point=targets.pickGround?.();const result=point&&await host?.rally?.(point);if(disposed)return;if(result?.ok){selection.setRally(point);ui.showNotice('Точка сбора назначена · '+result.count+' бойцов');}else ui.showNotice(result?.reason||'Посмотри на свободную землю для точки сбора');
  }catch(error){if(!disposed)ui.showNotice(error?.message||'Не удалось выполнить приказ.');}
  finally{contextPending=false;if(!disposed)updateAimSelection();}
 }
 function keydown(e){if(e.code==='KeyX'&&!e.repeat&&!e.defaultPrevented&&!isBlocked()&&!ui.isOpen&&!dialogue.isOpen&&!actionMenu.isOpen){const path=e.composedPath?.()||[e.target];if(path.some(n=>n?.isContentEditable||/INPUT|SELECT|TEXTAREA/.test(n?.tagName||'')))return;e.preventDefault();e.stopImmediatePropagation?.();void commandAtAim();return;}if(e.code!=='KeyE'||e.repeat||e.defaultPrevented||isBlocked()||ui.isOpen||dialogue.isOpen||actionMenu.isOpen)return;const path=e.composedPath?.()||[e.target];if(path.some(n=>n?.isContentEditable||/INPUT|SELECT|TEXTAREA/.test(n?.tagName||'')))return;
  if(collectNearbyLoot()){e.preventDefault();e.stopImmediatePropagation?.();return;}const own=nearestOwnMember(),id=own?.id||host?.nearestCandidate?.();if(id){e.preventDefault();e.stopImmediatePropagation?.();talkId=null;const receipt=host?.beginConversation?.(id);if(receipt!==false&&receipt?.ok!==false){conversationId=id;if(!(own?dialogue.openMember(id):dialogue.open(id))){host?.endConversation?.(id);conversationId=null;}}else ui.showNotice(receipt?.message||receipt?.reason||'Разговор сейчас недоступен.');}
 }
 document.addEventListener('keydown',keydown,true);
 return {openMember(id){const key=String(id).replace(/^npc:/,'').replace(/^(npc_crew_|crew_)/,'');if(getHost()!==host)update(0);const member=host?.getRoster?.().members?.find(m=>String(m.id)===key);let reason=disposed?'disposed':!member?'member-missing':isBlocked()?'game-blocked':null;if(!reason){actionMenu.close();dialogue.close();talkId=null;if(ui.openMember(member.id)!==true)reason='ui-blocked';}if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryMemberOpen=JSON.stringify({id,key,reason,ok:!reason});if(reason)ui.showNotice('Сейчас карточка бойца недоступна. Закройте другие окна и попробуйте снова.');return !reason;},update,updatePresentation:dt=>{badges.update(dt);speechBubble.update();selection.update(dt);taskMarkers.update(dt);actionTimers.updatePresentation(dt);},targets,ui,dialogue,actionMenu,badges,speechBubble,selection,taskMarkers,get chatter(){return chatter;},interrupt(){commandReticle.style.display="none";actionMenu.close();dialogue.close();ui.close();talkId=null;nearLoot=null;lootPrompt.hidden=true;showActionPrompt(null);selection.setTarget(null);taskMarkers.clear();selection.setRally(null);},get isOpen(){return ui.isOpen||dialogue.isOpen||actionMenu.isOpen;},dispose(){if(disposed)return;disposed=true;document.removeEventListener('keydown',keydown,true);actionMenu.dispose();chatter?.dispose();speechBubble.dispose();ui.dispose();dialogue.dispose();lootPrompt.remove();actionPrompt.remove();commandReticle.remove();badges.dispose();selection.dispose();taskMarkers.dispose();safeBinding.dispose();charges.dispose();actionTimers.dispose();targets.dispose();pickingProbe?.dispose();nativePickingQa?.dispose();npcSkinPickingQa?.dispose();for(const r of trafficDamage.values())r.damage.dispose();trafficDamage.clear();host?.bindTargets?.(null);}};
}
