import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
for(const [,attrs,body]of source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/type=["'](?:module|importmap|application\/)/.test(attrs))new vm.Script(body);
const start=source.indexOf('function _localHostileCanResolveHit()'),end=source.indexOf('\nlet myKills',start);
assert(start>=0&&end>start);
const c={_LOCAL_PREVIEW:true,_worldDirectCombatDemo:false,_murderPoliceArrest:null,_walkRendererActive:()=>true,
  _meleeBlockHeld:false,player:{r:5,c:6,ang:0},myHp:100,myDead:false,
  document:{documentElement:{dataset:{}}},performance:{now:()=>1000},_registerIncomingFire:()=>{},
  _threePlayerImpactState:{},_meleeBruiseAt:0};
vm.createContext(c);
vm.runInContext(source.slice(start,end)+'\nthis.setResolver=fn=>_walkCoverResolver=fn;',c);
const shooter={kind:'weapon',weapon:'pistol',source:{r:1,c:2}};
let calls=0,seen;
c.setResolver(request=>{calls++;seen=request;return {blocked:true};});
assert.equal(c._hurtLocal(20,'NPC',true,shooter),false);
assert.equal(c.myHp,100,'physical full cover vetoes local HP damage');
assert.equal(seen.sourceR,1);assert.equal(seen.sourceC,2);assert.equal(seen.sourceHeight,1.45);
assert.equal(c.document.documentElement.dataset.walkCoverHit,'blocked');
c.setResolver(()=>({multiplier:.25}));c._hurtLocal(20,'NPC',true,shooter);
assert.equal(c.myHp,95,'partial physical exposure controls local damage');
c.setResolver(()=>({blocked:true}));
for(const detail of [null,{kind:'weapon'},...['melee','explosive','fire','grenade','rocket'].map(kind=>({...shooter,kind})),{...shooter,weapon:'rpg'}]){
  const hp=c.myHp;c._hurtLocal(2,'NPC',true,detail);assert.equal(c.myHp,hp-2,'non-ballistic/missing source cannot grant immunity');
}
let hp=c.myHp;c._hurtLocal(3,'blast',false,shooter);assert.equal(c.myHp,hp-3);
c.setResolver(()=>{throw Error('renderer unavailable');});hp=c.myHp;c._hurtLocal(3,'NPC',true,shooter);assert.equal(c.myHp,hp-3);
c.setResolver(()=>({blocked:true}));c._walkRendererActive=()=>false;hp=c.myHp;c._hurtLocal(3,'NPC',true,shooter);assert.equal(c.myHp,hp-3,'legacy damage preserved');
c._walkRendererActive=()=>true;c._LOCAL_PREVIEW=false;c._worldDirectCombatDemo=false;
assert.equal(c._walkCoverDamage(20,true,shooter),20,'authenticated damage has no client veto');
c._worldDirectCombatDemo=true;assert.equal(c._walkCoverDamage(20,true,shooter),0,'explicit direct demo participates');
c.setResolver(request=>{seen=request;return {};});
c._walkCoverDamage(20,true,{...shooter,muzzleR:3,muzzleC:4,sourceHeight:2.6});
assert.equal(seen.sourceR,3);assert.equal(seen.sourceC,4);assert.equal(seen.sourceHeight,2.6);
assert(source.includes('registerWalkCoverResolver(resolver)'));
for(const fragment of ["weapon:wep,source:n,muzzleR:muzR,muzzleC:muzC","weapon:'pistol',source:npc,muzzleR:muzzle.r,muzzleC:muzzle.c","weapon:n.weapon,source:n,muzzleR:muzzle.r,muzzleC:muzzle.c"]){assert(source.includes(fragment),'hostile bullet source is retained for physical cover');}
console.log('PASS cover local damage bridge: full/partial physical cover, attacker/muzzle metadata, fail-safe errors, legacy isolation, melee/blast exclusions, network-authority isolation, world script syntax');
