import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const helperStart=source.indexOf('function setVehicleWindowPrompt');
const resetStart=source.indexOf('function resetVehicleWindowFire',helperStart);
const updateStart=source.indexOf('function updateVehicleWindowFire',resetStart);
assert(helperStart>=0&&resetStart>helperStart&&updateStart>resetStart,'production window prompt helpers are present');
const resetSource=source.slice(resetStart,source.indexOf('function vehicleWindowCameraTarget',resetStart));
const updateSource=source.slice(updateStart,source.indexOf('function fireState',updateStart));
assert.match(resetSource,/setVehicleWindowPrompt\(false\)/,'actual reset uses the diffing prompt bridge');
assert.match(updateSource,/updateVehicleWindowPrompt\(\)/,'actual window update presents through the diffing bridge');

let hidden=true,text='',hiddenWrites=0,textWrites=0;
const vehicleWindowPrompt={};Object.defineProperties(vehicleWindowPrompt,{
 hidden:{get:()=>hidden,set:value=>{hiddenWrites++;hidden=value;}},
 textContent:{get:()=>text,set:value=>{textWrites++;text=value;}},
});
const host={vehicleWindowPrompt,vehicleWindowFire:{result:null},occupiedSeat:null,aiming:false};
vm.createContext(host);vm.runInContext(source.slice(helperStart,resetStart),host);
const present=(occupiedSeat,aim,result)=>{host.occupiedSeat=occupiedSeat;host.aiming=aim;host.vehicleWindowFire.result=result;vm.runInContext('updateVehicleWindowPrompt()',host);};

present(null,false,null);assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:0,textWrites:0},'already-hidden no-result state writes nothing');
present('front_left',true,{canFire:true,reason:''});assert.equal(hidden,false);assert.equal(text,'ПКМ — прицел из окна · ЛКМ — огонь · R — перезарядить');assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:1,textWrites:1},'can-fire transition is immediate');
present('front_left',true,{canFire:true,reason:''});assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:1,textWrites:1},'unchanged can-fire state writes nothing');
present('front_left',true,{canFire:false,reason:'Стекло закрыто'});assert.equal(hidden,false);assert.equal(text,'Стекло закрыто');assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:1,textWrites:2},'blocked reason replaces visible text immediately');
present('front_left',true,{canFire:false,reason:'Линия огня перекрыта'});assert.equal(text,'Линия огня перекрыта');assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:1,textWrites:3},'changed blocked reason is immediate');
present('front_left',false,null);assert.equal(hidden,true);assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:2,textWrites:3},'no-result transition hides prompt immediately');
present('front_left',false,null);assert.deepEqual({hiddenWrites,textWrites},{hiddenWrites:2,textWrites:3},'unchanged hidden state writes nothing');

console.log(JSON.stringify({passed:true,checks:['actual_production_prompt_bridge','no_result','can_fire','blocked_reason','changed_reason','repeat_write_elision','immediate_transitions']}));
