// Read-only audit: current source approach/impact gate versus real authored GLBs.
import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {clone} from './assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs';
import {createHeroWalker} from './assets/maps/city_rebuild_v1/hero_walk.mjs';import {NPC_ASSETS} from './assets/maps/city_rebuild_v1/npc_actor.mjs';
import {createNpcMeleeContact} from './assets/maps/city_rebuild_v1/npc_melee_contact.mjs';import {normalizeNpcSnapshot} from './assets/maps/city_rebuild_v1/npc_population.mjs';
const source=fs.readFileSync('world.html','utf8'),from=source.indexOf('    if (n._fightingMelee && !_buildingInt && !_bankInt)'),to=source.indexOf('    // SNITCH:',from),branch=source.slice(from,to);
const n={r:0,c:0,speed:1,_fightingMelee:true,_nextHitAt:Infinity,_nextMeleeDefenseThinkAt:Infinity},player={r:3,c:0};let goalRadius;
const ctx={n,player,now:5000,dt:.1,_buildingInt:null,_bankInt:null,myDead:false,npcPassableForSnitch:()=>true,_npcPacedSpeed:()=>1,_planNpcRouteTo:(n,r,c,pass,radius)=>{goalRadius=radius;},_npcAdvanceRoute:()=>false,_npcBodyPassable:()=>true,_clearNpcRoute(){},_localHostileCanResolveHit:()=>false};vm.createContext(ctx);
const tick=new vm.Script('for(const n of [globalThis.n]){'+branch+'}');for(let i=0;i<100;i++){ctx.now+=100;tick.runInContext(ctx);}
const settledMetres=Math.hypot(player.r-n.r,player.c-n.c)*4.1;assert(settledMetres>4&&settledMetres<4.85,'actual source stops several metres before skin reach');assert.equal(goalRadius,1.2);
const rangeText=branch.match(/const heavyAttack=n\._npcHeavyAttack===true,contactRange=([^;]+);/)[1],predicate=branch.match(/if\((_localHostileCanResolveHit\(\)&&impactDistance<=contactRange&&impactLineClear)\)/)[1];
const accepts=new vm.Script('const heavyAttack=n._npcHeavyAttack===true,contactRange='+rangeText+';globalThis.result='+predicate+';');
for(const type of ['punch','kick','heavy'])for(const posture of ['stand','crouch','prone']){
 const c={n:{_npcHeavyAttack:type==='heavy',_meleeType:type,ang:Math.PI},player:{r:1.2,c:0,posture},impactDistance:1.2,impactLineClear:true,_localHostileCanResolveHit:()=>true};vm.createContext(c);accepts.runInContext(c);assert(c.result,'existing gate accepts 4.92m independently of facing/posture');
}
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const result=[];
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),scene=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const type of ['punch','kick','heavy'])for(const position of ['front','behind','old-stop'])for(const posture of ['stand','prone']){
  const attacker=createHeroWalker({THREE,scene:clone(scene),targetHeight:1.9}),hero=createHeroWalker({THREE,scene:clone(scene),targetHeight:1.9});hero.object.position.z=position==='behind'?-.7:position==='old-stop'?settledMetres:.7;hero.object.rotation.y=Math.PI;
  hero.update(.1,false,false,null,{}, {posture:{target:posture,value:posture==='prone'?2:0}});
  const contact=createNpcMeleeContact({THREE,getActors:()=>[{id:'player',object:hero.object}],obstacles:()=>[]}),limb=type==='kick'?'foot_r':'hand_r',previous=new THREE.Vector3();let hit=null,seen=false;
  const [begin,end]=type==='kick'?[180,340]:type==='heavy'?[70,360]:[35,190];
  for(let ms=begin;ms<=end;ms=Math.min(end,ms+8)){
   const row={id:'npc-fixture',r:0,c:0,ang:Math.PI/2,role:'civilian',weapon:'none',_shotAt:1000,meleeType:type,meleeKickSide:1};const normalized=normalizeNpcSnapshot(row,{time:(1000+ms)/1000,sourceNowMs:1000+ms});
   attacker.update(.008,false,false,null,{}, {action:normalized.action});const current=attacker.artistContext().bones[limb].getWorldPosition(new THREE.Vector3());if(!seen){previous.copy(current);seen=true;}
   hit=contact({previous,current,radius:type==='kick'?.14:.1,attackType:type,poseRevision:1});previous.copy(current);if(hit||ms===end)break;
  }
  if(position==='front'&&posture==='stand')assert(hit,'actual nearby posed contact '+type);
  if(position==='old-stop'||posture==='prone')assert(!hit,'current approach stops outside limb reach / prone posture misses');
  if(position==='behind'&&type!=='heavy')assert(!hit,'punch/kick do not hit behind attacker');
  result.push({sex,type,position,posture,hit:!!hit,zone:hit?.zone});attacker.dispose();hero.dispose();
 }
}
console.log(JSON.stringify({pass:true,settledMetres,routeArrivalMetres:goalRadius*4.1,currentGateAcceptsMetres:4.92,result,scope:'read-only source and authored GLB fixture; no incoming damage fix implemented'},null,2));
