import {createNpcLogicalVehicleBinding} from './npc_logical_vehicle_binding.mjs';
import {installNativeTerrainRaycastIndex} from './native_terrain_raycast_index.mjs';
import {installBuildingCameraTriangleIndex} from './building_camera_triangle_index.mjs';
import {createHeroCustodyVehiclePose} from './hero_custody_vehicle_pose.mjs';
import {createWalkLifeInterrupt} from './walk_life_interrupt.mjs';
import {createWorldTrafficPresentation,npcVehicleBlocks,worldTrafficProfile} from './world_traffic_presentation.mjs';
import {createRenderFreezeQa,allowRenderFreeze} from './render_freeze_qa.mjs';
import {createRenderIsolationQa} from './render_isolation_qa.mjs';
import {installWalkDebugPanels} from './walk_debug_panels.mjs';
import {createVehicleShadowCulling,vehicleShadowCullingEnabled} from './vehicle_shadow_culling.mjs';
import {setVehicleRenderDetailOptimization} from './vehicle_render_batches.mjs';
import {createMercenaryWalk} from './mercenary_walk.mjs';
import {createMercenaryFences} from './mercenary_fences.mjs';
import {createMercenaryPowerPanel} from './mercenary_power_panel.mjs';
import {createMercenaryProfessionShowcase} from './mercenary_profession_showcase.mjs';
import {createVehicleEntryHighlight} from './vehicle_entry_highlight.mjs';
import {createMercenaryShowcaseUI} from './mercenary_showcase_ui.mjs';
import {createHeroFollowGesture} from './hero_follow_gesture.mjs';
import {createNpcRuntimeInspection} from './npc_runtime_inspection.mjs';
import {createNpcNativeNavigation} from './npc_native_navigation.mjs';
import {createNpcSupportCache} from './npc_support_cache.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
import {createNpcServiceDestinations} from './npc_service_destinations.mjs';
import {createNpcDetentionAccess} from './npc_detention_access.mjs';
import {createNpcResidentBuildingAccess} from './npc_resident_building_access.mjs';
import {createNpcNativePerception} from './npc_native_perception.mjs';
import {createNpcVehicleAccessResolver} from './npc_vehicle_access.mjs';
import {createWorldVehiclePlayerAccess} from './world_vehicle_player_access.mjs';
import {createWorldVehiclePlayerPose} from './world_vehicle_player_pose.mjs';
import {createVehicleHijackPose} from './vehicle_hijack_pose.mjs';
import {createVehicleImpactView} from './vehicle_impact_view.mjs';
import {createVehicleOccupantImpactPose} from './vehicle_impact_reaction.mjs';
import {createVehicleVisualQa} from './vehicle_visual_qa.mjs';
import {createIndoorCamera} from './indoor_camera.mjs';
import {createIndoorHeroVisibility} from './hero_visibility.mjs';
import {buildingDoorPrompt} from './building_prompt.mjs';
import {createBuildingVerticalNavigation} from './building_vertical_navigation.mjs';
import {createWaterInteractionEffects} from './water_interaction_fx.mjs';
import {stepVehicleWater,mergeWaterDriveEffects,resetVehicleWater} from './vehicle_water_state.mjs';
import {vehicleWaterDeparturePoint,vehicleWaterSeatPoint,createVehicleWaterExitSurface,canAscendFromVehicle} from './vehicle_water_exit.mjs';
import {createVehicleWaterVapor} from './vehicle_water_vapor.mjs';
import {createWaterInteractionInputSampler} from './water_interaction_inputs.mjs';
import {isWaterVehicleAccess,waterVehicleSurfaceAt,WATER_VEHICLE_ACCESS} from './water_vehicle_access.mjs';
import {findWaterJumpInspection,createWaterImpactCapture,createWaterInspectionPanel} from './water_inspection.mjs';
import {createWalkHudController} from './walk_hud_controller.mjs';
import {createNpcPopulation,npcWeaponId} from './npc_population.mjs';
import {createNpcShotEffects} from './npc_shot_effects.mjs';
import {createNpcTrafficVehicleBinding} from './npc_vehicle_pose.mjs';
import {createWorldWalkCombat} from './world_walk_combat.mjs';
import {createWorldWalkHealth,worldWalkHealthSurfaceReceipt,synchronizeWorldWalkHealthSurface} from './world_walk_health.mjs';
import {createWorldWalkMeleeInput} from './world_walk_melee_input.mjs';
import {createWorldWalkMeleeHost} from './world_walk_melee_host.mjs';
import {createNpcGalleryHost} from './npc_gallery_host.mjs';
import {clone as cloneNpcSkeleton} from './vendor/three_skeleton_utils.mjs';
// Standalone inspection or presentation of the existing world runtime through Mafiozi3DBridge.


import * as THREE from 'three';
import {ensureVehicleExitVisible} from './vehicle_exit_camera.mjs';


import {createArtist14Input} from './hero_artist14_input.mjs';


import {createArtist14Surface} from './hero_artist14_surface.mjs';
import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createVehicleFleet} from './vehicle_fleet.mjs';
import {loadArtistFleetModels,createArtistVehicle} from './vehicle_fleet_models.mjs';
import {setVehicleWheelRenderOptimization} from './vehicle_wheel_render_batches.mjs';
import {createBlastResponse} from './blast_response.mjs';
import {stepBlastKnockback} from './vehicle_blast_motion.mjs';
import {createVehicleRollover} from './vehicle_rollover.mjs';



import {installFastWalkStartup} from './point_light_loop.mjs';
import {createWalkPerformanceProbe} from './walk_performance_probe.mjs';


import {OrbitControls} from 'three/addons/controls/OrbitControls.js';


import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';


import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {RoundedBoxGeometry} from 'three/addons/geometries/RoundedBoxGeometry.js';
import {vehicleWindowFrame,planVehicleWindowShot,applyVehicleWindowPose,setVehicleWindowOpen} from './vehicle_window_fire.mjs';
import {CAR,createDemoCar,carFits,stepCar,createCarWorld,carCorners,pointInPolygon,carOverlapsCircle,DRIVER_SEAT} from './car_drive.mjs';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
import {advanceEntryHold,entryPose,TRANSITION_SECONDS,HOLD_SECONDS,EXIT_HOLD_SECONDS} from './car_entry.mjs';
import {createTireTracks} from './tire_tracks.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';


import {resolveBuildingCameraPosition} from './building_entry.mjs';


import {EXIT,planMovingExit,departurePoint,launchExitBody,stepExitBody} from './car_exit.mjs';


import {loadHeroWalker} from './hero_walk.mjs';


import {createHeroPosture,requestHeroPosture,resetHeroPosture,stepHeroPosture,posturePresentation} from './hero_posture.mjs';


import {LANDING_POSTURE_SECONDS} from './hero_pose_transition.mjs';
import {JUMP,jumpDirection,launchJump,stepJump,tryDiveJump} from './hero_jump.mjs';
import {planTraversal,stepTraversal} from './hero_traversal.mjs';
import {createTraversalWorld} from './hero_traversal_world.mjs';
import {nativePedestrianLand} from './native_pedestrian_surface.mjs';
import {createVehicleExitSurface,createExitPoseFloorSampler,createExitSwimHandoff} from './vehicle_exit_surface.mjs';
import {applyTraversalPose} from './hero_traversal_pose.mjs';
import {installTraversalQa} from './hero_traversal_qa.mjs';


import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';


import {createWeaponHud} from './weapon_hud.mjs';


import {createWeaponInventory} from './weapon_inventory.mjs';
import {createGroundWeapons,nearestWeaponDrop} from './ground_weapons.mjs';
import {createWeaponCrosshair} from './weapon_crosshair.mjs';
import {createWeaponRecoilView} from './weapon_recoil_view.mjs';
import {createWeaponFireState,stepWeaponFire,sampleWeaponRecoil,weaponFireProfile} from './hero_weapon_fire.mjs';
import {createHeroCover} from './hero_cover_host.mjs';
import {installCoverQa} from './hero_cover_qa.mjs';
import {coverCameraShoulder} from './hero_cover_camera.mjs';
import {COVER_MOVE_SPEED,coverElapsedTime} from './hero_cover_motion.mjs';
import {vehicleOpaqueCoverHeight} from './hero_cover_contact.mjs';
import {vehicleCoverPolygon} from './vehicle_cover_edges.mjs';
import {sourceVehicleCoverBodies} from './hero_source_vehicle_cover.mjs';
import {sourceVehicleEscapeId} from './hero_source_vehicle_escape.mjs';


import {createWeaponEffects,resolveWeaponShotTransforms} from './weapon_effects.mjs';


import {initCarPhysicsQa} from './car_physics_qa.mjs';


import {VEHICLE_SEATS,vehicleSeat,vehicleSeatPoint,vehicleDoorPoint,findVehicleEntry,vehicleEntryPoint,vehicleDeparturePoint,planVehicleSeatExit,canControlVehicle,inputForVehicleSeat} from './vehicle_seats.mjs';


import {createVehicleDamage} from './vehicle_damage.mjs';


import {createGlassBreakage} from './glass_breakage.mjs';


import {circleFits,movePedestrian} from './walk_motion.mjs';


import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createIncrementalWalkCollisionIndex,updateWalkEntryCollisionGroups} from './incremental_walk_collision_index.mjs';
import {collectNearbyBuildingEntries} from './building_entry_broadphase.mjs';
import {createRaycastRootIndex} from './raycast_root_index.mjs';
import {createStableEntryLights} from './stable_entry_lights.mjs';
import {applyCloneVisibilityMask,applyTemplateVisibilityMask,maskSignature} from './template_visibility_mask.mjs';
import {createSurfaceMotion,resolveJumpSurface} from './surface_motion.mjs';


import {residentialWindowCacheStats} from './residential_windows.mjs';


import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {createStreetLighting} from './street_lighting.mjs';
import {createStaticRenderBatches} from './static_render_batches.mjs';
import {createTyreDamage} from './tyre_damage.mjs';
import {createLandscapeTerrain} from './landscape_terrain.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';
import {createExplorationRailway,withRailwayVehicleWorld} from './exploration_railway.mjs';
import {planExplorationDecor} from './exploration_decor_plan.mjs';
import {planExplorationDecorAsync} from './exploration_decor_worker_client.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {createExplorationDecor} from './exploration_decor.mjs';
import {createEnvironmentVisuals} from './environment_visuals.mjs';
import {createGrassActorContact} from './grass_actor_contact.mjs';
import {planEnvironmentVisualsAsync} from './environment_planning_worker_client.mjs';
import {createExplorationMinimap,normalizeNativeInstances,mapKind,explorationNpcMapMarkers} from './exploration_minimap.mjs';
import {createExplorationWaypointVisual,reachedExplorationWaypoint} from './exploration_waypoint_visual.mjs';
import {createExplorationVehicleWorld,poseVehicleOnLandscape} from './exploration_vehicle_support.mjs';
import {explorationKeepouts,resolveLandscapeCamera} from './exploration_scene_support.mjs';
const walkShell=window.MafioziWalkShell||document;
const walkDebugPanels=installWalkDebugPanels({document,href:location.href,releaseControls:()=>releaseControls()});
addEventListener('pagehide',()=>walkDebugPanels?.dispose(),{once:true});
const $=id=>walkShell.getElementById(id), M=4.1, root='/assets/maps/city_rebuild_v1/';
const exitQaMode=new URLSearchParams(location.search).get('carexitqa')==='1';
const staticRenderBatching=new URLSearchParams(location.search).get('renderbatch')!=='0';
let exitQaPaused=false;
const scene=new THREE.Scene();scene.background=new THREE.Color('#bfd1d6');scene.fog=new THREE.Fog('#bfd1d6',180,550);


const camera=new THREE.PerspectiveCamera(45,innerWidth/innerHeight,.2,1500);


const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});



const startup=installFastWalkStartup({THREE,renderer,scene,camera,isReady:()=>!!hero&&!!car});
let vehicleShadowCulling=null,vehicleShadowQaButton=null;
const staticMatrixOptimization=staticRenderBatching&&allowRenderFreeze(location.href)&&new URLSearchParams(location.search).get('staticmatrix')==='1';
const wheelRenderOptimization=allowRenderFreeze(location.href)&&new URLSearchParams(location.search).get('wheelbatched')==='1'&&renderer.extensions.has('WEBGL_multi_draw');
const performanceProbe=new URLSearchParams(location.search).get('perfqa')==='1'?createWalkPerformanceProbe({renderer,scene,document,getStartup:()=>startup.report}):null;
const renderFreezeQa=createRenderFreezeQa({applyStaticMatrices:staticMatrixOptimization?enabled=>{staticRenderBatches?.setLocalMatrixOptimizationEnabled(enabled);if(staticRenderBatches)document.body.dataset.staticRenderBatches=JSON.stringify(staticRenderBatches.stats());}:undefined,document,window,camera,probe:performanceProbe,isReady:()=>startup.report.phase==='rendered'&&!busy,releaseControls:()=>releaseControls(),applyVehicleWheels:wheelRenderOptimization?enabled=>{for(const root of [...(fleet?.records||[]).map(record=>record.car.object),...(worldTrafficPresentation?.getActors()||[]).map(record=>record.object)])setVehicleWheelRenderOptimization(root,enabled);}:undefined,applyVehicleDetails:renderer.extensions.has('WEBGL_multi_draw')?enabled=>{for(const root of [...(fleet?.records||[]).map(record=>record.car.object),...(worldTrafficPresentation?.getActors()||[]).map(record=>record.object)])setVehicleRenderDetailOptimization(root,enabled);}:undefined,onHoldStart:()=>{npcPopulation?.markPoseInterrupted();resetVehicleShadowQa();},onHoldEnd:()=>{renderIsolationQa?.stop('hold ended');resetVehicleShadowQa();},getSnapshot:()=>{let npc={};try{npc=JSON.parse(document.body.dataset.npcWorld||'{}')}catch{}return {pixelRatio:renderer.getPixelRatio(),width:renderer.domElement.width,height:renderer.domElement.height,feet:hero?.object.position.toArray(),npc:{seen:npc.seen,visible:npc.visible,pending:npc.pending},traffic:{actors:npc.traffic?.actors,loading:npc.traffic?.loading},note:'Fixed 3D presentation only; source world continues; not gameplay FPS'};}});
addEventListener('pagehide',()=>renderFreezeQa?.dispose(),{once:true});
const renderIsolationQa=createRenderIsolationQa({document,window,renderer,camera,probe:performanceProbe,freeze:renderFreezeQa,getTargets:mode=>{
 if(mode==='residents')return (npcPopulation?.getActors()||[]).map(record=>record.object);
 if(mode==='vehicles')return [...(fleet?.records||[]).map(record=>record.car.object),...(worldTrafficPresentation?.getActors()||[]).map(record=>record.object)];
 const targets=[];scene.traverse(node=>{const data=node.userData||{};if(mode==='pointlights'&&node.isPointLight||mode==='water'&&node.isMesh&&(data.nativeTerrainKind==='water'||data.landscapeWater===true||data.surfaceKind==='water'||data.environmentSurface==='water')||mode==='interiors'&&(data.renderIsolationInteriorFurnishings||/^Interior_Furnishings_/.test(node.name||'')))targets.push(node);});return targets;
}});
addEventListener('pagehide',()=>renderIsolationQa?.dispose(),{once:true});
addEventListener('pagehide',()=>{vehicleShadowCulling?.dispose();vehicleShadowQaButton?.remove();performanceProbe?.dispose();},{once:true});


renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.setSize(innerWidth,innerHeight);


renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;


renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;


$('viewport').append(renderer.domElement);


const pmrem=new THREE.PMREMGenerator(renderer),room=new RoomEnvironment();


const environment=pmrem.fromScene(room,.04);scene.environment=environment.texture;scene.environmentIntensity=.45;room.dispose();pmrem.dispose();


const ambient=new THREE.HemisphereLight('#e8f3ff','#889973',.8);scene.add(ambient);


const sun=new THREE.DirectionalLight('#fff0d4',1.7);sun.position.set(-75,130,90);sun.castShadow=true;


sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});sun.shadow.bias=-.0003;sun.shadow.normalBias=.04;scene.add(sun,sun.target);
// Conservative vehicle-only shadow rejection is accepted by default. Keep an
// explicit URL rollback for visual diagnosis without changing any content.
if(vehicleShadowCullingEnabled(location.search))vehicleShadowCulling=createVehicleShadowCulling({THREE,renderer,scene,sun,onSample:performanceProbe?stats=>{document.body.dataset.vehicleShadowCulling=JSON.stringify(stats);}:undefined});
function resetVehicleShadowQa(){vehicleShadowCulling?.setEnabled(true);if(vehicleShadowQaButton)vehicleShadowQaButton.textContent='Тени машин: отсечение невидимых · сравнить';}
if(vehicleShadowCulling&&renderFreezeQa){
 vehicleShadowQaButton=document.createElement('button');vehicleShadowQaButton.id='vehicle-shadow-qa';vehicleShadowQaButton.type='button';vehicleShadowQaButton.style.cssText='position:fixed;top:122px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px;max-width:90vw';document.body.append(vehicleShadowQaButton);resetVehicleShadowQa();
 vehicleShadowQaButton.onclick=()=>{if(!renderFreezeQa.active){vehicleShadowQaButton.textContent='Сначала зафиксируйте 3D-сцену';return;}const enabled=!vehicleShadowCulling.stats.enabled;vehicleShadowCulling.setEnabled(enabled);vehicleShadowQaButton.textContent=enabled?'Тени машин: отсечение невидимых · сравнить':'Тени машин: прежняя отрисовка · сравнить';performanceProbe?.reset();};
}


const controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.maxPolarAngle=Math.PI*.92;controls.minDistance=3;controls.maxDistance=16;controls.rotateSpeed=.65;


controls.target.set(60*M,0,30*M);camera.position.copy(controls.target).add(new THREE.Vector3(45,75,95));


const loader=new GLTFLoader(),templates=new Map(),content=new THREE.Group();scene.add(content);


let topology=null,instances=[],bodies=[],loaded=0,failed=0,busy=false,walking=false,revision='',lastLoadAt=0,hero=null;
let walkPlayerHud=null,hudAppearanceHero=null;
let mercenaryWalk=null;
let mercenaryFences=null;
let mercenaryPowerPanel=null;
let mercenaryShowcase=null,mercenaryShowcaseUI=null;
const entryDoorHighlight=createVehicleEntryHighlight({THREE});
addEventListener('pagehide',()=>entryDoorHighlight.dispose(),{once:true});
const mercenaryInputBlocked=()=>worldHealthFrame?.inputsBlocked===true||walkPlayerHud?.isBlocked()===true;
const hudInputBlocked=()=>mercenaryInputBlocked()||mercenaryWalk?.isOpen===true;
let buildingEntries=[],carBodies=[],buildingKeyConsumed=false,buildingQaMove=null,cameraBeforeBuildingClamp=null;
const indoorCamera=createIndoorCamera({THREE,resolvePosition:resolveBuildingCameraPosition});
const indoorHeroVisibility=createIndoorHeroVisibility({THREE,getHero:()=>hero,getWeapon:()=>weaponModel});
let buildingCameraIndexes=[],buildingCameraIndexBuildMs=0,buildingCameraIndexGeneration=0;
let buildingCameraIndexEnabled=new URLSearchParams(location.search).get('buildingcameraindex')!=='0';
window.MafioziBuildingCameraIndex={
 setEnabled(enabled){buildingCameraIndexEnabled=!!enabled;for(const h of buildingCameraIndexes)h.setEnabled(buildingCameraIndexEnabled);const state=this.stats();document.body.dataset.buildingCameraIndex=JSON.stringify(state);performanceProbe?.reset();return state;},
 stats(){return {ready:buildingCameraIndexes.length>0,enabled:buildingCameraIndexEnabled,generation:buildingCameraIndexGeneration,buildMs:buildingCameraIndexBuildMs,meshes:buildingCameraIndexes.length,triangles:buildingCameraIndexes.reduce((n,h)=>n+h.stats.triangles,0),queries:buildingCameraIndexes.reduce((n,h)=>n+h.stats.queries,0),fallbacks:buildingCameraIndexes.reduce((n,h)=>n+h.stats.fallbacks,0)};}
};
let indoorCameraFrame=null,indoorCameraDiagnosticsAt=-Infinity; 
let entryBodyVersions=new Map(),walkCollisionIndex=null,buildingSampleIndex=null;
const walkCollisionDiagnostic=performanceProbe?{at:-Infinity,index:null,stats:null}:null;
let stableEntryLights=null,staticRenderBatches=null,shotRaycastIndex=null;
const nativeTerrainPickingRequested=new URLSearchParams(location.search).get('nativepick')!=='0';
let nativeTerrainRaycastIndexes=[],nativeTerrainPickingEnabled=nativeTerrainPickingRequested,nativeTerrainPickingBuildMs=0,nativeTerrainPickingGeneration=0;
window.MafioziNativeTerrainPicking={
 get ready(){return nativeTerrainRaycastIndexes.length>0;},
 get enabled(){return nativeTerrainPickingEnabled&&nativeTerrainRaycastIndexes.length>0;},
 get generation(){return nativeTerrainPickingGeneration;},
 setEnabled(enabled){nativeTerrainPickingEnabled=!!enabled;for(const handle of nativeTerrainRaycastIndexes)handle.setEnabled(nativeTerrainPickingEnabled);return this.stats();},
 stats(){return {requested:nativeTerrainPickingRequested,enabled:this.enabled,generation:nativeTerrainPickingGeneration,buildMs:nativeTerrainPickingBuildMs,meshes:nativeTerrainRaycastIndexes.length,indices:nativeTerrainRaycastIndexes.map(handle=>({...handle.stats}))};}
};
let environmentVisuals=null;
let laneRouteJobs=null;
let cityRoadNavigation=null,cityRoadStaticWorld=null,mapRoadRouteAt=-Infinity,mapRoadRouteOrigin=null,mapRoadRouteTarget=null;
function laneRoutingSnapshot(){
 const plan=environmentVisuals?.roadPlan;
 return {metresPerCell:M,topology,bodies:carBodies,roadPlan:{trafficPlan:plan.preparedLaneGraph.plan,preparedLaneGraph:plan.preparedLaneGraph,serviceAccess:plan.serviceAccess},parkingPlan:environmentVisuals.parkingPlan,instances:instances.map(group=>{const i=group.userData.instance;return {id:i.id,role:i.role,entry:i.entry,footprint:i.footprint,stopFootprint:i.stopFootprint,transform:i.role==='district_detention'?{yawDegrees:i.transform?.yawDegrees}:undefined};})};
}
let grassContactHero=null,grassActorContact=null;
const noGrassContact={actorPosition:null,actorFeet:[],actorGround:null};
function grassHeroContact(){
 if(!hero?.object.visible||occupiedSeat||transition||jump||heroBlast||verticalNavigation.active||artistSwimming())return noGrassContact;
 const position=hero.object.position,ground=landscape?.groundHeight(position.x,position.z)??0;
 if(Math.abs(position.y-ground)>.3)return noGrassContact;
 if(grassContactHero!==hero){grassActorContact=createGrassActorContact({THREE,hero,getGroundHeight:(x,z)=>landscape?.groundHeight(x,z)??0});grassContactHero=hero;}
 return {actorPosition:position,...grassActorContact.update()};
}
let waterEffects=null,waterInspection=null,waterInspectionEntry=null,waterInspectionDriveUntil=0,waterTeleported=false,waterFailureCapture=false,waterInspectionExitRemaining=0;
const waterInputs=createWaterInteractionInputSampler({THREE});
let waterVapor=null;
function poseWalkVehicle(vehicle,state,rollAngle=0,dt=0){
 poseVehicleOnLandscape(THREE,vehicle,state,explorationSurface,rollAngle);
 return stepVehicleWater({THREE,car:vehicle,state,waterAt,terrain:explorationSurface,dt,rollAngle});
}
const waterImpactCapture=createWaterImpactCapture();
function captureWaterInspection(dt){
 if(!waterInspection||!waterEffects)return;
 const stats=waterEffects.stats();
 if(waterImpactCapture.update(dt,waterFailureCapture?(carState?.waterState?.flooded?1:0):stats.impacts)){
  releaseControls();waterInspectionDriveUntil=0;
  if(waterFailureCapture&&car&&carState){
   const target=carLocal(0,(car.profile?.length||5)*.3,0);target.y=Math.max(target.y,carState.waterState?.waterLevel??target.y)+.65;
   const yaw=carState.yaw;controls.target.copy(target);camera.position.copy(target).add(new THREE.Vector3(Math.sin(yaw)*7+Math.cos(yaw)*6,4,Math.cos(yaw)*7-Math.sin(yaw)*6));camera.lookAt(controls.target);
  }
  document.body.dataset.waterInteractions=JSON.stringify(stats);document.body.dataset.vehicleWaterVapor=JSON.stringify(waterVapor?.stats()||{});
  waterInspection.setStatus(waterFailureCapture?'Мотор затоплен · тяга отключена · пар затухает · нажмите «Продолжить»':'Стоп-кадр реального контакта · капель '+stats.activeDroplets+' · кругов '+stats.activeRings+' · нажмите «Продолжить»');
 }
}
function updateWaterInteractions(dt){
 if(!waterEffects)return;
 const actors=waterInputs.sample({hero,records:fleet?.records||[],occupiedSeat,transition,dt,teleport:waterTeleported});waterTeleported=false;
 waterEffects.update(dt,{...actors,focus:hero?.object.position||controls.target});
 environmentVisuals?.setWaterRipples(waterEffects.getRipples());
}
function initWaterInspection(){
 if(waterInspection||window.Mafiozi3DBridge||new URLSearchParams(location.search).get('waterqa')!=='1')return;
 const prepare=()=>{releaseControls();waterImpactCapture.reset();waterFailureCapture=false;waterInspectionExitRemaining=0;waterInspectionDriveUntil=0;if(occupiedSeat&&carState){carState.speed=0;fleet?.syncActive(carState);}occupiedSeat=null;transition=null;jump=null;heroBlast=null;verticalNavigation.reset();resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);artistSurface?.reset();hero.reset();hero.object.rotation.set(0,0,0);setWalking(true);$('scene-menu').hidden=true;setArsenalOpen(false);setFreeMouse(false);waterInputs.reset();waterTeleported=true;for(const id of ['district','walk','reload'])$(id).disabled=false;};
 waterInspection=createWaterInspectionPanel({document,onShore(){
  if(!hero||busy)return;const entry=findWaterJumpInspection(landscape,pedestrianAllowed);if(!entry){waterInspection.setStatus('Свободный берег не найден');return;}prepare();waterInspectionEntry=entry;
  hero.object.position.copy(entry.origin);hero.object.rotation.y=Math.atan2(entry.direction.x,entry.direction.z);resetFootSupport();controls.target.copy(hero.object.position).add(new THREE.Vector3(entry.direction.x*.8,1.0,entry.direction.z*.8));camera.position.copy(hero.object.position).add(new THREE.Vector3(-entry.direction.x*6,3.4,-entry.direction.z*6));camera.lookAt(controls.target);waterInspection.setStatus(entry.name+' · обычный прыжок с берега');
 },onJump(){
  if(!waterInspectionEntry||occupiedSeat||jump||!hero)return;keys.add('KeyW');beginJump();keys.delete('KeyW');
 },onVehicle(){
  if(!hero||busy||!fleet?.records.length)return;const record=[...fleet.records].filter(r=>r.car.profile?.massKg).sort((a,b)=>b.car.profile.massKg-a.car.profile.massKg)[0]||fleet.records[0];
  const route=WATER_VEHICLE_ACCESS,d=20,x=route.start.x+route.direction.x*d,z=route.start.z+route.direction.z*d;
  if(!driveAllowed.poseAllowed(x,z,route.yaw,record.car.profile)){waterInspection.setStatus('Подъезд занят — освободите место');return;}
  prepare();activateVehicle(record);resetVehicleWater(car,carState);Object.assign(carState,{x,z,yaw:route.yaw,travelYaw:route.yaw,speed:0,steer:0,yawRate:0,distance:0});poseVehicleOnLandscape(THREE,car,carState,explorationSurface,0);fleet.syncActive(carState);occupiedSeat='front_left';
  const seat=vehicleSeatPoint(carState,occupiedSeat);hero.object.position.set(seat.x,car.object.position.y+seat.y,seat.z);hero.object.rotation.y=route.yaw;poseVehicleOccupant(occupiedSeat,1);controls.target.copy(car.object.position).add(new THREE.Vector3(0,1.4,0));camera.position.copy(car.object.position).add(new THREE.Vector3(-route.direction.x*9+route.direction.z*5,5,-route.direction.z*9-route.direction.x*5));camera.lookAt(controls.target);followCarCamera=false;waterInspection.setStatus(car.profile.label+' · газ по существующему пологому берегу');
 },onDrive(){if(occupiedSeat==='front_left'){waterInspectionDriveUntil=performance.now()+20000;keys.add('KeyW');}},onCapture(){waterFailureCapture=false;waterImpactCapture.arm(waterEffects?.stats().impacts||0);waterInspection.setStatus('Ожидание настоящего всплеска — выполните прыжок или заезд');},onFailureCapture(){waterFailureCapture=true;waterImpactCapture.arm(carState?.waterState?.flooded?1:0,.7);waterInspection.setStatus('Ожидание затопления мотора — выполните заезд');},onExit(){waterImpactCapture.reset();waterInspectionDriveUntil=0;releaseControls();if(occupiedSeat){waterInspectionExitRemaining=.6;keys.add('KeyE');}},onResume(){waterImpactCapture.reset();releaseControls();waterInspectionDriveUntil=0;waterInspection.setStatus('Проверка продолжается');}});
}
let landscape=null,explorationRailway=null,explorationRailPlan=null,explorationDecor=null,explorationMap=null,waypointVisual=null,waypointDistance=null,explorationPlaces=[],railwayDiagnosticsAt=-Infinity;
const explorationSurface={contains:(x,z)=>!!landscape?.contains(x,z)||explorationRailway?.floorHeight(x,z)!=null||!!waterAt(x,z),groundHeight:(x,z)=>explorationRailway?.floorHeight(x,z)??waterAt(x,z)?.floor??landscape?.groundHeight(x,z)??0,canDrive:(x,z)=>waterVehicleSurfaceAt({terrain:landscape,topology,waterAt,metresPerCell:M},x,z)};
let streetLighting=createStreetLighting({THREE,scene,maxLights:8,maxFixtures:192,groundHeight,staticPlacement:true}),environmentNight=0;


