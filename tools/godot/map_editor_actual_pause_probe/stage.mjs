import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=fs.realpathSync(process.cwd()), source=path.join(root,'godot/mafiozi_walk');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const own=path.join(root,'tools/godot/map_editor_actual_pause_probe');
function safe(p){let q=p;while(q!==path.dirname(q)){if(fs.lstatSync(q).isSymbolicLink())throw Error('Symlink refused '+q);q=path.dirname(q);}return p;}
safe(source);safe(own);safe(path.join(root,'outputs'));
const files=[];
function collect(dir){for(const d of fs.readdirSync(dir,{withFileTypes:true})){const p=safe(path.join(dir,d.name));if(d.isDirectory()){if(d.name==='tests')continue;collect(p);}else if(d.isFile()&&!d.name.endsWith('.uid')){const rel=path.relative(source,p).split(path.sep).join('/');const b=fs.readFileSync(p);files.push([rel,b]);}}}
for(const d of ['scripts','scenes','data','assets'])collect(path.join(source,d));
const main=files.find(([n])=>n==='scripts/main.gd')[1];
if(!main.toString().includes('s01-20260927-melee21'))throw Error('Revision changed: review before probing');
const originalProject=fs.readFileSync(path.join(source,'project.godot'));
files.push(['probe.gd',fs.readFileSync(path.join(own,'probe.gd'))]);
files.push(['project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="Actual Main Pause CPU Diagnostic"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="MafioziPauseProbe-'+crypto.randomUUID()+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')]);
const bytes=files.reduce((s,[,b])=>s+b.length,0);if(bytes>256*1024*1024)throw Error('Bounded stage exceeded');
const out=fs.mkdtempSync(path.join(root,'outputs','actual-main-pause-probe-'));safe(out);
const manifest={schema:1,revision:'s01-20260927-melee21',gpu:false,ready:false,purpose:'diagnostic, not editor pause admission',originalProjectSha256:sha(originalProject),files:[]};
for(const[n,b]of files){const p=path.join(out,n);if(!p.startsWith(out+path.sep))throw Error('Escape');fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,b,{flag:'wx'});if(sha(fs.readFileSync(p))!==sha(b))throw Error('Copy mismatch');const src=path.join(source,n);if(n!=='project.godot'&&fs.existsSync(src)&&sha(fs.readFileSync(src))!==sha(b))throw Error('Source changed while staging '+n);manifest.files.push({path:n,bytes:b.length,sha256:sha(b)});}
fs.writeFileSync(path.join(out,'source_snapshot.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({stage:out,files:files.length,bytes,mainSha256:sha(main),importRequired:true,gpu:false}));
