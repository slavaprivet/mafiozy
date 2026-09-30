"""Explicit isolated export using accepted pinned support; requires passing native34 receipt."""
import argparse
import shutil
from common34 import *


def pwsh_path():
    found = shutil.which('pwsh')
    require(found is not None and Path(found).is_file(), 'PowerShell7 pwsh executable required for export')
    return found


def process_snapshot():
    command = '[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $rows=@(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name,CreationDate); ConvertTo-Json -InputObject $rows -Compress'
    result = subprocess.run([pwsh_path(), '-NoProfile', '-NonInteractive', '-Command', command],
                            capture_output=True, encoding='utf-8-sig', timeout=20,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    require(result.returncode == 0, 'Cannot verify export process tree: ' + result.stderr)
    return json.loads(result.stdout)


def stop_owned_tree(process, original):
    # Keep the Popen handle open; PID + creation time + parent pin this launch.
    rows = process_snapshot()
    root = next((row for row in rows if row['ProcessId'] == process.pid), None)
    if process.poll() is not None:
        return {'already_exited': True, 'snapshot': rows}
    require(original is not None and root == original, 'Export root identity changed; refusing an unverified process stop')
    owned = [root]
    owned_ids = {process.pid}
    while True:
        children = [row for row in rows if row['ProcessId'] not in owned_ids and row['ParentProcessId'] in owned_ids]
        if not children:
            break
        owned.extend(children)
        owned_ids.update(row['ProcessId'] for row in children)
    # /T is rooted only at this verified, still-owned PowerShell child. No
    # process-name-wide stop and no existing peer/user game can be selected.
    result = subprocess.run(['taskkill.exe', '/PID', str(process.pid), '/T', '/F'],
                            capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
    require(result.returncode == 0 or process.poll() is not None, 'Own export tree did not stop')
    process.wait(timeout=10)
    after = process_snapshot()
    remaining = [row for row in after if row in owned]
    require(not remaining, 'Verified export children survived timeout cleanup: ' + str(remaining))
    return {'verified_root': original, 'parent_tree_snapshot': owned, 'taskkill_exit_code': result.returncode,
            'verified_survivors': remaining}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-run', required=True, type=Path)
    parser.add_argument('--dashboard-run', required=True, type=Path)
    args = parser.parse_args()
    m = load_assembly()
    assembly_sha = sha(ASSEMBLY)
    run_path = args.native_run.resolve()
    require(run_path.is_relative_to(HERE / 'runs'), 'Native receipt must belong to this isolated staging')
    native = read(run_path)
    require(native.get('passed') is True and native.get('mode') == 'native' and
            native.get('suite') == 'lamp' and native.get('result_checks', 0) >= 105 and
            native.get('assembly_sha256') == assembly_sha, 'Passing native34 receipt required')
    dashboard_path = args.dashboard_run.resolve()
    require(dashboard_path.is_relative_to(HERE / 'runs'), 'Dashboard receipt must belong to this isolated staging')
    dashboard = read(dashboard_path)
    qa = read(HERE / 'QA34.json')
    require(qa['assembly_sha256'] == assembly_sha and native.get('qa_sha256') == qa['qa_sha256'], 'Native lamp QA does not match current prepared fixture')
    require(dashboard.get('passed') is True and dashboard.get('mode') == 'native' and
            dashboard.get('suite') == 'dashboard' and dashboard.get('assembly_sha256') == assembly_sha and
            dashboard.get('qa_sha256') == qa['dashboard_qa_sha256'] and dashboard.get('native_physical_space_proven') is True and
            dashboard.get('result_checks', 0) >= qa['dashboard_native_min_checks'], 'Passing current native dashboard34 receipt required')
    candidate = Path(m['candidate_root'])
    for row in m['build_support']:
        require(sha(candidate / row['Rel']) == row['Sha'], 'Export helper changed')
    export = Path(m['game']) / 'exports/win64' / REVISION
    require(not export.exists() and not (HERE / 'DELIVERY34.json').exists(), 'Preserve previous export')
    command = [pwsh_path(), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
               str(candidate / 'tools/godot/export_preview.ps1'), '-Label', REVISION]
    export_run = {'command': command, 'assembly_sha256': assembly_sha, 'hard_timeout_seconds': 240}
    with (HERE / 'export34.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=candidate, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        original = next((row for row in process_snapshot() if row['ProcessId'] == process.pid), None)
        export_run.update(own_root_pid=process.pid, own_root_identity=original)
        write(HERE / 'EXPORT_RUN34.json', export_run)
        try:
            code = process.wait(timeout=240)
        except subprocess.TimeoutExpired:
            export_run['timeout'] = True
            try:
                export_run['owned_tree_stop'] = stop_owned_tree(process, original)
            finally:
                write(HERE / 'EXPORT_RUN34.json', export_run)
            raise RuntimeError('Export timed out; stopped only the verified launched process tree')
    export_run['exit_code'] = code
    write(HERE / 'EXPORT_RUN34.json', export_run)
    require(code == 0, 'Export failed; inspect export34.log')
    load_assembly()
    receipt_path = export / 'build_receipt.json'
    receipt = read(receipt_path)
    require(receipt['sourceInputsUnchangedDuringExport'] is True, 'Export inputs changed')
    for row in receipt['artifacts']:
        file = safe_child(export, row['filename'])
        require(sha(file) == row['sha256'] and file.stat().st_size == row['bytes'], 'Export artifact changed')
    pack, exe = export / 'MafioziPreview.pck', export / 'MafioziPreview.exe'
    write(HERE / 'DELIVERY34.json', {'status': 'EXPORTED_NATIVE_PASS_PACKED_AND_GPU_QA_PENDING',
          'revision': REVISION, 'assembly_sha256': assembly_sha, 'source_count': len(m['source_pins']),
          'native_run': str(run_path), 'native_run_sha256': sha(run_path), 'build_receipt': str(receipt_path),
          'dashboard_native_run': str(dashboard_path), 'dashboard_native_run_sha256': sha(dashboard_path),
          'build_receipt_sha256': sha(receipt_path), 'pck': str(pack), 'pck_sha256': sha(pack),
          'exe': str(exe), 'exe_sha256': sha(exe), 'export_script_sha256': sha(Path(__file__)),
          'raw_audio_exact_check': 'Required in run34.py --mode packed, reading all three res://audio/*.bytes',
          'shared_modified': False, 'game_opened': False, 'performance_accepted': False})


if __name__ == '__main__':
    main()