const surfaceMotion=createSurfaceMotion();
let tyres=null;
let fleet=null,carTrunk=null,carHood=null,blastResponse=null,heroBlast=null,heroBlastSource=null;const vehicleOccupantImpactPose=createVehicleOccupantImpactPose(THREE);
const vehicleImpactView=createVehicleImpactView(THREE);let vehicleImpactPoseResult=null;
let vehicleVisualQa=null;
let carRollover=null;let car=null,carState=null,carDamage=null,carQa=null,occupiedSeat=null,driveAllowed=()=>false,transition=null,entryHeld=0,entryArmed=true,pointerHeld=false,lastDoorSide=1,followCarCamera=true,carDriveDiagnosticsAt=-Infinity;
let jump=null,jumpCount=0;
let artistInput=createArtist14Input({now:()=>performance.now()/1000});const artistPose=createArtist14Pose(THREE);
let artistSurface=null,artistSurfaceState=null,artistAction={action:{type:'none'},start:null},artistDropId=0,artistDropDistance=0,artistDiagnosticsAt=-Infinity,fireDiagnosticsAt=-Infinity;
let worldWalkHealth=null,worldWalkHealthBridge=null,worldHealthFrame=null,worldHealthSource=null,heroCustodyActive=false,healthDiagnosticsAt=-Infinity,lastWorldVehicleImpactSequence=0;
let sourceVehicleAccess=null,sourceVehicleState=null,sourceVehicleDiagnosticAt=-Infinity,sourceVehicleDrive=null;
const sourceVehicleDriveControllers=new WeakMap(),sourceVehicleDriveControllerSet=new Set();
const sourceHijackPoses=new WeakMap();
const sourceVehiclePose=createWorldVehiclePlayerPose({THREE,getVehicle:id=>worldTrafficPresentation?.getActor(id),setDoorPose:value=>worldTrafficPresentation?.setDoorPose(value)});
const sourceVehicleActive=()=>!!sourceVehicleState?.active&&!worldHealthFrame?.snapshot.dead&&!heroCustodyActive;
function refreshSourceVehicleState(){
 const wasActive=sourceVehicleActive();sourceVehicleState=npcBridge?.getWalkVehicleState?.()||null;
 sourceVehiclePose.prepare(hero,sourceVehicleActive()?sourceVehicleState:null);
 if(wasActive&&!sourceVehicleActive()){
   if(sourceVehicleDrive){worldTrafficPresentation?.releasePlayerControl?.(sourceVehicleDrive.actor);sourceVehicleDrive=null;}
  hero?.reset();resetFootSupport();resetHeroPosture(heroPosture);
  const s=sourceVehicleState;
  if(hero&&!worldHealthFrame?.snapshot.dead&&!heroCustodyActive&&Number.isFinite(s?.r)&&Number.isFinite(s?.c)){
   const before=hero.object.position.clone();hero.object.position.set(s.c*M,groundHeight(s.c*M,s.r*M),s.r*M);hero.object.rotation.y=Math.PI/2-(s.ang||0);
   const shift=hero.object.position.clone().sub(before);camera.position.add(shift);controls.target.add(shift);
  }
  document.body.dataset.sourceVehiclePlayer=JSON.stringify({active:false,phase:s?.phase||'idle'});
 }
}
function createSourceVehicleDriveController(actor,source){
 const yaw=Math.PI/2-(+source.ang||0),vx=(+source.vx||0)*M,vz=(+source.vy||0)*M,forward=vx*Math.sin(yaw)+vz*Math.cos(yaw),speed=Math.hypot(vx,vz)*(forward<0?-1:1),state={...CAR,x:(+source.c||0)*M,z:(+source.r||0)*M,yaw,speed,travelYaw:speed<0?Math.atan2(-vx,-vz):Math.atan2(vx,vz),vx,vz,steer:0,yawRate:0,distance:0,bumped:false,contact:null,frontSlip:0,rearSlip:0,vehicleProfile:{...CAR,...actor.profile},seats:actor.seats};
 let controller;const damage=createVehicleDamage(THREE,actor,{scene,groundHeight,allowed:(x,z)=>driveAllowed(x,z),getState:()=>controller?.state||state,profile:{maxHp:Math.max(240,Math.min(1200,Math.round((actor.profile?.massKg||1500)*.16)))},onExplosion(){blastResponse?.enqueue({point:actor.object.localToWorld(new THREE.Vector3(0,1,0)),power:1,radius:10,source:actor});glass.shatterAll(actor.object,{impulse:80,weaponId:'vehicle_explosion'});}}),roll=createVehicleRollover(THREE,actor),tyre=createTyreDamage(THREE,actor,{groundHeight});
 controller={actor,state,damage,roll,tyre,sourceId:source.presentationCarId,lastReceipt:null,dispose(){damage.dispose();tyre.dispose?.();roll.dispose?.();sourceVehicleDriveControllerSet.delete(controller);}};sourceVehicleDriveControllers.set(actor,controller);sourceVehicleDriveControllerSet.add(controller);glass.prepare(actor.object);return controller;
}
function sourceVehicleDriveWorld(controller){
 const base=driveAllowed,ignoreId=sourceVehicleState?.presentationCarId||controller.sourceId,allowed=(x,z)=>base(x,z);
 allowed.poseAllowed=(x,z,yaw,profile=controller.state.vehicleProfile)=>{
  if(!base.poseAllowed?.(x,z,yaw,profile))return false;
  for(const [px,pz]of carCorners(x,z,yaw,profile))if(worldTrafficPresentation?.blocks(px,pz,.08,{ignoreId,y:controller.actor.object.position.y,height:actorHeight(controller.actor)}))return false;
  return !fleet?.overlaps(x,z,.1,null);
 };
 allowed.contactAt=(...args)=>base.contactAt?.(...args)||null;return allowed;
}
function actorHeight(actor){return Math.max(.5,Number(actor?.profile?.height)||2);}
function ensureSourceVehicleDrive(){
 if(!sourceVehicleActive()||sourceVehicleState?.phase!=='driving'||sourceVehicleState?.canDrive!==true)return null;
 const actor=worldTrafficPresentation?.claimPlayerControl?.(sourceVehicleState.presentationCarId)||worldTrafficPresentation?.getActor?.(sourceVehicleState.presentationCarId);if(!actor)return null;
 let controller=sourceVehicleDriveControllers.get(actor);if(!controller)controller=createSourceVehicleDriveController(actor,sourceVehicleState);controller.sourceId=sourceVehicleState.presentationCarId;sourceVehicleDrive=controller;return controller;
}
function stepSourceVehicleDrive(dt){
 const controller=ensureSourceVehicleDrive();if(!controller)return false;
 const {actor,damage,roll,tyre}=controller,input=damage.disabled?{}:{forward:keys.has('KeyW'),reverse:keys.has('KeyS'),left:keys.has('KeyA'),right:keys.has('KeyD'),handbrake:keys.has('Space')},before=controller.state;
 before.tyreEffects=tyre.effects;const crashEffects=damage.crashEffects||{},sliding=damage.disabled||roll.unstable;before.crashEffects=sliding?{...crashEffects,engineDisabled:true,rollingDrag:(crashEffects.rollingDrag||0)+5.5}:crashEffects;before.throttle=!before.crashEffects.engineDisabled&&(input.forward||input.reverse)?1:0;
 const idle=!input.forward&&!input.reverse&&!input.left&&!input.right&&!input.handbrake&&before.speed===0&&before.steer===0&&before.yawRate===0&&before.travelYaw===before.yaw&&before.frontSlip===0&&before.rearSlip===0&&!before.handbrake&&!before.braking,next=idle?{...before,distance:0,bumped:false,contact:null,handbrake:false,braking:false,frontSlip:0,rearSlip:0}:stepCar(before,input,dt,sourceVehicleDriveWorld(controller));controller.state=next;
 actor.object.position.set(next.x,0,next.z);actor.object.rotation.y=next.yaw;damage.collision(before,next);if(next.contact)roll.impact(next.contact,next.yaw);roll.update(dt);poseWalkVehicle(actor,next,roll.stats().angle||0,dt);actor.update(next,!!next.braking);tyre.update(next,dt);damage.update(dt);damage.crash?.applyWheels({tyres:tyre.state});
 const stats=damage.stats(),receipt=npcBridge?.setWalkVehicleInput?.({nativePhysics:true,pose:{x:next.x/M,y:next.z/M,ang:Math.PI/2-next.yaw,vx:(next.vx||Math.sin(next.travelYaw??next.yaw)*next.speed)/M,vy:(next.vz||Math.cos(next.travelYaw??next.yaw)*next.speed)/M,steer:next.steer||0,braking:!!next.braking,damageRatio:stats.maxHp?stats.hp/stats.maxHp:1,wrecked:!!stats.wrecked,burning:!!stats.burning}});controller.lastReceipt=receipt;
 document.body.dataset.sourceVehicleAdvancedDrive=JSON.stringify({active:true,id:sourceVehicleState.presentationCarId,speed:next.speed,steer:next.steer,handbrake:!!next.handbrake,bumped:!!next.bumped,damage:stats,receipt});return true;
}
function applySourceVehiclePresentation(dt){
 if(!hero||!sourceVehicleActive())return;
 const s=sourceVehicleState,before=hero.object.position.clone();
 if(Number.isFinite(s.r)&&Number.isFinite(s.c)){hero.object.position.set(s.c*M,groundHeight(s.c*M,s.r*M),s.r*M);hero.object.rotation.y=Math.PI/2-(s.ang||0);}
 const posed=sourceVehiclePose.apply(hero,s,dt),entry=s.vehicleEntry||worldHealthSource?.vehicleEntry;
 if(entry?.phase==='pull_driver'||entry?.phase==='pulled_out'){
  let pose=sourceHijackPoses.get(hero);if(!pose){pose=createVehicleHijackPose({THREE,walker:hero,getVehicle:id=>worldTrafficPresentation?.getActor(id)});sourceHijackPoses.set(hero,pose);}
  const sample={...entry,carId:entry.carId||entry.vehicleId||s.presentationCarId},blocked=heroCustodyActive||worldHealthFrame?.snapshot.dead;
  if(entry.phase==='pulled_out')pose.applyVictim({...sample,phase:'pulled'},{dt,dead:false,blocked});else pose.applyPuller(sample,{blocked});
 }
 const shift=hero.object.position.clone().sub(before);camera.position.add(shift);controls.target.add(shift);
 if(weaponModel)weaponModel.visible=false;
 const now=performance.now();if(now-sourceVehicleDiagnosticAt>250){sourceVehicleDiagnosticAt=now;document.body.dataset.sourceVehiclePlayer=JSON.stringify({active:true,phase:s.phase,sourceCarId:s.sourceCarId,presentationCarId:s.presentationCarId,seatId:s.seatId,bound:posed.bound,progress:s.progress});}
}
function requestSourceVehicle(action,candidate){
 if(!sourceVehicleAccess||!hero)return;
 releaseWeapon();heroCover.leave();entryArmed=false;entryHeld=0;pointerHeld=false;keys.delete('KeyE');setArsenalOpen(false);
 const state=sourceVehicleState,carId=candidate?.sourceCarId||state?.sourceCarId,seatId=candidate?.seatId||state?.seatId;
 sourceVehicleAccess.request(action,{carId,seatId,player:{x:hero.object.position.x,z:hero.object.position.z,yaw:hero.object.rotation.y}}).then(result=>{
  if(!result.accepted&&!result.pending){const reasons={'seat-unavailable':'Это место недоступно','server-seat-unavailable':'Это пассажирское место пока недоступно','vehicle-unloaded':'Машина ещё загружается','door-blocked':'У двери нет места','approach-selected-door':'Подойди ближе к выбранной двери','vehicle-unavailable':'Эта машина уже недоступна','protected-or-disabled':'Эту машину нельзя использовать','not-occupant':'Ты уже вышел из машины'};exitNotice=reasons[result.reason]||'Не удалось выполнить действие с машиной';exitNoticeUntil=performance.now()+2200;}
 });
}
const heroCustodyPose=createHeroCustodyVehiclePose({THREE,getVehicle:id=>worldTrafficPresentation?.getActor(id)});
const lifeInterrupt=createWalkLifeInterrupt({
 closeDialogs(){
  mercenaryWalk?.interrupt();walkPlayerHud?.closeDialogs();setArsenalOpen(false);$('scene-menu').hidden=true;
  for(const name of ['closeNpcActionMenu','_closeBusinessActionCard','_closeBrigadirDossier','_closeSaidHireConfirm','closeGameMainMenu','closeNewspaper'])try{window[name]?.();}catch(error){console.warn('Death dialogue close',name,error);}
 },
 cancelScriptedActions(){
  buildingQaMove=null;animationQaMoveUntil=0;animationQaMoveDirection=null;animationQaJumpPending=false;waterInspectionDriveUntil=0;waterInspectionExitRemaining=0;
  heroCover.leave();verticalNavigation.reset();jump=null;
  // Keep vehicle ownership with its source; stop unfinished on-foot staging.
  if(!occupiedSeat){if(transition?.doorId)car?.setDoorById?.(0,transition.doorId);transition=null;heroBlast=null;heroBlastSource=null;hero?.reset();}
 },releaseInput:()=>releaseControls(),onError:error=>console.warn('Death scene interruption',error)
});
const artistBusy=()=>worldHealthFrame?.inputsBlocked===true||['hit','fall','dead'].includes(artistSurface?.state.kind),artistSwimming=()=>artistSurfaceState?.swim.active===true;
function applyWorldVehicleImpactPresentation(source){
 const event=source?.vehicleImpact,sequence=+event?.sequence||0;if(!sequence||sequence===lastWorldVehicleImpactSequence)return false;
 lastWorldVehicleImpactSequence=sequence;
 if(!hero||sourceVehicleActive()||heroCustodyActive||worldHealthFrame?.snapshot.dead||!(+event.fallMs>0))return false;
 const dirX=+event.dirC||0,dirZ=+event.dirR||0,length=Math.hypot(dirX,dirZ)||1,launch=Math.max(2.2,Math.min(14.5,+event.launchMps||2.2)),lift=Math.max(.35,Math.min(4.2,+event.liftMps||.35)),duration=Math.max(.62,Math.min(2.4,(+event.fallMs||900)/1000)),floor=heroGroundHeight(hero.object.position.x,hero.object.position.z),strength=Math.max(.2,Math.min(2,(+event.speedMps||2)/9));
 heroBlast={x:hero.object.position.x,y:Math.max(floor,hero.object.position.y),z:hero.object.position.z,baseY:floor,vx:dirX/length*launch,vy:lift,vz:dirZ/length*launch,heading:Math.atan2(dirX,dirZ),elapsed:0,progress:0,rolls:event.tier==='severe'?2:1,duration,strength,kind:'vehicle-impact',done:false,blocked:false,remainder:0};
 heroBlastSource=worldTrafficPresentation?.getActor?.(event.vehicleId)||null;verticalNavigation.reset();transition=null;jump=null;releaseControls();releaseWeapon();keys.clear();hero.object.rotation.z=0;hero.reset();setWalking(true);for(const id of ['district','walk','reload'])$(id).disabled=false;
 document.body.dataset.vehiclePedestrianImpact=JSON.stringify({sequence,vehicleId:event.vehicleId,tier:event.tier,speedMps:event.speedMps,duration});return true;
}
function updateWorldWalkHealth(){
 if(!npcBridge||!hero)return;
 if(worldWalkHealthBridge!==npcBridge){worldWalkHealth?.dispose();worldWalkHealth=createWorldWalkHealth({bridge:npcBridge});worldWalkHealthBridge=npcBridge;}
 const source=npcBridge.getPlayerState(),now=performance.now();worldHealthSource=source;heroCustodyActive=heroCustodyPose.prepare(hero,source).active;
 worldHealthFrame=worldWalkHealth.update({actorKey:hero,time:now,source});
 lifeInterrupt.apply(worldHealthFrame.snapshot);
 for(const event of worldHealthFrame.events){
  if(event.type==='death'){artistSurface?.receive(worldWalkHealthSurfaceReceipt(event));releaseControls();heroCover.leave();verticalNavigation.reset();jump=null;resetHeroPosture(heroPosture);}
  if(event.type==='restore'){
   if(event.reason==='custody-takeover'){artistSurface?.reset();releaseControls();continue;}
   releaseControls();heroBlast=null;heroBlastSource=null;jump=null;transition=null;occupiedSeat=null;verticalNavigation.reset();heroCover.leave();artistSurface?.reset();hero.reset();resetHeroPosture(heroPosture);
   if(Number.isFinite(source.r)&&Number.isFinite(source.c)){const before=hero.object.position.clone();hero.object.position.set(source.c*M,groundHeight(source.c*M,source.r*M),source.r*M);const shift=hero.object.position.clone().sub(before);controls.target.add(shift);camera.position.add(shift);resetFootSupport();}
  }
 }
 if(worldHealthFrame.actorSync?.dead)resetHeroPosture(heroPosture);
 synchronizeWorldWalkHealthSurface(artistSurface,worldHealthFrame.actorSync,{time:now/1000});
 if(worldHealthFrame.inputsBlocked)releaseControls();
 refreshSourceVehicleState();
 applyWorldVehicleImpactPresentation(source);
 if(now-healthDiagnosticsAt>=100){healthDiagnosticsAt=now;document.body.dataset.worldWalkHealth=JSON.stringify({...worldHealthFrame.snapshot,reaction:worldHealthFrame.reaction?.kind||'idle',surface:artistSurface?.state.kind||'idle'});}
}
function artistAllowed(){return !sourceVehicleActive()&&jump?.mode!=='traversal'&&!hudInputBlocked()&&!!hero&&walking&&!occupiedSeat&&!transition&&!busy&&!arsenalOpen()&&$('scene-menu').hidden&&!heroBlast&&!verticalNavigation.active&&!artistBusy()&&!artistSwimming();}
function artistMeleeContext(){return {time:performance.now()/1000,allowed:artistAllowed()&&heroPosture.value<.001,armed:currentWeapon.id!=='none',airborne:!!jump,yaw:hero?.object.rotation.y||0,airHeight:hero?Math.max(0,hero.object.position.y-heroGroundHeight(hero.object.position.x,hero.object.position.z)):0};}


const NPC_RENDER_DISTANCE_M=100,NPC_LOGICAL_HANDOFF_MARGIN_M=5;
let npcShotEffects=null,npcLogicalVehicles=null,npcInspection=null,worldTrafficPresentation=null,npcPopulation=null,npcBridge=window.Mafiozi3DBridge||null,worldWalkCombat=null,npcGallery=null,worldWalkMelee=null,npcDiagnosticsAt=-Infinity;
let npcSupportCache=null,npcNativeNavigation=null,npcNativePerception=null,npcVehicleNavigation=null,npcServiceDestinations=null,transportDiagnosticAt=0;
async function initNpcPopulation(){
 worldTrafficPresentation=createWorldTrafficPresentation({THREE,RoundedBox:RoundedBoxGeometry,loader,scene,groundHeight:(x,z)=>groundHeight(x,z),worldScale:M,wheelRenderOptimization,detailOptimization:renderer.extensions.has('WEBGL_multi_draw')});
 npcLogicalVehicles=createNpcLogicalVehicleBinding({bridge:npcBridge,worldScale:M,groundHeight,streamRadius:(NPC_RENDER_DISTANCE_M-NPC_LOGICAL_HANDOFF_MARGIN_M)/M,getTemplate:id=>fleet?.records.find(record=>record.car?.profile?.id===id)?.car,getVisibleVehicle:id=>worldTrafficPresentation.getActor(id),getVisibleNpc:id=>npcPopulation?.getActor(String(id))});
 sourceVehicleAccess=npcBridge?createWorldVehiclePlayerAccess({traffic:worldTrafficPresentation,bridge:npcBridge,worldScale:M}):null;
 const vehicleBindings=new WeakMap();
 const visibleNpcVehicleAccess=createNpcVehicleAccessResolver({traffic:worldTrafficPresentation,worldScale:M});
 const getSourceVehicle=id=>{const actor=worldTrafficPresentation.getActor(id);if(!actor)return null;let binding=vehicleBindings.get(actor);
  if(!binding){binding=createNpcTrafficVehicleBinding({THREE,actor});if(binding)vehicleBindings.set(actor,binding);}return binding;};
 if(npcBridge){artistInput=createWorldWalkMeleeInput({bridge:npcBridge});worldWalkMelee=createWorldWalkMeleeHost({THREE,bridge:npcBridge,getHero:()=>hero,getActors:()=>npcPopulation?.getActors()||[],obstacles:()=>[content,...(fleet?.records.map(r=>r.car.object)||[])]});}
 npcSupportCache=createNpcSupportCache({sample:groundHeight,getEnvironment:()=>({scene,buildingIndex:buildingSampleIndex,railway:explorationRailway,railPlan:explorationRailPlan,landscape,topology,entries:buildingEntries})});
 npcSupportCache.beginFrame();
 npcNativeNavigation=createNpcNativeNavigation({worldScale:M,waterAt,groundHeight:npcSupportCache.sample,bodiesAt:(c,r)=>walkCollisionIndex?.(c,r)||[],bodiesInBounds:(...bounds)=>walkCollisionIndex?.queryBounds?.(...bounds)||[],containsBody:(body,r,c)=>inPolygon(r,c,body.polygonCR),terrainAllows:(x,z)=>landscape?.contains(x,z)?landscape.canWalk(x,z):nativePedestrianLand(topology,z/M,x/M)||!!waterAt(x,z),surfaceAt:(x,z,r,c)=>topology?.roadMask?.[Math.floor(r)]?.[Math.floor(c)]?'road':'land',blocksDynamic:(x,z,body)=>!!explorationRailway?.blocks(x,z,0)||!!fleet?.records.some(record=>npcVehicleBlocks(record.car,x,z,0,body))||!!npcLogicalVehicles?.blocks(x,z,body)});
 npcBridge?.registerWalkNpcNavigationResolver?.(npcNativeNavigation.query);
 npcNativePerception=createNpcNativePerception({worldScale:M,groundHeight,bodiesAt:(c,r)=>walkCollisionIndex?.(c,r)||[],ready:()=>!!walkCollisionIndex,getVehicles:()=>[...(fleet?.records||[]),...(worldTrafficPresentation?.getActors()||[])]});
 npcBridge?.registerWalkNpcPerceptionResolver?.(npcNativePerception.query);
 npcBridge?.registerWalkNpcVehicleAccessResolver?.(request=>{const visible=worldTrafficPresentation.getActor(request.carId);return visible?visibleNpcVehicleAccess(request):npcLogicalVehicles.access(request);});
 npcVehicleNavigation=createNpcVehicleNavigation({worldScale:M,inspectRoutes:!!performanceProbe,ready:()=>!!walkCollisionIndex&&!!driveAllowed,poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,driveAllowed,shape),isRoad:(x,z)=>!!topology?.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)],waterAt,groundHeight,getVehicle:id=>npcLogicalVehicles.getActor(id),getVehicles:()=>[...(fleet?.records||[]),...npcLogicalVehicles.getVehicles()]});
 npcServiceDestinations=createNpcServiceDestinations({worldScale:M,getHospitals:()=>buildingEntries.filter(entry=>/hospital/i.test(entry.instance?.assetId||'')).map(entry=>{const point=entry.object.localToWorld(new THREE.Vector3(0,0,1));return {hospitalId:entry.instance.id,door:{r:point.z/M,c:point.x/M}};}),vehicleQuery:npcVehicleNavigation.query,pedestrianQuery:npcNativeNavigation.query,isRoad:(x,z)=>!!topology?.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)]});
 const detentionAccess=createNpcDetentionAccess({getEntries:()=>buildingEntries,worldScale:M});
 const residentAccess=createNpcResidentBuildingAccess({getEntries:()=>buildingEntries,worldScale:M});
 npcBridge?.registerWalkTrafficNavigationResolver?.(request=>{if(request?.mode==='initial-vehicle-shape'){const id=worldTrafficProfile(request.vehicle),actor=fleet?.records.find(record=>record.car?.profile?.id===id)?.car,profile=actor?.profile;return profile?{ready:true,profileId:id,halfLength:(profile.collisionHalfLength??profile.halfLength)*Math.abs(actor.object.scale.z)/M,halfWidth:(profile.collisionHalfWidth??profile.halfWidth)*Math.abs(actor.object.scale.x)/M}:{ready:false,status:'pending',reason:'vehicle-profile-loading'};}if(request?.mode==='lane-route'||request?.mode==='lane-route-touch'||request?.mode==='lane-route-cancel'||request?.mode==='road-rules'||request?.mode==='parking-anchors'||request?.mode==='parking-destination'||request?.mode==='parking-exit')return cityRoadNavigation?.query(request)||{ready:false,status:'pending',reason:'city_loading',points:[]};if(request?.mode==='resident-access')return residentAccess(request);if(request?.mode==='detention-access')return detentionAccess(request);if(request?.mode==='hospital')return npcServiceDestinations.query(request);if(request?.mode==='driver')return npcLogicalVehicles.driver(request);return npcVehicleNavigation.query(request);});
 addEventListener('pagehide',()=>npcBridge?.registerWalkTrafficNavigationResolver?.(null),{once:true});
 if(npcBridge?.registerWalkCoverResolver)npcBridge.registerWalkCoverResolver(request=>heroCover.resolveDamage(request));
 if(npcBridge)worldWalkCombat=createWorldWalkCombat({THREE,bridge:npcBridge,getActors:()=>npcPopulation?.getActors()||[],obstacles:shotObstacles});
 window.addEventListener('artist14:confirmed-hit',event=>queueMicrotask(()=>{const hit=event.detail?.kind==='melee'?worldWalkMelee?.resolveConfirmedReceipt(event):worldWalkCombat?.resolveConfirmedReceipt(event);if(hit?.targetId)npcPopulation?.receive(hit.targetId,{...hit,id:hit.shotId});}));
 npcShotEffects=createNpcShotEffects({THREE,scene,getActor:id=>npcPopulation?.getActor(id),groundHeight,worldScale:M});
 addEventListener('pagehide',()=>npcShotEffects?.dispose(),{once:true});
 npcPopulation=await createNpcPopulation({THREE,scene,loader,cloneSkeleton:cloneNpcSkeleton,bridge:npcBridge,groundHeight:(x,z)=>groundHeight(x,z),waterAt:(x,z)=>waterAt(x,z),worldScale:M,getFocus:()=>hero?.object.position,renderDistance:NPC_RENDER_DISTANCE_M,creationBudget:1,profile:new URLSearchParams(location.search).get('perfqa')==='1',getInspectId:()=>npcInspection?.getSelection()?.id,getVehicle:getSourceVehicle,onSnapshot:(snapshot,{time})=>{worldTrafficPresentation.sync(snapshot?.cars||[]);npcShotEffects.sync(snapshot?.npcs||[],time*1000,performance.now()/1000);},onBeforePose:({dt})=>worldTrafficPresentation.update(dt)});
 npcInspection=createNpcRuntimeInspection({document,parent:document.body,getActors:()=>npcPopulation?.getActors()||[],getFocus:()=>hero?.object.position,focusActor:row=>{if(!row.object?.visible)return;const p=row.object.position;followCarCamera=false;controls.target.set(p.x,p.y+1.1,p.z);camera.position.set(p.x+3.5,p.y+2.6,p.z+4.5);camera.lookAt(controls.target);}});
 window.MafioziWalkNpcs={getActors:()=>npcPopulation?.getActors()||[],getActor:id=>npcPopulation?.getActor(id),receive:(id,event)=>npcPopulation?.receive(id,event),attach:bridge=>{npcBridge=bridge;npcPopulation.attach(bridge);}};
 if(npcBridge){const state=npcBridge.getPlayerState();hero.object.position.set(state.c*M,groundHeight(state.c*M,state.r*M),state.r*M);hero.object.rotation.y=Math.PI/2-state.ang;controls.target.copy(hero.object.position).y+=1.1;camera.position.copy(hero.object.position).add(new THREE.Vector3(3,2.2,4));}
 const status=document.createElement('div');status.id='npc-world-status';status.style.cssText='font-size:12px;color:#c5ddd6;margin-top:6px';
 if(npcBridge)status.textContent='NPC: логика world подключена';
 else {const link=document.createElement('a');link.href='/world.html?render=3d&renderer=walk';link.textContent='Открыть город с NPC и логикой world';status.append(link);}
 walkShell.querySelector('footer').append(status);
 if(new URLSearchParams(location.search).get('npcgallery')==='1'){
  const parent=document.createElement('div');parent.style.cssText='position:fixed;left:280px;top:70px;z-index:80;width:350px;max-height:80vh;overflow:auto';(walkShell===document?document.body:walkShell).append(parent);
  npcGallery=await createNpcGalleryHost({THREE,scene,loader,cloneSkeleton:cloneNpcSkeleton,groundHeight,anchor:hero.object.position.clone().add(new THREE.Vector3(0,0,-12)),parent,document});
  npcGallery.panel.style.position='relative';npcGallery.panel.style.top='0';npcGallery.panel.style.left='0';
  const showGallery=npcGallery.gallery.populate;npcGallery.gallery.populate=async rows=>{const records=await showGallery(rows);if(records.length){setFreeMouse(false);const center=new THREE.Vector3();records.forEach(r=>center.add(r.actor.object.position));center.divideScalar(records.length);controls.target.copy(center).y+=1;camera.position.copy(center).add(new THREE.Vector3(9,7,14));camera.lookAt(controls.target);}return records;};
 }

}
function updateNpcPopulation(dt){
 if(!npcPopulation||!hero)return;
 npcLogicalVehicles?.beginFrame();
 npcSupportCache?.beginFrame();
 npcNativeNavigation?.beginFrame();
 npcVehicleNavigation?.beginFrame();
 npcServiceDestinations?.beginFrame();
 if(performance.now()-transportDiagnosticAt>500){transportDiagnosticAt=performance.now();document.body.dataset.npcTransport=JSON.stringify(npcVehicleNavigation?.diagnostics());}
 npcNativePerception?.beginFrame();
 if(npcBridge?.syncWalkPlayer){const receipt=npcBridge.syncWalkPlayer({r:hero.object.position.z/M,c:hero.object.position.x/M,ang:Math.PI/2-hero.object.rotation.y,walking:[...keys].some(key=>['KeyW','KeyA','KeyS','KeyD'].includes(key)),stance:heroPosture.target});
  if(receipt?.locked&&!sourceVehicleActive()&&receipt.state&&Number.isFinite(receipt.state.r)&&Number.isFinite(receipt.state.c)){
   const s=receipt.state;releaseControls();restoreBuildingCamera();
   const before=hero.object.position.clone();hero.object.position.set(s.c*M,groundHeight(s.c*M,s.r*M),s.r*M);
   // A source custody/teleport move also owns floor support and the orbit anchor.
   // Otherwise the next frame restores the old floor while the camera stays behind.
   resetFootSupport();const shift=hero.object.position.clone().sub(before);controls.target.add(shift);camera.position.add(shift);
  }
 }
 const sourceClock=npcBridge?.getWorldClock?.(),now=(Number.isFinite(sourceClock)?sourceClock:sourceClock?.now??performance.now())/1000;npcPopulation.update(dt,now);npcInspection?.update(performance.now()/1000);
 npcShotEffects?.update(performance.now()/1000);
 // diagnostics() walks and sorts the complete roster. It feeds an inspection
 // data attribute only, so a 250 ms cadence preserves its observability while
 // leaving actor simulation and every visible NPC update fully per-frame.
 const diagnosticNow=performance.now();if(diagnosticNow-npcDiagnosticsAt>=250){npcDiagnosticsAt=diagnosticNow;document.body.dataset.npcWorld=JSON.stringify({...npcPopulation.diagnostics(),traffic:worldTrafficPresentation?.diagnostics(),perception:npcNativePerception?.diagnostics(),navigation:{...npcNativeNavigation?.diagnostics(),support:npcSupportCache?.diagnostics(),source:npcBridge?.getWalkNpcNavigationDiagnostics?.()}});}
}
let exitSwimHandoff=null,artistSurfaceFrameDt=0;
function heroSwimHeight(x,z,sample){const target=groundHeight(x,z)+sample.liftWorld;if(!waterAt(x,z))exitSwimHandoff=null;if(!exitSwimHandoff)return target;const y=exitSwimHandoff.update(target,artistSurfaceFrameDt);if(exitSwimHandoff.done)exitSwimHandoff=null;return y;}
function artistUpdate(dt,moved,running){artistSurfaceFrameDt=dt;if(verticalNavigation.active)return;


 if(!artistSurface||!hero)return;const pos=hero.object.position,before=pos.clone(),water=waterAt(pos.x,pos.z),floor=heroGroundHeight(pos.x,pos.z),unit=hero.scale;


 artistSurfaceState=artistSurface.update(dt,{time:performance.now()/1000,waterLevel:water?.level??null,inWater:!!water&&water.depth>0,moving:moved,fast:running,chestWorldY:floor+3.08*unit,groundWorldY:floor,blocked:sourceVehicleActive()||!!occupiedSeat||(!!transition&&(!transition.exiting||transition.phase!=='body'))||!!jump||!!heroBlast||verticalNavigation.active});


 if(!occupiedSeat&&!transition&&!jump){const shift=pos.clone().sub(before);camera.position.add(shift);controls.target.add(shift);}


 if(worldHealthFrame?.reaction?.kind==='hit'&&artistSurfaceState.reaction.kind==='idle'&&!occupiedSeat&&!transition&&!heroBlast)artistPose.reaction(worldHealthFrame.reaction,hero.artistContext());
 if(weaponModel&&(artistSurfaceState.swim.blend>.1||worldHealthFrame?.snapshot.dead))weaponModel.visible=false;
 const diagnosticsNow=performance.now();if(diagnosticsNow-artistDiagnosticsAt>=100){artistDiagnosticsAt=diagnosticsNow;document.body.dataset.artist14=JSON.stringify({revision:'artist14-game-v14',swim:artistSurfaceState.swim.active,fast:artistSurfaceState.swim.fast,reaction:artistSurfaceState.reaction.kind,melee:artistAction.action.type,shedding:artistSurfaceState.shedding});}
}


document.addEventListener('artist14:hit',event=>{if(event.detail?.target==='hero'&&artistSurface?.receive(event.detail)){artistInput.cancel();releaseControls();}});


document.addEventListener('artist14:restore',event=>{if(event.detail?.confirmed===true)artistSurface?.reset();});


const heroPosture=createHeroPosture();let postureMotion=posturePresentation(heroPosture),animationQaMoveUntil=0,animationQaMoveDirection=null,animationQaJumpPending=false;


