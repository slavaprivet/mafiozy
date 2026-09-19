# Astra 1 — grass cell-index parity research

Research accepted against exact supplied source hashes. The diff below is not applied and was not run.

TASK_ID: `grass-cell-index-parity-20260919`  
MAIN_SHA: `3442bf0d84dd66e787005aa2bbb456caf298b9ca`  
SOURCE_SNAPSHOT_ID: `4a3e599dd600002edf3d7a9434d7a78acbfec9b9c0aa2be159622475bcb18612`  
Факт: текущий `chunksByRow` хранит массивы строк; прежний предложенный прямой X-поиск здесь отсутствует.  
Diff добавляет только регрессию: настоящий `update` против независимого полного обхода без индекса/heap; сравниваются глобальный и внутримешевый порядок ID, counts и fade.  
Отдельно проверяются отрицательные границы, shuffled insertion, равные дистанции, три бюджета и AABB-гало `widestTuftRadius`: одних выбранных ID для последнего недостаточно.  
Ограничения: корректные конечные данные, ограниченные синтетические диапазоны; используется существующий локальный Three. Код не применялся, тест не запускался, GPU/FPS не оценивались.  
Координатору: проверить применимость diff, выполнить новый тест и существующие selection/prefix-регрессии; production и прежние тесты не меняются.

