import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';

const sourcePath=process.argv[2];
if(!sourcePath)throw new Error('vehicle_pair_impulse.mjs path required');
const sourceBytes=await readFile(sourcePath);
const sourceSha256=createHash('sha256').update(sourceBytes).digest('hex');
const {resolveVehiclePairImpulse}=await import(pathToFileURL(sourcePath).href);

const encode=value=>{
 if(typeof value==='number'&&!Number.isFinite(value))return {$number:Number.isNaN(value)?'NaN':value>0?'Infinity':'-Infinity'};
 if(Array.isArray(value))return value.map(encode);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,item])=>[key,encode(item)]));
 return value;
};
const body=(x,z,vx,vz,mass,halfWidth=1,halfLength=2,yawRate=0)=>({x,z,vx,vz,mass,halfWidth,halfLength,yawRate});
const contact=(x,z,nx,nz)=>({point:{x,z},normal:{x:nx,z:nz}});
const cases=[];
const add=(id,a,b,c,options)=>cases.push({id,a,b,contact:c,...(options===undefined?{}:{options})});

add('equal_centered',body(-1,0,10,0,1000),body(1,0,0,0,1000),contact(0,0,1,0));
add('light_into_heavy',body(-2,0,18,1,1200,.9,2.1,.2),body(3,0,-1,-.5,9600,1.5,4.5,-.1),contact(.4,.8,3,1));
add('heavy_into_light',body(-2,0,18,1,9600,1.5,4.5,.2),body(3,0,-1,-.5,1200,.9,2.1,-.1),contact(.4,.8,3,1));
add('offset_yaw',body(-4,2,12,-3,1600,1.1,2.6,1.7),body(5,-1,-2,4,2300,1.3,3.0,-.8),contact(.75,4.2,2,-5),{restitution:.37,angular:true});
add('separating',body(0,0,-3,0,1200),body(2,0,4,0,1400),contact(1,0,1,0));
add('zero_closing',body(0,0,2,-1,1200),body(2,0,2,-1,1400),contact(1,0,1,0));
add('invalid_mass',body(0,0,3,0,-1),body(2,0,0,0,1400),contact(1,0,1,0));
add('nonfinite_velocity_fallback',{...body(0,0,3,0,1200),vx:NaN,vz:Infinity,yawRate:-Infinity},body(2,0,-2,0,1400),contact(1,0,1,0));
add('nonfinite_contact',body(0,0,3,0,1200),body(2,0,0,0,1400),contact(1,0,Infinity,1));
add('degenerate_normal',body(0,0,3,0,1200),body(2,0,0,0,1400),contact(1,0,1e-12,-1e-12));
add('angular_false',body(-1,1,9,1,1000,1,2,3),body(2,-2,-1,-2,1500,1.2,2.4,-2),contact(.2,2.7,1,.4),{restitution:.12,angular:false});
add('missing_velocity_fields',{x:0,z:0,mass:1000,halfWidth:1,halfLength:2},{x:2,z:0,mass:1000,halfWidth:1,halfLength:2,vx:-4},contact(1,0,1,0));
add('invalid_dimensions_disable_angular',body(-1,0,8,0,1300,NaN,2,5),body(2,0,0,0,1700,1,Infinity,-4),contact(.4,2,1,0));
add('restitution_low_clamp',body(-1,0,8,0,1000),body(1,0,0,0,1000),contact(0,0,1,0),{restitution:-9,angular:true});
add('restitution_high_clamp',body(-1,0,8,0,1000),body(1,0,0,0,1000),contact(0,0,1,0),{restitution:9,angular:true});
add('restitution_null_fallback',body(-1,0,8,0,1000),body(1,0,0,0,1000),contact(0,0,1,0),{restitution:null,angular:true});
add('restitution_nonfinite_fallback',body(-1,0,8,0,1000),body(1,0,0,0,1000),contact(0,0,1,0),{restitution:NaN,angular:true});
add('options_missing_defaults',body(-1,0,8,0,1000),body(1,0,0,0,1000),contact(0,0,1,0));
add('robust_hypot_normal',body(-1,0,8,3,1000),body(1,0,-2,-1,2000),contact(0,0,1e308,5e307),{restitution:.5,angular:false});
add('extreme_denominator_overflow',body(0,0,10,0,1000,1e308,1e308,2),body(2,0,0,0,1000,1e308,1e308,-3),contact(1,1e308,1,0),{restitution:.2,angular:true});
add('extreme_impulse_overflow',body(0,0,1e308,0,1e308,1,2,0),body(2,0,0,0,1e308,1,2,0),contact(1,0,1,0),{restitution:1,angular:false});
add('shifted_world_origin',body(1e7,-2e7,14,-5,1800,1.2,2.8,.4),body(1e7+4,-2e7+3,-3,7,2400,1.4,3.2,-.3),contact(1e7+1.1,-2e7+4.2,-4,2),{restitution:.27,angular:true});

let seed=0x51f15e5d;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/0x100000000;};
const range=(lo,hi)=>lo+(hi-lo)*random();
for(let index=0;index<256;index++){
 const a=body(range(-100,100),range(-100,100),range(-40,40),range(-40,40),range(500,15000),range(.6,2.0),range(1.2,6),range(-5,5));
 const b=body(range(-100,100),range(-100,100),range(-40,40),range(-40,40),range(500,15000),range(.6,2.0),range(1.2,6),range(-5,5));
 const c=contact(range(-100,100),range(-100,100),range(-2,2),range(-2,2));
 const options={restitution:range(-.5,1.5),angular:index%5!==0};
 add(`random_${String(index).padStart(3,'0')}`,a,b,c,options);
}

const transcript=cases.map(row=>({
 id:row.id,
 input:encode({a:row.a,b:row.b,contact:row.contact,...('options'in row?{options:row.options}:{})}),
 expected:encode(resolveVehiclePairImpulse(row.a,row.b,row.contact,row.options)),
}));
process.stdout.write(JSON.stringify({schema:'mafiozi.vehicle-pair-impulse-oracle.v1',source_sha256:sourceSha256,cases:transcript}));
