import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {JUMP,jumpDirection,launchJump,tryDiveJump,stepJump} from './hero_jump.mjs';
import {createHeroPosture,requestHeroPosture,resetHeroPosture,posturePresentation} from './hero_posture.mjs';
import {resolveJumpSurface} from './surface_motion.mjs';
import {LANDING_POSTURE_SECONDS} from './hero_pose_transition.mjs';
const source=fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8');
const binding=source.slice(source.indexOf('const keys=new Set();'),source.indexOf('function updateJump(dt)'));
const postureBinding=source.slice(source.indexOf('let landingEyeTransition='),source.indexOf('function resetFootSupport()'));
const updateBinding=source.slice(source.indexOf('function updateJump(dt)'),source.indexOf('const releaseControls='));
assert.ok(binding.includes('beginJump(e.timeStamp)'));
function session(){
 const events={};const c={sourceVehicleActive:()=>false,worldHealthFrame:null,heroCover:{leave(){}},toggleHeroCover(){},nearestInteraction:()=>null,LANDING_POSTURE_SECONDS,JUMP,jumpDirection,launchJump,tryDiveJump,stepJump,resolveJumpSurface,requestHeroPosture,resetHeroPosture,posturePresentation,performance:{now:()=>9000},
  addEventListener:(name,fn)=>(events[name]??=[]).push(fn),hudInputBlocked:()=>false,arsenalOpen:()=>false,artistSwimming:()=>false,artistBusy:()=>false,artistAction:{action:{type:'none'}},
  tryBeginTraversal:()=>false,updateTraversal:()=>null,traversalWorld:{pointFits:(x,z,y,height)=>c.pedestrianAllowed(x,z)&&c.groundHeight(x,z)<=y+.28&&c.ceilingHeight(x,z)>=y+height-.03,supportHeight:(...args)=>c.groundHeight(...args)},
  hero:{object:{position:{x:0,y:0,z:0,set(x,y,z){this.x=x;this.y=y;this.z=z}},rotation:{y:0}},reset(){},blendIntoPosture(seconds){c.poseBlendCalls.push(seconds)}},heroPosture:createHeroPosture(),surfaceMotion:{state:{grounded:true},reset(position,state){this.state={...state}}},walking:true,occupiedSeat:null,transition:null,jump:null,heroBlast:null,busy:false,jumpCount:0,
  controls:{target:{clone:()=>({sub:()=>({x:0,z:1})})}},camera:{position:{}},$:()=>({hidden:true}),groundHeight:()=>0,heroGroundHeight:(...args)=>c.groundHeight(...args),heroCeilingHeight:(...args)=>c.ceilingHeight(...args),verticalNavigation:{active:false,slideDown:()=>true},nearestInteraction:()=>null,buildingQaMove:null,entryHeld:0,pointerHeld:false,
  canOccupyPostureHeight:()=>true,animationQaMoveUntil:0,animationQaMoveDirection:null,animationQaJumpPending:false,exitNotice:'',exitNoticeUntil:0,postureMotion:null,poseBlendCalls:[],pedestrianAllowed:()=>true,ceilingHeight:()=>Infinity,document:{body:{dataset:{}}}};
 vm.createContext(c);vm.runInContext(postureBinding+'\n'+binding+'\n'+updateBinding,c);
 const event=(name,code,timeStamp,repeat=false,tagName='CANVAS')=>{for(const fn of events[name]??[])fn({code,timeStamp,repeat,target:{tagName},preventDefault(){}})};
 return {c,event};
}
for(const code of ['KeyW','KeyA','KeyS','KeyD']){
 const {c,event}=session();event('keydown',code,990);event('keydown','Space',1000);
 assert.equal(c.jump.mode,'normal');assert.equal(c.jump.startedAt,1000,'use input timestamp, not delayed render clock');assert.ok(c.jump.directional);
 c.jump=stepJump(c.jump,.1,()=>true);const y=c.jump.y;event('keydown','Space',1100,true);assert.equal(c.jump.mode,'normal','held key cannot double-tap');
 event('keyup','Space',1150);event('keydown','Space',1450);assert.equal(c.jump.mode,'dive',code+' second real press');assert.equal(c.jump.y,y);assert.equal(c.jumpCount,1);
 event('keyup','Space',1460);event('keydown','Space',1470);assert.equal(c.jumpCount,1);
}
const stationary=session();stationary.event('keydown','Space',1000);assert.equal(stationary.c.jump.directional,false);stationary.event('keyup','Space',1010);stationary.event('keydown','Space',1200);assert.equal(stationary.c.jump.mode,'dive');assert.equal(stationary.c.jump.dz,1);
const late=session();late.event('keydown','Space',1000);late.event('keyup','Space',1010);late.event('keydown','Space',1510);assert.equal(late.c.jump.mode,'normal');
const car=session();car.c.occupiedSeat='driver';car.event('keydown','Space',1000);assert.equal(car.c.jump,null);assert.equal(vm.runInContext("keys.has('Space')",car.c),true,'Space remains vehicle handbrake');
console.log('PASS actual /walk keyboard bindings: WASD, normal, repeat ignored, release+second press, delayed handler clock, stationary dive, late press, vehicle handbrake');
for(const [code,target]of [['KeyC','crouch'],['KeyC','crouch'],['KeyZ','prone']]){
 const {c,event}=session();event('keydown','Space',1000);c.jump=stepJump(c.jump,.1,()=>true);event('keyup','Space',1110);event('keydown','Space',1150);assert.equal(c.jump.mode,'dive');
 const before={...c.jump};event('keydown',code,1160);assert.equal(c.jump.queuedPosture,target,code+' must queue desired landing posture during a dive');assert.equal(c.heroPosture.target,'stand','queue cannot change air pose/controller early');assert.equal(c.heroPosture.value,0);
 for(const key of ['x','y','z','elapsed','progress','mode'])assert.equal(c.jump[key],before[key],'posture key cannot restart or alter trajectory '+key);
 event('keydown',code,1170,true);assert.equal(c.jump.queuedPosture,target,'keyboard repeat cannot cancel queued posture');
 event('keyup',code,1180);event('keydown',code,1190);assert.equal(c.jump.queuedPosture??c.heroPosture.target,'stand','second press toggles against queued posture');
 event('keyup',code,1200);event('keydown',code,1210);assert.equal(c.jump.queuedPosture,target,'third press requeues posture');
}
{
 const {c,event}=session();event('keydown','Space',1000);event('keydown','KeyC',1010);event('keydown','KeyZ',1020);assert.equal(c.jump.queuedPosture,'prone','Z overrides crouch queue');event('keyup','KeyC',1030);event('keydown','KeyC',1040);assert.equal(c.jump.queuedPosture,'crouch','C overrides prone queue');
}
for(const [guard,value]of [['occupiedSeat','driver'],['transition',{}],['heroBlast',{}],['busy',true],['walking',false],['hero',null]]){
 const {c,event}=session();event('keydown','Space',1000);c[guard]=value;event('keydown','KeyC',1010);event('keydown','KeyZ',1020);assert.equal(c.jump.queuedPosture,undefined,guard+' must retain posture admission guard');
}
for(const tagName of ['INPUT','SELECT','TEXTAREA']){
 const {c,event}=session();event('keydown','Space',1000);event('keydown','KeyZ',1010,false,tagName);assert.equal(c.jump.queuedPosture,undefined,'typing cannot queue a landing pose');
}
{
 const {c,event}=session();event('keydown','Space',1000);c.arsenalOpen=()=>true;event('keydown','KeyZ',1010);assert.equal(c.jump.queuedPosture,undefined,'arsenal menu retains input guard');
}
for(const [code,target]of [['KeyC','crouch'],['KeyZ','prone']]){
 const {c,event}=session();event('keydown','Space',1000);event('keyup','Space',1020);event('keydown','Space',1100);event('keydown',code,1110);
 let elapsed=0;while(c.jump&&elapsed<JUMP.flight-.03){vm.runInContext('updateJump(.02)',c);elapsed+=.02;if(elapsed<JUMP.flight-.03)assert.equal(c.heroPosture.target,'stand','do not apply queued posture before ground contact')}
 assert.ok(c.jump,'flight cannot terminate before contact');while(c.jump&&elapsed<JUMP.flight+.08){vm.runInContext('updateJump(.02)',c);elapsed+=.02}
 assert.equal(c.jump,null,'queued pose must apply on contact, without waiting .45s recovery');assert.equal(c.heroPosture.target,target);assert.equal(c.heroPosture.value,target==='prone'?2:1,'posture controller switches immediately on contact');assert.equal(c.poseBlendCalls.length,1,'landing captures one blend source');assert.equal(c.poseBlendCalls[0],LANDING_POSTURE_SECONDS);assert.ok(c.hero.object.position.y>=-.001&&c.hero.object.position.y<.021,'grounded landing root');
}
{
 // Walking off an elevated support while diving must not consume the queue at
 // nominal flight end: it belongs to actual lower-ground contact.
 const {c,event}=session();c.groundHeight=()=>3;event('keydown','Space',1000);event('keydown','KeyZ',1010);c.hero.object.position.y=3;c.groundHeight=()=>0;
 let elapsed=0;while(c.jump&&elapsed<JUMP.flight+.02){vm.runInContext('updateJump(.02)',c);elapsed+=.02}
 assert.ok(c.jump,'still airborne over lower ground at nominal flight end');assert.equal(c.heroPosture.target,'stand');assert.equal(c.jump.queuedPosture,'prone');
 while(c.jump&&elapsed<3){vm.runInContext('updateJump(.02)',c);elapsed+=.02}
 assert.equal(c.jump,null);assert.equal(c.heroPosture.target,'prone','queued pose eventually applies on actual ground');assert.equal(c.poseBlendCalls.length,1);
}
console.log('PASS actual C/Z landing queue, repeats, queue-aware toggles, admission guards, immediate grounded posture and lower-ground deferral');

