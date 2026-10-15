"""Audit terminal services evidence without rewriting native receipts."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--expected-source', type=Path, required=True)
    args = parser.parse_args()
    run = args.run.resolve()
    run.relative_to(OUT / 'runs')
    target = run / 'FINAL_SERVICES58.json'
    assert not target.exists(), 'Preserve prior audit'
    names = ['RUN.json', 'SERVICES56.json', 'SOURCE.json', 'SOURCE_AFTER.json',
             'CONTROL_PINS.json', 'CONTROL_PINS_AFTER.json', 'HARNESS_PINS.json',
             'HARNESS.zip', 'FLAGS.json', 'PROBE.json', 'stdout.log', 'stderr.log']
    before = {name: sha(run / name) for name in names}
    receipt = read(run / 'RUN.json')
    assert 'exit_code' in receipt, 'Native run is not terminal'
    native = read(run / 'SERVICES56.json')
    expected = read(args.expected_source)['source_pins']
    pins = read(run / 'HARNESS_PINS.json')
    with zipfile.ZipFile(run / 'HARNESS.zip') as archive:
        archived = set(archive.namelist()) == set(pins) and all(
            hashlib.sha256(archive.read(name)).hexdigest() == digest for name, digest in pins.items())
        assert archived, 'Tested harness archive mismatch'
        assert pins['accept_services56.py'] == 'df62eda3bce3cdad6824e3ed897a331aba6545649abaf05540d2fb39213b0006'
        checker = {}
        exec(compile(archive.read('accept_services56.py'), '<archived independent checker>', 'exec'), checker)
    checks = checker['accept'](native)
    gates = {
        'terminal_native_passed': receipt.get('passed') is True and receipt.get('exit_code') == 0,
        'all37_independent_checks': len(checks) == 37 and all(checks.values()),
        'checks_match_original_receipt': checks == receipt['checks'],
        'exact_final_candidate': read(run / 'SOURCE.json') == read(run / 'SOURCE_AFTER.json') == expected,
        'pinned_manifest': receipt['candidate_sha256'] == sha(args.expected_source),
        'controls_unchanged': read(run / 'CONTROL_PINS.json') == read(run / 'CONTROL_PINS_AFTER.json'),
        'no_source_control_harness_drift': all(receipt.get(key) == [] for key in ['source_drift', 'control_drift', 'harness_drift']),
        'no_native_errors': receipt.get('errors') == [] and receipt.get('stderr_bytes') == 0,
        'graphical_ten_residents': receipt['mode'] == 'graphical' and receipt['requested_residents'] == 10,
        'immutable_harness_verified': archived and receipt['harness_archive_sha256'] == sha(run/'HARNESS.zip'),
    }
    cases = {name: {key: row.get(key) for key in ['id', 'entered', 'completed', 'outbound', 'travel_m', 'max_physics_displacement_m', 'hp_after_tt']}
             | {'native_payment_receipts': len(row.get('money_receipts', [])),
                'native_healing_receipts': len(row.get('heal_receipts', [])),
                'service_frame': row.get('service', {}).get('frame'),
                'exit_frame': row.get('exit', {}).get('frame')}
             for name, row in native['cases'].items()}
    result = {'schema': 'mafiozi.qa58.final-services-audit/v1', 'passed': all(gates.values()),
        'gates': gates, 'checks_passed': sum(checks.values()), 'checks_total': len(checks),
        'native_reason': native['reason'], 'run': str(run.relative_to(ROOT)),
        'source_manifest': str(args.expected_source.resolve()), 'source_count': len(expected),
        'source_manifest_sha256': sha(args.expected_source), 'wall_s': receipt.get('wall_s'),
        'cases': cases, 'failed_checks': [key for key, value in checks.items() if not value],
        'raw_evidence_sha256': before, 'auditor_sha256': sha(Path(__file__)),
        'performance_accepted': False, 'full_soak_accepted': False, 'release_accepted': False,
        'production_modified': False, 'user_game_preserved': True,
        'limitations': ['This is the four-service fixture, separate from the natural1200-second spatial observation.',
                       'Runs alongside the user game are functional evidence, not comparable FPS.']}
    assert before == {name: sha(run/name) for name in names}, 'Native evidence changed during audit'
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['passed', 'gates', 'checks_passed', 'checks_total', 'native_reason', 'wall_s', 'cases']}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
