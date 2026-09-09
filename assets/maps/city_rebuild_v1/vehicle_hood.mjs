// Hood/service hatch presentation. The crash adapter remains the sole owner of
// detached hood debris; the engine bay is a separate body-attached assembly.
import {stepVehiclePanelMotion} from './vehicle_trunk.mjs';
import {sampleCrashDeformation,crashCrushLimits} from './vehicle_crash_mechanics.mjs';
export const VEHICLE_HOOD_RULES=Object.freeze({range:1.5,maxInteractionSpeed:.5,maxRepairSpeed:.2,animationSeconds:.70,openAngle:-Math.PI*80/180});
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const smooth=v=>{const t=clamp(v);return t*t*(3-2*t)};

export function findHoodInteraction(vehicle,hero,{state={},profile={},damageState=null,occupied=false,transition=false,blocked=false}={}){
  if(!vehicle||!hero||![vehicle.x,vehicle.z,vehicle.yaw,vehicle.speed??0,hero.x,hero.z,hero.y??0].every(Number.isFinite)||occupied||transition||blocked||damageState?.destroying||damageState?.wrecked||Math.abs(vehicle.speed||0)>VEHICLE_HOOD_RULES.maxInteractionSpeed)return null;
  const sin=Math.sin(vehicle.yaw),cos=Math.cos(vehicle.yaw),dx=hero.x-vehicle.x,dz=hero.z-vehicle.z,side=dx*cos-dz*sin,front=dx*sin+dz*cos;
  const sign=profile.front===false?-1:1,accessZ=profile.accessZ??2.22,accessSide=profile.accessSide??0;
  if((front-accessZ)*sign<.10||Math.abs(side)>(profile.width??1.91)*.5+.3||Math.abs((hero.y??0)-(vehicle.y??0))>1.8)return null;
  const near=Math.hypot(side-accessSide,front-accessZ);if(near>VEHICLE_HOOD_RULES.range)return null;
  const repairAvailable=(state.amount>=.9||state.detached)&&Math.abs(vehicle.speed||0)<=VEHICLE_HOOD_RULES.maxRepairSpeed;
  return{kind:'hood',near,action:state.detached?'repair':state.target?'close':'open',label:state.detached?'Капот сорван — двигатель доступен':state.target?'Закрыть капот':'Открыть капот',repairAvailable,repairLabel:repairAvailable?'R — ремонт двигателя':null,anchor:{x:vehicle.x+accessSide*cos+accessZ*sin,y:(vehicle.y??0)+(profile.handleY??1),z:vehicle.z-accessSide*sin+accessZ*cos}};
}

