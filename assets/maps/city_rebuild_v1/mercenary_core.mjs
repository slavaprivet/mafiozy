/** Specialist progression and commands. No scene, HP, money, or gang ownership here.
 * Adapter positions/distances use world metres; now() and all durations use seconds.
 * Balance is provisional and may be overridden with options.balance.
 */
export {createMercenaryRoutePlanner} from './mercenary_route.mjs';
export {createMercenaryLongFollow} from './mercenary_long_follow.mjs';
export {createMercenarySafePlacement,advanceMercenarySafeDrop,createMercenaryCatchup} from './mercenary_catchup.mjs';
export const MERCENARY_PROFESSIONS = Object.freeze({
  medic: {name:'Медик',hpMultiplier:1,meleeMultiplier:1,skills:['medicine','fitness'],actions:['revive']},
  bruiser: {name:'Громила',hpMultiplier:1.65,meleeMultiplier:1.8,skills:['intimidation','melee','fitness'],actions:['intimidate','breach_door']},
  safecracker: {name:'Медвежатник',hpMultiplier:1,meleeMultiplier:1,skills:['lockpicking','fitness'],actions:['unlock_safe','unlock_door']},
  engineer: {name:'Электрик-резчик',hpMultiplier:1,meleeMultiplier:1,skills:['cutting','fitness'],actions:['cut_fence','disable_power']},
  demolitions: {name:'Подрывник',hpMultiplier:1.1,meleeMultiplier:1,skills:['explosives','fitness'],actions:['plant_bomb']},
});
const ACTIONS = {
  revive:{profession:'medic',skill:'medicine',duration:4,range:1.6,cooldown:12},
  intimidate:{profession:'bruiser',skill:'intimidation',duration:2.5,range:2,cooldown:8},
  breach_door:{profession:'bruiser',skill:'melee',duration:2.5,range:1.5,cooldown:3,noiseRadius:12},
  unlock_safe:{profession:'safecracker',skill:'lockpicking',duration:8,range:1.5,cooldown:2},
  unlock_door:{profession:'safecracker',skill:'lockpicking',duration:5,range:1.5,cooldown:2},
  cut_fence:{profession:'engineer',skill:'cutting',duration:6,range:1.5,cooldown:2},
  disable_power:{profession:'engineer',skill:'cutting',duration:5,range:1.5,cooldown:2},
  plant_bomb:{profession:'demolitions',skill:'explosives',duration:4,range:2,cooldown:20,noiseRadius:40},
};
const finite=(v,f=0)=>Number.isFinite(v)?v:f;
const point=o=>o?.position;
const distance=(a,b)=>point(a)&&point(b)?Math.hypot(a.position.x-b.position.x,(a.position.y||0)-(b.position.y||0),a.position.z-b.position.z):Infinity;
const alive=m=>m&&m.available!==false&&!m.dead&&!m.downed&&m.hp>0;
const acknowledged=result=>result===true||result?.ok===true;
function validTarget(kind,t){
  if(!t||t.valid===false||!point(t)||!Number.isFinite(t.position.x)||!Number.isFinite(t.position.z))return false;
  if(kind==='revive')return ['npc','player'].includes(t.kind)&&t.revivable!==false&&(t.downed||t.dead||t.hp<=0);
  if(kind==='intimidate')return t.kind==='npc'&&!t.dead&&!t.downed&&t.hp>0&&t.intimidatable!==false;
  if(kind==='breach_door')return t.kind==='door'&&t.locked===true&&!t.opened&&!t.destroyed&&t.breachable===true;
  if(kind==='unlock_safe')return t.kind==='safe'&&t.locked===true&&!t.opened;
  if(kind==='unlock_door')return t.locked===true&&(t.kind==='door'&&!t.opened&&t.lockpickable!==false||t.kind==='vehicle'&&t.lockpickable!==false);
  if(kind==='cut_fence')return t.kind==='fence'&&t.cuttable!==false&&!t.cut;
  if(kind==='disable_power')return t.kind==='power_panel'&&t.powered===true&&!t.disabled;
  return kind==='plant_bomb'&&!t.destroyed&&(t.kind==='vehicle'&&t.bombable!==false||t.kind==='door'&&t.locked===true&&!t.opened&&t.bombable===true);
}

