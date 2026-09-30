from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];base=root/'outputs/coordinator23_quality/candidate17';dst=root/'outputs/coordinator23_quality/candidate18'
assert not dst.exists();shutil.copytree(base,dst,ignore=shutil.ignore_patterns('exports'))
game=dst/'godot/mafiozi_walk';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((dst/'INTEGRATION.json').read_text(encoding='utf8'))
def edit(name,old,new):
 p=game/name;before=sha(p);s=p.read_text(encoding='utf8');assert s.count(old)==1
 p.write_text(s.replace(old,new),encoding='utf8',newline='\n')
 row=manifest['changes'].setdefault(name,{'before':before})
 row['after']=sha(p);row['source']='Root18 final guarded composition + blast blood'
proposal=root/'outputs/coordinator23_rpg23i/blood_proposal'
receipt=json.loads((proposal/'RECEIPT.json').read_text(encoding='utf8'))
assert receipt['checks_total']==118 and receipt['status']=='FROZEN_READY_NATIVE118_PASS_GPU_PENDING'
for row in receipt['files']:
 p=game/row['path'];source=proposal/'files'/row['path']
 assert sha(p)==row['before_sha256'] and sha(source)==row['after_sha256']
 shutil.copy2(source,p);manifest['changes'][row['path']]={'before':row['before_sha256'],'after':sha(p),'source':str(source.relative_to(root))}
edit('scripts/weapons/rpg_effects.gd','\tvar projectile: Dictionary = shot.projectiles[0]','\tif not shot.projectiles[0] is Dictionary: return {"ok":false,"reason":"projectile_shape"}\n\tvar projectile: Dictionary = shot.projectiles[0]')
edit('scripts/npc_visual/npc_local_preview_hit_owner.gd','\t\t_native_impulse_context={"event_id":accepted.event_id,"value":proposal,"uniform_only":true}','\t\t# Completed HP owns the bounded burst; anchor is still standing feet or\n\t\t# the existing physical pelvis before any new activation changes its mode.\n\t\tif blood!=null: blood.receive_blast(accepted.event_id,position,direction)\n\t\t_native_impulse_context={"event_id":accepted.event_id,"value":proposal,"uniform_only":true}')
notes=game/'data/preview_updates.json';before=sha(notes)
value=json.loads(notes.read_text(encoding='utf8'))
value.update(title='30.09 · Взрыв РПГ · 23i',updated_at='2026-09-30T15:30:00+03:00',runtime_revision='s01-20260930-quality23i')
value['items']=[
 'Q — арсенал. РПГ взрывается при попадании: урон ближайшим жителям, кровь и физическое падение. R — перезарядка.',
 'ЛКМ — выстрел, ПКМ — прицел. При движении ракета учитывает разброс оружия. C/Z — присесть/лечь.',
 'Наведите камеру на оружие в открытом багажнике: подсветка и E — взять. Без наведения E открывает или закрывает крышку.',
 'F — содержимое багажника. Карточка + E или «Взять» сразу возвращает управление. G — положить; вдали от машины G/E — бросить/подобрать.',
 'В квартале три жителя. Урон РПГ игроку, машинам и зданиям ещё не подключён. Повторный взрыв пока не толкает уже лежащее тело.'
]
notes.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
manifest['changes']['data/preview_updates.json']={'before':before,'after':sha(notes),'source':'Root truthful23i runtime notes'}
manifest.update(parent='candidate17',base_accepted='candidate16',status='FROZEN18 authentic RPG + bounded receipt blood; compiled/GPU acceptance pending')
(dst/'INTEGRATION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('candidate18 frozen',len(manifest['changes']),'scoped paths')
