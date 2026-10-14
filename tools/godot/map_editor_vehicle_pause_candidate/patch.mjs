import fs from 'node:fs';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const source=path.join(root,'godot/mafiozi_walk/scripts/preview_transport.gd');
const expected='3a67a707ee4ef53116323ce4bf52c801f1c8f2e4b3e494bc7c9579c95adb8213';
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
export function deriveTransport(original=fs.readFileSync(source)) {
  if(sha(original)!==expected) throw Error('Transport owner source drift; rebase deliberately');
  const append=fs.readFileSync(path.join(own,'transport_owner_append.gdinc'));
  const result=Buffer.concat([original,append]);
  if(!result.toString('utf8').includes('func map_editor_vehicle_acquire')) throw Error('Missing owner API');
  return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))
  console.log(JSON.stringify({sourceSha256:expected,derivedSha256:sha(deriveTransport()),productionWritten:false}));
