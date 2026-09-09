import assert from 'node:assert/strict';
import {vehicleCoverPolygon} from './vehicle_cover_edges.mjs';
import {findCover,moveCover,coverExposure} from './hero_cover.mjs';
const profile={collisionHull:[[-1,-1.2],[-.8,-2.5],[.8,-2.5],[1,-1.2],[1,1.2],[.8,2.5],[-.8,2.5],[-1,1.2]]};
for(const yaw of [0,.73,-1.9]){
 const polygon=vehicleCoverPolygon(13,-4,yaw,profile);assert.equal(polygon.length,4);
 const tr=(x,z)=>({x:13+x*Math.cos(yaw)+z*Math.sin(yaw),y:0,z:-4-x*Math.sin(yaw)+z*Math.cos(yaw)});
 const p=tr(-1.6,0),direction={x:Math.cos(yaw),z:-Math.sin(yaw)};
 const c=findCover({position:p,direction,bodies:[{id:'car',polygon,minY:0,maxY:2.2,vehicle:true}],canOccupy:()=>true});
 assert.ok(c);assert.ok(Math.abs(c.length-5)<1e-8,'cover follows whole side, not tyre bevel');
 for(const sign of [-1,1]){const edge=moveCover(c,sign*100,()=>true),peek=coverExposure(edge,{aiming:true,direction});
 const x=edge.anchor.x+peek.offset.x-13,z=edge.anchor.z+peek.offset.z+4,localZ=x*Math.sin(yaw)+z*Math.cos(yaw);
 assert.ok(Math.abs(localZ)>2.5,'peek clears real bumper ends');
 const hood=coverExposure({...edge,height:1.1},{aiming:true,direction});assert.ok(Math.hypot(hood.offset.x,hood.offset.z)>.4,'car corner peeks sideways even beside a low hood');}
}
assert.equal(profile.collisionHull.length,8,'driving hull remains detailed');console.log('vehicle_cover_edges: PASS full side, both ends, yaw, unchanged driving hull');
