import assert from 'node:assert/strict';
import {refreshVehicleFleetQaSelect} from './vehicle_fleet_qa_select.mjs';

class OptionElement{
 constructor(){this.value='';this.textContent='';}
}
class SelectElement{
 constructor(ownerDocument){this.ownerDocument=ownerDocument;this.children=[];this.value='';this.disabled=false;}
 replaceChildren(){this.children=[];this.value='';}
 append(option){this.children.push(option);}
}
const document={createElement(tag){assert.equal(tag,'option');return new OptionElement();}};
const select=new SelectElement(document);
const fleet={activeId:'taxi',records:[
 {id:'red_sedan',car:{profile:{label:'Kingswell'}}},
 {id:'taxi',car:{profile:{label:'Такси'}}},
 {id:'service_van',car:{profile:{}}},
]};

let result=refreshVehicleFleetQaSelect(select,fleet);
assert.deepEqual(result,{count:3,selectedId:'taxi'});
assert.equal(select.value,'taxi');
assert.deepEqual(select.children.map(option=>[option.value,option.textContent]),[
 ['red_sedan','Kingswell'],['taxi','Такси'],['service_van','service_van'],
]);
assert.equal(select.disabled,false);

// Preserve a valid operator selection across the async 14-car refresh.
select.value='red_sedan';fleet.activeId='taxi';fleet.records.push({id:'police',car:{profile:{label:'Полиция'}}});
result=refreshVehicleFleetQaSelect(select,fleet);
assert.equal(result.selectedId,'red_sedan');
assert.equal(select.value,'red_sedan');

// A stale selection cannot leave the closed combobox visually blank.
select.value='removed';fleet.records=fleet.records.slice(1);fleet.activeId='missing';
result=refreshVehicleFleetQaSelect(select,fleet);
assert.equal(result.selectedId,'taxi');
assert.equal(select.value,'taxi');

fleet.records=[];
result=refreshVehicleFleetQaSelect(select,fleet);
assert.deepEqual(result,{count:0,selectedId:null});
assert.equal(select.disabled,true);

console.log('vehicle fleet QA select tests passed');
