// Keep a bounded room-light shader layout while buildings are distance-culled.
// Hundreds of visible zero-intensity PointLights still consume GPU uniforms;
// a GLSL loop does not reduce that array. Nearby enabled sources share 32 fixed
// slots. Authored fixtures/source objects and their ownership remain intact.
import {selectNearestLightFixtures} from './street_lighting.mjs';
export function createStableEntryLights(THREE, entries, scene, {maxLights=32,getFocus=()=>null}={}) {
  const group = new THREE.Group();
  group.name = 'Stable_Entry_Light_Slots';
  const sources = [], seen = new Set();
  const limit=Math.max(1,Math.min(32,Math.floor(Number.isFinite(maxLights)?maxLights:32)));
  for (const entry of entries) entry.object.traverse(source => {
    if (!source.isPointLight || source.castShadow || seen.has(source)) return;
    seen.add(source);const mask = source.layers.mask;
    // The unmodified source retains its position, intensity, colour and parent;
    // only its direct contribution is replaced by one pooled GPU slot.
    source.layers.disableAll();
    sources.push({source,mask,world:new THREE.Vector3(),active:false});
  });
  const slots=Array.from({length:Math.min(limit,sources.length)},()=>{
    const light=new THREE.PointLight(0,0,0,2);light.name='Entry_Light_Slot';light.visible=true;light.castShadow=false;group.add(light);return light;
  });
  const nearest=[],distances=[],origin=new THREE.Vector3(),inverse=new THREE.Matrix4();let disposed=false,visibleSources=0;
  scene.add(group);
  function update(settings={}) {
    if(disposed)return;
    const focus=settings?.isVector3?settings:settings?.focus||getFocus();
    if(focus&&[focus.x,focus.y,focus.z].every(Number.isFinite))origin.set(focus.x,focus.y,focus.z);else origin.set(0,0,0);
    visibleSources=0;
    for (const descriptor of sources) {
      const {source,mask}=descriptor;
      let visible = true;
      for (let node = source; node; node = node.parent) if (!node.visible) { visible = false; break; }
      descriptor.active=visible&&mask!==0&&Number.isFinite(source.intensity)&&source.intensity>0;
      if(descriptor.active){visibleSources++;source.getWorldPosition(descriptor.world)}
    }
    selectNearestLightFixtures(sources,origin,slots.length,nearest,distances);
    group.updateWorldMatrix(true,false);inverse.copy(group.matrixWorld).invert();
    for(let i=0;i<slots.length;i++){
      const light=slots[i],descriptor=nearest[i];
      if(!descriptor){light.intensity=0;delete light.userData.roomLightSource;continue}
      const {source,mask}=descriptor;
      light.intensity=source.intensity;light.color.copy(source.color);light.distance=source.distance;light.decay=source.decay;light.layers.mask=mask;
      light.position.copy(descriptor.world).applyMatrix4(inverse);light.userData.roomLightSource=source.uuid;
    }
    return stats();
  }
  // `update` already evaluates every source to build the nearest set.  Keep
  // that exact count instead of allocating a filtered source array on each
  // scheduled room-light refresh (the full city can have hundreds of sources).
  function stats(){return{sourceLights:sources.length,fixedLights:slots.length,activeLights:nearest.length,visibleSources,maxLights:limit,focus:{x:origin.x,y:origin.y,z:origin.z}}}
  update();
  return {update,stats, dispose() {
    if(disposed)return;disposed=true;
    for (const {source, mask} of sources) source.layers.mask = mask;
    group.removeFromParent();for(const light of slots)light.dispose?.();
  }};
}
