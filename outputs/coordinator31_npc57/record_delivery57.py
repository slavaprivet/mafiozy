"""Record the verified persistent release57 launch and current coordinator state."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RELEASE = ROOT / 'outputs/coordinator31_release57'
STARTUP = HERE / 'proposals/services31_resume/release_tools/runs/startup57_01'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    pointer = read(ROOT / 'godot/current_version.json')
    opened = read(ROOT / 'outputs/current_game/OPENED.json')
    assert pointer == read(RELEASE / 'PROPOSED_CURRENT.json')
    assert opened['revision'] == pointer['revision'] == 's01-20261015-residents57'
    assert opened['ready'] is True and opened['window_handle'] != 0
    assert opened['assembly_sha256'] == pointer['assembly_sha256'] == sha(RELEASE / 'ASSEMBLY.json')
    ordinary = Path(opened['run_directory'])
    assert ordinary.is_relative_to(ROOT / 'outputs/current_game/interactive')
    ready = read(ordinary / 'CURRENT_READY.json')
    assert ready['ok'] is True and ready['revision'] == pointer['revision']
    assert ready['resident_count'] == 10 and ready['staff_count'] == 12
    assert read(STARTUP / 'RUN.json')['ordinary_ready'] is True
    assert (ordinary / 'play.err').stat().st_size == 0
    assert not (RELEASE / 'DELIVERY.json').exists()
    now = datetime.now(timezone.utc).isoformat()
    evidence = RELEASE / 'DELIVERY_EVIDENCE.zip'
    members = {f'startup57/{p.name}': p for p in STARTUP.iterdir() if p.is_file()}
    for name in ('OPENED.json', 'CURRENT_READY.json', 'RELEASE.json', 'STARTED.json'):
        members[f'ordinary57/{name}'] = ordinary / name
    members['ACTIVATION57.json'] = HERE / 'ACTIVATION57.json'
    for name in ('PERF_FOUR_RUNS31.json', 'PERF_FOUR_RUNS31.md'):
        members[name] = HERE / 'proposals/qa31_resume' / name
    with zipfile.ZipFile(evidence, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, path in sorted(members.items()):
            archive.writestr(name, path.read_bytes())
    with zipfile.ZipFile(evidence) as archive:
        assert archive.testzip() is None
        assert all(hashlib.sha256(archive.read(name)).hexdigest() == sha(path) for name, path in members.items())
    delivery = {
        'ordinary_ready': True, 'revision': pointer['revision'], 'resident_count': 10,
        'staff_count': 12, 'window_pid_at_delivery': opened['pid'],
        'assembly_sha256': pointer['assembly_sha256'],
        'ordinary_run': ordinary.relative_to(ROOT).as_posix(), 'recorded_at': now,
        'mean_fps': 105.19616852177317, 'p95_ms': 16.036, 'p99_ms': 18.094,
        'measurement_seconds': 90, 'render_size': [1920, 1080],
        'reverse_order_candidate_mean_fps': 112.46385,
        'reverse_order_baseline_mean_fps': 107.4985,
        'reverse_order_baseline_passed': False,
        'reverse_order_baseline_failure': 'False exterior entered state caused required-motion inactivity25.147s',
        'fps_complaint_fully_resolved': False,
        'performance_scope': 'Finite batch10+12; primary matched pair passed all12 existing gates. Reverse candidate passed, reverse baseline failed liveness. Stable8% regression was not reproduced; no claim of speedup or all-scenario FPS resolution.',
        'all_ten_moved': True, 'services_pass': True, 'threat_pass': True,
        'passage_six_opposing_native_pass': True,
        'soak_seconds': 600, 'soak_purchases': 51, 'soak_walks': 271,
        'soak_max_motion_idle_seconds': 4.029, 'soak_max_queue_seconds': 9.011,
        'soak_exit_blocked_count': 0,
        'next_batch': 20, 'next_batch_activated': False,
        'full_city_performance_accepted': False,
        'building_policy': 'Current ordinary buildings temporarily allowed for testing; future permanent buildings only destructible like Palazzo',
        'delivery_evidence': 'DELIVERY_EVIDENCE.zip', 'delivery_evidence_sha256': sha(evidence),
        'publication': 'Scoped main commit and push follows this record; exact verified remote SHA in outputs/coordinator31_npc57/checkpoint57/RESULT.json',
    }
    write(RELEASE / 'DELIVERY.json', delivery)
    current_path = ROOT / 'docs/ai/CURRENT_COORDINATOR.json'
    current = read(current_path)
    assert current['thread_id'] == '01a13f85-fd0d-73f0-b5f9-79fc5b24f890'
    current.update(updated_at=now, accepted_revision=pointer['revision'],
                   accepted_assembly=pointer['assembly'], accepted_assembly_sha256=pointer['assembly_sha256'],
                   accepted_delivery='outputs/coordinator31_release57/DELIVERY.json',
                   current_candidate_status='BATCH10_RELEASE57_DELIVERED; FPS_COMPLAINT_NOT_FULLY_RESOLVED; BATCH20_NOT_ACTIVATED',
                   current_play_revision=pointer['revision'], current_play_assembly=pointer['assembly'],
                   last_inventory_note=f"Persistent57 ready PID{opened['pid']} at{now}; preserve user game. PID historical, always refresh inventory.",
                   publication_receipt='outputs/coordinator31_npc57/checkpoint57/RESULT.json',
                   fps_complaint_fully_resolved=False)
    write(current_path, current)
    agents_path = ROOT / 'AGENTS.md'
    agents = agents_path.read_text(encoding='utf-8-sig')
    heading = '# Координация проекта\n\n'
    assert agents.startswith(heading)
    section = """## Версия57 доставлена — действующий Координатор31, 15 октября 2026

