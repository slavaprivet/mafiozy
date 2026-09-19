import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8');
const start=source.indexOf('      const pursueBeforeR=cop.y,pursueBeforeC=cop.x;');
const end=source.indexOf('      // В pursue mode',start);
assert(start>=0&&end>start,'actual police pursuit movement block');
const block=source.slice(start,end);
function run({distance=5,visible=true,armed=true,deferred=false,blocked=false}={}){
 let calls=0,probes=0;
 const cop={x:0,y:0,walking:false,walkPhase:0};
 const scope={cop,perceivedTarget:{r:0,c:distance,visible},armedAggro:armed,distToPlayer:distance,dpr:0,dpc:distance,dt:1/60,stepR:0,stepC:1,Math,
  _movePoliceFootCop(n){calls++;n._policeFootMoveDeferred=deferred;if(!blocked&&!deferred){n.x+=.04;n.walking=true;}},
  _policeCrewSegmentPassable(){probes++;return true;}};
 vm.runInNewContext(block,scope);return{cop,calls,probes};
}
const hold=run();assert.equal(hold.cop.x,0,'stationary shooting must not enter obstacle sidestep');assert.equal(hold.cop.y,0);assert.equal(hold.cop.walking,false);assert.equal(hold.calls,0);assert.equal(hold.probes,0,'no collision queries for an intentional hold');
const wait=run({distance:10,deferred:true});assert.equal(wait.cop.x,0,'route budget wait cannot bypass the mover');assert.equal(wait.probes,0);
const approach=run({distance:10});assert.equal(approach.calls,1);assert.equal(approach.cop.x,.04);assert.equal(approach.probes,0);
const search=run({visible:false});assert.equal(search.calls,1);assert.equal(search.cop.x,.04);
const retreat=run({distance:2});assert.equal(retreat.calls,1);
const obstruction=run({distance:10,blocked:true});assert(obstruction.probes>0,'real obstacle retains swept fallback');assert.equal(obstruction.cop.walking,true);
console.log('PASS actual police pursuit: stable fire lane, deferred route wait, approach/search/retreat and swept obstacle fallback');
