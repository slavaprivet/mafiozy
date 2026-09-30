from pathlib import Path
import hashlib,json
base=Path(__file__).resolve().parent
load=lambda n:json.loads((base/n).read_text(encoding='utf8'))
raw=load('CARGO20_CLOSURE.json')
metadata=load('CARGO20_METADATA_DRIFT.json')
assert raw['pack_sha256']==metadata['candidate20_first_pack_sha256']=='634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5'
assert not raw['input_hash_errors'] and not raw['artifact_hash_errors'] and not raw['source_error_list']
assert not raw['baseline_payload_md5_errors'] and not raw['candidate_payload_md5_errors']
assert raw['export_source_count']==209 and raw['candidate_payload_count']==316
assert {v['payload'] for v in metadata['scenes']}==set(raw['unexpected_payloads'])
assert len(metadata['scenes'])==7 and all(v['identical_after_only_named_metadata_removed'] for v in metadata['scenes'])
assert raw['errors']==['unexpected_payload:'+p for p in raw['unexpected_payloads']]
final={
 'status':'VERIFIED_209_SOURCE_PINS_316_PAYLOADS_WITH_DECLARED_NONVISUAL_IMPORT_ID_DRIFT',
 'pack_sha256':raw['pack_sha256'],
 'baseline_pack_sha256':raw['expected_base_pack_sha256'],
 'source_inputs_verified':209,'embedded_payload_md5_verified':316,
 'source_changes':raw['source_changes'],
 'unchanged_packed_payloads':304,
 'intentional_packed_changes':['data/preview_updates.json','scripts/main.gdc','scripts/weapons/preview_weapon_cargo.gdc','scripts/weapons/preview_weapons.gdc'],
 'declared_internal_metadata_changes':['.godot/uid_cache.bin']+[v['payload'] for v in metadata['scenes']],
 'metadata_proof':'CARGO20_METADATA_DRIFT.json',
 'metadata_proof_sha256':hashlib.sha256((base/'CARGO20_METADATA_DRIFT.json').read_bytes()).hexdigest(),
 'metadata_scope':'All six imported GLB scenes differ only in PackedScene node_ids array contents. Exported main scene differs only in its one node_id and 8-byte external main.gd resource UID. All other decompressed serialized bytes are identical. Authored gameplay IDs, source GLBs/import configs and other code remain unchanged.',
 'main_notes_revision':raw['main_revision'],'notes_count':5,'rpg_damage_not_adopted':True,
 'export_receipt_sha256':raw['export_receipt_sha256'],'integration_sha256':raw['integration_sha256'],
 'errors':[],
 'limits':['Read-only independent review; no Godot, engine tests or GPU executed.','Metadata-normalized asset equality is not raw byte identity of all payloads.','Functional, actual focused input and performance acceptance remain Root24 responsibility.','Candidate20 and its export were not changed during this audit.'],
}
(base/'CARGO20_FINAL_AUDIT.json').write_text(json.dumps(final,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'status':final['status'],'pack_sha256':final['pack_sha256'],'errors':[]},indent=2))
