"""Root-only explicit native/import/packed/GPU run. No shared writes or process handoff."""
import argparse
import shutil
import time
from common34 import *


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('import', 'native', 'packed', 'gpu'), required=True)
    parser.add_argument('--suite', choices=('lamp', 'rear', 'dashboard'), default='lamp')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    require(args.suite != 'rear' or args.mode in ('native', 'packed'), 'Accepted rear fixture is native/headless only')
    require(args.suite != 'dashboard' or args.mode in ('native', 'packed', 'gpu'), 'Dashboard suite requires a runtime mode')
    require(args.out and all(c.isalnum() or c in '_-' for c in args.out), 'Use a simple fresh run name')
    m = load_assembly()
    assembly_sha = sha(ASSEMBLY)
    qa_receipt = read(HERE / 'QA34.json')
    qa_name = {'lamp':'test_street34.gd', 'rear':'test_rear34.gd', 'dashboard':'test_dashboard34.gd'}[args.suite]
    qa_sha = qa_receipt[{'lamp':'qa_sha256', 'rear':'rear_qa_sha256', 'dashboard':'dashboard_qa_sha256'}[args.suite]]
    require(qa_receipt['assembly_sha256'] == assembly_sha and sha(HERE / qa_name) == qa_sha, 'QA changed')
    if args.suite == 'rear':
        rear_receipt = read(HERE / 'REAR_QA34.json')
        require(rear_receipt['qa_sha256'] == qa_sha and sha(Path(rear_receipt['source'])) == rear_receipt['source_sha256'], 'Accepted rear source changed')
    if args.suite == 'dashboard':
        dashboard_receipt = read(HERE / 'DASHBOARD_QA34.json')
        require(dashboard_receipt['qa_sha256'] == qa_sha and sha(Path(dashboard_receipt['base_source'])) == dashboard_receipt['base_source_sha256'], 'Dashboard inherited source changed')
        require(sha(HERE / 'dashboard_base34.gd') == qa_receipt['dashboard_base_sha256'] == dashboard_receipt['base_qa_sha256'], 'Dashboard inherited fixture changed')
    game = Path(m['game'])
    out = HERE / 'runs' / args.out
    require(not out.exists(), 'Preserve previous results')
    before = inventory()
    if args.mode == 'gpu':
        require_gpu_free(before)
    pack = None
    pack_sha = None
    if args.mode in ('packed', 'gpu'):
        delivery = read(HERE / 'DELIVERY34.json')
        require(delivery['assembly_sha256'] == assembly_sha, 'Export does not match assembly')
        pack = Path(delivery['pck'])
        pack_sha = delivery['pck_sha256']
        require(sha(pack) == pack_sha, 'Pack changed')
    out.mkdir(parents=True)
    runtime_root = out if pack else game
    if pack:
        require(not any(out.iterdir()), 'Pack-only launch directory must start empty')
    command = [str(engine_path()), '--path', str(runtime_root)]
    if args.mode != 'gpu':
        command.append('--headless')
    if args.mode == 'import':
        command += ['--editor', '--import']
    else:
        frozen = out / qa_name
        shutil.copy2(HERE / qa_name, frozen)
        if args.suite == 'dashboard':
            shutil.copy2(HERE / 'dashboard_base34.gd', out / 'dashboard_base34.gd')
        if pack:
            command += ['--main-pack', str(pack)]
        command += ['--resolution', '1280x720', '--script', str(frozen), '--', '--run-id=.']
    require(not pack or not any((out / n).exists() for n in ('project.godot','scripts','scenes','data','audio','assets','.godot')), 'Loose runtime resources must not accompany packed QA')
    record = {'assembly_sha256': assembly_sha, 'qa_sha256': qa_sha, 'mode': args.mode, 'suite': args.suite,
              'command': command, 'inventory_before': before, 'source_count': len(m['source_pins']),
              'pck_sha256': pack_sha, 'pack_only_root': str(runtime_root) if pack else None,
              'performance_accepted': False, 'full_city_performance_accepted': False}
    started = time.monotonic()
    with (out / 'engine.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=out, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        record['own_engine_pid'] = process.pid
        write(out / 'STARTED.json', record)
        try:
            code = process.wait(timeout=150)
        except subprocess.TimeoutExpired:
            record['timeout'] = True
            process.kill()  # Only this newly created child; never the user's game.
            code = process.wait(timeout=10)
    record['exit_code'] = code
    record['seconds'] = time.monotonic() - started
    record['inventory_after'] = inventory()
    record['source_changed'] = [n for n, pin in m['source_pins'].items() if not (game / n).is_file() or sha(game / n) != pin]
    record['assembly_unchanged'] = sha(ASSEMBLY) == assembly_sha
    record['pack_unchanged'] = pack is None or sha(pack) == pack_sha
    record['qa_unchanged'] = sha(HERE / qa_name) == qa_sha and (args.mode == 'import' or sha(out / qa_name) == qa_sha)
    if args.suite == 'dashboard':
        record['dashboard_base_unchanged'] = sha(HERE / 'dashboard_base34.gd') == sha(out / 'dashboard_base34.gd') == qa_receipt['dashboard_base_sha256']
        record['qa_unchanged'] = record['qa_unchanged'] and record['dashboard_base_unchanged']
    record['no_loose_runtime_resources'] = not pack or not any((out / n).exists() for n in ('project.godot','scripts','scenes','data','audio','assets'))
    log = (out / 'engine.log').read_text(encoding='utf-8', errors='replace')
    record['native_errors'] = [line for line in log.splitlines() if any(t in line for t in ('SCRIPT ERROR', 'ERROR:', 'Parse Error'))]
    result = read(out / 'RESULT.json') if (out / 'RESULT.json').exists() else {}
    record['result_checks'] = result.get('checks', 0)
    record['result_failures'] = result.get('failures')
    threshold = 33 if args.suite == 'rear' else 105
    if args.suite == 'dashboard':
        threshold = qa_receipt['dashboard_gpu_min_checks' if args.mode == 'gpu' else 'dashboard_native_min_checks']
    record['minimum_required_checks'] = threshold
    # The unchanged accepted rear fixture records no embedded script hash;
    # both its source and its frozen launched bytes are pinned above instead.
    hash_matches = args.suite == 'rear' or result.get('test_sha256') == qa_sha
    record['native_physical_space_proven'] = args.suite != 'dashboard' or result.get('report', {}).get('physical_space_supported') is True
    functional = args.mode == 'import' or (result.get('failures') == [] and result.get('checks', 0) >= threshold and
                  result.get('gpu') is (args.mode == 'gpu') and hash_matches and record['native_physical_space_proven'])
    record['passed'] = code == 0 and not record.get('timeout') and not record['native_errors'] and not record['source_changed'] and record['assembly_unchanged'] and record['pack_unchanged'] and record['qa_unchanged'] and record['no_loose_runtime_resources'] and functional
    if args.mode == 'gpu':
        try:
            require_gpu_free(record['inventory_after'])
        except RuntimeError:
            record['passed'] = False
            record['exclusive_inventory_endpoints'] = False
        else:
            record['exclusive_inventory_endpoints'] = True
        record['visual_and_cost_review'] = 'Root must inspect PNGs, cold first-metal impact, paired cadence/memory and full glass/audio lifetime; PASS is functional only.'
    write(out / 'RUN.json', record)
    print(json.dumps({k: record[k] for k in ('passed', 'mode', 'exit_code', 'result_checks', 'native_errors', 'source_changed')}))
    raise SystemExit(0 if record['passed'] else 1)


if __name__ == '__main__':
    main()