let currentWeapon=ARSENAL[0],weaponModel=null,weaponHud=null,lastWeaponId=null;
const heroFollowGesture=createHeroFollowGesture({THREE});
let heroFollowSignals=0;
function followGestureAllowed(){return !!hero&&walking&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!heroCustodyActive&&!heroCover.active&&!busy&&!artistBusy()&&!artistSwimming()&&!hudInputBlocked()&&!arsenalOpen()&&$('scene-menu').hidden&&heroPosture.value<.01&&artistAction.action.type==='none'&&!aiming&&!triggerHeld&&!triggerPressed&&!(fireState()?.reloadRemaining>0)&&!worldHealthFrame?.snapshot.dead;}
function signalHeroFollow(){if(heroFollowGesture.trigger({hero,weapon:currentWeapon,now:performance.now()/1000,allowed:followGestureAllowed()}))document.body.dataset.heroFollowGesture=JSON.stringify({sequence:++heroFollowSignals,weapon:currentWeapon.id,duration:heroFollowGesture.duration,hand:'left',queued:heroFollowGesture.queued});}
const weaponInventory=createWeaponInventory();
const weaponCrosshair=createWeaponCrosshair({host:$('cross'),document});
const renderWeaponView=createWeaponRecoilView(THREE);
let groundWeapons=null;
const weaponPickupPrompt=document.createElement('div');weaponPickupPrompt.id='weapon-pickup-prompt';weaponPickupPrompt.hidden=true;weaponPickupPrompt.setAttribute('role','status');weaponPickupPrompt.style.cssText='position:fixed;left:50%;bottom:140px;transform:translateX(-50%);z-index:44;padding:12px 20px;border:1px solid #b9a57c;border-radius:6px;background:#15191df2;color:#f3e9d1;font:600 15px system-ui;pointer-events:none;box-shadow:0 8px 26px #0008';document.body.append(weaponPickupPrompt);
let weaponPickupPromptState=null;
const npcHoldUpPrompt=document.createElement('div');npcHoldUpPrompt.id='npc-hold-up-prompt';npcHoldUpPrompt.hidden=true;npcHoldUpPrompt.setAttribute('role','status');npcHoldUpPrompt.style.cssText='position:fixed;left:50%;bottom:184px;transform:translateX(-50%);z-index:46;padding:11px 19px;border:1px solid #d8b35b;border-radius:7px;background:#17120df2;color:#ffe6a6;font:800 15px system-ui;pointer-events:none;box-shadow:0 8px 28px #0009;text-align:center';document.body.append(npcHoldUpPrompt);
const npcHoldUpDirection=new THREE.Vector3();let npcHoldUp={id:null,canTake:false,cashAvailable:false,nextAt:0};
const tireTracks=createTireTracks(THREE,{surfaceAt:(x,z)=>[0,9,19].includes(topology?.grid?.[Math.floor(z/M)]?.[Math.floor(x/M)])});scene.add(tireTracks.object);
let glass=createGlassBreakage(THREE,scene,{groundHeight});
const fireStates=new Map(),effects=createWeaponEffects(THREE,scene,{groundHeight,onImpact(payload){for(const record of fleet?.records||[]){record.damage?.impact(payload);record.tyres?.hit(payload)}if(payload.explosive)blastResponse?.enqueue({point:payload.point,power:1.4,radius:11});glass.hit(payload.hit,{direction:payload.direction,impulse:payload.damage,weaponId:payload.weaponId})}}),aimRay=new THREE.Raycaster();
const vehicleWindowPrompt=document.createElement('div');vehicleWindowPrompt.id='vehicle-window-prompt';vehicleWindowPrompt.hidden=true;vehicleWindowPrompt.setAttribute('role','status');vehicleWindowPrompt.style.cssText='position:fixed;left:50%;bottom:154px;transform:translateX(-50%);z-index:44;max-width:80vw;padding:10px 18px;border:1px solid #9d8a5b;border-radius:6px;background:#152324ed;color:#f3e9d1;font:600 13px system-ui;pointer-events:none;text-align:center';document.body.append(vehicleWindowPrompt);
const vehicleWindowFire={car:null,seatId:null,frame:null,damage:null,plan:null,blend:0,result:null,pending:0,diagnosticsAt:-Infinity};
let pendingCoverShotUntil=0,triggerHeld=false,triggerPressed=false,reloadPressed=false,aiming=false,aimBlend=0,savedCameraOffset=null;
const walkBlastSession=crypto.randomUUID();
blastResponse=createBlastResponse(THREE,scene,{getHero:()=>hero,getVehicles:()=>fleet?.records||[],getRoots:()=>[content],getGlass:()=>glass,groundHeight:heroGroundHeight,onHeroExposure(event,exposure){
 // Source RPG/grenade damage is already resolved by world; only the separate
 // walk fleet needs admission. The bridge refuses local HP writes online.
 if(event.source&&npcBridge?.applyWalkVehicleBlast){const receipt=npcBridge.applyWalkVehicleBlast({eventId:`walk-fleet:${walkBlastSession}:${event.id}`,r:event.point.z/M,c:event.point.x/M,...exposure});document.body.dataset.walkBlastDamage=JSON.stringify(receipt);}
},onHeroLaunch(body,event){verticalNavigation.reset();if(heroBlast&&body.strength<heroBlast.strength*.65)return;heroBlastSource=occupiedSeat?car:event.source;occupiedSeat=null;transition=null;jump=null;heroBlast=body;releaseControls();releaseWeapon();keys.clear();hero.object.rotation.z=0;hero.reset();setWalking(true);for(const id of ['district','walk','reload'])$(id).disabled=false;}});
function combatAllowed(){return !sourceVehicleActive()&&jump?.mode!=='traversal'&&!hudInputBlocked()&&!artistSwimming()&&!artistBusy()&&!!hero&&walking&&(!occupiedSeat||!carDamage?.disabled&&!carRollover?.unstable)&&!transition&&!heroBlast&&!verticalNavigation.active&&!busy&&!arsenalOpen()&&$('scene-menu').hidden&&currentWeapon.id!=='none'}
function clearNpcHoldUp(){npcHoldUp.id=null;npcHoldUp.canTake=false;npcHoldUp.cashAvailable=false;if(!npcHoldUpPrompt.hidden)npcHoldUpPrompt.hidden=true;}
function updateNpcHoldUp(now=performance.now()){
 if(!aiming||!combatAllowed()||occupiedSeat||!worldWalkCombat||!npcBridge?.aimNpcHoldUp){clearNpcHoldUp();return;}
 if(now<npcHoldUp.nextAt)return;npcHoldUp.nextAt=now+100;
 camera.getWorldDirection(npcHoldUpDirection);const hit=worldWalkCombat.aim({origin:camera.position,direction:npcHoldUpDirection,range:8*M});
 if(!hit?.npcId){clearNpcHoldUp();return;}
 const receipt=npcBridge.aimNpcHoldUp(hit.npcId);if(!receipt?.ok){clearNpcHoldUp();return;}
 npcHoldUp.id=String(hit.npcId);npcHoldUp.canTake=!!receipt.canTake;npcHoldUp.cashAvailable=receipt.cashAvailable!==false;
 const text=receipt.alreadyRobbed?'Руки вверх · наличных больше нет':receipt.robberyPending?'Передача наличных…':npcHoldUp.canTake?'E — взять наличные':'Держи на прицеле · подойди ближе';if(npcHoldUpPrompt.textContent!==text)npcHoldUpPrompt.textContent=text;npcHoldUpPrompt.hidden=false;
 document.body.dataset.npcHoldUp=JSON.stringify({id:npcHoldUp.id,canTake:npcHoldUp.canTake,cashAvailable:npcHoldUp.cashAvailable,alreadyRobbed:!!receipt.alreadyRobbed,robberyPending:!!receipt.robberyPending,distance:receipt.distance,intimidated:!!receipt.intimidated});
}
function takeNpcCash(){
 if(!npcHoldUp.canTake||!npcHoldUp.id||!npcBridge?.robAimedNpc)return false;
 const receipt=npcBridge.robAimedNpc(npcHoldUp.id);document.body.dataset.npcHoldUpTake=JSON.stringify(receipt||{ok:false});
 if(!receipt?.ok)return false;clearNpcHoldUp();return true;
}
function releaseWeapon(){resetVehicleWindowFire();pendingCoverShotUntil=0;triggerHeld=false;triggerPressed=false;reloadPressed=false;aiming=false;clearNpcHoldUp()}
function setVehicleWindowPrompt(visible,message=''){
 const hidden=!visible;if(vehicleWindowPrompt.hidden!==hidden)vehicleWindowPrompt.hidden=hidden;
 if(visible&&vehicleWindowPrompt.textContent!==message)vehicleWindowPrompt.textContent=message;
}
function updateVehicleWindowPrompt(){
 const result=vehicleWindowFire.result,visible=!!occupiedSeat&&aiming&&!!result;
 setVehicleWindowPrompt(visible,visible?(result.canFire?'ПКМ — прицел из окна · ЛКМ — огонь · R — перезарядить':result.reason):'');
}
function resetVehicleWindowFire(){
 if(vehicleWindowFire.car)document.body.dataset.vehicleWindowFire=JSON.stringify({active:false,seatId:null});
 setVehicleWindowPrompt(false);
 if(vehicleWindowFire.car&&vehicleWindowFire.seatId)setVehicleWindowOpen(vehicleWindowFire.car,vehicleWindowFire.seatId,false,{restore:!vehicleWindowFire.damage?.disabled&&!vehicleWindowFire.damage?.state?.explosions});
 vehicleWindowFire.car=null;vehicleWindowFire.seatId=null;vehicleWindowFire.frame=null;vehicleWindowFire.damage=null;vehicleWindowFire.plan=null;vehicleWindowFire.blend=0;vehicleWindowFire.result=null;vehicleWindowFire.pending=0;
}
function vehicleWindowCameraTarget(forward){
 const frame=vehicleWindowFire.frame||vehicleWindowFrame(THREE,car,occupiedSeat);
 if(!frame)return hero.object.position.clone().add(new THREE.Vector3(0,1.25,0));
 const plan=planVehicleWindowShot({vehicleState:carState,seatId:occupiedSeat,aimDirection:forward,weaponId:currentWeapon.id,frame});
 const side=frame.side,local=plan.localMuzzle||{x:side*Math.max(Math.abs(frame.min[0]),Math.abs(frame.max[0])),y:(frame.min[1]+frame.max[1])/2,z:frame.seat.front};
 const target=car.object.localToWorld(new THREE.Vector3(local.x,local.y,local.z)),normal=new THREE.Vector3(side,0,0).applyQuaternion(car.object.quaternion);
 return target.addScaledVector(normal,.35).addScaledVector(forward,4);
}
function updateVehicleWindowFire(dt,{basePose=true}={}){
 if(!occupiedSeat&&!vehicleWindowFire.car)return null;
 const eligible=!!occupiedSeat&&!transition&&combatAllowed()&&!!weaponModel;
 const available=eligible&&(aiming||vehicleWindowFire.blend>0&&vehicleWindowFire.car===car&&vehicleWindowFire.seatId===occupiedSeat);
 if(!available){resetVehicleWindowFire();if(weaponModel&&occupiedSeat)weaponModel.visible=false;}
 else{
  if(vehicleWindowFire.car!==car||vehicleWindowFire.seatId!==occupiedSeat){resetVehicleWindowFire();vehicleWindowFire.car=car;vehicleWindowFire.seatId=occupiedSeat;vehicleWindowFire.damage=carDamage;vehicleWindowFire.frame=vehicleWindowFrame(THREE,car,occupiedSeat);}
  vehicleWindowFire.blend=THREE.MathUtils.clamp(vehicleWindowFire.blend+(aiming?1:-1)*Math.max(0,dt)/.18,0,1);setVehicleWindowOpen(car,occupiedSeat,true);
  if(basePose){if(car.poseOccupant)car.poseOccupant(hero,occupiedSeat,{steer:carState.steer,dt:0});else hero.vehiclePose(1,0,{driver:canControlVehicle(occupiedSeat),steeringGrips:car.getSteeringGrips(),steer:carState.steer,dt:0});if(Math.cos(carRollover?.angle||0)>.5)vehicleImpactPoseResult=vehicleOccupantImpactPose.apply(hero,car,occupiedSeat,fleet?.active?.impactReaction?.sample());}
  const plan=aiming?planVehicleWindowShot({vehicleState:carState,seatId:occupiedSeat,aimDirection:camera.getWorldDirection(new THREE.Vector3()),weaponId:currentWeapon.id,frame:vehicleWindowFire.frame}):vehicleWindowFire.plan;vehicleWindowFire.plan=plan;
  vehicleWindowFire.result=applyVehicleWindowPose(THREE,hero.artistContext(),{plan,car,weapon:weaponModel,blend:vehicleWindowFire.blend});if(!aiming)vehicleWindowFire.result.canFire=false;weaponModel.visible=!!vehicleWindowFire.result.applied&&vehicleWindowFire.result.selfClear!==false;
 }
 const now=performance.now();if(now-vehicleWindowFire.diagnosticsAt>100){vehicleWindowFire.diagnosticsAt=now;const r=vehicleWindowFire.result;document.body.dataset.vehicleWindowFire=JSON.stringify({active:!!vehicleWindowFire.car,seatId:occupiedSeat,weaponId:currentWeapon.id,blend:vehicleWindowFire.blend,canFire:!!r?.canFire,reason:r?.reason||'',muzzle:r?.muzzle?.toArray(),direction:r?.direction?.toArray(),selfClear:r?.selfClear,ownCarClear:r?.ownCarClear,pending:vehicleWindowFire.pending});}
 updateVehicleWindowPrompt();
 return vehicleWindowFire.result;
}
function fireState(){if(!fireStates.has(currentWeapon.id))fireStates.set(currentWeapon.id,createWeaponFireState(currentWeapon.id));return fireStates.get(currentWeapon.id)}


function syncWorldWeapon(){
 if(!npcBridge)return;
 const source=npcBridge.getPlayerState(),id=npcWeaponId(source.weapon);
 if(currentWeapon.id!==id){artistInput.cancel();releaseWeapon();hero?.mountWeapon(null);disposeWeapon(weaponModel);weaponModel=null;currentWeapon=ARSENAL.find(w=>w.id===id);if(id!=='none'){weaponModel=createWeaponModel({THREE,id});hero?.mountWeapon(weaponModel)}}
 const state=fireState();state.magazine=source.magazine||0;state.reserveAmmo=source.reserve||0;
}
function updateCombat(dt,moving=false,running=false){
 syncWorldWeapon();
 const allowed=combatAllowed();if(!allowed)releaseWeapon();


 const posture=heroPosture.value>=1.95?'prone':heroPosture.value>=.95?'crouch':'stand';moving=moving||!!jump;running=(running&&moving)||!!jump;
 if(heroCover.active&&triggerPressed){if(!pendingCoverShotUntil)pendingCoverShotUntil=.65;pendingCoverShotUntil-=dt;if(pendingCoverShotUntil<=0)triggerPressed=false;}
 if(occupiedSeat&&aiming&&triggerPressed){if(!vehicleWindowFire.pending)vehicleWindowFire.pending=.65;vehicleWindowFire.pending-=dt;if(vehicleWindowFire.pending<=0)triggerPressed=false;}
 const shotReady=heroCover.canFire&&(!occupiedSeat||aiming&&vehicleWindowFire.result?.canFire);
 const fireInput={triggerHeld:allowed&&shotReady&&triggerHeld,triggerPressed:allowed&&shotReady&&triggerPressed,reload:allowed&&reloadPressed,aiming,posture,moving,running,coverFire:heroCover.active&&heroCover.mode==='blind'?'blind':null};
 const result=worldWalkCombat?worldWalkCombat.step(fireState(),fireInput,dt,{aimOrigin:occupiedSeat||heroCover.active?null:camera.position,origin:occupiedSeat?vehicleWindowFire.result?.muzzle:weaponModel?resolveWeaponShotTransforms(THREE,weaponModel).origin:null,forward:occupiedSeat?vehicleWindowFire.result?.direction||camera.getWorldDirection(new THREE.Vector3()):camera.getWorldDirection(new THREE.Vector3())}):stepWeaponFire(fireState(),fireInput,dt);fireStates.set(currentWeapon.id,result.state);if(occupiedSeat){if(!aiming||shotReady||!triggerPressed){triggerPressed=false;vehicleWindowFire.pending=0;}}else if(!heroCover.active||heroCover.canFire||heroCover.mode==='blocked'||!triggerPressed){triggerPressed=false;pendingCoverShotUntil=0;}reloadPressed=false;
 effects.update(dt);
 weaponCrosshair.update(result.state,{aiming,posture,moving,running,coverFire:fireInput.coverFire},{height:renderer.domElement.clientHeight||innerHeight,fov:camera.fov});
 const recoil=sampleWeaponRecoil(result.state),forward=occupiedSeat&&vehicleWindowFire.result?.direction?vehicleWindowFire.result.direction:camera.getWorldDirection(new THREE.Vector3());


 const active=allowed&&(aiming||triggerHeld||result.shots.length||recoil.normalized>0||result.state.reloadRemaining>0),aimPitch=Math.asin(THREE.MathUtils.clamp(forward.y,-.958,.958)),aimYaw=Math.atan2(forward.x,forward.z),profile=weaponFireProfile(currentWeapon.id),reloadProgress=result.state.reloadRemaining>0&&profile?1-result.state.reloadRemaining/profile.reloadSeconds:0;


 weaponHud?.setState({weaponId:currentWeapon.id,...result.state,...(npcBridge?{ownedWeaponIds:ownedWeaponIds()}:{}),disabled:!weaponInteractionAllowed({menu:true})});
 weaponHud?.setScopeVisible(allowed&&aiming&&currentWeapon.id==='sniper');


 $('cross').style.display=allowed&&(aiming||triggerHeld)&&!(aiming&&currentWeapon.id==='sniper')?'block':'none';


 const diagnosticsNow=performance.now();if(diagnosticsNow-fireDiagnosticsAt>=100){fireDiagnosticsAt=diagnosticsNow;document.body.dataset.heroFire=JSON.stringify({id:currentWeapon.id,allowed,walking,busy,arsenalOpen:arsenalOpen(),aiming,triggerHeld,magazine:result.state.magazine,reserve:result.state.reserveAmmo,reloading:result.state.reloadRemaining,recoil:recoil.normalized,...effects.stats()});}
 return {allowed,active,result,recoil,forward,aim:{aimYaw,aimPitch,recoil:recoil.weaponKick,recoilYaw:recoil.recoilYaw},reloadProgress};
}


function staticShotRoots(){const roots=[];for(const node of content.children){const chunks=node===landscape?.object||node===explorationDecor?.object?node.children:null;roots.push(...(chunks?.length?chunks:[node]))}return roots}
function shotObstacles(origin,direction,distance){const staticRoots=[...(shotRaycastIndex?.query(origin,direction,distance)??[content]),...(mercenaryShowcase?.getPickRoots()||[])],cars=[...(fleet?.records.map(record=>record.car.object)||[]),...(worldTrafficPresentation?.getActors().map(record=>record.object)||[])];return cars.length?[...staticRoots,...cars]:staticRoots}
function emitCombatShots(combat){
 if(!combat?.allowed||!weaponModel||!combat.result.shots.length)return;
 camera.updateMatrixWorld();aimRay.set(camera.position,combat.forward);aimRay.near=0;aimRay.far=100;
 const obstacles=shotObstacles(camera.position,combat.forward,100);for(const obstacle of obstacles)obstacle.updateWorldMatrix?.(true,true);
 const hit=aimRay.intersectObjects(obstacles,true).find(hit=>{for(let node=hit.object;node;node=node.parent)if(!node.visible)return false;return true}),target=hit?hit.point:aimRay.ray.at(100,new THREE.Vector3()),transforms=resolveWeaponShotTransforms(THREE,weaponModel);
 const coverTarget=heroCover.active||occupiedSeat?transforms.origin.clone().addScaledVector(combat.forward,100):target;
 for(const shot of combat.result.shots)effects.shoot(shot,transforms,shot.worldTarget||coverTarget,shotObstacles);
}
function updateAimCamera(dt){


 const desired=aiming&&combatAllowed()?1:0;


 controls.maxPolarAngle=Math.PI*(desired?.92:.48);


 const scoped=!!desired&&currentWeapon.id==='sniper';


 if(desired&&!savedCameraOffset)savedCameraOffset=camera.position.clone().sub(controls.target);


 aimBlend+=(desired-aimBlend)*(1-Math.exp(-14*dt));


 if(savedCameraOffset){


  const forward=camera.getWorldDirection(new THREE.Vector3()),right=new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0)).normalize();


  const target=occupiedSeat?vehicleWindowCameraTarget(forward):hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0)).add(heroCover.active?heroCover.offset:new THREE.Vector3()).addScaledVector(right,scoped?0:heroCover.active?coverCameraShoulder(heroCover.state,forward,heroCover.shoulder):.75),behind=forward.clone().multiplyScalar(scoped&&!occupiedSeat?-.12:-4.2);


  if(desired){if(scoped)camera.position.copy(target).add(behind);else camera.position.lerp(target.clone().add(behind),1-Math.exp(-10*dt));camera.position.y=Math.max(.3,camera.position.y);controls.target.copy(camera.position).addScaledVector(forward,4.2);camera.lookAt(controls.target);const radius=Math.hypot(savedCameraOffset.x,savedCameraOffset.z),horizontal=Math.hypot(forward.x,forward.z);if(horizontal>.001){savedCameraOffset.x=-forward.x/horizontal*radius;savedCameraOffset.z=-forward.z/horizontal*radius}}


  else {const normal=occupiedSeat?carLocal(0,2,1):hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0));controls.target.copy(normal);camera.position.lerp(normal.clone().add(savedCameraOffset),1-Math.exp(-14*dt));camera.lookAt(normal);if(aimBlend<.005)savedCameraOffset=null}


 }


 if(hero)hero.object.visible=!scoped;


 camera.fov=(scoped?14:45-3*aimBlend)+sampleWeaponRecoil(fireState()).weaponKick*.15;camera.updateProjectionMatrix();
 document.body.dataset.sniperScope=scoped?'active':'off';


}


let exitNotice='',exitNoticeUntil=0;


function receiveVehicleContact(contact){if(!car||!carState)return false;if(car.object.userData.receiveCollision)return car.object.userData.receiveCollision(contact);const damaged=carDamage.contactImpact(contact),rolled=carRollover.impact(contact,carState.yaw);return damaged||rolled}
function carLocal(side,front=0,y=0){if(car){car.object.updateWorldMatrix(true,false);return car.object.localToWorld(new THREE.Vector3(side,y,front))}const {x,z,yaw}=carState;return new THREE.Vector3(x+Math.cos(yaw)*side+Math.sin(yaw)*front,y,z-Math.sin(yaw)*side+Math.cos(yaw)*front)}
function pedestrianAllowed(x,z,ignoreSourceId=null){return canWalk(x,z)&&!worldTrafficPresentation?.blocks(x,z,0,{ignoreId:ignoreSourceId,y:hero?.object.position.y,height:1.9})&&(fleet?!fleet.overlaps(x,z,0):!carState||!pointInPolygon(x,z,carCorners(carState.x,carState.z,carState.yaw,carState.vehicleProfile)))}
function updateMercenaries(dt){
 if(!mercenaryShowcaseUI&&hero&&window.MafioziMercenaries?.qaSupported?.())initMercenaryShowcase();
 mercenaryShowcase?.update(dt,hero?.object.position);mercenaryShowcaseUI?.update(dt);
 if(!mercenaryWalk&&hero&&window.MafioziMercenaries){mercenaryWalk=createMercenaryWalk({THREE,document,onFollowGesture:signalHeroFollow,parent:document.body,camera,scene,getHost:()=>window.MafioziMercenaries,getFleet:()=>({records:[...(fleet?.records||[]),...(mercenaryShowcase?.getVehicles()||[])]}),getTraffic:()=>worldTrafficPresentation,getNpcs:()=>npcPopulation?.getActors()||[],getFocus:()=>hero?.object.position,getHero:()=>hero?.object,getPickRoots:(origin,direction,distance)=>[...shotObstacles(origin,direction,distance),...(npcPopulation?.getActors()||[]).map(r=>r.object)],getBuildings:()=>[...instances,...(mercenaryShowcase?.getTargets()||[]),...(mercenaryFences?.getTargets?.()||[]),...(mercenaryPowerPanel?.getTargets?.()||[]),...(window.MafioziInteriorSafeTargets?.getTargets?.()||[])],getRoots:()=>[content,...(fleet?.records||[]).map(r=>r.car.object),...(worldTrafficPresentation?.getActors()||[]).map(r=>r.object),...(npcPopulation?.getActors()||[]).map(r=>r.object)],canMove:(from,to)=>{const steps=Math.max(1,Math.ceil(Math.hypot(to.x-from.x,to.z-from.z)/.2));for(let i=1;i<=steps;i++){const t=i/steps;if(!pedestrianAllowed(from.x+(to.x-from.x)*t,from.z+(to.z-from.z)*t))return false;}return true;},groundHeight,isBlocked:()=>mercenaryInputBlocked()||!!occupiedSeat||!!transition||busy||arsenalOpen()||!$('scene-menu').hidden,onOpenChange:open=>{releaseControls();setFreeMouse(!open);if(open&&document.pointerLockElement)document.exitPointerLock();}});}
 mercenaryWalk?.update(dt);
}
function initMercenaryShowcase(){
 const host=()=>window.MafioziMercenaries;
 const applyBodies=({removed,added,context})=>{if(!host()?.qaSupported?.())return false;for(const list of[bodies,carBodies]){for(let i=list.length-1;i>=0;i--)if(removed.includes(list[i]))list.splice(i,1);list.push(...added);}walkCollisionIndex?.replaceGroup('world-static',bodies,{order:0,force:true});if(!['safe_door','breach_door_open','breach_door_motion'].includes(context?.kind)){if(laneRouteJobs){cityRoadStaticWorld=createCarWorld(topology,carBodies,M);laneRouteJobs.updateWorld(carBodies);}driveAllowed=withRailwayVehicleWorld(createExplorationVehicleWorld({topology,bodies:carBodies,terrain:explorationSurface,metresPerCell:M}),()=>explorationRailway);}return true;};
 mercenaryShowcase=createMercenaryProfessionShowcase({THREE,RoundedBox:RoundedBoxGeometry,scene:content,enabled:()=>host()?.qaSupported?.()===true,groundHeight,onCollisionChange:applyBodies,onPowerChange:()=>host()?.canUseLocalEffects?.()===true,canPlace:(x,z,radius=1.5)=>{for(const[dx,dz]of[[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius]])if(waterAt(x+dx,z+dz)||!pedestrianAllowed(x+dx,z+dz))return false;return true;},onExplosion:event=>{const vehicle=event.record?.car;if(vehicle){blastResponse?.enqueue({point:vehicle.object.localToWorld(new THREE.Vector3(0,1,0)),power:1,radius:10,source:vehicle});glass.shatterAll(vehicle.object,{impulse:80,weaponId:'vehicle_explosion'});}else if(event.kind==='breach_door_blast'&&event.position){blastResponse?.enqueue({point:new THREE.Vector3(event.position.x,event.position.y+.85,event.position.z),power:.65,radius:5,source:'mercenary_door'});}}});
 function inspect(kind='overview'){
  const layout=mercenaryShowcase?.layout;if(!layout||!hero||occupiedSeat||transition||busy)return {ok:false,message:'Сначала подготовьте площадку, находясь пешком на улице.'};
  const target=kind==='overview'?layout.lookAt:layout[kind];if(!target)return {ok:false,message:'Объект не найден.'};
  let spot=layout.entry;if(kind!=='overview'){spot=null;for(const[dx,dz]of[[0,-5],[-5,0],[5,0],[0,5]]){const x=target.x+dx,z=target.z+dz;if(pedestrianAllowed(x,z)&&!waterAt(x,z)){spot={x,y:groundHeight(x,z),z};break;}}if(!spot)return {ok:false,message:'Нет свободного места рядом с объектом.'};}
  releaseControls();hero.object.position.set(spot.x,spot.y,spot.z);resetFootSupport();const direction=new THREE.Vector3(target.x-spot.x,0,target.z-spot.z).normalize();hero.object.rotation.y=Math.atan2(direction.x,direction.z);followCarCamera=false;restoreBuildingCamera();savedCameraOffset=null;aimBlend=0;controls.target.copy(hero.object.position).y+=postureEyeHeight();const look=new THREE.Vector3(target.x,target.y+(kind==='patient'?.35:kind==='door'?1.15:1.0),target.z),viewDirection=look.sub(controls.target).normalize();camera.position.copy(controls.target).addScaledVector(viewDirection,-5);camera.lookAt(controls.target);setFreeMouse(false);npcBridge?.syncWalkPlayer?.({r:spot.z/M,c:spot.x/M,ang:Math.PI/2-hero.object.rotation.y,walking:false,stance:heroPosture.target});return{ok:true,message:kind==='overview'?'Площадка готова. Наведитесь на объект и нажмите X.':'X — действие специалиста. X на земле — отмена и движение.'};
 }
 mercenaryShowcaseUI=createMercenaryShowcaseUI({document,prepare:async()=>{if(!hero||occupiedSeat||transition||busy||worldHealthFrame?.inputsBlocked)return{ok:false,message:'Выйдите живым героем на улицу.'};const result=await mercenaryShowcase.show(hero.object.position);if(!result.ok)return{...result,message:result.reason==='no_clear_site'?'Рядом нет свободной площадки. Подойдите к открытому месту.':result.reason};inspect('overview');const assembled=host().qaAssembleProfessions({positions:Object.fromEntries(result.layout.recruits.map(({profession,...position})=>[profession,position])),patientPosition:result.layout.patient});return{...assembled,message:assembled.ok?'Объекты и отряд готовы. X на объекте — действие, X на земле — к точке.':'Объекты выставлены. '+(assembled.message||assembled.reason||'Не все специалисты готовы — повторите подготовку.')};},inspect,wound:()=>mercenaryShowcase.layout?host().qaPlacePatient({position:mercenaryShowcase.layout.patient}):{ok:false,reason:'Сначала подготовьте площадку.'},getState:()=>({layout:mercenaryShowcase?.layout,safe:mercenaryShowcase?.safe?.getState(),door:mercenaryShowcase?.door?.getState(),vehicles:mercenaryShowcase?.getVehicles().map(v=>({id:v.id,hp:v.damage.state.hp,wrecked:v.damage.state.wrecked})),members:host()?.getRoster?.().members,actions:host()?.getRoster?.().members?.map(m=>{const action=host().getAction(m.id),member=host().getMember(m.id),target=action&&host().getTarget(action.targetId);return{id:m.id,action,position:member?.position,movement:member?.movement,posture:member?.posture,target:target&&{position:target.position,workPoint:target.workPoint,workRange:target.workRange}};}),targets:mercenaryShowcase?.getTargets().map(t=>({id:t.id,kind:t.object?.userData?.mercenaryTarget?.kind,cut:t.object?.userData?.mercenaryCut,powered:t.object?.userData?.mercenaryTarget?.powered}))})});
}
function exitWalkAllowed(x,z){return canWalk(x,z)&&!worldTrafficPresentation?.blocks(x,z,0,{ignoreId:car?.object?.userData?.sourceVehicleId,y:hero?.object.position.y,height:1.9})&&(!fleet||!fleet.overlaps(x,z,0,fleet.activeId))}
function waterExitCapsule(position,height=1.1){
 const radius=EXIT.radius;
 for(const[dx,dz]of[[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius]]){
  const x=position.x+dx,z=position.z+dz,y=position.y;
  if(!traversalMapContains(x,z)||groundHeight(x,z,y)>y+.08||ceilingHeight(x,z,y)<y+height-.02)return false;
  for(const body of walkCollisionIndex?.(x/M,z/M)||[]){if((body.maxYM??Infinity)<y+.05||(body.minYM??-Infinity)>y+height-.03)continue;if(inPolygon(z/M,x/M,body.polygonCR))return false;}
  for(const record of fleet?.records||[]){if(record.car===car)continue;const bottom=record.car.object.position.y,top=bottom+(record.car.profile?.height||2);if(top<y+.05||bottom>y+height)continue;if(carOverlapsCircle(record.state,x,z,0))return false;}
 }
 return true;
}
function isWaterExit(seatId){
 if(!car||!carState)return false;
 const point=vehicleWaterDeparturePoint({THREE,car,state:carState,seatId,distance:1.9,progress:1}),water=waterAt(point.x,point.z);
 return !!water&&water.depth>0&&point.y<water.level-.05;
}
function planWaterExit(seatId){
 const seat=vehicleSeat(seatId,carState);
 for(const distance of[1.9,2.4]){
  let clear=true,point;
  for(let i=0;i<=24;i++){point=vehicleWaterDeparturePoint({THREE,car,state:carState,seatId,distance,progress:i/24});if(!waterExitCapsule(point)){clear=false;break;}}
  if(clear&&!carOverlapsCircle(carState,point.x,point.z,EXIT.radius)&&canAscendFromVehicle({position:point,waterAt,canOccupy:waterExitCapsule}))return{seatId,doorId:seat.doorId,side:seat.side,distance,kind:'walk',waterExit:true,landing:point};
 }
 return null;
}
function unattendedAllowed(x,z){return driveAllowed(x,z)}
unattendedAllowed.contactAt=(...args)=>driveAllowed.contactAt?.(...args);
unattendedAllowed.poseAllowed=(x,z,yaw,profile=carState?.vehicleProfile)=>driveAllowed.poseAllowed(x,z,yaw,profile)&&(!hero||!carOverlapsCircle({x,z,yaw,vehicleProfile:profile},hero.object.position.x,hero.object.position.z,transition?.phase==='body'?EXIT.radius:.36));
function carExitSpot(seatId='front_left'){if(!carState)return null;if(isWaterExit(seatId)){const plan=planWaterExit(seatId);return plan?new THREE.Vector3(plan.landing.x,plan.landing.y,plan.landing.z):null;}for(const distance of [1.9,2.4]){const p=vehicleDoorPoint(carState,seatId,distance);if(circleFits(p.x,p.z,pedestrianAllowed))return new THREE.Vector3(p.x,groundHeight(p.x,p.z),p.z)}return null}
function poseVehicleOccupant(seatId,fold=1,reach=0,pose={}){if(car.poseOccupant)car.poseOccupant(hero,seatId,{fold,reach,pose,reclineBlend:fold,steer:carState.steer});else hero.vehiclePose(fold,reach,pose)}
function activateVehicle(record){
 if(!record||!fleet)return;fleet.syncActive(carState);const active=fleet.activate(record);car=active.car;carState=active.state;carDamage=active.damage;carRollover=active.roll;tyres=active.tyres;carTrunk=active.trunk;carHood=active.hood;frameInteraction=frameEntrySpot=undefined;
}
function squadVehicleLocked(record){const sourceId=record?.car?.object?.userData?.sourceVehicleId;return sourceId!=null&&window.MafioziMercenaryVehicleLocks?.get(sourceId)?.locked===true;}
function entrySpot({fresh=false}={}){
 // updateCarInteraction() and the prompt query the same door after movement
 // has settled for this frame. Keep that exact result (including null) so a
 // parked fleet does not run the capsule admission path twice per render.
 // Input-triggered interaction asks for fresh data and is never served here.
 if(!fresh&&frameEntrySpot!==undefined)return frameEntrySpot;
 if(!hero||!carState||transition||jump||heroBlast){if(!fresh)frameEntrySpot=null;return null}if(occupiedSeat){const exit=carExitSpot(occupiedSeat);if(!fresh)frameEntrySpot=exit;return exit}
 let nearest=null;
 for(const record of fleet?.nearby(hero.object.position)||[]){
  if(record.damage?.disabled||record.roll?.unstable||record.state?.waterState?.flooded||squadVehicleLocked(record))continue;
  const candidate=findVehicleEntry(record.state,hero.object.position,canWalk);if(!candidate||candidate.near>=(nearest?.near??Infinity))continue;
  const from=hero.object.position,to=candidate.outside;let clear=true;for(let i=0;i<=12;i++){const t=i/12;if(!circleFits(from.x+(to.x-from.x)*t,from.z+(to.z-from.z)*t,pedestrianAllowed)){clear=false;break}}if(clear)nearest={...candidate,record,seatLabel:candidate.label,label:`${record.car.profile.label} · ${candidate.label}`};
 }
 const sourceCandidate=sourceVehicleAccess?.findEntry(hero.object.position,pedestrianAllowed);
 if(sourceCandidate&&sourceCandidate.near<(nearest?.near??Infinity))nearest=sourceCandidate;
 if(!fresh)frameEntrySpot=nearest;return nearest;
}
function entryEligible(){return !!entrySpot()}
function beginCarTransition(){
 const sourceCandidate=entrySpot({fresh:true});if(!occupiedSeat&&sourceCandidate?.sourceOwned){requestSourceVehicle('enter',sourceCandidate);return;}
 if(!entryEligible())return;releaseWeapon();exitSwimHandoff=null;entryArmed=false;entryHeld=0;pointerHeld=false;keys.clear();


 setArsenalOpen(false);
 if(occupiedSeat){
  const plan=isWaterExit(occupiedSeat)?planWaterExit(occupiedSeat):planVehicleSeatExit(carState,occupiedSeat,fleet?.blockingWorld(driveAllowed)||driveAllowed,exitWalkAllowed);
  if(!plan){exitNotice='Нет безопасного места сбоку — отъедь от препятствия';exitNoticeUntil=performance.now()+2500;return}
  lastDoorSide=plan.side;transition={exiting:true,phase:'door',elapsed:0,...plan,door:0};
 }else{
  const candidate=entrySpot({fresh:true});if(!candidate||squadVehicleLocked(candidate.record))return;activateVehicle(candidate.record);lastDoorSide=candidate.side;transition={exiting:false,elapsed:0,...candidate,from:hero.object.position.clone(),outside:new THREE.Vector3(candidate.outside.x,candidate.outside.y,candidate.outside.z)};carState.speed=0;carState.distance=0;
 }
 resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);$('district').disabled=true;$('walk').disabled=true;$('reload').disabled=true;controls.enablePan=false;hero.reset();
}


