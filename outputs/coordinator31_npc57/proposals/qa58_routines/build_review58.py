"""Read-only acceptance design for the upcoming shared-clock/home model."""
from pathlib import Path
import hashlib
import json

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
GAME=ROOT/'outputs/coordinator31_npc57/game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={name:sha(GAME/name) for name in [
 'scripts/quick_controls/day_night_clock.gd','scripts/quick_controls/quick_controls.gd',
 'scripts/quick_controls/scene_hook.gd','scripts/npc_daily_life.gd','scripts/npc_city_daily.gd',
 'scripts/npc_ambient/ambient_controller28.gd','scripts/npc_ambient/ambient_bench_registry29.gd',
 'scripts/city/runtime/npc_threat_life30.gd','scripts/city/runtime/npc_wait_cohort56.gd']}
def save(name,data):
    path=OUT/name
    assert not path.exists()
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

cases=[
 ('clock_single_owner','All ten read the same root clock while lighting changes.',
  'One clock identity; NPC reads never advance it; native physics delta and health/route/quiet timers remain real time.',
  'Clock identity/day/hour per sample plus native physics/frame timestamps.'),
 ('midnight_and_dawn','Cross23:59→00:00,05:59→06:00,17:59→18:00, and a whole5400s clock cycle.',
  'Day increases once at midnight, never merely at dawn; daylight rates300/150s per hour preserved; full cycles not discarded.',
  'Bounded pure native clock checks, explicitly separate from physical passage acceptance.'),
 ('n_jump_and_t_pause','Use actual N day/night transition, repeat N during transition, and cancel transition with T.',
  'No repeated day increments after crossing24; no catch-up burst of missed purchases. T pauses schedule time only; real support/threat/death checks continue.',
  'Native input path or actual control method; frame-by-frame day/hour, tickets and receipts.'),
 ('ten_distinct_schedules','Observe morning, lunch, evening and sleep windows for all ten stable source IDs.',
  'Individual meal/shop/wake/sleep times and late schedules are present. No all-ten departure caused by a single shared threshold; no old random wander fallback.',
  'Per-ID schedule table, chosen need/reason, departures, arrivals and rests.'),
 ('one_to_three_per_home','Assign all ten original residents to real shared homes.',
  'Each home has1–3 residents, enough distinct physical beds, valid destructible building identity; one current owner per bed; no unassigned ID or duplicate bed claim.',
  'Home/body/bed paths, assignments and exact generation-bound lease inventory.'),
 ('home_physical_cycle','Resident travels home, enters through door, approaches assigned bed, sleeps, wakes and exits.',
  'Native movement throughout entry/exit; sleep starts only after real arrival/support and pose ownership. World/floor/door/player collision contract retained.',
  'Positions, phases, cached contacts, actual door fractions, native ticks and pose-commit proof.'),
 ('need_then_rest','Hunger, planned meal/shop and low funds select a real venue; rest follows completed activity.',
  'Actual bank/service transaction precedes routine completion; energy restores only through existing authenticated receipt path. Failed/cancelled request is not marked complete.',
  'Goal ticket, pending purpose, staff interaction, receipt identity/amount, balance before/after and physical exit.'),
 ('clock_jump_during_service','Jump over meal windows/day rollover while a bank/payment/entry/exit is pending.',
  'Active service retains original ticket until terminal release; one committed payment per ticket. Skipped windows do not enqueue a backlog; new day is reconsidered after safe unwind.',
  'Original and resumed ticket IDs, unique receipt IDs, account ledger and route ownership.'),
 ('threat_injury_death','Trigger authentic shot/hit/death during home approach, sleep and bench rest.',
  'Existing medical/combat/threat priorities win; home/bench movement and pose authority release; death immediately retires old generation with no stale claim or later payment.',
  'Native damage/shot events, frame of cancellation, lease release, threat/hospital movement, respawn generation.'),
 ('bed_or_home_destroyed','Remove physical bed support or destroy its house during approach and sleep, including while T is paused.',
  'Sleep and its pose cancel on support/identity loss; real falling/blocked exit remains physical. Bounded recovery or explicit unavailable reason; no sleeping in air or stale bed claim.',
  'Actual destruction event, support lifecycle, contacts, health, phase and claim snapshots.'),
 ('ambient_bench','Use an existing available OriginalBench, then interrupt or remove its support.',
  'Existing exact physical reservation, approach/dock/pose checks remain. No invented bench/seat or pose without committed support; cancellation releases exact lease.',
  'Bench registry lease, native approach/dock positions, pose frames and support-removal cancellation.'),
 ('liveness_and_load','Observe the final combined source with ten originals plus twelve staff.',
  'Motion idle≤10s and queue idle≤30s; required motion confined within1.5m for30s fails even through retries. Valid sleep/rest excluded only with live owner/support proof; every due journey moves. No FPS acceptance beside user game.',
  'Exact SOURCE/HARNESS archive, native frame-time/physics timeline, spatial audit, cached slides, memory/object counters and per-ID transitions.')]
