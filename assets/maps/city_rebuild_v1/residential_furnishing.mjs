// Original primitive recipes. Metres, +Z centred doorway, no lights/textures.
const hash=value=>{let h=2166136261;for(const c of String(value)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
const random=seed=>{let n=seed>>>0;return()=>{n+=0x6d2b79f5;let t=n;t=Math.imul(t^(t>>>15),t|1);t^=t+Math.imul(t^(t>>>7),t|61);return((t^(t>>>14))>>>0)/4294967296}};
const palettes={
 cottage:[{wall:'#d1c5aa',floor:'#86654a',accent:'#677867',wood:'#705039',metal:'#b29a67'},{wall:'#cdc4b7',floor:'#80614e',accent:'#8b5355',wood:'#624634',metal:'#a68a58'}],
 oldtown:[{wall:'#c6b19d',floor:'#72543e',accent:'#783d4d',wood:'#533b32',metal:'#b2925b'},{wall:'#c5c1a5',floor:'#7f5d42',accent:'#446b69',wood:'#604434',metal:'#b59562'}],
 modern:[{wall:'#ccc8be',floor:'#99938a',accent:'#426b6c',wood:'#766555',metal:'#827969'},{wall:'#c7beb1',floor:'#a19b8f',accent:'#804c53',wood:'#625449',metal:'#a79366'}],
 apartment:[{wall:'#c7c5b3',floor:'#918471',accent:'#647e78',wood:'#80654c',metal:'#a7926e'},{wall:'#cdbfae',floor:'#8c7b68',accent:'#965f50',wood:'#715641',metal:'#ad966b'}],
};
function recipe(kind,p,rng){
 const parts=[],add=(shape,x,y,z,w,h,d,color,extra={})=>parts.push({shape,position:[x,y,z],size:[w,h,d],color,roughness:.82,...extra});
 const box=(x,y,z,w,h,d,c,extra)=>add('box',x,y,z,w,h,d,c,extra),cyl=(x,y,z,d,h,c,extra)=>add('cylinder',x,y,z,d,h,d,c,extra);
 const brass={metalness:.65,roughness:.35},cream='#dfd6c5',dark='#302f2e',linen='#c4b7a1';let width,depth,height;
 const legs=(w,d,top,leg=.055)=>{for(const x of[-w/2+.07,w/2-.07])for(const z of[-d/2+.07,d/2-.07])box(x,top/2,z,leg,top,leg,p.wood)};
 switch(kind){
 case 'sofa': width=1.95;depth=.88;height=.91;legs(width,depth,.15);box(0,.26,0,1.88,.24,.8,p.wood);box(0,.68,-.35,1.9,.46,.18,p.accent);for(const x of[-.9,.9])box(x,.52,0,.15,.47,.88,p.accent);for(const x of[-.42,.42]){box(x,.44,.025,.79,.16,.64,p.accent);box(x,.69,-.225,.75,.32,.15,p.accent)}box(-.59,.68,.1,.3,.29,.12,linen);box(.56,.64,.08,.32,.23,.14,cream);break;
 case 'armchair':width=.8;depth=.83;height=.94;legs(width,depth,.16);box(0,.28,0,.75,.23,.76,p.wood);box(0,.46,.04,.57,.17,.61,p.accent);box(0,.7,-.31,.77,.47,.2,p.accent);for(const x of[-.34,.34])box(x,.51,0,.12,.42,.8,p.accent);break;
 case 'bed':case 'single_bed':width=kind==='bed'?1.48:.95;depth=2.03;height=1.13;legs(width,depth,.2,.065);box(0,.24,0,width,.18,1.96,p.wood);box(0,.4,0,width-.08,.2,1.93,cream);box(0,.52,.26,width-.06,.09,1.37,p.accent);box(0,.61,-.94,width,1.02,.15,p.wood);box(0,.89,-.835,width-.18,.31,.055,linen);for(const x of(kind==='bed'?[-.35,.35]:[0]))box(x,.55,-.65,kind==='bed'?.59:.65,.16,.43,linen);box(0,.575,.73,width-.04,.045,.38,cream);break;
 case 'wardrobe':width=1.13;depth=.55;height=1.96;box(0,.995,0,1.13,1.93,.55,p.wood);for(const x of[-.28,.28]){box(x,1.045,.288,.535,1.74,.018,p.wall);box(x,1.045,.306,.4,1.5,.018,p.wood)}for(const x of[-.052,.052])cyl(x,1.025,.329,.031,.28,p.metal,brass);depth=.69;break;
 case 'bookcase':width=.86;depth=.34;height=1.64;box(0,.82,-.142,.86,1.64,.052,p.wood);for(const x of[-.397,.397])box(x,.82,0,.065,1.64,.34,p.wood);for(const y of[.05,.46,.9,1.34,1.6])box(0,y,0,.86,.055,.34,p.wood);for(const y of[.49,.93,1.37]){let x=-.33;for(let i=0;i<5;i++){const w=.075+rng()*.025,h=.15+rng()*.085;if(x+w>.35)break;box(x+w/2,y+h/2,0,w,h,.205,[p.accent,linen,p.wall,'#665854'][i%4]);x+=w+.016}}break;
 case 'desk':width=1.2;depth=.6;height=.77;legs(width,depth,.71,.06);box(0,.735,0,1.2,.07,.6,p.wood);box(.34,.57,.005,.42,.25,.5,p.wood);box(.34,.57,.268,.34,.18,.02,p.wall);box(.34,.57,.287,.13,.022,.016,p.metal,brass);box(-.21,.779,0,.34,.012,.25,cream);height=.79;break;
 case 'dining_table':width=1.18;depth=.78;height=.76;legs(width,depth,.7,.065);box(0,.725,0,1.18,.07,.78,p.wood);box(0,.766,0,.86,.012,.28,linen);cyl(.25,.79,0,.16,.035,p.wall);height=.81;break;
 case 'chair':width=.47;depth=.5;height=.93;legs(.47,.5,.43,.045);box(0,.45,0,.47,.055,.48,p.wood);box(0,.49,.015,.41,.04,.4,p.accent);for(const x of[-.2,.2])box(x,.685,-.21,.045,.49,.045,p.wood);box(0,.785,-.21,.42,.23,.055,p.wood);break;
 case 'coffee_table':width=.88;depth=.48;height=.42;legs(.88,.48,.36);box(0,.39,0,.88,.06,.48,p.wood);box(-.18,.43,.02,.23,.035,.28,cream);box(-.18,.452,.02,.22,.012,.27,p.accent);height=.46;break;
 case 'nightstand_lamp':width=.48;depth=.46;height=1.05;box(0,.26,0,.46,.5,.44,p.wood);box(0,.33,.229,.38,.2,.012,p.wall);box(0,.33,.241,.13,.02,.018,p.metal,brass);cyl(0,.539,-.045,.21,.035,p.metal,brass);cyl(0,.705,-.045,.026,.32,p.metal,brass);cyl(0,.915,-.045,.3,.25,cream);depth=.51;break;
 case 'kitchen_counter':width=1.48;depth=.62;height=1.05;box(0,.455,0,1.46,.85,.6,p.wood);box(0,.905,0,1.48,.06,.62,cream);for(const x of[-.48,0,.48]){box(x,.48,.31,.455,.72,.025,p.wall);box(x,.72,.329,.21,.025,.019,p.metal,brass)}box(-.38,.941,0,.44,.014,.36,p.metal,{metalness:.45,roughness:.42});box(-.38,.95,0,.33,.012,.25,dark);cyl(-.38,.997,-.17,.035,.106,p.metal,brass);box(.36,.941,0,.45,.015,.43,dark);for(const x of[.24,.48])for(const z of[-.115,.115])cyl(x,.955,z,.145,.012,p.metal,brass);depth=.7;break;
 case 'refrigerator':width=.66;depth=.68;height=1.79;box(0,.895,0,.66,1.79,.63,p.wall);box(0,1.46,.325,.6,.54,.035,cream);box(0,.6,.325,.6,1.1,.035,cream);for(const y of[.99,1.3])box(-.235,y,.353,.033,.24,.035,p.metal,brass);depth=.76;break;
 case 'low_console':width=.98;depth=.41;height=.75;legs(.98,.36,.16);box(0,.42,0,.96,.51,.34,p.wood);for(const x of[-.23,.23]){box(x,.42,.181,.44,.41,.018,p.wall);box(x,.45,.195,.13,.018,.012,p.metal,brass)}box(0,.7,0,.98,.08,.36,p.wood);break;
 case 'rug':width=1.2;depth=.78;height=.022;box(0,.008,0,1.2,.016,.78,p.accent);box(0,.018,0,1.05,.008,.64,linen);break;
 default:throw Error('Unknown residential furniture '+kind);
 }
 return{kind,width,depth,height,parts};
}
function bounds(f){const c=Math.abs(Math.cos(f.yaw)),s=Math.abs(Math.sin(f.yaw)),w=f.width*c+f.depth*s,d=f.width*s+f.depth*c;return[f.x-w/2,f.z-d/2,f.x+w/2,f.z+d/2]}
const overlap=(a,b,gap=0)=>a[0]<b[2]+gap&&a[2]>b[0]-gap&&a[1]<b[3]+gap&&a[3]>b[1]-gap;

export function planResidentialRoom({assetId='',level=0,roomIndex=0,width,depth,seed=0}={}){
 if(!Number.isFinite(width)||!Number.isFinite(depth)||width<=0||depth<=0)throw Error('Residential room requires positive finite width/depth');
 const rng=random(hash(`${assetId}:${level}:${roomIndex}:${seed}`));
 const family=/tower|pavilion/.test(assetId)?'modern':/old_town/.test(assetId)?'oldtown':/walkup|apartment/.test(assetId)?'apartment':'cottage';
 const palette={...palettes[family][Math.floor(rng()*2)]};
 const role=level>0?['bedroom','study','bedroom','living'][Math.abs(roomIndex)%4]:['living','kitchen','study','bedroom'][Math.abs(roomIndex)%4];
 const names={bedroom:'Спальня',living:'Гостиная',kitchen:'Кухня и столовая',study:'Кабинет'};
 const finish={cottage:'limewash_with_timber_panels',oldtown:'muted_wallpaper_with_lower_wood_panels',modern:'warm_plaster_stone_accent',apartment:'painted_plaster_with_skirting'}[family];
 const floorFinish=family==='modern'?'limestone_tiles':family==='oldtown'?'herringbone_wood':family==='cottage'?'timber_planks':'wood_boards';
 const queue={bedroom:[width>=3?'bed':'single_bed','nightstand_lamp','wardrobe','bookcase','rug'],living:['sofa','armchair','coffee_table','bookcase','low_console','rug'],kitchen:['kitchen_counter','refrigerator','dining_table','chair','chair','low_console'],study:['desk','chair','bookcase','armchair','nightstand_lamp','rug']}[role];
 const furniture=[],wallGap=.09,usable=[-width/2+wallGap,-depth/2+wallGap,width/2-wallGap,depth/2-wallGap],doorAisle=[-.72,-.05,.72,depth/2];
 const place=f=>{
  const angles=[0,Math.PI/2,-Math.PI/2,Math.PI];
  const candidates=[];
  // Functional pairs first: desk chair faces its desk, bed lamp stays beside
  // the pillow, and a coffee table sits in front of the sofa when space permits.
  const near=(anchor,dx,dz,yaw=anchor.yaw)=>{const c=Math.cos(anchor.yaw),s=Math.sin(anchor.yaw);candidates.push({x:anchor.x+dx*c+dz*s,z:anchor.z-dx*s+dz*c,yaw})};
  if(f.kind==='chair'){const table=furniture.find(o=>o.kind==='desk'||o.kind==='dining_table');if(table){near(table,0,table.depth/2+f.depth/2+.22,table.yaw+Math.PI);if(table.kind==='dining_table')near(table,0,-table.depth/2-f.depth/2-.22,table.yaw)}}
  if(f.kind==='nightstand_lamp'){const bed=furniture.find(o=>/^(bed|single_bed)$/.test(o.kind));if(bed)for(const sign of[-1,1])near(bed,sign*(bed.width/2+f.width/2+.13),-bed.depth/2+f.depth/2+.16)}
  if(f.kind==='coffee_table'){const sofa=furniture.find(o=>o.kind==='sofa');if(sofa)near(sofa,0,sofa.depth/2+f.depth/2+.32)}
  const pairCount=candidates.length;
  for(const yaw of angles){const w=Math.abs(Math.cos(yaw))*f.width+Math.abs(Math.sin(yaw))*f.depth,d=Math.abs(Math.cos(yaw))*f.depth+Math.abs(Math.sin(yaw))*f.width;
   if(w>usable[2]-usable[0]||d>usable[3]-usable[1])continue;
   const xs=[usable[0]+w/2,usable[2]-w/2,0],zs=[usable[1]+d/2,usable[3]-d/2,-depth*.2];
   for(const z of zs)for(const x of xs)candidates.push({x,z,yaw});
  }
  // Seed changes the first furnished side without moving the entrance corridor.
  if(rng()>.5)for(const c of candidates.slice(pairCount))c.x=-c.x;
  for(const c of candidates){const placed={...f,...c},b=bounds(placed);if(b[0]<usable[0]-1e-6||b[2]>usable[2]+1e-6||b[1]<usable[1]-1e-6||b[3]>usable[3]+1e-6||overlap(b,doorAisle,.06))continue;if(furniture.some(other=>overlap(b,bounds(other),.13)))continue;furniture.push(placed);return true}return false;
 };
 for(const kind of queue){const f=recipe(kind,palette,rng);place(f)}
 if(!furniture.length)place(recipe('bookcase',palette,rng));
 if(!furniture.length&&width>=.75&&depth>=.85){const f=recipe('low_console',palette,rng);const factor=Math.min(1,(width-.22)/f.width);f.width*=factor;for(const p of f.parts){p.position[0]*=factor;p.size[0]*=factor}place(f)}
 return{name:names[role],finish,floorFinish,palette,furniture};
}


