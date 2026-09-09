import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';import {NPC_ASSETS} from './npc_actor.mjs';import {createArtist14Surface} from './hero_artist14_surface.mjs';import {createWorldWalkMeleeHost} from './world_walk_melee_host.mjs';
const deps=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(deps+'/build/three.module.js').href:s,c)}});const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
async function make(sex){const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));return createHeroWalker({THREE,scene:(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,targetHeight:1.9})}
let count=0;
for(const sex of ['male','female']){
 const hero=await make(sex),target=await make(sex),world=new THREE.Scene();world.add(hero.object,target.object);const surface=createArtist14Surface({THREE,context:target.artistContext(),scene:world});
 const records=[{id:'real-target-'+sex,object:target.object}],calls=[];let now=1000;
 const host=createWorldWalkMeleeHost({THREE,bridge:{resolveWalkMelee:request=>{calls.push(request);return {accepted:true,confirmed:false}}},getHero:()=>hero,getActors:()=>records,obstacles:()=>[],now:()=>now});
 function pose(type,side,age){hero.update(.016,false,false,null,{}, {action:{type,side,progress:age/(type==='kick'?.62:.34)}});target.update(.016);}
 for(const side of [-1,1]){
  const seq=++count,start={id:seq,seq,type:'kick',side,sourceStartAt:now,contactWindow:[180,340]},snapshot={start};
  target.object.position.set(50,0,0);pose('kick',side,0);host.update(snapshot);assert.equal(calls.length,seq-1);
  now+=200;pose('kick',side,.2);host.update(snapshot);assert.equal(calls.length,seq-1,'no premature null while active');
  const foot=hero.artistContext().bones['foot_'+(side<0?'l':'r')].getWorldPosition(new THREE.Vector3());target.object.position.set(0,0,0);target.update(.016);const head=target.artistContext().bones.head.getWorldPosition(new THREE.Vector3());target.object.position.copy(foot).sub(head);target.object.updateMatrixWorld(true);
  now+=20;host.update(snapshot);const request=calls.at(-1);assert.equal(request.seq,seq);assert(request.contact?.anchor);assert.equal(request.contact.npcId,records[0].id);assert(new THREE.Vector3(...Object.values(request.contact.point)).distanceTo(foot)<.141,'contact comes from correct active foot');
  host.update(snapshot);assert.equal(calls.length,seq,'single consume');
  const old={...request.contact.point};target.object.position.x+=3;target.object.position.z-=2;
  const receipt=host.resolveConfirmedReceipt({detail:{confirmed:true,kind:'melee',shotId:'walk-melee:'+seq,targetId:records[0].id,point:old,normal:request.contact.normal,blocked:true,heavy:true,knockdown:true}});
  assert(receipt);assert.equal(receipt.id,'walk-melee:'+seq);assert(Math.abs(receipt.point.x-old.x-3)<1e-6);assert(Math.abs(receipt.point.z-old.z+2)<1e-6,'receipt anchor rebased before surface receive');
  surface.update(.016,{time:now/1000});assert(surface.receive(receipt));surface.update(.016,{time:now/1000+.016});assert.equal(surface.state.kind,'block');assert.equal(world.getObjectByName('Artist14ContactParticles').count,0,'blocked contact emits no blood');assert.equal(host.resolveConfirmedReceipt(receipt),null,'duplicate receipt consumed');
  now+=1000;
 }
 const seq=++count,start={id:seq,seq,type:'punch',side:1,sourceStartAt:now,contactWindow:[35,190]};target.object.position.set(0,-10,0);pose('punch',1,0);host.update({start});now+=70;pose('punch',1,.07);host.update({start});assert.equal(calls.length,2,'high limb misses lowered target without premature resolution');now+=130;host.update({start});assert.equal(calls.at(-1).contact,null);host.update({start});assert.equal(calls.length,3);
 host.dispose();const beforeDisposed=calls.length;host.update({start:{...start,id:999,seq:999}});assert.equal(calls.length,beforeDisposed);assert.equal(host.resolveConfirmedReceipt({confirmed:true}),null);surface.dispose();hero.dispose();target.dispose();count=0;
}
console.log('PASS actual male/female world melee host: correct left/right foot, deferred miss, single resolve, pending receipt rebase/id, block no fall/blood');

// Contact sampling runs during an accepted melee animation. It must reuse its
// limb vectors after the first sample instead of producing GC work each frame.
let transientVectors=0;
class CountedVector3 extends THREE.Vector3{constructor(...args){super(...args);transientVectors++;}}
const measuredThree={...THREE,Vector3:CountedVector3},bone={getWorldPosition(out){return out.set(0,0,0)}},measuredHero={object:{updateMatrixWorld(){}},artistContext:()=>({bones:{hand_l:bone,hand_r:bone,foot_l:bone,foot_r:bone}})};
const measuredHost=createWorldWalkMeleeHost({THREE:measuredThree,bridge:{resolveWalkMelee:()=>({accepted:false})},getHero:()=>measuredHero,getActors:()=>[],obstacles:()=>[],now:()=>0});
const measuredStart={id:'allocation-check',seq:1,type:'punch',side:1,sourceStartAt:0,contactWindow:[50,100]};
measuredHost.update({start:measuredStart});transientVectors=0;
for(let i=0;i<120;i++)measuredHost.update({start:measuredStart});
assert.equal(transientVectors,0,'active melee sampling reuses limb vectors after warm-up');
measuredHost.dispose();
console.log('PASS melee host: 120 pre-contact frames allocate no transient Vector3 limb samples');


