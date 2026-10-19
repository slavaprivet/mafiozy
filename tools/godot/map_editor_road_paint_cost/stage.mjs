import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const root=process.cwd(),src=path.join(root,'outputs/map_editor_procedural_source'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const raw=fs.readFileSync(path.join(src,'manifest.json'));if(hash(raw)!=='82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd')throw Error('Source changed');
const original=fs.readFileSync(path.join(root,'tools/godot/map_editor_procedural_native_v3/scripts/procedural_factory.gd'));if(hash(original)!=='280880c927809d0d773c3175cdf43fc7534a772af286d77fbf0b50a85fe53628')throw Error('Frozen original changed');
const files=[['manifest.json',raw],['scripts/procedural_factory.gd',original],['catalog.json',fs.readFileSync(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json'))]];
const m=JSON.parse(raw),dep=m.dependencies.find(x=>x.path==='godot/mafiozi_walk/data/map_editor/catalog.json');if(hash(files[2][1])!==dep.sha256)throw Error('Catalog changed');
for(const r of m.buffers){const b=fs.readFileSync(path.join(src,r.file));if(hash(b)!==r.sha256||b.length!==r.bytes)throw Error('Buffer changed');files.push([r.file,b]);}
for(const f of ['paint_array_candidate.gd','test_paint_cost.gd'])files.push([f,fs.readFileSync(path.join(root,'tools/godot/map_editor_road_paint_cost',f))]);
files.push(['project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Actual Road Paint CPU Cost"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')]);
const out=fs.mkdtempSync(path.join(root,'outputs','map-editor-road-paint-cost-'));for(const[n,b]of files){const dest=path.join(out,n);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,b,{flag:'wx'});if(hash(fs.readFileSync(dest))!==hash(b))throw Error('Readback mismatch');}
console.log(JSON.stringify({stage:out,files:files.length,gpu:false}));
