import {sampleHeroAirborneMotion,applyHeroAirborneMotionPose} from './hero_airborne_motion_pose.mjs';
import {sampleHeroObstacleMotion,applyHeroObstacleMotionPose} from './hero_obstacle_motion_pose.mjs';
import {sampleHeroSlopeMotion,applyHeroSlopeMotionPose} from './hero_slope_motion_pose.mjs';
import {applyHeroLadderMotionPose} from './hero_ladder_motion_pose.mjs';

const clamp01=value=>Math.max(0,Math.min(1,Number.isFinite(value)?value:0));
const smoothScalar=(current,target,dt,seconds90)=>target+(current-target)*Math.exp(-Math.max(0,Number.isFinite(dt)?dt:0)/(Math.max(.001,seconds90)/Math.log(10)));
const durations=Object.freeze({ladder:[.45,.26],traversal:[.18,.16],airborne:[.14,.20],'auto-step':[.12,.14],slope:[.18,.22]});
const hardOwnerOrder=['death','blast','vehicle','custody','interaction'];
const layerModes=['ladder','traversal','airborne','auto-step','slope'];
const contactKeys=['handL','handR','footL','footR'];
const contactVerifiedKeys=['handLVerified','handRVerified',null,null];
const makeContact=()=>({x:0,y:0,z:0,blend:0});
const copyContact=(out,value)=>{if(!value)return null;out.x=value.x;out.y=value.y;out.z=value.z;out.blend=value.blend??1;return out};

