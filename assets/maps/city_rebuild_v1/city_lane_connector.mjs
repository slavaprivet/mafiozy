const EPS=1e-7,ANGLE_EPS=1e-6,MAX_POINTS=4096;
// Only immutable curve geometry is cached. Road and complete-hull predicates
// are always re-evaluated, so a later collision revision cannot reuse clearance.
const geometryCache=new Map(),MAX_GEOMETRY_CACHE=128;
const angle=n=>Math.atan2(Math.sin(n),Math.cos(n));
const finite=p=>p&&[p.x,p.z,p.yaw].every(Number.isFinite);
const distance=(a,b)=>Math.hypot(b.x-a.x,b.z-a.z);
const evaluate=(coeff,t)=>{let n=0;for(let i=coeff.length-1;i>=0;i--)n=n*t+coeff[i];return n;};
const derivative=coeff=>coeff.slice(1).map((n,i)=>n*(i+1));
function multiply(a,b){const result=Array(a.length+b.length-1).fill(0);for(let i=0;i<a.length;i++)for(let j=0;j<b.length;j++)result[i+j]+=a[i]*b[j];return result;}
function combine(a,b,scale=1){return Array.from({length:Math.max(a.length,b.length)},(_,i)=>(a[i]||0)+scale*(b[i]||0));}

// Isolate every real polynomial root on [0,1] by its derivative's extrema.
// Each resulting interval is monotone; bisection also handles repeated roots
// at those extrema. Degree is at most five for cubic curvature extrema.
function roots01(source){
 const scale=Math.max(...source.map(Math.abs));if(scale<1e-20)return [];
 const coeff=source.map(n=>n/scale);while(coeff.length>1&&Math.abs(coeff.at(-1))<1e-13)coeff.pop();
 if(coeff.length===1)return [];
 if(coeff.length===2){const root=-coeff[0]/coeff[1];return root>=0&&root<=1?[root]:[];}
 const boundaries=[0,...roots01(derivative(coeff)).filter(t=>t>1e-12&&t<1-1e-12),1].sort((a,b)=>a-b),roots=[];
 const append=t=>{if(!roots.some(r=>Math.abs(r-t)<1e-9))roots.push(t);};
 for(const t of boundaries)if(Math.abs(evaluate(coeff,t))<1e-11)append(t);
 for(let i=1;i<boundaries.length;i++){
  let low=boundaries[i-1],high=boundaries[i],a=evaluate(coeff,low),b=evaluate(coeff,high);if(a*b>=0)continue;
  for(let n=0;n<48;n++){const middle=(low+high)/2,value=evaluate(coeff,middle);if(a*value<=0){high=middle;b=value;}else{low=middle;a=value;}}
  append((low+high)/2);
 }
 return roots.sort((a,b)=>a-b);
}
function curveFor(from,to,a,b){
 const p0={x:from.x,z:from.z},p1={x:from.x+Math.sin(from.yaw)*a,z:from.z+Math.cos(from.yaw)*a},p2={x:to.x-Math.sin(to.yaw)*b,z:to.z-Math.cos(to.yaw)*b},p3={x:to.x,z:to.z};
 const coefficients=axis=>[3*(p1[axis]-p0[axis]),6*(p2[axis]-2*p1[axis]+p0[axis]),3*(p3[axis]-3*p2[axis]+3*p1[axis]-p0[axis])];
 return {p:[p0,p1,p2,p3],dx:coefficients('x'),dz:coefficients('z')};
}
function curvatureBounds(curve,minRadius=0){
 const {dx,dz}=curve,ddx=derivative(dx),ddz=derivative(dz);
 // Endpoint curvature is a necessary cheap bound. Sideways/short candidates
 // usually fail here, before polynomial construction and root isolation.
 if(minRadius>0)for(const t of [0,1]){const vx=evaluate(dx,t),vz=evaluate(dz,t),speed2=vx*vx+vz*vz,k=Math.abs(vx*evaluate(ddz,t)-vz*evaluate(ddx,t))/Math.pow(speed2,1.5);if(!Number.isFinite(k)||k>1/(minRadius*(1+1e-7)))return null;}
 const speed2=combine(multiply(dx,dx),multiply(dz,dz)),cross=combine(multiply(dx,ddz),multiply(dz,ddx),-1);
 // A cusp has no physical heading, even if the sampled positions look clear.
 const speedRoots=roots01(derivative(speed2)),minSpeed2=Math.min(...[0,1,...speedRoots].map(t=>evaluate(speed2,t)));if(minSpeed2<1e-8)return null;
 const stationary=combine(multiply(derivative(cross),speed2).map(n=>2*n),multiply(cross,derivative(speed2)),-3),times=[0,1,...roots01(stationary)];
 let maximum=0;for(const t of times){const speed=evaluate(speed2,t);if(speed<=0)return null;maximum=Math.max(maximum,Math.abs(evaluate(cross,t))/Math.pow(speed,1.5));}
 return {minRadiusM:maximum>1e-12?1/maximum:Infinity,minSpeed2};
}
const midpoint=(a,b)=>({x:(a.x+b.x)/2,z:(a.z+b.z)/2});
function sampleCurve(curve,step){
 const points=[],{dx,dz}=curve;let failed=false,lengthM=0;
 const append=(p,t)=>{if(points.length>=MAX_POINTS){failed=true;return;}const next={x:p.x,z:p.z,yaw:Math.atan2(evaluate(dx,t),evaluate(dz,t))};if(points.length)lengthM+=distance(points.at(-1),next);points.push(next);};
 append(curve.p[0],0);
 const split=(p,t0,t1,depth)=>{
  if(failed)return;const hullLength=distance(p[0],p[1])+distance(p[1],p[2])+distance(p[2],p[3]);
  if(hullLength<=step){append(p[3],t1);return;}if(depth>=16){failed=true;return;}
  const a=midpoint(p[0],p[1]),b=midpoint(p[1],p[2]),c=midpoint(p[2],p[3]),d=midpoint(a,b),e=midpoint(b,c),f=midpoint(d,e),tm=(t0+t1)/2;
  split([p[0],a,d,f],t0,tm,depth+1);split([f,e,c,p[3]],tm,t1,depth+1);
 };
 split(curve.p,0,1,0);return failed?null:{points,lengthM};
}

