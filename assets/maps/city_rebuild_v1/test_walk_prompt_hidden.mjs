import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const helperStart=source.indexOf('function setWalkPromptHidden');
const carStart=source.indexOf('function updateCarPrompt',helperStart);
const buildingStart=source.indexOf('function updateBuildingPrompt',carStart);
const afterBuilding=source.indexOf('function restoreBuildingCamera',buildingStart);
assert(helperStart>=0&&carStart>helperStart&&buildingStart>carStart&&afterBuilding>buildingStart,'production prompt helper and both prompt paths are present');
const carSource=source.slice(carStart,buildingStart),buildingSource=source.slice(buildingStart,afterBuilding);
assert.match(carSource,/setWalkPromptHidden\(prompt,true\)/,'actual no-car-candidate path uses the helper');
assert.match(buildingSource,/setWalkPromptHidden\(prompt,true\)/,'actual no-building-candidate path uses the helper');

const writes={car:0,building:0},hidden={car:true,building:true};
const prompts={
 car:{get hidden(){return hidden.car;},set hidden(value){writes.car++;hidden.car=value;}},
 building:{get hidden(){return hidden.building;},set hidden(value){writes.building++;hidden.building=value;}},
};
const host={};vm.createContext(host);vm.runInContext(source.slice(helperStart,carStart),host);
const hide=(name)=>{host.prompt=prompts[name];vm.runInContext('setWalkPromptHidden(prompt,true)',host);};

hide('car');hide('building');assert.deepEqual(writes,{car:0,building:0},'already-hidden absent prompts do not rewrite hidden');
prompts.car.hidden=false;assert.equal(writes.car,1,'another writer made car prompt visible');hide('car');assert.equal(hidden.car,true);assert.equal(writes.car,2,'no-candidate car path hides the externally-visible prompt once');hide('car');assert.equal(writes.car,2,'repeated no-candidate car path is write-free');
prompts.building.hidden=false;assert.equal(writes.building,1,'another writer made building prompt visible');hide('building');assert.equal(hidden.building,true);assert.equal(writes.building,2,'no-candidate building path hides the externally-visible prompt once');hide('building');assert.equal(writes.building,2,'repeated no-candidate building path is write-free');

console.log(JSON.stringify({passed:true,checks:['actual_car_and_building_paths','initial_absent_elision','cross_writer_car','cross_writer_building','repeat_absent_elision']}));
