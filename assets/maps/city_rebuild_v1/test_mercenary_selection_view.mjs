import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {createMercenarySelectionView} from './mercenary_selection_view.mjs';
import {createMercenaryBreachDoor} from './mercenary_breach_door.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const arcs=root=>root.getObjectByName('Mercenary_Object_Focus_Arcs');
function fixture(){const scene=new THREE.Scene(),root=new THREE.Group(),shared=new THREE.MeshStandardMaterial({color:0x446655}),body=new THREE.Mesh(new THREE.BoxGeometry(2,1,4),shared);root.add(body);scene.add(root);return {scene,root,body,shared,view:createMercenarySelectionView({THREE,scene})};}

test('one simple soft ribbon marker replaces the entire silhouette, preserving authored materials and buffers',()=>{
 const f=fixture(),before=f.body.geometry.attributes.position.array.slice(),normal=f.body.geometry.attributes.normal.array.slice();f.view.setTarget({kind:'safe',object:f.root});const marker=arcs(f.root),g=marker.geometry;
 assert(marker);assert.equal(f.root.getObjectByName('Mercenary_Object_Edge_Outline'),undefined);assert.equal(marker.material.uniforms.edgeColor.value.getHex(),0xf03532);assert.equal(marker.material.side,THREE.DoubleSide);assert(marker.material.depthTest);assert(!marker.material.depthWrite);assert(marker.material.transparent);assert.equal(g.attributes.position.count,594);assert.equal(g.index.count/3,768);assert(g.attributes.edgeAlpha.array.includes(0));assert(g.attributes.edgeAlpha.array.includes(1));assert(g.attributes.edgeAlpha.array.some(a=>a>0&&a<1));assert.equal(f.body.material,f.shared);assert.deepEqual(f.body.geometry.attributes.position.array,before);assert.deepEqual(f.body.geometry.attributes.normal.array,normal);assert.equal(f.body.geometry.boundingBox,null,'source bounds not mutated');
 const hits=[];marker.raycast({},hits);assert.equal(hits.length,0);let disposed=0;g.addEventListener('dispose',()=>disposed++);f.view.setTarget(null);assert.equal(arcs(f.root),undefined);assert.equal(disposed,1);f.view.dispose();
});

test('red selection, green work and completed removal happen without geometry or bounds churn',()=>{
 const f=fixture();f.view.setTarget({kind:'safe',object:f.root});const marker=arcs(f.root),g=marker.geometry;
 for(let i=0;i<400;i++){f.view.setTarget({kind:'safe',object:f.root,working:i%2===0});f.view.update(.016);assert.equal(marker.geometry,g);assert.equal(marker.material.uniforms.edgeColor.value.getHex(),i%2===0?0x61df89:0xf03532);}
 assert.equal(f.view.stats().boundsComputed,1);assert.equal(f.view.stats().outlineBuilds,1);assert.equal(f.view.stats().materialClones,0);
 for(const flags of[{valid:false},{invalid:true},{completed:true},{opened:true},{state:'completed'},{state:'opened'},{state:'invalid'}]){f.view.setTarget({object:f.root});assert(arcs(f.root));assert.equal(f.view.setTarget({object:f.root,...flags}),false);assert(!arcs(f.root));}
 f.view.setTarget({object:f.root});f.root.userData.mercenaryOpened=true;assert.equal(f.view.setTarget({kind:'safe',object:f.root}),false);assert.equal(f.view.stats().boundsComputed,1);f.view.dispose();
});

test('authored power panel bounds exclude remote lamps; marker follows the selected object transform',()=>{
 const f=fixture(),lamp=new THREE.Mesh(new THREE.BoxGeometry(),f.shared);lamp.position.set(40,10,-80);f.root.add(lamp);f.root.userData.mercenaryTarget={kind:'power_panel',highlightBounds:{min:[-.37,.86,-.24],max:[.37,1.8,.18]}};f.view.setTarget({object:f.root});const marker=arcs(f.root);assert.deepEqual(marker.userData.focusBounds,{min:[-.37,.86,-.24],max:[.37,1.8,.18]});marker.geometry.computeBoundingBox();assert(marker.geometry.boundingBox.max.x<.6);assert(marker.geometry.boundingBox.min.y>.8);const old=marker.getWorldPosition(new THREE.Vector3());f.root.position.x=30;f.root.rotation.y=.6;f.view.update(.016);assert.equal(marker.getWorldPosition(new THREE.Vector3()).x,old.x+30);assert.equal(f.view.stats().boundsComputed,1);f.root.userData.mercenaryTarget.powered=false;assert.equal(f.view.setTarget({object:f.root}),false);f.view.dispose();
});

