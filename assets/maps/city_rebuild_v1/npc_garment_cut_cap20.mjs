// ISOLATED garment-cap geometry helper. No runtime import, material/actor writes
// or bitmap generation. Only edges proven newly cut by a triangle partition may
// be capped; original garment openings and ambiguous branches remain untouched.
const sub=(a,b)=>a.map((x,i)=>x-b[i]),dot=(a,b)=>a.reduce((n,x,i)=>n+x*b[i],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const unit=a=>{const length=Math.hypot(...a);return length>1e-14?a.map(x=>x/length):null;};
const edgeKey=(a,b)=>a<b?`${a}:${b}`:`${b}:${a}`;
const orient=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
function fittedPlane(points){
 const centre=[0,0,0];for(const p of points)for(let i=0;i<3;i++)centre[i]+=p[i]/points.length;
 const matrix=Array.from({length:3},()=>[0,0,0]),vectors=[[1,0,0],[0,1,0],[0,0,1]];
 for(const p of points){const d=sub(p,centre);for(let i=0;i<3;i++)for(let j=0;j<3;j++)matrix[i][j]+=d[i]*d[j];}
 // Symmetric 3x3 Jacobi eigensolver: least-variance axis is the fitted normal.
 for(let step=0;step<24;step++){
  let p=0,q=1;for(const [i,j]of [[0,2],[1,2]])if(Math.abs(matrix[i][j])>Math.abs(matrix[p][q])){p=i;q=j;}
  if(Math.abs(matrix[p][q])<1e-16)break;
  const angle=.5*Math.atan2(2*matrix[p][q],matrix[q][q]-matrix[p][p]),c=Math.cos(angle),s=Math.sin(angle),pp=matrix[p][p],qq=matrix[q][q],pq=matrix[p][q];
  matrix[p][p]=c*c*pp-2*s*c*pq+s*s*qq;matrix[q][q]=s*s*pp+2*s*c*pq+c*c*qq;matrix[p][q]=matrix[q][p]=0;
  for(let r=0;r<3;r++)if(r!==p&&r!==q){const a=matrix[r][p],b=matrix[r][q];matrix[r][p]=matrix[p][r]=c*a-s*b;matrix[r][q]=matrix[q][r]=s*a+c*b;}
  for(let r=0;r<3;r++){const a=vectors[r][p],b=vectors[r][q];vectors[r][p]=c*a-s*b;vectors[r][q]=s*a+c*b;}
 }
 const order=[0,1,2].sort((a,b)=>matrix[a][a]-matrix[b][b]),normal=unit(vectors.map(row=>row[order[0]])),u=unit(vectors.map(row=>row[order[2]]));if(!normal||!u)return null;
 const v=unit(cross(normal,u));if(!v)return null;
 const projected=points.map(p=>{const d=sub(p,centre);return [dot(d,u),dot(d,v)];});
 return {normal,u,v,centre,projected,maxDeviation:Math.max(...points.map(p=>Math.abs(dot(sub(p,centre),normal))))};
}
function triangulate(points){
 const plane=fittedPlane(points);if(!plane)return {reason:'degenerate-plane'};
 const p=plane.projected,n=p.length,min=[Infinity,Infinity],max=[-Infinity,-Infinity];for(const q of p)for(let k=0;k<2;k++){min[k]=Math.min(min[k],q[k]);max[k]=Math.max(max[k],q[k]);}
 const span=Math.max(max[0]-min[0],max[1]-min[1]),epsilon=Math.max(1e-15,span*span*1e-11);let area=0;
 for(let i=0;i<n;i++)area+=p[i][0]*p[(i+1)%n][1]-p[(i+1)%n][0]*p[i][1];if(Math.abs(area)<=epsilon)return {reason:'degenerate-projection'};
 const onSegment=(a,b,c)=>Math.abs(orient(a,b,c))<=epsilon&&c[0]>=Math.min(a[0],b[0])-1e-10&&c[0]<=Math.max(a[0],b[0])+1e-10&&c[1]>=Math.min(a[1],b[1])-1e-10&&c[1]<=Math.max(a[1],b[1])+1e-10;
 for(let i=0;i<n;i++)for(let j=i+1;j<n;j++){
  if(j===i+1||i===0&&j===n-1)continue;const a=p[i],b=p[(i+1)%n],c=p[j],d=p[(j+1)%n],abC=orient(a,b,c),abD=orient(a,b,d),cdA=orient(c,d,a),cdB=orient(c,d,b);
  if(abC*abD<0&&cdA*cdB<0||onSegment(a,b,c)||onSegment(a,b,d)||onSegment(c,d,a)||onSegment(c,d,b))return {reason:'self-intersecting-projection',vertices:n,maxDeviation:plane.maxDeviation};
 }
 const sign=Math.sign(area),remaining=Array.from({length:n},(_,i)=>i),indices=[];
 while(remaining.length>3){
  let ear=-1,best=-Infinity;
  for(let i=0;i<remaining.length;i++){
   const a=remaining[(i+remaining.length-1)%remaining.length],b=remaining[i],c=remaining[(i+1)%remaining.length],twice=sign*orient(p[a],p[b],p[c]);if(twice<=epsilon)continue;
   let empty=true;for(const v of remaining)if(v!==a&&v!==b&&v!==c&&sign*orient(p[a],p[b],p[v])>=-epsilon&&sign*orient(p[b],p[c],p[v])>=-epsilon&&sign*orient(p[c],p[a],p[v])>=-epsilon){empty=false;break;}
   const sides=dot(sub(p[a],p[b]),sub(p[a],p[b]))+dot(sub(p[b],p[c]),sub(p[b],p[c]))+dot(sub(p[c],p[a]),sub(p[c],p[a])),quality=twice/Math.max(epsilon,sides);
   if(empty&&quality>best){ear=i;best=quality;}
  }
  if(ear<0)return {reason:'untriangulable-projection',vertices:n,maxDeviation:plane.maxDeviation};
  indices.push(remaining[(ear+remaining.length-1)%remaining.length],remaining[ear],remaining[(ear+1)%remaining.length]);remaining.splice(ear,1);
 }
 if(sign*orient(p[remaining[0]],p[remaining[1]],p[remaining[2]])<=epsilon)return {reason:'degenerate-final-triangle'};indices.push(...remaining);
 for(let i=0;i<indices.length;i+=3){const a=points[indices[i]],b=points[indices[i+1]],c=points[indices[i+2]],normal=cross(sub(b,a),sub(c,a));if(!normal.every(Number.isFinite)||Math.hypot(...normal)<=epsilon||sign*dot(normal,plane.normal)<=epsilon)return {reason:'folded-or-degenerate-cap'};}
 const uv=new Float32Array(n*2);for(let i=0;i<n;i++){uv[i*2]=(p[i][0]-min[0])/Math.max(1e-12,max[0]-min[0]);uv[i*2+1]=(p[i][1]-min[1])/Math.max(1e-12,max[1]-min[1]);}
 return {indices:new Uint16Array(indices),uv,maxDeviation:plane.maxDeviation,projectedArea:Math.abs(area)*.5,planeNormal:plane.normal};
}
export function prepareNpcGarmentCutCaps20({positions,indices,triangleRegions,targetRegion,weldTolerance=1e-5,maxLoopVertices=128,maxCaps=1,maxTriangles=20000}={}){
 if(!positions||!indices||!triangleRegions||positions.length%3||indices.length%3||triangleRegions.length!==indices.length/3||!Number.isInteger(targetRegion)||!Number.isFinite(weldTolerance)||weldTolerance<=0||weldTolerance>1e-4||!Number.isSafeInteger(maxCaps)||maxCaps<1||maxCaps>16||!Number.isSafeInteger(maxLoopVertices)||maxLoopVertices<3||maxLoopVertices>256||!Number.isSafeInteger(maxTriangles)||maxTriangles<1||maxTriangles>20000)throw Error('Invalid bounded cap input');
 if(indices.length/3>maxTriangles||positions.length/3>maxTriangles*3)return {status:'unknown',caps:[],unknown:[{reason:'geometry-capacity'}]};
 for(const x of positions)if(!Number.isFinite(x))throw Error('Non-finite source position');for(const i of indices)if(!Number.isInteger(i)||i<0||i>=positions.length/3)throw Error('Invalid source index');for(const r of triangleRegions)if(!Number.isInteger(r))throw Error('Invalid triangle region');
 const points=[],buckets=new Map(),weld=new Uint32Array(positions.length/3);let maxWeldResidual=0;
 for(let i=0;i<weld.length;i++){
  const p=Array.from(positions.slice(i*3,i*3+3)),cell=p.map(v=>Math.floor(v/weldTolerance));let found=-1,distance=Infinity;
  for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++)for(let dz=-1;dz<=1;dz++)for(const j of buckets.get(`${cell[0]+dx},${cell[1]+dy},${cell[2]+dz}`)||[]){const d=Math.hypot(...sub(p,points[j]));if(d<=weldTolerance&&d<distance){found=j;distance=d;}}
  if(found<0){found=points.length;points.push(p);const key=cell.join(',');if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(found);}else maxWeldResidual=Math.max(maxWeldResidual,distance);weld[i]=found;
 }
 const edges=new Map(),badVertices=new Set(),naturalVertices=new Set();let degenerateTriangles=0;
 for(let i=0;i<indices.length;i+=3){const ids=[indices[i],indices[i+1],indices[i+2]],w=ids.map(id=>weld[id]);if(new Set(w).size<3){degenerateTriangles++;for(const id of w)badVertices.add(id);continue;}
  for(let j=0;j<3;j++){const a=w[j],b=w[(j+1)%3],key=edgeKey(a,b);if(!edges.has(key))edges.set(key,[]);edges.get(key).push({a,b,sourceA:ids[j],sourceB:ids[(j+1)%3],region:triangleRegions[i/3]});}
 }
 const cuts=[],adjacency=new Map();let naturalBoundaryEdges=0;
 for(const list of edges.values()){
  if(list.length===1){if(list[0].region===targetRegion){naturalBoundaryEdges++;naturalVertices.add(list[0].a);naturalVertices.add(list[0].b);}continue;}
  if(list.length!==2||list[0].a!==list[1].b||list[0].b!==list[1].a){for(const edge of list){badVertices.add(edge.a);badVertices.add(edge.b);}continue;}
  if(list[0].region===targetRegion&&list[1].region===targetRegion)continue;
  const cut=list.find(e=>e.region===targetRegion);if(!cut)continue;const id=cuts.length;cuts.push(cut);for(const v of [cut.a,cut.b]){if(!adjacency.has(v))adjacency.set(v,[]);adjacency.get(v).push(id);}
 }
 const seen=new Set(),components=[];for(let i=0;i<cuts.length;i++){if(seen.has(i))continue;const queue=[i],component=[],vertices=new Set();while(queue.length){const id=queue.pop();if(seen.has(id))continue;seen.add(id);component.push(id);for(const v of [cuts[id].a,cuts[id].b]){vertices.add(v);for(const next of adjacency.get(v))if(!seen.has(next))queue.push(next);}}components.push({edgeIds:component,vertices});}components.sort((a,b)=>b.edgeIds.length-a.edgeIds.length);
 const caps=[],unknown=[];for(const component of components){
  const n=component.edgeIds.length,vertices=[...component.vertices],reject=reason=>unknown.push({reason,vertices:vertices.length,edges:n});
  if(vertices.some(v=>badVertices.has(v))){reject('nonmanifold-source');continue;}
  if(vertices.some(v=>naturalVertices.has(v))){reject('touches-original-opening');continue;}
  if(vertices.some(v=>adjacency.get(v).length!==2)){reject('branched-cut');continue;}
  if(n<3||n>maxLoopVertices){reject('loop-capacity');continue;}
  const outgoing=new Map();let valid=true;for(const id of component.edgeIds){const e=cuts[id];if(outgoing.has(e.a)){valid=false;break;}outgoing.set(e.a,e);}if(!valid){reject('inconsistent-boundary-winding');continue;}
  const boundary=[],start=cuts[component.edgeIds[0]].a;let v=start;
  do{const e=outgoing.get(v);if(!e){valid=false;break;}boundary.push(e.sourceA);v=e.b;}while(v!==start&&boundary.length<=n);
  if(!valid||boundary.length!==n||v!==start){reject('open-or-repeated-cut');continue;}
  // Reverse the retained shell's directed boundary, so cap normals face outward.
  boundary.reverse();const actual=boundary.map(id=>Array.from(positions.slice(id*3,id*3+3))),result=triangulate(actual);
  if(result.reason){unknown.push(result);continue;}
  const capEdges=new Map();for(let i=0;i<result.indices.length;i+=3)for(let j=0;j<3;j++){const a=result.indices[i+j],b=result.indices[i+(j+1)%3],key=edgeKey(weld[boundary[a]],weld[boundary[b]]);if(!capEdges.has(key))capEdges.set(key,[]);capEdges.get(key).push({a:weld[boundary[a]],b:weld[boundary[b]]});}
  for(const [key,list]of capEdges){const retained=(edges.get(key)||[]).filter(e=>e.region===targetRegion),combined=[...retained,...list];if(combined.length!==2||combined[0].a!==combined[1].b||combined[0].b!==combined[1].a){valid=false;break;}}
  if(!valid){reject('cap-diagonal-or-boundary-nonmanifold');continue;}
  if(caps.length>=maxCaps){reject('cap-count-limit');continue;}
  caps.push({sourceVertexIds:new Uint32Array(boundary),positions:new Float32Array(actual.flat()),indices:result.indices,uv:result.uv,targetRegion,boundaryEdges:n,triangles:result.indices.length/3,maxPlaneDeviation:result.maxDeviation,projectedArea:result.projectedArea,planeNormal:result.planeNormal});
 }
 return {status:caps.length?'ready':unknown.length?'unknown':'none',caps,unknown,naturalBoundaryEdges,introducedBoundaryEdges:cuts.length,degenerateTriangles,maxWeldResidual};
}
export function createNpcGarmentCapGeometry20(THREE,cap){
 const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.BufferAttribute(cap.positions.slice(),3));geometry.setAttribute('uv',new THREE.BufferAttribute(cap.uv.slice(),2));geometry.setIndex(new THREE.BufferAttribute(cap.indices.slice(),1));geometry.computeVertexNormals();geometry.computeBoundingBox();return geometry;
}
