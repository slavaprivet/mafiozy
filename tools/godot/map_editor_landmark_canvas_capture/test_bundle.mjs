// Synthetic byte fixtures only: never draws Canvas, imports Three, or starts UI.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {fileURLToPath} from 'node:url';import {deflateSync} from 'node:zlib';
import {buildTarBundle,parserTar,validateBundle,sha256,canonical,SOURCE_PIN,CLOSURE_PIN,MAX_BUNDLE_BYTES,BUNDLE_FILENAME} from './bundle.browser.mjs';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const closureBytes=new Uint8Array(fs.readFileSync(path.join(root,'outputs/map_editor_landmark_texture_closure/manifest.json'))),closure=JSON.parse(new TextDecoder().decode(closureBytes));
let checks=0;const check=(ok,label)=>{checks++;assert(ok,label);};
function crc32(bytes){let crc=0xffffffff;for(const byte of bytes){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return (crc^0xffffffff)>>>0;}
function chunk(type,data){const t=Buffer.from(type),all=Buffer.concat([t,data]),result=Buffer.alloc(12+data.length);result.writeUInt32BE(data.length);all.copy(result,4);result.writeUInt32BE(crc32(all),8+data.length);return result;}
function png(width,height,rgba){const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(width);ihdr.writeUInt32BE(height,4);ihdr[8]=8;ihdr[9]=6;const rows=Buffer.alloc((width*4+1)*height);for(let y=0;y<height;y++)Buffer.from(rgba.buffer,rgba.byteOffset+y*width*4,width*4).copy(rows,y*(width*4+1)+1);return new Uint8Array(Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',deflateSync(rows,{level:1})),chunk('IEND',Buffer.alloc(0))]));}
const artifacts=new Map(),slots=[];
for(const texture of closure.textures)for(const [ordinal,image] of texture.images.entries()){
 const id=texture.id+'-image-'+ordinal,rgba=new Uint8Array(image.width*image.height*4).fill(slots.length+1),encoded=png(image.width,image.height,rgba);
 artifacts.set(id,{rgba,png:encoded});
 slots.push({id,textureId:texture.id,ordinal,cubeFaceOrdinal:texture.type==='CubeTexture'?ordinal:null,width:image.width,height:image.height,rgbaBytes:rgba.length,rgbaSha256:await sha256(rgba),pngBytes:encoded.length,pngSha256:await sha256(encoded),sourceRecipeSha256:image.sourceRecipeSha256,sourceRecipeKey:image.recipeKey,sourceSampler:texture.sampler,nativeFontMeasurements:[],nativeTextDraws:[],platformFonts:null,fontBackendStatus:'SYNTHETIC_TEST_ONLY_NOT_CAPTURE'});
}
const receipt={schema:'original-landmark-canvas-browser-capture-v1',sourceManifestSha256:SOURCE_PIN,sourceClosureSha256:CLOSURE_PIN,threeRevision:'180',slots,zeroWebGL:true,webglAttempts:0,ready:false,browser:{backend:'SYNTHETIC_FIXTURE_NOT_NATIVE_CAPTURE'},gates:['TEST_NOT_VISUAL_ACCEPTANCE']};
const sign=async r=>{const copy={...r};delete copy.canonicalSha256;r.canonicalSha256=await sha256(new TextEncoder().encode(canonical(copy)));return r;};await sign(receipt);
const api={receipt:()=>receipt,artifact:(id,kind)=>artifacts.get(id)[kind].slice()};
const before=canonical(receipt),bundle=await buildTarBundle(api,closureBytes),parsed=parserTar(bundle.bytes),valid=await validateBundle(bundle.bytes,closureBytes);
check(bundle.entries===87&&parsed.size===87&&bundle.filename===BUNDLE_FILENAME,'one safe87-entry TAR');check(bundle.ready===false&&valid.ready===false&&valid.receipt.ready===false,'HOLD remains HOLD');check(canonical(receipt)===before,'original receipt not mutated');check(bundle.bytes.length<MAX_BUNDLE_BYTES&&bundle.bytes.length%512===0,'bounded STORE512-byte blocks');
check(bundle.bytes.subarray(-1024).every(v=>v===0),'exact two zero endblocks');
const names=[...parsed.keys()];check(names[0]==='receipt.json','canonical receipt first');check(names.slice(1).join('|')===[...names.slice(1)].sort().join('|'),'stable ASCII artifact order');
for(const slot of slots)for(const kind of ['rgba','png']){const file='images/'+slot.id+'.'+kind;check(parsed.get(file).length===slot[kind+'Bytes'],'all original source dimension bytecounts');check(await sha256(parsed.get(file))===slot[kind+'Sha256'],'all86 exact byte hashes');check(Buffer.compare(Buffer.from(parsed.get(file)),Buffer.from(artifacts.get(slot.id)[kind]))===0,'all86 bytes unchanged');}
check(await sha256(bundle.bytes)===bundle.bundleSha256,'whole TAR SHA');
const second=await buildTarBundle(api,closureBytes);check(second.bundleSha256===bundle.bundleSha256&&Buffer.compare(Buffer.from(second.bytes),Buffer.from(bundle.bytes))===0,'deterministic complete archive');
function refusesParser(edit,label){const corrupt=bundle.bytes.slice();edit(corrupt);checks++;assert.throws(()=>parserTar(corrupt),undefined,label);}
refusesParser(b=>b[0]=47,'absolute path denied');refusesParser(b=>b[156]=50,'link entry denied');refusesParser(b=>b[148]^=1,'bad checksum denied');refusesParser(b=>b[b.length-1]=1,'nonzero terminal block denied');refusesParser(b=>b[512+parsed.get('receipt.json').length]=1,'nonzero entry padding denied');
refusesParser(b=>{const offset=512+Math.ceil(parsed.get('receipt.json').length/512)*512;b.fill(0,offset,offset+100);b.set(new TextEncoder().encode('receipt.json'),offset);},'duplicate entry denied');
checks++;assert.throws(()=>parserTar(bundle.bytes.subarray(0,bundle.bytes.length-512)),'truncated terminal block refused');checks++;assert.throws(()=>parserTar(new Uint8Array(1024)),'empty fakearchive refused');
const wrongClosure=closureBytes.slice();wrongClosure[0]^=1;checks++;await assert.rejects(buildTarBundle(api,wrongClosure),/closure bytes/);
const corrupt=bundle.bytes.slice();const firstRgba=parsed.get('images/'+slots[0].id+'.rgba');corrupt[firstRgba.byteOffset-bundle.bytes.byteOffset]^=1;checks++;await assert.rejects(validateBundle(corrupt,closureBytes),/Artifact byte\/hash mismatch/);check(artifacts.get(slots[0].id).rgba[0]===1,'archive mutation cannot mutate original artifact');
for(const [label,mutate,resign] of [
 ['unsafe slot',r=>r.slots[0].id='../evil',true],['slot order',r=>r.slots.reverse(),true],['dimensions',r=>r.slots[0].width++,true],['source sampler',r=>r.slots[0].sourceSampler.flipY=false,true],['source recipe',r=>r.slots[0].sourceRecipeKey='0'.repeat(64),true],['byte hash',r=>r.slots[0].rgbaSha256='0'.repeat(64),true],['ready false required',r=>r.ready=true,true],['missing slot',r=>r.slots.pop(),true],['stale receipt',r=>r.browser.backend='changed',false]
 ]){
 const changed=JSON.parse(canonical(receipt));mutate(changed);if(resign)await sign(changed);checks++;await assert.rejects(buildTarBundle({...api,receipt:()=>changed},closureBytes),undefined,label);
}
for(const offset of [0,19]){
 const changed=JSON.parse(canonical(receipt)),badPng=artifacts.get(slots[0].id).png.slice();badPng[offset]^=1;changed.slots[0].pngSha256=await sha256(badPng);await sign(changed);
 const badApi={receipt:()=>changed,artifact:(id,kind)=>id===slots[0].id&&kind==='png'?badPng:api.artifact(id,kind)};
 checks++;await assert.rejects(buildTarBundle(badApi,closureBytes),/PNG/,'hash-consistent invalid PNG rejected');
}
console.log(JSON.stringify({suite:'landmark-canvas-TAR-byte-fixtures',checks,entries:87,slots:43,sourceDimensionRGBABytes:slots.reduce((n,s)=>n+s.rgbaBytes,0),syntheticTarBytes:bundle.bytes.length,browserStarted:false,sourceFactoriesExecuted:false,gpu:false,ready:false}));
