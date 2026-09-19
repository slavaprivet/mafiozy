// Opt-in exterior roof access. World metres, hero position is sole height.
const finite=p=>p&&['x','y','z'].every(k=>Number.isFinite(p[k]));
const clone=p=>({x:p.x,y:p.y,z:p.z});
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const lerp=(a,b,t)=>({x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t,z:a.z+(b.z-a.z)*t});
export function roofLadderDescriptor({id,lower,upper,outward,width=.8,rungSpacing=.28}){
  if(!finite(lower)||!finite(upper)||upper.y-lower.y<2||!Number.isFinite(width)||width<.65||width>1.5||!Number.isFinite(rungSpacing)||rungSpacing<.18||rungSpacing>.4)throw Error('Invalid roof ladder dimensions');
  const n=Math.hypot(outward?.x??0,outward?.z??0);if(n<.001||!Number.isFinite(n))throw Error('Roof ladder needs outward normal');
  const normal={x:outward.x/n,z:outward.z/n},right={x:normal.z,z:-normal.x};
  if((lower.x-upper.x)*normal.x+(lower.z-upper.z)*normal.z<.35)throw Error('Roof landing must be inward of ladder');
  const crest={x:lower.x,y:upper.y+.12,z:lower.z},landing={x:upper.x,y:upper.y+.12,z:upper.z};
  return {id:String(id??'roof-ladder'),lower:clone(lower),upper:clone(upper),normal,right,width,rungSpacing,yaw:Math.atan2(-normal.x,-normal.z),path:[clone(lower),crest,landing,clone(upper)],apertureWidth:Math.max(1,width+.3)};
}
export function createRoofLadder(THREE,options){
  const descriptor=roofLadderDescriptor(options),{lower,upper,normal,right,width,rungSpacing}=descriptor;
  const wallTieDepth=Math.max(.48,Number(options?.wallTieDepth)||.48);
  const object=new THREE.Group();object.name='RoofLadder_'+descriptor.id;object.userData.roofLadderId=descriptor.id;
  const material=new THREE.MeshStandardMaterial({color:0x596462,roughness:.7,metalness:.45});
  const railGeometry=new THREE.CylinderGeometry(.038,.038,1,8),rungGeometry=new THREE.CylinderGeometry(.028,.028,1,8);
  const batches=new Map([[railGeometry,[]],[rungGeometry,[]]]);
  function bar(a,b,geometry){const delta=new THREE.Vector3(b.x-a.x,b.y-a.y,b.z-a.z),length=delta.length(),position=new THREE.Vector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2),rotation=new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0,1,0),delta.normalize());batches.get(geometry).push(new THREE.Matrix4().compose(position,rotation,new THREE.Vector3(1,length,1)));}
  // Rail plane .38 m closer to facade than hero's feet. Extend handrails onto
  // roof without a transverse top bar that would close the exit aperture.
  const center={x:lower.x-normal.x*.38,z:lower.z-normal.z*.38};
  for(const sign of [-1,1]){
    const x=center.x+right.x*width*.5*sign,z=center.z+right.z*width*.5*sign;
    bar({x,y:lower.y+.05,z},{x,y:upper.y+1.05,z},railGeometry);
    bar({x,y:upper.y+1.05,z},{x:upper.x+right.x*width*.5*sign,y:upper.y+1.05,z:upper.z+right.z*width*.5*sign},railGeometry);
    // Short wall ties, below the roof handrails; ladder route is unchanged.
    for(let y=lower.y+.5;y<upper.y-.15;y+=2.2)bar({x,y,z},{x:x-normal.x*wallTieDepth,y,z:z-normal.z*wallTieDepth},railGeometry);
  }
  for(let y=lower.y+.18;y<=upper.y+.05;y+=rungSpacing)bar({x:center.x-right.x*width*.5,y,z:center.z-right.z*width*.5},{x:center.x+right.x*width*.5,y,z:center.z+right.z*width*.5},rungGeometry);

  // Small non-emissive roof/access symbols and footplates. One shared batch;
  // arrows are geometry so there are no canvas textures, fonts or new lights.
  const markerGeometry=new THREE.BoxGeometry(1,1,1),markerMaterial=new THREE.MeshStandardMaterial({color:0xffffff,roughness:.72,metalness:.12}),markers=[];
  function marker(p,size,color,roll=0,faceNormal=normal){const yaw=Math.atan2(faceNormal.x,faceNormal.z),q=new THREE.Quaternion().setFromEuler(new THREE.Euler(0,yaw,0)).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),roll));markers.push({matrix:new THREE.Matrix4().compose(new THREE.Vector3(p.x,p.y,p.z),q,new THREE.Vector3(...size)),color});}
  for(const sign of[-1,1])marker({x:center.x+right.x*width*.5*sign,y:lower.y+.025,z:center.z+right.z*width*.5*sign},[.16,.05,.2],0x887b60);
  for(const [end,direction]of[[lower,1],[upper,-1]]){
    const fn={x:normal.x*direction,z:normal.z*direction},fr={x:fn.z,z:-fn.x},origin={x:end.x+right.x*.93-normal.x*.38,y:end.y+(direction===1?1.35:.72),z:end.z+right.z*.93-normal.z*.38};
    const signDepth=Number(options?.wallSignDepths?.[direction===1?'lower':'upper'])||.38;
    origin.x=end.x+right.x*.93-normal.x*direction*signDepth;origin.z=end.z+right.z*.93-normal.z*direction*signDepth;
    const point=(x,y,front=.046)=>({x:origin.x+fr.x*x+fn.x*front,y:origin.y+y,z:origin.z+fr.z*x+fn.z*front});
    marker(origin,[.5,.65,.055],0x345e59,0,fn);
    // Roof silhouette above a vertical arrow (up at base, down at roof).
    marker(point(-.085,.20),[.23,.035,.02],0xe5d7aa,.48,fn);marker(point(.085,.20),[.23,.035,.02],0xe5d7aa,-.48,fn);
    marker(point(0,-.065),[.045,.21,.025],0xf1e6c9,0,fn);
    marker(point(-.045,-.065+direction*.073),[.13,.04,.025],0xf1e6c9,direction*.72,fn);marker(point(.045,-.065+direction*.073),[.13,.04,.025],0xf1e6c9,-direction*.72,fn);
    marker(point(0,-.22),[.20,.025,.02],0xb29b68,0,fn);
    // Sign fastener reaches the neighbouring ladder rail at each endpoint.
    bar({x:origin.x,y:origin.y,z:origin.z},{x:end.x+right.x*width*.5-normal.x*(direction===1?.38:0),y:direction===1?origin.y:end.y+1.05,z:end.z+right.z*width*.5-normal.z*(direction===1?.38:0)},railGeometry);
  }
  for(const [geometry,matrices] of batches){const mesh=new THREE.InstancedMesh(geometry,material,matrices.length);matrices.forEach((matrix,i)=>mesh.setMatrixAt(i,matrix));mesh.instanceMatrix.needsUpdate=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();mesh.castShadow=true;mesh.receiveShadow=true;mesh.userData.ladderDecor=true;mesh.userData.worldBlastStaticBounds=true;object.add(mesh);}
  const markerMesh=new THREE.InstancedMesh(markerGeometry,markerMaterial,markers.length);markers.forEach((m,i)=>{markerMesh.setMatrixAt(i,m.matrix);markerMesh.setColorAt(i,new THREE.Color(m.color))});markerMesh.instanceMatrix.needsUpdate=true;markerMesh.instanceColor.needsUpdate=true;markerMesh.computeBoundingBox();markerMesh.computeBoundingSphere();markerMesh.castShadow=markerMesh.receiveShadow=true;markerMesh.name='RoofAccessSigns';markerMesh.userData.ladderDecor=true;markerMesh.userData.worldBlastStaticBounds=true;markerMesh.userData.staticRenderMaterialImmutable=true;object.add(markerMesh);
  object.updateMatrixWorld(true);
  let disposed=false;return {object,descriptor,dispose(){if(disposed)return;disposed=true;object.removeFromParent();for(const mesh of object.children)mesh.dispose();railGeometry.dispose();rungGeometry.dispose();markerGeometry.dispose();markerMaterial.dispose();material.dispose();}};
}
export function sampleLadderPose(descriptor,position,travelled=0,direction=1,{sliding=false,dismount=0}={}){
  const phase=travelled/descriptor.rungSpacing*Math.PI,cycle=sliding?0:Math.sin(phase),{normal,right}=descriptor;
  const target=(side,height)=>({x:position.x-normal.x*.38+right.x*side*.24,y:position.y+height,z:position.z-normal.z*.38+right.z*side*.24});
  const pose={yaw:descriptor.yaw,phase,direction,sliding,handBlend:1-dismount,phaseName:dismount>0?'dismount':sliding?'slide':'climb',handL:target(1,1.4+cycle*.1),handR:target(-1,1.4-cycle*.1),footL:target(1,.15-cycle*.13),footR:target(-1,.15+cycle*.13),angles:{chest:{x:.13},upperarm_l:{x:-1.9-cycle*.22},upperarm_r:{x:-1.9+cycle*.22},forearm_l:{x:-.4},forearm_r:{x:-.4},thigh_l:{x:-.55+cycle*.38},thigh_r:{x:-.55-cycle*.38},shin_l:{x:.7-cycle*.35},shin_r:{x:.7+cycle*.35}}};
  if(sliding){pose.handL=target(1,1.35);pose.handR=target(-1,1.35);pose.angles.chest.x=.04;pose.angles.thigh_l.x=pose.angles.thigh_r.x=-.14;pose.angles.shin_l.x=pose.angles.shin_r.x=.24;}
  if(dismount>0){const t=dismount*tEase(dismount);for(const a of Object.values(pose.angles))for(const key of Object.keys(a))a[key]*=1-t;pose.angles.thigh_l.x+=Math.sin(phase)*.22*t;pose.angles.thigh_r.x-=Math.sin(phase)*.22*t;}
  return pose;
}
const tEase=t=>t*(3-2*t);
export function createLadderClimbController({validatePosition,validateSegment,speed=1.7,slideSpeed=5.5,stepOff=.75,reach=1.35}={}){
  if(typeof validatePosition!=='function'||typeof validateSegment!=='function')throw Error('Ladder host must validate endpoints and swept body clearance');
  if(![speed,slideSpeed].every(n=>n>0&&Number.isFinite(n))||!Number.isFinite(stepOff)||stepOff<0)throw Error('Invalid ladder speed/landing');
  let state=null,last=null;
  const context=(s,mode='climb')=>({ladder:s.ladder,mode,bodyHeight:1.9,radius:.33});
  const roofPoint=ladder=>({x:ladder.upper.x-ladder.normal.x*stepOff,y:ladder.upper.y,z:ladder.upper.z-ladder.normal.z*stepOff});
  function clear(a,b,ctx){if(!validateSegment(a,b,ctx))return false;const steps=Math.max(1,Math.ceil(distance(a,b)/.18));for(let i=0;i<=steps;i++)if(!validatePosition(lerp(a,b,i/steps),ctx))return false;return true;}
  function prompt(point,ladders){if(state||!finite(point))return null;let best=null;for(const ladder of ladders)for(const end of ['lower','upper']){const d=distance(point,ladder[end]);
    // The roof endpoint is vertically gated: a player standing on the ground
    // under a tall ladder must never receive a misleading Ctrl prompt.  Ctrl
    // becomes available only in the roof approach band, where mounting the
    // ladder is physically possible; the lower endpoint keeps the normal E
    // interaction distance.
    const upperApproach=end==='upper'&&point.y>=ladder.upper.y-1.15&&d<=Math.min(reach,.95);
    if((end==='lower'?d<=reach:upperApproach)&&(!best||d<best.distance))best={ladder,end,distance:d,text:end==='lower'?'E — подняться на крышу':'Ctrl — быстро спуститься'};}
  return best;}
  function pose(s){const progress=s.direction>0&&!s.cancelling?Math.max(0,Math.min(1,(s.travelled-s.exitStart)/Math.max(.01,s.total-s.exitStart))):0;return sampleLadderPose(s.ladder,s.position,s.travelled,s.direction,{sliding:s.sliding,dismount:progress});}
  function begin(point,ladder,end,{sliding=false}={}){if(state||!finite(point))return false;end??=distance(point,ladder.lower)<=distance(point,ladder.upper)?'lower':'upper';if(!['lower','upper'].includes(end)||distance(point,ladder[end])>reach)return false;
    const route=ladder.path.map(clone);if(stepOff>0)route.push(roofPoint(ladder));
    const path=[clone(point),...(end==='lower'?route:[...ladder.path].reverse()).map(clone)];
    const ctx={ladder,mode:'climb',bodyHeight:1.9,radius:.33};for(let i=1;i<path.length;i++)if(!clear(path[i-1],path[i],ctx))return false;
    if(!validatePosition(path.at(-1),{...ctx,mode:'landing'}))return false;
    let total=0,exitStart=0;for(let i=1;i<path.length;i++){total+=distance(path[i-1],path[i]);if(i===2)exitStart=total;}
    state={ladder,route,path,index:1,position:clone(point),travelled:0,total,exitStart,direction:end==='lower'?1:-1,sliding:sliding&&end==='upper',cancelling:false,history:[clone(point)]};last=null;return true;
  }
  function update(dt){if(!state)return last;if(!Number.isFinite(dt)||dt<0)dt=0;let time=Math.min(dt,.25),s=state;
    while(time>1e-9&&s.index<s.path.length){const goal=s.path[s.index],d=distance(s.position,goal);
      // Mounting, crossing the parapet opening and stepping onto ground stay
      // controlled. Only the vertical run uses the fast sliding speed.
      const vertical=goal.y<s.position.y-.01&&Math.hypot(goal.x-s.position.x,goal.z-s.position.z)<.02;
      const velocity=s.sliding&&vertical?slideSpeed:speed,move=Math.min(d,time*velocity),next=d<1e-9?clone(goal):lerp(s.position,goal,move/d);
      if(!clear(s.position,next,context(s))){last={position:clone(s.position),active:true,blocked:true,sliding:s.sliding,pose:pose(s)};return last;}
      s.position=next;s.travelled+=move;time-=move/velocity;if(d<=move+1e-9){s.index++;s.history.push(clone(next));}
    }
    const done=s.index>=s.path.length;last={position:clone(s.position),active:!done,done,cancelled:done&&s.cancelling,sliding:s.sliding,pose:pose(s)};if(done)state=null;return last;
  }
  // E during a slide slows the remaining descent to its safe ground endpoint.
  // Ordinary climb cancellation returns over the already traversed route.
  function cancel(){if(!state)return false;if(state.sliding){state.sliding=false;state.cancelling=true;return true}if(state.cancelling)return true;state.path=[clone(state.position),...state.history.slice().reverse()];state.index=1;state.direction*=-1;state.sliding=false;state.cancelling=true;return true;}
  function slideDown(){
    if(!state)return false;const s=state;
    if(s.direction<0){s.sliding=true;return true;}
    // Locate the current point on the known ladder route. This also handles
    // Ctrl during ascent or after cancelling descent, without teleportation.
    let best=null;for(let i=1;i<s.route.length;i++){const a=s.route[i-1],b=s.route[i],dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,length=dx*dx+dy*dy+dz*dz,t=length?Math.max(0,Math.min(1,((s.position.x-a.x)*dx+(s.position.y-a.y)*dy+(s.position.z-a.z)*dz)/length)):0,q=lerp(a,b,t),d=distance(s.position,q);if(!best||d<best.distance)best={i,q,distance:d};}
    const path=[clone(s.position),best.q,...s.route.slice(0,best.i).reverse().map(clone)];
    for(let i=1;i<path.length;i++)if(!clear(path[i-1],path[i],context(s)))return false;
    if(!validatePosition(path.at(-1),context(s,'landing')))return false;
    s.path=path;s.index=1;s.direction=-1;s.sliding=true;s.cancelling=false;s.history=[clone(s.position)];return true;
  }
  function reset(){const point=state?clone(state.position):last?.position?clone(last.position):null;state=null;last=null;return point;}
  return {prompt,begin,update,cancel,slideDown,reset,get locked(){return state!==null},get state(){return state?{position:clone(state.position),direction:state.direction,sliding:state.sliding,cancelling:state.cancelling,ladderId:state.ladder.id}:null}};
}