function finishExit(){hero.object.rotation.z=0;transition=null;occupiedSeat=null;car.setDoorById(0,'front_left');hero.reset();const floor=heroGroundHeight(hero.object.position.x,hero.object.position.z),water=waterAt(hero.object.position.x,hero.object.position.z);exitSwimHandoff=water?createExitSwimHandoff({fromY:hero.object.position.y,waterLevel:water.level}):null;hero.object.position.y=exitSwimHandoff?exitSwimHandoff.update(floor+(artistSurfaceState?.swim.liftWorld||0),0):floor;surfaceMotion.reset({x:hero.object.position.x,y:floor,z:hero.object.position.z});setWalking(true);ensureVehicleExitVisible(THREE,{hero,car,camera,controls,eyeHeight:postureEyeHeight()});keys.clear();$('district').disabled=false;$('walk').disabled=false;$('reload').disabled=false;if(exitQaMode&&$('exit-qa-status'))$('exit-qa-status').textContent='Тест выхода завершён';}
function abortExit(){
 occupiedSeat=transition?.seatId||occupiedSeat;transition=null;car.setDoorById(0,occupiedSeat);hero.reset();const p=vehicleWaterSeatPoint({THREE,car,state:carState,seatId:occupiedSeat});hero.object.position.set(p.x,p.y,p.z);hero.object.rotation.y=carState.yaw;poseVehicleOccupant(occupiedSeat,1,0,{driver:canControlVehicle(occupiedSeat),steeringGrips:car.getSteeringGrips()});
 exitNotice='Выход отменён: рядом препятствие';exitNoticeUntil=performance.now()+2500;
}
function updateMovingExit(dt){


 const t=transition;
 if(t.phase==='door'){
  t.elapsed+=dt;const p=Math.min(1,t.elapsed/EXIT.releaseSeconds),point=t.waterExit?vehicleWaterDeparturePoint({THREE,car,state:carState,seatId:t.seatId,distance:t.distance,progress:p}):vehicleDeparturePoint(carState,t.seatId,t.distance,p);const carBaseY=car.object.position.y;if(!t.waterExit)point.y+=carBaseY;
  const roll=carRollover?.stats().angle||0;if(roll&&!t.waterExit){const a=vehicleSeat(t.seatId,carState).anchor,flat=vehicleSeatPoint(carState,t.seatId);car.object.updateWorldMatrix(true,false);const tilted=car.object.localToWorld(new THREE.Vector3(a.side,a.y,a.front));point.x+=(tilted.x-flat.x)*(1-p);point.y+=(tilted.y-flat.y-carBaseY)*(1-p);point.z+=(tilted.z-flat.z)*(1-p);}hero.object.rotation.z=roll*(1-p);
  if(t.waterExit?!waterExitCapsule(point):!circleFits(point.x,point.z,exitWalkAllowed,EXIT.radius)){abortExit();return}
  hero.object.position.set(point.x,point.y,point.z);hero.object.rotation.y=carState.yaw-t.side*(1-point.pose.seat)*Math.PI/2;
  const fold=t.kind==='tumble'?Math.max(point.pose.fold,THREE.MathUtils.smoothstep(p,.35,.9)):point.pose.fold;
  poseVehicleOccupant(t.seatId,fold,point.pose.reach,point.pose);t.door=Math.min(1,p/.2);car.setDoorById(t.door,t.doorId);
  if(p>=1){
   if(carOverlapsCircle(carState,point.x,point.z,EXIT.radius)){abortExit();return}
   t.phase='body';t.body=launchExitBody(point,carState,t.side,t.kind);t.surface=t.waterExit?createVehicleWaterExitSurface({position:point,groundHeight,waterAt,canOccupy:waterExitCapsule}):createVehicleExitSurface({position:point,groundHeight:(x,z,referenceY)=>traversalWorld.supportHeight(x,z,referenceY),waterAt});t.elapsed=0;occupiedSeat=null;hero.reset();
   const supported=t.surface.update({x:t.body.x,z:t.body.z,dt:0,hop:t.body.y});hero.object.position.set(supported.x,supported.y,supported.z);hero.object.rotation.y=t.body.heading;
   if(t.kind==='tumble')hero.tumblePose(0,t.body.rolls,{floorHeight:createExitPoseFloorSampler(hero.object.position,t.surface.floorHeight)});
  }
 }else{


  t.body=stepExitBody(t.body,dt,pedestrianAllowed);t.elapsed=t.body.elapsed;
  if(exitQaMode&&$('exit-qa-status'))$('exit-qa-status').textContent=t.kind==='tumble'?'Перекат':'Шаг из машины';
  const supported=t.surface.update({x:t.body.x,z:t.body.z,dt,hop:t.body.y});t.body.x=supported.x;t.body.z=supported.z;hero.object.position.set(supported.x,supported.y,supported.z);hero.object.rotation.y=t.body.heading;
  if(t.kind==='tumble')hero.tumblePose(t.body.progress,t.body.rolls,{floorHeight:createExitPoseFloorSampler(hero.object.position,t.surface.floorHeight)});else hero.update(dt,Math.hypot(t.body.vx,t.body.vz)>.15,false);
  t.door=Math.max(0,1-t.elapsed/.3);car.setDoorById(t.door,t.doorId);if(t.waterExit&&supported.blocked){exitNotice='Над выходом препятствие';exitNoticeUntil=performance.now()+1000;}if(t.body.done&&supported.grounded&&!supported.blocked)finishExit();
  if(exitQaMode&&t.kind==='tumble'&&t.body.progress>=.23&&!t.body.done&&$('exit-qa-freeze')?.checked)exitQaPaused=true;


 }


}


function setCarInteractionText(id,text){const node=$(id);if(node.textContent!==text)node.textContent=text;}
function updateCarInteraction(dt){
 if(sourceVehicleActive()){
  sourceVehicleAccess?.poll();const pressed=keys.has('KeyE')&&!buildingKeyConsumed;if(!pressed)entryArmed=true;
  const hold=advanceEntryHold(entryHeld,pressed&&entryArmed,sourceVehicleState.phase==='driving',dt,EXIT_HOLD_SECONDS);entryHeld=hold.elapsed;
  setCarInteractionText('drive-status',sourceVehicleState.phase==='driving'?'E · удержать 0,3 с — выйти':sourceVehicleState.phase==='pull_driver'?'Вытаскиваем водителя…':sourceVehicleState.phase==='exit'?'Выходим…':'Садимся…');
  if(hold.ready)requestSourceVehicle('exit');return;
 }
 if(!car||!hero)return;
 let entryCandidate=null,entryAvailable=false;
 if(transition?.exiting){updateMovingExit(dt);setCarInteractionText('car',transition?.kind==='tumble'?'Выпрыгиваем…':'Выходим…');}
 else if(transition){
  const t=transition;t.elapsed+=dt;const p=Math.min(1,t.elapsed/TRANSITION_SECONDS),outside=t.from.clone().lerp(t.outside,Math.min(1,p/.25)),point=vehicleEntryPoint(carState,t.seatId,p,outside),pose=point.pose;point.y+=groundHeight(point.x,point.z);
  hero.object.position.set(point.x,point.y,point.z);hero.object.rotation.y=point.yaw;poseVehicleOccupant(t.seatId,pose.fold,pose.reach,pose);t.door=pose.door;car.setDoorById(pose.door,t.doorId);
  setCarInteractionText('car',t.exiting?'Выходим…':'Садимся…');
  if(pose.done){occupiedSeat=t.seatId;transition=null;car.setDoorById(0,t.doorId);hero.reset();setWalking(true);keys.clear();$('district').disabled=true;$('walk').disabled=true;$('reload').disabled=true;}
 }else{


  const pressed=(keys.has('KeyE')&&!buildingKeyConsumed)||pointerHeld;if(!pressed)entryArmed=true;
  // Entry validation traces a capsule path around the vehicle. Keep exactly
  // one result for this frame instead of repeating that same search for hold
  // admission and the HUD text below.
  entryCandidate=entrySpot();entryAvailable=!!entryCandidate;
  const holdDuration=occupiedSeat?EXIT_HOLD_SECONDS:HOLD_SECONDS;


  const hold=advanceEntryHold(entryHeld,pressed&&entryArmed,entryAvailable&&(occupiedSeat||pointerHeld||nearestInteraction({fresh:true})?.kind==='car'),dt,holdDuration);entryHeld=hold.elapsed;
  setCarInteractionText('car',entryHeld>0?`Удерживай E · ${Math.round(entryHeld/holdDuration*100)}%`:occupiedSeat?'Удерживай E 0,3 с — выйти':'Удерживай E 0,3 с — сесть');


  if(hold.ready)beginCarTransition();


 }
 const state=transition?(transition.exiting?(transition.phase==='body'?(transition.kind==='tumble'?'tumbling':'stepping_off'):'exiting'):'entering'):occupiedSeat?(canControlVehicle(occupiedSeat)?'driving':'passenger'):'on_foot';
 setCarInteractionText('drive-status',performance.now()<exitNoticeUntil?exitNotice:transition?(transition.exiting?(transition.kind==='tumble'?'Выпадение и перекат…':'Выход на ходу…'):`Посадка · ${car.profile.label} · ${vehicleSeat(transition.seatId,carState).label}`):occupiedSeat?`${car.profile.label} · ${vehicleSeat(occupiedSeat,carState).label} · ${Math.round(Math.abs(carState.speed)*3.6)} км/ч · E 0,3 с — ${Math.abs(carState.speed)>EXIT.tumbleSpeed?'выпрыгнуть':'выйти'}${currentWeapon.id==='none'?' · Q — достать оружие':' · ПКМ — прицел из окна'}${carState.waterState?.engineDisabled?' · мотор затоплен — тяги нет':carDamage?.disabled?' · машина уничтожена':carState.bumped?' · препятствие':''}`:carDamage?.disabled?'Машина уничтожена':entryAvailable?`E · удержать 0,3 с — ${entryCandidate.label}`:Math.abs(carState.speed)>.5?'Машина катится по инерции':'');
 const diagnosticsNow=performance.now();if(diagnosticsNow-carDriveDiagnosticsAt>=100){carDriveDiagnosticsAt=diagnosticsNow;document.body.dataset.carDrive=JSON.stringify({vehicleId:fleet?.activeId,state,occupiedSeat,driving:canControlVehicle(occupiedSeat),speed:carState.speed,x:carState.x,z:carState.z,yaw:carState.yaw,steer:carState.steer||0,hold:entryHeld,doorSide:lastDoorSide,doorId:transition?.doorId||null,door:transition?.door||0,exitKind:transition?.kind||null,exitProgress:transition?.body?.progress||0,wheelSpin:car.wheels[0].wheel.rotation.x,handbrake:!!carState.handbrake,yawRate:carState.yawRate||0,slipAngle:carState.slipAngle||0,lateralVelocity:carState.lateralVelocity||0,bumped:!!carState.bumped,contact:carState.contact||null,maneuver:carQa?.stats?.()||null,y:car.object.position.y,water:carState.waterState||null});}
}
function setWalkPromptHidden(prompt,hidden){if(prompt.hidden!==hidden)prompt.hidden=hidden;}
function updateCarPrompt(){
 const prompt=$('car-prompt'),candidate=nearestInteraction(),selected=candidate?.kind==='car'?candidate.spot:null,service=candidate?.kind==='trunk'||candidate?.kind==='hood';
 entryDoorHighlight.update(selected,{enabled:!!car&&!!hero&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!hudInputBlocked(),position:hero?.object.position});
 if(!car||!hero||occupiedSeat||sourceVehicleActive()||transition||(!selected&&!service)){setWalkPromptHidden(prompt,true);return}
 let anchor;
 if(service){anchor=new THREE.Vector3(candidate.anchor.x,candidate.anchor.y,candidate.anchor.z);anchor.y+=Math.max(.65,candidate.record.car.profile.height*.28);}
 else{const owner=selected.record.car,a=owner.anchors.doors.find(door=>door.id===selected.doorId)?.handle;if(!a){prompt.hidden=true;return}owner.object.updateWorldMatrix(true,false);anchor=owner.object.localToWorld(new THREE.Vector3(a.side,a.y??Math.min(1.95,owner.profile?.height||1.95),a.front));}
 const screen=anchor.project(camera);prompt.hidden=screen.z<-1||screen.z>1||Math.abs(screen.x)>1.1||Math.abs(screen.y)>1.1;
 $('car-seat-label').textContent=service?`${candidate.record.car.profile.label} · ${candidate.label}`:selected.label;
 prompt.querySelector('small').textContent=service?(candidate.action==='repair'?'R — ремонт двигателя':candidate.kind==='hood'&&(candidate.repairAvailable||candidate.record.hood?.stats().open)?'E — закрыть · R — ремонт двигателя':'E — нажать'):'Удерживайте E · 0,3 с · Ctrl — в укрытие';
 if(!prompt.hidden){const x=Math.round((screen.x+1)*innerWidth/2),y=Math.round((1-screen.y)*innerHeight/2);prompt.style.transform=`translate3d(${x}px,${y}px,0) translate(-50%,-100%)`;$('car-hold-progress').style.transform=`scaleX(${service?0:entryHeld/HOLD_SECONDS})`}
}
function waterAt(x,z){
 if(landscape?.contains(x,z))return landscape.waterAt(x,z);


 const r=Math.floor(z/M),c=Math.floor(x/M);if(topology?.grid?.[r]?.[c]!==16||topology?.protectedMask?.[r]?.[c])return null;


 let shore=3.5;for(let rr=r-1;rr<=r+1;rr++)for(let cc=c-1;cc<=c+1;cc++){if(topology?.grid?.[rr]?.[cc]===16)continue;const dx=Math.max(cc*M-x,0,x-(cc+1)*M),dz=Math.max(rr*M-z,0,z-(rr+1)*M);shore=Math.min(shore,Math.hypot(dx,dz));}


 const floor=-Math.min(2.4,shore*.9);return {level:-.18,depth:Math.max(0,-.18-floor),floor};


}


function ladderPathDistance(point,ladder){const path=ladder?.path;if(!Array.isArray(path)||path.length<2)return Infinity;let best=Infinity;for(let i=1;i<path.length;i++){const a=path[i-1],b=path[i],dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,len=dx*dx+dy*dy+dz*dz,t=len?Math.max(0,Math.min(1,((point.x-a.x)*dx+(point.y-a.y)*dy+(point.z-a.z)*dz)/len)):0,q={x:a.x+dx*t,y:a.y+dy*t,z:a.z+dz*t};best=Math.min(best,Math.hypot(point.x-q.x,point.y-q.y,point.z-q.z))}return best}
const verticalNavigation=createBuildingVerticalNavigation({THREE,getHero:()=>hero,getEntries:()=>buildingEntries,getWeapon:()=>weaponModel,camera,controls,canOccupy(p,radius,height,ctx){const ladder=ctx?.ladder,nearLadder=ladderPathDistance(p,ladder)<=radius+.18;for(const[dx,dz]of[[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius]]){const x=p.x+dx,z=p.z+dz,c=x/M,r=z/M;if(!nearLadder&&ceilingHeight(x,z,p.y)<p.y+height-.03)return false;for(const body of walkCollisionIndex?.(c,r)||[]){if((body.maxYM??Infinity)<p.y+.08||(body.minYM??-Infinity)>p.y+height-.03)continue;if(inPolygon(r,c,body.polygonCR)){const part=String(body.storeyPart||'');if(nearLadder&&ladder?.id&&body.buildingEntryId===ladder.id&&!part.startsWith('Roof_Ladder_Rail_Collision'))continue;return false}}}return true},onBegin(){jump=null;artistInput.cancel();releaseControls();releaseWeapon();resetHeroPosture(heroPosture);hero.reset()},onEnd(){releaseControls();surfaceMotion.reset(hero.object.position);hero.reset()}});
function sampledBuildingEntries(x,z){const candidates=buildingSampleIndex?.(x/M,z/M);return candidates?candidates.map(candidate=>candidate.entry):buildingEntries}
const nearbyEntryScratch=[],cameraEntryScratch=[];
function nearbyBuildingEntries(point,padding=3){
 return collectNearbyBuildingEntries(buildingEntries,point,padding,nearbyEntryScratch);
}
function groundHeight(x,z,referenceY=0){for(const entry of sampledBuildingEntries(x,z)){const y=entry.floorHeight(x,z,referenceY);if(y!==null)return y}const railFloor=explorationRailway?.floorHeight(x,z);if(railFloor!=null)return railFloor;const water=waterAt(x,z);return water?water.floor:(landscape?.groundHeight(x,z)??0)}
function heroGroundHeight(x,z){return traversalWorld.supportHeight(x,z,hero?.object.position.y??0)}
function heroCeilingHeight(x,z){return ceilingHeight(x,z,hero?.object.position.y??0)}
function ceilingHeight(x,z,referenceY=0){let height=Infinity;for(const entry of sampledBuildingEntries(x,z)){const y=entry.ceilingHeight({x,z,y:referenceY});if(y!==null)height=Math.min(height,y)}return height}
function canOccupyPostureHeight(height,x=hero?.object.position.x,z=hero?.object.position.z){


 if(!Number.isFinite(x)||!Number.isFinite(z))return false;const floor=heroGroundHeight(x,z);if(heroCeilingHeight(x,z)<floor+height-.03)return false;const r=z/M,c=x/M;


 for(const body of walkCollisionIndex?.(c,r)||[]){if(body.maxYM!==undefined&&body.maxYM<floor+.05)continue;if(body.minYM!==undefined&&body.minYM>floor+height)continue;if(inPolygon(r,c,body.polygonCR))return false}return true;


}


let landingEyeTransition=null;function postureEyeHeight(){const target=postureMotion?.eyeHeight||1.1;if(!landingEyeTransition)return target;const t=Math.max(0,Math.min(1,(performance.now()-landingEyeTransition.start)/(LANDING_POSTURE_SECONDS*1000))),blend=t*t*(3-2*t),height=landingEyeTransition.from+(target-landingEyeTransition.from)*blend;if(t===1)landingEyeTransition=null;return height;}


function setHeroPosture(target){
 if(worldHealthFrame?.inputsBlocked)return false;
 if(!hero||occupiedSeat||transition||heroBlast||verticalNavigation.active||busy||!walking)return false;if(jump){jump.queuedPosture=target==='stand'?null:target;return true;}


 const accepted=requestHeroPosture(heroPosture,target,{canOccupyHeight:height=>canOccupyPostureHeight(height)});if(accepted&&target!=='prone'){animationQaMoveUntil=0;animationQaMoveDirection=null}if(!accepted){exitNotice='Над головой мало места, чтобы подняться';exitNoticeUntil=performance.now()+1800}return accepted;


}


function resetFootSupport(){if(!hero)return;hero.object.position.y=heroGroundHeight(hero.object.position.x,hero.object.position.z);surfaceMotion.reset(hero.object.position)}


function insideBuilding(){return !!hero&&buildingEntries.some(entry=>entry.containsInterior(hero.object.position))}


let frameInteraction,frameEntrySpot;
function nearestInteraction({fresh=false}={}){
 if(!fresh&&frameInteraction!==undefined)return frameInteraction;
 if(!hero||!walking||occupiedSeat||transition||jump||heroBlast||verticalNavigation.active||busy||arsenalOpen()||!$('scene-menu').hidden)return null;
 let nearest=null;const ladder=verticalNavigation.nearest();if(ladder)nearest={kind:'ladder',distance:ladder.distance,ladder,anchor:new THREE.Vector3(ladder.ladder[ladder.end].x,ladder.ladder[ladder.end].y+1.5,ladder.ladder[ladder.end].z),action:ladder.end==='lower'?'Подняться на крышу':'Быстро спуститься по лестнице'};
 for(const entry of nearbyBuildingEntries(hero.object.position,3)){const proximity=entry.proximity(hero.object.position);if(proximity&&(!nearest||proximity.distance<nearest.distance))nearest={kind:'building',entry,...proximity}}
 const spot=entrySpot({fresh});if(spot&&(!nearest||spot.near<nearest.distance))nearest={kind:'car',distance:spot.near,spot};
 for(const record of fleet?.nearby(hero.object.position)||[])for(const kind of ['trunk','hood']){const controller=record[kind],service=controller?.interaction(hero.object.position,record.state,{damageState:record.damage.state,occupied:false,transition:false,blocked:record.roll?.unstable});if(service&&(!nearest||service.near<nearest.distance))nearest={...service,kind,record,controller,distance:service.near};}
 if(!fresh)frameInteraction=nearest;return nearest;
}
function interactWithVehiclePanel(repair=false){
 const candidate=nearestInteraction({fresh:true});if(!['trunk','hood'].includes(candidate?.kind)||repair&&candidate.kind!=='hood')return false;
 const record=candidate.record;buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;keys.delete('KeyE');releaseWeapon();
 const context={hero:hero.object.position,vehicleState:record.state,damage:record.damage,damageState:record.damage.state,occupied:false,transition:false,blocked:record.roll?.unstable},result=repair||candidate.action==='repair'?candidate.controller.repair(context):candidate.controller.toggle(context);
 if(repair&&result?.accepted||result?.reason){const reasons={'hood-closed':'Сначала открой капот','moving':'Останови машину','out-of-range':'Подойди ближе','destroyed':'Машина уничтожена','burning':'Сначала нужно потушить пожар','blocked':'Поставь машину на колёса','detached':'Крышка сорвана'};exitNotice=result.accepted?'Двигатель и охлаждение отремонтированы':reasons[result.reason]||'Сейчас недоступно';exitNoticeUntil=performance.now()+2200}frameInteraction=undefined;return true;
}
function interactWithBuilding(){
 const candidate=nearestInteraction({fresh:true});if(candidate?.kind==='ladder'){if(candidate.ladder.end!=='lower')return false;buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;if(!verticalNavigation.begin(candidate.ladder)){exitNotice='Проход к лестнице закрыт';exitNoticeUntil=performance.now()+1800}return true}if(candidate?.kind!=='building')return false;
 buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;releaseWeapon();


 const result=candidate.entry.interact(hero.object.position);


 if(!result.accepted&&result.reason==='door-sweep-occupied'){exitNotice='Отойдите от створок, чтобы закрыть дверь';exitNoticeUntil=performance.now()+1800}


 return true;


}


function updateBuildingEntries(dt){
 if(!walkCollisionIndex){walkCollisionIndex=createIncrementalWalkCollisionIndex();walkCollisionIndex.replaceGroup('world-static',bodies,{order:0});entryBodyVersions.clear()}
 updateWalkEntryCollisionGroups(walkCollisionIndex,entryBodyVersions,buildingEntries,dt,hero?.object.position);
 if(walkCollisionDiagnostic){const now=performance.now(),d=walkCollisionDiagnostic;if(now-d.at>=1000){const stats=walkCollisionIndex.stats,previous=d.index===walkCollisionIndex?d.stats:null;document.body.dataset.walkCollisionIndex=JSON.stringify({...stats,totalBodies:stats.bodyReferences,dirtyGroups:stats.replacements-(previous?.replacements??0),verticesVisitedDelta:stats.verticesVisited-(previous?.verticesVisited??0),bodiesVisitedDelta:stats.bodiesVisited-(previous?.bodiesVisited??0),queryCacheBuildsDelta:stats.queryCacheBuilds-(previous?.queryCacheBuilds??0),windowMs:Number.isFinite(d.at)?now-d.at:0,counterWindow:previous?'interval':'generation'});d.at=now;d.index=walkCollisionIndex;d.stats=stats}}
}


function updateBuildingPrompt(){


 const prompt=$('building-prompt'),candidate=nearestInteraction();


 if(candidate?.kind!=='building'&&candidate?.kind!=='ladder'){setWalkPromptHidden(prompt,true);return}


 const screen=candidate.anchor.clone().project(camera);


 prompt.hidden=screen.z<-1||screen.z>1||Math.abs(screen.x)>1.1||Math.abs(screen.y)>1.1;


 $('building-action').textContent=buildingDoorPrompt(candidate);prompt.querySelector('kbd').textContent=candidate.kind==='ladder'&&candidate.ladder.end==='upper'?'Ctrl':'E';


 if(!prompt.hidden)prompt.style.transform=`translate3d(${Math.round((screen.x+1)*innerWidth/2)}px,${Math.round((1-screen.y)*innerHeight/2)}px,0) translate(-50%,-100%)`;


 if(!transition&&!occupiedSeat&&!jump&&performance.now()>=exitNoticeUntil)setCarInteractionText('drive-status',candidate.kind==='ladder'?(candidate.ladder.end==='upper'?'Ctrl — быстрый спуск':'E — подъём · Ctrl — скользить вниз'):'E — дверь · WASD — пройти');


}


function restoreBuildingCamera(){
 indoorHeroVisibility.restore();indoorCameraFrame=null;


 if(!cameraBeforeBuildingClamp)return;


 camera.position.copy(cameraBeforeBuildingClamp.position);controls.target.copy(cameraBeforeBuildingClamp.target);camera.quaternion.copy(cameraBeforeBuildingClamp.quaternion);camera.updateMatrixWorld();cameraBeforeBuildingClamp=null;


}


function clampBuildingCamera(dt){
 if(!hero||occupiedSeat||transition){indoorCamera.reset();return;}
 // Camera solving happens every render frame.  First reject distant complete
 // entries with their immutable world AABBs; the exact entry tests below still
 // decide every room/corridor/proximity result, so doors and interior camera
 // behaviour are unchanged.
 cameraEntryScratch.length=0;
 for(const entry of nearbyBuildingEntries(hero.object.position,12))if(entry.containsInterior(hero.object.position)||entry.proximity(hero.object.position,12))cameraEntryScratch.push(entry);
 const relevant=cameraEntryScratch;
 if(!relevant.length){indoorCamera.reset();return;}
 for(const entry of relevant)entry.visual.updateWorldMatrix(true,true);
 const current=relevant.find(entry=>entry.containsInterior(hero.object.position));
 indoorCameraFrame=indoorCamera.solve({feet:hero.object.position,eyeHeight:postureEyeHeight(),desired:camera.position,target:controls.target,objects:relevant.map(entry=>entry.visual),ceilingY:current?.ceilingHeight(hero.object.position)??Infinity,inside:!!current||verticalNavigation.active,aiming,dt});
 const view=indoorCameraFrame;
 if(view.position.distanceToSquared(camera.position)<1e-8&&view.target.distanceToSquared(controls.target)<1e-8)return;
 cameraBeforeBuildingClamp={position:camera.position.clone(),target:controls.target.clone(),quaternion:camera.quaternion.clone()};
 camera.position.copy(view.position);controls.target.copy(view.target);camera.lookAt(view.target);camera.updateMatrixWorld();
}


