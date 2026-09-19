import {createMercenaryFences} from './mercenary_fences.mjs';
import {createMercenaryPowerPanel} from './mercenary_power_panel.mjs';
import {createInteriorSafe} from './interior_interactive_safe.mjs';
import {registerInteriorSafe,requestInteriorSafeAction} from './interior_safe_registry.mjs';
import {createDemoCar,CAR,carCorners} from './car_drive.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
import {createMercenaryBreachDoor} from './mercenary_breach_door.mjs';

const PROFESSIONS=['medic','bruiser','safecracker','engineer','demolitions'];
const accepted=r=>r===true||r?.ok===true;
// One click performs a bounded ground-only search. No search in update/render.
function* anchorSearch({focus,canPlace,groundHeight=()=>0,maxChecks=12000}){
 if(!Number.isFinite(focus?.x)||!Number.isFinite(focus?.z)||typeof canPlace!=='function')return null;
 let checks=0;const offsets=[[0,14]];for(const radius of[24,40,60,85,115])for(let i=0;i<12;i++){const a=i*Math.PI/6;offsets.push([Math.sin(a)*radius,Math.cos(a)*radius]);}
 for(const[dx,dz]of offsets){const x=focus.x+dx,z=focus.z+dz,y=groundHeight(x,z);let clear=Number.isFinite(y);
  // Border and dense interior samples cover access lanes as well as props.
  for(let sx=-11;clear&&sx<=17;sx+=2)for(let sz=-13;clear&&sz<=9;sz+=2){if(++checks>maxChecks)return null;const height=groundHeight(x+sx,z+sz);if(!Number.isFinite(height)||Math.abs(height-y)>.35||canPlace(x+sx,z+sz,1.5)!==true)clear=false;yield;}
  if(clear)return {x,z,y,checks};
 }
 return null;
}
export function findMercenaryShowcaseAnchor(options){const search=anchorSearch(options);let next;do{next=search.next();}while(!next.done);return next.value;}
export async function findMercenaryShowcaseAnchorAsync(options,{yieldTask=()=>new Promise(resolve=>setTimeout(resolve,0)),shouldContinue=()=>true,checksPerSlice=48}={}){
 const search=anchorSearch(options);let count=0;while(shouldContinue()){const next=search.next();if(next.done)return next.value;if(++count>=Math.max(1,checksPerSlice)){count=0;await yieldTask();}}return null;
}
export function mercenaryShowcaseLayout(anchor,groundHeight=()=>anchor.y||0){
 const point=(dx,dz)=>({x:anchor.x+dx,y:groundHeight(anchor.x+dx,anchor.z+dz),z:anchor.z+dz});
 return {anchor:{...anchor},entry:point(0,-12),lookAt:point(1,1),cage:point(-7,3),power:point(-4.85,.25),safe:point(-7,-5),door:point(5,-5),patient:point(-1,-5),vehicle:point(12,5),recruits:PROFESSIONS.map((profession,i)=>({profession,...point((i-2)*2,-9)}))};
}

