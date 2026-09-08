// Temporary inspection car; not a replacement for authoritative game vehicles.
import {createVehicleInterior,SEDAN_DRIVER_SEAT} from './vehicle_interiors.mjs';
import {polygonVehicleContact,contactKinematics} from './vehicle_contact.mjs';
export const CAR=Object.freeze({halfWidth:1.28,halfLength:2.24,wheelBase:2.65,wheelRadius:.4,maxSpeed:22,reverseSpeed:6});
// +Z is the car's forward axis: driver's left is +X, right is -X.
export const DRIVER_SEAT=SEDAN_DRIVER_SEAT;
export function carOverlapsCircle(car,x,z,radius=.36){const dx=x-car.x,dz=z-car.z,sin=Math.sin(car.yaw),cos=Math.cos(car.yaw),side=Math.abs(dx*cos-dz*sin),front=Math.abs(dx*sin+dz*cos);return (side<CAR.halfWidth&&front<CAR.halfLength)||Math.hypot(Math.max(0,side-CAR.halfWidth),Math.max(0,front-CAR.halfLength))<radius}
const approach=(value,target,amount)=>value+Math.sign(target-value)*Math.min(Math.abs(target-value),amount);
const angleDelta=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
export function carCorners(x,z,yaw){const sin=Math.sin(yaw),cos=Math.cos(yaw);return [[-1,-1],[1,-1],[1,1],[-1,1]].map(([a,b])=>[x+a*CAR.halfWidth*cos+b*CAR.halfLength*sin,z-a*CAR.halfWidth*sin+b*CAR.halfLength*cos])}
export function pointInPolygon(x,z,polygon){let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])inside=!inside}return inside}
function polygonsOverlap(a,b){
 if(a.some(p=>pointInPolygon(...p,b))||b.some(p=>pointInPolygon(...p,a)))return true;
 const cross=(p,q,r)=>(q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0]);
 for(let i=0;i<a.length;i++)for(let j=0;j<b.length;j++){const p=a[i],q=a[(i+1)%a.length],r=b[j],s=b[(j+1)%b.length];if(Math.max(p[0],q[0])<Math.min(r[0],s[0])||Math.max(r[0],s[0])<Math.min(p[0],q[0])||Math.max(p[1],q[1])<Math.min(r[1],s[1])||Math.max(r[1],s[1])<Math.min(p[1],q[1]))continue;if(cross(p,q,r)*cross(p,q,s)<=0&&cross(r,s,p)*cross(r,s,q)<=0)return true}return false;
}
export function createCarWorld(topology,bodies,meters=4.1){
 // Flat grass, paving and low curbs are traversable; water and solid obstacles are not.
 const surface=(x,z)=>{const r=Math.floor(z/meters),c=Math.floor(x/meters);return [0,8,9,19].includes(topology.grid?.[r]?.[c])&&!topology.policeMask?.[r]?.[c]};
 const buckets=new Map();for(const body of bodies){if(body.maxYM<=.22||body.minYM>1.95||!body.polygonCR?.length)continue;const polygon=body.polygonCR.map(p=>[p[0]*meters,p[1]*meters]),xs=body.polygonCR.map(p=>p[0]),zs=body.polygonCR.map(p=>p[1]);for(let r=Math.floor(Math.min(...zs));r<=Math.floor(Math.max(...zs));r++)for(let c=Math.floor(Math.min(...xs));c<=Math.floor(Math.max(...xs));c++){const key=r+','+c;if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(polygon)}}
 const allowed=(x,z)=>surface(x,z)&&!(buckets.get(Math.floor(z/meters)+','+Math.floor(x/meters))||[]).some(p=>pointInPolygon(x,z,p));
 allowed.poseAllowed=(x,z,yaw)=>{const box=carCorners(x,z,yaw),xs=box.map(p=>p[0]),zs=box.map(p=>p[1]),checked=new Set();for(let r=Math.floor(Math.min(...zs)/meters);r<=Math.floor(Math.max(...zs)/meters);r++)for(let c=Math.floor(Math.min(...xs)/meters);c<=Math.floor(Math.max(...xs)/meters);c++){
  if(!surface((c+.5)*meters,(r+.5)*meters)&&polygonsOverlap(box,[[c*meters,r*meters],[(c+1)*meters,r*meters],[(c+1)*meters,(r+1)*meters],[c*meters,(r+1)*meters]]))return false;
  for(const polygon of buckets.get(r+','+c)||[]){if(checked.has(polygon))continue;checked.add(polygon);if(polygonsOverlap(box,polygon))return false}
 }return true};
 allowed.contactAt=(x,z,yaw)=>{
  const box=carCorners(x,z,yaw),xs=box.map(p=>p[0]),zs=box.map(p=>p[1]),checked=new Set();let best=null;
  const consider=polygon=>{const contact=polygonVehicleContact(box,polygon);if(contact&&(!best||contact.depth>best.depth))best=contact};
  for(let r=Math.floor(Math.min(...zs)/meters);r<=Math.floor(Math.max(...zs)/meters);r++)for(let c=Math.floor(Math.min(...xs)/meters);c<=Math.floor(Math.max(...xs)/meters);c++){
   if(!surface((c+.5)*meters,(r+.5)*meters))consider([[c*meters,r*meters],[(c+1)*meters,r*meters],[(c+1)*meters,(r+1)*meters],[c*meters,(r+1)*meters]]);
   for(const polygon of buckets.get(r+','+c)||[]){if(checked.has(polygon))continue;checked.add(polygon);consider(polygon)}
  }return best;
 };return allowed;
}
export function carFits(x,z,yaw,allowed){
 if(![x,z,yaw].every(Number.isFinite))return false;
 if(allowed.poseAllowed)return allowed.poseAllowed(x,z,yaw);
 const sin=Math.sin(yaw),cos=Math.cos(yaw);
 for(let i=0;i<=6;i++)for(let j=0;j<=14;j++){
  const side=-CAR.halfWidth+i*CAR.halfWidth/3,front=-CAR.halfLength+j*CAR.halfLength/7;
  if(!allowed(x+side*cos+front*sin,z-side*sin+front*cos))return false;
 }return true;
}
export function stepCar(state,input,dt,allowed){
 if(!Number.isFinite(dt)||![state.x,state.z,state.yaw,state.speed].every(Number.isFinite))throw Error('Invalid car state/time');
 dt=Math.min(.1,Math.max(0,dt));let {x,z,yaw,speed}=state,steer=state.steer||0,travelYaw=state.travelYaw??yaw,distance=0,bumped=false,yawRate=state.yawRate||0,braking=false,frontSlip=0,rearSlip=0,contact=null;
 const handbrake=!!(input.handbrake||input.brake),throttle=(input.forward?1:0)-(input.reverse?1:0),n=Math.max(1,Math.ceil(dt/(1/120))),h=dt/n;
 for(let i=0;i<n;i++){
  const tyre=state.tyreEffects||{},speedFactor=tyre.speedFactor??1,frontGrip=tyre.frontGrip??1,rearGrip=tyre.rearGrip??1;
  const limit=.56/(1+Math.abs(speed)*.045),target=((input.left?1:0)-(input.right?1:0))*limit;steer+=(target-steer)*(1-Math.exp(-8*h));
  braking=handbrake||!!(throttle&&speed*throttle<0);
  if(handbrake)speed=approach(speed,0,12*h);else if(braking)speed=approach(speed,0,11*h);else if(throttle)speed+=throttle*(throttle>0?6.5:4.5)*h;else speed=approach(speed,0,(.75+.012*speed*speed)*h);
  speed=Math.max(-CAR.reverseSpeed*speedFactor,Math.min(CAR.maxSpeed*speedFactor,speed));
  // Limit lateral acceleration at speed, while allowing the rear to slide with
  // the handbrake. Relaxing the steering restores grip smoothly after a drift.
  const requested=speed/CAR.wheelBase*Math.tan(steer)*(handbrake?1.25:1)+(tyre.pull||0)*Math.min(1,Math.abs(speed)/6)*Math.sign(speed);
  const yawLimit=(handbrake?14:10)*frontGrip/Math.max(2,Math.abs(speed));
  const targetYawRate=Math.max(-yawLimit,Math.min(yawLimit,requested));
  yawRate+=(targetYawRate-yawRate)*(1-Math.exp(-12*h));
  if(Math.abs(speed)<.02){yawRate=0;travelYaw=yaw}
  const newYaw=yaw+yawRate*h,cornerLoad=Math.min(1,Math.abs(requested*speed)/10);
  const grip=(handbrake?2.5:18-8*cornerLoad)*rearGrip;
  travelYaw+=angleDelta(newYaw,travelYaw)*(1-Math.exp(-grip*h));
  const slip=Math.abs(angleDelta(newYaw,travelYaw)),moving=Math.min(1,Math.abs(speed)/3);
  frontSlip=moving*Math.max(braking&&!handbrake?.7:0,Math.min(1,Math.max(0,Math.abs(requested*speed)-10)/12));
  rearSlip=moving*Math.max(handbrake?1:0,Math.min(1,Math.max(0,slip-.045)*7));
  const dx=Math.sin(travelYaw)*speed*h,dz=Math.cos(travelYaw)*speed*h;
  if(carFits(x+dx,z+dz,newYaw,allowed)){x+=dx;z+=dz;yaw=newYaw;distance+=Math.sign(speed)*Math.hypot(dx,dz)}else{
   const hit=allowed.contactAt?.(x+dx,z+dz,newYaw);if(hit){const candidate=contactKinematics(hit,speed,travelYaw);if(!contact||candidate.impactSpeed>contact.impactSpeed)contact=candidate}
   bumped=true;const candidates=Math.abs(dx)>Math.abs(dz)?[[dx,0],[0,dz]]:[[0,dz],[dx,0]];let slid=false;
   for(const [sx,sz] of candidates){if(Math.hypot(sx,sz)<Math.hypot(dx,dz)*.35)continue;if(carFits(x+sx,z+sz,yaw,allowed)){x+=sx;z+=sz;distance+=Math.sign(speed)*Math.hypot(sx,sz);speed*=Math.exp(-3*h);slid=true;break}}
   if(!slid){speed=0;yawRate=0;frontSlip=rearSlip=0;travelYaw=yaw;break}travelYaw=yaw;
  }
 }return{x,z,yaw,speed,steer,travelYaw,distance,bumped,contact,handbrake,braking,yawRate,slipAngle:angleDelta(yaw,travelYaw),frontSlip,rearSlip,tyreEffects:state.tyreEffects};
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
  const lower=z=>Math.max(bottom,...[-1.35,1.3].map(center=>Math.abs(z-center)<.48?.43+Math.sqrt(.48**2-(z-center)**2):bottom));
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
  const part=(w,h,d,x,y,z,mat)=>{const mesh=new T.Mesh(new RoundedBox(w,h,d,3,.035),mat);mesh.position.set(x,y,z);mesh.castShadow=true;door.add(mesh)};
  if(rear)archedPanel('Rear_door_arch_'+side,front-length,front,.455,1.045,side,.87,.97,door,front,.96);else part(.10,.59,length,0,-.21,-length/2,paint);
  part(.035,.94,length-.10,0,.58,-length/2,glass);part(.085,.09,length,0,1.075,-length/2,paint);
  part(.095,.065,length,0,.10,-length/2,paint);
  for(const end of [-.035,-length+.035])part(.09,.99,.065,0,.57,end,paint);
  part(.12,.055,.19,side*.065,.045,-length+.17,trim);
  part(.035,rear?.16:.38,length-.13,-side*.074,rear?.075:-.14,-length/2,rubber);part(.09,.07,.40,-side*.12,rear?.10:-.02,-length*.48,trim);
 }
 for(const x of [-.87,.87]){for(const z of [-1.64,-.59,.87])box(.11,1.21,.09,x,1.52,z,paint,.015);box(.22,.13,.3,x*1.16,1.28,.74,paint,.04);solid('Sill_'+x,.16,.12,1.64,x,.44,-.015,trim,.015)}
 const interior=createVehicleInterior(T,RoundedBox,{family:'sedan4'});object.add(interior.object);
 box(.68,.23,.06,0,.73,2.15,rubber,.02);
 const brakeLight=new T.MeshStandardMaterial({color:'#9f2330',emissive:'#d52b34',emissiveIntensity:.2});
 for(const z of [-2.14,2.14])box(1.65,.18,.1,0,.61,z,trim,.04);
 for(const x of [-.62,.62]){box(.4,.2,.08,x,.92,2.14,new T.MeshStandardMaterial({color:'#fff0be',emissive:'#ffe5a1',emissiveIntensity:.5}),.04);box(.38,.18,.08,x,.92,-2.14,brakeLight,.04)}
 const wheels=[];for(const x of [-.92,.92])for(const z of [-1.35,1.3]){
  const pivot=new T.Group();pivot.position.set(x,.43,z);const wheel=new T.Group();pivot.add(wheel);
  const id=(z>0?'front_':'rear_')+(x>0?'left':'right');pivot.userData.vehicleWheelId=id;wheel.userData.vehicleWheelId=id;
  const tire=new T.Mesh(new T.CylinderGeometry(.4,.4,.24,20),rubber);tire.name='Tyre_'+id;tire.userData.vehicleWheelId=id;tire.rotation.z=Math.PI/2;tire.castShadow=true;pivot.add(tire);
  const hub=new T.Mesh(new T.CylinderGeometry(.24,.24,.255,16),trim);hub.rotation.z=Math.PI/2;wheel.add(hub);
  for(let a=0;a<5;a++){const spoke=new T.Mesh(new T.BoxGeometry(.016,.055,.4),rubber);spoke.position.x=Math.sign(x)*.135;spoke.rotation.x=a*Math.PI/5;wheel.add(spoke)}
  object.add(pivot);wheels.push({id,pivot,wheel,tire,hub,front:z>0});
 }
 function update(state,braking=false){for(const item of wheels){item.pivot.rotation.y=item.front?state.steer||0:0;if(item.front||!state.handbrake)item.wheel.rotation.x+=(state.distance||0)/(item.rollingRadius||CAR.wheelRadius)}interior.update(state);brakeLight.emissiveIntensity=braking||state.handbrake?2.3:.2}
 const setRearDoor=(amount,side=1)=>{const door=doors.get('rear_'+(side>0?'left':'right'));door.rotation.y=-side*Math.max(0,Math.min(1,amount))*1.1};
 function setDoorById(amount,id){const key=id==='front_left'?1:id==='front_right'?-1:id;if(!doors.has(key))throw Error('Unknown vehicle door '+id);for(const [doorKey,door]of doors){const side=typeof doorKey==='number'?doorKey:doorKey.endsWith('left')?1:-1;door.rotation.y=doorKey===key?-side*Math.max(0,Math.min(1,amount))*1.1:0}}
 const outlines=new Map(),outlineMaterial=new T.LineBasicMaterial({color:'#f6cd74',transparent:true,opacity:.86,depthWrite:false});
 for(const [id,door]of doors){const vertices=[],point=new T.Vector3();for(const child of door.children){if(!child.isMesh)continue;child.updateMatrix();const edges=new T.EdgesGeometry(child.geometry,35),p=edges.attributes.position;for(let i=0;i<p.count;i++){point.fromBufferAttribute(p,i).applyMatrix4(child.matrix);vertices.push(point.x,point.y,point.z)}edges.dispose()}const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(vertices,3));const outline=new T.LineSegments(g,outlineMaterial);outline.name='Selected_door_outline';outline.visible=false;outline.raycast=()=>{};outline.renderOrder=2;door.add(outline);outlines.set(id,outline)}
 function setHighlightedDoor(id=null){const key=id==='front_left'?1:id==='front_right'?-1:id;for(const [doorId,outline]of outlines)outline.visible=doorId===key}
 return{object,wheels,interior,doors,shell,anchors:{...interior.anchors,doors:doorAnchors},getSteeringGrips:interior.getSteeringGrips,update,setRearDoor,setDoorById,setHighlightedDoor,setDoor:(amount,side=1)=>{if(typeof side==='string'){setDoorById(amount,side);return}for(const [s,door]of doors)if(typeof s==='number')door.rotation.y=s===side?-s*Math.max(0,Math.min(1,amount))*1.1:0}};
}
