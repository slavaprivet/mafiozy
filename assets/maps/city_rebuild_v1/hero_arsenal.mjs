// Artist14 detailed clay-metal props for the isolated third-person preview. Visuals only: no ammo, damage or firing authority.
const specs=[
  ['none','Без оружия',false,'none'],
  ['nagan','Наган',false,'revolver'],
  ['tt_pistol','Пистолет ТТ',false,'pistol'],
  ['revolver','Револьвер',false,'revolver'],
  ['deagle','Дезерт Игл',false,'heavy-pistol'],
  ['golden_colt','Золотой Кольт',false,'pistol'],
  ['sawn_off','Обрез',true,'shotgun'],
  ['shotgun','Дробовик',true,'shotgun'],
  ['uzi','Узи',true,'smg'],
  ['golden_uzi','Золотой Узи',true,'smg'],
  ['ak74','АК-74',true,'rifle'],
  ['m16','М-16',true,'rifle'],
  ['tommy_gun','Томми Ган',true,'smg'],
  ['sniper','Снайперская винтовка',true,'sniper'],
  ['rpg','Базука',true,'launcher'],
];

export const ARSENAL=Object.freeze(specs.map(([id,label,twoHanded,family])=>Object.freeze({id,label,twoHanded,family})));
const byId=new Map(ARSENAL.map(item=>[item.id,item]));