matrix={'schema':'mafiozi.routines58.qa-matrix/v1','status':'DESIGN_ONLY_NOT_EXECUTED',
        'source_read_pins':sources,'production_modified':False,
        'cases':[dict(zip(['id','trigger','required_result','evidence'],c)) for c in cases],
        'execution_plan':[
         'Pure native clock/idempotence checks first; no city instance needed.',
         'Short targeted native component cases for homes/support/priority/time jumps through real owners.',
         'Only after integration, ordinary ten-resident observation on the exact combined source with frozen harness and updated home-phase diagnostics.',
         'A1200s ordinary run cannot prove a full5400s day. With current17.5start, it mainly covers evening/early night; morning/lunch require explicit controlled production-clock windows or a separately authorized full-day run.'
        ],'natural_acceptance_passed':False}
save('QA_MATRIX58.json',matrix)

review={'schema':'mafiozi.routines58.clock-hooks-review/v1','read_only':True,'source_read_pins':sources,
 'clock':{'owner':'QuickControls._process → _advance_day; root meta mafiozi_visual_clock',
          'initial_hour':17.5,'cycle_real_seconds':5400,'day_seconds_per_hour':300,'night_seconds_per_hour':150,
          'n':'Forward hour-only transition to22 or next12 over2 real seconds; set_hour called each render.',
          't':'T stops only clock.advance and cancels an active N transition. It does not pause scene physics.',
          'current_limit':'No day index; advance reduces delta modulo full cycle and therefore intentionally loses whole-cycle count.',
          'narrow_extension':'Keep one shared clock. Add day index, count normalized forward midnight wraps once in set_hour; separately count full midnight crossings in advance. Do not increment floor(input_hour/24) on every N render.',
          'advance_crossing_formula':'With existing elapsed seconds on06:00 axis: floor((elapsed+delta+900)/5400)-floor((elapsed+900)/5400). Equivalent whole-cycle+remainder implementation can bound arithmetic.',
          'schedule_ticket_rule':'Use stable source ID plus day index plus routine slot for eligibility; actual receipt marks completion. Preserve active ticket across bank/interruptions and clock jumps. Lifecycle ownership still binds current generation.'},
 'hooks':[
  {'file':'scripts/npc_city_daily.gd','line':39,'finding':'_physical_needed30 enumerates existing owners; HOME/SLEEP needs explicit active-owner predicate. New phases alone are not enough for60Hz support/pose/movement.'},
  {'file':'scripts/npc_daily_life.gd','line':834,'finding':'Death precedes threat/attention/ambient and physical service branches. Home must not introduce a second movement owner or bypass medical priority.'},
  {'file':'scripts/npc_daily_life.gd','line':1010,'finding':'dsh_notice_damage performs immediate damage-side cancellation; home needs equivalent exact cancellation/unwind.'},
  {'file':'scripts/npc_daily_life.gd','line':1801,'finding':'_end_life cancels all current owners and marks old generation retired; home lease/pose/ticket owner cleanup must join this hook and dispose1851.'},
  {'file':'scripts/city/runtime/npc_threat_life30.gd','line':72,'finding':'_release_service waits for actual service release before starting threat movement. Home approach/sleep/exit must participate here.'},
  {'file':'scripts/city/runtime/npc_wait_cohort56.gd','line':32,'finding':'Current optimization knows no home. Returning null/full steps is safe; do not add sleeping owners to throttled waits without live support checks.'},
  {'file':'scripts/npc_ambient/ambient_controller28.gd','line':165,'finding':'Bench checks renewable exact reservation, support, native docking and pose commits. Reuse contract, not a fake seated/sleep flag.'},
  {'file':'scripts/npc_ambient/ambient_bench_registry29.gd','line':97,'finding':'Registry validates exact physical support and owner/body/serial; destruction removes claim before reentrant cancellation.'}
 ],
 'observer_change_required_after_api_settled':'Add home owner/phase, bed validity, shared clock and routine ticket fields in a NEW observer version. HOME approach/entry/exit require motion; supported committed sleep does not. Existing V4 has no home-specific knowledge yet.',
 'errors_claimed_in_unwritten_new_model':False}
save('CLOCK_HOOK_REVIEW58.json',review)
assert sources=={name:sha(GAME/name) for name in sources}
print(json.dumps({'cases':len(cases),'read_only':True,'files':['QA_MATRIX58.json','CLOCK_HOOK_REVIEW58.json']}))
