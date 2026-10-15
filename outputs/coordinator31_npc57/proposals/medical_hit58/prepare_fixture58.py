from pathlib import Path
HERE=Path(__file__).resolve().parent
source=HERE.parent/'attention31_resume/regression/injury30'
for old,new in [('observer_death28.gd','observer_hit_base58.gd'),('observer_injury30.gd','observer_injury_base58.gd')]:
    text=(source/old).read_text(encoding='utf-8-sig').replace('extends "observer_death28.gd"','extends "observer_hit_base58.gd"')
    target=HERE/new;assert not target.exists();target.write_text(text,encoding='utf-8')
