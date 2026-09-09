import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createWaterImpactCapture} from './water_inspection.mjs';
const source=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r/g,'');
const extract=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0);const end=source.indexOf('\n}',start);assert(end>start);return source.slice(start,end+2)};
const hero={object:{position:{x:4,y:1,z:7}}},records=[{id:'actual-car'}],calls=[];
const actors={hero:{id:'hero'},vehicles:[{id:'actual-car'}]},ripples=[{x:4,z:7,age:.4,strength:1}];
const context={hero,fleet:{records},occupiedSeat:null,transition:null,waterTeleported:true,
 waterInputs:{sample(input){calls.push(['sample',input]);return actors}},waterEffects:{update(dt,input){calls.push(['update',dt,input])},getRipples:()=>ripples},
 environmentVisuals:{setWaterRipples(input){calls.push(['ripples',input])}},controls:{target:{x:0,y:0,z:0}}};
vm.createContext(context);vm.runInContext(extract('updateWaterInteractions')+'\nupdateWaterInteractions(.04);',context);
assert.equal(calls[0][1].hero,hero);assert.equal(calls[0][1].records,records);assert.equal(calls[0][1].teleport,true);
assert.equal(calls[1][1],.04);assert.equal(calls[1][2].hero,actors.hero);assert.equal(calls[1][2].vehicles,actors.vehicles);assert.equal(calls[1][2].focus,hero.object.position);
assert.equal(calls[2][1],ripples);assert.equal(context.waterTeleported,false);
context.waterEffects=null;const before=calls.length;vm.runInContext('updateWaterInteractions(.04)',context);assert.equal(calls.length,before);
const frame=source.slice(source.indexOf('function frame(){'));
assert(frame.indexOf('artistUpdate(dt,moved,running)')<frame.indexOf('updateWaterInteractions(dt)'),'contacts sampled after current pose/swim');
assert(frame.indexOf('updateWaterInteractions(dt)')<frame.indexOf('environmentVisuals?.update('));
assert(frame.indexOf('updateWaterInteractions(dt)')<frame.indexOf('renderWeaponView(renderer'));
assert(frame.includes('if(document.hidden||waterImpactCapture.paused)return;'),'local stop-frame stops simulation, not just particle age');
assert(frame.indexOf('updateWaterInteractions(dt);captureWaterInspection(dt)')<frame.indexOf('renderWeaponView(renderer'),'capture keeps the real contact frame visible');
const capture=createWaterImpactCapture(),liveStats={impacts:2,activeDroplets:18,activeRings:1};let released=0,status='';
const inspectionContext={waterFailureCapture:false,waterVapor:null,waterInspection:{setStatus(text){status=text}},waterEffects:{stats:()=>liveStats},waterImpactCapture:capture,releaseControls(){released++},waterInspectionDriveUntil:4200,document:{body:{dataset:{}}}};
vm.createContext(inspectionContext);vm.runInContext(extract('captureWaterInspection'),inspectionContext);
vm.runInContext('captureWaterInspection(.04)',inspectionContext);assert.equal(released,0,'unarmed QA never interferes');
capture.arm(1);for(let i=0;i<4;i++)vm.runInContext('captureWaterInspection(.04)',inspectionContext);
assert.equal(capture.paused,true);assert.equal(released,1);assert.equal(inspectionContext.waterInspectionDriveUntil,0);
assert.equal(JSON.parse(inspectionContext.document.body.dataset.waterInteractions).activeDroplets,18);assert(status.includes('Стоп-кадр'));
capture.reset();inspectionContext.waterInspection=null;capture.arm(0);vm.runInContext('captureWaterInspection(.04)',inspectionContext);assert.equal(capture.paused,false,'absent local panel cannot capture');
assert(source.includes('waterEffects?.dispose();waterEffects=null;waterInputs.reset();'),'reload clears pools and sampling history');
assert(source.includes('waterEffects=createWaterInteractionEffects({THREE,waterAt,groundHeight});content.add(waterEffects.object);'));
assert(source.includes('canDrive:(x,z)=>waterVehicleSurfaceAt({terrain:landscape,topology,waterAt,metresPerCell:M},x,z)'),'water entry uses depth-independent admission while keeping native protection');
assert(source.includes('waterInspection?.dispose();'),'QA UI disposed');
for(const [bridge,search]of [[{},'?waterqa=1'],[undefined,''],[undefined,'?waterqa=0']]){
 const c={waterInspection:null,window:{Mafiozi3DBridge:bridge},location:{search},URLSearchParams,createWaterInspectionPanel(){throw Error('QA must not mount here')}};
 vm.createContext(c);vm.runInContext(extract('initWaterInspection')+'\ninitWaterInspection();',c);
}
console.log('PASS actual walk water hooks: posed inputs, shader feedback, bounded admission, reload disposal, no network QA controls');
