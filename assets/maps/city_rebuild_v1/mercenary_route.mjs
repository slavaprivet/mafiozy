// Small, incremental local routes for hired crew orders and work approaches.
// The adapter supplies its authoritative swept body/native collision predicate.
export function createMercenaryRoutePlanner({canMove,groundHeight=()=>0,clock=()=>performance.now(),step=.65,maxNodes=2400,maxDistance=48}={}){
 const dirs=[[1,0],[-1,0],[0,1],[0,-1]],distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
 function start(from,to,{arrivalRadius=0}={}){
  const origin={...from},goal={...to},nodes=new Map(),heap=[],stats={expanded:0,checks:0,slices:0};
  const key=(x,z)=>x+','+z,point=(x,z)=>{const px=origin.x+x*step,pz=origin.z+z*step;return{x:px,y:groundHeight(px,pz),z:pz};};
  const heuristic=p=>Math.max(0,Math.abs(p.x-goal.x)+Math.abs(p.z-goal.z)-Math.SQRT2*Math.max(step*1.5,arrivalRadius)),less=(a,b)=>a.f<b.f||a.f===b.f&&a.h<b.h;
  const push=n=>{let i=heap.push(n)-1;while(i){const p=(i-1)>>1;if(!less(n,heap[p]))break;heap[i]=heap[p];i=p;}heap[i]=n;};
  const pop=()=>{const first=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let c=i*2+1;if(c+1<heap.length&&less(heap[c+1],heap[c]))c++;if(!less(heap[c],last))break;heap[i]=heap[c];i=c;}heap[i]=last;}return first;};
  const clear=(a,b)=>{stats.checks++;return canMove(a,b)===true;};
  const first={x:0,z:0,p:origin,g:0,h:heuristic(origin),f:heuristic(origin),parent:null};nodes.set('0,0',first);push(first);let result=null,done=false;
  function finish(node,exact=true){const endpoint=exact?goal:node.p,path=exact?[goal]:[];for(let n=node;n;n=n.parent)path.push(n.p);path.reverse();const compact=[path[0]];for(let i=1;i<path.length-1;i++){const a=compact.at(-1),b=path[i],c=path[i+1];if(Math.abs((b.x-a.x)*(c.z-b.z)-(b.z-a.z)*(c.x-b.x))>1e-7)compact.push(b);}compact.push(endpoint);done=true;result=compact.slice(1);}
  return {stats,get done(){return done;},get path(){return result;},advance({maxExpanded=12,budgetMs=1}={}){
   if(done)return result;stats.slices++;const deadline=clock()+budgetMs;let expanded=0;
   while(heap.length&&nodes.size<maxNodes&&expanded<maxExpanded&&(expanded===0||clock()<deadline)){
    const cur=pop();if(cur.closed)continue;cur.closed=true;expanded++;stats.expanded++;
    if(distance(cur.p,goal)<=arrivalRadius){finish(cur,false);return result;}
    if(distance(cur.p,goal)<=step*1.5&&clear(cur.p,goal)){finish(cur);return result;}
    for(const [dx,dz]of dirs){const x=cur.x+dx,z=cur.z+dz,k=key(x,z);if(nodes.has(k))continue;const p=point(x,z),g=cur.g+step,h=heuristic(p);if(g+distance(p,goal)>maxDistance||!clear(cur.p,p))continue;const n={x,z,p,g,h,f:g+h,parent:cur};nodes.set(k,n);push(n);}
   }
   if(!heap.length||nodes.size>=maxNodes){done=true;result=null;}return result;
  }};
 }
 return {start};
}
