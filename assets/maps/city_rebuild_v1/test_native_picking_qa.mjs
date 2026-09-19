import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createNativePickingQa,allowNativePickingQa} from './native_picking_qa.mjs';
import {createMercenaryWalk} from './mercenary_walk.mjs';
const href='http://127.0.0.1:18538/walk?perfqa=1&nativepick=1';
for(const url of ['https://example.com/?perfqa=1&nativepick=1','http://localhost/?nativepick=1',href+'&token=x',href+'&mercenarypickqa=1'])assert.equal(allowNativePickingQa(url),false);
assert(allowNativePickingQa(href));
class Element{
 constructor(tag){this.tagName=tag.toUpperCase();this.children=[];this.dataset={};this.style={};this.attrs={};this.listeners=new Map();}
 append(...nodes){for(const n of nodes){n.parentNode=this;this.children.push(n);}}
 replaceChildren(...nodes){this.children=[];this.append(...nodes);}
 remove(){if(this.parentNode)this.parentNode.children=this.parentNode.children.filter(n=>n!==this);this.parentNode=null;}
 setAttribute(k,v){this.attrs[k]=v;}
 addEventListener(k,f){if(!this.listeners.has(k))this.listeners.set(k,[]);this.listeners.get(k).push(f);}
 removeEventListener(k,f){this.listeners.set(k,(this.listeners.get(k)||[]).filter(v=>v!==f));}
 emit(k,e={}){for(const f of this.listeners.get(k)||[])f(e);}
 focus(){}
}
function fixture(url=href){const doc=new Element('document');doc.body=new Element('body');doc.documentElement=new Element('html');doc.createElement=t=>new Element(t);doc.createElementNS=(_,t)=>new Element(t);doc.defaultView={location:{href:url,search:new URL(url).search}};return doc;}
const doc=fixture(),win=doc.defaultView;let time=0,statsCalls=0,toggles=0;
const source={ready:false,enabled:false,generation:0,setEnabled(value){toggles++;this.enabled=value;return this.stats();},stats(){statsCalls++;return {ready:this.ready,enabled:this.enabled,generation:this.generation};}};
win.MafioziNativeTerrainPicking=source;const qa=createNativePickingQa({document:doc,now:()=>time}),button=doc.body.children[0],read=()=>JSON.parse(doc.documentElement.dataset.nativePickingHover);
assert(button.disabled);assert.equal(qa.begin(),null);assert.equal(toggles,0,'QA never forces startup toggle');
source.ready=true;source.enabled=true;source.generation++;
function sample(ms,options={}){const token=qa.begin();qa.finish(token,{started:time,ended:time+ms,...options});}
sample(8);time=1000;qa.begin();assert.equal(read().samples,1);assert.equal(read().p95Ms,8);
const statsBefore=statsCalls;for(let i=0;i<10;i++){time+=50;sample(8);}assert.equal(statsCalls,statsBefore,'source stats/DOM sorting only at publish interval');
sample(0,{blocked:true});sample(0,{failed:true});time=2000;qa.begin();assert.equal(read().windowSamples,11);assert.equal(read().blockedSamples,1);assert.equal(read().failedSamples,1);assert.equal(read().p50Ms,8);
button.emit('click');assert.equal(source.enabled,false);assert.equal(toggles,1);assert.equal(read().mode,'off');assert.equal(read().samples,0);assert.equal(read().p95Ms,null);
for(let i=1;i<=130;i++){time+=10;sample(i);}time+=1000;qa.begin();assert.equal(read().samples,130);assert.equal(read().windowSamples,120);assert.equal(read().p50Ms,70);assert.equal(read().p95Ms,124);assert.equal(read().lastMs,130);
const token=qa.begin();source.generation++;qa.finish(token,{started:0,ended:999});assert.equal(read().samples,0,'generation change drops in-flight sample');
source.ready=false;source.generation++;qa.begin();assert(button.disabled);assert.equal(read().mode,'waiting');button.emit('click');assert.equal(toggles,1);
const replacement={...source,ready:true,enabled:true,generation:0};win.MafioziNativeTerrainPicking=replacement;sample(5);time+=1000;qa.begin();assert.equal(read().samples,1,'new API identity resets old samples');
const oldClick=button.listeners.get('click')[0],next=createNativePickingQa({document:doc,now:()=>time});const payload=doc.documentElement.dataset.nativePickingHover;qa.dispose();oldClick({});assert.equal(doc.documentElement.dataset.nativePickingHover,payload);assert.equal(toggles,1,'stale helper cannot toggle current source');
delete win.MafioziNativeTerrainPicking;next.begin();assert.equal(read().mode,'waiting');next.dispose();assert.equal(doc.body.children.length,0);assert.equal(doc.documentElement.dataset.nativePickingHover,undefined);assert.equal(next.begin(),null);
let offReads=0;const off=fixture('http://localhost/?nativepick=1');Object.defineProperty(off.defaultView,'MafioziNativeTerrainPicking',{get(){offReads++;throw Error('QA-off must not touch source');}});assert.equal(createNativePickingQa({document:off,now:()=>{throw Error('QA-off timer');}}),null);assert.equal(offReads,0);assert.equal(off.body.children.length,0);

