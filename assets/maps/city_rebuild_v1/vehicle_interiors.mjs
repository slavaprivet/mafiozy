// Shared metre-based interior contract: +Z forward, +X driver-left.
// Only sedan4 is integrated into /walk; other families are preparation for migration.
export const VEHICLE_INTERIOR_PROFILES=Object.freeze({
 sedan4:Object.freeze({frontSide:.43,frontZ:-.15,rearZ:-1.15,floorTop:.4,cushionTop:.59,roofBottom:2.07,driverRootY:.19,rearSeats:true,cargo:false}),
 coupe:Object.freeze({frontSide:.43,frontZ:-.15,rearZ:null,floorTop:.4,cushionTop:.59,roofBottom:2.08,driverRootY:.22,rearSeats:false,cargo:false}),
 truck:Object.freeze({frontSide:.43,frontZ:.55,rearZ:null,floorTop:.64,cushionTop:.83,roofBottom:2.32,driverRootY:.46,rearSeats:false,cargo:true}),
});
export const SEDAN_DRIVER_SEAT=Object.freeze({side:.43,front:-.15,y:VEHICLE_INTERIOR_PROFILES.sedan4.driverRootY});
export function createVehicleInterior(T,RoundedBox,{family='sedan4'}={}){
 const profile=VEHICLE_INTERIOR_PROFILES[family];if(!profile)throw Error('Unknown vehicle interior family '+family);
 const object=new T.Group();object.name='Interior_'+family;
 const leather=new T.MeshStandardMaterial({color:'#815d42',roughness:.86}),insert=new T.MeshStandardMaterial({color:'#9a7753',roughness:.94}),piping=new T.MeshStandardMaterial({color:'#d1b58b',roughness:.8}),dark=new T.MeshStandardMaterial({color:'#343b37',roughness:.94}),wood=new T.MeshStandardMaterial({color:'#69513b',roughness:.64}),metal=new T.MeshStandardMaterial({color:'#b8b39b',metalness:.35,roughness:.48}),dial=new T.MeshStandardMaterial({color:'#d6d2b8',roughness:.75});
 const lift=profile.floorTop-.4,zOffset=profile.frontZ+.15,parts={seats:[],gauges:[]};
 function box(name,w,h,d,x,y,z,mat,round=.035,parent=object){const mesh=new T.Mesh(new RoundedBox(w,h,d,3,Math.min(round,w/3,h/3,d/3)),mat);mesh.name=name;mesh.position.set(x,y+lift,z+zOffset);mesh.castShadow=mesh.receiveShadow=true;parent.add(mesh);return mesh}
 const cabinRear=profile.rearSeats?-1.62:-.67;
 box('Cabin_floor',1.55,.10,.78-cabinRear,0,.35,(.78+cabinRear)/2,dark);
 function seat(side,z,row){
  const prefix=row+'_'+(side>0?'left':'right'),x=side*profile.frontSide;
  for(const rail of [-.22,.22])box(prefix+'_seat_rail',.045,.055,.47,x+rail,.4175,z,dark,.009);
  const cushion=box(prefix+'_cushion',.65,.16,.59,x,.51,z,leather,.065);parts.seats.push(cushion);
  box(prefix+'_insert',.49,.018,.46,x,.599,z,insert,.008);
  box(prefix+'_back',.65,.61,.15,x,.90,z-.285,leather,.055);
  box(prefix+'_back_insert',.48,.46,.021,x,.91,z-.20,insert,.008);
  for(const seam of [-.19,-.095,0,.095,.19]){
   box(prefix+'_seat_seam',.009,.008,.42,x+seam,.612,z,piping,.002);
   box(prefix+'_back_seam',.009,.43,.009,x+seam,.91,z-.184,piping,.002);
  }
  for(const post of [-.12,.12])box(prefix+'_headrest_post',.026,.18,.026,x+post,1.27,z-.28,metal,.008);
  box(prefix+'_headrest',.39,.25,.16,x,1.40,z-.28,leather,.055);
  box(prefix+'_belt_latch',.04,.09,.07,x-side*.35,.65,z-.09,dark,.012);
 }
 for(const side of [-1,1]){seat(side,-.15,'front');if(profile.rearSeats)seat(side,profile.rearZ,'rear')}
 box('Transmission_tunnel',.13,.10,1.08,0,.46,.22,dark);
 box('Gear_lever',.022,.19,.022,0,.63,.19,metal,.006);
 box('Gear_knob',.065,.055,.065,0,.74,.19,wood,.02);
 box('Dashboard_shell',1.61,.24,.28,0,1.12,.75,dark,.065);
 box('Dashboard_wood_fascia',1.47,.15,.018,0,1.12,.599,wood,.008);
 for(const x of [-.63,-.16,.63]){box('Dashboard_vent',.16,.064,.022,x,1.16,.582,dark,.01);for(const y of [-.018,.018])box('Vent_slat',.14,.005,.008,x,1.16+y,.566,metal,.002)}
 box('Radio',.23,.078,.028,-.24,1.055,.575,dark,.01);box('Radio_display',.10,.025,.008,-.24,1.07,.556,dial,.002);
 for(const x of [-.32,-.16])box('Radio_knob',.022,.024,.018,x,1.043,.549,metal,.006);
 for(const x of [.32,.54]){
  const rim=new T.Mesh(new T.TorusGeometry(.084,.008,6,24),metal);rim.name='Instrument_rim';rim.position.set(x,1.155+lift,.571+zOffset);object.add(rim);
  const face=new T.Mesh(new T.CircleGeometry(.077,24),dark);face.name='Instrument_face';face.position.copy(rim.position);face.position.z-=.002;face.rotation.y=Math.PI;object.add(face);parts.gauges.push(face);
  for(let i=0;i<9;i++){const a=-2.4+i*.6;const tick=box('Instrument_tick',.008,.018,.004,x+Math.sin(a)*.061,1.155+Math.cos(a)*.061,.561,dial,.001);tick.rotation.z=-a}
  const needle=box('Instrument_needle',.005,.060,.005,x,1.178,.553,piping,.001);needle.rotation.z=-.55;
 }
 const steering=new T.Group();steering.name='Steering_column';steering.position.set(profile.frontSide,1.15+lift,.38+zOffset);steering.rotation.x=-.30;object.add(steering);
 const wheel=new T.Group();wheel.name='Steering_wheel';steering.add(wheel);
 const rim=new T.Mesh(new T.TorusGeometry(.18,.025,8,32),wood);rim.name='Steering_rim';wheel.add(rim);
 for(const angle of [0,2.1,4.2]){const spoke=new T.Mesh(new RoundedBox(.022,.17,.021,2,.006),metal);spoke.position.set(Math.sin(angle)*.075,Math.cos(angle)*.075,0);spoke.rotation.z=-angle;wheel.add(spoke)}
 const hub=new T.Mesh(new T.CylinderGeometry(.042,.042,.036,16),dark);hub.rotation.x=Math.PI/2;wheel.add(hub);
 for(const x of [.35,.50])box('Driver_pedal',.09,.025,.13,x,.47,.67,dark,.01);
 let cargo=null;if(profile.cargo){cargo=new T.Group();cargo.name='Cargo_bed';object.add(cargo);box('Cargo_floor',1.74,.12,1.95,0,.52,-1.8,dark,.035,cargo);for(const side of [-1,1])box('Cargo_side',.11,.53,1.95,side*.85,.81,-1.8,wood,.035,cargo);box('Cargo_tailgate',1.74,.53,.11,0,.81,-2.72,wood,.035,cargo);for(let i=-3;i<=3;i++)box('Cargo_floor_rib',.018,.018,1.78,i*.20,.591,-1.8,metal,.003,cargo)}
 const anchors={driver:{side:profile.frontSide,front:profile.frontZ,y:profile.driverRootY},passenger:{side:-profile.frontSide,front:profile.frontZ,y:profile.driverRootY},rear:profile.rearSeats?[-1,1].map(side=>({side:side*profile.frontSide,front:profile.rearZ,y:profile.driverRootY})):[],floorTop:profile.floorTop,cushionTop:profile.cushionTop,roofBottom:profile.roofBottom};
 function getSteeringGrips(){wheel.updateWorldMatrix(true,false);return{left:new T.Vector3(.18*Math.cos(Math.PI/6),.09,-.025).applyMatrix4(wheel.matrixWorld),right:new T.Vector3(-.18*Math.cos(Math.PI/6),.09,-.025).applyMatrix4(wheel.matrixWorld)}}
 return{object,profile,anchors,parts,wheel,steeringWheel:wheel,cargo,getSteeringGrips,update(state){wheel.rotation.z=-(state.steer||0)*2.1}};
}
