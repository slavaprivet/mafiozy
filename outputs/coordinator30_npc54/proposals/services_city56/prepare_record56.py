"""Capture preparation status and exact harness/reference hashes without an engine."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

references = [
    OUT.parent / 'injury30/observer_injury30.gd',
    OUT.parent / 'injury30/observer_death28.gd',
    OUT.parent / 'final_qa30/staff_cycle_final30.gd',
    OUT.parent / 'final_qa30/run_final30b.py',
    OUT.parent / 'stalls56/observer_counts56.gd',
    ROOT / 'docs/godot/TEST_SCHEDULER.md',
]
cpu = json.loads((OUT / 'CPU_CHECK.json').read_text(encoding='utf-8'))
assert cpu['passed'] and cpu['native_launched'] is False
record = {
    'schema': 'services56.prepared/v1',
    'status': 'PREPARED_NOT_NATIVE_TESTED',
    'native_launched': False,
    'shared_or_frozen_modified': False,
    'harness_pins': {p.name: sha(p) for p in OUT.iterdir() if p.is_file() and p.name != 'PREPARED.json'},
    'references': {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in references},
    'cpu_checks': cpu['check_count'],
    'independent_acceptance_predicates': cpu['independent_acceptance_check_count'],
    'remaining': ['Coordinated native parse/actual full-city run after root perf', 'Review failure evidence or accept first four actual services'],
}
(OUT / 'PREPARED.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'status': record['status'], 'files': len(record['harness_pins']), 'cpu_checks': record['cpu_checks'], 'native_launched': False}))