export function createMercenarySquad(options={}){
  const {getMember=()=>null,getTarget=()=>null,moveMember=()=>{},performEffect=()=>false,
    now=()=>Date.now()/1000,onAction=()=>{},scanReviveTargets=()=>[],canAutoRevive=()=>true,canStartQueued=()=>true,allowQaPatientReset=()=>false}=options;
  const balance={maxMembers:5,maxQueued:8,approachTimeout:40,blockedTimeout:10,bombFuse:6,retreatDistance:8,autoMedicInterval:0.5,hospitalDuration:300,reviveGrace:20,...options.balance};
  const roster=new Map(),actions=new Map(),settledActionIds=new Set();
  let lastScan=-Infinity,sequence=0;
  const copy=v=>JSON.parse(JSON.stringify(v));
  const result=(ok,reason,extra={})=>({ok,reason,...extra});
  function workRange(kind,target){const limit=balance[kind]?.range??ACTIONS[kind].range;return Number.isFinite(target?.workRange)?Math.min(limit,Math.max(.05,target.workRange)):limit;}
  function stats(id){
    const r=roster.get(id);if(!r)return null;
    const p=MERCENARY_PROFESSIONS[r.profession];
    return {hpMultiplier:p.hpMultiplier*(1+0.08*(r.skills.fitness||0)),meleeMultiplier:p.meleeMultiplier*(1+0.12*(r.skills.melee||0)),
      skillLevel:{...r.skills},level:r.level,reviveFraction:Math.min(.8,.35+.05*(r.skills.medicine||0))};
  }
  function addXP(id,amount){
    const r=roster.get(id);if(!r||!Number.isFinite(amount)||amount<=0)return false;
    r.xp+=Math.floor(amount);
    const level=Math.min(20,1+Math.floor(r.xp/100));
    if(level>r.level){r.skillPoints+=level-r.level;r.level=level;}
    return true;
  }
  function recruit({id,profession,name=''}){
    if(typeof id!=='string'||!id||!Object.hasOwn(MERCENARY_PROFESSIONS,profession))return result(false,'invalid_member');
    if(roster.has(id)||actions.has(id))return result(false,'already_recruited');
    if(roster.size>=balance.maxMembers)return result(false,'squad_full');
    roster.set(id,{id,profession,name:String(name).slice(0,100),xp:0,level:1,skillPoints:0,
      skills:Object.fromEntries(MERCENARY_PROFESSIONS[profession].skills.map(s=>[s,0])),cooldowns:{},status:'active',hospitalUntil:0,downedAt:null,weapon:null,queued:[]});
    return result(true,'recruited');
  }
  function upgrade(id,skill){
    const r=roster.get(id);
    if(!r||!Object.hasOwn(r.skills,skill))return result(false,'invalid_skill');
    if(r.skillPoints<1||r.skills[skill]>=5)return result(false,'upgrade_unavailable');
    r.skillPoints--;r.skills[skill]++;return result(true,'upgraded');
  }
  function updateContact(a,t){for(const key of ['workPoint','workNormal','supportPoint']){const p=t?.[key];if(p&&[p.x,p.y,p.z].every(Number.isFinite))a[key]={x:p.x,y:p.y,z:p.z};else delete a[key];}}
  // Track the vehicle's real contact point, including rotation. An unarmed
  // charge needs a continuous stationary work interval, not drive-by progress.
  function movingBombTarget(a,t,time){
    if(a.kind!=='plant_bomb'||t.kind!=='vehicle')return false;
    const p=t.workPoint||t.center||t.position,previous=a.vehicleSample;
    let moving=t.moving===true||Math.abs(finite(t.speed))>.12;
    if(previous&&time>previous.at){const travel=Math.hypot(p.x-previous.x,(p.y||0)-previous.y,p.z-previous.z);moving ||= travel>.015&&travel/(time-previous.at)>.12;}
    a.vehicleSample={x:p.x,y:p.y||0,z:p.z,at:time};
    if(moving)a.vehicleMovingUntil=time+.3;
    return moving||time<(a.vehicleMovingUntil||0);
  }
  function publish(a){if(a.detached)return;onAction(a.memberId,{kind:a.kind,phase:a.phase,progress:a.progress||0,targetId:a.targetId,startedAt:a.phaseStartedAt,duration:a.phase==='retreat'||a.phase==='countdown'?balance.bombFuse:a.duration,waitingForSafety:!!a.waitingForSafety,...(a.workPoint?{workPoint:{...a.workPoint}}:{}),...(a.workNormal?{workNormal:{...a.workNormal}}:{}),...(a.supportPoint?{supportPoint:{...a.supportPoint}}:{})});}
  function finish(a,reason,completed=false){
    if(actions.get(a.memberId)!==a)return result(false,'stale_request');
    actions.delete(a.memberId);if(['cancelled','damaged','member_unavailable','hospitalized'].includes(reason))clearQueue(a.memberId);
    if(!a.detached){moveMember(a.memberId,null,{phase:'stop',stopDistance:0});
    onAction(a.memberId,{kind:a.kind,phase:completed?'completed':'cancelled',progress:completed?1:0,targetId:a.targetId,startedAt:now(),duration:0,reason});}
    if(completed){addXP(a.memberId,25);const r=roster.get(a.memberId);if(r)r.cooldowns[a.kind]=now()+a.cooldown;}
    return result(completed,reason);
  }
  const competing=(a,kind,t,targetId=t.id)=>a.targetId===targetId&&(a.kind===kind||t.kind==='door'&&['unlock_door','breach_door','plant_bomb'].includes(a.kind)&&['unlock_door','breach_door','plant_bomb'].includes(kind));
  const queuedEntries=r=>r.resumeWork?[r.resumeWork,...r.queued]:r.queued;
  const targetBusy=(kind,t,targetId=t.id)=>[...actions.values()].some(a=>competing(a,kind,t,targetId))||[...roster.values()].some(r=>queuedEntries(r).some(a=>competing(a,kind,t,targetId)));
  function clearQueue(id){const r=roster.get(id);if(!r)return 0;const count=r.queued.length+(r.resumeWork?1:0);r.queued=[];delete r.resumeWork;delete r.queueHp;return count;}
  function command(memberId,kind,targetId,{fromQueue=false}={}){
    const r=roster.get(memberId),def=ACTIONS[kind],m=getMember(memberId),t=getTarget(targetId),time=now();
    if(!r||!def||r.profession!==def.profession)return result(false,'wrong_profession');
    if(!alive(m)||r.status==='hospital')return result(false,'member_unavailable');
    if(typeof targetId!=='string'||!validTarget(kind,t)||targetId===memberId||(kind==='revive'&&roster.get(targetId)?.status==='hospital'))return result(false,'invalid_target');
    const active=actions.get(memberId);if(active?.kind===kind&&active.targetId===targetId)return result(false,'busy');
    if(targetBusy(kind,t,targetId))return result(false,'target_busy');
    if(!fromQueue&&(actions.has(memberId)||r.queued.length||r.resumeWork||(r.cooldowns[kind]||0)>time||!canStartQueued(memberId))){
      if(r.queued.length>=balance.maxQueued)return result(false,'queue_full');
      r.queued.push({kind,targetId,queuedAt:time});if(!Number.isFinite(r.queueHp))r.queueHp=m.hp;
      return result(true,'queued',{queued:true,queuePosition:r.queued.length,memberId});
    }
    if(actions.has(memberId))return result(false,'busy');
    if((r.cooldowns[kind]||0)>time)return result(false,'cooldown');
    const a={id:++sequence,memberId,targetId,kind,phase:'approach',progress:0,startedAt:time,phaseStartedAt:time,lastProgressAt:time,
      bestDistance:distance(m,t),duration:(balance[kind]?.duration??def.duration)/(1+.12*(r.skills[def.skill]||0)),
      range:workRange(kind,t),cooldown:balance[kind]?.cooldown??def.cooldown,armed:false,effectApplied:false,lastHp:m.hp};
    updateContact(a,t);actions.set(memberId,a);publish(a);return result(true,'accepted',{actionId:a.id});
  }
  function apply(a,target){
    if(a.effectApplied||settledActionIds.has(a.id))return false;a.effectApplied=true;
    settledActionIds.add(a.id);
    if(settledActionIds.size>4096)settledActionIds.delete(settledActionIds.values().next().value);
    try{
      const receipt=performEffect({kind:a.kind,memberId:a.memberId,targetId:a.targetId,target,member:getMember(a.memberId),stats:stats(a.memberId),actionId:a.id,requestId:a.id,...(ACTIONS[a.kind]?.noiseRadius?{noiseRadius:balance[a.kind]?.noiseRadius??ACTIONS[a.kind].noiseRadius}:{})});
      if(receipt&&typeof receipt.then==='function'){
        a.phase='awaiting';a.progress=1;a.phaseStartedAt=now();a.awaiting=true;publish(a);
        Promise.resolve(receipt).then(value=>resolvePending(a.id,value),()=>resolvePending(a.id,false));
        return null;
      }
      return acknowledged(receipt);
    }
    catch{return false;}
  }
  function resolvePending(requestId,receipt){
    const a=[...actions.values()].find(a=>a.id===requestId&&a.awaiting);
    if(!a)return result(false,'unknown_request');
    const ok=acknowledged(receipt);a.awaiting=false;
    return finish(a,ok?'completed':'effect_rejected',ok);
  }
  function update(){
    const time=now();
    for(const r of roster.values()){
      const m=getMember(r.id);
      if(r.status==='hospital'){
        if(time>=r.hospitalUntil&&time>=(r.lifecycleRetryAt||0)){
          r.lifecycleRetryAt=time+1;
          // Adapter restores HP at hospital; ordinary navigation brings the member back.
          let ok=false;try{ok=acknowledged(performEffect({kind:'discharge',memberId:r.id,member:m,stats:stats(r.id)}));}catch{}
          if(ok){r.status='returning';r.hospitalUntil=0;r.downedAt=null;}
        }
        continue;
      }
      if(!m){clearQueue(r.id);continue;}
      if(queuedEntries(r).length){if(!alive(m)||Number.isFinite(r.queueHp)&&m.hp<r.queueHp)clearQueue(r.id);else r.queueHp=m.hp;}
      if(m.dead||m.downed||m.hp<=0){
        if(r.downedAt===null)r.downedAt=time;
        r.status='downed';
        const qaRescueUntil=Number.isFinite(m.qaRescueUntil)?Math.min(r.downedAt+600,Math.max(0,m.qaRescueUntil)):0;
        if((m.deathConfirmed||(m.dead&&!m.downed)||(time-r.downedAt>=balance.reviveGrace&&time>=qaRescueUntil))&&time>=(r.lifecycleRetryAt||0)){
          r.lifecycleRetryAt=time+1;
          let ok=false;const hospitalUntil=time+balance.hospitalDuration;
          try{ok=acknowledged(performEffect({kind:'hospitalize',memberId:r.id,member:m,hospitalUntil}));}catch{}
          if(ok){r.status='hospital';r.hospitalUntil=hospitalUntil;if(actions.has(r.id)&&!actions.get(r.id).armed&&!actions.get(r.id).awaiting)finish(actions.get(r.id),'hospitalized');}
        }
      }else{r.downedAt=null;if(r.status==='downed')r.status='active';if(r.status==='returning'&&m.followArrived)r.status='active';}
    }
    for(const a of [...actions.values()]){
      if(a.awaiting)continue; // Request already sent; source receipt owns the outcome.
      const m=getMember(a.memberId),t=getTarget(a.targetId);
      updateContact(a,t);
      if(!validTarget(a.kind,t)){finish(a,'target_invalid');continue;}
      // Once attached, C4 follows this target identity and its fuse survives operator death.
      if(a.armed){
        const elapsed=time-a.armedAt;a.progress=Math.min(1,elapsed/Math.max(.001,a.detonateAt-a.armedAt));
        // Vehicle approach points lie beside the body: safety is measured from
        // the actual blast centre. A live operator never triggers from danger.
        const origin=t.center&&Number.isFinite(t.center.x)&&Number.isFinite(t.center.z)?t.center:t.position;
        const safeDistance=Math.max(balance.retreatDistance,finite(t.blastRadius)+1);
        const unsafe=!a.detached&&alive(m)&&Math.hypot(m.position.x-origin.x,m.position.z-origin.z)<safeDistance;
        a.waitingForSafety=unsafe&&time>=a.detonateAt;
        if(time>=a.detonateAt&&!unsafe){const ok=apply(a,t);if(ok!==null)finish(a,ok?'completed':'effect_rejected',ok);continue;}
        // Dismissal leaves the charge running but releases control of its operator.
        if(a.detached){a.phase='countdown';continue;}
        if(unsafe){
          a.phase='retreat';
          const dx=m.position.x-origin.x,dz=m.position.z-origin.z,len=Math.hypot(dx,dz)||1,goalDistance=safeDistance+1;
          moveMember(a.memberId,{id:a.targetId,position:{x:origin.x+(dx||(!dz?1:0))/len*goalDistance,y:m.position.y||0,z:origin.z+dz/len*goalDistance}},{phase:'retreat',stopDistance:.5});
        }else{a.phase='countdown';moveMember(a.memberId,null,{phase:'stop',stopDistance:0});}
        publish(a);continue;
      }
      if(!alive(m)){finish(a,'member_unavailable');continue;}
      if(Number.isFinite(a.lastHp)&&m.hp<a.lastHp){finish(a,'damaged');continue;}a.lastHp=m.hp;
      const pursueVehicle=a.kind==='plant_bomb'&&t.kind==='vehicle',vehicleMoving=movingBombTarget(a,t,time);
      a.range=workRange(a.kind,t);const d=distance(m,t);if(m.approachMoving||m.approachSearching)a.lastProgressAt=time;
      if(d>a.range||vehicleMoving){
        if(a.phase!=='approach'){a.phase='approach';a.phaseStartedAt=time;a.progress=0;a.bestDistance=d;a.lastProgressAt=time;}
        if(d<a.bestDistance-.1){a.bestDistance=d;a.lastProgressAt=time;}
        if(!pursueVehicle&&(time-a.startedAt>balance.approachTimeout||time-a.lastProgressAt>balance.blockedTimeout)){finish(a,'path_timeout');continue;}
        // The source walks in XZ while arrival is measured in 3D. Reserve the
        // vertical component before choosing the horizontal stopping radius.
        const heightDelta=(m.position.y||0)-(t.position.y||0),horizontalRange=Math.sqrt(Math.max(0,a.range*a.range-heightDelta*heightDelta));
        moveMember(a.memberId,t,{phase:'approach',stopDistance:horizontalRange*.85});publish(a);continue;
      }
      if(a.phase==='approach'){a.phase='working';a.phaseStartedAt=time;if(a.kind!=='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});}
      // Intimidation keeps ordinary physical locomotion while its target walks.
      // Work still requires the existing full 3D range check on every update.
      if(a.kind==='intimidate'){
        const heightDelta=(m.position.y||0)-(t.position.y||0),horizontalRange=Math.sqrt(Math.max(0,a.range*a.range-heightDelta*heightDelta));
        moveMember(a.memberId,t,{phase:'approach',stopDistance:horizontalRange*.6});
      }
      a.progress=Math.min(1,(time-a.phaseStartedAt)/a.duration);
      if(a.progress<1){publish(a);continue;}
      if(a.kind==='plant_bomb'){a.armed=true;a.armedAt=time;a.detonateAt=time+balance.bombFuse;a.phaseStartedAt=time;a.phase='retreat';a.progress=0;publish(a);continue;}
      if(a.kind==='intimidate')moveMember(a.memberId,null,{phase:'stop',stopDistance:0});
      const ok=apply(a,t);if(ok!==null)finish(a,ok?'completed':'effect_rejected',ok);
    }
    // Explicit user work is FIFO and has priority over automatic medic scans.
    for(const r of roster.values()){
      if(!queuedEntries(r).length||actions.has(r.id)||!alive(getMember(r.id))||r.status==='hospital'||!canStartQueued(r.id))continue;
      for(let checked=0;checked<=balance.maxQueued&&queuedEntries(r).length;checked++){
        const next=r.resumeWork||r.queued[0],target=getTarget(next.targetId);
        if(validTarget(next.kind,target)&&(r.cooldowns[next.kind]||0)>time)break;
        if(r.resumeWork)delete r.resumeWork;else r.queued.shift();
        if(command(r.id,next.kind,next.targetId,{fromQueue:true}).ok)break;
      }
      if(!queuedEntries(r).length)delete r.queueHp;
    }
    if(time-lastScan>=balance.autoMedicInterval){
      lastScan=time;
      // Adapter supplies player + current squad only, bounded by the squad limit.
      const targets=scanReviveTargets().slice(0,balance.maxMembers+1);
      for(const r of roster.values())if(r.profession==='medic'&&!actions.has(r.id)&&!queuedEntries(r).length&&alive(getMember(r.id))&&canAutoRevive(r.id)&&canStartQueued(r.id)){
        for(const target of targets){const id=typeof target==='string'?target:target.id;if(roster.get(id)?.status==='hospital')continue;if(command(r.id,'revive',id,{fromQueue:true}).ok)break;}
      }
    }
  }
  function cancel(id){const cleared=clearQueue(id),a=actions.get(id);if(!a)return result(cleared>0,cleared?'queue_cancelled':'no_action',{queuedCleared:cleared});if(a.awaiting)return result(false,'effect_pending',{queuedCleared:cleared});if(a.armed)return result(false,'bomb_armed',{queuedCleared:cleared});finish(a,'cancelled');return result(true,'cancelled');}
  function dismiss(id){const r=roster.get(id);if(!r)return result(false,'not_recruited');clearQueue(id);if(!actions.get(id)?.armed&&!actions.get(id)?.awaiting)cancel(id);if(actions.has(id))actions.get(id).detached=true;roster.delete(id);return result(true,'dismissed',{member:copy(r)});}
  function setWeapon(id,weapon){const r=roster.get(id);if(!r)return false;r.weapon=weapon==null?null:copy(weapon);return true;}
  function snapshot(){return {version:1,sequence,settledActionIds:[...settledActionIds],
    pendingTransactions:[...actions.values()].filter(a=>a.awaiting).map(a=>({requestId:a.id,memberId:a.memberId,targetId:a.targetId,kind:a.kind,startedAt:a.phaseStartedAt,cooldown:a.cooldown,detached:!!a.detached})),
    charges:[...actions.values()].filter(a=>a.armed&&!a.effectApplied).map(a=>({actionId:a.id,memberId:a.memberId,targetId:a.targetId,kind:a.kind,phase:a.phase,armedAt:a.armedAt,detonateAt:a.detonateAt,cooldown:a.cooldown,detached:!!a.detached,waitingForSafety:!!a.waitingForSafety})),
    members:[...roster.values()].map(r=>({...copy(r),resumeWork:actions.has(r.id)&&!actions.get(r.id).armed&&!actions.get(r.id).awaiting?{kind:actions.get(r.id).kind,targetId:actions.get(r.id).targetId,queuedAt:actions.get(r.id).startedAt}:r.resumeWork,cooldowns:Object.fromEntries(Object.entries(r.cooldowns).map(([k,t])=>[k,Math.max(0,t-now())]))}))};}
  function restore(data){
    if(data?.version!==1||!Array.isArray(data.members))return result(false,'unsupported_save');
    if(actions.size)return result(false,'commands_active');
    roster.clear();
    for(const raw of data.members.slice(0,balance.maxMembers)){
      if(!raw||typeof raw!=='object')continue;
      if(!recruit(raw).ok)continue;const r=roster.get(raw.id);
      const queueEntry=q=>q&&typeof q.targetId==='string'&&q.targetId.length>0&&q.targetId.length<512&&ACTIONS[q.kind]?.profession===r.profession?{kind:q.kind,targetId:q.targetId,queuedAt:finite(q.queuedAt,now())}:null;
      r.queued=(Array.isArray(raw.queued)?raw.queued:[]).slice(0,balance.maxQueued).map(queueEntry).filter(Boolean);r.resumeWork=queueEntry(raw.resumeWork)||undefined;r.queueHp=Number.isFinite(raw.queueHp)?raw.queueHp:undefined;
      r.weapon=raw.weapon==null?null:copy(raw.weapon);
      r.hospitalUntil=Math.max(0,finite(raw.hospitalUntil));
      r.downedAt=Number.isFinite(raw.downedAt)&&raw.downedAt>=0?raw.downedAt:null;
      r.lifecycleRetryAt=Math.max(0,finite(raw.lifecycleRetryAt));
      r.status=r.hospitalUntil>0?'hospital':raw.status==='returning'?'returning':raw.status==='downed'?'downed':'active';
      r.xp=Math.max(0,Math.min(100000,Math.floor(finite(raw.xp))));r.level=Math.min(20,1+Math.floor(r.xp/100));
      let spent=0;
      for(const s of Object.keys(r.skills)){r.skills[s]=Math.min(5,Math.max(0,Math.floor(finite(raw.skills?.[s]))),Math.max(0,r.level-1-spent));spent+=r.skills[s];}
      r.skillPoints=r.level-1-spent;
      for(const k of MERCENARY_PROFESSIONS[r.profession].actions)r.cooldowns[k]=now()+Math.max(0,Math.min(120,finite(raw.cooldowns?.[k])));
    }
    sequence=Math.max(sequence,Math.floor(Math.max(0,finite(data.sequence))));
    for(const id of (Array.isArray(data.settledActionIds)?data.settledActionIds:[]).slice(-4096))if(Number.isSafeInteger(id)&&id>0){settledActionIds.add(id);sequence=Math.max(sequence,id);}
    for(const raw of (Array.isArray(data.charges)?data.charges:[]).slice(0,128)){
      if(!raw||raw.kind!=='plant_bomb'||raw.effectApplied||typeof raw.memberId!=='string'||typeof raw.targetId!=='string'||!raw.memberId||!raw.targetId||!Number.isFinite(raw.armedAt)||!Number.isFinite(raw.detonateAt)||raw.detonateAt<raw.armedAt||actions.has(raw.memberId))continue;
      const id=Number.isSafeInteger(raw.actionId)&&raw.actionId>0?raw.actionId:++sequence;sequence=Math.max(sequence,id);
      if(settledActionIds.has(id))continue;
      actions.set(raw.memberId,{id,memberId:raw.memberId,targetId:raw.targetId,kind:'plant_bomb',phase:raw.phase==='retreat'?'retreat':'countdown',
        armed:true,armedAt:raw.armedAt,detonateAt:raw.detonateAt,startedAt:raw.armedAt,phaseStartedAt:raw.armedAt,
        duration:0,progress:0,cooldown:Math.max(0,finite(raw.cooldown,ACTIONS.plant_bomb.cooldown)),effectApplied:false,
        detached:!!raw.detached||!roster.has(raw.memberId),waitingForSafety:!!raw.waitingForSafety});
    }
    for(const raw of (Array.isArray(data.pendingTransactions)?data.pendingTransactions:[]).slice(0,128)){
      if(!raw||!Number.isSafeInteger(raw.requestId)||raw.requestId<1||!Object.hasOwn(ACTIONS,raw.kind)||typeof raw.memberId!=='string'||typeof raw.targetId!=='string'||actions.has(raw.memberId))continue;
      sequence=Math.max(sequence,raw.requestId);settledActionIds.add(raw.requestId);
      actions.set(raw.memberId,{id:raw.requestId,memberId:raw.memberId,targetId:raw.targetId,kind:raw.kind,phase:'awaiting',progress:1,
        phaseStartedAt:finite(raw.startedAt,now()),duration:0,cooldown:Math.max(0,finite(raw.cooldown)),awaiting:true,effectApplied:true,
        detached:!!raw.detached||!roster.has(raw.memberId),requiresReconciliation:true});
    }
    return result(true,'restored');
  }
  function availableActions(target){
    const t=typeof target==='string'?getTarget(target):target;
    return [...roster.values()].flatMap(r=>MERCENARY_PROFESSIONS[r.profession].actions.filter(k=>validTarget(k,t)).map(kind=>({memberId:r.id,profession:r.profession,kind,queuedCount:r.queued.length,willQueue:actions.has(r.id)||queuedEntries(r).length>0||(r.cooldowns[kind]||0)>now()||!canStartQueued(r.id),available:t.id!==r.id&&!(kind==='revive'&&roster.get(t.id)?.status==='hospital')&&r.status!=='hospital'&&alive(getMember(r.id))&&r.queued.length<balance.maxQueued&&!targetBusy(kind,t)})));
  }
  // Fresh isolated projection for single-member reads; never retain a roster snapshot.
  function getRecord(id){const r=roster.get(id);return r?copy({...r,hospitalRemaining:Math.max(0,r.hospitalUntil-now())}):undefined;}
  function resetQaPatient(id){const r=roster.get(id),a=actions.get(id);if(!allowQaPatientReset()||r?.profession!=='bruiser'||a?.armed||a?.awaiting)return result(false,'qa_patient_reset_denied');if(a)cancel(id);r.status='downed';r.hospitalUntil=0;r.downedAt=now();r.lifecycleRetryAt=0;return result(true,'qa_patient_ready');}
  return {recruit,dismiss,upgrade,addXP,command,cancel,clearQueue,getQueue:id=>copy(roster.get(id)?.queued||[]),update,snapshot,restore,stats,availableActions,setWeapon,resolvePending,getRecord,resetQaPatient,
    getRoster:()=>copy([...roster.values()].map(r=>({...r,hospitalRemaining:Math.max(0,r.hospitalUntil-now())}))),getAction:id=>actions.has(id)?copy(actions.get(id)):null};
}
