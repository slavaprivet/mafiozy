import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {weaponArtId,normalizeNetworkDrops,createWorldWeaponTransfers} from './world_weapon_transfers.mjs';

const ids=['nagan','revolver','tt_pistol','deagle','golden_colt','sawn_off','uzi','golden_uzi','tommy_gun','golden_tommy','ak74','m16','sniper','rpg'];
for(const id of ids)assert.equal(weaponArtId(id),id);
for(const [raw,id] of Object.entries({pistol:'tt_pistol',tt:'tt_pistol',pistol_heavy:'deagle',pistol_gold:'golden_colt',shotgun:'sawn_off',smg:'uzi',rifle:'ak74'}))assert.equal(weaponArtId(raw),id);
assert.equal(weaponArtId('invented'),null);
const row={drop_id:'drop-1',item_id:'ak74',space:'world',layer:'ground',elevation:0,r:2,c:3,magazine:17,expires_at:1300};
const ground={ok:true,server_now:1000,drops:[row]};
const normalized=normalizeNetworkDrops(ground,20)[0];
assert.equal(normalized.expiresAt,300020);
assert.deepEqual(normalized.position,{x:3*4.1,y:0,z:2*4.1});
assert.deepEqual(normalized.fireState,{magazine:17,reserveAmmo:0});
for(const invalid of [{expires_at:1000},{layer:'floor2'},{elevation:4},{r:NaN},{item_id:'fake'},{space:'bank'}])assert.deepEqual(normalizeNetworkDrops({...ground,drops:[{...row,...invalid}]},0),[]);
assert.equal(normalizeNetworkDrops({...ground,drops:[null,undefined,1,{...row,magazine:-1},{...row,drop_id:''},row]},0).length,1);
assert.deepEqual(normalizeNetworkDrops({ok:false,server_now:1000,drops:[row]},0),[]);
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};

// Retry the same logical request; apply only confirmed state. Pickup callback
// uses receipt data but never chooses the picked-up item as equipment.
let requests=[],applied=0,fail=true,t=20;
let held='tt_pistol',reload={id:'live-reload',until:800};
const result={ok:true,action:'pickup',equipped_weapon:'tt_pistol',inventory:[{id:'tt_pistol',qty:1},{id:'ak74',qty:1}],ammo_state:{mags:{pistol:4,rifle:17},reserve:{rifle:0}}};
const client=createWorldWeaponTransfers({now:()=>t,makeId:()=> 'stable-1',request:async(path,body)=>{
 requests.push([path,body&&{...body}]);if(path==='weapon-ground')return ground;
 if(fail){fail=false;throw Error('lost reply');}return result;
},applyState:data=>{applied++;assert.equal(data.equipped_weapon,held);}});
assert.equal((await client.pickup('drop-1')).ok,true);
assert.equal(applied,1);
assert.equal(requests[0][1].request_id,requests[1][1].request_id);
assert.equal(held,'tt_pistol');assert.deepEqual(reload,{id:'live-reload',until:800});
t=300020;assert.deepEqual(client.getDrops(),[]);

// Both replies lost: ground polling replays the ORIGINAL ID, not another drop.
requests=[];let connected=false;applied=0;
const uncertain=createWorldWeaponTransfers({makeId:()=> 'uncertain-1',now:()=>0,
 request:async(path,body)=>{requests.push([path,body&&{...body}]);if(!connected)throw Error('offline');return path==='weapon-ground'?ground:result;},applyState:()=>applied++});
assert.equal((await uncertain.pickup('drop-1')).error,'network');
assert.equal(uncertain.pending,true);assert.equal(uncertain.uncertain,true);
assert.equal((await uncertain.drop('ak74')).error,'pending_confirmation');
connected=true;await uncertain.refresh();
assert.equal(applied,1);assert.equal(uncertain.pending,false);
assert.deepEqual(requests.map(r=>r[1].request_id),['uncertain-1','uncertain-1','uncertain-1']);

// A pending transfer rejects a second one. Late pre-transfer ground cannot
// resurrect a picked item or clear the currently running new poll reference.
const oldPoll=defer(),newPoll=defer(),pickup=defer();let pollCount=0,transferCount=0;
const race=createWorldWeaponTransfers({now:()=>0,makeId:()=> 'race-1',request:(path)=>{
 if(path==='weapon-ground')return ++pollCount===1?oldPoll.promise:newPoll.promise;
 transferCount++;return pickup.promise;
}});
const oldRefresh=race.refresh();
const picking=race.pickup('drop-1');
assert.equal((await race.drop('ak74')).error,'busy');assert.equal(transferCount,1);
pickup.resolve(result);await new Promise(resolve=>setTimeout(resolve,0));
assert.equal(pollCount,2);
oldPoll.resolve(ground);await oldRefresh;
const sharing=race.refresh();assert.equal(pollCount,2);
newPoll.resolve({...ground,drops:[]});await Promise.all([picking,sharing]);
assert.deepEqual(race.getDrops(),[]);

