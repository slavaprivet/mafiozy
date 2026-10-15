"""Detect required-motion actors confined to a small area in native 1Hz samples.

This supplements displacement/queue gates; it never replaces the raw receipt.
It resets on intentional rest, actual completed walk, lifecycle change or gaps.
"""
import argparse, collections, hashlib, json, math, pathlib

def audit(source, window_s=30.0, diameter_m=1.5):
    data=json.loads(source.read_text(encoding='utf-8-sig'))
    histories={}; episodes=[]; active={}; prior={}
    for sample in data['samples']:
        t=sample['measure_ms']/1000
        for actor in sample['actors'][:sample.get('count',len(sample['actors']))]:
            ident=actor['id']; generation=actor.get('generation'); key=(ident,generation)
            q=histories.setdefault(key,collections.deque())
            completed=actor.get('completed',{}).get('walk')
            previous=prior.get(key); prior[key]=(t,completed)
            reset=(not actor['required_motion'] or actor.get('attention',False)
                   or previous is not None and (t-previous[0]>2.5 or previous[1]!=completed))
            if reset:
                q.clear();active.pop(key,None)
                continue
            p=actor['position']; q.append((t,float(p[0]),float(p[2])))
            while len(q)>1 and q[1][0]<=t-window_s:q.popleft()
            if t-q[0][0]<window_s:continue
            xs=[v[1] for v in q];zs=[v[2] for v in q]
            span=math.hypot(max(xs)-min(xs),max(zs)-min(zs))
            if span>diameter_m:
                active.pop(key,None);continue
            if key not in active:
                episode={'id':ident,'generation':generation,'start_s':q[0][0],'end_s':t,
                         'max_window_bbox_diagonal_m':span,'first_native_phase':actor.get('life_phase'),
                         'first_outer_phase':actor.get('outer_phase'),'first_door_stage':actor.get('door_stage'),
                         'sample_count':0,'last_position':p}
                episodes.append(episode);active[key]=episode
            episode=active[key];episode['end_s']=t;episode['sample_count']+=1
            episode['max_window_bbox_diagonal_m']=max(span,episode['max_window_bbox_diagonal_m'])
            episode['last_position']=p;episode['duration_s']=t-episode['start_s']
    return {'schema':'mafiozi.qa31.spatial-liveness/v1','passed':not episodes,
            'source':str(source.resolve()),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'window_s':window_s,'bbox_diagonal_limit_m':diameter_m,'episodes':episodes,
            'policy':'All samples require motion; intentional rest, completed walk and lifecycle boundaries reset. No route-retry reset. Maximum input gap2.5s.',
            'limitations':['1Hz sampled positions; rapid excursions between samples can be missed.',
                           'Read-only supplementary gate, not a replacement for existing native assertions.']}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=pathlib.Path);p.add_argument('output',type=pathlib.Path);a=p.parse_args()
    assert not a.output.exists(), 'Preserve previous audit'
    result=audit(a.source);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':result['passed'],'episodes':[{k:r.get(k) for k in ['id','duration_s','max_window_bbox_diagonal_m','first_outer_phase']} for r in result['episodes']]},ensure_ascii=False))

if __name__=='__main__':main()
