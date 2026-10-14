import json,pathlib,sys
OUT=pathlib.Path(__file__).resolve().parent
names=sys.argv[1:] or ['economy53_01']
for name in names:
    run=OUT/name
    data=json.loads((run/'OBSERVATION.json').read_text(encoding='utf-8'))
    check=json.loads((run/'RUN_CHECK.json').read_text(encoding='utf-8'))
    samples=data['samples']; last=samples[-1]; account=last['account']['account']
    receipts=account['receipts'];bank=[r for r in receipts if r['kind']=='local_bank_grant28']
    food=[r for r in receipts if r['kind'] in ('local_restaurant_purchase28','local_shop_purchase28')]
    errors=(run/'engine/stderr.log').read_text(encoding='utf-8')
    log=(run/'engine/stdout.log').read_text(encoding='utf-8')
    checks={
        'clean_execution':check['exit']==0 and not check['source_drift'] and not errors,
        'bounded_observation':data['reason']=='bounded_observation_complete',
        'one_bank_one_purchase':len(bank)==1 and len(food)==1,
        'unique_receipts':len({r['id'] for r in receipts})==len(receipts),
        'inside_at_real_settlement':all(r.get('inside') is True and r['dwell_ms']>=2000 for r in bank+food),
        'bank_target_exactly_1000':len(bank)==1 and bank[0]['cash_after']==1000,
        'saved_price_and_cash_conservation':len(food)==1 and len(bank)==1 and bank[0]['saved_purchase']==food[0]['saved_purchase'] and 5<=food[0]['amount']<=50 and account['cash']==1000-food[0]['amount'] and last['account']['conserved'],
        'energy_restored_100':any(s.get('economy',{}).get('receipt',{}).get('energy_after')==100.0 for s in samples),
        'physical_bank_exit':'kind=bank stage=complete' in log,
        'physical_food_exit':any('kind='+kind+' stage=complete' in log for kind in ('restaurant','shop')),
        'real_roam_resumed':last.get('economy',{}).get('roams',0)>=1,
        'ambient_executed_and_released':any(s.get('ambient',{}).get('pose_frames',0)>=8 for s in samples) and any(s.get('ambient',{}).get('reason')=='finished' for s in samples),
    }
    if name.startswith('cycle'):
        checks['hospital_healed_and_physically_exited']='reason=treated_and_physically_exited' in log and last['hp']==last['max_hp']
        checks['all_slots_released']=any(s.get('hospital_route29',{}).get('capacity',{}).get('requests')==0 for s in samples)
    result={'passed':all(checks.values()),'checks':checks,'sample_count':len(samples),'final_cash':account['cash'],
        'price':food[0]['amount'] if food else None,'one_resident':True,'performance_accepted':False,'visual_ambient_accepted':False}
    (run/'BEHAVIOR_ACCEPTANCE29.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(name,json.dumps(result))
    if not result['passed']:sys.exit(1)
