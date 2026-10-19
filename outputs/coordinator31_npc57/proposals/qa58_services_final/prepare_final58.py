"""Create a new adapter for exact stage58_03; preserve all historical evidence."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = OUT.parent / 'qa58_services'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = ROOT / 'outputs/coordinator31_npc57/extended31/stage58_03/CANDIDATE58.json'
expected_sha = '46a095bd14fdede78861d097cd5e69ad73a32c6cdf842b6944375101e84155a7'
assert sha(manifest) == expected_sha
native_names = ['accept_services56.py', 'entry_services56.gd', 'observer_counts56.gd', 'observer_services56.gd']
assert not any((OUT / name).exists() for name in native_names + ['run_services58.py'])
for name in native_names:
    (OUT / name).write_bytes((BASE / name).read_bytes())
s = (BASE / 'run_services58.py').read_text(encoding='utf-8')
s = s.replace("    parser.add_argument('--seconds', type=int, default=240)",
    "    parser.add_argument('--seconds', type=int, default=600)\n"
    "    parser.add_argument('--expected-source', type=Path, required=True)")
s = s.replace('assert 180 <= args.seconds <= 420', 'assert 180 <= args.seconds <= 600')
s = s.replace("expected_path=ROOT/'outputs/coordinator31_npc57/extended31/stage58_02/CANDIDATE58.json'",
    "expected_path=args.expected_source.resolve()")
s = s.replace('4a00c3c85b4d705ce917c60a7d0b92deb634d24eb57b41cff2664d24e2cfb70e', expected_sha)
s = s.replace("    assert (project / 'project.godot').is_file()",
    "    assert (project / 'project.godot').is_file()\n"
    "    assert project == (ROOT / 'outputs/coordinator31_npc57/game').resolve()\n"
    "    assert args.residents == 10")
s = s.replace("            before = pins(project)",
    "            assert {str(p.resolve()):sha(p) for p in controls_files} == controls, 'Controls changed before launch'\n"
    "            before = pins(project)")
(OUT / 'run_services58.py').write_text(s, encoding='utf-8')
report = {'schema': 'mafiozi.qa58.final-services-preparation/v1',
    'source_manifest': str(manifest.relative_to(ROOT)), 'source_manifest_sha256': expected_sha,
    'source_count': len(json.loads(manifest.read_text(encoding='utf-8'))['source_pins']),
    'native_files': {name: {'sha256': sha(OUT/name), 'byte_identical_to_source02_harness': (OUT/name).read_bytes() == (BASE/name).read_bytes()} for name in native_names},
    'adapter_sha256': sha(OUT/'run_services58.py'),
    'base_adapter_sha256': sha(BASE/'run_services58.py'),
    'duration_cap_s': 600,
    'duration_rationale': 'Previous exact source02 natural restaurant route694.991m needed407.701s, leaving12.299s under420. Set600 before new run; native movement/service checks and all behavior remain unchanged.',
    'production_modified': False, 'historical_evidence_modified': False}
(OUT / 'PREPARATION58.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
