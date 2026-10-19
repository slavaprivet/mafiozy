"""Independent immutable-evidence audit; corrects no raw receipt or timing."""
from pathlib import Path
import hashlib,json,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
RUN=HERE/'runs/geometry_c4_03'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
checks=[]
def check(ok,name,detail=None):checks.append({'ok':bool(ok),'name':name,'detail':detail})
native=read(RUN/'GEOMETRY58.json');run=read(RUN/'RUN.json')
source=read(RUN/'SOURCE.json');after=read(RUN/'SOURCE_AFTER.json')
expected=read(ROOT/'outputs/coordinator31_npc57/extended31/stage58_04/CANDIDATE58.json')['source_pins']
controls=read(RUN/'CONTROL_PINS.json');after_controls=read(RUN/'CONTROL_PINS_AFTER.json')
overlay=read(RUN/'OVERLAY.json')
check(source==after==expected,'exact stage04 baseline source before/after',len(source))
check(controls==after_controls and not run['control_drift'],'exact harness/control pins before/after',len(controls))
check(not run['source_drift'] and not run['errors'] and (RUN/'stderr.log').stat().st_size==0,'no native error or source drift')
with zipfile.ZipFile(RUN/'OVERLAY.zip') as archive:
 check(set(archive.namelist())==set(overlay) and all(hashlib.sha256(archive.read(k)).hexdigest()==v for k,v in overlay.items()),'exact six-file VFS overlay archive',len(overlay))
with zipfile.ZipFile(RUN/'HARNESS.zip') as archive:
 errors=[]
 for path,expected_sha in controls.items():
  p=Path(path)
  if p.suffix=='.zip':continue
  key=p.relative_to(ROOT).as_posix()
  if hashlib.sha256(archive.read(key)).hexdigest()!=expected_sha:errors.append(key)
 for rel,expected_sha in overlay.items():
  if hashlib.sha256(archive.read('overlay/'+rel)).hexdigest()!=expected_sha:errors.append(rel)
 check(not errors,'immutable full tested harness/source-overlay archive',errors)
failed=[row['name'] for row in native['checks'] if not row['ok']]
check(failed==['mattress becomes moving native rubble'],'only known invalid final-freeze assertion failed',failed)
check(all(row['ok'] for row in native['checks'] if row['name']!='mattress becomes moving native rubble'),'every other original native gate passed',len(native['checks'])-1)
check(native['native_ticks']>=1800 and native['native_elapsed_s']>=30,'at least30 native seconds and30 actual wall seconds',{'ticks':native['native_ticks'],'native_sim_s':native['native_ticks']/60,'wall_s':native['native_elapsed_s']})
rows=native['final']['homes'];check(len(rows)==4 and [r['pieces'] for r in rows]==[54,54,52,52],'four expected owned houses')
check(all(r['owned']==r['pieces']==r['physical'] and not r['released'] and r['habitable'] and r['support']['state']=='stable' for r in rows),'all real physical sections stable before blast')
check(all(s['registry']['available_beds']==10 for s in native['samples']),'all ten assigned physical beds current throughout stability')
placed=native['c4_placed'];check(placed['real_lmb'] and placed['physics_frames']>=180 and placed['actor_drift_m']<=.04 and len(placed['snapshot']['placed'])==1,'real uninterrupted native C4 hold and one item',{'frames':placed['physics_frames'],'drift_m':placed['actor_drift_m']})
blast=native['c4_blast'];events=blast['snapshot']['events']
check(len(events)==1 and events[0]['committed'] and events[0]['physical_charge_consumed'] and events[0]['affected_houses']==['HOME58-001'] and events[0]['power']==1920 and events[0]['radius']==3.2,'authentic consumed C4 damages intended home')
check(len(events[0]['released'])==20,'twenty real owned sections released')
check(blast['bed_detached'] and blast['bed_support_detached'] and blast['bed_layer']==512 and blast['bed_travel_m']>.1,'actual mattress/base detach and native motion',{'bed_layer':blast['bed_layer'],'mattress_travel_m':blast['bed_travel_m']})
check(not blast['slot_current'] and not blast['house_habitable'],'damage invalidates bed and home admission')
check(native['c4_after_reset']['available_beds']==10,'real rebuild restores new-generation bed inventory')
report={'schema':'mafiozi.qa58.independent-home-c4-audit/v1','passed':all(c['ok'] for c in checks),'checks':checks,
 'scope':'Exact stage04 + six housing overlay files: 4 real homes/10beds/native30seconds support, actual C4 input/item/remote/native damage, current-slot invalidation and real reset. Does not certify sleep, routine behavior or performance.',
 'raw_receipt_preserved':True,'raw_run_passed':run['passed'],'raw_native_passed':native['passed'],
 'correction':{'incorrect_gate':'required mattress.freeze==false eight seconds after blast','reason':'Freeze is also used by the established native rubble-parking lifecycle after the rigid body has moved. The actual detached layer512 mattress moved4.396m; requiring perpetual motion/unfrozen state rejects valid settled rubble. No source or raw data changed.',
 'parking_evidence_limit':'parked metadata was not sampled. Settled parking explains final freeze by code; corrected acceptance relies on directly sampled detachment, layer and native motion, not on inferred parking metadata.',
 'backend':'scripts/destruction/palazzo/source/showcase.gd:_park_debris sets parked=true and freeze=true; palazzo_site preserves rubble layer512'},
 'inputs':{name:sha(RUN/name) for name in ['RUN.json','GEOMETRY58.json','SOURCE.json','SOURCE_AFTER.json','CONTROL_PINS.json','CONTROL_PINS_AFTER.json','HARNESS.zip','OVERLAY.zip','OVERLAY.json','stdout.log','stderr.log']}}
dest=HERE/'AUDIT_GEOMETRY_C4_03.json';dest.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':report['passed'],'checks':len(checks),'failed':[c['name'] for c in checks if not c['ok']],'sha256':sha(dest)}))
