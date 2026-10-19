// Test-only: execute the actual current source function, never reimplement it.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), crypto = require('node:crypto');
const repo = path.resolve(__dirname, '../../../../..');
const world = fs.readFileSync(path.join(repo, 'world.html'), 'utf8');
const source = world.match(/function _npcEffectiveSpeed\(n\) \{[\s\S]*?\r?\n\}/)?.[0];
if (!source) throw Error('source function not found');
const packet = JSON.parse(fs.readFileSync(path.join(repo, 'godot/mafiozi_walk/assets/npc_visual/session/e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096.json'), 'utf8'));
const fn = vm.runInNewContext('(' + source + ')');
const result = {function_sha256: crypto.createHash('sha256').update(source).digest('hex'), rows: packet.rows.map(row => ({id: row.source_id, speed_mps: fn(row.source_raw) * 4.1}))};
fs.writeFileSync(path.join(__dirname, 'resident_speed_oracle.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result));
