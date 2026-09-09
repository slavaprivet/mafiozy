// Cover weapon placement is solved against the authored head, not an assumed
// human-sized sphere. Cached bone-local bounds follow later animation without
// evaluating every skinned vertex each frame. These helpers never mutate pose.
const rigCache=new WeakMap(),weaponCache=new WeakMap();
const finite=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z);
const names=['head','neck','chest'];
function axes(T,q){return [new T.Vector3(1,0,0),new T.Vector3(0,1,0),new T.Vector3(0,0,1)].map(v=>v.applyQuaternion(q));}
function rigBounds(T,c){
  let cached=rigCache.get(c.object);if(cached)return cached;
  const boxes=Object.fromEntries(names.filter(n=>c.bones[n]).map(n=>[n,new T.Box3()]));
  const inverse=Object.fromEntries(Object.keys(boxes).map(n=>[n,c.bones[n].matrixWorld.clone().invert()]));
  const p=new T.Vector3();
  c.object.traverse(mesh=>{
    if(!mesh.isSkinnedMesh)return;const {position,skinWeight,skinIndex}=mesh.geometry.attributes;
    if(!skinWeight||!skinIndex)return;mesh.skeleton.update();
    for(let i=0;i<position.count;i++){
      const influence={head:0,neck:0,chest:0};
      for(let j=0;j<4;j++){const name=mesh.skeleton.bones[skinIndex.getComponent(i,j)]?.name;if(name in influence)influence[name]+=skinWeight.getComponent(i,j);}
      if(!names.some(n=>influence[n]>.35))continue;
      p.fromBufferAttribute(position,i);mesh.applyBoneTransform(i,p);p.applyMatrix4(mesh.matrixWorld);
      for(const name of names)if(influence[name]>.35&&boxes[name])boxes[name].expandByPoint(p.clone().applyMatrix4(inverse[name]));
    }
  });
  cached=Object.entries(boxes).filter(([,box])=>!box.isEmpty()).map(([name,box])=>({name,center:box.getCenter(new T.Vector3()),half:box.getSize(new T.Vector3()).multiplyScalar(.5)}));
  rigCache.set(c.object,cached);return cached;
}
function gunBounds(T,weapon){
  let cached=weaponCache.get(weapon);if(cached)return cached;
  weapon.updateWorldMatrix(true,true);const inverse=weapon.matrixWorld.clone().invert(),boxes=[];
  weapon.traverse(mesh=>{
    if(!mesh.isMesh||!mesh.geometry?.attributes?.position)return;
    mesh.geometry.computeBoundingBox();const source=mesh.geometry.boundingBox;if(source.isEmpty())return;
    const transform=inverse.clone().multiply(mesh.matrixWorld),box=new T.Box3();
    for(const x of [source.min.x,source.max.x])for(const y of [source.min.y,source.max.y])for(const z of [source.min.z,source.max.z])box.expandByPoint(new T.Vector3(x,y,z).applyMatrix4(transform));
    boxes.push({center:box.getCenter(new T.Vector3()),half:box.getSize(new T.Vector3()).multiplyScalar(.5)});
  });
  weaponCache.set(weapon,boxes);return boxes;
}
function overlaps(a,b){
  const R=a.axes.map(x=>b.axes.map(y=>x.dot(y))),A=R.map(r=>r.map(v=>Math.abs(v)+1e-8));
  const delta=b.center.clone().sub(a.center),t=a.axes.map(axis=>delta.dot(axis));
  const ah=a.half.toArray(),bh=b.half.toArray();
  for(let i=0;i<3;i++)if(Math.abs(t[i])>ah[i]+bh.reduce((s,h,j)=>s+h*A[i][j],0))return false;
  for(let j=0;j<3;j++)if(Math.abs(t.reduce((s,v,i)=>s+v*R[i][j],0))>bh[j]+ah.reduce((s,h,i)=>s+h*A[i][j],0))return false;
  for(let i=0;i<3;i++)for(let j=0;j<3;j++){
    const i1=(i+1)%3,i2=(i+2)%3,j1=(j+1)%3,j2=(j+2)%3;
    if(Math.abs(t[i2]*R[i1][j]-t[i1]*R[i2][j])>ah[i1]*A[i2][j]+ah[i2]*A[i1][j]+bh[j1]*A[i][j2]+bh[j2]*A[i][j1])return false;
  }
  return true;
}
function segmentBox(from,to,box){
  const p=from.clone().sub(box.center),d=to.clone().sub(from),half=box.half.toArray();let lo=0,hi=1;
  for(let i=0;i<3;i++){
    const o=p.dot(box.axes[i]),v=d.dot(box.axes[i]);
    if(Math.abs(v)<1e-8){if(Math.abs(o)>half[i])return false;continue;}
    let a=(-half[i]-o)/v,b=(half[i]-o)/v;if(a>b)[a,b]=[b,a];lo=Math.max(lo,a);hi=Math.min(hi,b);if(lo>hi)return false;
  }
  return true;
}
function prepare(T,c,weapon,quaternion,padding){
  c.object.updateMatrixWorld(true);
  const bodies=rigBounds(T,c).map(local=>{
    const bone=c.bones[local.name],q=bone.getWorldQuaternion(new T.Quaternion()),scale=bone.getWorldScale(new T.Vector3());
    return {name:local.name,center:local.center.clone().applyMatrix4(bone.matrixWorld),half:local.half.clone().multiply(scale).addScalar(padding),axes:axes(T,q)};
  });
  const scale=weapon.getWorldScale(new T.Vector3()),gunAxes=axes(T,quaternion);
  const gun=gunBounds(T,weapon).map(box=>({center:box.center.clone().multiply(scale).applyQuaternion(quaternion),half:box.half.clone().multiply(scale),axes:gunAxes}));
  const muzzleOffset=new T.Vector3(...(weapon.userData.muzzle||[0,0,.3])).multiply(scale).applyQuaternion(quaternion);
  const forward=gunAxes[2].clone().multiplyScalar(1.5);
  return origin=>{
    const muzzle=origin.clone().add(muzzleOffset),end=muzzle.clone().add(forward);
    const result={clear:true,headClear:true,neckClear:true,muzzleClear:true};
    for(const body of bodies){
      if(segmentBox(muzzle,end,body)){result.muzzleClear=false;result.clear=false;}
      if(body.name==='chest')continue;
      if(segmentBox(origin,muzzle,body)||gun.some(part=>overlaps(body,{...part,center:part.center.clone().add(origin)}))){result[body.name+'Clear']=false;result.clear=false;}
    }
    return result;
  };
}

