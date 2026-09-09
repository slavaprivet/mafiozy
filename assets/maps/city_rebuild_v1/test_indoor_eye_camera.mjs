import assert from 'node:assert/strict';
import * as T from 'file:///D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js';
import {createIndoorCamera} from './indoor_camera.mjs';
let distance=1;const c=createIndoorCamera({THREE:T,resolvePosition:({from})=>from.clone().add(new T.Vector3(0,0,-distance))});
const feet=new T.Vector3(8,3,9),desired=feet.clone().add(new T.Vector3(0,3,-5)),target=feet.clone().add(new T.Vector3(0,1.64,0)),args={feet,desired,target,objects:[],inside:true,ceilingY:5.35};
let view=c.solve(args);assert.equal(view.mode,'eye');assert.equal(view.hideHead,true);assert.equal(view.position.y,4.64);assert(view.target.clone().sub(view.position).normalize().distanceTo(target.clone().sub(desired).normalize())<1e-9);
distance=3.0;assert.equal(c.solve(args).mode,'eye');distance=3.5;assert.equal(c.solve(args).mode,'orbit');distance=3.0;assert.equal(c.solve(args).mode,'orbit');distance=1.95;assert.equal(c.solve(args).mode,'eye','stair landing head must not fill the view');distance=.2;assert.equal(c.solve({...args,inside:false}).mode,'orbit');
assert.equal(c.solve({...args,eyeHeight:.8}).position.y,3.8);c.reset();assert.equal(c.closeView,false);assert.deepEqual(feet.toArray(),[8,3,9]);console.log('PASS compressed boom eye view, orbit direction, hysteresis, crouch, outside/reset and immutable input');
