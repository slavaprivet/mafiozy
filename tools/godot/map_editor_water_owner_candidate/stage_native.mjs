import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const own = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(own, '../../..');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const files = [
  ['scripts/preview_water_surface.gd','godot/mafiozi_walk/scripts/preview_water_surface.gd','7d89235d93f31dd565aadf37f549a05074bec5534acfb120543228f1dba2655c'],
  ['scripts/preview_water_material.gd','godot/mafiozi_walk/scripts/preview_water_material.gd','51f3d2d5f6c744cc98b0131a62d2acb1e97b8327f2235702b9b1896615952d88'],
  ['diagnostic/water_owner_guard.gd','tools/godot/map_editor_water_owner_candidate/water_owner_guard.gd',null],
  ['test_water_owner_native.gd','tools/godot/map_editor_water_owner_candidate/test_water_owner_native.gd',null]
];
const staged = files.map(([dst,src,pin]) => {
  const bytes=fs.readFileSync(path.join(root,src));
  if(pin && sha(bytes)!==pin) throw Error(`Pinned water source drift: ${src}`);
  return {dst,bytes,sha256:sha(bytes)};
});
const manifest={scope:'isolated water-owner negative fixture',production:false,gpu:false,files:staged.map(({dst,sha256})=>({path:dst,sha256}))};
if(process.argv.includes('--dry-run')) {console.log(JSON.stringify(manifest)); process.exit(0);}
if(!process.argv.includes('--stage')) throw Error('Use --dry-run or --stage');
const output=fs.mkdtempSync(path.join(root,'outputs/map-editor-water-owner-'));
for(const {dst,bytes,sha256} of staged){
  const target=path.join(output,dst);
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes,{flag:'wx'});
  if(sha(fs.readFileSync(target))!==sha256) throw Error(`Stage mismatch: ${dst}`);
}
fs.writeFileSync(path.join(output,'project.godot'),'config_version=5\n[application]\nconfig/name="Water owner negative fixture"\nrun/main_scene=""\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
console.log(JSON.stringify({...manifest,stage:output}));
