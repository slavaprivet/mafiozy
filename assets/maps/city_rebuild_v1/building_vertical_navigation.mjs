import {createLadderClimbController} from './roof_ladder.mjs';
import {applyRoofLadderPose} from './roof_ladder_pose.mjs';

export function createBuildingVerticalNavigation({THREE:T,getHero,getEntries,getWeapon,camera,controls,canOccupy,onBegin=()=>{},onEnd=()=>{}}){
 const clear=(p,ctx)=>canOccupy(p,ctx.radius,ctx.bodyHeight);
 const controller=createLadderClimbController({validatePosition:clear,validateSegment(a,b,ctx){const n=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.y-a.y,b.z-a.z)/.12));for(let i=0;i<=n;i++){const t=i/n;if(!clear({x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t,z:a.z+(b.z-a.z)*t},ctx))return false}return true;}});
 let sample=null,weaponVisibility=null;
 function nearest(){const hero=getHero();return hero?controller.prompt(hero.object.position,getEntries().map(e=>e.storeys?.ladder?.worldDescriptor).filter(Boolean)):null}
 function begin(candidate,options){const hero=getHero();if(!hero||!candidate||!controller.begin(hero.object.position,candidate.ladder,candidate.end,options))return false;onBegin();const weapon=getWeapon();weaponVisibility=weapon?{weapon,visible:weapon.visible}:null;if(weapon)weapon.visible=false;return true}
 function update(dt){if(!controller.locked)return;const hero=getHero(),before=hero.object.position.clone();sample=controller.update(dt);if(!sample)return;hero.object.position.set(sample.position.x,sample.position.y,sample.position.z);const shift=hero.object.position.clone().sub(before);camera.position.add(shift);controls.target.add(shift);if(sample.done){if(weaponVisibility)weaponVisibility.weapon.visible=weaponVisibility.visible;weaponVisibility=null;hero.reset();onEnd(sample)}else pose();}
 function pose(){if(controller.locked&&sample){getHero().object.rotation.y=sample.pose.yaw;applyRoofLadderPose(getHero(),sample.pose,T);const weapon=getWeapon();if(weapon)weapon.visible=false}}
 function reset(){controller.reset();sample=null;if(weaponVisibility)weaponVisibility.weapon.visible=weaponVisibility.visible;weaponVisibility=null}
 function slideDown(){if(controller.locked)return controller.slideDown();const candidate=nearest();return candidate?.end==='upper'?begin(candidate,{sliding:true}):false}
 return{nearest,begin,slideDown,update,pose,reset,cancel:()=>controller.cancel(),get active(){return controller.locked},get state(){return sample}};
}
