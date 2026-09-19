import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const routeSource=world.match(/^function _planNpcRouteTo\([^]*?^}/m)?.[0];
assert(routeSource,'production route function found');
let reserved=0,cancelled=0;
const box={
  Math,performance:{now:()=>1000},MAP_COLS:200,
  _walkNpcNavigationResolver:()=>({blocked:false,depth:0,surface:'land'}),
  _npcPathPassable:()=>true,
  _cancelNpcDirectedSearch:n=>{cancelled++;n._routeSearchPending=false;},
  _setNpcRoute:(n,path,kind)=>{n._route=path;n._routeKind=kind;return true;},
  _npcReserveRouteWork:()=>{reserved++;throw new Error('near clear driver must not enter shared BFS');},
  _npcRouteWorkExpired:()=>false,_npcFinishRouteWork:()=>{},npcPassable:()=>true,
};
vm.createContext(box);vm.runInContext(routeSource+'\nglobalThis.plan=_planNpcRouteTo;',box);
const driver={id:'resident_driver',r:10,c:10};
assert(box.plan(driver,14,10,()=>true,.08,1200,'traffic_driver'));
assert.equal(reserved,0);assert.equal(cancelled,1);
assert.equal(driver._route.length,1);assert.equal(driver._route[0].r,14);assert.equal(driver._route[0].c,10);assert.equal(driver._routeKind,'traffic_driver');
console.log('PASS nearby traffic driver uses full-sweep direct approach without shared BFS admission');
