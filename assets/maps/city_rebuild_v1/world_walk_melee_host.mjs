import {createNpcMeleeContact} from './npc_melee_contact.mjs';
import {resolveNpcContactAnchor} from './npc_contact_anchor.mjs';
export function createWorldWalkMeleeHost({THREE,bridge,getHero,getActors,obstacles,now=()=>performance.now()}){
 const contact=createNpcMeleeContact({THREE,getActors,obstacles}),previous=new Map(),pending=new Map(),segments=[{previous:null,current:null,radius:.1},{previous:null,current:null,radius:.1}],singleSegment=[],activeSamples=[];singleSegment.push(segments[0]);let activeId=null,resolved=false,disposed=false;
 const rootBefore=new THREE.Vector3(),rootNow=new THREE.Vector3(),sampleRoot=new THREE.Vector3(),contactOrigin=new THREE.Vector3(),rotationBefore=new THREE.Quaternion(),rotationNow=new THREE.Quaternion(),sampleRotation=new THREE.Quaternion();
 const sampledAction={type:'punch',side:1,progress:0};let previousAge=0,poseRevision=0;
 function resetPrevious(){for(const sample of previous.values())sample.seen=false;activeSamples.length=0;}
 function sampleLimb(context,name,index,radius){
  let sample=previous.get(name);if(!sample){sample={name,last:new THREE.Vector3(),current:new THREE.Vector3(),seen:false};previous.set(name,sample);}
  context.bones[name].getWorldPosition(sample.current);if(!sample.seen){sample.last.copy(sample.current);sample.seen=true;}
  const segment=segments[index];segment.previous=sample.last;segment.current=sample.current;segment.radius=radius;activeSamples[index]=sample;
 }
 function commitSamples(count){for(let i=0;i<count;i++)activeSamples[i].last.copy(activeSamples[i].current);}
 function update(snapshot){
  if(disposed)return;
  const start=snapshot?.start,hero=getHero();if(!start||!hero){if(activeId!==null){resetPrevious();activeId=null;}return;}
  if(start.id!==activeId){activeId=start.id;resolved=false;resetPrevious();previousAge=0;rootBefore.copy(hero.object.position||rootBefore);rotationBefore.copy(hero.object.quaternion||rotationBefore);}
  const context=hero.artistContext();hero.object.updateMatrixWorld(true);
  const side=start.side<0?'l':'r',legs=start.type==='kick'||start.type==='dropkick',radius=legs?.14:.10;
  let count=1;
  if(start.type==='dropkick'){sampleLimb(context,'foot_l',0,radius);sampleLimb(context,'foot_r',1,radius);count=2;}
  else sampleLimb(context,(legs?'foot_':'hand_')+side,0,radius);
  if(resolved){commitSamples(count);return;}const age=now()-start.sourceStartAt,[begin,end]=start.contactWindow;
  rootNow.copy(hero.object.position||rootBefore);rotationNow.copy(hero.object.quaternion||rotationBefore);
  let hit=null,contactAge=age;
  if(Number.isFinite(begin)&&Number.isFinite(end)&&age>=begin&&age<=end+250){
   if(typeof hero.sampleMeleeContactPose==='function'){
    // A slow frame can cross the whole strike window. Sample its authored
    // curved limb path, clipped to that window, rather than only the final
    // recovery pose or a chord through a spinning backfist. Never extend the
    // damaging pose beyond the accepted window or catch up an arbitrary stall.
    const from=Math.max(begin,previousAge),to=Math.min(end,age),duration=start.duration||({punch:.34,kick:.62,heavy:.50,backfist:.50,dropkick:1.25}[start.type]);
    if(to>=from&&duration>0){
     const steps=Math.min(12,Math.ceil((to-from)/32)),revision=++poseRevision;
     sampledAction.type=start.type;sampledAction.side=start.side;
     for(let i=0;i<=steps;i++){
      const sampleAge=steps?from+(to-from)*i/steps:from,t=age>previousAge?Math.max(0,Math.min(1,(sampleAge-previousAge)/(age-previousAge))):1;
      sampleRoot.lerpVectors(rootBefore,rootNow,t);sampleRotation.slerpQuaternions(rotationBefore,rotationNow,t);sampledAction.progress=sampleAge/(duration*1000);
      hero.sampleMeleeContactPose(sampledAction,sampleRoot,sampleRotation,activeSamples);
      if(i===0)commitSamples(count);
      contactOrigin.copy(sampleRoot);contactOrigin.y+=1.1;
      hit=contact({contacts:count===1?singleSegment:segments,attackType:start.type,poseRevision:revision,origin:contactOrigin});commitSamples(count);if(hit){contactAge=sampleAge;break;}
     }
    }
   }else if(age<=end)hit=contact({contacts:count===1?singleSegment:segments,attackType:start.type});
  }
  previousAge=age;rootBefore.copy(rootNow);rotationBefore.copy(rotationNow);
  commitSamples(count);
  if(!Number.isFinite(begin)||age<begin)return;
  if(!hit&&age<end)return;
  const key=`walk-melee:${start.seq}`;
  if(hit?.anchor)pending.set(key,{npcId:hit.npcId,anchor:hit.anchor,at:now()});
  const receipt=bridge.resolveWalkMelee({seq:start.seq,contact:hit,contactAge});
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
