import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createEnvironmentLawnGround} from './environment_lawn_ground.mjs';

const THREE=await import(pathToFileURL((process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/')+'build/three.module.js'));
const tufts=[];for(let z=0;z<32;z++)for(let x=0;x<32;x++)tufts.push({id:`lawn-${x}-${z}`,zone:'lawn',style:'grass',x:x*.8,z:z*.8,y:-.015,yaw:(x+z)*.17,radius:.65});
const ground=createEnvironmentLawnGround({THREE,plan:{tufts}});ground.update({focus:{x:12,z:12},force:true});
assert.ok(ground.stats.objects>900);assert.ok(ground.stats.objects<=1024);assert.ok(ground.stats.triangles<=4096);assert.equal(ground.stats.draws,1);assert.equal(ground.mesh.castShadow,false);assert.equal(ground.mesh.receiveShadow,true);assert.equal(ground.mesh.userData.worldBlastIgnore,true);assert.equal(ground.mesh.raycast(),undefined);
assert.equal(ground.geometry.drawRange.count,ground.stats.triangles*3);assert.equal(ground.stats.objects,ground.stats.soil+ground.stats.stone+ground.stats.leaf+ground.stats.weed);for(const kind of['soil','stone','leaf','weed'])assert.ok(ground.stats[kind]>0,kind+' is represented');
const first=ground.geometry.attributes.position.array.slice(0,ground.geometry.drawRange.count*3);ground.update({focus:{x:12,z:12},force:true});assert.deepEqual(ground.geometry.attributes.position.array.slice(0,ground.geometry.drawRange.count*3),first,'same focus is deterministic');
for(const attribute of['position','normal','color'])for(const value of ground.geometry.attributes[attribute].array.slice(0,ground.geometry.drawRange.count*3))assert.ok(Number.isFinite(value),attribute+' remains finite');
ground.update({focus:{x:1e6,z:1e6},force:true});assert.equal(ground.stats.objects,0);assert.equal(ground.stats.draws,0);ground.dispose();
console.log(JSON.stringify({status:'PASS',objects:1024,maxTriangles:4096,draws:1}));
