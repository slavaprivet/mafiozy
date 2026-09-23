import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';

const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(vendor+'build/three.module.js').href:specifier,context)}});
const T=await import('three');
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const placements=JSON.parse(readFileSync(new URL('buildings_placement.v1.json',import.meta.url))).instances.filter(item=>item.assetId==='old_town_narrow_townhouse_v1');
assert.equal(placements.length,22);
const bytes=readFileSync(new URL('../../..'+placements[0].binding.url,import.meta.url));
const loader=new GLTFLoader().register(()=>({name:'Test_No_Image_Upload',loadTexture(){return Promise.resolve(new T.Texture())}}));
const template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
template.traverse(node=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;if(node.isMesh)node.castShadow=node.receiveShadow=true});

const windowNames=new Set(['ResidentialWindow_DeepRecess','ResidentialWindow_Frame_And_Interior']);
const dynamicName=/ResidentialWindow_DeepGlass|^(?:PublicDoor|ServiceDoor|DoorLeaf|Entry_Brass|Entry_Handle|Entry_Leaf|InteriorDoor)/;
const matrixKey=matrix=>matrix.elements.map(value=>Math.round(value*1e5)).join(',');
const collisionSnapshot=resources=>JSON.stringify(resources.map(resource=>resource.entry.getCollisionBodies()));

function sourceInstanceMatrices(source,rootInverse){
 const prefix=new T.Matrix4().multiplyMatrices(rootInverse,source.matrixWorld),local=new T.Matrix4(),world=new T.Matrix4(),result=[];
 for(let index=0;index<source.count;index++){source.getMatrixAt(index,local);result.push(world.multiplyMatrices(prefix,local).clone())}
 return result;
}

async function build(){
 const root=new T.Group(),instances=[],resources=[];
 for(const item of placements){
  const group=new T.Group(),visual=template.clone(true),transform=item.transform;
  visual.position.fromArray(transform.modelLocalOffsetM);group.position.fromArray(transform.positionM);group.rotation.y=transform.yawDegrees*Math.PI/180;group.scale.setScalar(transform.uniformScale);group.add(visual);group.userData.instance=item;root.add(group);
  const doors=applyBuildingDoorsGlass(visual,item),building=createWindowedBuildingEntry({THREE:T,visual,instance:item});resources.push({doors,...building});instances.push(group);
 }
 root.updateWorldMatrix(true,true);
 const candidates=[],dynamic=[];
 root.traverse(mesh=>{
  if(!mesh.isMesh)return;
  if(windowNames.has(mesh.name))candidates.push({mesh,material:mesh.material,geometry:mesh.geometry,parent:mesh.parent,matrixWorld:mesh.matrixWorld.clone(),castShadow:mesh.castShadow,receiveShadow:mesh.receiveShadow,layers:mesh.layers.mask,raycast:mesh.raycast,count:mesh.count});
  if(mesh.userData?.breakableGlass||dynamicName.test(mesh.name))dynamic.push({mesh,material:mesh.material,geometry:mesh.geometry,parent:mesh.parent,matrixWorld:mesh.matrixWorld.clone()});
 });
 assert.equal(candidates.length,88);assert.equal(candidates.reduce((sum,row)=>sum+row.count,0),4004);assert.equal(dynamic.length,286);
 return {root,instances,resources,candidates,dynamic,collision:collisionSnapshot(resources)};
}

