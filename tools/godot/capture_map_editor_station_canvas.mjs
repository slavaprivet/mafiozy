/** Exact original station Canvas2D capture; isolated installed Chrome, CPU only. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const hash=b=>createHash('sha256').update(b).digest('hex');
const expected='69ecbd14108fd151b504a41dc3d00ab5dbeca98b8c5ccd6251553fb60189546b';
const output=path.join(root,'outputs/map_editor_station_canvas_capture');
const manifestBytes=fs.readFileSync(path.join(root,'outputs/map_editor_transport_decor_source/manifest.json'));
assert.equal(hash(manifestBytes),expected);const manifest=JSON.parse(manifestBytes);
const sourceReceipt=manifest.dependencies.find(d=>d.path==='assets/maps/city_rebuild_v1/exploration_railway.mjs');
const sourceBytes=fs.readFileSync(path.join(root,sourceReceipt.path));assert.equal(hash(sourceBytes),sourceReceipt.sha256);
const original=sourceBytes.toString('utf8');
const start=original.indexOf("const canvas=document.createElement('canvas');");
const end=original.indexOf('const texture=new THREE.CanvasTexture(canvas);',start);
assert(start>=0&&end>start);const drawing=original.slice(start,end);
assert(drawing.includes("ctx.font='600 66px Arial'")&&drawing.includes('ctx.fillText(s.name,512,96,950)'));
const browserExe='C:/Program Files/Google/Chrome/Application/chrome.exe';assert(fs.existsSync(browserExe),'Installed Chrome required; no installation fallback');
const require=createRequire(import.meta.url);
const dependencyRoot=path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
const {chromium}=require(require.resolve('playwright',{paths:[dependencyRoot]}));
const fonts=['arial.ttf','arialbd.ttf'].map(file=>{const p=path.join('C:/Windows/Fonts',file);const b=fs.readFileSync(p);return {file,bytes:b.length,sha256:hash(b)};});
const flags=['--disable-gpu','--disable-gpu-compositing','--disable-gpu-rasterization','--disable-accelerated-2d-canvas','--disable-accelerated-video-decode','--no-first-run','--no-default-browser-check'];
const browser=await chromium.launch({executablePath:browserExe,headless:true,args:flags});
try{
 const browserSession=await browser.newBrowserCDPSession();
 const systemInfo=await browserSession.send('SystemInfo.getInfo');
 const version=await browserSession.send('Browser.getVersion');
 const context=await browser.newContext({viewport:{width:1200,height:800},deviceScaleFactor:1});
 const page=await context.newPage(); // Ephemeral offscreen CPU page, not a user/game browser tab.
 await page.setContent('<!doctype html><meta charset="UTF-8"><body></body>');
 const session=await context.newCDPSession(page);await session.send('DOM.enable');await session.send('CSS.enable');
 const captures=[];
 for(const texture of manifest.textures){
  const name=texture.image.recipe.find(r=>r.operation==='fillText').args[0];
  const render=async()=>page.evaluate(({drawing,name})=>{
   const result=new Function('s',drawing+"return {width:canvas.width,height:canvas.height,font:ctx.font,rgba:Array.from(ctx.getImageData(0,0,canvas.width,canvas.height).data),png:canvas.toDataURL('image/png'),fontAvailable:document.fonts.check(ctx.font,s.name)};")({name});
   return result;
  },{drawing,name});
  const first=await render(),second=await render();
  assert.equal(first.width,texture.image.width);assert.equal(first.height,texture.image.height);
  assert(first.fontAvailable&&first.font==='600 66px Arial');
  const rgba=Buffer.from(first.rgba);assert.equal(rgba.length,1024*192*4);assert.equal(hash(rgba),hash(Buffer.from(second.rgba)),'Repeated original canvas draws must agree');
  await page.evaluate(name=>{const e=document.createElement('span');e.id='font-proof';e.style.font='600 66px Arial';e.textContent=name;document.body.replaceChildren(e);},name);
  const document=await session.send('DOM.getDocument');const queried=await session.send('DOM.querySelector',{nodeId:document.root.nodeId,selector:'#font-proof'});
  const platformFonts=await session.send('CSS.getPlatformFontsForNode',{nodeId:queried.nodeId});
  assert(platformFonts.fonts.length>0&&platformFonts.fonts.every(f=>f.familyName==='Arial'&&f.isCustomFont===false&&f.postScriptName==='Arial-BoldMT'),'Actual Windows Arial Bold required; fallback refused');
  const png=Buffer.from(first.png.split(',')[1],'base64');
  captures.push({texture_id:texture.id,name,recipe:texture.image.recipe,width:first.width,height:first.height,colorSpace:texture.colorSpace,sourceTexture:texture,rgba_sha256:hash(rgba),png_sha256:hash(png),rgba,png,font:first.font,platformFonts:platformFonts.fonts,repeatMatch:true});
 }
 const receipt={schema:'mafiozi.exact-station-canvas-capture/v1',source_manifest_sha256:expected,sourceGenerator:sourceReceipt,drawSubstringSha256:hash(Buffer.from(drawing)),drawSubstring:drawing,capturedAt:new Date().toISOString(),browserVersion:version,launchFlags:flags,platform:{os:os.platform(),release:os.release(),arch:os.arch(),fontFiles:fonts},fontBackend:{selected:'Windows registered Arial Bold via Chromium native font backend',proof:'CDP CSS.getPlatformFontsForNode per original Cyrillic name',implementationBackend:'Windows Chromium text raster backend; internal DirectWrite/Skia implementation not independently introspected'},gpuFeatureStatus:systemInfo.gpu.featureStatus,captures:captures.map(({rgba,png,...r})=>({...r,rgba_file:r.texture_id+'.rgba',png_file:r.texture_id+'.png'})),status:'EXACT-ORIGINAL-CPU-BROWSER-CAPTURE; native upload and coordinator live parity review pending',userProfileUsed:false,gameTabsOpened:0};
 assert(!fs.existsSync(output),'Refuse overwriting earlier pixel receipt');fs.mkdirSync(output,{recursive:true});
 for(const capture of captures){fs.writeFileSync(path.join(output,capture.texture_id+'.rgba'),capture.rgba,{flag:'wx'});fs.writeFileSync(path.join(output,capture.texture_id+'.png'),capture.png,{flag:'wx'});}
 fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:receipt.status,browser:version.product,output,captures:receipt.captures.map(r=>({id:r.texture_id,font:r.platformFonts,rgbaSha256:r.rgba_sha256,pngSha256:r.png_sha256})),gpuFeatureStatus:receipt.gpuFeatureStatus}));
}finally{await browser.close();}
