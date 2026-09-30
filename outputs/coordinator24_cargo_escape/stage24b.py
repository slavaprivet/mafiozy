"""Scoped checkpoint; insert only this delivery's new blocks in shared documents."""
from pathlib import Path
import subprocess,hashlib,json
root=Path(__file__).resolve().parents[2]
def git(*args,data=None):
    p=subprocess.run(['git',*args],cwd=root,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode: raise RuntimeError(p.stderr.decode('utf8',errors='replace'))
    return p.stdout
assert git('rev-parse','HEAD').decode().strip()=='a498d8bcbfcd30bc1601aed10ad86c4a7fd855d9'
assert not git('diff','--cached','--name-only').strip(),'Shared index occupied'
blocks={
 'docs/ai/AGENT_HUB.md': '''## 30 сентября17:45 — Root24 доставил Esc24b

По точному воспроизведению F→Esc исправлен обязательный дополнительный ЛКМ.
Первый Esc закрывает содержимое и возвращает управление; отдельный следующий Esc
вне окна освобождает мышь. Baseline27/headless26/focusedGPU30 PASS, raw injected input.
PCKbecb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749.
Единственная игра PID34044 отвечала17:45; ярлык24b. Проверять свежий inventory.
Три guarded пути,1725чужих файлов сохранены. NPC21/quality24c, postmortem marks и
corpse blocking/nudge ещё в работе; Художник24 владеет NPC, root player/contact.
В будущие NPC/RPG пакеты обязательно сохранить Esc24b. Память24 актуальна.

''',
 'docs/godot/MIGRATION_BOARD.md': '''## 30 September17:45 — modal Escape24b delivered

Exact candidate22 fixes the user's F→Esc→extra-click reproduction. Existing close
path now resumes capture/held movement; next distinct Escape outside the modal still
releases cursor. Baseline27/headless26/focusedGPU30 PASS, injected Godot input.
PCKbecb595b967ca70fe31660e137a9e591a17abb2418259733fa707342ddc7a749.
Three guarded production paths;1725other source files preserved. One user game
PID34044 responding17:45 and shortcut updated24b; always refresh inventory.
NPC21/quality24c and corpse improvements remain isolated. Preserve24b on rebases.
See outputs/coordinator24_delivery24b/ACCEPTANCE.md for proof scope and limitations.

'''}
partial={}
for path,block in blocks.items():
    work=root/path
    before=work.read_bytes()
    def insert(b):
        pos=b.index(b'\n\n')+2 if b.startswith(b'# ') and b'\n\n' in b else (b.index(b'\r\n\r\n')+4 if b.startswith(b'# ') and b'\r\n\r\n' in b else 0)
        return b[:pos]+block.encode('utf8')+b[pos:]
    if block.splitlines()[0].encode() not in before:
        work.write_bytes(insert(before))
    else:
        assert block.encode('utf8') in before, 'Existing delivery block differs'
    staged=insert(git('show','HEAD:'+path))
    blob=git('hash-object','-w','--stdin',data=staged).decode().strip()
    mode=git('ls-files','-s','--',path).decode().split()[0]
    git('update-index','--cacheinfo',mode+','+blob+','+path)
    partial[path]={'blob':blob,'preserved_worktree_before_sha256':hashlib.sha256(before).hexdigest()}
paths=['godot/mafiozi_walk/'+p for p in ['scripts/main.gd','scripts/weapons/preview_weapon_cargo.gd','data/preview_updates.json']]
paths+=['docs/ai/COORDINATOR_24_MEMORY.md','docs/ai/COORDINATOR_24_HANDOFF.md','outputs/coordinator24_quality/candidate22/INTEGRATION.json']
for folder in ['outputs/coordinator24_cargo_escape','outputs/coordinator24_delivery24b']:
    for p in (root/folder).rglob('*'):
        if not p.is_file() or 'before' in p.parts or '__pycache__' in p.parts:continue
        if p.suffix.lower() not in ['.json','.gd','.py','.ps1','.md','.log','.png']:continue
        assert p.stat().st_size<1500000
        paths.append(p.relative_to(root).as_posix())
paths=sorted(set(paths))
git('add','-f','--',*paths)
record={'parent':'a498d8bcbfcd30bc1601aed10ad86c4a7fd855d9','full_paths':paths,'partial_document_blocks':partial,'scope':'Escape24b only; unrelated WIP preserved; no export binaries'}
record_path=root/'outputs/coordinator24_delivery24b/GIT_STAGE.json'
record_path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
git('add','-f','--',record_path.relative_to(root).as_posix())
print(json.dumps({'files':len(paths)+len(partial)+1,'partial':list(partial)}))
