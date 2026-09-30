from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parents[2]
def git(*args):return subprocess.check_output(['git',*args],cwd=root).decode('utf8').strip()
assert git('rev-parse','HEAD')=='b334f890d7137bc0a354bd243d8e0f29a0f32012'
preexisting=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=root).decode('utf8').strip('\0').split('\0'))-{''}
scope=set()
for p in (root/'outputs/coordinator23_rpg23i').rglob('*'):
 if p.is_file() and not any(x in ['stage','__pycache__'] for x in p.relative_to(root/'outputs/coordinator23_rpg23i').parts) and p.suffix in ['.py','.gd','.md','.json','.log','.txt','.patch'] and p.stat().st_size<8_000_000:
  if p.name not in ['export18.log','CHECKPOINT_PENDING.json']:scope.add(p.relative_to(root).as_posix())
for label in ['candidate17','candidate18']:
 stage=root/'outputs/coordinator23_quality'/label
 manifest=json.loads((stage/'INTEGRATION.json').read_text(encoding='utf8'))
 scope.add((stage/'INTEGRATION.json').relative_to(root).as_posix())
 for name,row in manifest['changes'].items():
  p=stage/'godot/mafiozi_walk'/name
  assert hashlib.sha256(p.read_bytes()).hexdigest()==row['after']
  scope.add(p.relative_to(root).as_posix())
assert preexisting.issubset(scope),'Foreign staged paths; leave untouched'
rows=[];lines=[]
for name in sorted(scope):
 blob=git('hash-object','-w','--',name)
 existing=git('ls-files','--stage','--',name)
 if existing and existing.split()[1]==blob and name not in preexisting:continue
 lines.append('100644 '+blob+'\t'+name+'\n');rows.append({'path':name,'blob':blob})
assert rows
subprocess.run(['git','update-index','--index-info'],cwd=root,input=''.join(lines).encode('utf8'),check=True)
actual=set(subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=root).decode('utf8').strip('\0').split('\0'))
assert actual=={r['path'] for r in rows}
# Native raw logs contain CRCRLF, and pinned inherited source has blank EOFs.
# Preserve exact evidence bytes rather than normalizing already hashed inputs.
subprocess.run(['git','-c','core.whitespace=-blank-at-eof,-blank-at-eol','diff','--cached','--check','--','.',':(exclude)*.patch',':(exclude)*.log'],cwd=root,check=True)
subprocess.run(['git','commit','-m','Save isolated RPG integration and verified native proofs; GPU acceptance pending'],cwd=root,check=True)
head=git('rev-parse','HEAD');subprocess.run(['git','push','origin','main'],cwd=root,check=True)
assert git('ls-remote','origin','refs/heads/main').split()[0]==head
(root/'outputs/coordinator23_rpg23i/CHECKPOINT_PENDING.json').write_text(json.dumps({'head':head,'status':'saved outputs-only, accepted runtime remains23h','files':rows},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Remote verified',head,'scoped files',len(rows))