// Use the real movement-frame modifier calculation, not a duplicate helper.
const speedBinding=source.slice(source.indexOf('let moved=false,carStepped=false;'),source.indexOf('postureMotion=posturePresentation(heroPosture,{running,slowWalking});')+'postureMotion=posturePresentation(heroPosture,{running,slowWalking});'.length);
assert.ok(speedBinding.includes('slowWalking'));
for(const alt of ['AltLeft','AltRight'])for(const shift of ['ShiftLeft','ShiftRight']){
 const {c,event}=session(),speed=()=>vm.runInContext('(()=>{'+speedBinding+'return {running,slowWalking,speed:postureMotion.maxSpeed}})()',c);
 assert.equal(speed().speed,4.6);event('keydown',shift,10);assert.equal(speed().speed,7.8);assert.equal(speed().running,true);
 event('keydown',alt,20);assert.equal(speed().speed,1.65);assert.equal(speed().running,false);assert.equal(speed().slowWalking,true);
 event('keyup',alt,30);assert.equal(speed().speed,7.8);event('keyup',shift,40);assert.equal(speed().speed,4.6);
 for(const target of ['crouch','prone']){resetHeroPosture(c.heroPosture,target);event('keydown',shift,50);event('keydown',alt,60);assert.equal(speed().speed,target==='crouch'?1.55:.8);event('keyup',alt,70);assert.equal(speed().speed,target==='crouch'?1.55:.8);event('keyup',shift,80)}
}
console.log('PASS actual movement frame: normal/Shift/held Alt, both modifier sides, Alt priority/release, crouch/prone unchanged');

