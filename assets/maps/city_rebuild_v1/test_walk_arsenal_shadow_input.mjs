import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// Exercise the production outside-click listener with the event retargeting
// produced by world_walk_host's open shadow root. Hiding the arsenal on
// pointerdown prevents the subsequent weapon-button click from reaching it.
const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const init=source.slice(source.indexOf('function initArsenal(){'),source.indexOf('\ninitArsenal();'));
const registration=init.match(/document\.addEventListener\('pointerdown',[\s\S]*?\);updateWeaponUi\(\);/);
assert(registration,'production arsenal pointer listener must exist');
let listener,open=true,closes=0;
const button={},label={},outside={},shadowHost={},shadowRoot={};
const hud={contains:node=>node===hud||node===button||node===label};
const document={addEventListener(name,callback){assert.equal(name,'pointerdown');listener=callback;}};
vm.runInNewContext(registration[0],{
 document,$:id=>{assert.equal(id,'weapon-hud');return hud;},
 arsenalOpen:()=>open,setArsenalOpen(value){open=value;closes++;},updateWeaponUi(){},
});

listener({target:shadowHost,composedPath:()=>[label,button,hud,shadowRoot,shadowHost,document]});
assert.equal(open,true,'world shadow button pointerdown must keep the arsenal open for its click');
assert.equal(closes,0);
listener({target:shadowHost,composedPath:()=>[outside,shadowRoot,shadowHost,document]});
assert.equal(open,false,'outside click inside the same shadow root still closes the arsenal');
assert.equal(closes,1);

open=true;
listener({target:label,composedPath:()=>[label,button,hud,document]});
assert.equal(open,true,'standalone button pointerdown remains inside');
listener({target:label});
assert.equal(open,true,'target containment remains a fallback without composedPath');
listener({target:outside,composedPath:()=>[outside,document]});
assert.equal(open,false,'outside document click closes the arsenal');
const closedCalls=closes;
listener({target:outside});
assert.equal(closes,closedCalls,'closed arsenal does not perform redundant mutations');
console.log('PASS: world shadow arsenal selection and outside-click dismissal');
