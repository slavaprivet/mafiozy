import assert from 'node:assert/strict';
import fs from 'node:fs';
import {planExplorationDecorAsync} from './exploration_decor_worker_client.mjs';
import {buildExplorationDecorPlan} from './exploration_decor_worker_core.mjs';
import {explorationKeepouts} from './exploration_scene_support.mjs';
const topology=JSON.parse(fs.readFileSync(new URL('./topology_for_placement.json',import.meta.url),'utf8')),buildings=JSON.parse(fs.readFileSync(new URL('./buildings_placement.v1.json',import.meta.url),'utf8')).instances,decor=JSON.parse(fs.readFileSync(new URL('./decor_placement.v1.json',import.meta.url),'utf8')).instances,input={topology,keepouts:explorationKeepouts([...buildings,...decor],4.1),metresPerCell:4.1},result=await planExplorationDecorAsync(input);
assert.deepEqual(result.plan,buildExplorationDecorPlan(input));assert.ok(['worker','main-fallback'].includes(result.mode));
console.log(JSON.stringify({status:'PASS',mode:result.mode,objects:result.plan.objects.length,trees:result.plan.stats.trees}));
