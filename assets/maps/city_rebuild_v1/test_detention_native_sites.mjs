import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { registerHooks } from 'node:module';
import { pathToFileURL } from 'node:url';
import { DETENTION_NATIVE_MODEL, detentionDestination, detentionLocalToWorld, planDetentionNativeSites, createDetentionNativeEntry, detentionShellResourceStats } from './detention_native_sites.mjs';
import { createExplorationRailwayPlan } from './exploration_railway_plan.mjs';
import { interiorMeshPoolResourceStats } from './interior_mesh_pool.mjs';
import { createStableEntryLights } from './stable_entry_lights.mjs';
import { applyBuildingDoorsGlass } from './building_doors_glass.mjs';
import { isBreakableGlass, createGlassBreakage } from './glass_breakage.mjs';

const root=new URL('../../../',import.meta.url),read=p=>JSON.parse(fs.readFileSync(new URL(p,root)));
const topology=read('assets/maps/city_rebuild_v1/topology_for_placement.json'),placement=read('outputs/interiors_spacious/sizes_final_candidate/spacious_sizes.candidate.json'),decor=read('assets/maps/city_rebuild_v1/decor_placement.v1.json'),ledger=read('docs/city-rebuild/rebuild-ledger.generated.json'),rail=createExplorationRailwayPlan({topology});
const plan=planDetentionNativeSites({topology,placement,decor,ledger,rail});
const vendor=process.env.MAFIOZY_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const bytes=fs.readFileSync(new URL(DETENTION_NATIVE_MODEL.url.slice(1),root)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
function fixture(instance=plan.instances[0]){const parent=new T.Group();parent.position.fromArray(instance.transform.positionM);parent.rotation.y=instance.transform.yawDegrees*Math.PI/180;parent.scale.setScalar(instance.transform.uniformScale);const visual=source.clone(true),doorsGlass=applyBuildingDoorsGlass(visual,instance);parent.add(visual);parent.updateMatrixWorld(true);const before=[];visual.traverse(n=>{if(n.isMesh)before.push({node:n,geometry:n.geometry,visible:n.visible,material:n.material,parent:n.parent,matrix:n.matrix.clone()})});const entry=createDetentionNativeEntry({THREE:T,visual,instance});return{parent,visual,entry,instance,before,doorsGlass};}
const intersects=(a,b)=>a.minC<b.maxC-1e-6&&a.maxC>b.minC+1e-6&&a.minR<b.maxR-1e-6&&a.maxR>b.minR+1e-6;
const step=entry=>{for(let i=0;i<10;i++)entry.update(.15)};

test('three deterministic district branches preserve final75, protected anchors, decor, rail and real road stopping space',()=>{
  assert.equal(plan.instances.length,3);assert.equal(new Set(plan.instances.map(i=>i.districtId)).size,3);
  assert.deepEqual(plan,planDetentionNativeSites({topology,placement,decor,ledger,rail}));
  const before=JSON.stringify(placement);
  for(const site of plan.instances){
    for(const other of placement.instances)assert.ok(!intersects(site.footprint,other.clearance||other.footprint),other.id);
    for(const other of placement.protectedRects)assert.ok(!intersects(site.footprint,other),other.id);
    for(const [bounds,onRoad]of[[site.footprint,false],[site.entryCorridor,false],[site.stopFootprint,true],[site.stopLane,true]]){
      for(let r=Math.floor(bounds.minR+1e-6);r<Math.ceil(bounds.maxR-1e-6);r++)for(let c=Math.floor(bounds.minC+1e-6);c<Math.ceil(bounds.maxC-1e-6);c++){
        assert.equal(!!topology.protectedMask[r][c],false);assert.equal(!!topology.policeMask[r][c],false);assert.equal(!!topology.roadMask[r][c],onRoad);assert.ok(onRoad?topology.grid[r][c]===0:[8,9].includes(topology.grid[r][c]));
      }
    }
    assert.equal(rail.blocksPlacement(...[site.transform.positionM[0],site.transform.positionM[2]],Math.hypot(15,10.8)*.8),false);
    assert.equal(site.collision.worldBodies.length,5);
    for(const body of site.collision.worldBodies){assert.equal(body.carOnly,true);assert.ok(Number.isFinite(body.minYM)&&body.maxYM>body.minYM);assert.ok(body.polygonCR.flat().every(Number.isFinite));assert.equal(intersects(body.rectangleRC,site.stopFootprint),false);}
    const d=detentionDestination(site);assert.equal(d.nativeReady,false);assert.equal(d.instanceId,site.id);assert.ok(Math.abs(d.stop.angle-(Math.PI/2-(site.transform.yawDegrees-90)*Math.PI/180))<1e-7);
    const p=detentionLocalToWorld(site,-5.1,3.5);assert.ok(Math.abs(d.intake.r*4.1-p.z)<1e-7&&Math.abs(d.intake.c*4.1-p.x)<1e-7);
  }
  assert.equal(JSON.stringify(placement),before);assert.equal(plan.livePlacementWritten,false);assert.equal(plan.liveRegistryWritten,false);
});

test('merged static geometry preserves every source vertex, normal, triangle and material',()=>{
  const f=fixture(),{entry,visual}=f,inverse=visual.matrixWorld.clone().invert();let comparedVertices=0,comparedTriangles=0,draws=0;
  for(const mesh of entry.root.children.filter(n=>n.name.startsWith('Detention_Shell_Batch_'))){
    draws++;let vertexOffset=0,indexOffset=0;
    for(const name of mesh.userData.sourceNodeNames){
      const source=visual.getObjectByName(name),g=source.geometry,toLocal=inverse.clone().multiply(source.matrixWorld),normalMatrix=new T.Matrix3().getNormalMatrix(toLocal);
      assert.equal(mesh.material,source.material);assert.equal(source.visible,false);
      for(let i=0;i<g.attributes.position.count;i++){
        const want=new T.Vector3().fromBufferAttribute(g.attributes.position,i).applyMatrix4(toLocal),actual=new T.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,vertexOffset+i);assert.ok(want.distanceTo(actual)<2e-5,name+' position');
        if(g.attributes.normal){const expected=new T.Vector3().fromBufferAttribute(g.attributes.normal,i).applyMatrix3(normalMatrix).normalize(),normal=new T.Vector3().fromBufferAttribute(mesh.geometry.attributes.normal,vertexOffset+i);assert.ok(expected.distanceTo(normal)<2e-5,name+' normal');}
        if(g.attributes.uv)for(let k=0;k<2;k++)assert.equal(mesh.geometry.attributes.uv.array[(vertexOffset+i)*2+k],g.attributes.uv.array[i*2+k]);
        comparedVertices++;
      }
      const count=g.index?.count??g.attributes.position.count;for(let i=0;i<count;i++)assert.equal(mesh.geometry.index.array[indexOffset+i],vertexOffset+(g.index?g.index.array[i]:i),name+' topology');
      comparedTriangles+=count/3;indexOffset+=count;vertexOffset+=g.attributes.position.count;
    }
    assert.equal(indexOffset,mesh.geometry.index.count);assert.equal(vertexOffset,mesh.geometry.attributes.position.count);
  }
  assert.equal(draws,12);assert.ok(comparedVertices>5000);assert.equal(comparedTriangles,8371);assert.equal(entry.staticBatchStats.beforeTriangles,entry.staticBatchStats.afterTriangles);
  f.entry.dispose();
});

