"""Root-operated only: two sequential offscreen GPU runs; 38s cap each, no game-process cleanup."""
import argparse, hashlib, json, os, pathlib, subprocess, sys, time
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EXPECTED='4a2392c044eff5163e5fa4c4a95dbdcd5da8467c9fce3d3b1b7c825168bbe1bf'
# Explicit root-approved owner handoff. No wildcard/path-only allowlist.
AUDITED_DELTAS={} # 23c already includes floor recovery; no exceptions authorized for this pair.
p=argparse.ArgumentParser()
p.add_argument('--engine',default=str(pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'))
p.add_argument('--baseline-pck',default=str(ROOT/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23c-play/MafioziPreview.pck'))
p.add_argument('--candidate-pck',required=True,help='Candidate exported PCK; require adjacent build_receipt.json unless --candidate-receipt supplied')
p.add_argument('--candidate-receipt')
p.add_argument('--candidate',default=str(ROOT/'outputs/coordinator23_quality/candidate01/godot/mafiozi_walk'))
p.add_argument('--tag',default=time.strftime('%Y%m%d_%H%M%S'))
p.add_argument('--compare-only',action='store_true')
p.add_argument('--include-current',action='store_true',help='Also capture exact 23d PCK already bound by loaded_23c_to_23d_01/MANIFEST.json')
a=p.parse_args()
folder=HERE/a.tag
if pathlib.Path(a.engine).stem.endswith('_console'):raise SystemExit('Use GUI executable directly to prevent orphan engine children')
if not a.compare_only:
    if folder.exists():raise SystemExit('Refuse overwriting a previous run: choose a fresh --tag')
    baseline=pathlib.Path(a.baseline_pck).resolve();candidate=pathlib.Path(a.candidate).resolve()
    if hashlib.sha256(baseline.read_bytes()).hexdigest()!=EXPECTED:raise SystemExit('Not accepted exact quality23c-play PCK')
    candidate_pack=pathlib.Path(a.candidate_pck).resolve() if a.candidate_pck else None
    candidate_provenance=None
    if candidate_pack:
        cr=pathlib.Path(a.candidate_receipt).resolve() if a.candidate_receipt else candidate_pack.parent/'build_receipt.json'
        receipt=json.loads(cr.read_text(encoding='utf-8-sig'));candidate_sha=hashlib.sha256(candidate_pack.read_bytes()).hexdigest()
        if not receipt.get('sourceInputsUnchangedDuringExport') or not any(x.get('filename')==candidate_pack.name and x.get('sha256')==candidate_sha for x in receipt['artifacts']):raise SystemExit('Candidate receipt does not bind exact PCK')
        candidate_provenance={'pck':str(candidate_pack),'pck_sha256':candidate_sha,'receipt':str(cr),'receipt_sha256':hashlib.sha256(cr.read_bytes()).hexdigest(),'canonical_inputs':{'res://'+row['path']:row['sha256'] for row in receipt['inputs']},'mode':receipt.get('mode'),'engine':receipt.get('engineVersion'),'architecture':receipt.get('architecture'),'compiled_scripts':any(x.endswith('.gdc') for x in receipt.get('packInventory',{}).get('paths',[]))}
        source_receipt=None
    else:
        if not (candidate/'project.godot').is_file():raise SystemExit('Missing candidate project')
        source_receipt=json.loads((candidate.parents[1]/'SOURCE.json').read_text(encoding='utf-8-sig'))
        if source_receipt.get('baseline_pck')!=EXPECTED or source_receipt.get('baseline_inputs')!=141:raise SystemExit('Candidate lacks accepted baseline SOURCE141 receipt')
    receipt_path=baseline.parent/'build_receipt.json'
    if hashlib.sha256(receipt_path.read_bytes()).hexdigest()!='4da06fc50d2ef678b279673afb544a0aeb2b489843cdd8a167fb120febfdc2f3':raise SystemExit('Baseline receipt differs from pinned quality23c-play receipt')
    baseline_receipt=json.loads(receipt_path.read_text(encoding='utf-8-sig'))
    if not baseline_receipt.get('sourceInputsUnchangedDuringExport') or not any(x.get('filename')=='MafioziPreview.pck' and x.get('sha256')==EXPECTED for x in baseline_receipt['artifacts']):raise SystemExit('Baseline receipt does not bind exact PCK')
    canonical={'res://'+row['path']:row['sha256'] for row in baseline_receipt['inputs']}
    if len(canonical)!=185:raise SystemExit('Expected185 exact quality23c-play source inputs')
    if not candidate_provenance:raise SystemExit('Targeted capture requires candidate PCK')
    ci=candidate_provenance['canonical_inputs']
    prefixes=('res://scripts/npc_visual/','res://scripts/navigation/','res://assets/npc_visual/','res://assets/buildings/','res://assets/decor/')
    protected={path for path in set(canonical)|set(ci) if path.startswith(prefixes)}|{'res://data/block.json','res://assets/hero.glb','res://scripts/preview_population.gd'}
    if any(canonical.get(path)!=ci.get(path) for path in protected):raise SystemExit('Unknown protected dependency mismatch')
    if any(candidate_provenance.get(k)!=v for k,v in {'mode':baseline_receipt.get('mode'),'engine':baseline_receipt.get('engineVersion'),'architecture':baseline_receipt.get('architecture'),'compiled_scripts':True}.items()):raise SystemExit('Expected matching compiled release forms')
    folder.mkdir()
    manifest={'baseline_pck':str(baseline),'baseline_sha256':EXPECTED,'baseline_source_provenance':{'receipt':str(receipt_path),'receipt_sha256':hashlib.sha256(receipt_path.read_bytes()).hexdigest(),'canonical_inputs':canonical,'mode':baseline_receipt.get('mode'),'engine':baseline_receipt.get('engineVersion'),'architecture':baseline_receipt.get('architecture'),'compiled_scripts':any(x.endswith('.gdc') for x in baseline_receipt.get('packInventory',{}).get('paths',[]))},'candidate_form':'compiled_pck' if candidate_pack else 'raw_project','candidate_source_provenance':candidate_provenance,'candidate':str(candidate),'candidate_source_receipt':source_receipt,'harness_sha256':hashlib.sha256((HERE/'cold_warm_capture.gd').read_bytes()).hexdigest(),'settings':'1280x720 Forward+; TAA; MSAA4x; medium directional shadows; uncapped/noVSync','window':'offscreen -32000,-32000; NO_FOCUS; no physical cursor capture','baseline_version':'quality23c-play','scope':'Root must stop the existing GPU game before invoking; no freeze/resident/collider reductions.'}
    (folder/'MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    current_pack=None
    if a.include_current:
        accepted=json.loads((HERE/'loaded_23c_to_23d_01/MANIFEST.json').read_text(encoding='utf8'))['candidate_source_provenance']
        current_pack=pathlib.Path(accepted['pck'])
        if hashlib.sha256(current_pack.read_bytes()).hexdigest()!=accepted['pck_sha256'] or hashlib.sha256(pathlib.Path(accepted['receipt']).read_bytes()).hexdigest()!=accepted['receipt_sha256']:raise SystemExit('Current23d does not match exact prior accepted manifest')
        manifest['current_source_provenance']=accepted
        (folder/'MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    start=time.perf_counter()
    runs=[('baseline',['--main-pack',str(baseline)]),('candidate',['--main-pack',str(candidate_pack)] if candidate_pack else ['--path',str(candidate)])]
    if current_pack:runs.insert(1,('current',['--main-pack',str(current_pack)]))
    for label,args in runs:
        output=folder/(label+'.json')
        command=[a.engine,*args,'--rendering-method','forward_plus','--resolution','1280x720','--position','-32000,-32000','--script',str(HERE/'cold_warm_capture.gd'),'--','--bench-label='+label,'--bench-out='+str(output)]
        with (folder/(label+'.log')).open('w',encoding='utf8') as log:
            # Launch the GUI executable directly: timeout kills the actual engine, no orphan GUI child.
            # Both windows are offscreen and NO_FOCUS; no raw demo or cursor capture.
            process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            try:returncode=process.wait(timeout=38)
            except subprocess.TimeoutExpired:
                process.kill();process.wait();returncode=-1
        if not output.exists():
            (folder/(label+'_FAILED.json')).write_text(json.dumps({'returncode':returncode,'no_result':True}))
            print(label+' failed to save result; see '+str(folder/(label+'.log')))
    (folder/'WALL.json').write_text(json.dumps({'both_runs_seconds':time.perf_counter()-start}))

summary={"scope":"Targeted timing/event evidence only, not automatic regression approval","sides":{}}
for label in (['baseline','current','candidate'] if a.include_current else ['baseline','candidate']):
    file=folder/(label+'.json')
    if not file.exists():summary['sides'][label]={'missing':True};continue
    data=json.loads(file.read_text(encoding='utf8'));rows=[]
    for phase in data['phases']:
        trace=phase['trace'];peaks=sorted(trace,key=lambda x:x['wall_ms'],reverse=True)[:5]
        annotated=[]
        for peak in peaks:
            absolute=phase['capture_start_usec']+int(peak['end_ms']*1000)
            annotated.append({'frame':peak,'shots_within_100ms':[s for s in phase['shot_events'] if abs(s['usec']-absolute)<100000],'mark_observations_within_100ms':[s for s in phase['mark_changes'] if abs(s['observed_usec']-absolute)<100000]})
        rows.append({'name':phase['name'],'wall':phase['frame_ms'],'gpu':phase['gpu_ms'],'shots':phase['shots'],'pipeline_before':phase['pipeline_before'],'pipeline_after':phase['pipeline_after'],'top5':annotated})
    summary['sides'][label]={'valid':data['valid'],'errors':data['errors'],'phases':rows}
(folder/'COLD_WARM_ANALYSIS.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
print(json.dumps(summary,indent=2))