export function createHeroMotionPoseOrchestrator(){
 const frameLayers=[],weaponFrame={policy:'none',restoreVisible:null},frame={mode:'walk',reason:null,layers:frameLayers,leadFoot:'l',filteredSlopeGrade:0,weapon:weaponFrame};
 const obstacleInput={},slopeInput={},airborneInput={},obstacleSamples={traversal:{},'auto-step':{}},slopeSample={},airborneSample={};
 const ladderContacts={handL:makeContact(),handR:makeContact(),footL:makeContact(),footR:makeContact()},ladderData={handL:null,handR:null,footL:null,footR:null,presentationScale:.44},slots=layerModes.map(mode=>({mode,weight:0,data:mode==='ladder'?ladderData:mode==='traversal'?obstacleSamples.traversal:mode==='auto-step'?obstacleSamples['auto-step']:mode==='slope'?slopeSample:airborneSample,present:false}));
 let filteredGrade=0,lastTarget='walk',leadFoot='l',actionKey=null,holstered=false,restoreWeaponVisible=true;
 const slotFor=mode=>slots[layerModes.indexOf(mode)];
 function clear(){for(const slot of slots){slot.weight=0;slot.present=false}frameLayers.length=0;filteredGrade=0;lastTarget='walk';actionKey=null}
 function blocked(reason,external,weapon){const restore=holstered&&!external?restoreWeaponVisible:null;clear();holstered=false;frame.mode='blocked';frame.reason=reason;frameLayers.length=0;frame.leadFoot=leadFoot;frame.filteredSlopeGrade=0;weaponFrame.policy=external?'external':restore===null?'none':'restore';weaponFrame.restoreVisible=restore;return frame}
 function update(dt,input={}){
  dt=Math.max(0,Number.isFinite(dt)?dt:0);const owners=input.blocked||{};let hardOwner=null;for(let i=0;i<hardOwnerOrder.length;i++)if(owners[hardOwnerOrder[i]]){hardOwner=hardOwnerOrder[i];break}
  const weapon=input.weapon||{},armed=!!weapon.armed;
  if(hardOwner)return blocked(hardOwner,true,weapon);
  if(input.jump?.active||owners.jump)return blocked('jump',true,weapon);
  if(dt===0){let owner='walk';if(input.traversal?.active)owner='traversal';else if(input.airborne?.active&&input.airborne.source!=='surface')owner='airborne';else if(input.ladder?.active)owner='ladder';else if(owners.water)return blocked('water',true,weapon);else if(owners.cover)return blocked('cover',false,weapon);else if(input.airborne?.active)owner='airborne';else if(input.autoStep?.active)owner='auto-step';else if(Math.abs(input.slope?.grade||0)>.42)owner='slope';if(owner!==lastTarget)frameLayers.length=0;lastTarget=owner;frame.mode=owner;frame.reason=null;return frame}
  const slope=input.slope||{},rawGrade=Number.isFinite(slope.grade)?Math.max(-1.15,Math.min(1.15,slope.grade)):0;
  filteredGrade=smoothScalar(filteredGrade,rawGrade,dt,.12);
  let target='walk',data=null;
  if(input.traversal?.active){target='traversal';const t=input.traversal,key=t.actionId??t.startedAt??'traversal';if(key!==actionKey){actionKey=key;leadFoot=t.leadSide==='r'?'r':t.leadSide==='l'?'l':leadFoot}const contacts=t.contacts||t;obstacleInput.kind=t.kind;obstacleInput.progress=t.progress;obstacleInput.obstacleHeight=t.obstacleHeight;obstacleInput.leadSide=leadFoot;obstacleInput.direction=t.direction;obstacleInput.edge=t.edge;obstacleInput.start=t.start;obstacleInput.handL=contacts.handLVerified?t.handL:null;obstacleInput.handR=contacts.handRVerified?t.handR:null;obstacleInput.armed=armed;data=sampleHeroObstacleMotion(obstacleInput,obstacleSamples.traversal);}
  else if(input.airborne?.active&&input.airborne.source!=='surface'){target='airborne';const a=input.airborne.sample||input.airborne;airborneInput.verticalVelocity=a.verticalVelocity;airborneInput.airborneAge=a.airborneAge;airborneInput.fallDistance=a.fallDistance;airborneInput.landingAge=a.landingAge;airborneInput.landingDuration=a.landingDuration;airborneInput.impactSpeed=a.impactSpeed;airborneInput.armed=armed;data=sampleHeroAirborneMotion(airborneInput,airborneSample);}
  else if(input.ladder?.active){target='ladder';const next=input.ladder.sample||input.ladder,contacts=input.ladder.contacts||input.ladder;ladderData.phase=next.phase||0;ladderData.phaseName=next.phaseName;ladderData.direction=next.direction;ladderData.sliding=next.sliding;ladderData.blend=next.blend;ladderData.yaw=next.yaw;ladderData.weaponPolicy='holster';for(let keyIndex=0;keyIndex<contactKeys.length;keyIndex++){const key=contactKeys[keyIndex],verifiedKey=contactVerifiedKeys[keyIndex],allowed=!verifiedKey||contacts[verifiedKey],value=allowed?next[key]:null;ladderData[key]=value?copyContact(ladderContacts[key],value):null}data=ladderData;}
  else if(owners.water)return blocked('water',true,weapon);
  else if(owners.cover)return blocked('cover',false,weapon);
  else if(input.airborne?.active){target='airborne';const a=input.airborne.sample||input.airborne;airborneInput.verticalVelocity=a.verticalVelocity;airborneInput.airborneAge=a.airborneAge;airborneInput.fallDistance=a.fallDistance;airborneInput.landingAge=a.landingAge;airborneInput.landingDuration=a.landingDuration;airborneInput.impactSpeed=a.impactSpeed;airborneInput.armed=armed;data=sampleHeroAirborneMotion(airborneInput,airborneSample);}
  else if(input.autoStep?.active){target='auto-step';const step=input.autoStep,key=step.actionId??step.startedAt??'auto-step';if(key!==actionKey){actionKey=key;leadFoot=step.leadSide==='r'?'r':step.leadSide==='l'?'l':leadFoot}obstacleInput.kind='auto-step';obstacleInput.progress=step.progress;obstacleInput.obstacleHeight=step.obstacleHeight;obstacleInput.leadSide=leadFoot;obstacleInput.direction=step.direction;obstacleInput.edge=step.edge;obstacleInput.start=step.start;obstacleInput.handL=null;obstacleInput.handR=null;obstacleInput.armed=armed;data=sampleHeroObstacleMotion(obstacleInput,obstacleSamples['auto-step']);}
  else {actionKey=null;slopeInput.slopeGrade=filteredGrade;slopeInput.blend=null;const targetBlend=sampleHeroSlopeMotion(slopeInput,slopeSample).targetBlend;const slopeSlot=slotFor('slope');if(Math.abs(rawGrade)>.42||(slopeSlot.present&&Math.abs(rawGrade)>.001)){target='slope';const contacts=slope.contacts||slope;slopeInput.slopeGrade=filteredGrade;slopeInput.blend=targetBlend;slopeInput.gaitPhase=slope.gaitPhase;slopeInput.gaitWeight=slope.gaitWeight;slopeInput.moving=slope.moving;slopeInput.armed=armed;slopeInput.footL=slope.footL;slopeInput.footR=slope.footR;slopeInput.handL=contacts.handLVerified?slope.handL:null;slopeInput.handR=contacts.handRVerified?slope.handR:null;data=sampleHeroSlopeMotion(slopeInput,slopeSample);}}
  if(lastTarget!==target&&(lastTarget==='traversal'||lastTarget==='auto-step'))leadFoot=leadFoot==='l'?'r':'l';
  lastTarget=target;
  if(target!=='walk'){const layer=slotFor(target);layer.present=true;layer.data=data}
  frameLayers.length=0;for(const layer of slots){if(!layer.present)continue;const active=layer.mode===target,[rise,fall]=durations[layer.mode]||[.12,.16];layer.weight=smoothScalar(layer.weight,active?1:0,dt,active?rise:fall);if(!active&&layer.weight<1e-4){layer.present=false;layer.weight=0;continue}layer.weight=clamp01(layer.weight);frameLayers.push(layer)}
  let policy='none';for(const layer of frameLayers)if(layer.weight>.01&&layer.data?.weaponPolicy==='holster')policy='holster';else if(policy==='none'&&layer.data?.weaponPolicy==='carry-safe')policy='carry-safe';
  let restore=null;if(policy==='holster'){if(!holstered)restoreWeaponVisible=weapon.visible!==false;holstered=true}else if(holstered){restore=restoreWeaponVisible;holstered=false;policy='restore'}
  frame.mode=target;frame.reason=null;frame.leadFoot=leadFoot;frame.filteredSlopeGrade=filteredGrade;weaponFrame.policy=policy;weaponFrame.restoreVisible=restore;return frame;
 }
 return {update,reset(){clear();holstered=false;restoreWeaponVisible=true;leadFoot='l'},get state(){return {mode:lastTarget,filteredSlopeGrade:filteredGrade,leadFoot,holstered,layers:slots.filter(x=>x.present).map(x=>({mode:x.mode,weight:x.weight}))}}};
}

