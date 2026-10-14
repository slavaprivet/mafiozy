/** Pinned actual-main checkpoint stage; source copied by the existing audited stager. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {buildAtomicSource as buildNavAtomic} from '../map_editor_nav_atomic_candidate/build_candidate.mjs';
import {buildSource as buildResidentAtomic} from '../map_editor_resident_atomic_candidate/build_candidate.mjs';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const base=path.join(root,'tools/godot/map_editor_ordinary_building_tx_candidate/stage_checkpoint.mjs');
const staged=JSON.parse(execFileSync(process.execPath,[base,'--stage'],{cwd:root,encoding:'utf8'}).trim());
assert.equal(staged.status,'STAGED_NO_GODOT');
const dir=path.resolve(root,staged.stage);
assert.ok(dir.startsWith(path.join(root,'outputs')+path.sep));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const nav=buildNavAtomic(),resident=buildResidentAtomic();
const overlays=[
  ['scripts/navigation/preview_navigation_host.gd',nav.host],
  ['scripts/navigation/path_job_queue.gd',nav.queue],
  ['scripts/navigation/pause_backend.gd',nav.pauseBackend],
  ['scripts/navigation/atomic_backend.gd',nav.backend],
  ['scripts/preview_population.gd',Buffer.from(resident.population)],
  ['scripts/npc_visual/preview_resident_host.gd',Buffer.from(resident.resident)],
  ['scripts/npc_visual/preview_resident_world_policy.gd',Buffer.from(resident.policy)],
];
for(const [relative,bytes] of overlays){
  const target=path.join(dir,relative);
  assert.ok(target.startsWith(dir+path.sep));
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes);
  assert.equal(sha(fs.readFileSync(target)),sha(bytes));
}
const additions=[['nav_geometry_receipt.gd','scripts/map_editor/nav_geometry_receipt.gd'],['shadow_navigation_owner.gd','scripts/map_editor/shadow_navigation_owner.gd'],['test_actual_three_residents.gd','test_actual_three_residents.gd'],['test_shadow_navigation_owner.gd','test_shadow_navigation_owner.gd'],['test_shadow_delete.gd','test_shadow_delete.gd'],['test_multi_building_geometry.gd','test_multi_building_geometry.gd']];
for(const [sourceName,targetName] of additions){
  const bytes=fs.readFileSync(path.join(own,sourceName));
  const target=path.join(dir,targetName);
  assert.ok(target.startsWith(dir+path.sep));
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes,{flag:'wx'});
  assert.equal(sha(fs.readFileSync(target)),sha(bytes));
}
const receipt={schema:'mafiozi.nav-geometry-stage/v2',baseReceiptSha256:staged.receiptSha256,overlays:overlays.map(([relative,bytes])=>({path:relative,sha256:sha(bytes)})),additions:additions.map(([sourceName,relative])=>({path:relative,sha256:sha(fs.readFileSync(path.join(own,sourceName)))})),gpu:false};
fs.writeFileSync(path.join(dir,'nav_geometry_stage_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:'STAGED_NAV_GEOMETRY_ATOMIC_OWNERS',stage:staged.stage,baseReceiptSha256:staged.receiptSha256,sourceClosure:'Coordinator22 immutable residents checkpoint',residents:3,gpu:false}));
