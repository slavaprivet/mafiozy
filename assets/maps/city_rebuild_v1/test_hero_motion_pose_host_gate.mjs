import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const hostPath=path.resolve(process.env.WALK_PREVIEW_CANDIDATE||path.join(here,'walk_preview.mjs'));
const navigationPath=path.resolve(process.env.BUILDING_VERTICAL_NAVIGATION_CANDIDATE||path.join(here,'building_vertical_navigation.mjs'));
const host=fs.readFileSync(hostPath,'utf8'),navigation=fs.readFileSync(navigationPath,'utf8');
const requireIntegrated=process.env.WALK_POSE_REQUIRE_INTEGRATED==='1';
const matches=(source,pattern)=>(source.match(pattern)||[]).length;
function balancedBody(source,anchor,{call=false}={}){
 const at=source.indexOf(anchor);assert.ok(at>=0,`missing semantic anchor: ${anchor}`);
 const first=source.indexOf('(',at+anchor.length);assert.ok(first>=0,`missing arguments: ${anchor}`);
 let depth=0,quote='',escape=false,close=-1;
 for(let i=first;i<source.length;i++){
  const char=source[i];
  if(quote){if(escape)escape=false;else if(char==='\\')escape=true;else if(char===quote)quote='';continue}
  if(char==='"'||char==="'"||char==='`'){quote=char;continue}
  if(char==='(')depth++;else if(char===')'&&--depth===0){close=i;break}
 }
 assert.ok(close>=0,`unterminated arguments: ${anchor}`);
 if(call)return source.slice(first+1,close);
 const open=source.indexOf('{',close);assert.ok(open>=0,`missing function body: ${anchor}`);
 depth=0;quote='';escape=false;
 for(let i=open;i<source.length;i++){
  const char=source[i];
  if(quote){if(escape)escape=false;else if(char==='\\')escape=true;else if(char===quote)quote='';continue}
  if(char==='"'||char==="'"||char==='`'){quote=char;continue}
  if(char==='{')depth++;else if(char==='}'&&--depth===0)return source.slice(open+1,i);
 }
 assert.fail(`unterminated function body: ${anchor}`);
}

