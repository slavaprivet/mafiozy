import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const {createWaterInteractionInputSampler} = await import(pathToFileURL(process.argv[2]));
const cases=JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
class V {constructor(){this.x=0;this.y=0;this.z=0;}}
const number=v=>v==='NaN'?NaN:v==='Infinity'?Infinity:v;
const object=()=>({p:[0,0,0],rotation:{y:.7},userData:{},getWorldPosition(v){[v.x,v.y,v.z]=this.p.map(number);}});
let calls=0,bounds={},body=object();
const owner=()=>({object:body,diagnostics:()=>{calls++;return {sourceBounds:bounds};}});
let hero=owner();const sampler=createWaterInteractionInputSampler({THREE:{Vector3:V}}), rows=[];
for(const c of cases){
 if(c.new_node){body=object();hero.object=body;}
 if(c.new_owner)hero=owner();
 if(c.reset)sampler.reset();
 if(c.bounds)bounds=c.bounds;
 if(c.p)body.p=c.p;
 hero.scale=c.source_scale??1;hero.massKg=c.mass_kg;body.userData.massKg=c.meta_mass??80;
 const h=sampler.sample({hero:c.missing?null:hero,dt:number(c.dt??.1),occupiedSeat:c.occupied_seat,transition:c.transition,teleport:c.teleport,heroVelocityY:number(c.vertical_velocity)}).hero;
 const normalized=h?{id:h.id,kind:h.kind,p:Object.values(h.position),yaw:h.yaw,contactOffsetY:h.contactOffsetY,enabled:h.enabled,teleport:h.teleport,v:h.velocity?Object.values(h.velocity):null,mass:h.massKg??null,footprint:h.footprint??null}:null;
 rows.push({name:c.name,sample:normalized,callbacks:calls});
}
console.log(JSON.stringify(rows));
