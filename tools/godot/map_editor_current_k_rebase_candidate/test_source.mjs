import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildCurrentSource, patchCurrentHitOwner, patchCurrentPopulation, patchCurrentResident} from './build_candidate.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const project = path.join(root, 'godot/mafiozi_walk');
const read = relative => fs.readFileSync(path.join(project, relative), 'utf8');
const original = {
  resident: read('scripts/npc_visual/preview_resident_host.gd'),
  population: read('scripts/preview_population.gd'),
  policy: read('scripts/npc_visual/preview_resident_world_policy.gd'),
  hit: read('scripts/npc_visual/npc_local_preview_hit_owner.gd')
};
const built = buildCurrentSource(relative => {
  const key = ({'scripts/npc_visual/preview_resident_host.gd':'resident', 'scripts/preview_population.gd':'population', 'scripts/npc_visual/preview_resident_world_policy.gd':'policy', 'scripts/npc_visual/npc_local_preview_hit_owner.gd':'hit'})[relative];
  assert(key, `Unexpected source ${relative}`);
  return original[key];
});
let checks = 0;
const has = (content, fragment, label) => { assert(content.includes(fragment), label); checks++; };
has(built.resident, 'var activity: RefCounted = record.activity', 'current activity captured');
has(built.resident, '"physical_rows":physical_rows', 'current physical owners captured');
has(built.resident, 'if physical_status.get("mode") != "IDLE": return {}', 'active ragdoll refused');
has(built.population, 'const LocalHits = preload(', 'current local hit owner retained');
has(built.population, 'hit_owners.append(owner)', 'current local HP setup retained');
has(built.population, 'state.hit_owners.append(', 'local HP receipt captured');
has(built.population, 'func prepare_editor_resume_atomic(', 'atomic release retained');
has(built.hit, 'var _gameplay_clock: RefCounted', 'HP clock bound');
has(built.hit, 'return _gameplay_clock.now_ms()-_start_ms+1.0', 'HP time excludes pause');
has(built.workspace, '"weapons_state":_main.preview_weapons.snapshot()', 'weapon owner captured');
has(built.workspace, 'return "weapons_effect_in_flight"', 'weapon effects quiescent gate');
has(built.workspace, 'func _resume_gameplay(', 'K release retained');
assert(!built.hit.includes('var _start_us:=0'));
checks++;
assert.throws(() => patchCurrentHitOwner(original.hit.replace('var _start_us:=0', 'var _start_us:=1')), /Missing or ambiguous/);
checks++;
assert.throws(() => patchCurrentPopulation(original.population.replace('func setup(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true)', 'func setup2(scene: Node3D, staged_preview: bool = false, walking_preview: bool = true)')), /Expected one source seam/);
checks++;
assert.throws(() => patchCurrentResident(original.resident.replace('func configure(scene: Node3D, navigation: RefCounted', 'func configure2(scene: Node3D, navigation: RefCounted')), /Expected one source seam/);
checks++;
for (const [key, relative] of Object.entries({resident:'scripts/npc_visual/preview_resident_host.gd', population:'scripts/preview_population.gd', policy:'scripts/npc_visual/preview_resident_world_policy.gd', hit:'scripts/npc_visual/npc_local_preview_hit_owner.gd'})) {
  assert.equal(read(relative), original[key], `Source not mutated: ${relative}`);
  checks++;
}
console.log(JSON.stringify({checks, production:false, nativeParse:false, currentArtist23FeaturesRetained:true}));