// A real, disposable QA station in the loaded world. Source recruitment, injury,
// safe permissions/money and explosive outcomes stay in their normal adapters.
export function createMercenaryProfessionShowcase({THREE,RoundedBox,scene,enabled=()=>false,canPlace,groundHeight=()=>0,onCollisionChange,onPowerChange,onExplosion=()=>{},sessionId=String(Date.now())}={}){
 const token=String(sessionId).replace(/[^a-zA-Z0-9_-]/g,'').slice(0,70);if(!token)throw Error('Showcase requires a session id');
 const prefix='QA-MERCENARY-'+token;let group=null,cage=null,power=null,safe=null,door=null,vehicle=null,layout=null,colliders=[],safeBodies=[],unregister=null,disposed=false,lastCull=0,searchPending=null,safeCollisionElapsed=0,safeCollisionPending=false;
 const resources=new Set();
 function replaceBodies(removed,added,context={}){if(disposed||!enabled()||typeof onCollisionChange!=='function')return false;const receipt=onCollisionChange({removed,added,context});if(!accepted(receipt))return false;const deleted=new Set(removed);colliders=colliders.filter(b=>!deleted.has(b)).concat(added);return true;}
 function show(focus){
  if(disposed)return Promise.resolve({ok:false,reason:'disposed'});if(!enabled())return Promise.resolve({ok:false,reason:'qa_not_enabled'});if(group)return Promise.resolve({ok:true,existing:true,layout});if(searchPending)return searchPending;
  if(!scene||!RoundedBox||typeof onCollisionChange!=='function')return Promise.resolve({ok:false,reason:'showcase_not_connected'});
  searchPending=findMercenaryShowcaseAnchorAsync({focus,canPlace,groundHeight},{shouldContinue:()=>!disposed&&enabled()}).then(anchor=>{
   if(disposed)return {ok:false,reason:'disposed'};if(!enabled())return {ok:false,reason:'qa_not_enabled'};return anchor?build(anchor,focus):{ok:false,reason:'no_clear_site'};
  }).finally(()=>{searchPending=null;});return searchPending;
 }
 function build(anchor,focus){
  layout=mercenaryShowcaseLayout(anchor,groundHeight);group=new THREE.Group();group.name='Mercenary_Profession_Showcase';
  cage=createMercenaryFences({THREE,groundHeight,site:{id:prefix+':cage',...layout.cage},onCollisionChange:change=>replaceBodies(change.removed,change.added,change.context)});
  power=createMercenaryPowerPanel({THREE,groundHeight,site:{id:prefix+':power',...layout.power},onPowerChange:change=>enabled()&&typeof onPowerChange==='function'?onPowerChange(change):false});
  const roomId=prefix+':floor:0:main',safeId='interior-safe:'+roomId;
  safe=createInteriorSafe(THREE,{id:safeId,buildingId:prefix,roomId,position:layout.safe,yaw:Math.PI,onUnlock:(id,details)=>requestInteriorSafeAction('unlock',id,details),onCollect:(id,details)=>requestInteriorSafeAction('collect',id,details)});
  safe.object.userData.mercenaryTarget.label='Сейф · медвежатник';
  door=createMercenaryBreachDoor({THREE,site:{id:prefix+':door',...layout.door},groundHeight,onCollisionChange:change=>replaceBodies(change.removed,change.added,change.context),onBlast:onExplosion});
  group.add(cage.object,power.object,safe.object,door.object);scene.add(group);group.updateMatrixWorld(true);safeBodies=safe.getCollisionBodies();
  const car=createDemoCar(THREE,RoundedBox);car.profile={...CAR,id:prefix+':car',label:'Машина для подрыва',massKg:1500};car.object.position.set(layout.vehicle.x,layout.vehicle.y,layout.vehicle.z);car.object.rotation.y=0;
  car.object.name='Showcase_Demolition_Car';car.object.userData.vehicleFleetId=prefix+':car';car.object.userData.label='Машина для подрыва';car.object.traverse(o=>{if(o.geometry)resources.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:[o.material])if(m)resources.add(m);});group.add(car.object);
  const state={x:layout.vehicle.x,z:layout.vehicle.z,yaw:0,speed:0,steer:0,vehicleProfile:car.profile};
  vehicle={id:prefix+':car',car,state,damage:createVehicleDamage(THREE,car,{scene:group,groundHeight,getState:()=>state,onExplosion:event=>onExplosion({...event,record:vehicle})})};
  const corners=carCorners(state.x,state.z,0,car.profile),vehicleBody={id:prefix+':car-body',mercenaryShowcaseVehicle:true,polygonCR:corners.map(p=>[p[0]/4.1,p[1]/4.1]),minYM:layout.vehicle.y,maxYM:layout.vehicle.y+2.25};
  const initial=[...cage.colliders,...power.colliders,...safeBodies,...door.colliders,vehicleBody];
  if(!replaceBodies([],initial,{kind:'showcase_create'})){clearVisuals();return {ok:false,reason:'collision_not_connected'};}
  unregister=registerInteriorSafe(safe,{purpose:'mercenary-qa',position:layout.safe});power.updateVisibility(focus);
  return {ok:true,existing:false,layout,safeId,vehicleId:'fleet:'+vehicle.id};
 }
 function update(dt=0,focus=null){if(disposed||!group)return;const step=Math.min(.1,Math.max(0,Number(dt)||0));
  if(door.needsUpdate)door.update(step);
  safeCollisionElapsed+=step;if(safe.needsUpdate){safe.update(step);safeCollisionPending=true;}
  // Smooth visual door movement, bounded collision refresh, and exact final
  // geometry. This context must never trigger a road-worker snapshot rebuild.
  if(safeCollisionPending&&(safeCollisionElapsed>=.1||!safe.needsUpdate)){const next=safe.getCollisionBodies();if(next===safeBodies||replaceBodies(safeBodies,next,{kind:'safe_door'})){safeBodies=next;safeCollisionPending=false;safeCollisionElapsed=0;}}
  const state=vehicle.damage.state;if(state.hp<state.maxHp||state.destroying||state.wrecked)vehicle.damage.update(step);
  lastCull+=step;if(lastCull>=.25){lastCull=0;power.updateVisibility(focus);}
 }
 function clearVisuals(){unregister?.();unregister=null;cage?.dispose();power?.dispose();safe?.dispose();door?.dispose();vehicle?.damage.dispose();for(const resource of resources)resource.dispose();resources.clear();group?.removeFromParent();group=cage=power=safe=door=vehicle=layout=null;safeBodies=[];}
 return {show,update,get layout(){return layout;},get colliders(){return colliders;},getTargets:()=>group?[...cage.getTargets(),...power.getTargets(),...door.getTargets(),{id:safe.getState().id,kind:'safe',object:safe.object}]:[],getPickRoots:()=>group?[group]:[],getVehicles:()=>vehicle?[vehicle]:[],get safe(){return safe;},get door(){return door;},dispose(){if(disposed)return;if(colliders.length&&typeof onCollisionChange==='function')onCollisionChange({removed:colliders,added:[],context:{kind:'showcase_dispose'}});colliders=[];clearVisuals();disposed=true;}};
}
