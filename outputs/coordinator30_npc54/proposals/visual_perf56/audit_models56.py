"""Read-only pinned asset inventory; does not instantiate or run Godot."""
from pathlib import Path
import argparse, collections, hashlib, json, struct

def audit(project):
    manifest_file = project / 'assets/npc_city/prepared/manifest.json'
    manifest = json.loads(manifest_file.read_text(encoding='utf-8'))
    totals, rows = collections.Counter(), []
    for receipt in manifest['entries']:
        entry = receipt['entry']
        raw = (manifest_file.parent / receipt['prepared_file']).read_bytes()
        assert raw[:4] == b'RSRC'
        digest = hashlib.sha256(raw).hexdigest()
        assert digest == receipt['prepared_sha256']
        resources = {}
        for name in ['StandardMaterial3D', 'ArrayMesh', 'Skin']:
            signature = name.encode() + b'\0'
            resources[name] = raw.count(struct.pack('<I', len(signature)) + signature)
        assert resources['ArrayMesh'] == int(entry['mesh_count'])
        row = {'id': entry['bridge_id'], 'sex': entry['descriptor']['sex'],
               'mesh_instances_authored': int(entry['mesh_count']),
               'vertices_authored': int(entry['roundtrip']['vertices']),
               'bones': int(entry['bone_count']),
               'animation_players_authored': int(entry['animation_count']),
               'prepared_bytes': len(raw),
               'binary_sized_resource_class_records': resources, 'sha256': digest}
        rows.append(row)
        for key in ['mesh_instances_authored', 'vertices_authored', 'bones', 'animation_players_authored', 'prepared_bytes']:
            totals[key] += row[key]
        for name, count in resources.items():
            totals['binary_' + name] += count
    return {'schema': 'visual_source_audit56/v1', 'source_project': str(project),
            'manifest_sha256': hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
            'resident_count': len(rows), 'totals': dict(totals),
            'mesh_range': [min(row['mesh_instances_authored'] for row in rows), max(row['mesh_instances_authored'] for row in rows)],
            'sexes': dict(collections.Counter(row['sex'] for row in rows)),
            'method': 'Read-only manifest counts + verified pinned uncompressed RSRC files. Sized resource class record signatures are source-resource counts, not live tree/runtime draw-call measurements. ArrayMesh signature count cross-checked against every actor manifest mesh_count. Runtime staff/props/cards/pooled ragdolls are outside these catalog totals.',
            'native_or_graphical_started': False, 'rows': rows}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.project)
    args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'residents': result['resident_count'], **result['totals']}))
