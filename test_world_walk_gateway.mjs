import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {mountWorldWalkHost,watchWorldWalkReady} from './world_walk_host.mjs';
const source=await readFile(new URL('./world.html',import.meta.url),'utf8'),method=source.slice(source.indexOf('  syncWalkPlayer(input={}){'),source.indexOf('  getCityV3DecorHost(){',source.indexOf('  syncWalkPlayer(input={}){')));
function context(renderer='walk'){
 const c={_UP:new URLSearchParams('render=3d&renderer='+renderer),player:{r:8,c:9},myDead:false,_murderPoliceArrest:null,myJailIn:0,myDrivingCarId:null,_inBus:false,myJetSkiId:null,_buildingInt:null,_bankInt:null,_majorInteriorObjectId:null,chatOpen:false,_gameMenuOpen:false,MAP_ROWS:200,MAP_COLS:200,_keyState:{up:true},joyL:{active:true},_playerStance:{},_playerStanceAllowed:()=>true,_effectivePlayerStance:()=> 'stand',performance:{now:()=>1000},Date};vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function _walkRendererActive'),source.indexOf('\n',source.indexOf('function _walkOwnsGameKey')))+'\nthis.bridge={getPlayerState(){return {...player}},'+method+'};',c);return c;
}
const input={r:12,c:14,ang:.7,walking:true,stance:'prone'};let c=context();assert(c.bridge.syncWalkPlayer(input).ok);assert.equal(c.player.r,12);assert.equal(c._keyState.up,false);assert.equal(c.joyL.active,false);assert.equal(c._playerStance.prone,true);
for(const flag of ['myDead','_murderPoliceArrest','myJailIn','myDrivingCarId','_inBus','myJetSkiId','_buildingInt','_bankInt','_majorInteriorObjectId','chatOpen','_gameMenuOpen']){c=context();c[flag]=true;assert(c.bridge.syncWalkPlayer(input).locked,flag);assert.equal(c.player.r,8);}
c=context('legacy');assert.equal(c.bridge.syncWalkPlayer(input).reason,'renderer');assert.equal(c.player.r,8);assert.equal(c._walkOwnsGameKey({code:'Space'}),false);
c=context();assert.equal(c.bridge.syncWalkPlayer({...input,r:NaN}).reason,'position');assert(c._walkOwnsGameKey({code:'KeyW'}));assert(!c._walkOwnsGameKey({code:'Enter'}));assert(!c._walkOwnsGameKey({code:'Escape'}));
const tags=[...source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)],selector=tags.map(m=>m[1]).find(s=>s.includes('const rendererSelection='));assert(selector);assert(!/<script[^>]+src="three_preview\.js/.test(source));
for(const [search,expected] of [['?render=3d&renderer=walk','world_walk_host'],['?render=3d','three_preview'],['?render=canvas','three_preview']]){const chosen=[];await new Function('URLSearchParams','location','choose','return (async()=>{'+selector.replaceAll('await import(','await choose(')+'})()')(URLSearchParams,{search},async url=>chosen.push(url));assert.equal(chosen.length,1);assert(chosen[0].includes(expected));}
function node(name){return {name,children:[],style:{},append(...items){this.children.push(...items)},attachShadow(){return node('shadow')},remove(){this.removed=true}}}
const stage=node('stage'),classes=new Set();stage.classList={add:x=>classes.add(x),remove:x=>classes.delete(x)};const doc={getElementById:id=>id==='stage'?stage:null,createElement:node,importNode:n=>({...n}),documentElement:{dataset:{}}};const script=node('script');let stripped=false;script.remove=()=>{stripped=true};globalThis.DOMParser=class{parseFromString(){return {querySelectorAll:()=>[script],head:{querySelectorAll:()=>[node('style')]},body:{childNodes:[node('viewport'),node('hud')]}}}};
const win={location:{search:'?render=3d&renderer=walk'},Mafiozi3DBridge:{}};let imports=0,fetches=0;const args={document:doc,window:win,fetch:async()=>{fetches++;return {ok:true,text:async()=>'<script>bad()</script>'}},importWalk:async()=>{imports++}};
const first=await mountWorldWalkHost(args),second=await mountWorldWalkHost(args);assert(first.mounted&&second.mounted);assert.equal(imports,1);assert.equal(fetches,1);assert(stripped);assert.equal(stage.children.length,1);assert.equal(win.MafioziWalkShell,first.shell);assert(classes.has('three-mode'));
let notify,disconnected=0,completions=0;
const readyDoc={body:{dataset:{}},documentElement:{dataset:{}}},readyWin={MafioziLoading:{complete(){completions++}}};
class Observer{constructor(callback){notify=callback}observe(target,options){assert.equal(target,readyDoc.body);assert.deepEqual(options.attributeFilter,['data-rebuild-proof','data-hero-walk'])}disconnect(){disconnected++}}
watchWorldWalkReady({document:readyDoc,window:readyWin,Observer});
assert.equal(completions,0,'module/canvas alone is not ready');
readyDoc.body.dataset.rebuildProof=JSON.stringify({loaded:12,planned:12,failed:0});notify();assert.equal(completions,0,'city without rendered hero is not ready');
readyDoc.body.dataset.heroWalk=JSON.stringify({loaded:true});readyDoc.body.dataset.rebuildProof=JSON.stringify({loaded:11,planned:12,failed:1});notify();assert.equal(completions,0,'partial city is not complete');
readyDoc.body.dataset.rebuildProof=JSON.stringify({loaded:12,planned:12,failed:0});notify();notify();assert.equal(completions,1);assert.equal(disconnected,1);assert.equal(readyDoc.documentElement.dataset.worldWalkReady,'first-populated-frame');
console.log('PASS world walk gateway: exclusive renderer, single mount, stripped scripts, gameplay locks, post-render readiness, partial-load rejection, observer cleanup');
