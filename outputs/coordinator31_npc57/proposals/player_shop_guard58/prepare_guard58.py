from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent;GAME=HERE.parents[1]/'game'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rel='scripts/shop/player_shop_host.gd';base=GAME/rel
before=base.read_text(encoding='utf-8-sig')
anchor='func _available(item_id: String) -> Dictionary:\n'
assert before.count(anchor)==1
after=before.replace(anchor,anchor+'\t# Revalidate on the transaction stack; modal closure runs later in _process.\n\tif _physical_store_mode() and not _physical_cashier_available():\n\t\treturn {"ok": false, "reason": "store_unavailable"}\n')
anchor='\t\t\t"unknown_item":\n'
assert after.count(anchor)==1
after=after.replace(anchor,'\t\t\t"store_unavailable":\n\t\t\t\ttext = "Магазин временно закрыт"\n'+anchor)
target=HERE/'patch'/rel;target.parent.mkdir(parents=True,exist_ok=True)
assert not target.exists();target.write_text(after,encoding='utf-8')
flat={rel:{'base_sha256':sha(base),'candidate_sha256':sha(target)}}
(HERE/'PATCH.json').write_text(json.dumps(flat,indent=2)+'\n',encoding='utf-8')
(HERE/'PATCH.diff').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='base/'+rel,tofile='patch/'+rel)),encoding='utf-8')
print(json.dumps(flat))
