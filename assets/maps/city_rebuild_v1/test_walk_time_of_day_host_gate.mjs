import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const hostPath=path.resolve(process.env.WALK_PREVIEW_CANDIDATE||path.join(here,'walk_preview.mjs'));
const source=fs.readFileSync(hostPath,'utf8');
const requireIntegrated=process.env.WALK_TOD_REQUIRE_INTEGRATED==='1';
const count=pattern=>(source.match(pattern)||[]).length;
const requirePattern=(pattern,label)=>assert.match(source,pattern,label);
function bodyAfter(anchor){
 const start=source.indexOf(anchor);assert.ok(start>=0,`missing semantic anchor: ${anchor}`);
 const open=source.indexOf('{',start);assert.ok(open>=0,`missing body after: ${anchor}`);
 let depth=0,quote='',escape=false;
 for(let i=open;i<source.length;i++){
  const char=source[i];
  if(quote){if(escape)escape=false;else if(char==='\\')escape=true;else if(char===quote)quote='';continue}
  if(char==='"'||char==="'"||char==='`'){quote=char;continue}
  if(char==='{')depth++;else if(char==='}'&&--depth===0)return source.slice(open+1,i);
 }
 assert.fail(`unterminated body after: ${anchor}`);
}

const preflight=[
 [/createStreetLighting.*street_lighting\.mjs/,'street-lighting import'],
 [/const scene=new THREE\.Scene\(\)/,'scene'],
 [/scene\.fog=new THREE\.Fog\(/,'existing linear fog'],
 [/toneMappingExposure\s*=/,'renderer exposure'],
 [/scene\.environmentIntensity\s*=/,'environment intensity'],
 [/new THREE\.HemisphereLight\(/,'hemisphere ambient'],
 [/new THREE\.DirectionalLight\(/,'sun'],
 [/npcBridge=window\.Mafiozi3DBridge/,'authoritative bridge'],
 [/function insideBuilding\(\)/,'interior authority'],
 [/\$\('night-toggle'\)\.onclick/,'night QA control'],
 [/function frame\(\)/,'frame loop'],
 [/streetLighting\.update\(/,'street-lighting update'],
 [/addEventListener\('pagehide'/,'host disposal'],
];
for(const [pattern,label]of preflight)requirePattern(pattern,`missing host anchor: ${label}`);

const integrated=/from ['"]\.\/walk_time_of_day\.mjs['"]/.test(source)||/createWalkTimeOfDay\s*\(/.test(source);
if(integrated||requireIntegrated){
 requirePattern(/import\s*\{[^}]*createWalkTimeOfDay[^}]*\}\s*from ['"]\.\/walk_time_of_day\.mjs['"]/,'time-of-day import');
 assert.equal(count(/createWalkTimeOfDay\s*\(/g),1,'create exactly one time-of-day controller');
 assert.equal(count(/walkTimeOfDay\.update\s*\(/g),1,'update exactly once in the host');
 assert.equal(count(/walkTimeOfDay\.apply\s*\(/g),1,'apply exactly once in the host');
 const frame=bodyAfter('function frame()');
 assert.equal((frame.match(/walkTimeOfDay\.update\s*\(/g)||[]).length,1,'update once per frame loop');
 assert.equal((frame.match(/walkTimeOfDay\.apply\s*\(/g)||[]).length,1,'apply once per frame loop');
 const updateAt=frame.indexOf('walkTimeOfDay.update'),applyAt=frame.indexOf('walkTimeOfDay.apply'),cullAt=frame.indexOf('if(now-lastCull>250)'),streetAt=frame.indexOf('streetLighting.update');
 assert.ok(updateAt>=0&&updateAt<applyAt&&applyAt<cullAt&&cullAt<streetAt,'order must be update -> apply -> cull -> streetLighting');
 const reader=bodyAfter('function readWalkTimeSource()');
 assert.match(reader,/npcBridge\?\.getEnvironmentState\?\.\(\)/,'poll authoritative bridge environment through the bounded reader');
 assert.match(reader,/npcBridge\?\.getInteriorState\?\.\(\)/,'sample source interior only on the 250ms reader cadence');
 assert.match(source,/\bwalkTimeTargets\s*=\s*\{[^}]*scene[^}]*ambient[^}]*sun[^}]*renderer[^}]*sunOffsetVector\s*:\s*walkSunOffset[^}]*interiorLightingActive/,'reuse a complete apply-target object');
 assert.match(frame,/walkTimeOfDay\.apply\s*\(\s*walkTimeFrame\s*,\s*walkTimeTargets\s*\)/,'apply with reusable targets');
 assert.doesNotMatch(frame,/walkTimeOfDay\.apply\s*\([^;]*\{/,'no per-frame apply target allocation');
 assert.match(frame,/environmentNight\s*=\s*\w+\.night/,'publish solar night');
 assert.match(frame,/environmentLampPower\s*=\s*\w+\.lampPower/,'publish scheduled lamp power');
 assert.match(frame,/streetLighting\.update\s*\(\{[^}]*night\s*:\s*environmentLampPower/,'street lights consume lamp power');
 assert.match(frame,/sun\.position\.copy\([^)]*\)\.add\(walkSunOffset\)/,'sun uses reusable offset');
 assert.doesNotMatch(frame,/new THREE\.Vector3\(\s*-75\s*,\s*130\s*,\s*90\s*\)/,'no per-cull sun-offset allocation');
 const nightHandler=bodyAfter("$('night-toggle').onclick");
 assert.match(nightHandler,/walkTimeOfDay\.setOffset\s*\(/,'night QA uses explicit offset');
 assert.doesNotMatch(nightHandler,/(?:ambient|sun)\.intensity\s*=|scene\.(?:background|fog|environmentIntensity)/,'night QA cannot mutate render channels directly');
 assert.match(source,/dataset\.walkTimeOfDay\s*=/,'time-of-day diagnostics');
 assert.match(bodyAfter('if(now-lastStats>1000)'),/dataset\.walkTimeOfDay\s*=/,'diagnostics use existing one-second cadence');
 assert.equal(count(/walkTimeOfDay\.dispose\s*\(/g),1,'dispose controller exactly once');
 const clearContent=bodyAfter('function clearContent(');
 assert.doesNotMatch(clearContent,/createWalkTimeOfDay|walkTimeOfDay\.dispose/,'content rebuild cannot recreate or dispose controller');
}

console.log(JSON.stringify({passed:true,status:integrated?'integrated-semantic-gate':'HOLD-ready',integrationDetected:integrated,requireIntegrated,hostPath,wholeFileHashRequired:false,anchors:preflight.map(([,label])=>label),integratedChecks:integrated||requireIntegrated?['single_controller','single_update_apply_in_frame','update_apply_cull_street_order','bounded_clock_and_interior_reader','reusable_apply_targets','night_and_lamp_outputs','street_lamp_power','reusable_sun_offset','qa_offset_only','one_second_diagnostics','single_dispose','survives_clearContent']:[]}));
