import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const source=process.argv[2];
const destination=process.argv[3];
if(!source||!destination)throw new Error('source_oracle.mjs SOURCE OUTPUT required');
const {createWaterInteractionSimulator}=await import(pathToFileURL(source));
const hero=(x,y,z=0,extra={})=>({id:'hero',position:{x,y,z},...extra});
const cases=[];
function add(name,frames,water='lake',options={}){cases.push({name,frames,water,options});}
const frame=(dt,h,extra={})=>({dt,input:h===null?extra:{hero:h,...extra}});
add('first_stationary_exit',[frame(.05,hero(0,-.2)),...Array.from({length:40},()=>frame(.05,hero(0,-.2))),frame(.05,hero(0,1))]);
add('swept_impact',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2,0,{velocity:{x:0,y:-6,z:0}})),...Array.from({length:130},()=>frame(.05,hero(0,-.2)))]);
add('grounded_velocity_reset',[frame(.05,hero(0,1)),frame(.05,hero(0,0,0,{velocity:{x:0,y:0,z:0}})),...Array.from({length:50},()=>frame(.05,hero(0,0)))]);
add('dry_endpoint_narrow',[frame(.05,hero(-.3,0)),frame(.05,hero(.9,0)),...Array.from({length:45},()=>frame(.05,null))],'narrow');
add('airborne_narrow',[frame(.05,hero(-.3,2)),frame(.05,hero(.9,2))],'narrow');
add('shallow_wake',[frame(.1,hero(-.1,0)),frame(.1,hero(.1,-.02)),frame(.1,hero(.8,-.02))],'shallow');
add('walk_spacing',[frame(.05,hero(0,-.1)),...Array.from({length:100},(_,i)=>frame(.05,hero((i+1)*.08,-.1))),...Array.from({length:40},()=>frame(.05,hero(8,-.1)))]);
add('teleport_despawn_suspension',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2,0,{teleport:true})),frame(.05,hero(0,1)),frame(3,hero(0,-.2)),frame(.05,null),frame(.05,hero(0,-.2)),frame(.05,hero(16,-.2))]);
add('disabled_id_focus',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2,0,{enabled:false})),frame(.05,hero(0,-.2)),frame(.05,hero(0,1,0,{id:'other'})),frame(.05,hero(0,-.2,0,{id:'other'}),{focus:{x:1000,z:1000}}),frame(.05,hero(0,-.2,0,{id:'other'}))]);
add('contact_offset_mass',[frame(.04,hero(0,2,0,{contactOffsetY:-1,massKg:180})),frame(.04,hero(0,.8,0,{contactOffsetY:-1,massKg:180})),...Array.from({length:35},()=>frame(.04,null))]);
add('small_pools_reuse',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2)),...Array.from({length:45},(_,i)=>frame(.05,hero(i*.6,-.2)))],'lake',{maxDroplets:8,maxRings:2,maxFoam:3});
add('zero_pools',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2))],'lake',{maxDroplets:0,maxRings:0,maxFoam:0});
add('gravity_without_drag',[frame(.05,hero(0,1)),frame(.05,hero(0,0)),...Array.from({length:80},()=>frame(.05,hero(0,0)))],'lake',{drag:0});
add('recontact_small_waves',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2)),...Array.from({length:80},()=>frame(.04,hero(0,-.2)))],'lake',{constantRandom:.1});
add('shore_ground_expiry',[frame(.05,hero(.05,1)),frame(.05,hero(.05,-.2)),...Array.from({length:60},()=>frame(.05,null))],'shore',{groundHeight:0});
add('floor_depth_and_rejected_thin',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2)),frame(.05,hero(1,-.2))],'floor');
add('source_nonboolean_enabled_and_partial_focus',[frame(.05,hero(0,1,0,{enabled:0}),{focus:{}}),frame(.05,hero(0,-.2,0,{enabled:0}),{focus:{x:0}}),frame(.05,hero(0,1,0,{enabled:false})),frame(.05,hero(0,-.2,0,{enabled:true}))]);
for(const seed of [842,12,57,396])add('seeded_real_recontacts_'+seed,[frame(.016,hero(0,1)),frame(.016,hero(0,-.2)),...Array.from({length:310},(_,i)=>frame(.016,hero(i<60?sinpos(i):sinpos(59),-.2)))],'lake',{seededRandom:seed});
function sinpos(i){return Math.sin(i*.1)*.6;}
add('simultaneous_real_return_wave_ties',[frame(.05,hero(0,1)),frame(.05,hero(0,-.2)),...Array.from({length:100},()=>frame(.05,hero(0,-.2)))],'lake',{scriptedFan:true});
function water(mode,x,z){
 if(mode==='narrow')return x>=0&&x<=.6?{level:0,depth:.7}:null;
 if(mode==='shallow')return x>=0?{level:0,depth:.04}:null;
 if(mode==='shore')return x>0?{level:0,depth:1}:null;
 if(mode==='floor')return {level:0,floor:x<.5?-1:-.01};
 return Math.abs(x)<20&&Math.abs(z)<20?{level:0,depth:1,floor:-1}:null;
}
const fields={droplets:['x','y','z','vx','vy','vz','radius','age','life'],rings:['x','y','z','age','life','strength','radius'],foam:['x','y','z','age','life','radius','angle']};
function state(s){return {stats:s.stats(),ripples:s.getRipples(),...Object.fromEntries(Object.entries(fields).map(([key,keys])=>[key,s[key].map(p=>p.active?Object.fromEntries([['active',true],...keys.map(k=>[k,p[k]])]):{active:false})]))};}
for(const c of cases){
 let seed=c.options.seededRandom,calls=0;
 function random(){if(c.options.scriptedFan){const i=calls++;return i<150&&i%6===0?Math.floor(i/6)/25:i<152?.4:.1;}return seed===undefined?c.options.constantRandom??.4:((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);}
 const opts={...c.options,waterAt:(x,z)=>water(c.water,x,z),random};
 if('groundHeight'in opts)opts.groundHeight=()=>c.options.groundHeight;
 const s=createWaterInteractionSimulator(opts);
 for(const f of c.frames){s.update(f.dt,f.input);f.expected=state(s);}
 s.dispose();c.disposed=state(s);
}
fs.writeFileSync(destination,JSON.stringify({source,scope:'hero-only source oracle',cases}));
console.log(JSON.stringify({cases:cases.length,frames:cases.reduce((n,c)=>n+c.frames.length,0),passed:true}));
