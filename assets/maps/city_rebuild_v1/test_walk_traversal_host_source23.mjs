import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const raw=name=>fs.readFileSync(new URL(name,import.meta.url));
const hostRaw=(environment,fallback)=>fs.readFileSync(path.resolve(process.env[environment]||path.join(here,fallback)));
const text=buffer=>buffer.toString('utf8').replace(/\r\n/g,'\n');
const sha=buffer=>crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
const walkRaw=hostRaw('WALK_PREVIEW_CANDIDATE','walk_preview.mjs'),verticalRaw=hostRaw('BUILDING_VERTICAL_NAVIGATION_CANDIDATE','building_vertical_navigation.mjs');
const walk=text(walkRaw),vertical=text(verticalRaw);
const expectIntegrated=process.argv.includes('--expect-integrated');

const dependencyHashes={
 './pedestrian_surface_passability.mjs':'2F2C37BB16B2CC55BA51EDE9FCB482FE31A2F594F8AE005BDA0AA0D0D8F0FA99',
 './pedestrian_player_route_adapter.mjs':'D4EC20CA9C33285869B4F2031C7B241A3DC3789F2D593EADC82A89D801B2D897',
 './npc_pedestrian_edge_probe.mjs':'42A7BAB538D54E6CDA341FD4E6291835EA3432B923BEE6E73E143120307803CD',
 './hero_airborne_motion_pose.mjs':'1C7499D3E38A2C7C0C59502A55478100B97A7F67106270065208BCBE5CA9CA71',
 './hero_obstacle_motion_pose.mjs':'347C50E4D0785D9E8FF4AF9EA991BA297607345D568AF4AEBA5140772FFF007A',
 './hero_ladder_motion_pose.mjs':'BFDE816739B364D03BF1F0E80998D13137B1E8E9231AF9467795D587B1BD887A',
 './hero_slope_motion_pose.mjs':'9510B0F5A73B83DE9BBF956F88C29980764EC6F13165701BF1CD44CCC7BC5E00',
 './hero_motion_pose_orchestrator.mjs':'C98222D318C66780E58ECEB315882E175631FF5FA93F060437E835B66DE79F39',
 './hero_surface_motion.mjs':'6C6623348EE6BCD233F7C09432801B5B857892EC39F8D7D6AF086F68BC208929',
 './pedestrian_surface_integration_contract.mjs':'791965043990F4605D7E95EE55F8D150B1D83F442E2D1035A0FD60A2BF5CFF22',
 './hero_vehicle_surface.mjs':'4269B7E5B659B50B9E9BDAA3F936A4DB5005DA52F7B3F12C76DA1FE72AEAB334',
 './hero_traversal_world.mjs':'49D3CA9DEECF5C12CCDCFB62BA3F31B7BEE84AF320A0D1AB7BED9BDF62733094',
 './hero_traversal.mjs':'479E7D0B765316006C9438204A121E874CC09D8A4A6D55027CC28A1271982F86',
 './surface_motion.mjs':'A9CACFD619E65DA7F75CFE5AC756A97C003BD0F6D4BBE04D21D7EC6852CCE8F6',
 './roof_ladder.mjs':'A6A2982426053DF4A6AC8B38DB029EC36AF97AFA0FA868787C688BCA8B2B1733',
 './roof_ladder_pose.mjs':'E11ECFFCB1243D9AF6C8F1ACD7DDFFC6D165065B281606D510EB4C9A2EDF1003',
};
for(const [name,expected] of Object.entries(dependencyHashes))assert.equal(sha(raw(name)),expected,`${name} changed after frozen traversal gate`);

const requiredImports=[
 'createHeroSurfaceMotion',
 'createPedestrianPlayerRouteAdapter',
 'createHeroVehicleSurface',
 'createHeroMotionPoseOrchestrator',
 'createHeroMotionPoseApplicator',
 'createSurfaceMotionAirbornePoseAdapter',
 'createBuildingVerticalNavigationPoseAdapter',
];

