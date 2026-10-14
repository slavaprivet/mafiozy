// Read-only actual-rig regression for fixed help/talk exit and seat entry.
// Phone measurements are informational and owned by the phone visual module.
// No browser/GPU, AI updates, source movement, network or production changes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcActivityPose} from './npc_activity_pose.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const results=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'animation_audit20_'+sex,sex});
 const c=actor.walker.artistContext(),position={x:4.1,y:0,z:8.2};
 const tick=(time,life={})=>actor.update(1/60,{time,position,yaw:0,life,moving:false});
 const root=()=>actor.object.position.toArray();
 for(const [name,life]of [['help',{helping:true}],['talk',{talking:true}],['phone',{phoneCalling:true}]]){
  for(let i=0;i<45;i++)tick(1+i/60,life);
  const before=c.worldPosition('socket_hand_r');
  tick(1+45/60,{});const released=c.worldPosition('socket_hand_r');
  tick(1+46/60,{});const neutral=c.worldPosition('socket_hand_r');
  const jump=before.distanceTo(released),neutralDifference=released.distanceTo(neutral);
  if(name!=='phone'){assert(jump<.01,name+' first release frame stays near the outgoing pose');assert(neutralDifference>.0001,name+' continues its finite exit instead of snapping to neutral');}
  assert.deepEqual(root(),[4.1,0,8.2],'animation must preserve source root');
  results.push({sex,measurement:name==='phone'?'phone_visual_owned':'fixed_gesture_release',gesture:name,frameSeconds:1/60,handJumpMetres:jump,nextFrameHandStep:neutralDifference});
 }
 // First seating observation arrives 250ms after the prior standing frame,
 // but the source says this seat was assigned exactly now (since=1250).
 // The preceding standing interval must not be consumed by the new seat.
 const overlay=createNpcActivityPose({THREE,walker:actor.walker});
 tick(1);overlay.apply({time:1,life:{}});
 actor.walker.reset();c.object.updateMatrixWorld(true);
 const hipBefore=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5),handBefore=c.worldPosition('socket_hand_r'),shinBefore=c.bones.shin_r.getWorldQuaternion(new THREE.Quaternion());
 overlay.apply({time:1.25,life:{seat:{id:'audit20-bench',c:1,r:2,height:.46,yaw:0,phase:'sit',since:1250}}});
 const hipAfter=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5);
 assert.equal(overlay.diagnostics().seated,0,'newly assigned seat starts at its actual age');
 const handJump=handBefore.distanceTo(c.worldPosition('socket_hand_r')),shinJump=shinBefore.angleTo(c.bones.shin_r.getWorldQuaternion(new THREE.Quaternion()));
 assert(handJump<1e-8,'no hand jump on first zero-age seat observation');
 assert.deepEqual(root(),[4.1,0,8.2]);
 results.push({sex,fixed:'seat_entry_consumes_preceding_standing_time',sourceSeatAgeSeconds:0,frameSeconds:.25,firstSeatWeight:overlay.diagnostics().seated,hipJumpMetres:hipBefore.distanceTo(hipAfter),handJumpMetres:handJump,shinAngleJumpRadians:shinJump});
 const resources=new Set();overlay.phone.traverse(o=>{if(o.geometry)resources.add(o.geometry);if(o.material)resources.add(o.material)});overlay.phone.removeFromParent();for(const resource of resources)resource.dispose();
 actor.dispose();
}
console.log(JSON.stringify({gestureExitRegressionPassed:true,seatEntryRegressionPassed:true,results,limits:'Actual male/female GLB CPU audit only. No LIVE/GPU or full-scene performance claim.'},null,2));