export function createVehicleHood(T,RoundedBox,car,{scene=null,groundHeight=()=>0,onRepair=()=>{}}={}){
  if(!car?.object)throw Error('Hood requires a vehicle object');
  const spec=car.hoodSpec||{},lid=spec.lid||car.object.getObjectByName('Hood_lid');
  let bodyMesh=null;lid?.traverse(node=>{if(!bodyMesh&&node.isMesh&&node.geometry?.attributes?.position)bodyMesh=node});
  const initial=()=>({target:0,amount:0,velocity:0,detached:false,repairs:0,smoke:0,reason:null});
  let state=initial(),disposed=false,time=0,lastAngle=-1,lastDetailVisibility=null,idleUpdates=0;
  if(!bodyMesh)return{enabled:false,reason:'no-separate-hood',interaction:()=>null,toggle:()=>({accepted:false,reason:'no-separate-hood'}),repair:()=>({accepted:false,reason:'no-separate-hood'}),update(){},reset(){},dispose(){},stats:()=>({enabled:false,detached:false,smoke:0,amount:0})};
  const original={parent:lid.parent,position:lid.position.clone(),quaternion:lid.quaternion.clone(),scale:lid.scale.clone(),visible:lid.visible};
  car.object.updateWorldMatrix(true,true);
  const bounds=node=>{const b=new T.Box3(),inverse=car.object.matrixWorld.clone().invert(),p=new T.Vector3();node.traverse(mesh=>{const a=mesh.geometry?.attributes?.position;if(a)for(let i=0;i<a.count;i++)b.expandByPoint(p.fromBufferAttribute(a,i).applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse))});return b};
  const lidBounds=bounds(lid),core=spec.core||car.object.getObjectByName('Engine_core'),coreBounds=core?bounds(core):null,coreVisible=core?.visible;
  const front=spec.front!==false,sign=front?1:-1,width=lidBounds.max.x-lidBounds.min.x;
  const profile={front,width:Math.max(width,car.profile?.width??0),accessSide:spec.accessSide??(front?0:(lidBounds.min.x+lidBounds.max.x)/2+width*.30),accessZ:sign*Math.max(car.profile?.halfLength||0,front?lidBounds.max.z:-lidBounds.min.z)+sign*.06,handleY:Math.min(lidBounds.max.y,lidBounds.min.y+.12)};
  const defaultHinge=[(lidBounds.min.x+lidBounds.max.x)/2,lidBounds.max.y,front?lidBounds.min.z-.012:lidBounds.max.z+.012];
  const hinge=new T.Group();hinge.name='Hood_hinge';hinge.userData.vehiclePartId='hood';hinge.position.fromArray(spec.hingePoint||defaultHinge);car.object.add(hinge);hinge.updateWorldMatrix(true,false);hinge.attach(lid);
  const requestedAngle=Number.isFinite(spec.openAngle)?spec.openAngle:VEHICLE_HOOD_RULES.openAngle*sign,openAngle=Math.sign(requestedAngle)*clamp(Math.abs(requestedAngle),Math.PI*80/180,Math.PI*85/180);
  const closed={position:lid.position.clone(),quaternion:lid.quaternion.clone(),scale:lid.scale.clone()};
  const bay=new T.Group();bay.name='Engine_bay_detail';bay.userData.crashDeform=false;car.object.add(bay);if(core)core.visible=false;
  const geometries=new Set(),materials=new Set(),lidAdditions=[];
  const mat=options=>{const m=new T.MeshStandardMaterial(options);materials.add(m);return m};
  const iron=mat({color:'#3c4547',metalness:.55,roughness:.65}),aluminum=mat({color:'#a4aaa2',metalness:.68,roughness:.38}),black=mat({color:'#172021',roughness:.91}),red=mat({color:'#913c32',metalness:.2,roughness:.64}),cap=mat({color:'#c4ae62',metalness:.4,roughness:.54});
  function mesh(name,geometry,material,parent=bay){const m=new T.Mesh(geometry,material);m.name=name;m.castShadow=m.receiveShadow=true;m.userData.crashDeform=false;geometries.add(geometry);parent.add(m);return m}
  function box(name,w,h,d,x,y,z,material=iron,parent=bay){const m=mesh(name,new RoundedBox(w,h,d,2,Math.max(.001,Math.min(.015,w/4,h/4,d/4))),material,parent);m.position.set(x,y,z);return m}
  function pipe(name,a,b,r=.022,material=black){const start=new T.Vector3(...a),end=new T.Vector3(...b),direction=end.clone().sub(start);const m=mesh(name,new T.CylinderGeometry(r,r,direction.length(),8),material);m.position.copy(start).addScaledVector(direction,.5);m.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),direction.normalize());return m}
  let engineBounds=spec.engineBounds;
  if(!engineBounds){
    const half=Math.max(.18,Math.min(width*.40,coreBounds?(coreBounds.max.x-coreBounds.min.x)*.52:width*.34)),top=lidBounds.min.y-.026;
    const floor=Math.max(.22,Math.min(top-.20,coreBounds?.min.y??top-.52)),rearZ=lidBounds.min.z+.065,frontZ=lidBounds.max.z-.065;
    engineBounds={min:[-half,floor,rearZ],max:[half,top,Math.max(rearZ+.20,frontZ)]};
  }
  const lo=engineBounds.min,hi=engineBounds.max,cx=(lo[0]+hi[0])/2,cy=(lo[1]+hi[1])/2,cz=(lo[2]+hi[2])/2;
  // Keep the powertrain rigid while its body mounts follow the local cage.
  // Offset the parent only: the crash adapter owns all structural vertex edits.
  const mountPoint={x:cx,y:cy,z:cz};
  function updateMount(crashState){
    if(!crashState?.profile||!crashState.grid||crashState.nodes?.length!==45)return false;
    const offset=sampleCrashDeformation(crashState,mountPoint);if(![offset.x,offset.y,offset.z].every(Number.isFinite))return false;
    const limits=crashCrushLimits(crashState.profile),x=clamp(offset.x,-limits.x,limits.x),y=clamp(offset.y,-limits.y,limits.y),z=clamp(offset.z,-limits.z,limits.z);
    if(bay.position.x===x&&bay.position.y===y&&bay.position.z===z)return false;
    bay.position.set(x,y,z);lastAngle=-1;return true;
  }
  const w=Math.max(.24,hi[0]-lo[0]),h=Math.max(.20,hi[1]-lo[1]),d=Math.max(.24,hi[2]-lo[2]);
  const engineZ=cz-sign*d*.13,engineBase=lo[1]+(front?h*.10:0);
  let radiatorZ=front?hi[2]-d*.065:lo[2]+d*.065,radiatorHeight=h*.77,radiatorY=lo[1]+h*.46;
  if(front){
    // Match the actual sloped closed bonnet, not its highest AABB corner.
    // A cab-over nose is much lower than the engine bay under the cab.
    let ceiling=Infinity;
    const surfaceAt=z=>{let y=Infinity;for(const x of [cx-w*.29,cx,cx+w*.29]){const origin=car.object.localToWorld(new T.Vector3(x,Math.max(lidBounds.max.y,hi[1])+1,z)),direction=new T.Vector3(0,-1,0).transformDirection(car.object.matrixWorld),hit=new T.Raycaster(origin,direction,0,5).intersectObject(lid,true)[0];if(hit)y=Math.min(y,car.object.worldToLocal(hit.point.clone()).y-.028)}return y};
    for(let i=0;i<=6;i++){const z=hi[2]-d*(.065+i*.06),limit=surfaceAt(z);radiatorZ=z;ceiling=limit;if(!Number.isFinite(limit)||limit-lo[1]>=Math.min(.27,h*.6))break}
    if(Number.isFinite(ceiling)){const base=lo[1]+Math.min(.025,h*.06);radiatorHeight=Math.max(.055,Math.min(radiatorHeight,ceiling-base));radiatorY=base+radiatorHeight*.5}
  }
  bay.userData.engineBounds=engineBounds;bay.userData.vehicleComponent='engine';
  box('Engine_bay_floor',w,.032,d,cx,lo[1],cz,black);
  for(const x of [lo[0],hi[0]])box('Engine_bay_side',.025,h*.74,d,x,lo[1]+h*.37,cz,black);
  box('Engine_block',w*.55,h*.54,d*.52,cx,engineBase+h*.32,engineZ,iron);
  box('Engine_oil_pan',w*.47,h*.13,d*.47,cx,engineBase+h*.055,engineZ,black);
  box('Engine_valve_cover',w*.50,h*.13,d*.48,cx,engineBase+h*.66,engineZ,aluminum);
  for(const side of [-1,1])for(const z of [-.18,.18])box('Engine_mount',w*.095,h*.12,d*.10,cx+side*w*.32,engineBase+h*.25,engineZ+z*d,black);
  for(let i=0;i<5;i++)box('Valve_cover_rib',w*.42,h*.022,d*.022,cx,engineBase+h*.741,engineZ+(i-2)*d*.083,iron);
  const oilCap=mesh('Oil_filler_cap',new T.CylinderGeometry(w*.045,w*.045,h*.04,12),cap);oilCap.position.set(cx-w*.11,engineBase+h*.76,engineZ-d*.13);
  box('Radiator_frame',w*.83,radiatorHeight,d*.095,cx,radiatorY,radiatorZ,iron);
  box('Radiator_core',w*.75,radiatorHeight*.86,d*.105,cx,radiatorY,radiatorZ,black);
  for(let i=-5;i<=5;i++)box('Radiator_cooling_fin',w*.009,radiatorHeight*.79,d*.115,cx+i*w*.061,radiatorY,radiatorZ,aluminum);
  const fan=mesh('Radiator_fan_shroud',new T.TorusGeometry(Math.min(w*.16,radiatorHeight*.34),.022,6,18),black);fan.position.set(cx,radiatorY,radiatorZ-sign*d*.09);
  for(let i=0;i<4;i++){const blade=box('Radiator_fan_blade',w*.23,h*.045,.012,fan.position.x,fan.position.y,fan.position.z,black);blade.rotation.z=i*Math.PI/2}
  const beltZ=engineZ+sign*d*.30;
  for(const side of [-1,1]){const pulley=mesh('Accessory_pulley',new T.CylinderGeometry(h*.105,h*.105,.025,14),black);pulley.rotation.x=Math.PI/2;pulley.position.set(cx+side*w*.16,engineBase+h*.32,beltZ)}
  pipe('Drive_belt_top',[cx-w*.16,engineBase+h*.40,beltZ],[cx+w*.16,engineBase+h*.40,beltZ],.012);
  pipe('Drive_belt_bottom',[cx-w*.16,engineBase+h*.24,beltZ],[cx+w*.16,engineBase+h*.24,beltZ],.012);
  const batteryX=cx+w*.36;
  box('Engine_battery',w*.20,h*.29,d*.26,batteryX,lo[1]+h*.38,cz-sign*d*.27,black);
  for(const side of [-1,1])box('Battery_terminal',w*.035,h*.025,d*.03,batteryX+side*w*.055,lo[1]+h*.541,cz-sign*d*.27,side>0?red:aluminum);
  box('Air_filter_housing',w*.19,h*.20,d*.30,cx-w*.36,lo[1]+h*.49,cz-sign*d*.22,black);
  pipe('Intake_pipe',[cx-w*.31,lo[1]+h*.55,cz-sign*d*.16],[cx-w*.15,engineBase+h*.62,engineZ],Math.min(.036,w*.027));
  pipe('Upper_radiator_hose',[cx+w*.21,engineBase+h*.66,engineZ+sign*d*.24],[cx+w*.28,radiatorY+radiatorHeight*.30,radiatorZ-sign*d*.055],Math.min(.030,w*.025));
  pipe('Lower_radiator_hose',[cx-w*.22,engineBase+h*.22,engineZ+sign*d*.24],[cx-w*.27,radiatorY-radiatorHeight*.30,radiatorZ-sign*d*.055],Math.min(.027,w*.022));
  const tank=box('Coolant_expansion_tank',w*.15,h*.24,d*.18,cx-w*.36,lo[1]+h*.38,cz+sign*d*.20,aluminum);box('Coolant_cap',w*.058,h*.035,d*.052,tank.position.x,lo[1]+h*.518,tank.position.z,cap);
  const handle=new T.Vector3(profile.accessSide,lidBounds.min.y+.01,front?lidBounds.max.z+.012:lidBounds.min.z-.012);lid.worldToLocal(car.object.localToWorld(handle));
  const handleMesh=box('Hood_release_handle',Math.min(.19,w*.18),.026,.035,handle.x,handle.y,handle.z,aluminum,lid);lidAdditions.push(handleMesh);
  const props=[];for(const side of [-1,1]){const base=new T.Vector3(cx+side*w*.42,lo[1]+h*.35,front?lo[2]+d*.11:hi[2]-d*.11),tip=new T.Vector3(cx+side*w*.42,lidBounds.min.y-.006,cz+sign*d*.19);lid.worldToLocal(car.object.localToWorld(tip));const m=mesh('Hood_support_strut',new T.CylinderGeometry(.012,.012,1,8),aluminum);props.push({mesh:m,base,tip})}
  const details=bay.children.slice();
  const smoke=Array.from({length:9},(_,i)=>{const material=new T.MeshBasicMaterial({color:i%2?'#747b78':'#c6d1c8',transparent:true,opacity:0,depthWrite:false});materials.add(material);const m=mesh('Engine_smoke_'+i,new T.IcosahedronGeometry(.09,1),material);m.visible=false;m.raycast=()=>{};return m});
  function pose(){const angle=smooth(state.amount)*openAngle,exposed=state.amount>.01||state.detached||!lid.visible;if(angle===lastAngle&&lastDetailVisibility===exposed)return;lastAngle=angle;hinge.rotation.x=angle;if(exposed!==lastDetailVisibility){for(const mesh of details)mesh.visible=exposed;lastDetailVisibility=exposed}if(!exposed)return;car.object.updateWorldMatrix(true,true);for(const p of props){p.mesh.visible=!state.detached;if(state.detached)continue;const end=bay.worldToLocal(lid.localToWorld(p.tip.clone())),direction=end.sub(p.base);p.mesh.position.copy(p.base).addScaledVector(direction,.5);p.mesh.scale.set(1,direction.length(),1);p.mesh.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),direction.normalize())}}
  function interaction(hero,vehicleState,context={}){if(disposed)return null;const result=findHoodInteraction({...vehicleState,y:car.object.getWorldPosition(new T.Vector3()).y},hero,{...context,profile,state:{...state,detached:state.detached||!lid.visible}});if(result){const a=car.object.localToWorld(new T.Vector3(profile.accessSide,profile.handleY,profile.accessZ));result.anchor={x:a.x,y:a.y,z:a.z}}return result}
  function eligibility(context={},repairing=false){if(disposed)return'disposed';if(!repairing&&(state.detached||!lid.visible))return'detached';if(context.damageState?.destroying||context.damageState?.wrecked)return'destroyed';if(context.occupied)return'occupied';if(context.transition)return'transition';if(context.blocked)return'blocked';if(!context.vehicleState)return'missing-vehicle-state';if(Math.abs(context.vehicleState.speed||0)>.5)return'moving';if(!interaction(context.hero,context.vehicleState,context))return'out-of-range';return null}
  function toggle(context={}){const reason=eligibility(context);if(reason)return{accepted:false,reason};state.target=state.target?0:1;state.reason=null;return{accepted:true,open:!!state.target}}
  function repair(context={}){
    const damage=context.damage,reason=eligibility({...context,damageState:damage?.state||context.damageState},true);if(reason)return{accepted:false,reason};
    if(!state.detached&&lid.visible&&(state.amount<.9||!state.target))return{accepted:false,reason:'hood-closed'};if(Math.abs(context.vehicleState.speed||0)>VEHICLE_HOOD_RULES.maxRepairSpeed)return{accepted:false,reason:'moving'};
    if(!damage?.repairPowertrain)return{accepted:false,reason:'no-repair-adapter'};const result=damage.repairPowertrain();if(result?.accepted===false)return result;state.repairs++;state.smoke=0;for(const m of smoke)m.visible=false;onRepair({car,damage,result});return{accepted:true,repairs:state.repairs,...result};
  }
  function update(dt,{vehicleState=null,damageState=null,crashState=null}={}){
    if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid hood time');
    const mountChanged=updateMount(crashState);
    let detachedThisFrame=false;if(!lid.visible&&!state.detached){state.detached=true;state.target=0;state.reason='detached';detachedThisFrame=true}
    const engine=Number.isFinite(crashState?.engine)?crashState.engine:1,radiator=Number.isFinite(crashState?.radiator)?crashState.radiator:1,temperature=Number.isFinite(crashState?.temperature)?crashState.temperature:0;
    const severity=damageState?.wrecked||damageState?.destroying?0:Math.max(clamp((.65-engine)/.65),clamp((.45-radiator)/.45)*.8,clamp((temperature-.50)*2));
    // A closed healthy lid (or a detached, cooled one) has no evolving pose,
    // smoke or interaction state. Keep the authored final meshes untouched.
    if(!mountChanged&&!detachedThisFrame&&(state.detached||state.amount===0&&state.target===0&&state.velocity===0)&&severity===0&&!state.smoke){idleUpdates++;return}
    time+=Math.min(dt,.2);
    if(!state.detached){if(Math.abs(vehicleState?.speed||0)>2.5||damageState?.destroying||damageState?.wrecked)state.target=0;Object.assign(state,stepVehiclePanelMotion(state.amount,state.velocity,state.target,dt))}pose();
    if(!severity&&!state.smoke)return;state.smoke=severity;
    for(const [i,m]of smoke.entries()){m.visible=severity>.015;if(!m.visible)continue;const age=(time*(.36+severity*.20)+i/smoke.length)%1,open=state.amount>.4||state.detached;m.position.set(cx+Math.sin(i*2.4+time)*(.045+age*.18),Math.max(hi[1],open?hi[1]:lidBounds.max.y)+.025+age*(.6+severity*.9),open?engineZ:radiatorZ-sign*d*.06);m.position.z+=Math.cos(i*1.7)*age*.13;m.scale.setScalar(.45+age*(1.7+severity));m.material.opacity=Math.sin(Math.PI*age)*severity*.34}
  }
  function reset(){if(disposed)return;state=initial();time=0;lastAngle=-1;idleUpdates=0;bay.position.set(0,0,0);lid.visible=original.visible;lid.position.copy(closed.position);lid.quaternion.copy(closed.quaternion);lid.scale.copy(closed.scale);if(core)core.visible=false;for(const m of smoke)m.visible=false;pose()}
  function dispose(){if(disposed)return;disposed=true;for(const m of lidAdditions)m.removeFromParent();original.parent.add(lid);lid.position.copy(original.position);lid.quaternion.copy(original.quaternion);lid.scale.copy(original.scale);lid.visible=original.visible;if(core)core.visible=coreVisible;hinge.removeFromParent();bay.removeFromParent();for(const g of geometries)g.dispose();for(const m of materials)m.dispose()}
  pose();return{enabled:true,lid,hinge,bay,profile,interaction,toggle,repair,update,reset,dispose,get state(){return state},stats:()=>({enabled:true,open:!!state.target,amount:state.amount,angle:hinge.rotation.x,detached:state.detached,repairs:state.repairs,smoke:state.smoke,smokeParticles:smoke.filter(m=>m.visible).length,idleUpdates,engineParts:details.length,visibleEngineParts:lastDetailVisibility?details.length-(state.detached?props.length:0):0,front})};
}
