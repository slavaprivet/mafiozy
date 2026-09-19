import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import vm from 'node:vm';
import {createWalkLifeInterrupt} from './walk_life_interrupt.mjs';
import {createMercenaryWalk} from './mercenary_walk.mjs';
import {createMercenarySquad} from './mercenary_core.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
class Element{
 constructor(tag){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.attrs={};this.style={};this.listeners=new Map();this.textContent='';this.value='';this.hidden=false;this.disabled=false;}
 append(...nodes){for(const n of nodes){n.parentNode=this;this.children.push(n);}}
 replaceChildren(...nodes){this.children.forEach(n=>n.parentNode=null);this.children=[];this.append(...nodes);}
 remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null;}}
 setAttribute(k,v){this.attrs[k]=v;}
 addEventListener(k,f){if(!this.listeners.has(k))this.listeners.set(k,[]);this.listeners.get(k).push(f);}
 removeEventListener(k,f){this.listeners.set(k,(this.listeners.get(k)||[]).filter(v=>v!==f));}
 emit(k,e={}){for(const f of this.listeners.get(k)||[])f(e);}
 focus(){}
}
const all=n=>[n,...n.children.flatMap(all)];
const key=(doc,code)=>{const e={code,key:code==='KeyV'?'v':code==='KeyE'?'e':code,target:new Element('div'),prevented:false,preventDefault(){this.prevented=true;this.defaultPrevented=true;},stopPropagation(){},stopImmediatePropagation(){}};doc.emit('keydown',e);return e;};
const document=new Element('document');document.body=new Element('body');document.createElement=tag=>new Element(tag);document.createElementNS=(ns,tag)=>new Element(tag);
const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(50,1,.1,200);camera.position.set(0,1,8);camera.lookAt(0,1,0);camera.updateMatrixWorld();
function mesh(name,x=0){const o=new THREE.Mesh(new THREE.BoxGeometry(2,2,2),new THREE.MeshBasicMaterial());o.name=name;o.position.set(x,1,0);scene.add(o);scene.updateMatrixWorld(true);return o;}
const car1=mesh('Car1'),car2=mesh('Car2',6);let damage1=0,damage2=0;
const fleet={records:[{id:'one',car:{object:car1},damage:{state:{maxHp:100},blastImpact(){damage1++;return true;}}},{id:'two',car:{object:car2},damage:{state:{maxHp:100},blastImpact(){damage2++;return true;}}}]};
let host=null,bound=null,bindingCount=0,blocked=false,time=1000,nearest='candidate';const commands=[];
const core=createMercenarySquad({now:()=>time,getMember:()=>({hp:100,position:{x:0,y:0,z:0}}),getTarget:id=>bound?.get(id),performEffect:e=>bound.performEffect(e)});
core.recruit({id:'demo',profession:'demolitions'});core.recruit({id:'safecracker',profession:'safecracker'});
const npcRows=[];const walk=createMercenaryWalk({THREE,document,camera,scene,getHost:()=>host,getFleet:()=>fleet,getTraffic:()=>null,getNpcs:()=>npcRows,getBuildings:()=>[],getRoots:()=>[scene],isBlocked:()=>blocked});
walk.update();assert.equal(bound,null,'Late source not invented');
host={bindTargets:v=>{bound=v;bindingCount++;},getRoster:()=>({members:[{id:'merc_resident_3',name:'Лука',profession:'demolitions',hp:100,maxHp:100,skills:[]}],candidates:[{id:'candidate',name:'Медик',profession:'medic'}]}),
  getActions:t=>core.availableActions(t).map(a=>({...a,id:a.kind,label:a.kind,enabled:a.available})),command:(id,t)=>{commands.push([id,t.id]);return {ok:true};},
  nearestCandidate:()=>nearest,canUseLocalEffects:()=>true};
