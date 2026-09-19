// Physical wheel assemblies. +X is the axle; positive X rotation rolls toward +Z.
// Every visible tyre/rim fastener belongs to the rolling group and wheel mount.
export const VEHICLE_WHEEL_DESIGNS=Object.freeze({
 classic:{type:'domed-hubcap',holes:8,holeRing:.80,holeW:.095,holeH:.065,dish:.36,cap:.56,rim:.62,finish:'#ced1c8'},
 hatch:{type:'dark-stamped-steel',holes:8,holeRing:.69,holeW:.13,holeH:.13,dish:.28,cap:.20,rim:.62,finish:'#4b5357'},
 sedan:{type:'five-spoke-alloy',spokes:5,rim:.64,finish:'#bac2c1'},
 executive:{type:'fourteen-spoke-alloy',spokes:14,spokeWidth:.062,rim:.69,finish:'#d2cec0'},
 coupe:{type:'split-spoke-alloy',spokes:5,split:true,rim:.72,finish:'#c3cace'},
 wagon:{type:'steel-partial-cap',holes:12,holeRing:.76,holeW:.09,holeH:.14,dish:.48,cap:.43,rim:.61,finish:'#959e9d'},
 suv:{type:'deep-six-spoke',spokes:6,spokeWidth:.25,dish:.25,rim:.62,finish:'#a8aba5'},
 pickup:{type:'heavy-vented-steel',holes:8,holeRing:.70,holeW:.12,holeH:.18,dish:.23,cap:.29,rim:.57,finish:'#8b9695'},
 van:{type:'gray-service-steel',holes:10,holeRing:.69,holeW:.105,holeH:.105,dish:.56,cap:.22,rim:.56,finish:'#b1b7b6'},
 police:{type:'black-pursuit-steel',holes:16,holeRing:.75,holeW:.058,holeH:.085,dish:.32,cap:.32,rim:.60,finish:'#3c4448'},
 ambulance:{type:'white-service-steel',holes:6,holeRing:.71,holeW:.18,holeH:.12,dish:.48,cap:.33,rim:.58,finish:'#d9ddd2'},
 fire:{type:'bright-heavy-truck',holes:6,holeRing:.72,holeW:.17,holeH:.13,dish:.38,cap:.44,bolts:10,rim:.58,finish:'#d1d7d5'},
 bus:{type:'deep-truck-hub',holes:10,holeRing:.75,holeW:.08,holeH:.12,dish:.22,cap:.46,bolts:10,rim:.57,finish:'#aeb8ba'},
 city_taxi:{type:'taxi-stamped-small-cap',holes:9,holeRing:.74,holeW:.10,holeH:.12,dish:.40,cap:.27,rim:.61,finish:'#535a5c',polishedCap:true},
});

const renderBindings=new WeakMap();
// A palette is owned by one newly built car, never by a model/template cache.
// Individual loose tyres and crash/explosion debris retain their own clones.
export function createVehicleWheelMaterialPalette(T,{owner,family='sedan',designId=family}={}){
 if(!owner?.isObject3D)throw Error('Wheel palette requires its owning vehicle');
 const design=VEHICLE_WHEEL_DESIGNS[designId]||VEHICLE_WHEEL_DESIGNS[family]||VEHICLE_WHEEL_DESIGNS.sedan;
 return Object.freeze({owner,family,designId,materials:Object.freeze({
  rubber:new T.MeshStandardMaterial({color:'#23282a',roughness:.96}),
  treadRubber:new T.MeshStandardMaterial({color:'#303638',roughness:.98}),
  alloy:new T.MeshStandardMaterial({color:design.finish,metalness:.72,roughness:.31}),
  inset:new T.MeshStandardMaterial({color:'#444d51',metalness:.52,roughness:.58}),
  polished:new T.MeshStandardMaterial({color:'#d3d9d8',metalness:.85,roughness:.21}),
 })});
}
export function getVehicleWheelRenderBinding(mesh){return renderBindings.get(mesh)||null;}

function merged(T,items){
 const positions=[],normals=[];
 for(const {geometry,matrix} of items){const g=geometry.index?geometry.toNonIndexed():geometry.clone();if(matrix)g.applyMatrix4(matrix);positions.push(...g.attributes.position.array);normals.push(...g.attributes.normal.array);g.dispose();geometry.dispose()}
 const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('normal',new T.Float32BufferAttribute(normals,3));g.computeBoundingBox();g.computeBoundingSphere();return g;
}