function initBuildingQa(){


 if(new URLSearchParams(location.search).get('buildingqa')!=='1')return;


 const panel=document.createElement('div');panel.id='building-qa';panel.style.cssText='position:absolute;top:120px;left:12px;z-index:6;padding:8px;background:#142b32;border:1px solid #d7b85e;display:flex;gap:5px;flex-wrap:wrap;max-width:440px';


 const add=(label,callback)=>{const button=document.createElement('button');button.textContent=label;button.onclick=callback;panel.append(button)};


 const available=()=>hero&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!busy;


 const choice=document.createElement('select');choice.id='building-qa-choice';choice.setAttribute('aria-label','Здание для проверки комнаты');


 for(const entry of buildingEntries)choice.add(new Option(`${entry.instance.assetId} · ${entry.instance.id}`,entry.instance.id));panel.append(choice);


 add('QA: к выбранной двери',()=>{


  if(!available()||!buildingEntries.length)return;


  releaseControls();restoreBuildingCamera();savedCameraOffset=null;aimBlend=0;


  const entry=buildingEntries.find(e=>e.instance.id===choice.value)||buildingEntries[0],point=entry.approachPoint();


  if(!circleFits(point.x,point.z,pedestrianAllowed))return;


  point.y=heroGroundHeight(point.x,point.z);hero.object.position.copy(point);surfaceMotion.reset(point);const facing=entry.roomPoint().sub(point);facing.y=0;facing.normalize();hero.object.rotation.y=Math.atan2(facing.x,facing.z);


  hero.reset();setWalking(true);$('scene-menu').hidden=true;setArsenalOpen(false);


  controls.target.copy(point).add(new THREE.Vector3(0,1.1,0));camera.position.copy(point).addScaledVector(facing,-5).add(new THREE.Vector3(0,2.6,0));camera.lookAt(controls.target);setFreeMouse(false);


 });


 add('QA: нажать E',()=>{if(available())interactWithBuilding()});


 for(const [label,method] of [['QA: пройти внутрь','roomPoint'],['QA: центр комнаты','roomCenterPoint'],['QA: хранилище','vaultPoint'],['QA: выйти наружу','approachPoint']])add(label,()=>{


  if(!available())return;const entry=buildingEntries.find(e=>e.containsInterior(hero.object.position)||e.proximity(hero.object.position,4));if(!entry)return;


  if(method==='vaultPoint'&&!entry.vaultPoint)return;releaseControls();setFreeMouse(false);const targets=method==='vaultPoint'?[entry.roomCenterPoint(),entry.vaultPoint()]:method==='roomCenterPoint'?[entry.roomPoint(),entry.roomCenterPoint()]:method==='approachPoint'?[entry.roomPoint(),entry.approachPoint()]:[entry.roomPoint()];buildingQaMove={entry,target:targets.shift(),remaining:targets,elapsed:0};


 });



 // Opt-in QA placement only; movement and E still run the normal controllers.
 const placeAtStair=(roof,upper=false)=>{
  if(!available())return;const entry=buildingEntries.find(e=>e.instance.id===choice.value);if(!entry)return;
  const ladder=entry.storeys?.ladder?.worldDescriptor,stair=entry.storeys?.stairs?.[0];
  if(roof?!ladder:!stair)return;
  const point=roof?new THREE.Vector3((upper?ladder.upper:ladder.lower).x,(upper?ladder.upper:ladder.lower).y,(upper?ladder.upper:ladder.lower).z):entry.storeys.worldPoint(stair.route[0]);
  const direction=roof?new THREE.Vector3(-ladder.normal.x,0,-ladder.normal.z):entry.storeys.worldPoint(stair.route[1]).sub(point).setY(0).normalize();
  releaseControls();restoreBuildingCamera();indoorCamera.reset();buildingQaMove=null;savedCameraOffset=null;aimBlend=0;resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);
  hero.object.position.copy(point);surfaceMotion.reset(point);hero.reset();hero.object.rotation.y=Math.atan2(direction.x,direction.z);setWalking(true);$('scene-menu').hidden=true;setArsenalOpen(false);
  controls.target.copy(point).y+=postureEyeHeight();camera.position.copy(controls.target).addScaledVector(direction,-5).y+=1.4;camera.lookAt(controls.target);setFreeMouse(false);
 };
 add('QA: к внутренней лестнице',()=>placeAtStair(false));
 add('QA: к наружной лестнице',()=>placeAtStair(true));
 add('QA: верх наружной лестницы',()=>placeAtStair(true,true));
 add('QA: прыжок',()=>{if(available())beginJump()});


 const status=document.createElement('span');status.id='building-qa-status';status.style.cssText='flex-basis:100%;color:#ffdfa4';status.textContent='Проверка входа в той же сцене';panel.append(status);document.body.append(panel);
}
async function loadVehicleFleet(origin){
 document.body.dataset.vehicleFleetLoading='0/12';let vehicles=[];
 try{vehicles=await loadArtistFleetModels({THREE,loader,RoundedBox:RoundedBoxGeometry,includeTaxi:true,vehicleFactory:wheelRenderOptimization?(...args)=>createArtistVehicle(...args,{wheelRenderOptimization:true}):undefined,baseUrl:root+'models/artist_vehicle_pack/',onProgress:progress=>{document.body.dataset.vehicleFleetLoading=JSON.stringify(progress)}})}catch(error){vehicles=error.vehicles||[];fail('Автопарк: '+error.message)}
 for(const vehicle of vehicles){const spawn=fleet.findSpawn(vehicle.profile,origin,{topology,meters:M,hero});if(!spawn){fail('Нет безопасной парковки: '+vehicle.profile.label);continue}const record=fleet.addCar(vehicle,spawn);glass.prepare(record.car.object);}
 document.body.dataset.vehicleFleetLoading=`${fleet.records.length-1}/13`;refreshVehicleFleetQa();
}
function refreshVehicleFleetQa(){const select=$('fleet-qa-select');if(!select||!fleet)return;const previous=select.value;select.replaceChildren();for(const record of fleet.records){const option=document.createElement('option');option.value=record.id;option.textContent=record.car.profile.label;select.append(option)}select.value=previous||fleet.activeId;}
function installVehicleFleetQa(){
 const stageDriving=(nearFire=false)=>{
  if(occupiedSeat||transition||jump||heroBlast){carQa.status.textContent='Сначала выйди из машины';return;}
  let area=null;const stageRadius=nearFire?23:35,stageShape={halfWidth:stageRadius,halfLength:stageRadius},stageWorld=fleet.blockingWorld(driveAllowed),origin=fleet.active.spawn;
  outer:for(let radius=0;radius<=900;radius+=18){const samples=radius?Math.max(12,Math.ceil(radius*.3)):1;
   for(let i=0;i<samples;i++){const angle=i/samples*Math.PI*2,x=origin.x+Math.sin(angle)*radius,z=origin.z+Math.cos(angle)*radius;let dry=true,minY=Infinity,maxY=-Infinity;
    for(let sx=-stageRadius;sx<=stageRadius&&dry;sx+=stageRadius/2)for(let sz=-stageRadius;sz<=stageRadius;sz+=stageRadius/2){if(waterAt(x+sx,z+sz)){dry=false;break;}const y=groundHeight(x+sx,z+sz);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
    if(dry&&maxY-minY<.4&&carFits(x,z,0,stageWorld,stageShape)){area={x,z};break outer;}
   }
  }
  if(!area){carQa.status.textContent='Свободная площадка рядом не найдена';return;}
  releaseControls();resetVehicleWater(car,carState);const x=area.x-5,z=area.z-(nearFire?15:28);
  Object.assign(carState,{x,z,yaw:0,speed:0,travelYaw:0,steer:0,yawRate:0,vx:0,vz:0,rearGripBlend:1,frontSlip:0,rearSlip:0,slipAngle:0,lateralVelocity:0,longitudinalVelocity:0});
  car.object.position.set(x,groundHeight(x,z),z);car.object.rotation.set(0,0,0);fleet.syncActive(carState);
  if(nearFire){const other=fleet.records.find(r=>r.id==='fire_engine'&&r!==fleet.active)||fleet.records.find(r=>r.car.profile.family==='fire'&&r!==fleet.active);
   if(other){resetVehicleWater(other.car,other.state);const w=carState.vehicleProfile.collisionHalfWidth??carState.vehicleProfile.halfWidth,ow=other.state.vehicleProfile.collisionHalfWidth??other.state.vehicleProfile.halfWidth;
    Object.assign(other.state,{x:x+w+ow+.12,z:area.z-4,yaw:0,speed:0,travelYaw:0,steer:0,yawRate:0,vx:0,vz:0});other.car.object.position.set(other.state.x,groundHeight(other.state.x,other.state.z),other.state.z);other.car.object.rotation.set(0,0,0);}
  }
  hero.reset();hero.object.position.copy(carExitSpot());hero.object.rotation.y=0;resetFootSupport();controls.target.copy(hero.object.position).y+=1.1;camera.position.copy(carLocal(8,-8,7));setWalking(true);setFreeMouse(false);frameInteraction=undefined;carQa.status.textContent=nearFire?'Проезд рядом с пожарной · зазор 12 см · сядь за руль':'Свободная площадка · сядь за руль';
 };
 for(const [label,nearFire]of [['QA: свободная площадка',false],['QA: проезд рядом с пожарной',true]]){const b=document.createElement('button');b.textContent=label;b.onclick=()=>stageDriving(nearFire);carQa.panel.append(b);}

 const select=document.createElement('select');select.id='fleet-qa-select';select.setAttribute('aria-label','QA: модель автомобиля');carQa.panel.append(select);
 const near=(kind)=>{if(sourceVehicleActive()||occupiedSeat||transition||jump||heroBlast)return;const record=fleet.records.find(r=>r.id===select.value);if(!record)return;activateVehicle(record);let p;
  if(kind==='door')p=carExitSpot();else{
   const controller=kind==='hood'?carHood:carTrunk,access=controller?.profile;if(!controller?.enabled)return;
   const sign=kind==='hood'&&access.front!==false?1:-1,z=kind==='hood'?access.accessZ:access.rearZ,side=kind==='hood'?(access.accessSide||0):0;
   // A parked car can have a wall behind the old single QA target. Choose a
   // reachable point in the real service sector, never put the hero in a wall.
   for(const distance of [.65,.35,.95]){for(const offset of [0,.35,-.35,.65,-.65]){const candidate=carLocal(side+offset,z+sign*distance,0);candidate.y=groundHeight(candidate.x,candidate.z);if(circleFits(candidate.x,candidate.z,pedestrianAllowed)&&controller.interaction(candidate,record.state,{damageState:record.damage.state,blocked:record.roll?.unstable})){p=candidate;break}}if(p)break}
   if(!p){carQa.status.textContent='К этой панели сейчас нет свободного подхода';return}
  }
  if(!p)return;releaseControls();hero.reset();hero.object.position.copy(p);hero.object.rotation.y=carState.yaw+(kind==='hood'?Math.PI:0);resetFootSupport();controls.target.copy(p).y+=1.1;camera.position.copy(carLocal(car.profile.halfWidth+4,kind==='hood'?car.profile.halfLength+4:-car.profile.halfLength-4,car.profile.height+2));setWalking(true);setFreeMouse(false);frameInteraction=undefined;
 };
 for(const [kind,label] of [['door','QA: к выбранной машине'],['trunk','QA: к багажнику'],['hood','QA: к капоту']]){const button=document.createElement('button');button.textContent=label;button.onclick=()=>near(kind);carQa.panel.append(button)}
 for(const [label,action] of [['QA: нажать E',()=>interactWithVehiclePanel()],['QA: ремонт R',()=>interactWithVehiclePanel(true)],['QA: фронтальный удар',()=>receiveVehicleContact({point:carLocal(0,car.profile.halfLength,.9),normal:{x:Math.sin(carState.yaw),y:0,z:Math.cos(carState.yaw)},impactSpeed:18,slideSpeed:0})]]){const button=document.createElement('button');button.textContent=label;button.onclick=action;carQa.panel.append(button)}refreshVehicleFleetQa();
}
function initCar(){
 if(car||!hero)return;const hr=hero.object.position.z/M,hc=hero.object.position.x/M;let best=null;
 for(let r=Math.max(1,Math.floor(hr)-18);r<Math.min(topology.grid.length-1,hr+18);r++)for(let c=Math.max(1,Math.floor(hc)-18);c<Math.min(topology.grid[r].length-1,hc+18);c++){


  if(!topology.roadMask[r][c])continue;for(const yaw of [0,Math.PI/2,Math.PI,-Math.PI/2]){const x=(c+.5)*M,z=(r+.5)*M,d=(r-hr)**2+(c-hc)**2;if(best&&d>=best.d)continue;


   const clearAhead=[0,3,6,10].every(offset=>carFits(x+Math.sin(yaw)*offset,z+Math.cos(yaw)*offset,yaw,driveAllowed));


   if(clearAhead){carState={x,z,yaw,speed:0,steer:0,d};if(carExitSpot())best=carState;}


  }


 }
 if(!best){carState=null;fail('Не найден безопасный участок для машины');return}carState=best;car=createDemoCar(THREE,RoundedBoxGeometry);car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;scene.add(car.object);
 car.profile={...CAR,id:'red_sedan',label:'Kingswell',height:2.22,massKg:1500};car.seats=VEHICLE_SEATS;car.object.userData.mapColor='#'+car.object.getObjectByName('Hood_lid').material.color.getHexString();
 fleet=createVehicleFleet(THREE,{scene,wheelRenderOptimization,detailOptimization:renderer.extensions.has('WEBGL_multi_draw'),RoundedBox:RoundedBoxGeometry,world:()=>driveAllowed,groundHeight,pose:(vehicle,state,angle,dt)=>poseWalkVehicle(vehicle,state,angle,dt),getHero:()=>hero,onExplosion(event){const vehicle=event.vehicle;blastResponse?.enqueue({point:vehicle.object.localToWorld(new THREE.Vector3(0,1,0)),power:1,radius:10,source:vehicle});glass.shatterAll(vehicle.object,{impulse:80,weaponId:'vehicle_explosion'});if(vehicle===car){exitNotice='Машина уничтожена';exitNoticeUntil=performance.now()+2500;if(occupiedSeat&&!transition)beginCarTransition()}}});
 const first=fleet.addCar(car,best);carState=first.state;activateVehicle(first);glass.prepare(car.object);loadVehicleFleet(best);
 const p=carExitSpot();hero.object.position.copy(p);resetFootSupport();controls.target.copy(p).y=hero.object.position.y+1.1;camera.position.copy(carLocal(4,-6,3));
 const button=document.createElement('button');button.id='car';button.textContent='Удерживай E 0,3 с — сесть';button.onpointerdown=e=>{if(e.button!==0)return;e.preventDefault();button.setPointerCapture(e.pointerId);pointerHeld=true};button.onpointerup=button.onpointercancel=()=>{pointerHeld=false};$('controls').append(button);
 if(new URLSearchParams(location.search).get('carqa')==='1'||new URLSearchParams(location.search).get('carphysicsqa')==='1')carQa=initCarPhysicsQa({document,


  onInput(input){for(const [name,key] of Object.entries({forward:'KeyW',reverse:'KeyS',left:'KeyA',right:'KeyD',handbrake:'Space'})){if(input[name])keys.add(key);else keys.delete(key)}},
  onRelease(){keys.clear();pointerHeld=false},onEntryHold(pressed){pointerHeld=pressed},
  onReset(){fleet.active.impactReaction?.reset();vehicleImpactView.reset();vehicleVisualQa?.reset();const best=fleet.active.spawn;releaseControls();glass.reset(car.object);carDamage.reset();carRollover?.reset();carHood?.reset();blastResponse?.reset();heroBlast=null;hero.object.rotation.z=0;tyres.reset();tireTracks.clear();transition=null;jump=null;occupiedSeat=null;entryArmed=true;resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);hero.reset();carState={...carState,...best,speed:0,steer:0,yawRate:0,travelYaw:best.yaw,vx:0,vz:0,lateralVelocity:0,longitudinalVelocity:0,rearGripBlend:1,frontSlip:0,rearSlip:0,slipAngle:0};car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;car.setDoorById(0,'front_left');hero.object.position.copy(carExitSpot());resetFootSupport();hero.object.rotation.y=best.yaw;setWalking(true);controls.target.copy(hero.object.position).y=hero.object.position.y+postureEyeHeight();camera.position.copy(carLocal(4,-6,3));for(const id of ['district','walk','reload'])$(id).disabled=false;fleet.syncActive(carState);setFreeMouse(false)}
 });
 if(carQa){installVehicleFleetQa();vehicleVisualQa=createVehicleVisualQa(THREE,{document,panel:carQa.panel,getRecord:()=>fleet?.active,onContact:receiveVehicleContact,onRelease:releaseControls});}
 if(carQa){for(const speed of [3,16]){const b=document.createElement('button');b.textContent=speed===3?'QA: слабый боковой удар':'QA: сильный боковой удар';b.onclick=()=>{const point=carLocal(car.profile.halfWidth,0,Math.min(1,car.profile.height*.5)),normal={x:Math.cos(carState.yaw),y:0,z:-Math.sin(carState.yaw)};receiveVehicleContact({point,normal,impactSpeed:speed,slideSpeed:0})};carQa.panel.append(b)}}
 if(carQa)for(const seat of VEHICLE_SEATS){const button=document.createElement('button');button.textContent=`QA: к двери — ${seat.label}`;button.setAttribute('aria-label',button.textContent);button.onclick=()=>{if(occupiedSeat||transition||jump||heroBlast||!car.seats.some(s=>s.id===seat.id))return;const point=carExitSpot(seat.id);if(!point)return;releaseControls();hero.object.position.copy(point);resetFootSupport();controls.target.copy(point).y=hero.object.position.y+1.1;camera.position.copy(carLocal(seat.side*4,-5,3));setFreeMouse(false)};carQa.panel.append(button)}
 if(exitQaMode){
  // Explicit UI fixture for slow-motion visual QA; absent from the normal demo URL.
  const panel=document.createElement('div'),label=document.createElement('span');label.id='exit-qa-status';label.textContent='Проверка выхода · замедлено 4×';panel.append(label);


  const pauseLabel=document.createElement('label'),pause=document.createElement('input');pause.type='checkbox';pause.id='exit-qa-freeze';pause.onchange=()=>{if(!pause.checked)exitQaPaused=false};pauseLabel.append(pause,'Пауза на кувырке');panel.append(pauseLabel);
  for(const speed of [8,60]){const test=document.createElement('button');test.textContent=`Тест выхода ${speed} км/ч`;test.onclick=()=>{
   const best=fleet.active.spawn;glass.reset(car.object);carDamage.reset();carRollover?.reset();carHood?.reset();blastResponse?.reset();heroBlast=null;hero.object.rotation.z=0;tyres.reset();tireTracks.clear();transition=null;exitQaPaused=false;hero.reset();keys.clear();carState={...carState,...best,speed:speed/3.6,steer:0,yawRate:0,travelYaw:best.yaw};car.object.position.set(best.x,0,best.z);car.object.rotation.y=best.yaw;car.setDoorById(0,'front_left');occupiedSeat='front_left';
   hero.object.position.copy(carLocal(DRIVER_SEAT.side,DRIVER_SEAT.front,DRIVER_SEAT.y));hero.object.rotation.y=best.yaw;hero.vehiclePose(1,0);controls.target.copy(hero.object.position).y=1;camera.position.copy(carLocal(6,-8,4));setFreeMouse(false);label.textContent='Дверь открывается';beginCarTransition();
  };panel.append(test)}panel.style.cssText='position:fixed;left:330px;bottom:145px;z-index:45;display:flex;flex-wrap:wrap;gap:8px;padding:10px;max-width:620px;color:#fff;background:#172b2eee';document.body.append(panel);
 }


}


const errors=[];function fail(message){errors.push(message);$('errors').textContent=errors.slice(-3).join(' · ')}


function safeUrl(url){const u=new URL(url,location.origin);if(u.origin!==location.origin||!/^\/assets\/(maps\/city_rebuild_v1|buildings\/city_v3|decor\/civic_park_v2)\//.test(u.pathname))throw Error('Недопустимый URL модели');return u.href}


async function getJsonBytes(name,optional=false){const res=await fetch(root+name,{cache:'no-store'});if(optional&&res.status===404)return null;if(!res.ok)throw Error(name+': HTTP '+res.status);return res.arrayBuffer()}
async function jsonRevision(bytes){if(bytes===null)return 'missing';const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));return Array.from(digest,n=>n.toString(16).padStart(2,'0')).join('')}
async function template(binding){


 const key=binding.sha256;if(!key||!binding.url)throw Error('Нет хеша/URL модели');


 if(!templates.has(key))templates.set(key,(async()=>{const response=await fetch(safeUrl(binding.url));if(!response.ok)throw Error('GLB HTTP '+response.status);const bytes=await response.arrayBuffer();if(bytes.byteLength!==binding.bytes)throw Error('Размер GLB не совпал');const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),n=>n.toString(16).padStart(2,'0')).join('');if(digest!==key.toLowerCase())throw Error('Хеш GLB не совпал');const gltf=await loader.parseAsync(bytes,new URL('.',safeUrl(binding.url)).href);


 gltf.scene.traverse(node=>{if(/(^|[_\s])(collision|collider|clearance|socket|anchor|keepout|nav|proxy|datum)([_\s]|$)/i.test(node.name)||/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))node.visible=false;


 if(node.isMesh){node.castShadow=true;node.receiveShadow=true;const mats=Array.isArray(node.material)?node.material:[node.material];for(const material of mats){if(material.transparent){material.depthWrite=false;material.side=THREE.FrontSide;material.forceSinglePass=true;material.envMapIntensity=.35}}}});


 return gltf.scene;})());return templates.get(key);
}
function clearContent({recreate=true}={}){mercenaryShowcaseUI?.dispose();mercenaryShowcaseUI=null;mercenaryShowcase?.dispose();mercenaryShowcase=null;for(const handle of buildingCameraIndexes)handle.dispose();buildingCameraIndexes=[];buildingCameraIndexBuildMs=0;buildingCameraIndexGeneration++;document.getElementById('building-camera-index-qa')?.remove();for(const handle of nativeTerrainRaycastIndexes)handle.dispose();nativeTerrainRaycastIndexes=[];nativeTerrainPickingBuildMs=0;nativeTerrainPickingGeneration++;cityRoadNavigation?.invalidate();laneRouteJobs?.dispose();laneRouteJobs=null;cityRoadNavigation=null;cityRoadStaticWorld=null;mapRoadRouteOrigin=null;mapRoadRouteTarget=null;explorationMap?.setRoute(null);mercenaryFences?.dispose();mercenaryFences=null;mercenaryPowerPanel?.dispose();mercenaryPowerPanel=null;waterVapor?.dispose();waterVapor=null;waterEffects?.dispose();waterEffects=null;waterInputs.reset();waterImpactCapture.reset();waterInspectionDriveUntil=0;environmentVisuals?.dispose();environmentVisuals=null;verticalNavigation.reset();restoreBuildingCamera();explorationRailway?.dispose();explorationRailway=null;explorationRailPlan=null;explorationDecor?.dispose();explorationDecor=null;landscape?.dispose();landscape=null;shotRaycastIndex?.dispose();shotRaycastIndex=null;staticRenderBatches?.dispose();staticRenderBatches=null;stableEntryLights?.dispose();stableEntryLights=null;glass.dispose();while(content.children.length){const node=content.children.pop();node.parent=null;node.userData.roomReveals?.dispose();node.userData.streetLighting?.dispose();node.userData.buildingEntry?.dispose();node.userData.residentialWindows?.dispose();node.userData.doorsGlass?.dispose();if(node.userData.owned)node.traverse(x=>{x.geometry?.dispose();if(x.material){for(const m of Array.isArray(x.material)?x.material:[x.material])if(!m.userData?.environmentSurface)m.dispose()}})}streetLighting.dispose();instances=[];bodies=[];carBodies=[];buildingEntries=[];entryBodyVersions.clear();walkCollisionIndex?.clear();walkCollisionIndex=null;buildingSampleIndex=null;buildingQaMove=null;document.body.dataset.windowCacheAfterClear=JSON.stringify(residentialWindowCacheStats());if(recreate){glass=createGlassBreakage(THREE,scene,{groundHeight});streetLighting=createStreetLighting({THREE,scene,maxLights:8,maxFixtures:192,groundHeight,staticPlacement:true});for(const record of fleet?.records||[])glass.prepare(record.car.object)}}
function configureExplorationMap(all,decorPlan){
 if(!explorationMap)explorationMap=createExplorationMinimap({onExpandedChange(expanded){releaseControls();setFreeMouse(false);controls.enabled=!expanded;},onWaypointChange(point){mapRoadRouteAt=-Infinity;mapRoadRouteTarget=null;showExplorationWaypoint(point)}});
 const native=normalizeNativeInstances(all,M),features=landscape.mapFeatures.map(p=>({...p,kind:p.type==='lake'?'water':p.type})),newObjects=decorPlan.mapFeatures.map(p=>({...p,poi:decorPlan.vignettes.some(v=>v.id===p.id),kind:['pine','oak','birch','cypress'].includes(p.kind)?'tree':p.kind==='armillary'?'monument':['clock','kiosk','telescope'].includes(p.kind)?'landmark':mapKind(p.kind)==='object'?p.kind:mapKind(p.kind)}));
 explorationMap.setWorld({bounds:landscape.bounds,grid:topology.grid,cellSize:M,districts:topology.districts.map(d=>({id:d.id,name:d.display_name?.split(' · ')[0]||d.id,polygon:d.polygon_grid.map(([x,z])=>({x:x*M,z:z*M})),x:d.center_grid?.[0]*M,z:d.center_grid?.[1]*M})),buildings:native.filter(p=>p.building),objects:[...native.filter(p=>!p.building),...newObjects,...(environmentVisuals?.mapFeatures||[]),...(explorationRailPlan?.stations||[]).map(s=>({...s,kind:'station',poi:true,radius:3})),...features.filter(p=>['landmark','water','mountain','forest'].includes(p.kind)).map(p=>({...p,polygon:undefined,points:undefined,radius:2,poi:true})),{id:'preserved-police',name:'Полицейский комплекс',kind:'police',x:76*M,z:76*M},{id:'preserved-red-bridge',name:'Красный мост',kind:'landmark',x:90*M,z:52*M}],regions:features.filter(p=>['forest','mountain'].includes(p.kind)),water:features.filter(p=>p.kind==='water'),roads:landscape.paths.filter(p=>p.drive),trails:landscape.paths.filter(p=>!p.drive),railways:explorationRailPlan?.mapFeatures.filter(p=>p.type==='rail')||[]});
 explorationPlaces=[...(environmentVisuals?.parkingPlan?.lots||[]).map((lot,i)=>({id:lot.id,name:lot.name+' · '+(i+1),...lot.tour,lookAt:{x:(lot.rect.minX+lot.rect.maxX)/2,z:(lot.rect.minZ+lot.rect.maxZ)/2}})),...landscape.landmarks,{id:WATER_VEHICLE_ACCESS.id,name:'Пологий берег Лазурного озера',x:WATER_VEHICLE_ACCESS.start.x+WATER_VEHICLE_ACCESS.direction.x*20,z:WATER_VEHICLE_ACCESS.start.z+WATER_VEHICLE_ACCESS.direction.z*20,lookAt:WATER_VEHICLE_ACCESS.shore},...(explorationRailPlan?.stations||[]).map(s=>({id:s.id,name:s.name,x:s.x+s.nx*(s.width/2+4),z:s.z+s.nz*(s.width/2+4),lookAt:{x:s.rail.x,z:s.rail.z}})),...decorPlan.vignettes.filter(p=>p.zone==='city').map((p,i)=>({...p,name:p.name+' · '+(i+1)}))];let select=$('exploration-place');if(!select){select=document.createElement('select');select.id='exploration-place';select.setAttribute('aria-label','Место для прогулки');$('controls').append(select)}select.replaceChildren(new Option('Окрестности…',''));for(const p of explorationPlaces)select.add(new Option(p.name,p.id));select.onchange=()=>{const p=explorationPlaces.find(p=>p.id===select.value);if(p)visitExplorationPlace(p);select.value=''};
 document.body.dataset.exploration=JSON.stringify({bounds:landscape.bounds,terrain:landscape.report,railway:explorationRailway?.report,decor:explorationDecor.stats,places:explorationPlaces});
}
function visitExplorationPlace(place){
 if(!hero||occupiedSeat||transition||jump||heroBlast||verticalNavigation.active||busy)return;let point=null;for(const radius of [0,2,4,7,10])for(let i=0;i<12&&!point;i++){const x=place.x+Math.cos(i*Math.PI/6)*radius,z=place.z+Math.sin(i*Math.PI/6)*radius;if(circleFits(x,z,pedestrianAllowed)&&!waterAt(x,z))point={x,z}}if(!point)return;
 releaseControls();restoreBuildingCamera();savedCameraOffset=null;aimBlend=0;resetHeroPosture(heroPosture);hero.reset();hero.object.position.set(point.x,groundHeight(point.x,point.z),point.z);surfaceMotion.reset(hero.object.position);hero.object.rotation.y=Math.atan2(-4,-7);setWalking(true);$('scene-menu').hidden=true;setArsenalOpen(false);controls.target.copy(hero.object.position).add(new THREE.Vector3(0,1.35,0));camera.position.copy(controls.target).add(new THREE.Vector3(4,3.2,7));if(place.lookAt){const dx=point.x-place.lookAt.x,dz=point.z-place.lookAt.z,d=Math.hypot(dx,dz)||1;camera.position.copy(controls.target).add(new THREE.Vector3(dx/d*7,3.2,dz/d*7));hero.object.rotation.y=Math.atan2(-dx,-dz)}camera.lookAt(controls.target);setFreeMouse(false);explorationMap?.setWaypoint(place);
}
function showExplorationWaypoint(point){
 if(!waypointVisual){if(!point)return;waypointDistance=document.createElement('div');waypointDistance.id='waypoint-distance';waypointDistance.style.cssText='position:fixed;left:0;top:0;color:#ffe0a3;background:#142b32c9;border:1px solid #e3bd6b88;border-radius:5px;padding:2px 6px;font:700 12px system-ui;pointer-events:none;z-index:3';document.body.append(waypointDistance);waypointVisual=createExplorationWaypointVisual(THREE);scene.add(waypointVisual)}waypointVisual.visible=!!point;waypointDistance.hidden=!point;if(point)waypointVisual.position.set(point.x,groundHeight(point.x,point.z),point.z);
}
let npcMapCache=[],npcMapCacheAt=-Infinity;
function explorationNpcMarkers(){const now=performance.now();if(now-npcMapCacheAt>250){npcMapCacheAt=now;npcMapCache=explorationNpcMapMarkers(window.MafioziWalkNpcs?.getActors?.()||[],window.MafioziMercenaries)}return npcMapCache}
function explorationVehicleMarker(vehicle,state,id){const paint=vehicle?.object?.getObjectByName('Hood_lid')?.material?.color;return {...state,id,color:vehicle?.object?.userData.mapColor??(paint?'#'+paint.getHexString():undefined)}}
// The minimap itself cannot present a new frame more often than every 80 ms.
// Reusing these snapshots between its paint ticks avoids allocations and deep
// vehicle/material walks on every render frame without making its display older.
let minimapVehicleCache=[],minimapTrainCache=[],minimapMarkerCacheAt=-Infinity;
function explorationMinimapVehicles(){const now=performance.now();if(now-minimapMarkerCacheAt>=80){minimapMarkerCacheAt=now;minimapVehicleCache=fleet?.records.map(record=>explorationVehicleMarker(record.car,record.state,record.id))||[];minimapTrainCache=explorationRailway?.actors()||[]}return minimapVehicleCache}
function explorationMinimapTrains(){explorationMinimapVehicles();return minimapTrainCache}
function updateExplorationRailway(dt){if(!explorationRailway)return;const snapshot=explorationRailway.update(dt,{isOccupied(x,z,r){if(hero&&!occupiedSeat&&Math.hypot(hero.object.position.x-x,hero.object.position.z-z)<r+.4)return true;return !!fleet?.overlaps(x,z,r)}});const now=performance.now();if(now-railwayDiagnosticsAt>=100){railwayDiagnosticsAt=now;document.body.dataset.explorationRailway=JSON.stringify({...explorationRailway.report,speed:snapshot.speed,dwellRemaining:snapshot.dwellRemaining,stoppedForObstacle:snapshot.stoppedForObstacle,position:snapshot.cars[0],nextStation:snapshot.nextStation});}}
function updateMapRoadRoute(){
 const target=explorationMap?.waypoint;
 if(!target||!occupiedSeat||transition||!carState){if(mapRoadRouteTarget){explorationMap?.setRoute(null);mapRoadRouteTarget=null;mapRoadRouteOrigin=null;}return;}
 const now=performance.now(),key=[target.id||'',target.x,target.z].join(':');
 if(key===mapRoadRouteTarget&&mapRoadRouteOrigin&&now-mapRoadRouteAt<1500)return;
 if(key===mapRoadRouteTarget&&mapRoadRouteOrigin&&Math.hypot(carState.x-mapRoadRouteOrigin.x,carState.z-mapRoadRouteOrigin.z)<5&&Math.abs(Math.atan2(Math.sin(carState.yaw-mapRoadRouteOrigin.yaw),Math.cos(carState.yaw-mapRoadRouteOrigin.yaw)))<.4)return;
 mapRoadRouteAt=now;mapRoadRouteTarget=key;mapRoadRouteOrigin={x:carState.x,z:carState.z,yaw:carState.yaw};
 const route=cityRoadNavigation?.route({from:mapRoadRouteOrigin,to:target})||{status:'pending',points:[]};explorationMap?.setRoute(route);
 document.body.dataset.cityRoadRoute=JSON.stringify({status:route.status,reason:route.reason,distance:route.distanceM,points:route.points?.length||0,controls:route.controls?.length||0,destination:route.destination,accessRouteIds:route.accessRouteIds});
}
function updateWaypointDistance(){
 updateMapRoadRoute();
 if(!waypointDistance)return;const target=explorationMap?.waypoint;
 if(!target||!hero){waypointDistance.hidden=true;return}
 if(walking&&!occupiedSeat&&!transition&&!jump&&reachedExplorationWaypoint(hero.object.position,waypointVisual.position)){explorationMap.setWaypoint(null);return}
 waypointVisual.userData.update?.(performance.now()*.001,camera);
 if(explorationMap.expanded){waypointDistance.hidden=true;return}
 const screen=waypointVisual.userData.screenPosition||=new THREE.Vector3();screen.copy(waypointVisual.position);screen.y+=2.15;screen.project(camera);waypointDistance.hidden=screen.z<-1||screen.z>1||Math.abs(screen.x)>1||Math.abs(screen.y)>1;if(!waypointDistance.hidden){waypointDistance.textContent=Math.round(Math.hypot(target.x-hero.object.position.x,target.z-hero.object.position.z))+' м';waypointDistance.style.transform='translate('+Math.round((screen.x+1)*innerWidth/2)+'px,'+Math.round((1-screen.y)*innerHeight/2)+'px) translate(-50%,-100%)'}
}
function clampLandscapeView(){if(!hero||!landscape||explorationMap?.expanded)return;const from={x:hero.object.position.x,y:hero.object.position.y+1.3,z:hero.object.position.z},next=resolveLandscapeCamera(from,camera.position,explorationSurface);if(Math.hypot(next.x-camera.position.x,next.y-camera.position.y,next.z-camera.position.z)>.001){const shift=new THREE.Vector3(next.x,next.y,next.z).sub(camera.position);camera.position.set(next.x,next.y,next.z);if(aiming)controls.target.add(shift);else camera.lookAt(controls.target);camera.updateMatrixWorld()}}
function terrain(grid,protectedMask,asphalt){


 const palettes={0:'#525a5a',8:'#789274',9:'#c4c1ab',14:'#d9c698',16:'#4f9eb0',19:'#858e89'},vertices=new Map();


 for(let r=0;r<grid.length;r++)for(let c=0;c<grid[r].length;c++){const t=grid[r][c],key=protectedMask?.[r]?.[c]?'protected':t;const arr=vertices.get(key)||[];vertices.set(key,arr);const x=c*M,z=r*M,y=t===16?-.18:0;arr.push(x,y,z,x+M,y,z+M,x+M,y,z,x,y,z,x,y,z+M,x+M,y,z+M)}


 for(const [key,data] of vertices){const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(data,3));geo.computeVertexNormals();const water=key===16;const mat=new THREE.MeshStandardMaterial({color:key==='protected'?'#9a9990':palettes[key]||'#788275',roughness:water?.22:.88,metalness:water?.14:0});if(key===0&&asphalt?.baseColorFactor){mat.color.fromArray(asphalt.baseColorFactor);mat.roughness=asphalt.roughnessFactor??.8;mat.metalness=asphalt.metallicFactor??0}const mesh=new THREE.Mesh(geo,mat);mesh.receiveShadow=!water;mesh.userData.owned=true;mesh.userData.nativeTerrainKind=key===16?'water':key===8?'grass':key===14?'sand':key===0||key===19?'asphalt':'paving';content.add(mesh)}


}


