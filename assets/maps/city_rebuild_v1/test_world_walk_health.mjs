import assert from 'node:assert/strict';
import {createWorldWalkHealth,readWorldWalkHealth,worldWalkHealthSurfaceReceipt,synchronizeWorldWalkHealthSurface} from './world_walk_health.mjs';
let tests=0;function test(name,fn){fn();tests++;console.log('PASS',name)}
const state=(hp,version=1,extra={})=>({hp,dead:hp<=0,combat_state:{body:{current:hp,max:100,dead:hp<=0},combat_version:version},...extra});

test('world HP is read without mutation, no render-side health or false default maximum',()=>{
 const source=state(63),before=JSON.stringify(source),bridge={getPlayerState:()=>source},health=createWorldWalkHealth({bridge,now:()=>1000}),frame=health.update({actorKey:{}});
 assert.equal(frame.snapshot.hp,63);assert.equal(frame.snapshot.max,100);assert.equal(frame.snapshot.dead,false);assert.equal(frame.events.length,0);assert.equal(frame.actorSync.dead,false);assert.equal(JSON.stringify(source),before);
 assert.equal(readWorldWalkHealth({hp:5000}).hp,5000);assert.equal(readWorldWalkHealth({hp:5000}).max,null);assert.equal(readWorldWalkHealth({hp:null}).available,false);
});
test('arrest downed and temporary melee stun never become permanent death at positive HP',()=>{
 for(const extra of [{dead:true,arrestPhase:'downed'},{dead:true,arrestPhase:'awaiting_pickup'},{dead:true,arrest:{down:true}},{dead:true,meleeStunned:{remaining:1.2,startedAt:400}},{meleeStunned:true}]){const health=createWorldWalkHealth({now:()=>1000}),frame=health.update({source:state(47,1,extra)});assert.equal(frame.snapshot.dead,false);assert.equal(frame.inputsBlocked,true);assert.equal(frame.events.length,0);const free=health.update({source:state(47,2)});assert.equal(free.inputsBlocked,false);assert.equal(free.events.some(e=>e.type==='restore'),false)}
 const custody=readWorldWalkHealth(state(0,3,{arrestPhase:'downed',meleeStunned:true}));assert.equal(custody.dead,false,'police custody uses zero HP for a living downed prisoner');assert.equal(custody.custodyOwned,true);assert.equal(custody.inputsBlocked,true);assert.equal(readWorldWalkHealth(state(60,3,{meleeStunned:{remaining:0}})).inputsBlocked,false);
});
test('death/restore edges occur once per actual lifecycle transition and guard persists through missing data',()=>{
 const health=createWorldWalkHealth(),actor={};health.update({source:state(100,3),actorKey:actor,time:1000});
 let frame=health.update({source:state(0,4),actorKey:actor,time:1010});assert.deepEqual(frame.events.map(e=>e.type),['death']);assert.equal(frame.inputsBlocked,true);assert.equal(frame.reaction.kind,'dead');assert.equal(frame.reaction.age,0);
 const receipt=worldWalkHealthSurfaceReceipt(frame.events[0]);assert.equal(receipt.confirmed,true);assert.equal(receipt.fatal,true);assert.ok(!('point' in receipt));
 frame=health.update({source:state(0,4),actorKey:actor,time:1100});assert.equal(frame.events.length,0);assert.equal(frame.inputsBlocked,true);
 frame=health.update({source:null,time:1300});assert.equal(frame.snapshot.available,false);assert.equal(frame.snapshot.dead,true);assert.equal(frame.inputsBlocked,true);assert.equal(frame.events.length,0);
 frame=health.update({source:state(40,5),time:1400});assert.deepEqual(frame.events.map(e=>e.type),['restore']);assert.equal(frame.inputsBlocked,false);assert.equal(frame.reaction,null);assert.equal(health.update({source:state(40,5),time:1500}).events.length,0);
});
test('older combat versions cannot resurrect or repeat a death, same-version local emergency restore is supported',()=>{
 const health=createWorldWalkHealth();health.update({source:state(100,5),time:0});health.update({source:state(0,6),time:10});let frame=health.update({source:state(100,5),time:20});assert.equal(frame.snapshot.stale,true);assert.equal(frame.snapshot.dead,true);assert.equal(frame.events.length,0);
 frame=health.update({source:state(0,6,{hp:40,dead:false}),time:30});assert.equal(frame.snapshot.hp,40);assert.equal(frame.snapshot.dead,false,'stale body.current=0/dead cannot overrule a positive explicit restored myHp');assert.deepEqual(frame.events.map(e=>e.type),['restore']);
});
test('initial death and a replacement actor synchronize settled death without replaying a fall or impact',()=>{
 const health=createWorldWalkHealth(),a={},b={};let frame=health.update({source:state(0,7,{impact:{stamp:900,age:100,power:2}}),actorKey:a,time:1000});assert.equal(frame.events.length,0);assert.equal(frame.actorSync.dead,true);assert.ok(frame.actorSync.reaction.age>=1);assert.ok(frame.reaction.age>=1);
 frame=health.update({source:state(0,7,{impact:{stamp:900,age:200,power:2}}),actorKey:b,time:1100});assert.equal(frame.events.length,0);assert.equal(frame.actorSync.reason,'actor-replaced');assert.ok(frame.reaction.age>=1);
 assert.equal(health.update({source:state(0,7),actorKey:b,time:1200}).actorSync,null);
 const live=createWorldWalkHealth();live.update({source:state(100,0),actorKey:a,time:0});live.update({source:state(0,1),actorKey:a,time:10});assert.ok(live.update({source:state(0,1),actorKey:b,time:20}).reaction.age>=1);
});
test('actual bridge stamp and raw at aliases dedupe independently of combat version and actor replacement',()=>{
 const health=createWorldWalkHealth(),a={},b={};health.update({source:state(100,1,{impact:{stamp:20,age:500,power:1}}),actorKey:a,time:1000});
 let frame=health.update({source:state(90,2,{impact:{stamp:1000,age:30,power:1,angle:1.3,kind:'bullet',bodyPart:'torso'}}),actorKey:a,time:1030});assert.deepEqual(frame.events.map(e=>e.type),['impact']);assert.equal(frame.reaction.kind,'hit');assert.equal(frame.reaction.age,.03);assert.equal(frame.events[0].bodyPart,'torso');assert.ok(!('point' in frame.events[0]));assert.equal(worldWalkHealthSurfaceReceipt(frame.events[0]),null);
 frame=health.update({source:state(80,3,{impact:{at:1000,age:80,power:1}}),actorKey:b,time:1080});assert.equal(frame.events.length,0,'version/rig change cannot replay one accepted stamp');
 frame=health.update({source:state(70,4,{impact:{at:900,age:180,power:1}}),time:1100});assert.equal(frame.events.length,0,'out-of-order old impact is ignored');
 frame=health.update({source:state(65,5,{impact:{at:1130,age:0,power:1}}),time:1130});assert.deepEqual(frame.events.map(e=>e.type),['impact']);assert.equal(health.update({source:state(65,5),time:1700}).reaction,null);
});
test('expired telemetry and missing impact stamps do not synthesize wounds/reactions from a HP delta',()=>{
 const health=createWorldWalkHealth();health.update({source:state(100),time:1000});let frame=health.update({source:state(70,2),time:1100});assert.equal(frame.events.length,0);assert.equal(frame.reaction,null);
 frame=health.update({source:state(60,3,{impact:{stamp:50,age:1100,power:2}}),time:1200});assert.equal(frame.events[0].type,'impact');assert.equal(frame.reaction,null);assert.equal(worldWalkHealthSurfaceReceipt(frame.events[0],{confirmed:true,point:{x:1,y:NaN,z:0}}),null);
 const receipt=worldWalkHealthSurfaceReceipt(frame.events[0],{confirmed:true,point:{x:1,y:2,z:3},normal:{x:0,y:0,z:1},zone:'head',side:-1});assert.deepEqual(receipt.point,{x:1,y:2,z:3});assert.equal(receipt.zone,'head');assert.equal(receipt.side,-1);
});
test('surface synchronization uses the target rig snapshot and no contact or receipt replay',()=>{
 let saved={version:1,time:4,reaction:{kind:'idle',age:0,side:1,zone:null},receipts:['existing'],wet:{rig:'female'},wounds:{rig:'female'}},restored=null,resets=0;
 const surface={state:{kind:'idle'},snapshot:()=>saved,restore:(s,options)=>{restored={s,options}},reset:()=>resets++};
 assert.equal(synchronizeWorldWalkHealthSurface(surface,{dead:true,reaction:{age:7}},{time:9}),true);assert.equal(restored.s.wet,saved.wet);assert.equal(restored.s.wounds,saved.wounds);assert.equal(restored.s.reaction.age,7);assert.deepEqual(restored.s.receipts,['existing']);assert.equal(restored.options.time,9);assert.equal(saved.reaction.kind,'idle');
 surface.state.kind='dead';synchronizeWorldWalkHealthSurface(surface,{dead:false});assert.equal(resets,1);assert.equal(synchronizeWorldWalkHealthSurface(null,{dead:true}),false);
});
test('lifecycle is deterministic with regressing render time, supports body-only data and disposes safely',()=>{
 const health=createWorldWalkHealth();health.update({source:{combat_state:{body:{current:100,max:120,dead:false,version:1}}},time:100});const dead=health.update({source:{combat_state:{body:{current:0,max:120,dead:true,version:2}}},time:200});assert.equal(dead.snapshot.max,120);assert.equal(health.update({source:null,time:150}).reaction.age,0);assert.throws(()=>health.update({time:NaN}),/finite/);health.dispose();health.dispose();assert.throws(()=>health.update({time:300}),/disposed/);
});
test('bridge read failure preserves death/input guard and reports its error without fake restore',()=>{
 let failing=false;const health=createWorldWalkHealth({now:()=>1000,bridge:{getPlayerState(){if(failing)throw Error('world reconnecting');return state(0,4)}}});health.update();failing=true;const frame=health.update();assert.equal(frame.snapshot.available,false);assert.equal(frame.snapshot.dead,true);assert.equal(frame.inputsBlocked,true);assert.equal(frame.sourceError,'world reconnecting');assert.equal(frame.events.length,0);
});
test('zero-HP arrest remains nonfatal through every custody phase and explicit world lifecycle beats stale body state',()=>{
 const health=createWorldWalkHealth();health.update({source:state(100,1,{healthDead:false,healthCustody:false}),time:0});for(const [i,phase]of ['downed','cuffing','escort','loading','transport','unloading','handoff','prison_escort','booking'].entries()){const frame=health.update({source:state(0,i+2,{healthDead:true,healthCustody:true,arrestPhase:phase}),time:i*10+10});assert.equal(frame.snapshot.deathConfirmed,false);assert.equal(frame.snapshot.dead,false);assert.equal(frame.inputsBlocked,true);assert.equal(frame.events.length,0);assert.equal(frame.reaction,null)}
 let frame=health.update({source:state(0,15,{hp:40,healthDead:false,healthCustody:false,dead:false,arrestPhase:'prisoner'}),time:200});assert.equal(frame.snapshot.dead,false);assert.equal(frame.inputsBlocked,false);assert.equal(frame.events.length,0);
 const positive=readWorldWalkHealth(state(25,3,{healthDead:true,healthCustody:false}));assert.equal(positive.dead,true);assert.equal(positive.deathSource,'world-health');
 const zero=readWorldWalkHealth(state(0,4,{healthDead:false,healthCustody:false,dead:false}));assert.equal(zero.dead,false,'explicit authoritative alive phase must not be overridden by a transient zero HP sample');
 const takeover=createWorldWalkHealth();takeover.update({source:state(100),time:0});takeover.update({source:state(0,2),time:10});frame=takeover.update({source:state(0,3,{arrestPhase:'cuffing'}),time:20});assert.equal(frame.events[0].reason,'custody-takeover');assert.equal(frame.inputsBlocked,true);
});
console.log(JSON.stringify({status:'PASS',tests}));
