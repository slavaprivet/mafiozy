// Presentation adapter for reduced structural physics. The solver itself is THREE-free.
import {createCrashMechanicsState,applyCrashMechanicsImpact,stepCrashMechanics,sampleCrashDeformation,crashDriveEffects,resetCrashMechanics,createCrashDebrisState,stepCrashDebris} from './vehicle_crash_mechanics.mjs';
import {getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';

// Preserve UVs, vertex colours and material groups when adding bend support.
export function subdivideVehicleGeometry(T,original,maxEdge=.24,maxTriangles=18000){
 const source=original.index?original.toNonIndexed():original.clone(),names=Object.keys(source.attributes),attributes=names.map(name=>({name,attribute:source.attributes[name],offset:0})),arrays=Object.fromEntries(names.map(n=>[n,[]])),groups=[];
 // This path can run for several panels in the exact impact frame.  The old
 // generic attribute records created an object, an array and an Object.entries
 // map for every input and midpoint vertex.  Store the same decoded components
 // in one packed vector instead: UVs, vertex colours and material groups remain
 // byte-for-byte on the resulting Float32 attributes, but the burst has far
 // less allocation and GC pressure.
 let stride=0;for(const item of attributes){item.offset=stride;stride+=item.attribute.itemSize}
 const position=attributes.find(item=>item.name==='position'),positionOffset=position?.offset??0,maxEdgeSq=maxEdge*maxEdge;
 const vertex=index=>{const out=new Float64Array(stride);for(const item of attributes)for(let k=0;k<item.attribute.itemSize;k++)out[item.offset+k]=item.attribute.getComponent(index,k);return out};
 const midpoint=(a,b)=>{const out=new Float64Array(stride);for(let i=0;i<stride;i++)out[i]=(a[i]+b[i])*.5;return out};
 const length=(a,b)=>{const dx=a[positionOffset]-b[positionOffset],dy=a[positionOffset+1]-b[positionOffset+1],dz=a[positionOffset+2]-b[positionOffset+2];return dx*dx+dy*dy+dz*dz};
 let splitsRemaining=Math.max(0,Math.floor(maxTriangles)-source.attributes.position.count/3),groupIndex=0;
 function emit(vertex,material){for(const item of attributes){const out=arrays[item.name],start=item.offset,end=start+item.attribute.itemSize;for(let i=start;i<end;i++)out.push(vertex[i])}const last=groups.at(-1);if(last?.materialIndex===material)last.count+=1;else groups.push({start:arrays.position.length/3-1,count:1,materialIndex:material})}
 function split(a,b,c,depth,material){
  const ab=length(a,b),bc=length(b,c),ca=length(c,a),longest=Math.max(ab,bc,ca);
  if(depth<7&&longest>maxEdgeSq&&splitsRemaining>0){splitsRemaining--;if(ab>=bc&&ab>=ca){const m=midpoint(a,b);split(a,m,c,depth+1,material);split(m,b,c,depth+1,material)}else if(bc>=ca){const m=midpoint(b,c);split(a,b,m,depth+1,material);split(a,m,c,depth+1,material)}else{const m=midpoint(c,a);split(a,b,m,depth+1,material);split(m,b,c,depth+1,material)}return}
  emit(a,material);emit(b,material);emit(c,material);
 }
 for(let i=0;i<source.attributes.position.count;i+=3){while(groupIndex<source.groups.length&&i>=source.groups[groupIndex].start+source.groups[groupIndex].count)groupIndex++;const material=source.groups[groupIndex]?.start<=i&&i<source.groups[groupIndex].start+source.groups[groupIndex].count?source.groups[groupIndex].materialIndex:0;split(vertex(i),vertex(i+1),vertex(i+2),0,material)}
 const result=new T.BufferGeometry();for(const n of names)result.setAttribute(n,new T.Float32BufferAttribute(arrays[n],source.attributes[n].itemSize));for(const g of groups)result.addGroup(g.start,g.count,g.materialIndex);result.userData={...original.userData,vehicleCrashSubdivided:true};result.computeBoundingBox();result.computeBoundingSphere();source.dispose();return result;
}

export function createVehicleCrash(T,car,{scene=car.object.parent,groundHeight=()=>0,allowed=()=>true,getState=()=>({}),trunk=null}={}){
 const profile={massKg:car.object.userData.massKg||1500,...car.profile,wheelPositions:car.profile?.wheelPositions||Object.fromEntries((car.wheels||[]).map(w=>[w.id,{x:w.restPosition?.x??w.pivot.position.x,y:w.restPosition?.y??w.pivot.position.y,z:w.restPosition?.z??w.pivot.position.z}]))},state=createCrashMechanicsState(profile),root=new T.Group();root.name='Vehicle_world_crash_debris';(scene||car.object).add(root);
 const geometryRest=new Map(),bindings=new Map(),parts=new Map(),hidden=new Map(),debris=[],wheelRest=new Map();let disposed=false,lastRevision=-1,time=0,idleUpdates=0;
 const p=new T.Vector3(),delta=new T.Vector3(),matrix=new T.Matrix4(),inverse=new T.Matrix4(),carInverse=new T.Matrix4(),debrisQuaternion=new T.Quaternion(),reachPoint={x:0,y:0,z:0},reachDeformation={x:0,y:0,z:0},nodeOffsets=new Float64Array(45*3);
 car.object.updateWorldMatrix(true,true);
 for(const wheel of car.wheels||[])wheelRest.set(wheel.id,{position:wheel.pivot.position.clone(),rotation:wheel.pivot.rotation.clone(),visible:wheel.pivot.visible});
 for(const [key,door]of car.doors||[]){const id=typeof key==='number'?'front_'+(key>0?'left':'right'):key;parts.set('door_'+id,door)}
 for(const wheel of car.wheels||[])parts.set('wheel_'+wheel.id,wheel.pivot);
 const names={Hood_lid:'hood',Trunk_lid:'trunk',Bumper_front:'bumper_front',Bumper_rear:'bumper_rear'};
 car.object.traverse(n=>{
  // Keep the immutable artist node names. The original sedan uses Bumper_front,
  // while the authored fleet retains LOD0_<model>_FrontBumper / RearBumper.
  // Both must release their actual mesh when the same structural mount fails.
  const id=names[n.name]||(/_FrontBumper$/.test(n.name)?'bumper_front':/_RearBumper$/.test(n.name)?'bumper_rear':null);
  if(id&&!parts.has(id))parts.set(id,n);
 });
 const candidates=[];
 car.object.traverse(mesh=>{if(!mesh.isMesh||!mesh.geometry?.attributes?.position||mesh.geometry.attributes.position.count>90000)return;const materials=Array.isArray(mesh.material)?mesh.material:[mesh.material];if(materials.every(m=>m?.transparent))return;for(let n=mesh;n&&n!==car.object;n=n.parent)if(n.userData?.vehicleWheelId||n===car.interior?.object||n.name?.includes('damage_effects')||n.userData?.crashDeform===false)return;candidates.push(mesh)});
 const authoredGeometry=new Map(candidates.map(mesh=>[mesh,mesh.geometry]));
 // A structural revision does not move all 45 cage nodes.  Remember exactly
 // which eight-node interpolation cells feed each bound mesh, so a settling
 // contact does not rescan/recompute normals and bounds for panels whose
 // source nodes are unchanged.  This is conservative (boundary vertices keep
 // both neighbouring cells) and therefore cannot skip a changed vertex.
 function gridInterval(values,value){
  if(value<=values[0])return 0;const last=values.length-1;if(value>=values[last])return last-1;
  for(let i=0;i<last;i++)if(value<=values[i+1])return i;return last-1;
 }
 function gridBlend(values,value,index){const v=Math.max(values[0],Math.min(values[values.length-1],value));return (v-values[index])/(values[index+1]-values[index])}
 function maskBindingNode(mask,index){
  if(index<32)mask.lo=(mask.lo|(1<<index))>>>0;
  else mask.hi=(mask.hi|(1<<(index-32)))>>>0;
 }
 function captureBindingNodes(binding){
  const values=binding.nodePositions;
  for(let i=0,j=0;i<state.nodes.length;i++,j+=3){
   const present=i<32?(binding.nodeMaskLo&(1<<i))!==0:(binding.nodeMaskHi&(1<<(i-32)))!==0;if(!present)continue;
   const node=state.nodes[i];values[j]=node.position.x;values[j+1]=node.position.y;values[j+2]=node.position.z;
  }
 }
 function bindingNodesChanged(binding){
  const values=binding.nodePositions;
  for(let i=0,j=0;i<state.nodes.length;i++,j+=3){
   const present=i<32?(binding.nodeMaskLo&(1<<i))!==0:(binding.nodeMaskHi&(1<<(i-32)))!==0;if(!present)continue;
   const node=state.nodes[i];if(node.position.x!==values[j]||node.position.y!==values[j+1]||node.position.z!==values[j+2])return true;
  }
  return false;
 }
 function captureNodeOffsets(){for(let i=0,j=0;i<state.nodes.length;i++,j+=3){const node=state.nodes[i],rest=node.rest,position=node.position;nodeOffsets[j]=position.x-rest.x;nodeOffsets[j+1]=position.y-rest.y;nodeOffsets[j+2]=position.z-rest.z}}
 function reachesMesh(mesh){
  if(!mesh.geometry.boundingBox)mesh.geometry.computeBoundingBox();
  matrix.copy(carInverse).multiply(mesh.matrixWorld);const box=mesh.geometry.boundingBox.clone().applyMatrix4(matrix);
  const axis=(name,grid)=>[box.min[name],box.max[name],...grid.filter(value=>value>box.min[name]&&value<box.max[name])];
  for(const x of axis('x',state.grid.x))for(const y of axis('y',state.grid.y))for(const z of axis('z',state.grid.z)){reachPoint.x=x;reachPoint.y=y;reachPoint.z=z;const d=sampleCrashDeformation(state,reachPoint,reachDeformation);if(d.x*d.x+d.y*d.y+d.z*d.z>=.000001)return true}return false;
 }
 function bind(mesh){
  const geometry=mesh.geometry,positions=geometry.attributes.position;
  matrix.copy(carInverse).multiply(mesh.matrixWorld);const toCar=matrix.clone(),toMesh=new T.Matrix3().setFromMatrix4(toCar).invert();
  const base=positions.array.slice(),local=new Float32Array(base.length),mask={lo:0,hi:0},cells=new Uint8Array(positions.count*3),blends=new Float64Array(positions.count*3);
  for(let i=0;i<positions.count;i++){
   const j=i*3;p.fromBufferAttribute(positions,i).applyMatrix4(toCar);local[j]=p.x;local[j+1]=p.y;local[j+2]=p.z;
   const x=local[j],y=local[j+1],z=local[j+2],xi=gridInterval(state.grid.x,x),yi=gridInterval(state.grid.y,y),zi=gridInterval(state.grid.z,z);cells[j]=xi;cells[j+1]=yi;cells[j+2]=zi;blends[j]=gridBlend(state.grid.x,x,xi);blends[j+1]=gridBlend(state.grid.y,y,yi);blends[j+2]=gridBlend(state.grid.z,z,zi);
   for(let z=0;z<2;z++)for(let y=0;y<2;y++)for(let x=0;x<2;x++)maskBindingNode(mask,((zi+z)*3+yi+y)*3+xi+x);
  }
  const binding={geometry,base,local,toMesh,version:positions.version,offset:new Float32Array(base.length),nodeMaskLo:mask.lo,nodeMaskHi:mask.hi,nodePositions:new Float64Array(state.nodes.length*3),cells,blends,deformationApplied:false};captureBindingNodes(binding);bindings.set(mesh,binding);return binding;
 }
 function deform(){
  if(state.revision===lastRevision)return;lastRevision=state.revision;
  // A contact updates the car hierarchy once.  Repeating that full traversal
  // for every affected panel dominated the first visible collision burst; all
  // panel matrices are read-only while this deformation pass runs.
  car.object.updateWorldMatrix(true,true);carInverse.copy(car.object.matrixWorld).invert();
  captureNodeOffsets();
  for(const mesh of candidates){let visible=true;for(let node=mesh;node&&node!==car.object;node=node.parent)if(!node.visible){visible=false;break}if(!visible)continue;
   if(!geometryRest.has(mesh)){if(!reachesMesh(mesh))continue;const current=mesh.geometry;if(!current.userData.vehicleCrashSubdivided)mesh.geometry=subdivideVehicleGeometry(T,current,.15,9000);geometryRest.set(mesh,authoredGeometry.get(mesh)||current)}
   let b=bindings.get(mesh);if(!b||b.geometry!==mesh.geometry)b=bind(mesh);const a=mesh.geometry.attributes.position,sourceChanged=a.version!==b.version;
   // A panel whose interpolation nodes and authored/dented input are identical
   // has byte-identical positions, normals and bounds.  Leave it untouched;
   // this preserves the same mesh, material and raycast state while avoiding
   // the expensive full normal/bounds pass during repeated nearby impacts.
   if(b.deformationApplied&&!sourceChanged&&!bindingNodesChanged(b))continue;
   // A bullet may dent this same mesh between structural solves. Retain it.
   if(sourceChanged)for(let i=0;i<a.array.length;i++)b.base[i]=a.array[i]-b.offset[i];
   // The cage grid and this mesh's rest-space vertices are immutable.  Bind
   // their exact trilinear cell/fractions once, then sample the same eight
   // live node offsets in the original z/y/x order.  This removes three grid
   // searches and a Vector3 decode for every rendered support vertex without
   // approximating the deformation or reducing the artist geometry.
   const e=b.toMesh.elements,cells=b.cells,blends=b.blends,offset=b.offset,base=b.base;
   for(let i=0,j=0;i<a.count;i++,j+=3){const xi=cells[j],yi=cells[j+1],zi=cells[j+2],xt=blends[j],yt=blends[j+1],zt=blends[j+2],xm=1-xt,ym=1-yt,zm=1-zt,k=(((zi*3+yi)*3+xi)*3),kX=k+3,kY=k+9,kXY=k+12,kZ=k+27,kXZ=k+30,kYZ=k+36,kXYZ=k+39;const dx=nodeOffsets[k]*xm*ym*zm+nodeOffsets[kX]*xt*ym*zm+nodeOffsets[kY]*xm*yt*zm+nodeOffsets[kXY]*xt*yt*zm+nodeOffsets[kZ]*xm*ym*zt+nodeOffsets[kXZ]*xt*ym*zt+nodeOffsets[kYZ]*xm*yt*zt+nodeOffsets[kXYZ]*xt*yt*zt,dy=nodeOffsets[k+1]*xm*ym*zm+nodeOffsets[kX+1]*xt*ym*zm+nodeOffsets[kY+1]*xm*yt*zm+nodeOffsets[kXY+1]*xt*yt*zm+nodeOffsets[kZ+1]*xm*ym*zt+nodeOffsets[kXZ+1]*xt*ym*zt+nodeOffsets[kYZ+1]*xm*yt*zt+nodeOffsets[kXYZ+1]*xt*yt*zt,dz=nodeOffsets[k+2]*xm*ym*zm+nodeOffsets[kX+2]*xt*ym*zm+nodeOffsets[kY+2]*xm*yt*zm+nodeOffsets[kXY+2]*xt*yt*zm+nodeOffsets[kZ+2]*xm*ym*zt+nodeOffsets[kXZ+2]*xt*ym*zt+nodeOffsets[kYZ+2]*xm*yt*zt+nodeOffsets[kXYZ+2]*xt*yt*zt;const x=e[0]*dx+e[3]*dy+e[6]*dz,y=e[1]*dx+e[4]*dy+e[7]*dz,z=e[2]*dx+e[5]*dy+e[8]*dz;offset[j]=x;offset[j+1]=y;offset[j+2]=z;a.setXYZ(i,base[j]+x,base[j+1]+y,base[j+2]+z)}
   a.needsUpdate=true;b.version=a.version;b.deformationApplied=true;captureBindingNodes(b);mesh.geometry.computeVertexNormals();mesh.geometry.computeBoundingBox();mesh.geometry.computeBoundingSphere();
  }
 }
 function clonePart(source){
  const copy=source.clone(false),material=getVehicleRenderSourceMaterial(source);if(source.geometry)copy.geometry=source.geometry.clone();if(material)copy.material=Array.isArray(material)?material.map(m=>m.clone()):material.clone();copy.raycast=()=>{};copy.userData={...copy.userData,detachedVehiclePart:true};if(copy.isLine)copy.visible=false;
  for(const child of source.children)if(!child.userData.vehicleRenderBatch)copy.add(clonePart(child));return copy;
 }
 function detach(id,contact={},velocityState=getState()){
  const source=parts.get(id);if(!source||!source.visible||hidden.has(source))return false;
  if(id==='trunk'&&trunk){const result=trunk.detach({contact,vehicleState:velocityState,reason:'crash'});if(result!==false)return true}
  car.object.updateWorldMatrix(true,true);root.updateWorldMatrix(true,false);const copy=clonePart(source),world=source.matrixWorld.clone(),position=new T.Vector3(),q=new T.Quaternion(),scale=new T.Vector3();world.decompose(position,q,scale);
  matrix.copy(root.matrixWorld).invert().multiply(world).decompose(copy.position,copy.quaternion,copy.scale);root.add(copy);hidden.set(source,source.visible);source.visible=false;source.userData.crashDetached=true;
  const box=new T.Box3().setFromObject(copy),size=box.getSize(new T.Vector3()),normal=contact.normal||{x:0,y:0,z:1},impact=Math.min(24,contact.impactSpeed||8),yaw=velocityState.travelYaw??velocityState.yaw??0,speed=velocityState.speed||0;
  const seed=[...id].reduce((v,c)=>v*31+c.charCodeAt(0),state.impacts+1)>>>0,random=offset=>Math.sin(seed+offset*2.399)*.5+.5;
  const body=createCrashDebrisState({position:{x:position.x,y:position.y,z:position.z},quaternion:{x:q.x,y:q.y,z:q.z,w:q.w},velocity:{x:Math.sin(yaw)*speed*.72-normal.x*impact*.15+(random(1)-.5)*3,y:1.3+impact*.12+random(2),z:Math.cos(yaw)*speed*.72-normal.z*impact*.15+(random(3)-.5)*3},angularVelocity:{x:(random(4)-.5)*7,y:(random(5)-.5)*7,z:(random(6)-.5)*7},radius:Math.max(.04,Math.min(size.x,size.y,size.z)*.5),massKg:id.startsWith('wheel')?24:18});
  const localBox=copy.geometry?.boundingBox?.clone()||new T.Box3(new T.Vector3(-size.x/2,-size.y/2,-size.z/2),new T.Vector3(size.x/2,size.y/2,size.z/2));debris.push({id,mesh:copy,body,scale,localBox,grounded:false});return true;
 }
 function contactImpact(contact){
  if(disposed||!contact?.point||!contact?.normal)return false;car.object.updateWorldMatrix(true,false);inverse.copy(car.object.matrixWorld).invert();p.set(contact.point.x,contact.point.y,contact.point.z).applyMatrix4(inverse);delta.set(contact.normal.x,contact.normal.y,contact.normal.z).transformDirection(inverse);
  const result=applyCrashMechanicsImpact(state,{...contact,point:{x:p.x,y:p.y,z:p.z},normal:{x:delta.x,y:delta.y,z:delta.z}});if(!result.applied)return false;deform();for(const id of result.detached)detach(id,contact);return true;
 }
 function isIdle(){const thermal=(state.radiator<.8&&state.engine>.015)||state.temperature>0;return !thermal&&!state.active&&debris.every(item=>item.body.settled&&item.grounded)}
 function update(dt){if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid crash timestep');if(isIdle()){idleUpdates++;return}time+=dt;const drive=getState();stepCrashMechanics(state,dt,{speed:drive.speed,throttle:drive.throttle});if(state.impacts)deform();
  let debrisRootReady=false;
  for(const item of debris){if(item.body.settled&&item.grounded)continue;const body=item.body,oldX=body.position.x,oldZ=body.position.z;stepCrashDebris(body,dt,groundHeight);if(!allowed(body.position.x,body.position.z,body.position.y)){body.position.x=oldX;body.position.z=oldZ;body.velocity.x*=-.18;body.velocity.z*=-.18}p.set(body.position.x,body.position.y,body.position.z);debrisQuaternion.set(body.quaternion.x,body.quaternion.y,body.quaternion.z,body.quaternion.w);matrix.compose(p,debrisQuaternion,item.scale);if(!debrisRootReady){root.updateWorldMatrix(true,false);inverse.copy(root.matrixWorld).invert();debrisRootReady=true;}matrix.premultiply(inverse).decompose(item.mesh.position,item.mesh.quaternion,item.mesh.scale);
   if(body.settled&&!item.grounded){item.mesh.updateWorldMatrix(true,true);const box=new T.Box3().setFromObject(item.mesh),floor=groundHeight(body.position.x,body.position.z);item.mesh.position.y+=floor+.015-box.min.y;item.grounded=true}
  }
 }
 function applyWheels({tyres=[]}={}){if(!state.impacts)return;const effects=crashDriveEffects(state);for(const wheel of car.wheels||[]){const damage=effects.wheels[wheel.id],rest=wheelRest.get(wheel.id);if(!damage||!rest)continue;if(damage.detached){wheel.pivot.visible=false;continue}const tyre=tyres.find(item=>item.id===wheel.id),tyreDrop=tyre?.detached?.16:tyre?Math.max(0,Math.min(1,1-tyre.pressure))*.1:0;wheel.pivot.rotation.y=(wheel.front?(getState().steer||0):0)+damage.toe;wheel.pivot.rotation.z=rest.rotation.z+damage.camber;wheel.pivot.position.x=rest.position.x+Math.sign(rest.position.x)*damage.sag*.2;wheel.pivot.position.y=rest.position.y-tyreDrop-damage.sag;wheel.pivot.position.z=rest.position.z-Math.sign(rest.position.z)*damage.sag*.4}}
 function clearDebris(){const count=debris.length;for(const item of debris){item.mesh.removeFromParent();const gs=new Set(),ms=new Set();item.mesh.traverse(n=>{if(n.geometry)gs.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])ms.add(m)});for(const g of gs)g.dispose();for(const m of ms)m.dispose()}debris.length=0;return count}
 function reset(){clearDebris();for(const [source,visible]of hidden){source.visible=visible;delete source.userData.crashDetached}hidden.clear();for(const [mesh,original]of geometryRest){if(mesh.geometry!==original)mesh.geometry.dispose();mesh.geometry=original}geometryRest.clear();bindings.clear();for(const wheel of car.wheels||[]){const rest=wheelRest.get(wheel.id);wheel.pivot.position.copy(rest.position);wheel.pivot.rotation.copy(rest.rotation);wheel.pivot.visible=rest.visible}resetCrashMechanics(state);lastRevision=-1;idleUpdates=0}
 function dispose(){if(disposed)return;reset();disposed=true;root.removeFromParent()}
 return{state,root,contactImpact,update,applyWheels,detach,clearDebris,reset,dispose,get isIdle(){return isIdle()},get effects(){return crashDriveEffects(state)},stats:()=>({impacts:state.impacts,crushM:state.maxCrush,engine:state.engine,radiator:state.radiator,steering:state.steering,temperature:state.temperature,detached:[...state.detachedParts],debris:debris.length,active:state.active,idleUpdates,nodeCount:state.nodes.length,beamCount:state.beams.length,brokenBeams:state.beams.filter(b=>b.broken).length,effects:crashDriveEffects(state)})};
}
