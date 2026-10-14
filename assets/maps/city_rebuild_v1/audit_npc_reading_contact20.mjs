// Measurement only: actual rigs across the source reading expiry, not acceptance.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const report=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));
 const source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'reading_contact20_'+sex,sex});
 const context=actor.walker.artistContext(),position={x:4.1,y:0,z:8.2};
 const seat={id:'reading-bench',c:1,r:2,seatWorldY:.46,yaw:.2,phase:'sit',since:1000};
 const tick=(time,activity)=>{actor.update(1/60,{time,position,yaw:.2,life:{seat,activity}});assert.deepEqual(actor.object.position.toArray(),Object.values(position));};
 tick(1);tick(2);
 const activity={kind:'read',phase:'active',since:3000,until:6000},entry=[];
 for(const age of [0,1/60,.05,.1,.25]){
  tick(3+age,activity);const book=actor.object.getObjectByName('NPC_ReadingBook');
  const center=book?.visible?book.getWorldPosition(new THREE.Vector3()):null;
  entry.push({age,bookVisible:!!book?.visible,handDistanceToCenterM:center?['l','r'].map(side=>context.worldPosition('socket_hand_'+side).distanceTo(center)):null});
 }
 tick(6-1/60,activity);const before=['l','r'].map(side=>context.worldPosition('socket_hand_'+side));
 // npc_civilian_activity_source.js read branch releases at until, without finish.
 tick(6,undefined);const expiryHandDeltaM=['l','r'].map((side,i)=>context.worldPosition('socket_hand_'+side).distanceTo(before[i]));
 report.push({sex,entry,expiryHandDeltaM,bookVisibleAfterExpiry:actor.object.getObjectByName('NPC_ReadingBook')?.visible});
 actor.dispose();
}
console.log(JSON.stringify({measurement:'reading contact / ordinary expiry',report,limits:'Actual male/female bones; source expiry-shaped snapshots, not full source/renderer integration. No LIVE or FPS, no quality PASS assertion.'},null,2));
