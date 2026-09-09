import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source=readFileSync(new URL('./world.html',import.meta.url),'utf8');
const start=source.indexOf('const _npcEmpireWalkPhotos=');
const end=source.indexOf('function _installReadableNpcEmpireUi(){',start);
let loads=0,legacy=0,resolvePortrait;
const context={console,Map,Promise,JSON,Math,String,
 _UP:new URLSearchParams('renderer=walk'),
 _npcEmpireUiLook:()=>({hair:'pink'}),_npcEmpireById:new Map(),
 SPECIALIST_NPCS:[{_specialistId:'inga',role:'unique_npc'}],
 _threeNpcEntityId:()=> 'unique_inga',drawChar:()=>legacy++,
 Image:class {width=360;height=470;set src(url){this.url=url;queueMicrotask(()=>this.onload());}},
 window:{MafioziCharacter3D:{paint(){legacy++;return true;}},MafioziWalkHud:{getNpcPortrait(){loads++;return new Promise(resolve=>{resolvePortrait=resolve;});}},addEventListener(){}},
};
vm.createContext(context);vm.runInContext(source.slice(start,end),context);
function canvas(){const draws=[];return {width:360,height:470,isConnected:true,dataset:{nePortrait:'inga'},draws,getContext(){return {clearRect(){draws.push('clear');},save(){},restore(){},fillText(){draws.push('placeholder');},drawImage(photo){draws.push(photo.url);}};}};}
const first=canvas(),second=canvas();
const paint=(...nodes)=>context._paintNpcEmpireUiPortraits({querySelectorAll:()=>nodes});
paint(first,second);
await new Promise(setImmediate);
assert.equal(loads,1,'one render job for duplicate portraits');
assert.equal(legacy,0,'walk loading must never show an old character');
first.isConnected=false;
resolvePortrait('data:new-pink-hair');
await new Promise(setImmediate);
assert.equal(first.draws.includes('data:new-pink-hair'),false,'detached canvas ignored');
assert.equal(second.dataset.portraitMode,'walk-glb');
const count=second.draws.length;paint(second);
assert.equal(second.draws.length,count,'readiness or refresh cannot erase the ready portrait');
const refreshed=canvas();paint(refreshed);
assert.deepEqual(refreshed.draws,['clear','data:new-pink-hair'],'rebuilt menu receives cached new portrait synchronously');
assert.equal(loads,1);assert.equal(legacy,0);
context._UP=new URLSearchParams();delete context.window.MafioziWalkHud;
paint(canvas());assert.equal(legacy,1,'non-walk renderer still works');
console.log('portrait refresh: pending deduplication, detached DOM, synchronous cache, no legacy flicker, non-walk fallback PASS');

const refreshStart=source.indexOf("    if(document.getElementById('npcEmpireOverlay')?.classList.contains('show')){");
const refreshCode=source.slice(refreshStart,source.indexOf('    return true;',refreshStart));
for(const view of ['dossier','dashboard']){
 let card={scrollTop:745},archive={open:true},focused=false;
 const active={hasAttribute:name=>name==='data-ne-extra',getAttribute:()=> 'apologize'};
 const overlay={classList:{contains:()=>true},dataset:{leaderId:view==='dossier'?'inga':'',uiMode:view},contains:()=>true,
  querySelector:s=>s==='.ne-card'?card:s==='.ne-intel-details'?archive:null,
  querySelectorAll:()=>[{getAttribute:()=> 'apologize',focus:options=>{assert.equal(options.preventScroll,true);focused=true;}}]};
 const refreshContext={document:{getElementById:()=>overlay,activeElement:active},Array,
  openNpcEmpirePanel(){card={scrollTop:0};archive={open:false};},
  openNpcSandboxDashboard(){card={scrollTop:0};archive={open:false};}};
 vm.runInNewContext(refreshCode,refreshContext);
 assert.equal(card.scrollTop,745);assert.equal(archive.open,true);assert.equal(focused,true);
}
console.log('server refresh: dossier and dashboard preserve scroll, archive and keyboard focus PASS');
