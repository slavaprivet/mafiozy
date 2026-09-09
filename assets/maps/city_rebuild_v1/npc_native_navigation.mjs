// Read the same authored world solids and water support used by /walk. This
// query is independent of the player's posture, position and camera.
export function createNpcNativeNavigation({worldScale=4.1,waterAt=()=>null,groundHeight=()=>0,bodiesAt=()=>[],containsBody,terrainAllows=()=>true,blocksDynamic=()=>false,height=1.9}={}){
 if(typeof containsBody!=='function')throw new TypeError('NPC navigation requires a polygon containment query');
 const counts={queries:0,solid:0,water:0,cacheHits:0},cache=new Map(),dynamicBody={y:0,height};
 function query({r,c}={}){
  if(!Number.isFinite(r)||!Number.isFinite(c))return {blocked:true,depth:0};
  const key=r+'|'+c,cached=cache.get(key);if(cached){counts.cacheHits++;return cached;}
  const x=c*worldScale,z=r*worldScale,floor=groundHeight(x,z),water=waterAt(x,z);
  const depth=water&&Number.isFinite(water.level)?Math.max(0,water.level-floor):Math.max(0,Number(water?.depth)||0);
  let blocked=!Number.isFinite(floor)||!terrainAllows(x,z);
  if(!blocked)for(const body of bodiesAt(c,r)||[]){
   if(Number.isFinite(body.maxYM)&&body.maxYM<=floor+.05)continue;
   if(Number.isFinite(body.minYM)&&body.minYM>=floor+height)continue;
   if(containsBody(body,r,c)){blocked=true;break;}
  }
  // The callback only samples the current query synchronously.  Reusing this
  // small context avoids one short-lived object for every uncached route cell.
  if(!blocked){dynamicBody.y=floor;blocked=!!blocksDynamic(x,z,dynamicBody);}
  counts.queries++;if(blocked)counts.solid++;if(depth>.025)counts.water++;
  const result={blocked,depth};if(cache.size<30000)cache.set(key,result);return result;
 }
 return {query,beginFrame:()=>cache.clear(),diagnostics:()=>({...counts})};
}
