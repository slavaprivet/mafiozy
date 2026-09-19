import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const code=readFileSync(new URL('./mercenary_melee_source.js',import.meta.url),'utf8');
function harness(){
  let blocked=false;const hits=[];const c={window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},performance:{now:()=>1000},
    _npcPathPassable:()=>!blocked,_businessInteriorMovementBlocked:()=>false,_buildingInt:null,
    hitNpc:(...args)=>hits.push(['npc',...args]),_hitInteriorNpc:(...args)=>hits.push(['interior',...args]),
    _hitBankGuard:(...args)=>hits.push(['bank',...args]),hitCityCop:(...args)=>hits.push(['cop',...args])};
  vm.runInNewContext(code,c);return {api:c.window.MafioziMercenaryMelee,hits,block:v=>blocked=v};
}
for(const kind of ['street_npc','interior_guard','bank_guard','city_cop']){
  const h=harness(),m={r:0,c:0,hp:100,weapon:null},target={r:0,c:.3,hp:100};
  const step=now=>h.api.step(m,{targetKind:kind,targetRef:target,pos:target,now,dt:.016,stats:{meleeMultiplier:1.8}});
  assert(step(1000));assert.equal(h.hits.length,0);assert.equal(m._shotWeapon,'fists');step(1179);assert.equal(h.hits.length,0);step(1180);assert.equal(h.hits.length,1);
  for(let t=1200;t<1800;t+=16)step(t);assert.equal(h.hits.length,1,'800ms cooldown');
  assert.equal(kind==='street_npc'?h.hits[0][5]:h.hits[0][4],29,'Bruiser multiplier');assert.equal(target.hp,100,'Helper delegates HP exclusively');
}
{
  const h=harness(),m={r:0,c:0,hp:100},target={r:0,c:1,hp:100};
  h.api.step(m,{targetKind:'street_npc',targetRef:target,pos:target,now:1000,dt:10});assert(m.c>0&&m.c<=3.2*.05/4.1);assert.equal(h.hits.length,0);
  h.block(true);const c=m.c;h.api.step(m,{targetKind:'street_npc',targetRef:target,pos:target,now:1050,dt:.05});assert.equal(m.c,c,'Blocked movement');
}
{
  const h=harness(),m={r:0,c:0,hp:100},target={r:0,c:.2,hp:100};
  h.api.step(m,{targetKind:'street_npc',targetRef:target,pos:target,now:1000});target.c=1;
  h.api.step(m,{targetKind:'street_npc',targetRef:target,pos:target,now:1180});assert.equal(h.hits.length,0,'Target escaped contact');
  target.c=.2;h.block(true);h.api.step(m,{targetKind:'street_npc',targetRef:target,pos:target,now:2000});assert.equal(m._shotSeq,1,'No punch through wall');
  m.weapon='pistol';assert.equal(h.api.step(m,{}),false,'Armed AI retained');
  m.weapon=null;h.api.step(m,{targetKind:'player',targetRef:target,pos:target,now:3000});assert.equal(h.hits.length,0,'No fabricated remote damage');
}
console.log('mercenary melee source: delayed local damage, profession multiplier, native range, cooldown, collision, moving target, remote exclusion PASS');
