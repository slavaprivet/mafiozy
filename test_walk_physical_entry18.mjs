import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {stagePhysicalEntryPatch} from './outputs/artist18_physical_entry_patch.mjs';
const disk=fs.readFileSync('world.html','utf8'),source=disk.includes('function _walkPhysicalEntryOnly(')?disk:stagePhysicalEntryPatch(disk);
for(const m of source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/type=['"](?:module|importmap|application\/json)/.test(m[1])&&m[2].trim())new vm.Script(m[2]);
function bodyAt(start){let p=source.indexOf('{',start),depth=1;const begin=p;for(p++;depth;p++){if(source[p]==='{')depth++;if(source[p]==='}')depth--;}return source.slice(begin,p);}
function fn(name){const start=source.indexOf('function '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('{',start))+bodyAt(start);}
let walk=true,carCalls=0,toasts=0;
const c={Math,Number,performance:{now:()=>10000},_walkRendererActive:()=>walk,_buildingInt:null,_bankInt:null,myDrivingCarId:null,myDead:false,myJailIn:0,
 player:{r:36,c:16},JAIL_ISLAND_3D_ENABLED:false,_gtaActionKind:null,_gtaActionCarId:null,_gtaBtn:{style:{},dataset:{},textContent:''},_selectedBuildingEntry:null,
 _nearestBlackmarketInteraction:()=>null,_nearestWorldEntryCandidate:()=>null,_refreshManualBuildingEntry:()=>null,
 _gtaBusinessPointerHandledAt:0,_gtaActionEnterAs:'driver',enterCar:()=>{carCalls++;},showToast:()=>{toasts++;},
 _zoneEl:{dataset:{},style:{}},BANKS:[{id:'b1'}],_policeState:{employed:true},_mafiaState:{employed:false}};
vm.createContext(c);
const protectedNames=['_currentBuildingEntryTarget','_nearbyBuildingInteractionFor3D','_activateSelectedBuildingIfNear','activateCurrentBuildingEntry','_activateApartmentGuestEntry','_activateBankEntryFrom3D','toggleNearbyBuildingActionsFrom3D'];
for(const name of ['_walkPhysicalEntryOnly',...protectedNames])vm.runInContext(fn(name),c);
for(const name of protectedNames){const result=c[name]();assert(result===false||result===null||result?.ok===false,name+' blocks the old exterior entry before accessing old grid data');}
const start=source.indexOf('  if(!_walkPhysicalEntryOnly()){\n  // Чёрный рынок'),end=source.indexOf('  // Лидер постоянной банды зовёт',start);
assert(start>=0&&end>start);vm.runInContext('function prompt(){_gtaBtn.style.display="none";'+source.slice(start,end)+'return "continue-npc-car";}',c);
assert.equal(c.prompt(),'continue-npc-car');assert.equal(c._gtaBtn.style.display,'none','Walk suppresses all old special/house entry branch and still reaches subsequent actions');
walk=false;c.prompt();assert.equal(c._gtaActionCarId,'36,16,job');assert.equal(c._gtaBtn.style.display,'block','2D original job entry remains');walk=true;
for(const [element,name]of [['_gtaBtn','gtaClick'],['_zoneEl','zoneClick']]){const marker=element+".addEventListener('click', () => ";const at=source.indexOf(marker);assert(at>=0);vm.runInContext('function '+name+'()'+bodyAt(at),c);}
for(const kind of ['building_enter','apt_guest_enter','major_enter']){c._gtaActionKind=kind;c.gtaClick();}
c._gtaActionKind='enter';c.gtaClick();assert.equal(carCalls,1,'car entry callback remains active in Walk');
c._zoneEl.dataset.bizId='old-shop';c.zoneClick();delete c._zoneEl.dataset.bizId;
c._zoneEl.dataset.bankId='b1';c.zoneClick();assert.equal(toasts,0,'stale bank exterior button inert');
c._bankInt={bank:c.BANKS[0],phase:'lobby'};assert.equal(c._walkPhysicalEntryOnly(),false);c.zoneClick();assert.equal(toasts,1,'existing bank interior action remains available');c._bankInt=null;
const pose=fs.readFileSync('assets/maps/city_rebuild_v1/walk_preview.mjs','utf8');assert(pose.includes('const result=candidate.entry.interact(hero.object.position);'),'native E remains actual door interaction');
assert(!source.includes('function _walkSpecialBuildingEntry('),'superseded mapped gold-button design absent');
console.log(JSON.stringify({pass:true,mode:source===disk?'applied':'staged only; world unchanged',checks:'7 old entry/marker/bridge gates; job 2D preserved; Walk special block skipped; stale GTA/zone clicks inert; car callback and bank interior preserved; native door code untouched; all inline syntax'}));
