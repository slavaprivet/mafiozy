import fs from 'node:fs';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
const sourcePath='assets/maps/city_rebuild_v1/vehicle_damage.mjs';
const source=fs.readFileSync(sourcePath,'utf8');
const block=source.slice(source.indexOf('export const VEHICLE_DAMAGE_RULES'),source.indexOf('// Exact local bounds')).replaceAll('export ','');
const context=vm.createContext({}); vm.runInContext(block,context);
const rows=[];
for(const maxHp of [240,360,420]) for(const armor of [1,1.65]) for(const kind of ['gun','collision','rpg']) for(const damage of [0,.49,4,80,500]) for(const dt of [0,.5,1.55,2]) {
 const input={maxHp,armor,kind,damage,dt}; context.input=input;
 const result=vm.runInContext(`(()=>{const s=createVehicleDamageState(input), a=applyVehicleDamage(s,{damage:input.damage,eventId:'actual-event',kind:input.kind});return {initial:s,applied:a,stepped:stepVehicleDamage(a,input.dt),duplicate:applyVehicleDamage(a,{damage:input.damage,eventId:'actual-event',kind:input.kind})}})()`,context);
 rows.push({...input,...JSON.parse(JSON.stringify(result))});
}
const destination='godot/mafiozi_walk/data/transport/damage_state_oracle.json';
fs.writeFileSync(destination,JSON.stringify({source_sha256:createHash('sha256').update(source).digest('hex'),rows})+'\n');
console.log(JSON.stringify({rows:rows.length,destination,sha256:createHash('sha256').update(fs.readFileSync(destination)).digest('hex')}));
