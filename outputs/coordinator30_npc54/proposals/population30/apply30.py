"""Review/apply only population30 hunks; caller owns target scheduler write lease."""
import argparse, difflib, hashlib, json, pathlib
OUT=pathlib.Path(__file__).resolve().parent
def sha(data):return hashlib.sha256(data).hexdigest()
def merge(base,candidate,current):
    if current==base:return candidate
    if current==candidate:return current
    a=base.decode('utf-8').splitlines(keepends=True);b=candidate.decode('utf-8').splitlines(keepends=True)
    text=current.decode('utf-8')
    for group in difflib.SequenceMatcher(a=a,b=b,autojunk=False).get_grouped_opcodes(3):
        old=''.join(a[group[0][1]:group[-1][2]]);new=''.join(b[group[0][3]:group[-1][4]])
        if text.count(new)==1 and old not in text:continue
        if text.count(old)!=1:raise RuntimeError('Context changed or ambiguous; manual integration required: '+old[:200])
        text=text.replace(old,new,1)
    return text.encode('utf-8')
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--project',required=True,type=pathlib.Path);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    project=args.project.resolve();assert (project/'project.godot').is_file()
    assert all(s not in str(project).lower() for s in ['coordinator29_release','coordinator29_npc','coordinator27_release','coordinator30_release']), 'Frozen/release projects cannot be patched'
    manifest=json.loads((OUT/'MANIFEST30.json').read_text(encoding='utf-8'));pending=[];report=[]
    for rel,entry in manifest['files'].items():
        base=(OUT/'baseline'/rel).read_bytes();candidate=(OUT/rel).read_bytes();target=project/rel;current=target.read_bytes()
        assert sha(base)==entry['base_sha256'] and sha(candidate)==entry['candidate_sha256'],rel+' package changed'
        updated=merge(base,candidate,current);pending.append((target,updated))
        report.append({'file':rel,'before':sha(current),'after':sha(updated),'changed':updated!=current})
    if args.apply:
        for target,data in pending:target.write_bytes(data)
    print(json.dumps({'applied':args.apply,'project':str(project),'files':report},indent=2))
if __name__=='__main__':main()
