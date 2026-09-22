// Presentation only. Host calls after walker.update, before hit/death overlays.
// Source owns targets, pathfinding, timers and effects; this never changes HP or position.
const KINDS={breach_door:'kick',revive:'heal',unlock_safe:'unlock',unlock_door:'unlock',cut_fence:'cut',disable_power:'power',plant_bomb:'plant',heal:'heal',unlock:'unlock',cut:'cut',plant:'plant',intimidate:'intimidate'};
const clamp=v=>Math.max(0,Math.min(1,v));
const smooth=(a,b,v)=>{const n=clamp((v-a)/(b-a));return n*n*(3-2*n);};
const finitePoint=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z);
export function createMercenaryPose({THREE,walker}){
 const c=walker.artistContext(),tools=new THREE.Group(),mount=c.bones.socket_hand_r||c.bones.hand_r;tools.name='Mercenary_Tools';tools.visible=false;mount.add(tools);
 // Tool dimensions are metres, independent of the male/female source GLB scale.
 const mountScale=new THREE.Vector3();mount.getWorldScale(mountScale);tools.scale.setScalar(1/Math.max(.001,mountScale.x));
 const geometry=new THREE.BoxGeometry(1,1,1),steel=new THREE.MeshStandardMaterial({color:0x545c60,roughness:.65,metalness:.55}),grip=new THREE.MeshStandardMaterial({color:0x352d28,roughness:.9}),cloth=new THREE.MeshStandardMaterial({color:0xeee5cf,roughness:1});
 const cylinder=new THREE.CylinderGeometry(1,1,1,12),cone=new THREE.ConeGeometry(1,1,8),blue=new THREE.MeshBasicMaterial({color:0x77cfff,toneMapped:false}),hot=new THREE.MeshBasicMaterial({color:0xffcf70,toneMapped:false});
 const props={};
 function part(group,scale,position,material=steel){const m=new THREE.Mesh(geometry,material);m.scale.set(...scale);m.position.set(...position);m.castShadow=true;m.receiveShadow=true;group.add(m);return m;}
 function prop(name){const g=new THREE.Group();g.name='Mercenary_'+name;g.visible=false;tools.add(g);props[name]=g;return g;}
 part(prop('heal'),[.12,.065,.09],[0,.04,.04],cloth);
 const lock=prop('unlock');part(lock,[.014,.18,.014],[0,.085,.035]);part(lock,[.035,.065,.035],[0,0,.035],grip);
 const cutter=prop('cut');cutter.name='Mercenary_Cutting_Torch';
 const bottle=new THREE.Mesh(cylinder,grip);bottle.name='Torch_Small_Fuel_Cylinder';bottle.scale.set(.05,.24,.05);bottle.position.set(0,-.15,.01);bottle.castShadow=bottle.receiveShadow=true;cutter.add(bottle);
 part(cutter,[.07,.035,.07],[0,-.02,.01]);part(cutter,[.035,.09,.10],[0,.02,.025],grip);part(cutter,[.026,.026,.53],[0,.045,.325]);part(cutter,[.04,.04,.04],[0,.045,.59]);
 const flame=new THREE.Group();flame.name='Torch_Contact_Flame';flame.position.set(0,.045,.61);flame.visible=false;cutter.add(flame);
 for(const [radius,length,material]of[[.010,.075,blue],[.004,.051,hot]]){const jet=new THREE.Mesh(cone,material);jet.scale.set(radius,length,radius);jet.rotation.x=Math.PI/2;jet.position.z=length/2;jet.userData.mercenaryPickIgnore=true;flame.add(jet);}
 const sparks=new THREE.InstancedMesh(geometry,hot,6);sparks.name='Torch_Contact_Sparks';sparks.frustumCulled=false;sparks.visible=false;sparks.userData.mercenaryPickIgnore=true;cutter.add(sparks);
 const sparkMatrix=new THREE.Matrix4(),sparkPosition=new THREE.Vector3(),sparkScale=new THREE.Vector3(),sparkQuaternion=new THREE.Quaternion();
 const charge=prop('plant');part(charge,[.19,.12,.055],[0,.035,.04],grip);part(charge,[.10,.04,.015],[0,.045,.075]);
 const probe=prop('power');part(probe,[.025,.13,.025],[0,.04,.04],grip);part(probe,[.009,.10,.009],[0,.15,.04]);
 let disposed=false,applied=0,lastKind=null,contactError=null,contactActive=false,stage=null,kickExtension=1;
 const footL=new THREE.Vector3(),footR=new THREE.Vector3(),inv=new THREE.Matrix4(),kickSupport=new THREE.Vector3(),kickStart=new THREE.Vector3(),kickGoal=new THREE.Vector3(),kickQ=new THREE.Quaternion(),supportQ=new THREE.Quaternion(),kickShinRest=new THREE.Vector3(),kickFootRest=new THREE.Vector3();
 const contact=new THREE.Vector3(),normal=new THREE.Vector3(),forward=new THREE.Vector3(),palmTarget=new THREE.Vector3(),supportTarget=new THREE.Vector3(),currentPalm=new THREE.Vector3(),tip=new THREE.Vector3(),toolOffset=new THREE.Vector3(),rootPosition=new THREE.Vector3(),stowed=new THREE.Vector3(),axisZ=new THREE.Vector3(0,0,1);
 const toolQ=new THREE.Quaternion(),handQ=new THREE.Quaternion(),leftQ=new THREE.Quaternion(),socketQ=new THREE.Quaternion(),rootQ=new THREE.Quaternion();
 const gaitPosition=new THREE.Vector3(),gaitScale=new THREE.Vector3(),gaitRotation=new THREE.Quaternion(),gaitSpread=new THREE.Quaternion();
 function spreadWalkingThigh(name,angle){const bone=c.bones[name];if(!bone)return;bone.matrix.decompose(gaitPosition,gaitRotation,gaitScale);gaitRotation.multiply(gaitSpread.setFromAxisAngle(axisZ,angle));bone.matrix.compose(gaitPosition,gaitRotation,gaitScale);bone.matrixWorldNeedsUpdate=true;}
 if(c.rest?.socket_hand_r)socketQ.copy(c.rest.socket_hand_r.q).invert();
 function contactPose(action,kind,progress,time,weight){
  if(kind==='kick'||!finitePoint(action.workPoint)||typeof c.reachPalm!=='function'||!c.bones.socket_hand_r)return;
  contact.copy(action.workPoint);c.object.getWorldPosition(rootPosition);c.object.getWorldQuaternion(rootQ);
  if(finitePoint(action.workNormal))normal.copy(action.workNormal);else normal.copy(rootPosition).sub(contact).setY(0);if(normal.lengthSq()<1e-8)normal.set(0,0,-1).applyQuaternion(rootQ);normal.normalize();forward.copy(normal).negate();
  const cutting=kind==='cut',engage=smooth(.08,.25,progress)*(1-smooth(.85,.97,progress)),blend=weight*engage;
  if(cutting){
   stage=progress<.25?'draw':progress>.85?'stow':'contact';
   // Source point is on the metal. Only sweep along the wire plane: the flame
   // never gets moved away from the surface to imitate a distant successful cut.
   contact.y+=Math.sin(smooth(.25,.85,progress)*Math.PI*3)*.035;
   toolQ.setFromUnitVectors(axisZ,forward);handQ.copy(toolQ).multiply(socketQ);
   toolOffset.set(0,.045,.68).applyQuaternion(toolQ);palmTarget.copy(contact).sub(toolOffset);
   stowed.set(.24,.78,.07).applyQuaternion(rootQ).add(rootPosition);palmTarget.lerpVectors(stowed,palmTarget,engage);currentPalm.setFromMatrixPosition(c.bones.socket_hand_r.matrixWorld);palmTarget.lerpVectors(currentPalm,palmTarget,weight);
  }else{
   c.bones.hand_r.getWorldQuaternion(handQ);palmTarget.copy(contact);
   if(kind==='heal')palmTarget.y+=(.5+.5*Math.sin(time*10))*.015;
   if(kind==='unlock')palmTarget.addScaledVector(normal,.02);
   currentPalm.setFromMatrixPosition(c.bones.socket_hand_r.matrixWorld);palmTarget.lerpVectors(currentPalm,palmTarget,blend);
  }
  c.reachPalm('r',palmTarget,handQ);
  if(c.bones.socket_hand_l){
   if(finitePoint(action.supportPoint))supportTarget.copy(action.supportPoint);
   else if(cutting)supportTarget.set(-.025,-.11,.01).applyQuaternion(toolQ).add(palmTarget);
   else{supportTarget.copy(contact);toolOffset.set(-.12,kind==='heal'?0:.08,0).applyQuaternion(rootQ);supportTarget.add(toolOffset);}
   currentPalm.setFromMatrixPosition(c.bones.socket_hand_l.matrixWorld);supportTarget.lerpVectors(currentPalm,supportTarget,blend);c.bones.hand_l.getWorldQuaternion(leftQ);c.reachPalm('l',supportTarget,leftQ);
  }
  c.object.updateMatrixWorld(true);
  if(cutting){
   tip.set(0,.045,.68);tools.localToWorld(tip);contactError=tip.distanceTo(contact);contactActive=progress>=.25&&progress<=.85&&contactError<.065;
   flame.visible=sparks.visible=contactActive;
   if(contactActive){flame.scale.set(1,1,.94+.06*Math.sin(time*29));for(let i=0;i<6;i++){const age=(time*2.8+i/6)%1,spread=Math.sin(i*2.4);sparkPosition.set(spread*age*.065,.045-age*age*.10,.68+Math.cos(i*1.8)*age*.035);sparkScale.set(.003,.014*(1-age)+.002,.003);sparkMatrix.compose(sparkPosition,sparkQuaternion,sparkScale);sparks.setMatrixAt(i,sparkMatrix);}sparks.instanceMatrix.needsUpdate=true;}
  }
 }
 function feetMin(){c.object.updateMatrixWorld(true);inv.copy(c.object.matrixWorld).invert();footL.setFromMatrixPosition(c.bones.foot_l.matrixWorld).applyMatrix4(inv);footR.setFromMatrixPosition(c.bones.foot_r.matrixWorld).applyMatrix4(inv);return Math.min(footL.y,footR.y);}
 function apply(action,time=0,moving=false){
  if(disposed)return false;
  tools.visible=false;flame.visible=sparks.visible=false;for(const p of Object.values(props))p.visible=false;lastKind=null;contactError=null;contactActive=false;stage=null;kickExtension=1;
  const kind=KINDS[action?.kind];if(!kind)return false;
  // The source supplies real retreat movement. Add urgency to the existing run,
  // never teleport the actor or play an in-place escape during planting.
  if(kind==='plant'&&action.phase==='retreat'){c.rotate('chest',.14,0,0);c.rotate('head',-.08,0,0);lastKind='retreat';applied++;return true;}
  if(!['working','acting'].includes(action.phase))return false;
  // Approach/retreat preserve ordinary walking. Each work pose begins with the host's
  // fresh walker pose; no saved clothing/skin reset and no accumulating offsets.
  const progress=clamp(Number.isFinite(action.progress)?action.progress:0),weight=clamp(progress/.08)*clamp((1-progress)/.06),t=Number.isFinite(time)?time:0,pulse=Math.sin(t*7),s=walker.height/1.9;
  if(weight<=0)return false;
  const floor=feetMin(),r=(name,x=0,y=0,z=0)=>c.rotate(name,x*weight,y*weight,z*weight);
  if(kind!=='intimidate'&&kind!=='power'&&kind!=='kick'){
   r('thigh_l',-1.05);r('shin_l',1.6);r('foot_l',-.48);
   r('thigh_r',kind==='unlock'?-.95:-.35);r('shin_r',kind==='unlock'?1.55:1.65);r('foot_r',-.45);
   r('chest',.30);r('neck',-.06);r('head',.15);
  }
  if(kind==='kick'){
   // Source working progress owns the beat: brace, chamber, one late heel strike.
   // No synthetic movement or impact event: only the source completes the door.
   const chamber=smooth(.66,.86,progress),strike=smooth(.91,.955,progress),returning=smooth(.982,1,progress);kickExtension=1+.40*strike*(1-returning);
   stage=progress<.66?'brace':progress<.91?'chamber':progress<.982?'strike':'recover';
   c.object.updateMatrixWorld(true);c.bones.foot_l.getWorldPosition(kickSupport);c.bones.foot_r.getWorldPosition(kickStart);c.bones.foot_l.getWorldQuaternion(supportQ);c.bones.foot_r.getWorldQuaternion(kickQ);
   r('chest',(-.20*chamber+.28*strike)*(1-returning),0,-.055*chamber);r('upperarm_l',-.25,0,-.25);r('forearm_l',-.7);r('upperarm_r',-.45,0,.22);r('forearm_r',-.9);r('head',.04);
   if(finitePoint(action.workPoint)&&typeof c.reachFoot==='function'){
    c.object.getWorldQuaternion(rootQ);forward.set(0,0,1).applyQuaternion(rootQ);
    // Visual pelvis follows the planted leg; world position/collision root stays fixed.
    c.visualPivot.position.z+=.34*chamber*(1-returning);c.visualPivot.position.y-=.20*chamber*(1-returning);
    c.object.updateMatrixWorld(true);c.reachFoot('l',kickSupport,supportQ);
    kickGoal.copy(kickStart).addScaledVector(forward,.18*chamber);kickGoal.y+=.54*chamber;
    contact.copy(action.workPoint);contact.y=Math.min(contact.y,kickStart.y+.52);contact.addScaledVector(forward,-.20);kickGoal.lerp(contact,strike);kickGoal.lerp(kickStart,returning);
    // A short stylised extension was requested. Temporarily adjust only the
    // kicking leg's IK lengths; restore shared rest immediately, even on error.
    // The next ordinary walker reset restores the posed matrices exactly.
    kickShinRest.copy(c.rest.shin_r.p);kickFootRest.copy(c.rest.foot_r.p);
    try{
     c.rest.shin_r.p.multiplyScalar(kickExtension);c.rest.foot_r.p.multiplyScalar(kickExtension);
     c.rotate('shin_r');c.rotate('foot_r');c.object.updateMatrixWorld(true);c.reachFoot('r',kickGoal,kickQ);
    }finally{c.rest.shin_r.p.copy(kickShinRest);c.rest.foot_r.p.copy(kickFootRest);}
    c.object.updateMatrixWorld(true);c.bones.foot_r.getWorldPosition(tip);contactError=tip.distanceTo(contact);contactActive=strike>.9&&returning<.1&&contactError<.16;
   }
  }else if(kind==='heal'){
   // Assess first, compress with straight elbows, dress the wound, then offer a
   // supporting hand. These distinct beats follow source progress, not new timers.
   const assess=progress<.18,bandage=progress>.64,help=progress>.88,compression=.5+.5*Math.sin(t*10);
   r('chest',assess?.3:help?.18:.42+(bandage?pulse*.025:compression*.055));
   r('upperarm_l',help?-.70:-1.05,0,-.12);r('upperarm_r',assess?-.80:help?-1.2:-1.05,0,.12);
   r('forearm_l',-.20+(bandage?pulse*.13:0));r('forearm_r',assess?-.75:help?-.45:-.20+(bandage?-pulse*.13:0));
   r('hand_r',0,bandage?pulse*.35:0);c.visualPivot.position.y-=(bandage?0:compression*.022)*s*weight;
  }else if(kind==='unlock'){
   const listen=progress<.25,turn=progress>.72;
   r('upperarm_l',-.9,0,-.2);r('forearm_l',-.55);r('upperarm_r',turn?-1.05:-.95,0,.12);r('forearm_r',turn?-.38:-.6);r('hand_r',0,Math.sin(t*(turn?2:4))*(turn?.75:.24),.15);
   r('head',listen?.03:.12,listen?-.25:0,listen?.14:0);r('chest',turn?-.06:0);
  }else if(kind==='cut'){
   const draw=smooth(.05,.25,progress)*(1-smooth(.85,.98,progress)),trace=Math.sin(progress*Math.PI*3)*.06+Math.sin(t*3)*.012;
   r('upperarm_l',-.48-draw*.45+trace,0,-.17);r('upperarm_r',-.32-draw*.63+trace,0,.14);r('forearm_l',-.65);r('forearm_r',-.5);r('chest',.24+draw*.24);r('head',.17);
  }else if(kind==='plant'){
   const attach=progress<.4,wire=progress<.83;
   r('chest',attach?.50:.38);r('upperarm_l',-.85,0,-.23);r('forearm_l',-.5);r('upperarm_r',attach?-.95:-1.05,0,.13);r('forearm_r',-.25+Math.sin(t*(wire?5:2))*(wire?.035:.08));r('hand_r',wire?0:-.25,wire?pulse*.08:0);r('head',.22);
  }else if(kind==='power'){
   // Inspect terminals standing up, then grip and firmly lower the isolator.
   const pull=clamp((progress-.66)/.26);r('chest',.12);r('head',.10);r('upperarm_l',-.9,0,-.16);r('forearm_l',-.6);r('upperarm_r',-1.1+pull*.3,0,.13);r('forearm_r',-.35-pull*.35);r('hand_r',pull*.4,pull?0:pulse*.08);
  }else{
   // Broad stance and a deliberate raised fist; source handles intimidation result.
   if(moving){spreadWalkingThigh('thigh_l',-.12*weight);spreadWalkingThigh('thigh_r',.12*weight);}
   else{r('thigh_l',0,0,-.12);r('thigh_r',0,0,.12);}
   r('chest',-.06,Math.sin(t*2)*.04);
   r('upperarm_l',-.22,0,-.3);r('forearm_l',-.7);r('upperarm_r',-.65,0,.48);r('forearm_r',-1.25);r('head',-.08);
  }
  // Constant-cost ankle reference maintains the actor's floor height. Never scan
  // skinned vertices per frame or update the complete game scene.
  if(kind!=='kick')c.visualPivot.position.y+=floor-feetMin();c.object.updateMatrixWorld(true);
  contactPose(action,kind,progress,t,weight);
  if(props[kind]&&!(kind==='plant'&&progress>.86)&&!(kind==='heal'&&progress<.64)&&!(kind==='power'&&progress>.66)){tools.visible=true;props[kind].visible=true;}
  lastKind=kind;applied++;return true;
 }
 function dispose(){if(disposed)return;disposed=true;tools.removeFromParent();sparks.dispose();for(const g of[geometry,cylinder,cone])g.dispose();for(const m of[steel,grip,cloth,blue,hot])m.dispose();}
 return {apply,dispose,stats:()=>({disposed,applied,kind:lastKind,geometries:disposed?0:3,materials:disposed?0:5,props:disposed?0:5,stage,kickExtension,contactActive,contactError,sparks:lastKind==='cut'&&contactActive?6:0})};
}