{
 const fixture=await build(),rootInverse=fixture.root.matrixWorld.clone().invert(),expected=new Map();
 for(const row of fixture.candidates)for(const matrix of sourceInstanceMatrices(row.mesh,rootInverse)){const key=matrixKey(matrix),record=expected.get(key)||{count:0,name:row.mesh.name,material:row.mesh.material.name};record.count++;expected.set(key,record)}
 const passedMatrices=[],originalSetMatrixAt=T.BatchedMesh.prototype.setMatrixAt;T.BatchedMesh.prototype.setMatrixAt=function(id,matrix){passedMatrices.push({batch:this,id,matrix:matrix.clone(),key:matrixKey(matrix)});return originalSetMatrixAt.call(this,id,matrix)};
 const api=createStaticRenderBatches({THREE:T,root:fixture.root,instances:fixture.instances,multiDraw:true});T.BatchedMesh.prototype.setMatrixAt=originalSetMatrixAt;const stats=api.stats(),batches=fixture.root.children.filter(node=>node.userData.staticRenderBatch);
 assert.deepEqual([stats.batches,stats.members,stats.optimizationBatches,stats.optimizationMembers],[28,11640,16,7612]);
 assert.equal(stats.mode,'BatchedMesh');assert.equal(batches.length,28);assert(batches.every(batch=>batch.raycast(new T.Raycaster(),[])===undefined));
 for(const row of fixture.candidates){assert.equal(row.mesh.material.visible,false);assert.equal(row.mesh.geometry,row.geometry);assert.equal(row.mesh.parent,row.parent);assert.deepEqual(row.mesh.matrixWorld.elements,row.matrixWorld.elements);assert.equal(row.mesh.castShadow,row.castShadow);assert.equal(row.mesh.receiveShadow,row.receiveShadow);assert.equal(row.mesh.layers.mask,row.layers);assert.equal(row.mesh.raycast,row.raycast)}
 for(const row of fixture.dynamic){assert.equal(row.mesh.material,row.material);assert.equal(row.mesh.geometry,row.geometry);assert.equal(row.mesh.parent,row.parent);assert.deepEqual(row.mesh.matrixWorld.elements,row.matrixWorld.elements)}
 assert.equal(passedMatrices.length,stats.members);const passedCounts=new Map();for(const record of passedMatrices){passedCounts.set(record.key,(passedCounts.get(record.key)||0)+1);const actual=new T.Matrix4();record.batch.getMatrixAt(record.id,actual);for(let i=0;i<16;i++)assert(Math.abs(actual.elements[i]-record.matrix.elements[i])<1e-4,'BatchedMesh stores the exact supplied root-local transform')}
 for(const [key,record]of expected)assert((passedCounts.get(key)||0)>=record.count,`all ${record.count} ${record.name}/${record.material} transforms must be copied`);
 assert.equal(collisionSnapshot(fixture.resources),fixture.collision);

 const firstGroup=fixture.candidates[0].mesh.parent,groupMembers=fixture.candidates.filter(row=>row.mesh.parent===firstGroup).reduce((sum,row)=>sum+row.count,0),visibleBefore=api.stats().visible;
 firstGroup.visible=false;api.update();assert.equal(api.stats().visible,visibleBefore-groupMembers);firstGroup.visible=true;api.update();assert.equal(api.stats().visible,visibleBefore);
 api.setOptimizationEnabled(false);assert(fixture.candidates.every(row=>row.mesh.material===row.material));assert(fixture.dynamic.every(row=>row.mesh.material===row.material));
 api.setOptimizationEnabled(true);assert(fixture.candidates.every(row=>row.mesh.material.visible===false));

 const mutationGroup=fixture.candidates[0].mesh.parent,mutated=fixture.candidates.find(row=>row.mesh.parent===mutationGroup&&row.count>1),originalLocal=new T.Matrix4();mutated.mesh.getMatrixAt(0,originalLocal);
 mutationGroup.removeFromParent();api.update();assert(fixture.candidates.filter(row=>row.mesh.parent===mutationGroup).every(row=>row.mesh.material===row.material));
 const moved=originalLocal.clone();moved.elements[12]+=.25;mutated.mesh.setMatrixAt(0,moved);fixture.instances[0].add(mutationGroup);api.update();assert.equal(mutated.mesh.material,mutated.material,'mutated source fails open instead of reusing stale batch data');
 assert.equal(collisionSnapshot(fixture.resources),fixture.collision);
 api.dispose();for(const row of fixture.candidates)assert.equal(row.mesh.material,row.material);for(const row of fixture.dynamic)assert.equal(row.mesh.material,row.material);
 for(const resource of fixture.resources){resource.roomReveals?.dispose();resource.entry?.dispose();resource.windows?.dispose();resource.doors.dispose()}
}

{
 const fixture=await build(),api=createStaticRenderBatches({THREE:T,root:fixture.root,instances:fixture.instances,multiDraw:false}),stats=api.stats();
 assert.deepEqual([stats.batches,stats.members,stats.optimizationBatches,stats.optimizationMembers],[6,132,0,0]);assert.equal(stats.mode,'StaticRenderBatch_Zero');
 for(const row of fixture.candidates){assert.equal(row.mesh.material,row.material);assert.equal(row.mesh.geometry,row.geometry);assert.equal(row.mesh.parent,row.parent);assert.deepEqual(row.mesh.matrixWorld.elements,row.matrixWorld.elements);assert.equal(row.mesh.raycast,row.raycast)}
 assert.equal(collisionSnapshot(fixture.resources),fixture.collision);api.setOptimizationEnabled(false);api.setOptimizationEnabled(true);assert(fixture.candidates.every(row=>row.mesh.material===row.material));api.dispose();
 for(const resource of fixture.resources){resource.roomReveals?.dispose();resource.entry?.dispose();resource.windows?.dispose();resource.doors.dispose()}
}

function scopeProbe({assetId='old_town_narrow_townhouse_v1',sha256=placements[0].binding.sha256,lod=0,name='ResidentialWindow_Frame_And_Interior',materialName='Residential stone reveal',transparent=false,breakable=false,movingDoor=false,hidden=false,ordinary=false}={}){
 const root=new T.Group(),instances=[],geometry=new T.BoxGeometry(1,1,1),material=new T.MeshStandardMaterial({name:materialName,transparent,opacity:transparent?.5:1}),sources=[];
 for(let placement=0;placement<3;placement++){const group=new T.Group(),parent=new T.Group(),mesh=ordinary?new T.Mesh(geometry,material):new T.InstancedMesh(geometry,material,2);group.userData.instance={assetId,binding:{sha256,lod}};group.userData.movingDoor=movingDoor;parent.visible=!hidden;mesh.name=name;mesh.userData.worldBlastStaticBounds=true;mesh.userData.breakableGlass=breakable;if(mesh.isInstancedMesh){mesh.setMatrixAt(0,new T.Matrix4().makeTranslation(0,0,0));mesh.setMatrixAt(1,new T.Matrix4().makeTranslation(1,0,0))}parent.add(mesh);group.add(parent);group.position.x=placement*3;root.add(group);instances.push(group);sources.push(mesh)}
 const api=createStaticRenderBatches({THREE:T,root,instances,multiDraw:true}),admitted=sources.every(mesh=>mesh.material.visible===false);api.dispose();geometry.dispose();material.dispose();return admitted;
}
assert.equal(scopeProbe(),true);
for(const variant of [{sha256:'wrong'},{lod:1},{assetId:'garden_lane_house_v1'},{name:'ResidentialWindow_DeepGlass',materialName:'Residential DeepGlass',breakable:true},{materialName:'Wrong material'},{transparent:true},{movingDoor:true},{hidden:true},{ordinary:true}])assert.equal(scopeProbe(variant),false,`strict window-frame scope rejects ${JSON.stringify(variant)}`);

console.log('PASS actual old-town LOD0 window-frame batches: exact geometry/material/world matrices, shadows, layers, raycast, collision, visibility, mutation fail-open, A/B, dispose and fallback');
