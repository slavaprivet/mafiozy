// Executes source UI bindings with stubs at the gameplay/network boundary.
// No joins, kicks, purchases, profile deletion, browser navigation or sockets run.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as hudModule from './world_walk_hud_data.mjs';
import {WALK_HUD_SHELL_CSS} from './walk_hud_shell.mjs';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r/g,'');
const functionSource=name=>{const start=source.search(new RegExp('^(?:async )?function '+name+'\\(','m'));assert(start>=0,name+' exists');const end=source.indexOf('\n}',start);assert(end>start);return source.slice(start,end+2)};
class Element{
 constructor(attrs={}){this.attrs=attrs;this.dataset={};this.listeners=new Map();this.hidden=false;this.textContent='';this.classes=new Set();this.classList={contains:s=>this.classes.has(s),add:s=>this.classes.add(s),remove:s=>this.classes.delete(s),toggle:(s,on)=>on?this.classes.add(s):this.classes.delete(s)};for(const[k,v]of Object.entries(attrs))if(k.startsWith('data-'))this.dataset[k.slice(5).replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]=v}
 addEventListener(type,callback){const list=this.listeners.get(type)||[];list.push(callback);this.listeners.set(type,list)}
 getAttribute(name){return this.attrs[name]??null}getClientRects(){return this.hidden?[]:[{}]}closest(){return null}focus(){}click(){const event={target:this,stopPropagation(){}};for(const callback of this.listeners.get('click')||[])callback(event);this.onclick?.(event)}
}
const calls=[],record=(name,result=true)=>(...args)=>{calls.push([name,...args]);return result};
const els=new Map(),profile=new Element(),status=new Element();status.click=record('role_help');els.set('profileModal',profile);els.set('jobStatusHud',status);
const doc={getElementById:id=>els.get(id)||null,querySelectorAll:()=>[]};
const context={hudModule,Promise,document:doc,_walkRendererActive:()=>context.active,active:true,_npcEmpires:[{leader_id:'leila'}],_policeState:{employed:true},_mafiaState:{employed:true},_customGang:{role:'leader'},switchProfileTab:record('profile-tab'),toggleProfileModal:()=>{calls.push(['profile-open']);profile.classes.add('show')},openGameMainMenu:record('menu'),openNewspaper:record('newspaper'),_openMissions:record('missions'),openNpcSandboxDashboard:record('empires'),openNpcEmpirePanel:record('boss'),loadCustomGangState:record('gang-refresh'),openPoliceServiceBoard:record('police'),openMafiaBoard:record('mafia'),openCustomGangModal:record('gang_manage'),switchModeFlow:record('mode'),showExactMoneyHudTemporarily:record('money'),window:{MafioziWalkHud:{openGang:record('gang'),openStatus:record('status')}},fetch(){throw Error('Network forbidden in action parity test')}};
vm.createContext(context);const start=source.indexOf('let _walkHudFacade = null'),end=source.indexOf('window.Mafiozi3DBridge = Object.freeze({',start);assert(start>0&&end>start);
vm.runInContext(source.slice(start,end).replace("import('./assets/maps/city_rebuild_v1/world_walk_hud_data.mjs')",'Promise.resolve(hudModule)'),context);await new Promise(resolve=>setImmediate(resolve));
const route=async(action,payload={id:'leila'})=>{context.action=action;context.payload=payload;return await vm.runInContext('_walkHudFacade.performWalkHudAction(action,payload)',context)};
for(const action of hudModule.WALK_HUD_ACTIONS)assert.equal((await route(action)).accepted,true,action+' routes to existing source UI');
assert(!calls.some(c=>c[0]==='gang-refresh'),'opening the roster must not call state GET with implicit gang creation');
for(const name of ['menu','newspaper','missions','empires','boss','gang','status','role_help','police','mafia','gang_manage','mode','money'])assert(calls.some(c=>c[0]===name),name+' actual source callback');
assert(calls.some(c=>c[0]==='profile-tab'&&c[1]==='status'));assert(calls.some(c=>c[0]==='profile-tab'&&c[1]==='inv'));assert(calls.some(c=>c[0]==='profile-tab'&&c[1]==='biz'));assert.equal(calls.filter(c=>c[0]==='profile-open').length,1,'already-open profile only switches tabs');
assert.deepEqual(calls.find(c=>c[0]==='boss'),['boss','leila',false],'dashboard boss button does not launch assault');
let count=calls.length;assert.equal((await route('boss',{id:'forged'})).accepted,false);assert.equal((await route('delete_character')).accepted,false);assert.equal(calls.length,count);
for(const [action,state]of [['police',context._policeState],['mafia',context._mafiaState]]){state.employed=false;count=calls.length;assert.equal((await route(action)).accepted,false);assert.equal(calls.length,count);state.employed=true}
context._customGang.role='member';count=calls.length;assert.equal((await route('gang_manage')).accepted,false);assert.equal(calls.length,count);context.active=false;assert.equal((await route('inventory')).accepted,false);assert.equal(calls.length,count);