// Exact adapter for the current `building_vertical_navigation.state` shape.
// Integration must disable its old `applyRoofLadderPose` call for that frame;
// applying both old and orchestrated ladder poses is invalid.
export function createBuildingVerticalNavigationPoseAdapter(){
 const sample={handL:null,handR:null,footL:null,footR:null},contacts={handLVerified:false,handRVerified:false},result={active:true,sample,contacts},targets={handL:makeContact(),handR:makeContact(),footL:makeContact(),footR:makeContact()};
 return function adapt(frame,{contactsVerified=true}={}){const pose=frame?.pose;if(!frame?.active||!pose)return null;const blend=clamp01(pose.handBlend??1);sample.phaseName=pose.phaseName||((frame.sliding||pose.sliding)?'slide':pose.direction<0?'climb-down':'climb-up');sample.phase=Number.isFinite(pose.phase)?pose.phase:0;sample.direction=pose.direction<0?-1:1;sample.sliding=!!(frame.sliding||pose.sliding);sample.blend=blend;sample.yaw=pose.yaw;sample.weaponPolicy='holster';for(let i=0;i<contactKeys.length;i++){const key=contactKeys[i],value=pose[key];sample[key]=value?copyContact(targets[key],value):null;if(sample[key])sample[key].blend=blend}contacts.handLVerified=!!contactsVerified;contacts.handRVerified=!!contactsVerified;return result};
}
const defaultVerticalNavigationAdapter=createBuildingVerticalNavigationPoseAdapter();
export function adaptBuildingVerticalNavigationSample(frame,options){return defaultVerticalNavigationAdapter(frame,options)}

// Presentation adapter for ordinary ledge falls driven by surfaceMotion. It
// observes grounded/y/velocityY only and never changes collision or root motion.
export function createSurfaceMotionAirbornePoseAdapter({landingDuration=.34}={}){
 const input={},sample={},result={active:false,source:'surface'};let wasGrounded=true,airborneAge=0,fallDistance=0,startY=0,landingAge=Infinity,impactSpeed=0;
 function reset(surface={}){wasGrounded=surface.grounded!==false;airborneAge=0;fallDistance=0;startY=Number.isFinite(surface.y)?surface.y:0;landingAge=Infinity;impactSpeed=0;result.active=false;delete result.sample;return result}
 function update(dt,surface={},weapon={}){dt=Math.max(0,Number.isFinite(dt)?dt:0);const grounded=surface.grounded!==false,y=Number.isFinite(surface.y)?surface.y:startY,velocityY=Number.isFinite(surface.velocityY)?surface.velocityY:0;if(!grounded){if(wasGrounded){airborneAge=0;fallDistance=0;startY=y;landingAge=Infinity}airborneAge+=dt;fallDistance=Math.max(fallDistance,startY-y);impactSpeed=Math.max(impactSpeed,-velocityY);input.verticalVelocity=velocityY;input.airborneAge=airborneAge;input.fallDistance=fallDistance;input.landingAge=null;input.landingDuration=landingDuration;input.impactSpeed=impactSpeed;input.armed=!!weapon.armed;result.active=true;result.sample=sampleHeroAirborneMotion(input,sample)}else if(!wasGrounded||landingAge<landingDuration){if(!wasGrounded)landingAge=0;else landingAge+=dt;input.verticalVelocity=0;input.airborneAge=airborneAge;input.fallDistance=fallDistance;input.landingAge=landingAge;input.landingDuration=landingDuration;input.impactSpeed=impactSpeed;input.armed=!!weapon.armed;result.active=landingAge<=landingDuration;result.sample=result.active?sampleHeroAirborneMotion(input,sample):null}else{result.active=false;result.sample=null}wasGrounded=grounded;return result}
 return {update,reset,get state(){return {wasGrounded,airborneAge,fallDistance,landingAge,impactSpeed}}};
}

