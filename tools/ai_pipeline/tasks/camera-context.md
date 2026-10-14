# Context for Astra 4 — bounded camera index review

User priority: severe game lag, interiors included, with no loss of picture quality.
Existing architect owns building camera triangle acceleration. Another author owns
near-body framing/visibility. You are an independent researcher preparing evidence
for Coordinator 17, not replacing those authors or executing game changes.

Historical evidence, 13 September (not today's measurement): tower camera solve
16.96/23.48 ms p50/p95, matrices .033/.072; bank solve .517/.614. Five rays touched
large merged building meshes. Camera triangle index was prepared as a candidate.
Shared world FPS was not resolved. Do not infer a fresh speedup from these values.

Coordinator read current walk_preview.mjs on 16 September:
- import {createIndoorCamera} from './indoor_camera.mjs';
- import {resolveBuildingCameraPosition} from './building_entry.mjs';
- const indoorCamera=createIndoorCamera({THREE,resolvePosition:resolveBuildingCameraPosition});
- solve receives objects: relevant.map(entry=>entry.visual), ceiling from current
  entry, inside: !!current||verticalNavigation.active, current aiming and dt.
- A search of walk_preview.mjs found no import/reference to the building camera
  triangle index. This is a scoped search, not proof that no other module installs it.

Current indoor_camera imports indoor_camera_clearance, which belongs to ongoing
near-body work. Old handoff PASS statements precede some of those changes. Do not
claim current near-body acceptance or alter it to make an index review simpler.
Three source itself and actual GLB geometry are absent from this context; the
test references the local installed vendor. Name any exact missing contract rather
than inventing private Three.js behavior. Coordinator can inspect or execute those
specific checks locally after your report; you have no tool execution here.

Return a focused acceptance review and, only for an established defect, an index-only
patch. A full implementation of another camera system is outside the assignment.
