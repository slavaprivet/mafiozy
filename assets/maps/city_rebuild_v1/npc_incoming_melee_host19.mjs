// Isolated prototype. Not imported by walk_preview or connected to world HP.
import {createNpcMeleeContact} from './npc_melee_contact.mjs';
const WINDOWS={punch:[35,190],kick:[180,340],heavy:[70,360],dropkick:[160,380]};
const DURATIONS={punch:.34,kick:.62,heavy:.5,dropkick:1.25};
export function createNpcIncomingMeleeHost19({THREE,getHero,getTickets,getNpcActor,resolve,obstacles=()=>[],now=()=>performance.now(),clock=()=>performance.now(),budgetMs=4,maxPoseSamples=16,maxAttackers=4}){
 const jobs=new Map(),hidden=[],records=[],actorRows=[],axis=new THREE.Vector3(0,1,0);let disposed=false,revision=0,cursor=0,diagnostic={};
 const contact=createNpcMeleeContact({THREE,getActors:()=>actorRows,obstacles});
 function physicalContact(hero,input){
  // Camera culling is not immunity. Synchronous temporary visibility is fully
  // restored before the renderer can draw; no visible-state mutation survives.
  hidden.length=0;for(let node=hero.object;node;node=node.parent)if(!node.visible){hidden.push(node);node.visible=true;}
  hero.object.traverse(node=>{if(!node.visible){hidden.push(node);node.visible=true;}});
  try{return contact(input);}finally{for(const node of hidden)node.visible=false;hidden.length=0;}
 }
 function finish(job,hit,contactAge,reason){
  if(job.done)return;job.done=true;
  resolve({npcId:job.npcId,generation:job.generation,seq:job.seq,type:job.type,contactAge,contact:hit,reason});
 }
 function admissible(ticket){
  const window=WINDOWS[ticket?.type];return ticket?.kind==='civilian'&&ticket.local===true&&ticket.alive!==false&&!ticket.armed&&Number.isInteger(ticket.seq)&&ticket.seq>0&&typeof ticket.npcId==='string'&&Number.isFinite(ticket.startAt)&&Number.isFinite(ticket.yaw)&&window&&ticket.contactWindow?.[0]===window[0]&&ticket.contactWindow?.[1]===window[1];
 }
 function update(){
  if(disposed)return;const started=clock(),sourceNow=now(),hero=getHero();diagnostic={poseSamples:0,contactQueries:0,completed:0,budgetDeferred:0,cpuMs:0,active:0};
  if(!hero?.object||hero.dead){jobs.clear();return;}
  const seen=new Set();records.length=0;actorRows.length=0;actorRows.push({id:'player',object:hero.object});
  for(const ticket of getTickets()){
   if(!admissible(ticket)||ticket.startAt>sourceNow)continue;const actor=getNpcActor(ticket.npcId);if(!actor?.walker?.sampleMeleeContactPose||actor.dead||actor.weapon)continue;
   const walker=actor.walker,object=walker.object;if(!object?.visible||object.position.distanceToSquared(hero.object.position)>9)continue;
   const key=JSON.stringify([ticket.npcId,ticket.generation??0,ticket.seq]);seen.add(key);let job=jobs.get(key);
   if(!job){const bone=(ticket.type==='kick'?'foot_':'hand_')+(ticket.side<0?'l':'r'),names=ticket.type==='dropkick'?['foot_l','foot_r']:[bone];
    job={...ticket,contactWindow:ticket.contactWindow.slice(),key,type:ticket.type,side:ticket.side<0?-1:1,done:false,nextAge:ticket.contactWindow[0],previousAge:0,fromRoot:object.position.clone(),toRoot:object.position.clone(),sampleRoot:new THREE.Vector3(),origin:new THREE.Vector3(),rotation:new THREE.Quaternion().setFromAxisAngle(axis,ticket.yaw),action:{type:ticket.type,side:ticket.side<0?-1:1,progress:0},samples:names.map(name=>({name,current:new THREE.Vector3(),last:new THREE.Vector3()})),segments:[],seeded:false};
    job.segments=job.samples.map(s=>({previous:s.last,current:s.current,radius:/kick/.test(job.type)?.14:.1}));jobs.set(key,job);
   }
   if(job.startAt!==ticket.startAt||job.type!==ticket.type||job.side!==(ticket.side<0?-1:1)||job.yaw!==ticket.yaw||job.walker&&job.walker!==walker){job.done=true;continue;}
   if(job.done)continue;const age=sourceNow-job.startAt;
   if(age>job.contactWindow[1]+250){finish(job,null,job.contactWindow[1],'expired');diagnostic.completed++;continue;}
   job.walker=walker;job.frameAge=age;job.toRoot.copy(object.position);records.push(job);
  }
  // Keep a cancelled token as a tombstone through its whole delivery lifetime.
  // Disappearing/reappearing or arming/unarming cannot replay the same attack.
  for(const [key,job]of jobs)if(!seen.has(key)){job.done=true;if(sourceNow>job.startAt+job.contactWindow[1]+250)jobs.delete(key);}
  // Deterministic round robin across active nearby civilians. At most one pose
  // per turn; one shared hero posed-vertex revision across the whole frame.
  const batchRevision=++revision;let idle=0,actorsServed=new Set();
  while(records.length&&diagnostic.poseSamples<maxPoseSamples&&idle<records.length){
   if(diagnostic.poseSamples&&clock()-started>=budgetMs){diagnostic.budgetDeferred++;break;}
   const job=records[cursor++%records.length];if(job.done||job.nextAge>job.frameAge||(!actorsServed.has(job.key)&&actorsServed.size>=maxAttackers)){idle++;continue;}
   idle=0;actorsServed.add(job.key);const sampleAge=job.nextAge,t=job.frameAge>job.previousAge?Math.max(0,Math.min(1,(sampleAge-job.previousAge)/(job.frameAge-job.previousAge))):1;
   job.sampleRoot.lerpVectors(job.fromRoot,job.toRoot,t);job.action.progress=sampleAge/(DURATIONS[job.type]*1000);job.walker.sampleMeleeContactPose(job.action,job.sampleRoot,job.rotation,job.samples);
   if(!job.seeded){for(const sample of job.samples)sample.last.copy(sample.current);job.seeded=true;}
   job.origin.copy(job.sampleRoot);job.origin.y+=1.1;diagnostic.poseSamples++;diagnostic.contactQueries++;
   const hit=physicalContact(hero,{contacts:job.segments,attackType:job.type,origin:job.origin,poseRevision:batchRevision});
   for(const sample of job.samples)sample.last.copy(sample.current);
   if(hit||sampleAge===job.contactWindow[1]){finish(job,hit,sampleAge,hit?'contact':'miss');diagnostic.completed++;}
   else job.nextAge=Math.min(job.contactWindow[1],sampleAge+32);
  }
  for(const job of records){job.previousAge=job.frameAge;job.fromRoot.copy(job.toRoot);}
  diagnostic.active=records.filter(job=>!job.done).length;diagnostic.cpuMs=clock()-started;
 }
 return {update,diagnostics:()=>({...diagnostic,jobs:jobs.size}),dispose(){disposed=true;jobs.clear();actorRows.length=records.length=hidden.length=0;}};
}
