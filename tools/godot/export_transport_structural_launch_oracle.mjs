import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root=path.resolve(import.meta.dirname,'../..');
const sourcePath=path.join(root,'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const outputPath=path.join(root,'godot/mafiozi_walk/data/transport/structural_launch_oracle.json');
const ids=['hood','trunk','door_front_left','door_front_right','door_rear_left','door_rear_right','bumper_front','bumper_rear','wheel_front_left','wheel_front_right','wheel_rear_left','wheel_rear_right'];
const cases=[
 {impacts:0,normal:[.6,.2,-.7],impact:0,speed:-142.75,yaw:-2.4},
 {impacts:7,normal:[-.3,.8,.1],impact:31.5,speed:88.5,yaw:.7},
 {impacts:2147483647,normal:[0,1,0],impact:12.25,speed:0,yaw:Math.PI},
];
function launch(id,input){
 let raw=[...id].reduce((v,c)=>v*31+c.charCodeAt(0),input.impacts+1);
 const seed=raw>>>0, random=offset=>Math.sin(seed+offset*2.399)*.5+.5;
 const impact=Math.min(24,input.impact||8),sourceNormal={x:-input.normal[0],y:input.normal[1],z:-input.normal[2]};
 const sourceVelocity={x:Math.sin(input.yaw)*input.speed*.72-sourceNormal.x*impact*.15+(random(1)-.5)*3,y:1.3+impact*.12+random(2),z:Math.cos(input.yaw)*input.speed*.72-sourceNormal.z*impact*.15+(random(3)-.5)*3};
 const sourceAngular={x:(random(4)-.5)*7,y:(random(5)-.5)*7,z:(random(6)-.5)*7};
 return {seed_u32:seed,seed_exceeds_safe_integer:Math.abs(raw)>Number.MAX_SAFE_INTEGER,linear_velocity_native:[-sourceVelocity.x,sourceVelocity.y,-sourceVelocity.z],angular_velocity_native:[-sourceAngular.x,sourceAngular.y,-sourceAngular.z],mass_kg:id.startsWith('wheel')?24:18};
}
const rows=ids.map((id,index)=>{const input=cases[index%cases.length];return {id,impact_count:input.impacts,normal_native:input.normal,impact_speed_mps:input.impact,signed_speed_mps:input.speed,travel_yaw_native:input.yaw,...launch(id,input)};});
const source=fs.readFileSync(sourcePath);
fs.mkdirSync(path.dirname(outputPath),{recursive:true});
fs.writeFileSync(outputPath,JSON.stringify({schema:'mafiozi.transport-structural-launch-oracle.v1',source:'vehicle_crash.mjs detach lines 127-135',source_sha256:crypto.createHash('sha256').update(source).digest('hex'),rows},null,2)+'\n');
console.log(JSON.stringify({output:path.relative(root,outputPath).replaceAll('\\','/'),rows:rows.length,overflow_rows:rows.filter(r=>r.seed_exceeds_safe_integer).length}));
