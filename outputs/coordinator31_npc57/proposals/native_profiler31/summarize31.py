"""Summarize engine profiler attribution without calling it a clean FPS test."""
import json,pathlib,statistics,hashlib
HERE=pathlib.Path(__file__).resolve().parent
run=HERE/'runs/city_headless04'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
profile=read(run/'PROFILE.json');native=read(run/'NATIVE.json');receipt=read(run/'RESULT.json')
assert receipt['passed'] and not any(receipt[k] for k in ['source_drift','harness_drift','control_drift','errors'])
rows=[r for r in profile['all_functions'] if r['signature'].startswith('res://') and r['calls']>0]
top=sorted(rows,key=lambda r:r['self_s'],reverse=True)[:20]
for row in top:row['profiled_self_us_per_call']=row['self_s']*1e6/row['calls']
samples=native['samples'];monitors={}
for key in samples[0]:
    if key in ['elapsed_s','physics_frame']:continue
    values=[s[key] for s in samples if key in s]
    monitors[key]={'median':statistics.median(values),'min':min(values),'max':max(values),'first':values[0],'last':values[-1]}
report={'schema':'mafiozi.native-profiler31.summary/v1','native_passed':True,
 'engine':'Godot4.7.2 official locked binary','builtin':'LocalDebugger ScriptsProfiler via --debug --profiling / EngineDebugger.profiler_enable',
 'measurement_before_final_dump_s':samples[-1]['elapsed_s'],'physics_ticks':samples[-1]['physics_frame']-samples[0]['physics_frame'],
 'residents':native['residents'],'staff':native['staff'],'moved_residents':sum(v>1 for v in native['moved_from_start_m'].values()),
 'top_production_self':top,'monitors_raw_units':monitors,
 'limitations':['Headless concurrent with the preserved user game; not comparable FPS or GPU acceptance.',
 'Script profiler prints large frame/accumulated dumps. Observer reset/dump is the largest artificial self-time entry and is excluded from production ranking.',
 'Debug warnings and instrumentation overhead are present. Function timings are diagnostic attribution, not release speed guarantees.',
 'Inclusive totals overlap and must not be summed. C++ engine work is not fully attributed by script function self-time.',
 'End dump took about3.85s after the60s window; only sample timestamps define measurement duration.'],
 'evidence_sha256':{name:hashlib.sha256((run/name).read_bytes()).hexdigest() for name in ['RESULT.json','NATIVE.json','PROFILE.json','stdout.log','stderr.log','SOURCE.json','SOURCE_AFTER.json']}}
(HERE/'SUMMARY31.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# Встроенный профайлер Godot — настоящий запуск31','','Native ScriptProfiler включён в неизменной57:10 жителей+12 сотрудников,30с прогрева,60с наблюдения. Все10 покинули исходные позиции. Ошибок движка и изменения исходников/F5 нет.','',
'Самые дорогие собственные участки в этом диагностическом запуске:','','| Участок | Собственное время, с | Вызовов | мкс/вызов с профилированием |','|---|---:|---:|---:|']
for r in top[:10]:lines.append(f"| `{r['signature']}` | {r['self_s']:.3f} | {r['calls']} | {r['profiled_self_us_per_call']:.2f} |")
lines += ['','Основные кандидаты для дальнейшего измеренного упрощения: каждый физический кадр12 сотрудников; полное движение/проверки опоры жителей; многократный сбор списка обитателей для разных дверей; обновление стекла. Сам поиск пути через NavigationServer в этом окне занимает мало времени. Ничего из этого не отключено ради цифр.','',
'Это диагностический headless запуск с включённым профайлером и открытой пользовательской игрой. Он не измеряет чистый FPS/GPU. Печать результатов и сброс профайлера сами дороги; время observer исключено из списка, а измерение заканчивается до финальной печати. Inclusive total нельзя складывать.','',
'Документация: https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html ; https://docs.godotengine.org/en/stable/classes/class_enginedebugger.html .','',
'Полный журнал,4408 зарегистрированных функций (включая не вызванные), предупреждения debug и исходные pins находятся в `runs/city_headless04`. Неудачные попытки01–03 сохранены отдельно: отсутствующий необязательный файл, отсутствие --debug и преждевременная остановка по предупреждениям.']
(HERE/'SUMMARY31.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'profiled_seconds':report['measurement_before_final_dump_s'],'physics_ticks':report['physics_ticks'],'top_production':top[:5],'navigation':monitors.get('TIME_NAVIGATION_PROCESS')}))
