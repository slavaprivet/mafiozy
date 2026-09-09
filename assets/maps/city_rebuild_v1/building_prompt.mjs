const names={civic_hall:'Ратуша',hospital:'Больница',nightclub:'Ночной клуб',pawnshop:'Ломбард',print_shop:'Типография',gun_shop:'Оружейный магазин',bookmaker:'Букмекерская',strip_club:'Стрип-клуб',glass_pavilion_small_v1:'Торговый павильон',old_town_narrow_townhouse_v1:'Городской дом',eastside_garden_walkup_v1:'Многоквартирный дом',eastside_stepped_apartment_v1:'Многоквартирный дом',coastal_orchard_house_v1:'Прибрежный дом',garden_lane_house_v1:'Дом с садом',hillstep_chalet_v1:'Шале',pine_ridge_cottage_v1:'Коттедж',veranda_bungalow_v1:'Бунгало',woodland_crosswing_house_v1:'Лесной дом',compact_podium_glass_tower_v1:'Жилая башня',bank_small_shell_v1:'Малый банк',bank_medium_shell_v1:'Банк',bank_large_shell_v1:'Главный банк'};
export function buildingDoorPrompt(candidate){
 if(candidate?.kind!=='building'||candidate.door)return candidate?.action??'';
 const i=candidate.entry?.instance??{},name=i.displayName||i.name||names[i.assetId]||i.roomSizing?.label||'Здание';
 return `${name} — ${candidate.opening?'закрыть дверь':'открыть дверь'}`;
}