Root31 `01a13f85-fd0d-73f0-b5f9-79fc5b24f890` подхватил прежнего31 и всех3 агентов.
F5/current_version теперь `outputs/coordinator31_release57/ASSEMBLY.json`;
обычная57 открыта:10 жителей +12 сотрудников. Сохранять пользовательское окно.
Исправлены проход встречных NPC в узких входах, ложный entered снаружи магазина,
очередь выхода, поворот к угрозе и postpanicIDLE из-за дрейфа масштаба при поворотах.
Финальные600сек:10/10 двигались,51покупка/271прогулка,exit_blocked0;
все4 услуги/физические входы-выходы и реакции/возврат к занятиям прошли.
Сопоставимые90сек/1920x1080:105.20FPS,p95 16.036мс; повтор112.46FPS.
Устойчивые-8% не подтвердились; обратный baseline56 сам повторил остановку25.15с.
FPS-жалобу полностью решённой НЕ считать; пока остаёмся10,20 не активирована.
Каталог287 сохранён. Следующие+10 только после отдельной проверки поведения/FPS.
Приёмка/доставка в release57; Git/SHA в coordinator31_npc57/checkpoint57/RESULT.json.
Frozen57/56 и старые пакеты не менять; candidate остаётся coordinator31_npc57/game.
Перед30+ исправить лимит32 акторов в одной зоне прохода (MERGED_AUDIT.md).
Чужие shop/WIP сохранять, scoped Git; старых владельцев не будить; godot-4 PAUSED.
Нижние записи описывают историю, включая прежнюю актуальность56 и ожидание проверок.

"""
    agents_path.write_text(heading + section + agents[len(heading):], encoding='utf-8')
    memory_path = ROOT / 'docs/ai/COORDINATOR_31_MEMORY.md'
    memory = memory_path.read_text(encoding='utf-8-sig')
    first, rest = memory.split('\n', 1)
    memory_section = f"""

## Итог доставки57 — {now}

Обычная57 READY, F5 проверена и активирована; PID{opened['pid']} исторический,
окно сохранять. ASSEMBLY SHA `{pointer['assembly_sha256']}`. Доказательства
`outputs/coordinator31_release57/ACCEPTANCE.json`, `DELIVERY.json`,
`EVIDENCE.zip`, `DELIVERY_EVIDENCE.zip` (startup, обычный запуск, 4прогонаFPS).
Freeze/startup PASS,1130pins,7поведенческих файлов; release меняет только revision/news.
Reverse04: candidate112.46385FPS PASS; baseline107.4985FPS FAIL liveness25.147с,
причина false entered вне bounds у магазина. Обратную пару целикомPASS не объявлять.
Стабильные-8% не воспроизвелись. Primary03 все12gatesPASS:105.1962FPS,p9516.036мс,
90сек/1920x1080; original56 при1280x720 несопоставима. Финальные функциональные
проверки PASS:600сек/51покупка/271прогулка/exit_blocked0;37services; threat/visual;
6встречныхNPC. FPSжалоба полностью не закрыта,10сохранены,20ещё не включена.
Увеличение после отдельной проверки; перед30+ исправить overflow32 в passage.
Root публикует scoped main/GitHub; точный подтверждённыйSHA и сохранность чужого
индекса в `outputs/coordinator31_npc57/checkpoint57/RESULT.json`.
Следующие разделы — хронология; временный HOLD/reverse pending ниже уже снят
для исправлений10, но не означает принятие производительности всего города.
"""
    memory_path.write_text(first + memory_section + rest, encoding='utf-8')
    print(json.dumps({'delivered': True, 'revision': pointer['revision'], 'pid': opened['pid'],
                      'evidence_sha256': sha(evidence)}, ensure_ascii=True))
