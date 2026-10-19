from pathlib import Path
import json
O=Path(__file__).parent.resolve()
D=O/'raw_queue_rejected';D.mkdir(exist_ok=False)
assert D.resolve().parent==O
for group in ['CORE','VISUAL']:
    suite=O/(group+'_SUITE.json')
    for row in json.loads(suite.read_text()):
        src=(O/row['name']).resolve();dst=D/row['name']
        assert src.parent==O and dst.resolve().parent==D.resolve() and src.name!='game'
        receipt=json.loads((src/'native/SCHEDULER_RUN.json').read_text())
        assert receipt.get('error')=='Queue wait must be in (0,600] seconds'
        src.rename(dst)
    suite.rename(D/suite.name)
(D/'EXPLANATION.json').write_text(json.dumps({'reason':'Runner requested queue wait900 seconds; scheduler maximum600. Engine was never started. Runner corrected to600; production source and fixture assertions unchanged.'},indent=2))
