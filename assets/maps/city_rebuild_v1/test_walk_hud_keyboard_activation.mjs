import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

// Run the production keyboard listener, including its admission guards.
const source=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const start=source.indexOf("addEventListener('keydown',e=>{",source.indexOf("addEventListener('blur',()=>keys.clear());")+1);
const end=source.indexOf('function beginJump(',start);
assert(start>=0&&end>start);
let listener,jumps=0;
const keys=new Set();
runInNewContext(source.slice(start,end),{
 addEventListener(type,callback){assert.equal(type,'keydown');listener=callback;},
 hudInputBlocked:()=>false,arsenalOpen:()=>false,keys,beginJump(){jumps++;},
});
const press=(target,extra={})=>{
 keys.clear();jumps=0;
 const event={code:'Space',target,repeat:false,timeStamp:100,defaultPrevented:false,preventDefault(){this.defaultPrevented=true;},...extra};
 listener(event);return {prevented:event.defaultPrevented,jumps,held:keys.has('Space')};
};
const idle={prevented:false,jumps:0,held:false},button={tagName:'BUTTON'};
assert.deepEqual(press(button),idle,'focused HUD button keeps native Space activation');
const shadowHost={tagName:'CUSTOM-HOST'},span={tagName:'SPAN'};
assert.deepEqual(press(shadowHost,{composedPath:()=>[span,button,shadowHost]}),idle,'button in composed path keeps native activation');
for(const tagName of ['INPUT','TEXTAREA','SELECT'])assert.deepEqual(press({tagName}),idle,tagName+' still ignores game Space');
assert.deepEqual(press({tagName:'DIV',isContentEditable:true}),idle,'editable still ignores game Space');
assert.deepEqual(press({tagName:'CANVAS'}),{prevented:true,jumps:1,held:true},'canvas Space retains one jump and held state');
assert.deepEqual(press({tagName:'CANVAS'},{repeat:true}),{prevented:true,jumps:0,held:true},'canvas repeat does not trigger another jump');
console.log('PASS actual walk Space admission: HUD button, shadow path, text controls, canvas jump and repeat');
