"""Apply lifecycle30 exact scoped hunks after population30; caller holds a write lease."""
import argparse,difflib,hashlib,json,pathlib
OUT=pathlib.Path(__file__).resolve().parent
def sha(data):return hashlib.sha256(data).hexdigest()
def normalize(data):return data.decode('utf-8').replace('\r\n','\n')
def merge(base,candidate,current):
    if current==base:return candidate
    if normalize(current)==normalize(candidate):return current
    a=normalize(base).splitlines(keepends=True);b=normalize(candidate).splitlines(keepends=True)
    text=normalize(current)
    for group in difflib.SequenceMatcher(a=a,b=b,autojunk=False).get_grouped_opcodes(3):
        old=''.join(a[group[0][1]:group[-1][2]]);new=''.join(b[group[0][3]:group[-1][4]])
        if text.count(new)==1 and old not in text:continue
        if text.count(old)!=1:raise RuntimeError('Changed or ambiguous context; manual integration required: '+old[:250])
        text=text.replace(old,new,1)
    return (text.replace('\n','\r\n') if b'\r\n' in current else text).encode('utf-8')
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--project',required=True,type=pathlib.Path);parser.add_argument('--apply',action='store_true');parser.add_argument('--receipt',type=pathlib.Path);args=parser.parse_args()
    project=args.project.resolve();assert (project/'project.godot').is_file()
    assert all(s not in str(project).lower() for s in ['coordinator29_release','coordinator29_npc','coordinator27_release','coordinator30_release']),'Frozen/release projects cannot be patched'
    manifest=json.loads((OUT/'MANIFEST30.json').read_text(encoding='utf-8'));pending=[];report=[]
    for rel,entry in manifest['files'].items():
        candidate=(OUT/rel).read_bytes();target=project/rel;current=target.read_bytes() if target.exists() else None
        assert sha(candidate)==entry['candidate_sha256'],rel+' candidate changed'
        if entry['base_sha256'] is None:
            assert current is None or normalize(current)==normalize(candidate),rel+' new file already differs'
            updated=candidate if current is None else current
        else:
            base=(OUT/'baseline'/rel).read_bytes();assert sha(base)==entry['base_sha256'] and current is not None,rel+' baseline changed or target missing'
            try:updated=merge(base,candidate,current)
            except RuntimeError as e:raise RuntimeError(rel+': '+str(e)) from e
        pending.append((target,updated));report.append({'file':rel,'before_sha256':sha(current) if current is not None else None,'after_sha256':sha(updated),'changed':updated!=current})
    if args.apply:
        for target,data in pending:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    receipt={'applied':args.apply,'project':str(project),'files':report}
    if args.receipt:args.receipt.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
