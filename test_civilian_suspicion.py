import copy
import time
from civilian_suspicion import validate_civilian_report

def run():
    p={"x":4.0,"y":2.0,"_weapon":"pistol","_wanted":0,"hp":80}
    data={"nonce":"cw_10000_1","report_kind":"weapon_display","witness_id":"resident_42","x":4.0,"y":2.0,"witness_x":3.0,"witness_y":1.0}
    r=validate_civilian_report(p,data,100)
    assert r['ok'] and r['action']=='observe' and r['witness_verified'] is False
    assert p['_wanted']==0 and p['hp']==80
    assert validate_civilian_report(p,data,101)==r, 'Same exact nonce returns cached receipt'
    assert validate_civilian_report(p,{**data,'nonce':'cw_10001_2'},102)['reason']=='cooldown'
    for updates,reason in [({'x':float('nan')},'position'),({'x':float('inf')},'position'),({'x':200},'range'),({'witness_x':200},'range'),({'witness_id':'police_1'},'witness'),({'report_kind':'murder'},'kind'),({'target_uid':'other'},'authority'),({'wanted':5},'authority'),({'nonce':'x'},'nonce')]:
        fresh={k:v for k,v in p.items() if not k.startswith('_civilian')}
        result=validate_civilian_report(fresh,{**data,**updates},150)
        assert result['ok'] is False and result['reason']==reason,(updates,result)
        assert fresh['_wanted']==0 and fresh['hp']==80
    assert validate_civilian_report({**p,'dead':True},data,200)['reason']=='unavailable'
    assert validate_civilian_report({**p,'_jail_until':250},data,200)['reason']=='unavailable'
    assert validate_civilian_report({**p,'_weapon':'fists'},data,200)['reason']=='weapon'
    assert validate_civilian_report(None,data,200)['ok'] is False
    heard={**data,'nonce':'cw_20000_1','report_kind':'heard_gunfire'}
    assert validate_civilian_report({**p,'_last_shot_t':199},heard,200)['ok']
    assert validate_civilian_report({**p,'_last_shot_t':1},heard,200)['reason']=='no_recent_shot'
    src=open('mafiozi_bot.py',encoding='utf8').read();section=src.split("elif t == 'civilian_report':",1)[1].split("elif t == 'open_fire':",1)[0]
    assert 'world.players.get(uid)' in section and 'validate_civilian_report' in section
    assert 'world._bump_wanted' not in section and 'world.connections' not in section
    samples=[]
    for i in range(2000):
        q={'x':4,'y':2,'_weapon':'pistol'};start=time.perf_counter_ns();validate_civilian_report(q,data,100);samples.append((time.perf_counter_ns()-start)/1e6)
    samples.sort();print('PASS civilian suspicion: self context, finite/range/nonce/cooldown, exact ACK, dead/jail, weapon, no arbitrary targets or wanted/damage; validation p50 %.4fms p95 %.4fms'%(samples[1000],samples[1900]))

if __name__=='__main__':run()
