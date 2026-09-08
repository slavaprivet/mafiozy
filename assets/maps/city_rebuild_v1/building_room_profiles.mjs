// Audited ground-floor main volumes in original GLB visual coordinates (metres).
// Bounds exclude roofs, porticoes, bay-window furniture and facade trim. Room
// insets retain the real exterior wall; no placement/ownership/gameplay ID change.
export const BUILDING_ROOM_PROFILES=Object.freeze({
 old_town_narrow_townhouse_v1:{source:'OldTownTerracotta ground-floor shell',bounds:[-1.76,-3.65,1.76,3.65],inset:.17},
 eastside_garden_walkup_v1:{source:'EastsideSandStucco ground-floor shell',bounds:[-1.43,-7.36,1.43,7.36],inset:.17},
 eastside_stepped_apartment_v1:{source:'EastsideRoseSand ground-floor shell',bounds:[-1.43,-7,1.43,7.05],inset:.17},
 coastal_orchard_house_v1:{source:'MainBody',bounds:[-4.075,-4.9,4.075,4.9],inset:.24},
 garden_lane_house_v1:{source:'MainBody',bounds:[-2.65,-5.7,2.65,5.7],inset:.24},
 hillstep_chalet_v1:{source:'MainBody',bounds:[-3.175,-5.4,3.175,5.4],inset:.24},
 pine_ridge_cottage_v1:{source:'MainBody',bounds:[-3.125,-5.8,3.125,5.8],inset:.24},
 veranda_bungalow_v1:{source:'MainBody',bounds:[-4.125,-4.6,4.125,4.6],inset:.24},
 woodland_crosswing_house_v1:{source:'MainBody; connected CrossWing remains same facade',bounds:[-3.1,-6.1,3.1,6.1],inset:.24},
 pawnshop:{source:'Main_brick_volume',bounds:[-6,-4.6,6,4.6],inset:.35},
 print_shop:{source:'Main_print_hall',bounds:[-8.3,-5.9,7.5,4.3],inset:.35},
 gun_shop:{source:'Long_armory_shell',bounds:[-7.6,-4.75,7.6,4.75],inset:.35},
 bookmaker:{source:'Betting_hall_shell',bounds:[-7.75,-4.7,7.75,4.7],inset:.35},
 nightclub:{source:'MainHall',bounds:[-6,-4.4,6,3.7],inset:.35},
 civic_hall:{source:'CivicHall_MainBody; portico connects through short corridor',bounds:[-5.3,.3,5.3,9.9],inset:.35},
 hospital:{source:'Hospital_MainWing; public entrance through atrium',bounds:[-9.1,-2.3,4.7,10.3],inset:.35},
 compact_podium_glass_tower_v1:{source:'LightLimestone connected podium component y0..4.4',bounds:[-8.6,-6.7,7,6.7],inset:.45},
 glass_pavilion_small_v1:{source:'Small_Rear_Core + ground-floor glazed front hall; retain facade display pockets',bounds:[-5.8,-4.4,5.8,4.5],inset:.75},
 strip_club:{source:'Club_First_Floor',bounds:[-6,-4.5,6,4.5],inset:.2},
});

export function resolveRoomRect(THREE,assetId,visual,space,bankProfile=null){
 const profile=bankProfile??BUILDING_ROOM_PROFILES[assetId];if(!profile)throw Error(`Room profile missing: ${assetId}`);
 const [minX,minZ,maxX,maxZ]=profile.bounds,s=profile.inset,box=new THREE.Box3();
 for(const [x,z]of [[minX+s,minZ+s],[maxX-s,minZ+s],[maxX-s,maxZ-s],[minX+s,maxZ-s]])box.expandByPoint(space.worldToLocal(visual.localToWorld(new THREE.Vector3(x,0,z))));
 return {rect:[box.min.x,box.min.z,box.max.x,box.max.z],source:profile.source,sourceBounds:profile.bounds.slice(),inset:s};
}

export function createBuildingContentRoot(THREE,parent,instance,position){
 const root=new THREE.Group();root.name=`Building_Content_${instance.id}`;root.userData={buildingInstanceId:instance.id,gameplayId:instance.gameplayId??null,assetId:instance.assetId,emptyRoom:true,previewOnly:true};if(position)root.position.copy(position);parent.add(root);return root;
}
