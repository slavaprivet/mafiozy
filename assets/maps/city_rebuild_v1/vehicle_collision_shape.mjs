// Driving footprint derived once from the owned, closed runtime vehicle.
// Render/seat/water dimensions remain separate; mirrors are compliant appendages.
const EPS=1e-9;
const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
export function convexVehicleHull(points){
 const ordered=points.filter(p=>p.every(Number.isFinite)).sort((a,b)=>a[0]-b[0]||a[1]-b[1]),unique=[];
 for(const point of ordered){const last=unique.at(-1);if(!last||Math.abs(point[0]-last[0])>EPS||Math.abs(point[1]-last[1])>EPS)unique.push(point)}
 if(unique.length<3)throw Error('Vehicle collision shape needs non-collinear geometry');
 const lower=[],upper=[];
 for(const p of unique){while(lower.length>=2&&cross(lower.at(-2),lower.at(-1),p)<=EPS)lower.pop();lower.push(p)}
 for(let i=unique.length-1;i>=0;i--){const p=unique[i];while(upper.length>=2&&cross(upper.at(-2),upper.at(-1),p)<=EPS)upper.pop();upper.push(p)}
 lower.pop();upper.pop();const hull=lower.concat(upper);if(hull.length<3)throw Error('Degenerate vehicle collision shape');return hull;
}

export function buildVehicleCollisionShape(T,car){
 if(!car?.object)throw Error('A vehicle object is required');
 const root=car.object,doors=new Set(car.doors?.values?.()||[]),wheels=new Map((car.wheels||[]).map(w=>[w.pivot,w])),spins=new Set((car.wheels||[]).map(w=>w.wheel)),tyres=new Set((car.wheels||[]).map(w=>w.tire));
 const points=[],meshNames=[],excluded=[],v=new T.Vector3(),identity=new T.Matrix4(),unit=new T.Vector3(1,1,1),zeroQ=new T.Quaternion();
 const decorative=/Mirror|DoorHandle|Door_handle|Lightbar|Ladder|RoofRail|Roof_rail|Roofrail|RoofSpoiler|Spoiler|Taxi_(roof_sign|sign_mount|letters)|damage_effect|Engine_smoke|Hood_support_strut/i;
 function visit(node,parentMatrix,inWheel=false,inTyre=false){
  if(node!==root&&!node.visible)return;
  if(node===car.interior?.object||node.name?.startsWith('Interior_')||decorative.test(node.name||'')){excluded.push(node.name);return}
  let matrix=parentMatrix;
  if(node!==root){
   const wheel=wheels.get(node),closed=doors.has(node)||spins.has(node)||/^(Hood|Trunk)_hinge$/.test(node.name);
   const local=new T.Matrix4().compose(wheel?.restPosition||node.position,wheel||closed?zeroQ:node.quaternion,tyres.has(node)?unit:node.scale);matrix=parentMatrix.clone().multiply(local);
   if(wheel)inWheel=true;if(tyres.has(node))inTyre=true;
  }
  // Rims and bolts lie inside the tyre's envelope and need no duplicate scan.
  if(node.isMesh&&(!inWheel||inTyre)&&!node.material?.transparent){
   const a=node.geometry?.attributes?.position;if(a){meshNames.push(node.name);for(let i=0;i<a.count;i++){v.fromBufferAttribute(a,i).applyMatrix4(matrix);points.push([v.x,v.z])}}
  }
  for(const child of node.children)visit(child,matrix,inWheel,inTyre);
 }
 visit(root,identity);
 const hull=convexVehicleHull(points),xs=hull.map(p=>p[0]),zs=hull.map(p=>p[1]),min=[Math.min(...xs),Math.min(...zs)],max=[Math.max(...xs),Math.max(...zs)];
 return {
  collisionHull:hull,collisionHalfWidth:Math.max(Math.abs(min[0]),Math.abs(max[0])),collisionHalfLength:Math.max(Math.abs(min[1]),Math.abs(max[1])),
  collisionBounds:{min,max},collisionShapeSource:'closed-runtime-body-bumpers-tyres',
  collisionShapeDiagnostics:{vertices:hull.length,sourceVertices:points.length,meshes:meshNames,excluded,pose:'closed access panels, neutral wheels',padding:0},
 };
}

function localPolygon(shape){
 const hull=shape?.collisionHull;
 if(Array.isArray(hull)&&hull.length>=3&&hull.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)))return hull;
 const w=Number.isFinite(shape?.halfWidth)?shape.halfWidth:1.28,l=Number.isFinite(shape?.halfLength)?shape.halfLength:2.24;
 return [[-w,-l],[w,-l],[w,l],[-w,l]];
}
function paddedPolygon(poly,padding){
 if(!(padding>0))return poly;
 let area=0;for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length];area+=a[0]*b[1]-a[1]*b[0]}const sign=area>=0?1:-1;
 const edges=poly.map((a,i)=>{const b=poly[(i+1)%poly.length],dx=b[0]-a[0],dz=b[1]-a[1],len=Math.hypot(dx,dz)||1,nx=sign*dz/len,nz=-sign*dx/len;return{nx,nz,d:nx*a[0]+nz*a[1]+padding}});
 return poly.map((p,i)=>{const a=edges[(i+edges.length-1)%edges.length],b=edges[i],det=a.nx*b.nz-a.nz*b.nx;return Math.abs(det)<EPS?[p[0]+b.nx*padding,p[1]+b.nz*padding]:[(a.d*b.nz-a.nz*b.d)/det,(a.nx*b.d-a.d*b.nx)/det]});
}
export function collisionPolygon(x,z,yaw,shape={}){
 const padding=Number.isFinite(shape.collisionPadding)?Math.max(0,shape.collisionPadding):0,poly=paddedPolygon(localPolygon(shape),padding),sin=Math.sin(yaw),cos=Math.cos(yaw);
 return poly.map(([side,front])=>[x+side*cos+front*sin,z-side*sin+front*cos]);
}
export function collisionCircleOverlap(car,x,z,radius=.36,shape=car.vehicleProfile||car.profile||{}){
 if(![car.x,car.z,car.yaw,x,z,radius].every(Number.isFinite)||radius<0)return false;
 const poly=collisionPolygon(car.x,car.z,car.yaw,shape);let inside=false,min=Infinity;
 for(let i=0,j=poly.length-1;i<poly.length;j=i++){
  const a=poly[j],b=poly[i],dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((x-a[0])*dx+(z-a[1])*dz)/(dx*dx+dz*dz||1)));
  min=Math.min(min,(x-a[0]-t*dx)**2+(z-a[1]-t*dz)**2);
  if((a[1]>z)!==(b[1]>z)&&x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0])inside=!inside;
 }
 return inside||min<radius*radius;
}
