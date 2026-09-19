import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
async function fixture({storage=new Map(),clockStart=1000,qa=false,combatTarget=null}={}){
 let clock=clockStart;const ctx={module,URL,Promise,console,Date:{now:()=>clock*1000},performance:{now:()=>clock*1000},document:{getElementById:id=>id==='npc-combat-session'&&combatTarget?{dataset:{npcId:combatTarget}}:null,documentElement:{dataset:{}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},location:{origin:'http://localhost',...(qa?{hostname:'localhost',href:'http://localhost/world.html?mercenaryqa=1'}:{})},window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},_LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_customGang:null,_myGang:[],NPCS:Array.from({length:8},(_,i)=>({id:'civilian'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:'NPC '+i,look:{hair:i}})),player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:5,_hiredBotIds:new Set(),_inventoryItems:[],currentWeapon:null,QP:{cash:500},_saveGang(){},_syncMyWeaponsFromInventory(){},_npcBodyPassable:()=>true,_npcPathPassable:()=>true};
 vm.createContext(ctx);vm.runInContext(script,ctx);await new Promise(r=>setImmediate(r));const api=ctx.window.MafioziMercenaries;
 const recruit=p=>{const row=api.getRoster().candidates.find(r=>r.profession===p);assert(row);assert(api.recruit(row.id).ok);return ctx._myGang.at(-1);};
 return {ctx,api,recruit,storage,tick:(dt=.05)=>{clock+=dt;api.tick(.05);}};
}
for(const [profession,kind,targetKind] of [['demolitions','plant_bomb','vehicle'],['engineer','cut_fence','fence'],['engineer','disable_power','power_panel'],['safecracker','unlock_safe','safe']]){
 test(`ground rally cancels ${kind} before effect and physically starts movement`,async()=>{
  const f=await fixture(),m=f.recruit(profession),target={id:'object:test',kind:targetKind,valid:true,locked:true,powered:true,position:{...f.api.getMember(m.id).position}};let effects=0;
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;return true;}});assert(f.api.command(kind,target).ok);f.tick();assert.equal(f.api.getAction(m.id).phase,'working');
  const from=m.c,result=f.api.rally({x:60,y:0,z:41});assert(result.ok);assert.equal(f.api.getAction(m.id),null);f.tick(.05);assert(m.c>from);assert.equal(f.api.getRoster().members[0].order,'rally');assert.equal(effects,0);f.tick(10);assert.equal(effects,0);
 });
}
test('QA wounded patient reload preserves original bounded rescue deadline and still expires',async()=>{
 const first=await fixture({qa:true}),patient=first.recruit('bruiser');first.api.bindTargets({canMove:()=>true});assert(first.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok);first.tick();
 const deadline=patient._mercenaryQaRescueUntil,saved=[...first.storage.values()].map(v=>JSON.parse(v)).find(v=>v.rows),originalStorage=new Map(first.storage);assert.equal(saved.rows.find(r=>r.id===patient.id)._mercenaryQaRescueUntil,deadline);
 const next=await fixture({qa:true,storage:first.storage,clockStart:1030});next.api.bindTargets({canMove:()=>true});next.tick();assert.equal(next.api.getRoster().members[0].status,'downed');assert.equal(next.api.getMember(patient.id).qaRescueUntil,deadline);
 next.tick(569);assert.equal(next.api.getRoster().members[0].status,'downed');next.tick(2);assert.equal(next.api.getRoster().members[0].status,'hospital');
 const normal=await fixture({storage:originalStorage,clockStart:1030});normal.tick();assert.equal(normal.api.getMember(patient.id).qaRescueUntil,0);assert.equal(normal.api.getRoster().members[0].status,'hospital');
});
test('explicit QA patient reset recovers only hospital bruiser preserving identity cash and gear',async()=>{
 const f=await fixture({qa:true}),patient=f.recruit('bruiser'),other=f.recruit('engineer');patient.hp=0;other.hp=0;f.tick();f.tick(21);assert(f.api.getRoster().members.every(r=>r.status==='hospital'));
 const before={id:patient.id,name:patient.name,weapon:patient.weapon,cash:f.ctx.QP.cash};f.api.bindTargets({canMove:()=>false});assert.equal(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok,false);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'hospital');
 f.api.bindTargets({canMove:()=>true});assert(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok);f.tick();assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'downed');assert.equal(f.api.getRoster().members.find(r=>r.id===other.id).status,'hospital');assert.deepEqual({id:patient.id,name:patient.name,weapon:patient.weapon,cash:f.ctx.QP.cash},before);assert.equal(patient._mercenaryHospital,false);assert.equal(patient.hp,0);
 f.tick(30);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'downed');
 const ordinary=module.createMercenarySquad({getMember:()=>({hp:0})});ordinary.recruit({id:'ordinary',profession:'bruiser'});assert.equal(ordinary.resetQaPatient('ordinary').ok,false);
});
test('combat QA target is never adopted as a recruit and existing placeholder member keeps identity on QA rename',async()=>{
 const f=await fixture({qa:true,combatTarget:'civilian0'});assert(!f.api.getRoster().candidates.some(r=>r.id==='civilian0'));assert.equal(f.ctx.NPCS.find(n=>n.id==='civilian0')._mercenaryProfession,undefined);
 const member=f.recruit('safecracker'),id=member.id;member.name='Проверка урона';f.api.bindTargets({canMove:()=>true});const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}]));assert(f.api.qaAssembleProfessions({positions}).ok);assert.equal(member.id,id);assert.notEqual(member.name,'Проверка урона');assert(f.ctx.NPCS.some(n=>n.id==='civilian0'));
});
test('ground rally cancels medic and its automatic scan does not undo explicit movement order',async()=>{
 const f=await fixture(),medic=f.recruit('medic'),ally=f.recruit('bruiser');ally.hp=0;
 f.api.bindTargets({canMove:()=>true});f.tick();f.tick();assert.equal(f.api.getAction(medic.id).phase,'working');
 assert(f.api.rally({x:60,y:0,z:41}).ok);assert.equal(f.api.getAction(medic.id),null);const from=medic.c;
 for(let i=0;i<12;i++)f.tick(.5);assert.equal(f.api.getAction(medic.id),null);assert.equal(ally.hp,0);assert(medic.c>from);
 assert(f.api.command('revive',f.api.getTarget(ally.id)).ok,'explicit object command still overrides rally');
});
test('rally preserves armed operator safe retreat then moves him to queued point',async()=>{
 const f=await fixture(),m=f.recruit('demolitions'),origin={...f.api.getMember(m.id).position},target={id:'car',kind:'vehicle',valid:true,position:origin,center:origin};let effects=0;
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;return true;}});f.api.command('plant_bomb',target);f.tick();f.tick(4);
 assert(f.api.getAction(m.id).armed);const rally=f.api.rally({x:60,y:0,z:41});assert(rally.ok);assert.equal(rally.deferred,1);assert(f.api.getAction(m.id).armed);
 f.tick(6);assert.equal(effects,0);assert(f.api.getAction(m.id).waitingForSafety);assert(m._mercenaryMove.position.x<origin.x||m._mercenaryMove.position.x>origin.x+7,'retreat goal has precedence');
 for(let i=0;i<90;i++)f.tick(.05);assert.equal(effects,1);assert.equal(f.api.getAction(m.id),null);assert.equal(m._mercenaryMove.position.x,60);assert.equal(f.api.getRoster().members[0].order,'rally');
});
test('rally preserves pending receipt, never resends effect, then resumes queued movement',async()=>{
 const f=await fixture(),m=f.recruit('safecracker'),target={id:'safe',kind:'safe',locked:true,valid:true,position:{...f.api.getMember(m.id).position}};let calls=0,resolve;
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{calls++;return new Promise(r=>resolve=r);}});f.api.command('unlock_safe',target);f.tick();f.tick(8);assert.equal(f.api.getAction(m.id).phase,'awaiting');
 assert(f.api.rally({x:60,y:0,z:41}).ok);f.tick(5);assert.equal(calls,1);assert.equal(f.api.getAction(m.id).phase,'awaiting');resolve({ok:true});await Promise.resolve();await Promise.resolve();f.tick();assert.equal(calls,1);assert.equal(f.api.getAction(m.id),null);assert.equal(m._mercenaryMove.position.x,60);
});
test('invalid rally destination keeps current work and target',async()=>{
 const f=await fixture(),m=f.recruit('engineer'),target={id:'fence',kind:'fence',position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,canMove:()=>false});f.api.command('cut_fence',target);f.tick();const action=f.api.getAction(m.id);assert.equal(f.api.rally({x:60,y:0,z:41}).ok,false);assert.equal(f.api.getAction(m.id).id,action.id);
});
test('source actions expose only fitting professions and never offer civilian revival',async()=>{
 const f=await fixture();for(const p of ['medic','bruiser','safecracker','engineer','demolitions'])f.recruit(p);
 const targets=[['vehicle','plant_bomb','demolitions'],['safe','unlock_safe','safecracker'],['fence','cut_fence','engineer'],['power_panel','disable_power','engineer']];
 for(const [kind,action,profession]of targets){const target={id:'test',kind,locked:kind==='safe',powered:true,position:{x:41,y:0,z:41}},rows=f.api.getActions(target).filter(r=>r.enabled);assert.equal(rows.length,1);assert.equal(rows[0].id,action);assert.equal(rows[0].profession,profession);}
 const bruiser=f.ctx._myGang.find(m=>f.api.getRoster().members.find(r=>r.id===m.id)?.profession==='bruiser');bruiser.hp=0;
 const revive=f.api.getActions(f.api.getTarget(bruiser.id)).filter(r=>r.enabled);assert.equal(revive.length,1);assert.equal(revive[0].profession,'medic');
 f.ctx.NPCS[0].hp=0;assert.equal(f.api.getActions(f.api.getTarget(f.ctx.NPCS[0].id)).length,0);
});
test('core availability agrees with command for already assigned target and dead or absent profession',()=>{
 const members={a:{hp:100,position:{x:0,z:0}},b:{hp:100,position:{x:0,z:0}}},target={id:'patient',kind:'npc',hp:0,downed:true,position:{x:0,z:0}};
 const core=module.createMercenarySquad({getMember:id=>members[id],getTarget:()=>target});core.recruit({id:'a',profession:'medic'});core.recruit({id:'b',profession:'medic'});
 assert(core.command('a','revive','patient').ok);assert(core.availableActions(target).every(r=>!r.available),'second medic cannot offer already assigned patient');core.cancel('a');members.a.hp=0;assert.equal(core.availableActions(target).find(r=>r.memberId==='a').available,false);assert.equal(core.availableActions({...target,kind:'vehicle',hp:100}).length,0);
});
test('QA placement gates mutations and preserves actual candidate identity without free hire',async()=>{
 const f=await fixture();f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}]));
 assert.equal(f.api.qaPrepareProfessions({positions}).ok,false);f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';f.ctx.setTimeout=()=>0;
 const before=f.ctx.NPCS.map(n=>({id:n.id,name:n.name,look:JSON.stringify(n.look)})),result=f.api.qaPrepareProfessions({positions});assert(result.ok);assert.equal(result.placed.length,5);assert.equal(f.ctx._myGang.length,0);assert.equal(f.ctx.QP.cash,500);
 for(const original of before){const n=f.ctx.NPCS.find(n=>n.id===original.id);assert.equal(n.name,original.name);assert.equal(JSON.stringify(n.look),original.look);}
});
test('QA patient remains downed until explicit medic order; invalid placement does not mutate fighter',async()=>{
 const f=await fixture(),medic=f.recruit('medic'),patient=f.recruit('bruiser');f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';
 f.api.bindTargets({canMove:()=>false});assert.equal(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok,false);assert(patient.hp>0);
 f.api.bindTargets({canMove:()=>true});assert(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok);assert.equal(patient.hp,0);assert.equal(patient.dead,false);f.tick();assert.equal(f.api.getAction(medic.id),null);assert(f.api.command('revive',f.api.getTarget(patient.id)).ok);
});
test('QA assembly preserves hired IDs, recruits missing actual residents once and reports real cost',async()=>{
 const f=await fixture(),medic=f.recruit('medic'),engineer=f.recruit('engineer'),originalIds=[medic.id,engineer.id];f.api.bindTargets({canMove:()=>true,groundHeight:()=>0});
 const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}]));assert.equal(f.api.qaAssembleProfessions({positions}).ok,false);
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';const result=f.api.qaAssembleProfessions({positions,patientPosition:{x:64,y:0,z:64}});
 assert(result.ok);assert.equal(result.assembled.filter(r=>r.hired).length,3);assert.equal(result.charged,0,'normal source currently has no hire tariff');assert.equal(f.ctx._myGang.length,5);assert(originalIds.every(id=>f.ctx._myGang.some(m=>m.id===id)));
 assert.equal(f.ctx._myGang.find(m=>m.id===result.patient.memberId).hp,0);const again=f.api.qaAssembleProfessions({positions});assert(again.ok);assert.equal(again.assembled.filter(r=>r.hired).length,0);assert.equal(f.ctx._myGang.length,5);
});
test('QA wounded patient has bounded ten-minute rescue window and ordinary damage returns to normal grace',async()=>{
 const f=await fixture(),medic=f.recruit('medic'),patient=f.recruit('bruiser');f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';f.api.bindTargets({canMove:()=>true});assert(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok);
 f.tick();f.tick(30);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'downed');f.tick(550);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'downed');
 f.api.command('revive',f.api.getTarget(patient.id));medic.r=patient.r;medic.c=patient.c;f.tick();f.tick(4);assert(patient.hp>0);assert.equal(patient._mercenaryQaRescueUntil,undefined);
 patient.hp=0;f.tick();f.tick(20);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'hospital');
});
test('unrescued QA patient eventually enters hospital instead of becoming immortal',async()=>{
 const f=await fixture(),patient=f.recruit('bruiser');f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';f.api.bindTargets({canMove:()=>true});f.api.qaPlacePatient({position:{x:41,y:0,z:44}});f.tick();f.tick(600);assert.equal(f.api.getRoster().members.find(r=>r.id===patient.id).status,'hospital');
});
test('QA assembly searches nearby valid space when nominal safecracker slot is obstructed',async()=>{
 const f=await fixture();f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}])),nominal=positions.safecracker;
 f.api.bindTargets({canMove:p=>Math.hypot(p.x-nominal.x,p.z-nominal.z)>1.4});const result=f.api.qaAssembleProfessions({positions});assert(result.ok);const actual=result.assembled.find(r=>r.profession==='safecracker').position;assert(Math.hypot(actual.x-nominal.x,actual.z-nominal.z)>1.4);assert(Math.hypot(actual.x-nominal.x,actual.z-nominal.z)<=4.8+1e-6);assert.equal(f.ctx._myGang.length,5);
});
test('QA adopts a real free resident without extracting specialist owned by indoor visit',async()=>{
 const f=await fixture();const original=f.ctx.NPCS.find(n=>n._mercenaryProfession==='safecracker');original._residentIndoors=true;f.ctx.RESIDENTS_INDOORS=[original];f.ctx.NPCS.splice(f.ctx.NPCS.indexOf(original),1);const names=new Map(f.ctx.NPCS.map(n=>[String(n.id),n.name]));
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';f.api.bindTargets({canMove:()=>true});const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}]));const result=f.api.qaAssembleProfessions({positions});assert(result.ok);
 const hired=f.ctx._myGang.find(m=>m.id===result.assembled.find(r=>r.profession==='safecracker').memberId);assert.notEqual(hired.sourceBotId,String(original.id));assert.equal(hired.name,names.get(hired.sourceBotId));assert.equal(original._residentIndoors,true);assert.equal(f.ctx.RESIDENTS_INDOORS[0],original);assert(!f.ctx.NPCS.includes(original));
});
test('QA reports unavailable residents distinctly from blocked geometry without creating fake specialist',async()=>{
 const f=await fixture(),original=f.ctx.NPCS.find(n=>n._mercenaryProfession==='safecracker');original._civilianTrip={phase:'riding'};for(const n of f.ctx.NPCS)if(!n._mercenaryProfession)n._guard=true;
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenaryqa=1';f.api.bindTargets({canMove:()=>true});const positions=Object.fromEntries(['medic','bruiser','safecracker','engineer','demolitions'].map((p,i)=>[p,{x:60+i*2,y:0,z:60}]));const result=f.api.qaAssembleProfessions({positions});assert.equal(result.ok,false);assert.equal(result.rejected.find(r=>r.profession==='safecracker').code,'no_available_resident');assert.equal(f.ctx._myGang.length,4);assert(original._civilianTrip);
 f.api.bindTargets({canMove:()=>false});const blocked=f.api.qaAssembleProfessions({positions});assert(blocked.rejected.some(r=>r.code==='native_blocked'));assert.equal(f.ctx._myGang.length,4);
});
test('actual world movement reaches authored contact range before work and holds position without jitter',async()=>{
 const f=await fixture(),m=f.recruit('engineer'),origin=f.api.getMember(m.id).position,target={id:'panel-contact',kind:'power_panel',powered:true,workRange:.4,position:{x:origin.x+1.3,y:0,z:origin.z}};
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>true});assert(f.api.command('disable_power',target).ok);f.tick();assert.equal(f.api.getAction(m.id).phase,'approach');assert.equal(m._mercenaryMove.stopDistance,.34);
 for(let i=0;i<12&&f.api.getAction(m.id).phase==='approach';i++)f.tick();assert.equal(f.api.getAction(m.id).phase,'working');const actual=f.api.getMember(m.id).position,d=Math.hypot(target.position.x-actual.x,target.position.z-actual.z);assert(d<=.4+1e-6&&d>=.3,'work contact should be 30–40cm from approach point');
 const held={r:m.r,c:m.c};for(let i=0;i<10;i++)f.tick();assert.equal(m.r,held.r);assert.equal(m.c,held.c);assert.equal(f.api.getAction(m.id).phase,'working');
});
test('tight fence approach reaches twenty-centimetre work range without crossing mesh',async()=>{
 const f=await fixture(),m=f.recruit('engineer');m.r=40/4.1;m.c=41/4.1;
 const target={id:'tight-fence',kind:'fence',cuttable:true,workRange:.2,position:{x:41,y:0,z:44-.48}};let effects=0;
 f.api.bindTargets({get:()=>target,canMove:(from,to)=>to.z<=44-.12-.3,performEffect:()=>{effects++;target.cut=true;return true;}});assert(f.api.command('cut_fence',target).ok);
 for(let i=0;i<200&&f.api.getAction(m.id)?.phase!=='working';i++){f.tick();assert(m.r*4.1<=44-.42);}
 assert.equal(f.api.getAction(m.id)?.phase,'working');assert(Math.hypot(m.r*4.1-target.position.z,m.c*4.1-target.position.x)<=.2);const at={r:m.r,c:m.c};f.tick(3);assert.equal(m.r,at.r);assert.equal(m.c,at.c);f.tick(3);assert.equal(effects,1);
});
test('tight work range accounts for small terrain height difference rather than stopping outside 3D radius',async()=>{
 const f=await fixture(),m=f.recruit('engineer'),origin=f.api.getMember(m.id).position,target={id:'sloped-fence',kind:'fence',cuttable:true,workRange:.2,position:{x:origin.x+1,y:0,z:origin.z}};
 f.api.bindTargets({get:()=>target,groundHeight:()=>.12,canMove:()=>true,performEffect:()=>true});assert(f.api.command('cut_fence',target).ok);
 for(let i=0;i<80&&f.api.getAction(m.id)?.phase==='approach';i++)f.tick();assert.equal(f.api.getAction(m.id)?.phase,'working');
 const p=f.api.getMember(m.id).position;assert(Math.hypot(p.x-target.position.x,p.y-target.position.y,p.z-target.position.z)<=.2);
});
for(const [profession,kind,targetKind,duration] of [['engineer','cut_fence','fence',6],['engineer','disable_power','power_panel',5],['safecracker','unlock_safe','safe',8],['demolitions','plant_bomb','vehicle',4]]){
 for(const killed of [false,true])test(`${kind} ${killed?'death':'damage'} before timer zero cancels with no effect or cash grant`,async()=>{
  const f=await fixture({qa:true}),m=f.recruit(profession),cash=f.ctx.QP.cash,target={id:'interrupt',kind:targetKind,valid:true,locked:true,powered:true,position:{...f.api.getMember(m.id).position}};let effects=0;
  f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;f.ctx.QP.cash+=99;return true;}});assert(f.api.command(kind,target).ok);f.tick();f.tick(duration-.01);m.hp=killed?0:m.hp-1;f.tick(.02);
  assert.equal(f.api.getAction(m.id),null);assert.equal(effects,0);assert.equal(f.ctx.QP.cash,cash);assert.equal(f.api.getMember(m.id).movement.lastAction.reason,killed?'member_unavailable':'damaged');f.tick(10);assert.equal(effects,0);assert.equal(f.ctx.QP.cash,cash);
 });
}
test('damaged medic stops rescue without automatic restart; V clears hold after explicit successful revive',async()=>{
 const f=await fixture({qa:true}),medic=f.recruit('medic'),patient=f.recruit('bruiser');f.api.bindTargets({canMove:()=>true});assert(f.api.qaPlacePatient({position:{x:41,y:0,z:44}}).ok);medic.r=patient.r;medic.c=patient.c-.2;
 assert(f.api.command('revive',f.api.getTarget(patient.id)).ok);f.tick();f.tick(3.99);medic.hp--;f.tick(.02);assert.equal(f.api.getAction(medic.id),null);assert.equal(patient.hp,0);f.tick(5);assert.equal(f.api.getAction(medic.id),null);
 assert(f.api.command('revive',f.api.getTarget(patient.id)).ok);f.tick();f.tick(4);assert(patient.hp>0);f.tick();f.ctx.player.r=15;f.ctx.player.c=14;const starts=[medic,patient].map(m=>({r:m.r,c:m.c}));assert(f.api.follow().ok);for(let i=0;i<160;i++)f.tick();
 for(const [i,m]of [medic,patient].entries()){assert.equal(f.api.getRoster().members.find(r=>r.id===m.id).order,'follow');assert(Math.hypot(m.r-starts[i].r,m.c-starts[i].c)>2,JSON.stringify({id:m.id,start:starts[i],m:f.api.getMember(m.id),raw:m}));assert.equal(m._mercenaryRally,null);}
});
test('already armed bomb survives operator damage while pending receipts remain source-owned',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('demolitions'),target={id:'car-armed',kind:'vehicle',valid:true,position:{...f.api.getMember(m.id).position}};let effects=0;f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{effects++;return true;}});f.api.command('plant_bomb',target);f.tick();f.tick(4);assert(f.api.getAction(m.id).armed);m.hp--;f.tick();assert(f.api.getAction(m.id).armed);assert.equal(effects,0);m.hp=0;f.tick(6);assert.equal(effects,1);
});
test('crew mirrors leader stand crouch prone in source snapshots and speed; work and fallen pose retain precedence',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer');let stance='stand';f.ctx._effectivePlayerStance=()=>stance;f.api.bindTargets({canMove:()=>true});assert(f.api.rally({x:47,y:0,z:41}).ok);
 for(const [mode,speed]of [['stand',3],['crouch',1.5],['prone',.65]]){stance=mode;m.r=10;m.c=10;f.tick();assert(Math.abs((m.c-10)*4.1-speed*.05)<1e-8);assert.equal(f.api.getMember(m.id).posture,mode);const snapshot=f.api.decorateEntities([{id:'crew_'+m.id,hp:m.hp},{id:'ordinary',crouching:true}]);assert.equal(snapshot[0].crouching,mode==='crouch');assert.equal(snapshot[0].prone,mode==='prone');assert.equal(snapshot[1].crouching,true);}
 const target={id:'posture-panel',kind:'power_panel',powered:true,position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,canMove:()=>true});assert(f.api.command('disable_power',target).ok);f.tick();assert.equal(f.api.getAction(m.id).phase,'working');assert.equal(f.api.getMember(m.id).posture,'stand');
 m.hp=0;f.tick();const fallen=f.api.decorateEntities([{id:'crew_'+m.id,hp:0,dead:false}])[0];assert.equal(fallen.downed,true);assert.equal(fallen.prone,false);assert.equal(fallen.crouching,false);assert.equal(f.api.getAction(m.id),null);
});
test('QA movement diagnostic is read-only and preserves terminal action reason after cancellation',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer'),target={id:'diag-fence',kind:'fence',cuttable:true,position:{x:50,y:0,z:41}};f.api.bindTargets({get:()=>target,canMove:()=>false});f.api.command('cut_fence',target);f.tick();const movement=f.api.getMember(m.id).movement;assert.equal(movement.reason,'no_route');assert(movement.search.expanded>0);movement.goal.x=999;assert.notEqual(f.api.getMember(m.id).movement.goal.x,999);f.api.cancelCommand(m.id);assert.equal(f.api.getMember(m.id).movement.lastAction.reason,'cancelled');
 f.ctx.location.href='http://localhost/world.html';assert.equal(f.api.getMember(m.id).movement,undefined);
});
