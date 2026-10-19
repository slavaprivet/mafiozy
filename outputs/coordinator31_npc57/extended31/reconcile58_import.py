"""Record the four reviewed UID additions from the first guarded editor import."""
import json,re
from stage58 import HERE,ROOT,GAME,FROZEN,read,save,pins,sha

prior=HERE/'stage58_01'
before=read(prior/'SOURCE_BEFORE.json');after=read(prior/'SOURCE_AFTER.json')
expected={
    'scripts/hospital/npc_door_clearance31.gd.uid',
    'scripts/city/runtime/npc_wait_cohort56.gd.uid',
    'scripts/navigation/npc_passage31.gd.uid',
    'scripts/cpu_profile56.gd.uid',
}
changed={p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)}
assert changed==expected and pins(GAME)==after
assert before==read(HERE.parent/'INTEGRATION_door58_01.json')['source_pins']
for path in expected:
    assert path not in before and path[:-4] in before
    assert re.fullmatch(r'uid://[a-z0-9]+\n',(GAME/path).read_text(encoding='utf-8'))
assert pins(FROZEN)==read(FROZEN.parent/'ASSEMBLY.json')['source_pins']
assert read(ROOT/'godot/current_version.json')==read(FROZEN.parent/'PROPOSED_CURRENT.json')
receipt=read(prior/'RESULT.json')
assert receipt['exit_code']==0 and not (prior/'stderr.log').stat().st_size
assert receipt['passed'] is False and 'Unexpected import source change' in receipt['error']
output=HERE/'IMPORT_RECOVERY58.json';assert not output.exists()
save(output,{'source_pins':after,'reviewed_additions':sorted(expected),
    'previous_guarded_failure':str(prior/'RESULT.json'),'previous_receipt_sha256':sha(prior/'RESULT.json'),
    'production_scripts_unchanged_by_import':True,'native_reimport_required':True,
    'gameplay_acceptance_pending':True})
print(json.dumps({'source_count':len(after),'reviewed_uid_additions':sorted(expected)}))
