"""Install exact accepted cursor import metadata/cache, without importing unrelated WIP."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2];out=root/'outputs/coordinator23_delivery23h'
promotion=json.loads((out/'PROMOTION.json').read_text(encoding='utf8'))
source=root/'outputs/coordinator23_quality'/promotion['candidate']/'godot/mafiozi_walk';dest=root/'godot/mafiozi_walk'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
names=['assets/ui/cursor_arrow.svg.import','assets/ui/cursor_hand.svg.import','scripts/ui/walk_cursor.gd.uid']
for name in names[:2]:
    text=(source/name).read_text(encoding='utf8');cached=re.search(r'^path="res://([^\"]+)"',text,re.M).group(1)
    assert cached.startswith('.godot/imported/cursor_');names.append(cached)
rows=[]
for name in names:
    src=source/name;dst=dest/name
    assert src.exists() and (not dst.exists() or sha(dst)==sha(src)),name
    dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(src.read_bytes())
    rows.append({'path':'godot/mafiozi_walk/'+name,'sha256':sha(dst),'cache':name.startswith('.godot/')})
(out/'CURSOR_IMPORTS.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Exact cursor metadata and cache installed',len(rows))
