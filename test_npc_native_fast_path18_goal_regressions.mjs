// Exercise existing regression modules against the staged source without
// changing the file the browser currently serves.
import fs from 'node:fs';
import {stageNativeGoalAnchors} from './test_npc_native_fast_path18_goal_candidate.mjs';
const path='assets/maps/city_rebuild_v1/npc_native_directed_route_source.js',original=fs.readFileSync,source=original(path,'utf8'),applied=source.includes('search.goalDiscovery={candidates,index:0,anchors:new Map()}'),candidate=applied?source:stageNativeGoalAnchors(source);
fs.readFileSync=function(file,...args){
 const name=String(file).replaceAll('\\','/');
 if(name.endsWith('/npc_native_directed_route_source.js')){const encoding=typeof args[0]==='string'?args[0]:args[0]?.encoding;return encoding?candidate:Buffer.from(candidate);}
 return original.call(this,file,...args);
};
try{
 await import('./test_npc_native_fast_path18.mjs?goal-candidate');
 await import('./test_npc_native_fast_path18_adaptive.mjs?goal-candidate');
 await import('./assets/maps/city_rebuild_v1/test_npc_actual_shop_visit.mjs?goal-candidate');
}finally{fs.readFileSync=original;}
console.log('PASS '+(applied?'applied':'staged')+' goal anchors: existing direct, adaptive and actual shop visit regressions; production file unchanged');
