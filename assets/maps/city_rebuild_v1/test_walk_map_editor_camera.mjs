import assert from 'node:assert/strict';
import {createWalkMapEditorCamera} from './walk_map_editor_camera.mjs';

class Vector3{
 constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}clone(){return new Vector3(this.x,this.y,this.z)}copy(v){return this.set(v.x,v.y,v.z)}add(v){this.x+=v.x;this.y+=v.y;this.z+=v.z;return this}sub(v){this.x-=v.x;this.y-=v.y;this.z-=v.z;return this}multiplyScalar(v){this.x*=v;this.y*=v;this.z*=v;return this}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}normalize(){const length=Math.sqrt(this.lengthSq())||1;return this.multiplyScalar(1/length)}distanceTo(v){return Math.hypot(this.x-v.x,this.y-v.y,this.z-v.z)}crossVectors(a,b){return this.set(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)}applyQuaternion(){return this}
}
class Euler{constructor(x=0,y=0,z=0,order='YXZ'){this.set(x,y,z,order)}set(x,y,z,order=this.order){this.x=x;this.y=y;this.z=z;this.order=order;return this}setFromQuaternion(q,order=this.order){return this.set(q.x,q.y,q.z,order)}}
class Quaternion{constructor(x=0,y=0,z=0,w=1){this.x=x;this.y=y;this.z=z;this.w=w}clone(){return new Quaternion(this.x,this.y,this.z,this.w)}copy(q){Object.assign(this,q);return this}setFromEuler(e){this.x=e.x;this.y=e.y;this.z=e.z;this.w=1;return this}angleTo(q){return Math.hypot(this.x-q.x,this.y-q.y,this.z-q.z,this.w-q.w)}}
const THREE={Vector3,Euler};
const camera={fov:50,aspect:16/9,near:.1,far:2000,zoom:1,position:new Vector3(5,6,7),up:new Vector3(0,1,0),quaternion:new Quaternion(),lookAt(){},updateProjectionMatrix(){},updateMatrixWorld(){}};
const original={position:camera.position.clone(),quaternion:camera.quaternion.clone(),up:camera.up.clone(),near:camera.near,far:camera.far,zoom:camera.zoom};
const controls={target:new THREE.Vector3(1,0,1),enabled:true,minDistance:2,maxDistance:16,minPolarAngle:.1,maxPolarAngle:1.4,update(){this.updates=(this.updates||0)+1}};
const originalTarget=controls.target.clone();
const editor=createWalkMapEditorCamera({THREE,camera,controls,bounds:{minX:0,minZ:0,maxX:100,maxZ:80},groundHeight:()=>2});
editor.enter('top');assert.equal(editor.active,true);assert.equal(editor.mode,'top');assert.equal(controls.enabled,false);assert.ok(camera.position.y>40);
const topStart=camera.position.clone();editor.handleAction({action:'navigate',code:'KeyW',pressed:true});editor.update(.1);editor.handleAction({action:'navigate',code:'KeyW',pressed:false});assert.ok(camera.position.z<topStart.z);
const topHeight=camera.position.y;editor.handleAction({action:'zoom',delta:100});assert.ok(camera.position.y>topHeight);
const speed=editor.speed,zoomPosition=camera.position.clone();assert.equal(editor.handleAction({action:'zoom',delta:NaN}),false);assert.ok(camera.position.distanceTo(zoomPosition)<1e-12);assert.equal(editor.handleAction({action:'fly-speed',delta:Infinity}),false);assert.equal(editor.speed,speed);
editor.handleAction({action:'camera-pan-start'},{clientX:0,clientY:0});editor.handleAction({action:'camera-pan-move'},{clientX:-1e6,clientY:-1e6});editor.handleAction({action:'camera-pan-end'});assert.ok(camera.position.x>=0&&camera.position.x<=100&&camera.position.z>=0&&camera.position.z<=80);assert.ok(controls.target.x>=0&&controls.target.x<=100&&controls.target.z>=0&&controls.target.z<=80);
editor.handleAction({action:'navigate',code:'KeyW',pressed:true});const beforeMode=camera.position.clone();editor.setMode('fly');editor.update(.1);assert.ok(camera.position.distanceTo(beforeMode)<1e-12,'mode switch must release held movement');
assert.equal(editor.mode,'fly');assert.equal(editor.handleAction({action:'camera-pan-start'},{clientX:0,clientY:0}),false);const flyStart=camera.position.clone();editor.handleAction({action:'navigate',code:'KeyW',pressed:true});editor.update(.1);editor.handleAction({action:'navigate',code:'KeyW',pressed:false});assert.ok(camera.position.distanceTo(flyStart)>0);
const priorSpeed=editor.speed;assert.equal(editor.handleAction({action:'fly-speed',delta:-200}),true);assert.ok(editor.speed>priorSpeed);
const raised=camera.position.y;editor.handleAction({action:'navigate-vertical',direction:1,pressed:true});editor.update(.1);editor.handleAction({action:'navigate-vertical',direction:1,pressed:false});assert.ok(camera.position.y>raised);
const beforeLook=camera.quaternion.clone();editor.handleAction({action:'camera-look-start'},{clientX:10,clientY:10});editor.handleAction({action:'camera-look-move'},{clientX:30,clientY:20});editor.handleAction({action:'camera-look-end'});assert.ok(beforeLook.angleTo(camera.quaternion)>0);
editor.handleAction({action:'navigate',code:'KeyW',pressed:true});editor.handleAction({action:'clear-input'});const stopped=camera.position.clone();editor.update(.1);assert.ok(stopped.distanceTo(camera.position)<1e-12);
editor.setMode('top');camera.position.y=2000;editor.setMode('fly');assert.ok(camera.position.y<=900,'fly mode must clamp immediately');
assert.equal(editor.restore(),true);assert.ok(camera.position.distanceTo(original.position)<1e-12);assert.ok(camera.quaternion.angleTo(original.quaternion)<1e-12);assert.ok(camera.up.distanceTo(original.up)<1e-12);assert.equal(camera.zoom,original.zoom);assert.ok(controls.target.distanceTo(originalTarget)<1e-12);assert.equal(controls.enabled,true);assert.equal(controls.maxDistance,16);assert.equal(editor.restore(),false);
const inactivePosition=camera.position.clone();assert.equal(editor.handleAction({action:'navigate',code:'KeyW',pressed:true}),false);assert.equal(editor.update(.1),false);assert.ok(camera.position.distanceTo(inactivePosition)<1e-12);editor.setMode('top');assert.ok(camera.position.distanceTo(inactivePosition)<1e-12);assert.equal(editor.fitTop(),false);
editor.enter('fly');assert.ok(camera.up.distanceTo(new Vector3(0,1,0))<1e-12);assert.equal(editor.dispose(),true);assert.equal(editor.dispose(),false);

console.log('walk map editor camera: PASS');
