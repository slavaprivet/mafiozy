"""Independent evidence checks; a native passed flag alone is insufficient."""

def accept(data):
    cases = data.get('cases', {})
    kinds = ('hospital', 'restaurant', 'bank', 'shop')
    composition = data.get('composition', {})
    samples = data.get('samples', [])
    setup = data.get('qa_initializations', [])
    shots = data.get('shots', [])
    terminals = data.get('native_terminals', [])
    ids = [cases.get(k, {}).get('id') for k in kinds]
    originals = composition.get('original_ids', [])
    expected = data.get('expected_residents', 0)
    checks = {
        'bounded_batch_of_ten': isinstance(expected, int) and 10 <= expected <= 280 and expected % 10 == 0,
        'native_completed': data.get('passed') is True and data.get('reason') == 'complete' and not data.get('failures'),
        'four_distinct_original_ids': len(set(ids)) == 4 and None not in ids and all(x in originals for x in ids),
        'all_requested_originals_and_12_staff': len(originals) == len(set(originals)) == expected and composition.get('daily_count') == composition.get('health_owners') == expected and composition.get('staff_count') == 12,
        'continuous_full_composition': bool(samples) and all(s.get('original_count') == expected and s.get('staff') == 12 and s.get('phases', {}).get('counts', {}).get('total') == expected for s in samples),
        'three_explicit_setup_changes': len(setup) == 3 and sum(s.get('kind') == 'qa_initial_energy56' for s in setup) == 2 and sum(s.get('kind') == 'qa_initial_wallet56' for s in setup) == 1,
        'no_fake_service_or_movement': data.get('npc_relocations') == data.get('observer_service_settlements') == data.get('route_or_rng_writes') == 0 and data.get('synthetic_damage') is False and data.get('movement_disabled') is False and data.get('new_venues_created_by_observer') is False,
        'two_native_tt_shots': len(shots) == 2 and all(s.get('weapon') == 'tt_pistol' and s.get('shot_id') for s in shots),
        'two_owned_native_tt_terminals': len(terminals) == 2 and all(t.get('weapon') == 'tt_pistol' and t.get('owned') is True and t.get('status') == 'hit' for t in terminals),
        'city_continues_moving': sum(float(v) > .5 for k, v in data.get('city_travel_m', {}).items() if k not in ids) >= min(5, max(1, expected - 4)),
        'no_false_perf_or_render_claim': data.get('performance_accepted') is False and data.get('visual_verified') is False,
    }
    all_receipt_ids = []
    for kind in kinds:
        case = cases.get(kind, {})
        service = case.get('service', {})
        staff = case.get('staff_serving', {})
        exit_row = case.get('exit', {})
        selection = case.get('selection', {})
        events = case.get('route_events', [])
        checks[kind + '_physical_service_and_staff'] = bool(service) and service.get('on_floor') is True and service.get('distance_m', 1) <= .42 and staff.get('venue') == service.get('venue') and staff.get('customer_body_id') == selection.get('body_id')
        checks[kind + '_actual_entry_outbound_exit'] = case.get('completed') is True and case.get('entered') is True and case.get('outbound') is True and case.get('travel_m', 0) > 1 and exit_row.get('on_floor') is True and exit_row.get('depth', 0) < -1.1 and exit_row.get('outside_distance_m', 1) <= .42 and exit_row.get('selected_claim_released') is True and exit_row.get('frame', 0) > service.get('frame', 0) and any(e.get('phase') == 'OUTBOUND' for e in events)
        checks[kind + '_account_conserved_at_exit'] = exit_row.get('account', {}).get('conserved') is True
        checks[kind + '_no_discontinuous_motion'] = case.get('max_physics_displacement_m', 100) <= .65
        if kind == 'hospital':
            hits = case.get('health_receipts', [])
            heals = case.get('heal_receipts', [])
            # Ordinary accepted TT shots may critically hit for 30 rather than 24.
            # Validate actual native receipt arithmetic; never manufacture HP.
            expected_hp = float(selection.get('initial_hp', -1))
            arithmetic = len(hits) == 2
            for hit in hits:
                damage = hit.get('hit', {}).get('damage', 0)
                arithmetic = arithmetic and damage in (24, 30)
                expected_hp -= damage
                arithmetic = arithmetic and hit.get('hp') == expected_hp
            checks['hospital_60_actual_damage_60'] = selection.get('initial_hp') == 60 and selection.get('account_before', {}).get('conserved') is True and arithmetic and 0 < expected_hp <= 30 and case.get('hp_after_tt') == expected_hp and exit_row.get('hp') == 60
            checks['hospital_authenticated_chain'] = len(hits) == 2 and all(h.get('hit', {}).get('weapon_id') == 'tt_pistol' and h.get('hit', {}).get('damage') in (24, 30) and h.get('binding', {}).get('source_id') == case.get('id') and h.get('binding', {}).get('life_generation') == selection.get('generation') and any(str(h.get('event_id', '')).endswith(':' + t.get('shot_id', '!')) and t.get('owned') is True and t.get('status') == 'hit' and any(s.get('shot_id') == t.get('shot_id') for s in shots) for t in terminals) for h in hits)
            heal = heals[0] if len(heals) == 1 else {}
            checks['hospital_real_treatment'] = case.get('treated') is True and heal.get('reason') == 'hospital51_native_walk_in_treatment' and heal.get('hospital', {}).get('inside') is True and heal.get('hospital', {}).get('treatment_ms', 0) >= 1500 and heal.get('hospital', {}).get('hp_before') == expected_hp and heal.get('hospital', {}).get('hp_after') == 60 and heal.get('frame', 0) >= service.get('frame', 0) and heal.get('frame', 10**20) < exit_row.get('frame', 0)
        else:
            receipts = case.get('money_receipts', [])
            receipt = receipts[0] if len(receipts) == 1 else {}
            expected_kind = {'bank': 'local_bank_grant28', 'restaurant': 'local_restaurant_purchase28', 'shop': 'local_shop_purchase28'}[kind]
            checks[kind + '_real_authoritative_receipt'] = len(receipts) == 1 and receipt.get('kind') == expected_kind and receipt.get('inside') is True and receipt.get('dwell_ms', 0) >= 2000 and receipt.get('life_generation') == selection.get('generation') and receipt.get('frame', 0) >= service.get('frame', 0) and receipt.get('frame', 10**20) < exit_row.get('frame', 0)
            all_receipt_ids.append(receipt.get('event_id'))
            if kind == 'bank':
                checks['bank_actual_existing_grant_policy'] = receipt.get('cash_before') == 0 and receipt.get('cash_after') == 1000 and receipt.get('amount') == 1000 and receipt.get('own_bank_debit') is False
            else:
                checks[kind + '_cash_debit_and_energy'] = 5 <= receipt.get('amount', 0) <= 50 and receipt.get('cash_before', 0) - receipt.get('cash_after', 0) == receipt.get('amount') and receipt.get('saved_purchase', {}).get('kind') == kind and receipt.get('saved_purchase', {}).get('restore_energy') is True and case.get('energy_restored') is True
    checks['unique_transaction_events'] = len(set(all_receipt_ids)) == 3 and None not in all_receipt_ids
    return checks
