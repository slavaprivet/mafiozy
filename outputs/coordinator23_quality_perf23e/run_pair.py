"""Root-operated only: two sequential offscreen GPU runs; 38s cap each, no game-process cleanup."""
import argparse, hashlib, json, os, pathlib, subprocess, sys, time
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EXPECTED='4a2392c044eff5163e5fa4c4a95dbdcd5da8467c9fce3d3b1b7c825168bbe1bf'
# Explicit root-approved owner handoff. No wildcard/path-only allowlist.
AUDITED_DELTAS={('res://assets/npc_visual/death_eyes/assets_manifest.json', None, '90d20822a859a7a19ff5785772d0dcbde3bbfb8ff15a40636f5c290af5b4131f'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_169_hair_closed.res', None, '49ce7b368944d9f89c13b4ba2a595a4f43ff2f2e7497da6f68b8f6c97dc4a1b1'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_169_skin_closed.res', None, '59d3393889e4c14fbe38af5e777e0fc38372e52948c86ce65070e7225873614b'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_252_hair_closed.res', None, 'f1697dd64ba5a82886defb22e0d7c93dfae33b44368264e4651c1ca17bb70956'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_252_skin_closed.res', None, '9a330dc9dce45b62d610cd06c274cfe50d127bee26c08a0cd0623c55405acb9d'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_72_hair_closed.res', None, '896a894c664112760b950a4a454c810228609dfe51858a087e72d4ae10df05e5'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://assets/npc_visual/death_eyes/npc_resident_72_skin_closed.res', None, '7ffbbad4c0ad98bc8c636fced8d3c648cba095419d8f3edf96004a4daf4faf85'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/npc_visual/npc_blood_adapter.gd', None, 'ee76e46c2a6c044814f1971c62881bee6501cab969b54b1b10db1c49e0f5b591'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/npc_visual/npc_blood_renderer.gd', None, '9c2ca54509f67302b570275fd5868c5309ac067776f0f922e4f5be90f0727873'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/npc_visual/npc_death_eyes.gd', None, '67971321ba296ba6e70a76a6f4a95ca55df3de34c2848e54b4a7e0ba552b978c'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/npc_visual/npc_local_preview_hit_owner.gd', '3cf0ee6b6fb667884a1538b63ca69edb7a62473c30a38138892ec2234eb42643', 'cd0f09b407ac76fb926bb9deae13a451cd3a9d112461426dfbac1825c7bf5c4c'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/npc_visual/npc_ragdoll_host.gd', 'c8e2aba4d9c57a25e7414422fa6c42a0069cc723f66b464fcacc3719a0f484b5', '59573587d7eac3c6e4911ff1279e0c683f2646be61bc2346be0c82e314850bb2'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner Artist23 exact delivered file; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/preview_population.gd', 'b6de096a67244772031375446c7e51d4aa772e636e3e39b18f1b2dc77a552e67', 'ec6a98758804b8d8f26fa5162e970baefedee3fa2bf8404048a0e556c8a4d366'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner root integration; runtime 3 NPC IDs/capsules/377 colliders remain required', ('res://scripts/weapons/weapon_projectiles.gd', '073cae755074dafc4154f04357a7301869765d7e80f576c216378dca5cb01df5', 'e1a1433b1f5df9c8aea116580e1a8443279401f2e65b832756eee18923552d27'): 'Root approved Artist23 13-gun ordinary hits/blood/death eyes integration; MERGE_PLAN SHA256 64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43; owner root integration; runtime 3 NPC IDs/capsules/377 colliders remain required'}
MERGE_PLAN_SHA256='64da24098ab59d0496e1fd6ffff3f114bde5d4901e7dee595c31f0f6971acf43'
p=argparse.ArgumentParser()
p.add_argument('--engine',default=str(pathlib.Path(os.environ['LOCALAPPDATA'])/'MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe'))
p.add_argument('--baseline-pck',default=str(ROOT/'godot/mafiozi_walk/exports/win64/s01-20260930-quality23c-play/MafioziPreview.pck'))
p.add_argument('--candidate-pck',required=True,help='Candidate exported PCK; require adjacent build_receipt.json unless --candidate-receipt supplied')
p.add_argument('--candidate-receipt')
p.add_argument('--candidate',default=str(ROOT/'outputs/coordinator23_quality/candidate01/godot/mafiozi_walk'))
p.add_argument('--tag',default=time.strftime('%Y%m%d_%H%M%S'))
p.add_argument('--compare-only',action='store_true')
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
    # Fail unknown workload source changes before spending a GPU run.
    ci=candidate_provenance['canonical_inputs']
    prefixes=('res://scripts/npc_visual/','res://scripts/navigation/','res://assets/npc_visual/','res://assets/buildings/','res://assets/decor/')
    protected={path for path in set(canonical)|set(ci) if path.startswith(prefixes)}|{'res://data/block.json','res://assets/hero.glb','res://scripts/preview_population.gd','res://scripts/weapons/weapon_projectiles.gd'}
    bad=[path for path in protected if canonical.get(path)!=ci.get(path) and (path,canonical.get(path),ci.get(path)) not in AUDITED_DELTAS]
    if bad:raise SystemExit('Unknown protected dependency changes: '+str(sorted(bad)))
    folder.mkdir()
    manifest={'baseline_pck':str(baseline),'baseline_sha256':EXPECTED,'baseline_source_provenance':{'receipt':str(receipt_path),'receipt_sha256':hashlib.sha256(receipt_path.read_bytes()).hexdigest(),'canonical_inputs':canonical,'mode':baseline_receipt.get('mode'),'engine':baseline_receipt.get('engineVersion'),'architecture':baseline_receipt.get('architecture'),'compiled_scripts':any(x.endswith('.gdc') for x in baseline_receipt.get('packInventory',{}).get('paths',[]))},'candidate_form':'compiled_pck' if candidate_pack else 'raw_project','candidate_source_provenance':candidate_provenance,'candidate':str(candidate),'candidate_source_receipt':source_receipt,'harness_sha256':hashlib.sha256((HERE/'loaded_bench.gd').read_bytes()).hexdigest(),'settings':'1280x720 Forward+; TAA; MSAA4x; medium directional shadows; uncapped/noVSync','window':'offscreen -32000,-32000; NO_FOCUS; no physical cursor capture','merge_plan_sha256':MERGE_PLAN_SHA256,'baseline_version':'quality23c-play','scope':'Root must stop the existing GPU game before invoking; no freeze/resident/collider reductions.'}
    (folder/'MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    start=time.perf_counter()
    for label,args in [('baseline',['--main-pack',str(baseline)]),('candidate',['--main-pack',str(candidate_pack)] if candidate_pack else ['--path',str(candidate)])]:
        output=folder/(label+'.json')
        command=[a.engine,*args,'--rendering-method','forward_plus','--resolution','1280x720','--position','-32000,-32000','--script',str(HERE/'loaded_bench.gd'),'--','--bench-label='+label,'--bench-out='+str(output)]
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
issues=[];notes=[];results={};accepted_source_changes=[]
for label in ['baseline','candidate']:
    file=folder/(label+'.json')
    if not file.exists():issues.append(label+': no output');continue
    result=results[label]=json.loads(file.read_text(encoding='utf-8-sig'))
    if not result.get('valid'):issues.append(label+': invalid '+str(result.get('errors')))
    log=(folder/(label+'.log')).read_text(encoding='utf8')
    if 'SCRIPT ERROR' in log or 'ERROR:' in log:issues.append(label+': engine errors in log')
comparisons=[]
if len(results)==2:
    b,c=results['baseline'],results['candidate']
    manifest=json.loads((folder/'MANIFEST.json').read_text(encoding='utf8'))
    canonical=manifest['baseline_source_provenance']['canonical_inputs']
    b['raw_export_inputs']=dict(b['inputs'])
    b['inputs']={name:canonical.get(name,sha) for name,sha in b['inputs'].items()}
    candidate_provenance=manifest.get('candidate_source_provenance')
    if manifest.get('candidate_form','raw_project')!='compiled_pck':issues.append('Build-form mismatch: baseline compiled PCK vs candidate raw project; memory/performance attribution not strictly comparable')
    else:
        if not candidate_provenance:issues.append('Missing candidate PCK receipt provenance')
        else:
            c['inputs']={name:candidate_provenance['canonical_inputs'].get(name,sha) for name,sha in c['inputs'].items()}
            for field in ['mode','engine','architecture','compiled_scripts']:
                if manifest['baseline_source_provenance'].get(field)!=candidate_provenance.get(field):issues.append('Export metadata differs: '+field)
    notes.append('Baseline source hashes resolved from exact PCK-bound build_receipt185 for quality23c-play; raw runtime export hashes retained in baseline.json. Provenance in MANIFEST.json.')
    if b['settings']!=c['settings']:issues.append('settings differ')
    if manifest.get('baseline_sha256')!=EXPECTED:issues.append('Manifest does not pin accepted quality23c-play baseline')
    if candidate_provenance:
        for role,prov in [('baseline',manifest['baseline_source_provenance']),('candidate',candidate_provenance)]:
            if prov.get('mode')!='release' or not prov.get('compiled_scripts'):issues.append(role+': expected compiled release PCK')
        source_delta=[{'path':path,'baseline_sha256':canonical.get(path),'candidate_sha256':candidate_provenance['canonical_inputs'].get(path)} for path in sorted(set(canonical)|set(candidate_provenance['canonical_inputs'])) if canonical.get(path)!=candidate_provenance['canonical_inputs'].get(path)]
        (folder/'SOURCE_DELTA.json').write_text(json.dumps(source_delta,indent=2),encoding='utf8')
    for side,data in [('baseline',b),('candidate',c)]:
        if data.get('cargo_summary',{}).get('count')!=14 or data.get('cargo_summary',{}).get('used_units')!=100 or data.get('cargo_summary',{}).get('capacity_units')!=100:issues.append(side+': expected real 14 cargo/100 units')

    if candidate_provenance:
        candidate_inputs=candidate_provenance['canonical_inputs']
        protected_prefixes=('res://scripts/npc_visual/','res://scripts/navigation/','res://assets/npc_visual/','res://assets/buildings/','res://assets/decor/')
        protected={path for path in set(canonical)|set(candidate_inputs) if path.startswith(protected_prefixes)}|{'res://data/block.json','res://assets/hero.glb','res://scripts/preview_population.gd','res://scripts/weapons/weapon_projectiles.gd'}
        mismatch=[]
        for path in sorted(protected):
            before,after=canonical.get(path),candidate_inputs.get(path)
            if before==after:continue
            key=(path,before,after)
            if key in AUDITED_DELTAS:accepted_source_changes.append({'path':path,'baseline_sha256':before,'candidate_sha256':after,'audit':AUDITED_DELTAS[key]})
            else:mismatch.append(path)
        if mismatch:issues.append('NPC/navigation/source geometry dependencies differ: '+str(mismatch))
        notes.append('Protected NPC/navigation/source geometry canonical dependencies checked: '+str(len(protected)))
    for name in ['res://data/block.json','res://scripts/preview_population.gd']:
        before,after=b['inputs'].get(name),c['inputs'].get(name)
        if not before or (before!=after and (name,before,after) not in AUDITED_DELTAS):issues.append('fixture input differs or missing: '+name)
    if b['inputs'].get('res://scripts/preview_player.gd')!=c['inputs'].get('res://scripts/preview_player.gd'):notes.append('Player implementation changed; camera/body geometry invariants are checked at runtime; costs include player changes.')
    bp={x['name']:x for x in b['phases']};cp={x['name']:x for x in c['phases']}
    if bp.keys()!=cp.keys():issues.append('phase sets differ')
    for name in sorted(bp.keys()&cp.keys()):
        x,y=bp[name],cp[name]
        for side,data in [('baseline',x),('candidate',y)]:
            proof=data.get('camera_proof',{})
            if proof.get('verified_rendered_frames',0)<data['frame_ms']['n']:issues.append(name+': missing per-render camera proof '+side)
            if proof.get('max_position_error',1)>.0001 or proof.get('max_basis_error',1)>.00001 or proof.get('max_fov_error',1)>.00001:issues.append(name+': camera normalization error '+side)
        for edge in ['before','after']:
            for side,data in [('baseline',x[edge]),('candidate',y[edge])]:
                if (data.get('npc'),data.get('buildings'),data.get('body_count'),data.get('collision_shape_count'))!=(3,8,377,377):issues.append(name+': '+side+' expected3NPC8buildings377bodies377shapes '+edge)
                if data.get('static_memory_bytes',0)<=0:issues.append(name+': missing memory checkpoint '+side+' '+edge)
            for field in ['npc','npc_fixture','buildings','source_colliders','body_count','collision_shape_count','transport','population','taa','msaa','camera_attached']:
                if x[edge][field]!=y[edge][field]:issues.append(name+': fixture '+field+' differs '+edge)
            for field in ['camera_fov','camera_yaw','camera_pitch']:
                if abs(x[edge].get(field,999)-y[edge].get(field,-999))>0.0001:issues.append(name+': '+field+' differs '+edge)
            for field in ['camera_forward','camera_basis_x']:
                if field not in x[edge] or field not in y[edge] or sum((u-v)**2 for u,v in zip(x[edge][field],y[edge][field]))**.5>.0001:issues.append(name+': camera basis differs '+edge)
            for field in ['camera','player']:
                if sum((u-v)**2 for u,v in zip(x[edge][field],y[edge][field]))**.5>.005:issues.append(name+': '+field+' differs >5mm '+edge)
        comparisons.append({'phase':name,'static_memory_edges':{'baseline_before':x['before'].get('static_memory_bytes'),'baseline_after':x['after'].get('static_memory_bytes'),'candidate_before':y['before'].get('static_memory_bytes'),'candidate_after':y['after'].get('static_memory_bytes')},'static_p50_delta_bytes':y['static_memory_bytes']['p50']-x['static_memory_bytes']['p50'],'gpu_p50_delta_ms':y['gpu_ms']['p50']-x['gpu_ms']['p50'],'gpu_p95_delta_ms':y['gpu_ms']['p95']-x['gpu_ms']['p95'],'wall_p50_delta_ms':y['frame_ms']['p50']-x['frame_ms']['p50'],'baseline_ms':x['frame_ms'],'candidate_ms':y['frame_ms'],'p95_delta_ms':y['frame_ms']['p95']-x['frame_ms']['p95'],'p95_ratio':y['frame_ms']['p95']/x['frame_ms']['p95'],'drawcalls':{'baseline':x['drawcalls'],'candidate':y['drawcalls']},'primitives':{'baseline':x['primitives'],'candidate':y['primitives']},'static_memory_bytes':{'baseline':x['static_memory_bytes'],'candidate':y['static_memory_bytes']},'vram_bytes':{'baseline':x['vram_bytes'],'candidate':y['vram_bytes']},'gpu_ms':{'baseline':x['gpu_ms'],'candidate':y['gpu_ms']},'shots':{'baseline':x['shots'],'candidate':y['shots']}})
report={'comparable':not issues,'comparison_standard':'Matching workload AND export form required; a raw-project/PCK exploratory pair is not strict regression evidence','issues':issues,'notes':notes,'accepted_source_changes':accepted_source_changes,'comparisons':comparisons,'note':'Short loaded rendering benchmark; no visual acceptance and no automatic regression approval.'}
(folder/'COMPARISON.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(0 if not issues else 2)
