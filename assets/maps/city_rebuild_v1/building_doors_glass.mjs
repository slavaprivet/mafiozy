// Runtime-only treatment of audited LOD0 assets. Call after byte/hash verification
// on an instance clone, never on the shared GLTF template. No geometry is added.
const canonGlass = 'Canon_Deep_Smoked_Teal_Glass';
const profile = (sha256, glass = [], knobs = false, hiddenNodes = []) =>
  Object.freeze({sha256, glass: Object.freeze(glass), knobs, hiddenNodes: Object.freeze(hiddenNodes)});

export const BUILDING_DOORS_GLASS_PROFILES = Object.freeze({
  coastal_orchard_house_v1: profile('ac9b33396f0773823d74a517ec8764438bd8b2bd253110a0cf3806310f5b9f20', [], true),
  garden_lane_house_v1: profile('c15b6c3f8360a504a76f35e4b96510c18fb30a321db75651a8260bd965540c37', [], true),
  hillstep_chalet_v1: profile('26f0868537c6e95136cdf69f9d3a7a554b61b29e974fc1949cdd94f8819c8714', [], true),
  pine_ridge_cottage_v1: profile('0ee0526b4389a356006396310d796c69080ddcd976ecac24d7dd7c424e2a0da3', [], true),
  veranda_bungalow_v1: profile('8adf5797cf739c73bf5b3a7d0586406dade6f1a3b566c18cda2c0a510ba5aa5b', [], true),
  woodland_crosswing_house_v1: profile('060efe1399086eba29b8ba0871787792aa4bfd8187a54203837e5f7ddf44814b', [], true),
  compact_podium_glass_tower_v1: profile('caa4b79ab28993e3a8c84054f5366de2df94a4d70ff76f7073d01dd73caea531', ['SmokedTealGlass']),
  pawnshop: profile('1a95f97569d94d162d2d0c4217e1435a2b9e5860a49a2d140d90e4d899d6232f', ['Smoked shop glass']),
  glass_pavilion_small_v1: profile('ecae5f97bd53e9466bea3a520ec95a58ecacd7a232fbde902de0a1a7d4672873', ['Smoky teal architectural glass'], false, ['Small_Galleria_Sign']),
  civic_hall: profile('81a289dc228032ae4bd0a7f610a06527f9eac36ca3ee8efdc1be312053e4ad3c', [canonGlass]),
  hospital: profile('542b901c3bd0abebf4ac8a3590cbf30047eb748abb7ab3216fa18ec6ecd780a8', [canonGlass]),
  nightclub: profile('624967d9ad8e11bd105e314794af8371c67e8d0bd3a2d00855243b56371a9415', [canonGlass]),
});

const applications = new WeakMap();

/**
 * Preserve authored colour, alpha, AO, roughness, transmission and silhouettes.
 * The pinned profile opts in exact assets/materials; opaque window panels require
 * artist geometry, so they deliberately do not become transparent here.
 * dispose() restores this instance and disposes only material clones we own.
 */
export function applyBuildingDoorsGlass(visual, instance = {}) {
  const previous = applications.get(visual);
  if (previous) return previous;
  const config = BUILDING_DOORS_GLASS_PROFILES[instance.assetId];
  const report = {assetId: instance.assetId ?? null, status: 'not-profiled',
    glassMeshes: 0, brassKnobs: 0, hiddenNodes: [], materialClones: 0};
  const skipped = () => ({report, dispose() {}});
  if (!config) return skipped();
  if (instance.binding?.sha256?.toLowerCase() !== config.sha256 || instance.binding?.lod !== 0) {
    report.status = 'binding-mismatch';
    return skipped();
  }
  if (!visual?.traverse) throw new TypeError('A cloned GLTF scene is required');
  const replacements = [], visibility = [], clones = new Map();
  function materialCopy(source, kind) {
    let variants = clones.get(source);
    if (!variants) clones.set(source, variants = new Map());
    if (variants.has(kind)) return variants.get(kind);
    const material = source.clone();
    if (kind === 'glass') {
      material.depthWrite = false;
      material.side = 0; // THREE.FrontSide: prevent duplicate transparent surfaces.
      material.forceSinglePass = true;
    } else {
      // Linear RGB from the accepted pavilion's Muted brass PBR material.
      material.color.fromArray([0.72, 0.43, 0.10]);
      material.metalness = 0.56;
      material.roughness = 0.34;
      material.name = 'Door hardware · muted brass';
    }
    material.needsUpdate = true;
    variants.set(kind, material);
    report.materialClones++;
    return material;
  }
  visual.traverse(node => {
    if (config.hiddenNodes.includes(node.name)) {
      visibility.push([node, node.visible]);
      node.visible = false;
      report.hiddenNodes.push(node.name);
    }
    if (!node.isMesh || !node.material) return;
    const original = node.material;
    const source = Array.isArray(original) ? original : [original];
    let glass = false, knob = false;
    const updated = source.map(material => {
      if (config.glass.includes(material.name) && material.transparent && material.opacity < 1) {
        glass = true;
        return materialCopy(material, 'glass');
      }
      if (config.knobs && node.name === 'PublicDoorKnob' && material.name === 'ClayStone') {
        knob = true;
        return materialCopy(material, 'brass');
      }
      return material;
    });
    if (glass || knob) {
      replacements.push([node, original]);
      node.material = Array.isArray(original) ? updated : updated[0];
      if (glass) report.glassMeshes++;
      if (knob) report.brassKnobs++;
    }
  });
  report.status = 'applied-needs-live-review';
  let disposed = false;
  const result = {report, dispose() {
    if (disposed) return;
    disposed = true;
    for (const [node, material] of replacements) node.material = material;
    for (const [node, visible] of visibility) node.visible = visible;
    for (const variants of clones.values()) for (const material of variants.values()) material.dispose();
    applications.delete(visual);
  }};
  applications.set(visual, result);
  return result;
}
