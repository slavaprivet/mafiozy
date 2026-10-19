from pathlib import Path
H=Path(__file__).resolve().parent
out=H/'run_shop_components58.py'
assert not out.exists()
s=(H/'run_native58.py').read_text(encoding='utf-8')
s=s.replace("choices=['startup','clock'],default='startup'", "choices=['player_pose','shop_city'],required=True")
s=s.replace("controls=[manifest,scheduler,lock,ROOT/'godot/current_version.json',Path(__file__),HERE/'entry_native58.gd']", "entry=GAME/'scripts/shop/tests'/('test_player_pose57.gd' if a.case=='player_pose' else 'test_shop_city57.gd')\n    controls=[manifest,scheduler,lock,ROOT/'godot/current_version.json',Path(__file__),entry]")
s=s.replace("str(HERE/'entry_native58.gd')", "str(entry)")
s=s.replace("'--qa-out='+str(run),'--qa-case='+a.case", "'--qa-out='+str(run)")
s=s.replace("'Short ordinary READY/clock coverage, not full behavior or performance acceptance'", "'Existing author component: C/Ctrl/Z routed key input; jump/dive direct request; fire through weapon port. Shop modal and projectile launch direct calls. Not actual E/entry or complete native throw-input acceptance.'")
s=s.replace("native=read(run/'NATIVE58.json') if (run/'NATIVE58.json').exists() else {};result['native_passed']=native.get('passed',False)", "native={}\n            if a.case=='shop_city' and (run/'SHOP_CITY57.json').exists():native=read(run/'SHOP_CITY57.json')\n            elif a.case=='player_pose':\n                reports=[line.removeprefix('PLAYER_POSE57 ') for line in (run/'stdout.log').read_text(encoding='utf-8-sig',errors='replace').splitlines() if line.startswith('PLAYER_POSE57 ')]\n                if len(reports)==1:native=json.loads(reports[0]);save(run/'PLAYER_POSE57.json',native)\n            result['native_passed']=native.get('ok',False);result['native_checks']=native.get('checks');result['native_failures']=native.get('failures')")
s=s.replace("native.get('passed') is True", "native.get('ok') is True")
out.write_text(s,encoding='utf-8')