function inPolygon(r,c,polygon){if(!polygon?.length)return false;let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if(((a[1]>r)!==(b[1]>r))&&(c<(b[0]-a[0])*(r-a[1])/(b[1]-a[1])+a[0]))inside=!inside}return inside}


function canWalk(x,z){if(explorationRailway?.blocks(x,z,.36))return false;const r=z/M,c=x/M,rr=Math.floor(r),cc=Math.floor(c);if(landscape?.contains(x,z)){if(!landscape.canWalk(x,z))return false}else if(!nativePedestrianLand(topology,rr,cc)&&!waterAt(x,z))return false;const floor=Math.max(heroGroundHeight(x,z),hero?.object.position.y??0),bodyHeight=postureMotion?.height||1.9;if(heroCeilingHeight(x,z)<floor+bodyHeight-.03)return false;for(const body of walkCollisionIndex?.(c,r)||[]){if(body.maxYM!==undefined&&body.maxYM<floor+.05)continue;if(body.minYM!==undefined&&body.minYM>floor+bodyHeight)continue;if(inPolygon(r,c,body.polygonCR))return false}return true}


function focus(instance){restoreBuildingCamera();const t=instance?.transform?.positionM||[60*M,0,30*M];const pos=new THREE.Vector3(t[0],0,t[2]);let landing=pos.clone().add(new THREE.Vector3(0,0,20));for(let radius=15;radius<60&&!circleFits(landing.x,landing.z,canWalk);radius+=5){for(let a=0;a<Math.PI*2;a+=Math.PI/6){const test=pos.clone().add(new THREE.Vector3(Math.sin(a)*radius,0,Math.cos(a)*radius));if(circleFits(test.x,test.z,canWalk)){landing=test;break}}}if(!circleFits(landing.x,landing.z,canWalk)){fail('Для этой точки не найден безопасный подход');return}landing.y=heroGroundHeight(landing.x,landing.z);controls.target.copy(landing);if(hero){resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);hero.object.position.copy(landing);surfaceMotion.reset(landing);hero.reset();controls.target.y=landing.y+postureEyeHeight();camera.position.copy(landing).add(new THREE.Vector3(8,11,14))}else camera.position.copy(landing).add(new THREE.Vector3(35,50,65));controls.update()}


function records(data){return data?.instances||[]}


async function refresh(){if(renderFreezeQa?.active||busy||jump||insideBuilding()||buildingQaMove)return;const startedAt=performance.now();busy=true;$('status').textContent='Читаю свежую расстановку…';
 try{const [topBytes,bldBytes,decBytes,detBytes]=await Promise.all([getJsonBytes('topology_for_placement.json'),getJsonBytes('buildings_placement.v1.json',true),getJsonBytes('decor_placement.v1.json',true),getJsonBytes('detention_native_sites.v1.json',true)]),nextRevision=await Promise.all([jsonRevision(topBytes),jsonRevision(bldBytes),jsonRevision(decBytes),jsonRevision(detBytes)]);if(revision&&revision[0]===nextRevision[0]&&revision[1]===nextRevision[1]&&revision[2]===nextRevision[2]&&revision[3]===nextRevision[3]){$('status').textContent=`В сцене ${loaded} 3D-объектов. Расстановка не изменилась.`;return}const decoder=new TextDecoder(),top=JSON.parse(decoder.decode(topBytes)),bld=bldBytes===null?null:JSON.parse(decoder.decode(bldBytes)),dec=decBytes===null?null:JSON.parse(decoder.decode(decBytes)),det=detBytes===null?null:JSON.parse(decoder.decode(detBytes));if(!Array.isArray(top.grid)||top.grid.length!==200)throw Error('Нет полной сетки: сцена не заменена');
 // Stage models before touching the last visible generation. Failed GLBs never become boxes.
 const buildings=[...records(bld),...records(det)],decorItems=records(dec),buildingItems=new Set(buildings),all=[...buildings,...decorItems],unique=new Map(),templateMasks=new Map();for(const item of all)if(item.binding){unique.set(item.binding.sha256,item.binding);const signature=maskSignature(item.hideNodeNames),existing=templateMasks.get(item.binding.sha256);if(!existing)templateMasks.set(item.binding.sha256,{names:item.hideNodeNames||[],signature,uniform:true});else if(existing.signature!==signature)existing.uniform=false}const decorKeepouts=explorationKeepouts(all,M),decorPlanPromise=planExplorationDecorAsync({topology:top,instances:all,keepouts:decorKeepouts,metresPerCell:M}).catch(error=>({error})),decorPlanStarted=performance.now();loaded=0;failed=0;
 const queue=[...unique.values()];await Promise.all(Array.from({length:Math.min(3,queue.length)},async()=>{while(queue.length){const binding=queue.shift();try{await template(binding)}catch(e){failed++;templates.delete(binding.sha256);fail(e.message)}$('status').textContent=`Загрузка моделей: ${templates.size}/${unique.size} типов…`}}));for(const [sha256,mask] of templateMasks){const source=await templates.get(sha256);if(source)applyTemplateVisibilityMask(source,mask.uniform?mask.names:[])}const templatesReadyAt=performance.now();
 npcVehicleNavigation?.invalidate();npcServiceDestinations?.invalidate();clearContent();topology=top;terrain(top.grid,top.protectedMask,dec?.surfaces?.[0]?.materialDescriptor);landscape=createLandscapeTerrain({THREE});content.add(landscape.object);const assemblyTiming={clone:0,doorsGlass:0,entryWindows:0,streetLights:0,glass:0,railwayWait:0,railwayElapsed:0,decorPlanWait:0,decorPlanElapsed:0,decorPlanWorker:0,decorPlanMode:'worker',staticRenderBatches:0};
 // The train only needs the terrain and its deterministic plan.  Start its
 // authored GLB request before the independent building assembly below, but
 // retain the await barrier before any railway collision, map or vehicle hook.
 explorationRailPlan=createExplorationRailwayPlan({landscape,topology});const railwayStartedAt=performance.now(),railwayLoad=createExplorationRailway({THREE,loader,landscape,plan:explorationRailPlan}).then(railway=>({railway}),error=>({error}));
 for(const item of all){if(!item.binding||!templates.has(item.binding.sha256))continue;let phaseStarted=performance.now();const source=await templates.get(item.binding.sha256);const group=new THREE.Group(),visual=source.clone(true),t=item.transform||{},offset=t.modelLocalOffsetM||[0,0,0],templateMask=templateMasks.get(item.binding.sha256);if(!templateMask?.uniform)applyCloneVisibilityMask(visual,item.hideNodeNames);visual.position.fromArray(offset);assemblyTiming.clone+=performance.now()-phaseStarted;phaseStarted=performance.now();group.userData.doorsGlass=applyBuildingDoorsGlass(visual,item);assemblyTiming.doorsGlass+=performance.now()-phaseStarted;group.add(visual);group.position.fromArray(t.positionM||[item.c*M,0,item.r*M]);group.rotation.y=THREE.MathUtils.degToRad(t.yawDegrees||0);group.scale.setScalar(t.uniformScale??1);group.userData.instance=item;content.add(group);group.updateMatrixWorld(true);phaseStarted=performance.now();const {entry,windows,roomReveals}=buildingItems.has(item)?createWindowedBuildingEntry({THREE,visual,instance:item,metresPerCell:M}):{entry:null,windows:null,roomReveals:null};assemblyTiming.entryWindows+=performance.now()-phaseStarted;group.userData.buildingEntry=entry;group.userData.residentialWindows=windows;group.userData.roomReveals=roomReveals;if(entry)buildingEntries.push(entry);else bodies.push(...(item.collision?.worldBodies||[]));phaseStarted=performance.now();group.userData.streetLighting=streetLighting.prepare(visual,item);assemblyTiming.streetLights+=performance.now()-phaseStarted;phaseStarted=performance.now();glass.prepare(visual);assemblyTiming.glass+=performance.now()-phaseStarted;carBodies.push(...(item.collision?.worldBodies||[]));instances.push(group);loaded++}
 $('status').textContent='Прокладываю железную дорогу…';const railwayWaitStarted=performance.now(),railwayResult=await railwayLoad;assemblyTiming.railwayWait=performance.now()-railwayWaitStarted;assemblyTiming.railwayElapsed=performance.now()-railwayStartedAt;if(railwayResult.error)throw railwayResult.error;explorationRailway=railwayResult.railway;content.add(explorationRailway.object);
 const decorWaitStarted=performance.now();let decorPlanResult=await decorPlanPromise;if(decorPlanResult.error){console.warn('Forest planning worker unavailable; using verified main-thread fallback',decorPlanResult.error);decorPlanResult={plan:buildExplorationDecorPlan({topology,instances:all,metresPerCell:M,keepouts:decorKeepouts}),workerMs:null,mode:'main-fallback'}}assemblyTiming.decorPlanWait=performance.now()-decorWaitStarted;assemblyTiming.decorPlanElapsed=performance.now()-decorPlanStarted;assemblyTiming.decorPlanWorker=decorPlanResult.workerMs??0;assemblyTiming.decorPlanMode=decorPlanResult.mode;const explorationPlan=decorPlanResult.plan,environmentPlanStarted=performance.now(),environmentPlanPromise=planEnvironmentVisualsAsync({topology,instances:all,keepouts:decorKeepouts,decorPlan:explorationPlan}).catch(error=>({error}));explorationDecor=createExplorationDecor({THREE,RoundedBoxGeometry,plan:explorationPlan});npcBridge?.setWalkCivilianPlaces?.({benches:explorationPlan.objects.filter(p=>p.kind==='bench').map(p=>({id:p.id,r:p.z/M,c:p.x/M,yaw:p.yaw||0,seatWorldY:p.y+.61*(p.scale||1)}))});content.add(explorationDecor.object);bodies.push(...explorationDecor.colliders);carBodies.push(...explorationDecor.colliders);const environmentPlans=await environmentPlanPromise;if(environmentPlans.error)console.warn('Environment planning worker unavailable; using main-thread fallback',environmentPlans.error);assemblyTiming.environmentPlanElapsed=performance.now()-environmentPlanStarted;assemblyTiming.environmentPlanWorker=environmentPlans.workerMs??0;assemblyTiming.environmentPlanMode=environmentPlans.error?'main-fallback':environmentPlans.mode;environmentVisuals=createEnvironmentVisuals({preparedPlans:environmentPlans.error?undefined:environmentPlans,THREE,topology,landscape,railPlan:explorationRailPlan,instances:all,decorPlan:explorationPlan,keepouts:decorKeepouts,nativeMeshes:content.children.filter(m=>m.userData.nativeTerrainKind),depthAt:(x,z)=>waterAt(x,z)?.depth??0});content.add(environmentVisuals.object);bodies.push(...environmentVisuals.colliders);carBodies.push(...environmentVisuals.colliders);configureExplorationMap(all,explorationPlan);
 waterEffects=createWaterInteractionEffects({THREE,waterAt,groundHeight});content.add(waterEffects.object);waterVapor=createVehicleWaterVapor({THREE});content.add(waterVapor.object);
  buildingSampleIndex=createWalkCollisionIndex([buildingEntries.map(entry=>{const b=entry.sampleBounds;return {entry,polygonCR:[[b.min.x/M,b.min.z/M],[b.max.x/M,b.min.z/M],[b.max.x/M,b.max.z/M],[b.min.x/M,b.max.z/M]]}})]);stableEntryLights=createStableEntryLights(THREE,buildingEntries,scene,{maxLights:32,getFocus:()=>hero?.object.position||controls.target});
 const staticRenderBatchStarted=performance.now();
 if(staticRenderBatching)try{staticRenderBatches=createStaticRenderBatches({THREE,root:content,instances,minInstances:3,maxDistance:220,localMatrixOptimization:staticMatrixOptimization});document.body.dataset.staticRenderBatches=JSON.stringify(staticRenderBatches.stats())}catch(error){console.warn('Static render batching disabled',error);staticRenderBatches=null;document.body.dataset.staticRenderBatches=JSON.stringify({disabled:true,error:error.message})}
 else document.body.dataset.staticRenderBatches=JSON.stringify({disabled:true,reason:'query'});
 assemblyTiming.staticRenderBatches=performance.now()-staticRenderBatchStarted;
 if(window.MafioziMercenaries?.canUseLocalEffects?.()){
  mercenaryFences?.dispose();const key='mafiozi.mercenary-fences.v1';let cutIds=[];try{cutIds=JSON.parse(localStorage.getItem(key)||'[]');if(!Array.isArray(cutIds))cutIds=[];}catch{}
  mercenaryFences=createMercenaryFences({THREE,groundHeight,cutIds,persistCut:id=>{if(!cutIds.includes(id))cutIds.push(id);localStorage.setItem(key,JSON.stringify(cutIds));},onCollisionChange:({removed,added})=>{if(!window.MafioziMercenaries?.canUseLocalEffects?.())return false;for(const list of [bodies,carBodies]){for(let i=list.length-1;i>=0;i--)if(removed.includes(list[i]))list.splice(i,1);list.push(...added);}walkCollisionIndex?.replaceGroup('world-static',bodies,{order:0,force:true});if(laneRouteJobs){cityRoadStaticWorld=createCarWorld(topology,carBodies,M);laneRouteJobs.updateWorld(carBodies);}driveAllowed=withRailwayVehicleWorld(createExplorationVehicleWorld({topology,bodies:carBodies,terrain:explorationSurface,metresPerCell:M}),()=>explorationRailway);return true;}});
  content.add(mercenaryFences.object);bodies.push(...mercenaryFences.colliders);carBodies.push(...mercenaryFences.colliders);
  mercenaryPowerPanel?.dispose();const powerKey='mafiozi.mercenary-yard-power.v1';let powered=true;try{powered=localStorage.getItem(powerKey)!=='off';}catch{}
  mercenaryPowerPanel=createMercenaryPowerPanel({THREE,groundHeight,powered,onPowerChange:()=>window.MafioziMercenaries?.canUseLocalEffects?.()===true,persistPower:()=>localStorage.setItem(powerKey,'off')});
  mercenaryPowerPanel.updateVisibility?.(hero?.object.position||controls.target);content.add(mercenaryPowerPanel.object);bodies.push(...mercenaryPowerPanel.colliders);carBodies.push(...mercenaryPowerPanel.colliders);
 }
 if(performanceProbe){
  document.getElementById('static-batch-qa')?.remove();
  const button=document.createElement('button');button.id='static-batch-qa';
  button.style.cssText='position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px';
  let enabled=true;button.textContent='Дома: оптимизация включена';
  button.onclick=()=>{if(!staticRenderBatches?.setOptimizationEnabled)return;enabled=!enabled;staticRenderBatches.setOptimizationEnabled(enabled);document.body.dataset.staticBatchComparison=enabled?'optimized':'previous';performanceProbe.reset();button.textContent=enabled?'Дома: оптимизация включена':'Дома: предыдущая отрисовка';};
  document.body.append(button);document.body.dataset.staticBatchComparison='optimized';
 }

 // Index final immutable building geometry after every factory/material edit.
 // Doors keep their transforms; mutated geometry falls back to native ray tests.
 {const started=performance.now(),seen=new Set();for(const entry of buildingEntries)entry.visual.traverse(mesh=>{if(seen.has(mesh))return;seen.add(mesh);const handle=installBuildingCameraTriangleIndex({THREE,mesh});if(handle){handle.setEnabled(buildingCameraIndexEnabled);buildingCameraIndexes.push(handle);}});buildingCameraIndexBuildMs=performance.now()-started;buildingCameraIndexGeneration++;document.body.dataset.buildingCameraIndex=JSON.stringify(window.MafioziBuildingCameraIndex.stats());}
 if(performanceProbe){document.getElementById('building-camera-index-qa')?.remove();const button=document.createElement('button');button.id='building-camera-index-qa';button.style.cssText='position:fixed;top:42px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px';const label=()=>button.textContent=buildingCameraIndexEnabled?'Камера: индекс включён':'Камера: индекс выключен';label();button.onclick=()=>{window.MafioziBuildingCameraIndex.setEnabled(!buildingCameraIndexEnabled);label();};document.body.append(button);}
 // Build immutable native triangle indices after environment material preparation,
 // before interactive picking and shot-root indexing; never on first hover.
 if(nativeTerrainPickingRequested){const started=performance.now();nativeTerrainRaycastIndexes=content.children.filter(mesh=>mesh.userData.nativeTerrainKind).map(mesh=>installNativeTerrainRaycastIndex({THREE,mesh})).filter(Boolean);for(const handle of nativeTerrainRaycastIndexes)handle.setEnabled(nativeTerrainPickingEnabled);nativeTerrainPickingBuildMs=performance.now()-started;nativeTerrainPickingGeneration++;document.body.dataset.nativeTerrainPicking=JSON.stringify(window.MafioziNativeTerrainPicking.stats());}
 shotRaycastIndex=createRaycastRootIndex({THREE,roots:staticShotRoots(),padding:4});document.body.dataset.shotRaycastIndex=JSON.stringify(shotRaycastIndex.stats());
 updateBuildingEntries(0);driveAllowed=withRailwayVehicleWorld(createExplorationVehicleWorld({topology,bodies:carBodies,terrain:explorationSurface,metresPerCell:M}),()=>explorationRailway);
 cityRoadStaticWorld=createCarWorld(topology,carBodies,M);laneRouteJobs=createLaneRouteJobs();cityRoadNavigation=createCityRoadNavigation({routeJobs:laneRouteJobs,getRoadPlan:()=>environmentVisuals?.roadPlan,getParkingPlan:()=>environmentVisuals?.parkingPlan,getInstances:()=>instances,isRoad:(x,z)=>!!topology.roadMask?.[Math.floor(z/M)]?.[Math.floor(x/M)]||isExistingTrafficBridge(topology,x,z,M),poseAllowed:(x,z,yaw,profile)=>carFits(x,z,yaw,cityRoadStaticWorld,profile||CAR),getVehicleProfile:id=>{const actor=npcLogicalVehicles?.getActor(String(id))||worldTrafficPresentation?.getActor(String(id)),p=actor?.profile;return p?{halfLength:(p.collisionHalfLength??p.halfLength)*Math.abs(actor.object.scale.z),halfWidth:(p.collisionHalfWidth??p.halfWidth)*Math.abs(actor.object.scale.x)}:null;},metresPerCell:M});cityRoadNavigation.prepare();laneRouteJobs.initialize(laneRoutingSnapshot());document.body.dataset.cityRoadNavigation=JSON.stringify(cityRoadNavigation.diagnostics());


 const select=$('district'),old=select.value;select.replaceChildren(new Option('Выбрать здание…',''));const byType=new Map();for(const item of buildings){const key=item.district||item.assetId||item.id;if(!byType.has(key))byType.set(key,item)}for(const [key,item] of byType){select.add(new Option(key,item.id))}select.value=old;
 select.onchange=()=>focus(buildings.find(x=>x.id===select.value));if(!revision&&buildings.length)focus(buildings[0]);revision=nextRevision;lastLoadAt=Date.now();


 $('status').textContent=`Установлено ${loaded} 3D-объектов: ${buildings.length} зданий, ${records(dec).length} элементов декора. ${failed?'Ошибок загрузки: '+failed+'.':'Хеши загруженных моделей проверены.'}`;


 document.body.dataset.buildingDoorsGlass=JSON.stringify(instances.map(g=>g.userData.doorsGlass?.report).filter(Boolean));document.body.dataset.residentialWindows=JSON.stringify({buildings:instances.filter(g=>g.userData.residentialWindows).length,windows:instances.reduce((n,g)=>n+(g.userData.residentialWindows?.report.windows||0)),cache:residentialWindowCacheStats()});document.body.dataset.rebuildProof=JSON.stringify({loaded,planned:all.length,buildings:buildings.length,decor:records(dec).length,failed,mode:'isolated_walk_preview',pendingHost:top.pendingHostSnapshot!==false});document.body.dataset.walkLoadTiming=JSON.stringify({assetTypes:unique.size,modelStageMs:Math.round(templatesReadyAt-startedAt),assemblyMs:Math.round(performance.now()-templatesReadyAt),totalMs:Math.round(performance.now()-startedAt),loadWorkers:3,assemblyBreakdownMs:{clone:Math.round(assemblyTiming.clone),doorsGlass:Math.round(assemblyTiming.doorsGlass),entryWindows:Math.round(assemblyTiming.entryWindows),streetLights:Math.round(assemblyTiming.streetLights),glass:Math.round(assemblyTiming.glass),railwayWait:Math.round(assemblyTiming.railwayWait),railwayElapsed:Math.round(assemblyTiming.railwayElapsed),decorPlanWait:Math.round(assemblyTiming.decorPlanWait),decorPlanElapsed:Math.round(assemblyTiming.decorPlanElapsed),decorPlanWorker:Math.round(assemblyTiming.decorPlanWorker),decorPlanMode:assemblyTiming.decorPlanMode,environmentPlanElapsed:Math.round(assemblyTiming.environmentPlanElapsed),environmentPlanWorker:Math.round(assemblyTiming.environmentPlanWorker),environmentPlanMode:assemblyTiming.environmentPlanMode,staticRenderBatches:Math.round(assemblyTiming.staticRenderBatches)}});
 }catch(error){fail(error.message);$('status').textContent='Ожидаем проверенные файлы расстановки. Последняя сцена сохранена.'}finally{busy=false}}


$('reload').onclick=refresh;


$('night-toggle').onclick=()=>{environmentNight=environmentNight?0:1;const night=!!environmentNight;$('night-toggle').setAttribute('aria-pressed',String(night));$('night-toggle').textContent=night?'Вернуть дневной свет':'Вечерний свет';ambient.intensity=night?.20:.8;sun.intensity=night?.12:1.7;scene.environmentIntensity=night?.18:.45;scene.background.set(night?'#1b2937':'#bfd1d6');scene.fog.color.copy(scene.background)};


function setWalking(enabled){walking=enabled;$('walk').setAttribute('aria-pressed',String(walking));controls.enablePan=!walking;$('cross').style.display='none';if(walking&&hero){const shift=hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0)).sub(controls.target);controls.target.add(shift);camera.position.add(shift)}}


 $('walk').onclick=()=>{if(!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active)setWalking(!walking)};


function arsenalOpen(){return weaponHud?.isOpen()??false}


function disposeWeapon(model){


 if(!model)return;model.removeFromParent();const geometries=new Set(),materials=new Set();model.traverse(node=>{if(node.geometry)geometries.add(node.geometry);for(const material of Array.isArray(node.material)?node.material:node.material?[node.material]:[])materials.add(material)});for(const geometry of geometries)geometry.dispose();for(const material of materials)material.dispose();


}


function ownedWeaponIds(){return npcBridge?(npcBridge.getWalkWeaponOptions?.().options||[]).map(item=>item.id):weaponInventory.getOwnedIds();}
function updateWeaponUi(){
 weaponHud?.setState({weaponId:currentWeapon.id,...fireState(),ownedWeaponIds:ownedWeaponIds(),ammoByWeaponId:Object.fromEntries(fireStates),disabled:!weaponInteractionAllowed({menu:true})});
 document.body.dataset.heroWeapon=JSON.stringify({id:currentWeapon.id,label:currentWeapon.label,family:currentWeapon.family,twoHanded:currentWeapon.twoHanded,visualOnly:true});


}


function equipWeapon(id){
 if(!weaponInteractionAllowed({menu:true}))return false;
 if(npcBridge){const result=npcBridge.selectWalkWeapon?.(id);if(result?.then){result.then(receipt=>{syncWorldWeapon();updateWeaponUi();if(receipt?.accepted)setArsenalOpen(false);}).catch(()=>{});return true;}syncWorldWeapon();updateWeaponUi();if(result?.accepted)setArsenalOpen(false);return !!result?.accepted;}
 return applyInventoryEquipment(weaponInventory.equip(id,fireState()));
}
function applyInventoryEquipment(result){
 if(!result.ok)return false;
 const id=result.equippedId,next=ARSENAL.find(item=>item.id===id);
 for(const ownedId of weaponInventory.getOwnedIds())fireStates.set(ownedId,weaponInventory.getFireState(ownedId));
 fireStates.set(id,result.fireState);
 artistInput.cancel();releaseWeapon();hero?.mountWeapon(null);disposeWeapon(weaponModel);weaponModel=null;currentWeapon=next;
 if(id!=='none')lastWeaponId=id;


 if(hero&&id!=='none'){weaponModel=createWeaponModel({THREE,id});hero.mountWeapon(weaponModel)}


 updateWeaponUi();setArsenalOpen(false);return true;
}
function weaponInteractionAllowed({menu=false}={}){
 return !hudInputBlocked()&&!!hero&&walking&&(menu||!occupiedSeat)&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!busy&&!artistBusy()&&!artistSwimming()&&$('scene-menu').hidden&&(menu||!arsenalOpen());
}
let networkWeaponDrops=[],networkWeaponPending=false,networkGroundPolling=false,networkGroundNextAt=0;
function currentGroundDrops(){return npcBridge?networkWeaponDrops.filter(d=>d.expiresAt>performance.now()):weaponInventory.getDropped();}
function networkWeaponSurfaceAllowed(){return !!hero&&Math.abs(hero.object.position.y)<.65&&!npcBridge?.getPlayerState?.().interior;}
function pollNetworkGroundWeapons(force=false){
 if(!npcBridge||networkGroundPolling||(!force&&performance.now()<networkGroundNextAt))return;
 networkGroundPolling=true;networkGroundNextAt=performance.now()+1200;
 Promise.resolve(npcBridge.getWalkGroundWeapons?.()).then(drops=>{networkWeaponDrops=Array.isArray(drops)?drops:[];syncGroundWeapons();})
 .catch(()=>{networkWeaponDrops=[];syncGroundWeapons();networkGroundNextAt=performance.now()+5000;}).finally(()=>{networkGroundPolling=false;});
}
function requestNetworkWeaponTransfer(action,candidate=null){
 if(networkWeaponPending)return false;
 if(!networkWeaponSurfaceAllowed()){exitNotice='Сетевой подбор пока доступен только на уровне улицы';exitNoticeUntil=performance.now()+2500;return false;}
 networkWeaponPending=true;
 if(action==='drop')releaseWeapon();
 const request=action==='drop'?npcBridge.dropWalkWeapon?.():npcBridge.pickupWalkWeapon?.(candidate.drop.uid);
 Promise.resolve(request).then(async result=>{
  if(result?.ok){
   let equipped=false;
   if(action==='drop')lastWeaponId=null;
   else if(weaponInteractionAllowed({menu:true})){
    // Equip only after the source has confirmed ownership. Network games still
    // require their normal equip receipt; a failed equip never undoes pickup.
    try{equipped=!!(await npcBridge.selectWalkWeapon?.(candidate.drop.weaponId))?.accepted;}catch{}
   }
   syncWorldWeapon();updateWeaponUi();
   exitNotice=action==='drop'?'Оружие выброшено · исчезнет через 5 минут':equipped?'Оружие подобрано и взято в руки':'Оружие подобрано · выберите его в Q';
  }
  else {const reasons={out_of_reach:'Предмет слишком далеко',drop_unavailable:'Предмет уже забрали или время истекло',unsupported_surface:'На этом этаже сетевой подбор пока недоступен',not_equipped_weapon:'Сначала выберите оружие в Q',ammo_full:'Недостаточно места для патронов'};exitNotice=reasons[result?.error]||'Сервер не подтвердил операцию с оружием';}
  exitNoticeUntil=performance.now()+2400;
 }).catch(()=>{exitNotice='Нет подтверждения сервера';exitNoticeUntil=performance.now()+2400;})
 .finally(()=>{networkWeaponPending=false;pollNetworkGroundWeapons(true);});
 return true;
}
function nearbyGroundWeapon(){
 if(!weaponInteractionAllowed()||networkWeaponPending||npcBridge&&!networkWeaponSurfaceAllowed())return null;
 return nearestWeaponDrop(currentGroundDrops(),hero.object.position,{reachable:(x,z)=>pedestrianAllowed(x,z)&&Math.abs(groundHeight(x,z,hero.object.position.y)-hero.object.position.y)<.65});
}
function syncGroundWeapons(){
 if(!groundWeapons)groundWeapons=createGroundWeapons({THREE,scene,groundHeight,scale:hero?.scale||.368});
 groundWeapons.sync(currentGroundDrops());
 frameInteraction=undefined;
}
function expireGroundWeapons(){if(npcBridge){const alive=currentGroundDrops();if(alive.length!==networkWeaponDrops.length){networkWeaponDrops=alive;syncGroundWeapons();}pollNetworkGroundWeapons();}else if(weaponInventory.expireDrops().length)syncGroundWeapons();}
function dropCurrentWeapon(){
 if(!weaponInteractionAllowed()||currentWeapon.id==='none')return false;
 if(npcBridge)return requestNetworkWeaponTransfer('drop');
 const origin=hero.object.position,yaw=hero.object.rotation.y;
 let position=null;
 // Check the whole short path, not merely an endpoint beyond a wall.
 for(const distance of [.8,.55,.3,0]){
  const x=origin.x+Math.sin(yaw)*distance,z=origin.z+Math.cos(yaw)*distance,y=groundHeight(x,z,origin.y);
  const candidate={uid:'candidate',position:{x,y,z}};
  if(!waterAt(x,z)&&nearestWeaponDrop([candidate],origin,{reachable:(px,pz)=>pedestrianAllowed(px,pz)&&Math.abs(groundHeight(px,pz,origin.y)-origin.y)<.45})){position={x,y,z};break}
 }
 if(!position){exitNotice='Нет безопасного места для оружия';exitNoticeUntil=performance.now()+1800;return false}
 const id=currentWeapon.id,result=weaponInventory.drop({position,yaw,fireState:fireState()});
 if(!result.ok)return false;
 fireStates.delete(id);if(lastWeaponId===id)lastWeaponId=null;
 applyInventoryEquipment(result);syncGroundWeapons();return true;
}
function pickupNearbyWeapon(){
 expireGroundWeapons();
 const candidate=nearbyGroundWeapon();if(!candidate)return false;
 if(npcBridge){buildingKeyConsumed=true;entryHeld=0;keys.delete('KeyE');return requestNetworkWeaponTransfer('pickup',candidate);}
 const result=weaponInventory.pickup(candidate.drop.uid,fireState());if(!result.ok){if(result.expired?.length)syncGroundWeapons();return false;}
 buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;keys.delete('KeyE');
 // The pickup transaction preserves ammunition; the player's E also equips it.
 for(const id of weaponInventory.getOwnedIds())fireStates.set(id,weaponInventory.getFireState(id));
 equipWeapon(result.drop.weaponId);syncGroundWeapons();return true;
}
function updateGroundWeaponInteraction(dt){
 expireGroundWeapons();
 groundWeapons?.update(dt);
 const candidate=nearbyGroundWeapon();
 if(!candidate){if(!weaponPickupPrompt.hidden)weaponPickupPrompt.hidden=true;weaponPickupPromptState=null;}
 else{const drop=candidate.drop,next={weaponId:drop.weaponId,magazine:drop.fireState.magazine,reserve:drop.fireState.reserveAmmo};if(weaponPickupPrompt.hidden)weaponPickupPrompt.hidden=false;if(!weaponPickupPromptState||weaponPickupPromptState.weaponId!==next.weaponId||weaponPickupPromptState.magazine!==next.magazine||weaponPickupPromptState.reserve!==next.reserve){weaponPickupPrompt.textContent=`E · Подобрать ${ARSENAL.find(item=>item.id===next.weaponId)?.label||'оружие'} · ${next.magazine} / ${next.reserve}`;weaponPickupPromptState=next;}$('car-prompt').hidden=true;$('building-prompt').hidden=true;}
 // This is an inspection-only attribute.  The pickup test and its visible
 // prompt above still run every frame; avoid serialising inventory arrays and
 // mutating the DOM up to sixty times a second when no UI consumes the data.
 const diagnosticsNow=performance.now(),lastDiagnosticsAt=updateGroundWeaponInteraction.diagnosticsAt??-Infinity;if(diagnosticsNow-lastDiagnosticsAt>=100){updateGroundWeaponInteraction.diagnosticsAt=diagnosticsNow;document.body.dataset.weaponInventory=JSON.stringify({source:npcBridge?'server':'standalone',pending:networkWeaponPending,equippedId:currentWeapon.id,ownedIds:ownedWeaponIds(),dropped:currentGroundDrops().map(d=>({uid:d.uid,weaponId:d.weaponId,position:d.position,magazine:d.fireState.magazine,reserveAmmo:d.fireState.reserveAmmo})),nearby:candidate?.drop.uid??null,ground:groundWeapons?.stats()??{count:0}});}
}
function setArsenalOpen(open){


 weaponHud?.setOpen(!!open&&weaponInteractionAllowed({menu:true}));
}


