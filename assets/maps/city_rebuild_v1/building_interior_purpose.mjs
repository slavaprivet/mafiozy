// The name seen at the entrance is the same identity used to furnish its rooms.
// A visual shell never invents a different business or changes its gameplay ID.
const assets={
 civic_hall:['civic','Ратуша'],hospital:['hospital','Больница'],nightclub:['nightclub','Ночной клуб'],
 pawnshop:['pawnshop','Ломбард'],print_shop:['print_shop','Типография'],gun_shop:['gun_shop','Оружейный магазин'],bookmaker:['bookmaker','Букмекерская'],strip_club:['strip_club','Стрип-клуб'],glass_pavilion_small_v1:['retail','Торговый павильон'],
 old_town_narrow_townhouse_v1:['residential','Городской дом'],eastside_garden_walkup_v1:['residential','Многоквартирный дом'],eastside_stepped_apartment_v1:['residential','Многоквартирный дом'],coastal_orchard_house_v1:['residential','Прибрежный дом'],garden_lane_house_v1:['residential','Дом с садом'],hillstep_chalet_v1:['residential','Шале'],pine_ridge_cottage_v1:['residential','Коттедж'],veranda_bungalow_v1:['residential','Бунгало'],woodland_crosswing_house_v1:['residential','Лесной дом'],compact_podium_glass_tower_v1:['residential','Жилая башня'],
 bank_small_shell_v1:['bank','Малый банк'],bank_medium_shell_v1:['bank','Банк'],bank_large_shell_v1:['bank','Главный банк'],police_station:['police','Полицейский комплекс'],fire_station:['fire_station','Пожарная часть'],
};
const rules=[
 ['hotel',/hotel|motel|отел|гостиниц|мотел/i],['hospital',/hospital|clinic|больниц|поликлиник|клиник/i],
 ['fire_station',/fire_station|пожарн/i],['police',/police|полиц/i],['bank',/bank|банк/i],
 ['strip_club',/strip|стрип/i],['nightclub',/nightclub|night_club|ночн.*клуб/i],
 ['restaurant',/restaurant|cafe|diner|ресторан|кафе|столов/i],['pawnshop',/pawn|ломбард/i],
 ['gun_shop',/gun_shop|weapon_shop|оружейн/i],['bookmaker',/bookmaker|букмекер/i],
 ['print_shop',/print_shop|типограф/i],['workshop',/workshop|garage|auto_service|автосервис|мастерск/i],
 ['warehouse',/warehouse|склад/i],['civic',/civic|town_hall|ратуш|мэри/i],
 ['retail',/retail|shop|store|магазин|торгов/i],['residential',/residen|apartment|cottage|house|жил|дом|квартир|коттедж|шале|бунгало/i],
];
export function resolveBuildingPurpose(instance={}){
 const explicitLabel=String(instance.displayName||instance.name||'').trim(),
  explicitType=String(instance.interiorPurpose||instance.businessType||instance.operationType||instance.metadata?.businessType||instance.metadata?.purpose||'').trim(),
  authored=assets[instance.assetId],declared=[explicitType,explicitLabel].filter(Boolean).join(' '),
  matched=rules.find(([,pattern])=>pattern.test(declared)),fallback=rules.find(([,pattern])=>pattern.test(instance.assetId||'')),
  kind=instance.bankLayout||instance.role==='bank_shell'?'bank':matched?.[0]||authored?.[0]||fallback?.[0]||(instance.role==='residence'?'residential':'office');
 return {kind,label:explicitLabel||authored?.[1]||instance.roomSizing?.label||'Здание',assetId:instance.assetId||'',buildingId:instance.id||'',gameplayId:instance.gameplayId??null,source:matched?'declared-name-or-type':authored?'authored-asset':'role'};
}
