import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';import {createNpcPopulation} from './npc_population.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const population=await createNpcPopulation({THREE,scene:new THREE.Scene(),loader:new GLTFLoader(),cloneSkeleton:clone,maxActors:4,cacheSeconds:8}),failures=[],checks=[],evidence={};
const row=(id,x=0,moving=true)=>({id,r:0,c:x/4.1,walking:moving,ang:0,weapon:'fists',role:'civilian',look:{gender:0}});
const check=(name,run)=>{try{run();checks.push(name);}catch(e){failures.push({name,error:e.message});}};
check('sub8m reentry does not inherit a many-second interpolation',()=>{
 const id='review_reentry';population.sync([row(id,0,false)],1);population.update(.05,1);population.sync([],1.1);population.update(.05,1.1);population.sync([row(id,4,false)],6);population.update(.05,6);population.update(.1,6.1);
 const x=population.getActor(id).object.position.x;evidence.reentry={target:4,renderedAt100ms:x};assert(Math.abs(x-4)<.01,'reentry leaves visible actor at '+x+' instead of current source position 4');
});
check('restart after retained walking intent is not stretched across the whole stopped interval',()=>{
 const id='review_blocked';population.sync([row(id)],10);population.update(.05,10);
 for(let i=1;i<=50;i++){population.sync([row(id)],10+i*.1);population.update(.1,10+i*.1);}
 population.sync([row(id,.16)],15.1);population.update(.1,15.1);population.update(.1,15.2);
 const x=population.getActor(id).object.position.x;evidence.restart={target:.16,renderedAt100ms:x};assert(x>.10,'new 100ms move is interpolated over five seconds; x='+x);
});
check('ordinary stopped intent resets its next movement anchor',()=>{
 const id='review_stop_start';population.sync([row(id,0,false)],20);population.update(.05,20);
 for(let i=1;i<=20;i++){population.sync([row(id,0,false)],20+i*.1);population.update(.1,20+i*.1);}
 population.sync([row(id,.16,true)],22.1);population.update(.1,22.1);population.update(.1,22.2);assert(Math.abs(population.getActor(id).object.position.x-.16)<.001);
});
check('teleport snaps without injecting walking distance',()=>{
 const id='review_teleport';population.sync([row(id)],30);population.update(.05,30);const actor=population.getActor(id),update=actor.update;let received;
 actor.update=(dt,snapshot)=>{received={distance:snapshot.gaitDistance,speed:snapshot.motionSpeed,moving:snapshot.moving};return update(dt,snapshot);};
 population.sync([row(id,20)],30.1);population.update(.1,30.1);assert.equal(actor.object.position.x,20);assert.equal(received.distance,0);assert.equal(received.moving,false);actor.update=update;
});
check('250ms source/100ms sampling stops both translation and gait after its last target',()=>{
 const id='review_cadence';population.sync([row(id)],40);population.update(.05,40);const actor=population.getActor(id),update=actor.update,samples=[];
 actor.update=(dt,snapshot)=>{samples.push({time:snapshot.time,distance:snapshot.gaitDistance,moving:snapshot.moving,speed:snapshot.motionSpeed});return update(dt,snapshot);};
 for(let i=1;i<=120;i++){const elapsed=i*.05,time=40+elapsed;if(i%2===0)population.sync([row(id,Math.floor((Math.min(elapsed,3)+1e-7)/.25)*.25*1.6,elapsed<3)],time);population.update(.05,time);}
 const late=samples.filter(x=>x.time>45);assert(late.every(x=>!x.moving&&x.distance===0));assert(Math.abs(actor.object.position.x-4.8)<1e-6);evidence.cadenceLast=late.at(-1);actor.update=update;
});
check('yaw-only duplicate packets cannot restart translational interpolation',()=>{
 const a='review_fixed_yaw',b='review_turning_yaw';population.sync([row(a),row(b)],50);population.update(.05,50);
 population.sync([row(a,.48),row(b,.48)],50.3);population.update(.1,50.4);
 population.sync([row(a,.48),{...row(b,.48),ang:.2}],50.4);population.update(.05,50.45);
 const fixed=population.getActor(a).object.position.x,turning=population.getActor(b).object.position.x;evidence.yawOnly={fixed,turning};assert(Math.abs(fixed-turning)<1e-7,'same physical source path accelerates when only facing changes');
});
population.dispose();console.log(JSON.stringify({checks,failures,evidence},null,2));if(failures.length)process.exitCode=1;