{const {c,event}=session();c.verticalNavigation.active=true;event('keydown','Space',1000);assert.equal(c.jump,null,'ladder locks jump');event('keydown','KeyC',1010);assert.equal(c.heroPosture.target,'stand','ladder retains standing climb pose');}

for(const swimming of [false,true]){
 const {c,event}=session();let attempts=0;c.artistSwimming=()=>swimming;c.surfaceMotion.state.grounded=!swimming;
 c.tryBeginTraversal=direction=>{attempts++;assert.equal(direction.z,1);c.jump={mode:'traversal'};return true;};
 event('keydown','Space',1000);assert.equal(attempts,1,'Space probes reachable ledge even while swimming');assert.equal(c.jump.mode,'traversal');
 event('keyup','Space',1010);event('keydown','Space',1200);assert.equal(attempts,1);assert.equal(c.jump.mode,'traversal','double-tap cannot replace a climb with a dive');
}
{const {c,event}=session();c.artistSwimming=()=>true;c.surfaceMotion.state.grounded=false;event('keydown','Space',1000);assert.equal(c.jump,null,'deep water without a ledge cannot launch a ground jump');}
console.log('PASS actual Space traversal admission: camera direction, swimming, no ledge, repeat/dive ownership');

for(const code of ['ControlLeft','ControlRight']){
 const {c,event}=session();let slides=0,covers=0;c.toggleHeroCover=()=>covers++;c.nearestInteraction=()=>({kind:'ladder',ladder:{end:'upper'}});c.verticalNavigation.slideDown=()=>{slides++;return true};
 event('keydown',code,1000);assert.equal(slides,1);assert.equal(c.heroPosture.target,'stand','roof Ctrl belongs to slide');event('keydown',code,1001,true);assert.equal(slides,1);
 c.verticalNavigation.active=true;event('keydown',code,1100);assert.equal(slides,2);assert.equal(c.heroPosture.target,'stand','on ladder Ctrl never crouches');
 c.verticalNavigation.active=false;c.nearestInteraction=()=>({kind:'ladder',ladder:{end:'lower'}});event('keydown',code,1200);assert.equal(covers,1,'ground Ctrl toggles contextual cover');assert.equal(c.heroPosture.target,'stand','Ctrl cannot also crouch');
}
console.log('PASS both Ctrl keys start roof slide or reverse active climb, repeats ignored, ground cover action preserved');

