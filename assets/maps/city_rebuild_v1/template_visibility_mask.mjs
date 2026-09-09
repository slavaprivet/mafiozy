// Placement metadata often hides collision, socket and authored LOD helper
// nodes. When every placement of a verified GLB uses the same mask, applying
// it to the non-rendered template once lets Object3D.clone copy the exact
// visibility state. Keep the original values so a later placement revision
// can safely restore or replace the mask.
const baselineVisibility = new WeakMap();

function namesSet(names) {
  return Array.isArray(names) && names.length ? new Set(names) : null;
}

export function maskSignature(names) {
  const hidden = namesSet(names);
  return hidden ? [...hidden].sort().join('\u001f') : '';
}

export function applyTemplateVisibilityMask(template, names = []) {
  if (!template?.traverse) throw new TypeError('A GLTF template Object3D is required');
  const hidden = namesSet(names);
  let baseline = baselineVisibility.get(template);
  if (!baseline && !hidden) return {visited: 0, hidden: 0, tracked: false};
  let visited = 0, masked = 0;
  if (!baseline) {
    baseline = new Map();
    template.traverse(node => {
      baseline.set(node, node.visible);
      visited++;
      if (hidden.has(node.name)) {
        node.visible = false;
        masked++;
      }
    });
    baselineVisibility.set(template, baseline);
  } else {
    for (const [node, visible] of baseline) {
      visited++;
      const next = visible && !(hidden?.has(node.name));
      if (next !== node.visible) node.visible = next;
      if (!next && visible) masked++;
    }
  }
  return {visited, hidden: masked, tracked: true};
}

// Preserve the legacy per-clone path for a future placement revision where
// one GLB is intentionally used with different masks.
export function applyCloneVisibilityMask(visual, names = []) {
  if (!visual?.traverse) throw new TypeError('A GLTF clone Object3D is required');
  const hidden = namesSet(names);
  if (!hidden) return {visited: 0, hidden: 0};
  let visited = 0, masked = 0;
  visual.traverse(node => {
    visited++;
    if (hidden.has(node.name)) {
      node.visible = false;
      masked++;
    }
  });
  return {visited, hidden: masked};
}
