// Bus arrays contain pedestrians waiting for, approaching, or leaving a bus.
// Array offsets cannot identify them: splice moves a different person into that slot.
const _threeBusPersonIds=new WeakMap();
const _threeBusPersonSeq={bus_rider:0,bus_waiter:0};
function _threeBusPersonView(person,kind){
  if(!person||!Object.prototype.hasOwnProperty.call(_threeBusPersonSeq,kind))return null;
  let id=_threeBusPersonIds.get(person);
  if(!id){id=`${kind}_${_threeBusPersonSeq[kind]++}`;_threeBusPersonIds.set(person,id);}
  const moving=!person.dead&&(kind==='bus_waiter'?!!person.leaving:Math.hypot(person.tgtR-person.r,person.tgtC-person.c)>.1)&&person._busFootMoving!==false;
  return {...person,id,_actionRef:person,role:'bus_passenger',name:'Пассажир',walking:moving,moving};
}
