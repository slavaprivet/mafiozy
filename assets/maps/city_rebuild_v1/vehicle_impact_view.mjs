// A render-only camera offset: OrbitControls and physical transforms never
// accumulate the shock, including when rendering throws or seats are changed.
export function createVehicleImpactView(T){
 const position=new T.Vector3(),quaternion=new T.Quaternion(),shift=new T.Vector3();
 let peakOffset=0,frames=0;
 function render(camera,car,reaction,draw){
  if(!reaction?.active||!car?.object){draw();return}
  position.copy(camera.position);quaternion.copy(camera.quaternion);
  const sample=reaction.camera;shift.set(sample.x,sample.y,sample.z).applyQuaternion(car.object.quaternion);
  camera.position.add(shift);camera.rotateZ(-reaction.local.x*.14);camera.updateMatrixWorld();
  peakOffset=Math.max(peakOffset,shift.length());frames++;
  try{draw()}finally{camera.position.copy(position);camera.quaternion.copy(quaternion);camera.updateMatrixWorld()}
 }
 return{render,stats:()=>({peakOffset,frames}),reset(){peakOffset=frames=0}};
}
