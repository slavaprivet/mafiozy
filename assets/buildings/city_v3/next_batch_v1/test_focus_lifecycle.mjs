import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const world=fs.readFileSync(new URL('../../../../world.html',import.meta.url),'utf8');
const source=fs.readFileSync(new URL('../../../../three_preview.js',import.meta.url),'utf8');
function bodyAt(text,needle){const s=text.indexOf(needle);assert(s>=0,needle);let i=text.indexOf('{',s),depth=0;for(;i<text.length;i++){if(text[i]==='{')depth++;if(text[i]==='}'&&!--depth)return text.slice(s,i+1);}throw Error(needle);}
const helper=name=>bodyAt(world,`function ${name}(`);
const applyMethod=bodyAt(world,"previewApproachCityV3Building(key='civic_hall_landmark@1')");
const start=source.indexOf("const cityV3FocusKey=rendererParams.get('cityv3focus')"),end=source.indexOf('// Стартуем только',start);
const prepareSource=source.slice(start,end);
const commitSource=bodyAt(source,'if(cityV3StartupFocusKey){');
assert(!prepareSource.includes('previewApproachCityV3Building?.('),'early phase is read-only');
const applyIndex=source.indexOf('if(cityV3StartupFocusKey){');
assert(source.indexOf('cityV3NextInstance=await Promise.race')<applyIndex);
assert(source.indexOf('cityV3GlassInstance=await Promise.race')<applyIndex);
assert(applyIndex<source.indexOf('const worldSnapshot=bridge?.getWorldSnapshot'));
assert(!commitSource.includes('setTimeout')&&!commitSource.includes('setInterval'));
let now=1000,teleports=0;
const player={r:150,c:120,tr:150,tc:120,vr:1,vc:1,walking:true},window={},document={documentElement:{dataset:{}}},renderer={domElement:{dataset:{}}};
const context=vm.createContext({player,window,document,renderer,Date:{now:()=>now},Math,Object,JSON,String,
 _LOCAL_PREVIEW:true,_UP:new URLSearchParams('preview=1&previewcityv3=stage-a&cityv3buildings=1'),
 CITY_V3_CIVIC_PREVIEW_CONTRACT:{key:'civic_hall_landmark@1'},CITY_V3_ACCEPTED_PREVIEW_CONTRACTS:{},isBlockedPed:()=>false,
 rendererParams:new URLSearchParams('cityv3focus=glass_pavilion_small%401'),cityV3BuildingPreviewRequested:true,cityV3AcceptedCandidates:[],cityV3BuildingCandidate:null,
 originR:50.5,originC:66.9390243902439});
vm.runInContext(['_cityV3BuildingPreviewGateRequested','_cityV3BuildingFocusTarget','_cityV3GlassContract','_cityV3NextContractRecords','_cityV3NextHostContract'].map(helper).join('\n')+`\nconst host={${applyMethod}};`,context);
context.bridge={getPlayerState:()=>({...player}),getCityV3BuildingFocusTarget:key=>vm.runInContext(`_cityV3BuildingFocusTarget(${JSON.stringify(key)})`,context),previewApproachCityV3Building:key=>{teleports++;return vm.runInContext(`host.previewApproachCityV3Building(${JSON.stringify(key)})`,context);}};
vm.runInContext(prepareSource,context);assert.equal(teleports,0);assert.equal(player.r,150);assert.equal(window._studioTeleportUntil,undefined);
const planned=vm.runInContext('initialState',context);assert.equal(planned.r,50.5);assert.equal(planned.c,66.9390243902439);
// Slow GLB decode/network and server resnapshot happen while the player has
// never been moved. A 10-second grace period cannot expire before it exists.
now+=60000;player.r=180;player.c=125;
vm.runInContext(commitSource,context);assert.equal(teleports,1);assert.equal(player.r,50.5);assert.equal(player.c,66.9390243902439);
assert.equal(player.tr,player.r);assert.equal(player.tc,player.c);assert.equal(player.vr,0);assert.equal(player.vc,0);
assert.equal(window._studioTeleportUntil,now+10000);
const proof=JSON.parse(document.documentElement.dataset.cityV3StartupFocus);assert.equal(proof.applied,true);assert.equal(proof.count,1);assert.equal(proof.phase,'after-asset-install-before-snapshot');
assert.equal(proof.r,player.r);assert.equal(proof.c,player.c);assert.equal(renderer.domElement.dataset.cityV3StartupFocus,document.documentElement.dataset.cityV3StartupFocus);
now+=10001;player.r+=2;assert.equal(teleports,1,'no recurring pin after user starts walking');
console.log('PASS delayed startup focus: read-only origin planning, 60s async delay/server relocation, one final teleport before snapshot, fresh 10s grace, target+origin DOM proof, no recurring pin.');
