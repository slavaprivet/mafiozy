export function reachedExplorationWaypoint(actor,target,{radius=1.15,heightTolerance=.9}={}){
 return !!actor&&!!target&&Number.isFinite(actor.x+actor.y+actor.z+target.x+target.y+target.z)&&Math.hypot(actor.x-target.x,actor.z-target.z)<=radius&&Math.abs(actor.y-target.y)<=heightTolerance;
}

/** Small brass map pin and a calm ground halo, in the city's existing palette. */
export function createExplorationWaypointVisual(THREE){
 const object=new THREE.Group();object.name='Путевая метка';
 const gold=new THREE.MeshBasicMaterial({color:0xe9c77b,transparent:true,opacity:.95});
 const dark=new THREE.MeshBasicMaterial({color:0x183b40,transparent:true,opacity:.88,side:THREE.DoubleSide});
 const glow=new THREE.MeshBasicMaterial({color:0xe9c77b,transparent:true,opacity:.18,depthWrite:false});
 const ring=new THREE.Mesh(new THREE.RingGeometry(.77,.805,64),gold);ring.rotation.x=-Math.PI/2;ring.position.y=.045;object.add(ring);
 const inner=new THREE.Mesh(new THREE.RingGeometry(.63,.75,64),glow);inner.rotation.x=-Math.PI/2;inner.position.y=.042;object.add(inner);
 for(let i=0;i<4;i++){const tick=new THREE.Mesh(new THREE.BoxGeometry(.055,.012,.15),gold),a=i*Math.PI/2;tick.position.set(Math.sin(a)*.94,.05,Math.cos(a)*.94);tick.rotation.y=a;object.add(tick)}
 const marker=new THREE.Group();marker.position.y=1.08;object.add(marker);
 const silhouette=new THREE.Shape();silhouette.moveTo(0,0);silhouette.bezierCurveTo(-.13,.18,-.30,.35,-.30,.55);silhouette.bezierCurveTo(-.30,.95,.30,.95,.30,.55);silhouette.bezierCurveTo(.30,.35,.13,.18,0,0);
 const face=new THREE.Mesh(new THREE.ShapeGeometry(silhouette,24),dark);marker.add(face);
 const contour=new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(silhouette.getPoints(40)),new THREE.LineBasicMaterial({color:0xe9c77b}));contour.position.z=.008;marker.add(contour);
 const eye=new THREE.Mesh(new THREE.RingGeometry(.09,.13,32),gold);eye.position.set(0,.56,.012);marker.add(eye);
 object.userData.update=(time,camera)=>{const pulse=.5+.5*Math.sin(time*1.7);inner.material.opacity=.12+pulse*.09;inner.scale.setScalar(.98+pulse*.04);marker.position.y=1.08+Math.sin(time*1.7)*.045;if(camera)marker.rotation.y=Math.atan2(camera.position.x-object.position.x,camera.position.z-object.position.z)};
 return object;
}
