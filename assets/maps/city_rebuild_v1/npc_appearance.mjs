// Stable appearance for independently cloned canonical NPC rigs. No roster or gameplay authority.
const SKIN=['#e7bb9b','#d7a17e','#bb805c','#9c6246','#704634','#edcbb0'];
const HAIR=['#242321','#493329','#76523a','#a06a3f','#b7a188','#777672','#d0c9bb','#763c2c'];
const SUITS=['#334851','#584541','#364f43','#68414b','#454559','#6b5a45','#42566c','#6c6570'];
export const NPC_HAIRSTYLES=Object.freeze(['short','slick','part','crop','bob','bun','curly','ponytail','bald','braids','undercut','wavy','crew']);
function randomFor(key){let state=2166136261;for(const c of String(key)){state^=c.charCodeAt(0);state=Math.imul(state,16777619)}return()=>{state+=0x6D2B79F5;let t=state;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296}}
export function describeNpcAppearance(id,overrides={}){
 if(id===undefined||id===null||String(id)==='')throw Error('NPC appearance needs existing stable id');
 const r=randomFor(id),pick=list=>list[Math.floor(r()*list.length)],sex=overrides.sex==='female'||overrides.sex==='f'?'female':overrides.sex==='male'||overrides.sex==='m'?'male':r()<.42?'female':'male';
 const role=overrides.role||'civilian',police=/police|cop|officer/i.test(role),boss=/boss|leader|unique_npc/i.test(role);
 const raw={id:String(id),sex,role,height:1.65+r()*.40,build:.94+r()*.12,skin:pick(SKIN),hairColor:pick(HAIR),hairstyle:pick(sex==='female'?['bob','bun','part','curly','ponytail','crop','braids','wavy','undercut']:['short','slick','part','crop','curly','bald','undercut','wavy','crew']),browStyle:Math.floor(r()*8),outfit:/medic|doctor|nurse/i.test(role)?'#dfdfd4':police?'#25394c':boss?pick(['#272833','#463338','#34413f']):pick(SUITS),shirt:police?'#b8c4c8':pick(['#e2d8c7','#d7c8b6','#b8c6be']),hat:police?'police':boss&&r()<.5?'fedora':'none'};
 const result={...raw,...overrides,id:String(id),sex};if(overrides.outfitColor)result.outfit=overrides.outfitColor;if(String(result.prisonGear||'').includes('helmet'))result.hat='helmet';if(/medic|doctor|nurse/i.test(role))result.medicalMark=true;if(typeof result.build==='string')result.build=({slim:.94,normal:1,heavy:1.07}[result.build])||1;result.height=Math.max(1.65,Math.min(2.05,Number.isFinite(result.height)?result.height:raw.height));result.build=Math.max(.93,Math.min(1.07,Number.isFinite(result.build)?result.build:raw.build));if(!NPC_HAIRSTYLES.includes(result.hairstyle))result.hairstyle=raw.hairstyle;
 return Object.freeze(result);
}
export function applyNpcAppearance({THREE,scene,descriptor,cloneTextures=false}){
 if(!THREE||!scene||!descriptor)throw Error('THREE, independently cloned scene and descriptor required');
 if(scene.userData.npcAppearance)throw Error('NPC appearance already applied; apply once before hero normalization');
 scene.updateMatrixWorld(true);const bones={},nodes=[];scene.traverse(o=>{if(o.isBone)bones[o.name]=o;if(o.isMesh)nodes.push(o)});if(!bones.head)throw Error('Canonical head bone required');
 const ownedGeometry=new Set(),ownedMaterial=new Set(),ownedTextures=new Set(),textureCopies=new Map();
 const suitBase=new THREE.Color(descriptor.sex==='female'?'#644467':'#722D38'),skinBase=new THREE.Color(descriptor.sex==='female'?'#E6B598':'#D7A17E'),skinTarget=new THREE.Color(descriptor.skin),outfitTarget=new THREE.Color(descriptor.outfit),shirtTarget=new THREE.Color(descriptor.shirt),trousersBase=new THREE.Color('#28323c');
 const originMatrix=scene.matrixWorld.clone(),inverseScene=originMatrix.clone().invert(),v=new THREE.Vector3(),color=new THREE.Color(),artAccent=new THREE.Color(descriptor.accent||descriptor.outfit),hsl={};
 for(const mesh of nodes){
 
  if(['hair','headwear'].includes(mesh.userData.creator_module)){mesh.removeFromParent();continue}
  const cloneMaterial=m=>{const n=m.clone();ownedMaterial.add(n);if(cloneTextures)for(const [key,value]of Object.entries(n))if(value?.isTexture){if(!textureCopies.has(value)){const copy=value.clone();textureCopies.set(value,copy);ownedTextures.add(copy);}n[key]=textureCopies.get(value);}return n};mesh.material=Array.isArray(mesh.material)?mesh.material.map(cloneMaterial):cloneMaterial(mesh.material);

  const geometry=mesh.geometry.clone();ownedGeometry.add(geometry);mesh.geometry=geometry;
  const p=geometry.attributes.position,c=geometry.attributes.color,si=geometry.attributes.skinIndex,sw=geometry.attributes.skinWeight,isFabric=/FABRIC/.test(mesh.name),isSkin=/SKIN/.test(mesh.name),isHair=/HAIR/.test(mesh.name),brow=isHair?new Uint8Array(p.count):null;
  const localToSource=mesh.matrixWorld.clone().premultiply(inverseScene),sourceToLocal=localToSource.clone().invert();
  for(let i=0;i<p.count;i++){
   v.fromBufferAttribute(p,i).applyMatrix4(localToSource);let headWeight=0,torsoWeight=0;
   if(si&&sw)for(let j=0;j<4;j++){const name=mesh.skeleton.bones[si.getComponent(i,j)]?.name,w=sw.getComponent(i,j);if(name==='head')headWeight+=w;if(['chest','spine_01','pelvis'].includes(name))torsoWeight+=w}
   // Existing brows are merged with shoes/irises; remove only their authored head region.
   if(brow)brow[i]=headWeight>.9&&v.y>4.405&&v.y<4.56&&v.z>.40&&Math.abs(v.x)<.43;
   if(c){color.setRGB(c.getX(i),c.getY(i),c.getZ(i));color.getHSL(hsl);const luminance=(color.r+color.g+color.b)/3;
    if(isSkin&&hsl.s>.15&&color.r>color.g*1.06){
     // Skin/lid tones scale together; preserve eye whites, glints and lips.
     const ratio=color.r/Math.max(.01,skinBase.r),matches=Math.abs(color.g/Math.max(.01,skinBase.g)-ratio)<.13&&Math.abs(color.b/Math.max(.01,skinBase.b)-ratio)<.16;
     if(matches)color.copy(skinTarget).multiplyScalar(Math.max(.60,Math.min(1.08,ratio)));
    }
    if(isFabric){const ratio=color.r/Math.max(.01,suitBase.r),suitMatch=Math.abs(color.g/Math.max(.01,suitBase.g)-ratio)<.18&&Math.abs(color.b/Math.max(.01,suitBase.b)-ratio)<.18;if(suitMatch){color.copy(outfitTarget).multiplyScalar(Math.max(.5,Math.min(1.15,ratio)))}else if(descriptor.trousers&&luminance<.15&&color.b>color.r*1.4&&color.g>color.r*1.1){const strength=color.g/trousersBase.g;color.set(descriptor.trousers).multiplyScalar(Math.max(.65,Math.min(1.5,strength)))}else if(luminance>.38){color.copy(shirtTarget).multiplyScalar(Math.min(1.1,luminance/.64))}}
    if(isFabric&&descriptor.wardrobe&&v.y>1.72&&v.y<3.32&&hsl.s>.12){
     const wardrobe=descriptor.wardrobe,front=v.z>.15;
     if(wardrobe==='pinstripe'&&front)color.lerp(artAccent,.10+.12*Math.cos(v.x*14));
     if(wardrobe==='colorblock'&&(v.x<-.40||v.y>2.93))color.set(v.x<-.40?descriptor.accent:descriptor.shirt);
     if(wardrobe==='brocade'&&front)color.lerp(artAccent,.13+.15*Math.sin(v.x*7+v.y*5)*Math.cos(v.y*7-v.x*5));
     if(wardrobe==='doublebreasted'&&front&&Math.abs(v.x)<.26)color.multiplyScalar(.70);
     if(wardrobe==='leather')color.multiplyScalar(.82);
    }
    c.setXYZ(i,color.r,color.g,color.b);
   }
   // Change only torso surface girth; bind skeleton and weapon sockets remain identical.
   let changed=false;
   if(isFabric&&torsoWeight>.35){const weight=Math.min(1,(torsoWeight-.35)/.65),taper=Math.max(0,1-Math.abs(v.y-2.22)/.9),factor=1+(descriptor.build-1)*weight*taper;v.x*=factor;v.z*=factor;changed=true;}
   if(descriptor.bodyShape&&torsoWeight>.05){
    const belly=descriptor.belly||0,waist=Math.exp(-Math.pow((v.y-2.12)/.48,2)),shoulder=Math.exp(-Math.pow((v.y-3.05)/.35,2)),weight=Math.min(1,torsoWeight*1.3);
    const girth=({heavy:.35,stocky:.17,pear:.24,slim:-.10,athletic:.02})[descriptor.bodyShape]||0;
    v.x*=1+weight*(girth*waist+((descriptor.shoulderWidth||1)-1)*shoulder);
    v.z+=weight*waist*belly*(v.z>=0?.43:-.12);changed=true;
   }
   if(descriptor.faceWidth&&headWeight>.5){
    const cheeks=Math.exp(-Math.pow((v.y-4.18)/.24,2)),jaw=Math.exp(-Math.pow((v.y-3.91)/.20,2));
    v.x*=descriptor.faceWidth+(descriptor.jawWidth-1)*jaw+(descriptor.cheekFullness||0)*.13*cheeks;
    if(v.z>0)v.z+=(descriptor.cheekFullness||0)*.075*cheeks;
    if(descriptor.eyeShape&&v.z>.38&&v.y>4.31&&v.y<4.51){const eyeY=4.395,blend=Math.max(0,1-Math.abs(v.y-eyeY)/.115);v.y+=(eyeY-v.y)*(descriptor.eyeShape==='almond'?.15:descriptor.eyeShape==='round'?-.09:0)*blend;}
    changed=true;
   }
   if(changed){v.applyMatrix4(sourceToLocal);p.setXYZ(i,v.x,v.y,v.z);}
  }
  if(isHair){const old=geometry.index?.array||Array.from({length:p.count},(_,i)=>i),indices=[];for(let i=0;i<old.length;i+=3)if(!brow[old[i]]&&!brow[old[i+1]]&&!brow[old[i+2]])indices.push(old[i],old[i+1],old[i+2]);geometry.setIndex(indices)}
  if(c)c.needsUpdate=true;p.needsUpdate=true;geometry.computeVertexNormals();geometry.computeBoundingBox();geometry.computeBoundingSphere();
 }
 const group=new THREE.Group();group.name='npc_appearance_'+descriptor.id;group.userData.creator_module='npc_appearance';group.matrixAutoUpdate=false;group.matrix.copy(bones.head.matrixWorld).invert().multiply(originMatrix);bones.head.add(group);
 const material=(value,roughness=.75,metalness=0)=>{const m=new THREE.MeshStandardMaterial({color:value,roughness,metalness});ownedMaterial.add(m);return m};
 const hair=material(descriptor.hairColor),outfit=material(descriptor.outfit),black=material('#23272a'),gold=material('#b99c55',.35,.65);
 const add=(name,g,m,x,y,z,sx=1,sy=1,sz=1)=>{ownedGeometry.add(g);const o=new THREE.Mesh(g,m);o.name=name;o.position.set(x,y,z);o.scale.set(sx,sy,sz);o.castShadow=o.receiveShadow=true;o.userData.npcAppearance=true;group.add(o);return o};
 const oval=(name,x,y,z,sx,sy,sz,m=hair)=>add(name,new THREE.SphereGeometry(1,12,8),m,x,y,z,sx,sy,sz);
 const style=descriptor.hairstyle,rx=descriptor.sex==='female'?.56:.61;
 if(style!=='bald'){
  const positions=[],indices=[],rings=9,segments=24;
  for(let row=0;row<=rings;row++)for(let i=0;i<=segments;i++){const phi=i/segments*Math.PI*2,front=Math.max(0,Math.cos(phi)),limit=1.80-front*.68,theta=row/rings*limit;positions.push(Math.sin(phi)*rx*Math.sin(theta),4.22+(.69+(style==='curly'?.04:0))*Math.cos(theta),-.025+Math.cos(phi)*.54*Math.sin(theta))}
  for(let row=0;row<rings;row++)for(let i=0;i<segments;i++){const a=row*(segments+1)+i,b=a+segments+1;indices.push(a,b,a+1,b,b+1,a+1)}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setIndex(indices);g.computeVertexNormals();add('npc_hair_cap',g,hair,0,0,0);
 }
 if(style==='slick'||style==='part'){for(let i=0;i<4;i++){const o=oval('npc_combed_lock',-.30+i*.17,4.83-i*.015,.13,.14,.10,.36);o.rotation.z=style==='part'?-.22:.08}}
 if(style==='crop'){for(let i=0;i<4;i++)oval('npc_crop_fringe',-.30+i*.20,4.53,.47,.12,.10,.09)}
 if(style==='bob'){for(const sign of [-1,1])for(let i=0;i<3;i++)oval('npc_bob_lock',sign*(rx-.05),4.16-i*.08,-.12+i*.13,.11,.32,.18)}
 if(style==='crew'){for(let i=0;i<5;i++)oval('npc_crew_top',-.35+i*.175,4.86,.06,.10,.065,.31)}
 if(style==='wavy'){for(let i=0;i<5;i++){const o=oval('npc_wave',-.38+i*.19,4.79+Math.sin(i)*.04,.12,.17,.14,.34);o.rotation.z=.24*Math.sin(i)}}
 if(style==='undercut'){const o=oval('npc_undercut_crest',-.10,4.90,.05,.38,.18,.40);o.rotation.z=.18}
 if(style==='braids'){for(const sign of [-1,1])for(let i=0;i<4;i++)oval('npc_braid',sign*(.43+Math.sin(i)*.025),4.20-i*.17,-.43,.09,.125,.085)}
 if(style==='bun')oval('npc_bun',0,4.62,-.58,.27,.25,.23);
 if(style==='ponytail'){for(let i=0;i<3;i++)oval('npc_ponytail',0,4.46-i*.22,-.60-i*.045,.17-i*.028,.22,.18)}
 if(style==='curly'){for(let i=0;i<11;i++){const a=i*Math.PI*2/11;oval('npc_curl',Math.sin(a)*rx*.8,4.66+(i%3)*.055,Math.cos(a)*.41,.16,.17,.16)}}
 const eye=descriptor.sex==='female'?.23:.22,browStyle=Math.max(0,Math.min(7,descriptor.browStyle|0)),slant=[-.065,-.04,-.02,0,.02,.04,.06,.08][browStyle];
 for(const sign of [-1,1]){const pts=[new THREE.Vector3(sign*(eye-.13),4.45-slant,.487),new THREE.Vector3(sign*eye,4.477,.514),new THREE.Vector3(sign*(eye+.13),4.45+slant,.456)],curve=new THREE.CatmullRomCurve3(pts);add('npc_brow_'+sign,new THREE.TubeGeometry(curve,8,.015+(browStyle%4)*.005,5,false),hair,0,0,0)}
 if(descriptor.hat==='helmet'){oval('npc_tactical_helmet',0,4.78,-.03,.65,.27,.58,black);for(const sign of [-1,1])oval('npc_helmet_ear',sign*.58,4.50,-.02,.08,.17,.17,black);if(String(descriptor.prisonGear).includes('riot')){const glass=material('#abc4c7',.20,.05);glass.transparent=true;glass.opacity=.25;oval('npc_riot_visor',0,4.49,.56,.49,.19,.055,glass)}}
 if(descriptor.hat==='police'){oval('npc_police_cap',0,4.86,-.025,.64,.18,.56,outfit);oval('npc_police_visor',0,4.76,.45,.45,.045,.28,black);oval('npc_cap_badge',0,4.90,.525,.065,.075,.02,gold)}
 if(descriptor.hat==='fedora'){oval('npc_fedora_brim',0,4.84,0,.75,.065,.64,black);oval('npc_fedora_crown',0,5.00,-.015,.51,.25,.43,outfit)}
 if(/police|cop|officer/i.test(descriptor.role)){
  // Badge is attached to chest, in source coordinates, and follows recoil/swimming.
  const badge=oval('npc_chest_badge',-.27,2.98,.48,.075,.095,.018,gold);badge.updateMatrix();const sourceTransform=badge.matrix.clone();group.remove(badge);bones.chest.add(badge);badge.matrixAutoUpdate=false;badge.matrix.copy(bones.chest.matrixWorld).invert().multiply(originMatrix).multiply(sourceTransform);
 }
 const attach=(mesh,name)=>{mesh.updateMatrix();const local=mesh.matrix.clone();group.remove(mesh);bones[name].add(mesh);mesh.matrixAutoUpdate=false;mesh.matrix.copy(bones[name].matrixWorld).invert().multiply(originMatrix).multiply(local);return mesh};
 if(descriptor.facialHair&&descriptor.facialHair!=='none'){
  for(const sign of [-1,1]){const m=oval('npc_moustache_'+sign,sign*.095,4.065,.575,.125,.042,.038);m.rotation.z=sign*.12;}
  if(descriptor.facialHair==='goatee')oval('npc_goatee',0,3.91,.48,.15,.12,.065);
  if(descriptor.facialHair==='beard'){
   oval('npc_beard_chin',0,3.89,.37,.32,.14,.18);
   for(const sign of [-1,1]){const m=oval('npc_beard_cheek_'+sign,sign*.34,4.015,.31,.115,.24,.16);m.rotation.z=sign*-.24;}
  }
 }
 const accentMaterial=material(descriptor.accent||'#c7aa69',.48,.12);
 if(descriptor.accessory==='glasses'){
  const lens=material('#304652',.25,.15);lens.transparent=true;lens.opacity=.68;
  for(const sign of [-1,1]){const x=sign*.23*(descriptor.faceWidth||1);add('npc_glasses_frame_'+sign,new THREE.TorusGeometry(.135,.018,6,18),gold,x,4.39,.565);oval('npc_glasses_lens_'+sign,x,4.39,.565,.121,.116,.012,lens);}
  oval('npc_glasses_bridge',0,4.41,.58,.105,.018,.018,gold);
 }
 if(descriptor.accessory==='earrings')for(const sign of [-1,1])add('npc_earring_'+sign,new THREE.TorusGeometry(.086,.017,6,16),gold,sign*.59,4.11,-.01);
 if(descriptor.accessory==='bowtie'){for(const sign of [-1,1])attach(oval('npc_bowtie_'+sign,sign*.105,3.20,.52,.12,.075,.04,accentMaterial),'chest');attach(oval('npc_bowtie_knot',0,3.20,.555,.045,.048,.032,black),'chest');}
 if(descriptor.accessory==='scarf'){
  attach(oval('npc_scarf_collar',0,3.28,.10,.36,.09,.36,accentMaterial),'chest');
  for(const sign of [-1,1]){const scarf=oval('npc_scarf_tail_'+sign,sign*.19,2.94,.54,.095,.29,.042,accentMaterial);scarf.rotation.z=sign*.13;attach(scarf,'chest');}
 }
 if(descriptor.accessory==='chain'){
  const curve=new THREE.CatmullRomCurve3([new THREE.Vector3(-.24,3.28,.33),new THREE.Vector3(-.15,2.96,.57),new THREE.Vector3(0,2.87,.60),new THREE.Vector3(.15,2.96,.57),new THREE.Vector3(.24,3.28,.33)]);
  attach(add('npc_neck_chain',new THREE.TubeGeometry(curve,18,.021,5,false),gold,0,0,0),'chest');
  attach(oval('npc_chain_medallion',0,2.85,.62,.063,.085,.024,gold),'chest');
 }
 if(descriptor.wardrobe==='doublebreasted')for(const sign of [-1,1])for(let i=0;i<3;i++){
  const y=2.95-i*.22,z=.51+(descriptor.belly||0)*.43*Math.exp(-Math.pow((y-2.12)/.48,2));
  attach(oval('npc_jacket_button_'+sign+'_'+i,sign*.20,y,z,.032,.032,.018,gold),'chest');
 }
 // Seat the separate top locks and hats onto the cap instead of above it.
 if(descriptor.bodyShape)for(const mesh of group.children){
  if(/^npc_fedora_/.test(mesh.name))mesh.position.y-=.10;
  if(/^npc_(combed_lock|crew_top|undercut_crest|wave)$/.test(mesh.name))mesh.position.y-=.09;
 }
 if(descriptor.accent)attach(oval('npc_boss_accent',-.25,3.09,.51,.055,.075,.022,material(descriptor.accent,.42,.35)),'chest');
 if(descriptor.medicalMark){const mark=material('#25806b');attach(oval('npc_medical_patch',-.29,3.02,.51,.10,.105,.02,material('#eee9dc')),'chest');attach(oval('npc_medical_cross_v',-.29,3.02,.536,.021,.073,.012,mark),'chest');attach(oval('npc_medical_cross_h',-.29,3.02,.538,.07,.022,.012,mark),'chest');}
 if(descriptor.shield){attach(oval('npc_riot_shield',-.99,2.27,.36,.34,.54,.055,material('#293c48',.5,.35)),'forearm_l');attach(oval('npc_shield_emblem',-.99,2.38,.42,.065,.09,.014,gold),'forearm_l');}
 scene.userData.npcAppearance={...descriptor};scene.updateMatrixWorld(true);let disposed=false;
 return {descriptor,scene,dispose(){if(disposed)return;disposed=true;for(const m of ownedMaterial)m.dispose();for(const t of ownedTextures)t.dispose();for(const g of ownedGeometry)g.dispose();const remove=[];scene.traverse(o=>{if(o.userData.npcAppearance)remove.push(o)});for(const o of remove)o.removeFromParent();group.removeFromParent();delete scene.userData.npcAppearance}};
}




