"""CPU-only adversarial checks of the evidence evaluator. Never runs an engine."""
import ast
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

from accept_services56 import accept

OUT = Path(__file__).resolve().parent

def fixture():
    """Synthetic CPU data only; deliberately cannot be mistaken for native proof."""
    result = {'expected_residents': 10, 'passed': True, 'reason': 'complete', 'failures': [], 'cases': {},
              'composition': {'original_ids': [f'resident_{i}' for i in range(10)], 'daily_count': 10, 'health_owners': 10, 'staff_count': 12},
              'samples': [{'original_count': 10, 'staff': 12, 'phases': {'counts': {'total': 10}}}],
              'qa_initializations': [{'kind': 'qa_initial_energy56'}, {'kind': 'qa_initial_energy56'}, {'kind': 'qa_initial_wallet56'}],
              'npc_relocations': 0, 'observer_service_settlements': 0, 'route_or_rng_writes': 0, 'synthetic_damage': False, 'movement_disabled': False, 'new_venues_created_by_observer': False,
              'performance_accepted': False, 'visual_verified': False,
              'city_travel_m': {f'resident_{i}': 2 for i in range(10)},
              'shots': [{'weapon': 'tt_pistol', 'shot_id': f'tt_pistol:{i}'} for i in (1, 2)],
              'native_terminals': [{'weapon': 'tt_pistol', 'shot_id': f'tt_pistol:{i}', 'owned': True, 'status': 'hit'} for i in (1, 2)]}
    for index, kind in enumerate(('hospital', 'restaurant', 'bank', 'shop')):
        row = {'id': f'resident_{index}', 'completed': True, 'entered': True, 'outbound': True, 'travel_m': 5, 'max_physics_displacement_m': .04,
               'selection': {'body_id': index + 10, 'generation': 1, 'initial_hp': 60, 'account_before': {'conserved': True}},
               'service': {'venue': kind + '1', 'on_floor': True, 'distance_m': .2, 'frame': 30},
               'staff_serving': {'venue': kind + '1', 'customer_body_id': index + 10},
               'exit': {'on_floor': True, 'depth': -1.5, 'outside_distance_m': .1, 'selected_claim_released': True, 'frame': 300, 'account': {'conserved': True}, 'hp': 60},
               'route_events': [{'phase': 'INBOUND'}, {'phase': 'INSIDE'}, {'phase': 'OUTBOUND'}], 'energy_restored': True}
        if kind == 'hospital':
            row.update(hp_after_tt=12, treated=True,
                       health_receipts=[{'hp': 60-24*i, 'event_id': f'resident_0:1:tt_pistol:{i}', 'hit': {'weapon_id': 'tt_pistol', 'damage': 24}, 'binding': {'source_id': 'resident_0', 'life_generation': 1}} for i in (1, 2)],
                       heal_receipts=[{'reason': 'hospital51_native_walk_in_treatment', 'hospital': {'inside': True, 'treatment_ms': 1500, 'hp_after': 60}, 'frame': 150}])
        else:
            receipt = {'kind': {'bank': 'local_bank_grant28', 'shop': 'local_shop_purchase28', 'restaurant': 'local_restaurant_purchase28'}[kind], 'inside': True, 'dwell_ms': 2000, 'life_generation': 1, 'frame': 150, 'event_id': kind + ':1'}
            receipt.update({'cash_before': 0, 'cash_after': 1000, 'amount': 1000, 'own_bank_debit': False} if kind == 'bank' else {'cash_before': 1000, 'cash_after': 980, 'amount': 20, 'saved_purchase': {'kind': kind, 'restore_energy': True}})
            row['money_receipts'] = [receipt]
        result['cases'][kind] = row
    return result

