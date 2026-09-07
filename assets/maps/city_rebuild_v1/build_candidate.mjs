// Explicit CLI output only. Never reads/writes the current game world or server.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {compileTopology} from './topology.mjs';
const [sourcePath,policePath,outPath]=process.argv.slice(2);
if(!sourcePath||!policePath||!outPath)throw new Error('Usage: node build_candidate.mjs <contract.json> <police-ledger.json|-> <new-output.json>');
const output=path.resolve(outPath);
if(output===path.resolve(sourcePath)||(policePath!=='-'&&output===path.resolve(policePath)))throw new Error('Output must not overwrite input');
const bytes=fs.readFileSync(sourcePath),source=JSON.parse(bytes),host=policePath==='-'?{}:JSON.parse(fs.readFileSync(policePath,'utf8'));
const result=compileTopology(source,host);
const artifact={...result,sourceSha256:createHash('sha256').update(bytes).digest('hex')};
fs.writeFileSync(output,JSON.stringify(artifact,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:result.status,output,errors:result.validation.errors.length,gridPublished:!!result.grid}));
if(result.status==='REJECTED')process.exitCode=2;
