"""Caller owns candidate and scheduler writer lease; preserves adjacent edits."""
from pathlib import Path
import argparse,hashlib,json,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def apply_to(project):
    project=Path(project).resolve()
    if project==ROOT/'outputs/coordinator30_release55/game':raise RuntimeError('Frozen55 is immutable')
    spec=json.loads((HERE/'PATCH56.json').read_text(encoding='utf-8'));pending={}
    for c in spec['changes']:
        file=c['file'];text=pending.get(file,(project/file).read_text(encoding='utf-8-sig'))
        if c['after'] in text:continue
        if text.count(c['before'])!=1:raise RuntimeError('Non-unique hunk '+file+': '+c['before'][:80])
        pending[file]=text.replace(c['before'],c['after'],1)
    for file,expected in spec['helpers'].items():
        p=HERE/'patch'/file
        if hashlib.sha256(p.read_bytes()).hexdigest()!=expected:raise RuntimeError('Helper source drift '+file)
        pending[file]=p.read_text(encoding='utf-8')
    for file,text in pending.items():
        p=project/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
    return {file:hashlib.sha256((project/file).read_bytes()).hexdigest() for file in pending}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('project',type=Path);a=p.parse_args();sys.path.insert(0,str(ROOT))
    from tools.godot.test_scheduler import Lease
    with Lease('headless',a.project,'write',30):result=apply_to(a.project)
    print(json.dumps(result,indent=2))
