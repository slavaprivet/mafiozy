import pathlib, shutil
OUT=pathlib.Path(__file__).resolve().parent
ROOT=OUT.parents[1]
UP=ROOT/'outputs/coordinator29_npc53'
(OUT/'qa').mkdir(exist_ok=True)
for source in (UP/'qa').glob('*.gd'):
    dest=OUT/'qa'/source.name
    if not dest.exists(): shutil.copy2(source,dest)
runner=(UP/'run.py').read_text(encoding='utf-8')
runner=runner.replace("'--city-hospital-marker=0',", "'--city-hospital-marker=0', '--city-venue-sites29=1', '--city-venue-staff29=1',")
assert 'venue-staff29' in runner
dest=OUT/'run30.py'
assert not dest.exists()
dest.write_text(runner,encoding='utf-8')
print('Prepared new QA entrypoints and scheduler runner; old QA unchanged.')
