import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {COVER_MOVE_SPEED,COVER_ENTRY_SECONDS,coverElapsedTime} from './hero_cover_motion.mjs';
import {findCover,moveCover} from './hero_cover.mjs';

const body={id:'wall',polygon:[{x:0,z:0},{x:12,z:0},{x:12,z:2},{x:0,z:2}],minY:0,maxY:3};
for(const fps of [10,15,25,60,144]){
 let elapsed=0,distance=0,entryFinishedAt=null;
 let cover=findCover({position:{x:2,y:0,z:-.6},direction:{x:0,z:1},bodies:[body],canOccupy:()=>true});
 for(let frame=1;frame<=fps;frame++){
  const dt=coverElapsedTime(1/fps,Math.min(1/fps,.04));elapsed+=dt;distance+=dt*COVER_MOVE_SPEED;
  if(entryFinishedAt===null&&elapsed>=COVER_ENTRY_SECONDS)entryFinishedAt=frame/fps;
  cover=moveCover(cover,dt*COVER_MOVE_SPEED,p=>p.x+.36<3.105||p.x-.36>3.115);
 }
 assert.ok(Math.abs(distance-2.35)<1e-8,`${fps} FPS keeps metres per real second`);
 assert.ok(entryFinishedAt<=COVER_ENTRY_SECONDS+1/fps+1e-8,'entry completes on the first rendered frame after its duration');
 assert.ok(cover.anchor.x+.36<3.105,'swept movement cannot skip a thin blocker at low FPS');
}
assert.equal(coverElapsedTime(.1,.01),.025,'slow-motion scale survives');
assert.equal(coverElapsedTime(.1,0),0,'pause stays paused');
assert.equal(coverElapsedTime(8,.04),.1,'resume hitch stays bounded');
assert.equal(coverElapsedTime(NaN,.04),0);
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const movement=source.slice(source.indexOf('function moveHeroOnFoot(delta)'),source.indexOf('function frame(){'));
const vector=distance=>({distance,clone(){return vector(this.distance);},multiplyScalar(scale){this.distance*=scale;return this;}});
let actualDistance=0,sprintInput=false;
const host={keys:new Set(),heroCover:{active:true,move(delta,options){sprintInput=options.sprinting;actualDistance+=delta.distance;return true;}},postureMotion:{maxSpeed:1.55},COVER_MOVE_SPEED,coverMovementScale:1};
vm.createContext(host);vm.runInContext(movement,host);
for(const fps of [10,60,144])for(const speed of [1.55,4.6]){
 actualDistance=0;host.postureMotion.maxSpeed=speed;
 const raw=1/fps,dt=Math.min(raw,.04);host.coverMovementScale=coverElapsedTime(raw,dt)/dt;
 for(let i=0;i<fps;i++)host.moveHeroOnFoot(vector(dt*speed));
 assert.ok(Math.abs(actualDistance-COVER_MOVE_SPEED)<1e-8,'actual walk movement hook uses real-time cover speed in either posture');
}
host.heroCover.active=false;actualDistance=0;host.moveHeroOnFoot(vector(.08));
assert.equal(actualDistance,.08,'free C movement is passed through unchanged');
console.log('PASS cover real-time speed at 10/15/25/60/144 FPS, prompt entry, thin-wall sweep, pause, slow-motion, resumed-tab cap');

for(const key of ['ShiftLeft','ShiftRight']){host.keys.add(key);host.moveHeroOnFoot(vector(.1));assert.equal(sprintInput,true);host.keys.delete(key);}host.moveHeroOnFoot(vector(.1));assert.equal(sprintInput,false);
