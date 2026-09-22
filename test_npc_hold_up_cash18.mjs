import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const world=fs.readFileSync(new URL('./world.html',import.meta.url),'utf8');
const walk=fs.readFileSync(new URL('./assets/maps/city_rebuild_v1/walk_preview.mjs',import.meta.url),'utf8');
const actor=fs.readFileSync(new URL('./assets/maps/city_rebuild_v1/npc_actor.mjs',import.meta.url),'utf8');
const server=fs.readFileSync(new URL('./mafiozi_bot.py',import.meta.url),'utf8');
const preview=fs.readFileSync(new URL('./_preview_ws_server.py',import.meta.url),'utf8');
const robberyReceipts=fs.readFileSync(new URL('./npc_robbery_receipts.py',import.meta.url),'utf8');

const between=(source,start,end)=>source.slice(source.indexOf(start),source.indexOf(end,source.indexOf(start)));
const hold=between(world,'function _threeNpcHoldUp','function _threeNpcRobAimed');
const take=between(world,'function _threeNpcRobAimed','function openUniqueNpcMenuFrom2D');
const surrenderPresentation=between(world,'function _npcSurrenderPresentation','function _registerNpcRobberyIncident');
const complete=between(world,'function _completeNpcRobbery','function _confiscateNpcRobberyLoot');
const snitch=between(world,'function _snitchReport','// NPC_PERCEPTION_START');

