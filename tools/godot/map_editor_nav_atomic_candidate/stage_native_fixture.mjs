import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildAtomicSource} from './build_candidate.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const fixture=path.join(own,'fixture');
const source=buildAtomicSource();
const pinned={
 'scripts/navigation/path_job_queue.gd':'dc19de386ccef8e23dcf1c2f0b62f6a46f7f816cf8fd5c3c26c8a6409b7be473',
 'scripts/navigation/preview_engine_navigation.gd':'aca4ff31b689a5b652ca85ddd0999d45696debb912bb8e1495f056d02db69aab',
};
const copies=new Map([
 ['scripts/navigation/atomic_backend.gd',source.backend],
 ['scripts/navigation/pause_backend.gd',source.pauseBackend],
 ['scripts/navigation/path_job_queue.gd',fs.readFileSync(path.join(root,'godot/mafiozi_walk/scripts/navigation/path_job_queue.gd'))],
 ['scripts/navigation/preview_engine_navigation.gd',fs.readFileSync(path.join(root,'godot/mafiozi_walk/scripts/navigation/preview_engine_navigation.gd'))],
]);
for(const [relative,bytes] of copies){
 if(pinned[relative] && crypto.createHash('sha256').update(bytes).digest('hex')!==pinned[relative])throw Error(`Pinned navigation dependency drift: ${relative}`);
 const target=path.resolve(fixture,relative);
 if(!target.startsWith(fixture+path.sep))throw Error(`Fixture escape: ${relative}`);
 fs.mkdirSync(path.dirname(target),{recursive:true});
 fs.writeFileSync(target,bytes);
}
console.log(JSON.stringify({fixture,sourceFiles:copies.size,gpu:false}));