test('native entry has the walk contract and a physical doorway/gate that cannot close through a character',()=>{
  const f=fixture(),e=f.entry;assert.equal(e.instance,f.instance);assert.equal(e.visual,f.visual);assert.equal(e.object,e.root);assert.equal(e.contentRoot,e.root);assert.ok(e.sampleBounds.isBox3);
  assert.ok(e.report.room.width>=8&&e.report.room.height>=2.4);assert.ok(e.report.openingWidth>=1.2);assert.equal(e.containsInterior(e.roomPoint()),true);assert.equal(e.containsInterior(e.approachPoint()),false);assert.ok(e.sampleBounds.containsPoint(e.roomCenterPoint()));
  for(const localPoint of [new T.Vector3(-5.1,.33,3.5),new T.Vector3(-1.1,.33,-2.2),new T.Vector3(-5.1,.33,7.4)]){
    const point=f.visual.localToWorld(localPoint),floor=e.floorHeight(point.x,point.z),ceiling=e.ceilingHeight(point);assert.equal(e.containsInterior(point),true);assert.equal(e.containsInterior(point.clone().setY(floor-.04)),false);assert.equal(e.containsInterior(point.clone().setY(ceiling+1)),false);assert.equal(e.containsInterior(point.clone().setY((floor+ceiling)/2)),true);
  }
  assert.equal(e.needsUpdate,false);assert.ok(e.interact(e.approachPoint()).accepted);assert.equal(e.needsUpdate,true);step(e);assert.equal(e.needsUpdate,false);assert.equal(e.report.openFraction,1);
  const sweep=f.visual.localToWorld(new T.Vector3(-5.1,.33,7.4));e.setEntranceOpen(false);e.update(.15,sweep);assert.equal(e.doors[0].target,1);assert.equal(e.report.openFraction,1);assert.equal(e.interact(sweep).reason,'door-sweep-occupied');
  e.setGateOpen(true);step(e);const before=e.getCollisionBodies();assert.equal(e.getCollisionBodies(),before);e.setGateOpen(false);e.update(.15);assert.notEqual(e.getCollisionBodies(),before);assert.equal(e.needsUpdate,true);step(e);assert.equal(e.doors[1].fraction,0);
  assert.throws(()=>e.update(-1),RangeError);assert.equal(e.floorHeight(-5000,-5000),null);assert.equal(e.ceilingHeight({x:-5000,z:-5000}),null);
  e.dispose();
});

