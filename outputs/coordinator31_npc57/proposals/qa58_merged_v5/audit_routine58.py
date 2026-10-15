"""Read-only post-exit evidence and unexplained standing gate from real 1Hz rows."""
import hashlib,json,math
from pathlib import Path
def audit(path):
    path=Path(path);data=json.loads(path.read_text(encoding='utf-8-sig'))
    previous={};anchors={};since={};maximum={};events=[];pending={};ids=set();missing=[]
    def moved(a,b):return math.dist((a[0],a[2]),(b[0],b[2]))>=.1
    for sample in data['samples']:
        now=sample['measure_ms']/1000
        for row in sample['actors'][:sample['count']]:
            ident=row['id'];key=(ident,row['generation']);ids.add(ident);p=row['position'];prior=previous.get(key)
            if 'rest_evidence58' not in row or 'unexplained_idle58' not in row:missing.append({'id':ident,'at_s':now});continue
            contiguous=prior is not None and 0<=now-prior['at']<=2.5
            if not contiguous or not row['unexplained_idle58'] or key not in anchors or moved(p,anchors[key]):anchors[key]=p;since[key]=now
            maximum[ident]=max(maximum.get(ident,0),now-since[key])
            if contiguous:
                for kind in ['hospital','restaurant','bank','shop']:
                    if row['completed'].get(kind,0)>prior['row']['completed'].get(kind,0):
                        event={'id':ident,'generation':row['generation'],'kind':kind,'observed_exit_s':now,'exit_sampling_interval_s':[prior['at'],now],'anchor':p,'first_next_intent_s':None,'first_movement_s':None,'evidence':[]}
                        events.append(event);pending.setdefault(key,[]).append(event)
                old_home=prior['row'].get('home58',{});home=row.get('home58',{})
                if old_home.get('active') and old_home.get('phase')=='HOME_EXIT' and home and not home.get('active'):
                    event={'id':ident,'generation':row['generation'],'kind':'home_exit_transition','observed_exit_s':now,'exit_sampling_interval_s':[prior['at'],now],'anchor':p,'first_next_intent_s':None,'first_movement_s':None,'evidence':[],'home_finish_reason':home.get('reason')}
                    events.append(event);pending.setdefault(key,[]).append(event)
            for event in pending.get(key,[]):
                if event['first_movement_s'] is not None:continue
                intent=row.get('routine58',{}).get('intent',{})
                evidence={'at_s':now,'phase':row['life_phase'],'goal':row['goal'],'intent':intent,'rest':row['rest_evidence58'],'required_motion':row['required_motion']}
                # Up to1200 observed seconds, no generated/wall-time estimate.
                event['evidence'].append(evidence)
                active_intent=row['required_motion'] or bool(row.get('home58',{}).get('active')) or bool(row.get('ambient58',{}).get('active')) or bool(row['rest_evidence58'].get('bounded_routine_rest'))
                if active_intent and event['first_next_intent_s'] is None:event['first_next_intent_s']=now-event['observed_exit_s']
                if moved(p,event['anchor']):event['first_movement_s']=now-event['observed_exit_s']
                event['observed_through_s']=now
            previous[key]={'row':row,'at':now}
    failures=[{'id':k,'unexplained_idle_s':v} for k,v in maximum.items() if v>10.0]
    return {'passed':not failures and not missing and len(ids)==10,'schema':'routine58.liveness/v1','raw_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_ids':sorted(ids),'unexplained_idle_limit_s':10.0,'max_unexplained_idle_s':maximum,'failures':failures,'missing_evidence_samples':missing[:20],'post_exit':events,'limitations':['Exit times are bounded by successive actual1Hz samples, not exact native callbacks. Service completion counters increment only after physical exit in the source. Home exit is an explicitly labelled phase transition.','No elapsed limit is imposed on proven timed rest or live committed sleeping/ambient pose. Rolling decision poll timestamps alone do not prove a rest duration.','A final event without movement remains censored at the last observed sample; it is never reported as resumed.']}
if __name__=='__main__':
    import argparse
    ap=argparse.ArgumentParser();ap.add_argument('raw',type=Path);ap.add_argument('out',type=Path);a=ap.parse_args()
    result=audit(a.raw);a.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in result.items() if k not in ['post_exit']},ensure_ascii=True))