test('fallback bounds union visible instances once, ignoring hidden proxies and annotations',()=>{
 const f=fixture(),geo=new THREE.BoxGeometry(),instances=new THREE.InstancedMesh(geo,f.shared,3);for(let i=0;i<3;i++)instances.setMatrixAt(i,new THREE.Matrix4().makeTranslation(i*4,2,0));f.root.add(instances);
 for(const mode of['hidden','material','annotation']){const m=new THREE.Mesh(geo,mode==='material'?new THREE.MeshBasicMaterial({visible:false}):f.shared);m.position.x=500;if(mode==='hidden')m.visible=false;if(mode==='annotation')m.userData.mercenaryPickIgnore=true;f.root.add(m);}
 const original=instances.instanceMatrix.array.slice();f.view.setTarget({kind:'fence',object:f.root});assert.equal(arcs(f.root).userData.focusBounds.max[0],8.5);assert.deepEqual(instances.instanceMatrix.array,original);f.view.setTarget(null);f.view.setTarget({kind:'fence',object:f.root});assert.equal(f.view.stats().boundsComputed,1,'reselect uses cached model bounds');f.view.dispose();
});

test('door uses authored frame bounds, preserves its leaf and disappears immediately after breach',()=>{
 const f=fixture(),door=createMercenaryBreachDoor({THREE,site:{id:'test-door',x:8,z:5},onCollisionChange:()=>true});f.scene.add(door.object);f.view.setTarget({kind:'door',object:door.object});assert.deepEqual(arcs(door.object).userData.focusBounds,{min:[-1.22,0,-.18],max:[1.22,2.61,.16]});const leafGeometry=door.leaf.children[0].geometry;f.view.setTarget({kind:'door',object:door.object,working:true});assert.equal(arcs(door.object).material.uniforms.edgeColor.value.getHex(),0x61df89);door.breakOpen();f.view.setTarget({kind:'door',object:door.object});assert.equal(arcs(door.object),undefined);assert.equal(door.leaf.children[0].geometry,leafGeometry);f.view.dispose();door.dispose();
});

test('NPC/member/player keep only their lower rings and vehicles keep only their independent door highlight',()=>{
 const f=fixture();for(const kind of['npc','member','player']){f.view.setTarget({kind,object:f.root,hp:60});assert(!arcs(f.root));assert(f.scene.getObjectByName('Mercenary_Npc_Selection_Ring').visible);assert.equal(f.body.material,f.shared);}
 f.root.position.set(5,.4,7);f.view.update(.016);const ring=f.scene.getObjectByName('Mercenary_Npc_Selection_Ring');assert.deepEqual(ring.position.toArray(),[5,.4,7]);f.view.setTarget({kind:'member',object:f.root,downed:true,hp:0});assert.equal(ring.material.color.getHex(),0xffce83);assert(ring.scale.z>ring.scale.x);
 const door=new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshBasicMaterial());door.name='Selected_door_outline';f.root.add(door);assert.equal(f.view.setTarget({kind:'vehicle',object:f.root}),false);assert(!arcs(f.root));assert(!ring.visible);assert(door.visible);assert.equal(door.parent,f.root);f.view.dispose();assert.equal(door.parent,f.root);
});

test('rally still fades independently; object update cost stays bounded on a high-detail model',()=>{
 const f=fixture(),mesh=new THREE.Mesh(new THREE.SphereGeometry(.5,128,64),f.shared);f.root.add(mesh);f.view.setTarget({object:f.root});const geometry=arcs(f.root).geometry;f.view.setRally({x:20,y:3,z:7});const rally=f.scene.getObjectByName('Mercenary_Rally_Marker');assert(rally.visible);f.view.update(3);assert(!rally.visible);assert.equal(arcs(f.root).geometry,geometry);
 const samples=[];for(let i=0;i<2500;i++){const start=performance.now();f.view.setTarget({object:f.root,working:i%2===0});f.view.update(.016);if(i>=300)samples.push(performance.now()-start);}samples.sort((a,b)=>a-b);assert.equal(f.view.stats().boundsComputed,1);assert.equal(f.view.stats().outlineBuilds,1);assert.equal(f.view.stats().outlineVertices,594);console.log(JSON.stringify({scenario:'one selected high-detail model, CPU only',p50Ms:samples[1100],p95Ms:samples[2090],markerDraws:1,markerTriangles:768,boundsBuilds:1,limitation:'Loaded scene performance not verified'}));f.view.dispose();f.view.dispose();assert.equal(f.view.stats().materials,0);assert.equal(arcs(f.root),undefined);
});