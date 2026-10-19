// Explicit offline source continuation, never a browser/server snapshot.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
export const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export const hash=value=>createHash('sha256').update(value).digest('hex');
export const html=fs.readFileSync(path.join(repo,'world.html'),'utf8');
export const worldSHA='9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5';
if(hash(html)!==worldSHA)throw Error('Source world changed');
const ordinaryRun='outputs/astra21_npc_preview_session/1176bf985c5722035affdf135effc39a8f428bf32c322d5916f1de42cd0eb920';
export const boundary=Object.freeze({session_id:'godot-preview-new-session-20260927-01',phase:'AFTER_FULL_DEFERRED_POPULATION_CALLBACK_BEFORE_ANY_SERVER_SNAPSHOT_BEFORE_NATIVE_RESOLVER',source_now_ms:0,game_minutes:720,date_iso:'2026-09-27T00:00:00.000Z',seed:20260927});

function endAt(start,statement){
 let depth=0,state='code';
 for(let i=start;i<html.length;i++){
  const c=html[i],n=html[i+1];
  if(state==='line'){if(c==='\n')state='code';continue;}
  if(state==='block'){if(c==='*'&&n==='/'){state='code';i++;}continue;}
  if(state!=='code'){if(c==='\\'){i++;continue;}if(c===state)state='code';continue;}
  if(c==='/'&&n==='/'){state='line';i++;continue;}if(c==='/'&&n==='*'){state='block';i++;continue;}
  if(c==='"'||c==="'"||c==='`'){state=c;continue;}
  if('([{'.includes(c))depth++;if(')]}'.includes(c))depth--;
  if(statement?c===';'&&depth===0:c==='}'&&depth===0)return i+1;
 }
 throw Error('Unclosed actual source slice');
}
export function sourceFunction(name){
 const start=html.indexOf('function '+name+'(');if(start<0)throw Error('Missing source function '+name);
 const end=endAt(html.indexOf('{',start),false),code=html.slice(start,end);
 new vm.Script(code);return {name,start,end,line:html.slice(0,start).split('\n').length,sha256:hash(code),code};
}
export function sourceDeclaration(name){
 const found=new RegExp('^(?:const|let) '+name+'\\b','m').exec(html);if(!found)throw Error('Missing source declaration '+name);
 const start=found.index,end=endAt(start,true),code=html.slice(start,end);
 new vm.Script(code);return {name,start,end,line:html.slice(0,start).split('\n').length,sha256:hash(code),code};
}

