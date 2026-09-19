import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('walk_preview.mjs',import.meta.url),'utf8');
const refresh=source.slice(source.indexOf('async function refresh(){'),source.indexOf("$('reload').onclick=refresh;"));
let invalidations=0,failed=0,networkFailure=false;
const status={textContent:''},context={renderFreezeQa:null,busy:false,jump:null,insideBuilding:()=>false,buildingQaMove:null,performance,
 npcVehicleNavigation:{invalidate(){invalidations++;}},npcServiceDestinations:{invalidate(){invalidations++;}},
 $:()=>status,revision:['same','same','same','same'],loaded:239,
 getJsonBytes:async()=>{if(networkFailure)throw Error('offline');return 'same';},jsonRevision:async x=>x,fail:()=>failed++};
vm.createContext(context);vm.runInContext(refresh,context);
for(let i=0;i<4;i++)await context.refresh();
assert.equal(invalidations,0,'Unchanged periodic polls must preserve long-running vehicle and hospital searches');
assert.equal(context.busy,false);
networkFailure=true;await context.refresh();assert.equal(failed,1);assert.equal(invalidations,0,'Failed refresh keeps searches for the last valid scene');
console.log('PASS actual host refresh: unchanged and failed polling preserve pending transport navigation');
