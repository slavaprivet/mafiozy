import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {MERCENARY_CHATTER_LINES,createMercenaryChatterDirector,createMercenarySpeech,createMercenaryChatter,selectMercenaryVoice} from './mercenary_chatter.mjs';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)'),fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);
function setup(){let now=100000,seq=0,hidden=false;const lines=[],director=createMercenaryChatterDirector({clock:()=>now,random:()=>.38,isHidden:()=>hidden,onLine:e=>lines.push(e)});return{director,lines,advance:ms=>{now+=ms;director.update();},hide:v=>hidden=v,event:(extra={})=>({seq:++seq,at:now,speakerId:'crew',name:'Лука',profession:'bruiser',kind:'idle',alive:true,distance:3,busy:false,anyCombat:false,...extra})};}
test('authored pools cover every profession and action; shuffle bags avoid repeat within a cycle',()=>{
 let count=0;for(const section of Object.values(MERCENARY_CHATTER_LINES))for(const pool of Object.values(section)){count+=pool.length;assert.equal(new Set(pool).size,pool.length);assert(pool.every(line=>typeof line==='string'&&line.length<95));}assert(count>=250);
 for(const profession of ['bruiser','medic','engineer','safecracker','demolitions']){const f=setup(),pool=MERCENARY_CHATTER_LINES[profession].idle,seen=[];for(let i=0;i<pool.length+1;i++){assert(f.director.accept(f.event({profession})));seen.push(f.lines.at(-1).text);f.advance(25000);}assert.equal(new Set(seen.slice(0,pool.length)).size,pool.length);assert.notEqual(seen.at(-1),seen.at(-2));}
});
test('one global speaker, exact first V/X phrases, throttled command spam and no old replay',()=>{
 const f=setup();assert(f.director.accept(f.event()));assert.equal(f.director.accept(f.event({speakerId:'another',kind:'combat',profession:'demolitions'})),false);
 assert(f.director.accept(f.event({speakerId:'player',kind:'follow'})));assert.equal(f.lines.at(-1).text,'Все ко мне!');assert.equal(f.director.accept(f.event({speakerId:'player',kind:'rally'})),false);f.advance(1800);assert(f.director.accept(f.event({speakerId:'player',kind:'rally'})));assert.equal(f.lines.at(-1).text,'Все сюда!');
 const stale=f.event();f.advance(10000);assert.equal(f.director.accept(stale),false);const fresh=f.event({kind:'combat'});assert(f.director.accept(fresh));f.advance(10000);assert.equal(f.director.accept(fresh),false);
});
test('idle is nearby, calm and unoccupied; hidden scene cancels captions without backlog',()=>{
 const f=setup();for(const flags of [{distance:13},{anyCombat:true},{busy:true},{alive:false}])assert.equal(f.director.accept(f.event(flags)),false);assert(f.director.accept(f.event()));f.hide(true);f.director.update();assert.equal(f.director.active,null);assert.equal(f.director.accept(f.event({speakerId:'player',kind:'follow'})),false);f.hide(false);f.advance(30000);assert.equal(f.director.active,null);
});
function speechFixture(){const handlers=new Map(),calls=[],stats={cancel:0},doc={hidden:false,addEventListener:(n,fn)=>handlers.set(n,fn),removeEventListener:n=>handlers.delete(n)};let volume=.5,voices=[{lang:'ru-RU',name:'Local Russian',localService:true}];const synth={speaking:false,pending:false,getVoices:()=>voices,speak:u=>calls.push(u),cancel:()=>stats.cancel++},win={speechSynthesis:synth,SpeechSynthesisUtterance:class{constructor(text){this.text=text;}}};return{calls,handlers,stats,doc,synth,setVolume:v=>volume=v,setVoices:v=>voices=v,audio:createMercenarySpeech({window:win,document:doc,getVolume:()=>volume})};}
test('Russian TTS requires trusted input and respects mute without playing stale captions afterward',()=>{
 const f=speechFixture(),line={text:'Все ко мне!',speakerId:'player'};assert.equal(f.audio.speak(line),false);f.handlers.get('keydown')({isTrusted:false});assert.equal(f.audio.speak(line),false);f.handlers.get('keydown')({isTrusted:true});assert.equal(f.calls.length,0);assert(f.audio.speak(line));assert.equal(f.calls[0].lang,'ru-RU');assert.equal(f.calls[0].volume,.5);
 f.setVolume(0);f.audio.update();assert.equal(f.stats.cancel,1);assert.equal(f.audio.speak(line),false);f.setVolume(.8);f.audio.update();assert.equal(f.calls.length,1);f.setVoices([]);assert.equal(f.audio.speak(line),false);assert.equal(f.calls.length,1);f.audio.dispose();assert.equal(f.handlers.size,0);
});
test('new speech cancels only owned utterance; external utterance is not interrupted and hidden pauses',()=>{
 const f=speechFixture();f.handlers.get('pointerdown')({isTrusted:true});f.synth.speaking=true;assert.equal(f.audio.speak({text:'Раз'}),false);assert.equal(f.stats.cancel,0);f.synth.speaking=false;assert(f.audio.speak({text:'Раз'}));assert.equal(f.audio.speak({text:'Два'}),false);assert.equal(f.stats.cancel,0);f.calls[0].onend();assert(f.audio.speak({text:'Два'}));f.doc.hidden=true;f.audio.update();assert.equal(f.stats.cancel,1);assert.equal(f.audio.speak({text:'Три'}),false);
});
test('source publishes only fresh accepted V/X/task events and leaves ordinary gang speech to legacy',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer'),events=[];f.api.follow();const unbind=f.api.bindChatter(e=>{events.push(e);return true;});assert.equal(events.length,0);f.api.bindTargets({canMove:()=>true});assert(f.api.follow().ok);assert.equal(events.at(-1).kind,'follow');assert(f.api.rally({x:50,y:0,z:41}).ok);assert.equal(events.at(-1).kind,'rally');const count=events.length;f.api.rally({x:10000,z:0});assert.equal(events.length,count);
 const target={id:'panel',kind:'power_panel',powered:true,position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{target.powered=false;return true;}});f.api.command('disable_power',target);for(let i=0;i<130;i++)f.tick(.05);assert.equal(events.filter(e=>e.kind==='task').length,1);assert.equal(events.filter(e=>e.kind==='done').length,1);assert(events.every((e,i)=>i===0||e.seq>events[i-1].seq));assert.equal(f.api.chatterEvent('ordinary','idle'),null);unbind();assert.equal(f.api.chatterEvent(m.id,'idle'),null);
});
test('own conversation holds idle follow within 2.5m but preserves work, releases on close and rejects distance',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer');f.api.bindTargets({canMove:()=>true});m.r=10;m.c=10;assert(f.api.beginConversation(m.id).ok);const before={r:m.r,c:m.c};for(let i=0;i<10;i++)f.tick(.1);assert.deepEqual({r:m.r,c:m.c},before);assert(f.api.endConversation(m.id));f.tick(.1);assert.notDeepEqual({r:m.r,c:m.c},before);
 m.c=10;m.r=10;const target={id:'panel',kind:'power_panel',powered:true,position:{x:41,y:0,z:41}};let calls=0;f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{calls++;return true;}});f.api.command('disable_power',target);assert(f.api.beginConversation(m.id).ok);for(let i=0;i<110;i++)f.tick(.05);assert.equal(calls,1);f.ctx.player.c=20;assert.equal(f.api.beginConversation(m.id).ok,false);
});

