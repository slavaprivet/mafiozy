import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {prepareGameplayMigration,resolveMigrationIdentity,translateWorldAnchors} from './gameplay_migration.mjs';

const root=new URL('../../../',import.meta.url);
const ledger=JSON.parse(readFileSync(new URL('docs/city-rebuild/rebuild-ledger.generated.json',root),'utf8'));
const source=readFileSync(new URL('world.html',root),'utf8');
function literal(name,context={}) {
  const match=source.match(new RegExp(`const ${name} = (\\[[\\s\\S]*?\\n\\]);`));
  assert.ok(match,`real host registry ${name}`);
  return JSON.parse(JSON.stringify(vm.runInNewContext('('+match[1]+')',context,{timeout:1000})));
}
const registries={banks:literal('BANKS'),businesses:literal('BUSINESS_POIS'),
  pois:literal('POI',{MAIN_BLACKMARKET_SITE:{r:6,c:26}})};
const base={mode:'isolated-preview',persistence:'disabled',serverSession:'isolated-preview',registries};
const baseline=JSON.stringify({ledger,base});
let count=0;
function test(name,fn){fn();count++;console.log('PASS '+name);}
const build=(l=ledger,o={})=>prepareGameplayMigration(l,{...base,...o});
const bad=(change,code)=>{const l=structuredClone(ledger);change(l);const result=build(l);assert.equal(result.ok,false);assert.equal(result.stage,null);assert.ok(result.errors.some(e=>e.code===code),JSON.stringify(result.errors));};
const result=build(),stage=result.stage;
test('actual host definitions are accepted atomically',()=>{assert.equal(result.ok,true,JSON.stringify(result.errors));assert.equal(stage.registries.banks.length,3);assert.equal(stage.registries.businesses.length,10);assert.equal(stage.registries.pois.length,17);assert.equal(stage.remaps.length,30);});
test('IDs, names, economics, bank size and bank/interior links remain unchanged',()=>{
  for(const key of Object.keys(registries))for(const original of registries[key]){
    const transformed=stage.registries[key].find(r=>r.id===original.id);
    const unchanged=structuredClone(transformed);unchanged.r=original.r;unchanged.c=original.c;
    assert.deepEqual(unchanged,original);
  }
  for(const row of stage.remaps)assert.deepEqual(row.interior,ledger.rows.find(x=>x.id===row.id).interior??null);
});
test('all five major aliases resolve to existing POIs, not extra buildings',()=>{
  assert.equal(Object.keys(stage.aliasIndex).filter(x=>x.startsWith('major:')).length,5);
  for(const id of ['market','casino','factory','mansion','port']){
    assert.equal(resolveMigrationIdentity(stage,'major:'+id),resolveMigrationIdentity(stage,'poi:'+id));
    assert.equal(stage.serverAnchors.majorObjectsRC[id].canonicalId,'poi:'+id);
  }
  assert.notEqual(resolveMigrationIdentity(stage,'business:casino'),resolveMigrationIdentity(stage,'major:casino'));
  assert.notEqual(resolveMigrationIdentity(stage,'business:port'),resolveMigrationIdentity(stage,'major:port'));
});
test('coincident port sites retain both identities and disclose conflict',()=>{
  assert.ok(result.warnings.some(x=>x.code==='DISTINCT_IDENTITIES_SHARE_DESTINATION'&&x.ids.includes('business:port')&&x.ids.includes('poi:port')));
  assert.equal(stage.registries.businesses.filter(x=>x.id==='port').length,1);
  assert.equal(stage.registries.pois.filter(x=>x.id==='port').length,1);
});
test('nested world doors/services move but local interior coordinates do not',()=>{
  const original={id:'x',r:10,c:20,entryR:11,entryC:22,entry:{r:12,c:23,approach:{r:13,c:24}},
    vehicleStops:[{r:9,c:18}],route:[[10,20],[11,21]],interior:{spawn:{r:3,c:4}},metadata:{r:999,c:999}};
  const moved=translateWorldAnchors(original,[5,-2]);
  assert.deepEqual(moved.entry,{r:17,c:21,approach:{r:18,c:22}});assert.deepEqual(moved.vehicleStops,[{r:14,c:16}]);
  assert.deepEqual(moved.route,[[15,18],[16,19]]);assert.deepEqual(moved.interior,original.interior);assert.deepEqual(moved.metadata,original.metadata);
  assert.equal(moved.entryR,16);assert.equal(moved.entryC,20);assert.equal(original.r,10);
  assert.throws(()=>translateWorldAnchors(original,[5,-2],['interior']),/Interior/);
});
test('hospital respawn offset and server XY ordering are preserved',()=>{
  const hospital=stage.registries.pois.find(x=>x.id==='hospital');
  const respawn=stage.services.find(x=>x.namespace==='respawn');assert.equal(respawn.r,hospital.r-3);assert.equal(respawn.c,hospital.c-3);
  for(const b of stage.registries.businesses)assert.deepEqual(stage.serverAnchors.businessWorldPosXY[b.id],[b.c,b.r]);
  const xy=stage.serverAnchors.servicesXY.find(x=>x.namespace==='respawn');assert.equal(xy.x,respawn.c);assert.equal(xy.y,respawn.r);
});
test('protected police, custody, nested gate and geometry are exactly unchanged',()=>{
  assert.deepEqual(stage.registries.pois.find(x=>x.id==='police'),registries.pois.find(x=>x.id==='police'));
  assert.deepEqual(stage.services.filter(x=>x.owner==='poi:police'),ledger.serviceAnchors.filter(x=>x.owner==='poi:police'));
  assert.deepEqual(stage.immutableGeometry,ledger.immutableGeometry);
});
test('dynamic snapshot preserved without rekey, activation or persistence',()=>{
  const dynamic=[{kind:'building',holding_id:'0,3',operation_type:'pawnshop',upgrades:{safe:3},interior:{id:'owned-0,3'}},{kind:'hq',holding_id:'5,7'}];
  const r=build(ledger,{dynamicProperties:dynamic});assert.deepEqual(r.stage.dynamicProperties.snapshot,dynamic);
  assert.notEqual(r.stage.dynamicProperties.snapshot,dynamic);assert.equal(r.stage.dynamicProperties.disposition,'suspended_unchanged');
  assert.equal(r.stage.readyForMain,false);assert.equal(r.stage.readyForWorldPlacement,false);
});
test('unknown main ownership, enabled saves and live server reject',()=>{
  for(const override of [{mode:'main'},{persistence:'enabled'},{serverSession:'production'}])assert.equal(build(ledger,override).ok,false);
});
test('missing planned site rejects rather than drops instance',()=>bad(l=>{l.rows.find(x=>x.id==='business:coffee').plannedRC=null;},'PRIMARY_DESTINATION_MISSING'));
test('moved police rejects',()=>bad(l=>{l.rows.find(x=>x.id==='poi:police').plannedRC=[77,76];},'POLICE_IMMUTABLE'));
test('new business anchor cannot occupy police envelope',()=>bad(l=>{l.rows.find(x=>x.id==='business:coffee').plannedRC=[97,89.5];},'PROTECTED_ENVELOPE_ANCHOR'));
test('new business anchor cannot occupy immutable bridge',()=>bad(l=>{l.rows.find(x=>x.id==='business:coffee').plannedRC=[50,90];},'PROTECTED_ENVELOPE_ANCHOR'));
test('duplicate stable ID and conflicting alias reject',()=>{
  bad(l=>l.rows.push(structuredClone(l.rows[0])),'DUPLICATE_OR_INVALID_ID');
  bad(l=>l.rows.find(x=>x.id==='poi:market').aliases.push('business:coffee'),'ALIAS_COLLISION');
});
test('missing major alias cannot silently remove server identity',()=>bad(l=>{l.rows.find(x=>x.id==='poi:market').aliases=[];},'MAJOR_ALIAS_MISSING_OR_CHANGED'));
test('nonfinite/out-of-bounds coordinates reject',()=>{
  bad(l=>{l.rows[0].plannedRC=[Infinity,30];},'PRIMARY_DESTINATION_MISSING');
  bad(l=>{l.rows[0].plannedRC=[200,30];},'DESTINATION_OUT_OF_BOUNDS');
});
test('stale host anchor, missing host ID and extra host ID reject whole stage',()=>{
  for(const edit of [r=>{r.banks[0].r+=1;},r=>r.businesses.pop(),r=>r.pois.push({id:'new_unknown',r:1,c:1})]){
    const changed=structuredClone(registries);edit(changed);const r=build(ledger,{registries:changed});assert.equal(r.ok,false);assert.equal(r.stage,null);
  }
});
test('invalid nested anchor rejects instead of retaining half-old coordinate',()=>{
  const changed=structuredClone(registries);changed.businesses[0].entry={r:2};
  assert.ok(build(ledger,{registries:changed}).errors.some(e=>e.code==='NESTED_ANCHOR_INVALID'));
});
test('unplanned non-primary sites remain explicit deferred ledger records',()=>{
  assert.equal(stage.deferred.length,ledger.rows.filter(x=>!/^(bank|business|poi):/.test(x.id)).length);
  assert.ok(stage.deferred.some(x=>x.id==='gas-station:0'));assert.ok(stage.deferred.some(x=>x.id.startsWith('rail-station:')));
});
test('inputs unchanged and output detached',()=>{
  assert.equal(JSON.stringify({ledger,base}),baseline);
  stage.registries.businesses[0].name='test mutation';assert.equal(JSON.stringify({ledger,base}),baseline);
});
console.log(`${count} gameplay migration tests passed`);
