/** Deterministic world-metre extension. The original city is never rescaled or sculpted. */
export const LANDSCAPE_BOUNDS=Object.freeze({minX:-240,maxX:978,minZ:-420,maxZ:900});
export const CITY_BOUNDS=Object.freeze({minX:0,maxX:738,minZ:0,maxZ:820});
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const smooth=v=>{v=clamp(v);return v*v*(3-2*v)};
const mix=(a,b,t)=>a+(b-a)*t;
const gaussian=(x,z,cx,cz,rx,rz,h)=>h*Math.exp(-2*((x-cx)**2/rx**2+(z-cz)**2/rz**2));
function axis(lo,hi,extra){const a=[];for(let n=lo;n<=hi;n+=4)a.push(n);return [...new Set([...a,hi,...extra])].sort((a,b)=>a-b)}
function interval(a,v){let l=0,r=a.length-1;while(r-l>1){const m=(l+r)>>1;if(a[m]<=v)l=m;else r=m}return Math.min(a.length-2,l)}
function curve(points){const result=[];for(let i=0;i<points.length-1;i++){const a=points[Math.max(0,i-1)],b=points[i],c=points[i+1],d=points[Math.min(points.length-1,i+2)],count=Math.max(2,Math.ceil(Math.hypot(c[0]-b[0],c[1]-b[1])/3));for(let j=0;j<count;j++){const t=j/count,t2=t*t,t3=t2*t;result.push({x:.5*((2*b[0])+(-a[0]+c[0])*t+(2*a[0]-5*b[0]+4*c[0]-d[0])*t2+(-a[0]+3*b[0]-3*c[0]+d[0])*t3),z:.5*((2*b[1])+(-a[1]+c[1])*t+(2*a[1]-5*b[1]+4*c[1]-d[1])*t2+(-a[1]+3*b[1]-3*c[1]+d[1])*t3)})}}const end=points.at(-1);result.push({x:end[0],z:end[1]});return result}
export function createLandscapePlan(){
 const bounds=LANDSCAPE_BOUNDS,cityBounds=CITY_BOUNDS;
 const inBounds=(x,z)=>Number.isFinite(x)&&Number.isFinite(z)&&x>=bounds.minX&&x<=bounds.maxX&&z>=bounds.minZ&&z<=bounds.maxZ;
 // Native masks use floor indices: the eastern/southern edge belongs to the extension.
 const insideCity=(x,z)=>x>=0&&x<738&&z>=0&&z<820;
 const contains=(x,z)=>inBounds(x,z)&&!insideCity(x,z);
 const lakes=[{id:'lake-cedar',name:'Кедровое озеро',x:280,z:-137,rx:85,rz:51,level:1.8,depth:7.2},{id:'lake-east',name:'Лазурное озеро',x:867,z:425,rx:59,rz:91,level:1.2,depth:6}];
 const lakeRadius=(l,x,z)=>{const dx=(x-l.x)/l.rx,dz=(z-l.z)/l.rz,a=Math.atan2(dz,dx);return Math.hypot(dx,dz)/(1+.065*Math.sin(3*a)+.035*Math.cos(5*a))};
 function rawHeight(x,z){
  if(x>=0&&x<=738&&z>=0&&z<=820)return 0;
  const outside=Math.hypot(Math.max(-x,0,x-738),Math.max(-z,0,z-820)),fade=smooth(outside/42);
  let h=5+gaussian(x,z,85,-286,155,115,35)+gaussian(x,z,448,-324,170,103,50)+gaussian(x,z,713,-277,123,138,36)+gaussian(x,z,-150,350,135,230,18)+gaussian(x,z,855,700,115,155,18)+gaussian(x,z,-145,35,100,90,12);
  h+=fade*(1.3*Math.sin(x*.019+z*.011)+1.1*Math.cos(z*.026-x*.008)+.45*Math.sin(x*.047+z*.032));
  h*=fade;
  for(const l of lakes){const r=lakeRadius(l,x,z);if(r<1.38){const basin=l.level+.35-l.depth*(1-smooth(r));h=mix(basin,h,smooth((r-1)/.38))}}
  return h;
 }
 const definitions=[
  {id:'north-scenic-road',name:'Северная лесная дорога',width:9,drive:true,points:[[82,0],[82,-44],[115,-83],[161,-102],[164,-167],[216,-218],[348,-220],[408,-174],[430,-88],[459,-40],[459,0]]},
  {id:'west-forest-road',name:'Западная лесная дорога',width:9,drive:true,points:[[0,213],[-48,213],[-81,176],[-109,90],[-95,7],[-73,-58],[-27,-89],[43,-98],[115,-83]]},
  {id:'east-lakeside-road',name:'Озёрная дорога',width:9,drive:true,points:[[738,213],[779,213],[803,261],[788,330],[784,421],[794,500],[780,541],[738,541]]},
  {id:'ridge-ascent',name:'Тропа к вершине',width:4.2,drive:false,points:[[348,-220],[388,-252],[507,-251],[540,-278],[423,-287],[394,-307],[459,-326]]},
  {id:'cedar-shore',name:'Кедровая береговая тропа',width:4,drive:false,points:[[164,-167],[180,-119],[206,-79],[285,-66],[367,-91],[382,-141],[366,-180],[321,-203],[248,-200],[216,-218]]},
  {id:'west-ridge-trail',name:'Сосновый перевал',width:4,drive:false,points:[[-81,176],[-150,211],[-181,282],[-105,326],[-173,366],[-168,428],[-81,488],[-37,477],[0,477]]},
  {id:'east-shore-trail',name:'Лазурная тропа',width:3.8,drive:false,points:[[803,261],[865,298],[929,345],[941,425],[927,508],[869,543],[827,516],[794,500]]},
  {id:'east-meadow-trail',name:'Тропа солнечных лугов',width:4,drive:false,points:[[780,541],[815,591],[897,626],[864,686],[818,730],[864,786],[815,839],[729,852],[643,820]]},
  {id:'north-east-trail',name:'Восточный перевал',width:4,drive:false,points:[[574,0],[574,-64],[625,-118],[723,-152],[782,-217],[720,-282],[653,-270],[572,-219],[507,-251]]}
 ];
 const paths=definitions.map(p=>({...p,points:curve(p.points).map(q=>({...q,y:rawHeight(q.x,q.z)}))}));
 // Clamp profiles in both directions, retaining native city-height endpoints.
 for(const p of paths){const maxGrade=p.drive?.20:.30;for(let pass=0;pass<4;pass++){for(let i=1;i<p.points.length;i++){const a=p.points[i-1],b=p.points[i],d=Math.hypot(b.x-a.x,b.z-a.z)*maxGrade;b.y=clamp(b.y,a.y-d,a.y+d)}for(let i=p.points.length-2;i>=0;i--){const a=p.points[i+1],b=p.points[i],d=Math.hypot(b.x-a.x,b.z-a.z)*maxGrade;b.y=clamp(b.y,a.y-d,a.y+d)}}}
 const segmentBuckets=new Map(),bucketSize=32;
 for(const p of paths)for(let i=1;i<p.points.length;i++){const a=p.points[i-1],b=p.points[i],pad=p.width/2+15,segment={a,b,path:p};for(let ix=Math.floor((Math.min(a.x,b.x)-pad)/bucketSize);ix<=Math.floor((Math.max(a.x,b.x)+pad)/bucketSize);ix++)for(let iz=Math.floor((Math.min(a.z,b.z)-pad)/bucketSize);iz<=Math.floor((Math.max(a.z,b.z)+pad)/bucketSize);iz++){const k=ix+','+iz;if(!segmentBuckets.has(k))segmentBuckets.set(k,[]);segmentBuckets.get(k).push(segment)}}
 function pathAt(x,z,filter=null){let nearest=null;for(const s of segmentBuckets.get(Math.floor(x/bucketSize)+','+Math.floor(z/bucketSize))||[]){if(filter&&!filter(s.path))continue;const dx=s.b.x-s.a.x,dz=s.b.z-s.a.z,t=clamp(((x-s.a.x)*dx+(z-s.a.z)*dz)/(dx*dx+dz*dz||1)),distance=Math.hypot(x-s.a.x-dx*t,z-s.a.z-dz*t);if(!nearest||distance<nearest.distance)nearest={distance,path:s.path,y:mix(s.a.y,s.b.y,t)}}return nearest||{distance:Infinity,path:null,y:0}}
 function sculptedHeight(x,z){if(x>=0&&x<=738&&z>=0&&z<=820)return 0;const h=rawHeight(x,z),p=pathAt(x,z);return p.path?mix(p.y,h,smooth((p.distance-p.path.width/2)/12)):h}
 const xs=axis(bounds.minX,bounds.maxX,[0,738]),zs=axis(bounds.minZ,bounds.maxZ,[0,820]);
 const heights=new Float32Array(xs.length*zs.length);for(let j=0;j<zs.length;j++)for(let i=0;i<xs.length;i++)heights[j*xs.length+i]=sculptedHeight(xs[i],zs[j]);
 function groundHeight(x,z){if(!inBounds(x,z)||insideCity(x,z))return 0;const i=interval(xs,x),j=interval(zs,z),u=(x-xs[i])/(xs[i+1]-xs[i]),v=(z-zs[j])/(zs[j+1]-zs[j]),a=heights[j*xs.length+i],b=heights[j*xs.length+i+1],c=heights[(j+1)*xs.length+i],d=heights[(j+1)*xs.length+i+1];return u>=v?a+(b-a)*u+(d-b)*v:a+(d-c)*u+(c-a)*v}
 function waterAt(x,z){if(!contains(x,z))return null;for(const l of lakes){if(lakeRadius(l,x,z)>1.12)continue;const floor=groundHeight(x,z),depth=l.level-floor;if(depth>.015)return {id:l.id,level:l.level,floor,depth}}return null}
 const slopeAt=(x,z)=>Math.hypot((groundHeight(x+.5,z)-groundHeight(x-.5,z)),(groundHeight(x,z+.5)-groundHeight(x,z-.5)));
 const canWalk=(x,z)=>contains(x,z)&&(!!waterAt(x,z)||slopeAt(x,z)<.78);
 const canDrive=(x,z)=>{if(!contains(x,z)||waterAt(x,z))return false;const p=pathAt(x,z,p=>p.drive);return !!p.path?.drive&&p.distance<p.path.width/2-.15&&slopeAt(x,z)<.27};
 const forestZones=[{id:'western-pines',name:'Сосновый лес',x:-133,z:322,rx:95,rz:235,density:1},{id:'cedar-woods',name:'Кедровый бор',x:280,z:-137,rx:178,rz:100,density:1},{id:'north-ridge-forest',name:'Северный горный лес',x:417,z:-306,rx:448,rz:100,density:.8},{id:'east-woods',name:'Восточная роща',x:860,z:662,rx:94,rz:154,density:.75},{id:'west-gateway',name:'Лесная низина',x:-117,z:4,rx:85,rz:136,density:.85}];
 const landmarks=[{id:'cedar-overlook',name:'Кедровое озеро',x:280,z:-66},{id:'ridge-summit',name:'Северная вершина',x:459,z:-326},{id:'west-overlook',name:'Сосновый перевал',x:-173,z:366},{id:'azure-overlook',name:'Лазурное озеро',x:941,z:425},{id:'meadow-overlook',name:'Солнечные луга',x:864,z:686},{id:'north-gate',name:'Въезд в лес',x:82,z:-36}].map(p=>({...p,y:groundHeight(p.x,p.z)}));
 const ellipse=(l,n=56)=>Array.from({length:n},(_,i)=>{const a=i/n*Math.PI*2;let r=1;if(l.depth){let lo=0,hi=1.2;for(let j=0;j<20;j++){const t=(lo+hi)/2,x=l.x+Math.cos(a)*l.rx*t,z=l.z+Math.sin(a)*l.rz*t;if(groundHeight(x,z)<l.level)lo=t;else hi=t}r=(lo+hi)/2}return {x:l.x+Math.cos(a)*l.rx*r,z:l.z+Math.sin(a)*l.rz*r}});
 const mapFeatures=[...lakes.map(l=>({...l,type:'lake',polygon:ellipse(l)})),...forestZones.map(f=>({...f,type:'forest',polygon:ellipse(f)})),...paths.map(p=>({...p,type:p.drive?'road':'trail'})),...landmarks.map(p=>({...p,type:'landmark'})),{id:'northern-range',name:'Северный хребет',type:'mountain',x:448,z:-324,polygon:[{x:0,z:-420},{x:0,z:-245},{x:425,z:-222},{x:815,z:-205},{x:890,z:-420}]}];
 return {bounds,cityBounds,contains,inBounds,insideCity,groundHeight,waterAt,slopeAt,canWalk,canDrive,pathAt,paths,lakes,forestZones,landmarks,mapFeatures,grid:{xs,zs,heights},lakeRadius};
}
