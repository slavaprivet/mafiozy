// Opt-in LOCAL render-only comparison. This is not a game pause or an FPS mode:
// the world source can keep simulating while the last populated 3D pose is held.
export function allowRenderFreeze(href){
 const url=new URL(href,'http://invalid');
 return ['localhost','127.0.0.1'].includes(url.hostname)&&url.searchParams.get('perfqa')==='1'&&
  !['uid','account_uid','character_uid','initData','init_data','tgWebAppData','world_token','ws_ticket','auth','token','api'].some(k=>url.searchParams.has(k));
}
export function createRenderFreezeQa({document:doc,window:win,camera,probe,isReady,releaseControls,applyVehicleDetails,applyVehicleWheels,applyStaticMatrices,onHoldStart=()=>{},onHoldEnd=()=>{},getSnapshot=()=>({}),now=()=>performance.now()}={}){
 if(!probe||!allowRenderFreeze(win.location.href))return null;
 const button=doc.createElement('button');button.id='render-freeze-qa';button.type='button';
 button.style.cssText='position:fixed;top:46px;left:50%;transform:translateX(-50%);z-index:10000;padding:8px;max-width:90vw';
 doc.body.append(button);
 const position=camera.position.clone(),quaternion=camera.quaternion.clone(),projection=camera.projectionMatrix.clone();
 let active=false,disposed=false,startedAt=0,snapshot=null,frames=0,detailsEnabled=true,stopReason=null;
 const details=applyVehicleDetails?doc.createElement('button'):null;
 const publishDetails=()=>{if(!details)return;details.textContent=detailsEnabled?'Автодетали: оптимизировано · сравнить':'Автодетали: прежняя отрисовка · сравнить';details.setAttribute('aria-pressed',String(detailsEnabled));doc.body.dataset.vehicleDetailComparison=detailsEnabled?'optimized':'previous';};
 if(details){details.id='vehicle-detail-batch-qa';details.type='button';details.style.cssText=button.style.cssText;details.style.top='84px';doc.body.append(details);details.onclick=()=>{if(!active){details.textContent='Сначала зафиксируйте загруженную 3D-сцену';return;}try{detailsEnabled=!detailsEnabled;applyVehicleDetails(detailsEnabled);publishDetails();probe.reset();}catch(error){stop();throw error;}};publishDetails();}
 const gpu=typeof probe.setGpuTimingEnabled==='function'&&typeof probe.getGpuTimingEnabled==='function'?doc.createElement('button'):null;
 const publishGpu=()=>{if(!gpu)return;const enabled=probe.getGpuTimingEnabled();gpu.textContent=enabled?'GPU-таймер: включён · сравнить':'GPU-таймер: выключен · сравнить';gpu.setAttribute('aria-pressed',String(enabled));doc.body.dataset.gpuTimerComparison=enabled?'enabled':'disabled';};
 const restoreGpu=()=>{if(gpu){probe.setGpuTimingEnabled(true);publishGpu();}};
 const drawProbe=typeof probe.getDrawProfilingEnabled==='function'&&typeof probe.setDrawProfilingEnabled==='function'?doc.createElement('button'):null;
 const publishDrawProbe=()=>{if(!drawProbe)return;const enabled=probe.getDrawProfilingEnabled();drawProbe.textContent=enabled?'Замер каждой отрисовки: включён · сравнить':'Только общий замер кадра · сравнить';drawProbe.setAttribute('aria-pressed',String(enabled));doc.body.dataset.drawProbeComparison=enabled?'detailed':'frame-only';};
 const restoreDrawProbe=()=>{if(drawProbe){probe.setDrawProfilingEnabled(true);publishDrawProbe();}};
 if(drawProbe){drawProbe.id='draw-probe-qa';drawProbe.type='button';drawProbe.style.cssText=button.style.cssText;drawProbe.style.top='312px';doc.body.append(drawProbe);drawProbe.onclick=()=>{if(!active||disposed){drawProbe.textContent='Сначала зафиксируйте загруженную 3D-сцену';return;}try{probe.setDrawProfilingEnabled(!probe.getDrawProfilingEnabled());publishDrawProbe();}catch(error){stop('draw probe error');throw error;}};publishDrawProbe();}
 let wheelsEnabled=true;
 const wheels=applyVehicleWheels?doc.createElement('button'):null;
 const publishWheels=()=>{if(!wheels)return;wheels.textContent=wheelsEnabled?'Колёса: оптимизировано · сравнить':'Колёса: прежняя отрисовка · сравнить';wheels.setAttribute('aria-pressed',String(wheelsEnabled));doc.body.dataset.vehicleWheelComparison=wheelsEnabled?'optimized':'previous';};
 const restoreWheels=()=>{if(wheels&&!wheelsEnabled){wheelsEnabled=true;try{applyVehicleWheels(true);}finally{publishWheels();}}};
 if(wheels){wheels.id='vehicle-wheel-batch-qa';wheels.type='button';wheels.style.cssText=button.style.cssText;wheels.style.top='198px';doc.body.append(wheels);wheels.onclick=()=>{if(!active||disposed){wheels.textContent='Сначала зафиксируйте загруженную 3D-сцену';return;}try{wheelsEnabled=!wheelsEnabled;applyVehicleWheels(wheelsEnabled);publishWheels();probe.reset();}catch(error){stop('wheel comparison error');throw error;}};publishWheels();}
 let staticMatricesEnabled=true;
 const staticMatrices=applyStaticMatrices&&new URL(win.location.href).searchParams.get('staticmatrix')==='1'?doc.createElement('button'):null;
 const publishStaticMatrices=()=>{if(!staticMatrices)return;staticMatrices.textContent=staticMatricesEnabled?'Статика: матрицы оптимизированы · сравнить':'Статика: прежний расчёт матриц · сравнить';staticMatrices.setAttribute('aria-pressed',String(staticMatricesEnabled));doc.body.dataset.staticMatrixComparison=staticMatricesEnabled?'optimized':'previous';};
 const restoreStaticMatrices=()=>{if(staticMatrices&&!staticMatricesEnabled){staticMatricesEnabled=true;try{applyStaticMatrices(true);}finally{publishStaticMatrices();}}};
 if(staticMatrices){staticMatrices.id='static-matrix-qa';staticMatrices.type='button';staticMatrices.style.cssText=button.style.cssText;staticMatrices.style.top='236px';doc.body.append(staticMatrices);staticMatrices.onclick=()=>{if(!active||disposed){staticMatrices.textContent='Сначала зафиксируйте загруженную 3D-сцену';return;}try{staticMatricesEnabled=!staticMatricesEnabled;applyStaticMatrices(staticMatricesEnabled);publishStaticMatrices();probe.reset();}catch(error){stop('static matrix comparison error');throw error;}};publishStaticMatrices();}
 if(gpu){gpu.id='gpu-timer-qa';gpu.type='button';gpu.style.cssText=button.style.cssText;gpu.style.top='160px';doc.body.append(gpu);gpu.onclick=()=>{if(!active||disposed){gpu.textContent='Сначала зафиксируйте загруженную 3D-сцену';return;}try{probe.setGpuTimingEnabled(!probe.getGpuTimingEnabled());publishGpu();}catch(error){stop('GPU timer error');throw error;}};publishGpu();}
 const publish=()=>{button.textContent=active?'Только отрисовка · мир НЕ на паузе · продолжить (Esc)':'Зафиксировать 3D-сцену для замера';button.setAttribute('aria-pressed',String(active));doc.body.dataset.renderFreeze=JSON.stringify({active,scope:active?'render-only':'gameplay',frames,snapshot,stopReason,limitSeconds:120});};
 function stop(reason='manual'){if(!active){try{restoreWheels();}finally{try{restoreStaticMatrices();}finally{try{restoreDrawProbe();}finally{restoreGpu();}}}return;}active=false;stopReason=reason;try{if(!detailsEnabled){detailsEnabled=true;applyVehicleDetails(true);}}finally{publishDetails();try{restoreWheels();}finally{try{restoreStaticMatrices();}finally{try{restoreDrawProbe();}finally{try{restoreGpu();}finally{try{onHoldEnd();}finally{try{releaseControls();}finally{try{probe.reset();}finally{publish();}}}}}}}}}
 button.onclick=()=>{
  if(active){stop();return;}if(disposed||!isReady()){button.textContent='Дождитесь загрузки города и моделей';return;}
  releaseControls();position.copy(camera.position);quaternion.copy(camera.quaternion);projection.copy(camera.projectionMatrix);
  snapshot={...getSnapshot(),camera:position.toArray(),quaternion:quaternion.toArray(),projection:projection.toArray()};
  if((snapshot.npc?.pending||0)>0||(snapshot.traffic?.loading||0)>0){button.textContent='Дождитесь загрузки жителей и автомобилей';return;}
  startedAt=now();frames=0;stopReason=null;active=true;try{onHoldStart();probe.reset();publishDetails();publishGpu();publishWheels();publishStaticMatrices();publishDrawProbe();publish();}catch(error){stop('start error');throw error;}
 };
 // Do not queue a shot/movement while inspecting the held local scene. Keep
 // the existing batching A/B control usable; no gameplay source is rewritten.
 const blockInput=e=>{
  if(!active)return;
  if(e.type==='keydown'&&e.code==='Escape'){e.preventDefault();e.stopImmediatePropagation();stop('Escape');return;}
  const onControl=(e.composedPath?.()||[e.target]).some(n=>['render-freeze-qa','static-batch-qa','vehicle-detail-batch-qa','vehicle-shadow-qa','building-shadow-qa','gpu-timer-qa','vehicle-wheel-batch-qa','static-matrix-qa','draw-probe-qa','render-isolation-qa','render-isolation-mode','render-isolation-start'].includes(n?.id));
  if(onControl&&!['keydown','keyup'].includes(e.type))return;
  if(onControl&&['Tab','Enter','Space'].includes(e.code)){e.stopPropagation?.();return;}
  e.preventDefault();e.stopImmediatePropagation();
 };
 const events=['keydown','keyup','pointerdown','pointerup','mousedown','mouseup','click','mousemove','wheel','touchstart','touchmove'];
 for(const type of events)doc.addEventListener(type,blockInput,{capture:true,passive:false});
 publish();
 return {get active(){return active;},stop,render(draw){
  if(!active||disposed)return false;
  // Resizing changes the projection; resume rather than compare different views.
  try{
   if(now()-startedAt>=120000){stop('timeout');return false;}
   if(!camera.projectionMatrix.equals(projection)){stop('projection changed');return false;}
   if(!isReady()){stop('scene not ready');return false;}
   camera.position.copy(position);camera.quaternion.copy(quaternion);
   probe.begin();try{draw();frames++;if(frames%30===0)publish();}finally{probe.end();}
  }catch(error){stop();throw error;}
  return true;
 },dispose(){if(disposed)return;try{stop();}finally{disposed=true;button.remove();details?.remove();gpu?.remove();wheels?.remove();staticMatrices?.remove();drawProbe?.remove();for(const type of events)doc.removeEventListener(type,blockInput,true);delete doc.body.dataset.renderFreeze;if(details)delete doc.body.dataset.vehicleDetailComparison;if(gpu)delete doc.body.dataset.gpuTimerComparison;if(wheels)delete doc.body.dataset.vehicleWheelComparison;if(staticMatrices)delete doc.body.dataset.staticMatrixComparison;if(drawProbe)delete doc.body.dataset.drawProbeComparison;}}};
}
