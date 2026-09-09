// Explicit local QA helpers; these never run as network-world gameplay actions.
export function findWaterJumpInspection(terrain,allowed=()=>true){
 if(!terrain?.lakes||!terrain.waterAt)return null;
 for(const lake of [...terrain.lakes].reverse())for(let i=0;i<64;i++){
  const a=Math.PI+i*Math.PI/32,dx=Math.cos(a),dz=Math.sin(a);
  let lo=.3,hi=1.3;
  for(let j=0;j<22;j++){const r=(lo+hi)/2;if(terrain.waterAt(lake.x+dx*lake.rx*r,lake.z+dz*lake.rz*r))lo=r;else hi=r;}
  const shore={x:lake.x+dx*lake.rx*hi,z:lake.z+dz*lake.rz*hi};
  const origin={x:shore.x+dx*.65,z:shore.z+dz*.65},direction={x:-dx,z:-dz};
  const landing={x:origin.x+direction.x*2.8,z:origin.z+direction.z*2.8};
  const water=terrain.waterAt(landing.x,landing.z);
  if(terrain.waterAt(origin.x,origin.z)||!water||water.depth<.18||water.depth>1.3)continue;
  if(![0,.35,-.35].every(offset=>allowed(origin.x+dz*offset,origin.z-dx*offset)&&allowed(landing.x+dz*offset,landing.z-dx*offset)))continue;
  origin.y=terrain.groundHeight(origin.x,origin.z);
  if(Math.abs(origin.y-water.level)>.8)continue;
  return {origin,direction,landing,lakeId:lake.id,name:lake.name};
 }
 return null;
}

// Freeze a real contact after a short simulated delay; never fabricate particles.
export function createWaterImpactCapture(){
 let armed=false,paused=false,baseline=0,delay=null,captureDelay=.14;
 return {
  arm(impacts=0,seconds=.14){armed=true;paused=false;baseline=impacts;delay=null;captureDelay=Number.isFinite(seconds)?Math.max(.04,Math.min(2,seconds)):.14;},
  reset(){armed=false;paused=false;delay=null;},
  update(dt,impacts){
   if(!armed||paused)return false;
   if(delay===null&&impacts>baseline)delay=captureDelay;
   if(delay!==null)delay-=Number.isFinite(dt)?Math.max(0,Math.min(.04,dt)):0;
   if(delay!==null&&delay<=0){paused=true;armed=false;return true;}
   return false;
  },
  get paused(){return paused;}
 };
}

export function createWaterInspectionPanel({document:doc,onShore,onJump,onVehicle,onDrive,onCapture,onResume,onFailureCapture,onExit}={}){
 const panel=doc.createElement('section');panel.id='water-inspection';panel.setAttribute('aria-label','Локальная проверка воды');
 panel.style.cssText='position:absolute;left:330px;top:16px;z-index:80;max-width:480px;padding:10px 12px;background:#172a32ee;color:#efe1bd;border:1px solid #ab9469;border-radius:7px;display:flex;flex-wrap:wrap;gap:6px;font:12px system-ui';
 const label=doc.createElement('b');label.textContent='Вода · локальная проверка';label.style.flexBasis='100%';panel.append(label);
 for(const [text,handler]of [['К берегу',onShore],['Прыгнуть в воду',onJump],['Тяжёлая машина',onVehicle],['Заезд в воду',onDrive],['Стоп-кадр всплеска',onCapture],['Стоп-кадр поломки',onFailureCapture],['Выйти — E 0,3 с',onExit],['Продолжить',onResume]]){
  const button=doc.createElement('button');button.type='button';button.textContent=text;button.addEventListener('click',()=>handler?.());panel.append(button);
 }
 const note=doc.createElement('small');note.textContent='Подготовка сцены — только здесь. Прыжок и газ используют игровую физику.';note.style.flexBasis='100%';panel.append(note);doc.body.append(panel);
 return {setStatus(value){note.textContent=String(value)},dispose(){panel.remove()}};
}