// Exercise the actual keyboard and updateJump snippets with the real render
// frame's accepted timestep. In a slow scene the frame cap stretches time; it
// must never multiply metres or allow held/repeated Space to add an impulse.
const frameDtExpression=source.match(/const dt=([^;]+);const coverDt=/)?.[1];
assert.ok(frameDtExpression,'read current frame timestep, do not assume a duplicate cap');
const diveDistanceRows=[];
for(const fps of [5,10,30,60])for(const diagonal of [false,true])for(const secondPress of [0,200,500]){
 const {c,event}=session();c.rawDt=1/fps;c.exitQaMode=false;c.vehicleVisualQa=null;
 const dt=vm.runInContext(frameDtExpression,c);event('keydown','KeyW',999);if(diagonal)event('keydown','KeyD',999);event('keydown','Space',1000);
 let frames=0,upgraded=false,normalSeconds=0;
 while(c.jump&&frames<1000){
  const age=frames*1000/fps;
  if(!upgraded&&age+1e-7>=secondPress){
   normalSeconds=c.jump.elapsed;event('keyup','Space',1000+secondPress);event('keydown','Space',1000+secondPress);upgraded=true;
   assert.equal(c.jump.mode,'dive');
   // A third real press during flight and OS key repeat both leave it intact.
   const before={...c.jump};event('keyup','Space',1001+secondPress);event('keydown','Space',1002+secondPress);event('keydown','Space',1003+secondPress,true);
   assert.equal(c.jump.elapsed,before.elapsed);assert.equal(c.jumpCount,1);
  }
  event('keydown','Space',1000+age,true);vm.runInContext(`updateJump(${dt})`,c);frames++;
 }
 assert.equal(c.jump,null,'each trajectory reaches landing');assert.equal(c.jumpCount,1);
 const distance=Math.hypot(c.hero.object.position.x,c.hero.object.position.z),expected=3.5*normalSeconds+JUMP.speed*(JUMP.flight-normalSeconds);
 assert.ok(Math.abs(distance-expected)<1e-8,'one trajectory, world metres, no extra WASD/diagonal impulse');
 assert.ok(distance<=4.8+1e-8,'cinematic dive stays within a compact 4.8m flight');
 event('keydown','Space',9000,true);assert.equal(c.jump,null,'held Space cannot auto-launch after landing');
 if(!diagonal)diveDistanceRows.push({fps,secondPressMs:secondPress,metres:+distance.toFixed(3),wallSeconds:+(frames/fps).toFixed(3)});
}
{
 const {c,event}=session();c.surfaceMotion.state.grounded=false;event('keydown','Space',1000);assert.equal(c.jump,null,'airborne fall cannot start a new dive');
}
console.log(JSON.stringify({passed:true,checks:['actual_keyboard_updateJump_and_frame_timestep','compact_dive_range','5_10_30_60fps','third_tap_repeat_held_and_airborne','diagonal_has_no_boost'],diveDistanceRows}));
