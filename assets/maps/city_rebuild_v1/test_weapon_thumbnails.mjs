import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';
import {frameWeaponThumbnail,createWeaponThumbnailRenderer,createWeaponFistModel} from './weapon_thumbnails.mjs';
const THREE=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
let models=0;
for(const spec of ARSENAL){
 const model=spec.id==='none'?createWeaponFistModel(THREE):createWeaponModel({THREE,id:spec.id}),camera=frameWeaponThumbnail(THREE,model,2),bounds=new THREE.Box3().setFromObject(model);
 for(const x of [bounds.min.x,bounds.max.x])for(const y of [bounds.min.y,bounds.max.y])for(const z of [bounds.min.z,bounds.max.z]){
  const projected=new THREE.Vector3(x,y,z).project(camera);assert(Math.abs(projected.x)<.87&&Math.abs(projected.y)<.87,`${spec.id} must fit with margin`);assert(projected.z>=-1&&projected.z<=1);
 }
 models++;
}
let contexts=0,renders=0,geometryDisposals=0,materialDisposals=0,rendererDisposed=0,lost=0;
class Renderer{
 constructor({canvas}){contexts++;this.domElement=canvas}
 setPixelRatio(){}setSize(){}setClearColor(){}
 render(scene){renders++;const model=scene.children.find(child=>child.weaponId);assert(model,'must render createWeaponModel prop');model.traverse(child=>{child.geometry?.addEventListener('dispose',()=>geometryDisposals++);child.material?.addEventListener('dispose',()=>materialDisposals++)})}
 dispose(){rendererDisposed++}forceContextLoss(){lost++}
}
const renderer=createWeaponThumbnailRenderer({THREE:{...THREE,WebGLRenderer:Renderer,PMREMGenerator:null},document:{createElement(){return {toDataURL(){return 'data:image/png;base64,model'}}}}});
assert.equal(contexts,0,'renderer initializes lazily');assert.match(renderer.render('none'),/^data:image\/png/);assert.equal(contexts,1);assert.equal(renders,1);
assert.match(renderer.render('ak74'),/^data:image\/png/);assert.equal(contexts,1);assert.equal(renders,2);assert(geometryDisposals>0&&materialDisposals>0,'temporary model GPU assets must be disposed');
renderer.render('ak74');assert.equal(renders,2);for(const spec of ARSENAL)renderer.render(spec.id);assert.equal(renders,15);assert.equal(contexts,1);assert.equal(renderer.size,15);
assert.equal(renderer.render('unknown'),null);renderer.dispose();renderer.dispose();assert.equal(rendererDisposed,1);assert.equal(lost,1);assert.equal(renderer.render('m16'),null);assert.equal(renderer.size,0);
const unavailable=createWeaponThumbnailRenderer();assert.equal(unavailable.render('ak74'),null);unavailable.dispose();
const fist=createWeaponFistModel(THREE);assert.equal(fist.userData.menuOnly,true);assert.equal(fist.userData.gesture,'clenched_fist');assert.equal(fist.children.filter(child=>child.name.endsWith('_knuckle')).length,4);for(const name of ['palm','wrist','thumb_base','thumb_wrap','thumb_tip'])assert(fist.getObjectByName(name));assert.equal(createWeaponModel({THREE,id:'none'}).children.length,0,'HUD fist must not replace the actual unarmed model or rig');
console.log(JSON.stringify({passed:true,models,checks:['all14_and_fist_camera_framing','same_factory','sculpted_fist','unarmed_game_model_unchanged','single_lazy_context','cache','resource_disposal','idempotent_dispose','no_webgl_fallback']}));
