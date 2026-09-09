// Read-only bridge from the posed walk actors to water presentation. No solver state writes.
const finite=Number.isFinite;
const point=v=>({x:v.x,y:v.y,z:v.z});
const valid=v=>v&&finite(v.x)&&finite(v.y)&&finite(v.z);
const positive=v=>finite(v)&&v>0?v:undefined;

export function createWaterInteractionInputSampler({THREE}){
 const previous=new Map(),heroWidths=new WeakMap(),v=new THREE.Vector3();
 function sample({hero,records=[],occupiedSeat=null,transition=null,heroVelocityY,dt,teleport=false}={}){
  const inputs=[],seen=new Set(),seconds=finite(dt)&&dt>0&&dt<=.25?dt:null;
  function add(input,object){
   if(!valid(input.position))return;
   seen.add(input.id);const old=previous.get(input.id);
   const moved=old?Math.hypot(input.position.x-old.position.x,input.position.y-old.position.y,input.position.z-old.position.z):0;
   input.teleport=!!teleport||!old||old.object!==object||old.enabled!==input.enabled||!seconds||moved>12;
   if(!input.teleport&&old)input.velocity={x:(input.position.x-old.position.x)/seconds,y:(input.position.y-old.position.y)/seconds,z:(input.position.z-old.position.z)/seconds};
   if(input.kind==='hero'&&finite(heroVelocityY)&&!input.teleport)input.velocity={...(input.velocity||{x:0,z:0}),y:heroVelocityY};
   previous.set(input.id,{position:point(input.position),object,enabled:input.enabled});inputs.push(input);
  }
  const object=hero?.object;
  if(object){
   object.getWorldPosition(v);
   // createHeroWalker normalises source feet to origin; animated ankle bones are
   // intentionally not used as a sole plane (they would produce gait false impacts).
   if(!heroWidths.has(hero)){
    const bounds=hero.diagnostics?.().sourceBounds,s=positive(hero.scale)||1;
    const extent=bounds?.max&&bounds?.min?(bounds.max.x??bounds.max[0])-(bounds.min.x??bounds.min[0]):NaN;
    heroWidths.set(hero,positive(extent*s));
   }
   const width=heroWidths.get(hero);
   add({id:'hero',kind:'hero',position:point(v),yaw:finite(object.rotation?.y)?object.rotation.y:0,
    contactOffsetY:0,massKg:positive(hero.massKg)||positive(object.userData?.massKg),
    ...(width?{footprint:{width,length:width}}:{}),enabled:!occupiedSeat&&!transition},object);
  }
  for(const record of records){
   const car=record?.car,state=record?.state||{},node=car?.object;if(!node)continue;
   const profile={...car.profile,...state.vehicleProfile};node.getWorldPosition(v);
   const position=point(v),contacts=[];
   for(const wheel of car.wheels||[]){
    const pivot=wheel.pivot;if(!pivot||pivot.userData?.detached)continue;
    pivot.getWorldPosition(v);
    const radius=positive(wheel.rollingRadius)||positive(profile.wheelRadius);
    if(radius){
     // Tyre circle is authored in local YZ. Its vertical support extent uses
     // the actual transformed axes, including slope, steering, roll and scale.
     const e=pivot.matrixWorld.elements;v.y-=radius*Math.hypot(e[5],e[9]);
     contacts.push({...point(v),front:typeof wheel.front==='boolean'?wheel.front:(wheel.restPosition?.z??pivot.position.z)>0});
    }
   }
   // Authored wheel centres are local coordinates, not yaw-only world offsets.
   if(!car.wheels?.length&&profile.wheelPositions){
    for(const p of Object.values(profile.wheelPositions))if(finite(p.x)&&finite(p.y)&&finite(p.z)&&positive(profile.wheelRadius)){
     v.set(p.x,p.y,p.z);node.localToWorld(v);const e=node.matrixWorld.elements;
     v.y-=profile.wheelRadius*Math.hypot(e[5],e[9]);contacts.push({...point(v),front:p.z>0});
    }
   }
   const width=positive(profile.width)||positive(profile.halfWidth*2),length=positive(profile.length)||positive(profile.halfLength*2);
   add({id:'vehicle:'+String(record.id??node.uuid),kind:'vehicle',position,yaw:finite(state.yaw)?state.yaw:node.rotation.y,
    massKg:positive(profile.massKg)||positive(node.userData?.massKg),...(width&&length?{footprint:{width,length}}:{}),
    ...(contacts.length?{contactPoints:contacts}:{}),enabled:car.wheels?.length?contacts.length>0:true},node);
  }
  for(const id of previous.keys())if(!seen.has(id))previous.delete(id);
  return {hero:inputs.find(input=>input.kind==='hero')||null,vehicles:inputs.filter(input=>input.kind==='vehicle')};
 }
 return {sample,reset:()=>previous.clear()};
}