export function createWeaponModel(host,idArg){
  const THREE=host?.THREE||host,id=String(host?.id??idArg??'none'),spec=byId.get(id);
  if(!THREE?.Group||!THREE?.Mesh||!spec)throw Error(spec?'THREE host required':'Unknown weapon '+id);
  const root=new THREE.Group();root.name=`weapon_${id}`;
  root.weaponId=id;root.twoHanded=spec.twoHanded;
  root.userData={...root.userData,weaponId:id,label:spec.label,twoHanded:spec.twoHanded,family:spec.family,frontAxis:'+Z',gripOrigin:[0,0,0],visualOnly:true,muzzle:null,ejectionPort:null,supportGrip:null,mountOffset:spec.twoHanded?[.15,1.1,.18]:[.24,1.07,.26]};
  if(id==='none')return root;

  const materials={
    dark:new THREE.MeshStandardMaterial({color:0x17191d,metalness:.72,roughness:.3}),
    black:new THREE.MeshStandardMaterial({color:0x090a0c,metalness:.52,roughness:.34}),
    steel:new THREE.MeshStandardMaterial({color:0x565d66,metalness:.88,roughness:.22}),
    paleSteel:new THREE.MeshStandardMaterial({color:0xa9afb4,metalness:.9,roughness:.17}),
    wood:new THREE.MeshStandardMaterial({color:0x633516,metalness:.02,roughness:.72}),
    redWood:new THREE.MeshStandardMaterial({color:0x7b2c18,metalness:.03,roughness:.62}),
    gold:new THREE.MeshStandardMaterial({color:0xd6a72f,metalness:.93,roughness:.16}),
    goldLight:new THREE.MeshStandardMaterial({color:0xffd86a,metalness:.88,roughness:.13}),
    army:new THREE.MeshStandardMaterial({color:0x3d5032,metalness:.18,roughness:.62}),
    olive:new THREE.MeshStandardMaterial({color:0x66713a,metalness:.12,roughness:.68}),
    lens:new THREE.MeshStandardMaterial({color:0x4f91a5,metalness:.15,roughness:.08,transparent:true,opacity:.82}),
  };
  const add=(name,geometry,material,x,y,z,rx=0,ry=0,rz=0)=>{const mesh=new THREE.Mesh(geometry,material);mesh.name=name;mesh.position.set(x,y,z);mesh.rotation.set(rx,ry,rz);mesh.castShadow=true;mesh.receiveShadow=true;root.add(mesh);return mesh};
  // Small bevels catch the key light without changing the silhouette bounds.
  const box=(name,w,h,d,material,x,y,z,rx=0,ry=0,rz=0)=>{
    let geometry;
    if(Math.min(w,h,d)>.08){
      const r=Math.min(w,h,d)*.10, shape=new THREE.Shape(),a=w/2-r,b=h/2-r;
      shape.moveTo(-a,-b);shape.lineTo(a,-b);shape.lineTo(a,b);shape.lineTo(-a,b);shape.closePath();
      geometry=new THREE.ExtrudeGeometry(shape,{depth:d-2*r,bevelEnabled:true,bevelSize:r,bevelThickness:r,bevelSegments:1,steps:1,curveSegments:1});
      geometry.translate(0,0,-d/2+r);
    }else geometry=new THREE.BoxGeometry(w,h,d);
    return add(name,geometry,material,x,y,z,rx,ry,rz);
  };
  const tube=(name,r,length,material,x,y,z,segments=10)=>add(name,new THREE.CylinderGeometry(r,r,length,segments,1,['barrel','twin_barrel'].includes(name)),material,x,y,z,Math.PI/2);
  const tapered=(name,r1,r2,length,material,x,y,z,segments=10)=>add(name,new THREE.CylinderGeometry(r1,r2,length,segments),material,x,y,z,Math.PI/2);
  const muzzle=(y,z)=>{root.userData.muzzle=[0,y,z]};
  const sight=(z,material=materials.dark)=>box('front_sight',.035,.075,.045,material,0,.19,z);
  const pistolGrip=(material=materials.wood,z=-.01,tilt=-.16)=>box('primary_grip',.13,.34,.16,material,0,-.16,z,tilt);
  const longGrip=(material=materials.black,z=0)=>box('primary_grip',.14,.34,.18,material,0,-.16,z,-.18);
  // Source-rig units inherit ~0.368 scale. The old stock reached 35–43 cm
  // behind the grip, through the chest. Keep its shoulder pad within 18 cm.
  const stock=(material=materials.wood,z=-.48,length=.72)=>{length=Math.min(length*.46,.32);z=-.025-length/2+.23;box('stock',.18,.25,length,material,0,.02,z);box('stock_pad',.22,.34,.09,materials.black,0,.02,z-length/2)};
  const magazine=(material=materials.dark,z=.18,long=.34,tilt=0)=>box('magazine',.15,long,.19,material,0,-long/2+.01,z,tilt);
  const receiverDetails=(ejection=[.13,.29,.35])=>{
    root.userData.ejectionPort=ejection;
    box('ejection_port',.035,.075,.19,materials.black,ejection[0],ejection[1],ejection[2]);
    box('selector',.025,.055,.1,materials.goldLight,-.125,.18,.18,0,0,.38);
    add('receiver_pin',new THREE.CylinderGeometry(.025,.025,.255,8),materials.paleSteel,0,.17,.12,0,0,Math.PI/2);
  };
  const triggerDetails=()=>{
    const guard=add('trigger_guard_detail',new THREE.TorusGeometry(.075,.017,5,10,Math.PI),materials.dark,0,-.005,.115,Math.PI/2,0,0);
    guard.scale.z=.72;
    box('trigger',.028,.12,.025,materials.paleSteel,0,-.035,.11,-.32);
  };

  if(id==='nagan'||id==='revolver'){
    const large=id==='revolver',metal=large?materials.paleSteel:materials.dark,barrel=large?.52:.42;
    pistolGrip(id==='nagan'?materials.redWood:materials.wood,-.05,-.22);
    box('frame',.16,.19,.29,metal,0,.11,.13);
    add('cylinder',new THREE.CylinderGeometry(large?.12:.1,large?.12:.1,.2,10),metal,0,.11,.27,Math.PI/2,0,0);
    tube('barrel',large?.065:.05,barrel,metal,0,.14,.4+barrel/2);
    box('hammer',.09,.09,.08,materials.black,0,.22,-.04,-.25);sight(.4+barrel,metal);muzzle(.14,.4+barrel);
  }else if(['tt_pistol','deagle','golden_colt'].includes(id)){
    const heavy=id==='deagle',gold=id==='golden_colt',metal=gold?materials.gold:heavy?materials.paleSteel:materials.dark,length=heavy?.82:gold?.68:.62;
    pistolGrip(gold?materials.redWood:heavy?materials.black:materials.wood,-.02,-.14);
    box('receiver',heavy?.2:.16,.2,length,metal,0,.13,length/2-.02);
    box('slide',heavy?.21:.17,.11,length*.88,gold?materials.goldLight:materials.black,0,.25,length/2+.01);
    tube('barrel',heavy?.06:.045,length*.76,materials.dark,0,.15,length*.62);
    box('trigger_guard',.14,.035,.2,metal,0,-.005,.16);sight(length-.025,gold?materials.goldLight:materials.dark);
    if(id==='tt_pistol')box('tt_grip_star',.05,.05,.018,materials.goldLight,0,-.13,.095,0,0,Math.PI/4);
    if(gold)box('gold_top_rib',.11,.035,length*.72,materials.goldLight,0,.325,length*.52);
    muzzle(.15,length);
  }else if(id==='sawn_off'||id==='shotgun'){
    const sawn=id==='sawn_off',length=sawn?.88:1.42,metal=materials.dark;
    longGrip(materials.wood,-.02);stock(materials.redWood,sawn?-.28:-.48,sawn?.36:.72);
    box('receiver',.25,.27,.46,metal,0,.12,.24);
    if(sawn){for(const x of [-.075,.075])tube('twin_barrel',.065,length-.38,materials.steel,x,.2,.38+(length-.38)/2)}
    else{tube('barrel',.065,length-.38,materials.steel,0,.2,.38+(length-.38)/2);tube('magazine_tube',.054,.8,materials.dark,0,.065,.84)}
    if(!sawn){box('pump',.28,.25,.34,materials.wood,0,.1,.78);box('fore_end',.22,.12,.28,materials.redWood,0,.27,1.08)}
    else box('break_latch',.16,.07,.09,materials.paleSteel,0,.3,.32);
    sight(length,materials.paleSteel);muzzle(.2,length);
  }else if(id==='uzi'||id==='golden_uzi'){
    const gold=id==='golden_uzi',metal=gold?materials.gold:materials.dark,accent=gold?materials.goldLight:materials.black;
    longGrip(gold?materials.redWood:materials.black,-.02);
    box('receiver',.21,.3,.64,metal,0,.17,.3);box('top_cover',.2,.09,.58,accent,0,.36,.31);
    magazine(accent,-.02,.5,-.05);tube('barrel',.05,.34,accent,0,.22,.79);box('folding_stock',.045,.05,.54,accent,.1,.13,.08,0,.25,0);
    if(gold)box('gold_side_rib',.035,.1,.46,materials.goldLight,.13,.22,.34);
    sight(.96,accent);muzzle(.22,.96);
  }else if(id==='tommy_gun'){
    longGrip(materials.wood,.02);stock(materials.redWood,-.52,.72);box('receiver',.24,.28,.7,materials.dark,0,.19,.32);
    tube('barrel',.055,.72,materials.steel,0,.22,1.02);
    add('drum_magazine',new THREE.CylinderGeometry(.27,.27,.18,14),materials.black,0,-.08,.32,0,0,Math.PI/2);
    box('foregrip',.15,.35,.17,materials.wood,0,-.04,.72,-.28);sight(1.38);muzzle(.22,1.38);
  }else if(id==='ak74'||id==='m16'){
    const ak=id==='ak74',metal=ak?materials.dark:materials.army,grip=ak?materials.redWood:materials.black;
    longGrip(grip,.02);stock(ak?materials.redWood:materials.army,-.57,.78);box('receiver',.22,.27,.69,metal,0,.19,.32);
    magazine(materials.dark,.28,.48,ak?.2:0);tube('barrel',.045,.72,materials.steel,0,.23,1.02);
    if(ak){tube('gas_tube',.035,.58,materials.dark,0,.33,.91);box('wood_foregrip',.21,.21,.47,materials.redWood,0,.17,.76)}
    else{box('m16_foregrip',.2,.22,.55,materials.army,0,.21,.84);box('carry_handle',.11,.04,.42,materials.dark,0,.46,.33);for(const z of [.14,.51])box('carry_handle_support',.1,.12,.045,materials.dark,0,.40,z);box('front_post',.1,.24,.09,materials.dark,0,.38,1.24)}
    sight(1.38);muzzle(.23,1.4);
  }else if(id==='sniper'){
    longGrip(materials.wood,.02);stock(materials.wood,-.64,.9);box('receiver',.2,.24,.72,materials.army,0,.18,.31);
    box('forestock',.2,.18,.76,materials.wood,0,.12,.82);tube('barrel',.045,1.02,materials.dark,0,.23,1.35);
    tube('scope',.075,.66,materials.black,0,.48,.48);tube('scope_lens',.08,.035,materials.lens,0,.48,.83);
    for(const x of [-.15,.15])box('bipod_leg',.035,.47,.035,materials.steel,x,-.08,1.26,0,0,x<0?-.25:.25);
    sight(1.88);muzzle(.23,1.88);
  }else if(id==='rpg'){
    longGrip(materials.black,.08);tube('launcher_tube',.13,1.56,materials.olive,0,.23,.57,12);
    tapered('warhead',.005,.18,.42,materials.army,0,.23,1.52,12);tapered('rear_cone',.2,.13,.3,materials.army,0,.23,-.05,12);
    box('shoulder_pad',.28,.32,.16,materials.black,0,.11,.1);box('rear_sight',.05,.24,.08,materials.dark,.15,.42,.08);box('front_sight',.05,.27,.08,materials.dark,.15,.43,.93);
    muzzle(.23,1.73);
  }

  if(['nagan','revolver'].includes(id)){
    triggerDetails();root.userData.ejectionPort=null;
    for(let chamber=0,count=id==='nagan'?7:6;chamber<count;chamber++){
      const a=chamber*Math.PI*2/count;
      tube(`cylinder_chamber_${chamber}`,.021,.012,materials.black,Math.cos(a)*.066,.11+Math.sin(a)*.066,.376,8);
    }
    box('grip_medallion_l',.018,.07,.07,materials.goldLight,.071,-.15,-.045,0,0,Math.PI/4);
    box('grip_medallion_r',.018,.07,.07,materials.goldLight,-.071,-.15,-.045,0,0,Math.PI/4);
  }else if(['tt_pistol','deagle','golden_colt'].includes(id)){
    triggerDetails();receiverDetails([.105,.255,.34]);
    box('grip_panel_l',.018,.23,.105,id==='golden_colt'?materials.redWood:materials.black,.071,-.16,-.015,-.14);
    box('grip_panel_r',.018,.23,.105,id==='golden_colt'?materials.redWood:materials.black,-.071,-.16,-.015,-.14);
    box('rear_notch',.12,.05,.04,materials.dark,0,.33,.04);
  }else{
    triggerDetails();
    root.userData.supportGrip=({uzi:[0,-.01,.5],golden_uzi:[0,-.01,.5],tommy_gun:[0,-.1,.62],sawn_off:[0,.1,.42],rpg:[0,.09,.46]}[id])??[0,.1,.62];
    if(!['rpg'].includes(id))receiverDetails(id==='shotgun'||id==='sawn_off'?[.14,.3,.29]:[.13,.3,.37]);
    box('sling_stud_front',.045,.045,.04,materials.paleSteel,0,-.02,Math.min(1.1,root.userData.muzzle[2]-.22));
    box('sling_stud_rear',.045,.045,.04,materials.paleSteel,0,-.03,-.11);
  }
  if(root.userData.muzzle){
    const [mx,my,mz]=root.userData.muzzle;
    tube('muzzle_crown',id==='rpg'?.14:id==='shotgun'||id==='sawn_off'?.07:.055,id==='rpg'?.075:.055,materials.black,mx,my,mz-.012,12);
  }
  // The M16 stock must finish at the shoulder plane at every allowed aim pitch;
  // a small model-local forward mount avoids the live back-clipping report while
  // remaining inside the actual two-bone IK reach envelope.
  if(id==='m16'){
    root.userData.mountOffset=[.15,1.1,.18];root.userData.supportGrip=[0,.1,.57];
  }
  if(id==='rpg')root.userData.mountOffset=[.15,1.1,.24];

  // Authored details use the same grip, muzzle and support anchors as the accepted rig.
  const detailMetal=['golden_colt','golden_uzi'].includes(id)?materials.goldLight:materials.steel;
  const sidePin=(name,x,y,z,r=.018)=>add(name,new THREE.CylinderGeometry(r,r,.014,10),detailMetal,x,y,z,0,0,Math.PI/2);
  const band=(name,r,z,y=.23,material=materials.dark)=>tube(name,r,.035,material,0,y,z,12);
  const rib=(name,x,y,z,w=.018,h=.12,d=.016)=>box(name,w,h,d,materials.black,x,y,z);
  const ring=(name,r,y,z,x=0,material=detailMetal)=>add(name,new THREE.TorusGeometry(r,.012,6,16),material,x,y,z);
  if(['nagan','revolver'].includes(id)){
    box('top_strap',.115,.035,.32,detailMetal,0,.235,.22);
    tube('ejector_rod',.023,id==='nagan'?.35:.46,detailMetal,.055,.065,id==='nagan'?.57:.61);
    box('cylinder_crane',.045,.065,.19,detailMetal,-.075,.028,.24);
    box('rear_sight_notch',.095,.035,.055,materials.black,0,.26,.08);
    for(const x of [-.076,.076]){sidePin('grip_screw',x,-.15,-.05);sidePin('frame_screw',x,.12,.08)}
  }else if(['tt_pistol','deagle','golden_colt'].includes(id)){
    const end=id==='deagle'?.77:id==='golden_colt'?.63:.57;
    for(const sign of [-1,1]){
      for(let j=0;j<6;j++)rib('slide_serration',sign*(id==='deagle'?.107:.088),.26,.035+j*.025,.012,.075,.01);
      for(const y of [-.09,-.24])sidePin('grip_screw',sign*.085,y,-.015,.015);
      box('slide_rail',.012,.022,end-.05,detailMetal,sign*.09,.194,end/2);
    }
    box('slide_stop',.025,.025,.095,detailMetal,-.111,.14,.10);
    box('hammer_spur',.06,.065,.065,detailMetal,0,.23,-.055,-.3);
    tube('recoil_spring_plug',.027,.035,detailMetal,0,.07,end);
    if(id==='deagle'){for(let j=0;j<4;j++)box('top_vent',.075,.008,.045,materials.black,0,.309,.40+j*.065)}
    if(id==='golden_colt'){for(const x of [-.098,.098])for(let j=0;j<3;j++)sidePin('engraved_rosette',x,.135,.30+j*.075,.024)}
  }else if(id==='shotgun'||id==='sawn_off'){
    for(const x of [-.132,.132]){sidePin('receiver_rivet',x,.18,.12);sidePin('receiver_rivet',x,.18,.37)}
    if(id==='shotgun'){
      for(let j=0;j<7;j++)box('pump_groove',.286,.018,.013,materials.dark,0,.10,.64+j*.045);
      for(const x of [-.075,.075])box('pump_action_rail',.022,.025,.55,detailMetal,x,.06,.47);
      band('barrel_clamp',.078,1.18,.2);tube('magazine_cap',.061,.045,detailMetal,0,.065,1.23);
    }else{box('barrel_joining_rib',.035,.027,.40,materials.dark,0,.267,.64);box('hinge',.28,.075,.065,detailMetal,0,.04,.40)}
  }else if(id==='uzi'||id==='golden_uzi'){
    box('charging_handle',.095,.055,.075,detailMetal,0,.43,.21);
    for(const z of [.065,.57]){
      box('sight_ear_l',.025,.09,.06,detailMetal,-.075,.43,z);box('sight_ear_r',.025,.09,.06,detailMetal,.075,.43,z);
    }
    for(const x of [-.112,.112])for(let j=0;j<5;j++)box('receiver_vent',.014,.043,.029,materials.black,x,.23,.34+j*.046);
    for(let j=0;j<5;j++)box('foregrip_rib',.223,.021,.02,materials.black,0,.025,.35+j*.04);
    band('barrel_retaining_nut',.085,.665,.22,detailMetal);
    box('magazine_floorplate',.17,.03,.22,detailMetal,0,-.485,-.046);
  }else if(id==='tommy_gun'){
    for(let j=0;j<12;j++)band('cooling_fin',.082,.69+j*.036,.22);
    for(const x of [-.099,.099]){
      add('drum_face_ring',new THREE.TorusGeometry(.205,.013,5,18),detailMetal,x,-.08,.32,0,Math.PI/2);
      sidePin('drum_spindle',x,-.08,.32,.045);
    }
    box('charging_handle',.05,.06,.10,detailMetal,0,.36,.24);
    box('rear_aperture_base',.11,.08,.13,materials.dark,0,.37,.025);
    band('cutts_compensator',.071,1.31,.22,detailMetal);
    for(let j=0;j<3;j++)box('compensator_slot',.08,.014,.015,materials.black,0,.291,1.27+j*.027);
  }else if(id==='ak74'||id==='m16'){
    const ak=id==='ak74';
    // Curved magazine silhouette, extruded across X; follower stays in the receiver.
    const old=root.getObjectByName('magazine');root.remove(old);old.geometry.dispose();
    const shape=new THREE.Shape();shape.moveTo(.18,0);shape.lineTo(.37,0);shape.quadraticCurveTo(.39,-.30,ak?.58:.44,-.46);shape.lineTo(ak?.40:.25,-.50);shape.quadraticCurveTo(.18,-.31,.18,0);
    const geom=new THREE.ExtrudeGeometry(shape,{depth:.145,bevelEnabled:true,bevelSize:.008,bevelThickness:.008,bevelSegments:1,steps:1,curveSegments:5});
    add('magazine',geom,materials.dark,.0725,0,0,0,-Math.PI/2);
    for(const x of [-.117,.117]){for(let j=0;j<3;j++)sidePin('receiver_rivet',x,.14,.10+j*.16)}
    if(ak){
      for(let j=0;j<4;j++)box('handguard_vent',.224,.035,.025,materials.black,0,.22,.61+j*.065);
      band('gas_block',.064,1.15,.30);box('front_sight_base',.065,.18,.07,materials.dark,0,.29,1.30);
      ring('front_sight_hood',.047,.405,1.30);box('charging_bolt',.10,.025,.09,detailMetal,.15,.24,.47);
      tube('dust_cover',.113,.51,materials.dark,0,.247,.30,12);
    }else{
      for(let j=0;j<8;j++)band('handguard_rib',.114,.61+j*.058,.21,materials.black);
      box('forward_assist',.065,.065,.09,detailMetal,.145,.25,.12,0,-.5);
      box('dust_cover_hinge',.025,.022,.18,detailMetal,.144,.25,.37);
      ring('rear_aperture',.032,.465,.15);
    }
    band('flash_hider',.061,1.355,.23,detailMetal);
    for(let j=0;j<4;j++){const a=j*Math.PI/2;box('flash_hider_slot',.014,.014,.065,materials.black,Math.cos(a)*.053,.23+Math.sin(a)*.053,1.355)}
  }else if(id==='sniper'){
    for(const z of [.26,.67]){box('scope_mount',.11,.11,.065,materials.dark,0,.36,z);band('scope_ring',.091,z,.48,detailMetal)}
    tapered('scope_objective',.10,.075,.16,materials.black,0,.48,.76,16);
    band('scope_eye_cup',.092,.15,.48);tube('ocular_lens',.067,.012,materials.lens,0,.48,.14,16);
    add('scope_elevation_turret',new THREE.CylinderGeometry(.046,.046,.07,12),materials.black,0,.57,.46);
    add('scope_windage_turret',new THREE.CylinderGeometry(.04,.04,.06,12),materials.black,.092,.48,.46,0,0,Math.PI/2);
    box('bolt_handle',.16,.025,.035,detailMetal,.145,.21,.08,0,0,-.3);
    add('bolt_knob',new THREE.SphereGeometry(.047,10,8),materials.black,.222,.18,.08);
    for(const x of [-.21,.21])box('bipod_foot',.085,.03,.11,materials.black,x,-.30,1.26);
    band('barrel_collar',.065,1.13);band('muzzle_thread',.056,1.83);
  }else if(id==='rpg'){
    for(const z of [.08,.32,.57,.82])band('launcher_band',.143,z,.23,detailMetal);
    for(let j=0;j<7;j++)box('heat_shield_rib',.17,.018,.025,materials.wood,0,.105,.25+j*.065);
    ring('rear_sight_aperture',.045,.565,.08,.15,materials.dark);
    box('optical_range_plate',.028,.18,.11,materials.black,.15,.44,.65);
    for(let j=0;j<4;j++)box('range_tick',.006,.009,.055,materials.paleSteel,.167,.40+j*.03,.65);
    band('warhead_collar',.106,1.32,.23);band('warhead_seam',.115,1.46,.23,materials.olive);
  }
  // Recessed bores are real annuli with a dark recess, never solid end caps.
  const oldCrown=root.getObjectByName('muzzle_crown');if(oldCrown){root.remove(oldCrown);oldCrown.geometry.dispose()}
  const [mx,my,mz]=root.userData.muzzle;
  const boreRadius=id==='rpg'?.10:id==='shotgun'||id==='sawn_off'?.043:id==='deagle'?.036:.028;
  for(const x of id==='rpg'?[]:id==='sawn_off'?[-.075,.075]:[mx]){
    ring('muzzle_crown',boreRadius+.012,my,mz,x,detailMetal);
    tube('bore_recess',boreRadius,.006,materials.black,x,my,mz-.018,16);
  }
  root.userData.artRevision='artist14-weapons-v1';
  root.updateMatrixWorld(true);
  return root;
}