/** A bounded forward-only cubic connection between two selected lane poses.
 * The caller chooses upstream/downstream anchors; this is not a pathfinder.
 * x/z are metres and yaw=atan2(dx,dz). Every heading is the curve derivative.
 * The complete caller-supplied hull predicate is mandatory; blocked curves
 * return null without relaxing radius, heading, road or collision constraints.
 */
export function createLaneConnector({from,to,poseAllowed,isRoad,minRadius=4.3,sampleStep=.15,maxDistance=36}={}){
 if(!finite(from)||!finite(to)||typeof poseAllowed!=='function'||typeof isRoad!=='function'||!Number.isFinite(minRadius)||minRadius<=0||!Number.isFinite(sampleStep)||sampleStep<=0||!Number.isFinite(maxDistance)||maxDistance<=0)return null;
 const gap=distance(from,to),deltaYaw=Math.abs(angle(to.yaw-from.yaw));if(gap>maxDistance)return null;
 const fits=p=>isRoad(p.x,p.z)&&poseAllowed(p.x,p.z,p.yaw);
 if(!fits(from)||!fits(to))return null;
 if(gap<=EPS){if(deltaYaw>ANGLE_EPS)return null;return{points:[{x:from.x,z:from.z,yaw:from.yaw}],lengthM:0,minRadiusM:Infinity,length:0,distanceM:0};}
 // A same-heading pose behind the car cannot be reached by a simple forward
 // lane change; prevent an attempted loop or unmarked reverse shortcut.
 const chordX=(to.x-from.x)/gap,chordZ=(to.z-from.z)/gap;
 if(deltaYaw<.05&&(chordX*Math.sin(from.yaw)+chordZ*Math.cos(from.yaw)<=EPS||chordX*Math.sin(to.yaw)+chordZ*Math.cos(to.yaw)<=EPS))return null;
 if(deltaYaw<ANGLE_EPS&&chordX*Math.sin(from.yaw)+chordZ*Math.cos(from.yaw)>1-1e-12){
  const count=Math.ceil(gap/Math.min(sampleStep,.15));if(count>=MAX_POINTS)return null;const points=[];
  for(let i=0;i<=count;i++){const t=i/count,p={x:from.x+(to.x-from.x)*t,z:from.z+(to.z-from.z)*t,yaw:from.yaw+angle(to.yaw-from.yaw)*t};if(!fits(p))return null;points.push(p);}
  return{points,lengthM:gap,minRadiusM:Infinity,length:gap,distanceM:gap};
 }
 const key=[from.x,from.z,from.yaw,to.x,to.z,to.yaw,minRadius].join('|');let candidates=geometryCache.get(key);
 if(candidates){geometryCache.delete(key);geometryCache.set(key,candidates);}else{
  candidates=[];
  for(const a of [.28,.4,.55,.75,1])for(const b of [.28,.4,.55,.75,1]){
   const curve=curveFor(from,to,gap*a,gap*b),bounds=curvatureBounds(curve,minRadius);if(!bounds||bounds.minRadiusM<minRadius*(1+1e-7))continue;
   candidates.push({curve,bounds,estimatedLength:curve.p.slice(1).reduce((sum,p,i)=>sum+distance(curve.p[i],p),0)});
  }
  candidates.sort((a,b)=>a.estimatedLength-b.estimatedLength);geometryCache.set(key,candidates);if(geometryCache.size>MAX_GEOMETRY_CACHE)geometryCache.delete(geometryCache.keys().next().value);
 }
 // A Bezier arc never exceeds its control polygon length. Together with the
 // global curvature bound this also limits heading change to less than 1°.
 const step=Math.min(sampleStep,.15,minRadius*Math.PI/180*.98);
 for(const candidate of candidates){
  const sampled=sampleCurve(candidate.curve,step);if(!sampled)continue;
  sampled.points[0]={x:from.x,z:from.z,yaw:from.yaw};sampled.points[sampled.points.length-1]={x:to.x,z:to.z,yaw:to.yaw};
  let valid=true;for(let i=0;i<sampled.points.length;i++){
   const p=sampled.points[i];if(!fits(p)){valid=false;break;}if(i){const previous=sampled.points[i-1],length=distance(previous,p),dyaw=angle(p.yaw-previous.yaw),yaw=previous.yaw+dyaw/2,alignment=((p.x-previous.x)*Math.sin(yaw)+(p.z-previous.z)*Math.cos(yaw))/(length||1);
    if(length<EPS||alignment<.999||Math.abs(dyaw)>Math.PI/180+1e-8){valid=false;break;}
   }
  }
  if(valid)return{...sampled,minRadiusM:candidate.bounds.minRadiusM,length:sampled.lengthM,distanceM:sampled.lengthM};
 }
 return null;
}
export const makeLaneConnector=createLaneConnector;
