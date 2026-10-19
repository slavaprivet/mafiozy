import pathlib,json,sys
OUT=pathlib.Path(__file__).resolve().parent;ROOT=OUT.parents[1];GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
revision='s01-20261015-residents54'
title='15.10 · Житель, персонал и маршруты · версия54'
with Lease(mode='headless',project=GAME,access='write',wait_seconds=60):
    path=GAME/'scripts/main.gd';source=path.read_text(encoding='utf-8')
    old='const PREVIEW_RUNTIME_REVISION := "s01-20261015-residents53a"'
    new='const PREVIEW_RUNTIME_REVISION := "'+revision+'"'
    assert source.count(old)==1
    path.write_text(source.replace(old,new),encoding='utf-8')
    news={'title':title,'runtime_revision':revision,'items':[
      'Раненый житель не отвлекается на взгляд: при здоровье ниже половины идёт лечиться.',
      'В заведениях работают медики и кассиры. Житель подходит к сотруднику; остальные ждут своей очереди.',
      'На прогулке — 18 случайных занятий, включая телефон. Исправлены руки и посадка на лавочку.',
      'Близкий взгляд останавливает здорового жителя; отведи камеру — он продолжит путь. В тревоге остановки нет.',
      'Красные цифры рядом с головой показывают реальные траты. При нехватке денег житель сначала идёт в банк.',
      'Q — оружие; E — дверь. В сцене один житель и 12 сотрудников.'
    ]}
    (GAME/'data/preview_updates.json').write_text(json.dumps(news,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Candidate54 revision/news prepared; delivery remains gated by final checks.')
