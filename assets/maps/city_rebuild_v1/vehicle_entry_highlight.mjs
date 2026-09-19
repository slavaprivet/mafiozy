// The caller supplies the already collision/lock/seat-approved entry candidate.
// One shared white outline follows that door; no fleet search or admission here.
export function createVehicleEntryHighlight({THREE,maxEntryDistance=1.3}={}){
 const cube=new THREE.BoxGeometry(1,1,1),geometry=new THREE.EdgesGeometry(cube);cube.dispose();const material=new THREE.LineBasicMaterial({color:0xffffff,transparent:true,opacity:.9,depthTest:true,depthWrite:false});const outline=new THREE.LineSegments(geometry,material);outline.name='Nearby_Entry_Door_Outline';outline.visible=false;outline.userData.mercenaryPickIgnore=true;outline.raycast=()=>{};outline.renderOrder=2;
 const cache=new WeakMap(),box=new THREE.Box3(),part=new THREE.Box3(),inverse=new THREE.Matrix4(),transform=new THREE.Matrix4(),center=new THREE.Vector3(),size=new THREE.Vector3();let selected=null,disposed=false,boundsComputed=0;
 function hide(){outline.visible=false;outline.removeFromParent();selected=null;return false;}
 function update(candidate,{enabled=true,position=null}={}){
  if(disposed)return false;const car=candidate?.record?.car,near=position&&candidate?.outside?Math.hypot(position.x-candidate.outside.x,position.z-candidate.outside.z):candidate?.near;
  if(!enabled||!car?.object?.parent||!Number.isFinite(near)||near>maxEntryDistance||near<0||candidate.record.damage?.disabled||candidate.record.roll?.unstable||position&&Math.abs(position.y-(car.object.position.y||0))>2)return hide();
  const key=candidate.doorId,door=car.doors?.get(key)||car.doors?.get(key==='front_left'?1:key==='front_right'?-1:key);if(!door?.isObject3D||!door.parent||door.userData.detached)return hide();for(let p=door;p;p=p.parent)if(p.visible===false)return hide();
  if(selected===door){outline.visible=true;return true;}
  let bounds=cache.get(door);if(!bounds){door.updateWorldMatrix(true,true);inverse.copy(door.matrixWorld).invert();box.makeEmpty();door.traverse(node=>{if(!node.isMesh||!node.geometry||node.userData?.mercenaryPickIgnore)return;for(let p=node;p;p=p.parent){if(p.visible===false)return;if(p===door)break;}const materials=Array.isArray(node.material)?node.material:[node.material];if(materials.every(m=>m?.visible===false))return;const g=node.geometry;if(!g.boundingBox)g.computeBoundingBox();if(!g.boundingBox||g.boundingBox.isEmpty())return;transform.multiplyMatrices(inverse,node.matrixWorld);box.union(part.copy(g.boundingBox).applyMatrix4(transform));});boundsComputed++;if(box.isEmpty())return hide();bounds=box.clone();cache.set(door,bounds);}
  bounds.getCenter(center);bounds.getSize(size);outline.position.copy(center);outline.scale.set(Math.max(.035,size.x+.02),Math.max(.035,size.y+.02),Math.max(.035,size.z+.02));door.add(outline);outline.visible=true;selected=door;return true;
 }
 return{update,clear:hide,stats:()=>({visible:outline.visible,door:selected?.userData?.vehicleDoorId||selected?.name||null,boundsComputed,drawCalls:outline.visible?1:0,disposed}),dispose(){if(disposed)return;hide();disposed=true;geometry.dispose();material.dispose();}};
}
