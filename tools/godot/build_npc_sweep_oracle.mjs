// Reproducible exact-source oracle. No Walk mutation, renderer, or NPC creation.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {createNpcSweptFootprint} from '../../assets/maps/city_rebuild_v1/npc_swept_footprint.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const sourcePath='assets/maps/city_rebuild_v1/npc_swept_footprint.mjs';
const layoutPath='godot/mafiozi_walk/data/printshop_interior.json';
const read=name=>fs.readFileSync(path.join(root,name));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const layout=JSON.parse(read(layoutPath));
const cases=[];
function add(name,from,to,polygon,radius=.18,filter='none',origin='synthetic-negative-geometry'){
 const sweep=createNpcSweptFootprint(),contacts=[];sweep.set(from,to,radius);
 const predicate=filter==='none'?null:(c,r)=>{contacts.push([c,r]);return filter==='yes'?true:filter==='no'?false:filter==='half'?c+r>=0:Math.floor(Math.abs(c*17+r*31))%3===0;};
 const overlap=sweep.overlaps(polygon,predicate);
 cases.push({name,origin,from,to,radius,polygon,filter,overlap,contacts,bounds:{minC:sweep.minC,minR:sweep.minR,maxC:sweep.maxC,maxR:sweep.maxR}});
}
const thin=[[3.998,3.6],[4.002,3.6],[4.002,4.5],[3.998,4.5]],concave=[[8,0],[11,0],[11,3],[10,3],[10,1],[9,1],[9,3],[8,3]];
for(const filter of ['none','yes','no','half','pattern']){
 add('thin:'+filter,{r:4,c:3.7},{r:4,c:4.3},thin,.18,filter);
 add('concave_notch:'+filter,{r:2,c:9.5},{r:2.6,c:9.5},concave,.18,filter);
 add('concave_floor:'+filter,{r:2,c:9.5},{r:.5,c:9.5},concave,.18,filter);
 add('contained:'+filter,{r:0,c:0},{r:0,c:0},[[-.01,-.01],[.01,-.01],[.01,.01],[-.01,.01]],.18,filter);
 add('touch:'+filter,{r:0,c:0},{r:0,c:0},[[.18,-1],[.19,-1],[.19,1],[.18,1]],.18,filter);
 add('collinear:'+filter,{r:0,c:0},{r:2,c:0},[[.18,-2],[.18,3],[.4,3],[.4,-2]],.18,filter);
 add('zero_radius:'+filter,{r:0,c:0},{r:2,c:2},[[.5,.5],[1,1],[1,0]],0,filter);
}
add('empty',{r:0,c:0},{r:0,c:0},[]);add('null',{r:0,c:0},{r:0,c:0},null);
add('point_obstacle',{r:0,c:0},{r:1,c:1},[[.5,.5]]);
add('line_obstacle',{r:0,c:0},{r:1,c:1},[[.25,.75],[.75,.25]]);
add('repeated_vertices',{r:0,c:0},{r:1,c:1},[[0,0],[0,0],[1,0],[1,1],[0,1],[0,0]]);
for(const epsilon of [0,1e-12,-1e-12,1e-10,-1e-10,1e-8,-1e-8])add('near_touch:'+epsilon,{r:0,c:0},{r:0,c:0},[[.18+epsilon,-1],[.3,-1],[.3,1],[.18+epsilon,1]],.18,'no');
const bodies=[...layout.staticBodies.map((b,i)=>({b,label:'static:'+i})),...Object.entries(layout.doors).flatMap(([name,d])=>d.bodies.map((b,i)=>({b,label:'door:'+name+':'+i})))];
for(const {b,label}of bodies){const polygon=b.polygonCR;if(!polygon?.length)continue;const cs=polygon.map(p=>p[0]),rs=polygon.map(p=>p[1]),c0=Math.min(...cs),c1=Math.max(...cs),r0=Math.min(...rs),r1=Math.max(...rs),c=(c0+c1)/2,r=(r0+r1)/2;
 add(label+':cross',{r,c:c0-.5},{r,c:c1+.5},polygon,.18,'none',layoutPath);
 add(label+':contacts',{r:r0-.4,c:c0-.4},{r:r1+.4,c:c1+.4},polygon,.18,'no',layoutPath);
 add(label+':clear',{r:r1+1,c:c0},{r:r1+1,c:c1},polygon,.18,'pattern',layoutPath);
 add(label+':inside',{r,c},{r,c},polygon,.18,'yes',layoutPath);
}
// Deterministic synthetic polygons exercise reversed winding, translations,
// oblique segments and concavity; they are fixtures, never a gameplay roster.
let seed=197703;const rand=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
for(let i=0;i<256;i++){const c=rand()*200-100,r=rand()*200-100,s=.001+rand()*4,a=rand()*Math.PI*2,polygon=Array.from({length:8},(_,j)=>{const t=a+j*Math.PI/4,length=s*(j%2?.35:1);return[c+Math.cos(t)*length,r+Math.sin(t)*length]});if(i%2)polygon.reverse();add('star:'+i,{r:r+(rand()-.5)*s*5,c:c+(rand()-.5)*s*5},{r:r+(rand()-.5)*s*5,c:c+(rand()-.5)*s*5},polygon,rand()*.3,['none','no','pattern'][i%3]);}
// Godot's decimal JSON reader may round a last binary bit differently. Encode
// each input AND expected number as exact IEEE754 little-endian bytes instead
// of weakening parity with a geometric tolerance or decimal rounding.
function encode(value){if(typeof value==='number'){const b=Buffer.allocUnsafe(8);b.writeDoubleLE(value);return{$f64le:b.toString('hex')};}if(Array.isArray(value))return value.map(encode);if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)]));return value;}
const result={schema:'mafiozi.npc-sweep-oracle/v1',numericEncoding:'ieee754-f64le-hex',sources:[{path:sourcePath,sha256:sha(read(sourcePath))},{path:layoutPath,sha256:sha(read(layoutPath))}],actualBodyCount:bodies.length,cases:encode(cases)};
const destination=path.join(root,'godot/mafiozi_walk/scripts/tests/fixtures/npc_sweep_oracle.json');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(result));
console.log(JSON.stringify({destination,cases:cases.length,actualBodies:bodies.length,sourceSha256:result.sources[0].sha256,bytes:fs.statSync(destination).size}));
