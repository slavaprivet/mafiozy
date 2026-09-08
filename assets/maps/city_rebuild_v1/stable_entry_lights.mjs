// Keep the room-light shader layout fixed while buildings are distance-culled.
// Each source has one permanent slot. A culled source contributes zero, exactly
// as before; colour, attenuation and world position are otherwise unchanged.
// Only static, non-shadow-casting entry lights belong here. Animated effects
// and shadow lights keep their own lifecycle/API.
export function createStableEntryLights(THREE, entries, scene) {
  const group = new THREE.Group();
  group.name = 'Stable_Entry_Light_Slots';
  const slots = [];
  for (const entry of entries) entry.object.traverse(source => {
    if (!source.isPointLight || source.castShadow) return;
    const light = source.clone(), mask = source.layers.mask;
    light.name = 'Entry_Light_Slot';
    light.visible = true;
    // Preserve source hierarchy/visibility for ownership and dispose. Exclude
    // only its original render contribution; the slot supplies that same light.
    source.layers.disableAll();
    group.add(light);
    slots.push({source, light, mask});
  });
  scene.add(group);
  function update() {
    for (const {source, light} of slots) {
      let visible = true;
      for (let node = source; node; node = node.parent) if (!node.visible) { visible = false; break; }
      light.intensity = visible ? source.intensity : 0;
      light.color.copy(source.color);
      light.distance = source.distance;
      light.decay = source.decay;
      source.getWorldPosition(light.position);
    }
  }
  update();
  return {update, dispose() {
    for (const {source, mask} of slots) source.layers.mask = mask;
    group.removeFromParent();
  }};
}
