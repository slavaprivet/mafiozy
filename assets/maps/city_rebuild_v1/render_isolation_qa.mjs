import {allowRenderFreeze} from './render_freeze_qa.mjs';

// Diagnostic only: never removes simulation actors or changes saved settings.
export const RENDER_ISOLATION_MODES={shadows:'Без теней',residents:'Без отрисовки жителей',vehicles:'Без отрисовки машин',interiors:'Без мебели интерьеров',pointlights:'Без точечных источников света',water:'Без поверхности воды',resolution:'Половина разрешения по каждой оси'};
export function createRenderIsolationQa({document:doc,window:win,renderer,camera,probe,freeze,getTargets,now=()=>performance.now(),warmupFrames=45,sampleFrames=121}={}){
 if(!allowRenderFreeze(win.location.href)||new URL(win.location.href).searchParams.get('isolationqa')!=='1'||!freeze||!probe?.snapshot)return null;
 const panel=doc.createElement('section');panel.id='render-isolation-qa';
 panel.style.cssText='position:fixed;right:12px;top:55px;z-index:10002;background:#15201ff5;color:#fff;padding:10px;max-width:360px;font:12px sans-serif';
 const select=doc.createElement('select');select.id='render-isolation-mode';select.setAttribute('aria-label','Подсистема для замера');
 for(const [value,label] of Object.entries(RENDER_ISOLATION_MODES)){const option=doc.createElement('option');option.value=value;option.textContent=label;select.append(option);}select.value='shadows';
 const button=doc.createElement('button');button.id='render-isolation-start';button.textContent='Проверить выбранную подсистему';
 const cancel=doc.createElement('button');cancel.textContent='Остановить проверку';
 const status=doc.createElement('pre');status.style.cssText='white-space:pre-wrap;max-height:180px;overflow:auto';panel.append(select,button,cancel,status);doc.body.append(panel);
 let run=null,last=null,disposed=false;const results=[];
 const pose=()=>JSON.stringify([camera.position.toArray(),camera.quaternion.toArray(),camera.projectionMatrix.toArray()]);
 function publish(){const report={active:!!run,scope:'render-only; source simulation continues',mode:run?.mode||last?.mode||null,phase:run?.phase??null,frames:run?.frames||0,last,results};doc.body.dataset.renderIsolation=JSON.stringify(report);status.textContent=run?`${RENDER_ISOLATION_MODES[run.mode]} · ${['исходная сцена','временное отключение','исходная повторно'][run.phase]}\n${run.frames}/${warmupFrames+sampleFrames} кадров`:last?`${last.status}: ${last.reason||RENDER_ISOLATION_MODES[last.mode]}\n${last.phases.map(p=>`${p.name}: render ${p.profile.timings?.render?.p50??'?'} / ${p.profile.timings?.render?.p95??'?'} мс`).join('\n')}`:'Сначала зафиксируйте загруженную 3D-сцену.';button.disabled=!!run;select.disabled=!!run;}
 function stop(reason='cancelled',complete=false){
  if(!run)return;const prior=run;run=null;
  try{renderer.setPixelRatio(prior.pixelRatio);}finally{try{probe.setDrawProfilingEnabled(prior.direct);}finally{probe.reset();last={mode:prior.mode,status:complete?'complete':'aborted',reason,targets:prior.targets.length,startedAt:prior.startedAt,endedAt:now(),camera:prior.pose,phases:prior.phases};if(complete){results.push(last);if(results.length>14)results.shift();}publish();}}
 }
 function start(mode){
  if(disposed||run||!freeze.active||!Object.hasOwn(RENDER_ISOLATION_MODES,mode))return false;
  const targets=[...new Set(getTargets(mode)||[])].filter(Boolean);
  if(!['shadows','resolution'].includes(mode)&&!targets.length){status.textContent='Нет объектов этой подсистемы: замер не запущен.';return false;}
  run={mode,targets,phase:0,frames:0,phases:[],startedAt:now(),pixelRatio:renderer.getPixelRatio(),direct:probe.getDrawProfilingEnabled(),gpu:probe.getGpuTimingEnabled?.(),pose:pose(),width:renderer.domElement.width,height:renderer.domElement.height};
  try{probe.setDrawProfilingEnabled(false);probe.reset();publish();return true;}catch(error){stop('start error');throw error;}
 }
 function valid(){if(!run)return false;const scale=run.mode==='resolution'&&run.phase===1?.5:1;return freeze.active&&!doc.hidden&&pose()===run.pose&&now()-run.startedAt<110000&&!probe.getDrawProfilingEnabled()&&probe.getGpuTimingEnabled?.()===run.gpu&&renderer.domElement.width===Math.floor(run.width*scale)&&renderer.domElement.height===Math.floor(run.height*scale);}
 function render(draw){
  if(!run)return draw();if(!valid()){stop('hold ended, camera changed, page hidden or timeout');return draw();}
  const restores=[];
  try{
   if(run.phase===1){
    if(run.mode==='shadows'){const value=renderer.shadowMap.enabled;restores.push(()=>{renderer.shadowMap.enabled=value;});renderer.shadowMap.enabled=false;}
    else if(run.mode!=='resolution')for(const target of run.targets){const value=target.visible;restores.push(()=>{target.visible=value;});target.visible=false;}
   }
   return draw();
  }catch(error){stop('render error');throw error;}finally{for(let i=restores.length-1;i>=0;i--)restores[i]();}
 }
 function afterFrame(){
  if(!run)return;if(!valid()){stop('hold ended, camera changed, page hidden or timeout');return;}
  try{
  run.frames++;
  if(run.frames===warmupFrames)probe.reset();
  if(run.frames>=warmupFrames+sampleFrames){
   if(!['shadows','resolution'].includes(run.mode)){const current=[...new Set(getTargets(run.mode)||[])].filter(Boolean);if(current.length!==run.targets.length||current.some(target=>!run.targets.includes(target))){stop('Scene target membership changed; repeat comparison');return;}}
   const profile=probe.snapshot();run.phases.push({name:['baseline-before','variant','baseline-after'][run.phase],profile,width:renderer.domElement.width,height:renderer.domElement.height});
   if(run.phase===2){const [before,,after]=run.phases;const stable=JSON.stringify(before.profile.frameDraws)===JSON.stringify(after.profile.frameDraws)&&before.width===after.width&&before.height===after.height;stop(stable?'Baseline draw totals restored; compare timings, not gameplay FPS':'Baseline draw totals changed; repeat comparison',stable);return;}
   run.phase++;run.frames=0;
   if(run.mode==='resolution')renderer.setPixelRatio(run.pixelRatio*(run.phase===1?.5:1));
   probe.reset();publish();
  }else if(run.frames%30===0)publish();
  }catch(error){stop('measurement error');throw error;}
 }
 button.onclick=()=>start(select.value);cancel.onclick=()=>stop();
 const onHide=()=>{if(doc.hidden)stop('page hidden');};
 const onPageHide=()=>stop('pagehide');
 // Prevent concurrent QA toggles from silently changing the comparison setup.
 const guardInput=event=>{if(!run)return;const path=event.composedPath?.()||[event.target];if(event.code==='Escape'||path.some(node=>node===panel||node?.id==='render-freeze-qa'))return;event.preventDefault();event.stopImmediatePropagation();};
 const guardedEvents=['pointerdown','pointerup','mousedown','mouseup','click','keydown','keyup','change'];
 for(const type of guardedEvents)doc.addEventListener(type,guardInput,true);
 doc.addEventListener('visibilitychange',onHide);win.addEventListener?.('pagehide',onPageHide);
 publish();
 return{start,render,afterFrame,stop,report:()=>({active:!!run,last,results:[...results]}),dispose(){if(disposed)return;try{stop('dispose');}finally{disposed=true;panel.remove();for(const type of guardedEvents)doc.removeEventListener(type,guardInput,true);doc.removeEventListener('visibilitychange',onHide);win.removeEventListener?.('pagehide',onPageHide);delete doc.body.dataset.renderIsolation;}}};
}
