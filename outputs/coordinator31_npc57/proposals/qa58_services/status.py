import json,pathlib,sys
OUT=pathlib.Path(__file__).resolve().parent
RUN=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else OUT/'runs/merged58_services_graphical02'
lines=(RUN/'stdout.log').read_text(encoding='utf-8-sig').splitlines()
progress=[]
for line in lines:
    if line.startswith('SERVICES56_PROGRESS '):
        try:progress.append(json.loads(line.split(' ',1)[1]))
        except json.JSONDecodeError:pass
row=progress[-1] if progress else {}
selected={}
for kind,value in row.get('selected',{}).items():
    selected[kind]={key:value.get(key) for key in ['source_id','completed','hospital','route_phase','travel_m','hp','position']}
    debug=value.get('drive_debug',{})
    selected[kind].update(drive_phase=debug.get('drive_phase'),guide_m=debug.get('guide',{}).get('metres'),reason=debug.get('reason'))
print(json.dumps({'elapsed_s':row.get('elapsed_s'),'selected':selected,'stderr_bytes':(RUN/'stderr.log').stat().st_size,'terminal':(RUN/'RUN.json').exists()}))
print('\n'.join(line[:400] for line in lines if line.startswith(('SERVICES56_SHOT','SERVICES56_TERMINAL','SERVICES56_FINISH','SERVICES56_DONE'))))