test('intake and cell sources join the existing fixed 32-slot light pool',()=>{
  const f=fixture(),scene=new T.Scene();scene.add(f.parent);assert.equal(f.entry.lightSources.length,2);
  for(const source of f.entry.lightSources){assert.equal(source.parent,f.entry.object);assert.equal(source.isPointLight,true);assert.equal(source.castShadow,false);assert.ok(source.intensity>0&&source.distance>=8);assert.equal(f.entry.containsInterior(source.getWorldPosition(new T.Vector3())),true);}
  const far=new T.Group();far.position.set(-10000,0,-10000);for(let i=0;i<35;i++){const light=new T.PointLight('#ffffff',8,9,2);light.position.set(i,3,0);far.add(light);}scene.add(far);
  const stable=createStableEntryLights(T,[f.entry,{object:far}],scene,{maxLights:32,getFocus:()=>f.entry.roomPoint()});assert.equal(stable.stats().sourceLights,37);assert.equal(stable.stats().fixedLights,32);
  for(const source of f.entry.lightSources){assert.equal(source.layers.mask,0);assert.ok(scene.getObjectByName('Stable_Entry_Light_Slots').children.some(slot=>slot.userData.roomLightSource===source.uuid&&slot.intensity===source.intensity));}
  f.parent.visible=false;stable.update();assert.equal(stable.stats().visibleSources,35);f.parent.visible=true;stable.update();assert.equal(stable.stats().visibleSources,37);
  stable.dispose();for(const source of f.entry.lightSources)assert.equal(source.layers.mask,1);f.entry.dispose();
});