export function createSourceVm({classicModules=true,fixedDate=boundary.date_iso}={}){
 if(fixedDate!==boundary.date_iso||classicModules!==true)throw Error('Only the approved exact offline boundary with full classic modules is supported');
 const receipts=[],draws=[],birthCalls=[],queries=[],installed=new Set();let rngState=boundary.seed>>>0;
 const rng=()=>{rngState=(rngState+0x6d2b79f5)>>>0;let t=rngState;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);const value=((t^(t>>>14))>>>0)/4294967296;draws.push(value);return value;};
 const sourceMath=Object.create(Math);sourceMath.random=rng;
 const dateMs=Date.parse(fixedDate);
 class FixedDate extends Date{constructor(...args){super(...(args.length?args:[dateMs]));}static now(){return dateMs;}}
 const context=vm.createContext({Math:sourceMath,Date:FixedDate,URLSearchParams,location:{search:'?render=3d&renderer=walk',hostname:'localhost'},window:{},document:{documentElement:{dataset:new Proxy({}, {set(){return true;},get(){throw Error('Unexpected gameplay DOM read');}})}},performance:{now:()=>0},__birthCalls:birthCalls,__queryLedger:queries});
 const run=(code,label='source')=>vm.runInContext(code,context,{timeout:10000,filename:label});
 const installReceipt=receipt=>{
  if(installed.has(receipt.name))return;
  if(hash(receipt.code)!==receipt.sha256)throw Error('Receipt bytes changed');
  const exact=receipt.path?fs.readFileSync(path.join(repo,receipt.path),'utf8')===receipt.code:html.includes(receipt.code);
  if(!exact)throw Error('Receipt is not actual current source: '+receipt.name);
  run(receipt.code,receipt.name);installed.add(receipt.name);receipts.push(receipt);
 };
 const installFunction=name=>installReceipt(sourceFunction(name));
 const installDeclaration=name=>installReceipt(sourceDeclaration(name));
 const installModule=relative=>{if(installed.has(relative))return;const code=fs.readFileSync(path.join(repo,relative),'utf8');installReceipt({name:relative,path:relative,sha256:hash(code),code});};
 if(classicModules){
  const beforeMain=html.slice(0,html.indexOf('<script>',html.indexOf('npc_civilian_elapsed_source.js')));
  for(const match of beforeMain.matchAll(/<script src="(assets\/maps\/city_rebuild_v1\/(?:npc_|ambulance_)[^"]+\.js)"/g))installModule(match[1]);
 }
 const mapSlices=JSON.parse(fs.readFileSync(path.join(repo,'outputs/coordinator21_npc_source_map/source_slices.json'))).slices;
 for(const receipt of mapSlices)installReceipt(receipt);
 run('buildMap()');
 const factory=JSON.parse(fs.readFileSync(path.join(repo,ordinaryRun,'factory_slices.json')));
 const deferred=new Set(['actual_resident_doors_initializer','actual_ordinary_init_loop','actual_renderer_config_assignment','actual_synchronous_clock_tick_expression']);
 for(const receipt of factory.slices){
  if(receipt.name.startsWith('actual_call_')||deferred.has(receipt.name)||(classicModules&&receipt.name==='actual_native_population_target'))continue;
  installReceipt(receipt);
 }
 const mapBefore=run('JSON.stringify(MAP)')+'\n';
 if(hash(mapBefore)!=='be566fd54e9afdd24e2150dd1b53498c1d00d0063b5b5f19a8ceba9fdbee59f4')throw Error('Initial MAP differs');
 const executeNamed=name=>{const receipt=factory.slices.find(item=>item.name===name);if(!receipt)throw Error('Missing baseline receipt '+name);run(receipt.code,name);receipts.push(receipt);};
 executeNamed('actual_synchronous_clock_tick_expression');
 run('_cacheBusinessExteriorCollisions();');
 if(!run('_businessExteriorPedCollisionEnabled')||run('_businessExteriorCollisionCache.size')!==10)throw Error('Actual business prerequisites differ');
 executeNamed('actual_resident_doors_initializer');executeNamed('actual_renderer_config_assignment');
 run('_prepareCityV3DecorGardens();');
 if(run('_cityV3DecorGate()')!==false||draws.length!==0)throw Error('Actual preordinary source prerequisites differ');
 run('_gameMinutes=720;');
 run('const __sourcePassable=npcPassable; npcPassable=function(r,c){const result=__sourcePassable(r,c);__queryLedger.push([r,c,result]);return result;}; const __sourceSpawn=spawnNpc; spawnNpc=function(seed,opts){const row=__sourceSpawn(seed,opts);__birthCalls.push({seed,id:row?.id??null});return row;};');
 executeNamed('actual_ordinary_init_loop');
 const ordinary=run('JSON.stringify(NPCS)')+'\n';
 if(hash(ordinary)!=='43262037de6d987c9f36cac1aa8bd66569a69cfb2d89933e3784d206e14f409d'||draws.length!==6356||rngState!==2091196195)throw Error('Immutable ordinary source roster/RNG mismatch');
 return {context,run,installReceipt,installFunction,installDeclaration,installModule,installed,receipts,draws,birthCalls,queries,boundary,ordinary,worldSHA,rng:()=>({draw_count:draws.length,state:rngState})};
}