assert.match(hold,/cashAvailable&&distance<=1\.25/,'cash can only be taken at close range while this NPC can still pay');
assert.match(hold,/else if\(!cashAvailable\)\{ref\._npcCashOfferUntil=0;ref\._npcCashOfferSince=0;\}/,'an empty or pending victim clears the complete cash animation cycle');
assert.match(hold,/_npcSurrenderUntil/,'aiming keeps both hands in surrender pose');
assert.match(hold,/_npcCashOfferUntil/,'close aiming exposes the cash bundle');
assert.match(take,/_runNpcAction\('rob'\)/,'E uses the authoritative robbery transaction');
assert.doesNotMatch(take,/_runNpcAction\('threaten'\)/,'taking cash is not random threat/extortion');
assert.match(complete,/_npcIsIntimidated\(ref,now\)/,'victim silence uses existing intimidation state');
assert.match(complete,/_npcQueueWitnessCall\(ref/,'an unafraid victim flees and calls');
assert.match(complete,/triggerWitnessChain/,'other visible witnesses keep independent calls');
assert.doesNotMatch(complete,/myWanted\s*=|_registerNpcRobberyIncident/,'cash transfer itself does not summon police');
assert.match(snitch,/npc_robbery_report/,'police report is sent only from a completed phone call');

const eHandler=between(walk,"if(e.code==='KeyE'){","if(e.code==='Space')");
assert(eHandler.indexOf('takeNpcCash()')<eHandler.indexOf('rescue?.getPrompt()'),'cash E interaction has priority over vehicle/building interactions');
assert.match(walk,/E — взять наличные/);
assert.match(actor,/createNpcPhoneVisual/);assert.match(actor,/createNpcCashOfferVisual/);
const receiptBegin=between(robberyReceipts,'async def begin(','async def report(');
assert.match(receiptBegin,/INSERT INTO npc_robbery_receipts/,'payout creates a durable per-robbery receipt');
assert.match(receiptBegin,/VALUES\(\?,\?,\?,\?,\?,\?,'unreported'/,'a new robbery stays unreported until a real phone report');
const serverBegin=between(server,"elif t == 'npc_robbery':","elif t == 'npc_robbery_report':");
const serverReport=between(server,"elif t == 'npc_robbery_report':","elif t == 'npc_robbery_confiscate':");
assert.match(serverBegin,/await npc_robbery_receipts\.begin\(/,'actual robbery handler uses the durable payout transaction');
assert.match(serverReport,/await npc_robbery_receipts\.report\(/,'actual phone-report handler activates the matching receipt');
assert.match(server,/elif t == 'npc_robbery_report'/);
assert.match(preview,/elif t == "npc_robbery_report"/);

// Behavioural regression: the cash is a one-shot offer, while surrender remains
// repeatable.  This deliberately executes the production functions instead of
// accepting a source-only guard that could leave E or the cash bundle active.
let monoNow=1000,wallNow=1_800_000_000_000,cash=40,intimidated=true,queueAccepted=true,queueCalls=0;
const cooldowns=new Map(),actions=[],events=[],toasts=[];
const victim={id:'resident_cash_18',r:5,c:5,hp:100,alive:true,_arc:{panicMult:1}};
const entityId='resident_cash_18',view={id:entityId,r:5,c:5,role:'civilian'};
const sandbox={
  Math,performance:{now:()=>monoNow},Date:{now:()=>wallNow},
  NPC_ROB_COOLDOWN_MS:60*60*1000,
  NPCS:[victim],player:{r:5,c:5.8},myDead:false,_buildingInt:null,_bankInt:null,
  _threeNpcActionRefs:new Map([[entityId,{ref:victim,view}]]),
  _pendingNpcRobbery:null,_npcActionTarget:null,
  _isArmed:()=>true,_npcActionKind:()=> 'civilian',
  _npcConversationPosition:ref=>({r:ref.r,c:ref.c}),
  _npcCancelHelping:()=>{},_npcCancelSocial:()=>{},_clearNpcRoute:()=>{},
  _npcIsIntimidated:()=>intimidated,
  _npcRobCooldownLeft:key=>Math.max(0,(cooldowns.get(String(key))||0)-wallNow),
  _setNpcRobCooldown:(key,until=wallNow+60*60*1000)=>cooldowns.set(String(key),until),
  _setNpcThreatCooldown:()=>{},
  _runNpcAction(action){
    actions.push(action);
    if(action==='rob'){
      sandbox._setNpcRobCooldown(entityId);
      sandbox._pendingNpcRobbery={ref:victim,key:entityId,robberyId:'cash18'};
    }
  },
  document:{documentElement:{dataset:{}}},
  _applyNpcCash(value){cash=value;return true;},_npcActionEarn:value=>{cash+=value;},
  _districtRepAdd:()=>{},_npcActionFloat:()=>{},triggerWitnessChain:()=>events.push('witnesses'),
  _npcFleeIntimidatedWitness:()=>true,_npcActionSay:()=>{},showToast:text=>toasts.push(text),
  _npcQueueWitnessCall(ref){queueCalls++;events.push('victim');if(!queueAccepted)return false;ref.snitching=true;ref._witnessStage='escaping';return true;},
};
vm.createContext(sandbox);
for(const source of [hold,take,surrenderPresentation,complete])vm.runInContext(source,sandbox);

const staleSource={_npcSurrenderUntil:1850},poseOut={};
assert.deepEqual({...sandbox._npcSurrenderPresentation(staleSource,'surrender','surrender',1800,false,poseOut)},{surrendering:true,lifeState:'surrender',gesture:'surrender'},'active lease keeps the surrender pose');
assert.deepEqual({...sandbox._npcSurrenderPresentation(staleSource,'surrender','surrender',2000,false,poseOut)},{surrendering:false,lifeState:'',gesture:''},'expired lease cannot keep stale surrender hands raised');
assert.equal(sandbox._npcSurrenderPresentation(staleSource,'surrender','surrender',1800,true,poseOut).surrendering,false,'dead victim never exports surrender');

const firstAim=sandbox._threeNpcHoldUp(entityId,monoNow);
assert.equal(firstAim.ok,true,'first armed aim accepts the civilian hold-up');
assert.equal(firstAim.canTake,true,'first close hold-up exposes cash for E');
assert.ok(victim._npcCashOfferUntil>monoNow,'first close aim shows the cash bundle');
assert.ok(victim._npcSurrenderUntil>monoNow,'first aim raises both hands');
const firstOfferSince=victim._npcCashOfferSince;monoNow+=900;const reacquired=sandbox._threeNpcHoldUp(entityId,monoNow);assert.equal(reacquired.canTake,true);assert.equal(victim._npcCashOfferSince,firstOfferSince,'brief ray loss cannot restart the cash draw animation');assert(victim._npcCashOfferUntil>monoNow,'reacquiring aim only renews visibility');

monoNow+=10;
const firstTake=sandbox._threeNpcRobAimed(entityId);
assert.equal(firstTake.ok,true,'first E starts the robbery transaction');
assert.deepEqual(actions,['rob'],'first E invokes one authoritative robbery');
sandbox._pendingNpcRobbery=null;
sandbox._completeNpcRobbery(victim,entityId,7,'cash18');
assert.equal(cash,47,'cash is awarded exactly once');
assert.equal(victim._npcCashOfferUntil,0,'completion removes the cash bundle immediately');
assert.equal(victim._npcCashOfferSince,0,'completion closes the current offer animation cycle');
assert.ok(victim._npcRobbedAt>0,'completion records that this NPC already paid');

monoNow+=100;
const secondAim=sandbox._threeNpcHoldUp(entityId,monoNow);
assert.equal(secondAim.ok,true,'an already robbed NPC still reacts to the gun');
assert.equal(secondAim.alreadyRobbed,true,'the hold-up receipt exposes the spent-cash state');
assert.equal(secondAim.cashAvailable,false,'the same NPC has no second cash offer during cooldown');
assert.equal(secondAim.canTake,false,'an already robbed NPC never exposes a second E cash action');
assert.equal(victim._npcCashOfferUntil,0,'re-aiming cannot restore the cash bundle');
assert.ok(victim._npcSurrenderUntil>monoNow,'re-aiming still refreshes the hands-up pose');
const secondTake=sandbox._threeNpcRobAimed(entityId);
assert.equal(secondTake.ok,false,'E is rejected after this NPC has paid');
assert.equal(secondTake.reason,'empty','a rejected second take is reported as an empty victim');
assert.deepEqual(actions,['rob'],'the rejected E cannot start a second transaction');

// An unafraid victim must actually enter retreat before the UI claims it ran
// to call. Reserving the victim slot before general witnesses prevents the
// witness cap from silently consuming both caller slots first.
intimidated=false;queueAccepted=true;events.length=0;toasts.length=0;
const caller={id:'resident_caller',r:6,c:6,hp:100,alive:true,_npcSurrenderUntil:monoNow+850,_lifeGesture:'surrender'};
sandbox._completeNpcRobbery(caller,'resident_caller',4,'caller18');
assert.deepEqual(events.slice(0,2),['victim','witnesses'],'victim reserves the first caller slot before nearby witnesses');
assert.equal(caller._npcSurrenderUntil,0,'successful robbery releases surrender immediately for retreat');
assert.equal(caller._witnessStage,'escaping','victim enters the real retreat state');
assert(toasts.some(text=>text.includes('жертва побежала звонить')),'run-to-call toast requires a queued victim');

queueAccepted=false;events.length=0;toasts.length=0;
const blockedCaller={id:'resident_blocked',r:7,c:7,hp:100,alive:true,_npcSurrenderUntil:monoNow+850,_lifeGesture:'surrender'};
sandbox._completeNpcRobbery(blockedCaller,'resident_blocked',3,'blocked18');
assert.equal(queueCalls,2,'both victim queue attempts are observed');
assert(!toasts.some(text=>text.includes('жертва побежала звонить')),'failed queue never claims the victim ran or called');
assert(toasts.some(text=>text.includes('не начала звонок')),'failed queue reports the actual state');

intimidated=true;const intimidatedCaller={id:'resident_intimidated',r:8,c:8,hp:100,alive:true,_npcSurrenderUntil:monoNow+850,_lifeGesture:'surrender',_lifeState:'surrender'};
sandbox._completeNpcRobbery(intimidatedCaller,'resident_intimidated',2,'intimidated18');
assert.equal(intimidatedCaller._npcSurrenderUntil,0,'intimidated victim leaves surrender immediately');assert.equal(intimidatedCaller._lifeGesture,'');assert.equal(intimidatedCaller._lifeState,'');

console.log('PASS NPC hold-up: one cash/E offer per NPC, repeat aim still raises hands, intimidation silence, witness/victim phone report before police');
