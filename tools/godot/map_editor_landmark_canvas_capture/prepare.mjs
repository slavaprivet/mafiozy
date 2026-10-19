// File-only preparation. Never launches a browser/server/renderer.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const original=path.join(root,'outputs/map_editor_protected_landmarks_source/manifest.json'),closure=path.join(root,'outputs/map_editor_landmark_texture_closure/manifest.json');
const read=(file,pin)=>{if(fs.lstatSync(file).isSymbolicLink())throw Error('Linked source refused');const b=fs.readFileSync(file);if(pin&&sha(b)!==pin)throw Error('Source pin mismatch: '+file);return b;};
const sourceBytes=read(original,'4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c'),closureBytes=read(closure,'0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81');
const source=JSON.parse(sourceBytes),audit=JSON.parse(closureBytes);
for(const name of ['three_preview.js','world.html'])read(path.join(root,name),source.sourceReceipts[name]);
for(const[name,recipe]of Object.entries(source.recipes))if(sha(Buffer.from(recipe.code))!==recipe.sha256)throw Error('Original recipe pin mismatch '+name);
if(audit.summary.sourceTextures!==38||audit.summary.originalRasterImages!==43)throw Error('Closure inventory mismatch');
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build';
const files=new Map([['source.json',sourceBytes],['closure.json',closureBytes],['vendor/three.module.js',read(path.join(vendor,'three.module.js'),'c8211c69345d2e9949dc7a8ac969380497aa0600a5a8ac6a459c8cd02dd9cb8a')],['vendor/three.core.js',read(path.join(vendor,'three.core.js'),'eb077d2417f61d3e6d9264c317cabc4ea35769ed6b0ab533067292a550784c20')]]);
for(const name of ['index.html','capture.browser.mjs','bundle.browser.mjs','serve.mjs','font_evidence.mjs'])files.set(name,read(path.join(here,name)));
const recipeKeys=['scalarConstants','layout','surfaceTextures','jailSnapshot','canalSnapshot','box','outline','labelSprite','bridge','prison'];
if(recipeKeys.some(key=>!source.recipes[key]))throw Error('Original dependency recipe absent');
// Compile the exact original recipe scope for syntax only; do not execute factories.
new Function(source.recipes.scalarConstants.code+source.recipes.layout.code+source.recipes.surfaceTextures.code);
const mode=process.argv.slice(2);if(mode.length!==1||!['--check','--prepare'].includes(mode[0]))throw Error('Usage: --check|--prepare');
const manifest={schema:'landmark-original-canvas-harness-preparation-v1',sourcePins:source.sourceReceipts,sourceManifestSha256:sha(sourceBytes),closureSha256:sha(closureBytes),recipePins:Object.fromEntries(recipeKeys.map(key=>[key,source.recipes[key].sha256])),files:[...files].map(([name,b])=>({name,bytes:b.length,sha256:sha(b)})),originalTextureCount:38,originalImageSlots:43,capturesRun:0,ready:false,browserStarted:false,engineStarted:false,gpu:false};
if(mode[0]==='--check'){console.log(JSON.stringify({ok:true,mode:'file-only-readonly',...manifest}));}else{
 const outputs=path.join(root,'outputs');if(fs.lstatSync(outputs).isSymbolicLink()||fs.realpathSync(outputs).toLowerCase()!==outputs.toLowerCase())throw Error('Outputs resolved path unsafe');
 const out=fs.mkdtempSync(path.join(outputs,'landmark-canvas-harness-'));
 for(const[name,bytes]of files){const dest=path.join(out,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});if(sha(fs.readFileSync(dest))!==sha(bytes))throw Error('Readback mismatch');}
 fs.writeFileSync(path.join(out,'package_manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({ok:true,stage:out,capturesRun:0,ready:false,browserStarted:false,gpu:false}));
}
