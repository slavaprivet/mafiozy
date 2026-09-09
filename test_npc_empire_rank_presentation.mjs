import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync(new URL('./world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n'),env={};vm.createContext(env);
for(const name of ['_npcEmpireKnownRank','_npcEmpireRankLabel']){const a=s.indexOf(`function ${name}(`);assert.ok(a>=0);vm.runInContext(s.slice(a,s.indexOf('\n}',a)+2),env);}
assert.equal(env._npcEmpireRankLabel({status:'offline',rank:19}),'—','Catalogue fallback rank is not server ranking');
for(const rank of [undefined,null,0,-1,1.5,'bad',Infinity])assert.equal(env._npcEmpireRankLabel({rank}),'—');
assert.equal(env._npcEmpireRankLabel({status:'active',rank:1}),'№1');
assert.equal(env._npcEmpireRankLabel({status:'ruined',rank:19}),'№19','Actual nineteenth place is retained');
assert.ok(!s.includes('№${+empire.rank||19}'));
assert.ok(!s.includes('<div class="place">${i+1}</div>'));
assert.ok(s.includes('leader=ordered.find(e=>_npcEmpireKnownRank(e)===1)'));
assert.ok(s.includes('headerMeta.textContent=`Досье ·'));
console.log('PASS empire rank presentation: authoritative rank shared across list/dossier; offline/missing rank unknown');
