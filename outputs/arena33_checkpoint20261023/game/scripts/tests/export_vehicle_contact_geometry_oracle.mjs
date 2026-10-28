import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';

const sourcePath=process.argv[2];
if(!sourcePath)throw new Error('vehicle_contact.mjs path required');
const sourceBytes=await readFile(sourcePath);
const sourceSha256=createHash('sha256').update(sourceBytes).digest('hex');
const {polygonVehicleContact,contactKinematics}=await import(pathToFileURL(sourcePath).href);
const encode=value=>{
 if(typeof value==='number'&&!Number.isFinite(value))return {$number:Number.isNaN(value)?'NaN':value>0?'Infinity':'-Infinity'};
 if(Array.isArray(value))return value.map(encode);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,item])=>[key,encode(item)]));
 return value;
};
const rect=(cx,cz,hx,hz,yaw=0,start=0,reverse=false)=>{
 const c=Math.cos(yaw),s=Math.sin(yaw),base=[[-hx,-hz],[hx,-hz],[hx,hz],[-hx,hz]];
 let rows=base.map(([x,z])=>[cx+x*c+z*s,cz-x*s+z*c]);
 rows=[...rows.slice(start),...rows.slice(0,start)];if(reverse)rows.reverse();return rows;
};
const cases=[];
const add=(id,car,obstacle,speed=undefined,travelYaw=undefined)=>cases.push({id,car,obstacle,...(speed===undefined?{}:{speed,travelYaw})});
add('basic_side_overlap',[[-1,-2],[1,-2],[1,2],[-1,2]],[[.9,-.5],[2,-.5],[2,.5],[.9,.5]],10,Math.PI/2);
add('touching',rect(0,0,1,2),rect(2,0,1,3),7,Math.PI/2);
add('separated',rect(0,0,1,2),rect(2.000001,0,1,3));
const root2=Math.sqrt(2);
add('rotated_single_corner',[[0,-root2],[root2,0],[0,root2],[-root2,0]],[[1.3,-10],[3,-10],[3,10],[1.3,10]],12,Math.PI/2);
add('containment',rect(0,0,5,5),rect(.4,-.3,1,1,.2),5,-.7);
add('tie_first_axis',rect(0,0,1,1,0,0,false),rect(.5,.5,1,1),4,.3);
add('tie_reordered',rect(0,0,1,1,0,1,false),rect(.5,.5,1,1),4,.3);
add('tie_reversed',rect(0,0,1,1,0,0,true),rect(.5,.5,1,1),4,.3);
add('zero_edge_duplicate',[[-1,-1],[1,-1],[1,-1],[1,1],[-1,1]],rect(1.5,0,1,1),6,Math.PI/2);
add('nan_projection',[[-1,-1],[1,-1],[NaN,1],[-1,1]],rect(.5,0,1,1),3,.2);
add('infinity_projection',[[-1,-1],[1,-1],[Infinity,1],[-1,1]],rect(.5,0,1,1),3,.2);
add('mixed_nan_infinity_edge',[[0,NaN],[Infinity,0],[1,1],[-1,1]],rect(.5,0,1,1),3,.2);
add('empty_car',[],rect(0,0,1,1));
add('empty_obstacle',rect(0,0,1,1),[]);
add('single_points',[[0,0]],[[0,0]]);
add('all_degenerate',[[1,1],[1,1],[1,1]],[[1,1],[1,1],[1,1]]);
add('tiny_edge_skipped',[[0,0],[1e-10,0],[1,0],[1,1],[0,1]],rect(1.5,.5,1,1));
add('large_translation',rect(1e9,-2e9,1.2,2.7,.71),rect(1e9+1.5,-2e9+.3,1.1,3.1,-.2),11,1.1);
add('reverse_speed',rect(0,0,1,2),rect(1.5,0,1,2),-8,Math.PI/2);

let seed=0xc0111de;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/0x100000000;};
const range=(lo,hi)=>lo+(hi-lo)*random();
for(let index=0;index<256;index++){
 const ax=range(-100,100),az=range(-100,100),ahx=range(.4,3),ahz=range(.8,6),ay=range(-Math.PI,Math.PI);
 const separation=index%4===0?range(8,15):range(-1.5,1.5);
 const bx=ax+Math.sin(ay)*(ahz+separation)+range(-1,1),bz=az+Math.cos(ay)*(ahz+separation)+range(-1,1);
 const car=rect(ax,az,ahx,ahz,ay,index%4,index%7===0);
 const obstacle=rect(bx,bz,range(.5,4),range(.5,7),range(-Math.PI,Math.PI),index%3,index%11===0);
 add(`random_${String(index).padStart(3,'0')}`,car,obstacle,range(-30,30),range(-Math.PI,Math.PI));
}

const transcript=cases.map(row=>{
 const geometry=polygonVehicleContact(row.car,row.obstacle);
 const motion=('speed'in row)&&geometry?contactKinematics(geometry,row.speed,row.travelYaw):null;
 return {id:row.id,input:encode({car:row.car,obstacle:row.obstacle,...('speed'in row?{speed:row.speed,travelYaw:row.travelYaw}:{})}),geometry:encode(geometry),motion:encode(motion)};
});
process.stdout.write(JSON.stringify({schema:'mafiozi.vehicle-contact-geometry-oracle.v1',source_sha256:sourceSha256,cases:transcript}));
