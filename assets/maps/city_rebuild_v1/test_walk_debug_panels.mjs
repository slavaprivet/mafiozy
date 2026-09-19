import test from 'node:test';
import assert from 'node:assert/strict';
import {installWalkDebugPanels} from './walk_debug_panels.mjs';
function documentFixture(){
 const listeners=new Map();
 const doc={head:{nodes:[],append(n){this.nodes.push(n);}},body:{dataset:{}},createElement(tag){return{tagName:tag.toUpperCase(),remove(){this.removed=true;}};},addEventListener(type,handler){listeners.set(type,handler);},removeEventListener(type,handler){if(listeners.get(type)===handler)listeners.delete(type);}};
 return{doc,key(options={}){const e={code:'F9',ctrlKey:true,shiftKey:true,target:{tagName:'DIV'},preventDefault(){this.prevented=true;},stopImmediatePropagation(){this.stopped=true;},...options};listeners.get('keydown')?.(e);return e;},listeners};
}
test('local QA panels use keyboard access without screen button and preserve clean gameplay HUD',()=>{
 const{doc,key,listeners}=documentFixture();let releases=0;
 const ui=installWalkDebugPanels({document:doc,href:'http://127.0.0.1:18538/world.html?mercenaryqa=1',releaseControls:()=>releases++});
 assert.equal(doc.head.nodes.length,1);const css=doc.head.nodes[0];assert.match(css.textContent,/#districtRepHud,#drive-status:empty/);assert.match(css.textContent,/#npc-combat-session/);
 assert.equal(ui.expanded,false);assert.equal(key({repeat:true}).prevented,undefined);assert.equal(key({target:{tagName:'INPUT'}}).prevented,undefined);assert.equal(key({shiftKey:false}).prevented,undefined);
 assert.equal(key().prevented,true);assert.equal(ui.expanded,true);assert.equal(releases,1);assert.doesNotMatch(css.textContent,/#npc-combat-session/);assert.match(css.textContent,/#districtRepHud/);
 key();assert.equal(ui.expanded,false);ui.dispose();assert.equal(css.removed,true);assert.equal(listeners.size,0);
});
test('remote or non-QA builds cannot open diagnostics with the shortcut',()=>{
 for(const href of ['https://example.com/world.html?mercenaryqa=1','http://127.0.0.1:18538/world.html']){const{doc,key}=documentFixture();const ui=installWalkDebugPanels({document:doc,href});assert.equal(key().prevented,undefined);assert.equal(ui.expanded,false);ui.dispose();}
});
