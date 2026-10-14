#!/usr/bin/env node
// Source-extracted oracle for deformation grid cell ownership at boundaries.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const sourcePath=path.join(repo,'assets/maps/city_rebuild_v1/vehicle_crash.mjs');
const source=fs.readFileSync(sourcePath,'utf8');
const hash=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const extract=name=>{
 const start=source.indexOf(`function ${name}(`);if(start<0)throw new Error(`missing source function ${name}`);
 const open=source.indexOf('{',start);let depth=0,end=-1;
 for(let i=open;i<source.length;i++){if(source[i]==='{')depth++;else if(source[i]==='}'&&--depth===0){end=i+1;break}}
 if(end<0)throw new Error(`unterminated source function ${name}`);
 return (0,eval)(`(${source.slice(start,end)})`);
};
const gridInterval=extract('gridInterval'),gridBlend=extract('gridBlend');
const profile={halfWidth:1.188,halfLength:2.4542,height:1.9659721119020948};
const grids={x:[-profile.halfWidth,0,profile.halfWidth],y:[.28,profile.height*.46,profile.height*.91],z:[-profile.halfLength,-profile.halfLength*.5,0,profile.halfLength*.5,profile.halfLength]};
const bits=new ArrayBuffer(4),view=new DataView(bits);
function adjacent(value,direction){
 value=Math.fround(value);if(Number.isNaN(value)||value===direction*Infinity)return value;
 if(value===0){view.setUint32(0,1,false);const smallest=view.getFloat32(0,false);return direction<0?-smallest:smallest}
 view.setFloat32(0,value,false);let raw=view.getUint32(0,false);raw+=((value>0)=== (direction>0))?1:-1;view.setUint32(0,raw,false);return view.getFloat32(0,false);
}
const values={
 x:[['x_out_low',Math.fround(-profile.halfWidth*1.5)],['x_min',Math.fround(-profile.halfWidth)],['x_zero_prev',adjacent(0,-1)],['x_zero',0],['x_zero_next',adjacent(0,1)],['x_max',Math.fround(profile.halfWidth)],['x_out_high',Math.fround(profile.halfWidth*1.5)]],
 y:[['y_out_low',Math.fround(0)],['y_min',Math.fround(grids.y[0])],['y_mid_prev',adjacent(grids.y[1],-1)],['y_mid',Math.fround(grids.y[1])],['y_mid_next',adjacent(grids.y[1],1)],['y_max',Math.fround(grids.y[2])],['y_out_high',Math.fround(profile.height*1.2)]],
 z:[['z_out_low',Math.fround(-profile.halfLength*1.5)],['z_min',Math.fround(-profile.halfLength)],['z_neg_half_prev',adjacent(-profile.halfLength*.5,-1)],['z_neg_half',Math.fround(-profile.halfLength*.5)],['z_neg_half_next',adjacent(-profile.halfLength*.5,1)],['z_zero_prev',adjacent(0,-1)],['z_zero',0],['z_zero_next',adjacent(0,1)],['z_pos_half_prev',adjacent(profile.halfLength*.5,-1)],['z_pos_half',Math.fround(profile.halfLength*.5)],['z_pos_half_next',adjacent(profile.halfLength*.5,1)],['z_max',Math.fround(profile.halfLength)],['z_out_high',Math.fround(profile.halfLength*1.5)]],
};
function bind(label,p,inputKind='source_float32'){
 const xi=gridInterval(grids.x,p[0]),yi=gridInterval(grids.y,p[1]),zi=gridInterval(grids.z,p[2]);
 const blend=[gridBlend(grids.x,p[0],xi),gridBlend(grids.y,p[1],yi),gridBlend(grids.z,p[2],zi)];
 const indices=[];let lo=0,hi=0;
 for(let z=0;z<2;z++)for(let y=0;y<2;y++)for(let x=0;x<2;x++){
  const index=((zi+z)*3+yi+y)*3+xi+x;indices.push(index);
  if(index<32)lo=(lo|(1<<index))>>>0;else hi=(hi|(1<<(index-32)))>>>0;
 }
 return {label,input_kind:inputKind,source_point:p,native_point:[-p[0],p[1],-p[2]],cell:[xi,yi,zi],blend,node_indices:indices,mask_lo:lo,mask_hi:hi};
}
const rows=[];
for(const [label,x] of values.x)rows.push(bind(label,[x,Math.fround(grids.y[1]),Math.fround(grids.z[2])]));
for(const [label,y] of values.y)rows.push(bind(label,[Math.fround(grids.x[1]),y,Math.fround(grids.z[2])]));
for(const [label,z] of values.z)rows.push(bind(label,[Math.fround(grids.x[1]),Math.fround(grids.y[1]),z]));
for(const [xLabel,x] of values.x.filter(v=>v[0].startsWith('x_zero')))
 for(const [zLabel,z] of values.z.filter(v=>v[0].includes('half')||v[0].startsWith('z_zero')))
  for(const [yLabel,y] of values.y.filter(v=>['y_min','y_mid','y_max'].includes(v[0])))rows.push(bind(`${xLabel}_${zLabel}_${yLabel}`,[x,y,z]));
for(const [label,p] of [
 ['scalar_x_zero_exact64',[0,grids.y[1],0]],['scalar_y_min_exact64',[0,grids.y[0],0]],['scalar_y_mid_exact64',[0,grids.y[1],0]],['scalar_y_max_exact64',[0,grids.y[2],0]],
 ['scalar_z_neg_half_exact64',[0,grids.y[0],-profile.halfLength*.5]],['scalar_z_zero_exact64',[0,grids.y[0],0]],['scalar_z_pos_half_exact64',[0,grids.y[0],profile.halfLength*.5]],
])rows.push(bind(label,p,'source_float64'));
const fixture={schema:'mafiozi.transport-deformation-cell-boundary-oracle.v1',source:{path:path.relative(repo,sourcePath).replaceAll('\\','/'),sha256:hash(sourcePath),functions:['gridInterval','gridBlend'],lines:'54-58'},profile,grids,float_input:'Float32 mesh-local source coordinates',rows};
const destination=path.join(repo,'godot/mafiozi_walk/data/transport/vehicle_deformation_cell_boundary_oracle.json');
fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(fixture)+'\n');
const cache=path.join(repo,'outputs/oracle_review/vehicle_deformation_cell_boundary_oracle.json');fs.mkdirSync(path.dirname(cache),{recursive:true});fs.copyFileSync(destination,cache);
console.log(JSON.stringify({output:path.relative(repo,destination).replaceAll('\\','/'),cache:path.relative(repo,cache).replaceAll('\\','/'),sha256:hash(destination),rows:rows.length}));
