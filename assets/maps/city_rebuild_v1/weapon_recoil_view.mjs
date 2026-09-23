// Render-only kick never accumulates in mouse/orbit state or changes shot authority.
export function createWeaponRecoilView(THREE){
 const saved=new THREE.Quaternion();
 return (renderer,scene,camera,recoil,beforeRender)=>{
  const kick=Math.min(.025,Math.max(0,recoil?.cameraKick||0))*.55,yaw=(recoil?.yaw||0)*.6;
  // Rendering still occurs at the normal cadence. A settled weapon has no
  // temporary camera transform to restore, so avoid no-op quaternion/matrix work.
  if(kick===0&&yaw===0){beforeRender?.(camera);renderer.render(scene,camera);return}
  saved.copy(camera.quaternion);
  try{camera.rotateX(kick);camera.rotateY(yaw);beforeRender?.(camera);renderer.render(scene,camera)}
  finally{camera.quaternion.copy(saved);camera.updateMatrixWorld(true)}
 };
}
