// Executes the original JS module. Tiny THREE vector seam; no vehicle geometry.
import fs from 'node:fs';import {pathToFileURL} from 'node:url';
const {createWaterInteractionInputSampler}=await import(pathToFileURL(process.argv[2]));
class V {constructor(){this.x=0;this.y=0;this.z=0;}}
const object=()=>({p:[0,0,0],rotation:{y:0.4},getWorldPosition(v){[v.x,v.y,v.z]=this.p;}});
const hero={object:object(),scale:.95,diagnostics:()=>({sourceBounds:{min:[-.6,0,-.3],max:[.6,2,.3]}})};
const sampler=createWaterInteractionInputSampler({THREE:{Vector3:V}}),rows=[];
for(const c of JSON.parse(fs.readFileSync(new URL('./oracle_cases.json',import.meta.url),'utf8'))){
 if(c.reset)sampler.reset();if(c.replacement)hero.object=object();if(c.p)hero.object.p=c.p;
 const h=sampler.sample({hero:c.missing?null:hero,dt:c.dt,occupiedSeat:c.occupied_seat,transition:c.transition,heroVelocityY:c.vertical_velocity}).hero;
 rows.push(h?{enabled:h.enabled,teleport:h.teleport,p:Object.values(h.position),v:h.velocity?Object.values(h.velocity):null,width:h.footprint?.width}:null);
}
console.log(JSON.stringify(rows));
