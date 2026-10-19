"""Prepare the isolated, exact-source waypoint-progress patch; never edits game."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
REL = 'scripts/hospital/npc_simple_hospital.gd'
BASE_SHA = '0bb28b9d34ac0877c23b0737909348dcc715053739738c13f68522635f15020c'


def main():
    source = ROOT / 'outputs/coordinator31_npc57/game' / REL
    raw = source.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == BASE_SHA, 'source is not exact stage58_03'
    before = raw.decode('utf-8-sig')
    eol = '\r\n' if '\r\n' in before else '\n'
    after = before
    changes = [
        ('# Called only on an attempted service movement, after peer/FIFO waits. This is\n'
         '# a local replan request, never arrival, service completion or a collision bypass.',
         '# Called only on attempted service/roam movement, after peer waits. Track\n'
         '# the current waypoint, not the final goal: a planned detour may lead away\n'
         '# from that goal. Replan uses the same route and cumulative work budget.'),
        ('\tif direction.length()<.001:return _finish_step(before,delta,"walking")',
         '\tif direction.length()<.001:\n'
         '\t\t# A flat-aligned waypoint can still fail its floor/height/edge arrival\n'
         '\t\t# checks. Do not let that early return bypass roaming progress.\n'
         '\t\tif _target_source == "roam" and _service_waypoint_stalled56(int(_route._ready_frame), _way, remaining, delta):\n'
         '\t\t\t_roam_step29_phase = "planning"; _restart("roam_waypoint_no_progress58")\n'
         '\t\treturn _finish_step(before,delta,"walking")'),
        ('\tif _target_source == "service_approach" and _service_waypoint_stalled56(int(_route._ready_frame), _way, remaining, delta):\n'
         '\t\t_roam_step29_phase = "planning"; _restart("service_waypoint_no_progress56")',
         '\tif _target_source in ["service_approach", "roam"] and _service_waypoint_stalled56(int(_route._ready_frame), _way, remaining, delta):\n'
         '\t\t_roam_step29_phase = "planning"\n'
         '\t\t_restart("roam_waypoint_no_progress58" if _target_source == "roam" else "service_waypoint_no_progress56")'),
    ]
    for old, new in changes:
        old, new = old.replace('\n', eol), new.replace('\n', eol)
        assert after.count(old) == 1, 'patch anchor not unique'
        after = after.replace(old, new)
    destination = HERE / 'patch' / REL
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('x', encoding='utf-8', newline='') as handle:
        handle.write(after)
    diff = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                     fromfile='stage58_03/' + REL, tofile='candidate/' + REL))
    (HERE / 'PATCH.diff').write_text(diff, encoding='utf-8', newline='')
    manifest = dict(schema='mafiozi.roam-recovery58.patch/v1', status='AWAITING_NATIVE_COMPONENT',
                    production_modified=False, source_stage='stage58_03',
                    files=[dict(path=REL, before_sha256=BASE_SHA,
                                after_sha256=hashlib.sha256(destination.read_bytes()).hexdigest())],
                    constraints=['same physical motor, geometry, masks, speed and arrival gates',
                                 'same route/guide/goal and cumulative service_us29 across _restart',
                                 'existing 3s / .10m current-waypoint rule; peer waits excluded',
                                 'services retain their original nonzero-direction behavior'],
                    limitation='Historical table collider does not prove the original physical cause; fresh native replay arrived in 3.028s. Component validation and a new natural soak remain required.')
    (HERE / 'PROPOSAL.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    patch = {REL: dict(base_sha256=BASE_SHA, candidate_sha256=manifest['files'][0]['after_sha256'])}
    (HERE / 'PATCH.json').write_text(json.dumps(patch, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest))


if __name__ == '__main__':
    main()
