import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {NPC_NAMED_BOSSES,NPC_SAID,NPC_ARCHETYPE_CATALOGUE,NPC_SERVICE_CATALOGUE,NPC_SOURCE_CATALOGUE,NPC_DISPLAY_CATALOGUE,WORLD_SKIN_PALETTE,sourceLookAppearance} from './npc_role_catalogue.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),world=fs.readFileSync(path.resolve(here,'../../../world.html'),'utf8');
assert.equal(NPC_NAMED_BOSSES.length,19);assert.equal(NPC_ARCHETYPE_CATALOGUE.length,8);assert.equal(NPC_SOURCE_CATALOGUE.length,23);
assert.equal(NPC_SAID.id,'said_story_npc');assert.equal(NPC_SAID.name,'Саид');assert.equal(NPC_NAMED_BOSSES.find(x=>x.leaderId==='rustam').name,'Билли Капоне');
for(const row of NPC_NAMED_BOSSES){assert(world.includes(row.leaderId+":'"+row.name+"'"),'exact source renamed boss');assert.equal(row.id,'unique_'+row.leaderId);assert.equal(row.bridgeId,'npc_'+row.id);assert.equal(row.appearance.sex,row.look.gender===1?'female':'male');assert.equal(row.appearance.skin,WORLD_SKIN_PALETTE[row.look.skin]);assert(row.uniqueWeapon.weaponId);assert(Object.isFrozen(row.look));assert(Object.isFrozen(row.uniqueWeapon));assert(!('r' in row)&&!('c'in row),'catalogue must not spawn positions')}
assert.equal(new Set(NPC_DISPLAY_CATALOGUE.map(x=>x.id)).size,NPC_DISPLAY_CATALOGUE.length);
for(const row of NPC_SOURCE_CATALOGUE)assert(row.catalogueOnly&&row.identityKind==='source'&&row.authority);
assert(NPC_SERVICE_CATALOGUE.some(x=>x.role==='prison_guard'&&x.appearance.shield));assert(NPC_SERVICE_CATALOGUE.some(x=>x.role==='medic'));assert(NPC_SERVICE_CATALOGUE.some(x=>x.role==='owner'));
assert.deepEqual(sourceLookAppearance({gender:0,skin:2,suit:'#123456',hairColor:'#654321'}),{sex:'male',skin:WORLD_SKIN_PALETTE[2],outfit:'#123456',hairColor:'#654321'});
assert.equal(sourceLookAppearance({gender:1}).sex,'female');assert(!('sex'in sourceLookAppearance({})), 'role must not invent source gender');
console.log(JSON.stringify({passed:true,bosses:19,saidSeparate:true,archetypes:8,sources:23,serviceRoles:NPC_SERVICE_CATALOGUE.length,displayRows:NPC_DISPLAY_CATALOGUE.length}));
