import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const helperStart=source.indexOf('function setCarInteractionText');
const updateStart=source.indexOf('function updateCarInteraction',helperStart);
const nextStart=source.indexOf('function updateCarPrompt',updateStart);
const buildingStart=source.indexOf('function updateBuildingPrompt',nextStart);
const afterBuilding=source.indexOf('function restoreBuildingCamera',buildingStart);
assert(helperStart>=0&&updateStart>helperStart&&nextStart>updateStart&&buildingStart>nextStart&&afterBuilding>buildingStart,'production car status helper and update are present');
const updateSource=source.slice(updateStart,nextStart);
assert.equal((updateSource.match(/setCarInteractionText\(/g)||[]).length,4,'all three car states and drive status use actual-text comparison');
assert.match(source.slice(buildingStart,afterBuilding),/setCarInteractionText\('drive-status',candidate\.kind/,'actual building prompt uses the same actual-text bridge after car status');

const writes={car:0,drive:0},values={car:'',drive:''};
const nodes={
 car:{get textContent(){return values.car;},set textContent(value){writes.car++;values.car=value;}},
 'drive-status':{get textContent(){return values.drive;},set textContent(value){writes.drive++;values.drive=value;}},
};
const host={$:id=>nodes[id]};vm.createContext(host);vm.runInContext(source.slice(helperStart,updateStart),host);
const present=(car,drive)=>vm.runInContext(`setCarInteractionText('car',${JSON.stringify(car)});setCarInteractionText('drive-status',${JSON.stringify(drive)});`,host);

present('Удерживай E 0,3 с — сесть','Подойди к нужной двери машины');assert.deepEqual(writes,{car:1,drive:1},'first idle presentation writes both visible labels');
present('Удерживай E 0,3 с — сесть','Подойди к нужной двери машины');assert.deepEqual(writes,{car:1,drive:1},'unchanged no-entry frame writes neither label');
present('Удерживай E · 50%','E · удержать 0,3 с — Водитель');assert.deepEqual(writes,{car:2,drive:2},'hold percentage and nearby-entry label update immediately');
present('Удерживай E · 50%','Седан · Водитель · 36 км/ч · E 0,3 с — выйти · Q — достать оружие');assert.deepEqual(writes,{car:2,drive:3},'speed/status change updates immediately');
vm.runInContext("setCarInteractionText('drive-status','E — дверь · WASD — пройти')",host);assert.equal(writes.drive,4,'same-frame building writer replaces car status immediately');
vm.runInContext("setCarInteractionText('drive-status','E — дверь · WASD — пройти')",host);assert.equal(writes.drive,4,'unchanged active building prompt causes no extra DOM write');
present('Удерживай E · 50%','Седан · Водитель · 36 км/ч · E 0,3 с — выйти · Q — достать оружие');assert.deepEqual(writes,{car:2,drive:5},'next car frame restores its status from actual DOM, preserving car-then-building order');

console.log(JSON.stringify({passed:true,checks:['actual_production_helper','idle_repeat_elision','hold_immediate','speed_immediate','ordered_car_then_building_override']}));
