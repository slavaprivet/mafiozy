// Executed original world.html functions. Host dependencies are explicit
// TEST_ONLY effect recorders; this fixture does not authorize gameplay damage.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const bytes=fs.readFileSync(path.join(root,'world.html')), source=bytes.toString('utf8');
const sections=[];
function extract(start,end){
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 if(a<0||b<0||source.indexOf(start,a+start.length)!==-1)throw Error('source marker missing/ambiguous: '+start);
 const observed=source.slice(a,b),text=observed.replace(/\r\n/g,'\n');
 sections.push({startLine:source.slice(0,a).split('\n').length,endLine:source.slice(0,b).split('\n').length-1,
  sha256:crypto.createHash('sha256').update(text).digest('hex'),bytes:Buffer.byteLength(text),start,end,
  encoding:'UTF-8; CRLF normalized to LF only',observedSha256:crypto.createHash('sha256').update(observed).digest('hex'),observedBytes:Buffer.byteLength(observed)});
 return text;
}
const initial=extract('const PUNCH_CD_MS   = 300;','// Поиск ближайшей цели для удара без lock');
const helpers=extract('function _meleeTargetIsProne(tgt) {','function _meleeLineClear(');
const punch=extract('function punch(force, aimAngle = null, heavy = false) {','// ── Бандит/враждебный NPC достаёт пушку');
const methods=extract('  setWalkMeleeCharge(active){','  getWalkWeaponOptions(){');
const clean=value=>value===undefined?null:JSON.parse(JSON.stringify(value));
const op=(method,time,arg={},state={})=>({method,time,arg,state});
const base={walk_active:true,armed:false,chat_open:false,menu_open:false,dead:false,arresting:false,driving:false,jetski:false,swimming_deep:false,in_bus:false,ws_open:false,stunned:0,stance:'stand',mode:'pvp',player_r:10,player_c:12,player_angle:0};
const scenarios=[
 ['cadence_rng_hands',[op('begin',0,{angle:.7}),op('begin',299,{angle:.7}),op('begin',300,{angle:.7}),op('begin',599,{angle:.7}),op('advance',600),op('begin',600,{angle:8}),op('begin',900,{angle:-5}),op('advance',1200),op('begin',1200,{angle:0})],[.8,.1,.19,.2]],
 ['charge_heavy',[op('charge',500,true),op('begin',1665,{angle:0,heavy:true}),op('begin',1699,{angle:0,heavy:true}),op('begin',1700,{angle:0,heavy:true}),op('charge',1701,false),op('resolve',1769,{seq:1}),op('resolve',1770,{seq:1}),op('resolve',1771,{seq:1}),op('advance',2200)],[]],
 ['pending_charge_timeout',[op('charge',100,true),op('begin',1300,{angle:.2,heavy:true}),op('charge',1310,false),op('advance',1599),op('advance',1600),op('advance',1739),op('advance',1740),op('charge',1750,true),op('reset',1800,'reconnect-open'),op('advance',2500)],[]],
 ['reset_keeps_captured_timer',[op('charge',100,true),op('begin',1300,{angle:.2,heavy:true}),op('reset',1350,'focus'),op('charge',1400,true),op('advance',1740)],[]],
 ['airborne_no_rng',[op('begin',300,{angle:.9,airborne:true}),op('resolve',459,{seq:1}),op('resolve',460,{seq:1}),op('begin',600,{angle:.3}),op('reset',610,'death'),op('begin',900,{angle:.1})],[.1,.7]],
 ['setters_network',[op('block',100,true,{ws_open:true}),op('block',101,true),op('charge',102,true),op('block',103,false),op('charge',104,true),op('charge',105,true),op('charge',106,false),op('charge',107,false),op('block',108,true,{ws_open:false}),op('block',109,false),op('charge',110,true),op('charge',111,false)],[]],
 ['zero_charge_sentinel',[op('charge',0,true),op('begin',1200,{angle:0,heavy:true}),op('charge',1201,true),op('begin',2401,{angle:0,heavy:true})],[]],
 ['pending_replace',[op('begin',300,{angle:0}),op('begin',600,{angle:0}),op('resolve',601,{seq:1}),op('resolve',634,{seq:2}),op('resolve',635,{seq:2}),op('resolve',636,{seq:2})],[.8,.8]],
 ['delivery_grace',[op('begin',300,{angle:0}),op('resolve',740,{seq:1,contact:{npcId:'unknown'},contactAge:35}),op('begin',800,{angle:0}),op('resolve',1241,{seq:2})],[.8,.8]],
 ['contact_age',[op('begin',300,{angle:0}),op('resolve',340,{seq:1,contact:{npcId:'x'},contactAge:41}),op('begin',600,{angle:0}),op('resolve',700,{seq:2,contact:{npcId:'x'},contactAge:34}),op('begin',900,{angle:0}),op('resolve',1000,{seq:3,contact:{npcId:'x'},contactAge:null})],[.8,.8,.8]],
 ['resolve_lock_consumes',[op('begin',300,{angle:0}),op('resolve',340,{seq:1},{armed:true}),op('resolve',341,{seq:1},{armed:false}),op('begin',600,{angle:0}),op('resolve',634,{seq:2},{dead:true}),op('resolve',635,{seq:2})],[.8,.8]],
 ['renderer_pending',[op('begin',300,{angle:0}),op('resolve',340,{seq:1},{walk_active:false}),op('resolve',341,{seq:1},{walk_active:true})],[.8]],
];
for(const [field,value] of [['mode','pve'],['dead',true],['stunned',.001],['stance','prone'],['arresting',true],['driving',true],['jetski',true],['swimming_deep',true],['in_bus',true],['armed',true],['chat_open',true],['menu_open',true],['walk_active',false]])scenarios.push(['lock_'+field,[op('begin',500,{angle:.3},{[field]:value}),op('charge',600,true),op('block',700,true),op('begin',2000,{angle:.3,heavy:true})],[]]);
function execute([name,operations,rolls]){
 let now=0,draws=0,effects=[],timers=[],timerSerial=0,state={...base};
 const effect=e=>effects.push(clean(e));
 const player={r:10,c:12};let angle=0;Object.defineProperty(player,'ang',{get:()=>angle,set(v){angle=v;effect({kind:'heading',angle:v})}});
 const dataset=new Proxy({},{set(obj,field,value){obj[field]=value;effect({kind:'telemetry',field,value});return true}});
 const context=vm.createContext({console,Math:Object.assign(Object.create(Math),{random(){if(draws>=rolls.length)throw Error('Unexpected RNG '+name);return rolls[draws++]}}),performance:{now:()=>now},document:{documentElement:{dataset}},player,
 setTimeout(callback,delay){timers.push({id:++timerSerial,at:now+delay,callback});return timerSerial},
 _walkRendererActive:()=>state.walk_active,_isArmed:()=>state.armed,_effectivePlayerStance:()=>state.stance,
 showToast(){effect({kind:'toast',id:'pve_observer_melee',duration_ms:2600})},addKick(a,p){effect({kind:'camera_kick',angle:a,power:p})},_renewAllLocks(){effect({kind:'renew_locks'})},
 _fireBtn:{classList:{add(){effect({kind:'cooldown',active:true,duration_ms:300})},remove(){effect({kind:'cooldown',active:false,duration_ms:300})}}},
 ws:null,lockedTargets:new Set(),_LOCAL_PREVIEW:false,_UP:new URLSearchParams(),NPCS:[],cityCops:[],_bankInt:null,
 _walkShotNativeRef:()=>null,_threeNpcActionRefs:new Map(),_onlinePoliceArrest:null});
 vm.runInContext(initial+'\n'+helpers+'\n'+punch+'\nconst bridge={'+methods+'};\n'+
 'function capture(){return {fault:"",begin_context:!!_walkMeleeBeginContext,lastPunchClientT,attackSeq:_meleeAttackSeq,handSide:_meleeHandSide,kickSide:_meleeKickSide,block:_meleeBlockHeld,blockSeq:_meleeBlockSeq,chargeStartedAt:_meleeChargeStartedAt,chargeSeq:_meleeChargeSeq,animation:_punchAnim||{},pending:_walkMeleePending||{}}}',context);
 const rows=[];
 for(const operation of operations){
  now=operation.time;Object.assign(state,operation.state);effects=[];
  Object.assign(context,{myMode:state.mode,myDead:state.dead,_meleeStunnedIn:state.stunned,_murderPoliceArrest:state.arresting,myDrivingCarId:state.driving?'vehicle':null,myJetSkiId:state.jetski?'jetski':null,_playerSwimmingDeep:state.swimming_deep,_inBus:state.in_bus,chatOpen:state.chat_open,_gameMenuOpen:state.menu_open,
   ws:state.ws_open?{readyState:1,send(raw){const packet=JSON.parse(raw);effect({kind:'packet',type:packet.t,data:packet.d})}}:null});
  player.r=state.player_r;player.c=state.player_c;
  context.request=operation.arg;
  let reply;
  if(operation.method==='advance'){
   const due=timers.filter(t=>t.at<=now).sort((a,b)=>a.at-b.at||a.id-b.id);timers=timers.filter(t=>t.at>now);for(const timer of due)timer.callback();reply={ok:true};
  }else if(operation.method==='reset'){vm.runInContext('_resetMeleeTransientState(request)',context);reply={ok:true};}
  else reply=vm.runInContext('bridge.'+({begin:'beginWalkMelee',charge:'setWalkMeleeCharge',block:'setWalkMeleeBlock',resolve:'resolveWalkMelee'}[operation.method])+'(request)',context);
  const snapshot=clean(vm.runInContext('capture()',context));snapshot.timers=timers.length;
  rows.push({...operation,reply:clean(reply),effects:clean(effects),snapshot,draws});
 }
 return {name,initial:base,rolls,operations:rows};
}
const result={qualification:'Unchanged extracted world.html WALK functions; TEST_ONLY host effects, no gameplay target provider or HP.',source:{path:'world.html',sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,sections},scenarios:scenarios.map(execute)};
const dest=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/melee_attack_source_oracle.json');fs.writeFileSync(dest,JSON.stringify(result));console.log(JSON.stringify({scenarios:result.scenarios.length,operations:result.scenarios.reduce((n,s)=>n+s.operations.length,0),source:result.source}));
