// Room-local metre coordinates. The host creates floor plates around holeRects
// and transforms queries/collision boxes through the unchanged building root.
const within=(x,z,r)=>x>=r[0]-1e-7&&x<=r[2]+1e-7&&z>=r[1]-1e-7&&z<=r[3]+1e-7;
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
export function planInteriorStaircase({rect,floorHeight=3.3,floors=2,baseY=0,flightWidth=1.5,origin=null,slope=.65,landingDepth=flightWidth}={}){
 if(!rect||rect.length!==4||!rect.every(Number.isFinite)||!(rect[2]>rect[0]&&rect[3]>rect[1])||!Number.isInteger(floors)||floors<1||!Number.isFinite(baseY)||!Number.isFinite(floorHeight)||floorHeight<2.7||!Number.isFinite(flightWidth)||flightWidth<1.3)throw Error('Invalid staircase room/floor dimensions');
 if(!Number.isFinite(slope)||slope<=0||slope>.78||!Number.isFinite(landingDepth)||landingDepth<1.2)throw Error('Invalid staircase slope/landing');
 const gap=.18,slab=.12,landing=landingDepth,width=flightWidth*2+gap,halfRise=floorHeight/2,run=halfRise/slope,depth=run+2*landing;
 const x0=origin?.x??rect[0]+.12,z0=origin?.z??rect[1]+.12,x1=x0+flightWidth,x2=x1+gap,x3=x2+flightWidth,za=z0+landing,zb=za+run;
 const footprint=[x0,z0,x3,zb+landing];
 if(floors>1&&(!within(footprint[0],footprint[1],rect)||!within(footprint[2],footprint[3],rect)))throw Error(`Staircase requires ${width.toFixed(2)} x ${depth.toFixed(2)} metres plus wall margin`);
 const flights=[],landings=[],holeRects=[],obstacles=[],route=[],boxes=[],rails=[],postConnections=[];
 const addBox=(x,y,z,w,h,d)=>boxes.push({x,y,z,w,h,d});
 const addRail=(a,b)=>{
  rails.push({a,b});
  // Narrow rails remain collision barriers at the correct storey height.
  obstacles.push({rect:[Math.min(a.x,b.x)-.045,Math.min(a.z,b.z)-.045,Math.max(a.x,b.x)+.045,Math.max(a.z,b.z)+.045],minY:Math.min(a.y,b.y)-.85,maxY:Math.max(a.y,b.y)+.045,kind:'stair-railing'});
 };
 // Posts overlap both their real tread/landing and the underside of the
 // sloped 7cm handrail. A fixed .9m post left a visible gap below .95m rails.
 const addPost=(x,z,supportY,railY,railSlope=0)=>{
  const bottom=supportY-.008,underside=railY-.035*Math.sqrt(1+railSlope*railSlope),top=underside+.016;
  const boxIndex=boxes.length;addBox(x,(bottom+top)/2,z,.055,top-bottom,.055);
  postConnections.push({boxIndex,x,z,supportY,railY,underside,overlap:.016});
 };
 const segment=(a,b)=>{const steps=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/.06));for(let j=route.length?1:0;j<=steps;j++){const t=j/steps;route.push({x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t,z:a.z+(b.z-a.z)*t})}};
 for(let level=0;level<floors-1;level++){
  const y=baseY+level*floorHeight;
  holeRects.push({level:level+1,rect:[x0,za,x3,zb+landing]});
  const a={rect:[x0,za,x1,zb],base:y,direction:1,level},b={rect:[x2,za,x3,zb],base:y+halfRise,direction:-1,level};flights.push(a,b);
  landings.push({rect:[x0,zb,x3,zb+landing],y:y+halfRise,level});
  addBox((x0+x3)/2,y+halfRise-slab/2,zb+landing/2,width,slab,landing);
  const n=Math.ceil(halfRise/.18),tread=run/n,riser=halfRise/n;
  for(const f of[a,b]){
   const cx=(f.rect[0]+f.rect[2])/2;
   for(let i=0;i<n;i++){
    const z=f.direction===1?za+(i+.5)*tread:zb-(i+.5)*tread;
    // Thin individual stair sections leave real headroom underneath.
    addBox(cx,f.base+(i+1)*riser-slab/2,z,flightWidth,slab,tread+.008);
   }
   for(const rx of[f.rect[0],f.rect[2]]){
    // End supports sit 6cm inside the rail end caps. Middle supports are at
    // tread centres, avoiding ambiguous support on a vertical riser edge.
    const ts=[.06/run,1-.06/run];for(let i=2;i<n-1;i+=3)ts.push((i+.5)/n);
    for(const t of ts.sort((a,b)=>a-b)){const z=f.direction===1?za+t*run:zb-t*run,supportY=f.base+Math.min(n,Math.floor(t*n)+1)*riser;addPost(rx,z,supportY,f.base+t*halfRise+.95,slope)}
    const startZ=f.direction===1?za:zb,endZ=f.direction===1?zb:za;
    addRail({x:rx,y:f.base+.95,z:startZ},{x:rx,y:f.base+halfRise+.95,z:endZ});
   }
  }
  const landingY=y+halfRise,railY=landingY+.95;
  // Continuous perimeter connections to the half-landing back rail. These
  // stay at the outside edges, clear of the walking turn between flights.
  for(const x of[x0,x3]){addRail({x,y:railY,z:zb},{x,y:railY,z:zb+landing});addPost(x,zb+.06,landingY,railY);addPost(x,zb+landing-.06,landingY,railY)}
  addRail({x:x0,y:railY,z:zb+landing},{x:x3,y:railY,z:zb+landing});
  for(const x of[x0+.06,(x0+x3)/2,x3-.06])addPost(x,zb+landing,landingY,railY);
  addRail({x:x1,y:railY,z:zb},{x:x2,y:railY,z:zb});
  const lx=(x0+x1)/2,rx=(x2+x3)/2;
  if(level){const prev=route.at(-1);segment(prev,{x:lx,y,z:z0+landing/2})}
  segment({x:lx,y,z:z0+landing/2},{x:lx,y,z:za});
  segment({x:lx,y,z:za},{x:lx,y:y+halfRise,z:zb});
  segment(route.at(-1),{x:lx,y:y+halfRise,z:zb+landing/2});
  segment(route.at(-1),{x:rx,y:y+halfRise,z:zb+landing/2});
  segment(route.at(-1),{x:rx,y:y+halfRise,z:zb});
  segment(route.at(-1),{x:rx,y:y+floorHeight,z:za});
  segment(route.at(-1),{x:rx,y:y+floorHeight,z:z0+landing/2});
 }
 const heights=(x,z)=>{
  if(!within(x,z,rect))return [];
  const result=[];
  for(let level=0;level<floors;level++)if(!holeRects.some(h=>h.level===level&&within(x,z,h.rect)))result.push(baseY+level*floorHeight);
  for(const f of flights)if(within(x,z,f.rect))result.push(f.base+halfRise*clamp(f.direction===1?(z-za)/run:(zb-z)/run,0,1));
  for(const l of landings)if(within(x,z,l.rect))result.push(l.y);
  return result;
 };
 function sampleFloor(x,z,referenceY=baseY){if(!within(x,z,footprint)||floors===1)return null;const values=heights(x,z).filter(y=>y<=referenceY+.28+1e-6);return values.length?Math.max(...values):null}
 function sampleStairFloor(x,z,referenceY=baseY){
  if(!within(x,z,footprint)||floors===1)return null;
  const values=[];
  for(const f of flights)if(within(x,z,f.rect)){const y=f.base+halfRise*clamp(f.direction===1?(z-za)/run:(zb-z)/run,0,1);if(y<=referenceY+.28+1e-6)values.push(y)}
  for(const l of landings)if(within(x,z,l.rect)&&l.y<=referenceY+.28+1e-6)values.push(l.y);
  return values.length?Math.max(...values):null;
 }
 function sampleCeiling(x,z,referenceY=baseY){if(!within(x,z,footprint)||floors===1)return null;const values=heights(x,z).map(y=>y-slab).filter(y=>y>referenceY+.3);values.push(baseY+floors*floorHeight-slab);return Math.min(...values)}
 // Physical stair solids only: surrounding floor plates belong to the host,
 // whose previous/next stairwell openings can remove a nominal storey plane.
 function sampleStairCeiling(x,z,referenceY=baseY){
  if(!within(x,z,footprint)||floors===1)return null;
  const values=[];
  for(const f of flights)if(within(x,z,f.rect)){const y=f.base+halfRise*clamp(f.direction===1?(z-za)/run:(zb-z)/run,0,1)-slab;if(y>referenceY+.3)values.push(y)}
  for(const l of landings)if(within(x,z,l.rect)&&l.y-slab>referenceY+.3)values.push(l.y-slab);
  return values.length?Math.min(...values):null;
 }
 // Corner rail bounds for a sloped handrail are intentionally split below:
 // a full-height slope AABB would incorrectly close the entrance underneath.
 const collisionObstacles=[];
 for(const rail of rails){const count=Math.max(1,Math.ceil(Math.hypot(rail.b.x-rail.a.x,rail.b.z-rail.a.z)/.2));for(let i=0;i<count;i++){const point=t=>({x:rail.a.x+(rail.b.x-rail.a.x)*t,y:rail.a.y+(rail.b.y-rail.a.y)*t,z:rail.a.z+(rail.b.z-rail.a.z)*t}),a=point(i/count),b=point((i+1)/count);collisionObstacles.push({rect:[Math.min(a.x,b.x)-.045,Math.min(a.z,b.z)-.045,Math.max(a.x,b.x)+.045,Math.max(a.z,b.z)+.045],minY:Math.min(a.y,b.y)-.95,maxY:Math.max(a.y,b.y)+.045,kind:'stair-railing'})}}
 return {rect:rect.slice(),floorHeight,floors,baseY,footprint,holeRects,flights,landings,route,boxes,rails,postConnections,obstacles:collisionObstacles,sampleFloor,sampleStairFloor,sampleCeiling,sampleStairCeiling,requiredSize:{width,depth},slope,treadRise:halfRise/Math.ceil(halfRise/.18)};
}
export function createInteriorStaircase(THREE,options){
 const plan=planInteriorStaircase(options),group=new THREE.Group();group.name='Interior_U_Staircase';
 const geometry=new THREE.BoxGeometry(1,1,1),materials=[new THREE.MeshStandardMaterial({color:0xb5aa96,roughness:.85}),new THREE.MeshStandardMaterial({color:0x78623f,roughness:.48,metalness:.45})];
 const matrix=new THREE.Matrix4(),quaternion=new THREE.Quaternion(),up=new THREE.Vector3(0,1,0),position=new THREE.Vector3(),scale=new THREE.Vector3();
 if(plan.boxes.length){const steps=new THREE.InstancedMesh(geometry,materials[0],plan.boxes.length);steps.name='Stair_Treads_And_Posts';plan.boxes.forEach((b,i)=>{matrix.compose(position.set(b.x,b.y,b.z),quaternion.identity(),scale.set(b.w,b.h,b.d));steps.setMatrixAt(i,matrix)});steps.castShadow=steps.receiveShadow=true;steps.computeBoundingBox();steps.computeBoundingSphere();group.add(steps)}
 if(plan.rails.length){const rails=new THREE.InstancedMesh(geometry,materials[1],plan.rails.length);rails.name='Brass_Stair_Handrails';plan.rails.forEach((r,i)=>{const a=new THREE.Vector3(r.a.x,r.a.y,r.a.z),b=new THREE.Vector3(r.b.x,r.b.y,r.b.z),d=b.clone().sub(a);matrix.compose(position.copy(a).add(b).multiplyScalar(.5),quaternion.setFromUnitVectors(up,d.clone().normalize()),scale.set(.07,d.length(),.07));rails.setMatrixAt(i,matrix)});rails.castShadow=rails.receiveShadow=true;rails.computeBoundingBox();rails.computeBoundingSphere();group.add(rails)}
 let disposed=false;return {...plan,group,dispose(){if(disposed)return;disposed=true;group.removeFromParent();geometry.dispose();materials.forEach(m=>m.dispose())}};
}