function solveLayer(THREE,context,layer){
 switch(layer.mode){
  case 'slope':return applyHeroSlopeMotionPose(THREE,context,layer.data);
  case 'auto-step':case 'traversal':return applyHeroObstacleMotionPose(THREE,context,layer.data);
  case 'airborne':return applyHeroAirborneMotionPose(THREE,context,layer.data);
  case 'ladder':return applyHeroLadderMotionPose(THREE,context,layer.data);
  default:return false;
 }
}

// Reusable bone cross-fader. Each layer is solved from the exact same host base
// pose, then blended; no layer owns root position/yaw or physics state.
export function createHeroMotionPoseApplicator(THREE,context){
 if(!THREE||!context?.bones)throw Error('Hero pose applicator needs THREE and artist context');
 const entries=Object.entries(context.bones),count=entries.length,maxLayers=5;
 const base=entries.map(()=>({p:new THREE.Vector3(),q:new THREE.Quaternion(),s:new THREE.Vector3()}));
 const solved=Array.from({length:maxLayers},()=>entries.map(()=>new THREE.Quaternion()));
 const pivotSolved=Array.from({length:maxLayers},()=>({p:new THREE.Vector3(),q:new THREE.Quaternion()}));
 const pivotBase={p:new THREE.Vector3(),q:new THREE.Quaternion()},composite=new THREE.Quaternion(),result=new THREE.Quaternion(),pivotComposite=new THREE.Quaternion(),scratchP=new THREE.Vector3(),scratchS=new THREE.Vector3(),position=new THREE.Vector3(),activeLayers=new Array(maxLayers),weights=new Float64Array(maxLayers),applyResult={applied:false,layerCount:0,coverage:0};
 function captureBase(){for(let i=0;i<count;i++)entries[i][1].matrix.decompose(base[i].p,base[i].q,base[i].s);pivotBase.p.copy(context.visualPivot.position);pivotBase.q.copy(context.visualPivot.quaternion)}
 function restoreBase(){for(let i=0;i<count;i++){const bone=entries[i][1];bone.matrix.compose(base[i].p,base[i].q,base[i].s);bone.matrixWorldNeedsUpdate=true}context.visualPivot.position.copy(pivotBase.p);context.visualPivot.quaternion.copy(pivotBase.q);context.object.updateMatrixWorld(true)}
 function apply(frame){
  captureBase();let layerCount=0,total=0;const source=frame?.layers;if(source)for(let i=0;i<source.length&&layerCount<maxLayers;i++)if(source[i].weight>1e-6){activeLayers[layerCount]=source[i];weights[layerCount]=clamp01(source[i].weight);total+=weights[layerCount++]}for(let l=0;l<layerCount;l++){restoreBase();solveLayer(THREE,context,activeLayers[l]);for(let i=0;i<count;i++)entries[i][1].matrix.decompose(scratchP,solved[l][i],scratchS);pivotSolved[l].p.copy(context.visualPivot.position);pivotSolved[l].q.copy(context.visualPivot.quaternion)}
  restoreBase();const coverage=Math.min(1,total);
  if(total>1e-8)for(let i=0;i<count;i++){let accumulated=0;for(let l=0;l<layerCount;l++){const w=weights[l];if(accumulated===0)composite.copy(solved[l][i]);else composite.slerp(solved[l][i],w/(accumulated+w));accumulated+=w}result.copy(base[i].q).slerp(composite,coverage);entries[i][1].matrix.compose(base[i].p,result,base[i].s);entries[i][1].matrixWorldNeedsUpdate=true}
  if(total>1e-8){let accumulated=0;pivotComposite.copy(pivotBase.q);position.copy(pivotBase.p);for(let l=0;l<layerCount;l++){const w=weights[l];if(accumulated===0){pivotComposite.copy(pivotSolved[l].q);position.copy(pivotSolved[l].p)}else{const ratio=w/(accumulated+w);pivotComposite.slerp(pivotSolved[l].q,ratio);position.lerp(pivotSolved[l].p,ratio)}accumulated+=w}context.visualPivot.quaternion.copy(pivotBase.q).slerp(pivotComposite,coverage);context.visualPivot.position.copy(pivotBase.p).lerp(position,coverage)}
  context.object.updateMatrixWorld(true);applyResult.applied=layerCount>0;applyResult.layerCount=layerCount;applyResult.coverage=coverage;return applyResult;
 }
 return {apply};
}

