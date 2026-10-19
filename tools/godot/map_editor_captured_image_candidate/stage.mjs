// Explicit file-only staging; never runs an engine, browser, receiver, or GPU.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),capture=path.join(root,'outputs/landmark-canvas-capture-ZQyA1N');
const hash=b=>createHash('sha256').update(b).digest('hex');
const args=process.argv.slice(2);assert(args.length<=1&&args.every(a=>['--check','--stage'].includes(a)),'Use --check or --stage');
const within=(parent,file)=>{const r=path.relative(parent,file);return r!==''&&!r.startsWith('..')&&!path.isAbsolute(r);};
assert.equal((await fs.realpath(capture)).toLowerCase(),capture.toLowerCase(),'Capture root alias refused');
const files=[];
async function read(source,target,pin=null,size=null){
 const stat=await fs.lstat(source),resolved=await fs.realpath(source);
 assert(stat.isFile()&&!stat.isSymbolicLink()&&within(root,resolved),'Regular repository source only');
 const bytes=await fs.readFile(source);if(pin)assert.equal(hash(bytes),pin,'Source SHA changed: '+target);if(size!==null)assert.equal(bytes.length,size,'Source bytecount changed: '+target);
 assert(!target.includes('..')&&!path.isAbsolute(target),'Safe stage relative paths only');files.push([target,bytes]);return bytes;
}
const receiptBytes=await read(path.join(capture,'receipt.json'),'captured_canvas/receipt.json','2445be8994a25923d05c91f8523be944db7143e9d6e31585b543edcf4083f31a');
await read(path.join(root,'outputs/map_editor_landmark_texture_closure/manifest.json'),'captured_canvas/closure.json','0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81');
const receipt=JSON.parse(receiptBytes);assert.equal(receipt.canonicalSha256,'614c65a7a209946125dbc5fcd0632bb575df66cdf080cf6d083d300b914f4a32');assert.equal(receipt.ready,false);assert.equal(receipt.slots.length,43);
for(const slot of receipt.slots){assert(/^texture-(?:0|[1-9]\d?)-image-[0-5]$/.test(slot.id),'Fixed original slot name only');for(const kind of ['rgba','png'])await read(path.join(capture,'images',slot.id+'.'+kind),'captured_canvas/images/'+slot.id+'.'+kind,slot[kind+'Sha256'],slot[kind+'Bytes']);}
const candidate=JSON.parse(await fs.readFile(path.join(here,'receipt.json')));
for(const [name,pin] of Object.entries(candidate.files)){assert(/^[a-z_\.]+$/.test(name)&&!name.startsWith('.'),'Flat pinned source only');await read(path.join(here,name),name,pin);}
let destination=null;
if(args.includes('--stage')){
 const outputs=path.join(root,'outputs');assert.equal((await fs.realpath(outputs)).toLowerCase(),outputs.toLowerCase(),'Outputs alias refused');
 destination=await fs.mkdtemp(path.join(outputs,'captured-image-loader-'));
 for(const [relative,bytes] of files){const target=path.join(destination,relative);assert(within(destination,target));await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});assert.equal(hash(await fs.readFile(target)),hash(bytes),'Stage readback mismatch');}
}
console.log(JSON.stringify({ok:true,destination,files:files.length,slots:43,originalRGBABytes:receipt.slots.reduce((n,s)=>n+s.rgbaBytes,0),originalPNGBytes:receipt.slots.reduce((n,s)=>n+s.pngBytes,0),gpu:false,ready:false,productionInstalled:false}));
