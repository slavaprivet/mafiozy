import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(process.argv[2]||'world.html','utf8').replace(/\r\n/g,'\n');
const pace=source.slice(source.indexOf('const NPC_HERO_PACE='),source.indexOf('// NPC_LIFE_SYSTEM_START'));
const frameStart=source.indexOf('function frame() {'),frame=source.slice(frameStart,source.indexOf('\n}',frameStart)+2);
const walkStart=source.indexOf('    const sp = _npcEffectiveSpeed(n) * dt;',source.indexOf('function updateNpcs('));
const walk=source.slice(walkStart,source.indexOf('    }else{',walkStart))+'}';
const results=[];
for(const fps of [30,60,144])for(const speed of [1.2,.42,.62,.9,1.65]){
 let t=0,calls=0,elapsed=0;const noop=()=>{};
 const ctx={performance:{now:()=>t},document:{getElementById:()=>({classList:{contains:()=>true}}),documentElement:{dataset:{}}},
  player:{walking:false},joyL:{active:false},joyR:{active:false},myDrivingCarId:null,myJetSkiId:null,_murderPoliceArrest:null,
  serviceVehicles:[],myWanted:0,lastShotClientT:-10000,_localHpHurtAt:-10000,_THREE_ACTIVE_SIM_FPS:30,_THREE_IDLE_SIM_FPS:30,
  _WORLD_FRAME_MIN_MS:1000/60,prevT:0,requestAnimationFrame:noop,_applyResizeIfNeeded:noop,_battleOpen:false,
  hitStopUntil:0,_pixiFxFrame:noop,_worldResumeFrames:0,_buildingInt:null,_bankInt:null,_frameErrStreak:0,_hbFrames:0,
  _capArrays:noop,_heartbeat:noop,window:{MafioziLoading:{canvasReady:noop}},console:{error:e=>{throw Error(e)}},
  n:{id:'resident_measure',r:0,c:0,speed,hp:100,maxHp:100,walkPhase:0},_npcPathPassable:()=>true,
  _timedWorldUpdate:dt=>{calls++;elapsed+=dt;ctx.dt=dt;vm.runInContext(`{const dr=1000-n.r,dc=-n.c,d=Math.hypot(dr,dc);${walk}}`,ctx);}};
 vm.createContext(ctx);vm.runInContext(pace+'\n'+frame,ctx);
 for(let i=1;i<=fps*10;i++){t=i*1000/fps;ctx.frame();}
 const metres=ctx.n.r*4.1,actual=metres/10;
 assert.ok(elapsed<=10+1e-8&&elapsed>9.85,'source dt follows real wall time, no repeated full-dt updates');
 assert.ok(actual<=1.8+1e-8,`ambient walking ${actual.toFixed(3)} m/s at ${fps}FPS, speed=${speed}`);
 assert.ok(actual>0&&calls>100);
 if(fps===60)results.push({sourceSpeed:speed,metresPerWallSecond:+actual.toFixed(3),sourceUpdates:calls});
 const injured=ctx._npcEffectiveSpeed({...ctx.n,hp:20});assert.ok(injured<ctx._npcEffectiveSpeed(ctx.n));
 const hurry=ctx._npcEffectiveSpeed({...ctx.n,_fear:1,_routineSpeedK:2});assert.ok(hurry*4.1<=1.8+1e-8);
 assert.equal(ctx._npcPacedSpeed(99)*4.1,1.8,'all peaceful humanoids share the natural walk ceiling');
 assert.equal(ctx._npcPacedSpeed(99,true)*4.1,7.8,'emergency running admission unchanged');
}
console.log(JSON.stringify({pass:true,durationSeconds:10,actualFrame:true,results,heroWalkMetresPerSecond:4.6,heroRunMetresPerSecond:7.8}));
