"""Bounded source-only upstream inspection; no executable binaries or demos."""
import concurrent.futures, hashlib, json, pathlib, urllib.request

HERE=pathlib.Path(__file__).resolve().parent
PINS={'statecharts':('derkork/godot-statecharts','76d226a3efac66a72aea825382b320c94808f409'),
      'limboai':('limbonaut/limboai','df8933d3e1a0e7884efb640c0e363140741c50cb')}

def get(url):
    with urllib.request.urlopen(url,timeout=20) as r:
        b=r.read(1_048_577)
        assert len(b)<=1_048_576
        return b

def main():
    report={}
    for name,(repo,commit) in PINS.items():
        tree=json.loads(get(f'https://api.github.com/repos/{repo}/git/trees/{commit}?recursive=1'))['tree']
        if name=='statecharts':
            selected=[x for x in tree if x['type']=='blob' and (x['path'].startswith('addons/godot_state_charts/') or x['path'] in ['README.md','LICENSE']) and '/csharp/' not in x['path'] and not x['path'].endswith('.import')]
        else:
            selected=[x for x in tree if x['type']=='blob' and x['path'] in ['README.md','LICENSE.md','LOGO_LICENSE.md','limboai_version.py','doc/source/getting-started/gdextension.rst','doc/source/getting-started/using-blackboard.rst']]
        assert sum(x.get('size',0) for x in selected)<1_048_576
        def fetch(x):
            rel=x['path']; data=get(f'https://raw.githubusercontent.com/{repo}/{commit}/{rel}')
            target=HERE/('project' if name=='statecharts' and rel.startswith('addons/') else 'upstream/'+name)/rel
            target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists(): assert target.read_bytes()==data
            else: target.write_bytes(data)
            return {'path':str(target.relative_to(HERE)).replace('\\','/'),'upstream_path':rel,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            files=list(pool.map(fetch,selected))
        report[name]={'repository':'https://github.com/'+repo,'commit':commit,'files':files,'bytes':sum(x['bytes'] for x in files)}
    (HERE/'UPSTREAM31.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:{'commit':v['commit'],'files':len(v['files']),'bytes':v['bytes']} for k,v in report.items()}))

if __name__=='__main__': main()
