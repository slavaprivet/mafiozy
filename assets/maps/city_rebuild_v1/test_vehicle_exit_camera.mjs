import assert from 'node:assert/strict';import {pathToFileURL} from 'node:url';import {ensureVehicleExitVisible} from './vehicle_exit_camera.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const car={object:new T.Group()},body=new T.Mesh(new T.BoxGeometry(2.56,2.2,4.48),new T.MeshStandardMaterial());body.position.y=1.1;car.object.add(body);
const hero={object:new T.Group()};hero.object.position.set(2.5,0,0);const camera=new T.PerspectiveCamera(45,1,.2,100),controls={target:new T.Vector3(2.5,1.1,0)};camera.position.set(-6,1.5,0);camera.lookAt(controls.target);
assert(ensureVehicleExitVisible(T,{hero,car,camera,controls}));assert(camera.position.x>hero.object.position.x);const position=camera.position.clone();assert(!ensureVehicleExitVisible(T,{hero,car,camera,controls}));assert.deepEqual(camera.position.toArray(),position.toArray());
console.log('PASS hidden exit moves camera to free side, already clear camera unchanged');
