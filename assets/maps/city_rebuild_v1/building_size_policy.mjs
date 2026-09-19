// User-approved 2026-09-08: enlarge exterior and empty room together.
// Horizontal-only scale retains floor/ceiling heights and the city metre unit.
import {preserveBuildingSiteScale} from './building_site_scale.mjs';
export const SITE_BODY_SCALES=Object.freeze({hospital:1.3636362636363635,civic_hall:1.345291368314171});
export const BUILDING_SIZE_POLICY=Object.freeze({
 old_town_narrow_townhouse_v1:[1.8,1.15,'Небольшой городской дом'],
 eastside_garden_walkup_v1:[2,1.1,'Многоквартирный дом'],
 eastside_stepped_apartment_v1:[2,1.1,'Многоквартирный дом'],
 coastal_orchard_house_v1:[1.1,1.1,'Частный дом'],
 garden_lane_house_v1:[1.2,1.1,'Небольшой частный дом'],
 hillstep_chalet_v1:[1.15,1.1,'Шале'],
 pine_ridge_cottage_v1:[1.15,1.1,'Коттедж'],
 veranda_bungalow_v1:[1.1,1.1,'Бунгало'],
 woodland_crosswing_house_v1:[1.15,1.1,'Частный дом'],
 pawnshop:[1.15,1.15,'Небольшой магазин / ломбард'],
 gun_shop:[1.25,1.25,'Оружейный магазин'],
 bookmaker:[1.2,1.2,'Букмекерская'],
 print_shop:[1.4,1.4,'Производственный зал'],
 nightclub:[1.9,1.9,'Большой клубный зал'],
 strip_club:[1.7,1.7,'Клубный зал'],
 hospital:[1.9,1.9,'Больница, основной этаж'],
 civic_hall:[1.7,1.7,'Общественный зал'],
 compact_podium_glass_tower_v1:[1.4,1.4,'Просторный первый этаж башни'],
 glass_pavilion_small_v1:[1.2,1.2,'Небольшой торговый павильон'],
});

export function applyBuildingSizeTransform(visual,instance,THREE){
 const scale=instance?.transform?.horizontalScale;
 if(!scale)return;
 // Reviewed spacious-house plans can exceed the previous 3x limit on their
 // narrow authored axis. Vertical scale and the common world metre stay fixed.
 if(!visual.parent||scale.length!==2||scale.some(s=>!Number.isFinite(s)||s<1||s>4))throw Error('Invalid building horizontal scale');
 const base=instance.transform.uniformScale??1;
 visual.parent.scale.set(base*scale[0],base,base*scale[1]);
 visual.updateWorldMatrix(true,true);
 if(instance.transform.preserveSiteBounds){
  if(!THREE)throw Error('Site resize requires THREE');
  const site=preserveBuildingSiteScale({THREE,visual,assetId:instance.assetId,requestedScale:scale[0]});
  if(Math.abs(site.knownScale-scale[0])>1e-6)throw Error('Authored building no longer matches planned site scale');
 }
}

export function describeWorldRoom(entry){
 if(!entry)return;
 const s=entry.instance.transform?.horizontalScale??[1,1],r=entry.report.room;
 // Entry rotates by 0 or PI relative to the authored GLB, so X/Z axes agree.
 entry.report.roomWorld={width:r.width*s[0],depth:r.usableDepth*s[1],area:r.area*s[0]*s[1],height:r.height};
 entry.contentRoot.userData.roomWorld={...entry.report.roomWorld};
}
