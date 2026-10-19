import fs from 'node:fs';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs';import {createHeroWalker} from './assets/maps/city_rebuild_v1/hero_walk.mjs';import {NPC_ASSETS} from './assets/maps/city_rebuild_v1/npc_actor.mjs';import {normalizeNpcSnapshot} from './assets/maps/city_rebuild_v1/npc_population.mjs';
import {createNpcIncomingMeleeHost19} from './assets/maps/city_rebuild_v1/npc_incoming_melee_host19.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const templates={};for(const sex of ['male','female']){const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url));templates[sex]=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;}
const WINDOW={punch:[35,190],kick:[180,340],heavy:[70,360],dropkick:[160,380]},costs=[];
function run({sex='male',type='punch',fps=5,posture='stand',z=.7,wall=false,blocked=false,hidden=false,cancel=false,kind='civilian',budget=true,attackerCount=1,attackerY=0,ticketOverrides={}}={}){
 const hero=createHeroWalker({THREE,scene:clone(templates[sex]),targetHeight:1.9}),npcs=Array.from({length:attackerCount},()=>createHeroWalker({THREE,scene:clone(templates[sex]),targetHeight:1.9})),scene=new THREE.Scene();scene.add(hero.object,...npcs.map(n=>n.object));hero.object.position.z=z;hero.object.rotation.y=Math.PI;
 npcs.forEach(n=>n.object.position.y=attackerY);
 const tickets=npcs.map((_,i)=>({npcId:'citizen'+i,generation:1,seq:1,startAt:10000,type,side:1,contactWindow:WINDOW[type].slice(),yaw:0,kind,local:true,alive:true,armed:false}));let at=10000,authorityHp=100,knockdown=false,vertexCount=0,vertexCalls=0,budgetClock=0;const receipts=[],obstacles=[],completed=new Set();
 tickets.forEach(t=>Object.assign(t,ticketOverrides));
 hero.object.traverse(mesh=>{if(mesh.isSkinnedMesh){vertexCount+=mesh.geometry.attributes.position.count;const get=mesh.getVertexPosition;mesh.getVertexPosition=function(...args){vertexCalls++;return get.apply(this,args);};}});
 if(wall){const mesh=new THREE.Mesh(new THREE.BoxGeometry(4,4,.08),new THREE.MeshBasicMaterial());mesh.position.set(0,1,.35);scene.add(mesh);obstacles.push(mesh);}
 // Test authority boundary only, not a replacement for the future source bridge.
 const sourceResolve=r=>{assert(!completed.has(r.npcId+':'+r.seq),'exactly one resolve per ticket');completed.add(r.npcId+':'+r.seq);receipts.push(r);if(r.contact){assert(r.contactAge>=WINDOW[type][0]&&r.contactAge<=WINDOW[type][1]);assert(r.contactAge<=at-10000);authorityHp-=blocked?1:10;knockdown=!blocked&&type==='dropkick';}};
 const host=createNpcIncomingMeleeHost19({THREE,getHero:()=>hero,getTickets:()=>tickets,getNpcActor:id=>({walker:npcs[Number(id.slice(7))]}),resolve:sourceResolve,obstacles:()=>obstacles,now:()=>at,clock:budget==='force'?()=>budgetClock+=5:budget?()=>performance.now():()=>0,budgetMs:4,maxPoseSamples:16,maxAttackers:4});
 let maxSamples=0,maxQueries=0,maxVertices=0,budgetDeferred=0;
 for(let age=0;age<=WINDOW[type][1]+450;age+=1000/fps){
  at=10000+age;if(cancel&&age>=100)tickets.forEach(t=>t.armed=cancel==='reappear'?age<200:true);
  hero.update(1/fps,false,false,null,{}, {posture:{target:posture,value:posture==='prone'?2:posture==='crouch'?1:0}});
  for(const npc of npcs){const normalized=normalizeNpcSnapshot({id:'fixture',r:0,c:0,ang:Math.PI/2,role:'civilian',weapon:'none',_shotAt:10000,meleeType:type,meleeKickSide:1},{time:at/1000,sourceNowMs:at});npc.update(1/fps,false,false,null,{}, {action:normalized.action});}
  if(hidden)hero.object.visible=false;const beforeVertices=vertexCalls,beforePoses=npcs.map(n=>({phase:n.diagnostics().phase,matrices:Object.values(n.artistContext().bones).map(b=>[b,b.matrix.elements.slice()])})),beforeHp=authorityHp,beforeReceipts=receipts.length;
  const cpuAt=performance.now();host.update();const cpuMs=performance.now()-cpuAt,d=host.diagnostics();costs.push(cpuMs);maxSamples=Math.max(maxSamples,d.poseSamples);maxQueries=Math.max(maxQueries,d.contactQueries);maxVertices=Math.max(maxVertices,vertexCalls-beforeVertices);budgetDeferred+=d.budgetDeferred;
  assert(d.poseSamples<=16);assert(vertexCalls-beforeVertices<=vertexCount+3*attackerCount,'one skin pass shared by attackers');if(hidden)assert(!hero.object.visible,'camera visibility restored');
  npcs.forEach((npc,i)=>{assert.equal(npc.diagnostics().phase,beforePoses[i].phase);for(const [bone,matrix]of beforePoses[i].matrices)assert.deepEqual(bone.matrix.elements,matrix);});
  if(receipts.length===beforeReceipts)assert.equal(authorityHp,beforeHp,'host cannot mutate HP');
 }
 const out={sex,type,fps,posture,z,wall,blocked,hidden,cancel,kind,attackerCount,hits:receipts.filter(r=>r.contact).length,receipts:receipts.length,hp:authorityHp,knockdown,maxSamples,maxQueries,maxVertices,budgetDeferred};
 host.dispose();hero.dispose();npcs.forEach(n=>n.dispose());obstacles.forEach(m=>{m.geometry.dispose();m.material.dispose();});return out;
}
export {run,costs};
if(!process.env.INCOMING_MELEE_BENCH){
const results=[];
// Deterministic work-bound fixtures separate correctness from wall-clock load.
for(const sex of ['male','female'])for(const type of ['punch','kick','heavy','dropkick'])for(const fps of [5,8,15,60]){const r=run({sex,type,fps,budget:false});assert.equal(r.hits,1,JSON.stringify(r));results.push(r);}
for(const sex of ['male','female'])for(const fps of [5,60])for(const type of ['punch','kick','heavy','dropkick']){
 assert.equal(run({sex,type,fps,posture:'prone',budget:false}).hits,0);
 assert.equal(run({sex,type,fps,z:4.92,budget:false}).hits,0);
 assert.equal(run({sex,type,fps,wall:true,budget:false}).hits,0);
 const block=run({sex,type,fps,blocked:true,budget:false});assert.equal(block.hp,99);assert(!block.knockdown);
 assert.equal(run({sex,type,fps,hidden:true,budget:false}).hits,1,'camera-hidden hero remains physically hittable');
}
for(const type of ['punch','kick'])assert.equal(run({type,z:-.7,budget:false}).hits,0,'behind ordinary strike');
for(const sex of ['male','female'])for(const fps of [5,8,15,60]){assert.equal(run({sex,type:'kick',fps,attackerY:.4,budget:false}).hits,1);assert.equal(run({sex,type:'kick',fps,attackerY:.4,posture:'crouch',budget:false}).hits,0,'same elevated kick passes above crouching target');}
assert.equal(run({type:'heavy',z:-.7,budget:false}).hits,1,'actual spinning backfist can contact behind');
assert.equal(run({kind:'guard',budget:false}).hits,0);assert.equal(run({cancel:true,budget:false}).hits,0);
assert.equal(run({type:'kick',cancel:'reappear',fps:60,budget:false}).hits,0,'cancelled token cannot resume when weapon disappears');
for(const ticketOverrides of [{alive:false},{armed:true},{local:false},{seq:NaN},{yaw:NaN},{contactWindow:[0,1000]},{startAt:20000}])assert.equal(run({ticketOverrides,budget:false}).hits,0,'invalid/nonlocal ticket rejected');
const shared=run({attackerCount:4,fps:60,budget:false});assert.equal(shared.hits,4);
const timed=[];for(const type of ['punch','kick','heavy','dropkick']){const r=run({type,fps:5,budget:true});timed.push(r);assert.equal(r.hits,1,'budget continuation must preserve low-FPS contact '+JSON.stringify(r));}
const forced=[];for(const type of ['punch','kick','heavy','dropkick']){const r=run({type,fps:5,budget:'force'});assert.equal(r.hits,1,JSON.stringify(r));assert.equal(r.maxSamples,1);forced.push(r);}
costs.sort((a,b)=>a-b);console.log(JSON.stringify({pass:true,positives:results.length,shared,timed,forced:forced.map(({type,hits,maxSamples,budgetDeferred})=>({type,hits,maxSamples,budgetDeferred})),cpuMs:{p50:costs[Math.floor(costs.length*.5)],p95:costs[Math.floor(costs.length*.95)],max:costs.at(-1)},scope:'isolated incoming prototype; actual posed GLBs and normalization; source bridge/approach not integrated'},null,2));
}