// Network delay consumes remaining lifetime; it must not refresh five minutes.
let clock=0;const delayed=defer();
const latency=createWorldWeaponTransfers({now:()=>clock,request:()=>delayed.promise});
const loading=latency.refresh();clock=10000;delayed.resolve({...ground,drops:[{...row,expires_at:1005}]});await loading;
assert.deepEqual(latency.getDrops(),[]);

const idFailure=createWorldWeaponTransfers({makeId:()=>{throw Error('UUID unavailable');},request:async()=>ground});
assert.equal((await idFailure.drop('ak74')).error,'request_id_unavailable');assert.equal(idFailure.pending,false);
const disposal=defer();let afterDispose=0;
const disposed=createWorldWeaponTransfers({makeId:()=> 'dispose-1',request:()=>disposal.promise,applyState:()=>afterDispose++});
const disposing=disposed.pickup('drop-1');disposed.dispose();disposal.resolve(result);await disposing;
assert.equal(afterDispose,0);assert.deepEqual(disposed.getDrops(),[]);

// Execute the actual world callback AND its actual ammo reconciliation helper.
// No network/DOM/real player is used. This catches accidental auto-equip or
// cancel/restart of a different weapon's live reload in source integration.
const source=readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const callbackBody=source.split('async applyState(result){')[1]?.split('\n      }')[0];
assert.ok(callbackBody,'actual source transfer callback exists');
function sourceFunction(name){const start=source.indexOf(`function ${name}(`);assert.ok(start>=0);return source.slice(start,source.indexOf('\n}',start)+2);}
const context=vm.createContext({
 currentWeapon:'tt_pistol',_lastEquippedWeapon:'tt_pistol',_inventoryItems:[{id:'tt_pistol',qty:1,type:'weapon',name:'ТТ'},{id:'bulletproof',qty:1,type:'armor',current:50}],
 WEAPON_FX_CFG:{pistol:{ammoType:'9mm',magSize:12},rifle:{ammoType:'rifle',magSize:30}},WEAPON_ALIASES:{tt_pistol:'pistol',ak74:'rifle'},
 _serverAuthoritativeAmmo:true,_ammoVersion:1,_ammoState:{},AMMO_TYPES:{'9mm':{max:240},rifle:{max:180}},
 _reloadWeapon:'pistol',_reloadActionId:'existing-reload',_reloadUntil:1600,_reloadTicker:10,
 performance:{now:()=>100},Date:{now:()=>1000000},setInterval:()=>20,
 _wepPickOpen:false,_profileTab:'status',document:{getElementById:()=>null},
 cancelled:0,simulateFallback:true,
 weaponLabel:id=>id,_saveCurrentWeaponChoice:()=>{},renderWeaponHud:()=>{},renderWeaponPick:()=>{},renderProfileTab:()=>{},_saveAmmoState:()=>{},_finishWeaponReload:()=>{},
});
vm.runInContext(`function cancelWeaponReload(){cancelled++;_reloadWeapon=null;_reloadActionId='';}
 function resolveWeapon(id){return WEAPON_ALIASES[id]||id;}
 function _stopReloadTicker(){_reloadTicker=0;}
 function _syncMyWeaponsFromInventory(){if(simulateFallback&&currentWeapon)currentWeapon='ak74';}
 ${sourceFunction('_applyAuthoritativeAmmoState')}
 globalThis.actualApply=async function(result){${callbackBody}};`,context);
await context.actualApply({ok:true,action:'pickup',equipped_weapon:'tt_pistol',inventory:[{id:'tt_pistol',qty:1},{id:'ak74',qty:1},{id:'bulletproof',qty:1}],
 ammo_state:{ammo_version:2,mags:{pistol:4,rifle:17},reserve:{'9mm':36,rifle:8},reloads:{pistol:{id:'existing-reload',ready_at:1001.5}}}});
assert.equal(context.currentWeapon,'tt_pistol');assert.equal(context.cancelled,0);
assert.equal(context._reloadWeapon,'pistol');assert.equal(context._reloadActionId,'existing-reload');assert.equal(context._reloadUntil,1600);
assert.equal(context._ammoState.mags.pistol.mag,4);
assert.equal(context._inventoryItems.find(it=>it.id==='bulletproof').current,50);
context.simulateFallback=false;
await context.actualApply({ok:true,action:'drop',replayed:true,equipped_weapon:null,inventory:[],ammo_state:{ammo_version:3,mags:{},reserve:{},reloads:{}}});
assert.equal(context.currentWeapon,null);assert.equal(context.cancelled,1);
console.log('PASS 14 weapon IDs, server expiry/cells, same-receipt retry/reconciliation, poll races, selection/reload callback contract, dispose');