const checks={
 imports:requiredImports.every(name=>walk.includes(name)),
 alignedSurfaceMotion:/createSurfaceMotion\(\{[^}]*stepHeight\s*:\s*\.34[^}]*maxSlope\s*:\s*2\.35[^}]*snapDown\s*:\s*\.34[^}]*\}\)/s.test(walk),
 vehicleSurfaceFactory:walk.includes('createHeroVehicleSurface({'),
 vehicleSurfaceWorld:/createTraversalWorld\(\{[^;]*vehicleSurface/s.test(walk),
 vehicleSurfaceUpdate:/vehicleSurface\.update\(/.test(walk),
 sharedSurfaceFactory:/createHeroSurfaceMotion\(\{/.test(walk),
 playerRouteFactory:/createPedestrianPlayerRouteAdapter\(\{/.test(walk),
 playerRouteUse:walk.includes('playerRoute.routeInto(playerRouteOutput,heroSurfaceRouteInput,playerRouteWorkspace)')&&walk.includes('heroSurfaceRouteInput.from=before')&&walk.includes('heroSurfaceRouteInput.delta=delta'),
 oneTraversalEntry:walk.includes('beginTraversalPlan('),
 freeFallPreservesY:walk.includes("mode==='free-fall'")&&/surfaceMotion\.update\(/.test(walk),
 poseOrchestratorFactory:/createHeroMotionPoseOrchestrator\(\)/.test(walk),
 poseApplicatorFactory:/createHeroMotionPoseApplicator\(THREE\s*,\s*hero\.artistContext\(\)\)/.test(walk),
 airborneAdapterFactory:/createSurfaceMotionAirbornePoseAdapter\(\)/.test(walk),
 ladderAdapterFactory:/createBuildingVerticalNavigationPoseAdapter\(\)/.test(walk),
 stableVehicleProvider:walk.includes('const heroVehicleSurfaceActors=[];')&&walk.includes('heroVehicleSurfaceActors.length=0')&&walk.includes('getVehicles:()=>heroVehicleSurfaceActors')&&!walk.includes('createHeroVehicleSurface({THREE,getVehicles:()=>[...'),
 stablePoseEnvelope:walk.includes('const heroMotionPoseInput={blocked:')&&walk.includes('motionPoseOrchestrator.update(dt,heroMotionPoseInput)')&&walk.includes('heroMotionPoseInput.blocked.interaction=!!transition||artistBusy()||followGestureOwned')&&walk.includes('heroMotionPoseInput.blocked.water=artistSwimming()||artistSurfaceState?.swim.blend>.1'),
 qaDiagnostics:/const traversalQaDiagnosticsEnabled=new URLSearchParams\(location\.search\)\.get\(['"]traversalqa['"]\)===['"]1['"]/.test(walk)&&walk.includes('now-traversalQaDiagnosticsAt<100')&&walk.includes('document.body.dataset.pedestrianMotion=JSON.stringify(')&&walk.includes('document.body.dataset.heroMotionPose=JSON.stringify(')&&walk.includes('supportId')&&walk.includes('landingCount:heroSurfaceLandingCount'),
 noLegacyTraversalPose:!walk.includes('applyTraversalPose(THREE,hero.artistContext(),jumpFrame)'),
 walkDisablesLegacyLadder:walk.includes('applyLegacyPose:false'),
 verticalLegacyOption:/applyLegacyPose\s*=\s*true/.test(vertical),
 verticalLegacyGuard:/if\s*\(applyLegacyPose\)\s*applyRoofLadderPose/.test(vertical),
};

const integrated=Object.values(checks).every(Boolean);
const integrationSignals=Object.values(checks).filter(Boolean).length;
const mode=integrated?'integrated':integrationSignals===0?'hold':'partial';

if(expectIntegrated){
 assert.equal(mode,'integrated',`host integration incomplete: ${JSON.stringify(checks)}`);
}else{
 // The preparation checkpoint must be all-old or all-new.  A partial state is
 // dangerous because it can combine old collision with new animation owners.
 assert.notEqual(mode,'partial',`partial traversal host patch detected: ${JSON.stringify(checks)}`);
}

if(mode==='hold'){
 // Other owners may add isolated imports/hooks during HOLD.  Lock the exact
 // movement and ladder ownership anchors instead of rejecting their work by
 // whole-file hash.
 assert(walk.includes('const result=movePedestrian(before,delta,allowed);'),'old movement anchor changed during HOLD');
 assert(walk.includes('const surfaceMotion=createSurfaceMotion();'),'old surface-motion limits changed during HOLD');
 assert(walk.includes('const traversalWorld=createTraversalWorld({'),'old traversal-world anchor changed during HOLD');
 assert(!walk.includes('vehicleSurface}),'),'partial vehicle-surface traversal hook detected during HOLD');
 assert(walk.includes('if(verticalNavigation.active)verticalNavigation.pose()'),'old ladder pose anchor changed during HOLD');
 assert(vertical.includes('else pose();'),'confirmed duplicate ladder update anchor changed during HOLD');
}

console.log(JSON.stringify({passed:true,mode,checks,dependencies:Object.keys(dependencyHashes).length,hashes:{walk:sha(walkRaw),vertical:sha(verticalRaw)}}));
