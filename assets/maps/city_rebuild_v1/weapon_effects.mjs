// Bounded cosmetic effects for the isolated preview. The host remains the sole
// authority for ammo, damage, hit admission and ownership.
const DEFAULT_LIMITS=Object.freeze({projectiles:112,casings:48,flashes:24,impacts:48,marks:72,explosions:6,pendingCasings:48});

export function resolveWeaponShotTransforms(THREE,weaponModel){
 if(!THREE?.Vector3||!weaponModel?.localToWorld||!Array.isArray(weaponModel.userData?.muzzle))throw Error('Mounted weapon with muzzle metadata required');
 weaponModel.updateWorldMatrix?.(true,true);
 const origin=weaponModel.localToWorld(new THREE.Vector3().fromArray(weaponModel.userData.muzzle));
 const ejectionOrigin=Array.isArray(weaponModel.userData.ejectionPort)?weaponModel.localToWorld(new THREE.Vector3().fromArray(weaponModel.userData.ejectionPort)):origin.clone();
 const direction=new THREE.Vector3(0,0,1).transformDirection(weaponModel.matrixWorld);
 return {origin,ejectionOrigin,direction};
}

// Prefer authored surface metadata; material/name inference is cosmetic only.
export function classifyImpactSurface(object){
 const materials=Array.isArray(object?.material)?object.material:[object?.material];
 let tagged='';for(let node=object;node&&!tagged;node=node.parent)tagged=String(node.userData?.impactSurface||node.userData?.surfaceType||'').toLowerCase();
 if(tagged){if(/glass|window/.test(tagged))return 'glass';if(/metal|steel|iron/.test(tagged))return 'metal';if(/wood|timber|plank/.test(tagged))return 'wood';if(/soft|cloth|fabric|skin|flesh/.test(tagged))return 'soft';if(/masonry|stone|brick|concrete/.test(tagged))return 'masonry'}
 const label=tagged||String(object?.name||'').toLowerCase();
 if(/glass|window/.test(label)||materials.some(m=>(m?.transmission||0)>.2))return 'glass';
 if(/metal|steel|iron|car_body/.test(label)||materials.some(m=>(m?.metalness||0)>.55))return 'metal';
 if(/wood|timber|plank/.test(label))return 'wood';
 if(/soft|cloth|fabric|skin|flesh/.test(label))return 'soft';
 return 'masonry';
}

