// Short presentation overlay. The right hand, weapon mount and locomotion stay
// source-owned; the left support hand returns to the freshly solved weapon grip.
export function createHeroFollowGesture({THREE}){
 const palm=new THREE.Vector3(),target=new THREE.Vector3(),handQ=new THREE.Quaternion(),delta=new THREE.Quaternion(),euler=new THREE.Euler();
 let started=-Infinity,weaponId=null,owner=null,duration=.6,pending=false;
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
 function cancel(){started=-Infinity;owner=null;weaponId=null;pending=false;}
 function trigger({hero,weapon,now,allowed=true}={}){
  if(!allowed||!hero?.artistContext||!Number.isFinite(now))return false;
  // A distinct V press during the motion schedules one full repeat, without
  // snapping the arm back to its starting pose or accumulating a long backlog.
  if(hero===owner&&(weapon?.id||'none')===weaponId&&now>=started&&now-started<duration){pending=true;return true;}
  owner=hero;weaponId=weapon?.id||'none';duration=weapon?.twoHanded===true?.56:.66;started=now;pending=false;return true;
 }
 function apply({hero,weapon,now,allowed=true}={}){
  if(started===-Infinity)return false;
  let age=now-started;
  if(!allowed||hero!==owner||(weapon?.id||'none')!==weaponId||!Number.isFinite(age)||age<0){cancel();return false;}
  if(age>=duration){
   if(!pending||age>duration+.25){cancel();return false;}
   pending=false;started=now;age=0;
  }
  const t=age/duration,w=smooth(t/.24)*(1-smooth((t-.64)/.36));if(w<=0)return false;
  const c=hero.artistContext(),sweep=smooth((t-.25)/.36);
  // Lift beside the head, make one inward beckoning sweep, return. Long weapons
  // keep the complete right-hand grip while briefly releasing the support hand.
  if(!c.reachPalm||!c.bones.socket_hand_l||!c.bones.hand_l){cancel();return false;}
  c.bones.socket_hand_l.getWorldPosition(palm);c.bones.hand_l.getWorldQuaternion(handQ);
  const scale=(hero.height||1.9)/1.9;
  target.set((-.50+sweep*.11)*scale,(1.46+sweep*.08)*scale,(.40-sweep*.28)*scale);hero.object.localToWorld(target);
  palm.lerp(target,w);delta.setFromEuler(euler.set(-.32*sweep*w,.30*sweep*w,.12*w));handQ.multiply(delta);
  c.reachPalm('l',palm,handQ);
  return true;
 }
 return {trigger,apply,cancel,get active(){return started!==-Infinity;},get queued(){return pending;},get duration(){return duration;}};
}
