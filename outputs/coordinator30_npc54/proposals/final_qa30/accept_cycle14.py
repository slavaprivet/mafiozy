def accept_cycle(data, stdout):
    samples = data.get('samples', [])
    last = samples[-1] if samples else {}
    account = last.get('account', {}).get('account', {})
    receipts = account.get('receipts', [])
    bank = [r for r in receipts if r['kind'] == 'local_bank_grant28']
    food = [r for r in receipts if r['kind'] in ['local_shop_purchase28', 'local_restaurant_purchase28']]
    service = data.get('physical_service_evidence', {})
    gestures = data.get('staff_serving_evidence', {})
    expected = {'hospital', 'bank', 'restaurant' if food and food[0]['kind']=='local_restaurant_purchase28' else 'shop'}
    return {
        'cycle_physically_complete': data.get('reason') == 'cycle_physically_complete',
        'one_resident_twelve_staff': bool(samples) and all(s['resident_count']==1 and s['staff_count']==12 for s in samples),
        'all_services_physically_reached': expected <= service.keys(),
        'all_staff_gestures_from_real_service': expected <= gestures.keys(),
        'no_heal_or_settle_without_service': not data.get('violations', ['missing']),
        'one_bank_one_food': len(bank)==1 and len(food)==1,
        'unique_receipts': len({r['id'] for r in receipts})==len(receipts),
        'settlement_inside_after_dwell': bool(bank+food) and all(r.get('inside') is True and r['dwell_ms']>=2000 for r in bank+food),
        'bank_restores_1000_and_price_preserved': len(bank)==1 and len(food)==1 and bank[0]['cash_after']==1000 and bank[0]['saved_purchase']==food[0]['saved_purchase'] and 5<=food[0]['amount']<=50 and account['cash']==1000-food[0]['amount'] and last['account']['conserved'],
        'hospital_healed_and_physically_exited': 'reason=treated_and_physically_exited' in stdout and last.get('hp')==last.get('max_hp'),
        'bank_and_food_physically_exited': 'kind=bank stage=complete' in stdout and any('kind='+k+' stage=complete' in stdout for k in ['shop','restaurant']),
        'energy_restored': any(s['economy'].get('receipt',{}).get('energy_after')==100.0 for s in samples),
        'released_all_claims': bool(last) and last.get('capacity_claims')==0 and last.get('service_claims')==0,
        'real_roam_resumed': last.get('economy',{}).get('roams',0)>=1,
    }