export function createWeaponEffects(THREE,scene,options={}){
 if(!THREE?.Group||!scene?.add)throw Error('THREE host and scene required');
 const limits={...DEFAULT_LIMITS,...(options.limits||{})},worldScale=Math.max(.01,+options.worldScale||4.1),groundY=Number.isFinite(options.groundY)?options.groundY:.035;
 const ray=new THREE.Raycaster(),up=new THREE.Vector3(0,1,0),forwardAxis=new THREE.Vector3(0,0,1),right=new THREE.Vector3(),shotDirection=new THREE.Vector3(),normalMatrix=new THREE.Matrix3(),worldNormal=new THREE.Vector3();
 const projectilePool=[],casingPool=[],flashPool=[],impactPool=[],markPool=[],explosionPool=[],pending=[];
 let projectileCursor=0,casingCursor=0,flashCursor=0,impactCursor=0,markCursor=0,explosionCursor=0,totalShots=0,totalCases=0,totalImpacts=0,totalProjectiles=0,totalMarks=0,totalExplosions=0,elapsed=0,disposed=false;

 const projectileMaterial=()=>new THREE.MeshStandardMaterial({color:0xcaa36a,metalness:.78,roughness:.28});
 for(let i=0;i<limits.projectiles;i++){
  // A projectile is a small solid slug with a narrow motion streak. There is
  // deliberately no billboard, additive sphere or aura around it.
  const root=new THREE.Group(),core=new THREE.Mesh(new THREE.CylinderGeometry(.5,.5,1,8),projectileMaterial()),nose=new THREE.Mesh(new THREE.ConeGeometry(.5,1,8),projectileMaterial()),trail=new THREE.Mesh(new THREE.CylinderGeometry(.5,.3,1,6),new THREE.MeshBasicMaterial({color:0xc69b5b,transparent:true,opacity:.34,depthWrite:false,toneMapped:true}));
  const jacket=new THREE.Mesh(new THREE.CylinderGeometry(.5,.5,1,10),new THREE.MeshStandardMaterial({color:0x85633c,metalness:.86,roughness:.23})),fins=[];
  root.name='projectile';core.name='projectile-core';nose.name='projectile-nose';trail.name='projectile-motion-streak';jacket.name='projectile-jacket-band';core.rotation.x=nose.rotation.x=trail.rotation.x=jacket.rotation.x=Math.PI/2;root.add(core,nose,trail,jacket);
  for(let n=0;n<2;n++){const fin=new THREE.Mesh(new THREE.BoxGeometry(1,.05,1),new THREE.MeshStandardMaterial({color:0x333e28,metalness:.45,roughness:.55}));fin.name='rocket-stabilizer-fin';fin.rotation.z=n*Math.PI/2;fin.visible=false;root.add(fin);fins.push(fin)}
  root.visible=false;scene.add(root);projectilePool.push({root,core,nose,trail,jacket,fins,active:false,direction:new THREE.Vector3(),speed:0,remaining:0,obstacles:[],explosive:false,visualId:'',weaponId:'',shotId:'',damage:null});
 }
 const brass=new THREE.MeshStandardMaterial({color:0xd6a348,metalness:.82,roughness:.24}),primerMetal=new THREE.MeshStandardMaterial({color:0x827566,metalness:.85,roughness:.35});
 for(let i=0;i<limits.casings;i++){
  const mesh=new THREE.Group();mesh.name='spent-casing';
  const body=new THREE.Mesh(new THREE.CylinderGeometry(.023,.023,.073,10,1,true),brass.clone()),rim=new THREE.Mesh(new THREE.CylinderGeometry(.026,.026,.008,12),brass),primer=new THREE.Mesh(new THREE.CylinderGeometry(.008,.008,.002,8),primerMetal),mouth=new THREE.Mesh(new THREE.TorusGeometry(.021,.002,4,12),brass),neck=new THREE.Mesh(new THREE.CylinderGeometry(.014,.023,.018,10,1,true),brass);
  body.name='casing-hollow-body';rim.name='casing-extractor-rim';primer.name='casing-spent-primer';mouth.name='casing-open-mouth';neck.name='casing-rifle-shoulder';rim.position.y=-.039;primer.position.y=-.044;mouth.rotation.x=Math.PI/2;mouth.position.y=.037;neck.position.y=.039;neck.visible=false;mesh.add(body,rim,primer,mouth,neck);
  for(const part of mesh.children){part.castShadow=true;part.receiveShadow=true}mesh.visible=false;scene.add(mesh);casingPool.push({mesh,body,mouth,neck,active:false,life:0,velocity:new THREE.Vector3(),spin:new THREE.Vector3(),settled:false,bounces:0,kind:'brass',floor:groundY});
 }
 for(let i=0;i<limits.flashes;i++){
  const root=new THREE.Group(),core=new THREE.Mesh(new THREE.IcosahedronGeometry(.065,0),new THREE.MeshBasicMaterial({color:0xfff0b0,toneMapped:false,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false})),cone=new THREE.Mesh(new THREE.ConeGeometry(.075,.36,6),new THREE.MeshBasicMaterial({color:0xff9c36,toneMapped:false,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false}));root.name='muzzle-flash';core.name='muzzle-hot-core';cone.name='muzzle-forward-flame';cone.rotation.x=Math.PI/2;cone.position.z=.17;core.scale.set(.75,.75,1.5);root.add(core,cone);
  const tongues=[];for(let n=0;n<3;n++){const tongue=new THREE.Mesh(new THREE.ConeGeometry(.045,.21,4),cone.material);tongue.name='muzzle-pressure-petal';root.add(tongue);tongues.push(tongue)}
  root.visible=false;scene.add(root);flashPool.push({root,core,cone,tongues,active:false,life:0,maxLife:0,strength:1,seed:0});
 }
 for(let i=0;i<limits.impacts;i++){
  const mesh=new THREE.Mesh(new THREE.IcosahedronGeometry(.1,1),new THREE.MeshBasicMaterial({color:0xffc36a,transparent:true,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));mesh.visible=false;scene.add(mesh);const chips=[];for(let n=0;n<5;n++){const chip=new THREE.Mesh(new THREE.TetrahedronGeometry(.012,0),new THREE.MeshStandardMaterial({color:0xbca583,transparent:true,depthWrite:false,roughness:.8,metalness:0}));chip.name='impact-debris';mesh.add(chip);chips.push(chip)}
  const dust=new THREE.Mesh(new THREE.IcosahedronGeometry(.035,1),new THREE.MeshBasicMaterial({color:0x8b8170,transparent:true,opacity:0,depthWrite:false}));dust.name='impact-surface-dust';mesh.add(dust);impactPool.push({mesh,chips,dust,active:false,life:0,maxLife:0,surface:'masonry',seed:0});
 }
 for(let i=0;i<limits.marks;i++){
  const mesh=new THREE.Mesh(new THREE.CircleGeometry(.035,7),new THREE.MeshBasicMaterial({color:0x171411,transparent:true,opacity:.84,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-4,polygonOffsetUnits:-4,side:THREE.DoubleSide,toneMapped:true}));// Separate recessed centre from a rough chipped edge, still one pooled mark.
  const edge=new THREE.Mesh(new THREE.RingGeometry(.025,.035,9),new THREE.MeshBasicMaterial({color:0x807566,transparent:true,opacity:.7,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3,side:THREE.DoubleSide}));edge.name='impact-chipped-edge';edge.position.z=.0005;mesh.add(edge);
  const center=new THREE.Mesh(new THREE.CircleGeometry(.020,9),new THREE.MeshBasicMaterial({color:0x070706,transparent:true,opacity:.9,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-5,polygonOffsetUnits:-5,side:THREE.DoubleSide}));center.name='impact-recess';center.position.z=.001;mesh.add(center);
  const crackVertices=[];for(let n=0;n<7;n++){const a=n*2.399963,r=.047+(n%3)*.012;crackVertices.push(Math.cos(a)*.016,Math.sin(a)*.016,.0015,Math.cos(a+.12)*r,Math.sin(a+.12)*r,.0015)}
  const crackGeometry=new THREE.BufferGeometry();crackGeometry.setAttribute('position',new THREE.Float32BufferAttribute(crackVertices,3));const cracks=new THREE.LineSegments(crackGeometry,new THREE.LineBasicMaterial({color:0xc3d7d9,transparent:true,opacity:.65,depthWrite:false}));cracks.name='impact-glass-radial-cracks';cracks.visible=false;mesh.add(cracks);
  mesh.raycast=()=>{};for(const child of mesh.children)child.raycast=()=>{};mesh.name='impact-chip';mesh.visible=false;mesh.renderOrder=28;scene.add(mesh);markPool.push({mesh,active:false,life:0,maxLife:0,expiresAt:0,parent:null,normal:new THREE.Vector3(),kind:'',size:0});
 }
 for(let i=0;i<limits.explosions;i++){
  const root=new THREE.Group();
  const core=new THREE.Mesh(new THREE.IcosahedronGeometry(.36,1),new THREE.MeshBasicMaterial({color:0xff9b25,transparent:true,opacity:.96,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));root.add(core);
  const fire=[];for(let n=0;n<8;n++){const flame=new THREE.Mesh(new THREE.ConeGeometry(.12,.7,7),new THREE.MeshBasicMaterial({color:n%3?0xff7318:0xffd35b,transparent:true,opacity:.9,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));root.add(flame);fire.push(flame)}
  const smoke=[];for(let n=0;n<6;n++){const puff=new THREE.Mesh(new THREE.DodecahedronGeometry(.2,0),new THREE.MeshBasicMaterial({color:n%2?0x292725:0x443e39,transparent:true,opacity:.62,depthWrite:false}));root.add(puff);smoke.push(puff)}
  const embers=[];for(let n=0;n<12;n++){const ember=new THREE.Mesh(new THREE.TetrahedronGeometry(.035,0),new THREE.MeshBasicMaterial({color:n%3?0xff7a1b:0xffe49a,toneMapped:false}));root.add(ember);embers.push(ember)}
  const shock=new THREE.Mesh(new THREE.TorusGeometry(.42,.026,6,24),new THREE.MeshBasicMaterial({color:0xffa336,transparent:true,opacity:.8,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));shock.rotation.x=Math.PI/2;root.add(shock);
  root.visible=false;scene.add(root);explosionPool.push({root,core,fire,smoke,embers,shock,active:false,life:0,maxLife:0,seed:i*.73,fireAngles:new Float64Array(fire.length),fireCos:new Float64Array(fire.length),fireSin:new Float64Array(fire.length),smokeCos:new Float64Array(smoke.length),smokeSin:new Float64Array(smoke.length),emberCos:new Float64Array(embers.length),emberSin:new Float64Array(embers.length)});
 }
 // Counts change only at activation/expiry, including reuse of an occupied
 // ring slot. Preserve pool iteration order for projectile hit callbacks.
 const poolCounts=new Map();let activeEffects=0;
 for(const pool of [projectilePool,casingPool,flashPool,impactPool,markPool,explosionPool]){
  const count={active:0};poolCounts.set(pool,count);for(const entry of pool)entry.poolCount=count;
 }
 const activate=entry=>{if(!entry.active){entry.active=true;entry.poolCount.active++;activeEffects++}return entry};
 const take=(pool,cursorName)=>{const cursor=cursorName==='projectile'?projectileCursor++:cursorName==='casing'?casingCursor++:cursorName==='flash'?flashCursor++:cursorName==='impact'?impactCursor++:markCursor++;return activate(pool[cursor%pool.length])};
 const hide=entry=>{if(entry.active){entry.active=false;entry.poolCount.active--;activeEffects--}(entry.root||entry.mesh).visible=false};
 const colorize=(material,color)=>{material.color.set(color);if(material.emissive)material.emissive.set(color).multiplyScalar(.34)};
 const flash=(origin,direction,kind)=>{const entry=take(flashPool,'flash');entry.life=entry.maxLife=kind==='pellet'?.07:.052;entry.strength=kind==='rocket'?1.8:kind==='pellet'?1.25:kind==='rifle'?.9:.65;entry.seed=totalShots*2.399963;entry.root.visible=true;entry.root.position.copy(origin);entry.root.quaternion.setFromUnitVectors(forwardAxis,direction);entry.root.scale.setScalar(entry.strength);colorize(entry.core.material,0xfff4cf);colorize(entry.cone.material,0xffa241);entry.core.material.opacity=1;entry.cone.material.opacity=.8;
  for(let n=0;n<entry.tongues.length;n++){const petal=entry.tongues[n],a=entry.seed+n*Math.PI*2/3;petal.position.set(Math.cos(a)*.065,Math.sin(a)*.065,.095);petal.quaternion.setFromUnitVectors(up,new THREE.Vector3(Math.cos(a)*.55,Math.sin(a)*.55,1).normalize());petal.scale.set(1,.78+(n%2)*.3,.45)}
 };
 const spawnImpact=(hit,direction)=>{const entry=take(impactPool,'impact'),surface=classifyImpactSurface(hit.object),metal=surface==='metal',glass=surface==='glass';entry.surface=surface;entry.seed=totalImpacts*1.618;entry.life=entry.maxLife=metal?.22:glass?.40:.46;entry.mesh.visible=true;entry.mesh.position.copy(hit.point);entry.mesh.quaternion.setFromUnitVectors(forwardAxis,impactNormal(hit,direction));entry.mesh.scale.setScalar(1);entry.mesh.material.color.set(metal?0xffd789:surface==='wood'?0x8b6a43:glass?0x9db4bb:0xaaa18f);entry.mesh.material.blending=metal?THREE.AdditiveBlending:THREE.NormalBlending;entry.mesh.material.opacity=0;entry.mesh.material.visible=false;
  entry.dust.visible=surface==='masonry'||surface==='wood';entry.dust.scale.setScalar(.3);entry.dust.position.set(0,0,.025);entry.dust.material.opacity=0;entry.dust.material.color.copy(entry.mesh.material.color);
  for(const chip of entry.chips){chip.material.color.copy(entry.mesh.material.color);chip.material.emissive.copy(entry.mesh.material.color).multiplyScalar(metal?.9:0);chip.material.roughness=glass?.12:metal?.25:.85;chip.material.metalness=metal?.65:glass?.25:0;chip.material.blending=entry.mesh.material.blending;chip.material.opacity=metal?1:.8;chip.visible=surface!=='soft';chip.position.set(0,0,0)}totalImpacts++};

 const impactNormal=(hit,direction,target=new THREE.Vector3())=>{const object=hit?.object;if(hit?.face?.normal&&object){normalMatrix.getNormalMatrix(object.matrixWorld);return target.copy(hit.face.normal).applyMatrix3(normalMatrix).normalize()}return target.copy(direction).multiplyScalar(-1).normalize()};
 const markImpact=(hit,projectile)=>{
  if(!hit?.object||!hit.point)return;const entry=take(markPool,'mark'),object=hit.object,visual=projectile.visual||{},materials=Array.isArray(object.material)?object.material:[object.material],glass=classifyImpactSurface(object)==='glass',kind=projectile.explosive?'scorch':glass?'glass-chip':visual.kind==='pellet'?'pellet':'bullet';
  // Raycaster face normals are geometry-local. Convert to world space before
  // orienting the decal, then attach while preserving its world transform so a
  // door, vehicle or other moving hit mesh carries the mark with it.
  impactNormal(hit,projectile.direction,worldNormal);
  const size=projectile.explosive?1.65:visual.kind==='pellet'?.38:glass?.58:.72;
  entry.mesh.removeFromParent();scene.add(entry.mesh);entry.mesh.position.copy(hit.point).addScaledVector(worldNormal,.004);entry.mesh.quaternion.setFromUnitVectors(forwardAxis,worldNormal);entry.mesh.scale.setScalar(size);entry.mesh.rotation.z=((totalMarks*2.399963229728653)%6.283)-3.1415;entry.mesh.material.color.set(glass?0x29383c:projectile.explosive?0x100d0b:0x171411);entry.mesh.material.opacity=glass?.30:.84;const edge=entry.mesh.children[0],surface=classifyImpactSurface(object);edge.material.color.set(surface==='metal'?0x8c8f91:surface==='wood'?0x9d7951:glass?0x99bac2:0x928571);edge.material.opacity=.7;entry.mesh.children[1].material.opacity=glass?.22:.9;entry.mesh.children[2].visible=glass&&!projectile.explosive;entry.mesh.children[2].material.opacity=.65;entry.mesh.visible=true;entry.life=entry.maxLife=5;entry.expiresAt=elapsed+5;entry.parent=object;entry.normal.copy(worldNormal);entry.kind=kind;entry.size=.035*size;scene.updateMatrixWorld(true);object.attach?.(entry.mesh);totalMarks++;
 };
 const spawnExplosion=point=>{const entry=activate(explosionPool[explosionCursor++%explosionPool.length]);entry.life=entry.maxLife=1.25;entry.seed=explosionCursor*.618;
  for(let n=0;n<entry.fire.length;n++){const angle=n*2.399+entry.seed;entry.fireAngles[n]=angle;entry.fireCos[n]=Math.cos(angle);entry.fireSin[n]=Math.sin(angle)}
  for(let n=0;n<entry.smoke.length;n++){const angle=n*2.4+entry.seed;entry.smokeCos[n]=Math.cos(angle);entry.smokeSin[n]=Math.sin(angle)}
  for(let n=0;n<entry.embers.length;n++){const angle=n*2.17+entry.seed;entry.emberCos[n]=Math.cos(angle);entry.emberSin[n]=Math.sin(angle)}
  entry.root.visible=true;entry.root.position.copy(point);entry.root.scale.setScalar(1);entry.core.scale.setScalar(1);entry.core.material.opacity=.96;entry.shock.scale.setScalar(.3);entry.shock.material.opacity=.8;totalExplosions++};
 const eject=(origin,direction,casing,weaponId)=>{const entry=take(casingPool,'casing'),shell=['shotgun','sawn_off'].includes(weaponId),rifle=['ak74','m16','sniper'].includes(weaponId);entry.life=4.2;entry.kind=shell?'shotgun-shell':rifle?'rifle-brass':'pistol-brass';entry.settled=false;entry.bounces=0;entry.mesh.visible=true;entry.mesh.position.copy(origin);entry.mesh.rotation.set(.4,totalCases*1.7,.2);right.crossVectors(up,direction);if(right.lengthSq()<1e-8)right.set(1,0,0);else right.normalize();const velocity=casing?.velocity||{};entry.velocity.copy(right).multiplyScalar(Number.isFinite(velocity.right)?velocity.right:1.65+(totalCases%3)*.15).addScaledVector(up,Number.isFinite(velocity.up)?velocity.up:2.2).addScaledVector(direction,Number.isFinite(velocity.forward)?velocity.forward:-.4);entry.spin.set(13+(totalCases%4)*1.2,5+(totalCases%3)*2.1,9+(totalCases%5));entry.mesh.scale.set(shell?1.2:1,rifle?1.35:1,shell?1.2:1).multiplyScalar(casing?.scale||1);entry.body.material.color.set(shell?0x9e2c21:0xc89b48);entry.body.material.metalness=shell?.12:.82;entry.body.material.roughness=shell?.58:.25;entry.neck.visible=rifle;entry.mouth.position.y=rifle?.049:.037;entry.mouth.scale.setScalar(rifle?.65:1);totalCases++};
 const spawnProjectile=(projectile,shot,origin,direction,obstacles)=>{
  const entry=take(projectilePool,'projectile'),visual=projectile.visual||{},kind=visual.kind||'round',caliber=Math.max(.004,+visual.caliber||.007),length=Math.max(.03,+visual.length||.065),trailLength=Math.max(.03,+visual.trail||.08),color=visual.color||projectile.color||'#caa36a';
  entry.root.visible=true;entry.root.position.copy(origin).addScaledVector(direction,.045);entry.root.quaternion.setFromUnitVectors(forwardAxis,direction);entry.direction.copy(direction);entry.speed=Math.max(.1,+projectile.speed||20)*worldScale;entry.remaining=Math.max(.2,+projectile.range||8)*worldScale;entry.obstacles=typeof obstacles==='function'?obstacles:Array.isArray(obstacles)?obstacles:[];entry.explosive=!!projectile.explosive;entry.visual=visual;entry.visualId=String(projectile.visualId||kind);entry.weaponId=String(shot?.weaponId||projectile.visualId||'');entry.shotId=String(shot?.shotId||`${entry.weaponId}:${shot?.sequence??''}`);entry.damage=Number.isFinite(shot?.damage)?shot.damage:null;entry.core.scale.set(caliber*2,length,caliber*2);entry.core.position.z=0;entry.nose.visible=kind!=='pellet';entry.nose.scale.set(caliber*(kind==='rocket'?2.1:1.35),length*(kind==='rocket'?.45:.22),caliber*(kind==='rocket'?2.1:1.35));entry.nose.position.z=length*.58;entry.trail.scale.set(Math.max(.003,caliber*.24),trailLength,Math.max(.003,caliber*.24));entry.trail.position.z=-trailLength*.52-length*.42;entry.trail.visible=trailLength>0;entry.trail.material.opacity=kind==='rocket'?.48:kind==='pellet'?.28:.52;colorize(entry.core.material,color);colorize(entry.nose.material,color);colorize(entry.trail.material,kind==='rocket'?0xcf9752:0xe8cc91);
  entry.jacket.visible=kind!=='pellet';entry.jacket.scale.set(caliber*2.07,length*.08,caliber*2.07);entry.jacket.position.z=-length*.33;
  for(const fin of entry.fins){fin.visible=kind==='rocket';fin.scale.set(caliber*4.5,caliber*1.5,length*.3);fin.position.z=-length*.35}totalProjectiles++;
 };
 function shoot(shot,origin,aimPoint,obstacles=[],shotOptions={}){
  if(disposed||!shot?.projectiles?.length)return false;const muzzle=origin?.isVector3?origin:origin?.origin,ejectionOrigin=shotOptions.ejectionOrigin||origin?.ejectionOrigin||muzzle;
  if(!muzzle?.isVector3||!aimPoint?.isVector3)throw Error('Shot origin and aim point must be THREE.Vector3');const direction=aimPoint.clone().sub(muzzle);if(direction.lengthSq()<1e-8)return false;direction.normalize();totalShots++;flash(muzzle,direction,shot.projectiles[0]?.visual?.kind);
  if(shot.casing){pending.push({delay:Math.max(0,+shot.casing.delay||0),origin:ejectionOrigin.clone(),direction:direction.clone(),casing:shot.casing,weaponId:shot.weaponId});if(pending.length>limits.pendingCasings)pending.shift()}
  for(const projectile of shot.projectiles){const dir=shotDirection.copy(direction).applyAxisAngle(up,projectile.yawOffset||0);right.crossVectors(dir,up);if(right.lengthSq()>1e-8)dir.applyAxisAngle(right.normalize(),projectile.pitchOffset||0);dir.normalize();spawnProjectile(projectile,shot,muzzle,dir,obstacles)}return true;
 }
 function update(dt){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Effect dt must be finite and non-negative');const elapsedDt=dt;dt=Math.min(.1,dt);elapsed+=elapsedDt;
  if(activeEffects===0&&pending.length===0)return;
  for(let i=pending.length-1;i>=0;i--){pending[i].delay-=dt;if(pending[i].delay<=0){eject(pending[i].origin,pending[i].direction,pending[i].casing,pending[i].weaponId);pending.splice(i,1)}}
  for(const entry of projectilePool){if(!entry.active)continue;const distance=Math.min(entry.remaining,entry.speed*dt);ray.set(entry.root.position,entry.direction);ray.near=.001;ray.far=distance;const obstacles=typeof entry.obstacles==='function'?entry.obstacles(entry.root.position,entry.direction,distance):entry.obstacles,hit=ray.intersectObjects(Array.isArray(obstacles)?obstacles:[],true).find(result=>result.object.visible!==false&&result.distance>.001);if(hit){entry.root.position.copy(hit.point);if(entry.explosive)spawnExplosion(hit.point);else spawnImpact(hit,entry.direction);markImpact(hit,{visual:entry.visual,explosive:entry.explosive,direction:entry.direction});const normal=impactNormal(hit,entry.direction,new THREE.Vector3()),direction=entry.direction.clone(),projectile={weaponId:entry.weaponId,shotId:entry.shotId,damage:entry.damage,visualId:entry.visualId,explosive:entry.explosive};if(typeof options.onImpact==='function')options.onImpact({weaponId:entry.weaponId,shotId:entry.shotId,damage:entry.damage,impulse:entry.damage,explosive:entry.explosive,projectile,hit,point:hit.point.clone(),normal,direction,object:hit.object});hide(entry);continue}entry.root.position.addScaledVector(entry.direction,distance);entry.remaining-=distance;if(entry.remaining<=1e-5)hide(entry)}
  for(const entry of casingPool){if(!entry.active)continue;entry.life-=elapsedDt;if(entry.life<=0){hide(entry);continue}if(entry.settled)continue;
   entry.velocity.y-=9.8*dt;entry.mesh.position.addScaledVector(entry.velocity,dt);entry.mesh.rotation.x+=entry.spin.x*dt;entry.mesh.rotation.y+=entry.spin.y*dt;entry.mesh.rotation.z+=entry.spin.z*dt;
   const sampled=typeof options.groundHeight==='function'?options.groundHeight(entry.mesh.position.x,entry.mesh.position.z,entry.mesh.position.y):null;
   entry.floor=Number.isFinite(sampled)?sampled+.028*Math.max(entry.mesh.scale.x,entry.mesh.scale.z):groundY;
   if(entry.mesh.position.y<entry.floor){entry.mesh.position.y=entry.floor;entry.bounces++;entry.velocity.y=Math.abs(entry.velocity.y)*(entry.bounces===1?.32:.18);entry.velocity.x*=.55;entry.velocity.z*=.55;entry.spin.multiplyScalar(.43);
    if(entry.velocity.y<.22||entry.bounces>=3){entry.settled=true;entry.velocity.set(0,0,0);entry.spin.set(0,0,0);entry.mesh.rotation.x=Math.PI/2;entry.mesh.rotation.z=0}
   }
  }
  for(const entry of flashPool){if(!entry.active)continue;entry.life-=elapsedDt;if(entry.life<=0){hide(entry);continue}const p=entry.life/entry.maxLife;entry.root.scale.setScalar(entry.strength*(.6+p*.5));entry.core.material.opacity=p;entry.cone.material.opacity=p*p*.8}
  for(const entry of impactPool){if(!entry.active)continue;entry.life-=elapsedDt;if(entry.life<=0){hide(entry);continue}const p=entry.life/entry.maxLife,age=1-p,metal=entry.surface==='metal',glass=entry.surface==='glass',wood=entry.surface==='wood';entry.dust.scale.setScalar(.3+age*3.5);entry.dust.position.z=.025+age*.1;entry.dust.material.opacity=Math.sin(age*Math.PI)*.23;
   for(let n=0;n<entry.chips.length;n++){const chip=entry.chips[n],a=n*2.399963+entry.seed,travel=age*(metal?.32:.18)*(1+n*.16);chip.position.set(Math.cos(a)*travel,Math.sin(a)*travel-age*age*.15,age*(.12+n*.025));chip.rotation.set(age*(n+2)*5,n+entry.seed,age*9);chip.scale.set(metal?.26:glass?1.5:wood?.6:1,metal?3.4:wood?2.4:1,glass?.18:1);chip.material.opacity=p*(metal?1:.8);if(metal)chip.material.emissiveIntensity=p*2}
  }
  for(const entry of markPool){if(!entry.active)continue;entry.life=Math.max(0,entry.expiresAt-elapsed);if(entry.life<=0){hide(entry);entry.parent=null;continue}const glass=entry.kind==='glass-chip';entry.mesh.material.opacity=Math.min(glass?.30:.84,entry.life/.25);for(const child of entry.mesh.children)child.material.opacity=Math.min(child.name==='impact-recess'?(glass?.22:.9):child.isLineSegments?.65:.7,entry.life/.25)}
  for(const entry of explosionPool){if(!entry.active)continue;entry.life-=dt;if(entry.life<=0){hide(entry);continue}const p=1-entry.life/entry.maxLife,burst=Math.sin(Math.min(1,p*1.7)*Math.PI),fade=Math.max(0,1-p);entry.core.position.y=.18+burst*.48;entry.core.scale.setScalar(.55+burst*3.6);entry.core.material.opacity=Math.max(0,1-p*1.7);entry.core.material.color.set(p<.12?0xfff0a0:p<.42?0xffa21d:0xd9340c);entry.shock.scale.setScalar(.3+p*8.5);entry.shock.material.opacity=Math.max(0,1-p*2.3)*.76;for(let n=0;n<entry.fire.length;n++){const flame=entry.fire[n],a=entry.fireAngles[n],r=.12+(n%4)*.12+p*.75;flame.position.set(entry.fireCos[n]*r,.2+burst*(.55+(n%3)*.2)+p*.38,entry.fireSin[n]*r);flame.rotation.set(entry.fireSin[n]*.3,a,entry.fireCos[n]*.22);flame.scale.setScalar((.48+burst*(1.7+(n%3)*.22))*fade);flame.material.opacity=Math.max(0,1-p*1.35)}for(let n=0;n<entry.smoke.length;n++){const puff=entry.smoke[n],r=.2+p*(.85+(n%2)*.3);puff.position.set(entry.smokeCos[n]*r,.45+p*(1.4+(n%3)*.28),entry.smokeSin[n]*r);puff.scale.setScalar(.4+p*(1.9+(n%3)*.18));puff.material.opacity=Math.sin(Math.min(1,p*1.22)*Math.PI)*.58}for(let n=0;n<entry.embers.length;n++){const ember=entry.embers[n],travel=p*(1.1+(n%5)*.24),arc=Math.sin(p*Math.PI)*(1.15+(n%4)*.24);ember.position.set(entry.emberCos[n]*travel,.15+arc,entry.emberSin[n]*travel);ember.rotation.set(p*(n+2)*5,p*(n+1)*6,p*(n+3)*4);ember.scale.setScalar(Math.max(.12,.8-p*.66))}}
 }
 function dispose(){if(disposed)return;disposed=true;pending.length=0;const geometries=new Set(),materials=new Set();for(const pool of [projectilePool,casingPool,flashPool,impactPool,markPool,explosionPool])for(const entry of pool){const object=entry.root||entry.mesh;object.removeFromParent();object.traverse?.(node=>{if(node.geometry)geometries.add(node.geometry);for(const material of Array.isArray(node.material)?node.material:[node.material])if(material)materials.add(material)});hide(entry)}for(const geometry of geometries)geometry.dispose();for(const material of materials)material.dispose()}
 const stats=()=>({totalShots,totalCases,totalImpacts,totalProjectiles,totalMarks,totalExplosions,active:activeEffects,activeProjectiles:poolCounts.get(projectilePool).active,activeCasings:poolCounts.get(casingPool).active,activeMarks:poolCounts.get(markPool).active,activeExplosions:poolCounts.get(explosionPool).active,pendingCasings:pending.length,poolCapacity:limits.projectiles+limits.casings+limits.flashes+limits.impacts+limits.marks+limits.explosions});
 return {shoot,update,dispose,stats,limits:Object.freeze({...limits}),debugProjectiles:()=>projectilePool.filter(entry=>entry.active).map(entry=>({position:entry.root.position.clone(),visualId:entry.visualId,remaining:entry.remaining,hasAura:false,coreSize:entry.core.scale.clone(),trailSize:entry.trail.scale.clone()})),debugCasings:()=>casingPool.filter(entry=>entry.active).map(entry=>({position:entry.mesh.position.clone(),velocity:entry.velocity.clone(),spin:entry.spin.clone(),life:entry.life,kind:entry.kind,settled:entry.settled,bounces:entry.bounces})),debugMarks:()=>markPool.filter(entry=>entry.active).map(entry=>{entry.mesh.updateWorldMatrix(true,false);return {position:entry.mesh.getWorldPosition(new THREE.Vector3()),normal:forwardAxis.clone().transformDirection(entry.mesh.matrixWorld),parent:entry.mesh.parent,kind:entry.kind,life:entry.life,maxLife:entry.maxLife,size:entry.size,color:entry.mesh.material.color.getHex()}})};
}

