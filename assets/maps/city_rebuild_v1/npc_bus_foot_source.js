// Bus passengers on foot obey the same swept body gate as other outdoor NPCs.
// An obstructed approach waits in place; the bus simulation owns its own route.
function _busFootStep(person,targetR,targetC,speed,dt){
  person._busFootMoving=false;
  const dr=targetR-person.r,dc=targetC-person.c,d=Math.hypot(dr,dc);
  const step=Math.min(d,_npcPacedSpeed(speed)*Math.max(0,Math.min(.1,Number(dt)||0)));
  if(!(step>0))return false;
  const r=person.r+dr/d*step,c=person.c+dc/d*step;
  if(!_npcPathPassable(person.r,person.c,r,c,npcPassableForSnitch))return false;
  person.r=r;person.c=c;person.ang=Math.atan2(dr,dc);person._busFootMoving=true;
  return true;
}
