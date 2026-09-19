const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));

// A moving car is treated as a swept capsule. Extending the centre path by
// the body half-length prevents the bonnet from entering a pedestrian before
// the source centre reaches them, while the width remains model-specific.
export function sweptVehiclePedestrianContact(from,to,actor,{halfLength=.72,halfWidth=.4,pedestrianRadius=.2}={}){
 if(!from||!to||!actor)return null;
 const values=[from.r,from.c,to.r,to.c,actor.r,actor.c,halfLength,halfWidth,pedestrianRadius];
 if(!values.every(Number.isFinite)||halfLength<=0||halfWidth<=0||pedestrianRadius<0)return null;
 let dr=to.r-from.r,dc=to.c-from.c,length=Math.hypot(dr,dc);
 if(length<1e-7){const angle=Number.isFinite(to.angle)?to.angle:Number.isFinite(from.angle)?from.angle:0;dr=Math.sin(angle);dc=Math.cos(angle);length=1;}
 const nr=dr/length,nc=dc/length,startR=from.r-nr*halfLength,startC=from.c-nc*halfLength,endR=to.r+nr*halfLength,endC=to.c+nc*halfLength,
   segR=endR-startR,segC=endC-startC,seg2=segR*segR+segC*segC,
   t=clamp(((actor.r-startR)*segR+(actor.c-startC)*segC)/Math.max(1e-9,seg2),0,1),
   hitR=startR+segR*t,hitC=startC+segC*t,offR=actor.r-hitR,offC=actor.c-hitC,distance=Math.hypot(offR,offC),radius=halfWidth+pedestrianRadius;
 if(distance>radius)return null;
 const sideR=-nc,sideC=nr,sideSign=Math.sign(offR*sideR+offC*sideC)||1,
   blend=distance/radius,dirR=nr*(1-blend*.28)+sideR*sideSign*blend*.28,dirC=nc*(1-blend*.28)+sideC*sideSign*blend*.28,dirLength=Math.hypot(dirR,dirC)||1;
 return{t,distance,penetration:radius-distance,r:hitR,c:hitC,dirR:dirR/dirLength,dirC:dirC/dirLength};
}

export function vehiclePedestrianImpact(speedMps){
 if(!Number.isFinite(speedMps)||speedMps<.45)return null;
 const speed=clamp(speedMps,0,42),severity=clamp((speed-.45)/17.55,0,1);
 const falling=speed>=1.65,damage=speed<1.65?0:Math.round(clamp((speed-1.45)*3.6,1,105));
 return{
  speedMps:speed,severity,damage,falling,
  fallMs:falling?Math.round(620+Math.min(1600,speed*70)):0,
  launchMps:falling?clamp(speed*.72,2.2,14.5):clamp(speed*.32,.3,1.2),
  liftMps:falling?clamp(.35+(speed-1.65)*.22,.35,4.2):0,
  carSpeedRetention:clamp(.94-severity*.3,.58,.94),
  tier:speed>=12?'severe':speed>=5.5?'hard':speed>=1.65?'fall':'shove'
 };
}

export function createVehiclePedestrianContact({worldScale=4.1,cooldownMs=900,maxSweepCells=3}={}){
 const poses=new WeakMap(),hits=new WeakMap();let scans=0,contacts=0,skippedTeleports=0;
 function step({vehicles=[],actors=[],dt,now=0,vehiclePose,actorPose,canHit=()=>true,onImpact=()=>{}}={}){
  if(!Number.isFinite(dt)||dt<=0||!Number.isFinite(now)||typeof vehiclePose!=='function'||typeof actorPose!=='function')return 0;
  let frameContacts=0;
  for(const vehicle of vehicles){
   if(!vehicle||typeof vehicle!=='object')continue;
   const pose=vehiclePose(vehicle),previous=poses.get(vehicle);if(!pose||![pose.r,pose.c].every(Number.isFinite)){poses.delete(vehicle);continue;}
   poses.set(vehicle,{r:pose.r,c:pose.c,angle:pose.angle});if(!previous)continue;
   const travel=Math.hypot(pose.r-previous.r,pose.c-previous.c);if(travel>maxSweepCells){skippedTeleports++;continue;}
   const speedMps=travel*worldScale/dt,impact=vehiclePedestrianImpact(speedMps);if(!impact)continue;
   let vehicleHits=hits.get(vehicle);if(!vehicleHits){vehicleHits=new WeakMap();hits.set(vehicle,vehicleHits);}
   for(const actor of actors){
    if(!actor||typeof actor!=='object'||!canHit(vehicle,actor,pose))continue;
    const point=actorPose(actor);if(!point||![point.r,point.c].every(Number.isFinite))continue;
    if(Math.abs(point.r-pose.r)>travel+(pose.halfLength||.72)+1||Math.abs(point.c-pose.c)>travel+(pose.halfLength||.72)+1)continue;
    scans++;
    const contact=sweptVehiclePedestrianContact(previous,pose,point,pose);if(!contact||now-(vehicleHits.get(actor)||-Infinity)<cooldownMs)continue;
    vehicleHits.set(actor,now);contacts++;frameContacts++;onImpact({vehicle,actor,pose,point,contact,impact,now});
   }
  }
  return frameContacts;
 }
 return{step,reset(vehicle){if(vehicle){poses.delete(vehicle);hits.delete(vehicle);}else{scans=contacts=skippedTeleports=0;}},stats:()=>({scans,contacts,skippedTeleports})};
}
