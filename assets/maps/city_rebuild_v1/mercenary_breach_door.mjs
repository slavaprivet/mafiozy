// Local QA world object. Source profession logic owns the action clock, hit
// interruption, planted charge, safe retreat and permission to call these effects.
export function createMercenaryBreachDoor({THREE,site,groundHeight=()=>0,onCollisionChange,onBlast=()=>{}}={}){
 if(!site?.id)throw new TypeError('Breach door requires a stable id');
 const id=site.id,object=new THREE.Group(),leaf=new THREE.Group();object.name='Mercenary_Locked_Service_Door';object.position.set(site.x,site.y??groundHeight(site.x,site.z),site.z);object.rotation.y=site.yaw||0;
 leaf.name='Breach_Door_Hinged_Leaf';leaf.position.set(-1,0,0);object.add(leaf);
 const geometry=new THREE.BoxGeometry(1,1,1),wood=new THREE.MeshStandardMaterial({color:0x77503a,roughness:.86}),metal=new THREE.MeshStandardMaterial({color:0x475355,metalness:.65,roughness:.57}),lockMetal=new THREE.MeshStandardMaterial({color:0xab925c,metalness:.7,roughness:.4}),owned=[];
 const matrix=new THREE.Matrix4(),quaternion=new THREE.Quaternion(),point=new THREE.Vector3(),scale=new THREE.Vector3();
 function boxes(parent,parts,material,name){const mesh=new THREE.InstancedMesh(geometry,material,parts.length);mesh.name=name;mesh.castShadow=mesh.receiveShadow=true;for(let i=0;i<parts.length;i++){const [p,s]=parts[i];matrix.compose(point.fromArray(p),quaternion,scale.fromArray(s));mesh.setMatrixAt(i,matrix);}mesh.computeBoundingSphere();parent.add(mesh);owned.push(mesh);return mesh;}
 boxes(object,[[[-1.105,1.3,0],[.21,2.6,.24]],[[1.105,1.3,0],[.21,2.6,.24]],[[0,2.5,0],[2, .20,.24]]],metal,'Service_Door_Steel_Frame');
 boxes(leaf,Array.from({length:8},(_,i)=>[[.124+i*.25,1.21,0],[.246,2.38,.12]]),wood,'Thick_Timber_Door_Planks');
 // The decorative 4 mm plank seams must not turn a solid locked door into
 // holes for command picking. The centre inspection ray lands on such a seam.
 // This shares the physical leaf dimensions and follows its hinge, but never
 // renders or casts a shadow; it also cannot visually occlude NPC badges.
 const pickMaterial=new THREE.MeshBasicMaterial({visible:false}),pickSurface=new THREE.Mesh(geometry,pickMaterial);pickSurface.name='Breach_Door_Command_Surface';pickSurface.position.set(1,1.21,0);pickSurface.scale.set(2,2.38,.16);pickSurface.userData.mercenaryPickProxy=true;leaf.add(pickSurface);
 boxes(leaf,[[[1,.40,-.075],[1.96,.085,.034]],[[1,1.99,-.075],[1.96,.085,.034]],[[.05,1.19,0],[.06,2.4,.15]]],metal,'Door_Reinforcement_Straps');
 boxes(leaf,[[[1.72,1.02,-.089],[.11,.23,.045]],[[1.76,1.06,-.145],[.21,.038,.06]]],lockMetal,'Door_Handle_And_Lock');
 const latch=boxes(object,[[[.98,1.02,-.095],[.13,.09,.08]]],lockMetal,'Breakable_Lock_Strike');
 const fragment=boxes(object,[[[0,0,0],[.13,.09,.08]]],lockMetal,'Broken_Lock_Fragment');fragment.visible=false;fragment.position.set(.98,1.02,-.095);
 const frameBoxes=[{p:[-1.105,1.3,0],s:[.21,2.6,.24]},{p:[1.105,1.3,0],s:[.21,2.6,.24]},{p:[0,2.5,0],s:[2,.2,.24]}],leafBox={p:[1,1.21,0],s:[2,2.38,.16]},sweepBox={p:[-.31,1.21,.95],s:[2.82,2.38,2.30]},scratch=new THREE.Vector3();
 let disposed=false,opened=false,active=false,elapsed=0,angle=0,colliders=[],mode=null;
 function body(box,node,key){node.updateWorldMatrix(true,false);const[pX,pY,pZ]=box.p,[w,h,d]=box.s,polygonCR=[];let minYM=Infinity,maxYM=-Infinity;
  for(const[x,z]of[[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]]){scratch.set(pX+x,pY-h/2,pZ+z).applyMatrix4(node.matrixWorld);polygonCR.push([scratch.x/4.1,scratch.z/4.1]);minYM=Math.min(minYM,scratch.y);scratch.set(pX+x,pY+h/2,pZ+z).applyMatrix4(node.matrixWorld);maxYM=Math.max(maxYM,scratch.y);}
  return{id:key,mercenaryBreachDoor:id,polygonCR,minYM,maxYM,interiorFurniture:true};
 }
 object.updateMatrixWorld(true);colliders=frameBoxes.map((b,i)=>body(b,object,id+':frame:'+i));colliders.push(body(leafBox,leaf,id+':leaf'));
 const meta={id,kind:'door',label:'Запертая дверь',locked:true,lockable:true,lockpickable:false,breachable:true,bombable:true,workRange:.08,highlightBounds:{min:[-1.22,0,-.18],max:[1.22,2.61,.16]},getApproachPosition(){object.updateWorldMatrix(true,false);return object.localToWorld(new THREE.Vector3(.6,0,-1.08));},getWorkPoint(){return object.localToWorld(new THREE.Vector3(.6,.85,-.08));},getWorkNormal(){object.updateWorldMatrix(true,false);return new THREE.Vector3(0,0,-1).transformDirection(object.matrixWorld);}};
 object.userData.mercenaryTarget=meta;object.userData.locked=true;
 const accepted=r=>r===true||r?.ok===true;
 const change=value=>{try{return accepted(onCollisionChange(value));}catch{return false;}};
 function open(kind,effect={}){
  if(disposed)return{ok:false,reason:'disposed'};if(effect.targetId&&effect.targetId!==id)return{ok:false,reason:'wrong_target'};if(opened)return{ok:true,duplicate:true,opened:true,targetId:id};if(typeof onCollisionChange!=='function')return{ok:false,reason:'collision_not_connected'};
  // Reserve the complete moving-leaf volume for this short animation. Two
  // collision transactions (start/end), rather than rebuilding the city index
  // on every visual frame; nobody can walk through the moving door's arc.
  const old=colliders.at(-1),next=body(sweepBox,object,id+':leaf-sweep');
  if(!change({removed:[old],added:[next],context:{...effect,kind:'breach_door_open',method:kind}}))return{ok:false,reason:'collision_rejected'};
  colliders[colliders.length-1]=next;opened=true;active=true;mode=kind;meta.locked=object.userData.locked=false;meta.opened=object.userData.mercenaryOpened=true;meta.breachable=meta.bombable=false;latch.visible=false;fragment.visible=true;
  if(kind==='blast')try{onBlast({targetId:id,kind:'breach_door_blast',position:object.getWorldPosition(new THREE.Vector3()),effect});}catch{/* accepted physical change remains accepted if cosmetic FX fails */}
  return{ok:true,opened:true,breached:true,targetId:id};
 }
 function update(dt){if(disposed||!active)return false;const nextTime=Math.min(.8,elapsed+Math.max(0,Math.min(.1,Number(dt)||0))),t=nextTime/.8,nextAngle=-Math.PI*108/180*(1-(1-t)**3);if(nextTime===elapsed)return false;
  leaf.rotation.y=nextAngle;
  if(t===1){const next=body(leafBox,leaf,id+':leaf');if(!change({removed:[colliders.at(-1)],added:[next],context:{kind:'breach_door_motion',targetId:id}})){leaf.rotation.y=angle;leaf.updateMatrixWorld(true);return false;}colliders[colliders.length-1]=next;}
  elapsed=nextTime;angle=nextAngle;fragment.position.set(.98+.22*t,Math.max(.05,1.02-1.65*t*t),-.095-.30*t);fragment.rotation.set(t*4.2,0,t*2.3);active=t<1;return true;
 }
 const breakOpen=effect=>open('kick',effect),blast=effect=>open('blast',effect);Object.assign(meta,{breakOpen,blast});
 return{object,leaf,breakOpen,blast,update,get colliders(){return colliders;},get needsUpdate(){return active&&!disposed;},getState:()=>({id,opened,locked:!opened,opening:active,mode,angle}),getTargets:()=>disposed?[]:[{id,kind:'door',object}],dispose(){if(disposed)return;disposed=true;active=false;object.removeFromParent();for(const mesh of owned)mesh.dispose();geometry.dispose();wood.dispose();metal.dispose();lockMetal.dispose();pickMaterial.dispose();}};
}
