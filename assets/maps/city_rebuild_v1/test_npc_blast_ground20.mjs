import test from 'node:test';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {createNpcBlastGround20,stepNpcBlastGround20} from './npc_blast_ground20.mjs';
const bounds={min:{x:-.2,y:-.65,z:-.15},max:{x:.2,y:.65,z:.15}};
const seed=extra=>createNpcBlastGround20({position:{x:0,y:2,z:0},velocity:{x:1,y:2,z:.3},angularVelocity:{x:1.7,y:.4,z:.3},localBounds:bounds,eventAt:10,...extra});
function offsets(s){const q=s.quaternion;return s.corners.map(p=>{const ix=q.w*p.x+q.y*p.z-q.z*p.y,iy=q.w*p.y+q.z*p.x-q.x*p.z,iz=q.w*p.z+q.x*p.y-q.y*p.x,iw=-q.x*p.x-q.y*p.y-q.z*p.z;return {x:ix*q.w-iw*q.x-iy*q.z+iz*q.y,y:iy*q.w-iw*q.y-iz*q.x+ix*q.z,z:iz*q.w-iw*q.z-ix*q.y+iy*q.x};});}
function clear(s,ground){for(const p of offsets(s))assert(s.position.y+p.y>=ground(s.position.x+p.x,s.position.z+p.z)-.002,'rotated actual bounds stay above sampled ground');}
function finish(s,ground,now=13,maxQueries=32){let calls=0,iterations=0;for(;s.status==='flying'&&iterations<1500;iterations++){const before=JSON.stringify(s);let queries=0;const next=stepNpcBlastGround20(s,{now,maxQueries,groundHeight:(x,z)=>{queries++;return ground(x,z);}});assert.equal(JSON.stringify(s),before,'input state is immutable');assert.equal(next.queries,queries);assert(queries<=maxQueries);clear(next,ground);s=next;calls+=queries;if(!s.pendingSeconds&&s.status==='flying')break;}assert(iterations<1500);return {s,calls,iterations};}
test('rotated long part lands on real support, not an assumed sphere/centre',()=>{
 const ground=()=>0,{s}=finish(seed({quaternion:{x:0,y:0,z:Math.sin(Math.PI/4),w:Math.cos(Math.PI/4)},angularVelocity:{x:0,y:0,z:0},velocity:{x:0,y:0,z:0}}),ground);assert.equal(s.status,'settled');assert(Math.abs(s.position.y-.2)<.001);assert(s.radius>.65);clear(s,ground);
});
test('large elapsed does not skip descent; query cap retains debt and TTL is event-owned',()=>{
 const initial=seed(),one=stepNpcBlastGround20(initial,{now:14,groundHeight:()=>0});assert(one.queries<=32);assert(one.pendingSeconds>3);assert(one.position.y>1);const {s,iterations}=finish(one,()=>0,14);assert.equal(s.status,'settled');assert(iterations>1);const expired=stepNpcBlastGround20(initial,{now:18,groundHeight:()=>{throw Error('expired must not query');}});assert.equal(expired.status,'expired');assert.equal(expired.queries,0);assert.equal(expired.elapsed,0);
});
test('sloped and elevated floors keep every rotated support corner clear',()=>{
 for(const floor of [(x,z)=>.15*x+.07*z,()=>6]){const elevated=floor(0,0),{s}=finish(seed({position:{x:0,y:2+elevated,z:0}}),floor);assert.equal(s.status,'settled');assert(s.position.y>elevated);clear(s,floor);}
});
test('sampled step stops on last safe segment rather than lifting onto a roof',()=>{
 const floor=x=>x<.5?0:7,initial=seed({position:{x:0,y:1,z:0},velocity:{x:5,y:0,z:0},angularVelocity:{x:0,y:0,z:0}}),{s}=finish(initial,floor);assert.equal(s.status,'settled');assert(s.position.y<=initial.position.y);assert(s.position.x<.5);clear(s,floor);
 const airborne=stepNpcBlastGround20(seed(),{now:10.1,groundHeight:()=>0});const blocked=stepNpcBlastGround20(airborne,{now:10.2,groundHeight:()=>20});assert.equal(blocked.status,'blocked');assert.deepEqual(blocked.position,airborne.position);assert.deepEqual(blocked.quaternion,airborne.quaternion);
});
test('continuation rechecks current terrain and never tunnels after query budget exhaustion',()=>{
 let s=seed({velocity:{x:0,y:-12,z:0}});s=stepNpcBlastGround20(s,{now:11,groundHeight:()=>0,maxQueries:18});assert(s.pendingSeconds>0);const saved=JSON.stringify(s),blocked=stepNpcBlastGround20(s,{now:11,groundHeight:()=>NaN,maxQueries:9});assert.equal(blocked.status,'blocked');assert.equal(JSON.stringify(s),saved);assert.deepEqual(blocked.position,s.position);const {s:landed}=finish(s,()=>0,11,18);assert.equal(landed.status,'settled');clear(landed,()=>0);
});
test('ordinary and delayed delivery agree; settled state does no further terrain work',()=>{
 const ground=(x,z)=>.03*x-.02*z;let fine=seed();for(let i=1;i<=180&&fine.status==='flying';i++)fine=stepNpcBlastGround20(fine,{now:10+i/60,groundHeight:ground,maxQueries:192});const delayed=finish(seed(),ground,13,192).s;assert.equal(fine.status,'settled');assert.equal(delayed.status,'settled');assert(Math.hypot(fine.position.x-delayed.position.x,fine.position.y-delayed.position.y,fine.position.z-delayed.position.z)<.003);const still=stepNpcBlastGround20(fine,{now:14,groundHeight:()=>{throw Error('settled terrain work');}});assert.deepEqual(still.position,fine.position);assert.equal(still.queries,0);
});
test('argument validation rejects invalid transforms, backwards time and unbounded budgets',()=>{
 assert.throws(()=>seed({localBounds:{min:{x:2,y:0,z:0},max:{x:1,y:1,z:1}}}));assert.throws(()=>seed({lifetime:9}));assert.throws(()=>seed({quaternion:{x:0,y:0,z:0,w:0}}));for(const maxQueries of [0,8,193,Infinity])assert.throws(()=>stepNpcBlastGround20(seed(),{now:11,groundHeight:()=>0,maxQueries}));assert.throws(()=>stepNpcBlastGround20(seed(),{now:9,groundHeight:()=>0}));
});
test('twelve parts preserve per-call budgets, report actual support-query CPU',()=>{
 const samples=[];let total=0;for(let i=0;i<12;i++){const start=performance.now(),{s,calls}=finish(seed({position:{x:i,y:2+i*.02,z:1}}),(x,z)=>.01*x,13);samples.push(performance.now()-start);assert.equal(s.status,'settled');total+=calls;}samples.sort((a,b)=>a-b);console.log(JSON.stringify({parts:12,queries:total,p50WholeFlightMs:samples[6],p95WholeFlightMs:samples[11],limits:'Synthetic sampled heightfields; no arbitrary heightfield/thin-wall guarantee, GPU or LIVE measurements'}));
});
test('actual male/female GLB region bounds settle under rotation on sloped elevated ground',async()=>{
 const fs=await import('node:fs'),{registerHooks}=await import('node:module'),{pathToFileURL}=await import('node:url');
 const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
 const hooks=registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c);}});
 const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
 const regionOf=name=>/head|neck/.test(name)?1:/upperarm_l|forearm_l|hand_l|clavicle_l/.test(name)?2:/upperarm_r|forearm_r|hand_r|clavicle_r/.test(name)?3:/thigh_l|shin_l|foot_l/.test(name)?4:/thigh_r|shin_r|foot_r/.test(name)?5:0;
 const reports=[];
 try{for(const sex of ['male','female']){
  const url=new URL('./hero_models/',import.meta.url),file=fs.readdirSync(url).find(name=>name.startsWith('player_'+sex+'.')&&name.endsWith('.glb'));assert(file);
  const bytes=fs.readFileSync(new URL(file,url)),model=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;model.updateMatrixWorld(true);
  const boxes=Array.from({length:6},()=>new THREE.Box3()),whole=new THREE.Box3(),p=new THREE.Vector3();
  model.traverse(mesh=>{
   if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const g=mesh.geometry,labels=mesh.skeleton.bones.map(b=>regionOf(b.name)),skin=g.attributes.skinIndex,weights=g.attributes.skinWeight,index=g.index,vertices=new Float64Array(g.attributes.position.count*3);
   for(let i=0;i<g.attributes.position.count;i++){mesh.getVertexPosition(i,p).applyMatrix4(mesh.matrixWorld);p.toArray(vertices,i*3);whole.expandByPoint(p);}
   const scores=new Float64Array(6);for(let i=0;i<(index?.count??g.attributes.position.count);i+=3){scores.fill(0);const tri=[0,1,2].map(j=>index?index.getX(i+j):i+j);for(const v of tri)for(let j=0;j<4;j++)scores[labels[skin.getComponent(v,j)]??0]+=weights.getComponent(v,j);let best=0;for(let r=1;r<6;r++)if(scores[r]>scores[best])best=r;for(const v of tri)boxes[best].expandByPoint(p.fromArray(vertices,v*3));}
  });
  const scale=1.9/whole.getSize(new THREE.Vector3()).y;
  for(const [region,box]of boxes.entries()){assert(!box.isEmpty());const center=box.getCenter(new THREE.Vector3()),min=box.min.clone().sub(center).multiplyScalar(scale),max=box.max.clone().sub(center).multiplyScalar(scale),ground=(x,z)=>3+.08*x-.04*z;
   const {s}=finish(seed({position:{x:0,y:5,z:0},localBounds:{min,max},quaternion:{x:.2,y:.3,z:.1,w:.9}}),ground);assert.equal(s.status,'settled');clear(s,ground);reports.push({sex,region,boundsMetres:box.getSize(new THREE.Vector3()).multiplyScalar(scale).toArray().map(v=>+v.toFixed(3)),supportY:+s.position.y.toFixed(4)});}
  model.traverse(mesh=>{mesh.geometry?.dispose();if(mesh.material)(Array.isArray(mesh.material)?mesh.material:[mesh.material]).forEach(m=>m.dispose());});
 }}finally{hooks.deregister();}
 assert.equal(reports.length,12);console.log(JSON.stringify({actualGlbBounds:reports}));
});
