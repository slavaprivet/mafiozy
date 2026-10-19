from pathlib import Path
HERE=Path(__file__).resolve().parent
CASES={'modules':('test_player_shop.gd','run'),'defaults':('test_player_shop_defaults.gd','run'),'ui':('test_player_shop_ui.gd','run'),'city':('test_shop_city57.gd','_run'),'pose':('test_player_pose57.gd','_run')}
for case,(file,method) in CASES.items():
    target=HERE/('entry_'+case+'58.gd')
    assert not target.exists()
    target.write_text('extends "res://scripts/shop/tests/'+file+'"\nfunc _initialize() -> void:\n\t_delayed58.call_deferred()\nfunc _delayed58() -> void:\n\tawait create_timer(3.0).timeout\n\t'+method+'()\n',encoding='utf-8')
