// An exit can leave the old driving camera on the far side of the car.
// Preserve the orbit unless the car actually hides the walking character.
export function ensureVehicleExitVisible(T,{hero,car,camera,controls,eyeHeight=1.1}){
 hero.object.visible=true;car.object.updateWorldMatrix(true,true);
 const target=hero.object.position.clone().add(new T.Vector3(0,eyeHeight,0)),delta=target.clone().sub(camera.position),distance=delta.length();
 const ray=new T.Raycaster(camera.position,delta.normalize(),.05,Math.max(.05,distance-.25));
 const blocked=ray.intersectObject(car.object,true).some(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;const mats=Array.isArray(h.object.material)?h.object.material:[h.object.material];return mats.some(m=>m&&!m.transparent)});
 if(!blocked)return false;
 const outward=hero.object.position.clone().sub(car.object.position);outward.y=0;if(outward.lengthSq()<.01)outward.set(Math.cos(car.object.rotation.y),0,-Math.sin(car.object.rotation.y));outward.normalize();
 controls.target.copy(target);camera.position.copy(target).addScaledVector(outward,5).add(new T.Vector3(0,2.5,0));camera.lookAt(target);camera.updateMatrixWorld();return true;
}
