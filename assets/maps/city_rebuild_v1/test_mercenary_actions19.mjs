import test from 'node:test';
import assert from 'node:assert/strict';
import {createMercenarySquad} from './mercenary_core.mjs';

function fixture(){
 let time=1000;const entities=new Map(),effects=[],moves=[];
 const core=createMercenarySquad({now:()=>time,getMember:id=>entities.get(id),getTarget:id=>entities.get(id),moveMember:(id,target,options)=>moves.push({id,target,options}),
  scanReviveTargets:()=>[...entities.values()].filter(e=>e.downed),performEffect:e=>{effects.push(e);if(e.kind==='revive'){e.target.hp=35;e.target.downed=false;}return true;}});
 const add=(id,kind='npc',extra={})=>{const e={id,kind,hp:100,position:{x:0,y:0,z:0},...extra};entities.set(id,e);return e;};
 const recruit=(id,profession)=>{const m=add(id);assert(core.recruit({id,profession}).ok);return m;};
 return {core,entities,effects,moves,add,recruit,tick:(dt=0)=>{time+=dt;core.update();}};
}
test('live demolition operator physically retreats from blast center before exactly one explosion',()=>{
 const h=fixture(),m=h.recruit('demo','demolitions');h.add('car','vehicle',{center:{x:1.75,y:0,z:0}});
 assert(h.core.command('demo','plant_bomb','car').ok);h.tick();h.tick(4);h.tick(6);
 assert.equal(h.effects.length,0,'elapsed fuse cannot explode beside blocked operator');assert(h.core.getAction('demo').waitingForSafety);
 const goal=h.moves.at(-1);assert.equal(goal.options.phase,'retreat');assert.equal(Math.abs(goal.target.position.x-1.75),9,'stop radius leaves safety margin');
 m.position.x=-6.1;h.tick();assert.equal(h.effects.length,0,'8m from approach is still unsafe from vehicle centre');
 m.position={...goal.target.position};h.tick();h.tick();assert.equal(h.effects.filter(e=>e.kind==='plant_bomb').length,1);assert.equal(h.core.getAction('demo'),null);
});
test('moving vehicle and authored blast radius re-evaluate safety, death preserves charge',()=>{
 const h=fixture(),m=h.recruit('demo','demolitions'),car=h.add('car','vehicle',{blastRadius:12});
 h.core.command('demo','plant_bomb','car');h.tick();h.tick(4);m.position.x=9;h.tick(6);assert.equal(h.effects.length,0);
 assert.equal(h.moves.at(-1).target.position.x,14);car.position.x=9;h.tick();assert.equal(h.effects.length,0);
 m.hp=0;m.downed=true;h.tick();assert.equal(h.effects.filter(e=>e.kind==='plant_bomb').length,1);
});
test('reload preserves visible armed charge while blocked operator awaits safe retreat',()=>{
 const h=fixture();h.recruit('demo','demolitions');h.add('car','vehicle');h.core.command('demo','plant_bomb','car');h.tick();h.tick(4);h.tick(6);
 const save=h.core.snapshot();assert.equal(save.charges[0].waitingForSafety,true);
 const restored=fixture(),m=restored.add('demo');restored.add('car','vehicle');assert(restored.core.restore(save).ok);restored.tick(20);
 assert.equal(restored.effects.length,0);assert.equal(restored.core.snapshot().charges[0].waitingForSafety,true);
 m.position.x=9;restored.tick();assert.equal(restored.effects.filter(e=>e.kind==='plant_bomb').length,1);
});
test('engineer works on powered panel only and awaits real effect receipt',()=>{
 const h=fixture();h.recruit('engineer','engineer');const panel=h.add('power','power_panel',{powered:true});
 assert(h.core.availableActions(panel).some(a=>a.kind==='disable_power'));assert(h.core.command('engineer','disable_power','power').ok);
 h.tick();h.tick(4.9);assert.equal(h.effects.length,0);h.tick(.1);assert.equal(h.effects[0].kind,'disable_power');assert.equal(panel.powered,true,'core does not fake scene effects');
 panel.powered=false;assert.equal(h.core.availableActions(panel).length,0);
});
test('automatic medic revives downed squad once and healthy member returns active',()=>{
 const h=fixture();h.recruit('medic','medic');const ally=h.recruit('ally','bruiser');ally.hp=0;ally.downed=true;
 h.tick();assert.equal(h.core.getAction('medic').targetId,'ally');h.tick();h.tick(4);h.tick();
 assert.equal(ally.hp,35);assert.equal(ally.downed,false);assert.equal(h.core.getRecord('ally').status,'active');assert.equal(h.effects.filter(e=>e.kind==='revive').length,1);
});
test('medic cannot revive confirmed hospital patient or healthy target',()=>{
 const h=fixture();h.recruit('medic','medic');const ally=h.recruit('ally','bruiser');
 assert.equal(h.core.command('medic','revive','ally').ok,false);ally.hp=0;ally.dead=true;h.tick();
 assert.equal(h.core.getRecord('ally').status,'hospital');assert.equal(h.core.getAction('medic'),null);assert.equal(h.core.command('medic','revive','ally').ok,false);
});
test('authored workRange moves specialist close to interaction point and uses fresh target range',()=>{
 const h=fixture(),m=h.recruit('engineer','engineer'),target=h.add('panel','power_panel',{powered:true,workRange:.4,position:{x:1,y:0,z:0}});
 assert(h.core.command('engineer','disable_power','panel').ok);h.tick();assert.equal(h.core.getAction('engineer').phase,'approach');assert.equal(h.moves.at(-1).options.stopDistance,.34);
 m.position.x=.65;h.tick();assert.equal(h.core.getAction('engineer').phase,'working');h.tick(2);target.workRange=.25;h.tick();assert.equal(h.core.getAction('engineer').phase,'approach','tightened authored contact point cannot continue remote work');
 m.position.x=.8;h.tick();assert.equal(h.core.getAction('engineer').phase,'working');h.tick(4.9);assert.equal(h.effects.length,0);h.tick(.1);assert.equal(h.effects.length,1);
});
test('invalid or oversized workRange cannot enlarge profession interaction reach',()=>{
 for(const requested of [NaN,Infinity,100]){const h=fixture();h.recruit('engineer','engineer');h.add('panel','power_panel',{powered:true,workRange:requested,position:{x:5,y:0,z:0}});h.core.command('engineer','disable_power','panel');h.tick();assert.equal(h.core.getAction('engineer').range,1.5);assert.equal(h.core.getAction('engineer').phase,'approach');}
});
test('finite active route search prevents premature blocked timeout but never extends total approach timeout',()=>{
 const h=fixture(),m=h.recruit('engineer','engineer');h.add('fence','fence',{position:{x:20,y:0,z:0}});h.core.command('engineer','cut_fence','fence');m.approachSearching=true;h.tick(12);assert(h.core.getAction('engineer'));h.tick(27);assert(h.core.getAction('engineer'));h.tick(2);assert.equal(h.core.getAction('engineer'),null);assert.equal(h.effects.filter(e=>e.kind==='cut_fence').length,0);
});