function initArsenal(){


 weaponHud=createWeaponHud({document,THREE,host:$('weapon-hud'),arsenal:ARSENAL,onSelect:equipWeapon,onOpenChange(open){if(open){updateWeaponUi();releaseControls();setFreeMouse(false);if(document.pointerLockElement)document.exitPointerLock()}}});
 document.addEventListener('pointerdown',e=>{const hud=$('weapon-hud');if(arsenalOpen()&&!e.composedPath?.().includes(hud)&&!hud.contains(e.target))setArsenalOpen(false)});updateWeaponUi();


}


initArsenal();


// Context actions share jump ownership, so vehicle/weapon/ladder guards remain atomic.
function traversalMapContains(x,z){return !!landscape?.contains(x,z)||nativePedestrianLand(topology,z/M,x/M)||!!waterAt(x,z)}
function traversalMapWalkable(x,z){return landscape?.contains(x,z)?landscape.canWalk(x,z):traversalMapContains(x,z)}
const traversalWorld=createTraversalWorld({groundHeight,ceilingHeight,bodiesAt:(x,z)=>walkCollisionIndex?.(x/M,z/M)||[],contains:traversalMapContains,walkable:traversalMapWalkable,waterAt,blocksDynamic:(x,z,y,height)=>!!worldTrafficPresentation?.blocks(x,z,0,{y,height})||!!explorationRailway?.blocks(x,z,.36)||(fleet?fleet.overlaps(x,z,0):!!carState&&pointInPolygon(x,z,carCorners(carState.x,carState.z,carState.yaw,carState.vehicleProfile))),inBody:(body,x,z)=>inPolygon(z/M,x/M,body.polygonCR)});
// Cover reuses live collision faces. Moving doors and moving cars are excluded.
function vehicleCoverHeight(record,position,polygon,bounds,normal=null){
 let point=position;
 if(!normal){
  const area=polygon.reduce((sum,a,i)=>{const b=polygon[(i+1)%polygon.length];return sum+a.x*b.z-b.x*a.z;},0);let closest=null;
  for(let i=0;i<polygon.length;i++){const a=polygon[i],b=polygon[(i+1)%polygon.length],dx=b.x-a.x,dz=b.z-a.z,l2=dx*dx+dz*dz,t=THREE.MathUtils.clamp(((position.x-a.x)*dx+(position.z-a.z)*dz)/l2,0,1),x=a.x+dx*t,z=a.z+dz*t,d=Math.hypot(position.x-x,position.z-z);if(!closest||d<closest.d)closest={x,z,d,n:{x:dz/Math.sqrt(l2)*Math.sign(area),z:-dx/Math.sqrt(l2)*Math.sign(area)}};}
  normal=closest.n;point={x:closest.x+normal.x*.37,y:position.y,z:closest.z+normal.z*.37};
 }
 return vehicleOpaqueCoverHeight(THREE,record.car.object,{position:point,normal,maxHeight:Math.min(3.5,bounds.max.y-position.y+.1)}).topY;
}
function coverBodies(position){
 const found=new Set();for(const dx of [-2,0,2])for(const dz of [-2,0,2])for(const body of walkCollisionIndex?.((position.x+dx)/M,(position.z+dz)/M)||[])found.add(body);
 const result=[...found].filter(b=>!b.movingDoor&&b.polygonCR?.length>=3).map((body,index)=>({id:body.id||body.node||`${body.buildingEntryId||'wall'}:${index}`,standOff:.39,polygon:body.polygonCR.map(([c,r])=>({x:c*M,z:r*M})),minY:body.minYM??position.y,maxY:body.maxYM??position.y+3,source:body,valid:()=>walkCollisionIndex?.has(body)??false}));
 for(const record of fleet?.nearby(position,8)||[]){if(Math.abs(record.state.speed)>.25||record.roll?.unstable)continue;
  const state=record.state,x=state.x,z=state.z,yaw=state.yaw;record.car.object.updateWorldMatrix(true,true);const bounds=new THREE.Box3().setFromObject(record.car.object);
  const polygon=vehicleCoverPolygon(x,z,yaw,state.vehicleProfile);
  result.push({id:`vehicle:${record.id}`,polygon,standOff:.37,minY:bounds.min.y,maxY:bounds.max.y,heightAt:(p,n)=>vehicleCoverHeight(record,p,polygon,bounds,n),vehicle:true,source:record,valid:()=>Math.abs(record.state.speed)<.35&&Math.hypot(record.state.x-x,record.state.z-z)<.12&&Math.abs(record.state.yaw-yaw)<.05&&!record.roll?.unstable});
 }result.push(...sourceVehicleCoverBodies(THREE,worldTrafficPresentation,position));return result;
}
function coverCanOccupy(p,height=1.9){return (waterAt(p.x,p.z)?.depth??0)<.05&&Math.abs(traversalWorld.supportHeight(p.x,p.z,p.y)-p.y)<.28&&traversalWorld.canOccupy(p,height);}
const heroCover=createHeroCover({THREE,document,getHero:()=>hero,getWeapon:()=>weaponModel,getBodies:coverBodies,canOccupy:coverCanOccupy,
 allowed:()=>!!hero&&walking&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!busy&&!artistSwimming()&&!artistBusy()&&artistAction.action.type==='none'&&surfaceMotion.state?.grounded!==false&&!hudInputBlocked()&&!arsenalOpen()&&$('scene-menu').hidden,
 profile:performanceProbe,getPosture:()=>heroPosture,requestPosture:target=>requestHeroPosture(heroPosture,target,{canOccupyHeight:height=>canOccupyPostureHeight(height)}),
 onEnter(){releaseWeapon();artistInput.cancel();buildingQaMove=null;animationQaMoveUntil=0;},onMove(shift){controls.target.add(shift);camera.position.add(shift);surfaceMotion.reset(hero.object.position);},obstacles:shotObstacles,groundHeight});
function initCoverQa(){installCoverQa({document,enabled:new URLSearchParams(location.search).get('coverqa')==='1',
 sources:()=>[...(walkCollisionIndex?.allBodies()||bodies).filter(b=>!b.movingDoor&&b.polygonCR?.length).map(b=>({polygon:b.polygonCR.map(([c,r])=>({x:c*M,z:r*M})),maxY:b.maxYM??3})),...(fleet?.records||[]).map(record=>{record.car.object.updateWorldMatrix(true,true);return {vehicle:true,polygon:vehicleCoverPolygon(record.state.x,record.state.z,record.state.yaw,record.state.vehicleProfile),maxY:new THREE.Box3().setFromObject(record.car.object).max.y};})],
 bodiesAt:coverBodies,canOccupy:traversalWorld.canOccupy,groundHeight,
 place(position,direction){heroCover.leave();releaseControls();occupiedSeat=null;transition=null;artistSurface.reset();hero.reset();resetHeroPosture(heroPosture);hero.object.position.set(position.x,position.y,position.z);surfaceMotion.reset(position);hero.object.rotation.y=Math.atan2(direction.x,direction.z);savedCameraOffset=null;aimBlend=0;controls.target.copy(hero.object.position).y+=1.2;camera.position.copy(controls.target).add(new THREE.Vector3(-direction.x*4,1.5,-direction.z*4));camera.lookAt(controls.target);setWalking(true);setFreeMouse(false);$('scene-menu').hidden=true;if(!npcBridge)equipWeapon('tt_pistol');},
 weapons:ARSENAL,selectWeapon:id=>equipWeapon(id),windowSeat(seatId){if(npcBridge||!hero||!fleet)return;heroCover.leave();releaseControls();transition=null;hero.reset();resetHeroPosture(heroPosture);const record=fleet.active||fleet.records[0];activateVehicle(record);carState.speed=0;carState.steer=0;occupiedSeat=seatId;const anchor=vehicleSeat(seatId,carState).anchor;car.object.updateWorldMatrix(true,true);hero.object.position.copy(car.object.localToWorld(new THREE.Vector3(anchor.side,anchor.y,anchor.front)));hero.object.quaternion.copy(car.object.quaternion);poseVehicleOccupant(seatId);setWalking(true);$('scene-menu').hidden=true;setFreeMouse(false);if(currentWeapon.id==='none')equipWeapon('tt_pistol');const side=seatId.endsWith('left')?1:-1,outward=new THREE.Vector3(side,0,0).applyQuaternion(car.object.quaternion);controls.target.copy(hero.object.position).y+=.7;camera.position.copy(controls.target).addScaledVector(outward,-4);camera.position.y=controls.target.y;savedCameraOffset=null;aimBlend=0;camera.lookAt(controls.target);aiming=true;},
 holdEdge(side){if(!heroCover.state)return;releaseWeapon();animationQaMoveDirection=new THREE.Vector3(heroCover.state.tangent.x*side,0,heroCover.state.tangent.z*side);animationQaMoveUntil=performance.now()+1600;},compareContact:performanceProbe?enabled=>{heroCover.setContactCaching(enabled);performanceProbe.reset();}:undefined,
 toggle:toggleHeroCover,crouch(){if(heroCover.active)return;setHeroPosture(heroPosture.target==='crouch'?'stand':'crouch');},fire(aim,held){camera.position.y=controls.target.y;camera.lookAt(controls.target);aiming=aim;triggerHeld=held;triggerPressed=held;},move(amount){if(heroCover.state)heroCover.move(new THREE.Vector3(heroCover.state.tangent.x,0,heroCover.state.tangent.z).multiplyScalar(amount));},finish(){heroCover.leave();releaseControls();}});}
function poseHeroCover(aim){return performanceProbe?performanceProbe.measure('coverPose',()=>heroCover.pose(aim)):heroCover.pose(aim);}
function toggleHeroCover(){return heroCover.request(camera.getWorldDirection(new THREE.Vector3()));}
let shoreAttemptAt=0;
function tryBeginTraversal(direction){
 if(jump||!hero||artistBusy()||artistAction.action.type!=='none')return false;
 const position=hero.object.position,water=waterAt(position.x,position.z),plan=planTraversal({position,direction,swimming:!!water&&water.depth>.05,sample:traversalWorld.sample,canOccupy:traversalWorld.canOccupy});
 if(!plan)return false;
 artistInput.cancel();releaseWeapon();entryHeld=0;pointerHeld=false;buildingQaMove=null;resetHeroPosture(heroPosture);postureMotion=posturePresentation(heroPosture);hero.reset();
 jump={...plan,mode:'traversal',elapsed:0,progress:0,x:position.x,y:position.y,z:position.z,dx:plan.direction.x,dz:plan.direction.z,directional:true,done:false};jumpCount++;
 hero.object.rotation.y=Math.atan2(jump.dx,jump.dz);for(const id of ['district','walk','reload'])$(id).disabled=true;
 return true;
}
function updateTraversal(dt){
 jump=stepTraversal(jump,dt,traversalWorld.canOccupy);hero.object.position.set(jump.x,jump.y,jump.z);const pose={...jump};
 document.body.dataset.heroTraversal=JSON.stringify({kind:jump.kind,progress:jump.progress,done:jump.done,blocked:jump.blocked,x:jump.x,y:jump.y,z:jump.z,count:jumpCount});
 if(jump.done){if(jump.blocked&&!traversalWorld.canOccupy(hero.object.position,1.9)){const target=traversalWorld.canOccupy(hero.object.position,1.69)?'crouch':'prone';resetHeroPosture(heroPosture,target);postureMotion=posturePresentation(heroPosture);}const grounded=jump.y<=heroGroundHeight(jump.x,jump.z)+.03;surfaceMotion.reset(hero.object.position,{grounded,velocityY:0});jump=null;for(const id of ['district','walk','reload'])$(id).disabled=false;}
 return pose;
}
const keys=new Set();addEventListener('keydown',e=>{if(hudInputBlocked()||e.defaultPrevented||e.target.isContentEditable||/INPUT|SELECT|TEXTAREA/.test(e.target.tagName)||arsenalOpen())return;if(['KeyW','KeyA','KeyS','KeyD','ShiftLeft','ShiftRight','AltLeft','AltRight'].includes(e.code)){buildingQaMove=null;keys.add(e.code);if(walking)e.preventDefault()}});addEventListener('keyup',e=>{keys.delete(e.code);if(e.code==='KeyE'){buildingKeyConsumed=false;window.MafioziPoliceConvoyRescue?.end()}});addEventListener('blur',()=>keys.clear());
addEventListener('keydown',e=>{


 if(hudInputBlocked()||e.defaultPrevented||e.target.isContentEditable||/INPUT|SELECT|TEXTAREA/.test(e.target.tagName))return;
 if(e.code==='Space'&&(e.composedPath?.()||[e.target]).some(node=>node?.tagName==='BUTTON'))return;
 if(e.code==='KeyQ'){e.preventDefault();if(!e.repeat&&weaponInteractionAllowed({menu:true}))setArsenalOpen(!arsenalOpen());return}
 if(arsenalOpen()){if(e.code==='Escape'){e.preventDefault();setArsenalOpen(false)}return}
 if(e.code==='KeyG'){e.preventDefault();if(!e.repeat)dropCurrentWeapon();return}
 if(e.code==='KeyR'&&!e.repeat&&!occupiedSeat&&interactWithVehiclePanel(true)){e.preventDefault();return}
 if((e.code==='ControlLeft'||e.code==='ControlRight')&&!e.repeat){e.preventDefault();if(verticalNavigation.active){verticalNavigation.slideDown();return}const ladderCandidate=nearestInteraction({fresh:true});if(ladderCandidate?.kind==='ladder'&&ladderCandidate.ladder.end==='upper'){if(!verticalNavigation.slideDown()){exitNotice='Проход к лестнице закрыт';exitNoticeUntil=performance.now()+1800}return}toggleHeroCover();return}
 if(e.code==='KeyC'&&!e.repeat){e.preventDefault();if(heroCover.active)return;setHeroPosture((jump?.queuedPosture??heroPosture.target)==='crouch'?'stand':'crouch');return}
 if(e.code==='KeyZ'&&!e.repeat){e.preventDefault();heroCover.leave();setHeroPosture((jump?.queuedPosture??heroPosture.target)==='prone'?'stand':'prone');return}
 if(e.code==='KeyE'){
  if(sourceVehicleActive()){e.preventDefault();keys.add('KeyE');return;}
  if(!e.repeat&&takeNpcCash()){e.preventDefault();buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;return;}
  const rescue=window.MafioziPoliceConvoyRescue;if(rescue?.getPrompt()?.canInteract){e.preventDefault();buildingKeyConsumed=true;entryHeld=0;pointerHeld=false;if(!e.repeat)rescue.begin();return;}
  heroCover.leave();


  e.preventDefault();


  if(e.repeat&&buildingKeyConsumed)return;
  if(!e.repeat&&pickupNearbyWeapon())return;
  if(!e.repeat&&interactWithVehiclePanel())return;
  if(verticalNavigation.active){if(!e.repeat)verticalNavigation.cancel();return;}if(!e.repeat&&interactWithBuilding())return;
  if(!$('scene-menu').hidden||jump||busy)return;
  keys.add(e.code);


 }


 if(e.code==='Space'){e.preventDefault();if(sourceVehicleActive()){keys.add('Space');return;}if(!e.repeat&&!keys.has('Space'))beginJump(e.timeStamp);keys.add(e.code)}


 if(e.code==='Home'){restoreBuildingCamera();followCarCamera=true;if(!occupiedSeat&&hero){const back=new THREE.Vector3(0,2.8,-6).applyAxisAngle(new THREE.Vector3(0,1,0),hero.object.rotation.y);controls.target.copy(hero.object.position).y=hero.object.position.y+postureEyeHeight();camera.position.copy(hero.object.position).add(back)}}


 if(e.code==='Escape'){$('scene-menu').hidden=true;setArsenalOpen(false);setFreeMouse(false);if(document.pointerLockElement)document.exitPointerLock();releaseControls()}


});


function beginJump(pressTime=performance.now()){ 


 if(artistBusy()||artistAction.action.type!=='none')return;


 if(!hero||!walking||occupiedSeat||transition||heroBlast||verticalNavigation.active||busy||(!jump&&!artistSwimming()&&surfaceMotion.state?.grounded===false)||!$('scene-menu').hidden)return;


 heroCover.leave();
 if(heroPosture.value>.001){if(!setHeroPosture('stand'))animationQaJumpPending=false;return}


 const forward=controls.target.clone().sub(camera.position);


 const direction=jumpDirection(forward,{forward:keys.has('KeyW'),back:keys.has('KeyS'),left:keys.has('KeyA'),right:keys.has('KeyD')});


 if(!jump&&tryBeginTraversal(Math.hypot(direction.x,direction.z)?direction:jumpDirection(forward,{forward:true})))return;
 if(artistSwimming())return;
 if(jump){const diveDirection=Math.hypot(direction.x,direction.z)?direction:jump.directional?{x:jump.dx,z:jump.dz}:jumpDirection(forward,{forward:true});const next=tryDiveJump(jump,diveDirection,pressTime);if(next!==jump)jump=next;return;}buildingQaMove=null;jump={...launchJump(hero.object.position,direction,{startedAt:pressTime}),baseY:heroGroundHeight(hero.object.position.x,hero.object.position.z)};jumpCount++;entryHeld=0;pointerHeld=false;hero.reset();


 hero.object.rotation.y=Math.atan2(forward.x,forward.z);


 for(const id of ['district','walk','reload'])$(id).disabled=true;


}


function updateJump(dt){
 if(jump.mode==='traversal')return updateTraversal(dt);


 const bodyHeight=hero.height||1.9,probe=stepJump(jump,dt,()=>true),footY=jump.falling?hero.object.position.y:Math.max(hero.object.position.y,jump.baseY+probe.y),allowed=(x,z)=>traversalWorld.pointFits(x,z,footY,bodyHeight);


 jump=stepJump(jump,dt,allowed);const floor=traversalWorld.supportHeight(jump.x,jump.z,footY);jump=resolveJumpSurface(jump,{floor,ceiling:heroCeilingHeight(jump.x,jump.z),bodyHeight,previousY:hero.object.position.y,dt,flightTime:JUMP.flight});const worldY=jump.worldY;hero.object.position.set(jump.x,worldY,jump.z);const pose={...jump};


 document.body.dataset.heroJump=JSON.stringify({...jump,count:jumpCount});


 if(jump.queuedPosture&&jump.elapsed>=JUMP.flight&&worldY<=floor+.02){const target=jump.queuedPosture;landingEyeTransition={from:postureEyeHeight(),start:performance.now()};hero.blendIntoPosture(LANDING_POSTURE_SECONDS);surfaceMotion.reset(hero.object.position);jump=null;if(setHeroPosture(target)){resetHeroPosture(heroPosture,target);postureMotion=posturePresentation(heroPosture)}for(const id of ['district','walk','reload'])$(id).disabled=false;return null;}if(jump.done){surfaceMotion.reset(hero.object.position,{grounded:worldY<=floor+.02,velocityY:jump.falling?jump.fallVelocity:0});jump=null;for(const id of ['district','walk','reload'])$(id).disabled=false;}


 return pose;


}


const releaseControls=()=>{window.MafioziPoliceConvoyRescue?.end();artistInput.cancel();keys.clear();if(jump)jump.queuedPosture=null;entryHeld=0;pointerHeld=false;buildingKeyConsumed=false;buildingQaMove=null;animationQaMoveUntil=0;animationQaMoveDirection=null;animationQaJumpPending=false;releaseWeapon()};addEventListener('blur',releaseControls);document.addEventListener('visibilitychange',()=>{if(document.hidden){releaseControls();npcPopulation?.markPoseInterrupted()}});


// Keep the whole UI gesture consumed, even when its button/dialog disappears
// between pointerdown and the compatibility mouse event. A new scene press
// starts a fresh gesture; no cooldown or frame polling is needed.
let walkUiPointerGesture=false;
function walkPointerHitsUi(e){return (e.composedPath?.()||[e.target]).some(n=>n?.isContentEditable||/^(BUTTON|INPUT|SELECT|TEXTAREA|LABEL|A|SUMMARY)$/.test(n?.tagName||'')||n?.dataset?.walkHud!=null||n?.getAttribute?.('role')==='dialog'||n?.getAttribute?.('role')==='button');}
function captureWalkUiPointer(e){
 if(e.type==='pointerdown')walkUiPointerGesture=hudInputBlocked()||walkPointerHitsUi(e);
 else if(walkPointerHitsUi(e))walkUiPointerGesture=true;
 if(walkUiPointerGesture)releaseControls();
}
for(const type of ['pointerdown','mousedown','click'])document.addEventListener(type,captureWalkUiPointer,true);
renderer.domElement.addEventListener('contextmenu',e=>e.preventDefault());
renderer.domElement.addEventListener('mousedown',e=>{if(e.button!==2||!waypointVisual?.visible)return;const rect=renderer.domElement.getBoundingClientRect(),ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2((e.clientX-rect.left)/rect.width*2-1,1-(e.clientY-rect.top)/rect.height*2),camera);if(ray.intersectObject(waypointVisual,true).length){e.preventDefault();e.stopImmediatePropagation();explorationMap?.setWaypoint(null)}},true);


// Pointer down/up describes the first/last held mouse button, so a second


// button in the RMB+LMB chord must use mouse down/up instead.


renderer.domElement.addEventListener('mousedown',e=>{if(e.defaultPrevented||walkUiPointerGesture||walkPointerHitsUi(e))return;if(currentWeapon.id==='none'){if(!artistAllowed())return;if(heroPosture.value>.001){setHeroPosture('stand');return;}if(e.button===2){e.preventDefault();artistInput.block(true);}if(e.button===0)artistAction=artistInput.press(artistMeleeContext());return;}if(!combatAllowed())return;if(e.button===2){e.preventDefault();aiming=true;setFreeMouse(true)}if(e.button===0){triggerHeld=true;triggerPressed=true}});


document.addEventListener('mouseup',e=>{if(e.button===0){triggerHeld=false;artistAction=artistInput.release(artistMeleeContext());}if(e.button===2){aiming=false;artistInput.block(false);}});


renderer.domElement.addEventListener('lostpointercapture',()=>artistInput.release({time:performance.now()/1000,cancelled:true}));


renderer.domElement.addEventListener('pointercancel',()=>artistInput.cancel());


document.addEventListener('pointermove',e=>{if(e.pointerType==='mouse'&&Number.isInteger(e.buttons)&&!(e.buttons&1))artistInput.release({time:performance.now()/1000,cancelled:true});});


renderer.domElement.addEventListener('pointercancel',releaseWeapon);


addEventListener('keydown',e=>{if(!e.defaultPrevented&&e.code==='KeyR'&&!e.repeat&&combatAllowed()&&!/INPUT|SELECT|TEXTAREA/.test(e.target.tagName)){e.preventDefault();reloadPressed=true}});
let orbitActive=false;controls.addEventListener('start',()=>{orbitActive=true;followCarCamera=false});controls.addEventListener('end',()=>{orbitActive=false});


let freeMouseLook=true,mouseOnScene=false,edgeTurn=0;


function setFreeMouse(enabled){freeMouseLook=enabled;controls.enabled=!enabled;controls.enableDamping=!enabled;edgeTurn=0;renderer.domElement.style.cursor=enabled?'none':'default';$('camera-help').textContent=enabled?'Мышь без кнопок — камера · Esc — курсор · колесо — приближение · C — за спину':'Клик по сцене — свободная камера мышью';document.body.dataset.mouseLook=enabled?'free':'cursor'}


function sceneHasPointerLock(){return (renderer.domElement.getRootNode()?.pointerLockElement||document.pointerLockElement)===renderer.domElement}
function turnCamera(dx,dy){restoreBuildingCamera();followCarCamera=false;const spherical=new THREE.Spherical().setFromVector3(camera.position.clone().sub(controls.target));spherical.theta-=dx;spherical.phi=THREE.MathUtils.clamp(spherical.phi-dy,.2,Math.PI*(aiming?.92:.48));camera.position.copy(controls.target).add(new THREE.Vector3().setFromSpherical(spherical));camera.lookAt(controls.target);document.body.dataset.cameraOrbit=JSON.stringify({theta:spherical.theta,phi:spherical.phi,mode:sceneHasPointerLock()?'locked':'free'})}


$('menu-toggle').onclick=()=>{$('scene-menu').hidden=!$('scene-menu').hidden;setFreeMouse(false);releaseControls()};


renderer.domElement.addEventListener('click',e=>{if(e.defaultPrevented||walkUiPointerGesture||walkPointerHitsUi(e)||hudInputBlocked())return;setFreeMouse(true);if(!document.pointerLockElement&&renderer.domElement.requestPointerLock){try{renderer.domElement.requestPointerLock()?.catch(()=>setFreeMouse(true))}catch{setFreeMouse(true)}}});
document.addEventListener('pointerlockchange',()=>{const locked=sceneHasPointerLock();setFreeMouse(locked);orbitActive=false;followCarCamera=false;if(!locked)releaseControls()});


renderer.domElement.addEventListener('mouseenter',()=>{mouseOnScene=true;edgeTurn=0});renderer.domElement.addEventListener('mouseleave',()=>{mouseOnScene=false;edgeTurn=0});


document.addEventListener('mousemove',e=>{const locked=sceneHasPointerLock(),onCanvas=e.target===renderer.domElement||e.composedPath?.().includes(renderer.domElement);if(hudInputBlocked()||!freeMouseLook||(!locked&&!onCanvas))return;const rect=renderer.domElement.getBoundingClientRect();edgeTurn=locked?0:e.clientX<rect.left+22?1:e.clientX>rect.right-22?-1:0;turnCamera(THREE.MathUtils.clamp(e.movementX,-80,80)*.004,THREE.MathUtils.clamp(e.movementY,-80,80)*.003)});
renderer.domElement.addEventListener('wheel',e=>{if(hudInputBlocked()||!freeMouseLook)return;e.preventDefault();restoreBuildingCamera();const offset=camera.position.clone().sub(controls.target),length=THREE.MathUtils.clamp(offset.length()*Math.exp(e.deltaY*.001),controls.minDistance,16);camera.position.copy(controls.target).add(offset.setLength(length))},{passive:false});
setFreeMouse(true);


// Visible, opt-in QA controls exercise the same input state as held mouse buttons.
if(['127.0.0.1','localhost'].includes(location.hostname)&&new URLSearchParams(location.search).get('npccombatqa')==='1'){
 window.addEventListener('npccombatqa:input',event=>{
  if(!combatAllowed()||occupiedSeat||heroCover.active)return;
  const action=event.detail?.action;
  if(action==='fire'){triggerPressed=true;return;}
  if(action==='reload'){reloadPressed=true;return;}
  if(action!=='aim')return;
  const actor=npcPopulation?.getActor(event.detail?.id);if(!actor?.object?.visible)return;
  const point=actor.object.position.clone().add(new THREE.Vector3(0,1.1,0)),eye=hero.object.position.clone().add(new THREE.Vector3(0,postureEyeHeight(),0));
  const forward=point.clone().sub(eye).normalize(),right=new THREE.Vector3();
  for(let i=0;i<4;i++){right.crossVectors(forward,new THREE.Vector3(0,1,0)).normalize();forward.copy(point).sub(eye).addScaledVector(right,-.75).normalize();}
  right.crossVectors(forward,new THREE.Vector3(0,1,0)).normalize();camera.position.copy(eye).addScaledVector(right,.75).addScaledVector(forward,-4.2);
  controls.target.copy(point);camera.lookAt(point);savedCameraOffset=camera.position.clone().sub(eye);aimBlend=1;aiming=true;followCarCamera=false;setFreeMouse(false);
 });
}


if(new URLSearchParams(location.search).get('weaponqa')==='1'){


 const panel=document.createElement('div');panel.style.cssText='position:absolute;top:10px;left:10px;z-index:5;background:#142b32;padding:8px';


 const aimButton=document.createElement('button');aimButton.textContent='QA: удерживать прицел';aimButton.onclick=()=>{if(combatAllowed()){aiming=!aiming;setFreeMouse(false)}};


 const fireButton=document.createElement('button');fireButton.textContent='QA: очередь 1 с';fireButton.onclick=()=>{if(combatAllowed()){triggerHeld=true;triggerPressed=true;setTimeout(()=>{triggerHeld=false},1000)}};


 panel.append(aimButton,fireButton);document.body.append(panel);


}


