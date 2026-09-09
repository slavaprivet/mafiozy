import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {createHeroPosture} from './hero_posture.mjs';
import {createSurfaceMotion} from './surface_motion.mjs';
import {createGrassTuftGeometry,grassDeformVertex,GRASS_CONTACT} from './environment_grass.mjs';
import {createGrassActorContact} from './grass_actor_contact.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(path.join(deps,'build/three.module.js')).href:specifier,context);}});
const THREE=await import(pathToFileURL(path.join(deps,'build/three.module.js'))),{GLTFLoader}=await import(pathToFileURL(path.join(deps,'addons/loaders/GLTFLoader.js')));
const female=process.argv.includes('--female'),bytes=fs.readFileSync(path.join(here,female?'hero_models/player_female.298d50e6244a.glb':'hero_models/player_male.8130dfb1f7eb.glb')),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const hero=createHeroWalker({THREE,scene:gltf.scene}),meshes=[];
const slope=Number(process.argv.find(a=>a.startsWith('--slope='))?.split('=')[1]||0),axis=process.argv.includes('--slope-z')?'z':'x',quick=process.argv.includes('--quick');
const floorAt=(x,z)=>slope*(axis==='x'?x:z),surfaceMotion=createSurfaceMotion();
surfaceMotion.reset({x:-.1,y:floorAt(-.1,-.1),z:-.1});
const support=surfaceMotion.update({x:0,z:0,dt:.025,floorHeight:floorAt});assert.equal(support.blocked,false);hero.object.position.y=support.y;
hero.object.updateMatrixWorld(true);
const contactSampler=createGrassActorContact({THREE,hero,getGroundHeight:floorAt});
const posedVertices=mesh=>{if(mesh.isSkinnedMesh)mesh.skeleton.update();return Array.from({length:mesh.geometry.attributes.position.count},(_,i)=>{const p=new THREE.Vector3().fromBufferAttribute(mesh.geometry.attributes.position,i);if(mesh.isSkinnedMesh)mesh.applyBoneTransform(i,p);return p.applyMatrix4(mesh.matrixWorld)})};
// The actual boot surfaces belong to the HAIR material in this GLB. Select
// their complete indexed faces in the rest pose, then keep these face IDs
// while applying the real walker skeleton for each subsequent pose.
hero.object.traverse(mesh=>{if(!mesh.isMesh)return;const p=posedVertices(mesh),idx=mesh.geometry.index,faces=[];for(let i=0;i<idx.count;i+=3){const ids=[idx.getX(i),idx.getX(i+1),idx.getX(i+2)];if(ids.every(k=>p[k].y<.15))faces.push(ids)}if(faces.length)meshes.push({mesh,faces});});
assert.ok(meshes.length,'actual GLB boot faces required');
const ray=new THREE.Ray(),delta=new THREE.Vector3(),hit=new THREE.Vector3(),epsilon=1e-8;
// Roots are planted 15 mm below ground. Ignore intersections hidden by the
// opaque ground, including the few gait poses whose soles dip below it.
function edgeCrosses(a,b,tri){delta.subVectors(b,a);const length=delta.length();if(length<epsilon)return false;ray.set(a,delta.divideScalar(length));return ray.intersectTriangle(tri.a,tri.b,tri.c,false,hit)!==null&&hit.distanceTo(a)<=length+epsilon&&hit.y>floorAt(hit.x,hit.z)+.002;}
function surfacesCross(a,b){return edgeCrosses(a.a,a.b,b)||edgeCrosses(a.b,a.c,b)||edgeCrosses(a.c,a.a,b)||edgeCrosses(b.a,b.b,a)||edgeCrosses(b.b,b.c,a)||edgeCrosses(b.c,b.a,a);}
const geometries=['grass','reed'].map(style=>({style,g:createGrassTuftGeometry(THREE,style)})),summary=[],violations=[];
let checkedTufts=0,checkedTriangles=0,visiblePressedVertices=0,maxEnvelopeRatio=0;
for(let pose=0;pose<(quick?4:14);pose++){
  if(pose){for(let i=0;i<4;i++)hero.update(.025,true,pose>(quick?1:6));}
  hero.object.updateMatrixWorld(true);
  const shoes=[];for(const {mesh,faces} of meshes){const vertices=posedVertices(mesh);for(const ids of faces){const tri=new THREE.Triangle(...ids.map(k=>vertices[k]));shoes.push({tri,box:new THREE.Box3().setFromPoints([tri.a,tri.b,tri.c])})}}
  const shoeBounds=new THREE.Box3();for(const s of shoes)shoeBounds.union(s.box);
  const feet=contactSampler.update().actorFeet;
  summary.push({pose,bounds:{min:shoeBounds.min.toArray(),max:shoeBounds.max.toArray()}});
  let found=false;
  for(const {style,g} of geometries){if(found)break;
    const attr=g.attributes.position,idx=g.index;
    for(let r=0;r<=26&&!found;r+=quick?2:1)for(let angle=0;angle<24&&!found;angle+=quick?2:1)for(let yawIndex=0;yawIndex<(quick?4:8)&&!found;yawIndex++)for(const time of [0,.8,1.9,3.4])for(const height of [.23,.65,1.01]){
      const radius=r*.05,x=Math.sin(angle*Math.PI/12)*radius,z=Math.cos(angle*Math.PI/12)*radius,yaw=yawIndex*Math.PI/4,width=Number(process.argv.find(a=>a.startsWith('--width='))?.split('=')[1]||1.35),c=Math.cos(yaw),s=Math.sin(yaw),trail=[{x:0,z:0,time,radius:GRASS_CONTACT.radius}];
      const vertices=Array.from({length:attr.count},(_,i)=>{const u=attr.getX(i)*width,v=attr.getZ(i)*width,w=attr.getY(i),bx=g.attributes.grassBase.getX(i)*width,bz=g.attributes.grassBase.getY(i)*width,p=grassDeformVertex({vertex:{x:x+u*c+v*s,y:floorAt(x,z)-.015+w*height,z:z-u*s+v*c},root:{x,y:floorAt(x,z)-.015,z},base:{x:x+bx*c+bz*s,z:z-bx*s+bz*c},time,height,weight:w,progress:g.attributes.grassProgress.getX(i),trail,slopeX:axis==='x'?slope:0,slopeZ:axis==='z'?slope:0,feet});return new THREE.Vector3(p.x,p.y,p.z)});
      checkedTufts++;
      for(const p of vertices){maxEnvelopeRatio=Math.max(maxEnvelopeRatio,Math.hypot(p.x-x,p.z-z)/Math.max(.39*width+.78*height,.6));if(radius<.7&&p.y-floorAt(p.x,p.z)>.005)visiblePressedVertices++}
      const tuftBounds=new THREE.Box3().setFromPoints(vertices);if(!tuftBounds.intersectsBox(shoeBounds))continue;
      for(let k=0;k<idx.count&&!found;k+=3){const tri=new THREE.Triangle(vertices[idx.getX(k)],vertices[idx.getX(k+1)],vertices[idx.getX(k+2)]),box=new THREE.Box3().setFromPoints([tri.a,tri.b,tri.c]);if(!box.intersectsBox(shoeBounds))continue;checkedTriangles++;for(const shoe of shoes){if(box.intersectsBox(shoe.box)&&surfacesCross(tri,shoe.tri)){violations.push({pose,style,root:{x,z,radius},yaw,time,height,point:hit.toArray()});found=true;break}}}
    }
  }
}
hero.update(0,false,false,null,{}, {posture:createHeroPosture('prone')});
const proneContact=createGrassActorContact({THREE,hero,getGroundHeight:floorAt}).update();for(const foot of proneContact.actorFeet)assert.ok(foot.radius>.04&&foot.radius<.24,'lazy prone sampler must identify feet, not hands/head');
console.log(JSON.stringify({female,checkedTufts,checkedTriangles,visiblePressedVertices,maxEnvelopeRatio,bootFaces:meshes.reduce((n,m)=>n+m.faces.length,0),poses:summary.length,limits:{maximumBootRadius:Math.max(...summary.flatMap(p=>[Math.hypot(p.bounds.min[0],p.bounds.min[2]),Math.hypot(p.bounds.max[0],p.bounds.max[2])])),surfaceTolerance:.002,slope,axis,shrubsExcluded:true},violations}));
hero.dispose();for(const {g}of geometries)g.dispose();
assert.equal(violations.length,0,'actual solid grass triangles must not cross animated GLB boot surfaces');
assert.ok(visiblePressedVertices>1000,'pressed grass must remain visibly above terrain');
assert.ok(maxEnvelopeRatio<=1.001,'foot egress must respect existing placement/culling envelopes');
