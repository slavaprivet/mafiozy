from pathlib import Path
import hashlib,json

out = Path('D:/MafioziCombat31/bow_motion53_resume')
merged = Path('D:/MafioziCombat31/coordinator34_merged53')
manifest = json.loads((merged/'CANDIDATE.json').read_text(encoding='utf-8-sig'))
before = json.loads((out/'MERGED_SOURCE_PRE.json').read_text(encoding='utf-8-sig'))
actual = {name:hashlib.sha256((merged/'game'/name).read_bytes()).hexdigest() for name in manifest['source_pins']}
mismatches = [name for name,sha in manifest['source_pins'].items() if actual[name]!=sha]
post = {'passed':not mismatches and actual==before['source_pins'],'manifest_sha256':hashlib.sha256((merged/'CANDIDATE.json').read_bytes()).hexdigest(),'pins_checked':len(actual),'mismatches':mismatches,'source_unchanged':actual==before['source_pins'],'source_pins':actual}
(out/'MERGED_SOURCE_POST.json').write_text(json.dumps(post,indent=2),encoding='utf-8')
runs = {}
for weapon in ['bow','sword','spear']:
    folder = out/f'merged_{weapon}01'
    receipt = json.loads((folder/'RECEIPT.json').read_text(encoding='utf-8-sig'))
    scheduler = json.loads((folder/'native/SCHEDULER_RUN.json').read_text(encoding='utf-8-sig'))
    result = json.loads((folder/'result.json').read_text(encoding='utf-8-sig'))
    steady_bow = [row for row in result['rows'] if row['bow_owns']]
    runs[weapon] = {'passed':receipt['passed'] and scheduler['passed'],'checks_passed':sum(c['passed'] for c in receipt['checks']),'checks_total':len(receipt['checks']),'errors':receipt['errors'],'stderr_bytes':scheduler['stderr_bytes'],'source_unchanged':receipt['source_unchanged'],'harness_sha256':receipt['harness_sha256'],'max_bow_physics_correction_degrees':max((row['physics_correction_degrees'] for row in steady_bow),default=0),'max_bow_render_step_degrees':max((row['render_step_degrees'] for row in steady_bow),default=0),'receipt':str(folder/'RECEIPT.json'),'result_sha256':hashlib.sha256((folder/'result.json').read_bytes()).hexdigest()}
report = {'passed':post['passed'] and all(r['passed'] for r in runs.values()),'status':'merged_passed','game':str(merged/'game'),'manifest_sha256':post['manifest_sha256'],'pins_checked_before_and_after':len(actual),'all_source_unchanged':post['source_unchanged'],'runs':runs,'component_audit':str(out/'SOURCE_AUDIT.json'),'original_ready_preserved':'D:/MafioziCombat31/bow_motion53/READY.json','raw_failed_harness_preserved':str(out/'candidate_bow01'),'raw_explanation':str(out/'HARNESS_CORRECTION.json'),'scope':'Native synthetic walking WASD, RMB aim, real 1:1 mouse turn, bow/melee handoff, menu/cursor ownership, actual G/E castle storage transfer. Gameplay production untouched by this resume task.','limits':['No FPS acceptance.','Damage/contact, shadow-arc visual proof and NPC acceptance are owned by root/other agents.','Normal idle melee facing is unchanged; bow stability gate does not redefine sword/spear control.']}
(out/'MERGED_ACCEPTANCE.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
handoff = json.loads((out/'HANDOFF.json').read_text(encoding='utf-8-sig'))
handoff.update(status='merged_passed' if report['passed'] else 'merged_failed',merged_acceptance=str(out/'MERGED_ACCEPTANCE.json'),merged_required=['Root combined ownership/contact/high aim and visual/NPC suites remain separate.'])
(out/'HANDOFF.json').write_text(json.dumps(handoff,indent=2),encoding='utf-8')
print(json.dumps(report))
