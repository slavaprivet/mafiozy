// Source owns activities/timers. This overlay owns only upper-body presentation.
// Scratch objects and props are retained; apply() allocates no THREE resources.
const clamp=n=>Math.max(0,Math.min(1,n));
const KINDS=new Set(['talk','read','smoke']),PHASES=new Set(['active','finish']);
export function createNpcSocialPose({THREE,walker}){
 const c=walker.artistContext(),unit=walker.height/1.9;
 let seed=0;for(const ch of String(c.object.userData.npcId||''))seed=(seed*31+ch.charCodeAt(0))>>>0;const phaseOffset=seed%1000/157;
 const p=new THREE.Vector3(),s=new THREE.Vector3(),q=new THREE.Quaternion(),delta=new THREE.Quaternion(),euler=new THREE.Euler();
 const basis=new THREE.Quaternion(),parentQ=new THREE.Quaternion(),handQ=new THREE.Quaternion(),swing=new THREE.Quaternion();
 const forward=new THREE.Vector3(),right=new THREE.Vector3(),center=new THREE.Vector3(),goal=new THREE.Vector3(),current=new THREE.Vector3(),local=new THREE.Vector3();
 const shoulder=new THREE.Vector3(),fore=new THREE.Vector3(),wrist=new THREE.Vector3(),offset=new THREE.Vector3(),line=new THREE.Vector3(),bend=new THREE.Vector3(),elbow=new THREE.Vector3(),origin=new THREE.Vector3(),from=new THREE.Vector3(),to=new THREE.Vector3();
 const sides=[{side:'l',sign:-1,upper:'upperarm_l',fore:'forearm_l',hand:'hand_l',socket:'socket_hand_l'},{side:'r',sign:1,upper:'upperarm_r',fore:'forearm_r',hand:'hand_r',socket:'socket_hand_r'}];
 const geometries=[],materials=[];let book=null,cigarette=null,disposed=false,lastKind=null,applied=0,resourceBuilds=0;
 function material(color,roughness=.9){const m=new THREE.MeshStandardMaterial({color,roughness});materials.push(m);return m;}
 function box(group,g,m,x,y,z,sx,sy,sz){const mesh=new THREE.Mesh(g,m);mesh.position.set(x,y,z);mesh.scale.set(sx,sy,sz);group.add(mesh);return mesh;}
 function ensureBook(){if(book)return;resourceBuilds++;const g=new THREE.BoxGeometry(1,1,1);geometries.push(g);book=new THREE.Group();book.name='NPC_ReadingBook';c.offset.add(book);
  box(book,g,material(0x4b2532),0,0,0,.95,.065,.65);
  const paper=material(0xe9ddbd),left=box(book,g,paper,-.232,.045,0,.444,.034,.59),rightPage=box(book,g,paper,.232,.045,0,.444,.034,.59);left.rotation.z=.055;rightPage.rotation.z=-.055;
 }
 function ensureCigarette(){if(cigarette)return;resourceBuilds++;const g=new THREE.CylinderGeometry(1,1,1,6);geometries.push(g);cigarette=new THREE.Group();cigarette.name='NPC_Cigarette';c.bones.socket_hand_r.add(cigarette);cigarette.position.set(0,.025,.035);cigarette.rotation.x=Math.PI/2;
  const paper=material(0xe8e1cf),filter=material(0xb98049),ember=material(0xc95b28);
  box(cigarette,g,paper,0,.075,0,.022,.17,.022);box(cigarette,g,filter,0,-.04,0,.024,.07,.024);box(cigarette,g,ember,0,.165,0,.022,.012,.022);
 }
 function rotate(name,x=0,y=0,z=0){const bone=c.bones[name],rest=c.rest[name];bone.matrix.decompose(p,q,s);q.multiply(delta.setFromEuler(euler.set(x,y,z)));bone.matrix.compose(rest.p,q,rest.s);bone.matrixWorldNeedsUpdate=true;}
 function worldRotation(name,rotation){const bone=c.bones[name],rest=c.rest[name];bone.parent.getWorldQuaternion(parentQ);parentQ.invert().multiply(rotation);bone.matrix.compose(rest.p,parentQ,rest.s);bone.matrixWorldNeedsUpdate=true;bone.updateWorldMatrix(false,true);}
 function pointBone(name,end,target){c.bones[name].getWorldPosition(origin);c.bones[end].getWorldPosition(from).sub(origin).normalize();to.copy(target).sub(origin).normalize();swing.setFromUnitVectors(from,to);c.bones[name].getWorldQuaternion(q);swing.multiply(q);worldRotation(name,swing);}
 // Same two-link nonstretch solution as the hero, using persistent scratch.
 function reach(arm,target,blend){
  c.bones[arm.socket].getWorldPosition(current);goal.lerpVectors(current,target,blend);c.bones[arm.hand].getWorldQuaternion(handQ);
  offset.copy(c.rest[arm.socket].p).multiplyScalar(walker.scale).applyQuaternion(handQ);wrist.copy(goal).sub(offset);
  c.bones[arm.upper].getWorldPosition(shoulder);c.bones[arm.fore].getWorldPosition(fore);c.bones[arm.hand].getWorldPosition(current);
  const a=shoulder.distanceTo(fore),b=fore.distanceTo(current);line.copy(wrist).sub(shoulder);const length=Math.min(a+b-1e-6,Math.max(Math.abs(a-b)+1e-6,line.length()));line.normalize();
  bend.set(arm.sign*.35,-1,-.15).applyQuaternion(basis);bend.addScaledVector(line,-bend.dot(line)).normalize();
  const along=(a*a-b*b+length*length)/(2*length),height=Math.sqrt(Math.max(0,a*a-along*along));elbow.copy(shoulder).addScaledVector(line,along).addScaledVector(bend,height);
  pointBone(arm.upper,arm.fore,elbow);pointBone(arm.fore,arm.hand,wrist);worldRotation(arm.hand,handQ);
 }
 function apply(activity,time=0,blocked=false){
  if(disposed)return false;if(book)book.visible=false;if(cigarette)cigarette.visible=false;lastKind=null;
  if(blocked||!activity||!KINDS.has(activity.kind)||!PHASES.has(activity.phase))return false;
  const age=Number.isFinite(activity.since)?Math.max(0,time-activity.since/1000):1;
  if(Number.isFinite(activity.until)&&time*1000>=activity.until)return false;
  let blend=activity.phase==='finish'?1-clamp(age/.6):clamp(age/.25);
  // Reading ends directly at until in the source, without a finish phase.
  if(activity.kind==='read'&&activity.phase==='active'&&Number.isFinite(activity.until))blend*=THREE.MathUtils.smoothstep((activity.until-time*1000)/1000,0,.6);
  if(blend<=0)return false;
  const kind=activity.kind,t=time+phaseOffset,wave=Math.sin(t*3.1);c.offset.getWorldQuaternion(basis);forward.set(0,0,1).applyQuaternion(basis);right.set(1,0,0).applyQuaternion(basis);
  if(kind==='read'){
   ensureBook();rotate('head',.18*blend,Math.sin(t*.8)*.035*blend);rotate('neck',.06*blend);c.object.updateMatrixWorld(true);
   c.bones.chest.getWorldPosition(center);center.addScaledVector(forward,.27*unit);center.y-=.11*unit;
   local.copy(center);c.offset.worldToLocal(local);book.position.copy(local);book.rotation.set(.34,0,0);book.visible=true;
   for(const arm of sides){local.copy(center).addScaledVector(right,arm.sign*.15*unit);local.y-=.015*unit;reach(arm,local,blend);}
   // During raising/lowering the existing book follows the actual supporting
   // palms. Full-weight reading keeps its authored transform unchanged.
   if(blend<1){c.bones.socket_hand_l.getWorldPosition(from);c.bones.socket_hand_r.getWorldPosition(to);from.add(to).multiplyScalar(.5);from.y+=.015*unit;c.offset.worldToLocal(from);book.position.copy(from);}
  }else if(kind==='smoke'){
   ensureCigarette();const cycle=(t%5)/5,puff=THREE.MathUtils.smoothstep(cycle,.10,.28)*(1-THREE.MathUtils.smoothstep(cycle,.52,.72));
   rotate('head',-.035*puff*blend,Math.sin(t*.7)*.04*blend);c.object.updateMatrixWorld(true);
   c.bones.head.getWorldPosition(center);center.addScaledVector(forward,.15*unit).addScaledVector(right,.075*unit);center.y+=.11*unit;
   c.bones.chest.getWorldPosition(local);local.addScaledVector(forward,.17*unit).addScaledVector(right,.20*unit);local.y-=.13*unit;local.lerp(center,puff);
   reach(sides[1],local,blend);cigarette.visible=true;
  }else{
   const speaker=activity.speaker!==false;rotate('chest',0,wave*.035*blend);rotate('head',Math.sin(t*2.3)*.045*blend,-wave*.04*blend);c.object.updateMatrixWorld(true);
   if(speaker)for(const arm of sides){c.bones.chest.getWorldPosition(local);local.addScaledVector(forward,(.26+wave*.04)*unit).addScaledVector(right,arm.sign*.22*unit);local.y-=.12*unit;reach(arm,local,blend*(.5+arm.sign*Math.sin(t*.8)*.5));}
  }
  c.object.updateMatrixWorld(true);lastKind=kind;applied++;return true;
 }
 function dispose(){if(disposed)return;disposed=true;book?.removeFromParent();cigarette?.removeFromParent();for(const g of geometries)g.dispose();for(const m of materials)m.dispose();}
 return {apply,dispose,diagnostics:()=>({kind:lastKind,applied,resourceBuilds,geometries:geometries.length,materials:materials.length,book:!!book?.visible,cigarette:!!cigarette?.visible,disposed})};
}
