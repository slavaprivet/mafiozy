import {findCover} from './hero_cover.mjs';
// Explicit opt-in controls exercise the same live cover, posture and fire path.
export function installCoverQa({document,enabled,sources,bodiesAt,canOccupy,groundHeight,place,toggle,fire,crouch,move,finish,weapons=[],selectWeapon,windowSeat,holdEdge,compareContact}){
 if(!enabled)return;
 const panel=document.createElement('div');panel.id='cover-qa';panel.style.cssText='position:fixed;top:135px;left:8px;max-width:410px;max-height:calc(100vh - 280px);overflow:auto;z-index:46;background:#182b32;padding:8px;display:flex;gap:6px;flex-wrap:wrap';
 const status=document.createElement('span');status.id='cover-qa-status';status.style.cssText='color:white;flex-basis:100%';status.textContent='Проверка укрытий';
 const button=(label,action)=>{const b=document.createElement('button');b.textContent=label;b.onclick=action;panel.append(b);};
 function setup(kind){
  for(const body of sources()){
   if(kind==='car'?!body.vehicle:body.vehicle)continue;
   const polygon=body.polygon,area=polygon.reduce((s,a,i)=>{const b=polygon[(i+1)%polygon.length];return s+a.x*b.z-b.x*a.z;},0);
   for(let i=0;i<polygon.length;i++){
    const a=polygon[i],b=polygon[(i+1)%polygon.length],length=Math.hypot(b.x-a.x,b.z-a.z);if(length<1.5)continue;
    const tangent={x:(b.x-a.x)/length,z:(b.z-a.z)/length},normal={x:tangent.z*Math.sign(area),z:-tangent.x*Math.sign(area)};
    const along=kind==='wall'?.18:length/2,x=a.x+tangent.x*along+normal.x*.6,z=a.z+tangent.z*along+normal.z*.6,y=groundHeight(x,z);
    const rise=body.maxY-y;if(kind==='low'?(rise<1||rise>1.27):kind==='wall'?rise<1.9:false)continue;
    const position={x,y,z},direction={x:-normal.x,z:-normal.z};if(!canOccupy(position,1.9))continue;
    const cover=findCover({position,direction,bodies:bodiesAt(position),canOccupy});if(!cover||!!cover.body.vehicle!==(kind==='car')||(kind==='wall'&&cover.height<1.9)||(kind==='low'&&cover.height>1.5))continue;
    place(position,direction);toggle();status.textContent=`${kind}: ${cover.id} · высота ${cover.height.toFixed(2)} м`;return;
   }
  }status.textContent='Подходящее свободное укрытие не найдено';
 }
 button('QA: угол стены',()=>setup('wall'));button('QA: низкое укрытие',()=>setup('low'));button('QA: машина',()=>setup('car'));
 button('QA: Ctrl',toggle);button('QA: C',crouch);
 button('QA: спрятаться',()=>fire(false,false));button('QA: прицелиться',()=>fire(true,false));button('QA: прицельный огонь',()=>fire(true,true));button('QA: огонь вслепую',()=>fire(false,true));
 button('QA: левый край',()=>move(-100));button('QA: правый край',()=>move(100));
 if(holdEdge){button('QA: обойти слева',()=>holdEdge(-1));button('QA: обойти справа',()=>holdEdge(1));}
 if(compareContact){let cached=true;button('QA: сравнить контакт',()=>{cached=!cached;compareContact(cached);status.textContent=cached?'Контакт: кеш включён':'Контакт: прежние 10 проверок в секунду';});}
 if(selectWeapon){const select=document.createElement('select');select.setAttribute('aria-label','QA: оружие');for(const w of weapons){const option=document.createElement('option');option.value=w.id;option.textContent=w.label;select.append(option);}select.onchange=()=>selectWeapon(select.value);panel.append(select);}
 if(windowSeat)for(const [seat,label]of [['front_left','водитель'],['front_right','спереди справа'],['rear_left','сзади слева'],['rear_right','сзади справа']])button('QA: окно '+label,()=>{windowSeat(seat);status.textContent='Стрельба через окно · '+label;});button('Закончить проверку укрытий',()=>{finish();panel.remove();const u=new URL(location.href);u.searchParams.delete('coverqa');history.replaceState(null,'',u);});
 panel.append(status);document.body.append(panel);
}
