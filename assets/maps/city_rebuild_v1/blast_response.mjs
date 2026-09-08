import {applyWorldBlast} from './world_blast.mjs';
import {createBlastScorch} from './blast_scorch.mjs';
import {planBlastKnockback} from './vehicle_blast_motion.mjs';
export function createBlastResponse(T,scene,{getHero,getVehicles,getRoots,getGlass,groundHeight,onHeroLaunch}){
 const queue=[],scorch=createBlastScorch(T,scene);let sequence=0,total=0,last=null;
 function enqueue(event){if(!event?.point||!Number.isFinite(event.power??1))return;queue.push({...event,point:new T.Vector3(event.point.x,event.point.y??0,event.point.z),power:Math.max(.05,Math.min(4,event.power??1)),radius:Math.max(1,Math.min(24,event.radius??10)),id:++sequence});if(queue.length>16)queue.shift()}
 function transmission(from,to,roots){
  const a=new T.Vector3(from.x,from.y??0,from.z),b=new T.Vector3(to.x,to.y??0,to.z),length=a.distanceTo(b);if(length<.1)return 1;
  const ray=new T.Raycaster(a,b.sub(a).normalize(),.08,Math.max(.08,length-.2));
  const hit=ray.intersectObjects(roots,true).find(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;const mats=Array.isArray(h.object.material)?h.object.material:[h.object.material];return mats.some(m=>m&&!m.transparent&&!(m.transmission>0))});return hit?.object?0:1;
 }
 function update(){
  for(let count=0;queue.length&&count<4;count++){
   const event=queue.shift(),vehicles=getVehicles().filter(v=>v?.car),roots=getRoots();scene.updateMatrixWorld(true);
   const hero=getHero(),coverRoots=[...roots,...vehicles.filter(v=>v.car!==event.source).map(v=>v.car.object)];
   if(hero){const p=hero.object.position,body={x:p.x,y:p.y,z:p.z,groundY:groundHeight(p.x,p.z)};
    const launch=planBlastKnockback(body,event,(from,to)=>transmission(from,{x:to.x,y:to.y+.9,z:to.z},coverRoots));if(launch)onHeroLaunch(launch,event);
   }
   let carsHit=0;
   for(const v of vehicles){if(v.car===event.source||v.damage.state.wrecked||v.damage.state.destroying)continue;const p=v.car.object.localToWorld(new T.Vector3(0,.8,0)),distance=p.distanceTo(event.point),falloff=Math.max(0,1-distance/event.radius);if(!falloff||!transmission(event.point,p,roots))continue;
    v.damage.blastImpact({damage:420*event.power*falloff*falloff,eventId:'blast:'+event.id});const dx=p.x-event.point.x,dz=p.z-event.point.z,length=Math.hypot(dx,dz)||1;
    const mass=Math.max(400,Number(v.car.object.userData.massKg)||1500);
    v.roll?.impact({point:p,normal:{x:-dx/length,y:0,z:-dz/length},impactSpeed:12*Math.sqrt(event.power)*falloff*1500/mass,slideSpeed:0},v.car.object.rotation.y);carsHit++;
   }
   const world=applyWorldBlast(T,{point:event.point,radius:event.radius,power:120*event.power,roots:[...roots,...vehicles.map(v=>v.car.object)],glass:getGlass(),onSurfaceHit:scorch.hit});
   total++;last={id:event.id,power:event.power,radius:event.radius,carsHit,world};
  }
 }
 return{enqueue,update,reset(){queue.length=0;scorch.reset()},dispose(){queue.length=0;scorch.dispose()},stats:()=>({total,pending:queue.length,last,scorch:scorch.stats()})};
}
