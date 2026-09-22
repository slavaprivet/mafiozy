// QA only: fixed buckets, no object IDs, retained scene nodes or estimates.
export const SHADOW_CATEGORIES=Object.freeze(['npc','transport','lamps','buildingsInteriors','decor','water','other']);
export function shadowSubmissionCategory(object){
 let kind=null;
 for(let node=object;node;node=node.parent){
  const data=node.userData||{},name=String(node.name||''),item=data.instance;
  if(data.sourceVehicleId||data.vehicleFleetId)return 'transport';
  if(/^NPC_/.test(name))return 'npc';
  if(kind)continue;
  if(SHADOW_CATEGORIES.includes(data.shadowCensusCategory)){kind=data.shadowCensusCategory;continue;}
  if(data.staticRenderBatch){kind='other';continue;}
  if(data.landscapeWater||data.nativeTerrainKind==='water'||data.surfaceKind==='water'||data.environmentSurface==='water'){kind='water';continue;}
  if(/^StreetLamp_/.test(name)||/^lamp_/.test(item?.assetId||'')){kind='lamps';continue;}
  if(data.renderIsolationInteriorFurnishings||/^Interior_Furnishings_/.test(name)){kind='buildingsInteriors';continue;}
  if(item){kind='other';continue;}
  if(data.explorationDecor||data.environmentGrass||data.landscapeGround||data.roadEquipmentBatched||/^(Grass_|GrassChunk_|ExplorationChunk_|RoadEquipment|RoadPaint:|CityRoadDressing)/.test(name))kind='decor';
 }
 return kind||'other';
}

// Called only by perfqa while batches are created. Mixed batches stay whole.
export function tagShadowBatch(batch,members){
 let kind=null,mixed=false;
 for(let index=0;index<members.length;index++){
  if(index&&members[index].mesh===members[index-1].mesh)continue;
  const next=shadowSubmissionCategory(members[index].mesh);
  if(kind!==null&&kind!==next){mixed=true;break;}kind=next;
 }
 batch.userData.shadowCensusCategory=mixed?'other':kind||'other';
 batch.userData.shadowCensusMixed=mixed;
}

export function createShadowSubmissionCensus(){
 const values=new Float64Array(SHADOW_CATEGORIES.length*2);let invalidDeltas=0,mixedCalls=0,mixedTriangles=0;
 const valid=value=>Number.isSafeInteger(value)&&value>=0;
 const invalidate=()=>{invalidDeltas=Math.min(1000000,invalidDeltas+1);};
 function reset(){values.fill(0);invalidDeltas=mixedCalls=mixedTriangles=0;}
 function add(object,submissions,triangles){
  if(!valid(submissions)||!valid(triangles)||!submissions&&triangles){invalidate();return;}
  if(!submissions)return;
  try{
   const offset=SHADOW_CATEGORIES.indexOf(shadowSubmissionCategory(object))*2;
   if(!valid(values[offset]+submissions)||!valid(values[offset+1]+triangles)){invalidate();return;}
   values[offset]+=submissions;values[offset+1]+=triangles;
   if(object?.userData?.shadowCensusMixed===true){mixedCalls+=submissions;mixedTriangles+=triangles;}
  }catch{invalidate();}
 }
 function snapshot({frame=0,enabled=true,ready=true,expectedCalls=0,expectedTriangles=0}={}){
  const categories={};let submissions=0,triangles=0;
  for(let index=0;index<SHADOW_CATEGORIES.length;index++){
   const calls=values[index*2],tris=values[index*2+1];categories[SHADOW_CATEGORIES[index]]={submissions:calls,triangles:tris};submissions+=calls;triangles+=tris;
  }
  const matches=valid(submissions)&&valid(triangles)&&submissions===expectedCalls&&triangles===expectedTriangles;
  return {schema:1,scope:'last-frame-shadow',frame:valid(frame)?frame:0,status:!enabled?'disabled':!ready?'warming':invalidDeltas||!matches?'invalid':'ok',totals:{submissions,triangles},expected:{submissions:valid(expectedCalls)?expectedCalls:null,triangles:valid(expectedTriangles)?expectedTriangles:null},categories,mixed:{submissions:mixedCalls,triangles:mixedTriangles},invalidDeltas};
 }
 return {add,reset,invalidate,snapshot};
}