def main():
    checks = {}
    for source in OUT.glob('*.py'):
        ast.parse(source.read_text(encoding='utf-8'))
    checks['python_ast'] = True
    script = (OUT / 'observer_services56.gd').read_text(encoding='utf-8')
    writes = [line.strip() for line in script.splitlines() if '.global_position =' in line and not any(x in line for x in ['event.global_position', 'motion.global_position'])]
    checks['only_player_position_write'] = writes == ['_player.global_position = floor']
    checks['no_authority_or_controller_shortcuts'] = not any(token in script for token in ['.settle_economy28(', '._hospital51_heal(', '.note_roam_arrived(', '._pending =', '._rng.state =', '.set_physics_process(false)'])
    checks['counts_helper_exact_source_copy'] = (OUT / 'observer_counts56.gd').read_bytes() == (OUT.parent / 'stalls56/observer_counts56.gd').read_bytes()
    forbidden = subprocess.run([sys.executable, '-B', str(OUT / 'run_services56.py'), 'forbidden_cpu_only', '--residents', '287', '--go'], capture_output=True, text=True, encoding='utf-8', errors='replace')
    checks['runner_rejects_287_before_launch'] = forbidden.returncode == 2 and 'invalid choice' in forbidden.stderr and not (OUT / 'runs/forbidden_cpu_only').exists()
    baseline = fixture()
    accepted = accept(baseline)
    checks['synthetic_complete_evidence_accepted'] = bool(accepted) and all(accepted.values())
    mutations = {
        'forbidden_287': lambda d: d.__setitem__('expected_residents', 287),
        'not_batch_of_ten': lambda d: d.__setitem__('expected_residents', 16),
        'missing_staff': lambda d: d['composition'].__setitem__('staff_count', 11),
        'missing_original': lambda d: d['composition']['original_ids'].pop(),
        'population_disappeared': lambda d: d['samples'][0].__setitem__('original_count', 9),
        'npc_teleport': lambda d: d.__setitem__('npc_relocations', 1),
        'synthetic_damage': lambda d: d.__setitem__('synthetic_damage', True),
        'fake_settlement': lambda d: d.__setitem__('observer_service_settlements', 1),
        'money_only_no_exit': lambda d: d['cases']['shop']['exit'].__setitem__('depth', .6),
        'claim_not_released': lambda d: d['cases']['bank']['exit'].__setitem__('selected_claim_released', False),
        'no_medical_service': lambda d: d['cases']['hospital'].__setitem__('service', {}),
        'wrong_staff_customer': lambda d: d['cases']['restaurant']['staff_serving'].__setitem__('customer_body_id', 999),
        'stale_generation': lambda d: d['cases']['hospital']['health_receipts'][0]['binding'].__setitem__('life_generation', 2),
        'unowned_projectile': lambda d: d['native_terminals'][0].__setitem__('owned', False),
        'missing_shot_chain': lambda d: d['shots'][0].__setitem__('shot_id', 'other'),
        'insufficient_dwell': lambda d: d['cases']['restaurant']['money_receipts'][0].__setitem__('dwell_ms', 1999),
        'same_resident_twice': lambda d: d['cases']['shop'].__setitem__('id', 'resident_2'),
        'duplicate_transaction': lambda d: d['cases']['shop']['money_receipts'][0].__setitem__('event_id', 'bank:1'),
        'unconserved_account': lambda d: d['cases']['bank']['exit']['account'].__setitem__('conserved', False),
        'wrong_bank_claim': lambda d: d['cases']['bank']['money_receipts'][0].__setitem__('own_bank_debit', True),
        'no_energy_restored': lambda d: d['cases']['restaurant'].__setitem__('energy_restored', False),
        'instant_jump': lambda d: d['cases']['shop'].__setitem__('max_physics_displacement_m', 4.0),
        'city_frozen': lambda d: d.__setitem__('city_travel_m', {}),
    }
    for name, mutate in mutations.items():
        negative = copy.deepcopy(baseline)
        mutate(negative)
        checks['reject_' + name] = not all(accept(negative).values())
    checks['reject_empty_result'] = not all(accept({}).values())
    result = {'schema': 'services56.harness-cpu-only/v1', 'passed': all(checks.values()), 'checks': checks, 'check_count': len(checks), 'independent_acceptance_check_count': len(accepted), 'synthetic_input_only': True, 'native_launched': False, 'services_accepted': False}
    (OUT / 'CPU_CHECK.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))
    return 0 if result['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
