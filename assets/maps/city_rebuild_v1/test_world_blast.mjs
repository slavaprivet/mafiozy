import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createGlassBreakage} from './glass_breakage.mjs';
import {applyWorldBlast} from './world_blast.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const scene=new T.Scene(),root=new T.Group();scene.add(root);const material=new T.MeshStandardMaterial({name:'Window_Glass',transparent:true,opacity:.4,side:T.DoubleSide});
const one=new T.PlaneGeometry(1,1).toNonIndexed(),positions=[];for(const x of [0,20]){const p=one.attributes.position;for(let i=0;i<p.count;i++)positions.push(p.getX(i)+x,p.getY(i),p.getZ(i)+2)}
const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(positions,3));geo.computeVertexNormals();const merged=new T.Mesh(geo,material);root.add(merged);
const instances=new T.InstancedMesh(new T.PlaneGeometry(1,1),material,3);for(const [i,x]of [1,2,20].entries())instances.setMatrixAt(i,new T.Matrix4().makeTranslation(x,0,2));root.add(instances);
const ordinary=new T.Mesh(new T.PlaneGeometry(1,1),new T.MeshStandardMaterial({transparent:true,opacity:.5,side:T.DoubleSide}));ordinary.position.set(-1,0,2);root.add(ordinary);
const glass=createGlassBreakage(T,scene);glass.prepare(root);const origin=new T.Vector3(),source=geo.attributes.position.array.slice(),first=applyWorldBlast(T,{point:origin,radius:4,power:100,roots:[root],glass});
assert.equal(first.broken,3,'near merged pane and two instances only');assert.deepEqual(geo.attributes.position.array,source,'source vertices unchanged');assert.equal(ordinary.geometry.index.count,6);const second=applyWorldBlast(T,{point:origin,radius:4,power:100,roots:[root],glass});assert.equal(second.broken,0,'no repeat fracture');
const distant=applyWorldBlast(T,{point:new T.Vector3(20,0,0),radius:4,power:100,roots:[root],glass});assert.equal(distant.broken,2,'far merged pane and far instance were intact');glass.reset();
const surfaces=new T.Group();scene.add(surfaces);for(const z of [2,3,20]){const m=new T.Mesh(new T.PlaneGeometry(10,10),new T.MeshStandardMaterial({side:T.DoubleSide}));m.position.z=z;surfaces.add(m)}
const hits=[];const wall=applyWorldBlast(T,{point:origin,radius:5,power:100,roots:[surfaces],glass,onSurfaceHit:e=>hits.push(e)});assert.equal(wall.surfaceHits,1,'front wall occludes rear wall');assert.equal(hits[0].hit.object,surfaces.children[0]);assert(hits[0].damage>0&&hits[0].damage<100);
const many=new T.Group();scene.add(many);for(let i=0;i<100;i++){const m=new T.Mesh(new T.PlaneGeometry(.1,.1),material);m.position.set((i%10)*.2,Math.floor(i/10)*.2,2);many.add(m)}glass.prepare(many);const start=performance.now(),bounded=applyWorldBlast(T,{point:origin,radius:4,power:100,roots:[many],glass,maxMeshes:4,maxPanels:3});assert(bounded.truncated);assert(bounded.broken<=3);assert.equal(bounded.panelsTested,3);assert.equal(bounded.candidates,100);
assert.equal(applyWorldBlast(T,{point:origin,radius:NaN,roots:[root],glass}).broken,0);glass.dispose();console.log('PASS merged/instanced only local panes, non-glass excluded, original vertices, once-only fracture, outside panes intact, opaque line of sight, bounded work',JSON.stringify({first,distant,bounded,ms:performance.now()-start}));