test('three clones share compiled shell and furniture resources, and teardown restores originals once',()=>{
  const fixtures=plan.instances.map(fixture);assert.deepEqual(detentionShellResourceStats(T),{entries:1,references:3,geometries:12});assert.equal(interiorMeshPoolResourceStats(T).references,6);
  for(const f of fixtures){assert.equal(f.entry.staticBatchStats.batchDraws,12);assert.equal(f.entry.furnitureStats.draws,2);}
  const shared=fixtures[0].entry.root.children.find(n=>n.name==='Detention_Shell_Batch_0').geometry;assert.equal(shared,fixtures[1].entry.root.children.find(n=>n.name==='Detention_Shell_Batch_0').geometry);let disposed=0;shared.addEventListener('dispose',()=>disposed++);
  for(const[index,f]of fixtures.entries()){
    f.entry.dispose();f.entry.dispose();assert.equal(disposed,index===2?1:0);assert.equal(f.visual.getObjectByName('Detention_Native_'+f.instance.id),undefined);
    for(const state of f.before){assert.equal(state.node.geometry,state.geometry);assert.equal(state.node.material,state.material);assert.equal(state.node.visible,state.visible);assert.equal(state.node.parent,state.parent);state.node.updateMatrix();assert.ok(state.node.matrix.elements.every((v,i)=>Math.abs(v-state.matrix.elements[i])<1e-8));}
  }
  assert.deepEqual(detentionShellResourceStats(T),{entries:0,references:0,geometries:0});assert.deepEqual(interiorMeshPoolResourceStats(T),{references:0,geometries:0,materials:0});
});

test('opaque and transparent breakable panes remain individual after the real doors/glass pipeline',()=>{
  const a=fixture(),b=fixture(plan.instances[1]),scene=new T.Scene();scene.add(a.parent,b.parent);const glass=createGlassBreakage(T,scene,{maxShards:8,shardsPerHit:6}),batchNames=new Set();
  for(const mesh of a.entry.root.children.filter(n=>n.name.startsWith('Detention_Shell_Batch_'))){assert.equal(isBreakableGlass(mesh,mesh.material),false);for(const name of mesh.userData.sourceNodeNames)batchNames.add(name);}
  let breakable=0;for(const state of a.before)if(isBreakableGlass(state.node,state.node.material)){assert.equal(batchNames.has(state.node.name),false);breakable++;}
  assert.equal(breakable,97);assert.equal(a.entry.staticBatchStats.excludedBreakableMeshes,94);assert.equal(a.doorsGlass.report.status,'not-profiled');
  assert.equal(glass.prepare(a.visual),97);glass.prepare(b.visual);
  const target=a.visual.getObjectByName('Public_Single_Glass'),sibling=b.visual.getObjectByName('Public_Single_Glass'),other=a.visual.getObjectByName('Front_Window_Glass');assert.equal(target.material.transparent,false);assert.equal(target.visible,true);assert.equal(other.visible,true);
  const original=target.geometry,siblingGeometry=sibling.geometry,otherGeometry=other.geometry,sourceIndex=original.index.array.slice(),otherIndex=otherGeometry.index.array.slice(),g=target.geometry,indices=[0,1,2].map(i=>g.index?g.index.getX(i):i),vertices=indices.map(i=>new T.Vector3().fromBufferAttribute(g.attributes.position,i)),normal=vertices[1].clone().sub(vertices[0]).cross(vertices[2].clone().sub(vertices[0])).normalize(),point=vertices[0].clone().add(vertices[1]).add(vertices[2]).multiplyScalar(1/3);target.localToWorld(point);
  const hit=glass.hit({object:target,point,faceIndex:0,face:{normal}},{impulse:15});assert.equal(hit.broken,true);assert.equal(hit.mesh,target);glass.update(.1);assert.notEqual(target.geometry,original);assert.ok(target.geometry.index.array.some((v,i)=>v!==sourceIndex[i]));
  assert.equal(sibling.geometry,siblingGeometry);assert.deepEqual(sibling.geometry.index.array,sourceIndex);assert.equal(other.geometry,otherGeometry);assert.deepEqual(other.geometry.index.array,otherIndex);assert.deepEqual(original.index.array,sourceIndex);assert.equal(glass.stats().brokenPanels,1);
  glass.dispose();assert.equal(target.geometry,original);a.entry.dispose();b.entry.dispose();a.doorsGlass.dispose();b.doorsGlass.dispose();
});
