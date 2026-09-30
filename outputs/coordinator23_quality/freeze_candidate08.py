from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
stage = root / 'outputs/coordinator23_quality/candidate08'
project = stage / 'godot/mafiozi_walk'
manifest_path = stage / 'INTEGRATION.json'
manifest = json.loads(manifest_path.read_text(encoding='utf8'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
main = project / 'scripts/main.gd'
assert sha(main) == manifest['changes']['scripts/main.gd']['after']
text = main.read_text(encoding='utf8')
assert text.count('const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality23e"') == 1
assert text.count('@export var preview_final_dead_contact_enabled: bool = false') == 1
text = text.replace('const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality23e"', 'const PREVIEW_RUNTIME_REVISION := "s01-20260930-quality23f"')
text = text.replace('@export var preview_final_dead_contact_enabled: bool = false', '@export var preview_final_dead_contact_enabled: bool = true')
text = text.replace('# Native contact proposal119; rendered acceptance pending.', '# Bounded per-contact limits; original masses and joint constraints preserved.')
main.write_text(text, encoding='utf8', newline='\n')
notes = project / 'data/preview_updates.json'
before = sha(notes)
value = {
    'title': '30.09 · Попадания и физика тел · 23f',
    'items': [
        'Q — арсенал, 14 видов оружия. ЛКМ — выстрел, ПКМ — прицел с приближением, R — перезарядка.',
        'Попадания оставляют следы на одежде и коже. Кровь заметнее; стоящего жителя больше не сдвигает искусственным шагом.',
        'Попадание в голову смертельно. Падение получает импульс по направлению пули; лежащее тело можно сдвинуть шагом.',
        'У открытого багажника G — положить, E по модели — взять. Вдали G — бросить, E рядом — подобрать. Патроны сохраняются.',
        'Сейчас доступны три жителя тестового квартала. РПГ пока без урона взрывом. C/Z — присесть/лечь; Esc — мышь.'
    ],
    'updated_at': '2026-09-30T11:45:00+03:00',
    'runtime_revision': 's01-20260930-quality23f'
}
notes.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
manifest['changes']['scripts/main.gd']['after'] = sha(main)
manifest['changes']['data/preview_updates.json'] = {'before': before, 'after': sha(notes), 'source': 'paired exact runtime revision and available actions; pending acceptance'}
manifest['runtime_revision'] = value['runtime_revision']
manifest['status'] = 'ISOLATED acceptance candidate; combined features enabled here only; NOT delivered'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('23f acceptance stage frozen; shared source and visible game unchanged')
