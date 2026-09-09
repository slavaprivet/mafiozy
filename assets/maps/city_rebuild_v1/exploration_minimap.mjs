// North-up navigation. All coordinates are world metres: +X east, +Z south.
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const point=p=>Array.isArray(p)?{x:p[0],z:p[1]}:{x:p?.x,z:p?.z};
const valid=p=>Number.isFinite(p?.x)&&Number.isFinite(p?.z);
const polygon=p=>(p||[]).map(point).filter(valid);
export function mapProjection({center,width,height,metresPerPixel}){
  if(!valid(center)||!(width>0&&height>0&&metresPerPixel>0))throw new Error('Invalid map projection');
  return {toScreen:p=>({x:(p.x-center.x)/metresPerPixel+width/2,y:(p.z-center.z)/metresPerPixel+height/2}),toWorld:p=>({x:(p.x-width/2)*metresPerPixel+center.x,z:(p.y-height/2)*metresPerPixel+center.z})};
}
export function waypointInfo(position,waypoint,yaw=0){
  if(!valid(position)||!valid(waypoint))return null;
  const dx=waypoint.x-position.x,dz=waypoint.z-position.z,distance=Math.hypot(dx,dz),bearing=Math.atan2(dx,dz);
  return {distance,bearing,relativeBearing:Math.atan2(Math.sin(bearing-yaw),Math.cos(bearing-yaw)),arrived:distance<5};
}
export function boundedWaypoint(p,bounds){return valid(p)?{x:clamp(p.x,bounds.minX,bounds.maxX),z:clamp(p.z,bounds.minZ,bounds.maxZ)}:null}
export function pointInMapPolygon(p,vertices){
  if(!valid(p))return false;const pts=polygon(vertices);if(pts.length<3)return false;let inside=false;
  for(let i=0,j=pts.length-1;i<pts.length;j=i++){
    const a=pts[j],b=pts[i],cross=(b.x-a.x)*(p.z-a.z)-(b.z-a.z)*(p.x-a.x);
    if(Math.abs(cross)<1e-7&&p.x>=Math.min(a.x,b.x)-1e-8&&p.x<=Math.max(a.x,b.x)+1e-8&&p.z>=Math.min(a.z,b.z)-1e-8&&p.z<=Math.max(a.z,b.z)+1e-8)return true;
    if((a.z>p.z)!==(b.z>p.z)&&p.x<(b.x-a.x)*(p.z-a.z)/(b.z-a.z)+a.x)inside=!inside;
  }
  return pts.length>=3&&inside;
}
export function currentMapRegion(position,{districts=[],regions=[]}={}){
  return [...districts,...regions].find(region=>region.name&&pointInMapPolygon(position,region.polygon||region.points))||null;
}
export function waypointScreenPosition(waypoint,projection,width,height){
  if(!valid(waypoint))return null;const q=projection.toScreen(waypoint);return{x:clamp(q.x,13,width-13),y:clamp(q.y,16,height-16)};
}
export function waypointMarkerHit(pointer,waypoint,projection,width,height,radius=12){
  const q=waypointScreenPosition(waypoint,projection,width,height);return !!q&&Number.isFinite(pointer?.x)&&Number.isFinite(pointer?.y)&&Math.hypot(pointer.x-q.x,pointer.y-q.y)<=radius;
}
export function waypointDistanceText(position,waypoint){
  const info=waypointInfo(position,waypoint);return info?`До метки: ${Math.round(info.distance)} м${waypoint.name?` · ${waypoint.name}`:''}`:'Нажмите на карту — поставить метку';
}
export function mapObjectAt(pointer,objects,projection){
  const worldPoint=projection.toWorld(pointer);let nearest=null,distance=Infinity;
  for(const obj of objects){if(!valid(obj)||!obj.name)continue;const p=projection.toScreen(obj),d=Math.hypot(pointer.x-p.x,pointer.y-p.y);if(d<=12&&d<distance){nearest=obj;distance=d}}
  return nearest||objects.find(obj=>obj.name&&obj.polygon?.length&&pointInMapPolygon(worldPoint,obj.polygon))||null;
}
export function mapObjectBounds(object){
 const points=polygon(object?.polygon||object?.points);let minX=Infinity,maxX=-Infinity,minZ=Infinity,maxZ=-Infinity;
 for(const p of points){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minZ=Math.min(minZ,p.z);maxZ=Math.max(maxZ,p.z)}
 if(!Number.isFinite(minX)){const radius=Math.max(0,Number(object?.radius)||1),x=Number(object?.x),z=Number(object?.z);if(!Number.isFinite(x+z))return null;minX=x-radius;maxX=x+radius;minZ=z-radius;maxZ=z+radius}
 return {minX,maxX,minZ,maxZ};
}
// Map drawing is view-local, while the place list and pointer hit-testing still
// use the complete object array. The index is deliberately conservative: a
// returned object is drawn by the existing code, so no map symbol is omitted.
export function createMapObjectIndex(objects,{cellSize=128}={}){
 const size=Math.max(8,Number.isFinite(cellSize)?cellSize:128),cells=new Map(),entries=[];
 for(const object of objects||[]){const bounds=mapObjectBounds(object);if(!bounds)continue;const entry={object,bounds};entries.push(entry);for(let z=Math.floor(bounds.minZ/size);z<=Math.floor(bounds.maxZ/size);z++)for(let x=Math.floor(bounds.minX/size);x<=Math.floor(bounds.maxX/size);x++){const key=`${x},${z}`;if(!cells.has(key))cells.set(key,[]);cells.get(key).push(entry)}}
 function query(bounds){
  if(!bounds||![bounds.minX,bounds.maxX,bounds.minZ,bounds.maxZ].every(Number.isFinite))return objects||[];
  const result=[],seen=new Set();for(let z=Math.floor(bounds.minZ/size);z<=Math.floor(bounds.maxZ/size);z++)for(let x=Math.floor(bounds.minX/size);x<=Math.floor(bounds.maxX/size);x++)for(const entry of cells.get(`${x},${z}`)||[]){if(seen.has(entry))continue;seen.add(entry);result.push(entry.object)}return result;
 }
 return {query,stats(){return {objects:entries.length,cells:cells.size,cellSize:size}}};
}
export function mapKind(name=''){
  const s=String(name).toLowerCase();
  if(/parking|парковк/.test(s))return 'parking';
  for(const [kind,re] of [['hospital',/hospital|больниц/],['gunshop',/gun_shop|оружейн/],['pawnshop',/pawnshop|ломбард/],['printshop',/print_shop|типограф/],['nightclub',/nightclub|ночной клуб/],['stripclub',/strip_club|стрип/],['bookmaker',/bookmaker|букмекер/],['residential',/house|cottage|bungalow|chalet|apartment|walkup|glass_tower|жилой|жилые/],['civic',/civic_hall|общественный зал/],['shop',/glass_pavilion|магазин/]])if(re.test(s))return kind;
  for(const [kind,re] of [['station',/station|вокзал|станци/],['train',/train|поезд/],['bank',/bank|банк/],['police',/police|полици/],['tree',/tree|pine|birch|oak|cypress|дерев|сосн/],['fountain',/fountain|фонтан/],['monument',/monument|statue|sculpture|памят|скульп/],['bench',/bench|лавоч|скам/],['lamp',/lamp|light|фонар/],['mountain',/mountain|peak|ridge|summit|вершин|хребет|гор[аы]/],['water',/lake|pond|water|озер|озёр|вод/],['forest',/forest|лес/],['landmark',/gazebo|overlook|pavilion|belvedere|viewpoint|обзор|бесед/]])if(re.test(s))return kind;
  return 'object';
}
const kinds={parking:['Парковки','#76a4c1','P'],station:['Станции','#f0c77d','Ж'],railway:['Железная дорога','#514e43',''],train:['Поезд','#cf875f',''],bank:['Банк','#bd9c59','Б'],police:['Полиция','#70a0b0','П'],hospital:['Больница','#d9ece1',''],shop:['Магазин','#c8ae83',''],gunshop:['Оружейный','#bb957d',''],pawnshop:['Ломбард','#cab17a',''],printshop:['Типография','#d8d3b3',''],nightclub:['Ночной клуб','#ab92ae',''],stripclub:['Стрип-клуб','#c597a0',''],bookmaker:['Букмекер','#adbc87',''],residential:['Жилой дом','#cec3a9',''],civic:['Общественный зал','#dfd1b4',''],building:['Здания','#c9bea7',''],tree:['Деревья','#426958',''],forest:['Лес','#6e8d68','♠'],water:['Вода','#69afb5','≈'],mountain:['Горы','#baa88a','▲'],fountain:['Фонтаны','#8fcccc','○'],monument:['Памятники','#d3b672','◆'],bench:['Скамейки','#b89970',''],lamp:['Фонари','#d9ca95',''],landmark:['Места','#d7b572','◆'],object:['Декор','#baaa8b','']};
export const BUILDING_MAP_KINDS=Object.freeze(['bank','police','hospital','shop','gunshop','pawnshop','printshop','nightclub','stripclub','bookmaker','residential','civic','building']);
export function vehicleMapColor(vehicle){
  const color=vehicle?.color??vehicle?.skinColor;
  if(typeof color==='string'&&/^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i.test(color))return color;
  if(Number.isInteger(color)&&color>=0&&color<=0xffffff)return '#'+color.toString(16).padStart(6,'0');
  return '#f2c48a';
}
function drawBuildingIcon(context,kind,x,y,size){
  context.save();context.translate(x,y);context.scale(size/12,size/12);context.strokeStyle='#183237';context.fillStyle='#183237';context.lineWidth=1.55;context.lineJoin='round';context.lineCap='round';
  const line=points=>{context.beginPath();points.forEach(([x,y],i)=>i?context.lineTo(x,y):context.moveTo(x,y));context.stroke()},circle=(x,y,r)=>{context.beginPath();context.arc(x,y,r,0,Math.PI*2);context.stroke()};
  if(kind==='bank'||kind==='civic'){line([[-5,-2],[0,-5],[5,-2],[-5,-2]]);line([[-5,5],[5,5]]);for(const x of[-3,0,3])line([[x,-1],[x,3]])}
  else if(kind==='hospital'){context.fillRect(-1.6,-5,3.2,10);context.fillRect(-5,-1.6,10,3.2)}
  else if(kind==='police'){line([[-4,-4],[0,-5],[4,-4],[4,1],[0,5],[-4,1],[-4,-4]]);line([[0,-2],[0,2],[-2,0],[2,0]])}
  else if(kind==='residential'||kind==='building'){line([[-5,-1],[0,-5],[5,-1]]);line([[-3,-1],[-3,5],[3,5],[3,-1]]);line([[-1,5],[-1,1],[1,1],[1,5]])}
  else if(kind==='shop'){context.strokeRect(-4,-1,8,6);line([[-2,-1],[-2,-4],[2,-4],[2,-1]])}
  else if(kind==='gunshop'){line([[-5,-3],[5,-3],[5,-1],[0,-1],[0,1],[-2,1],[-2,5],[-4,5],[-3,-1],[-5,-1],[-5,-3]])}
  else if(kind==='pawnshop'){line([[-5,-1],[-2,-4],[2,-4],[5,-1],[0,5],[-5,-1],[5,-1]]);line([[-2,-4],[0,5],[2,-4]])}
  else if(kind==='printshop'){context.strokeRect(-3,-5,6,10);for(const y of[-2,1,3])line([[-1,y],[2,y]])}
  else if(kind==='nightclub'){line([[0,3],[0,-4],[4,-5],[4,2]]);circle(-2,3,1.7);circle(2,3,1.7)}
  else if(kind==='stripclub'){line([[0,-5],[1.5,-1.5],[5,-1.5],[2,1],[3,5],[0,2.5],[-3,5],[-2,1],[-5,-1.5],[-1.5,-1.5],[0,-5]])}
  else if(kind==='bookmaker'){context.strokeRect(-4,-5,8,10);context.fillRect(-2,-3,1.5,1.5);context.fillRect(1,1,1.5,1.5);line([[-2,3],[2,-1]])}
  context.restore();
}
export function selectMapPOIs(objects){
  const ids=new Set(),result=objects.filter(o=>{if(!valid(o)||!o.name||!(o.poi||BUILDING_MAP_KINDS.includes(o.kind)||['station','monument','fountain','mountain','forest','landmark','water'].includes(o.kind)))return false;if(o.id&&ids.has(o.id))return false;if(o.id)ids.add(o.id);return true});
  const counts=new Map();for(const o of result)counts.set(o.name,(counts.get(o.name)||0)+1);
  const score=o=>(Number.isFinite(o.mapPriority)?o.mapPriority:({station:120,mountain:105,forest:100,water:95,landmark:85,police:55,monument:45,fountain:40,bank:25}[o.kind]||20))-(counts.get(o.name)>1?25:0);
  return result.map((o,index)=>({o,index,score:score(o)})).sort((a,b)=>b.score-a.score||a.index-b.index).map(({o})=>o);
}
export function layoutMapLabels({pois,projection,width,height,metresPerPixel,measureText=text=>text.length*6}){
  const labels=[],limit=metresPerPixel<1.2?32:16;
  for(const obj of pois){if(labels.length>=limit)break;if(metresPerPixel>=1.2&&(BUILDING_MAP_KINDS.includes(obj.kind)||['fountain','monument'].includes(obj.kind)))continue;
    const q=projection.toScreen(obj),text=obj.name.length>29?obj.name.slice(0,27)+'…':obj.name,w=measureText(text),h=15;
    if(q.x<8||q.y<25||q.x>width-8||q.y>height-20)continue;
    const x=q.x+w+13<width?q.x+9:q.x-w-9,y=q.y-7,box={x:x-4,y:y-3,w:w+8,h:h+6};
    if(box.x<5||box.x+box.w>width-5||labels.some(l=>box.x<l.box.x+l.box.w+8&&box.x+box.w+8>l.box.x&&box.y<l.box.y+l.box.h+5&&box.y+box.h+5>l.box.y))continue;
    labels.push({obj,text,x,y:y+11,box});
  }
  return labels;
}
export function normalizeNativeInstances(instances,cellSize=4.1){
  return (instances||[]).map(raw=>{
    const item=raw.userData?.instance||raw,t=item.transform||{},p=t.positionM||[item.c*cellSize,0,item.r*cellSize],b=item.footprint;
    const isBuilding=!!b||/building|residential|commercial/.test(item.role||'');
    const detected=mapKind(item.assetId),kind=detected==='object'&&isBuilding?'building':detected;
    const outline=b?[[b.minC*cellSize,b.minR*cellSize],[b.maxC*cellSize,b.minR*cellSize],[b.maxC*cellSize,b.maxR*cellSize],[b.minC*cellSize,b.maxR*cellSize]]:(item.collision?.worldBodies?.[0]?.polygonCR||[]).map(p=>[p[0]*cellSize,p[1]*cellSize]);
    return {id:item.id,name:item.roomSizing?.label||item.name||(isBuilding?kinds[kind]?.[0]:'')||'',kind,x:p[0],z:p[2],polygon:outline,radius:kind==='tree'?2.4:1,building:isBuilding};
  }).filter(valid);
}
const css=`
.exploration-map{--ink:#e7e0cf;--brass:#bba46d;position:fixed;left:auto;top:auto;right:16px;bottom:16px;width:230px;z-index:4;color:var(--ink);background:#152c2eed;border:1px solid #bba46d88;border-radius:14px;box-shadow:0 7px 25px #0005;font:12px/1.35 system-ui,sans-serif;overflow:hidden;user-select:none}
.exploration-map *{box-sizing:border-box}.exploration-map button{font:inherit;color:var(--ink);background:#284044;border:1px solid #bba46d55;border-radius:6px;padding:6px 9px;cursor:pointer}.exploration-map button:hover{background:#3c5658}.exploration-map button:focus-visible,.exploration-map canvas:focus-visible{outline:2px solid #e5c57b;outline-offset:-3px}.exploration-map header{position:static;inset:auto;max-width:none;margin:0;border:0;border-bottom:1px solid #bba46d44;border-radius:0;background:transparent;display:flex;align-items:center;justify-content:space-between;padding:9px 10px;gap:8px}.exploration-map header strong{font-size:11px;letter-spacing:.15em;text-transform:uppercase}.exploration-map header button{padding:3px 7px}.exploration-map .em-stage{position:relative;width:100%;height:194px}.exploration-map canvas{display:block;width:100%;height:100%;touch-action:none;cursor:crosshair}.exploration-map .em-north{position:absolute;top:6px;left:10px;font-size:10px;pointer-events:none;color:#f2dec2;text-shadow:0 1px 3px #000}.exploration-map .em-scale{position:absolute;bottom:8px;left:12px;border-bottom:2px solid #ead8b3;text-align:center;font-size:9px;pointer-events:none;text-shadow:0 1px 3px #000}.exploration-map .em-status{display:flex;align-items:center;gap:7px;padding:8px 10px;min-height:38px;border-top:1px solid #bba46d44}.exploration-map .em-status span{flex:1}.exploration-map .em-status button{padding:2px 6px}.exploration-map .em-tools,.exploration-map .em-index,.exploration-map .em-help{display:none}.exploration-map[data-expanded=true]{z-index:30;inset:6vh 6vw;width:auto;display:flex;flex-direction:column;border-radius:18px;background:#142d30fa}.exploration-map[data-expanded=true] header{padding:14px 18px}.exploration-map[data-expanded=true] header strong{font-size:15px}.exploration-map[data-expanded=true] .em-main{display:flex;flex:1;min-height:0}.exploration-map[data-expanded=true] .em-stage{height:auto;flex:1;min-width:0}.exploration-map[data-expanded=true] .em-index{display:block;width:210px;overflow:auto;border-left:1px solid #bba46d44;padding:12px}.exploration-map .em-index h3{margin:0 0 8px;font-size:12px;color:#d9c593}.exploration-map .em-pois{display:grid;gap:5px}.exploration-map .em-pois button{text-align:left;background:#203d3f;font-size:11px}.exploration-map .em-legend{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:16px 0;font-size:10px}.exploration-map .em-legend i{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px}.exploration-map[data-expanded=true] .em-tools{display:flex;gap:6px;position:absolute;right:12px;top:12px}.exploration-map[data-expanded=true] .em-help{display:block;margin:0;padding:9px 14px;border-top:1px solid #bba46d33;font-size:11px;color:#b7c5bd}.exploration-map[data-expanded=true] .em-status{padding:9px 15px}.exploration-map .em-count{font-size:10px;color:#aabbaf;margin-top:12px}.exploration-map[hidden]{display:none!important}@media(max-width:700px){.exploration-map{left:auto;top:auto;right:8px;bottom:10px;width:190px}.exploration-map .em-stage{height:150px}.exploration-map[data-expanded=true]{inset:3vh 3vw}.exploration-map[data-expanded=true] .em-index{width:135px;padding:8px}.exploration-map .em-legend{grid-template-columns:1fr}.exploration-map[data-expanded=true] .em-help{font-size:10px}}`;

