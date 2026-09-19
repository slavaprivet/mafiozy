// Exact planar overlap between the translated axis-aligned NPC square and an
// authored (possibly concave) polygon. Scratch hull points are reused per query.
const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
const pointInside=(p,polygon)=>{let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
 const a=polygon[i],b=polygon[j];if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])inside=!inside;
}return inside;};
function edgesTouch(a,b,c,d){
 if(Math.max(a[0],b[0])<Math.min(c[0],d[0])-1e-10||Math.max(c[0],d[0])<Math.min(a[0],b[0])-1e-10||Math.max(a[1],b[1])<Math.min(c[1],d[1])-1e-10||Math.max(c[1],d[1])<Math.min(a[1],b[1])-1e-10)return false;
 return cross(a,b,c)*cross(a,b,d)<=1e-18&&cross(c,d,a)*cross(c,d,b)<=1e-18;
}
export function createNpcSweptFootprint(){
 const points=Array.from({length:8},()=>[0,0]),hull=[];
 let minC=0,minR=0,maxC=0,maxR=0;
 function set(from,to,radius=.18){
  for(let i=0;i<8;i++){const p=i<4?from:to;points[i][0]=p.c+((i&1)?radius:-radius);points[i][1]=p.r+((i&2)?radius:-radius);}
  points.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
  let k=0;for(let i=0;i<8;i++){while(k>=2&&cross(hull[k-2],hull[k-1],points[i])<=0)k--;hull[k++]=points[i];}
  const lower=k+1;for(let i=6;i>=0;i--){while(k>=lower&&cross(hull[k-2],hull[k-1],points[i])<=0)k--;hull[k++]=points[i];}
  hull.length=Math.max(1,k-1);minC=Math.min(from.c,to.c)-radius;maxC=Math.max(from.c,to.c)+radius;minR=Math.min(from.r,to.r)-radius;maxR=Math.max(from.r,to.r)+radius;
 }
 function overlaps(polygon,testPoint=null){
  if(!polygon?.length)return false;
  let pc0=Infinity,pc1=-Infinity,pr0=Infinity,pr1=-Infinity;
  for(const p of polygon){pc0=Math.min(pc0,p[0]);pc1=Math.max(pc1,p[0]);pr0=Math.min(pr0,p[1]);pr1=Math.max(pr1,p[1]);}
  if(pc1<minC||pc0>maxC||pr1<minR||pr0>maxR)return false;
  for(const p of polygon)if(pointInside(p,hull)&&(!testPoint||testPoint(p[0],p[1])))return true;
  for(const p of hull)if(pointInside(p,polygon)&&(!testPoint||testPoint(p[0],p[1])))return true;
  for(let i=0;i<hull.length;i++)for(let j=0;j<polygon.length;j++){
   const a=hull[i],b=hull[(i+1)%hull.length],c=polygon[j],d=polygon[(j+1)%polygon.length];
   if(!edgesTouch(a,b,c,d))continue;if(!testPoint)return true;
   const dx=b[0]-a[0],dy=b[1]-a[1],ex=d[0]-c[0],ey=d[1]-c[1],den=dx*ey-dy*ex;
   if(Math.abs(den)>1e-15){const t=((c[0]-a[0])*ey-(c[1]-a[1])*ex)/den;if(testPoint(a[0]+t*dx,a[1]+t*dy))return true;}
   else {const x=(Math.max(Math.min(a[0],b[0]),Math.min(c[0],d[0]))+Math.min(Math.max(a[0],b[0]),Math.max(c[0],d[0])))/2,y=(Math.max(Math.min(a[1],b[1]),Math.min(c[1],d[1]))+Math.min(Math.max(a[1],b[1]),Math.max(c[1],d[1])))/2;if(testPoint(x,y))return true;}
  }
  return false;
 }
 return {set,overlaps,get minC(){return minC},get minR(){return minR},get maxC(){return maxC},get maxR(){return maxR}};
}
