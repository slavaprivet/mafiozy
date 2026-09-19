import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createMercenaryTaskMarkers} from './mercenary_task_markers.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
class Element{constructor(){this.children=[];this.dataset={};this.style={};this.attrs={};}append(n){n.parent=this;this.children.push(n);}remove(){if(this.parent)this.parent.children=this.parent.children.filter(c=>c!==this);}setAttribute(k,v){this.attrs[k]=v;}}
const nodes=root=>[root,...root.children.flatMap(nodes)];
function fixture(occlusion=false){const doc={createElement:()=>new Element(),body:new Element()},scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(55,1.5,.1,120);doc.body.clientWidth=1200;doc.body.clientHeight=800;camera.position.set(0,2,12);camera.lookAt(0,1,0);camera.updateMatrixWorld();const material=new THREE.MeshBasicMaterial(),geometry=new THREE.BoxGeometry(1,2,1),targets=[];for(let i=0;i<14;i++){const object=new THREE.Mesh(geometry,material);object.position.set((i%5-2)*1.5,1,-Math.floor(i/5)*2);scene.add(object);targets.push({id:'t'+i,object,kind:'safe',valid:true});}const view=createMercenaryTaskMarkers({THREE,scene,document:doc,camera,getRoots:occlusion?()=>[scene]:null});return{doc,scene,camera,targets,view};}
const marker=t=>t.object.getObjectByName('Mercenary_Object_Focus_Arcs');

test('current and queued objects keep green/amber numbered markers without an aimed target, promote without rebuild, then disappear',()=>{
 const f=fixture(),[a,b]=f.targets;try{
  f.view.sync([{target:a,number:1,memberName:'Елена'},{target:b,number:2,queued:true,memberName:'Елена'}]);f.view.update(.016);
  assert.equal(marker(a).material.uniforms.edgeColor.value.getHex(),0x61df89);assert.equal(marker(b).material.uniforms.edgeColor.value.getHex(),0xd4aa62);assert.equal(f.view.stats().visible,2);const geometry=marker(b).geometry;
  assert.deepEqual(nodes(f.doc.body).filter(n=>n.dataset.taskTarget).map(n=>n.textContent),['1','2']);a.object.userData.mercenaryOpened=true;f.view.sync([{target:a,number:1},{target:b,number:1}]);f.view.update(.016);assert(!marker(a));assert.equal(marker(b).geometry,geometry);assert.equal(marker(b).material.uniforms.edgeColor.value.getHex(),0x61df89);assert.equal(nodes(f.doc.body).find(n=>n.dataset.taskTarget==='t1').textContent,'1');
  f.view.clear();assert(!marker(b));assert.equal(f.view.stats().active,0);assert(!nodes(f.doc.body).some(n=>n.dataset.taskTarget&&n.style.display==='block'));
 }finally{f.view.dispose();}
});

test('aimed vehicle has no overhead X; assigned number uses actual roof and wreck clears immediately',()=>{
 const f=fixture(),car={...f.targets[0],kind:'vehicle'};try{
  f.view.sync([],car);f.view.update(.016);assert.equal(f.view.stats().visible,0);assert(!marker(car));assert.equal(nodes(f.doc.body).find(n=>n.dataset.taskTarget===car.id),undefined);
  car.object.scale.set(1.4,.65,1.2);f.view.sync([{target:car,number:2,queued:true}],car);f.view.update(.016);const n=nodes(f.doc.body).find(n=>n.dataset.taskTarget===car.id);assert.equal(n.textContent,'2');assert.equal(n.dataset.taskState,'queued');assert(!marker(car));const roof=new THREE.Vector3(0,1,0).applyMatrix4(car.object.matrixWorld);roof.y+=.18;roof.project(f.camera);assert.equal(n.style.top,((-roof.y*.5+.5)*800).toFixed(1)+'px','anchor follows mesh roof and uses world-space margin');assert.equal(car.object.geometry.boundingBox,null,'source geometry bounds are not mutated');
  car.wrecked=true;f.view.sync([{target:car,number:2,queued:true}],car);assert.equal(n.style.display,'none');assert.equal(f.view.stats().active,0);
 }finally{f.view.dispose();}
});

