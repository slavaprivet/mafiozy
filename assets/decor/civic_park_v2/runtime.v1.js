import {civicParkDecorPreviewGate, loadCivicParkPlacementCandidate, loadCivicParkDecorAssetCandidate, preflightCivicParkPlacementCandidate, disposeCivicParkDecorCandidate} from './registry.v1.js';

export const CIVIC_DECOR_OWNER = 'CITY_V3_CIVIC_PARK_V2_ROOT';
const requireThat = (value, message) => { if (!value) throw new Error(message); };
const proxyName = name => /^(COLLISION_|CLEARANCE_|PLACEMENT_SOCKET_|WATER_SOCKET_|WATER_JET_SOCKET_)/.test(name || '');

// One transaction owns all meshes and gameplay bodies. Nothing attaches during loading.
export async function mountCivicParkDecor({THREE, GLTFLoader, scene, bridge, renderer, params, hostname, originR, originC, worldScale, signal}) {
  requireThat(civicParkDecorPreviewGate(params, hostname), 'decor-preview-gate');
  requireThat(typeof bridge?.getCityV3DecorHost === 'function' && typeof bridge?.registerCityV3DecorCollisions === 'function' && typeof bridge?.unregisterCityV3DecorCollisions === 'function', 'decor-gameplay-bridge-missing');
  requireThat(Math.abs(worldScale - 4.1) < 1e-9, 'decor-world-scale');
  const abort = new AbortController();
  const cancel = () => abort.abort(signal?.reason || new Error('decor-cancelled'));
  if (signal?.aborted) cancel(); else signal?.addEventListener('abort', cancel, {once:true});
  const timeout = setTimeout(() => abort.abort(new Error('decor-load-timeout')), 20000);
  const candidates = [], objects = [], bodies = [];
  const root = new THREE.Group(); root.name = CIVIC_DECOR_OWNER;
  let registered = false, disposed = false;
  const dispose = () => {
    if (disposed) return;
    disposed = true; abort.abort(new Error('decor-disposed'));
    root.removeFromParent();
    if (registered) bridge.unregisterCityV3DecorCollisions(CIVIC_DECOR_OWNER);
    for (const candidate of candidates) disposeCivicParkDecorCandidate(candidate);
    renderer.domElement.dataset.cityV3DecorActivation = 'inactive:rolled-back';
    renderer.domElement.dataset.cityV3DecorObjects = '0';
  };
  try {
    const candidate = await loadCivicParkPlacementCandidate({params, hostname, signal:abort.signal});
    requireThat(candidate.contract.placements.length === 30, 'decor-placement-count');
    preflightCivicParkPlacementCandidate(candidate, bridge.getCityV3DecorHost());
    const work = [...new Set(candidate.contract.placements.map(p => p.key))].flatMap(key => [0,1,2].map(lod => ({key,lod})));
    let next = 0;
    const loaded = new Map();
    const workers = Array.from({length:3}, async () => {
      while (next < work.length && !abort.signal.aborted) {
        const {key,lod} = work[next++];
        try {
          const asset = await loadCivicParkDecorAssetCandidate({THREE,GLTFLoader,params,hostname,key,lod,signal:abort.signal});
          candidates.push(asset); loaded.set(`${key}:${lod}`, asset);
        } catch (error) { abort.abort(error); throw error; }
      }
    });
    const results = await Promise.allSettled(workers);
    const failed = results.find(r => r.status === 'rejected');
    if (failed) throw failed.reason;
    if (abort.signal.aborted) throw abort.signal.reason;
    for (const placement of candidate.contract.placements) {
      const item = new THREE.Group(); item.name = placement.id;
      const uniformScale=placement.uniformScale??1;
      requireThat(Number.isFinite(uniformScale)&&uniformScale>=1&&uniformScale<=1.35, `decor-uniform-scale:${placement.id}`);
      item.scale.setScalar(uniformScale);
      item.position.set((placement.c-originC)*worldScale, .035, (placement.r-originR)*worldScale);
      item.rotation.y = placement.yawDeg*Math.PI/180;
      const levels = [], water = [];
      for (let lod=0; lod<3; lod++) {
        const asset = loaded.get(`${placement.key}:${lod}`);
        requireThat(asset, `decor-incomplete:${placement.key}:${lod}`);
        const level = asset.assetRoot.clone(true);
        const socket = level.getObjectByName(asset.entry.requiredNodes.find(name => name.startsWith('PLACEMENT_SOCKET_')));
        requireThat(socket, `decor-placement-socket:${placement.id}`);
        level.updateMatrixWorld(true);
        const localSocket = new THREE.Vector3(); socket.getWorldPosition(localSocket);
        level.position.sub(localSocket);
        level.traverse(node => {
          if (proxyName(node.name)) node.visible = false;
          if (node.isMesh) { node.castShadow = true; node.receiveShadow = true; node.userData.cityV3Decor = placement.id; }
          if (node.name.startsWith('ANIMATED_SURFACE_')) water.push({node, y:node.position.y});
        });
        level.visible = lod === 2; item.add(level); levels.push(level);
      }
      root.add(item); root.updateMatrixWorld(true);
      // Extract collision proxies after the exact socket/yaw/world transform.
      // CLEARANCE is never collision: benches and shelters retain their open space.
      levels[0].traverse(node => {
        if (!node.name.startsWith('COLLISION_') || !node.isMesh) return;
        const box = new THREE.Box3().setFromObject(node);
        requireThat(!box.isEmpty(), `decor-empty-collision:${placement.id}`);
        const body = {id:`${placement.id}:${node.name}`,minR:box.min.z/worldScale+originR,maxR:box.max.z/worldScale+originR,minC:box.min.x/worldScale+originC,maxC:box.max.x/worldScale+originC};
        const clearance = placement.clearanceAabbGridRC;
        requireThat(body.minR>=clearance.minR-.025&&body.maxR<=clearance.maxR+.025&&body.minC>=clearance.minC-.025&&body.maxC<=clearance.maxC+.025, `decor-collision-outside-clearance:${placement.id}`);
        bodies.push(body);
      });
      objects.push({placement,item,levels,water});
    }
    // Loading can span several frames: recheck the live city immediately before commit.
    preflightCivicParkPlacementCandidate(candidate, bridge.getCityV3DecorHost());
    if (abort.signal.aborted) throw abort.signal.reason;
    scene.add(root);
    registered = true; // unregister also cleans up a host registration that throws halfway.
    const result = bridge.registerCityV3DecorCollisions(CIVIC_DECOR_OWNER, bodies);
    requireThat(result?.ok === true, `decor-collision-registration:${result?.reason || 'rejected'}`);
    renderer.shadowMap.needsUpdate = true;
    renderer.domElement.dataset.cityV3DecorActivation = 'active:approved-civic-park-v2';
    renderer.domElement.dataset.cityV3DecorObjects = String(objects.length);
    renderer.domElement.dataset.cityV3DecorCollisions = String(bodies.length);
    renderer.domElement.dataset.cityV3DecorFountains = '3';
    renderer.domElement.dataset.cityV3DecorPedestrianLights = '3';
    renderer.domElement.dataset.cityV3DecorGpuLights = '0';
    renderer.domElement.dataset.cityV3DecorPlacementHash = candidate.placementSha256;
    const focus = candidate.contract.focusCoordinates.find(p => p.id === params.get('cityv3decorfocus'));
    if (focus) {
      const result = bridge.previewApproachCityV3Decor?.(focus);
      renderer.domElement.dataset.cityV3DecorFocus = result?.ok ? focus.id : `rejected:${result?.reason || 'focus-api-missing'}`;
    }
    return {root, objects, bodies, dispose, update(time, player, telemetryDue) {
      if (disposed) return;
      const lodCounts=[0,0,0]; let visible=0;
      for (const object of objects) {
        const distance = player ? Math.hypot(player.r-object.placement.r,player.c-object.placement.c)*worldScale : Infinity;
        const lod = distance < 22 ? 0 : distance < 55 ? 1 : 2;
        object.item.visible = distance < 190;
        object.levels.forEach((level,index) => { level.visible = index === lod; });
        if (object.item.visible) { visible++; lodCounts[lod]++; }
        const phase = Math.floor(time*.03)/30*1.2;
        for (const surface of object.water) surface.node.position.y = surface.y + Math.sin(phase)*.018;
      }
      if (telemetryDue) {
        renderer.domElement.dataset.cityV3DecorNearbyObjects = String(visible);
        renderer.domElement.dataset.cityV3DecorLods = lodCounts.join(',');
      }
    }};
  } catch (error) { dispose(); throw error; }
  finally { clearTimeout(timeout); signal?.removeEventListener('abort',cancel); }
}
