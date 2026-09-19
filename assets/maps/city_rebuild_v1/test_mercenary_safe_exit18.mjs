import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,script,assert);

async function begin({pending=false,blocked=false}={}){
 const f=await fixture({qa:true}),m=f.recruit('safecracker');m.c=10;m.r=10;
 const origin={x:41,y:0,z:41},target={id:'safe:exit',kind:'safe',valid:true,locked:true,position:origin,workPoint:{x:41,y:.88,z:40.16},workNormal:{x:0,y:0,z:1},workRange:.08};let calls=0,receipt;
 f.ctx.player.c=(41+2.5)/4.1;f.ctx.player.r=(41+1.3)/4.1;
 f.api.bindTargets({get:()=>target,canMove:(a,b)=>!blocked||b.z<41.5,performEffect:()=>{calls++;if(pending)return new Promise(resolve=>receipt=resolve);target.locked=false;return true;}});
 assert(f.api.command('unlock_safe',target).ok);for(let i=0;i<60&&!calls;i++)f.tick(.2);assert.equal(calls,1);return {...f,m,target,origin,calls:()=>calls,receipt:ok=>{target.locked=!ok;receipt({ok});}};
}

test('successful safe opening makes one short physical clearance before normal follow',async()=>{
 const f=await begin(),m=f.m;assert(m._mercenarySafeExit);const startZ=41;let cleared=false;
 for(let i=0;i<40;i++){const before=m.r;f.tick(.2);assert(Math.abs(m.r-before)*4.1<=.601,'bounded movement, never position replacement');if(m.r*4.1-startZ>1.1)cleared=true;}
 assert(cleared);assert.equal(f.calls(),1);assert.equal(m._mercenarySafeExit,undefined);assert.equal(f.api.getAction(m.id),null);
});

test('pending safe receipt holds still and rejection never schedules clearance',async()=>{
 const f=await begin({pending:true}),m=f.m,before={r:m.r,c:m.c};assert.equal(f.api.getAction(m.id).phase,'awaiting');for(let i=0;i<10;i++)f.tick(.2);assert.deepEqual({r:m.r,c:m.c},before);assert(!m._mercenarySafeExit);f.receipt(false);await Promise.resolve();await Promise.resolve();assert(!m._mercenarySafeExit);assert.equal(f.calls(),1);
});

for(const command of ['follow','rally'])test(`${command} replaces post-receipt safe clearance immediately`,async()=>{
 const f=await begin({pending:true}),m=f.m;f.receipt(true);await Promise.resolve();await Promise.resolve();assert(m._mercenarySafeExit);
 if(command==='follow')assert(f.api.follow().ok);else assert(f.api.rally({x:55,y:0,z:41}).ok);
 assert.equal(m._mercenarySafeExit,undefined);f.tick(.2);assert.notEqual(m._mercenaryMove.phase,'safe_exit');assert.equal(f.calls(),1);
});

test('blocked clearance cannot force operator through collision',async()=>{
 const f=await begin({blocked:true});assert(!f.m._mercenarySafeExit);assert(f.m.r*4.1<41.5);assert.equal(f.calls(),1);
});

test('actual safe guard opens its leaf and drops loot after source-driven clearance',async()=>{
 const {pathToFileURL}=await import('node:url'),T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js')),{createInteriorSafe}=await import('./interior_interactive_safe.mjs');
 const f=await fixture({qa:true}),m=f.recruit('safecracker'),safe=createInteriorSafe(T,{id:'source-exit',buildingId:'test',roomId:'manager',position:[41,0,39.66],onUnlock:()=>({ok:true,opened:true,lootDropped:true})});
 const meta=safe.object.userData.mercenaryTarget,origin=meta.getApproachPosition();m.c=origin.x/4.1;m.r=origin.z/4.1;f.ctx.player.c=(origin.x+2.5)/4.1;f.ctx.player.r=(origin.z+1.3)/4.1;
 const target={id:'source-exit',kind:'safe',valid:true,locked:true,position:origin,workNormal:meta.getWorkNormal(),workPoint:meta.getWorkPoint(),workRange:.08};let calls=0;
 f.api.bindTargets({get:()=>target,canMove:()=>true,performEffect:()=>{calls++;return safe.unlock({memberId:m.id,getOperatorPosition:id=>f.api.getMember(id)?.position});}});
 try{assert(f.api.command('unlock_safe',target).ok);for(let i=0;i<100&&safe.getState().openFraction<1;i++){f.tick(.2);await Promise.resolve();await Promise.resolve();safe.update(.2);}assert.equal(calls,1);assert.equal(safe.getState().openFraction,1);assert.equal(safe.getState().waitingForOperator,false);assert(safe.lootBag.visible);}finally{safe.dispose();}
});

