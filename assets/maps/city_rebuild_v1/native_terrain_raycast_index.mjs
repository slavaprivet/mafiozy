// Opt-in CPU index for the immutable, plain meshes produced by terrain().
// Rendering buffers and Mesh.raycast remain untouched. Final triangle tests use
// the caller's installed Three implementation, including its interpolants.
export function installNativeTerrainRaycastIndex({THREE,mesh}={}){
 const prototype=THREE?.Mesh?.prototype,geometry=mesh?.geometry;
 const plain=()=>mesh?.isMesh&&!mesh.isInstancedMesh&&!mesh.isSkinnedMesh&&
  ['water','grass','sand','asphalt','paving'].includes(mesh.userData?.nativeTerrainKind)&&
  mesh.raycast===prototype?.raycast&&mesh.getVertexPosition===prototype?.getVertexPosition&&
  !!mesh.material&&!Array.isArray(mesh.material)&&
  !Object.values(mesh.geometry?.morphAttributes||{}).some(a=>a?.length);
 const supportedAttribute=(a,size)=>a?.isBufferAttribute&&!a.isInterleavedBufferAttribute&&
  a.itemSize===size&&!a.normalized&&Number.isInteger(a.count)&&a.count>0&&
  (a.array instanceof Float32Array||a.array instanceof Float64Array||
   (size===1&&(a.array instanceof Uint16Array||a.array instanceof Uint32Array||a.array instanceof Uint8Array)))&&
  a.array.length===a.count*size&&['getX','getY','getZ'].every(key=>a[key]===THREE.BufferAttribute.prototype[key]);
 const position=geometry?.attributes?.position,index=geometry?.index;
 const total=index?.count??position?.count;
 const alignedRange=()=>Number.isInteger(geometry.drawRange.start)&&geometry.drawRange.start%3===0&&
  (Number.isFinite(geometry.drawRange.count)||geometry.drawRange.count===Infinity);
 if(!plain()||mesh._computeIntersections!==prototype._computeIntersections||
  !supportedAttribute(position,3)||(index!==null&&!supportedAttribute(index,1))||total%3!==0||!alignedRange())return null;
 const original=mesh._computeIntersections,own=Object.getOwnPropertyDescriptor(mesh,'_computeIntersections');
 const snapshots=[position,index].filter(Boolean).map(a=>({a,array:a.array,count:a.count,version:a.version,itemSize:a.itemSize,normalized:a.normalized}));
 const triangleCount=total/3,order=Array.from({length:triangleCount},(_,i)=>i);
 let boxes=new Float64Array(triangleCount*6);
 for(let t=0;t<triangleCount;t++){
  const b=t*6;boxes[b]=boxes[b+1]=boxes[b+2]=Infinity;boxes[b+3]=boxes[b+4]=boxes[b+5]=-Infinity;
  for(let j=0;j<3;j++){
   const vertex=index?index.getX(t*3+j):t*3+j;
   if(!Number.isInteger(vertex)||vertex<0||vertex>=position.count)return null;
   for(let axis=0;axis<3;axis++){
    const value=position.array[vertex*3+axis];if(!Number.isFinite(value))return null;
    boxes[b+axis]=Math.min(boxes[b+axis],value);boxes[b+axis+3]=Math.max(boxes[b+axis+3],value);
   }
  }
  // Outward-only padding admits grazing/flat triangles despite box arithmetic
  // roundoff. It never changes the final native triangle test or returned hit.
  for(let axis=0;axis<3;axis++){const pad=1e-7*Math.max(1,Math.abs(boxes[b+axis]),Math.abs(boxes[b+axis+3]));boxes[b+axis]-=pad;boxes[b+axis+3]+=pad;}
 }
 let nodes=[];
 function build(first,last){
  const node={bounds:[Infinity,Infinity,Infinity,-Infinity,-Infinity,-Infinity],first,last,left:-1,right:-1},id=nodes.push(node)-1;
  for(let i=first;i<last;i++)for(let a=0;a<3;a++){const b=order[i]*6;node.bounds[a]=Math.min(node.bounds[a],boxes[b+a]);node.bounds[a+3]=Math.max(node.bounds[a+3],boxes[b+a+3]);}
  if(last-first>16){
   let axis=0;for(let a=1;a<3;a++)if(node.bounds[a+3]-node.bounds[a]>node.bounds[axis+3]-node.bounds[axis])axis=a;
   const sorted=order.slice(first,last).sort((a,b)=>(boxes[a*6+axis]+boxes[a*6+axis+3])-(boxes[b*6+axis]+boxes[b*6+axis+3])||a-b);
   for(let i=0;i<sorted.length;i++)order[first+i]=sorted[i];
   const middle=(first+last)>>>1;node.left=build(first,middle);node.right=build(middle,last);
  }
  return id;
 }
 build(0,triangleCount);
 boxes=null; // Build scratch is not retained by the installed hook.
 const stats={triangles:triangleCount,nodes:nodes.length,queries:0,fallbacks:0,disabledQueries:0,enabled:true,lastCandidates:0,lastBoxTests:0};
 const facade={geometry:{attributes:null,index:null,groups:null,drawRange:{start:0,count:3}},material:null,matrixWorld:null,getVertexPosition:mesh.getVertexPosition.bind(mesh)};
 const stack=[],candidates=[];
 function intersectsBox(bounds,origin,direction){
  let enter=0,exit=Infinity;
  for(let a=0;a<3;a++){
   const o=origin[a],d=direction[a];
   if(d===0){if(o<bounds[a]||o>bounds[a+3])return false;continue;}
   let lo=(bounds[a]-o)/d,hi=(bounds[a+3]-o)/d;if(lo>hi){const swap=lo;lo=hi;hi=swap;}
   enter=Math.max(enter,lo);exit=Math.min(exit,hi);if(exit<enter)return false;
  }
  return true;
 }
 function accelerated(raycaster,hits,ray){
  if(!stats.enabled){stats.disabledQueries++;return original.call(this,raycaster,hits,ray);}
  if(this!==mesh||!nodes||!plain()||mesh.geometry!==geometry||geometry.attributes.position!==position||geometry.index!==index||!alignedRange()||
   snapshots.some(s=>s.a.array!==s.array||s.a.version!==s.version||s.a.count!==s.count||s.a.itemSize!==s.itemSize||s.a.normalized!==s.normalized||!supportedAttribute(s.a,s.itemSize))||
   !mesh.matrixWorld.elements.every(Number.isFinite)||mesh.matrixWorld.determinant()===0||
   ![ray.origin.x,ray.origin.y,ray.origin.z,ray.direction.x,ray.direction.y,ray.direction.z].every(Number.isFinite)){
   stats.fallbacks++;return original.call(this,raycaster,hits,ray);
  }
  stats.queries++;stats.lastBoxTests=0;stack.length=0;candidates.length=0;stack.push(0);
  const origin=[ray.origin.x,ray.origin.y,ray.origin.z],direction=[ray.direction.x,ray.direction.y,ray.direction.z];
  const start=Math.max(0,geometry.drawRange.start),end=Math.min(total,geometry.drawRange.start+geometry.drawRange.count);
  while(stack.length){
   const node=nodes[stack.pop()];stats.lastBoxTests++;
   if(!intersectsBox(node.bounds,origin,direction))continue;
   if(node.left>=0){stack.push(node.left,node.right);continue;}
   for(let i=node.first;i<node.last;i++){const offset=order[i]*3;if(offset>=start&&offset<end)candidates.push(offset);}
  }
  candidates.sort((a,b)=>a-b);stats.lastCandidates=candidates.length;
  facade.geometry.attributes=geometry.attributes;facade.geometry.index=index;facade.geometry.groups=geometry.groups;
  facade.material=mesh.material;facade.matrixWorld=mesh.matrixWorld;
  for(const offset of candidates){
   facade.geometry.drawRange.start=offset;
   const first=hits.length;
   try{original.call(facade,raycaster,hits,ray);}
   finally{for(let i=first;i<hits.length;i++)hits[i].object=mesh;}
  }
 }
 mesh._computeIntersections=accelerated;
 return {stats,setEnabled(enabled){stats.enabled=!!enabled&&!!nodes;return stats.enabled;},dispose(){
  if(mesh._computeIntersections===accelerated){if(own)Object.defineProperty(mesh,'_computeIntersections',own);else delete mesh._computeIntersections;}
  stats.enabled=false;nodes=null;order.length=0;stack.length=0;candidates.length=0;
 }};
}
