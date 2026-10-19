from pathlib import Path
import json,statistics
O=Path('D:/MafioziCombat31/bow_motion53')
for run in ['before02','after','graphical']:
 p=O/run/'result.json'
 if not p.exists():continue
 a=json.loads(p.read_text());print(run)
 for phase in ['back_held','back_aimed','back_released']:
  rows=[x for x in a['rows'] if x['phase']==phase][40:]
  if not rows:continue
  print(phase,'n',len(rows),'correction',round(max(x['frame_correction_degrees'] for x in rows),3),'renderstep',round(max(x['render_step_degrees'] for x in rows),3),'camera error',round(statistics.mean(x['camera_error_degrees'] for x in rows),3),'distance',rows[-1]['position'][2]-rows[0]['position'][2])
