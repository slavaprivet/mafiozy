import {createNpcMeleeContact} from './npc_melee_contact.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';
export function createWorldWalkMeleeHost({THREE,bridge,getHero,getActors,obstacles,now=()=>performance.now()}){
 const contact=createNpcMeleeContact({THREE,getActors,obstacles}),previous=new Map(),pending=new Map(),segments=[{previous:null,current:null,radius:.1},{previous:null,current:null,radius:.1}],singleSegment=[],activeSamples=[];singleSegment.push(segments[0]);let activeId=null,resolved=false,disposed=false;
 function resetPrevious(){for(const sample of previous.values())sample.seen=false;activeSamples.length=0;}
 function sampleLimb(context,name,index,radius){
  let sample=previous.get(name);if(!sample){sample={last:new THREE.Vector3(),current:new THREE.Vector3(),seen:false};previous.set(name,sample);}
  context.bones[name].getWorldPosition(sample.current);if(!sample.seen){sample.last.copy(sample.current);sample.seen=true;}
  const segment=segments[index];segment.previous=sample.last;segment.current=sample.current;segment.radius=radius;activeSamples[index]=sample;
 }
 function commitSamples(count){for(let i=0;i<count;i++)activeSamples[i].last.copy(activeSamples[i].current);}
 function update(snapshot){
  if(disposed)return;
  const start=snapshot?.start,hero=getHero();if(!start||!hero){if(activeId!==null){resetPrevious();activeId=null;}return;}
  if(start.id!==activeId){activeId=start.id;resolved=false;resetPrevious();}
  const context=hero.artistContext();hero.object.updateMatrixWorld(true);
  const side=start.side<0?'l':'r',legs=start.type==='kick'||start.type==='dropkick',radius=legs?.14:.10;
  let count=1;
  if(start.type==='dropkick'){sampleLimb(context,'foot_l',0,radius);sampleLimb(context,'foot_r',1,radius);count=2;}
  else sampleLimb(context,(legs?'foot_':'hand_')+side,0,radius);
  if(resolved){commitSamples(count);return;}const age=now()-start.sourceStartAt,[begin,end]=start.contactWindow;
  if(!Number.isFinite(begin)||age<begin){commitSamples(count);return;}
  const hit=age<=end?contact({contacts:count===1?singleSegment:segments,attackType:start.type}):null;
  commitSamples(count);
  if(!hit&&age<end)return;
  const key=`walk-melee:${start.seq}`;
  if(hit?.anchor)pending.set(key,{npcId:hit.npcId,anchor:hit.anchor,at:now()});
  const receipt=bridge.resolveWalkMelee({seq:start.seq,contact:hit});
  if(receipt?.reason!=='early')resolved=true;
  if(receipt?.accepted===false)pending.delete(key);
  for(const [id,item]of pending)if(now()-item.at>15000)pending.delete(id);
 }
 function resolveConfirmedReceipt(event){
  if(disposed)return null;
  const detail=event?.detail??event;if(detail?.confirmed!==true)return null;
  const item=pending.get(detail.shotId);if(!item||item.npcId!==detail.targetId||now()-item.at>15000)return null;
  pending.delete(detail.shotId);const record=getActors().find(x=>x.id===item.npcId);
  const surface=resolveNpcContactAnchor({THREE,record,anchor:item.anchor});
  return surface?{...detail,...surface,id:detail.shotId}:null;
 }
 return {update,resolveConfirmedReceipt,dispose(){disposed=true;pending.clear();previous.clear();activeSamples.length=0;}};
}