test('actual speech completes before queued command starts; caption timeout never cancels it',()=>{
 const f=speechFixture();f.doc.createElement=()=>({dataset:{},style:{},setAttribute(){},remove(){}});f.doc.body={append(){}};let now=100000,listener;const captions=[],host={bindChatter:fn=>(listener=fn,()=>{}),getChatterSettings:()=>({volume:.5}),getMember:()=>({hp:100})};
 const widget=createMercenaryChatter({host,window:{speechSynthesis:f.synth,SpeechSynthesisUtterance:class{constructor(text){this.text=text;}}},document:f.doc,clock:()=>now,onCaption:line=>captions.push(line)});f.handlers.get('keydown')({isTrusted:true});
 listener({seq:1,at:now,speakerId:'crew',name:'Боец',profession:'engineer',kind:'greeting',alive:true,distance:2});assert.equal(f.calls.length,1);const first=f.calls[0];now+=5200;widget.update();assert.equal(f.stats.cancel,0);assert(widget.active,'spoken line still captions after former five-second expiry');
 listener({seq:2,at:now,speakerId:'player',name:'Босс',kind:'follow'});assert.equal(f.calls.length,1);assert.equal(f.stats.cancel,0);assert.equal(widget.stats().pending,1);first.onend();now+=300;widget.update();assert.equal(f.calls.length,2);assert.equal(f.calls[1].text,'Все ко мне!');assert.equal(f.stats.cancel,0);widget.dispose();
});

