#!/usr/bin/env python3
"""Export the actual source ladder without rewriting the accepted interior file."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'godot/mafiozi_walk/scripts/tests/fixtures/printshop_ladder_source.json'


def generate(vendor):
    base = ROOT / 'tools/godot/export_preview_interior.py'
    spec = importlib.util.spec_from_file_location('accepted_interior_exporter', base)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    marker = '// Certification here is geometry, not service activation.'
    if module.NODE.count(marker) != 1:
        raise RuntimeError('Accepted exporter entry seam changed')
    prefix = module.NODE.split(marker)[0]
    suffix = r'''
scene.updateMatrixWorld(true);
const ladder=entry.storeys.ladder;
if(!ladder?.worldDescriptor)throw Error('Source ladder descriptor missing');
const source=ladder.worldDescriptor;
const point=p=>({x:p.x-origin.x,y:p.y-origin.y,z:p.z-origin.z});
const descriptor={id:source.id,lower:point(source.lower),upper:point(source.upper),normal:{...source.normal},right:{...source.right},width:source.width,rungSpacing:source.rungSpacing,yaw:source.yaw,path:source.path.map(point),apertureWidth:source.apertureWidth};
const interiorPath='godot/mafiozi_walk/data/printshop_interior.json';
const interiorBytes=read(interiorPath),interior=JSON.parse(interiorBytes);
if(interior.sourceId!==id||interior.assetSha256!==item.binding.sha256||JSON.stringify(interior.originM)!==JSON.stringify(block.originM))throw Error('Interior identity/frame mismatch');
const rails=interior.staticBodies.filter(b=>String(b.storeyPart??'').startsWith('Roof_Ladder_Rail_Collision_'));
if(rails.length!==2)throw Error('Expected two authored collision rails');
const hostPath='assets/maps/city_rebuild_v1/walk_preview.mjs',hostText=read(hostPath).toString('utf8');
const policyAnchor="if(nearLadder&&ladder?.id&&body.buildingEntryId===ladder.id&&!part.startsWith('Roof_Ladder_Rail_Collision'))continue";
if(!hostText.includes(policyAnchor)||!hostText.includes('ladderPathDistance(p,ladder)<=radius+.18'))throw Error('Source conditional collision policy changed');
const routeCollisionPolicy={sourcePath:hostPath,sourceSha256:digest(read(hostPath)),nearPathRadiusM:.33+.18,ignoredStaticBodyIndices:interior.staticBodies.flatMap((b,i)=>b.buildingEntryId===id&&!String(b.storeyPart??'').startsWith('Roof_Ladder_Rail_Collision')?[i]:[]),railStaticBodyIndices:interior.staticBodies.flatMap((b,i)=>String(b.storeyPart??'').startsWith('Roof_Ladder_Rail_Collision')?[i]:[]),ceilingQuery:'bypassed only near authored ladder path',landingSupport:'native support still required; never excluded'};
const sources=[...used].sort().map(p=>({path:p.startsWith(repo+path.sep)?path.relative(repo,p).replaceAll('\\','/'):'THREE_VENDOR/'+path.relative(vendor,p).replaceAll('\\','/'),sha256:digest(fs.readFileSync(p))}));
const result={schema:'mafiozi-source-ladder-v1',sourceId:id,assetSha256:item.binding.sha256,originM:block.originM,transform:item.transform,interiorSha256:digest(Buffer.from(interiorBytes.toString('utf8').replaceAll('\r\n','\n'))),descriptor,routeCollisionPolicy,rails:rails.map(b=>({storeyPart:b.storeyPart,polygonXZ:b.polygonXZ,minY:b.minY,maxY:b.maxY})),sources,limits:['Authored source descriptor and conditional policy only. No input, occupancy, body or pose authority activated.','Rail collisions stay enabled. Caller must bind exact source static-body indices to current native RIDs; never blanket-ignore this building.']};
process.stdout.write(JSON.stringify(result));
entry.dispose();
'''
    result = subprocess.run(['node', '--input-type=module', '-'], input=prefix+suffix,
                            text=True, encoding='utf-8', cwd=ROOT,
                            env=dict(os.environ, WALK_THREE_VENDOR=vendor), capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    data = json.loads(result.stdout)
    data['exporterSha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    data['baseExporterSha256'] = hashlib.sha256(base.read_bytes()).hexdigest()
    return (json.dumps(data, ensure_ascii=False, separators=(',', ':'), allow_nan=False)+'\n').encode('utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--three-vendor', default='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')
    args = parser.parse_args()
    output = generate(args.three_vendor)
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != output:
            raise SystemExit('FAIL: source ladder export differs')
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_bytes(output)
    data = json.loads(output)
    print(json.dumps({'passed':True,'check':args.check,'sha256':hashlib.sha256(output).hexdigest(),
                      'bytes':len(output),'descriptor':data['descriptor'],'rails':len(data['rails'])}))


if __name__ == '__main__':
    main()
