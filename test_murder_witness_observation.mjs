import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(process.argv[2]||new URL('./world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
function fn(name){const a=source.indexOf(`function ${name}(`);return a<0?'':source.slice(a,source.indexOf('\n}',a)+2);}
let now=10000;const npc=(id,r=1,c=1)=>({id,r,c,ang:-Math.PI/2});
const visible=npc('resident_a'),wall=npc('resident_b',2),late=npc('resident_c',50),victim=npc('victim',0,0);
let walls=new Set([wall.r]);
const env={performance:{now:()=>now},NPCS:[visible,wall,late,victim],player:{r:0,c:2},_buildingInt:null,_bankInt:null,
  _policeWorldLineClear:(r,c,tr,tc)=>!walls.has(r),Math,Number,String,
  _npcWitnessAble:n=>!!n&&!n.dead&&!n._medicalDowned&&!n._policeCuffed&&!(n._meleeStunnedUntil>now)&&!n._fightingMelee};
vm.createContext(env);
for(const n of ['_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_murderWitnessAvailable','_captureMurderWitnesses','_murderWitnessCanInterview','_murderSceneWitnesses','_murderWitnessStatement'])if(fn(n))vm.runInContext(fn(n),env);
const incident={r:0,c:0,victim,source:{kind:'player'},occurredAt:now};
// Baseline has no event capture; its real selector still demonstrates the bug.
env._captureMurderWitnesses?.(incident,now);
assert.ok(!env._murderSceneWitnesses(incident).includes(wall),'Through-wall bystander cannot witness murder');
late.r=1;now+=5000;assert.ok(!env._murderSceneWitnesses(incident).includes(late),'Later arrival cannot acquire past knowledge');
walls.clear();assert.ok(!env._murderSceneWitnesses(incident).includes(wall),'Opening visibility later does not rewrite observation');
assert.ok(env._murderSceneWitnesses(incident).includes(visible));
assert.equal(env._murderWitnessStatement(incident,visible),'Я видел, кто напал на него.');
visible.snitching=true;assert.equal(env._murderSceneWitnesses(incident).length,0,'Police interview must not override phone');
visible.snitching=false;visible.panicUntil=now+2000;assert.equal(env._murderSceneWitnesses(incident).length,0,'Panic remains higher priority');
visible.panicUntil=0;visible.dead=true;assert.equal(env._murderSceneWitnesses(incident).length,0);
env.NPCS=[{...visible,dead:false}];assert.equal(env._murderSceneWitnesses(incident).length,0,'Same ID replacement cannot inherit knowledge');
const delayed={...incident,witnessObservations:undefined,occurredAt:now-1000};env._captureMurderWitnesses(delayed,now);assert.equal(delayed.witnessObservations.length,0,'Old corpse discovery cannot invent observation');
const observer=npc('resident_d');env.NPCS=[observer];env._policeWorldLineClear=(r,c,tr,tc)=>tc!==2;
const hiddenShooter={...incident,witnessObservations:undefined,occurredAt:now};env._captureMurderWitnesses(hiddenShooter,now);
assert.equal(hiddenShooter.witnessObservations.length,1);assert.equal(hiddenShooter.witnessObservations[0].sawSuspect,false);
assert.ok(env._murderWitnessStatement(hiddenShooter,observer).includes('не разглядел'));
const robbery={r:0,c:0,victim:observer,source:{kind:'npc_robbery'},robberyAmount:42};
assert.equal(env._murderSceneWitnesses(robbery)[0],observer);assert.ok(env._murderWitnessStatement(robbery,observer).includes('$42'));
assert.ok(source.includes('_captureMurderWitnesses(incident,now);\n  victim._policeMurderIncidentId'));
assert.ok(source.includes('!_murderWitnessCanInterview(witness,now)||now-cop._phaseStartedAt'));
console.log('PASS murder event-time LOS, late arrivals, replacements, delayed discovery, suspect uncertainty, phone/panic priority, robbery victim');
