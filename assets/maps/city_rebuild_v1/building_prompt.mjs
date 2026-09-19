import {resolveBuildingPurpose} from './building_interior_purpose.mjs';
export function buildingDoorPrompt(candidate){
 if(candidate?.kind==='building'&&candidate.entry?.kind==='detention')return `${resolveBuildingPurpose(candidate.entry.instance).label} — ${candidate.name??'дверь'}: ${candidate.opening?'закрыть':'открыть'}`;
 if(candidate?.kind!=='building'||candidate.door)return candidate?.action??'';
 const i=candidate.entry?.instance??{},name=resolveBuildingPurpose(i).label;
 return `${name} — ${candidate.opening?'закрыть дверь':'открыть дверь'}`;
}