if(new URLSearchParams(location.search).get('animationqa')==='1'){


 const panel=document.createElement('div'),status=document.createElement('div'),weaponQa=new URLSearchParams(location.search).get('weaponqa')==='1';panel.id='animation-qa';panel.style.cssText=`position:absolute;top:${weaponQa?58:10}px;left:10px;z-index:6;display:flex;flex-wrap:wrap;gap:6px;max-width:520px;padding:8px;border:1px solid #d7b85e;border-radius:8px;background:#142b32ee;color:#fff1bd`;status.style.cssText='flex-basis:100%;font-weight:700';status.textContent='Animation QA · stand';


 const button=(label,action)=>{const node=document.createElement('button');node.type='button';node.textContent=label;node.onclick=()=>{action();status.textContent=`Animation QA · ${heroPosture.target}`};return node};


 panel.append(status,button('Стоять',()=>setHeroPosture('stand')),button('Присесть',()=>setHeroPosture('crouch')),button('Лечь',()=>setHeroPosture('prone')),button('Ползти 2 с',startAnimationQaCrawl),button('Прыжок',()=>{animationQaJumpPending=heroPosture.value>.001;beginJump()}),button('Вид спереди',()=>{if(!hero)return;setFreeMouse(false);controls.target.copy(hero.object.position).y+=.65;camera.position.copy(hero.object.position).add(new THREE.Vector3(2,1.25,3).applyAxisAngle(new THREE.Vector3(0,1,0),hero.object.rotation.y));camera.lookAt(controls.target);}),button('Перезарядить',()=>{if(combatAllowed())reloadPressed=true;}),button('Удар ЛКМ',()=>{if(!artistAllowed()||currentWeapon.id!=='none')return;artistAction=artistInput.press(artistMeleeContext());setTimeout(()=>{artistAction=artistInput.release(artistMeleeContext());},180);}));document.body.append(panel);


}


function startAnimationQaCrawl(){


 if(!setHeroPosture('prone')&&heroPosture.target!=='prone')return;const forward=controls.target.clone().sub(camera.position);forward.y=0;if(!forward.lengthSq())forward.set(0,0,1);forward.normalize();const right=new THREE.Vector3(-forward.z,0,forward.x),origin=hero.object.position;


 animationQaMoveDirection=[forward,right,right.clone().negate(),forward.clone().negate()].find(direction=>circleFits(origin.x+direction.x*.8,origin.z+direction.z*.8,pedestrianAllowed))||forward;animationQaMoveUntil=performance.now()+2600;


}


const clock=new THREE.Clock();let lastCull=0,lastStats=0,frameCount=0,frameElapsed=0,frameLongest=0;let coverMovementScale=1;


function moveHeroOnFoot(delta){
 const covered=heroCover.move(heroCover.active?delta.clone().multiplyScalar(COVER_MOVE_SPEED/Math.max(.01,postureMotion.maxSpeed)*coverMovementScale):delta,{sprinting:keys.has('ShiftLeft')||keys.has('ShiftRight')});if(covered!==null)return covered;


 const before=hero.object.position.clone(),escapeSourceId=sourceVehicleEscapeId(worldTrafficPresentation,before,delta),swimming=artistSwimming()||artistSurfaceState?.swim.blend>.1,grounded=surfaceMotion.state?.grounded!==false;let movementStartFloor,movementStartFloorReady=false;const allowed=(x,z)=>{if(!pedestrianAllowed(x,z,escapeSourceId))return false;if(swimming)return heroGroundHeight(x,z)<=before.y+.28;if(!grounded)return true;if(!movementStartFloorReady){movementStartFloor=heroGroundHeight(before.x,before.z);movementStartFloorReady=true;}return surfaceMotion.canMove(before,{x,z},heroGroundHeight,movementStartFloor)};const result=movePedestrian(before,delta,allowed);
 if(!result.moved&&Math.hypot(delta.x,delta.z)>0&&waterAt(before.x,before.z)?.depth>.05&&performance.now()>shoreAttemptAt){shoreAttemptAt=performance.now()+250;if(tryBeginTraversal(delta))return false;}


 // Face the requested step even when blocked; collision sliding controls
 // position, not the direction the player is trying to look.
 if(delta.x!==0||delta.z!==0)hero.object.rotation.y=Math.atan2(delta.x,delta.z);
 if(result.moved){hero.object.position.set(result.x,before.y,result.z);const shift=hero.object.position.clone().sub(before);controls.target.add(shift);camera.position.add(shift)}
 return result.moved;


}


function frame(){requestAnimationFrame(frame);frameInteraction=frameEntrySpot=undefined;const rawDt=clock.getDelta();frameCount++;frameElapsed+=rawDt;frameLongest=Math.max(frameLongest,rawDt);const dt=Math.min(rawDt,.04)*(exitQaMode?(exitQaPaused?0:.25):1)*(vehicleVisualQa?.timeScale||1);const coverDt=coverElapsedTime(rawDt,dt);coverMovementScale=dt>0?coverDt/dt:0;if(document.hidden||waterImpactCapture.paused)return;if(renderFreezeQa?.render(()=>renderIsolationQa?renderIsolationQa.render(()=>renderWeaponView(renderer,scene,camera,null)):renderWeaponView(renderer,scene,camera,null))){renderIsolationQa?.afterFrame();return;}carQa?.update(dt,carState);
 performanceProbe?.begin();if(performanceProbe){performanceProbe.measure('healthSync',updateWorldWalkHealth);performanceProbe.measure('playerHud',()=>walkPlayerHud?.update(performance.now()));performanceProbe.measure('mercenaryUpdate',()=>updateMercenaries(dt));}else{updateWorldWalkHealth();walkPlayerHud?.update(performance.now());updateMercenaries(dt);}if(hudInputBlocked())releaseControls();performanceProbe?.mark('healthHud');
 if(waterInspectionDriveUntil&&performance.now()>=waterInspectionDriveUntil){waterInspectionDriveUntil=0;keys.delete('KeyW');}
 if(waterInspectionExitRemaining>0){waterInspectionExitRemaining=Math.max(0,waterInspectionExitRemaining-dt);if(!waterInspectionExitRemaining)keys.delete('KeyE');}
 restoreBuildingCamera();updateBuildingEntries(dt);verticalNavigation.update(dt);if(verticalNavigation.state)document.body.dataset.roofNavigation=JSON.stringify(verticalNavigation.state);updateExplorationRailway(dt);performanceProbe?.mark('buildingRail');


 if(hero&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active)postureMotion=stepHeroPosture(heroPosture,heroCover.active?coverDt:dt,{canOccupyHeight:height=>canOccupyPostureHeight(height)});
 if(animationQaJumpPending&&!jump&&heroPosture.value<=.001){animationQaJumpPending=false;beginJump()}
 fleet?.syncActive(carState);fleet?.update(dt);if(fleet?.active)carState=fleet.active.state;
 artistAction=artistInput.step(artistMeleeContext());
 let moved=false,carStepped=false;const slowWalking=keys.has('AltLeft')||keys.has('AltRight'),running=!slowWalking&&(keys.has('ShiftLeft')||keys.has('ShiftRight')),qaCrawl=performance.now()<animationQaMoveUntil;postureMotion=posturePresentation(heroPosture,{running,slowWalking});
 if(car&&(!transition||transition.exiting)){


  const seated=!!occupiedSeat&&!transition,controlled=canControlVehicle(occupiedSeat)&&!artistBusy()&&!transition&&!carDamage?.disabled&&!carRollover?.unstable,detached=!occupiedSeat&&transition?.phase!=='door',old=car.object.position.clone();
  const input=controlled?inputForVehicleSeat(occupiedSeat,{forward:keys.has('KeyW'),reverse:keys.has('KeyS'),left:keys.has('KeyA'),right:keys.has('KeyD'),handbrake:keys.has('Space')}):{};
  carState.tyreEffects=tyres?.effects;const crashEffects=carDamage?.crashEffects||{},sliding=carDamage?.disabled||carRollover?.unstable;carState.crashEffects=sliding?{...crashEffects,engineDisabled:true,rollingDrag:(crashEffects.rollingDrag||0)+5.5}:crashEffects;carState.crashEffects=mergeWaterDriveEffects(carState,carState.crashEffects);carState.throttle=!carState.crashEffects.engineDisabled&&(input.forward||input.reverse)?1:0;const before=carState;
  const idleCar=!input.forward&&!input.reverse&&!input.left&&!input.right&&!input.handbrake&&carState.speed===0&&carState.steer===0&&carState.yawRate===0&&carState.travelYaw===carState.yaw&&carState.frontSlip===0&&carState.rearSlip===0&&!carState.handbrake&&!carState.braking;carState=idleCar?{...carState,distance:0,bumped:false,contact:null,handbrake:false,braking:false,frontSlip:0,rearSlip:0}:stepCar(carState,input,dt,fleet?fleet.blockingWorld(detached?unattendedAllowed:driveAllowed):(detached?unattendedAllowed:driveAllowed));car.object.position.set(carState.x,0,carState.z);car.object.rotation.y=carState.yaw;if(carState.contact?.otherVehicle)fleet?.resolve(before,carState,carState.contact);else{carDamage?.collision(before,carState);if(carState.contact){carRollover?.impact(carState.contact,carState.yaw);fleet?.active?.impactReaction?.impact(carState.contact,{yaw:carState.yaw});}}carRollover?.update(dt);poseWalkVehicle(car,carState,carRollover?.stats().angle||0,dt);
  car.update(carState,controlled&&keys.has('KeyS'));tyres?.update(carState,dt);carStepped=true;
  if(seated){
   const shift=car.object.position.clone().sub(old);controls.target.add(shift);camera.position.add(shift);controls.minDistance=aiming?.08:7;if(!aiming&&!savedCameraOffset)controls.target.lerp(carLocal(0,2,1),1-Math.exp(-5*dt));
   if(!aiming&&!savedCameraOffset&&!orbitActive&&followCarCamera)camera.position.lerp(carLocal(.7,-9-Math.abs(carState.speed)*.08,4),1-Math.exp(-3*dt));
   const anchor=vehicleSeat(occupiedSeat,carState).anchor;car.object.updateWorldMatrix(true,false);const seat=car.object.localToWorld(new THREE.Vector3(anchor.side,anchor.y,anchor.front));hero.object.position.copy(seat);hero.object.quaternion.copy(car.object.quaternion);
  }
  carDamage?.crash?.applyWheels({tyres:tyres?.state});
 }
 stepSourceVehicleDrive(dt);fleet?.active?.impactReaction?.update(dt);
 if(tyres&&!carStepped)tyres.update({...carState,distance:0},dt);carDamage?.update(dt);carTrunk?.update(dt,{vehicleState:carState,damageState:carDamage?.state});carHood?.update(dt,{vehicleState:carState,damageState:carDamage?.state,crashState:carDamage?.crash?.state});carDamage?.crash?.applyWheels({tyres:tyres?.state});fleet?.syncActive(carState);blastResponse?.update();fleet?.active?.renderBatches?.update();fleet?.active?.wheelRenderBatches?.update();
 if(!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!artistBusy()&&artistAction.action.type!=='dropkick'&&entryHeld===0&&walking&&(keys.size||qaCrawl)&&hero){const forward=controls.target.clone().sub(camera.position);forward.y=0;forward.normalize();const right=new THREE.Vector3().crossVectors(forward,new THREE.Vector3(0,1,0));const delta=new THREE.Vector3();if(keys.has('KeyW'))delta.add(forward);if(qaCrawl&&animationQaMoveDirection)delta.add(animationQaMoveDirection);if(keys.has('KeyS'))delta.sub(forward);if(keys.has('KeyD'))delta.add(right);if(keys.has('KeyA'))delta.sub(right);if(delta.lengthSq())delta.normalize().multiplyScalar(dt*(artistSwimming()?(running?3.4:2)*hero.scale:postureMotion.maxSpeed));moved=moveHeroOnFoot(delta)}
 if(buildingQaMove&&hero&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!artistBusy()&&artistAction.action.type!=='dropkick'){const qa=buildingQaMove;qa.elapsed+=dt;const delta=qa.target.clone().sub(hero.object.position);delta.y=0;const distance=delta.length();if(distance<.04){if(qa.remaining.length){qa.target=qa.remaining.shift();qa.elapsed=0}else buildingQaMove=null}else if(qa.elapsed>20)buildingQaMove=null;else moved=moveHeroOnFoot(delta.setLength(Math.min(distance,dt*postureMotion.maxSpeed)))||moved}
 if(hero&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active){if(!surfaceMotion.state)surfaceMotion.reset(hero.object.position);const before=hero.object.position.clone();if(artistSwimming()||artistSurfaceState?.swim.blend>.1)surfaceMotion.reset({x:before.x,y:heroGroundHeight(before.x,before.z),z:before.z});const supported=surfaceMotion.update({x:before.x,z:before.z,dt,floorHeight:heroGroundHeight});hero.object.position.set(supported.x,supported.y,supported.z);const shift=hero.object.position.clone().sub(before);controls.target.add(shift);camera.position.add(shift)}
 if(heroBlast&&hero){const old=hero.object.position.clone(),allowed=(x,z)=>canWalk(x,z)&&(!fleet||!fleet.overlaps(x,z,.58,heroBlastSource?.object?.userData.vehicleFleetId));heroBlast=stepBlastKnockback(heroBlast,dt,allowed,{groundHeight:heroGroundHeight,ceilingHeight:heroCeilingHeight});hero.object.position.set(heroBlast.x,heroBlast.y,heroBlast.z);hero.object.rotation.set(0,heroBlast.heading,0);const shift=hero.object.position.clone().sub(old);controls.target.add(shift);camera.position.add(shift);if(heroBlast.done){heroBlast=null;heroBlastSource=null;hero.reset();resetFootSupport();}}
 if(artistAction.action.type==='dropkick'&&artistAction.start){
  const attack=artistAction.start,age=performance.now()/1000-attack.time,ease=THREE.MathUtils.smoothstep;
  if(artistDropId!==attack.id){artistDropId=attack.id;artistDropDistance=0;jump=null;for(const id of ['district','walk','reload'])$(id).disabled=false;surfaceMotion.reset(hero.object.position,{grounded:false});}


  const distance=(2.8*ease(age,0,.34)+.35*ease(age,.34,.58))*hero.scale,delta=Math.max(0,distance-artistDropDistance);artistDropDistance=distance;


  moveHeroOnFoot(new THREE.Vector3(Math.sin(attack.yaw)*delta,0,Math.cos(attack.yaw)*delta));hero.object.rotation.y=attack.yaw;hero.object.position.y=heroGroundHeight(hero.object.position.x,hero.object.position.z)+attack.airHeight*(1-ease(age,.10,.65));


 }


 performanceProbe?.mark('fleetMotion');const jumpFrame=jump?updateJump(dt):null;


 updateCarInteraction(dt);


 tireTracks.update(carState,dt);


 if(weaponModel)weaponModel.visible=!occupiedSeat&&!transition&&jumpFrame?.mode!=='traversal';


 if(jump)$('drive-status').textContent=jump.mode==='traversal'?(jump.kind==='shore'?'Выбирается на берег…':'Перелезает…'):jump.elapsed<JUMP.flight?(jump.mode==='dive'?'Max Payne':jump.directional?'Обычный прыжок в сторону':'Прыжок вверх'):'Приземление…';


 if(!occupiedSeat&&hero&&!savedCameraOffset){controls.minDistance=3;const offset=new THREE.Vector3(hero.object.position.x,hero.object.position.y+postureEyeHeight(),hero.object.position.z).sub(controls.target);controls.target.add(offset);camera.position.add(offset)}


 if(freeMouseLook&&mouseOnScene&&edgeTurn&&document.hasFocus())turnCamera(-edgeTurn*dt*1.1,0);


 heroCover.update(coverDt,{direction:camera.getWorldDirection(new THREE.Vector3()),aiming,firing:triggerHeld||triggerPressed});
 if(heroCover.active){const forward=camera.getWorldDirection(new THREE.Vector3()),aimYaw=Math.atan2(forward.x,forward.z),aimPitch=Math.asin(THREE.MathUtils.clamp(forward.y,-.958,.958));hero.update(0,false,false,currentWeapon.id==='none'?null:currentWeapon,{aimYaw:hero.object.rotation.y,aimPitch:0},{posture:heroPosture});poseHeroCover({aimYaw,aimPitch});}
 controls.update();updateAimCamera(heroCover.active?coverDt:dt);clampLandscapeView();if(performanceProbe)performanceProbe.measure('indoorCamera',()=>clampBuildingCamera(dt));else clampBuildingCamera(dt);syncWorldWeapon();updateVehicleWindowFire(dt);const combat=updateCombat(dt,moved,running);
 if(hero&&!transition&&!heroCustodyActive){
  if(verticalNavigation.active)verticalNavigation.pose();else if(heroBlast)hero.tumblePose(heroBlast.progress,heroBlast.rolls);else if(occupiedSeat){if(car.poseOccupant)car.poseOccupant(hero,occupiedSeat,{steer:carState.steer,dt});else hero.vehiclePose(1,0,{driver:canControlVehicle(occupiedSeat),steeringGrips:car.getSteeringGrips(),steer:carState.steer,dt});if(Math.cos(carRollover?.angle||0)>.5)vehicleImpactPoseResult=vehicleOccupantImpactPose.apply(hero,car,occupiedSeat,fleet?.active?.impactReaction?.sample());}
  else if(jumpFrame?.mode==='traversal'){hero.reset();applyTraversalPose(THREE,hero.artistContext(),jumpFrame)}
  else if(jumpFrame){const armed=currentWeapon.id==='none'?null:currentWeapon,aim={...combat.aim,travelYaw:jumpFrame.directional?Math.atan2(jumpFrame.dx,jumpFrame.dz):combat.aim.aimYaw,diveBlend:jumpFrame.diveBlend??0};hero.jumpPose(jumpFrame.progress,jumpFrame.mode==='dive'&&jumpFrame.directional,armed,aim)}
  else {if(combat.active&&!heroCover.active)hero.object.rotation.y=combat.aim.aimYaw;hero.update(heroCover.active?coverDt:dt,moved,running,currentWeapon.id==='none'?null:currentWeapon,heroCover.active?{aimYaw:hero.object.rotation.y,aimPitch:0}:combat.active?combat.aim:{}, {posture:heroPosture,slowWalking,motionSpeed:heroCover.active?COVER_MOVE_SPEED:undefined,reloadProgress:combat.reloadProgress,action:artistAction.action})}
 }
 if(heroCover.active)poseHeroCover(combat.aim);performanceProbe?.mark('heroCombat');
 if(occupiedSeat)updateVehicleWindowFire(0,{basePose:false});
 artistUpdate(dt,moved,running);if(heroFollowGesture.active)heroFollowGesture.apply({hero,weapon:currentWeapon,now:performance.now()/1000,allowed:followGestureAllowed()});performanceProbe?.mark("heroSurface");updateNpcPopulation(dt);updateNpcHoldUp();applySourceVehiclePresentation(dt);const custodyPose=heroCustodyPose.apply(hero,worldHealthSource,dt);if(custodyPose.active&&weaponModel)weaponModel.visible=false;performanceProbe?.mark("npc");worldWalkMelee?.update(artistAction);npcGallery?.update(dt);emitCombatShots(combat);glass.update(dt);const now=performance.now();if(now-lastCull>250){for(const node of instances)node.visible=node.position.distanceToSquared(controls.target)<220*220;staticRenderBatches?.update({focus:controls.target,maxDistance:220});explorationDecor?.update?.({focus:controls.target,maxDistance:420});sun.position.copy(controls.target).add(new THREE.Vector3(-75,130,90));sun.target.position.copy(controls.target);stableEntryLights?.update();mercenaryPowerPanel?.updateVisibility?.(hero?.object.position||controls.target);lastCull=now}streetLighting.update({focus:hero?.object.position||controls.target,night:environmentNight});performanceProbe?.mark("cullLights");explorationMap?.setVisible($('scene-menu').hidden||explorationMap.expanded);if(hero)explorationMap?.update({position:hero.object.position,yaw:hero.object.rotation.y,vehicles:explorationMinimapVehicles(),trains:explorationMinimapTrains(),actors:explorationNpcMarkers()});updateWaterInteractions(dt);waterVapor?.update(dt,fleet?.records||[],hero?.object.position);captureWaterInspection(dt);environmentVisuals?.update({dt,time:now*.001,focus:hero?.object.position||controls.target,camera,...grassHeroContact(),actorRadius:.65});performanceProbe?.mark("mapEnvironment");const indoorVisibility=indoorHeroVisibility.update(!!indoorCameraFrame?.hideHead);if(now-indoorCameraDiagnosticsAt>=100){indoorCameraDiagnosticsAt=now;document.body.dataset.indoorCamera=JSON.stringify({...indoorVisibility,mode:indoorCameraFrame?.mode||'orbit',headDistance:indoorCameraFrame?.headDistance,boomLength:indoorCameraFrame?.boomLength,availableLength:indoorCameraFrame?.availableLength,occlusionReason:indoorCameraFrame?.occlusionReason,position:camera.position.toArray(),feet:hero?.object.position.toArray(),eyeHeight:postureEyeHeight()});}vehicleVisualQa?.applyCamera(camera,controls);vehicleImpactView.render(camera,car,occupiedSeat&&!transition?fleet?.active?.impactReaction?.sample():null,()=>{camera.updateMatrixWorld();mercenaryWalk?.updatePresentation(rawDt);renderWeaponView(renderer,scene,camera,combat.allowed?combat.recoil:null);});updateWaypointDistance();frameInteraction=undefined;updateCarPrompt();updateBuildingPrompt();const rescuePrompt=window.MafioziPoliceConvoyRescue?.getPrompt();if(rescuePrompt?.canInteract&&!hudInputBlocked()&&!occupiedSeat)setCarInteractionText('drive-status',rescuePrompt.text);
 performanceProbe?.mark('npcEnvironmentAndRender');updateGroundWeaponInteraction(dt);performanceProbe?.end();
 if(now-lastStats>1000){document.body.dataset.vehicleDamage=JSON.stringify(carDamage?.stats()||{});if(carQa)document.body.dataset.vehicleImpactReaction=JSON.stringify({reaction:fleet?.active?.impactReaction?.sample(),pose:vehicleImpactPoseResult,camera:vehicleImpactView.stats()});document.body.dataset.tyreDamage=JSON.stringify(tyres?.stats()||{});document.body.dataset.streetLighting=JSON.stringify(streetLighting.stats());document.body.dataset.staticRenderBatches=JSON.stringify(staticRenderBatches?.stats?.()||null);document.body.dataset.surfaceMotion=JSON.stringify(surfaceMotion.state);document.body.dataset.glassBreakage=JSON.stringify(glass.stats());document.body.dataset.blastResponse=JSON.stringify(blastResponse?.stats?.()||null);document.body.dataset.startupCompile=JSON.stringify(startup.report)}
 if(now-lastStats>1000){
  document.body.dataset.tireTracks=JSON.stringify({active:tireTracks.pool.active,count:tireTracks.pool.count});
  document.body.dataset.vehicleFleet=JSON.stringify(fleet?.stats());
  $('stats').textContent=`${hero?'Персонаж Художника 13 · ':''}Вызовы отрисовки: ${renderer.info.render.calls} · r ${Math.round(controls.target.z/M)}, c ${Math.round(controls.target.x/M)}`;
  if(hero){
   document.body.dataset.heroWalk=JSON.stringify({loaded:true,x:hero.object.position.x,y:hero.object.position.y,z:hero.object.position.z,moving:moved,running,slowWalking,maxSpeed:postureMotion.maxSpeed,mode:'isolated_walk',height:postureMotion.height,eyeHeight:postureMotion.eyeHeight,posture:heroPosture.target,postureValue:heroPosture.value,postureBlocked:postureMotion.blocked});


   const current=buildingEntries.find(entry=>entry.containsInterior(hero.object.position));


   document.body.dataset.buildingEntry=JSON.stringify({count:buildingEntries.length,inside:current?.instance.id||null,floorY:heroGroundHeight(hero.object.position.x,hero.object.position.z),heroY:hero.object.position.y,cameraClamped:!!cameraBeforeBuildingClamp,doors:buildingEntries.map(entry=>entry.report)});


   const buildingQaStatus=document.getElementById('building-qa-status');if(buildingQaStatus)buildingQaStatus.textContent=`${current?'Внутри комнаты':'Снаружи'} · пол ${heroGroundHeight(hero.object.position.x,hero.object.position.z).toFixed(2)} · герой ${hero.object.position.y.toFixed(2)} · ${buildingQaMove?'идёт':'стоит'} · камера ${cameraBeforeBuildingClamp?'перед стеной':'свободна'}`;


  }


  document.body.dataset.environmentVisuals=JSON.stringify(environmentVisuals?.stats||{});
  document.body.dataset.waterInteractions=JSON.stringify(waterEffects?.stats()||{});document.body.dataset.vehicleWaterVapor=JSON.stringify(waterVapor?.stats()||{});
  document.body.dataset.explorationRuntime=JSON.stringify({fps:Math.round(frameCount/Math.max(.001,frameElapsed)),longestFrameMs:Math.round(frameLongest*1000),calls:renderer.info.render.calls,triangles:renderer.info.render.triangles,decor:explorationDecor?.stats,groundY:hero?groundHeight(hero.object.position.x,hero.object.position.z):null});frameCount=frameElapsed=frameLongest=0;lastStats=now;


 }


}
function createHudHeroSurface(target){return createArtist14Surface({THREE,context:target.artistContext(),scene,applySwim:(sample,ctx)=>{if(worldHealthFrame?.snapshot.dead)return;if(transition?.waterExit&&transition.phase==='body'){artistPose.swim(sample,ctx);return;}if(sourceVehicleActive()||occupiedSeat||transition||jump||heroBlast)return;if(sample.blend>0||exitSwimHandoff)ctx.object.position.y=heroSwimHeight(ctx.object.position.x,ctx.object.position.z,sample);artistPose.swim(sample,ctx);},applyReaction:(sample,ctx)=>{if(!occupiedSeat&&!transition&&!heroBlast&&!verticalNavigation.active)artistPose.reaction(sample,ctx);}})}
function canApplyHudHero(){return !!hero&&!busy&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!artistBusy()&&!artistSwimming()&&artistAction.action.type==='none'&&!triggerHeld&&!aiming}
function applyHudHero(record){
 indoorHeroVisibility.restore();
 if(!canApplyHudHero())return false;const previous=hero,previousOwned=hudAppearanceHero,previousSurface=artistSurface,saved=previousSurface?.snapshot();let nextSurface;
 try{
  record.hero.object.position.copy(previous.object.position);record.hero.object.quaternion.copy(previous.object.quaternion);record.hero.object.visible=previous.object.visible;record.hero.object.updateMatrixWorld(true);
  nextSurface=createHudHeroSurface(record.hero);
  if(saved){try{nextSurface.restore(saved,{time:performance.now()/1000})}catch(error){
   // New creator topology cannot accept old triangle indices. Never erase active
   // bullet wounds to force a cosmetic swap. Unwounded rigs retain receipts,
   // reaction and bruises while the fresh clothing gets its own vertex arrays.
   if(saved.wounds?.marks?.length)throw error;
   const clean=nextSurface.snapshot();nextSurface.restore({...clean,time:saved.time,reaction:saved.reaction,bruises:saved.bruises,receipts:saved.receipts},{time:performance.now()/1000});
  }}
 }catch(error){nextSurface?.dispose();document.body.dataset.walkHudAppearanceError=error.message;return false}
 releaseControls();previous.mountWeapon(null);hero=record.hero;hudAppearanceHero=record;artistSurface=nextSurface;artistSurfaceState=null;scene.add(hero.object);if(weaponModel)hero.mountWeapon(weaponModel);hero.update(0,false,false,currentWeapon.id==='none'?null:currentWeapon,{}, {posture:heroPosture});surfaceMotion.reset(hero.object.position);previousSurface?.dispose();if(previousOwned)previousOwned.dispose();else previous.dispose();delete document.body.dataset.walkHudAppearanceError;return true;
}
function initPlayerDossier(){
 if(walkPlayerHud)return;walkPlayerHud=createWalkHudController({THREE,loader,cloneSkeleton:cloneNpcSkeleton,document,window,getBridge:()=>npcBridge,getHero:()=>hero,getNpcActor:id=>npcPopulation?.getActor(id)||npcPopulation?.getActor('npc_'+id)||npcPopulation?.getActor('npc_unique_'+id),canSwapHero:canApplyHudHero,swapHero:applyHudHero,openMercenaryMember:id=>mercenaryWalk?.openMember(id)===true,onInputLock(){releaseControls();setArsenalOpen(false);setFreeMouse(false);if(document.pointerLockElement)document.exitPointerLock()},onActionError:reason=>{document.body.dataset.walkHudActionError=reason}});
}
addEventListener('pagehide',()=>{walkPlayerHud?.dispose();hudAppearanceHero?.dispose()},{once:true});
addEventListener('pagehide',()=>indoorHeroVisibility.dispose(),{once:true});
addEventListener('pagehide',()=>mercenaryWalk?.dispose(),{once:true});
addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
addEventListener('pagehide',()=>{worldWalkHealth?.dispose();waterInspection?.dispose();npcBridge?.registerWalkNpcNavigationResolver?.(null);npcBridge?.registerWalkNpcPerceptionResolver?.(null);npcBridge?.registerWalkNpcVehicleAccessResolver?.(null);npcInspection?.dispose();npcPopulation?.dispose();for(const controller of sourceVehicleDriveControllerSet)controller.dispose();sourceVehicleDriveControllerSet.clear();worldTrafficPresentation?.dispose();npcGallery?.dispose();worldWalkCombat?.dispose();worldWalkMelee?.dispose();groundWeapons?.dispose();weaponPickupPrompt.remove();weaponCrosshair.dispose();weaponHud?.dispose();explorationMap?.dispose();if(waypointVisual){const materials=new Set();waypointVisual.traverse(n=>{n.geometry?.dispose();if(n.material)materials.add(n.material)});materials.forEach(m=>m.dispose());waypointVisual.removeFromParent()}waypointDistance?.remove();vehicleVisualQa?.dispose();carQa?.dispose();clearContent({recreate:false});fleet?.dispose();artistSurface?.dispose();effects.dispose();blastResponse?.dispose();tireTracks.dispose()},{once:true});
async function start(){await refresh();if(!topology)return;try{hero=await loadHeroWalker({THREE,loader,targetHeight:1.9});scene.add(hero.object);artistSurface=createArtist14Surface({THREE,context:hero.artistContext(),scene,applySwim:(sample,ctx)=>{if(worldHealthFrame?.snapshot.dead)return;if(transition?.waterExit&&transition.phase==='body'){artistPose.swim(sample,ctx);return;}if(sourceVehicleActive()||occupiedSeat||transition||jump||heroBlast)return;if(sample.blend>0||exitSwimHandoff)ctx.object.position.y=heroSwimHeight(ctx.object.position.x,ctx.object.position.z,sample);artistPose.swim(sample,ctx);},applyReaction:(sample,ctx)=>{if(!occupiedSeat&&!transition&&!heroBlast&&!verticalNavigation.active)artistPose.reaction(sample,ctx);}});focus(instances[0]?.userData.instance);setWalking(true);$('walk').textContent='Управлять персонажем';initCar();equipWeapon(currentWeapon.id);initBuildingQa();initWaterInspection();installTraversalQa({document,enabled:new URLSearchParams(location.search).get('traversalqa')==='1',available:()=>!!hero&&!busy&&!jump&&!occupiedSeat&&!transition&&!heroBlast&&!verticalNavigation.active,getBodies:()=>bodies,groundHeight,waterAt,canOccupy:traversalWorld.canOccupy,plan:(position,direction,swimming)=>planTraversal({position,direction,swimming,sample:traversalWorld.sample,canOccupy:traversalWorld.canOccupy}),move(position,direction){releaseControls();artistSurface.reset();hero.reset();resetHeroPosture(heroPosture);hero.object.position.set(position.x,position.y,position.z);hero.object.rotation.y=Math.atan2(direction.x,direction.z);surfaceMotion.reset(hero.object.position);controls.target.copy(hero.object.position).y+=1.2;camera.position.copy(controls.target).add(new THREE.Vector3(-direction.x*5,2.2,-direction.z*5));setWalking(true);setFreeMouse(false);$('scene-menu').hidden=true;},begin:()=>beginJump(),finish:releaseControls,walk(duration=20000){animationQaMoveDirection=new THREE.Vector3(0,0,1).applyAxisAngle(new THREE.Vector3(0,1,0),hero.object.rotation.y);animationQaMoveUntil=performance.now()+(typeof duration==='number'?duration:20000);}});initCoverQa();await initNpcPopulation();}catch(e){fail('Персонаж не загружен: '+e.message)}}
initPlayerDossier();start();frame();setInterval(()=>{if(!document.hidden&&!arsenalOpen()&&!busy&&!heroCover.active&&!occupiedSeat&&!sourceVehicleActive()&&!transition&&!jump&&!heroBlast&&!verticalNavigation.active&&!aiming&&!triggerHeld&&!savedCameraOffset&&Math.abs(carState?.speed||0)<.01)refresh()},15000);