test('voice queue has two slots, discards stale commands and cannot replay hidden backlog',()=>{
 let now=100000,speaking=false,seq=0,hidden=false;const lines=[],d=createMercenaryChatterDirector({clock:()=>now,isSpeaking:()=>speaking,isHidden:()=>hidden,onLine:e=>lines.push(e)}),event=kind=>({seq:++seq,at:now,speakerId:'player',kind});
 assert(d.accept(event('follow')));speaking=true;for(let i=0;i<5;i++){now+=100;assert(d.accept(event('rally')));}assert.equal(d.stats().pending,2);assert.equal(lines.length,1);now+=6000;speaking=false;d.update();d.update();assert.equal(lines.length,1);assert.equal(d.stats().pending,0);
 speaking=true;assert(d.accept(event('follow')));hidden=true;d.update();hidden=false;speaking=false;d.update();assert.equal(d.stats().pending,0);assert.equal(lines.length,1);
});

test('Russian voice selection uses real known sex metadata or names, honestly reuses sole installed voice',()=>{
 const male={lang:'ru-RU',name:'Microsoft Pavel',localService:true},female={lang:'ru-RU',name:'Microsoft Irina',localService:true},unknown={lang:'ru-RU',name:'System Russian',localService:true};assert.equal(selectMercenaryVoice([female,male],0),male);assert.equal(selectMercenaryVoice([male,female],1),female);assert.equal(selectMercenaryVoice([male],1),male);assert.equal(selectMercenaryVoice([unknown],0),unknown);
 const f=speechFixture();f.setVoices([male,female]);f.handlers.get('keydown')({isTrusted:true});assert(f.audio.speak({text:'Слушаю',gender:1}));assert.equal(f.calls[0].voice,female);assert.equal(f.calls[0].pitch,1);assert.equal(f.audio.stats().genderMatched,true);f.calls[0].onend();assert(f.audio.speak({text:'Слушаю',gender:0}));assert.equal(f.calls[1].voice,male);
});

test('hover greeting faces nearby own member smoothly, respects sex, cooldown, work, combat, death and V',async()=>{
 const f=await fixture({qa:true}),m=f.recruit('engineer'),events=[];m.c=10.4;m.r=10;m.ang=0;m.look.gender=1;f.api.bindChatter(e=>{events.push(e);return true;});f.api.bindTargets({canMove:()=>true});assert(f.api.greetMember(m.id));assert.equal(events.at(-1).kind,'greeting');assert.equal(events.at(-1).gender,1);assert.equal(f.api.greetMember(m.id),false);
 const start={r:m.r,c:m.c};for(let i=0;i<8;i++)f.tick(.2);assert.deepEqual({r:m.r,c:m.c},start);assert(Math.abs(Math.abs(m.ang)-Math.PI)<.01);f.api.follow();assert.equal(m._mercenaryGreetingUntil,undefined);
 for(const alter of [()=>m.hp=0,()=>m.targetKind='street_npc',()=>m.c=20]){m.hp=80;m.targetKind=null;m.c=10.4;m._mercenaryNextGreetingAt=0;alter();assert.equal(f.api.greetMember(m.id),false);}
 m.hp=80;m.targetKind=null;m.c=10.4;const target={id:'work',kind:'power_panel',powered:true,position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,canMove:()=>true});assert(f.api.command('disable_power',target).ok);m._mercenaryNextGreetingAt=0;assert.equal(f.api.greetMember(m.id),false);
});