export function createExplorationMinimap({container=document.body,onExpandedChange=()=>{},onWaypointChange=()=>{}}={}){
  const doc=container.ownerDocument,win=doc.defaultView;
  const style=doc.createElement('style');style.textContent=css;doc.head.append(style);
  const root=doc.createElement('section');root.className='exploration-map';root.dataset.expanded='false';root.setAttribute('aria-label','Карта города и окрестностей');
  root.innerHTML='<header><strong>Окрестности</strong><button type="button" class="em-toggle" aria-label="Развернуть карту" aria-expanded="false">M ↗</button></header><div class="em-main"><div class="em-stage"><canvas tabindex="0" aria-label="Карта: нажмите для метки. В большой карте стрелки двигают обзор, Enter ставит метку, плюс и минус меняют масштаб."></canvas><span class="em-north">↑ СЕВЕР</span><span class="em-scale"></span><div class="em-tools"><button type="button" data-action="plus" aria-label="Приблизить карту">+</button><button type="button" data-action="minus" aria-label="Отдалить карту">−</button><button type="button" data-action="hero" aria-label="Показать персонажа">Я</button><button type="button" data-action="fit">Весь мир</button></div></div><aside class="em-index"><h3>Места на карте</h3><div class="em-pois"></div><div class="em-legend"></div><div class="em-count"></div></aside></div><p class="em-help">Нажмите на место, чтобы поставить метку · ПКМ по метке — убрать · Колесо — масштаб · Перетащите карту · M / Esc — закрыть</p><div class="em-status"><span aria-live="polite">Нажмите на карту — поставить метку</span><button type="button" class="em-clear" aria-label="Убрать метку" hidden>×</button></div>';
  container.append(root);
  const canvas=root.querySelector('canvas'),ctx=canvas.getContext('2d'),stage=root.querySelector('.em-stage'),status=root.querySelector('.em-status span'),clear=root.querySelector('.em-clear'),toggle=root.querySelector('.em-toggle'),heading=root.querySelector('header strong');
  const atlas=doc.createElement('canvas'),actx=atlas.getContext('2d');let viewCache=null;
  const tooltip=doc.createElement('div');tooltip.className='em-tooltip';tooltip.style.cssText='position:absolute;z-index:5;max-width:210px;padding:5px 8px;background:#102d30ee;border:1px solid #c5b17b;border-radius:5px;color:#f5e9cb;font:12px/1.3 system-ui;pointer-events:none;white-space:normal;box-shadow:0 3px 12px #0006';tooltip.hidden=true;stage.append(tooltip);
  let world={bounds:{minX:0,maxX:738,minZ:0,maxZ:820},buildings:[],objects:[],regions:[],water:[],trails:[],roads:[],railways:[],districts:[]},objects=[],objectIndex=null,pois=[],districtLabels=[],expanded=false,zoom=1,center={x:369,z:410},position={x:369,z:410},yaw=0,vehicles=[],actors=[],trains=[],waypoint=null,lastDraw=-Infinity,lastStatus='',dirty=true,drag=null,width=230,height=194,dpr=1,atlasScale=1,priorFocus=null,disposed=false;
  const listen=(node,event,fn,options)=>{node.addEventListener(event,fn,options);cleanups.push(()=>node.removeEventListener(event,fn,options))},cleanups=[];
  function projection(){return mapProjection({center:expanded?center:position,width,height,metresPerPixel:expanded?Math.max((world.bounds.maxX-world.bounds.minX)/width,(world.bounds.maxZ-world.bounds.minZ)/height)*1.08/zoom:180/width})}
  function path(context,pts,project){if(!pts.length)return false;context.beginPath();pts.forEach((p,i)=>{const q=project(p);i?context.lineTo(q.x,q.y):context.moveTo(q.x,q.y)});return true}
  function rebuild(){viewCache=null;dirty=true}
  function drawBase(pr,mpp){
    const currentCenter=pr.toWorld({x:width/2,y:height/2}),padding=64;
    if(!viewCache||viewCache.width!==width||viewCache.height!==height||viewCache.dpr!==dpr||viewCache.expanded!==expanded||Math.abs(viewCache.mpp-mpp)>1e-8||Math.abs(viewCache.center.x-currentCenter.x)/mpp>padding-8||Math.abs(viewCache.center.z-currentCenter.z)/mpp>padding-8){
    const cw=width+padding*2,ch=height+padding*2;atlas.width=Math.ceil(cw*dpr);atlas.height=Math.ceil(ch*dpr);actx.setTransform(dpr,0,0,dpr,0,0);atlasScale=1/mpp;
    const cacheProjection=mapProjection({center:currentCenter,width:cw,height:ch,metresPerPixel:mpp}),project=cacheProjection.toScreen,lo=cacheProjection.toWorld({x:0,y:0}),hi=cacheProjection.toWorld({x:cw,y:ch});
    const inView=(x,z,r=0)=>x+r>=lo.x&&x-r<=hi.x&&z+r>=lo.z&&z-r<=hi.z;
    actx.fillStyle='#1c3639';actx.fillRect(0,0,cw,ch);const groundA=project({x:world.bounds.minX,z:world.bounds.minZ}),groundB=project({x:world.bounds.maxX,z:world.bounds.maxZ});actx.fillStyle='#61745b';actx.fillRect(groundA.x,groundA.y,groundB.x-groundA.x,groundB.y-groundA.y);
    for(const region of world.regions){const pts=polygon(region.polygon||region.points);if(path(actx,pts,project)){actx.closePath();actx.fillStyle=region.color||(region.kind==='mountain'?'#847d65':'#41614b');actx.fill();} }
    if(world.grid){const size=world.cellSize||4.1,colors={0:'#8e9180',8:'#718366',9:'#a9ad96',14:'#c7b98f',16:'#376b71',19:'#b59a75'};for(let r=Math.max(0,Math.floor(lo.z/size));r<Math.min(world.grid.length,Math.ceil(hi.z/size));r++)for(let c=Math.max(0,Math.floor(lo.x/size));c<Math.min(world.grid[r].length,Math.ceil(hi.x/size));c++){const q=project({x:c*size,z:r*size});actx.fillStyle=colors[world.grid[r][c]]||'#718366';actx.fillRect(q.x,q.y,size*atlasScale+.6,size*atlasScale+.6)}}
    for(const water of world.water){if(path(actx,polygon(water.polygon||water.points),project)){actx.closePath();actx.fillStyle='#376f78';actx.fill();actx.strokeStyle='#82b2ab';actx.lineWidth=1.5;actx.stroke()}}
    for(const [lines,color,dashed] of [[world.roads,'#b3ac8f',false],[world.trails,'#d2bd8a',true]])for(const line of lines){if(path(actx,polygon(line.points||line.polygon),project)){actx.strokeStyle=color;actx.lineWidth=Math.max(1,(line.width||2)*atlasScale);actx.setLineDash(dashed?[4,3]:[]);actx.stroke()}}actx.setLineDash([]);
    for(const railway of world.railways){if(!path(actx,polygon(railway.points||railway.polygon),project))continue;const railWidth=Math.max(2.5,(railway.width||2.2)*atlasScale);actx.strokeStyle='#433f35';actx.lineWidth=railWidth+3;actx.setLineDash([1.3,4]);actx.stroke();actx.setLineDash([]);actx.lineWidth=railWidth;actx.stroke();actx.strokeStyle='#c3b598';actx.lineWidth=Math.max(1,railWidth-1.7);actx.stroke()}
    const drawObjects=objectIndex?.query({minX:lo.x,maxX:hi.x,minZ:lo.z,maxZ:hi.z})||objects;for(const obj of drawObjects){const pts=polygon(obj.polygon),kind=obj.kind||'object';if(!pts.length&&!inView(obj.x,obj.z,obj.radius||1))continue;actx.fillStyle=kinds[kind]?.[1]||kinds.object[1];if(pts.length>=3&&kind!=='tree'){path(actx,pts,project);actx.closePath();actx.fill();if(obj.building||BUILDING_MAP_KINDS.includes(kind)){actx.strokeStyle='#615e51';actx.lineWidth=.85;actx.stroke()}}else{const q=project(obj);actx.beginPath();actx.arc(q.x,q.y,Math.max(.7,(obj.radius||1)*atlasScale),0,Math.PI*2);actx.fill()}}
    // Buildings and their badges share the road atlas, including its overscan.
    // They must never scroll as independent raster/vector layers.
    const detail=mpp<1.1;
    for(const obj of drawObjects){const q=project(obj);if(q.x<-12||q.y<-12||q.x>cw+12||q.y>ch+12)continue;
      if(BUILDING_MAP_KINDS.includes(obj.kind)){const size=detail?13:10;marker(q,kinds[obj.kind][1],size*.7,actx);drawBuildingIcon(actx,obj.kind,q.x,q.y,size);continue}
      const symbol=kinds[obj.kind]?.[2];if(symbol&&(obj.kind!=='water'||expanded)){marker(q,kinds[obj.kind][1],4,actx);if(detail){actx.fillStyle='#122c30';actx.font='bold 9px system-ui';actx.textAlign='center';actx.fillText(symbol,q.x,q.y+3)}}
    }
    viewCache={center:currentCenter,mpp,width,height,dpr,cw,ch,expanded};
    }
    const dx=(viewCache.center.x-currentCenter.x)/mpp-padding,dy=(viewCache.center.z-currentCenter.z)/mpp-padding;
    // Same physical-pixel scale: never enlarge a low-resolution world atlas.
    ctx.drawImage(atlas,dx,dy,atlas.width/dpr,atlas.height/dpr);
  }
  function resize(){const r=stage.getBoundingClientRect();if(!r.width||!r.height)return;width=r.width;height=r.height;dpr=Math.min(2,win.devicePixelRatio||1);canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);dirty=true;draw(true)}
  function marker(p,color,r=5,context=ctx){context.beginPath();context.arc(p.x,p.y,r,0,Math.PI*2);context.fillStyle=color;context.fill();context.strokeStyle='#142d30';context.lineWidth=2;context.stroke()}
  function draw(force=false){
    if(disposed||root.hidden)return;const now=performance.now();if(!force&&now-lastDraw<80)return;lastDraw=now;dirty=false;
    const region=currentMapRegion(position,world),regionName=region?.name||'Окрестности';heading.textContent=expanded?'Карта города':regionName;heading.title=regionName;root.dataset.currentRegion=region?.id||'';
    const pr=projection(),b=world.bounds,tl=pr.toScreen({x:b.minX,z:b.minZ}),br=pr.toScreen({x:b.maxX,z:b.maxZ});ctx.setTransform(dpr,0,0,dpr,0,0);ctx.fillStyle='#1c3639';ctx.fillRect(0,0,width,height);
    const mpp=(b.maxX-b.minX)/(br.x-tl.x);drawBase(pr,mpp);
    for(const actor of actors){const location=actor.position||actor;if(!valid(location)||actor.hidden||actor.active===false||actor.kind==='train')continue;const q=pr.toScreen(location);if(q.x<3||q.y<3||q.x>width-3||q.y>height-3)continue;marker(q,actor.kind==='police'?'#7ec0ee':actor.kind==='boss'?'#cf746c':'#dfdab5',actor.kind==='boss'?4:2.6)}
    for(const car of vehicles){const location=car.position||car;if(!valid(location))continue;const q=pr.toScreen(location);ctx.save();ctx.translate(q.x,q.y);ctx.rotate(-(car.yaw||0));ctx.fillStyle=vehicleMapColor(car);ctx.fillRect(-3,-5,6,10);ctx.strokeStyle='#263b3e';ctx.strokeRect(-3,-5,6,10);ctx.fillStyle='#bfe4df';ctx.fillRect(-2,1,4,2);ctx.restore()}
    const trainIds=new Set();for(const train of [...trains,...actors.filter(a=>a.kind==='train')]){const location=train.position||train;if(!valid(location)||train.hidden||train.active===false||(train.id&&trainIds.has(train.id)))continue;if(train.id)trainIds.add(train.id);const q=pr.toScreen(location);if(q.x<-10||q.y<-10||q.x>width+10||q.y>height+10)continue;ctx.save();ctx.translate(q.x,q.y);ctx.rotate(-(train.yaw||0));ctx.fillStyle='#c8885c';ctx.strokeStyle='#263b3e';ctx.lineWidth=2;ctx.fillRect(-4,-8,8,16);ctx.strokeRect(-4,-8,8,16);ctx.fillStyle='#fff0c3';ctx.fillRect(-2,3,4,3);ctx.fillStyle='#4a5553';ctx.fillRect(-2,-6,4,5);ctx.restore()}
    if(waypoint){const a=pr.toScreen(position),q=pr.toScreen(waypoint);ctx.strokeStyle='#f0c771';ctx.lineWidth=1.5;ctx.setLineDash([5,5]);ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(q.x,q.y);ctx.stroke();ctx.setLineDash([]);const edge=waypointScreenPosition(waypoint,pr,width,height);marker(edge,'#f3ca73',7);ctx.fillStyle='#213739';ctx.font='bold 11px system-ui';ctx.textAlign='center';ctx.fillText('◆',edge.x,edge.y+4)}
    const p=pr.toScreen(position);ctx.save();ctx.translate(clamp(p.x,9,width-9),clamp(p.y,9,height-9));ctx.rotate(-yaw);ctx.beginPath();ctx.moveTo(0,9);ctx.lineTo(-6,-6);ctx.lineTo(0,-3);ctx.lineTo(6,-6);ctx.closePath();ctx.fillStyle='#e8fcf3';ctx.strokeStyle='#133c3b';ctx.lineWidth=2;ctx.fill();ctx.stroke();ctx.restore();
    const scaleM=mpp>3?200:mpp>1?100:50;const scale=root.querySelector('.em-scale');scale.style.width=`${Math.min(width*.4,scaleM/mpp)}px`;scale.textContent=`${Math.round(Math.min(width*.4*mpp,scaleM))} м`;
    const message=waypointDistanceText(position,waypoint);if(message!==lastStatus){status.textContent=message;lastStatus=message}clear.hidden=!waypoint;
  }
  function setWaypoint(p){const bounded=boundedWaypoint(p,world.bounds);waypoint=bounded?{...bounded,name:p.name||''}:null;root.dataset.waypoint=waypoint?JSON.stringify(waypoint):'';onWaypointChange(waypoint?{...waypoint}:null);dirty=true;draw(true);return waypoint}
  function fit(){zoom=1;center={x:(world.bounds.minX+world.bounds.maxX)/2,z:(world.bounds.minZ+world.bounds.maxZ)/2};dirty=true;draw(true)}
  function setExpanded(value){if(expanded===!!value)return;expanded=!!value;root.dataset.expanded=String(expanded);toggle.setAttribute('aria-expanded',String(expanded));toggle.setAttribute('aria-label',expanded?'Свернуть карту':'Развернуть карту');toggle.textContent=expanded?'Закрыть ×':'M ↗';if(expanded){priorFocus=doc.activeElement;fit();if(doc.pointerLockElement)doc.exitPointerLock?.();canvas.focus({preventScroll:true})}else{canvas.blur();if(priorFocus&&priorFocus!==doc.body&&!root.contains(priorFocus))priorFocus.focus?.({preventScroll:true})}onExpandedChange(expanded);resize()}
  function zoomBy(factor,anchor){tooltip.hidden=true;const old=projection();const before=anchor?old.toWorld(anchor):null;zoom=clamp(zoom*factor,.6,12);if(before){const after=projection().toWorld(anchor);center.x+=before.x-after.x;center.z+=before.z-after.z}dirty=true;draw(true)}
  function setWorld(data){
    world={...world,...data};world.bounds={...world.bounds,...data.bounds};for(const field of ['buildings','objects','regions','water','trails','roads','railways','districts'])world[field]=world[field]||[];
    districtLabels=world.districts.map(d=>{const pts=polygon(d.polygon),center=point(d.center||d.centroid||d);return {...d,kind:'district',poi:true,mapPriority:110,x:valid(center)?center.x:pts.reduce((sum,p)=>sum+p.x,0)/pts.length,z:valid(center)?center.z:pts.reduce((sum,p)=>sum+p.z,0)/pts.length}}).filter(valid);
    objects=[...world.buildings,...world.objects].filter(valid);objectIndex=createMapObjectIndex(objects);root.dataset.objectIndex=JSON.stringify(objectIndex.stats());pois=selectMapPOIs(objects);const list=root.querySelector('.em-pois');list.replaceChildren();for(const obj of pois){const button=doc.createElement('button');button.type='button';button.textContent=obj.name;button.title=kinds[obj.kind]?.[0]||'Место';button.addEventListener('click',()=>{setWaypoint(obj);center={x:obj.x,z:obj.z};zoom=Math.max(zoom,2);dirty=true;draw(true)});list.append(button)}
    const legend=root.querySelector('.em-legend');legend.replaceChildren();for(const [kind,[name,color]]of Object.entries(kinds)){if(kind==='object'||kind==='lamp')continue;const row=doc.createElement('span');if(BUILDING_MAP_KINDS.includes(kind)){const icon=doc.createElement('canvas');icon.width=36;icon.height=36;icon.style.cssText='display:inline-block;width:18px;height:18px;vertical-align:middle;margin-right:3px;cursor:default';const iconCtx=icon.getContext('2d');iconCtx.fillStyle=color;iconCtx.fillRect(0,0,36,36);drawBuildingIcon(iconCtx,kind,18,18,26);row.append(icon)}else{const swatch=doc.createElement('i');swatch.style.background=color;row.append(swatch)}row.append(doc.createTextNode(name));legend.append(row)}root.querySelector('.em-count').textContent=`${objects.length.toLocaleString('ru-RU')} объектов · наведите на значок для названия`;root.dataset.objectCount=String(objects.length);rebuild();if(expanded)fit();draw(true);
  }
  const local=e=>{const r=canvas.getBoundingClientRect();return{x:e.clientX-r.left,y:e.clientY-r.top}};
  listen(toggle,'click',()=>setExpanded(!expanded));listen(clear,'click',()=>setWaypoint(null));
  listen(root,'pointerdown',e=>e.stopPropagation());listen(root,'pointerup',e=>e.stopPropagation());listen(root,'click',e=>e.stopPropagation());listen(root,'contextmenu',e=>{e.preventDefault();e.stopPropagation()});
  listen(canvas,'contextmenu',e=>{e.preventDefault();e.stopPropagation();if(waypointMarkerHit(local(e),waypoint,projection(),width,height))setWaypoint(null)});
  listen(root,'wheel',e=>{e.preventDefault();e.stopPropagation()},{passive:false});
  listen(canvas,'pointerdown',e=>{if(e.button!==0)return;e.preventDefault();canvas.focus({preventScroll:true});const p=local(e);drag={start:p,last:p,moved:false,id:e.pointerId};canvas.setPointerCapture?.(e.pointerId)});
  listen(canvas,'pointermove',e=>{const p=local(e);if(!drag){const obj=mapObjectAt(p,objects,projection());tooltip.hidden=!obj;if(obj){tooltip.textContent=obj.name;tooltip.style.left=clamp(p.x+12,5,Math.max(5,width-tooltip.offsetWidth-5))+'px';tooltip.style.top=clamp(p.y+12,5,Math.max(5,height-tooltip.offsetHeight-5))+'px'}return}tooltip.hidden=true;const dx=p.x-drag.last.x,dy=p.y-drag.last.y;drag.moved||=Math.hypot(p.x-drag.start.x,p.y-drag.start.y)>5;if(expanded&&drag.moved){const a=projection().toWorld({x:0,y:0}),b=projection().toWorld({x:dx,y:dy});center.x-=b.x-a.x;center.z-=b.z-a.z;dirty=true;draw(true)}drag.last=p});
  listen(canvas,'pointerleave',()=>{tooltip.hidden=true});
  listen(canvas,'pointerup',e=>{if(!drag||drag.id!==e.pointerId)return;if(!drag.moved)setWaypoint(projection().toWorld(local(e)));canvas.releasePointerCapture?.(e.pointerId);drag=null;if(!expanded)canvas.blur()});listen(canvas,'pointercancel',()=>{drag=null});
  listen(canvas,'wheel',e=>{e.preventDefault();if(expanded)zoomBy(e.deltaY<0?1.2:1/1.2,local(e))},{passive:false});
  listen(root.querySelector('.em-tools'),'click',e=>{const action=e.target.closest('button')?.dataset.action;if(action==='plus')zoomBy(1.4);if(action==='minus')zoomBy(1/1.4);if(action==='fit')fit();if(action==='hero'){center={...position};zoom=Math.max(zoom,3);dirty=true;draw(true)}});
  const typing=e=>e.target?.matches?.('input,textarea,select,[contenteditable="true"]');
  listen(root,'keydown',e=>{if(expanded)e.stopPropagation()});
  listen(win,'keydown',e=>{if(typing(e))return;if(e.altKey||e.ctrlKey||e.metaKey){if(expanded)e.stopImmediatePropagation();return}if(e.code==='KeyM'||(expanded&&e.code==='Escape')){e.preventDefault();e.stopImmediatePropagation();if(!e.repeat)setExpanded(!expanded);return}if(!expanded)return;if(e.code==='Tab'){const focusable=[...root.querySelectorAll('button:not([hidden]),canvas[tabindex]')],index=focusable.indexOf(doc.activeElement);e.preventDefault();e.stopImmediatePropagation();focusable[(index+(e.shiftKey?-1:1)+focusable.length)%focusable.length]?.focus();return}if(e.target?.closest?.('button')&&['Enter','Space'].includes(e.code))return;e.stopImmediatePropagation();e.preventDefault();if(e.code==='Equal'||e.code==='NumpadAdd')zoomBy(1.2);else if(e.code==='Minus'||e.code==='NumpadSubtract')zoomBy(1/1.2);else if(e.code==='Enter'&&e.target===canvas)setWaypoint(center);else if(e.code.startsWith('Arrow')){const a=projection().toWorld({x:0,y:0}),b=projection().toWorld({x:50,y:50});if(e.code==='ArrowLeft')center.x-=b.x-a.x;if(e.code==='ArrowRight')center.x+=b.x-a.x;if(e.code==='ArrowUp')center.z-=b.z-a.z;if(e.code==='ArrowDown')center.z+=b.z-a.z;dirty=true;draw(true)}},true);
  listen(win,'keyup',e=>{if(expanded&&!typing(e)&&e.code!=='Tab')e.stopImmediatePropagation()},true);listen(win,'resize',resize);
  const observer=typeof win.ResizeObserver==='function'?new win.ResizeObserver(resize):null;observer?.observe(stage);
  setWorld({});resize();
  return {element:root,setWorld,setWaypoint,get waypoint(){return waypoint?{...waypoint}:null},get expanded(){return expanded},setExpanded,update(state={}){
    // The game calls this every animation frame.  Redrawing unchanged map state
    // only burns main-thread time: draw() is already capped at 12.5 FPS.
    let changed=false;
    if(valid(state.position)&&(position.x!==state.position.x||position.z!==state.position.z)){position={x:state.position.x,z:state.position.z};changed=true}
    if(Number.isFinite(state.yaw)&&yaw!==state.yaw){yaw=state.yaw;changed=true}
    if(state.vehicles&&vehicles!==state.vehicles){vehicles=state.vehicles;changed=true}
    if(state.actors&&actors!==state.actors){actors=state.actors;changed=true}
    if(state.trains&&trains!==state.trains){trains=state.trains;changed=true}
    if(changed){dirty=true;draw()}
  },setVisible(value){if(root.hidden===!value)return;root.hidden=!value;if(value)resize()},dispose(){disposed=true;observer?.disconnect();cleanups.forEach(fn=>fn());root.remove();style.remove()}};
}
