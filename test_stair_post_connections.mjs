import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
import {createInteriorStaircase,planInteriorStaircase} from './assets/maps/city_rebuild_v1/interior_staircase.mjs';
// Frozen hashes from the shared planner before the rail-only integration.
const routeBaseline={
  "2.7/0.65/2": "359610b2d98da4d8b5bd6039f29570f9594e486ae83d34f99105ff5e40c0a8f1",
  "2.7/0.65/3": "024b0c0278e98d9040eddc674b9817bb10fd5da974328fda324926a6435f1a29",
  "2.7/0.78/2": "1a4205fae04b8edb3a878c70a79d4afbad463062a81cc00546baf73050fe4f13",
  "2.7/0.78/3": "93de8f8ded233ea0eb77884ccdb335702780f7b01111ebdb743abc2eae15f8a6",
  "2.9/0.65/2": "6060cd252c1c056e6d1b87d0fa1acd41a5b5bdaa8ea65504d05a8ecfc2ec4a1f",
  "2.9/0.65/3": "56f5b50c25be9ef1f6254fb2a74853281e0721faf7c1be3e7221d05fcbe5b3b8",
  "2.9/0.78/2": "157050b67aeae17a7f3dfb7cd0fd1da193f994f7f7a7b03d14ae2bc099e21f70",
  "2.9/0.78/3": "ee86ec5a65be4bbf69ab19d540d4b4e5c6b41e613d31cffc9254d91c0a047a38",
  "2.985/0.65/2": "bd0a329233d9e8a5a8425f8f95406426e65dcd8bfe462fa9ea64912e5ce04ce0",
  "2.985/0.65/3": "6288db92fdf4ff73d8711df6f1fdda0e7a60e83a40f62f5ade2aedac7a3d506b",
  "2.985/0.78/2": "8f268b45b0c00b2b3e0c36f6501236ef04fb73a42f00cfe8e0cae72bddecaa17",
  "2.985/0.78/3": "c3e5a1aa725a2a3b9856933e8c01bbafc2d460a40d2a52c29f4a4171c1106930",
  "3.25/0.65/2": "377080572ee139f892f7579a80e375be5b66d93a4c15d16b65172328bc3a4028",
  "3.25/0.65/3": "024008bc1b9a8fd649f1146828b798a1d9848e073a78aded8ac91487e71d499f",
  "3.25/0.78/2": "0ba28ebae1507492c2aedb71c0bd2560941837e3bf80d1fa56ea4dba4a107286",
  "3.25/0.78/3": "32a2e2c18a314e47a4bd96ab94ed6ae3f102c2bd483bae3af6fdcfb34c2d959c",
  "3.3/0.65/2": "d0bd5992e779d7190529edd123a3e4f3e9e27d1e0e1a75705a07408d25431032",
  "3.3/0.65/3": "0eb910c7b5b67833124fe91a374707bfbd70afefc1335c07e333ccd1b1fa7898",
  "3.3/0.78/2": "b2116ac32455963b8d76deddd21974e151a60a1f955eaebe3bda0ed6a41b1187",
  "3.3/0.78/3": "8ca1d7061bbca8b0504f82ef40b1cad8c74bfed041fda6914cdcffe140e7774b",
  "4.2/0.65/2": "f46d1809aadbc5840e1fca6702e7f1db6e54f01c329888bb9fcbd39d2c5320b3",
  "4.2/0.65/3": "d1bb0df787235142df06048599b221967dd2443c00ecead0e40ad3d469651129",
  "4.2/0.78/2": "238167acf6c8a4919f9c0ba1a640f5da04f30a8d60eab0df9a2d67aa2f32351b",
  "4.2/0.78/3": "81b21777d32c54ee0691002d2df9138b729768cf804d9debd9735f30c79c82fb"
};
const routeDigest=p=>createHash('sha256').update(JSON.stringify(Object.fromEntries(['footprint','flights','route','holeRects','landings'].map(k=>[k,p[k]])))).digest('hex');
let joints=0,poses=0;
for(const floorHeight of[2.7,2.9,2.985,3.25,3.3,4.2])for(const slope of[.65,.78])for(const floors of[2,3]){
 const options={rect:[-5,-9,5,5],floorHeight,slope,floors,flightWidth:1.3,landingDepth:slope===.78?1.2:1.3},pure=planInteriorStaircase(options);
 assert.equal(routeDigest(pure),routeBaseline[[floorHeight,slope,floors].join('/')],'original footprint/flights/route/holes/landings unchanged');
 for(const yaw of[0,Math.PI/2,Math.PI,Math.PI*1.37]){
  const stairs=createInteriorStaircase(T,options);stairs.group.rotation.y=yaw;stairs.group.position.set(8,.37,-4);stairs.group.updateMatrixWorld(true);assert.equal(stairs.group.children.length,2,'same two instanced draw pools');
  const steps=stairs.group.getObjectByName('Stair_Treads_And_Posts'),rails=stairs.group.getObjectByName('Brass_Stair_Handrails'),railInverses=[];
  for(let i=0;i<rails.count;i++){const m=new T.Matrix4();rails.getMatrixAt(i,m);railInverses.push(new T.Matrix4().multiplyMatrices(rails.matrixWorld,m).invert())}
  for(const c of stairs.postConnections){
   const b=stairs.boxes[c.boxIndex],bottom=b.y-b.h/2,top=b.y+b.h/2;
   assert.ok(bottom<c.supportY&&c.supportY-bottom<=.009,'post foot embeds into actual tread');
   assert.ok(top>c.underside+.01,'post top overlaps handrail underside');
   const worldTop=stairs.group.localToWorld(new T.Vector3(b.x,top,b.z));
   assert.ok(railInverses.some(m=>{const p=worldTop.clone().applyMatrix4(m);return Math.abs(p.x)<.5&&Math.abs(p.y)<.5&&Math.abs(p.z)<.5}),'post top is inside a REAL rotated handrail prism');
   const hits=[];for(const [dx,dz]of[[0,0],[.014,0],[-.014,0],[0,.014],[0,-.014],[.014,.014],[-.014,-.014]]){const origin=stairs.group.localToWorld(new T.Vector3(b.x+dx,c.supportY+.004,b.z+dz));hits.push(...new T.Raycaster(origin,new T.Vector3(0,-1,0),0,.03).intersectObject(steps).filter(h=>h.instanceId!==c.boxIndex))}
   assert.ok(hits.some(h=>Math.abs(h.point.y-(c.supportY+.37))<1e-5),'actual tread or landing directly anchors post foot '+JSON.stringify({floorHeight,slope,yaw,c}));
   joints++;
  }
  // All support columns remain inside the existing railing envelope; none
  // occupies the walk route reserved by the original staircase planner.
  for(const p of stairs.route)for(const c of stairs.postConnections){const b=stairs.boxes[c.boxIndex];if(b.y+b.h/2>p.y+.18&&b.y-b.h/2<p.y+1.85)assert.ok(Math.hypot(p.x-b.x,p.z-b.z)>.56,'no post in walking route')}
  stairs.dispose();poses++;
 }
}
console.log(`PASS ${joints} real tread/post/rail joints across ${poses} height/slope/storey/orientation cases; original route/floors/holes unchanged`);
