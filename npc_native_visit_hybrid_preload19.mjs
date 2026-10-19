// CPU-only injection of prototype into existing test fixtures. Not used by game.
import fs from 'node:fs';import {nativeVisitHybridCandidate19} from './npc_native_visit_hybrid_candidate19.mjs';
const actualRead=fs.readFileSync,helper=actualRead('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8'),world=actualRead('world.html','utf8'),candidate=nativeVisitHybridCandidate19(helper,world);
fs.readFileSync=function(path,...args){if(String(path).replaceAll('\\','/').endsWith('/npc_native_directed_route_source.js'))return typeof args[0]==='string'||args[0]?.encoding?candidate:Buffer.from(candidate);return actualRead.call(this,path,...args);};