export function createDetailedVehicleWheel(T,{id,radius=.4,width=.24,side=1,family='sedan',designId=family,materialPalette=null}={}){
 const design=VEHICLE_WHEEL_DESIGNS[designId]||VEHICLE_WHEEL_DESIGNS[family]||VEHICLE_WHEEL_DESIGNS.sedan,heavy=['bus','fire','van','ambulance','pickup'].includes(family);
 const rimRadius=radius*design.rim,half=width*.5;
 const rolling=new T.Group();rolling.name='Wheel_spin_'+id;rolling.userData={vehicleWheelId:id,wheelDesign:designId,wheelType:design.type,apertureRatio:design.holeRing||.81};
 if(materialPalette&&(materialPalette.family!==family||materialPalette.designId!==designId))throw Error('Wheel palette design mismatch');
 const {rubber,treadRubber,alloy,inset,polished}=materialPalette?.materials||{
  rubber:new T.MeshStandardMaterial({color:'#23282a',roughness:.96}),treadRubber:new T.MeshStandardMaterial({color:'#303638',roughness:.98}),alloy:new T.MeshStandardMaterial({color:design.finish,metalness:.72,roughness:.31}),inset:new T.MeshStandardMaterial({color:'#444d51',metalness:.52,roughness:.58}),polished:new T.MeshStandardMaterial({color:'#d3d9d8',metalness:.85,roughness:.21})};
 function mesh(name,geometry,material,parent=rolling){const m=new T.Mesh(geometry,material);m.name=name+'_'+id;m.userData.vehicleWheelId=id;m.castShadow=m.receiveShadow=true;parent.add(m);return m}
 function mergeInto(target,parts){
  const names=parts.map(n=>n.name),items=parts.map(n=>{n.updateMatrix();return {geometry:n.geometry,matrix:n.matrix.clone()}});
  target.geometry=merged(T,items);target.position.set(0,0,0);target.quaternion.identity();target.scale.set(1,1,1);target.userData.assembledParts=names;
  for(const part of parts)if(part!==target)part.removeFromParent();
  return target;
 }
 // Closed annular cross-section, with a recessed bead and shoulder. Axis Y is
 // retained locally for the tyre controller's existing radial scale.x contract.
 const section=[
  [rimRadius*.97,-half*.77],[radius*.75,-half*.95],[radius*.88,-half],
  [radius*.97,-half*.76],[radius*.99,-half*.57],
  [radius*.99,-half*.33],[radius*.969,-half*.29],[radius*.969,-half*.21],[radius*.99,-half*.17],
  [radius*.99,half*.17],[radius*.969,half*.21],[radius*.969,half*.29],[radius*.99,half*.33],
  [radius*.99,half*.57],[radius*.97,half*.76],[radius*.88,half],[radius*.75,half*.95],
  [rimRadius*.97,half*.77],[rimRadius*.965,-half*.77],
 ];
 const tire=mesh('Tyre',new T.LatheGeometry(section.map(([r,x])=>new T.Vector2(r,x)),32),rubber);tire.rotation.z=Math.PI/2;
 const tread=[];const matrix=new T.Matrix4(),q=new T.Quaternion(),scale=new T.Vector3(1,1,1);
 // Three staggered rows are one draw call. Small air gaps remain actual tread
 // grooves; the very outside of each block stays within the nominal radius.
 for(let row=-1;row<=1;row++)for(let i=0;i<32;i++){
  const a=(i+(row===0?.45:0))*Math.PI/16,block=new T.BoxGeometry(radius*.12,width*.19,radius*.018);
  q.setFromAxisAngle(new T.Vector3(0,1,0),a);
  matrix.compose(new T.Vector3(Math.sin(a)*radius*.987,row*width*.32,Math.cos(a)*radius*.987),q,scale);
  tread.push({geometry:block,matrix:matrix.clone()});
 }
 const treadMesh=mesh('Tyre_tread',merged(T,tread),treadRubber,tire);
 // Sidewall bead rings catch light and visually connect rubber to the flange.
 const beads=[];
 for(const s of [-1,1]){
  const ring=new T.TorusGeometry(radius*.895,radius*.008,4,32);ring.rotateX(Math.PI/2);ring.translate(0,s*half*.977,0);beads.push({geometry:ring});
 }
 const beadMesh=mesh('Tyre_sidewall_rings',merged(T,beads),treadRubber,tire);mergeInto(treadMesh,[treadMesh,beadMesh]);
 const barrel=mesh('Rim_barrel',new T.LatheGeometry([[rimRadius*.88,-half*.83],[rimRadius,-half*.90],[rimRadius,half*.90],[rimRadius*.88,half*.83],[rimRadius*.88,-half*.83]].map(([r,x])=>new T.Vector2(r,x)),32),alloy);barrel.rotation.z=Math.PI/2;
 const lips=[];for(const s of [-1,1]){const g=new T.TorusGeometry(rimRadius*.96,radius*.017,5,32);g.rotateY(Math.PI/2);g.translate(s*half*.91,0,0);lips.push({geometry:g})}const lipMesh=mesh('Rim_lips',merged(T,lips),polished);
 // Each spoke is a solid taper; its centre sits deeper than its rim end.
 const vertices=[];const face=(a,b,c,d)=>vertices.push(...a,...b,...c,...a,...c,...d);
 const spoke=(s,angle,spread)=>{
  const inner=radius*.135,outer=rimRadius*.91,ri=angle-spread,ro=angle+spread*.48;
  const point=(x,r,a)=>[s*x,Math.sin(a)*r,Math.cos(a)*r];
  const a=point(half*(design.dish||.40),inner,angle-spread),b=point(half*(design.dish||.40),inner,angle+spread),c=point(half*.78,outer,ro),d=point(half*.78,outer,ri),back=radius*.035;
  const e=[a[0]-s*back,a[1],a[2]],f=[b[0]-s*back,b[1],b[2]],g=[c[0]-s*back,c[1],c[2]],h=[d[0]-s*back,d[1],d[2]];
  face(a,b,c,d);face(e,h,g,f);face(a,e,f,b);face(b,f,g,c);face(c,g,h,d);face(d,h,e,a);
 };
 let spokes;
 if(design.holes){
  // These are through-holes in a thick stamped dish, not dark circles pasted
  // onto a solid disc. Different fleets have different vent/cap tooling.
  const plates=[];
  for(const s of [-1,1]){
   const shape=new T.Shape();for(let i=0;i<=32;i++){const a=i*Math.PI/16,x=Math.cos(a)*rimRadius*.91,y=Math.sin(a)*rimRadius*.91;if(i===0)shape.moveTo(x,y);else shape.lineTo(x,y)}shape.closePath();
   for(let i=0;i<design.holes;i++){const a=i*Math.PI*2/design.holes,hole=new T.Path();hole.absellipse(Math.sin(a)*rimRadius*design.holeRing,Math.cos(a)*rimRadius*design.holeRing,rimRadius*design.holeW,rimRadius*design.holeH,0,Math.PI*2,true,-a);shape.holes.push(hole)}
   const g=new T.ExtrudeGeometry(shape,{depth:radius*.04,bevelEnabled:false,curveSegments:6,steps:1});g.rotateY(Math.PI/2);g.translate(s*half*design.dish-radius*.02,0,0);plates.push({geometry:g});
  }
  spokes=mesh('Stamped_steel_dish',merged(T,plates),alloy);
 }else{
  for(const s of [-1,1])for(let i=0;i<design.spokes;i++)for(const offset of design.split?[-.052,.052]:[0])spoke(s,i*Math.PI*2/design.spokes+offset,design.spokeWidth||(design.split?.067:.15));
  const spokeGeometry=new T.BufferGeometry();spokeGeometry.setAttribute('position',new T.Float32BufferAttribute(vertices,3));spokeGeometry.computeVertexNormals();spokes=mesh('Rim_spokes',spokeGeometry,alloy);
 }
 spokes.material.side=T.DoubleSide;
 const hubRadius=Math.max(radius*.16,rimRadius*(design.cap||0)*.55),hub=mesh('Wheel_hub',new T.CylinderGeometry(hubRadius,hubRadius,width*.73,18),alloy);hub.rotation.z=Math.PI/2;
 const caps=[];if(design.cap)for(const s of [-1,1]){const g=new T.SphereGeometry(rimRadius*design.cap,24,10);g.scale(.22,1,1);g.translate(s*half*.52,0,0);caps.push(mesh('Wheel_centre_cap',g,design.polishedCap?polished:alloy))}
 const bolts=design.bolts||(heavy?8:5),boltCircle=Math.max(radius*.112,rimRadius*(design.cap||0)*.74),fasteners=[];
 for(const s of [-1,1])for(let i=0;i<bolts;i++){
  const a=i*Math.PI*2/bolts,bolt=new T.CylinderGeometry(radius*.022,radius*.022,radius*.04,6);bolt.rotateZ(Math.PI/2);bolt.translate(s*half*.87,Math.sin(a)*boltCircle,Math.cos(a)*boltCircle);fasteners.push({geometry:bolt});
 }const boltMesh=mesh('Wheel_lug_bolts',merged(T,fasteners),polished);mergeInto(lipMesh,[lipMesh,boltMesh,...caps.filter(n=>n.material===polished)]);mergeInto(hub,[barrel,spokes,hub,...caps.filter(n=>n.material===alloy)]);
 // A smaller rotor behind the spokes gives real depth without closing the rim.
 const rotorRadius=rimRadius*(design.holes?.46:.72),rotor=mesh('Brake_rotor',new T.CylinderGeometry(rotorRadius,rotorRadius,width*.065,32),inset);rotor.rotation.z=Math.PI/2;rotor.position.x=-side*width*.20;
 rolling.userData.nominalRadius=radius;rolling.userData.nominalWidth=width;
 if(materialPalette)for(const [role,part]of [['rubber',tire],['treadRubber',treadMesh],['alloy',hub],['inset',rotor],['polished',lipMesh]])renderBindings.set(part,Object.freeze({palette:materialPalette,role,id,wheel:rolling}));
 return {wheel:rolling,tire,hub,spokes:hub,nominalRollingRadius:radius,nominalRimRadius:rimRadius,nominalWidth:width};
}