// Actual walk adapter: natural .25s hover, equal target/raycast count with QA
// on/off, no synthetic rays from the button, blocked samples, teardown.
const T=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
function walkFixture(enabled){
 const document=fixture(enabled?href:'http://localhost/walk'),scene=new T.Scene(),camera=new T.PerspectiveCamera(50,1,.1,100),mesh=new T.Mesh(new T.BoxGeometry(2,2,2),new T.MeshBasicMaterial());scene.add(mesh);camera.position.z=8;camera.lookAt(0,0,0);scene.updateMatrixWorld(true);camera.updateMatrixWorld();
 mesh.userData.mercenaryTarget={id:'safe:qa',kind:'safe'};let rays=0,blocked=false,actions=0;const original=mesh.raycast;mesh.raycast=function(...args){rays++;return original.apply(this,args);};
 document.defaultView.MafioziNativeTerrainPicking={ready:true,enabled:true,generation:1,setEnabled(v){this.enabled=v;},stats(){return {enabled:this.enabled};}};
 const host={bindTargets(){},getRoster:()=>({members:[{id:'m'}],candidates:[]}),getActions:target=>{assert.equal(target.id,'safe:qa');actions++;return [{id:'unlock'}];}};
 const walk=createMercenaryWalk({THREE:T,document,camera,scene,getHost:()=>host,getFleet:()=>null,getTraffic:()=>null,getNpcs:()=>[],getBuildings:()=>[],getRoots:()=>[mesh],isBlocked:()=>blocked});
 walk.update(.24);assert.equal(rays,0);walk.update(.01);assert.equal(rays,1);assert.equal(actions,1);for(let i=0;i<3;i++)walk.update(.25);assert.equal(rays,4);
 if(enabled){const button=document.body.children.find(n=>n.id==='native-pick-qa');button.emit('click');assert.equal(rays,4);walk.update(.25);assert.equal(rays,5);}
 blocked=true;walk.update(.25);assert.equal(rays,enabled?5:4);const before=rays;walk.dispose();walk.update(1);assert.equal(rays,before);assert.equal(document.body.children.length,0);assert.equal(document.documentElement.dataset.nativePickingHover,undefined);mesh.geometry.dispose();mesh.material.dispose();return {rays,actions};
}
const ordinary=walkFixture(false),qaWalk=walkFixture(true);assert.equal(ordinary.rays,ordinary.actions);assert.equal(qaWalk.rays,qaWalk.actions);
console.log('PASS native picking QA: local gate/off zero access, 1Hz publish, rolling120, blocked/error exclusion, toggles, generation/replacement/clear, stale init/dispose, actual walk natural cadence/target parity/no extra rays');
