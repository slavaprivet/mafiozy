/* Source-world melee for unarmed hired specialists. Positions are source tiles;
   dt seconds, now performance milliseconds. Existing hit APIs own HP and witnesses. */
(function(){
  'use strict';
  const pending=new WeakMap();
  const finite=(x,f=0)=>Number.isFinite(x)?x:f;
  function pass(m,r,c){
    if(window.MafioziMercenaries?.canMoveMember&&!window.MafioziMercenaries.canMoveMember(m.id,{r:m.r,c:m.c},{r,c}))return false;
    if(typeof _npcPathPassable!=='function'||!_npcPathPassable(m.r,m.c,r,c))return false;
    return typeof _businessInteriorMovementBlocked!=='function'||!_businessInteriorMovementBlocked(typeof _buildingInt!=='undefined'?_buildingInt:null,r,c,.18);
  }
  function line(m,p){
    if(typeof _buildingInt!=='undefined'&&_buildingInt&&typeof _majorInteriorLineClear==='function'&&!_majorInteriorLineClear(_buildingInt,m.r,m.c,p.r,p.c))return false;
    return pass(m,p.r,p.c);
  }
  function damage(m,kind,ref,dy,dx,amount){
    if(kind==='street_npc'&&typeof hitNpc==='function'){hitNpc(ref,dy,dx,'fists',amount,{kind:'npc',ref:m});return true;}
    if(kind==='interior_guard'&&typeof _hitInteriorNpc==='function'){_hitInteriorNpc(ref,dy,dx,amount,'fists');return true;}
    if(kind==='bank_guard'&&typeof _hitBankGuard==='function'){_hitBankGuard(ref,dy,dx,amount);return true;}
    if(kind==='city_cop'&&typeof hitCityCop==='function'){hitCityCop(ref,dy,dx,amount,{kind:'gang_companion',ref:m,weapon:'fists'});return true;}
    return false; // Remote actors require their existing server-owned melee contract.
  }
  function step(m,context={}){
    if(!m)return false;
    if(m.weapon&&m.weapon!=='fists'){pending.delete(m);m._fightingMelee=false;return false;}
    const {targetKind:kind,targetRef:target,pos}=context;
    const now=finite(context.now,performance.now()),scale=Math.max(.01,Number(window.MAFIOZI_RENDERER_CONFIG?.worldScale)||4.1);
    const dt=Math.max(0,Math.min(.05,finite(context.dt))),range=1.65/scale;
    if(m.dead||m.hp<=0||m._mercenaryHospital||!target||target.dead||target.alive===false||target.hp===0||!pos||!Number.isFinite(pos.r)||!Number.isFinite(pos.c)){
      pending.delete(m);m._fightingMelee=false;return true;
    }
    if(!['street_npc','interior_guard','bank_guard','city_cop'].includes(kind)){pending.delete(m);m._fightingMelee=false;return true;}
    const dr=pos.r-m.r,dc=pos.c-m.c,d=Math.hypot(dr,dc),div=d||1;
    m.ang=Math.atan2(dr,dc);m._fightingMelee=true;m._meleeType='punch';
    const attack=pending.get(m);
    if(attack){
      if(attack.target!==target||attack.kind!==kind||now>attack.at+500)pending.delete(m);
      else if(now>=attack.at){
        pending.delete(m);
        if(d<=range&&line(m,pos)){
          const before=Number(target.hp);damage(m,kind,target,dr/div,dc/div,attack.amount);
          const actual=Number.isFinite(before)?Math.max(0,before-Math.max(0,Number(target.hp)||0)):0;
          if(actual>0)window.MafioziMercenaries?.awardCombatXp?.(m.id,actual,target.dead===true||target.alive===false||target.hp<=0,target.level||1);
        }
      }
      return true;
    }
    if(d>range*.85){
      const distance=Math.min(Math.max(0,d-range*.8),3.2*dt/scale);
      for(const [dy,dx]of [[dr/div,dc/div],[dr/div,0],[0,dc/div]]){
        const r=m.r+dy*distance,c=m.c+dx*distance;
        if(!pass(m,r,c))continue;
        const moved=Math.hypot(r-m.r,c-m.c);m.r=r;m.c=c;m.walkPhase=finite(m.walkPhase)+moved*scale*2.4;m._followSpeed=3.2/scale;break;
      }
    }else m._followSpeed=0;
    if(d>range||now<finite(m._mercenaryNextPunchAt)||!line(m,pos))return true;
    m._mercenaryNextPunchAt=now+800;m._punchAnim=now;m._shotAt=now;m._shotWeapon='fists';m._shotSeq=finite(m._shotSeq)+1;
    pending.set(m,{target,kind,at:now+180,amount:Math.max(1,Math.round(16*Math.max(.1,Math.min(5,finite(context.stats?.meleeMultiplier,1)))))});
    return true;
  }
  window.MafioziMercenaryMelee={step,clear(m){pending.delete(m);if(m)m._fightingMelee=false;}};
})();
