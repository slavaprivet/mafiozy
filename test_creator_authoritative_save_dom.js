'use strict';

// Execute the production creator save state machine without a browser. Every
// scenario is isolated and proves that only an authoritative HTTP response may
// unlock a character or redirect into the game.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('creator.html', 'utf8');
const worldSource = fs.readFileSync('world.html', 'utf8');
const start = source.indexOf('// ── SAVE ');
const endNeedle = "document.getElementById('save-btn')?.addEventListener('click',saveChar);";
const end = source.indexOf(endNeedle, start) + endNeedle.length;
assert(start >= 0 && end > start);
const productionSave = source.slice(start, end);

function response(ok, body) {
  return {ok, json: async () => body};
}

function makeScenario(options = {}) {
  const calls = [], markers = [], replacements = [], sent = [];
  const storage = new Map();
  const elements = {
    'save-btn': {disabled:false,textContent:'',attrs:{},setAttribute(k,v){this.attrs[k]=v;},addEventListener(){}},
    'save-status': {textContent:''},
    charName: {value:'QA Август',focus(){}},
  };
  let manifestCount = 0, postCount = 0, resolvePost = null;
  const fetch = async (url, init = {}) => {
    calls.push({url:String(url),method:init.method || 'GET',body:init.body || '',headers:init.headers || {}});
    if (!init.method) {
      manifestCount++;
      if (options.manifestFailure) throw new TypeError('Failed to fetch');
      return response(true, {base: options.freshApi || 'https://fresh.example.com'});
    }
    postCount++;
    if(options.deferredPost)return new Promise(resolve=>{resolvePost=()=>resolve(response(true,{ok:true,profile:{character_id:'800000000000789',has_look:true,starter_weapon:'nagan',starter_equipped:true}}));});
    if (options.postFailure) throw new TypeError('Failed to fetch');
    if (options.postResult) return response(true, options.postResult);
    return response(true, options.uid
      ? {ok:true,has_look:true}
      : {ok:true,profile:{character_id:'800000000000123',has_look:true,starter_weapon:'nagan',starter_equipped:true}});
  };
  const context = vm.createContext({
    console, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
    fetch,
    document: {documentElement:{dataset:{}},getElementById:id=>elements[id] || null},
    localStorage: {
      getItem:key=>storage.get(key)||null,
      setItem:(key,value)=>{storage.set(key,value);if(key.startsWith('mafiozi_character_ready_'))markers.push([key,value]);},
      removeItem:key=>storage.delete(key),
    },
    location: {
      href:'https://slavaprivet.github.io/mafiozy/creator.html?account_uid=990000021',
      hostname:'slavaprivet.github.io',replace:url=>replacements.push(String(url)),
    },
    state:{gender:0,skin:3,body:0,face:5,hair:1,hat:7},
    urlP:new URLSearchParams('account_uid=990000021'),
    creatorApi:options.creatorApi || '',
    creatorUid:options.uid || '', creatorAccount:options.account !== undefined ? options.account : '990000021',
    creatorReturn:'world.html', changeLookMode:false,
    tg:{initData:'signed-test-init-data',sendData:options.telegram ? data=>{if(options.telegramFailure)throw new Error('send failed');sent.push(data);} : undefined},
  });
  vm.runInContext(productionSave, context, {filename:'creator.html#authoritative-save'});
  return {context,calls,markers,replacements,sent,elements,storage,get manifestCount(){return manifestCount;},get postCount(){return postCount;},resolvePost:()=>resolvePost?.()};
}

