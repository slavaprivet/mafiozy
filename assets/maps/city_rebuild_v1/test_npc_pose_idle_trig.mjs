import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';

const source=fs.readFileSync(new URL('./hero_walk.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const optimized=`    const c=posture.crouch,p=posture.prone,crawl=p*gait;\n\n    if(c<1e-5&&p<1e-5)return;\n\n    const cycle=Math.sin(phase),bob=Math.cos(phase*2);`;
assert.equal(source.split(optimized).length-1,1,'posturePose must retain the reviewed idle trigonometry gate');

const before=(c,p,gait,phase)=>{
 const crawl=p*gait,cycle=Math.sin(phase),bob=Math.cos(phase*2);
 if(c<1e-5&&p<1e-5)return null;
 return [crawl,cycle,bob];
};
const after=(c,p,gait,phase)=>{
 const crawl=p*gait;
 if(c<1e-5&&p<1e-5)return null;
 const cycle=Math.sin(phase),bob=Math.cos(phase*2);
 return [crawl,cycle,bob];
};

for(const c of [0,1e-6,1e-5,.25,1])for(const p of [0,1e-6,1e-5,.5,1])for(const phase of [-10,-.1,0,.1,10]){
 assert.deepEqual(after(c,p,.73,phase),before(c,p,.73,phase));
}

const nativeSin=Math.sin,nativeCos=Math.cos,counts={before:{sin:0,cos:0},after:{sin:0,cos:0}};
for(const [name,run] of [['before',before],['after',after]]){
 Math.sin=value=>{counts[name].sin++;return nativeSin(value);};
 Math.cos=value=>{counts[name].cos++;return nativeCos(value);};
 try{for(let i=0;i<64;i++)assert.equal(run(0,0,0,i/60),null);}finally{Math.sin=nativeSin;Math.cos=nativeCos;}
}
assert.deepEqual(counts,{before:{sin:64,cos:64},after:{sin:0,cos:0}});

const warmups=32768,iterations=262144,results=[];
for(const round of [['before',before],['after',after],['after',after],['before',before]]){
 const [name,run]=round;let checksum=0;
 for(let i=0;i<warmups;i++)checksum+=run(0,0,0,i/60)===null?1:0;
 const started=performance.now();
 for(let i=0;i<iterations;i++)checksum+=run(0,0,0,i/60)===null?1:0;
 results.push({name,totalMs:performance.now()-started,checksum});
}
assert(results.every(result=>result.checksum===warmups+iterations));
console.log(JSON.stringify({scope:'posturePose idle scalar CPU proxy; not actor/render/LIVE/FPS',warmups,iterations,counts,results},null,2));
