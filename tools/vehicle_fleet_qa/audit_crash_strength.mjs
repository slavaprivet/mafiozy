import {writeFile,readFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createCrashMechanicsState,applyCrashMechanicsImpact,stepCrashMechanics,crashDriveEffects,sampleCrashDeformation} from '../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs';
const round=v=>Number(v.toFixed(6));
const rows=[];
for(const direction of ['front','side'])for(const speed of [3,6,10,16,22]){
 const state=createCrashMechanicsState(),point=direction==='front'?{x:0,y:.80,z:2.15}:{x:1,y:.80,z:1.325},normal=direction==='front'?{x:0,y:0,z:1}:{x:1,y:0,z:0};
 applyCrashMechanicsImpact(state,{point,normal,impactSpeed:speed});
 for(let i=0;i<180;i++)stepCrashMechanics(state,1/60);
 const deformation=sampleCrashDeformation(state,point),effects=crashDriveEffects(state);
 rows.push({direction,speed,maxCrush:round(state.maxCrush),contactCrush:round(Math.hypot(deformation.x,deformation.y,deformation.z)),engine:round(state.engine),radiator:round(state.radiator),nearWheel:round(state.wheels.front_left.health),farWheel:round(state.wheels.front_right.health),nearToe:round(state.wheels.front_left.toe),nearSag:round(state.wheels.front_left.sag),steering:round(state.steering),powerFactor:round(effects.powerFactor),speedFactor:round(effects.speedFactor),brokenBeams:state.beams.filter(b=>b.broken).length,detached:[...state.detachedParts],energyJ:state.totalEnergyJ,absorbedEnergyJ:round(state.absorbedEnergyJ),settled:!state.active});
}
const source=await readFile(new URL('../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs',import.meta.url));
const result={sourceSha256:createHash('sha256').update(source).digest('hex'),profile:'default 1500kg; front center and left front wheel side; 180 frames at 60Hz',rows};
if(process.argv[2]){await mkdir(new URL('../../outputs/vehicle_fleet_continuation/',import.meta.url),{recursive:true});await writeFile(new URL('../../outputs/vehicle_fleet_continuation/'+process.argv[2],import.meta.url),JSON.stringify(result,null,2)+'\n');}
console.log(JSON.stringify(result,null,2));
