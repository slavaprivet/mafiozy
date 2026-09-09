// Per-model upholstery. Geometry, seat anchors and source/body materials are untouched.
const palette=(label,seat,insert,door,dash,fascia,stitch)=>Object.freeze({label,seat,insert,door,dash,fascia,stitch,floor:'#252b2e'});
export const VEHICLE_INTERIOR_COLORS=Object.freeze({
 red_demo:palette('Бордовый','#632d3b','#7f3b49','#463039','#26282a','#393b3e','#ae8487'),
 city_hatchback:palette('Серый','#657078','#7c868a','#394348','#242b30','#566168','#aab3b6'),
 compact_sedan:palette('Графитовый','#353b40','#515a60','#30373c','#22272b','#424b52','#7f8b93'),
 family_wagon:palette('Серый тканевый','#586268','#758086','#424d53','#293238','#5e6d75','#a0adb3'),
 executive_sedan:palette('Тёмно-бордовый','#502c37','#743842','#3b272e','#23262a','#444149','#a37b85'),
 sport_coupe:palette('Красный','#8b303a','#ac4045','#572a31','#22252a','#383d43','#d38187'),
 city_suv:palette('Чёрный','#252c2c','#3b4645','#242c2b','#202627','#455250','#75847f'),
 delivery_van:palette('Серый служебный','#626a6d','#7e8585','#485257','#30393d','#5c696d','#a5afae'),
 utility_pickup:palette('Тёмно-серый','#3e4444','#626a65','#333c39','#262d2e','#505b57','#919b94'),
 city_bus:palette('Серо-синий','#3c515d','#587381','#34454d','#29383e','#536a72','#91a6af'),
 police_interceptor:palette('Чёрный служебный','#23292e','#363e47','#252d34','#1e252c','#3e4953','#687887'),
 city_ambulance:palette('Светло-серый','#747f82','#a2abad','#536167','#3a484d','#778b90','#c0cbcc'),
 fire_engine:palette('Бордово-серый','#65353a','#8f4348','#432f34','#292e32','#505b60','#b27e80'),
 city_taxi:palette('Чёрный износостойкий','#262b2e','#3a4044','#262d31','#1e2529','#434d53','#77858b'),
});
const ownedByCar=new WeakMap();
function roleFor(name){
 if(/^(front|rear)_(left|right)_(seat_insert|insert|back_insert)$/.test(name))return'insert';
 if(/^(front|rear)_(left|right)_(cushion|back|headrest)$/.test(name))return'seat';
 if(/^(front|rear)_(left|right)_(seat|back)_seam$/.test(name))return'stitch';
 if(/^Door_inner_/.test(name))return'door';
 if(/^Door_armrest_/.test(name))return'insert';
 if(/^Dashboard_(wood_)?fascia$/.test(name))return'fascia';
 if(/^(Dashboard_shell|Dashboard_vent|Gear_console|Transmission_tunnel|Steering_rim|Gear_knob)$/.test(name))return'dash';
 if(name==='Cabin_floor')return'floor';
 return null;
}
export function applyVehicleInteriorColors(car,modelId){
 const root=car.object||car,colors=VEHICLE_INTERIOR_COLORS[modelId]||VEHICLE_INTERIOR_COLORS.compact_sedan;
 let owned=ownedByCar.get(root);if(!owned){owned=new Map();ownedByCar.set(root,owned)}
 let meshes=0;
 root.traverse(node=>{
  if(!node.isMesh)return;const role=roleFor(node.name);if(!role)return;
  const recolor=source=>{
   if(!source?.color||source.transparent)return source;
   const original=source.userData.interiorPaletteSource||source.uuid,key=original+':'+role;
   let material=owned.get(key);
   if(!material){material=source.clone();material.name='Interior_'+role;material.userData={...source.userData,interiorPaletteSource:original,interiorPaletteRole:role};owned.set(key,material)}
   material.color.set(colors[role]);material.metalness=role==='fascia'?.08:0;material.roughness=role==='fascia'?.68:.88;return material;
  };
  node.material=Array.isArray(node.material)?node.material.map(recolor):recolor(node.material);meshes++;
 });
 root.userData.interiorPalette={id:modelId,label:colors.label,seat:colors.seat,insert:colors.insert};
 return {id:modelId,label:colors.label,meshes,materials:owned.size};
}
