// Round a kink in an authored offset lane inside its existing carriageway.
// Endpoints remain canonical; the curve cannot cross the road centreline.
export function createLaneCurve({from,to,path,direction,start,end,laneRoad,vehicleFits,minSide=1.3}){
 const distance=Math.hypot(to.x-from.x,to.z-from.z);if(distance<4)return null;
 const sample=(a,b,c,d,t)=>{const u=1-t;return{x:u*u*u*a.x+3*u*u*t*b.x+3*u*t*t*c.x+t*t*t*d.x,z:u*u*u*a.z+3*u*u*t*b.z+3*u*t*t*c.z+t*t*t*d.z}};
 const corridor=p=>{let best=null;for(const s of path.segments){const k=Math.max(0,Math.min(s.length,(p.x-s.a.x)*s.tx+(p.z-s.a.z)*s.tz)),progress=s.start+k;if(progress<Math.min(start,end)-.5||progress>Math.max(start,end)+.5)continue;const x=p.x-s.a.x-k*s.tx,z=p.z-s.a.z-k*s.tz,d=x*x+z*z;if(!best||d<best.distance)best={distance:d,side:(-s.tz*x+s.tx*z)*direction};}return best&&(path.lanes===1?Math.abs(best.side)<path.width/2-1.28:best.side>=minSide&&best.side<=path.width/2-1.28&&Math.abs(best.side-from.offset)<1.25);};
 for(const factor of [.32,.48,.65]){const c={x:from.x+from.tx*distance*factor,z:from.z+from.tz*distance*factor},d={x:to.x-to.tx*distance*factor,z:to.z-to.tz*distance*factor},n=Math.max(20,Math.ceil(distance*2/.3)),points=[];let clear=true;
  for(let k=0;k<=n;k++){const p=sample(from,c,d,to,k/n),a=sample(from,c,d,to,Math.max(0,(k-.1)/n)),b=sample(from,c,d,to,Math.min(1,(k+.1)/n)),yaw=Math.atan2(b.x-a.x,b.z-a.z);if(!corridor(p)||!laneRoad(p.x,p.z)||!vehicleFits(p.x,p.z,yaw)){clear=false;break;}points.push({...p,yaw});}
  if(clear)return points;
 }return null;
}
