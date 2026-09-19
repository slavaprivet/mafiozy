// Temporary inspection car; not a replacement for authoritative game vehicles.
import {createVehicleInterior,SEDAN_DRIVER_SEAT} from './vehicle_interiors.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
import {stepVehicleDynamics} from './vehicle_dynamics.mjs';
import {moveVehicleWithContacts} from './vehicle_contact_motion.mjs';
import {collisionPolygon,collisionCircleOverlap} from './vehicle_collision_shape.mjs';
import {createDetailedVehicleWheel,createWheelArch,updateVehicleWheelVisuals} from './vehicle_wheels.mjs';
import {applyVehicleInteriorColors} from './vehicle_interior_colors.mjs';
export const CAR=Object.freeze({halfWidth:1.28,halfLength:2.24,wheelBase:2.65,wheelRadius:.4,maxSpeed:22,reverseSpeed:6});
// +Z is the car's forward axis: driver's left is +X, right is -X.
export const DRIVER_SEAT=SEDAN_DRIVER_SEAT;
export function carOverlapsCircle(car,x,z,radius=.36){return collisionCircleOverlap(car,x,z,radius,car.vehicleProfile||CAR)}
export function carCorners(x,z,yaw,shape=CAR){return collisionPolygon(x,z,yaw,shape)}
export function pointInPolygon(x,z,polygon){let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])inside=!inside}return inside}
function polygonsOverlap(a,b){
 // Static-body overlap runs inside every driving query.  Preserve the
 // previous vertex order and early exits without allocating callbacks.
 for(let i=0;i<a.length;i++){const point=a[i];if(pointInPolygon(point[0],point[1],b))return true}
 for(let i=0;i<b.length;i++){const point=b[i];if(pointInPolygon(point[0],point[1],a))return true}
 const cross=(p,q,r)=>(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0]);
 for(let i=0;i<a.length;i++)for(let j=0;j<b.length;j++){const p=a[i],q=a[(i+1)%a.length],r=b[j],s=b[(j+1)%b.length];if(Math.max(p[0],q[0])<Math.min(r[0],s[0])||Math.max(r[0],s[0])<Math.min(p[0],q[0])||Math.max(p[1],q[1])<Math.min(r[1],s[1])||Math.max(r[1],s[1])<Math.min(p[1],q[1]))continue;if(cross(p,q,r)*cross(p,q,s)<=0&&cross(r,s,p)*cross(r,s,q)<=0)return true}return false;
}
export function createCarWorld(topology,bodies,meters=4.1,{surfaceAt}={}){
 // Flat grass, paving and low curbs are traversable; water and solid obstacles are not.
 const surface=(x,z)=>{const override=surfaceAt?.(x,z);if(override!==undefined&&override!==null)return !!override;const r=Math.floor(z/meters),c=Math.floor(x/meters);return [0,8,9,19].includes(topology.grid?.[r]?.[c])&&!topology.policeMask?.[r]?.[c]};
 const buckets=new Map(),polygonIds=new Map(),visitedEpoch=[];let queryEpoch=0;
 const bucketAt=(r,c)=>buckets.get(r)?.get(c);
 for(const body of bodies){if(body.maxYM<=.22||body.minYM>1.95||!body.polygonCR?.length)continue;const polygon=body.polygonCR.map(p=>[p[0]*meters,p[1]*meters]),polygonId=polygonIds.size;polygonIds.set(polygon,polygonId);let minX=Infinity,maxX=-Infinity,minZ=Infinity,maxZ=-Infinity;for(const point of body.polygonCR){minX=Math.min(minX,point[0]);maxX=Math.max(maxX,point[0]);minZ=Math.min(minZ,point[1]);maxZ=Math.max(maxZ,point[1])}for(let r=Math.floor(minZ);r<=Math.floor(maxZ);r++)for(let c=Math.floor(minX);c<=Math.floor(maxX);c++){let row=buckets.get(r);if(!row){row=new Map();buckets.set(r,row)}let bucket=row.get(c);if(!bucket){bucket=[];row.set(c,bucket)}bucket.push(polygon)}}
 const nextQueryEpoch=()=>{if(queryEpoch===Number.MAX_SAFE_INTEGER){visitedEpoch.fill(0);queryEpoch=0}return ++queryEpoch};
 const allowed=(x,z)=>{
  if(!surface(x,z))return false;
  const bucket=bucketAt(Math.floor(z/meters),Math.floor(x/meters));
  if(!bucket)return true;
  // Keep the authored bucket order, but avoid an Array#some callback for
  // every sampled wheel/foot point.
  for(let i=0;i<bucket.length;i++)if(pointInPolygon(x,z,bucket[i]))return false;
  return true;
 };
 allowed.poseAllowed=(x,z,yaw,shape=CAR)=>{const box=carCorners(x,z,yaw,shape);let minX=Infinity,maxX=-Infinity,minZ=Infinity,maxZ=-Infinity;for(const point of box){minX=Math.min(minX,point[0]);maxX=Math.max(maxX,point[0]);minZ=Math.min(minZ,point[1]);maxZ=Math.max(maxZ,point[1])}const epoch=nextQueryEpoch();for(let r=Math.floor(minZ/meters);r<=Math.floor(maxZ/meters);r++)for(let c=Math.floor(minX/meters);c<=Math.floor(maxX/meters);c++){
  if(!surface((c+.5)*meters,(r+.5)*meters)&&polygonsOverlap(box,[[c*meters,r*meters],[(c+1)*meters,r*meters],[(c+1)*meters,(r+1)*meters],[c*meters,(r+1)*meters]]))return false;
  for(const polygon of bucketAt(r,c)||[]){const id=polygonIds.get(polygon);if(visitedEpoch[id]===epoch)continue;visitedEpoch[id]=epoch;if(polygonsOverlap(box,polygon))return false}
 }return true};
 allowed.contactAt=(x,z,yaw,shape=CAR)=>{
  const box=carCorners(x,z,yaw,shape);let minX=Infinity,maxX=-Infinity,minZ=Infinity,maxZ=-Infinity;for(const point of box){minX=Math.min(minX,point[0]);maxX=Math.max(maxX,point[0]);minZ=Math.min(minZ,point[1]);maxZ=Math.max(maxZ,point[1])}const epoch=nextQueryEpoch();let best=null;
  const consider=polygon=>{const contact=polygonVehicleContact(box,polygon);if(contact&&(!best||contact.depth>best.depth))best=contact};
  for(let r=Math.floor(minZ/meters);r<=Math.floor(maxZ/meters);r++)for(let c=Math.floor(minX/meters);c<=Math.floor(maxX/meters);c++){
   if(!surface((c+.5)*meters,(r+.5)*meters))consider([[c*meters,r*meters],[(c+1)*meters,r*meters],[(c+1)*meters,(r+1)*meters],[c*meters,(r+1)*meters]]);
   for(const polygon of bucketAt(r,c)||[]){const id=polygonIds.get(polygon);if(visitedEpoch[id]===epoch)continue;visitedEpoch[id]=epoch;consider(polygon)}
  }return best;
 };return allowed;
}
export function carFits(x,z,yaw,allowed,shape=CAR){
 if(![x,z,yaw].every(Number.isFinite))return false;
 if(allowed.poseAllowed)return allowed.poseAllowed(x,z,yaw,shape);
 if(shape.collisionHull?.length){
  const poly=carCorners(x,z,yaw,shape),xs=poly.map(p=>p[0]),zs=poly.map(p=>p[1]);
  for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/.25));for(let j=0;j<=n;j++)if(!allowed(a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n))return false;}
  for(let px=Math.min(...xs);px<=Math.max(...xs);px+=.3)for(let pz=Math.min(...zs);pz<=Math.max(...zs);pz+=.3)if(pointInPolygon(px,pz,poly)&&!allowed(px,pz))return false;
  return true;
 }
 const sin=Math.sin(yaw),cos=Math.cos(yaw);
 for(let i=0;i<=6;i++)for(let j=0;j<=14;j++){
  const side=-shape.halfWidth+i*shape.halfWidth/3,front=-shape.halfLength+j*shape.halfLength/7;
  if(!allowed(x+side*cos+front*sin,z-side*sin+front*cos))return false;
 }return true;
}
export function stepCar(state,input,dt,allowed){
 if(!Number.isFinite(dt)||![state.x,state.z,state.yaw,state.speed].every(Number.isFinite))throw Error('Invalid car state/time');
 dt=Math.min(.1,Math.max(0,dt));const shape={...CAR,...state.vehicleProfile},n=Math.max(1,Math.ceil(dt/(1/120))),h=dt/n;
 let current=state,distance=0,bumped=false,contact=null;
 const queries={shape,fits:(x,z,yaw,p)=>carFits(x,z,yaw,allowed,p),contactAt:allowed.contactAt?.bind(allowed)};
 for(let i=0;i<n;i++){
  const next=stepVehicleDynamics(current,input,h,shape),moved=moveVehicleWithContacts(current,next,h,queries);
  distance+=moved.distance;bumped||=moved.bumped;
  if(moved.contact&&(!contact||moved.contact.impactSpeed>contact.impactSpeed))contact=moved.contact;
  current=moved;
  // The fleet applies the two-body impulse once, using velocity at contact.
  if(moved.contact?.otherVehicle)break;
 }
 return {...current,distance,bumped,contact};
}
export function createDemoCar(T,RoundedBox){
 const object=new T.Group();object.name='Demo_drive_sedan';
 const paint=new T.MeshStandardMaterial({color:'#8c293e',roughness:.55,metalness:.12}),glass=new T.MeshStandardMaterial({color:'#aac6c3',roughness:.2,metalness:.08,transparent:true,opacity:.23,depthWrite:false}),trim=new T.MeshStandardMaterial({color:'#c4b993',roughness:.45,metalness:.45}),rubber=new T.MeshStandardMaterial({color:'#20292c',roughness:.9});
 glass.name='Automotive_Glass';glass.userData.breakableGlass=true;
 function box(w,h,d,x,y,z,mat,round=.12){const mesh=new T.Mesh(new RoundedBox(w,h,d,3,round),mat);mesh.position.set(x,y,z);mesh.castShadow=mesh.receiveShadow=true;object.add(mesh);return mesh}
 const shell=[];
 function solid(name,w,h,d,x,y,z,mat=paint,round=.02){const mesh=box(w,h,d,x,y,z,mat,round);mesh.name=name;mesh.userData.bodyBox={min:[x-w/2,y-h/2,z-d/2],max:[x+w/2,y+h/2,z+d/2]};shell.push(mesh);return mesh}
 function archedPanel(name,from,to,bottom,top,side,inner=.88,outer=.97,parent=object,offsetZ=0,offsetY=0){
  const vertices=[],segments=48;
  const lower=z=>Math.max(bottom,...[-1.35,1.3].map(center=>Math.abs(z-center)<.48?CAR.wheelRadius+Math.sqrt(.48**2-(z-center)**2):bottom));
  const face=(a,b,c,d)=>vertices.push(...a,...b,...c,...a,...c,...d);
  for(let i=0;i<segments;i++){
   const z0=from+(to-from)*i/segments,z1=from+(to-from)*(i+1)/segments,l0=lower(z0),l1=lower(z1),x0=side>0?inner:-outer,x1=side>0?outer:-inner;
   const a=[x0,l0,z0],b=[x1,l0,z0],c=[x1,top,z0],d=[x0,top,z0],e=[x0,l1,z1],f=[x1,l1,z1],g=[x1,top,z1],h=[x0,top,z1];
   face(a,d,c,b);face(e,f,g,h);face(a,e,h,d);face(b,c,g,f);face(d,h,g,c);face(a,b,f,e);
  }
  const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(vertices,3));geo.computeVertexNormals();
  const mesh=new T.Mesh(geo,paint);mesh.name=name;mesh.position.set(-side*.92*(parent!==object),-offsetY,-offsetZ);mesh.castShadow=mesh.receiveShadow=true;mesh.material.side=T.DoubleSide;parent.add(mesh);
  mesh.userData.wheelArch={from,to,bottom,top,side,inner,outer,radius:.48};shell.push(mesh);return mesh;
 }
 // Open cabin: the old full-volume body box intersected both seats and legs.
 solid('Central_underbody',1.10,.20,4.25,0,.29,0,paint,.04);box(1.88,.14,2.72,0,2.14,-.36,paint,.035);
 solid('Engine_core',1.10,.50,1.29,0,.70,1.50,paint,.04);
 solid('Hood_lid',1.91,.14,1.31,0,1.045,1.49,paint,.045);
 solid('Trunk_lid',1.91,.17,.52,0,.99,-1.89,paint,.035);
 solid('Trunk_core',1.10,.51,.54,0,.67,-1.87,paint,.03);
 solid('Windshield_cowl',1.88,.16,.20,0,1.075,.85,paint,.025);
 solid('Cabin_firewall',1.58,.59,.08,0,.695,.795,rubber,.015);
 solid('Rear_bulkhead',1.56,.68,.06,0,.74,-1.64,rubber,.015);
 for(const side of [-1,1]){
  archedPanel('Front_fender_'+side,.84,2.15,.39,1.06,side,.56,.96);
  archedPanel('Rear_quarter_'+side,-2.15,-1.60,.39,1.05,side,.56,.96);
  solid('Front_door_jamb_'+side,.105,.67,.09,side*.90,.73,.80,paint,.012);
  solid('Rear_door_jamb_'+side,.105,.25,.09,side*.90,.96,-1.625,paint,.012);
 }
 box(1.73,.99,.035,0,1.56,.87,glass,.01);box(1.73,.99,.035,0,1.56,-1.63,glass,.01);
 for(const z of [.87,-1.63])box(1.84,.09,.09,0,2.055,z,paint,.015);
 const doors=new Map(),doorAnchors=[];for(const side of [-1,1])for(const rear of [false,true]){
  const front=rear?-.61:.84,length=rear?.98:1.41,id=(rear?'rear_':'front_')+(side>0?'left':'right');
  const door=new T.Group();door.name='Door_'+id;door.position.set(side*.92,.96,front);object.add(door);doors.set(rear?id:side,door);doorAnchors.push({id,side,front,rear,handle:{side:side*1.015,front:front-length+.17,y:1.005}});
  const part=(w,h,d,x,y,z,mat)=>{const mesh=new T.Mesh(new RoundedBox(w,h,d,3,.035),mat);mesh.position.set(x,y,z);mesh.castShadow=true;door.add(mesh);return mesh};
  if(rear)archedPanel('Rear_door_arch_'+side,front-length,front,.455,1.045,side,.87,.97,door,front,.96);else part(.10,.59,length,0,-.21,-length/2,paint);
  part(.035,.94,length-.10,0,.58,-length/2,glass);part(.085,.09,length,0,1.075,-length/2,paint);
  part(.095,.065,length,0,.10,-length/2,paint);
  for(const end of [-.035,-length+.035])part(.09,.99,.065,0,.57,end,paint);
  part(.12,.055,.19,side*.065,.045,-length+.17,trim);
  part(.035,rear?.16:.38,length-.13,-side*.074,rear?.075:-.14,-length/2,rubber).name='Door_inner_'+id;part(.09,.07,.40,-side*.12,rear?.10:-.02,-length*.48,trim).name='Door_armrest_'+id;
 }
 for(const x of [-.87,.87]){for(const z of [-1.64,-.59,.87])box(.11,1.21,.09,x,1.52,z,paint,.015);box(.22,.13,.3,x*1.16,1.28,.74,paint,.04);solid('Sill_'+x,.16,.12,1.64,x,.44,-.015,trim,.015)}
 const interior=createVehicleInterior(T,RoundedBox,{family:'sedan4'});object.add(interior.object);
 box(.68,.23,.06,0,.73,2.15,rubber,.02);
 const brakeLight=new T.MeshStandardMaterial({color:'#9f2330',emissive:'#d52b34',emissiveIntensity:.2});
 for(const z of [-2.14,2.14])box(1.65,.18,.1,0,.61,z,trim,.04).name=z>0?'Bumper_front':'Bumper_rear';
 for(const x of [-.62,.62]){box(.4,.2,.08,x,.92,2.14,new T.MeshStandardMaterial({color:'#fff0be',emissive:'#ffe5a1',emissiveIntensity:.5}),.04);box(.38,.18,.08,x,.92,-2.14,brakeLight,.04)}
 const wheels=[];for(const x of [-.92,.92])for(const z of [-1.35,1.3]){
  const pivot=new T.Group();pivot.position.set(x,CAR.wheelRadius,z);
  const id=(z>0?'front_':'rear_')+(x>0?'left':'right');pivot.name='Wheel_attachment_'+id;pivot.userData.vehicleWheelId=id;
  const detail=createDetailedVehicleWheel(T,{id,radius:CAR.wheelRadius,width:.24,side:Math.sign(x),family:'classic'});pivot.add(detail.wheel);
  object.add(pivot);wheels.push({id,pivot,...detail,front:z>0,rollingRadius:CAR.wheelRadius,restPosition:pivot.position.clone()});
  const arch=createWheelArch(T,{id,center:pivot.position,radius:CAR.wheelRadius,width:.24,front:z>0,side:Math.sign(x),outerX:.973,paint});object.add(arch);arch.traverse(n=>{if(n.isMesh)shell.push(n)});
 }
 function update(state,braking=false){updateVehicleWheelVisuals(wheels,state,CAR.wheelRadius);interior.update(state);brakeLight.emissiveIntensity=braking||state.handbrake?2.3:.2}
 const setRearDoor=(amount,side=1)=>{const door=doors.get('rear_'+(side>0?'left':'right'));door.rotation.y=-side*Math.max(0,Math.min(1,amount))*1.1};
 function setDoorById(amount,id){const key=id==='front_left'?1:id==='front_right'?-1:id;if(!doors.has(key))throw Error('Unknown vehicle door '+id);for(const [doorKey,door]of doors){const side=typeof doorKey==='number'?doorKey:doorKey.endsWith('left')?1:-1;door.rotation.y=doorKey===key?-side*Math.max(0,Math.min(1,amount))*1.1:0}}
 const outlines=new Map(),outlineMaterial=new T.LineBasicMaterial({color:'#f6cd74',transparent:true,opacity:.86,depthWrite:false});
 for(const [id,door]of doors){const vertices=[],point=new T.Vector3();for(const child of door.children){if(!child.isMesh)continue;child.updateMatrix();const edges=new T.EdgesGeometry(child.geometry,35),p=edges.attributes.position;for(let i=0;i<p.count;i++){point.fromBufferAttribute(p,i).applyMatrix4(child.matrix);vertices.push(point.x,point.y,point.z)}edges.dispose()}const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(vertices,3));const outline=new T.LineSegments(g,outlineMaterial);outline.name='Selected_door_outline';outline.visible=false;outline.raycast=()=>{};outline.renderOrder=2;door.add(outline);outlines.set(id,outline)}
 function setHighlightedDoor(id=null){const key=id==='front_left'?1:id==='front_right'?-1:id;for(const [doorId,outline]of outlines)outline.visible=doorId===key}
 applyVehicleInteriorColors(object,'red_demo');
 return{object,wheels,interior,doors,shell,anchors:{...interior.anchors,doors:doorAnchors},getSteeringGrips:interior.getSteeringGrips,update,setRearDoor,setDoorById,setHighlightedDoor,setDoor:(amount,side=1)=>{if(typeof side==='string'){setDoorById(amount,side);return}for(const [s,door]of doors)if(typeof s==='number')door.rotation.y=s===side?-s*Math.max(0,Math.min(1,amount))*1.1:0}};
}