async function run() {
  const empty = makeScenario();
  await vm.runInContext('saveChar()', empty.context);
  await new Promise(resolve=>setTimeout(resolve,150));
  assert.equal(empty.calls[0].method, 'GET');
  assert.match(empty.calls[0].url, /coop_api\.json/);
  assert.equal(empty.calls[1].url, 'https://fresh.example.com/profiles/990000021');
  const createPayload=JSON.parse(empty.calls[1].body);
  assert.match(createPayload.creation_token,/^[A-Za-z0-9._:-]{16,96}$/);
  assert.equal(empty.calls[1].headers['X-Telegram-Init-Data'],'signed-test-init-data');
  assert.equal(empty.storage.get('mafiozi_profile_creation_v1_990000021'),createPayload.creation_token);
  assert.deepEqual(JSON.parse(empty.storage.get('mafiozi_profile_creation_confirmed_v1_990000021')),
    {token:createPayload.creation_token,character_id:'800000000000123'});
  assert.deepEqual(empty.markers, [['mafiozi_character_ready_v1_800000000000123','1']]);
  assert.equal(empty.replacements.length, 1);
  assert.match(empty.replacements[0], /character=800000000000123/);
  assert.match(empty.replacements[0], /has_look=1/);
  assert.match(empty.replacements[0], /starter=nagan/);

  const deferred = makeScenario({deferredPost:true});
  const pendingSave = vm.runInContext('saveChar()', deferred.context);
  await new Promise(resolve=>setTimeout(resolve,0));
  assert.deepEqual(deferred.markers, []);
  assert.deepEqual(deferred.replacements, []);
  deferred.resolvePost();
  await pendingSave;
  await new Promise(resolve=>setTimeout(resolve,150));
  assert.deepEqual(deferred.markers, [['mafiozi_character_ready_v1_800000000000789','1']]);

  const stale = makeScenario({creatorApi:'https://dead.example.com'});
  await vm.runInContext('saveChar()', stale.context);
  assert.equal(stale.postCount, 1);
  assert.equal(stale.calls.find(call=>call.method==='POST').url,
    'https://fresh.example.com/profiles/990000021');

  const offline = makeScenario({manifestFailure:true});
  await vm.runInContext('saveChar()', offline.context);
  assert.equal(offline.postCount, 0);
  assert.deepEqual(offline.markers, []);
  assert.deepEqual(offline.replacements, []);
  assert.match(offline.elements['save-status'].textContent, /не сохранён/);

  const rejected = makeScenario({postFailure:true});
  await vm.runInContext('saveChar()', rejected.context);
  assert.equal(rejected.postCount, 1);
  assert.deepEqual(rejected.markers, []);
  assert.deepEqual(rejected.replacements, []);

  const malformed = makeScenario({postResult:{ok:true,profile:{has_look:true}}});
  await vm.runInContext('saveChar()', malformed.context);
  assert.deepEqual(malformed.markers, []);
  assert.deepEqual(malformed.replacements, []);
  assert.match(malformed.elements['save-status'].textContent, /не подтвердил/);

  const update = makeScenario({uid:'800000000000456'});
  await vm.runInContext('saveChar()', update.context);
  await new Promise(resolve=>setTimeout(resolve,150));
  assert.equal(update.calls.find(call=>call.method==='POST').url,
    'https://fresh.example.com/character/800000000000456/look');
  assert.deepEqual(update.markers, [['mafiozi_character_ready_v1_800000000000456','1']]);

  const telegram = makeScenario({account:'',telegram:true});
  await vm.runInContext('saveChar()', telegram.context);
  assert.equal(telegram.sent.length, 1);
  assert.deepEqual(telegram.markers, []);
  assert.deepEqual(telegram.replacements, []);
  assert.match(telegram.elements['save-btn'].textContent, /ЖДЁМ СЕРВЕР/);

  const telegramFail = makeScenario({account:'',telegram:true,telegramFailure:true});
  await vm.runInContext('saveChar()', telegramFail.context);
  assert.deepEqual(telegramFail.markers, []);
  assert.deepEqual(telegramFail.replacements, []);
  assert.match(telegramFail.elements['save-status'].textContent, /Не удалось/);

  assert(worldSource.includes("url.searchParams.set('save','server')"));
  console.log('creator authoritative save: empty/stale/offline/success/update/telegram OK');
}

run().catch(error => {console.error(error);process.exitCode=1;});
