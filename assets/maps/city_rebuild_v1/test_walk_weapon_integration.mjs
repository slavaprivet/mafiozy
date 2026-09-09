// Execute the actual /walk G/E/Q handlers and bridge functions with a lightweight
// DOM/hero host. Geometry, inventory and fire state are production implementations.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {createGroundWeapons,nearestWeaponDrop} from './ground_weapons.mjs';
import {createWeaponInventory} from './weapon_inventory.mjs';
import {createWeaponFireState,stepWeaponFire} from './hero_weapon_fire.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const section=source.slice(source.indexOf('function arsenalOpen()'),source.indexOf('function initArsenal()'));
// Locate by the actual Q action, not the spelling/order of unrelated UI guards.
const qBranch=source.indexOf("if(e.code==='KeyQ')"),handlerStart=source.lastIndexOf("addEventListener('keydown',e=>{",qBranch);
assert(qBranch>0&&handlerStart>0,'actual production input handler');
const handler=source.slice(handlerStart,source.indexOf('\n});',handlerStart)+4);
for(const branch of ['KeyQ','KeyG','KeyE'])assert(handler.includes(`if(e.code==='${branch}')`),'actual handler retains '+branch);
let keydown,prevented=0,buildingCalls=0,mounts=0,menuOpen=false,dead=false,blocked=false,hudBlocked=false;
const elements=new Map(['scene-menu','car-prompt','building-prompt'].map(id=>[id,{hidden:true}]));
const host={THREE,ARSENAL,createWeaponModel,createGroundWeapons,nearestWeaponDrop,createWeaponInventory,createWeaponFireState,
 weaponInventory:createWeaponInventory(),fireStates:new Map(),scene:new THREE.Scene(),currentWeapon:ARSENAL[0],weaponModel:null,groundWeapons:null,lastWeaponId:null,npcBridge:null,
 hero:{object:new THREE.Group(),scale:.368,mountWeapon(){mounts++}},verticalNavigation:{active:false},walking:true,occupiedSeat:null,transition:null,jump:null,heroBlast:null,busy:false,
 artistBusy:()=>dead,artistSwimming:()=>false,hudInputBlocked:()=>hudBlocked,artistInput:{cancel(){}},groundHeight:()=>0,pedestrianAllowed:()=>!blocked,waterAt:()=>null,
 $:id=>elements.get(id),document:{body:{dataset:{}},pointerLockElement:null},weaponPickupPrompt:{hidden:true},performance:{now:()=>1000},
 weaponHud:{setState(s){host.ui=s},isOpen:()=>menuOpen,setOpen(value){menuOpen=value}},
 releaseWeapon(){},keys:new Set(),buildingKeyConsumed:false,entryHeld:0,pointerHeld:false,frameInteraction:undefined,
 addEventListener:(name,fn)=>{if(name==='keydown')keydown=fn},interactWithBuilding(){buildingCalls++;return false},interactWithVehiclePanel(){return false},
 heroCover:{leave(){}},heroPosture:{target:'stand'},setHeroPosture(){},beginJump(){},restoreBuildingCamera(){},followCarCamera:false,controls:{target:new THREE.Vector3()},camera:{position:new THREE.Vector3()},
 setFreeMouse(){},releaseControls(){},exitNotice:'',exitNoticeUntil:0};