walk.update();walk.update();assert.equal(bindingCount,1,'Bind source once on arrival');assert(bound);
walk.ui.open();assert(walk.isOpen);camera.lookAt(6,1,0);camera.updateMatrixWorld();
const bomb=all(walk.ui.element).find(n=>n.tagName==='BUTTON'&&n.textContent==='plant_bomb');assert(bomb,'Real core action reaches UI');bomb.emit('click');
await new Promise(r=>setImmediate(r));assert.deepEqual(commands,[['plant_bomb','fleet:one']],'Mouse-opened panel captures original target despite camera change');
walk.ui.close();walk.update(.3);const actionPrompt=all(document.body).find(n=>n.dataset.walkHud==='mercenary-action');assert(actionPrompt);assert.equal(actionPrompt.hidden,false);assert.match(actionPrompt.textContent,/X — plant_bomb/);
assert(key(document,'KeyX').prevented);await new Promise(r=>setImmediate(r));assert.deepEqual(commands.at(-1),['plant_bomb','fleet:two'],'X uses current aim rather than the old panel/hover target');
const oldActions=host.getActions,commandCount=commands.length;host.getActions=()=>[];walk.update(.3);assert.equal(actionPrompt.hidden,true);assert.equal(actionPrompt.style.display,'none');assert.equal(walk.selection.stats().selected,false,'vehicles keep action prompts without whole-body highlighting');key(document,'KeyX');await new Promise(r=>setImmediate(r));assert.equal(commands.length,commandCount,'no profession means no direct action');
host.getActions=()=>[{id:'plant_bomb',enabled:false,available:false,disabledReason:'busy'}];walk.update(.3);assert.equal(actionPrompt.hidden,true);key(document,'KeyX');await new Promise(r=>setImmediate(r));assert.equal(commands.length,commandCount,'busy profession is not offered');host.getActions=oldActions;
const oldCommand=host.command;let resolveCommand;host.command=(id,t)=>{commands.push([id,t.id]);return new Promise(resolve=>resolveCommand=resolve);};key(document,'KeyX');key(document,'KeyX');assert.equal(commands.length,commandCount+1,'one pending request cannot be duplicated');resolveCommand({ok:true});await new Promise(r=>setImmediate(r));host.command=oldCommand;
walk.ui.close();const blast={kind:'plant_bomb',targetId:'fleet:one',actionId:1};assert(bound.performEffect(blast).ok);assert(bound.performEffect(blast).duplicate);assert.equal(damage1,1);assert.equal(damage2,0,'Other vehicle never damaged');
blocked=true;assert.equal(key(document,'KeyE').prevented,false);assert.equal(walk.isOpen,false);blocked=false;nearest=null;assert.equal(key(document,'KeyE').prevented,false);
nearest='candidate';assert(key(document,'KeyE').prevented);assert(walk.isOpen);assert(walk.dialogue.isOpen,'E opens personal conversation');assert(!walk.ui.isOpen,'E does not open squad management');const interruption=createWalkLifeInterrupt({closeDialogs:()=>walk.interrupt()});interruption.apply({dead:true});assert(!walk.isOpen,'death closes the active recruitment conversation');interruption.dispose();
assert(walk.openMember('npc:crew_merc_resident_3'),'left HUD crew identity resolves to personal roster');assert.equal(walk.ui.selectedMemberId,'merc_resident_3');walk.ui.close();assert.equal(walk.openMember('unrelated'),false);blocked=true;assert.equal(walk.openMember('merc_resident_3'),false,'blocked game cannot open member');blocked=false;
car1.visible=false;car2.visible=false;camera.lookAt(0,1,0);camera.updateMatrixWorld();const safe=mesh('Safe');let ownerCalls=0,resolveOwner,physicalLocked=true;
safe.userData.locked=true;safe.userData.mercenaryTarget={id:'safe:actual',kind:'safe',unlock:()=>{ownerCalls++;return new Promise(resolve=>resolveOwner=()=>{physicalLocked=false;resolve({ok:true,opened:true});});}};
assert.equal(walk.targets.pick().id,'safe:actual');const effect={kind:'unlock_safe',targetId:'safe:actual',actionId:2};
const receipt=bound.performEffect(effect);assert(receipt instanceof Promise);assert.equal(bound.performEffect(effect),receipt);assert.equal(ownerCalls,1);assert.equal(physicalLocked,true);assert.equal(safe.userData.locked,true);
resolveOwner();assert((await receipt).ok);assert.equal(physicalLocked,false);assert.equal(safe.userData.locked,false);assert(bound.performEffect(effect).duplicate);
safe.visible=false;const power=mesh('Power panel');let powerCalls=0;power.userData.mercenaryTarget={id:'power:actual',kind:'power_panel',powered:true,disablePower:effect=>{powerCalls++;assert.equal(effect.requestId,'mercenary:4');return {ok:true};}};assert.equal(walk.targets.pick().id,'power:actual');const powerEffect={kind:'disable_power',targetId:'power:actual',actionId:3};host.canUseLocalEffects=()=>false;assert.equal(bound.performEffect(powerEffect).ok,false,'online panel cannot bypass source authority');assert.equal(powerCalls,0);host.canUseLocalEffects=()=>true;powerEffect.actionId=4;assert.equal(bound.performEffect(powerEffect).ok,true);assert.equal(powerCalls,1);assert(bound.performEffect(powerEffect).duplicate);power.visible=false;
safe.visible=false;const rallyFloor=new THREE.Mesh(new THREE.PlaneGeometry(30,30),new THREE.MeshBasicMaterial());rallyFloor.rotation.x=-Math.PI/2;scene.add(rallyFloor);scene.updateMatrixWorld(true);camera.position.set(0,5,8);camera.lookAt(0,0,0);camera.updateMatrixWorld();let rallies=0;host.rally=point=>{rallies++;assert(Math.abs(point.y)<1e-5);return {ok:true,count:1};};assert(key(document,'KeyX').prevented);assert.equal(rallies,1,'X dispatches actual ground point to squad');blocked=true;assert.equal(key(document,'KeyX').prevented,false);assert.equal(rallies,1);blocked=false;
await new Promise(r=>setImmediate(r));const patientMesh=mesh('Downed Ally');npcRows.push({id:'crew_patient',object:patientMesh});camera.position.set(0,1,8);camera.lookAt(0,1,0);camera.updateMatrixWorld();host.getMember=id=>id==='npc:crew_patient'?{id:'patient',kind:'npc',hp:0,downed:true,position:{x:0,y:1,z:0}}:null;host.getActions=t=>t.id==='patient'&&t.downed?[{id:'revive',enabled:true,label:'Поднять союзника'}]:[];walk.update(.3);assert.equal(walk.selection.stats().selected,true,'source HP descriptor retains hit geometry for patient highlight');assert.equal(actionPrompt.hidden,false);assert.match(actionPrompt.textContent,/Поднять союзника/);key(document,'KeyX');await new Promise(r=>setImmediate(r));assert.deepEqual(commands.at(-1),['revive','patient'],'revive dispatches canonical member id with true source state');
walk.dispose();assert.equal(bound,null);assert.equal(document.body.children.length,0);assert.equal(key(document,'KeyV').prevented,false);assert.equal(key(document,'KeyE').prevented,false);assert.equal(walk.targets.pick(),null);walk.dispose();
const html=readFileSync(new URL('../../../world.html',import.meta.url),'utf8');let scripts=0;
for(const match of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)){
 const attrs=match[1],type=attrs.match(/\btype\s*=\s*["']([^"']+)/i)?.[1];if(/\bsrc\s*=/i.test(attrs)||type&&!['text/javascript','application/javascript'].includes(type.toLowerCase()))continue;
 new vm.Script(match[2],{filename:`world.inline.${++scripts}.js`});
}
assert(scripts>0);const gang=html.slice(html.indexOf('function _updateGang(dt)'),html.indexOf('function _updateGang(dt)')+16000);
assert(gang.indexOf('mercenaryMeleePursuit')>=0);assert(gang.indexOf('MafioziMercenaryMelee?.step')>gang.indexOf('const pos = _gangTargetPos'));
assert(gang.indexOf('MafioziMercenaryMelee?.step')<gang.indexOf('const gangAi='));
console.log(`PASS mercenary walk: real Three picking/core actions, late binding, mouse panel fixed target, correct fleet once, E gating, async physical lock receipt, dispose; ${scripts} classic world scripts compile; melee hook ordering`);
// Source receipt survives eviction; actor replacement never updates disposed previous actor.
const trafficScene=new THREE.Scene(),trafficCamera=new THREE.PerspectiveCamera(),aOld=new THREE.Group(),aNew=new THREE.Group();trafficScene.add(aOld,aNew);
let trafficRecord={id:7,actor:{object:aOld},object:aOld},sourceMode='ok',sourceCalls=0;const visualRecords=[];
const traffic={getActor:id=>id===7?trafficRecord?.actor:null,getActors:()=>trafficRecord?[trafficRecord]:[]};
const trafficHost={getRoster:()=>({members:[],candidates:[]}),bindTargets(){},blastVehicle(){sourceCalls++;if(sourceMode==='gone')trafficRecord=null;return sourceMode==='reject'?false:true;}};
const tw=createMercenaryWalk({THREE,document,camera:trafficCamera,scene:trafficScene,getHost:()=>trafficHost,getFleet:()=>null,getTraffic:()=>traffic,getNpcs:()=>[],getBuildings:()=>[],getRoots:()=>[trafficScene],createDamage:(T,actor)=>{const r={actor,disposed:false,hits:0,updates:0,state:{maxHp:100},blastImpact(){this.hits++;return true;},update(){this.updates++;},dispose(){this.disposed=true;}};visualRecords.push(r);return r;}});tw.update();
assert(tw.targets.performEffect({kind:'plant_bomb',targetId:'traffic:7',actionId:80}).ok);assert.equal(visualRecords.length,1);tw.update();assert.equal(visualRecords[0].disposed,false,'numeric lookup remains tracked');
trafficRecord={id:7,actor:{object:aNew},object:aNew};tw.update();assert.equal(visualRecords[0].disposed,true,'replacement disposes old damage rig');assert(tw.targets.performEffect({kind:'plant_bomb',targetId:'traffic:7',actionId:81}).ok);assert.equal(visualRecords[1].actor.object,aNew);
sourceMode='reject';assert.equal(tw.targets.performEffect({kind:'plant_bomb',targetId:'traffic:7',actionId:82}).ok,false);assert.equal(visualRecords[1].hits,1,'rejection never runs visual blast');
sourceMode='gone';assert.equal(tw.targets.performEffect({kind:'plant_bomb',targetId:'traffic:7',actionId:83}).ok,true,'authoritative successful explosion is not undone by renderer eviction');tw.dispose();
const rejectedFleet={records:[{id:'reject',car:{object:aOld},damage:{state:{maxHp:100},blastImpact:()=>false}}]};const fw=createMercenaryWalk({THREE,document,camera:trafficCamera,scene:trafficScene,getHost:()=>({...trafficHost,canUseLocalEffects:()=>true}),getFleet:()=>rejectedFleet,getTraffic:()=>null,getNpcs:()=>[],getBuildings:()=>[],getRoots:()=>[trafficScene]});fw.update();assert.equal(fw.targets.performEffect({kind:'plant_bomb',targetId:'fleet:reject',actionId:84}).ok,false);fw.dispose();
console.log('PASS vehicle blast receipts, actor eviction/replacement, numeric traffic IDs and rejected fleet effects');
// Actual core follows a moving descriptor, restarts work if car drives away, then arms/retreats/detonates.
let driveTime=10,moveOrder=null,detonations=0;const movingMember={hp:100,position:{x:0,y:1,z:0}},movingCar=new THREE.Group();movingCar.position.set(12,1,0);trafficScene.add(movingCar);
const {createMercenaryTargets}=await import('./mercenary_targets.mjs');const mt=createMercenaryTargets({THREE,camera:trafficCamera,getRoots:()=>[trafficScene],getTraffic:()=>({getActors:()=>[{id:22,object:movingCar}]}),onVehicleBlast:()=>{detonations++;return true;}});
const movingCore=createMercenarySquad({now:()=>driveTime,getMember:()=>movingMember,getTarget:id=>mt.get(id),moveMember:(id,target)=>{moveOrder=target;},performEffect:e=>mt.performEffect(e)});movingCore.recruit({id:'moving_demo',profession:'demolitions'});assert(movingCore.command('moving_demo','plant_bomb','traffic:22').ok);movingCore.update();assert.equal(movingCore.getAction('moving_demo').phase,'approach');movingMember.position={...moveOrder.position};movingCore.update();assert.equal(movingCore.getAction('moving_demo').phase,'working');driveTime++;movingCar.position.x+=8;movingCore.update();assert.equal(movingCore.getAction('moving_demo').phase,'approach','moving target cannot be planted from old location');movingMember.position={...moveOrder.position};movingCore.update();driveTime+=.4;movingCore.update();assert.equal(movingCore.getAction('moving_demo').phase,'working');driveTime+=4;movingCore.update();assert.equal(movingCore.getAction('moving_demo').phase,'retreat');assert.equal(movingCore.snapshot().charges.length,1);driveTime++;movingCore.update();assert.ok(moveOrder&&Math.hypot(moveOrder.position.x-mt.get('traffic:22').center.x,moveOrder.position.z-mt.get('traffic:22').center.z)>=8);movingMember.position={...moveOrder.position};driveTime+=6;movingCore.update();assert.equal(detonations,1);movingCore.update();assert.equal(detonations,1);mt.dispose();
console.log('PASS moving car approach/work restart/plant/retreat/fuse and exactly one detonation');

// QA door is not a generic name-based unlock: both destructive actions need
// explicit metadata callbacks and the same local-world authority as fleet FX.
const {createMercenaryBreachDoor}=await import('./mercenary_breach_door.mjs');
const {createMercenaryChargeView}=await import('./mercenary_charge_view.mjs');
const {mercenaryActionTimerText}=await import('./mercenary_action_timers.mjs');
for(const method of ['breach_door','plant_bomb']){
 const ds=new THREE.Scene(),dc=new THREE.PerspectiveCamera(50,1,.1,200);dc.position.set(.6,1,-6);dc.lookAt(.6,1,0);dc.updateMatrixWorld();let localAllowed=false,exploded=0,doorBinding=null,chosen=null;
 const door=createMercenaryBreachDoor({THREE,site:{id:'door:'+method,x:0,z:0},onCollisionChange:()=>true,onBlast:()=>exploded++});ds.add(door.object);ds.updateMatrixWorld(true);
 const dh={getRoster:()=>({members:[],candidates:[]}),bindTargets:value=>doorBinding=value,canUseLocalEffects:()=>localAllowed,getActions:()=>[{id:'plant_bomb',label:'Подорвать',enabled:true},{id:'breach_door',label:'Выбить дверь',enabled:true}],command:(id)=>{chosen=id;return{ok:true};}};
 const dw=createMercenaryWalk({THREE,document,camera:dc,scene:ds,getHost:()=>dh,getFleet:()=>[],getTraffic:()=>null,getNpcs:()=>[],getBuildings:()=>door.getTargets(),getRoots:()=>[ds]});dw.update(.3);
 const target=dw.targets.pick();assert.equal(target.id,'door:'+method);assert.equal(target.breachable,true);assert.equal(target.bombable,true);assert.equal(target.lockpickable,false);assert.equal(target.workRange,.08);
 key(document,'KeyX');await new Promise(r=>setImmediate(r));assert.equal(chosen,null,'multiple enabled actions wait for explicit choice');assert(dw.actionMenu.isOpen);all(dw.actionMenu.element).find(n=>n.dataset.actionId===method).emit('click');await new Promise(r=>setImmediate(r));assert.equal(chosen,method,'X choice dispatches the chosen real profession action');assert(!dw.actionMenu.isOpen);
 const effect={kind:method,targetId:target.id,memberId:'specialist',actionId:501};assert.equal(doorBinding.performEffect(effect).ok,false);assert.equal(door.getState().locked,true,'no local physical mutation before authority');
 const chargeView=createMercenaryChargeView({THREE,scene:ds,getTarget:id=>doorBinding.get(id),getCharges:()=>[{actionId:502,targetId:target.id,armed:true,phase:'retreat',detonateAt:110}],nowSeconds:()=>100});chargeView.update();const charge=door.object.getObjectByName('Mercenary_Armed_Charge');assert(charge,'a real armed door charge is shown');assert(Math.abs(charge.position.x-.6)<1e-6);assert(Math.abs(charge.position.y-.85)<1e-6);assert(charge.position.z<-.08,'charge rests outside the authored face');
 localAllowed=true;assert.equal(doorBinding.performEffect(effect).ok,true);assert.equal(doorBinding.performEffect(effect).duplicate,true);assert.equal(exploded,method==='plant_bomb'?1:0);assert.equal(doorBinding.get(target.id).opened,true);for(let i=0;i<10;i++)door.update(.1);assert.equal(door.getState().opening,false);
 assert.match(mercenaryActionTimerText({kind:'breach_door',phase:'working',duration:2.5,progress:.5},0),/Выбивание двери · 1,3 с/);
 chargeView.dispose();dw.dispose();door.dispose();
}
console.log('PASS real QA door metadata/picking, explicit X kick/bomb choice, local authority, single kick/blast receipt, visible authored charge and work timer');

// Actual X input -> source queue -> persistent numbers -> promotion -> V clear.
{
 const qs=new THREE.Scene(),qc=new THREE.PerspectiveCamera(55,1.5,.1,200);qc.position.set(0,2,8);let qb,timeQ=50;
 const makeTarget=(id,x,kind)=>{const object=new THREE.Mesh(new THREE.BoxGeometry(1,1.8,.25),new THREE.MeshBasicMaterial());object.position.set(x,.9,0);object.userData.mercenaryTarget={id,kind,powered:kind==='power_panel',cuttable:kind==='fence',getApproachPosition:()=>new THREE.Vector3(x,0,-1),disablePower:()=>{object.userData.mercenaryTarget.powered=false;return{ok:true};},cut:()=>{object.userData.mercenaryCut=true;return{ok:true};}};qs.add(object);return object;};
 const switchbox=makeTarget('queue-switch',-2,'power_panel'),wire=makeTarget('queue-wire',2,'fence'),third=makeTarget('queue-third',4,'fence'),member={hp:60,position:{x:-2,y:0,z:-1}};
 const queueCore=createMercenarySquad({now:()=>timeQ,getMember:()=>member,getTarget:id=>qb?.get(id),performEffect:e=>qb.performEffect(e)});queueCore.recruit({id:'engineer',profession:'engineer'});
 const queueHost={bindTargets:b=>qb=b,getRoster:()=>({members:[{id:'engineer',name:'Елена',profession:'engineer',queued:queueCore.getQueue('engineer')}],candidates:[]}),getAction:id=>queueCore.getAction(id),getQueue:id=>queueCore.getQueue(id),getActions:t=>queueCore.availableActions(t).map(a=>({...a,id:a.kind,label:a.kind,enabled:a.available})),canUseLocalEffects:()=>true,command:(kind,t)=>queueCore.command('engineer',kind,t.id),follow:()=>{queueCore.cancel('engineer');return{ok:true};}};
 const qw=createMercenaryWalk({THREE,document,camera:qc,scene:qs,getHost:()=>queueHost,getFleet:()=>[],getTraffic:()=>null,getNpcs:()=>[],getBuildings:()=>[switchbox,wire,third],getRoots:()=>[qs]});qc.lookAt(-2,.9,0);qc.updateMatrixWorld();qs.updateMatrixWorld(true);qw.update(.3);
 key(document,'KeyX');await new Promise(r=>setImmediate(r));queueCore.update();const first=queueCore.getAction('engineer');assert.equal(first.targetId,'queue-switch');assert.equal(first.phase,'working');qc.lookAt(2,.9,0);qc.updateMatrixWorld();qw.update(.3);
 assert(all(document.body).some(n=>n.dataset.walkHud==='mercenary-action'&&n.textContent.includes('В очередь')));key(document,'KeyX');await new Promise(r=>setImmediate(r));assert.equal(queueCore.getAction('engineer').id,first.id);assert.equal(queueCore.getQueue('engineer')[0].targetId,'queue-wire');qw.updatePresentation(.016);assert.equal(qw.taskMarkers.stats().active,2);
 assert.equal(all(document.body).find(n=>n.dataset.taskTarget==='queue-switch').textContent,'1');assert.equal(all(document.body).find(n=>n.dataset.taskTarget==='queue-wire').textContent,'2');qc.lookAt(20,2,-20);qc.updateMatrixWorld();qw.update(.3);assert.equal(qw.taskMarkers.stats().active,2,'looking away retains accepted task markers');
 timeQ+=5;queueCore.update();member.position={x:2,y:0,z:-1};queueCore.update();qw.update(.3);assert.equal(queueCore.getAction('engineer').targetId,'queue-wire');assert.equal(qw.taskMarkers.stats().active,1);assert.equal(all(document.body).find(n=>n.dataset.taskTarget==='queue-wire').textContent,'1');
 assert(queueCore.command('engineer','cut_fence','queue-third').queued);qw.update(.3);assert.equal(qw.taskMarkers.stats().active,2);key(document,'KeyV');await new Promise(r=>setImmediate(r));qw.update(.3);assert.equal(queueCore.getQueue('engineer').length,0);assert.equal(qw.taskMarkers.stats().active,0);qw.dispose();
}
console.log('PASS X queues actual source job without cancelling first; persistent 1/2 markers promote and V clears');

// Wrecked fleet state must stop both the contextual prompt and source commands,
// even when the surviving render object has no destroyed userData flag.
{
 const ws=new THREE.Scene(),wc=new THREE.PerspectiveCamera(50,1,.1,100),object=new THREE.Mesh(new THREE.BoxGeometry(2,2,3),new THREE.MeshBasicMaterial());object.position.y=1;ws.add(object);wc.position.set(0,1,8);wc.lookAt(0,1,0);wc.updateMatrixWorld();ws.updateMatrixWorld(true);let wb;
 const damage={state:{hp:240,maxHp:240,wrecked:false,destroying:false},blastImpact:()=>true},records=[{id:'wreck-test',car:{object},damage}],wreckCore=createMercenarySquad({getMember:()=>({hp:60,position:{x:0,y:0,z:0}}),getTarget:id=>wb?.get(id)});wreckCore.recruit({id:'demo',profession:'demolitions'});
 const wh={bindTargets:b=>wb=b,getRoster:()=>({members:[],candidates:[]}),getActions:t=>wreckCore.availableActions(t).map(a=>({...a,id:a.kind,label:'Подорвать',enabled:a.available})),canUseLocalEffects:()=>true};
 const ww=createMercenaryWalk({THREE,document,camera:wc,scene:ws,getHost:()=>wh,getFleet:()=>({records}),getTraffic:()=>null,getNpcs:()=>[],getBuildings:()=>[],getRoots:()=>[ws]});ww.update(.3);assert(wreckCore.availableActions(wb.get('fleet:wreck-test')).length);damage.state={...damage.state,hp:0,wrecked:true};ww.update(.3);assert.equal(wb.get('fleet:wreck-test').valid,false);assert.equal(wreckCore.availableActions(wb.get('fleet:wreck-test')).length,0);assert.equal(wreckCore.command('demo','plant_bomb','fleet:wreck-test').reason,'invalid_target');assert.equal(ww.taskMarkers.stats().active,0);assert(!all(document.body).some(n=>n.dataset.walkHud==='mercenary-action'&&n.style.display==='block'&&n.textContent.includes('Подорвать')));ww.dispose();
}
console.log('PASS actual fleet wreck invalidates prompt, marker and source plant command');

// E selects a nearby visible member before a candidate/building, with fresh LOS.
{
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(55,1,.1,100);camera.position.set(0,2,7);camera.lookAt(0,1,0);camera.updateMatrixWorld();const body=new THREE.Mesh(new THREE.BoxGeometry(.5,2,.5),new THREE.MeshBasicMaterial());body.position.y=1;scene.add(body);scene.updateMatrixWorld(true);
 let live={id:'own',position:{x:0,y:0,z:0},hp:100},member={id:'own',name:'Марко',profession:'bruiser',hp:100},nearest=null,receipt={ok:true},dismisses=0;const talks=[],ends=[],focus={x:0,y:0,z:2};
 const host={bindTargets(){},getRoster:()=>({members:member?[member]:[],candidates:[{id:'candidate',name:'Другой',profession:'medic'}]}),getMember:id=>id==='own'?live:null,nearestCandidate:()=>nearest,beginConversation:id=>{talks.push(id);return receipt;},endConversation:id=>ends.push(id),dismiss:id=>{assert.equal(id,'own');dismisses++;member=null;live=null;return{ok:true};}};
 const ownWalk=createMercenaryWalk({THREE,document,camera,scene,getHost:()=>host,getFleet:()=>[],getTraffic:()=>[],getNpcs:()=>[{id:'crew_own',object:body}],getBuildings:()=>[],getRoots:()=>[scene],getFocus:()=>focus});ownWalk.update(.3);nearest='candidate';assert(key(document,'KeyE').prevented);assert.equal(talks.at(-1),'own');assert(ownWalk.dialogue.isOpen);assert(!ownWalk.ui.isOpen);assert(all(ownWalk.dialogue.element).some(n=>n.textContent==='Уволить бойца'));ownWalk.dialogue.close();assert.equal(ends.at(-1),'own');nearest=null;
 live.position.z=-1;assert.equal(key(document,'KeyE').prevented,false,'out of 2.5m does not consume building E');live.position.z=0;const wall=new THREE.Mesh(new THREE.BoxGeometry(5,5,.2),new THREE.MeshBasicMaterial());wall.position.set(0,2,1);scene.add(wall);scene.updateMatrixWorld(true);assert.equal(key(document,'KeyE').prevented,false,'wall prevents talking through it');wall.visible=false;
 live.hp=0;assert.equal(key(document,'KeyE').prevented,false,'downed teammate remains medical target');live.hp=100;receipt={ok:false,reason:'Разговор отклонён'};assert(key(document,'KeyE').prevented);assert.equal(ownWalk.dialogue.isOpen,false,'object receipt rejection is respected');receipt={ok:true};key(document,'KeyE');const dismiss=all(ownWalk.dialogue.element).find(n=>n.textContent==='Уволить бойца');dismiss.emit('click');dismiss.emit('click');await new Promise(r=>setImmediate(r));assert.equal(dismisses,1);assert(!ownWalk.dialogue.isOpen);ownWalk.dispose();
}
console.log('PASS own E priority, distance, wall LOS, downed/source rejection and one authoritative dismissal');

// Chatter subscribes after real source binding and follows source replacement.
{
 document.body.clientWidth=800;document.body.clientHeight=600;const cs=new THREE.Scene(),cc=new THREE.PerspectiveCamera();cc.position.set(0,2,8);cc.lookAt(0,1,0);cc.updateMatrixWorld();let current=null,firstBindings=0,secondBindings=0,firstDisposed=0,secondDisposed=0,emit;
 const base={bindTargets(){},getRoster:()=>({members:[],candidates:[]}),getChatterSettings:()=>({volume:0}),getMember:()=>({hp:100})};
 const cw=createMercenaryWalk({THREE,document,camera:cc,scene:cs,getHost:()=>current,getFocus:()=>({x:0,y:0,z:0}),getFleet:()=>[],getTraffic:()=>[],getNpcs:()=>[],getBuildings:()=>[],getRoots:()=>[cs]});cw.update();assert.equal(cw.chatter,null);current={...base,bindChatter:fn=>{firstBindings++;emit=fn;return()=>firstDisposed++;}};cw.update();cw.update();assert.equal(firstBindings,1);emit({seq:1,at:Date.now(),speakerId:'player',kind:'follow',name:'Босс'});assert.equal(cw.chatter.stats().spoken,1);assert(all(document.body).some(n=>n.dataset.mercenaryChatter==='true'&&n.style.display==='block'));current={...base,bindChatter:fn=>{secondBindings++;emit=fn;return()=>secondDisposed++;}};cw.update();assert.equal(firstDisposed,1);assert.equal(secondBindings,1);assert.equal(cw.chatter.stats().spoken,0);assert.equal(all(document.body).filter(n=>n.dataset.mercenaryChatter==='true').length,1);cw.dispose();assert.equal(secondDisposed,1);assert.equal(all(document.body).filter(n=>n.dataset.mercenaryChatter==='true').length,0);
}
console.log('PASS chatter late-host subscription, replacement unsubscribe and one caption lifecycle');
