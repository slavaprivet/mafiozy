import {isCityParkingSurface,cityParkingGroundHeight,cityParkingCarFits} from './city_parking_plan.mjs';
/** All parking surfaces and signs are spatially batched; no textures or lights. */
export function createCityParking({THREE,plan,chunkSize=128}={}){
 if(!THREE||!plan?.lots)throw Error('Parking renderer requires THREE and a parking plan');
 const object=new THREE.Group();object.name='CityParking';
 const material=new THREE.MeshStandardMaterial({color:0xffffff,roughness:.91,metalness:.015}),geometry={box:new THREE.BoxGeometry(1,1,1),cylinder:new THREE.CylinderGeometry(1,1,1,12),triangle:new THREE.CylinderGeometry(1,1,1,3)};
 const colors={asphalt:0x596267,white:0xe5dfcd,blue:0x315d78,dark:0x34474a,stone:0xc5b99d,red:0xa94044};
 const buckets=new Map(),meshes=[],matrix=new THREE.Matrix4(),position=new THREE.Vector3(),scale=new THREE.Vector3(),rotation=new THREE.Quaternion(),euler=new THREE.Euler(),tint=new THREE.Color();
 function part(shape,x,y,z,sx,sy,sz,color,yaw=0,rx=0){const key=Math.floor(x/chunkSize)+','+Math.floor(z/chunkSize)+':'+shape;if(!buckets.has(key))buckets.set(key,[]);matrix.compose(position.set(x,y,z),rotation.setFromEuler(euler.set(rx,yaw,0)),scale.set(sx,sy,sz));buckets.get(key).push({matrix:matrix.clone(),color})}
 for(const r of plan.surfaceRects)part('box',(r.minX+r.maxX)/2,.046,(r.minZ+r.maxZ)/2,r.maxX-r.minX,.022,r.maxZ-r.minZ,colors.asphalt);
 function local(l,u,v,y=.075){return{x:l.origin.x+l.dz*u+l.dx*v,y,z:l.origin.z-l.dx*u+l.dz*v}}
 function paint(l,u,v,width,length){const p=local(l,u,v);part('box',p.x,p.y,p.z,width,.012,length,colors.white,l.yaw)}
 for(const l of plan.lots){if(l.layout==='parallel'){paint(l,3.6,.6,6.4,.1);paint(l,3.6,3.8,6.4,.1);paint(l,.4,2.2,.1,3.2);paint(l,6.8,2.2,.1,3.2)}else{for(let i=0;i<=l.bayCount;i++)paint(l,(i-l.bayCount/2)*3.2,10.9,.1,5.4);paint(l,0,13.6,l.bayCount*3.2,.1)}
  // Each stall stays open to the six-metre manoeuvring aisle.
  for(const b of plan.bays.filter(b=>b.lotId===l.id)){const p={...b,origin:{x:b.x,z:b.z},dx:Math.sin(b.yaw),dz:Math.cos(b.yaw)};paint(p,-.3,0,.11,1.25);paint(p,0,.57,.6,.11);paint(p,0,.03,.6,.11);paint(p,.3,.3,.11,.55)}
 }
 for(const mark of plan.access?.markings||[])part('box',mark.x,.075,mark.z,mark.width,.012,mark.length,colors.white,mark.yaw);
 for(const s of plan.signs){part('cylinder',s.x,1.4,s.z,.065,2.8,.065,colors.dark);part('cylinder',s.x,.06,s.z,.15,.12,.15,colors.stone);
  const sign=(x,y,z,sx,sy,sz,color,shape='box',rx=0)=>{const xx=s.x+x*Math.cos(s.yaw)+z*Math.sin(s.yaw),zz=s.z-x*Math.sin(s.yaw)+z*Math.cos(s.yaw);part(shape,xx,y,zz,sx,sy,sz,color,s.yaw,rx)};
  if(s.kind==='parking'){sign(0,2.52,0,.91,.99,.08,colors.white);sign(0,2.52,.055,.8,.88,.035,colors.blue);sign(-.18,2.52,.086,.1,.59,.025,colors.white);sign(.035,2.765,.086,.36,.1,.025,colors.white);sign(.035,2.50,.086,.36,.1,.025,colors.white);sign(.20,2.63,.086,.1,.32,.025,colors.white)}
  else {sign(0,2.47,0,.58,.07,.58,colors.red,'triangle',Math.PI/2);sign(0,2.505,.05,.44,.025,.44,colors.white,'triangle',Math.PI/2)}
 }
 for(const [key,parts]of buckets){const mesh=new THREE.InstancedMesh(geometry[key.split(':').at(-1)],material,parts.length);parts.forEach((p,i)=>{mesh.setMatrixAt(i,p.matrix);mesh.setColorAt(i,tint.setHex(p.color))});mesh.name='ParkingBatch:'+key;mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.needsUpdate=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();mesh.userData.worldBlastStaticBounds=true;mesh.castShadow=false;mesh.receiveShadow=true;object.add(mesh);meshes.push(mesh)}
 let disposed=false,lastX=NaN,lastZ=NaN;
 function update({focus}={}){if(disposed)return;if(focus?.x===lastX&&focus?.z===lastZ)return;for(const mesh of meshes){const b=mesh.boundingSphere;mesh.visible=!focus||Math.hypot(b.center.x-focus.x,b.center.z-focus.z)<300+b.radius}lastX=focus?.x;lastZ=focus?.z}
 const stats={...plan.stats,access:plan.access?.stats||null,totalDraws:meshes.length,triangles:meshes.reduce((sum,m)=>sum+m.geometry.index.count/3*m.count,0),get visibleDraws(){return meshes.filter(m=>m.visible).length}};
 return{object,plan,colliders:plan.colliders,mapFeatures:plan.mapFeatures,stats,update,isDriveSurface:(x,z)=>isCityParkingSurface(plan,x,z),groundHeight:(x,z)=>cityParkingGroundHeight(plan,x,z),carFits:(x,z,yaw,shape)=>cityParkingCarFits(plan,x,z,yaw,shape),dispose(){if(disposed)return;disposed=true;for(const mesh of meshes)mesh.dispose();for(const g of Object.values(geometry))g.dispose();material.dispose();object.clear();object.removeFromParent()}};
}
