// Source/syntax validation only. NEVER imports browser module or executes recipes.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';import {fileURLToPath} from 'node:url';import {spawnSync} from 'node:child_process';
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),source=JSON.parse(fs.readFileSync(path.join(root,'outputs/map_editor_protected_landmarks_source/manifest.json'))),closure=JSON.parse(fs.readFileSync(path.join(root,'outputs/map_editor_landmark_texture_closure/manifest.json')));
let checks=0;const check=(condition,message)=>{checks++;assert(condition,message);};
check(closure.textures.length===38,'38 exact source textures');check(closure.textures.reduce((n,t)=>n+t.images.length,0)===43,'43 source image slots');
for(const recipe of Object.values(source.recipes))check(crypto.createHash('sha256').update(recipe.code).digest('hex')===recipe.sha256,'Exact recipe pin');
const browser=fs.readFileSync(path.join(here,'capture.browser.mjs'),'utf8');
const exactCode=source.recipes.scalarConstants.code+source.recipes.layout.code+source.recipes.surfaceTextures.code+';const jail=({'+source.recipes.jailSnapshot.code+'}).jail;let originalCanal;{'+source.recipes.canalSnapshot.code+'originalCanal=canal;}const worldSnapshot={canal:originalCanal,landmarks:{jail}};'+source.recipes.box.code+source.recipes.outline.code+source.recipes.labelSprite.code+';const canal=worldSnapshot.canal,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;{'+source.recipes.bridge.code+'}inspect(scene);scene=new THREE.Scene();staticOutlineGeometries=[];{'+source.recipes.prison.code+'}inspect(scene);return encountered;';
new Function('THREE','document','renderer','scene','Math','originR','originC','WORLD_SCALE','batchStaticOutlines','staticOutlineGeometries','sharedOutlineMaterial','prisonAlarmBeacons','prisonReleaseGate','prisonReleaseGateLight','prisonVehicleLockGate','inspect','encountered',exactCode);checks++;
check(!/new\s+(?:THREE\.)?WebGLRenderer\b|PMREMGenerator|\.render\s*\(/.test(exactCode),'Original scope needs no renderer');
check(!/\.fillRect\(|\.fillText\(|\.strokeText\(|\.createLinearGradient\(/.test(browser),'No reimplemented drawing formulas');
check(browser.includes('new Function(')&&browser.includes('getImageData(0,0,cv.width,cv.height)'),'Original recipes/native pixels only');
check(browser.includes('slots.length===43&&webglAttempts===0'),'Zero WebGL/slot gate');
check(browser.includes('platformFonts:null')&&browser.includes('ready:false'),'No fabricated font/ready evidence');
for(const file of ['capture.browser.mjs','bundle.browser.mjs','prepare.mjs','serve.mjs','font_evidence.mjs']){const run=spawnSync(process.execPath,['--check',path.join(here,file)],{encoding:'utf8'});check(run.status===0,'Syntax '+file);}
const index=fs.readFileSync(path.join(here,'index.html'),'utf8'),inline=index.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
check(spawnSync(process.execPath,['--input-type=module','--check'],{input:inline,encoding:'utf8'}).status===0,'Inline UI module syntax');
check(index.includes('saveButton.onclick=')&&index.includes("fetch('./capture-bundle',{method:'POST'")&&index.includes('downloadButton.onclick='),'Explicit separate save/download buttons only');
const run=spawnSync(process.execPath,[path.join(here,'prepare.mjs'),'--check'],{encoding:'utf8'});check(run.status===0,'Readonly prepared closure');const report=JSON.parse(run.stdout);check(report.capturesRun===0&&report.browserStarted===false&&report.engineStarted===false&&report.gpu===false,'No capture/browser/engine executed');
console.log(JSON.stringify({suite:'landmark-original-canvas-preparation-only',checks,browserStarted:false,sourceFactoriesExecuted:false,engineStarted:false,gpu:false,ready:false}));