```diff
diff --git a/assets/maps/city_rebuild_v1/test_grass_cell_index_parity.mjs b/assets/maps/city_rebuild_v1/test_grass_cell_index_parity.mjs
new file mode 100644
--- /dev/null
+++ b/assets/maps/city_rebuild_v1/test_grass_cell_index_parity.mjs
@@ -0,0 +1,174 @@
+import assert from 'node:assert/strict';
+import {pathToFileURL} from 'node:url';
+import {createEnvironmentGrass} from './environment_grass.mjs';
+import {GRASS_LIMITS} from './environment_grass_plan.mjs';
+
+// Uses the existing local vendor; no renderer, GL context or network is created.
+const vendor=process.env.THREE_MODULE_PATH||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js';
+const THREE=await import(pathToFileURL(vendor).href);
+const styles=['grass','reed','shrub'],cost={grass:84,reed:108,shrub:168};
+const boxValues=b=>[b.min.x,b.min.y,b.min.z,b.max.x,b.max.y,b.max.z];
+
+// Independent full Map traversal: no row index, range query or bounded heap.
+function fullChunks(tufts,chunkSize){
+ const chunks=new Map();
+ for(const t of tufts){
+  const key=Math.floor(t.x/chunkSize)+','+Math.floor(t.z/chunkSize);
+  if(!chunks.has(key))chunks.set(key,{key,box:new THREE.Box3(),byStyle:Object.fromEntries(styles.map(s=>[s,[]]))});
+  const c=chunks.get(key);c.byStyle[t.style].push(t);
+  const margin=t.radius*Math.hypot(t.slopeX||0,t.slopeZ||0);
+  c.box.expandByPoint(new THREE.Vector3(t.x-t.radius,t.y-.03-margin,t.z-t.radius));
+  c.box.expandByPoint(new THREE.Vector3(t.x+t.radius,t.y+t.height+.03+margin,t.z+t.radius));
+ }
+ return [...chunks.values()];
+}
+
+function reference(chunks,b,focus,camera){
+ const frustum=new THREE.Frustum();
+ if(camera)frustum.setFromProjectionMatrix(new THREE.Matrix4().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse));
+ const perMesh=new Map(),candidates=[],probes=[];
+ for(const c of chunks)for(const s of styles)if(c.byStyle[s].length)perMesh.set(c.key+'|'+s,[]);
+ for(const c of chunks){
+  const box=c.box;
+  const distance=Math.hypot(Math.max(box.min.x-focus.x,0,focus.x-box.max.x),Math.max(box.min.z-focus.z,0,focus.z-box.max.z));
+  if(distance>b.viewDistance)continue;
+  if(camera){const hit=frustum.intersectsBox(box);probes.push([...boxValues(box),hit]);if(!hit)continue;}
+  for(const s of styles)for(const t of c.byStyle[s]){
+   const d=Math.hypot(t.x-focus.x,t.z-focus.z);
+   if(d<b.viewDistance)candidates.push({id:t.id,key:c.key+'|'+s,n:cost[s],d,order:candidates.length});
+  }
+ }
+ candidates.sort((a,z)=>a.d-z.d||a.order-z.order);
+ const ids=[],batches=new Set();let triangles=0,cutoff=b.viewDistance,limited=false;
+ for(const c of candidates){
+  const fresh=!batches.has(c.key);
+  if(ids.length>=b.maxVisibleTufts||triangles+c.n>b.maxVisibleTriangles||(fresh&&batches.size>=b.maxVisibleBatches)){cutoff=c.d;limited=true;break;}
+  ids.push(c.id);perMesh.get(c.key).push(c.id);batches.add(c.key);triangles+=c.n;
+ }
+ const far=limited?Math.max(4,cutoff-.4):b.viewDistance;
+ return {ids,perMesh,probes,triangles,batches:batches.size,far,near:Math.min(b.fadeStart,far*.68)};
+}
+
+// Observe actual update order and post-distance AABB probes without changing selection.
+function run(name,tufts,limits,queries){
+ const selected=[],probes=[];
+ class ProbeFrustum extends THREE.Frustum{
+  intersectsBox(box){const hit=super.intersectsBox(box);probes.push([...boxValues(box),hit]);return hit;}
+ }
+ const grass=createEnvironmentGrass({THREE:{...THREE,Frustum:ProbeFrustum},plan:{stats:{},tufts},limits});
+ const budget={...GRASS_LIMITS,...limits},chunks=fullChunks(tufts,budget.chunkSize);
+ const meshes=[];
+ for(const group of grass.object.children){
+  for(const mesh of group.children){
+   const key=group.name.slice('GrassChunk_'.length)+'|'+mesh.name.slice('Grass_'.length),ids=mesh.userData.tuftIds;
+   assert.equal(mesh.geometry.index.count/3,cost[mesh.name.slice('Grass_'.length)],name+': triangle cost');
+   Object.defineProperty(ids,'push',{
+    value(...values){selected.push(...values);return Array.prototype.push.apply(this,values);}
+   });
+   meshes.push({key,mesh,group});
+  }
+ }
+ const outputs=[];
+ try{
+  for(const [step,q]of queries.entries()){
+   q.camera?.updateMatrixWorld();
+   const r=reference(chunks,budget,q.focus,q.camera);
+   selected.length=0;probes.length=0;
+   grass.update({...q,time:step+1,force:true});
+   assert.deepEqual(selected,r.ids,name+': global selection IDs/order');
+   assert.deepEqual(probes,r.probes,name+': full-scan AABB/frustum probe order');
+   assert.deepEqual(meshes.map(m=>m.key),[...r.perMesh.keys()],name+': construction order');
+   for(const {key,mesh,group}of meshes){
+    const want=r.perMesh.get(key);
+    assert.deepEqual(Array.from(mesh.userData.tuftIds),want,name+': per-mesh IDs/order '+key);
+    assert.equal(mesh.count,want.length,name+': mesh count '+key);
+    assert.equal(mesh.visible,want.length>0,name+': mesh visibility '+key);
+    if(want.length)assert.equal(group.visible,true,name+': active group visibility');
+   }
+   assert.deepEqual([grass.stats.visibleTufts,grass.stats.visibleTriangles,grass.stats.visibleBatches],
+    [r.ids.length,r.triangles,r.batches],name+': count/triangles/batches');
+   assert.deepEqual([grass.stats.fadeFar,grass.uniforms.uGrassFadeFar.value,grass.uniforms.uGrassFadeNear.value],[r.far,r.far,r.near],name+': fade');
+   outputs.push(r);
+  }
+ }finally{grass.dispose();}
+ return outputs;
+}
+
+function cameraAt(span,x=0,z=0){
+ const c=new THREE.OrthographicCamera(-span,span,span,-span,.1,1000);
+ c.position.set(x,300,z);c.up.set(0,0,-1);c.lookAt(x,0,z);
+ c.updateProjectionMatrix();c.updateMatrixWorld();return c;
+}
+const wide=cameraAt(1024);
+const query=(x,z,camera=wide)=>({focus:{x,z},camera});
+const tuft=(id,x,z,style='grass',radius=1)=>({id,x,z,y:0,height:.8,width:1,yaw:0,style,radius,color:0x70824c,slopeX:.03,slopeZ:-.02});
+function shuffle(a,seed){
+ const out=a.slice();
+ for(let i=out.length-1;i>0;i--){seed=(Math.imul(seed,1664525)+1013904223)>>>0;const j=seed%(i+1);[out[i],out[j]]=[out[j],out[i]];}
+ return out;
+}
+
+// Equal-distance ties follow chunk construction, then style/intra-style order.
+const tie=[
+ tuft('east-shrub',64,0,'shrub'),tuft('north',0,-64),
+ tuft('east-reed',64,0,'reed'),tuft('west',-64,0),
+ tuft('east-grass',64,0),tuft('south',0,64),tuft('east-later',65,0),
+];
+const roomy={maxVisibleTufts:2000,maxVisibleTriangles:1e6,maxVisibleBatches:100};
+const scenarios=[
+ ['tuft-cap',{...roomy,maxVisibleTufts:2},['east-grass','east-reed']],
+ ['triangle-stop',{...roomy,maxVisibleTriangles:300},['east-grass','east-reed']],
+ ['batch-stop',{...roomy,maxVisibleBatches:1},['east-grass']],
+];
+for(const [label,budget,want]of scenarios){
+ const [r]=run(label,tie,budget,[query(0,0)]);
+ assert.deepEqual(r.ids,want);
+ assert.equal(r.far,64-.4);
+ assert.equal(r.near,(64-.4)*.68);
+}
+// A later cheap/existing-batch candidate must not bypass the first budget stop.
+const [uncapped]=run('tie-unlimited',tie,roomy,[query(0,0)]);
+assert.deepEqual(uncapped.ids,['east-grass','east-reed','east-shrub','north','west','south','east-later']);
+
+// Halo chunks pass AABB distance despite roots outside R: IDs alone miss this regression.
+const halo=[
+ tuft('halo-x+',256,0,'grass',152),tuft('halo-x-',-257,0,'reed',153),
+ tuft('halo-z+',0,256,'shrub',152),tuft('halo-z-',0,-257,'grass',153),
+ tuft('near',1,1),
+];
+const [h]=run('widest-radius-halo',halo,roomy,[query(0,0)]);
+assert.equal(h.probes.length,5,'wide radii retain all five AABB probes');
+assert.deepEqual(h.ids,['near']);
+
+const e=2**-20,boundary=[];
+const xs=[-128-e,-128,-128+e,-105-e,-105,-105+e,-64-e,-64,-64+e,-e,0,e,64-e,64,64+e,105-e,105,105+e,128-e,128,128+e];
+for(const z of [-128,-64,-e,0,64,128])for(const x of xs)
+ boundary.push(tuft('edge-'+boundary.length,x,z,styles[boundary.length%3]));
+const visits=[query(0,0),query(-22-e,-22-e),query(-22,-22),query(-22+e,-22+e),
+ query(22-e,22-e),query(22,22),query(22+e,22+e),query(-64,64),
+ query(0,0,cameraAt(20,64,0)),query(1e4,1e4),query(0,0),query(0,0,null)];
+for(const seed of [1,23])for(const b of [roomy,{...roomy,maxVisibleTufts:7},{...roomy,maxVisibleTriangles:360},{...roomy,maxVisibleBatches:2}])
+ run('shuffled-edges-'+seed,shuffle(boundary,seed),b,visits);
+
+const [edge]=run('strict-root-distance',[
+ tuft('on-plus',105,0),tuft('on-minus',-105,0),tuft('inside-plus',105-e,0),
+ tuft('outside-minus',-105-e,0),tuft('inside-minus',-105+e,0),tuft('outside-plus',105+e,0)
+],roomy,[query(0,0)]);
+assert.deepEqual(edge.ids,['inside-plus','inside-minus']);
+
+// Finite small-cell and wide-sparse queries; no unbounded stress loops.
+const tiny=[tuft('tiny-a',-.25,0),tuft('tiny-b',-.25-e,0,'reed'),
+ tuft('tiny-c',-.25+e,-.25,'shrub'),tuft('tiny-d',e,e)];
+run('small-cells',tiny,{...roomy,chunkSize:.25,viewDistance:2,fadeStart:1},[
+ query(-.25,-.25),query(0,0),query(10,10),query(-.25,-.25)]);
+
+const spread=[];
+for(const z of [-128,0,128])for(const x of [-4096,-512,0,512,4096])
+ spread.push(tuft('wide-'+spread.length,x,z,styles[spread.length%3]));
+run('wide-sparse-rows',shuffle(spread,31),{...roomy,viewDistance:4096},[query(0,0,null)]);
+const dense=Array.from({length:1250},(_,i)=>tuft('dense-'+i,i%2?64:-64,i%4<2?0:64,styles[i%3]));
+const [d]=run('default-budget',shuffle(dense,91),{},[query(0,0)]);
+assert(d.ids.length<GRASS_LIMITS.maxVisibleTufts&&d.far<GRASS_LIMITS.viewDistance);
+const [empty]=run('empty-plan',[],{},[query(0,0)]);
+assert.deepEqual(empty.ids,[]);assert.equal(empty.far,GRASS_LIMITS.viewDistance);
+console.log('Grass cell-index/full-scan parity assertions completed (CPU only).');
```

