import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd(),out=path.join(root,'outputs/map_editor_printshop_shadow_v2');
const copies=[['tools/godot/map_editor_candidate/scripts/map_editor/trusted_json.gd','trusted_json.gd'],['tools/godot/map_editor_printshop_shadow_v2/printshop_shadow.gd','printshop_shadow.gd'],['tools/godot/map_editor_printshop_shadow_v2/test_printshop_shadow.gd','test_printshop_shadow.gd'],['godot/mafiozi_walk/scripts/preview_printshop_interior.gd','scripts/preview_printshop_interior.gd'],['godot/mafiozi_walk/scripts/preview_interior_finish.gd','scripts/preview_interior_finish.gd'],['godot/mafiozi_walk/data/printshop_interior.json','data/printshop_interior.json']];
for(const[from,to]of copies){const target=path.join(out,to);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(root,from),target);}
fs.writeFileSync(path.join(out,'project.godot'),'config_version=5\n[application]\nconfig/name="Printshop CPU Shadow Candidate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
