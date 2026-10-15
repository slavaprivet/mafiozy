"""Prepare isolated host/passsage hooks against exact stage04; never edits game."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GAME = ROOT / 'outputs/coordinator31_npc57/game'


def patch(relative, base_sha, replacements):
    source = GAME / relative
    raw = source.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == base_sha
    before = raw.decode('utf-8-sig')
    eol = '\r\n' if '\r\n' in before else '\n'
    after = before
    for old, new in replacements:
        old, new = old.replace('\n', eol), new.replace('\n', eol)
        assert after.count(old) == 1, (relative, old)
        after = after.replace(old, new)
    destination = HERE / 'patch' / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('x', encoding='utf-8', newline='') as handle:
        handle.write(after)
    return ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='stage04/'+relative, tofile='candidate/'+relative))


def main():
    diffs = []
    diffs.append(patch('scripts/npc_visual/preview_resident_host.gd',
                       '9cae435a12c8649eae8f42364225efab19255abad68463d51c47314c983d3cee', [
        ('const AmbientPose28 = preload("res://scripts/npc_ambient/ambient_pose28.gd")',
         'const AmbientPose28 = preload("res://scripts/npc_ambient/ambient_pose28.gd")\nconst HomePose58 = preload("res://scripts/homes/npc_home_pose58.gd")'),
        ('\t\tvar treating28: bool = not treatment_sample28.is_empty() and treatment_pose28 != null',
         '\t\tvar treating28: bool = not treatment_sample28.is_empty() and treatment_pose28 != null\n'
         '\t\tvar home_sample58: Dictionary = HomePose58.sample(body, delta, external_motion51)\n'
         '\t\tif treating28 or (retaliation != null and retaliation.engaged()) or hit_pose_active: home_sample58 = {}\n'
         '\t\tvar home_pose58: RefCounted = record.get("home_pose58")\n'
         '\t\tif not home_sample58.is_empty():\n'
         '\t\t\tvar home_rig58: Skeleton3D = record.gait._skeleton\n'
         '\t\t\tif home_pose58 == null or not home_pose58.ready_for(home_rig58):\n'
         '\t\t\t\thome_pose58 = HomePose58.new()\n'
         '\t\t\t\tif home_pose58.bind(home_rig58, record.gait._rest_poses): record["home_pose58"] = home_pose58\n'
         '\t\t\t\telse: home_pose58 = null; home_sample58 = {}\n'
         '\t\tvar home_active58: bool = not home_sample58.is_empty() and home_pose58 != null\n'
         '\t\tvar home_previous58: bool = bool(record.get("home_pose_active58", false))\n'
         '\t\trecord["home_pose_active58"] = home_active58'),
        ('\t\tif treating28 or (retaliation != null and retaliation.engaged()) or hit_pose_active: ambient_sample28 = {}',
         '\t\tif treating28 or home_active58 or (retaliation != null and retaliation.engaged()) or hit_pose_active: ambient_sample28 = {}'),
        ('\t\tif treating28 or ambient_active28 or ambient_previous28 or hit_pose_active or (retaliation != null and retaliation.engaged()): dsh_lod_ok = true',
         '\t\tif treating28 or home_active58 or home_previous58 or ambient_active28 or ambient_previous28 or hit_pose_active or (retaliation != null and retaliation.engaged()): dsh_lod_ok = true'),
        ('\t\tif (retaliation != null and retaliation.engaged()) or hit_pose_active or treating28 or ambient_active28:',
         '\t\tif (retaliation != null and retaliation.engaged()) or hit_pose_active or treating28 or home_active58 or ambient_active28:'),
        ('\t\t\tif treating28: pose = treatment_pose28.compose(pose, treatment_sample28)\n\t\t\telif ambient_active28:',
         '\t\t\tif treating28: pose = treatment_pose28.compose(pose, treatment_sample28)\n\t\t\telif home_active58: pose = home_pose58.compose(pose, home_sample58)\n\t\t\telif ambient_active28:'),
        ('\t\t\t\tif ambient_active28: AmbientPose28.committed(rig, ambient_sample28)',
         '\t\t\t\tif ambient_active28: AmbientPose28.committed(rig, ambient_sample28)\n\t\t\t\tif home_active58: HomePose58.committed(rig, home_sample58)'),
    ]))
    diffs.append(patch('scripts/navigation/npc_passage31.gd',
                       '4fb0fa9f35fe030628e45a5802ca1ca12cae642f57a0ea6eff2697a25e73e4c9', [
        ('\tvar entries: Dictionary = registry._entries if is_instance_valid(registry) else {}\n\tvar now:',
         '\tvar entries: Dictionary = registry._entries if is_instance_valid(registry) else {}\n'
         '\t# Assigned homes share only the measured NPC doorway passage policy.\n'
         '\t# Copy before merge: home geometry never mutates the trading registry.\n'
         '\tvar homes58: Variant = scene.get_meta("npc_home_registry58", null)\n'
         '\tif is_instance_valid(homes58) and homes58.has_method("passage_entries"):\n'
         '\t\tvar home_entries58: Dictionary = homes58.passage_entries()\n'
         '\t\tif not home_entries58.is_empty():\n'
         '\t\t\tentries = entries.duplicate()\n'
         '\t\t\tfor key58: String in home_entries58:\n'
         '\t\t\t\tif key58.begins_with("home58:") and not entries.has(key58): entries[key58] = home_entries58[key58]\n'
         '\tvar now:'),
    ]))
    (HERE / 'HOOKS.diff').write_text(''.join(diffs), encoding='utf-8', newline='')
    print(json.dumps({'prepared': True, 'files': 2, 'production_modified': False}))


if __name__ == '__main__':
    main()