export function weaponHeadClearance(THREE,context,weapon,{origin,quaternion,padding=.018}={}){
  if(!THREE||!context?.bones?.head||!weapon||!finite(origin)||!quaternion)return {clear:false,headClear:false,neckClear:false,muzzleClear:false};
  return prepare(THREE,context,weapon,quaternion,padding)(origin);
}

/** Reach spheres use mount-origin centres, exactly as the two-hand IK solver.
 * Candidate search preserves the requested direction and authored arm lengths.
 * A false result must suppress fire or select a different presentation; do not
 * report the originally requested unsafe mount as successfully reachable.
 */
export function findClearWeaponMount(THREE,context,weapon,{origin,quaternion,constraints=[],preferredSide=1,previousOrigin=null,padding=.018}={}){
  if(!finite(origin)||!quaternion||!context?.bones?.head||!weapon)return {origin:origin?.clone?.()||origin,clear:false,correction:Infinity};
  const check=prepare(THREE,context,weapon,quaternion,padding),requested=origin.clone();
  function project(point){
    for(let i=0;i<32;i++)for(const {center,radius}of constraints){const delta=point.clone().sub(center);if(delta.length()>radius)point.copy(center).add(delta.setLength(Math.max(0,radius)));}
    return point;
  }
  const reachable=p=>constraints.every(({center,radius})=>p.distanceTo(center)<=radius+.001);
  const initial=project(origin.clone());if(reachable(initial)&&check(initial).clear)return {origin:initial,clear:true,correction:initial.distanceTo(requested),candidates:1};
  const forward=new THREE.Vector3(0,0,1).applyQuaternion(quaternion),right=new THREE.Vector3(1,0,0).applyQuaternion(quaternion),up=new THREE.Vector3(0,1,0),unit=context.targetHeight/1.9;
  let best=null,score=Infinity,candidates=1;const side=preferredSide===-1?-1:1;
  const previous=finite(previousOrigin)?previousOrigin:null;
  const merit=p=>p.distanceTo(requested)+Math.max(0,-p.clone().sub(requested).dot(right)*side)*.15+(previous?p.distanceTo(previous)*.35:0);
  function admit(point){
    const value=merit(point);if(value>=score||!reachable(point)||!check(point).clear)return false;
    best=point;score=value;return true;
  }
  if(previous)admit(project(previous.clone()));
  // Coarse-to-fine offsets avoid an explosive 3D grid. Most blocked mounts
  // resolve by moving one hand-span sideways or below the oversized head.
  for(const radius of [.10,.20,.32,.46,.62,.82])for(const dx of [side,-side,0])for(const dy of [0,-1,1])for(const dz of [0,1,-.5]){
    if(!dx&&!dy&&!dz)continue;
    const point=project(requested.clone().addScaledVector(right,dx*radius*unit).addScaledVector(up,dy*radius*unit).addScaledVector(forward,dz*radius*unit));candidates++;
    admit(point);
  }
  if(best){
    // A grid chooses a safe basin; it must not quantize the returned mount.
    // Refine from the safe end toward the requested projected point, retaining
    // a tested safe endpoint throughout. Then descend locally along each axis.
    let safe=best.clone(),lo=0,hi=1;
    for(let i=0;i<12;i++){
      const t=(lo+hi)/2,point=initial.clone().lerp(best,t);candidates++;
      if(reachable(point)&&check(point).clear){safe=point;hi=t;}else lo=t;
    }
    admit(safe);
    for(const amount of [.06,.03,.015,.0075])for(let pass=0;pass<2;pass++)for(const axis of [right,up,forward])for(const sign of [-1,1]){
      const point=project(best.clone().addScaledVector(axis,amount*unit*sign));candidates++;admit(point);
    }
  }
  return {origin:best||initial,clear:!!best,correction:(best||initial).distanceTo(requested),candidates};
}
