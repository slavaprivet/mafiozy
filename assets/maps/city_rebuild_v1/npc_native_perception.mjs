// Source AI owns attention/FOV and cadence. This adapter answers only whether
// the current native city obstructs a segment; no scene traversal or GPU work.
const EPS=1e-8;
function inside(x,z,poly){
 let yes=false;
 for(let i=0,j=poly.length-1;i<poly.length;j=i++){
  const a=poly[j],b=poly[i];
  if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])yes=!yes;
 }
 return yes;
}
export function perceptionBodyBlocks(body,from,to){
 const poly=body?.polygonCR;if(!poly||poly.length<3)return false;
 const dx=to.c-from.c,dz=to.r-from.r,dy=to.y-from.y;
 let lo=EPS,hi=1-EPS;
 const min=body.minYM??-Infinity,max=body.maxYM??Infinity;
 if(Math.abs(dy)<EPS){if(from.y<min||from.y>max)return false;}
 else {const a=(min-from.y)/dy,b=(max-from.y)/dy;lo=Math.max(lo,Math.min(a,b));hi=Math.min(hi,Math.max(a,b));if(lo>hi)return false;}
 if(inside(from.c+dx*lo,from.r+dz*lo,poly)||inside(from.c+dx*hi,from.r+dz*hi,poly))return true;
 for(let i=0,j=poly.length-1;i<poly.length;j=i++){
  const a=poly[j],b=poly[i],ex=b[0]-a[0],ez=b[1]-a[1],qx=a[0]-from.c,qz=a[1]-from.r,det=dx*ez-dz*ex;
  if(Math.abs(det)<EPS){
   if(Math.abs(qx*dz-qz*dx)>EPS)continue;
   const len=dx*dx+dz*dz;if(len<EPS)continue;
   const t0=(qx*dx+qz*dz)/len,t1=((b[0]-from.c)*dx+(b[1]-from.r)*dz)/len;
   if(Math.max(lo,Math.min(t0,t1))<=Math.min(hi,Math.max(t0,t1)))return true;
  }else{
   const t=(qx*ez-qz*ex)/det,u=(qx*dz-qz*dx)/det;
   if(t>=lo&&t<=hi&&u>=-EPS&&u<=1+EPS)return true;
  }
 }
 return false;
}
export function createNpcNativePerception({worldScale=4.1,cellSize=4,bodiesAt=()=>[],groundHeight=()=>0,getVehicles=()=>[],ready=()=>true}={}){
 const seen=new Set(),cuts=[],from={},to={},counts={queries:0,bodies:0,blocked:0,terrain:0};
 let vehicleBodies=null;
 function vehicles(){
  if(vehicleBodies)return vehicleBodies;
  vehicleBodies=[];
  for(const entry of getVehicles()||[]){
   const car=entry.actor||entry.car||entry,object=car.object,profile=car.profile||object?.userData?.vehicleProfile;
   if(!object||object.visible===false||!profile)continue;
   const p=object.position,s=object.scale,w=profile.halfWidth*Math.abs(s.x),l=profile.halfLength*Math.abs(s.z),sin=Math.sin(object.rotation.y),cos=Math.cos(object.rotation.y);
   if(![p.x,p.y,p.z,w,l].every(Number.isFinite))continue;
   const polygonCR=[[-w,-l],[w,-l],[w,l],[-w,l]].map(([x,z])=>[(p.x+x*cos+z*sin)/worldScale,(p.z-x*sin+z*cos)/worldScale]);
   vehicleBodies.push({polygonCR,minYM:p.y+(profile.bounds?.min?.[1]??0)*s.y,maxYM:p.y+(profile.bounds?.max?.[1]??profile.height??1.6)*s.y});
  }
  return vehicleBodies;
 }
 function query({fromR,fromC,toR,toC,eyeHeight=1.45,targetHeight=1.1}={}){
  if(!ready())return null;
  if(![fromR,fromC,toR,toC,eyeHeight,targetHeight].every(Number.isFinite))return {blocked:true};
  counts.queries++;
  Object.assign(from,{r:fromR,c:fromC,y:groundHeight(fromC*worldScale,fromR*worldScale)+eyeHeight});
  Object.assign(to,{r:toR,c:toC,y:groundHeight(toC*worldScale,toR*worldScale)+targetHeight});
  if(!Number.isFinite(from.y)||!Number.isFinite(to.y))return {blocked:true};
  const dc=toC-fromC,dr=toR-fromR;
  // Visit every broadphase cell crossed by the segment, including arbitrarily
  // thin walls near cell corners. Fixed-distance ray samples can miss these.
  cuts.length=0;cuts.push(0,1);seen.clear();
  for(const [start,end]of [[fromC,toC],[fromR,toR]]){
   if(Math.abs(end-start)<EPS)continue;
   for(let edge=(Math.floor(Math.min(start,end)/cellSize)+1)*cellSize;edge<Math.max(start,end);edge+=cellSize)cuts.push((edge-start)/(end-start));
  }
  cuts.sort((a,b)=>a-b);
  for(let i=1;i<cuts.length;i++){
   const t=(cuts[i-1]+cuts[i])*.5;
   for(const body of bodiesAt(fromC+dc*t,fromR+dr*t)||[]){
    if(seen.has(body))continue;seen.add(body);counts.bodies++;
    if(perceptionBodyBlocks(body,from,to)){counts.blocked++;return {blocked:true};}
   }
  }
  for(const body of vehicles())if(perceptionBodyBlocks(body,from,to)){counts.blocked++;return {blocked:true};}
  const steps=Math.ceil(Math.hypot(dc,dr)*worldScale/2);
  for(let i=1;i<steps;i++){
   const t=i/steps,y=from.y+(to.y-from.y)*t;
   if(groundHeight((fromC+dc*t)*worldScale,(fromR+dr*t)*worldScale)>y+.05){counts.terrain++;counts.blocked++;return {blocked:true};}
  }
  return {blocked:false};
 }
 return {query,beginFrame(){vehicleBodies=null;},diagnostics:()=>({...counts})};
}
