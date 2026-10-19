// Independent CPU repros; no renderer/GPU and no candidate edits.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as T from 'file:///D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js';
import {createServiceSpawnVisibility23} from './service_pilot23_candidate/visibility.mjs';

const results=[];
function setup({orthographic=false,width=20,height=20,near=.05,wallZ=2,wallMaterial}={}){
 const scene=new T.Scene(),camera=orthographic?new T.OrthographicCamera(-2,2,3,-3,near,100):new T.PerspectiveCamera(60,1,near,100);
 camera.position.set(0,1.05,5);camera.lookAt(0,1.05,0);camera.updateMatrixWorld(true);
 const wall=new T.Mesh(new T.PlaneGeometry(width,height),wallMaterial||new T.MeshStandardMaterial({side:T.DoubleSide}));wall.position.set(0,1.05,wallZ);scene.add(wall);scene.updateMatrixWorld(true);
 const layout={spawn:{x:0,y:0,z:0}};
 const check=createServiceSpawnVisibility23({THREE:T,getCamera:()=>camera,getOccluders:()=>[wall],isCurrentSite:l=>l===layout,ready:()=>true});
 return {scene,camera,wall,layout,check,hidden:()=>check(layout,1000)};
}
function repro(name,run){const result=run();results.push({name,...result});console.log(JSON.stringify(results.at(-1)));}
repro('baseline full opaque rectangle',()=>{const s=setup();assert.equal(s.hidden(),true);return{hidden:true,expected:true};});
repro('orthographic camera side strips remain exposed',()=>{
 const s=setup({orthographic:true,width:1.5});const hidden=s.hidden();
 const ray=new T.Raycaster();ray.setFromCamera(new T.Vector2(.425,0),s.camera);const hits=ray.intersectObject(s.wall);
 // NDC x=.425 maps to world x=.85, inside birth box but outside wall halfwidth .75.
 assert.equal(hits.length,0);assert.ok(Math.abs(ray.ray.origin.x)<.9);
 return{hidden,expected:false,visibleWorldX:ray.ray.origin.x,wallHalfWidth:.75};
});
repro('camera near plane clips claimed occluder',()=>{
 const s=setup({near:4}),hidden=s.hidden(),view=s.wall.position.clone().applyMatrix4(s.camera.matrixWorldInverse);
 assert.ok(-view.z<s.camera.near);return{hidden,expected:false,wallDepth:-view.z,cameraNear:s.camera.near};
});
repro('wireframe material does not fill the wall',()=>{
 const s=setup({wallMaterial:new T.MeshStandardMaterial({side:T.DoubleSide,wireframe:true})});return{hidden:s.hidden(),expected:false,wireframe:s.wall.material.wireframe};
});
repro('adjacent triangle uses back-face-only material',()=>{
 const s=setup();s.wall.geometry.clearGroups();s.wall.geometry.addGroup(0,3,0);s.wall.geometry.addGroup(3,3,1);
 s.wall.material=[new T.MeshStandardMaterial({side:T.FrontSide}),new T.MeshStandardMaterial({side:T.BackSide})];
 const hidden=s.hidden(),ray=new T.Raycaster();ray.set(s.camera.position,new T.Vector3(.5,.5,0).sub(s.camera.position).normalize());
 // Prove an actual perspective camera ray to a point inside the birth box sees no wall.
 const hits=ray.intersectObject(s.wall);assert.equal(hits.length,0);
 return{hidden,expected:false,visibleBirthPoint:[.5,.5,0],hitCount:hits.length};
});
repro('additive material is not opaque',()=>{
 const s=setup({wallMaterial:new T.MeshStandardMaterial({side:T.DoubleSide,blending:T.AdditiveBlending,depthWrite:false})});return{hidden:s.hidden(),expected:false,blending:s.wall.material.blending,depthWrite:s.wall.material.depthWrite};
});
repro('ordinary layer mismatch denied',()=>{const s=setup();s.wall.layers.set(1);return{hidden:s.hidden(),expected:false};});
repro('hidden ancestor denied',()=>{const s=setup();s.scene.visible=false;return{hidden:s.hidden(),expected:false};});
repro('positive result is not cached across opacity mutation',()=>{const s=setup();assert.equal(s.hidden(),true);s.wall.material.transparent=true;return{hidden:s.check(s.layout,1001),expected:false};});
repro('NeverDepth material is rejected by depth test and cannot hide body',()=>{
 const s=setup({wallMaterial:new T.MeshStandardMaterial({side:T.DoubleSide,depthTest:true,depthFunc:T.NeverDepth})});return{hidden:s.hidden(),expected:false,depthFunc:s.wall.material.depthFunc};
});
repro('current transformed ancestor followed on next positive proof',()=>{
 const s=setup();assert.equal(s.hidden(),true);s.scene.position.x=100;return{hidden:s.check(s.layout,1001),expected:false};
});
repro('current camera position followed after positive proof',()=>{
 const s=setup();assert.equal(s.hidden(),true);s.camera.position.set(0,1.05,1.2);s.camera.lookAt(0,1.05,0);return{hidden:s.check(s.layout,1001),expected:false};
});
repro('denial throttle delays only denial and does not retain positive',()=>{
 const s=setup();s.wall.visible=false;assert.equal(s.hidden(),false);s.wall.visible=true;assert.equal(s.check(s.layout,1001),false);assert.equal(s.check(s.layout,1300),true);return{hidden:false,expected:false};
});
repro('current instance transform changes invalidate positive proof',()=>{
 const s=setup(),wall=new T.InstancedMesh(new T.PlaneGeometry(20,20),new T.MeshStandardMaterial({side:T.DoubleSide}),1);
 wall.setMatrixAt(0,new T.Matrix4().makeTranslation(0,1.05,2));s.scene.add(wall);s.scene.updateMatrixWorld(true);
 const check=createServiceSpawnVisibility23({THREE:T,getCamera:()=>s.camera,getOccluders:()=>[wall],isCurrentSite:()=>true,ready:()=>true});assert.equal(check(s.layout,1000),true);
 wall.setMatrixAt(0,new T.Matrix4().makeTranslation(100,1.05,2));return{hidden:check(s.layout,1001),expected:false};
});
repro('built-in displacement map moves rendered wall behind camera',()=>{
 const displacement=new T.DataTexture(new Float32Array([1]),1,1,T.RedFormat,T.FloatType);displacement.needsUpdate=true;
 const s=setup({wallMaterial:new T.MeshStandardMaterial({side:T.DoubleSide,displacementMap:displacement,displacementScale:100})});
 // Actual bundled Three shader: transformed += normalize(objectNormal) *
 // (texture2D(displacementMap,uv).x * displacementScale + displacementBias).
 // Plane normal is +Z, so the rendered wall goes from z=2 to z=102.
 const shaderWallZ=s.wall.position.z+100;assert.ok(shaderWallZ>s.camera.position.z);
 return{hidden:s.hidden(),expected:false,rawWallZ:s.wall.position.z,shaderWallZ,cameraZ:s.camera.position.z};
});
repro('instance morph texture moves rendered wall out of view',()=>{
 const s=setup(),geometry=new T.PlaneGeometry(20,20),positions=geometry.attributes.position.clone();
 for(let i=0;i<positions.count;i++)positions.setX(i,positions.getX(i)+100);geometry.morphAttributes.position=[positions];
 const material=new T.MeshStandardMaterial({side:T.DoubleSide}),wall=new T.InstancedMesh(geometry,material,1),morph=new T.Mesh(geometry,material);
 morph.morphTargetInfluences[0]=1;wall.setMorphAt(0,morph);wall.setMatrixAt(0,new T.Matrix4().makeTranslation(0,1.05,2));s.scene.add(wall);s.scene.updateMatrixWorld(true);
 const check=createServiceSpawnVisibility23({THREE:T,getCamera:()=>s.camera,getOccluders:()=>[wall],isCurrentSite:()=>true,ready:()=>true});
 return{hidden:check(s.layout,1000),expected:false,morphTexture:!!wall.morphTexture,meshInfluences:wall.morphTargetInfluences??null,shaderShiftX:100};
});
repro('negative-determinant instance front face differs from CPU raycast',()=>{
 const s=setup(),wall=new T.InstancedMesh(new T.PlaneGeometry(20,20),new T.MeshStandardMaterial({side:T.FrontSide}),1);
 wall.setMatrixAt(0,new T.Matrix4().makeScale(-1,1,1).setPosition(0,1.05,2));s.scene.add(wall);s.scene.updateMatrixWorld(true);
 const check=createServiceSpawnVisibility23({THREE:T,getCamera:()=>s.camera,getOccluders:()=>[wall],isCurrentSite:()=>true,ready:()=>true});
 // Actual WebGLRenderer frontFaceCW uses object.matrixWorld.determinant(),
 // not the individual instance determinant; one draw cannot flip per instance.
 assert.equal(wall.matrixWorld.determinant(),1);
 return{hidden:check(s.layout,1000),expected:false,objectDeterminant:1,instanceDeterminant:-1};
});
// Expose the exact existing geometric predicate only in this test's in-memory
// module. No source/module edits or alternate predicate implementation.
const visibilitySource=fs.readFileSync(new URL('./service_pilot23_candidate/visibility.mjs',import.meta.url),'utf8');
const instrumented=visibilitySource.replace('return function canSpawnHidden(layout,now){','return {convexPair};\n function canSpawnHidden(layout,now){');
assert.notEqual(instrumented,visibilitySource);
const probes=await import('data:text/javascript;base64,'+Buffer.from(instrumented).toString('base64'));
const {convexPair}=probes.createServiceSpawnVisibility23({THREE:T});
const point=(x,y,z=0)=>new T.Vector3(x,y,z),a=point(-1,-1),b=point(1,-1),c=point(1,1),d=point(-1,1);
assert.equal(convexPair([a,b,c],[a,c,d]),true,'ordinary planar rectangle');
assert.equal(convexPair([a,b,c],[a,b,d]),false,'same-side common edge does not enclose quad');
const dent=point(-.4,-.4);assert.equal(convexPair([a,b,dent],[a,dent,d]),false,'concave union cannot prove full convex coverage');
assert.equal(convexPair([a,b,c],[a,c,point(-1,1,.1)]),false,'folded noncoplanar pair');
assert.equal(convexPair([a,b,c],[point(3,3),point(4,3),point(4,4)]),false,'disconnected corner blockers');
assert.equal(convexPair([a,b,c],[d,c,a]),false,'opposite normals rejected');
console.log(JSON.stringify({convexPairChecks:6,passed:true}));
console.log(JSON.stringify({falsePositiveCases:results.filter(r=>r.hidden&&!r.expected).map(r=>r.name),results},null,2));

assert.deepEqual(results.filter(r=>r.hidden!==r.expected).map(r=>r.name),[],"all independent visibility cases match");
