from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
for relative, marker in [
    ('proposals/qa31_resume/runs/merged600_02/stdout.log', 'SOAK31_LIVE '),
    ('proposals/services_regression31/runs/merged_graphical02/stdout.log', 'SERVICES56_PROGRESS '),
]:
    path = HERE / relative
    if not path.is_file():
        continue
    rows = [line[len(marker):] for line in path.read_text(encoding='utf-8', errors='replace').splitlines() if line.startswith(marker)]
    if not rows:
        continue
    latest = json.loads(rows[-1])
    if marker.startswith('SERVICES'):
        latest = {'elapsed_s': latest.get('elapsed_s'), 'selected': {
            name: {key: row.get(key) for key in ('source_id', 'completed', 'phase', 'route_phase', 'travel_m', 'hp', 'cash')}
            for name, row in latest.get('selected', {}).items()}}
    print(json.dumps({'run': str(path.parent.relative_to(HERE)), 'latest': latest}, ensure_ascii=False))