vm.createContext(host);vm.runInContext("function fireState(){if(!fireStates.has(currentWeapon.id))fireStates.set(currentWeapon.id,createWeaponFireState(currentWeapon.id));return fireStates.get(currentWeapon.id)}\n"+section+'\n'+handler,host);
const press=(code,repeat=false,overrides={})=>keydown({code,repeat,target:{tagName:'BODY'},preventDefault(){prevented++},...overrides});
press('KeyQ',false,{defaultPrevented:true});assert(!menuOpen,'source-consumed Q cannot reopen walk menu');
press('KeyQ',false,{target:{tagName:'DIV',isContentEditable:true}});assert(!menuOpen,'typing in a source editor does not open arsenal');
press('KeyQ');assert(menuOpen,'single Q opens immediately');assert.equal(host.currentWeapon.id,'none');press('KeyQ',true);assert(menuOpen);press('KeyQ');assert(!menuOpen,'second Q closes');
assert(host.equipWeapon('m16'));assert.equal(host.currentWeapon.id,'m16');
const fired=stepWeaponFire(host.fireStates.get('m16'),{triggerPressed:true},.01).state;host.fireStates.set('m16',fired);
const ammo=fired.magazine,reserve=fired.reserveAmmo;
press('KeyG');assert.equal(host.currentWeapon.id,'none');assert(!host.ui.ownedWeaponIds.includes('m16'));assert.equal(host.weaponInventory.getDropped().length,1);assert.equal(host.groundWeapons.stats().count,1);
press('KeyG',true);press('KeyG');assert.equal(host.weaponInventory.getDropped().length,1,'held G/unarmed cannot duplicate');
assert.equal(host.equipWeapon('m16'),false,'dropped gun cannot be selected by stale UI');
host.updateGroundWeaponInteraction(.04);assert(!host.weaponPickupPrompt.hidden);
hudBlocked=true;const blockedMounts=mounts,blockedBuildingCalls=buildingCalls,blockedOwned=host.weaponInventory.getOwnedIds().join(',');
for(const code of ['KeyQ','KeyG','KeyE'])press(code);
assert(!menuOpen,'source modal blocks Q');assert.equal(host.groundWeapons.stats().count,1,'source modal blocks E pickup');assert.equal(host.currentWeapon.id,'none');assert.equal(mounts,blockedMounts);assert.equal(buildingCalls,blockedBuildingCalls,'source modal E cannot leak into building interaction');assert(!host.keys.has('KeyE'),'source modal E cannot start vehicle hold');
assert.equal(host.equipWeapon('uzi'),false,'source modal also blocks direct HUD selection');assert.equal(host.pickupNearbyWeapon(),false,'source modal blocks direct pickup');assert.equal(host.weaponInventory.getOwnedIds().join(','),blockedOwned);hudBlocked=false;
const mountsBeforePickup=mounts;press('KeyE');assert.equal(host.currentWeapon.id,'none','pickup leaves fists equipped');assert.equal(mounts,mountsBeforePickup,'pickup does not remount');assert.equal(host.fireStates.get('m16').magazine,ammo);assert.equal(host.fireStates.get('m16').reserveAmmo,reserve);assert.equal(host.groundWeapons.stats().count,0);assert.equal(buildingCalls,0,'E pickup consumes building interaction');assert(!host.keys.has('KeyE'),'E pickup cannot start car hold');
press('KeyE',true);assert.equal(buildingCalls,0,'E autorepeat stays consumed until keyup');
host.equipWeapon('m16');host.dropCurrentWeapon();host.equipWeapon('uzi');
const heldModel=host.weaponModel,uziState={...host.fireStates.get('uzi'),magazine:15,reloadRemaining:1.1,triggerHeld:true};host.fireStates.set('uzi',uziState);host.buildingKeyConsumed=false;
press('KeyE');assert.equal(host.currentWeapon.id,'uzi','pickup never replaces held gun');assert.equal(host.weaponModel,heldModel,'same active model retained');assert.equal(host.fireStates.get('uzi').reloadRemaining,1.1,'active reload preserved');assert.equal(host.fireStates.get('uzi').triggerHeld,true);assert.equal(host.fireStates.get('m16').magazine,ammo,'pickup preserves collected ammo');
hudBlocked=true;press('KeyG');assert.equal(host.currentWeapon.id,'uzi','source modal blocks armed drop');assert.equal(host.dropCurrentWeapon(),false,'direct drop also honors source modal');assert.equal(host.weaponModel,heldModel);assert.equal(host.fireStates.get('uzi').reloadRemaining,1.1);hudBlocked=false;
for(const field of ['occupiedSeat','transition','jump','heroBlast','busy']){host[field]=true;press('KeyG');assert.equal(host.currentWeapon.id,'uzi',field+' blocks drop');host[field]=null}
dead=true;press('KeyG');assert.equal(host.currentWeapon.id,'uzi');assert.equal(host.equipWeapon('ak74'),false,'click selection cannot bypass death gate');host.setArsenalOpen(true);assert(!menuOpen);dead=false;
blocked=true;press('KeyG');assert.equal(host.currentWeapon.id,'uzi','cannot drop into inaccessible geometry');blocked=false;
press('KeyQ');press('KeyG');assert.equal(host.currentWeapon.id,'uzi','menu blocks gameplay keys');press('Escape');assert(!menuOpen);
press('KeyG');assert.equal(host.currentWeapon.id,'none');host.hero.object.position.x=10;host.buildingKeyConsumed=false;press('KeyE');assert.equal(host.currentWeapon.id,'none','distant item cannot be picked');
host.groundWeapons.dispose();host.disposeWeapon(host.weaponModel);
// Expiry can occur between the sweep and pickup transaction on the exact tick.
let timer=0;host.weaponInventory=createWeaponInventory({now:()=>timer,ownedIds:['m16']});host.currentWeapon=ARSENAL[0];host.fireStates.clear();host.groundWeapons=null;host.hero.object.position.set(0,0,0);host.equipWeapon('m16');host.dropCurrentWeapon();timer=299999;
const inventory=host.weaponInventory;host.weaponInventory={...inventory,expireDrops(){const removed=inventory.expireDrops();timer=300000;return removed}};
assert.equal(host.pickupNearbyWeapon(),false);assert.equal(inventory.getDropped().length,0);assert.equal(host.groundWeapons.stats().count,0,'expiry-at-pickup must dispose model, not orphan forever');
host.groundWeapons.dispose();
let bridgeSelections=0;host.npcBridge={getWalkWeaponOptions:()=>({options:[{id:'none'},{id:'tt_pistol'}]}),selectWalkWeapon(id){bridgeSelections++;return {accepted:id==='tt_pistol'}}};
host.syncWorldWeapon=()=>{host.currentWeapon=ARSENAL.find(w=>w.id==='tt_pistol')};
host.updateWeaponUi();assert.equal(host.ui.ownedWeaponIds.join(','),'none,tt_pistol','world gateway exposes only source inventory');
assert.equal(host.dropCurrentWeapon(),false,'no local ownership mutation in world gateway');assert.equal(host.nearbyGroundWeapon(),null);
dead=true;assert.equal(host.equipWeapon('tt_pistol'),false);assert.equal(bridgeSelections,0,'bridge selection respects death guard');dead=false;
host.setArsenalOpen(true);assert(host.equipWeapon('tt_pistol'));assert(!menuOpen,'accepted bridge selection closes Q menu');assert.equal(bridgeSelections,1);
console.log(JSON.stringify({passed:true,checks:['actual_GEQ_handler','source_default_prevented_and_editable_guards','source_HUD_blocks_Q_G_E_and_direct_mutation','immediate_Q','repeat_guard','ownership_UI','3D_drop','ammo_preserved','stale_selection_rejected','E_building_car_consumption','dead_vehicle_jump_menu_gates','range','wall_drop_guard'],mounts,prevented}));
