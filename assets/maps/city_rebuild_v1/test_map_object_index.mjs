import assert from 'node:assert/strict';
import {createMapObjectIndex,mapObjectBounds} from './exploration_minimap.mjs';
const objects=[];
for(let i=0;i<3200;i++){
 const x=(i*47%2048)-320,z=(i*83%1900)-260;
 objects.push(i%17===0?{id:i,x,z,polygon:[[x-18,z-7],[x+24,z-7],[x+24,z+11],[x-18,z+11]]}:{id:i,x,z,radius:1+i%5});
}
const index=createMapObjectIndex(objects),intersects=(a,b)=>a.minX<=b.maxX&&a.maxX>=b.minX&&a.minZ<=b.maxZ&&a.maxZ>=b.minZ;let queries=0,candidates=0,full=0;
for(let i=0;i<900;i++){
 const x=(i*113%1800)-230,z=(i*71%1650)-180,w=70+i%9*23,h=60+i%7*19,bounds={minX:x,maxX:x+w,minZ:z,maxZ:z+h},expected=objects.filter(object=>intersects(mapObjectBounds(object),bounds)),actual=index.query(bounds),actualIds=new Set(actual.map(object=>object.id));
 for(const object of expected)assert.ok(actualIds.has(object.id),'no visible map object may be omitted: '+object.id);candidates+=actual.length;full+=objects.length;queries++;
}
assert.ok(candidates<full*.16,'view index materially avoids full-world map passes');assert.equal(index.stats().objects,objects.length);assert.ok(index.stats().cells>0);
console.log(JSON.stringify({status:'PASS',queries,objects:objects.length,averageCandidates:candidates/queries,fullScan:full/queries,cells:index.stats().cells}));