for(const [source,pattern,label]of [
 [host,/function applyHudHero\(/,'appearance swap'],
 [host,/hero=await loadHeroWalker\(/,'initial hero load'],
 [host,/createBuildingVerticalNavigation\(/,'vertical-navigation host'],
 [host,/verticalNavigation\.update\(/,'vertical-navigation update'],
 [navigation,/applyRoofLadderPose/,'legacy ladder pose'],
 [navigation,/camera\.position\.add\(/,'ladder camera ownership'],
 [navigation,/controls\.target\.add\(/,'ladder controls ownership'],
])assert.match(source,pattern,`missing current host anchor: ${label}`);

const integrated=/from ['"]\.\/hero_motion_pose_orchestrator\.mjs['"]/.test(host)||/createHeroMotionPoseOrchestrator\s*\(/.test(host);
if(integrated||requireIntegrated){
 const imported=host.match(/import\s*\{([^}]*)\}\s*from ['"]\.\/hero_motion_pose_orchestrator\.mjs['"]/);assert.ok(imported,'complete motion-pose import');
 for(const name of ['createHeroMotionPoseOrchestrator','createHeroMotionPoseApplicator','createSurfaceMotionAirbornePoseAdapter','createBuildingVerticalNavigationPoseAdapter'])assert.match(imported[1],new RegExp(`\\b${name}\\b`),`motion-pose import includes ${name}`);
 assert.equal(matches(host,/createHeroMotionPoseOrchestrator\s*\(/g),1,'one pose orchestrator per host');
 assert.equal(matches(host,/createSurfaceMotionAirbornePoseAdapter\s*\(/g),1,'one surface-airborne observer per host');
 assert.equal(matches(host,/createBuildingVerticalNavigationPoseAdapter\s*\(/g),1,'one ladder adapter per host');
 const navigationArgs=balancedBody(host,'const verticalNavigation=createBuildingVerticalNavigation',{call:true});
 assert.match(navigationArgs,/\bapplyLegacyPose\s*:\s*false\b/,'/walk explicitly disables legacy ladder bone pose');
 assert.match(navigationArgs,/\bmanageLegacyWeapon\s*:\s*false\b/,'/walk explicitly disables legacy ladder weapon management');
 assert.equal(matches(host,/verticalNavigation\.pose\s*\(/g),0,'host must not invoke the legacy ladder pose');
 const frame=balancedBody(host,'function frame');
 const applicatorBinding=host.match(/\b([A-Za-z_$][\w$]*)\s*=\s*createHeroMotionPoseApplicator\s*\(/);assert.ok(applicatorBinding,'host binds a hero-specific pose applicator');
 const applicatorApply=new RegExp(`\\b${applicatorBinding[1]}\\?*\\.apply\\s*\\(`,'g');assert.equal((frame.match(applicatorApply)||[]).length,1,'one orchestrated pose application in the frame');
 assert.match(frame,/adapt(?:BuildingVerticalNavigationSample|Ladder)\s*\(/,'frame adapts authoritative ladder state');

 // External presentation owners establish the final base before the motion
 // applicator. The applicator is therefore the last bone writer only when it
 // actually owns traversal, ladder, airborne, auto-step or slope layers.
 const orchestratorAt=frame.indexOf('motionPoseOrchestrator.update(');assert.ok(orchestratorAt>=0,'frame samples the motion-pose orchestrator');
 for(const [anchor,label]of [
  ['artistUpdate(dt,moved,running)','artist surface/reaction owner'],
  ['heroFollowGesture.apply(','follow-gesture owner'],
  ['applySourceVehiclePresentation(dt)','source-vehicle owner'],
  ['heroCustodyPose.apply(','custody owner'],
 ]){const ownerAt=frame.indexOf(anchor);assert.ok(ownerAt>=0,`frame includes ${label}`);assert.ok(ownerAt<orchestratorAt,`${label} must run before final motion-pose apply`)}
 const orchestratorArgs=balancedBody(host,'motionPoseOrchestrator.update',{call:true}).replace(/\s+/g,'');
 assert.equal(orchestratorArgs,'dt,heroMotionPoseInput','orchestrator consumes one stable host input envelope');
 assert.match(host,/const heroMotionPoseInput=\{blocked:\{death:false,blast:false,vehicle:false,custody:false,interaction:false,water:false,cover:false\}/,'stable pose envelope preallocates every external owner');
 for(const field of ['death','blast','vehicle','custody','interaction','water','cover'])assert.match(frame,new RegExp(`heroMotionPoseInput\\.blocked\\.${field}=`),`frame refreshes blocked.${field}`);
 assert.match(frame,/heroMotionPoseInput\.blocked\.interaction=!!transition\|\|artistBusy\(\)\|\|followGestureOwned/,'health/action and follow gesture are external interaction owners');
 assert.match(frame,/heroMotionPoseInput\.blocked\.water=artistSwimming\(\)\|\|artistSurfaceState\?\.swim\.blend>\.1/,'water owns pose until the residual swim blend clears');
 for(const anchor of ['heroMotionPoseInput.jump.active=','heroMotionPoseInput.traversal.active=','heroMotionPoseInput.ladder=','heroMotionPoseInput.airborne=','heroMotionPoseInput.autoStep.active=','heroMotionPoseInput.slope.grade=','heroMotionPoseInput.weapon.armed='])assert.ok(frame.includes(anchor),`stable pose input refreshes ${anchor}`);
 assert.doesNotMatch(frame,/motionPoseOrchestrator\.update\(dt,\s*\{/,'frame must not allocate a pose envelope');
 assert.match(frame,/const followGestureOwned\s*=\s*heroFollowGesture\.active\s*&&\s*followGestureAllowed\(\)/,'follow gesture ownership is sampled once per frame');
 assert.doesNotMatch(frame,/if\s*\(weaponModel\)\s*weaponModel\.visible\s*=\s*!occupiedSeat\s*&&\s*!transition\s*&&\s*jumpFrame\?\.mode\s*!==\s*['"]traversal['"]/,'generic weapon visibility writer competes with motion owner');
 const weaponApply=balancedBody(host,'function applyMotionPoseWeapon');
 const externalHide=weaponApply.match(/const externalHide\s*=\s*([^;]+);/);assert.ok(externalHide,'motion weapon owner defines externalHide before policy arbitration');
 for(const [pattern,label]of [
  [/!!transition|\btransition\b/,'transition'],
  [/!!heroBlast|\bheroBlast\b/,'blast'],
  [/\bheroCustodyActive\b/,'custody'],
  [/artistSwimming\(\)/,'active water'],
  [/artistSurfaceState\?\.swim\.blend\s*>\s*\.1/,'residual water blend'],
  [/worldHealthFrame\?\.snapshot\.dead/,'death'],
 ])assert.match(externalHide[1],pattern,`externalHide includes ${label}`);
 assert.doesNotMatch(externalHide[1],/occupiedSeat|sourceVehicleActive/,'vehicle/window owner remains external to motion weapon hiding');
 assert.match(weaponApply,/if\s*\(externalHide\)\s*\{\s*weaponModel\.visible\s*=\s*false\s*;?\s*return\s*;?\s*\}/,'external hide is applied atomically');
 const externalHideAt=weaponApply.indexOf('const externalHide'),externalPolicyAt=weaponApply.search(/policy\s*===\s*['"]external['"]/);assert.ok(externalHideAt>=0&&externalPolicyAt>externalHideAt,'external hide runs before external-policy return');
 assert.match(weaponApply,/policy\s*===\s*['"]external['"][^;]*\|\|\s*occupiedSeat\s*\|\|\s*sourceVehicleActive\(\)/,'vehicle/window owner passes through without a competing write');
 assert.match(weaponApply,/policy\s*===\s*['"]holster['"]/,'motion weapon owner handles holster');
 assert.match(weaponApply,/policy\s*===\s*['"]restore['"]/,'motion weapon owner handles restore');
 assert.doesNotMatch(frame,/if\s*\(weaponModel\s*&&\s*transition\)\s*weaponModel\.visible\s*=\s*false/,'transition hide must be centralized in motion weapon arbitration');
 const applicatorAt=frame.search(applicatorApply),weaponAt=frame.indexOf('applyMotionPoseWeapon(');assert.ok(applicatorAt>=0&&weaponAt>applicatorAt,'motion weapon policy is applied after the final bone applicator');

 assert.match(navigation,/applyLegacyPose\s*=\s*true/,'navigation keeps a backwards-compatible legacy pose default');
 assert.match(navigation,/manageLegacyWeapon\s*=\s*true/,'navigation keeps a backwards-compatible legacy weapon default');
 const update=balancedBody(navigation,'function update');
 assert.match(update,/hero\.object\.position\.set\(/,'external presentation preserves navigation root motion');
 assert.match(update,/hero\.object\.rotation\.y\s*=/,'external presentation preserves navigation yaw');
 assert.match(update,/camera\.position\.add\(/,'external presentation preserves camera shift');
 assert.match(update,/controls\.target\.add\(/,'external presentation preserves controls shift');
 const pose=balancedBody(navigation,'function pose');
 assert.match(pose,/applyLegacyPose/,'legacy bone pose is explicitly gated');
 assert.match(pose,/applyRoofLadderPose\s*\(/,'legacy default remains available outside /walk');
 assert.ok(matches(navigation,/manageLegacyWeapon/g)>=4,'legacy capture/hide/restore/reset are all gated by weapon ownership');
 assert.match(balancedBody(navigation,'function begin'),/manageLegacyWeapon/,'weapon capture/hide is gated at ladder begin');
 assert.match(update,/manageLegacyWeapon/,'weapon restore is gated at ladder completion');
 assert.match(pose,/manageLegacyWeapon/,'per-frame legacy weapon hide is gated');
 assert.match(balancedBody(navigation,'function reset'),/manageLegacyWeapon/,'weapon restore is gated on reset');
}

console.log(JSON.stringify({passed:true,status:integrated?'integrated-semantic-gate':'HOLD-ready',integrationDetected:integrated,requireIntegrated,hostPath,navigationPath,wholeFileHashRequired:false,integratedChecks:integrated||requireIntegrated?['single_orchestrator_and_adapters','legacy_pose_disabled_in_walk','legacy_weapon_disabled_in_walk','no_host_legacy_pose_call','single_orchestrated_apply','external_pose_owners_before_final_apply','health_follow_and_water_owner_arbitration','no_competing_generic_weapon_writer','navigation_root_yaw_camera_preserved','legacy_defaults_preserved']:[]}));
