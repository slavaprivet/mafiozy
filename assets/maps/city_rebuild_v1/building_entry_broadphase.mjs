// Allocation-free AABB broadphase for entry work that is followed by the
// entries' exact local-space tests.  The bounds include each generated room,
// doorway and storeys, so this can only reject entries that are farther than
// the caller's requested interaction/camera radius.
export function collectNearbyBuildingEntries(entries, point, padding = 0, output = []) {
  output.length = 0;
  if (!point) return output;
  const limit = padding * padding;
  for (const entry of entries) {
    const bounds = entry.sampleBounds;
    if (!bounds) { output.push(entry); continue; }
    const dx = Math.max(bounds.min.x - point.x, 0, point.x - bounds.max.x);
    const dz = Math.max(bounds.min.z - point.z, 0, point.z - bounds.max.z);
    if (dx * dx + dz * dz <= limit) output.push(entry);
  }
  return output;
}