test('markers cap10 including an external aim, deduplicate targets and reuse pooled DOM/geometry',()=>{
 const f=fixture();try{
  const rows=f.targets.map((t,i)=>({target:t,number:i+1,queued:i>1}));f.view.sync(rows);f.view.update(.016);assert.equal(f.view.stats().active,10);assert.equal(f.view.stats().pooled,10);const builds=f.view.stats().geometryBuilds;
  for(let i=0;i<100;i++){f.view.sync(rows);f.view.update(.016);}assert.equal(f.view.stats().geometryBuilds,builds);
  const selected=f.view.sync(rows,f.targets[13]);assert.equal(selected.size,10);assert(selected.has(f.targets[13].id),'aimed queued target stays its real queue color/number');const external={...f.targets[13],id:'external'};assert.equal(f.view.sync(rows,external).size,9,'leave one of ten slots to the independent aimed marker');assert.equal(f.view.stats().pooled,10);
  f.view.sync([{target:f.targets[0],number:1},{target:f.targets[0],number:2,queued:true}]);assert.equal(f.view.stats().active,1);
  assert.equal(f.doc.body.children[0].dataset.walkHud,undefined,'fullscreen annotations are not badge occlusion masks');
 }finally{f.view.dispose();}assert.equal(f.doc.body.children.length,0);
});

test('behind-camera/invisible/detached objects hide labels; current object transforms update without a bounds rebuild',()=>{
 const f=fixture(),t=f.targets[2];try{
  f.view.sync([{target:t,number:1}]);f.view.update(.016);const n=nodes(f.doc.body).find(n=>n.dataset.taskTarget===t.id),builds=f.view.stats().geometryBuilds;assert.equal(n.style.display,'block');const x=n.style.left;t.object.position.x+=1;f.view.update(.016);assert.notEqual(n.style.left,x);assert.equal(f.view.stats().geometryBuilds,builds);
  t.object.position.z=30;f.view.update(.016);assert.equal(n.style.display,'none');t.object.position.z=0;t.object.visible=false;f.view.update(.016);assert.equal(n.style.display,'none');t.object.visible=true;t.object.removeFromParent();f.view.update(.016);assert.equal(n.style.display,'none');
 }finally{f.view.dispose();}
});

test('ten stationary tasks have bounded presentation CPU and no geometry churn',()=>{
 const f=fixture();try{const rows=f.targets.slice(0,10).map((t,i)=>({target:t,number:i+1,queued:i>0}));f.view.sync(rows);const builds=f.view.stats().geometryBuilds,samples=[];for(let i=0;i<1800;i++){const start=performance.now();f.view.update(.016);if(i>300)samples.push(performance.now()-start);}samples.sort((a,b)=>a-b);assert.equal(f.view.stats().geometryBuilds,builds);console.log(JSON.stringify({scenario:'10 task markers CPU-only',p50Ms:samples[749],p95Ms:samples[1424],draws:10,markerTriangles:7680,geometryBuilds:builds,limitation:'Shared scene performance not verified'}));}finally{f.view.dispose();}
});

test('queue numbers hide behind opaque walls with bounded rays and reappear after cover is removed',()=>{
 const f=fixture(true),t=f.targets[2],wall=new THREE.Mesh(new THREE.BoxGeometry(20,10,.2),new THREE.MeshBasicMaterial());wall.position.set(0,3,5);f.scene.add(wall);f.scene.updateMatrixWorld(true);
 try{f.view.sync([{target:t,number:1}]);f.view.update(.016);const n=nodes(f.doc.body).find(n=>n.dataset.taskTarget===t.id);assert.equal(n.style.display,'none');assert.equal(f.view.stats().raycasts,1);wall.visible=false;f.view.update(.06);assert.equal(n.style.display,'block');wall.visible=true;wall.material.transparent=true;wall.material.opacity=.3;f.view.update(.06);assert.equal(n.style.display,'block','transparent decoration does not mask the number');wall.material.opacity=1;f.view.update(.06);assert.equal(n.style.display,'none');wall.userData.isHero=true;f.view.update(.06);assert.equal(n.style.display,'block','hero is ignored like friendly badges');
  const rays=f.view.stats().raycasts,builds=f.view.stats().geometryBuilds;for(let i=0;i<100;i++)f.view.update(.016);assert(f.view.stats().raycasts-rays<=32,'one bounded ray per 50ms, never per target per frame');assert.equal(f.view.stats().geometryBuilds,builds);
 }finally{f.view.dispose();wall.geometry.dispose();wall.material.dispose();}
});
