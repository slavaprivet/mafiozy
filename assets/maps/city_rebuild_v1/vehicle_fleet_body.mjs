// Closed-body architecture for the authored fleet. These are real thin panels,
// framed openings and mechanical mounts, not invisible supports or filled cabins.
export function assembleArtistBody(T,RoundedBox,c){
 const {object,p,sourceMeshes,shell,doors,doorSpecs,bodyMaterial,dark,trim,metal,floorTop,bodyY,bodyH,cabinTop,roofBottom,front,rear,movedCab,interiorHalfWidth,trunkSpec,hoodSpec,wheels,cut}=c;
 const bus=p.family==='bus',utility=['van','ambulance','fire'].includes(p.family),hatch=['hatch','wagon','suv'].includes(p.family);
 const glass=(sourceMeshes.find(m=>m.material?.transparent)?.material||new T.MeshStandardMaterial({color:'#6c9da8',transparent:true,opacity:.35,roughness:.23})).clone();glass.side=T.DoubleSide;
 const created=[],glazing=[];
 const bounds=m=>{m.traverse(n=>n.geometry?.computeBoundingBox());object.updateMatrixWorld(true);return new T.Box3().setFromObject(m)};
 function mesh(name,geometry,material=bodyMaterial,parent=object){const n=new T.Mesh(geometry,material);n.name=name;n.castShadow=n.receiveShadow=true;n.userData.assembledBody=true;parent.add(n);created.push(n);if(material.transparent)glazing.push(n);else shell.push(n);return n}
 function box(name,w,h,d,x,y,z,material=bodyMaterial,parent=object,r=.035){const n=mesh(name,new RoundedBox(w,h,d,3,Math.min(r,w/3,h/3,d/3)),material,parent);n.position.set(x,y,z);if(parent!==object)n.position.sub(parent.position);return n}
 function beam(name,a,b,width=.085,material=bodyMaterial,parent=object,depth=width){const v1=new T.Vector3(...a),v2=new T.Vector3(...b),delta=v2.clone().sub(v1),mid=v1.add(v2).multiplyScalar(.5),n=box(name,width,delta.length()+width*.4,depth,mid.x,mid.y,mid.z,material,parent,.022);n.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),delta.normalize());return n}
 function quad(name,points,thickness=.025,material=bodyMaterial,parent=object){
  const points3=points.map(p=>new T.Vector3(...p)),normal=points3[1].clone().sub(points3[0]).cross(points3[2].clone().sub(points3[0])).normalize().multiplyScalar(thickness*.5),vertices=[];
  for(const sign of [-1,1])for(const v of points3){const q=v.clone().addScaledVector(normal,sign);if(parent!==object)q.sub(parent.position);vertices.push(q.x,q.y,q.z)}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(vertices,3));g.setIndex([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7]);g.computeVertexNormals();return mesh(name,g,material,parent);
 }
 function remove(n){if(!n)return;n.removeFromParent();n.visible=false;for(let i=shell.length-1;i>=0;i--)if(shell[i]===n)shell.splice(i,1);n.traverse(child=>child.geometry?.dispose())}
 const retired=[];
 // Original upper hulls were solid: after carving they no longer form a frame.
 // Replace those remnants and their incompatible floating glazing as one assembly.
 object.traverse(n=>{if(n.isMesh&&(n.userData.artistSourceNode&&/_(Cab|Cabin|Windshield|RearGlass|SideGlass_[LR])$/.test(n.userData.artistSourceNode)||/^Door_window_/.test(n.name)))retired.push(n)});
 if(bus)for(let i=retired.length-1;i>=0;i--)if(/RearGlass/.test(retired[i].name))retired.splice(i,1);
 retired.forEach(remove);
 const sideX=p.cabinWidth*.5-.035,roofX=bus?p.width*.465:Math.max(interiorHalfWidth-.025,p.cabinWidth*.455);
 const belt=bus?p.height*.525:Math.max(bodyY+bodyH*.51,floorTop+.48),roofY=roofBottom+.045;
 const roofFront=bus?front+.22:front-Math.min(.40,(front-rear)*.19),roofRear=bus?rear-.12:rear-.045;
 if(!bus){
  const roof=box('Body_Cabin_roof',roofX*2+.10,.105,roofFront-roofRear+.12,0,roofY+.035,(roofFront+roofRear)/2,bodyMaterial,object,.045);roof.userData.vehicleRoof=true;
  // A low raised crown keeps the original softly rounded clay vocabulary.
  box('Roof_crown',roofX*1.83,.035,(roofFront-roofRear)*.90,0,roofY+.096,(roofFront+roofRear)/2,bodyMaterial,object,.016);
 }
 const lowFront=front+.025,lowRear=rear-.025;
 for(const s of [-1,1]){
  const lower=s*sideX,upper=s*roofX;
  beam('Body_A_pillar_'+s,[lower,belt-.04,lowFront],[upper,roofY,roofFront],.115);
  beam('Body_C_pillar_'+s,[lower,belt-.025,lowRear],[upper,roofY,roofRear],.115);
  beam('Body_roof_side_rail_'+s,[upper,roofY,roofRear],[upper,roofY,roofFront],.105);
  box('Body_sill_'+s,.115,.13,front-rear+.14,lower,floorTop+.025,(front+rear)/2,bodyMaterial);
  if(p.seatCount===4)beam('Body_B_pillar_'+s,[lower,floorTop+.06,movedCab],[upper,roofY,movedCab],.09,trim);
  // Fixed hinge pillar meets the sill beneath the windscreen rather than ending in air.
  beam('Body_A_pillar_lower_'+s,[lower,floorTop+.04,lowFront],[lower,belt+.02,lowFront],.10);
  beam('Body_C_pillar_lower_'+s,[lower,floorTop+.04,lowRear],[lower,belt+.02,lowRear],.10);
 }
 beam('Windscreen_lower_frame',[-sideX,belt,lowFront],[sideX,belt,lowFront],.095);
 beam('Windscreen_upper_frame',[-roofX,roofY,roofFront],[roofX,roofY,roofFront],.095);
 const wind=quad('Fitted_windscreen',[[-sideX+.07,belt+.045,lowFront-.015],[sideX-.07,belt+.045,lowFront-.015],[roofX-.06,roofY-.045,roofFront],[ -roofX+.06,roofY-.045,roofFront]],.018,glass);
 wind.userData.bodyWindow='front';
 if(bus){
  // FrontGlass belonged to the full bus shell and must not remain as a second pane.
  for(const n of sourceMeshes.filter(n=>/_FrontGlass$/.test(n.name)))remove(n);
 }
 function sideRoofZ(z){return z>=movedCab?Math.min(z,roofFront-.06):Math.max(z,roofRear+.06)}
 for(const d of doorSpecs){
  const g=doors.get(d.id),s=d.side,x=s*sideX,rx=s*roofX,z0=d.opening.min[2]+.027,z1=d.opening.max[2]-.027,top0=sideRoofZ(z0),top1=sideRoofZ(z1);
  const bottom=floorTop+.095;
  const panel=box('Door_outer_skin_'+d.id,.075,belt-bottom,z1-z0,x,(belt+bottom)/2,(z0+z1)/2,bodyMaterial,g,.03);
  panel.userData.wheelArchCandidate=true;
  beam('Door_belt_frame_'+d.id,[x,belt,z0],[x,belt,z1],.075,bodyMaterial,g);
  beam('Door_window_rear_frame_'+d.id,[x,belt,z0],[rx,roofY-.055,top0],.062,bodyMaterial,g);
  beam('Door_window_front_frame_'+d.id,[x,belt,z1],[rx,roofY-.055,top1],.062,bodyMaterial,g);
  beam('Door_window_top_frame_'+d.id,[rx,roofY-.055,top0],[rx,roofY-.055,top1],.062,bodyMaterial,g);
  const pane=quad('Fitted_door_glass_'+d.id,[[x,belt+.035,z0+.035],[x,belt+.035,z1-.035],[rx,roofY-.088,top1-.025],[rx,roofY-.088,top0+.025]],.018,glass,g);pane.userData.bodyWindow=d.id;
  box('Door_handle_recess_'+d.id,.084,.065,.21,x+s*.024,belt-.15,z0+.23,dark,g,.018);
  box('Door_handle_fitted_'+d.id,.094,.032,.15,x+s*.06,belt-.14,z0+.23,metal,g,.012);
 }
 // Rear glazing and hatch use the same roof / belt datum, not the obsolete GLB cabin transform.
 let rearBeltZ=lowRear;
 if(hatch)rearBeltZ=-p.length*.478;
 if(!bus){
  const parent=hatch?trunkSpec.lid:object;
  beam('Rear_window_upper_frame',[-roofX,roofY,roofRear],[roofX,roofY,roofRear],.10,bodyMaterial,parent);
  beam('Rear_window_lower_frame',[-sideX,belt,rearBeltZ],[sideX,belt,rearBeltZ],.095,bodyMaterial,parent);
  for(const s of [-1,1])beam('Rear_window_side_frame_'+s,[s*sideX,belt,rearBeltZ],[s*roofX,roofY,roofRear],.105,bodyMaterial,parent);
  quad('Fitted_rear_glass',[[-sideX+.07,belt+.04,rearBeltZ],[sideX-.07,belt+.04,rearBeltZ],[roofX-.06,roofY-.05,roofRear],[-roofX+.06,roofY-.05,roofRear]],.018,glass,parent);
 }
 // Bumpers and lenses are fitted into real aprons. Their old positions were in
 // front of the tapered lower hull, with 10–35 cm of empty space behind them.
 const hoodTop=bodyY+bodyH*.54,frontZ=p.length*.482,rearZ=-p.length*.487,apronBottom=p.wheelRadius*.56;
 const apronTop=hoodTop-(utility?.11:0);
 const frontApron=box('Front_apron',p.width*.94,apronTop-apronBottom,.14,0,(apronTop+apronBottom)/2,frontZ,bodyMaterial,object,.045);
 box('Front_lower_grille',p.width*.42,.17,.024,0,apronBottom+.16,frontZ+.078,dark,object,.013);
 for(let j=-3;j<=3;j++)box('Grille_bar_'+j,.027,.14,.018,j*p.width*.052,apronBottom+.16,frontZ+.095,trim,object,.005);
 box('Front_license_plate',.30,.095,.021,0,apronBottom+.015,frontZ+.087,metal,object,.006);
 for(const s of [-1,1]){
  const lamp=sourceMeshes.find(n=>n.name.endsWith('_Headlamp_'+(s>0?'L':'R')));
  if(lamp){const b=bounds(lamp),center=b.getCenter(new T.Vector3());lamp.geometry.translate(0,0,frontZ+.085-center.z);box('Headlamp_housing_'+s,p.width*.235,.175,.095,center.x,center.y,frontZ+.025,trim,object,.025)}
 }
 const cargoFloor=trunkSpec.cavityBounds?.min[1]??bodyY+.28;
 const rearApronTop=Math.max(apronBottom+.06,Math.min(bodyY+.05,cargoFloor-.03));
 box('Rear_apron',p.width*.92,rearApronTop-apronBottom,.15,0,(rearApronTop+apronBottom)/2,rearZ,bodyMaterial,object,.035);
 for(const s of [-1,1]){
  const tail=sourceMeshes.find(n=>n.name.endsWith('_Taillamp_'+(s>0?'L':'R')));
  const lampY=Math.max(rearApronTop+.06,bodyY+.06),lampX=s*p.width*.424;
  box('Rear_corner_lamp_mount_'+s,p.width*.13,Math.max(.21,lampY+.11-apronBottom),.22,lampX,(lampY+.11+apronBottom)/2,rearZ+.025,bodyMaterial,object,.035);
  if(tail){const b=bounds(tail),center=b.getCenter(new T.Vector3()),a=tail.geometry.attributes.position;for(let j=0;j<a.count;j++)a.setX(j,lampX+(a.getX(j)-center.x)*.56);tail.geometry.translate(0,lampY-center.y,rearZ-.087-center.z);a.needsUpdate=true}
 }
 for(const end of ['Front','Rear']){
  const bumper=sourceMeshes.find(n=>n.name.endsWith('_'+end+'Bumper'));if(!bumper)continue;
  const b=bounds(bumper),center=b.getCenter(new T.Vector3()),z=end==='Front'?frontZ+.095:rearZ-.105;bumper.geometry.translate(0,0,z-center.z);
  for(const s of [-1,1])box(end+'_bumper_bracket_'+s,.12,.09,.22,s*p.width*.26,center.y,end==='Front'?frontZ-.005:rearZ+.005,trim);
 }
 // Thin fender shoulders join the hood to the doors; arches are clipped by the
 // same cylindrical wheel envelopes as the authored shell in the caller.
 for(const s of [-1,1]){
  const fender=box('Front_fender_'+s,p.width*.145,hoodTop-floorTop,Math.max(.16,frontZ-lowFront+.14),s*p.width*.432,(hoodTop+floorTop)/2,(frontZ+lowFront)/2,bodyMaterial,object,.045);fender.userData.wheelArchCandidate=true;
  const backDepth=Math.max(.12,lowRear-rearZ),back=box('Rear_quarter_'+s,p.width*.14,Math.max(.15,belt-floorTop),backDepth,s*p.width*.43,(belt+floorTop)/2,(lowRear+rearZ)/2,bodyMaterial,object,.04);back.userData.wheelArchCandidate=true;
  if(hatch)quad('Rear_upper_quarter_'+s,[[s*sideX,belt,rearBeltZ],[s*sideX,belt,lowRear],[s*roofX,roofY,roofRear],[s*roofX,roofY,roofRear-.01]],.08,bodyMaterial);
 }
 // Mirrors now have stems anchored to the door, and therefore open with it.
 for(const s of [-1,1]){
  const original=sourceMeshes.find(n=>n.name.endsWith('_Mirror_'+(s>0?'L':'R')));if(!original)continue;
  const door=doors.get('front_'+(s>0?'left':'right')),target=new T.Vector3(s*(sideX+.14),belt+.13,front-.19),b=bounds(original),center=b.getCenter(new T.Vector3());original.geometry.translate(...target.clone().sub(center).toArray());object.updateMatrixWorld(true);door.attach(original);
  beam('Mirror_stem_'+s,[s*sideX,belt+.07,front-.15],target.toArray(),.045,trim,door);
 }
 // Rebuild the service cover as a continuous thin external skin. The engine bay
 // remains open underneath and the controller owns its animated hinge.
 if(!bus){
  const old=hoodSpec.lid;remove(old);
  const z0=front+.03,z1=frontZ-.055;
  const hood=box('Hood_lid',p.width*.74,.065,Math.max(.20,z1-z0),0,hoodTop,(z0+z1)/2,bodyMaterial,object,.025);
  if(utility)box('Hood_front_lip',p.width*.74,.125,.14,0,hoodTop-.0525,frontZ,bodyMaterial,hood,.025);
  hoodSpec.lid=hood;hoodSpec.hingePoint=[0,hoodTop,z0];hoodSpec.engineBounds.min[2]=z0+.05;hoodSpec.engineBounds.max[2]=z1-.035;hoodSpec.engineBounds.max[1]=hoodTop-.07;
  if(utility)hoodSpec.engineBounds.min[1]=floorTop-.13;
  for(const s of [-1,1])box('Engine_bay_sidewall_'+s,.04,Math.max(.18,hoodTop-hoodSpec.engineBounds.min[1]),z1-z0,s*p.width*.362,(hoodTop+hoodSpec.engineBounds.min[1])/2,(z0+z1)/2,dark);
  box('Engine_bay_firewall',p.width*.73,Math.max(.18,hoodTop-hoodSpec.engineBounds.min[1]),.035,0,(hoodTop+hoodSpec.engineBounds.min[1])/2,z0,dark);
 }else{
  // The original service cut contained a thick piece of the hull. A bottom
  // hinge folds this thin cover down, clear of the separate cargo door above.
  const old=hoodSpec.lid;remove(old);
  const lo=hoodSpec.engineBounds.min,hi=hoodSpec.engineBounds.max,z=-p.length*.487;
  hoodSpec.lid=box('Hood_lid',p.width*.68,hi[1]-lo[1]+.09,.065,0,(hi[1]+lo[1])/2,z,bodyMaterial,object,.025);
  hoodSpec.hingePoint=[0,lo[1]-.045,z];hoodSpec.openAngle=-1.4;
 }
 // Hatchbacks get a usable lower cargo box beneath their sloped rear glass.
 if(hatch){
  const lid=trunkSpec.lid,toRemove=lid.children.filter(n=>!n.userData.assembledBody);toRemove.forEach(remove);
  const floor=trunkSpec.cavityBounds.min[1],cargoBack=rearBeltZ+.055,cargoFront=rear-.04,cargoTop=belt-.055;
  trunkSpec.cavityBounds={min:[-p.width*.335,floor,cargoBack],max:[p.width*.335,cargoTop,cargoFront]};
  trunkSpec.hingePoint=[0,roofY,roofRear];
  box('Hatch_lower_panel',sideX*2,.94*(belt-floor),.065,0,(belt+floor)/2,rearBeltZ,bodyMaterial,lid,.028);
  for(const n of object.children.filter(n=>/^Cargo_(floor|liner_side|bulkhead)$/.test(n.name)))remove(n);
  box('Cargo_floor',p.width*.70,.055,cargoFront-cargoBack,0,floor-.0275,(cargoBack+cargoFront)/2,dark);
  for(const s of [-1,1])box('Cargo_liner_side',.035,cargoTop-floor,cargoFront-cargoBack,s*p.width*.35,(cargoTop+floor)/2,(cargoBack+cargoFront)/2,dark);
  box('Cargo_bulkhead',p.width*.70,cargoTop-floor,.035,0,(cargoTop+floor)/2,cargoFront,dark);
 }
 if(['sedan','executive','police','coupe'].includes(p.family)){
  // A cut from a solid body also contained its underside: replace that volume
  // with a genuine 65 mm lid so cargo can occupy the entire declared cavity.
  const lid=trunkSpec.lid;[...lid.children].forEach(remove);
  const cavity=trunkSpec.cavityBounds,top=cavity.max[1]-.09;
  box('Trunk_lid_skin',p.width*.78,.065,cavity.max[2]-cavity.min[2]+.09,0,top,(cavity.min[2]+cavity.max[2])/2,bodyMaterial,lid,.028);
  cavity.max[1]=top-.060;trunkSpec.hingePoint=[0,top,cavity.max[2]+.025];
  // The rear fascia meets the thin lid and the floor; it is outside the usable box.
  box('Trunk_rear_fascia',p.width*.78,top-cavity.min[1]+.055,.07,0,(top+cavity.min[1]-.055)/2,cavity.min[2]-.042,bodyMaterial,object,.025);
 }
 if(utility||bus){
  // Cargo doors are thin rear skins, not arbitrary chunks of the lower hull.
  const lid=trunkSpec.lid;[...lid.children].forEach(remove);
  const b=trunkSpec.cavityBounds,z=b.min[2]-.055,width=p.width*.72,height=b.max[1]-b.min[1];
  box('Cargo_hatch_skin',width,height+.035,.065,0,(b.min[1]+b.max[1])/2,z,bodyMaterial,lid,.028);
  box('Cargo_hatch_seam',.025,height-.04,.016,0,(b.min[1]+b.max[1])/2,z-.041,trim,lid,.006);
  for(const s of [-1,1])box('Cargo_hatch_handle_'+s,.04,.18,.045,s*.12,b.min[1]+height*.46,z-.06,metal,lid,.01);
  trunkSpec.hingePoint=[0,b.max[1],z];
  if(p.family==='fire')box('Cargo_equipment_roof',p.width*.90,.08,b.max[2]-b.min[2]+.18,0,b.max[1]+.045,(b.min[2]+b.max[2])/2,bodyMaterial,object,.03);
 }
 if(p.family==='pickup'){
  const bed=sourceMeshes.find(n=>/_BedFloor$/.test(n.name)),b=bounds(bed),tail=bounds(trunkSpec.lid);
  trunkSpec.cavityBounds={min:[-p.width*.35,b.max.y+.008,tail.max.z+.055],max:[p.width*.35,bodyY+.63,Math.min(-p.length*.13,lowRear-.085)]};
  const cavity=trunkSpec.cavityBounds;
  for(const n of sourceMeshes.filter(n=>n.parent&&/_(LowerBody|CargoVolume)$/.test(n.name)))cut(n,cavity);
  const depth=cavity.max[2]-cavity.min[2],height=cavity.max[1]-cavity.min[1];
  for(const s of [-1,1])box('Cargo_liner_side',.035,height,depth,s*(p.width*.35+.02),(cavity.max[1]+cavity.min[1])/2,(cavity.max[2]+cavity.min[2])/2,dark);
  box('Cargo_bulkhead',p.width*.75,height,.035,0,(cavity.max[1]+cavity.min[1])/2,cavity.max[2]+.02,dark);
 }
 // Roof equipment is mounted to its actual supporting roof, not to source
 // dimensions before the cab was moved. Preserve the recognisable artist parts.
 const lightParts=sourceMeshes.filter(n=>/_Lightbar/.test(n.name));
 if(lightParts.length){const base=lightParts.find(n=>/_LightbarBase$/.test(n.name)),b=bounds(base),center=b.getCenter(new T.Vector3()),targetY=roofY+.13,targetZ=utility?movedCab:(roofFront+roofRear)/2;for(const n of lightParts)n.geometry.translate(0,targetY-center.y,targetZ-center.z);for(const s of [-1,1])box('Lightbar_roof_mount_'+s,.10,.13,.19,s*p.width*.22,roofY+.079,targetZ,trim)}
 const ladder=sourceMeshes.filter(n=>/RoofLadderRail|LadderRung/.test(n.name));
 if(ladder.length){const equipment=sourceMeshes.find(n=>/_EquipmentBody$/.test(n.name)),supportTop=bounds(equipment).max.y,all=new T.Box3();for(const n of ladder)all.union(bounds(n));const dy=supportTop+.18-all.min.y;for(const n of ladder)n.geometry.translate(0,dy,0);for(const z of [-p.length*.29,p.length*.05]){for(const s of [-1,1])box('Ladder_rack_foot_'+s+'_'+z,.11,.18,.15,s*.42,supportTop+.09,z,trim);box('Ladder_rack_crossbar_'+z,1.02,.06,.12,0,supportTop+.17,z,trim)}}
 for(const n of sourceMeshes.filter(n=>/_RoofSpoiler$/.test(n.name))){const b=bounds(n),center=b.getCenter(new T.Vector3());n.geometry.translate(0,roofY+.14-b.min.y,roofRear-center.z);for(const s of [-1,1])box('Spoiler_roof_mount_'+s,.10,.15,.10,s*roofX*.65,roofY+.08,roofRear,trim)}
 for(const n of sourceMeshes.filter(n=>/_RoofRail_[LR]$/.test(n.name))){const b=bounds(n),center=b.getCenter(new T.Vector3());n.geometry.translate(0,roofY+.12-b.min.y,0);for(const z of [roofRear+.15,roofFront-.15])box('Roofrail_mount_'+n.name+'_'+z,.09,.12,.13,center.x,roofY+.07,z,trim)}
 // The old wagon extension is replaced by the single connected roof above.
 for(const n of sourceMeshes.filter(n=>/_RoofExtension$/.test(n.name)))remove(n);
 object.userData.bodyAssemblyVersion=2;
 return {created,glazing,retired,roof:{x:roofX,y:roofY,front:roofFront,rear:roofRear},belt,sideX};
}
