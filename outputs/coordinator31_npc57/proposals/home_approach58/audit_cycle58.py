"""Read-only derived gates for archived native home cycles; no engine launch."""
import argparse, hashlib, importlib.util, json, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('name');a=ap.parse_args()
    run=HERE/'runs'/a.name;raw=run/'HOME_CYCLE58.json';data=read(raw);receipt=read(run/'RUN.json')
    out=HERE/'audits'/a.name;out.mkdir(parents=True,exist_ok=False)
    converted={'samples':[]};prior={};anchor={};since={};max_idle={};active_max={};queue_since={};queue_max={}
    for sample in data['samples']:
        now=sample['t'];actors=[]
        for actor in sample['actors']:
            ident=actor['source_id'];position=actor['position'];phase=actor['phase']
            valid_rest=phase in ['HOME_SLEEP','HOME_REST','HOME_SETTLE'] and actor['support_current'] and actor['claim_current'] and actor['pose_committed_frame']>=sample['frame']-1
            complete=actor['actual_exit']
            required=not valid_rest and not complete
            actors.append({'id':ident,'generation':actor['life_generation'],'position':position,'required_motion':required,'attention':False,'life_phase':phase,'outer_phase':actor.get('route',{}).get('phase',''),'door_stage':actor.get('door_state',{}).get('exit_stage',''),'completed':{'walk':0}})
            if not required or ident not in prior or now-prior[ident]>2.5:
                anchor[ident]=position;since[ident]=now
            elif math.dist((position[0],position[2]),(anchor[ident][0],anchor[ident][2]))>=.1:
                anchor[ident]=position;since[ident]=now
            idle=now-since[ident];max_idle[ident]=max(max_idle.get(ident,0),idle)
            if actor['active']:active_max[ident]=max(active_max.get(ident,0),idle)
            queued=actor.get('route',{}).get('phase') in ['PORTAL_WAIT_IN','PORTAL_WAIT_OUT','WAITING']
            if not queued or ident not in queue_since:queue_since[ident]=now
            queue_max[ident]=max(queue_max.get(ident,0),now-queue_since[ident])
            prior[ident]=now
        converted['samples'].append({'measure_ms':now*1000,'actors':actors,'count':len(actors)})
    converted_path=out/'SPATIAL_INPUT58.json';save(converted_path,converted)
    module_path=HERE.parent/'release58_tools/spatial58.py'
    spec=importlib.util.spec_from_file_location('home_spatial58',module_path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    spatial=module.audit(converted_path);save(out/'SPATIAL58.json',spatial)
    result={'passed':receipt['passed'] and data['passed'] and spatial['passed'] and all(v<=10 for v in max_idle.values()) and all(v<=30 for v in queue_max.values()),'raw_sha256':sha(raw),'run_sha256':sha(run/'RUN.json'),'source_before_after_exact':read(run/'SOURCE.json')==read(run/'SOURCE_AFTER.json'),'native_checks_passed':sum(bool(c['ok']) for c in data['checks']),'native_checks_count':len(data['checks']),'native_failures':[c for c in data['checks'] if not c['ok']],'actual_sleep_count':sum(r['ever_sleep'] for r in data['final']),'actual_exit_count':sum(r['actual_exit'] for r in data['final']),'motion_idle_limit_s':10,'motion_idle_max_s':max_idle,'while_controller_active_max_s':active_max,'queue_limit_s':30,'queue_max_s':queue_max,'queue_rationale':'Assigned-home adapter is concurrent and never enters PORTAL_WAIT. No artificial queue is inferred.','spatial_passed':spatial['passed'],'spatial_validator_sha256':sha(module_path),'excluded_rest_policy':'Only current supported claimed HOME_SETTLE/SLEEP/REST with pose commit current or exactly one pre-host frame old. Inactive unsuccessful home attempt remains required motion until fixture end; successful physical exit completes the objective.','limitations':['Component intent takeover, not ordinary daily scheduling acceptance.','1Hz derived idle/spatial evidence, actual native collisions and velocity guards are in raw run.']}
    save(out/'AUDIT58.json',result)
    print(json.dumps({k:result[k] for k in ['passed','native_checks_passed','native_checks_count','actual_sleep_count','actual_exit_count','spatial_passed','motion_idle_max_s']},ensure_ascii=True))
if __name__=='__main__':main()
