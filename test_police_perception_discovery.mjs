import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(process.argv[2]||'world.html','utf8').replace(/\r\n/g,'\n');function fn(n){const a=source.indexOf(`function ${n}(`);return a<0?'':source.slice(a,source.indexOf('\n}',a)+2);}
let now=10000,wall=true,reports=0;const cop=(extra={})=>({id:'cop1',kind:'patrol',x:0,y:0,ang:0,alive:true,...extra});
const e={Math,Number,String,Array,performance:{now:()=>now},cityCops:[],worldCops:[],player:{r:0,c:4},_bankInt:null,_buildingInt:null,myDead:false,myDrivingCarId:null,_isArmed:()=>true,_effectivePlayerStance:()=> 'stand',
 _policeWorldLineClear:()=>!wall,_copChats:new Map(),serviceVehicles:[],COP_REACT_R:10,_COP_REACT_CRIES:{shot:['Стой'],kill:['Стой'],fight:['Разойтись']},_sendPoliceWitnessOpenFire:()=>reports++};
vm.createContext(e);
for(const n of ['_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_npcCanHearPoint','_policePerceptionActor','_policeCanSeePoint','_policePursuitTarget','_policeWatchExposedWeapon','_alertNearbyCops','_copInRadius'])if(fn(n))vm.runInContext(fn(n),e);
let a=cop();e.cityCops=[a];e._alertNearbyCops('kill',0,4,true);assert.equal(reports,0,'RED: cop cannot identify crime through a wall');assert.equal(!!a._pursuing,false);
wall=false;a=cop({ang:Math.PI});e.cityCops=[a];e._alertNearbyCops('kill',0,4,true);assert.equal(reports,0,'Back-facing cop cannot identify killer');
a=cop();e.cityCops=[a];e._alertNearbyCops('kill',0,4,true);assert.equal(reports,1);assert.equal(a._pursuing,true);assert.ok(a._murderAggroUntil>now,'Visible actual murder preserves immediate combat');
wall=true;a=cop();e.cityCops=[a];e._alertNearbyCops('shot',0,3);assert.equal(reports,1);assert.equal(a._civilianSuspicion?.kind,'heard_gunfire');assert.equal(!!a._pursuing,false,'Hearing-only triggers inspection, not proof of shooter');
a=cop({x:30,tx:4,ty:0});e.cityCops=[];e.worldCops=[a];wall=false;assert.equal(e._copInRadius(0,4,10),false,'Waypoint is not actual officer position');
a=cop();e.worldCops=[a];assert.equal(e._copInRadius(0,4,10),true);wall=true;assert.equal(e._copInRadius(0,4,10),false);
a=cop();e.worldCops=[];wall=false;let target=e._policePursuitTarget(a,now,16,false);assert.equal(target.visible,true);a._pursuing=true;
wall=true;e.player.c=7;now+=1000;target=e._policePursuitTarget(a,now,16,false);assert.equal(target.visible,false);assert.equal(target.c,4,'Pursuit searches remembered position, not invisible player tracking');
now+=8000;assert.equal(e._policePursuitTarget(a,now,16,false),null,'Lost contact eventually returns to patrol without clearing wanted');
a=cop({_playerAttackUntil:now+45000,_pursuing:true});target=e._policePursuitTarget(a,now,24,true);assert.equal(target.c,7,'Actual direct attack retains known source');assert.equal(target.visible,false);
a=cop({_casePhase:'arrest_cuffing',kind:'murder_response'});e.cityCops=[a];wall=false;e._alertNearbyCops('kill',0,4,true);assert.equal(a._casePhase,'arrest_cuffing','Discovery does not steal custody pose owner');
let nativeQuery;e._walkNpcPerceptionResolver=q=>(nativeQuery=q,{blocked:false});e._effectivePlayerStance=()=> 'prone';e._policeCanSeePoint(cop(),e.player.r,e.player.c,16);assert.equal(nativeQuery.targetHeight,.35);
e._effectivePlayerStance=()=> 'crouch';e._policeCanSeePoint(cop(),e.player.r,e.player.c,16);assert.equal(nativeQuery.targetHeight,.8);
a=cop();wall=false;e._walkNpcPerceptionResolver=null;e._effectivePlayerStance=()=> 'stand';e._policeWatchExposedWeapon(a,now);assert.equal(a._civilianSuspicion,undefined);now+=1300;e._policeWatchExposedWeapon(a,now);assert.equal(a._civilianSuspicion.kind,'weapon_display');assert.equal(!!a._pursuing,false,'Visible weapon prompts inspection, never immediate combat');
console.log('PASS police source discovery: FOV/LOS/native stance, no waypoint witness, hearing-only inspection, visible murder, last-seen search/expiry, direct attack preservation, custody owner');
