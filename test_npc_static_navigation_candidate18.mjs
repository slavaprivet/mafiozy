// Isolated source transform only: production is unchanged.
import fs from 'node:fs';
const path=new URL('./assets/maps/city_rebuild_v1/npc_native_navigation.mjs',import.meta.url);
export function staticNavigationCandidate(source=fs.readFileSync(path,'utf8')){
 source=source.replace("'./npc_swept_footprint.mjs'",JSON.stringify(new URL('./assets/maps/city_rebuild_v1/npc_swept_footprint.mjs',import.meta.url).href));
 source=source.replace('height=1.9}={})','height=1.9,getStaticRevision=null,maxStaticPoints=30000,maxStaticSweeps=12000}={})');
 source=source.replace(' let activeBody=null;',` const staticPoints=new Map(),staticSweeps=new Map();let staticRevision,staticReady=false;
 function invalidateStatic(){staticPoints.clear();staticSweeps.clear();}
 function refreshStatic(){if(!getStaticRevision)return;const revision=getStaticRevision();if(!staticReady||revision!==staticRevision){invalidateStatic();staticRevision=revision;staticReady=true;}}
 function retain(map,key,value,limit){if(map.size>=limit)map.delete(map.keys().next().value);map.set(key,value);return value;}
 let activeBody=null;`);
 source=source.replace("counts.sweepQueries++;footprint.set(from,to,radius);",`if(getStaticRevision){const retained=staticSweeps.get(key);if(retained){counts.cacheHits++;sweepCache.set(key,retained);return retained;}}
  counts.sweepQueries++;footprint.set(from,to,radius);`);
 source=source.replace('if(sweepCache.size<4000)sweepCache.set(key,result);return result;', 'if(sweepCache.size<4000)sweepCache.set(key,result);if(getStaticRevision)retain(staticSweeps,key,result,maxStaticSweeps);return result;');
 source=source.replace('  if(mode===\'sweep\')', '  if(!staticReady)refreshStatic();\n  if(mode===\'sweep\')');
 source=source.replace('const x=c*worldScale,z=r*worldScale,floor=groundHeight(x,z),water=waterAt(x,z);', `const x=c*worldScale,z=r*worldScale,staticKey=r+'|'+c,retained=getStaticRevision?staticPoints.get(staticKey):null,floor=retained?retained.floor:groundHeight(x,z),water=waterAt(x,z);`);
 source=source.replace('  let blocked=!Number.isFinite(floor)||!terrainAllows(x,z);\n  if(!blocked)for(const body of bodiesAt(c,r)||[]){', `  let staticBlocked=retained?retained.blocked:!Number.isFinite(floor);
  if(!retained&&!staticBlocked)for(const body of bodiesAt(c,r)||[]){`);
 source=source.replace('if(containsBody(body,r,c)){blocked=true;break;}', 'if(containsBody(body,r,c)){staticBlocked=true;break;}');
 source=source.replace('  // The callback only samples', `  if(getStaticRevision&&!retained)retain(staticPoints,staticKey,{floor,blocked:staticBlocked},maxStaticPoints);
  let blocked=staticBlocked||!terrainAllows(x,z);
  // The callback only samples`);
 source=source.replace('beginFrame:()=>{cache.clear();sweepCache.clear();}', 'beginFrame:()=>{refreshStatic();cache.clear();sweepCache.clear();},invalidateStatic');
 return source;
}
export async function loadStaticNavigationCandidate(){return import('data:text/javascript;base64,'+Buffer.from(staticNavigationCandidate()).toString('base64'));}
