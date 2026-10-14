/** Install only byte-verified missing map-editor GLBs at their canonical SHA paths.
 * No catalog, scene, script, project or existing asset is rewritten.
 */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildActivation} from './canonical_activation.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const plan=buildActivation(); // Fails closed on changed catalog, package, paths or existing files.
const actions=plan.rows.filter(row=>row.action!=='verify-existing-canonical');
assert.equal(actions.length,193);
const targetDirectory=path.join(root,'godot/mafiozi_walk/assets/map_editor');
const outputDirectory=path.join(root,'outputs');
for(const directory of [root,outputDirectory,targetDirectory]){
  const stat=fs.lstatSync(directory);
  assert.ok(stat.isDirectory()&&!stat.isSymbolicLink(),`Unsafe directory: ${directory}`);
}
const mode=process.argv[2];
assert.ok(process.argv.length===3&&['--check','--install'].includes(mode),'usage: node install_canonical_assets.mjs --check|--install');
if(mode==='--check'){
  console.log(JSON.stringify({status:'READY_EXCLUSIVE_INSTALL',count:actions.length,bytes:plan.counts.copyBytes,catalogSha256:plan.catalogSha256}));
  process.exit(0);
}

// Prepare all raw copies away from res:// first. Hard-link publication on the
// same volume is exclusive: EEXIST never overwrites somebody else's asset.
const staging=fs.mkdtempSync(path.join(outputDirectory,'map-editor-asset-install-'));
const receipt={schema:'mafiozi.map-editor-canonical-asset-install/v1',catalogSha256:plan.catalogSha256,
  packageSha256:plan.missingPackageManifestSha256,planned:actions.length,created:[],status:'preparing'};
const receiptPath=path.join(staging,'receipt.json');
function persist(){
  const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
  const temp=receiptPath+'.tmp';
  fs.writeFileSync(temp,bytes,{flag:fs.existsSync(temp)?'w':'wx'});
  fs.renameSync(temp,receiptPath);
}
try{
  for(const row of actions){
    const source=path.join(root,row.source),temporary=path.join(staging,row.id+'.glb');
    const raw=fs.readFileSync(source);
    assert.equal(raw.length,row.bytes);
    assert.equal(sha(raw),row.id);
    fs.writeFileSync(temporary,raw,{flag:'wx'});
    // Windows rejects FlushFileBuffers on a read-only file handle.
    const fd=fs.openSync(temporary,'r+');
    try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
    assert.equal(sha(fs.readFileSync(temporary)),row.id);
  }
  // Repeat the full preflight after preparation to reject concurrent changes.
  const latest=buildActivation();
  assert.deepEqual(latest.rows,plan.rows);
  receipt.status='publishing'; persist();
  for(const row of actions){
    const destination=path.join(root,row.destination),temporary=path.join(staging,row.id+'.glb');
    assert.ok(destination.startsWith(targetDirectory+path.sep));
    fs.linkSync(temporary,destination); // Exclusive, never replaces an existing path.
    assert.equal(sha(fs.readFileSync(destination)),row.id);
    receipt.created.push({destination:row.destination,sha256:row.id,bytes:row.bytes});
    persist();
    fs.unlinkSync(temporary); // Only our temporary name; destination remains intact.
  }
  assert.equal(receipt.created.length,193);
  for(const row of plan.rows){
    const installed=path.join(root,row.destination);
    const stat=fs.lstatSync(installed);
    assert.ok(stat.isFile()&&!stat.isSymbolicLink());
    assert.equal(stat.size,row.bytes);
    assert.equal(sha(fs.readFileSync(installed)),row.id);
  }
  receipt.status='verified'; persist();
  console.log(JSON.stringify({status:'INSTALLED_VERIFIED',count:receipt.created.length,bytes:plan.counts.copyBytes,receipt:path.relative(root,receiptPath).replaceAll('\\','/')}));
}catch(error){
  receipt.status='hold';
  receipt.error=String(error);
  persist();
  console.error(JSON.stringify({status:'HOLD_NO_AUTOMATIC_DELETE',created:receipt.created.length,receipt:path.relative(root,receiptPath).replaceAll('\\','/'),error:String(error)}));
  process.exitCode=1;
}
