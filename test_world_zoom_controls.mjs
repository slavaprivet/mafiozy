import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('./three_preview.js',import.meta.url),'utf8');
const extract=needle=>{const s=source.indexOf(needle);assert(s>=0,needle);let i=source.indexOf('{',needle.startsWith('function ')?source.indexOf(')',s)+1:s),depth=0;for(;i<source.length;i++){if(source[i]==='{')depth++;if(source[i]==='}'&&!--depth)return source.slice(s,i+1);}throw Error(needle);};
class Element{
  constructor(tag){this.tag=tag;this.children=[];this.attributes={};this.style={};this.listeners=new Map();this.dataset={};this.classList={contains:()=>true};}
  setAttribute(k,v){this.attributes[k]=v;}
  append(...nodes){nodes.forEach(n=>this.appendChild(n));}
  appendChild(node){this.children.push(node);node.parent=this;}
  addEventListener(type,listener){this.listeners.set(type,listener);}
  removeEventListener(type,listener){if(this.listeners.get(type)===listener)this.listeners.delete(type);}
  remove(){this.parent.children=this.parent.children.filter(n=>n!==this);this.parent=null;}
  dispatch(type,data={}){const event={stopped:false,prevented:false,stopPropagation(){this.stopped=true;},preventDefault(){this.prevented=true;},...data};this.listeners.get(type)?.(event);return event;}
}
const stage=new Element('stage'),document={createElement:tag=>new Element(tag)},renderer={domElement:{dataset:{}}};
const camera={zoom:1,updates:0,updateProjectionMatrix(){this.updates++;}};
const window=new Element('window');
const context=vm.createContext({stage,document,renderer,camera,window,Math,THREE:{MathUtils:{clamp:(v,min,max)=>Math.min(max,Math.max(min,v))}},
 worldZoom:1,cameraZoomMode:'world',interiorZoom:1.08,cameraWheelEvents:0,disposeWorldZoomControls:()=>{},
 cityV3BuildingPreviewRequested:true,rendererParams:new URLSearchParams(),location:{hostname:'127.0.0.1'}});
const run=s=>vm.runInContext(s,context);
const defaultLine=source.split('\n').find(line=>line.includes('worldZoom=cityV3BuildingPreviewRequested?1.3:1;'));assert(defaultLine);
run(defaultLine);assert.equal(context.worldZoom,1.3);
context.cityV3BuildingPreviewRequested=false;run(defaultLine);assert.equal(context.worldZoom,1);
context.worldZoom=2.2;context.rendererParams.set('previewzoom','2.2');run(defaultLine);assert.equal(context.worldZoom,2.2,'existing explicit previewzoom wins');context.rendererParams.delete('previewzoom');
context.worldZoom=1.3;
run(extract('function createWorldZoomControls('));
run(extract('const setWorldZoom=value=>{')+';');
run("const worldZoomControls=createWorldZoomControls({host:stage,getZoom:()=>worldZoom,setZoom:setWorldZoom,getMode:()=>cameraZoomMode});");
const bar=stage.children[0],[minus,output,plus]=bar.children;
assert.equal(bar.id,'worldZoomControls');assert.equal(bar.attributes.role,'group');assert.equal(bar.attributes['aria-label'],'Масштаб города');
assert.equal(minus.attributes['aria-label'],'Отдалить город');assert.equal(plus.attributes['aria-label'],'Приблизить город');assert.equal(output.textContent,'130%');
assert(bar.style.cssText.includes('bottom:18px')&&bar.style.cssText.includes('left:50%'));
const click=plus.dispatch('click');assert(click.stopped);assert.equal(context.worldZoom,1.45);assert.equal(camera.zoom,1.45);assert.equal(renderer.domElement.dataset.worldZoom,'1.45');
for(let i=0;i<30;i++)plus.dispatch('click');assert.equal(context.worldZoom,2.6);assert.equal(plus.disabled,true);assert.equal(output.textContent,'260%');
for(let i=0;i<30;i++)minus.dispatch('click');assert.equal(context.worldZoom,.82);assert.equal(minus.disabled,true);assert.equal(output.textContent,'82%');
assert(bar.dispatch('pointerdown').stopped);const key=bar.dispatch('keydown',{key:'Enter'});assert(key.stopped&&!key.prevented,'native button keyboard activation remains allowed');
run(extract('const handleCameraWheel=e=>{')+';');
context.worldZoom=2.3;const wheel={deltaY:-100,preventDefault(){this.prevented=true;}};context.wheel=wheel;run('handleCameraWheel(wheel)');assert(wheel.prevented);assert.equal(context.worldZoom,2.52);assert.equal(output.textContent,'252%');
context.cameraZoomMode='interior';run('worldZoomControls.sync()');assert.equal(bar.style.display,'none');assert(minus.disabled&&plus.disabled);
const oldWorld=context.worldZoom;plus.dispatch('click');assert.equal(context.worldZoom,oldWorld);
context.interiorZoom=1.8;run('handleCameraWheel(wheel)');assert.equal(context.interiorZoom,1.9);assert.equal(camera.zoom,1.9);assert.equal(context.worldZoom,oldWorld);
context.cameraZoomMode='world';run('worldZoomControls.sync()');assert.equal(bar.style.display,'flex');assert.equal(output.textContent,'252%');
const cleanupStart=source.indexOf('let zoomControlsDisposed=false;'),cleanupEnd=source.indexOf("window.addEventListener('pagehide',disposeWorldZoomControls,{once:true});",cleanupStart)+"window.addEventListener('pagehide',disposeWorldZoomControls,{once:true});".length;
run("window.addEventListener('wheel',handleCameraWheel,{passive:false,capture:true});");run(source.slice(cleanupStart,cleanupEnd));
assert(window.listeners.has('wheel'));window.dispatch('pagehide');assert.equal(stage.children.length,0);assert(!window.listeners.has('wheel'));assert(!window.listeners.has('pagehide'));
const before=context.worldZoom;plus.dispatch('click');assert.equal(context.worldZoom,before);run('disposeWorldZoomControls()');
assert(source.includes('if (!document.body.contains(renderer.domElement)) {disposeWorldZoomControls();'));
assert(source.includes("camera.zoom=worldZoom;camera.updateProjectionMatrix();worldZoomControls.sync();"));
assert(!extract('function createWorldZoomControls(').includes('setPixelRatio')&&!extract('const setWorldZoom=value=>{').includes('setPixelRatio'));
console.log('PASS world zoom: local authored preview1.3 / normal1 / explicit override, accessible visible +/- controls, .82..2.6 clamps, wheel preserved, interior zoom isolated, HUD-safe placement, cleanup, no pixel-ratio change.');
