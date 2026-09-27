// Executes the original module unchanged. Bridge replies are explicit test data,
// not a replacement implementation of Walk admission or a gameplay authority.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const sourcePath='assets/maps/city_rebuild_v1/world_walk_melee_input.mjs';
const {createWorldWalkMeleeInput}=await import(pathToFileURL(path.join(root,sourcePath)));
const op=(method,time,options={},extra={})=>({method,now:time,options:{time,...options},...extra});
const block=value=>({method:'block',value});
const cancel=()=>({method:'cancel'});
const cases=[
 ['click_and_expiry',[op('press',0,{yaw:.7,airHeight:-3}),op('press',.1),op('step',.17),op('release',.2),op('step',.34),op('press',.5),cancel(),cancel()]],
 ['auto_heavy_reserved',[op('press',0),op('step',.34),op('step',1.199),op('step',1.2),op('release',1.21),op('press',1.3),op('step',1.7),op('release',1.8),cancel()]],
 ['release_heavy',[op('press',2),op('release',3.2),op('step',3.4),op('step',3.7),cancel()]],
 ['release_cancelled',[op('press',0),op('release',1.5,{cancelled:true}),op('press',2),op('step',3.2),cancel(),op('release',3.4)]],
 ['source_reject_then_heavy',[op('press',0,{}, {bridge:{accepted:false}}),op('step',1.2),op('step',1.3),op('release',1.4),op('press',2,{}, {bridge:{accepted:true}}),op('release',2.1)]],
 ['heavy_rejection_release',[op('press',0),op('release',1.3,{}, {bridge:{accepted:false}}),cancel()]],
 ['block_interrupt',[op('press',0),block(true),op('press',.2),block(false),op('press',1),op('step',2.2),block(true),block(false),cancel()]],
 ['block_denied',[block(true),op('press',0),block(true),block(false),op('step',1.3),cancel()],{blockAccept:false}],
 ['airborne_edges',[op('press',0,{airborne:true}),op('press',.1),op('step',.3),op('release',.4),op('press',1.3),op('step',1.4,{airborne:false}),op('press',1.5),op('step',2.6),cancel()]],
 ['ground_to_air',[op('press',0),op('step',1.3,{airborne:true}),op('release',1.4),op('press',1.5,{airborne:false}),cancel()]],
 ['locks_sticky',[op('press',0),op('step',.1,{blocked:true}),op('press',1),block(true),op('press',2,{allowed:true}),op('step',2.2,{armed:true}),op('press',3,{armed:false}),op('release',3.1),cancel()]],
 ['buttons',[op('press',0),op('step',.1,{buttons:1}),op('step',.2,{buttons:1.5}),op('step',.3,{buttons:2}),op('step',1.3),op('press',2),op('step',3.2,{buttons:-1}),op('step',3.3,{buttons:0}),cancel()]],
 ['clock_monotonic',[op('press',4),op('step',3),{method:'step',now:4.5,options:{}},op('release',2),op('step',8),cancel()]],
 ['source_metadata',[op('press',0,{}, {bridge:{type:'source-custom',duration:2.0,seq:79,side:0,startAt:9876,contactWindow:[31,77]}}),op('step',1.3),op('release',1.4),op('step',2),cancel()]],
 ['bad_duration_is_rejection',[op('press',0,{}, {bridge:{duration:0}}),op('step',1.2),op('release',1.3),op('press',2,{}, {bridge:{duration:-1}}),cancel()]],
 ['empty_reply',[op('press',0,{}, {bridge:{nullReply:true}}),op('release',.5),cancel()]],
 ['cancel_reserved_while_held',[op('press',0),op('step',1.2),cancel(),op('step',1.3),block(false)]],
 ['zero_clock_and_empty_window',[op('press',-1,{yaw:0,airHeight:2}, {bridge:{contactWindow:[],side:-1}}),op('step',-.5),op('step',.2),op('release',.3),cancel()]],
 ['large_integer_buttons',[op('press',0),op('step',.1,{buttons:1e20}),op('step',1.3),op('press',2),op('step',2.1,{buttons:-1e100}),cancel()]],
];
const scenarios=cases.map(([name,operations,initial={}])=>{
 let clock=0,serial=0,settings={...initial},calls=[];
 const bridge={
  setWalkMeleeCharge(value){calls.push(['charge',value]);return true;},
  setWalkMeleeBlock(value){calls.push(['block',value]);return settings.blockAccept!==false;},
  beginWalkMelee(request){calls.push(['begin',{...request}]);serial++;if(settings.nullReply)return null;
   const type=request.airborne?'dropkick':request.heavy?'heavy':'punch';
   const defaults={accepted:true,seq:serial,type,side:serial%2?-1:1,startAt:clock*1000+17,duration:type==='dropkick'?1.25:type==='heavy'?.5:.34,contactWindow:type==='dropkick'?[160,380]:type==='heavy'?[70,360]:[35,190]};
   return {...defaults,...settings};}
 };
 const instance=createWorldWalkMeleeInput({bridge,now:()=>clock});
 const expected=operations.map(operation=>{
  if(operation.now!==undefined)clock=operation.now;
  if(operation.bridge)settings={...settings,...operation.bridge};
  const snapshot=operation.method==='block'?instance.block(operation.value):operation.method==='cancel'?instance.cancel():instance[operation.method](operation.options??{});
  return JSON.parse(JSON.stringify({snapshot,calls:calls.splice(0)}));
 });
 return {name,initial,operations,expected};
});
const artifact={source:sourcePath,source_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,sourcePath))).digest('hex'),bridge:'TEST_ONLY scripted replies, not source admission implementation',scenarios};
const output=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/melee_input_oracle.json');
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(artifact,null,2)+'\n');
console.log(JSON.stringify({output,source_sha256:artifact.source_sha256,scenarios:scenarios.length,operations:scenarios.reduce((n,s)=>n+s.operations.length,0)}));
