import assert from 'node:assert/strict';
import {createNpcResidentBuildingAccess} from './npc_resident_building_access.mjs';
class Point{constructor(x=0,y=0,z=0){Object.assign(this,{x,y,z});}clone(){return new Point(this.x,this.y,this.z);}lerp(p,t){this.x+=(p.x-this.x)*t;this.y+=(p.y-this.y)*t;this.z+=(p.z-this.z)*t;return this;}}
let opening=false,fraction=.6,interactions=0;
const entry={instance:{id:'native-bank',gameplayId:'bank:large'},approachPoint:()=>new Point(0,0,2),roomPoint:()=>new Point(0,0,-3),floorHeight:()=>0,containsInterior:p=>p.z<-.2,proximity:()=>({opening,fraction}),interact(){interactions++;opening=!opening;}};
const entries=[entry],query=createNpcResidentBuildingAccess({getEntries:()=>entries});
const [door]=query({action:'list'}).doors;assert.equal(door.id,'native:native-bank');assert.equal(door.sourceId,'large');assert.equal(door.sourceKind,'bank');assert.deepEqual(door.sourceAliases,['bank:large']);
const request={action:'open',doorId:door.id,from:{r:door.r,c:door.c}};
assert(!query(request).ready);for(let i=0;i<30;i++)assert(!query(request).ready);assert.equal(interactions,1,'opening target is not toggled repeatedly while door animates');fraction=1;assert(query(request).ready);assert.equal(interactions,1);
opening=false;fraction=.5;query(request);query(request);assert.equal(interactions,2,'a closing door gets one reopening request');
assert(!query({...request,from:{r:999,c:999}}).ready);assert.equal(interactions,2);
entries.push({...entry,instance:{id:'unbound-shop',gameplayId:null,sourceParcelId:'PAR-EA-0042'}});const unbound=query({action:'list'}).doors[1];assert.equal(unbound.sourceKind,'native');assert.deepEqual(unbound.sourceAliases,[],'parcel is not silently assigned an owner/business identity');
entries.push({...entry,instance:{id:'printing',assetId:'print_shop',role:'commercial_building',gameplayId:null}});const store=query({action:'list'}).doors[2];assert.equal(store.assetId,'print_shop');assert.equal(store.buildingRole,'commercial_building');assert.deepEqual(store.sourceAliases,[],'commercial role is not server ownership');
console.log('PASS resident entry adapter: exact declared gameplay aliases, no guessed ownership, live entry refresh, opening/closing without repeated toggles');
