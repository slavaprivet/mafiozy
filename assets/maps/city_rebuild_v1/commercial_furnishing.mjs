// Decorative room plans in metres. Room door is centred on +Z. The central
// 1.44m approach stays clear; furniture parts use a bottom-centre local pivot.
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const PAL={wall:0xbdb09b,floor:0x796d62,accent:0x663641,wood:0x513e31,metal:0x9a8053};
const hash=value=>{let n=2166136261;for(const c of String(value))n=Math.imul(n^c.charCodeAt(0),16777619);return n>>>0};
function make(kind,w,d,h,p,variant=0){
 const parts=[],add=(shape,x,y,z,sx,sy,sz,color,extra={})=>parts.push({shape,position:[x,y,z],size:[sx,sy,sz],color,...extra});
 const box=(x,y,z,sx,sy,sz,c)=>add('box',x,y,z,sx,sy,sz,c);
 const metal=(x,y,z,sx,sy,sz)=>add('box',x,y,z,sx,sy,sz,p.metal,{metalness:.55,roughness:.4});
 const leg=(x,z,lh)=>box(x,lh/2,z,.055,lh,.055,p.wood);
 const top=(y,c=p.wood)=>box(0,y,0,w,.055,d,c);
 if(kind==='counter'||kind==='bar-counter'){
  box(0,h*.46,0,w*.97,h*.88,d*.89,p.wood);top(h-.028,p.wall);
  box(0,h*.51,d*.451,w*.91,h*.58,.024,p.accent);
  for(const x of[-.44,0,.44])metal(x*w,h*.51,d*.469,.022,h*.65,.018);
  metal(0,h*.17,d*.475,w*.94,.026,.02);
  // Recessed cash register remains within the furniture's declared height.
  box(-w*.3,h+.065,-d*.13,.19,.12,.2,0x343b36);
  box(-w*.3,h+.145,-d*.16,.15,.05,.10,p.metal);h+=.18;
  if(kind==='bar-counter')for(let i=0;i<4;i++){const x=w*(.05+i*.13);add('cylinder',x,h-.07,0,.055,.14,.055,i%2?0x43645c:0x845240);box(x,h+.015,0,.034,.03,.034,p.metal)}
  h+=kind==='bar-counter'?.05:0;
 }else if(kind==='display-case'){
  box(0,h*.18,0,w*.96,h*.34,d*.96,p.wood);
  box(0,h*.64,0,w*.93,h*.53,d*.86,0x36575a);
  for(const x of[-w*.47,w*.47])metal(x,h*.67,d*.46,.027,h*.63,.027);
  for(const y of[h*.37,h*.96])metal(0,y,d*.46,w*.96,.026,.027);
  top(h-.03,p.wall);
  for(let i=0;i<3;i++){const x=(i-1)*w*.26;box(x,h*.49,d*.475,w*.16,h*.14,.024,i%2?p.metal:0xa6926d);metal(x,h*.43,d*.49,w*.2,.025,.016)}
 }else if(kind==='goods-shelf'||kind==='bottle-shelf'||kind==='locked-cabinet'){
  box(0,h/2,-d*.45,w,h,d*.1,p.wood);
  for(const x of[-w*.47,w*.47])box(x,h/2,0,w*.06,h,d,p.wood);
  for(let j=0;j<4;j++){
   const y=.07+j*(h-.15)/3;box(0,y,0,w,.035,d,p.wood);
   if(j===3)continue;
   for(let i=0;i<4;i++){
    const x=(i-1.5)*w*.21,gh=Math.min(.23,(h-.15)/3*.7);
    if(kind==='bottle-shelf'){
     add('cylinder',x,y+gh*.45,0,w*.065,gh*.8,w*.065,(i+variant)%2?0x41625b:0x795844);
     add('cylinder',x,y+gh*.93,0,w*.035,gh*.2,w*.035,p.metal);
    }else {box(x,y+gh/2+.018,0,w*.14,gh,d*.55,[p.accent,p.wall,0x47605b,0x89765c][(i+j+variant)%4]);metal(x,y+gh*.6,d*.285,w*.09,.015,.01)}
   }
  }
  if(kind==='locked-cabinet')for(let i=0;i<3;i++)metal((i-1)*w*.3,h*.5,d*.5,.018,h*.87,.02);
 }else if(kind==='sofa'||kind==='banquette'){
  const seatH=h*.43;for(const x of[-w*.4,w*.4])for(const z of[-d*.34,d*.34])leg(x,z,.17);
  box(0,seatH,0,w*.92,h*.23,d*.91,p.accent);
  box(0,h*.75,-d*.34,w*.96,h*.5,d*.24,p.accent);
  for(const x of[-w*.46,w*.46])box(x,h*.51,0,w*.08,h*.49,d*.95,p.wood);
  const n=w>1.4?3:2;
  for(let i=0;i<n;i++){const x=(i-(n-1)/2)*w*.83/n;box(x,seatH+h*.17,d*.025,w*.78/n,h*.12,d*.64,variant%2?0x80515a:0x775c50);box(x,h*.78,-d*.18,w*.77/n,h*.29,d*.08,p.accent)}
  metal(0,h*.16,d*.48,w*.86,.025,.024);
 }else if(kind==='desk'||kind==='dressing-table'){
  for(const x of[-w*.43,w*.43])for(const z of[-d*.4,d*.4])leg(x,z,h*.85);
  top(h*.85,p.wood);box(-w*.28,h*.57,0,w*.3,h*.48,d*.9,p.wood);
  for(let j=0;j<2;j++){box(-w*.28,h*(.43+j*.23),d*.458,w*.27,h*.2,.025,p.accent);metal(-w*.28,h*(.43+j*.23),d*.48,w*.1,.023,.018)}
  if(kind==='desk'){box(w*.16,h*.9,0,w*.23,h*.035,d*.32,p.wall);box(w*.32,h*.96,-d*.2,w*.1,h*.09,d*.12,p.metal)}
  else {box(0,h*1.15,-d*.42,w*.64,h*.53,.04,p.metal);box(0,h*1.15,-d*.39,w*.58,h*.46,.025,0x567276);h*=1.42}
 }else if(kind==='music-console'){
  box(0,h*.35,0,w,h*.7,d,0x303631);box(0,h*.78,0,w*.88,h*.14,d*.84,p.wood);
  for(const x of[-w*.28,w*.28]){add('cylinder',x,h*.86,0,w*.28,.035,w*.28,0x202823);add('cylinder',x,h*.885,0,w*.06,.015,w*.06,p.metal)}
  for(let i=0;i<5;i++)metal((i-2)*w*.032,h*.91,d*.26,.019,.018,d*.16);
 }else if(kind==='stage'){
  box(0,h*.45,0,w,h*.9,d,p.wood);box(0,h*.93,0,w,.04,d,p.accent);
  for(const x of[-w*.43,w*.43]){box(x,h+.23,-d*.28,w*.13,.44,d*.3,0x303630);add('sphere',x,h+.29,-d*.12,w*.09,w*.09,.035,0x62695d);add('sphere',x,h+.12,-d*.12,w*.07,w*.07,.028,0x62695d)}h+=.47;
 }else if(kind==='coffee-table'){
  for(const x of[-w*.4,w*.4])for(const z of[-d*.36,d*.36])leg(x,z,h-.05);top(h-.025,p.wood);
  box(w*.17,h+.025,0,w*.28,.045,d*.32,p.wall);add('cylinder',-w*.25,h+.055,0,.09,.10,.09,p.metal);h+=.11;
 }else throw Error('Unknown commercial furnishing '+kind);
 // Keep small handles/edge trims within the declared placement footprint,
 // including narrow rooms whose cabinet depth is reduced.
 for(const part of parts){for(const [axis,limit]of[[0,w],[1,h],[2,d]])part.size[axis]=Math.min(part.size[axis],limit);part.position[0]=clamp(part.position[0],-w/2+part.size[0]/2,w/2-part.size[0]/2);part.position[2]=clamp(part.position[2],-d/2+part.size[2]/2,d/2-part.size[2]/2);part.position[1]=clamp(part.position[1],part.size[1]/2,h-part.size[1]/2)}
 return {kind,x:0,z:0,yaw:0,width:w,depth:d,height:h,parts};
}
export function planCommercialRoom({assetId,level=0,roomIndex=0,width,depth,seed=0}={}){
 if(![width,depth].every(n=>Number.isFinite(n)&&n>0)||!Number.isInteger(level)||level<0||!Number.isInteger(roomIndex)||roomIndex<0)throw Error('Invalid commercial room dimensions/index');
 const variation=hash(`${assetId}:${level}:${roomIndex}:${seed}`),night=/nightclub|strip_club/.test(assetId??''),gun=/gun_shop/.test(assetId??''),bet=/bookmaker/.test(assetId??''),glass=/glass_pavilion|galleria/.test(assetId??''),storage=level>0&&roomIndex%3===1;
 const p={...PAL,wall:night?0x8c7970:glass?0xd2c8b5:0xbdb09b,floor:night?0x5d4842:0x807263,accent:gun?0x41554c:bet?0x45594e:0x663641};
 const name=level>0?(storage?'Кладовая':night?'Гримёрная и кабинет':'Кабинет управляющего'):night?'Бар и музыкальный зал':gun?'Оружейный салон':bet?'Букмекерская контора':glass?'Галерея товаров':'Ломбард';
 const finish=storage?'brick':night?'wood-panel':level>0?'wallpaper':gun?'brick':'wood-panel';
 const result={name,finish,floorFinish:night?'dark-parquet':glass?'limestone-tile':'warm-parquet',palette:p,furniture:[]};
 if(width<1.45||depth<1.6)return result;
 const occupied=[],margin=.14;
 function place(kind,w,d,h,x,z,yaw=0){
  if(w<.45||d<.25||h<.2)return false;
  const item=make(kind,w,d,h,p,variation%4),c=Math.abs(Math.cos(yaw)),s=Math.abs(Math.sin(yaw)),hx=(w*c+d*s)/2,hz=(w*s+d*c)/2,b=[x-hx,z-hz,x+hx,z+hz];
  if(b[0]<-width/2+margin-1e-8||b[2]>width/2-margin+1e-8||b[1]<-depth/2+margin-1e-8||b[3]>depth/2-margin+1e-8)return false;
  if(b[2]>-.74&&b[0]<.74&&b[3]>-.08)return false;
  if(occupied.some(a=>b[0]<a[2]+.1&&b[2]>a[0]-.1&&b[1]<a[3]+.1&&b[3]>a[1]-.1))return false;
  Object.assign(item,{x,z,yaw});result.furniture.push(item);occupied.push(b);return true;
 }
 const backW=Math.min(width-.32,night&&level===0?3:2.5),backD=Math.min(.7,depth*.21);
 const primary=storage?'locked-cabinet':level>0?(night?'dressing-table':'desk'):night?(roomIndex%2?'music-console':'bar-counter'):gun?'locked-cabinet':bet?'counter':'display-case';
 place(primary,backW,backD,primary==='locked-cabinet'?1.85:1.02,0,-depth/2+margin+backD/2);
 // Wall-aligned objects face inward. Their actual rotated bounds are checked;
 // the entire front-centre aisle remains wider than the player capsule.
 const sideDepth=Math.min(.58,width/2-.9),sideW=Math.min(1.9,depth*.38);
 if(sideDepth>=.3&&depth>3.1){
  const lx=-width/2+margin+sideDepth/2,rx=-lx;
  place(storage?'goods-shelf':night?'banquette':level>0?'goods-shelf':'goods-shelf',sideW,sideDepth,night?1.05:1.75,lx,-.05,Math.PI/2);
  place(storage?'locked-cabinet':night?'bottle-shelf':level>0?'sofa':'display-case',sideW,sideDepth,night?1.75:level>0?.95:1.12,rx,-.05,-Math.PI/2);
  const frontZ=depth/2-margin-.65;
  if(depth>5.4){place(night?'banquette':'sofa',1.15,sideDepth,.98,lx,frontZ,Math.PI/2);place(level>0?'goods-shelf':night?'banquette':'display-case',1.15,sideDepth,night?.98:1.25,rx,frontZ,-Math.PI/2)}
 }
 if(width>6.5&&depth>7){
  const kind=night&&level===0?'stage':'coffee-table',w=night?2.2:1.15,d=night?1.2:.65;
  place(kind,w,d,night?.28:.45,0,-depth*.25+.1);
 }
 return result;
}
