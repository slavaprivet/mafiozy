from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
OLD=HERE.parent/'service_threat58'
records={}
for name in ['observer58.gd','observer_base58.gd','entry58.gd']:
    destination=HERE/name
    assert not destination.exists(),'Preserve generated final harness'
    data=(OLD/name).read_bytes();destination.write_bytes(data)
    records[name]=hashlib.sha256(data).hexdigest()
(HERE/'PREPARATION58.json').write_text(json.dumps({'source':'service_threat58 ordinary entry and unchanged native observers','copied_byte_pins':records,'overlay':False,'engine_started':False},indent=2)+'\n',encoding='utf-8')
print(json.dumps(records))
