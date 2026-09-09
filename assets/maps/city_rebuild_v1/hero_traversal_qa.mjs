// Opt-in controls use the actual shared scene, colliders and input controller.
export function installTraversalQa({document,enabled,available,getBodies,groundHeight,waterAt,canOccupy,plan,move,begin,walk,finish}){
 if(!enabled)return;
 const panel=document.createElement('div');panel.id='traversal-qa';panel.style.cssText='position:fixed;left:320px;top:55px;z-index:40;display:flex;gap:6px;flex-wrap:wrap;max-width:700px;background:#172025;padding:8px';
 const status=document.createElement('span');status.id='traversal-qa-status';status.textContent='Проверка перемещения';status.style.color='#fff';
 function button(label,action){const b=document.createElement('button');b.textContent=label;b.onclick=()=>{if(available())action();};panel.append(b);}
 function obstacle(kind){
  for(const body of getBodies()){
   if(!Number.isFinite(body.maxYM)||!body.polygonCR?.length)continue;
   const xs=body.polygonCR.map(p=>p[0]*4.1),zs=body.polygonCR.map(p=>p[1]*4.1),minX=Math.min(...xs),maxX=Math.max(...xs),minZ=Math.min(...zs),maxZ=Math.max(...zs);
   for(const [x,z,dx,dz]of [[minX-.5,(minZ+maxZ)/2,1,0],[maxX+.5,(minZ+maxZ)/2,-1,0],[(minX+maxX)/2,minZ-.5,0,1],[(minX+maxX)/2,maxZ+.5,0,-1]]){
    const y=groundHeight(x,z),rise=body.maxYM-y;if(rise<.3||rise>1.6||waterAt(x,z))continue;
    const position={x,y,z},direction={x:dx,z:dz};if(!canOccupy(position))continue;
    const p=plan(position,direction,false);if(p?.kind!==kind)continue;
    move(position,direction);status.textContent=`${kind}: ${body.id||body.node||'препятствие'} · Пробел`;return;
   }
  }
  status.textContent='Подходящий объект не найден';
 }
 button('QA: низкое препятствие',()=>obstacle('vault'));
 button('QA: центральный проход',()=>{move({x:86.5*4.1,y:0,z:91.5*4.1},{x:0,z:1});status.textContent='Центральная площадь: пройти по плитке к югу';});
 button('QA: перед скамьёй',()=>{const x=168.65,z=681.85;move({x,y:groundHeight(x,z),z},{x:1,z:0});status.textContent='Пройти вдоль лицевой стороны скамьи';});
 button('QA: забраться наверх',()=>obstacle('mantle'));
 function lakeShore(lake,depth){
  let lo=lake.x,hi=lake.x+lake.radius;
  for(let i=0;i<36;i++){const x=(lo+hi)/2;if((waterAt(x,lake.z)?.depth??0)>depth)lo=x;else hi=x;}
  const x=(lo+hi)/2,position={x,y:groundHeight(x,lake.z),z:lake.z};
  if(!canOccupy(position)){status.textContent='Берег занят препятствием';return;}
  move(position,{x:1,z:0});status.textContent=depth>1?'Плавание → W к берегу':'Мелководье → Пробел на сушу';
 }
 button('QA: берег Кедрового озера',()=>lakeShore({x:280,z:-137,radius:110},.06));
 button('QA: берег Лазурного озера',()=>lakeShore({x:867,z:425,radius:80},.06));
 button('QA: плавание к берегу',()=>lakeShore({x:280,z:-137,radius:110},1.5));
 button('QA: Пробел',begin);button('QA: идти вперёд 20 с',walk);
 button('QA: пройти 3 с',()=>walk(3000));
 button('Закончить проверку',()=>{finish();panel.remove();const url=new URL(location.href);url.searchParams.delete('traversalqa');history.replaceState(null,'',url);});
 panel.append(status);document.body.append(panel);
}
