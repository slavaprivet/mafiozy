import pathlib,sys,json
OUT=pathlib.Path(__file__).resolve().parent; ROOT=OUT.parents[1]; GAME=OUT/'game'
sys.path.insert(0,str(ROOT))
from tools.godot.test_scheduler import Lease
with Lease(mode='headless',project=GAME,access='write',wait_seconds=30):
    path=GAME/'scripts/main.gd';text=path.read_text(encoding='utf-8')
    old='const PREVIEW_RUNTIME_REVISION := "s01-20261003-c4-release48"'
    assert text.count(old)==1
    path.write_text(text.replace(old,'const PREVIEW_RUNTIME_REVISION := "s01-20261015-residents53a"'),encoding='utf-8')
    path=GAME/'scripts/npc_visual/preview_resident_host.gd';text=path.read_text(encoding='utf-8')
    old='\tlabel.name = "DshResidentName"\n'
    assert text.count(old)==1
    text=text.replace(old,old+'\t# The live health owner will reveal the shared focus card after binding.\n\tif OS.get_cmdline_user_args().has("--city-simple-hospital=1"): label.visible = false\n')
    path.write_text(text,encoding='utf-8')
    notes={'title':'15.10 · Жители и заведения · версия53a','runtime_revision':'s01-20261015-residents53a','items':[
        'Подойди к жителю и наведи камеру: он остановится и повернётся к тебе. Отведи взгляд — продолжит тот же путь. Во время тревоги он не отвлекается.',
        'Карточка жителя показывает здоровье. При покупке рядом с головой всплывает красная сумма траты.',
        'Житель гуляет, отдыхает и выбирает занятия. При нехватке сил идёт поесть; при здоровье ниже половины — в больницу.',
        'Добавлены 8 небольших заведений: больницы, банки, рестораны и магазины. Посетители выбирают ближайшие доступные места.',
        'Сохранены оружие, автомобили и разрушения. Q — выбор оружия; E — дверь или взаимодействие.'
    ]}
    (GAME/'data/preview_updates.json').write_text(json.dumps(notes,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Play53 revision/news and startup label staged.')