// Every static main-menu button is bound by the original source binder.
const menuHtml=source.slice(source.indexOf('<div id="gameMainMenu"'),source.indexOf('<div id="cityLoadingScreen"'));
const buttons=[];for(const match of menuHtml.matchAll(/<button\b([^>]*)>/g)){const attrs={};for(const attr of match[1].matchAll(/([\w-]+)(?:="([^"]*)")?/g))attrs[attr[1]]=attr[2]??'';const node=new Element(attrs);buttons.push(node);if(attrs.id)els.set(attrs.id,node)}
const menu=new Element(),volume=new Element(),confirm=new Element(),question=new Element(),kicker=new Element();els.set('gameMainMenu',menu);els.set('gmmVolume',volume);els.set('gmmCharacterConfirm',confirm);els.set('gmmCharacterConfirmQuestion',question);
const select=selector=>buttons.find(b=>Object.keys(b.attrs).some(attr=>selector==='['+attr+']'))||null;
const yes=buttons.find(b=>b.attrs['data-character-confirm']==='yes'),no=buttons.find(b=>b.attrs['data-character-confirm']==='no');
confirm.querySelector=selector=>selector==='[data-character-confirm="yes"]'?yes:selector==='[data-character-confirm="no"]'?no:kicker;
doc.body=new Element();doc.documentElement=new Element();doc.querySelectorAll=selector=>buttons.filter(b=>Object.keys(b.attrs).some(attr=>selector==='['+attr+']'));doc.querySelector=select;
const menuCalls=[],menuRecord=name=>(...args)=>menuCalls.push([name,...args]);
Object.assign(context,{_gameProfilesLoaded:true,_gameProfiles:[],_gameMenuCharacterReady:true,_DIRECT_WORLD_ENTRY:false,_LOCAL_PREVIEW:false,_UP:new URLSearchParams(),QP:{look:{}},_gameMenuSettings:{volume:50,vibration:true},_gameMenuPanel:menuRecord('panel'),_gameMenuEnterSelected:menuRecord('enter'),_gameMenuPrimaryAction:menuRecord('primary'),_gameMenuExit:menuRecord('exit'),_gameMenuInviteFriends:menuRecord('invite'),_openCharacterCreator:menuRecord('create'),_gameMenuNextCharacter:menuRecord('next'),_applyGameMenuSettings:menuRecord('settings'),_renderGameMenuCharacter(){},_renderGameProfiles(){},_renderGameMenuSave(){},_setGameMenuCharacterReady(){},_loadGameProfiles:menuRecord('source-profile-load'),showToast:menuRecord('toast')});context.window.addEventListener=()=>{};
vm.runInContext(functionSource('_bindEarlyAddCharacter')+'\n'+functionSource('_bindGameMenuActions')+'\n_bindGameMenuActions();',context);
const boundButtons=buttons.filter(b=>!('data-character-confirm'in b.attrs));for(const button of boundButtons){assert((button.listeners.get('click')||[]).length>0,JSON.stringify(button.attrs)+' has actual binding');button.click()}
for(const name of ['primary','enter','exit','invite','create','next'])assert(menuCalls.some(c=>c[0]===name),name+' wired');assert(menuCalls.some(c=>c[0]==='panel'&&c[1]==='settings'));assert(menuCalls.some(c=>c[0]==='panel'&&c[1]==='root'));
volume.listeners.get('input')[0]({target:{value:'85'}});assert.equal(context._gameMenuSettings.volume,85);assert.equal(context._gameMenuSettings.vibration,false);
const initialBindings=boundButtons.map(b=>b.listeners.get('click').length);vm.runInContext('_bindGameMenuActions()',context);assert.deepEqual(boundButtons.map(b=>b.listeners.get('click').length),initialBindings,'original binder remains idempotent');
context._gameProfiles=[{},{},{}];els.get('gmmAddCharacter').click();assert.equal(menuCalls.at(-1)[0],'toast','full account slot guard preserved');
vm.runInContext(functionSource('_gameMenuConfirm'),context);context.answerPromise=vm.runInContext("_gameMenuConfirm('<untrusted name>')",context);assert.equal(question.textContent,'<untrusted name>');no.click();assert.equal(await context.answerPromise,false);assert(confirm.hidden);context.answerPromise=vm.runInContext("_gameMenuConfirm('Играть?')",context);yes.click();assert.equal(await context.answerPromise,true);assert(confirm.hidden);
const profileHost=new Element(),profileCard=new Element({'data-profile-select':'test-profile'}),profileDelete=new Element({'data-profile-delete':'test-profile'}),profileCreate=new Element({'data-profile-create':''});els.set('gmmProfiles',profileHost);
profileHost.querySelectorAll=selector=>({'[data-profile-select]':[profileCard],'[data-profile-delete]':[profileDelete],'[data-profile-create]':[profileCreate],'[data-profile-canvas]':[]})[selector]||[];
context._gameProfiles=[{character_id:'test-profile',slot:1,name:'Test',has_look:true}];context._profileEsc=value=>String(value??'');context._profileRole=()=> 'Гражданский';context._selectGameProfile=menuRecord('select-profile-stub');context._deleteGameProfile=menuRecord('delete-profile-stub');
vm.runInContext(functionSource('_renderGameProfiles')+'\n_renderGameProfiles();',context);
assert(profileCard.listeners.has('keydown'),'focusable character card has real keyboard listener');const profileKey=profileCard.listeners.get('keydown')[0];let keyboardPrevented=0,keyboardStopped=0;
const keyEvent=(key,overrides={})=>({key,target:profileCard,repeat:false,preventDefault(){keyboardPrevented++},stopPropagation(){keyboardStopped++},...overrides});
profileKey(keyEvent('Enter'));profileKey(keyEvent(' '));assert.equal(menuCalls.filter(c=>c[0]==='select-profile-stub').length,2,'Enter and Space call existing click/select route');assert.equal(keyboardPrevented,2);assert.equal(keyboardStopped,2);
profileKey(keyEvent('Enter',{repeat:true}));profileKey(keyEvent(' ',{target:profileDelete}));profileKey(keyEvent('Escape'));assert.equal(menuCalls.filter(c=>c[0]==='select-profile-stub').length,2,'repeat, nested delete and unrelated key cannot select account');
profileDelete.click();assert.equal(menuCalls.filter(c=>c[0]==='delete-profile-stub').length,1);profileCreate.click();assert.equal(menuCalls.at(-1)[0],'create');
for(const id of ['gameMainMenu','profileModal','newspaperModal','missionsModal','modeModal','npcEmpireOverlay','customGangModal','policeModal'])assert(hudModule.WALK_HUD_SOURCE_PANEL_IDS.includes(id),id+' participates in input locking');
for(const id of ['profileModal','newspaperModal','missionsModal','modeModal','npcEmpireOverlay','customGangModal','policeModal'])assert(WALK_HUD_SHELL_CSS.includes('#'+id),id+' has scoped walk theme');
console.log(JSON.stringify({passed:true,hudActions:hudModule.WALK_HUD_ACTIONS.length,mainMenuButtons:boundButtons.length+2,checks:['source_callbacks_not_reimplemented','profile_existing_tabs','boss_allowlist_no_assault','role_capability_guards','inactive_renderer_guard','all_static_main_menu_buttons','settings_original_handler','main_menu_idempotent_bind','three_profile_slot_guard','confirmation_yes_no_literal_text','dynamic_character_select_delete_create_routes','character_Enter_Space_nested_repeat_guards','source_modal_input_lock_coverage','scoped_modal_theme_coverage','no_network']}));
