from pathlib import Path
HERE=Path(__file__).resolve().parent
runner=(HERE.parent/'player_shop58_qa/run_shop58.py').read_text(encoding='utf-8')
start=runner.index('CASES=');end=runner.index('\nsha=',start)
runner=runner[:start]+"CASES={'baseline':('player_shop_host.gd','headless',180),'overlay':('player_shop_host.gd','headless',180)}"+runner[end:]
runner=runner.replace("entry=HERE/('entry_'+args.case+'58.gd')","entry=HERE/'entry_guard58.gd'")
runner=runner.replace("native_test=GAME/'scripts/shop/tests'/fixture","native_test=GAME/'scripts/shop'/fixture")
runner=runner.replace("HERE/'prepare_wrappers58.py'","HERE/'prepare_runner58.py',HERE/'prepare_guard58.py',HERE/'PATCH.json',HERE/'patch/scripts/shop/player_shop_host.gd'")
runner=runner.replace("cp={str(p):sha(p) for p in controls}","patch=read(HERE/'PATCH.json')['scripts/shop/player_shop_host.gd']\nassert sha(native_test)==patch['base_sha256']\nassert sha(HERE/'patch/scripts/shop/player_shop_host.gd')==patch['candidate_sha256']\ncp={str(p):sha(p) for p in controls}")
runner=runner.replace("'--qa-out='+str(run),*flags]","'--qa-out='+str(run),*(['--guard-overlay=1'] if args.case=='overlay' else []),*flags]")
start=runner.index('native={}');end=runner.index('engine_clean=',start)
runner=runner[:start]+"native=read(run/'GUARD58.json') if (run/'GUARD58.json').exists() else {}\n"+runner[end:]
runner=runner.replace(" and native.get('failures')==[]", " and native.get('checks') and all(native['checks'].values())")
runner=runner.replace("'original_fixture_unchanged':True", "'overlay_only':args.case=='overlay'")
runner=runner.replace('Existing exact shop fixture with only delayed startup wrapper. City test calls live purchase/projectile ports; it does not prove physical walk-in/E, native mouse windup, NPC/home lifecycle, or performance.', 'Same-frame stale-cashier negative with actual city modal transaction and standalone sandbox positive; baseline and single-file overlay on exact source. No physical player entrance or FPS claim.')
target=HERE/'run_guard58.py';assert not target.exists();target.write_text(runner,encoding='utf-8')
