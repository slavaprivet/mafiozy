from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
GAME=HERE.parents[1]/'game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
save=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
paths=['scripts/destruction/palazzo/palazzo_structural_site.gd','scripts/destruction/palazzo/palazzo_finished_site.gd','scripts/destruction/palazzo/palazzo_live_site.gd','scripts/destruction/palazzo/palazzo_site.gd','scripts/destruction/palazzo/source/showcase.gd','scripts/destruction/palazzo/building_support.gd','scripts/venues/npc_compact_service_site29.gd','scripts/venues/npc_service_sites_host29.gd','scripts/city/runtime/npc_city_clone_door_swing.gd','scripts/destruction/palazzo/c4_building_blast.gd','scripts/destruction/palazzo/c4_equipment.gd']
report={
 'schema':'mafiozi.qa58.home-backend-review/v1','scope':'Independent source review and bounded native component observations; no production writes; not final sleep/routines/performance acceptance',
 'source_pins':{p:sha(GAME/p) for p in paths},
 'reviewed_housing_patch_sha256':'0c1c1f68c2a8a95c1436bb7e369c958a39f120ff65a2adf4dd7fcedbeec6b154',
 'reviewed_home_controller_patch_sha256':'2e39c030b28157b1bad15c0c42cf831c523d8bd4eff6b1aec4ad23db455810f6',
 'architecture_review':[
  'Reuse CompactService -> Structural -> Finished -> Live -> Site -> Showcase preserves owned RigidBody sections, support graph, native terrain, damage and reset. No copied full-Palazzo implementation.',
  'Compact _build_site supplies mandatory flash and uses prevalidated external terrain; no immovable OriginalFoundation/OriginalPlaza under the house.',
  'Home labels preserve intended floor/wall/roof sizes; generic Finished Floor/Facade/Side/Roof labels would force 2.002m widths.',
  'Beds use physical ground-touching base and separate physical mattress, not visual legs. Mattress top .82m; native actor docks at floor .24m, host alone composes skeletal bed pose.',
  'Normal C4 release changes detached/layer/freeze without incrementing rebuild_generation; current(slot) must check actual owned bed/support identities and physical shape pins, not generation alone.',
  'Root fixed enabled CollisionShape node/resource/frame/size checks; floor/roof use frame cache invalidated by release. Route geometry is separate from bed habitability so mattress loss does not bypass a live closed door.',
  'Inherited bind/reset reconstructs Swing and glazing. Old-generation bed/door weakrefs become invalid; reset publishes new slots only after real geometry returns.',
  'Main C4 provider includes all four homes. Damage bind/dispose reuses existing host lifecycle. Compact glazing capacity12 is required for8 venues+4homes.',
  'Home host now rejects missing beds after a native runtime failure; geometry is not accepted solely by counting house nodes.',
  'Home controller one-writer host pose, health precedence, current-frame metadata, exact life/body claims, death planner-only cancel and duplicate-before-merge passage hook passed scoped code review. Concurrent three-resident staging remains to be tested.'
 ],
 'runs':{},
 'remaining_native_cases':[
  'Exact merged source: 30 native seconds stability, record physics ticks and wall time independently.',
  'Actual C4: record any unfreezed mattress frame plus motion after authentic blast; eventual parked/frozen rubble is valid. No forged receipt.',
  'One original real resident walks from actual position through outside/door/inner to dock; supported pose committed >=8 frames; sleep requires exact current claim/support/pose.',
  'Three real assigned residents share one home concurrently, distinct bed claims; no NPC/NPC exclusive portal or staging stall.',
  'Wake and real physical exit for all four houses; no actor/capsule teleport to bed.',
  'Destroy bed/floor/roof during sleep, including clock T pause: next physics support check cancels sleep, claims/pose retire, safe physical exit retains real door/world/player collisions.',
  'Generation reset/new life cannot reuse old bed or stale pose/claim; hit/injury/death outrank sleeping.',
  'Invalid shape disabled/replaced/removed, invalid native ground, duplicate/missing assigned bed are rejected.',
  'Merged routine morning/lunch/evening/night, N/T, no repeated payments, late leisure target/rest, mandatory spatial liveness and matched performance.'
 ],
 'clock_contract_clarification':{'supersedes':'CLOCK_HOOK_REVIEW58.json optional forward-jump-day suggestion','manual_N':'selects hour on same day_index; does not mint a new purchase day','natural_advance':'midnight and full cycles increment shared day_index','T':'pauses clock only; native sleep support/health/threat physics continues'},
 'liveness':{'required_motion_max_s':10,'queue_max_s':30,'spatial_required_motion_window_s':30,'spatial_bbox_diagonal_m':1.5,'intentional_sleep_only':'live current claim+supported mattress+committed pose; HOME_BLOCKED remains failure eligible'},
}
for name in ['geometry01','geometry02','geometry_c4_03']:
 run=HERE/'runs'/name;native=read(run/'GEOMETRY58.json') if (run/'GEOMETRY58.json').exists() else {}
 failed=[c['name'] for c in native.get('checks',[]) if not c['ok']]
 report['runs'][name]={'run_sha256':sha(run/'RUN.json'),'native_sha256':sha(run/'GEOMETRY58.json') if native else None,'raw_passed':read(run/'RUN.json')['passed'],'native_failed_checks':failed,'native_ticks':native.get('native_ticks'),'native_wall_s':native.get('native_elapsed_s'),'raw_unchanged':True}
report['runs']['geometry01']['interpretation']='Real proposal error: typed ternary Array assignment aborted bed creation; host falsely reported ready with0beds. Both fixed by root.'
report['runs']['geometry02']['interpretation']='Structure/10bed/provider/global-ramp checks pass; QA wall-time gate expected1790ticks but saw1680. Next harness waits actual1800, no time scaling.'
report['runs']['geometry_c4_03']['interpretation']='All geometry,1800ticks,C4 actual item/remote,20released,bed4.396m,currentfalse,resetnew-generation pass. Only invalid QA final-freeze assertion failed after8s when valid rubble had parked. Preserve raw FAIL; next exact source test records any_unfrozen per tick.'
save(HERE/'HOME_BACKEND_REVIEW58.json',report)
print(json.dumps({'review_sha256':sha(HERE/'HOME_BACKEND_REVIEW58.json'),'status':'PRELIMINARY_NATIVE_COMPONENT_EVIDENCE; FINAL_HOME_CYCLE_PENDING'}))
