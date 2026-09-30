"""Decode changed RSCC scene payloads read-only; no Godot/resource instantiation."""
from pathlib import Path
from compression import zstd
import hashlib,json,math,struct

root=Path(__file__).resolve().parents[3]
out=Path(__file__).parent
sha=lambda b:hashlib.sha256(b).hexdigest()
paths=[root/'outputs/coordinator23_quality/candidate16/godot/mafiozi_walk/exports/win64/s01-20260930-quality23h/MafioziPreview.pck',root/'outputs/coordinator24_quality/candidate20/godot/mafiozi_walk/exports/win64/s01-20260930-quality24a/MafioziPreview.pck']
def unpack(path):
    data=path.read_bytes();head=struct.unpack_from('<6I2Q',data);pos=head[-1]
    count,=struct.unpack_from('<I',data,pos);pos+=4;files={}
    for _ in range(count):
        length,=struct.unpack_from('<I',data,pos);pos+=4
        name=data[pos:pos+length].rstrip(b'\0').decode();pos+=length
        offset,size,digest,flags=struct.unpack_from('<QQ16sI',data,pos);pos+=36
        payload=data[head[-2]+offset:head[-2]+offset+size]
        assert not flags and hashlib.md5(payload).digest()==digest
        files[name]=payload
    return files
def decode(data):
    if data[:4]==b'RSRC':return data[4:]
    assert data[:4]==b'RSCC'
    mode,block,total=struct.unpack_from('<3I',data,4);assert mode==2
    count=math.ceil(total/block);lengths=struct.unpack_from('<'+'I'*count,data,16)
    at=16+count*4;parts=[]
    for size in lengths:parts.append(zstd.decompress(data[at:at+size]));at+=size
    result=b''.join(parts);assert len(result)==total
    return result
packs=[unpack(p) for p in paths]
closure=json.loads((out/'CARGO20_CLOSURE.json').read_text(encoding='utf8'))
rows=[]
for name in closure['unexpected_payloads']:
    before,after=[decode(p[name]) for p in packs]
    assert len(before)==len(after)
    assert before.count(b'node_ids\0')==after.count(b'node_ids\0')==1
    key=before.index(b'node_ids\0');assert after.index(b'node_ids\0')==key
    kind,count=struct.unpack_from('<II',before,key+9)
    assert (kind,count)==struct.unpack_from('<II',after,key+9) and kind==32
    regions=[{'name':'PackedScene node_ids int32 array','offset':key+17,'length':count*4,'entries':count}]
    if name.endswith('-main.scn'):
        resource=b'res://scripts/main.gd\0'
        assert before.count(resource)==after.count(resource)==1
        uid=before.index(resource)+len(resource);assert after.index(resource)+len(resource)==uid
        regions.append({'name':'main.gd external-resource UID','offset':uid,'length':8})
    normalized=[bytearray(before),bytearray(after)]
    for region in regions:
        start=region['offset'];end=start+region['length']
        region['before_hex']=before[start:end].hex();region['after_hex']=after[start:end].hex()
        for data in normalized:data[start:end]=bytes(region['length'])
    assert normalized[0]==normalized[1],name
    rows.append({'payload':name,'decompressed_bytes':len(before),'different_bytes':sum(a!=b for a,b in zip(before,after)),'decompressed_before_sha256':sha(before),'decompressed_after_sha256':sha(after),'identical_after_only_named_metadata_removed':True,'normalized_sha256':sha(normalized[0]),'regions':regions})
result={'status':'ALL_SEVEN_SCENE_DIFFS_EXPLAINED_METADATA_ONLY','scope':'Exact original16 vs first20 PCK payload decoding; no engine or tests. No gameplay entity IDs changed. Preserve accepted import cache and script UID sidecars for final byte-identical asset closure if possible.','baseline_pack_sha256':sha(paths[0].read_bytes()),'candidate20_first_pack_sha256':sha(paths[1].read_bytes()),'scenes':rows}
(out/'CARGO20_METADATA_DRIFT.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'status':result['status'],'count':len(rows),'different_bytes':[{'payload':v['payload'],'different_bytes':v['different_bytes'],'normalized':v['identical_after_only_named_metadata_removed']} for v in rows]},ensure_ascii=False,indent=2))
