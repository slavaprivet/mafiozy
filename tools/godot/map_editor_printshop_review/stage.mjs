import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),target=path.join(root,'outputs/map_editor_printshop_review');
const copies=[['tools/godot/map_editor_printshop_placement_candidate/printshop_placement.gd','candidate/printshop_placement.gd'],['tools/godot/map_editor_candidate/scripts/map_editor/trusted_json.gd','map_editor_candidate/scripts/map_editor/trusted_json.gd'],['godot/mafiozi_walk/scripts/preview_printshop_interior.gd','scripts/preview_printshop_interior.gd'],['godot/mafiozi_walk/scripts/preview_interior_finish.gd','scripts/preview_interior_finish.gd'],['tools/godot/map_editor_printshop_review/test_review.gd','test_review.gd']];
for(const[from,to]of copies){const dest=path.join(target,to);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,from),dest);}
fs.writeFileSync(path.join(target,'project.godot'),'config_version=5\n[application]\nconfig/name="Printshop Readonly Review Probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
console.log('Isolated output-only review; original candidate files untouched');
