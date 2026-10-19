"""Generate reviewable58 tools from preserved57 helpers; CPU only, never run them."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE.parent / 'services31_resume/release_tools'


def main():
    base = (OLD / 'freeze57.py').read_text(encoding='utf-8')
    # Only pure helpers/validators, never copy the old release mutation workflow.
    helpers = base[:base.index('\ndef main():')]
    helpers = helpers.replace('ROOT = HERE.parents[4]', 'ROOT = HERE.parents[3]')
    helpers = helpers.replace('coordinator30_release56', 'coordinator31_release57')
    helpers = helpers.replace('RELEASE = ROOT / "outputs/coordinator31_release57"',
                              'RELEASE = ROOT / "outputs/coordinator31_release58"')
    helpers = helpers.replace('s01-20261015-residents57', 's01-20261015-residents58')
    helpers = helpers.replace('TITLE = "15.10 · Проходы и реакции жителей · версия57"',
                              'TITLE = "15.10 · Свободный проход жителей · версия58"')
    helpers = helpers.replace('"""Validate final receipts; --go freezes release57. Never activates F5 or runs Godot/Git."""',
                              '"""Preserved57 pure validation helpers, adapted to58. No executable main."""')
    start = helpers.index('    if role in ("perf_baseline", "perf_candidate"):\n', helpers.index('def validate_receipt'))
    end = helpers.index('    need(command.count("--script")', start)
    helpers = helpers[:start] + helpers[end:]
    # No execution of mutable current comparison code. Replaced by the pinned58 adapter.
    start = helpers.index('    compare_module = module(')
    end = helpers.index('    base = compare_module.summarize(', start)
    helpers = helpers[:start] + '    compare_module = PERF_CHECKER\n' + helpers[end:]
    (HERE / 'validators58.py').write_text(helpers, encoding='utf-8')
    startup = (OLD / 'startup57.py').read_text(encoding='utf-8').replace('57', '58')
    startup = startup.replace('from freeze58 import ROOT, HERE, RELEASE, REVISION, TITLE, SCHEDULER_SHA',
                              'from validators58 import ROOT, HERE, RELEASE, REVISION, TITLE, SCHEDULER_SHA')
    startup = startup.replace('from freeze58 import need, read, sha, save, pins, inside, city_flags, all_pins, unchanged',
                              'from validators58 import need, read, sha, save, pins, inside, city_flags, all_pins, unchanged')
    startup = startup.replace('Path(__file__), HERE / "freeze58.py"]',
                              'Path(__file__), HERE / "freeze58.py", HERE / "validators58.py", HERE / "activate58.py",\n                            release / "PREVIOUS_CURRENT.json"]')
    startup = startup.replace('child.wait(timeout=10)',
                              'try:\n                            child.wait(timeout=10)\n                        except subprocess.TimeoutExpired:\n                            child.kill()\n                            child.wait(timeout=5)')
    startup = startup.replace('    need(assembly.get("performance_accepted")',
                              '    need(acceptance.get("status") == "BATCH10_VERIFIED_PENDING_ORDINARY_START", "Release58 is not accepted for startup")\n    need(acceptance.get("spatial_liveness_accepted") is True, "Required58 spatial gate missing")\n    need(assembly.get("performance_accepted")')
    (HERE / 'startup58.py').write_text(startup, encoding='utf-8')
    sources = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
               for p in (OLD / 'freeze57.py', OLD / 'startup57.py')}
    (HERE / 'TEMPLATE_ORIGINS.json').write_text(json.dumps({'generated_only': True,
        'engine_launched': False, 'freeze_executed': False, 'original_templates': sources},
        indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