export function wheelArchEnvelope(radius,width,front){
 return {radius:Math.hypot(radius,width*.5)+.052,halfDepth:(front?radius*Math.sin(.58)+width*.5*Math.cos(.58):width*.5)+.035};
}

// The inner liner is a thick, open-bottom half cylinder. Unlike a black disc it
// never fills the wheel opening and leaves the full steering envelope clear.
export function createWheelArch(T,{id,center,radius,width,front,side,outerX,paint}={}){
 const envelope=wheelArchEnvelope(radius,width,front),group=new T.Group();group.name='Wheel_arch_'+id;
 const linerMaterial=new T.MeshStandardMaterial({color:'#292f31',roughness:.94,side:T.DoubleSide});
 function arc(name,innerRadius,outerRadius,x0,x1,material){
  if(x0>x1)[x0,x1]=[x1,x0];
  const points=[];const add=(a,b,c,d)=>points.push(...a,...b,...c,...a,...c,...d);
  for(let i=0;i<24;i++){
   const a=-.10*Math.PI+i*1.20*Math.PI/24,b=-.10*Math.PI+(i+1)*1.20*Math.PI/24;
   const at=(x,r,t)=>[x,center.y+Math.sin(t)*r,center.z+Math.cos(t)*r];
   const p=[at(x0,innerRadius,a),at(x1,innerRadius,a),at(x1,outerRadius,a),at(x0,outerRadius,a)],q=[at(x0,innerRadius,b),at(x1,innerRadius,b),at(x1,outerRadius,b),at(x0,outerRadius,b)];
   for(let j=0;j<4;j++)add(p[j],q[j],q[(j+1)%4],p[(j+1)%4]);
   if(i===0)add(p[0],p[1],p[2],p[3]);if(i===23)add(q[3],q[2],q[1],q[0]);
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(points,3));g.computeVertexNormals();const m=new T.Mesh(g,material);m.name=name+'_'+id;m.castShadow=m.receiveShadow=true;m.userData.wheelArchFor=id;group.add(m);return m;
 }
 const xInner=center.x-side*envelope.halfDepth,xOuter=side*outerX;
 arc('Wheel_arch_liner',envelope.radius-.008,envelope.radius+.012,xInner,xOuter,linerMaterial);
 arc('Wheel_arch_lip',envelope.radius-.006,envelope.radius+.029,xOuter-side*.015,xOuter+side*.018,paint);
 group.userData.wheelArchEnvelope=envelope;return group;
}

export function updateVehicleWheelVisuals(wheels,state,fallbackRadius=.4){
 for(const item of wheels){
  if(item.pivot.userData.detached||item.pivot.userData.crashDetached||!item.pivot.visible)continue;
  item.pivot.rotation.y=item.front?(state.steer||0):0;
  if(item.front||!state.handbrake)item.wheel.rotation.x+=(state.distance||0)/(item.rollingRadius||item.nominalRollingRadius||fallbackRadius);
 }
}
