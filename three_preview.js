// 3D UI v362: camera-facing HQ banners show their family primary and accent colors from every city angle.
// 3D UI v360: empire crew identity cards and focus rings inherit their boss family colors.
// 3D character/weapons v356: NPCs gain articulated forearms and role hems; every arsenal family gains semantic detail parts.
// 3D character v355: shared NPCs gain profiled anatomy, tailoring, jaws, beards, blinking and eye saccades.
// 3D character v354: the playable avatar and every NPC share a rounded, creator-grade silhouette and face/accessory detail.
// 3D optimization v353: startup avoids byte-identical hidden-beacon light-count shader variants.
// 3D character v344: creator gender changes the playable silhouette, tailoring and facial details.
// 3D character v343: fitted hats keep tucked hair while face and neck accessories stay independent.
// 3D character v342: creator body profiles, face marks, hair and visible hands carry into the city rig.
// 3D optimization v352: expired combat-FX sources and delayed ballistic callbacks are lifecycle-tracked.
// 3D UI v351: identity cards themselves fade from right to left with health; separate bars are removed.
// 3D UI v349: framed NPC health is raised into the clear gap below identity labels.
// 3D UI v347: raised overhead labels and a shared-texture framed NPC health indicator.
// 3D render v330: camera occlusion preserves readable facades and restores a selected building immediately.
// 3D city lighting v330: readable traffic lenses and scheduled instanced street-lamp glow.
// 3D prison v327: fixed professional lightbars use double-pulse red/blue lenses and soft glow.
// 3D render v328: exterior names are single roof-mounted signs instead of duplicate HUD sprites.
// 3D render v325: high-volume diagnostic fields share the 250 ms telemetry cadence.
// 3D render v324: standard opaque static details share spatial geometry batches.
// 3D render v323: batched outlines update parent transforms before entering world space.
// 3D input v320: held-RMB aiming accepts a deduplicated LMB click fallback inside the canvas.
// 3D animation v319: every walking humanoid gets a restrained arm swing while firing/reload poses keep priority.
// 3D input v317: RMB-held aim accepts LMB even when an embedded WebView reports an incomplete buttons bitmask.
// 3D composite v265: authored black-market facade, animated guarded door and collision-matched entrance.
// 3D composite v261: black market occupies the former park without legacy camera-relative trees clipping its facade.
// 3D composite v258: complete visual-world pass preserved with inventory armor rigs and audited animation layers.
// 3D composite v253: audited weapon rigs, family-specific reload mechanics and all-weapon QA diagnostics.
// 3D composite v252: explicit animation-state priority, teleport recovery and pooled vehicle-state cleanup.
// 3D composite v251: blended locomotion, directional combat reactions, staged reloads and pooled world motion.
// 3D composite v253: distinct homes, civic venues, prison services and animated business/factory details complete the visual-world pass.
// 3D composite v252: authored service interiors, scaled business rooms and matched 2D casino details complete the current visual pass.
// 3D composite v251: authored bank rooms and facade preserve the stable police/performance world while adding visual-only architecture.
// 3D composite v250: stable 30 FPS WebView profile, prewarmed combat shaders and fixed light budgets prevent police/arrest stalls.
// 3D composite v247: murder-response officers physically cuff, escort, load and transport the player; gang rescue interrupts the scene.
// 3D composite v246: origin/main v245 prison intake, release gate and staff stay authoritative; casino, bank, market, factory and business art are integrated without gameplay changes.
// 3D sync v318: startup warms the exact matte-wreck paint variants used by the first post-prison vehicle explosion.
// 3D sync v245: intake room and per-player timed release portcullis extend the prison over the canal.
// 3D sync v234: pooled NPC rigs consume authoritative life-state flags for panic, cover, surrender, helping and social gestures.
// 3D prison island: the premium complex occupies a three-times-larger canal platform without covering city buildings or roads.
// 3D sync v233: premium two-storey prison adds twenty double cells, open galleries, stairs and a complete common yard.
// 3D sync v232: ambulances use full-body-safe depot and patient-side parking so their complete recovery cycle stays road-driven.
// 3D sync v232 combat: clicked resident and vehicle silhouettes stay locked through the world ballistic pass.
// 3D sync v231: full-body building clearance keeps service vehicles out of facades; active hose trucks stream with their water.
// 3D sync v230: fire engines use road-first response; compact arched hose spray and staged tow loading/carrying replace abrupt effects.
// 3D sync v229: shots lock to the visible silhouette of clicked residents and cars before testing buildings.
// 3D sync v228: fire engines and tow trucks remain parked in persistent fleets and reuse their bays after every road return.
// 3D sync v226: the junkyard landmark streams in when the player reaches its sector instead of remaining an empty cleared lot.
// 3D sync v225: ambulances retry broken routes and keep stretchers locked to a fully arrived vehicle.
// 3D sync v224: tow trucks drive complete road routes without scene teleports.
// 3D sync v223: the coastal junkyard replaces four generic towers with scrap mountains and burning wreck lots.
// 3D sync v222: ambulance patients recover from stale prior-trip and orphaned-dispatch flags.
// 3D sync v221: visible road-side fire response and reliable tow loading after extinguishing.
// 3D sync v220: East-Side hospital and six-ambulance dual-station response; police corpses retain uniforms.
// 3D sync v219: three dirty-clothed junkyard workers patrol, sort scrap and clean the disposal yard.
// 3D sync v216: compact burgundy-gold famiglia seal reticle and verified RMB+LMB shot chord.
// 3D sync v215: bounded simulation-owned throwable/fire lifecycle prevents long-session stalls.
// 3D sync v214: RMB laser aiming accepts simultaneous LMB fire and uses the Mafiozi brass-diamond reticle.
// 3D sync v322: hostile gang labels show Bellini/Moretti instead of debug faction colors.
// 3D sync v321: one projected car-roof hold-E prompt drives hijack, entry and exit.
// 3D sync v213: distinct sidearms, hold-to-throw aiming, guaranteed 3D detonation and wide short-lived Molotov fire.
// 3D sync v212: every living NPC uses the player's restrained stride, weight shift and arm cadence with a deeper, body-safe leg attachment.
// 3D sync v205: dead NPCs freeze at their fall point and keep a pooled blood pool beneath the body.
// 3D sync v204: NPC identity/HP panels float safely above heads at gameplay zoom.
// 3D sync v203: fresh resident faces on respawn, natural asymmetric gait/bleeding and invariant blue police uniforms.
// 3D sync v201: large sharp NPC identity, HP and speech panels keep residents, police, gangs and the Brigadir readable at gameplay zoom.
// 3D sync v200: injured residents limp by default; only genuinely downed or leg-disabled NPCs crawl, at a deliberately slow pace.
// 3D sync v199: loading stays masked until the full frame, vehicle shots lock to the clicked mesh, and collapsed wrecks burn with textured pooled flames.
// 3D sync v198: sharp native rendering, dramatic pooled explosions, black burning wrecks, detailed bridge deck, four-layer bullets and wall impacts.
// 3D sync v198: Brigadir is full-size, speaks contextually and opens a styled, working contract flow.
// 3D sync v197: adaptive native resolution, lighter wreck fire and car-locked tracers restore smooth combat animation.
// 3D sync v196: pooled wreck fire restores burning cars without dynamic-light shader stalls.
// 3D sync v195: bounded vehicle explosions, hold-E entry, bounded pets and speed-aware NPC gait.
// Reversible Three.js city prototype. Canvas stays the default and emergency
// fallback. The central flag can disable 3D without removing this module.
const rendererParams = new URLSearchParams(location.search);
const rendererConfig = window.MAFIOZI_RENDERER_CONFIG || {};
if ((rendererParams.get('force3d') === '1' || rendererParams.get('render') !== 'canvas') && rendererConfig.threeEnabled !== false) {
  (async () => {
    const stage = document.getElementById('stage');
    const rendererBootAt=performance.now();
    const startupTrace=[];
    const startupMark=label=>{const elapsed=(performance.now()-rendererBootAt).toFixed(1);startupTrace.push(`${label}:${elapsed}`);document.documentElement.dataset.threeStartup=startupTrace.join(',');console.info(`[ThreeStartup] ${label} ${elapsed}ms`);};
    try {
      window.MafioziLoading?.set(52, 'Загружаем трёхмерный движок…');
      const THREE = await import('https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js');
      startupMark('module');
      window.MafioziLoading?.set(61, 'Настраиваем свет, материалы и тени…');
      const viewSize = () => ({ W: Math.max(1, stage.clientWidth || innerWidth), H: Math.max(1, stage.clientHeight || innerHeight) });
      const size = viewSize();
      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0x0c1b2c);
      scene.fog = new THREE.FogExp2(0x10233a, 0.0036);
      // Present a tiny unlit city silhouette before the authored physical
      // materials and their shadow variants are compiled by the GPU.
      const bootScene = new THREE.Scene();
      bootScene.background = new THREE.Color(0x0c1b2c);
      bootScene.fog = new THREE.FogExp2(0x10233a, 0.0036);

      // Local overview is a read-only inspection angle for the enlarged jail.
      // Normal gameplay keeps the established city framing unchanged.
      const cameraSpan=rendererParams.get('previewjail')==='overview'?58:40;
      const camera = new THREE.OrthographicCamera(-cameraSpan * size.W / size.H, cameraSpan * size.W / size.H, cameraSpan, -cameraSpan, 0.1, 1000);
      // Classic 2:1-ish isometric angle instead of the near top-down test view.
      camera.position.set(54, 62, 54);
      camera.lookAt(0, 0, 0);

      const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
      // Shader diagnostics synchronously query driver logs/link status on first
      // use and can block production frames for seconds. Keep them available
      // only in the explicit perf diagnostics mode; rendering is unchanged.
      renderer.debug.checkShaderErrors=rendererParams.has('perfdiag');
      // Start at native density. Forced 1.65x supersampling made a 1080p city
      // render more than five million pixels per frame and visibly degraded
      // every character/vehicle animation on ordinary desktop GPUs.
      const coarsePointer=!!globalThis.matchMedia?.('(pointer:coarse)')?.matches;
      const mobileRenderProfile=coarsePointer||Math.min(size.W,size.H)<700;
      const shadowPreference=rendererParams.get('shadows');
      const realTimeShadows=shadowPreference==='1'||(shadowPreference!=='0'&&!mobileRenderProfile);
      const requestedRenderFps=Math.max(24,Math.min(60,+rendererParams.get('fps')||0));
      const targetRenderFps=requestedRenderFps||(mobileRenderProfile?30:60);
      const threeFrameMinMs=1000/targetRenderFps;
      const baseRenderPixelRatio=Math.min(mobileRenderProfile?1:1.25,Math.max(1,devicePixelRatio||1));
      let renderPixelRatio=baseRenderPixelRatio;
      renderer.setPixelRatio(renderPixelRatio);
      renderer.setSize(size.W, size.H, false);
      renderer.shadowMap.enabled = false;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      renderer.shadowMap.autoUpdate = false;
      renderer.shadowMap.needsUpdate = true;
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.32;
      renderer.domElement.id = 'threePreview';
      renderer.domElement.dataset.deviceProfile=mobileRenderProfile?'mobile-stable':'desktop-full';
      renderer.domElement.dataset.targetRenderFps=String(targetRenderFps);
      renderer.domElement.dataset.realTimeShadows=realTimeShadows?'on':'off';
      // The weapon reticle is hold-to-aim. Outside RMB aiming the city keeps a
      // normal pointer instead of showing a misleading permanent crosshair.
      renderer.domElement.style.cursor = 'default';
      renderer.domElement.style.pointerEvents = 'auto';
      renderer.domElement.style.filter = 'saturate(1.09) contrast(1.035)';
      stage.appendChild(renderer.domElement);
      const cinematicGrade=document.createElement('div');cinematicGrade.id='threeCinematicGrade';cinematicGrade.style.cssText='position:absolute;inset:0;z-index:4;pointer-events:none;background:radial-gradient(circle at 50% 45%,transparent 48%,rgba(3,8,15,.08) 72%,rgba(2,5,11,.23) 100%);mix-blend-mode:multiply';stage.appendChild(cinematicGrade);
      // Keep only the day/night grade values consumed by diagnostics. The old
      // fullscreen render target is no longer sampled and must not reserve a
      // second full-resolution color/depth/MSAA buffer.
      const postMaterial={uniforms:{uBloom:{value:.18},uWarmth:{value:.12},uNight:{value:0}}};

      const bridge=window.Mafiozi3DBridge||null;
      renderer.domElement.dataset.npcInteractionBridge=bridge&&typeof bridge.fireAtGangNpc==='function'&&typeof bridge.selectGangNpc==='function'?'targeted-fire-right-click-hire':'missing';
      renderer.domElement.dataset.sessionStabilityProfile='bounded-throwables-fire-v215';
      if(rendererParams.has('previewbuilding'))bridge?.previewApproachGenericBuilding?.();
      if(rendererParams.has('previewbridge'))bridge?.previewApproachBridge?.();
      if(rendererParams.has('previewsaid')){
        const saidApproach=bridge?.previewApproachSaid?.();
        renderer.domElement.dataset.saidApproach=saidApproach?`safe:${saidApproach.citySafe?1:0}:hp:${saidApproach.hp}`:'missing';
        setTimeout(()=>{const hit=bridge?.previewAttackSaid?.();renderer.domElement.dataset.saidDamageQa=hit?`alive:${hit.dead?0:1}:hp:${hit.hp}:burn:${hit.burning?1:0}:important:${hit.important?1:0}`:'missing';},4200);
      }
      if(rendererParams.get('previewmajor')){const previewMajorId=rendererParams.get('previewmajor'),pinPreviewMajor=()=>bridge?.previewApproachMajor?.(previewMajorId);pinPreviewMajor();const previewMajorTimer=setInterval(pinPreviewMajor,550);setTimeout(()=>clearInterval(previewMajorTimer),24000);}
      const initialState=bridge?.getPlayerState?.()||null;
      // Стартуем только с ближайшего сектора. Остальные кварталы достраиваются
      // по мере движения и кэшируются — большая двухчастная карта не создаёт
      // сотни тяжёлых фасадов в первом кадре.
      // Camera-visible quality is unchanged; only far off-screen preload is
      // bounded so invisible facade meshes do not dominate every frame.
      // Stream only the camera neighborhood. Geometry quality is unchanged;
      // adjacent sectors are requested before the player reaches their edge.
      const WORLD_SNAPSHOT_RADIUS=Math.max(28,Math.min(58,+rendererConfig.snapshotRadius||34));
      const STREAM_SECTOR_SIZE=24;
      const worldSnapshot=bridge?.getWorldSnapshot?.(WORLD_SNAPSHOT_RADIUS)||null;
      const envSnapshot=bridge?.getEnvironmentState?.()||null;
      const originR=initialState?.r||0,originC=initialState?.c||0,WORLD_SCALE=Math.max(3,Math.min(5,+rendererConfig.worldScale||4.1)),selectedWeather=(rendererParams.get('weather')||envSnapshot?.weather||'clear').toLowerCase();
      window.MafioziLoading?.set(69, 'Разворачиваем ближайший сектор города…');

      const skyLight=new THREE.HemisphereLight(0xb9d7ff,0x302634,2.65);scene.add(skyLight);
      const sun = new THREE.DirectionalLight(0xffdfa0, 3.65);
      const sunOffsetVector=new THREE.Vector3(-45,85,35);
      sun.position.set(-45, 85, 35);
      sun.castShadow = true;
      sun.shadow.mapSize.set(1536, 1536);
      sun.shadow.camera.left = sun.shadow.camera.bottom = -58;
      sun.shadow.camera.right = sun.shadow.camera.top = 58;
      sun.shadow.bias = -.00035;
      sun.shadow.normalBias = .055;
      sun.shadow.radius = 3.2;
      scene.add(sun);scene.add(sun.target);

      // A small blurred footprint texture supplies the missing near-field
      // occlusion that a single sun shadow cannot show under the high
      // isometric camera. Buildings share one instanced draw call; moving
      // actors reuse the same texture without enabling an expensive SSAO pass.
      const contactShadowCanvas=document.createElement('canvas');contactShadowCanvas.width=contactShadowCanvas.height=128;
      const contactShadowContext=contactShadowCanvas.getContext('2d'),contactShadowGradient=contactShadowContext.createRadialGradient(64,64,5,64,64,62);
      contactShadowGradient.addColorStop(0,'rgba(0,0,0,.82)');contactShadowGradient.addColorStop(.42,'rgba(0,0,0,.48)');contactShadowGradient.addColorStop(.76,'rgba(0,0,0,.14)');contactShadowGradient.addColorStop(1,'rgba(0,0,0,0)');
      contactShadowContext.fillStyle=contactShadowGradient;contactShadowContext.fillRect(0,0,128,128);
      const contactShadowTexture=new THREE.CanvasTexture(contactShadowCanvas);contactShadowTexture.colorSpace=THREE.SRGBColorSpace;contactShadowTexture.minFilter=THREE.LinearFilter;contactShadowTexture.magFilter=THREE.LinearFilter;contactShadowTexture.generateMipmaps=false;
      const contactShadowMaterial=new THREE.MeshBasicMaterial({map:contactShadowTexture,color:0x111722,transparent:true,opacity:.28,depthWrite:false,toneMapped:false,side:THREE.DoubleSide});
      const dynamicContactShadowMaterial=contactShadowMaterial.clone();dynamicContactShadowMaterial.opacity=.42;
      const makeContactShadow=(w,d,material=dynamicContactShadowMaterial)=>{
        const shadow=new THREE.Mesh(new THREE.PlaneGeometry(w,d),material);shadow.rotation.x=-Math.PI/2;shadow.position.y=.055;shadow.renderOrder=3;
        shadow.onBeforeRender=()=>{const airborne=!!shadow.parent?.userData?.source?.helicopter;shadow.position.y=airborne?-5.44:.055;shadow.scale.setScalar(airborne?1.55:1);};
        return shadow;
      };

      const surfaceTextureCache=new Map();
      const surfaceTexture=(kind,base,detail)=>{
        const key=`${kind}:${base}:${detail}`;if(surfaceTextureCache.has(key))return surfaceTextureCache.get(key);
        const cv=document.createElement('canvas');cv.width=cv.height=512;const c=cv.getContext('2d');c.fillStyle=base;c.fillRect(0,0,512,512);
        let seed=kind.split('').reduce((n,ch)=>(n*33+ch.charCodeAt(0))>>>0,2166136261),rnd=()=>((seed=(seed*1664525+1013904223)>>>0)/4294967296);
        for(let i=0;i<2200;i++){const a=.025+rnd()*.11,g=55+Math.floor(rnd()*95);c.fillStyle=`rgba(${g},${g},${g},${a})`;const s=.4+rnd()*2.2;c.fillRect(rnd()*512,rnd()*512,s,s);}
        c.strokeStyle=detail;c.lineWidth=1.2;
        if(kind==='asphalt')for(let i=0;i<19;i++){c.beginPath();let x=rnd()*512,y=rnd()*512;c.moveTo(x,y);for(let k=0;k<5;k++){x+=(rnd()-.5)*42;y+=(rnd()-.5)*42;c.lineTo(x,y);}c.stroke();}
        if(kind==='concrete')for(let x=0;x<512;x+=64){c.globalAlpha=.18;c.strokeRect(x+(rnd()-.5)*4,0,1,512);c.strokeRect(0,x+(rnd()-.5)*4,512,1);}
        if(kind==='metal')for(let y=0;y<512;y+=18){c.globalAlpha=.2;c.fillStyle=detail;c.fillRect(0,y,512,2);}
        c.globalAlpha=1;const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.wrapS=tx.wrapT=THREE.RepeatWrapping;tx.repeat.set(kind==='asphalt'?18:kind==='concrete'?10:6,kind==='asphalt'?36:10);tx.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());tx.needsUpdate=true;surfaceTextureCache.set(key,tx);return tx;
      };
      const asphaltTexture=surfaceTexture('asphalt','#30383f','rgba(7,11,15,.22)'),concreteTexture=surfaceTexture('concrete','#687176','rgba(235,240,235,.3)'),roofTexture=surfaceTexture('metal','#34424c','rgba(210,225,232,.28)');
      const environmentFaces=Array.from({length:6},(_,face)=>{const cv=document.createElement('canvas');cv.width=cv.height=256;const c=cv.getContext('2d'),g=c.createLinearGradient(0,0,0,256);g.addColorStop(0,face===2?'#d9efff':'#78b9e3');g.addColorStop(.52,'#7fa0b5');g.addColorStop(.54,'#d8b982');g.addColorStop(1,'#26333c');c.fillStyle=g;c.fillRect(0,0,256,256);return cv;});
      const cityEnvironment=new THREE.CubeTexture(environmentFaces);cityEnvironment.colorSpace=THREE.SRGBColorSpace;cityEnvironment.needsUpdate=true;scene.environment=cityEnvironment;scene.environmentIntensity=.72;
      // One shared vertex-wind treatment keeps every tree family alive without
      // moving hundreds of objects on the CPU. World/instance coordinates give
      // each crown its own phase, while slow gusts prevent mechanical swaying.
      const windLeafMaterials=[];
      const windMaterial=(color,bendX,bendZ,roughness=.88)=>{const mat=new THREE.MeshStandardMaterial({color,roughness});mat.onBeforeCompile=shader=>{shader.uniforms.mfzWindTime={value:0};shader.vertexShader='uniform float mfzWindTime;\n'+shader.vertexShader.replace('#include <begin_vertex>',`#include <begin_vertex>
float mfzPhase=modelMatrix[3].x*.071+modelMatrix[3].z*.053;
#ifdef USE_INSTANCING
  mfzPhase+=instanceMatrix[3].x*.109+instanceMatrix[3].z*.087;
#endif
float mfzPulse=pow(.5+.5*sin(mfzWindTime*.19+mfzPhase*.37),5.0);
float mfzGust=.54+.3*sin(mfzWindTime*.29+mfzPhase*.63)+mfzPulse*.52;
float mfzWeight=.32+smoothstep(-2.1,2.35,position.y);
float mfzWind=sin(mfzWindTime*1.08+mfzPhase+position.y*1.17+position.x*.34);
transformed.x+=mfzWind*mfzGust*mfzWeight*${bendX};
transformed.z+=cos(mfzWindTime*.82+mfzPhase*1.31+position.z*.42)*mfzGust*mfzWeight*${bendZ};`);mat.userData.shader=shader;};
        // Color is a standard material uniform, not shader source. Keeping it in
        // the program key compiled the identical wind GLSL once per foliage tint.
        mat.customProgramCacheKey=()=>`mfz-wind-v4-${bendX}-${bendZ}`;windLeafMaterials.push(mat);return mat;};
      const windLeafMaterial=color=>windMaterial(color,.205,.128,.88);
      const windTrunkMaterial=color=>windMaterial(color,.045,.027,.96);
      const skyUniforms={uTop:{value:new THREE.Color(0x3c9fe0)},uHorizon:{value:new THREE.Color(0xb9d8e8)},uNight:{value:0},uSunset:{value:0}},skyDome=new THREE.Mesh(new THREE.SphereGeometry(430,28,16),new THREE.ShaderMaterial({side:THREE.BackSide,depthWrite:false,depthTest:false,fog:false,uniforms:skyUniforms,vertexShader:'varying vec3 vDir;void main(){vDir=normalize(position);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',fragmentShader:'uniform vec3 uTop;uniform vec3 uHorizon;uniform float uNight;uniform float uSunset;varying vec3 vDir;void main(){float h=smoothstep(-.18,.72,vDir.y);vec3 c=mix(uHorizon,uTop,h);float haze=pow(1.0-abs(vDir.y),5.0);c+=vec3(.22,.07,.025)*uSunset*haze;c=mix(c,vec3(.012,.035,.085),uNight*.82);gl_FragColor=vec4(c,1.0);}'}));skyDome.frustumCulled=false;skyDome.renderOrder=-1000;scene.add(skyDome);
      const starCount=120,starPositions=new Float32Array(starCount*3);for(let i=0;i<starCount;i++){const a=i*2.39996323,y=.15+((i*37)%83)/100,r=Math.sqrt(1-y*y)*360;starPositions[i*3]=Math.cos(a)*r;starPositions[i*3+1]=y*360;starPositions[i*3+2]=Math.sin(a)*r;}const starGeometry=new THREE.BufferGeometry();starGeometry.setAttribute('position',new THREE.BufferAttribute(starPositions,3));const starMaterial=new THREE.PointsMaterial({color:0xe8f3ff,size:1.35,sizeAttenuation:false,transparent:true,opacity:0,depthWrite:false,fog:false}),starField=new THREE.Points(starGeometry,starMaterial);starField.frustumCulled=false;starField.renderOrder=-999;scene.add(starField);

      const box = (x, z, w, d, h, mat) => {
        const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
        mesh.position.set(x, h / 2, z);
        mesh.castShadow = mesh.receiveShadow = true;
        scene.add(mesh);
        return mesh;
      };
      // BoxGeometry normally has six material groups, so a building with the
      // same facade on four sides still costs six draw calls. Reorder the
      // indexed faces into two contiguous groups (walls + roof/floor). This
      // preserves the exact UVs, normals and materials while cutting the main
      // mass to two calls. Native frustum culling then skips off-screen blocks.
      const buildingBoxGeometry = (w, h, d) => {
        const geometry = new THREE.BoxGeometry(w, h, d);
        const source = geometry.index.array;
        const order = [0, 1, 4, 5, 2, 3];
        const IndexArray = source.constructor;
        const reordered = new IndexArray(source.length);
        let offset = 0;
        for (const face of order) {
          const start = face * 6;
          for (let i = 0; i < 6; i++) reordered[offset++] = source[start + i];
        }
        geometry.setIndex(new THREE.BufferAttribute(reordered, 1));
        geometry.clearGroups();
        geometry.addGroup(0, 24, 0);
        geometry.addGroup(24, 12, 1);
        return geometry;
      };
      const buildingBox = (x, z, w, d, h, wallMat, roofMaterial) => {
        const mesh = new THREE.Mesh(buildingBoxGeometry(w, h, d), [wallMat, roofMaterial]);
        mesh.position.set(x, h / 2, z);
        mesh.castShadow = mesh.receiveShadow = true;
        scene.add(mesh);
        return mesh;
      };
      const staticOutlineGeometries=[];
      let batchStaticOutlines=true;
      const sharedOutlineMaterial=new THREE.LineBasicMaterial({color:0x0a111b,transparent:true,opacity:.78});
      sharedOutlineMaterial.userData.mfzPersistent=true;
      const disposeTransientObjectTree=root=>{
        if(!root)return;
        const geometries=new Set(),materials=new Set(),textures=new Set();
        root.traverse?.(object=>{
          if(object.geometry&&!object.geometry.userData?.mfzPersistent)geometries.add(object.geometry);
          const list=Array.isArray(object.material)?object.material:[object.material];
          for(const material of list){
            if(!material||material.userData?.mfzPersistent)continue;
            materials.add(material);
            for(const value of Object.values(material))if(value?.isTexture)textures.add(value);
          }
        });
        root.parent?.remove(root);
        textures.forEach(texture=>texture.dispose?.());
        geometries.forEach(geometry=>geometry.dispose?.());
        materials.forEach(material=>material.dispose?.());
      };
      const outline = mesh => {
        const edgeGeometry=new THREE.EdgesGeometry(mesh.geometry,24);
        if(batchStaticOutlines&&mesh.layers.mask!==2){
          mesh.updateWorldMatrix(true,false);
          edgeGeometry.applyMatrix4(mesh.matrixWorld);
          staticOutlineGeometries.push(edgeGeometry);
          return null;
        }
        const edges = new THREE.LineSegments(edgeGeometry,sharedOutlineMaterial);
        if(mesh.layers.mask===2){edges.layers.set(1);mesh.add(edges);}
        else{edges.position.copy(mesh.position);edges.rotation.copy(mesh.rotation);edges.scale.copy(mesh.scale);scene.add(edges);}
        return edges;
      };
      const detailMat=new THREE.MeshStandardMaterial({color:0x4c5964,roughness:.68,metalness:.18});
      const facadeTexture = (profile, seed) => {
        const family=typeof profile==='string'?{id:'mixed',base:profile}:profile,id=family.id||'mixed',base=family.base||'#59636a';
        const cv = document.createElement('canvas');
        cv.width = cv.height = 1536;
        const c = cv.getContext('2d');
        c.scale(3, 3);
        c.fillStyle=base;c.fillRect(0,0,512,512);
        if(id==='glass'){
          const sheen=c.createLinearGradient(0,0,512,512);sheen.addColorStop(0,'rgba(126,211,239,.2)');sheen.addColorStop(.38,'rgba(8,25,38,.08)');sheen.addColorStop(.58,'rgba(230,247,255,.13)');sheen.addColorStop(1,'rgba(3,13,22,.2)');c.fillStyle=sheen;c.fillRect(0,0,512,512);
          c.fillStyle='rgba(7,18,28,.42)';for(let x=0;x<512;x+=56)c.fillRect(x,0,5,512);for(let y=0;y<512;y+=48)c.fillRect(0,y,512,4);
          c.fillStyle='rgba(204,238,248,.22)';for(let x=9;x<512;x+=56)c.fillRect(x,0,3,512);
        }else if(id==='brick'){
          c.fillStyle='rgba(36,18,14,.27)';for(let y=0;y<512;y+=18){c.fillRect(0,y,512,2);for(let x=((y/18)&1)?-24:0;x<512;x+=48)c.fillRect(x,y,2,18);}
          c.fillStyle='rgba(238,170,120,.06)';for(let y=4;y<512;y+=36)c.fillRect(0,y,512,3);
        }else if(id==='limestone'){
          c.fillStyle='rgba(255,244,214,.1)';for(let y=0;y<512;y+=72)c.fillRect(0,y,512,7);
          c.fillStyle='rgba(64,55,45,.15)';for(let x=0;x<512;x+=112)c.fillRect(x,0,3,512);
          c.fillStyle='rgba(255,255,255,.08)';for(let x=6;x<512;x+=112)c.fillRect(x,0,2,512);
        }else if(id==='concrete'){
          c.fillStyle='rgba(20,26,30,.19)';for(let x=0;x<512;x+=96)c.fillRect(x,0,4,512);for(let y=0;y<512;y+=64)c.fillRect(0,y,512,4);
          c.fillStyle='rgba(236,242,239,.09)';for(let y=8;y<512;y+=128)c.fillRect(0,y,512,8);
        }else if(id==='deco'){
          c.fillStyle='rgba(223,196,131,.12)';for(let x=8;x<512;x+=64)c.fillRect(x,0,9,512);
          c.fillStyle='rgba(18,27,30,.24)';for(let x=44;x<512;x+=64)c.fillRect(x,0,5,512);
          for(let y=0;y<512;y+=96){c.fillStyle='rgba(238,211,149,.16)';c.fillRect(0,y,512,7);c.fillRect(0,y+13,512,2);}
        }else if(id==='industrial'){
          c.fillStyle='rgba(15,22,27,.2)';for(let x=0;x<512;x+=24)c.fillRect(x,0,3,512);
          c.fillStyle='rgba(232,176,72,.13)';for(let y=0;y<512;y+=112)c.fillRect(0,y,512,9);
          c.fillStyle='rgba(255,255,255,.05)';for(let x=5;x<512;x+=24)c.fillRect(x,0,2,512);
        }
        const familyGrid={
          glass:[56,48,43,34],brick:[56,48,26,22],limestone:[64,56,28,28],
          concrete:[64,64,31,27],deco:[64,48,28,30],industrial:[72,56,38,23],
          mixed:[56,48,28,22]
        }[id]||[56,48,28,22],stepX=familyGrid[0],stepY=familyGrid[1],winW=familyGrid[2],winH=familyGrid[3],variant=seed%3;
        for (let y = 24, iy = 0; y < 488; y += stepY, iy++) for (let x = 20, ix = 0; x < 488; x += stepX, ix++) {
          if(variant===1&&((ix+iy)&3)===0)continue;
          const lit=((ix*17+iy*31+seed*13)%9)<3,ww=winW+(variant===2&&id!=='glass'?6:0),hh=winH;
          c.fillStyle=id==='limestone'?'rgba(54,48,42,.62)':'#071018';c.fillRect(x-3,y-3,ww+6,hh+6);
          c.fillStyle=lit?(id==='glass'?'#d7f1ff':'#ffd67d'):(id==='glass'?'#163e52':id==='industrial'?'#172d35':'#11283a');c.fillRect(x,y,ww,hh);
          c.fillStyle=lit?'rgba(255,249,205,.68)':'rgba(116,190,222,.28)';c.fillRect(x+4,y+3,Math.max(7,ww*.28),hh-6);
          c.fillStyle='rgba(4,9,16,.7)';c.fillRect(x+ww*.5-1,y,2,hh);
          if(id==='brick'){c.fillStyle='rgba(219,177,129,.16)';c.fillRect(x-5,y+hh+3,ww+10,3);}
          if(id==='deco'){c.fillStyle='rgba(218,183,104,.28)';c.fillRect(x-5,y-5,3,hh+10);}
        }
        if(id==='glass'){const reflection=c.createLinearGradient(0,0,512,0);reflection.addColorStop(0,'rgba(255,255,255,0)');reflection.addColorStop(.47,'rgba(212,244,255,.17)');reflection.addColorStop(.56,'rgba(255,255,255,0)');c.fillStyle=reflection;c.fillRect(0,0,512,512);}
        const tx = new THREE.CanvasTexture(cv);
        tx.colorSpace = THREE.SRGBColorSpace;
        tx.wrapS = tx.wrapT = THREE.RepeatWrapping;
        tx.repeat.set(1, 2.1);
        tx.anisotropy = Math.min(16,renderer.capabilities.getMaxAnisotropy());
        tx.generateMipmaps = false;
        tx.magFilter = THREE.NearestFilter;
        tx.minFilter = THREE.LinearFilter;
        tx.needsUpdate = true;
        return tx;
      };

      const groundMaterial=new THREE.MeshStandardMaterial({color:0xa8b0b5,map:asphaltTexture,roughness:selectedWeather==='rain'?.34:.88,roughnessMap:asphaltTexture,metalness:selectedWeather==='rain'?.18:.08,bumpMap:asphaltTexture,bumpScale:.055,envMap:cityEnvironment,envMapIntensity:selectedWeather==='rain'?1.05:.12}),worldCols=envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||80,worldRows=envSnapshot?.mapRows||worldSnapshot?.bounds?.maxR||200,worldWidth=worldCols*WORLD_SCALE,worldDepth=worldRows*WORLD_SCALE;
      const ground = new THREE.Mesh(new THREE.PlaneGeometry(worldSnapshot?worldWidth+WORLD_SCALE*4:190,worldSnapshot?worldDepth+WORLD_SCALE*4:190),groundMaterial);
      ground.rotation.x = -Math.PI / 2;ground.position.set(worldSnapshot?(worldCols*.5-originC)*WORLD_SCALE:0,0,worldSnapshot?(worldRows*.5-originR)*WORLD_SCALE:0);ground.receiveShadow = true; scene.add(ground);
      const bootGround=new THREE.Mesh(new THREE.PlaneGeometry(worldSnapshot?worldWidth+WORLD_SCALE*4:190,worldSnapshot?worldDepth+WORLD_SCALE*4:190),new THREE.MeshBasicMaterial({color:0x1a2a35}));
      bootGround.rotation.x=-Math.PI/2;bootGround.position.copy(ground.position);bootScene.add(bootGround);
      const bootPlayerMarker=new THREE.Group(),bootPlayerBody=new THREE.Mesh(new THREE.CapsuleGeometry(.48,1.35,3,8),new THREE.MeshBasicMaterial({color:0xc3343d})),bootPlayerHead=new THREE.Mesh(new THREE.SphereGeometry(.44,10,7),new THREE.MeshBasicMaterial({color:0xe0ad83})),bootPlayerHat=new THREE.Mesh(new THREE.CylinderGeometry(.62,.72,.22,12),new THREE.MeshBasicMaterial({color:0x171b22}));
      bootPlayerBody.position.y=1.15;bootPlayerHead.position.y=2.35;bootPlayerHat.position.y=2.78;bootPlayerMarker.add(bootPlayerBody,bootPlayerHead,bootPlayerHat);bootScene.add(bootPlayerMarker);
      let waterSurface=null,waterUniforms=null,coastalAnimation=null;
      if(worldSnapshot?.canal){
        const canal=worldSnapshot.canal,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;
        const canalWaterMat=new THREE.MeshStandardMaterial({color:0x087fa5,roughness:.16,metalness:.25,transparent:true,opacity:.92,envMap:cityEnvironment,envMapIntensity:1.1});
        const canalWater=new THREE.Mesh(new THREE.PlaneGeometry((canal.c1-canal.c0)*WORLD_SCALE,(canal.r1-canal.r0)*WORLD_SCALE),canalWaterMat);canalWater.rotation.x=-Math.PI/2;canalWater.position.set(toX((canal.c0+canal.c1)/2),.09,toZ((canal.r0+canal.r1)/2));scene.add(canalWater);
        const bridgeWidth=(canal.c1-canal.c0+2)*WORLD_SCALE,bridgeDepth=(canal.bridge.r1-canal.bridge.r0)*WORLD_SCALE,bridgeX=toX((canal.c0+canal.c1)/2),bridgeZ=toZ((canal.bridge.r0+canal.bridge.r1)/2);
        const bridgeStoneMat=new THREE.MeshStandardMaterial({color:0x687078,roughness:.68,metalness:.2,envMap:cityEnvironment,envMapIntensity:.42}),bridgeDarkMat=new THREE.MeshStandardMaterial({color:0x172127,roughness:.3,metalness:.86,envMap:cityEnvironment,envMapIntensity:.88}),bridgeCableMat=new THREE.MeshStandardMaterial({color:0x242a2f,roughness:.24,metalness:.92,envMap:cityEnvironment,envMapIntensity:1.05}),bridgeHangerMat=new THREE.MeshStandardMaterial({color:0xb6b9b5,roughness:.26,metalness:.9}),bridgeGoldMat=new THREE.MeshStandardMaterial({color:0xd0a342,roughness:.22,metalness:.9}),bridgeRedMat=new THREE.MeshStandardMaterial({color:0xb52c31,roughness:.38,metalness:.48,envMap:cityEnvironment,envMapIntensity:.72}),bridgeJadeMat=new THREE.MeshStandardMaterial({color:0x184d46,roughness:.42,metalness:.35}),bridgeGlowMat=new THREE.MeshBasicMaterial({color:0xffd276,toneMapped:false}),bridgeRedGlowMat=new THREE.MeshBasicMaterial({color:0xff443d,toneMapped:false});
        const bridgeDeck=box(bridgeX,bridgeZ,bridgeWidth,bridgeDepth,.68,new THREE.MeshStandardMaterial({color:0xa7afb4,map:asphaltTexture,roughness:.72,metalness:.18}));bridgeDeck.position.y=.72;bridgeDeck.receiveShadow=true;
        // Deep stone fascia and steel girders give the crossing weight when seen from the fixed camera.
        for(const rr of [canal.bridge.r0+.22,canal.bridge.r1-.22]){
          const fascia=box(bridgeX,toZ(rr),bridgeWidth,.34,.72,bridgeDarkMat);fascia.position.y=.34;
          const lowerGirder=box(bridgeX,toZ(rr),bridgeWidth,.18,.22,bridgeGoldMat);lowerGirder.position.y=-.06;
          for(let c=canal.c0-1;c<=canal.c1+1;c+=2.15){const brace=box(toX(c),toZ(rr),.16,.25,1.02,bridgeHangerMat);brace.position.y=.27;brace.rotation.z=(Math.floor(c*10)%2?1:-1)*.72;}
        }
        for(let c=canal.c0-1;c<=canal.c1+1;c+=4){const cross=box(toX(c),bridgeZ,.22,bridgeDepth+.65,.3,bridgeDarkMat);cross.position.y=-.55;}
        // Only the two suspension towers touch the water; the open span remains light and readable.
        const suspensionTowerCs=[canal.c0+3.4,canal.c1-3.4],towerEdgeZ=[bridgeZ-bridgeDepth*.5+1.7,bridgeZ+bridgeDepth*.5-1.7],pierGeometry=new THREE.CylinderGeometry(.9,1.45,6.4,18),capitalGeometry=new THREE.CylinderGeometry(1.25,.92,.58,18);
        for(const c of suspensionTowerCs)for(const pz of towerEdgeZ){const pier=new THREE.Mesh(pierGeometry,bridgeStoneMat);pier.position.set(toX(c),-2.25,pz);pier.castShadow=pier.receiveShadow=true;scene.add(pier);const capital=new THREE.Mesh(capitalGeometry,bridgeGoldMat);capital.position.set(toX(c),.98,pz);capital.castShadow=true;scene.add(capital);}
        const railY=1.72;
        for(const rr of [canal.bridge.r0+.38,canal.bridge.r1-.38]){
          const topRail=box(bridgeX,toZ(rr),bridgeWidth,.18,.2,bridgeGoldMat);topRail.position.y=railY;
          const lowerRail=box(bridgeX,toZ(rr),bridgeWidth,.12,.13,bridgeDarkMat);lowerRail.position.y=1.15;
          for(let c=canal.c0-1;c<=canal.c1+1;c+=1.45){const baluster=new THREE.Mesh(new THREE.CylinderGeometry(.07,.1,.72,8),bridgeDarkMat);baluster.position.set(toX(c),1.36,toZ(rr));scene.add(baluster);}
        }
        const seawallMat=new THREE.MeshStandardMaterial({color:0x68737a,roughness:.78,metalness:.18});for(const cc of [canal.c0-.15,canal.c1+.15]){const wall=box(toX(cc),toZ((canal.r0+canal.r1)/2),.45*WORLD_SCALE,(canal.r1-canal.r0)*WORLD_SCALE,1.15,seawallMat);wall.position.y=.28;}
        const bridgeStripeMat=new THREE.MeshBasicMaterial({color:0xe7c75e});for(let c=canal.c0;c<canal.c1;c+=3){const stripe=box(toX(c+1),bridgeZ,1.5*WORLD_SCALE,.12*WORLD_SCALE,.045,bridgeStripeMat);stripe.position.y=1.135;}
        // v198 deck detailing stays batched: promenades, red curbs, expansion
        // joints, reflectors and anchor blocks add four draw calls in total.
        const addBridgeInstances=(geometry,material,poses)=>{const mesh=new THREE.InstancedMesh(geometry,material,poses.length),m=new THREE.Matrix4();poses.forEach(([x,y,z,sx=1,sy=1,sz=1],i)=>{m.compose(new THREE.Vector3(x,y,z),new THREE.Quaternion(),new THREE.Vector3(sx,sy,sz));mesh.setMatrixAt(i,m);});mesh.instanceMatrix.needsUpdate=true;mesh.castShadow=mesh.receiveShadow=true;scene.add(mesh);return mesh;};
        const promenadeMat=new THREE.MeshStandardMaterial({color:0x8b7761,roughness:.76,metalness:.14}),curbMat=new THREE.MeshStandardMaterial({color:0x9f2028,roughness:.48,metalness:.35}),jointMat=new THREE.MeshStandardMaterial({color:0x222a2f,roughness:.3,metalness:.82}),reflectorMat=new THREE.MeshBasicMaterial({color:0xffd66e,toneMapped:false});
        const promenadeZ=[bridgeZ-bridgeDepth*.5+1.05,bridgeZ+bridgeDepth*.5-1.05];
        addBridgeInstances(new THREE.BoxGeometry(bridgeWidth-.9,.18,1.18),promenadeMat,promenadeZ.map(z=>[bridgeX,1.16,z]));
        addBridgeInstances(new THREE.BoxGeometry(bridgeWidth-.9,.28,.16),curbMat,promenadeZ.map((z,i)=>[bridgeX,1.27,z+(i?-.66:.66)]));
        addBridgeInstances(new THREE.BoxGeometry(.18,.045,bridgeDepth-4.1),jointMat,[canal.c0+.75,canal.c0+3.4,canal.c1-3.4,canal.c1-.75].map(c=>[toX(c),1.16,bridgeZ]));
        const reflectorPos=[];for(let c=canal.c0+.7;c<canal.c1;c+=1.45)for(const dz of [-bridgeDepth*.18,bridgeDepth*.18])reflectorPos.push([toX(c),1.22,bridgeZ+dz]);addBridgeInstances(new THREE.BoxGeometry(.34,.1,.16),reflectorMat,reflectorPos);
        const anchorPos=[];for(const c of [canal.c0-2.25,canal.c1+2.25])for(const z of [bridgeZ-bridgeDepth*.5+1.7,bridgeZ+bridgeDepth*.5-1.7])anchorPos.push([toX(c),1.35,z]);addBridgeInstances(new THREE.BoxGeometry(2.2,2.2,3.1),bridgeStoneMat,anchorPos);
        renderer.domElement.dataset.bridgeDetails='promenades-curbs-joints-reflectors-anchors-v198';
        // Photo-inspired red suspension pylons: tall paired legs, restrained gold crossbars and crisp steel bracing.
        const pylonDeckY=1.12,pylonTopY=24.5,addSuspensionPylon=c=>{const px=toX(c);for(const pz of towerEdgeZ){const foot=box(px,pz,2.35,2.35,1.05,bridgeStoneMat);foot.position.y=1.35;const leg=box(px,pz,1.34,1.48,pylonTopY-pylonDeckY,bridgeRedMat);leg.position.y=(pylonTopY+pylonDeckY)/2;outline(leg);const inner=box(px,pz,1.56,1.7,.32,bridgeGoldMat);inner.position.y=18.25;const beacon=new THREE.Mesh(new THREE.SphereGeometry(.24,12,8),bridgeRedGlowMat);beacon.position.set(px,pylonTopY+.55,pz);scene.add(beacon);}for(const y of [10.5,18.25,24.15]){const beam=box(px,bridgeZ,1.18,bridgeDepth-3.1,y===24.15?.72:.58,y===18.25?bridgeGoldMat:bridgeRedMat);beam.position.y=y;outline(beam);}for(const sign of [-1,1]){const diagonal=box(px,bridgeZ+sign*bridgeDepth*.23,.54,bridgeDepth*.42,.42,bridgeHangerMat);diagonal.position.y=14.4;diagonal.rotation.x=sign*.62;}const crown=box(px,bridgeZ,1.7,bridgeDepth-2.65,.3,bridgeGoldMat);crown.position.y=pylonTopY+.18;};
        suspensionTowerCs.forEach(addSuspensionPylon);
        const cableGroup=new THREE.Group();cableGroup.name='premium-suspension-cables';scene.add(cableGroup);const addCable=(points,radius,material,segments=Math.max(24,points.length*5))=>{const curve=new THREE.CatmullRomCurve3(points,false,'centripetal'),mesh=new THREE.Mesh(new THREE.TubeGeometry(curve,segments,radius,7,false),material);mesh.castShadow=true;cableGroup.add(mesh);return mesh;},towerX0=toX(suspensionTowerCs[0]),towerX1=toX(suspensionTowerCs[1]),anchorX0=toX(canal.c0-2.3),anchorX1=toX(canal.c1+2.3),cableTop=pylonTopY+.18,cableSag=5.65;
        for(const pz of towerEdgeZ){const points=[new THREE.Vector3(anchorX0,2.15,pz),new THREE.Vector3((anchorX0+towerX0)*.5,12.2,pz),new THREE.Vector3(towerX0,cableTop,pz)];for(let i=1;i<20;i++){const u=i/20,x=THREE.MathUtils.lerp(towerX0,towerX1,u),y=cableSag+(cableTop-cableSag)*Math.pow(Math.abs(u-.5)*2,2);points.push(new THREE.Vector3(x,y,pz));}points.push(new THREE.Vector3(towerX1,cableTop,pz),new THREE.Vector3((towerX1+anchorX1)*.5,12.2,pz),new THREE.Vector3(anchorX1,2.15,pz));addCable(points,.18,bridgeCableMat,96);for(let i=1;i<20;i++){const u=i/20,x=THREE.MathUtils.lerp(towerX0,towerX1,u),y=cableSag+(cableTop-cableSag)*Math.pow(Math.abs(u-.5)*2,2),height=Math.max(.22,y-1.72),hanger=new THREE.Mesh(new THREE.CylinderGeometry(.045,.045,height,6),bridgeHangerMat);hanger.position.set(x,1.72+height/2,pz);cableGroup.add(hanger);}}
        // Side stays, tower-top cross cables and fine deck edge lines complete the engineered silhouette.
        for(const [tx,ax] of [[towerX0,anchorX0],[towerX1,anchorX1]])for(const pz of towerEdgeZ)addCable([new THREE.Vector3(tx,cableTop,pz),new THREE.Vector3(THREE.MathUtils.lerp(tx,ax,.48),13.4,pz),new THREE.Vector3(ax,2.15,pz)],.13,bridgeCableMat,28);
        for(const tx of [towerX0,towerX1])addCable([new THREE.Vector3(tx,cableTop,towerEdgeZ[0]),new THREE.Vector3(tx,cableTop+.5,bridgeZ),new THREE.Vector3(tx,cableTop,towerEdgeZ[1])],.11,bridgeGoldMat,24);
        renderer.domElement.dataset.bridgeStyle='premium-red-suspension';
        // Warm promenade lighting, plus a restrained under-deck glow reflected by the canal.
        const lampPostGeometry=new THREE.CylinderGeometry(.1,.16,3.8,10),lampBulbGeometry=new THREE.SphereGeometry(.28,12,8);
        for(let c=canal.c0;c<=canal.c1;c+=2.6)for(const rr of [canal.bridge.r0+.48,canal.bridge.r1-.48]){const post=new THREE.Mesh(lampPostGeometry,bridgeDarkMat);post.position.set(toX(c),3.05,toZ(rr));scene.add(post);const bulb=new THREE.Mesh(lampBulbGeometry,bridgeGlowMat);bulb.position.set(toX(c),5.02,toZ(rr));scene.add(bulb);const crown=box(toX(c),toZ(rr),.72,.72,.12,bridgeGoldMat);crown.position.y=4.72;}
        for(const rr of [canal.bridge.r0+.24,canal.bridge.r1-.24]){const glow=box(bridgeX,toZ(rr),bridgeWidth-.8,.08,.1,bridgeGlowMat);glow.position.y=-.7;}
        for(const c of [canal.c0+2,canal.c0+7,canal.c1-7,canal.c1-2]){const light=new THREE.PointLight(c>(canal.c0+canal.c1)/2?0xff5a3d:0xffc46b,1.1,15,2);light.position.set(toX(c),5.1,bridgeZ);light.castShadow=false;scene.add(light);}
      }
      if(worldSnapshot?.coast){
        const coast=worldSnapshot.coast,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE,coastWidth=worldCols*WORLD_SCALE,coastCenter=worldCols*.5,coastDepth=(coast.water.r1-coast.water.r0)*WORLD_SCALE;
        const sandCanvas=document.createElement('canvas');sandCanvas.width=sandCanvas.height=512;const sandContext=sandCanvas.getContext('2d'),sandGradient=sandContext.createLinearGradient(0,0,0,512);sandGradient.addColorStop(0,'#d3a962');sandGradient.addColorStop(.34,'#e5c27d');sandGradient.addColorStop(1,'#f0d693');sandContext.fillStyle=sandGradient;sandContext.fillRect(0,0,512,512);let sandSeed=918273;const sandRand=()=>((sandSeed=Math.imul(sandSeed,1664525)+1013904223|0)>>>0)/4294967296;for(let i=0;i<4100;i++){const x=sandRand()*512,y=sandRand()*512,r=.35+sandRand()*1.25;sandContext.fillStyle=sandRand()>.48?'rgba(116,77,36,.18)':'rgba(255,243,193,.24)';sandContext.beginPath();sandContext.arc(x,y,r,0,Math.PI*2);sandContext.fill();}sandContext.strokeStyle='rgba(135,91,44,.16)';sandContext.lineWidth=2;for(let y=25;y<510;y+=31){sandContext.beginPath();for(let x=0;x<=512;x+=8){const yy=y+Math.sin(x*.055+y*.03)*3.2;x?sandContext.lineTo(x,yy):sandContext.moveTo(x,yy);}sandContext.stroke();}const sandTexture=new THREE.CanvasTexture(sandCanvas);sandTexture.colorSpace=THREE.SRGBColorSpace;sandTexture.wrapS=sandTexture.wrapT=THREE.RepeatWrapping;sandTexture.repeat.set(Math.max(8,worldCols/8),7);sandTexture.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());sandTexture.needsUpdate=true;
        const sandMat=new THREE.MeshStandardMaterial({color:0xf0cf88,map:sandTexture,bumpMap:sandTexture,bumpScale:.16,roughness:.94,metalness:.015,envMap:cityEnvironment,envMapIntensity:.16}),dryEdgeMat=new THREE.MeshStandardMaterial({color:0xc69a5b,map:sandTexture,bumpMap:sandTexture,bumpScale:.1,roughness:.98,metalness:0,envMap:cityEnvironment,envMapIntensity:.08,transparent:true,opacity:.88}),wetSandMat=new THREE.MeshPhysicalMaterial({color:0x9b7548,map:sandTexture,roughness:.38,metalness:.05,clearcoat:.35,clearcoatRoughness:.22,envMap:cityEnvironment,envMapIntensity:.7}),woodMat=new THREE.MeshStandardMaterial({color:0x775036,roughness:.8}),shipMat=new THREE.MeshStandardMaterial({color:0x253845,roughness:.5,metalness:.35});
        // An irregular ribbon avoids the old endless rectangular strip at the city edge.
        const makeBeachRibbon=(rSouth,inset,material,y)=>{const segments=Math.max(48,Math.ceil(worldCols*1.25)),positions=[],uvs=[],indices=[];for(let i=0;i<=segments;i++){const u=i/segments,c=worldCols*u,wave=Math.sin(u*Math.PI*6.2)*.72+Math.sin(u*Math.PI*15.7+.8)*.28+Math.sin(u*Math.PI*2.1+1.9)*.46,north=coast.beach.r0+inset+wave;positions.push(toX(c),0,toZ(north),toX(c),0,toZ(rSouth));uvs.push(u,0,u,1);}for(let i=0;i<segments;i++){const a=i*2;indices.push(a,a+1,a+2,a+2,a+1,a+3);}const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));geometry.setIndex(indices);geometry.computeVertexNormals();const mesh=new THREE.Mesh(geometry,material);mesh.position.y=y;mesh.receiveShadow=true;scene.add(mesh);return mesh;};
        const beachShoulder=makeBeachRibbon(coast.beach.r0+.95,-1.65,dryEdgeMat,.039),beach=makeBeachRibbon(coast.beach.r1,0,sandMat,.04);
        const trackMat=new THREE.MeshBasicMaterial({color:0x8f663d,transparent:true,opacity:.18,depthWrite:false}),trackGeo=new THREE.PlaneGeometry(coastWidth*.94,.22);for(const offset of [-2.25,2.25]){const track=new THREE.Mesh(trackGeo,trackMat);track.rotation.x=-Math.PI/2;track.rotation.z=.006;track.position.set(toX(coastCenter),.072,toZ(coast.beach.r0+5.2)+offset);scene.add(track);}
        const wetSand=new THREE.Mesh(new THREE.PlaneGeometry(coastWidth,2.2*WORLD_SCALE,90,2),wetSandMat);wetSand.rotation.x=-Math.PI/2;wetSand.position.set(toX(coastCenter),.075,toZ(coast.beach.r1-1.08));wetSand.receiveShadow=true;scene.add(wetSand);
        waterUniforms={uTime:{value:0},uShallow:{value:new THREE.Color(0x23a8b6)},uMid:{value:new THREE.Color(0x087395)},uDeep:{value:new THREE.Color(0x063d62)},uSun:{value:new THREE.Color(0x9beaff)},uOpacity:{value:.94}};
        const waterMat=new THREE.ShaderMaterial({uniforms:waterUniforms,transparent:true,depthWrite:false,side:THREE.DoubleSide,vertexShader:`uniform float uTime;varying vec2 vUv;varying float vWave;void main(){vUv=uv;vec3 p=position;float shore=pow(clamp(1.0-uv.y,0.0,1.0),.35);float a=sin(p.x*.045+uTime*1.25)+sin(p.y*.082-uTime*.92)*.55+sin((p.x+p.y)*.021+uTime*.48)*.72;p.z=a*(.16+.22*shore);vWave=a;gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);}`,fragmentShader:`uniform float uTime;uniform vec3 uShallow;uniform vec3 uMid;uniform vec3 uDeep;uniform vec3 uSun;uniform float uOpacity;varying vec2 vUv;varying float vWave;void main(){float depth=clamp(1.0-vUv.y,0.0,1.0);vec3 col=mix(uShallow,uMid,smoothstep(.02,.28,depth));col=mix(col,uDeep,smoothstep(.38,1.0,depth));float ripple=sin(vUv.x*620.0+uTime*2.2+sin(vUv.y*84.0))*0.5+0.5;col+=uSun*(.035+.11*pow(max(0.0,vWave*.42+ripple*.38),4.0));float shoreBand=exp(-pow((vUv.y-(.955+sin(vUv.x*24.0+uTime*.75)*.012))*75.0,2.0));float foam=shoreBand*(.45+.55*sin(vUv.x*410.0-uTime*3.2)*sin(vUv.x*91.0+uTime));col=mix(col,vec3(.86,.97,.94),clamp(foam*.72,0.0,.78));gl_FragColor=vec4(col,uOpacity);
#include <tonemapping_fragment>
#include <colorspace_fragment>
}`});
        // The global city ground is asphalt and receives large moving shadows.
        // A transparent ocean used to reveal that black layer as giant drifting
        // polygons near the shore. An opaque, shadow-free seabed now isolates
        // the water visually; animated waves remain a separate layer above it.
        const seabedMat=new THREE.MeshBasicMaterial({color:0x087b9d,depthWrite:true,toneMapped:true}),seabed=new THREE.Mesh(new THREE.PlaneGeometry(coastWidth,coastDepth),seabedMat);seabed.rotation.x=-Math.PI/2;seabed.position.set(toX(coastCenter),.052,toZ((coast.water.r0+coast.water.r1)/2));seabed.receiveShadow=false;seabed.renderOrder=0;scene.add(seabed);
        const water=new THREE.Mesh(new THREE.PlaneGeometry(coastWidth,coastDepth,96,32),waterMat);water.rotation.x=-Math.PI/2;water.position.set(toX(coastCenter),.09,toZ((coast.water.r0+coast.water.r1)/2));water.receiveShadow=false;water.renderOrder=1;scene.add(water);waterSurface=water;renderer.domElement.dataset.coastWaterBase='opaque-shadow-free-seabed';
        const pier=box(toX((coast.pier.c0+coast.pier.c1)/2),toZ((coast.pier.r0+coast.pier.r1)/2),(coast.pier.c1-coast.pier.c0)*WORLD_SCALE,(coast.pier.r1-coast.pier.r0)*WORLD_SCALE,.55,woodMat);pier.position.y=.28;
        const ship=box(toX((coast.ship.c0+coast.ship.c1)/2),toZ((coast.ship.r0+coast.ship.r1)/2),(coast.ship.c1-coast.ship.c0)*WORLD_SCALE,(coast.ship.r1-coast.ship.r0)*WORLD_SCALE,3.3,shipMat);outline(ship);
        const deck=box(ship.position.x,ship.position.z-2,38,17,4.5,new THREE.MeshStandardMaterial({color:0xe7e1d1,roughness:.7}));deck.position.y=4.3;outline(deck);
        const palmTrunk=windTrunkMaterial(0x754b2e),palmLeaf=windLeafMaterial(0x218f5a);
        const addPalm=(r,c,s=1)=>{const g=new THREE.Group();const trunk=new THREE.Mesh(new THREE.CylinderGeometry(.32*s,.52*s,6.4*s,9),palmTrunk);trunk.position.y=3.2*s;trunk.castShadow=true;g.add(trunk);for(let i=0;i<8;i++){const leaf=new THREE.Mesh(new THREE.ConeGeometry(.55*s,4*s,5),palmLeaf);leaf.position.y=6.5*s;leaf.rotation.z=Math.PI/2.35;leaf.rotation.y=i*Math.PI/4;leaf.position.x=Math.cos(leaf.rotation.y)*1.05*s;leaf.position.z=Math.sin(leaf.rotation.y)*1.05*s;leaf.castShadow=true;g.add(leaf);}g.position.set(toX(c),0,toZ(r));scene.add(g);};
        for(let c=7;c<76;c+=8)addPalm(154+(c%3),c,.82+(c%5)*.035);
        const promenadeMat=new THREE.MeshStandardMaterial({color:0xcaa77b,roughness:.9}),benchMat=new THREE.MeshStandardMaterial({color:0x8a532f,roughness:.78}),metalMat=new THREE.MeshStandardMaterial({color:0x2e3c43,roughness:.48,metalness:.55});
        const promenade=new THREE.Mesh(new THREE.PlaneGeometry(Math.max(24,coastWidth-WORLD_SCALE*4),WORLD_SCALE*4),promenadeMat);promenade.rotation.x=-Math.PI/2;promenade.position.set(toX(coastCenter),.1,toZ(152));promenade.receiveShadow=true;scene.add(promenade);
        for(let c=8;c<74;c+=11){const x=toX(c),z=toZ(153);const seat=box(x,z,4,.72,.3,benchMat);seat.position.y=1.05;for(const dx of [-1.45,1.45]){const leg=box(x+dx,z,.22,.5,1,metalMat);leg.position.y=.5;}const lampPost=new THREE.Mesh(new THREE.CylinderGeometry(.12,.18,5.2,8),metalMat);lampPost.position.set(x+3.4,2.6,z);scene.add(lampPost);const lampBulb=new THREE.Mesh(new THREE.SphereGeometry(.34,10,7),new THREE.MeshBasicMaterial({color:0xffce75}));lampBulb.position.set(x+3.4,5.3,z);scene.add(lampBulb);}
        const umbrellaColors=[0xff5d62,0x36b8d4,0xffc74e,0x64c887];for(let i=0;i<12;i++){const r=158+(i%3)*2.1,c=8+Math.floor(i/3)*19+(i%2)*3,x=toX(c),z=toZ(r),pole=new THREE.Mesh(new THREE.CylinderGeometry(.07,.09,2.5,7),metalMat);pole.position.set(x,1.25,z);scene.add(pole);const shade=new THREE.Mesh(new THREE.ConeGeometry(2.2,.9,14),new THREE.MeshStandardMaterial({color:umbrellaColors[i%4],roughness:.7}));shade.position.set(x,2.65,z);shade.castShadow=true;scene.add(shade);}
        const beachBar=box(toX(68),toZ(156),14,8,4.2,new THREE.MeshStandardMaterial({color:0x3e5960,roughness:.68}));outline(beachBar);const barAwning=box(toX(68),toZ(157.8),12,2,.28,new THREE.MeshBasicMaterial({color:0x20dfbd}));barAwning.position.y=3.2;const barLight=new THREE.PointLight(0x20dfbd,18,24,2);barLight.position.set(toX(68),4,toZ(158));scene.add(barLight);
        for(const [i,d] of (coast.decor||[]).entries()){if(['palm','big_palm','umbrella','tiki_bar','beach_lamp','sand_path','grass','starfish','shell','crab','puddle'].includes(d.kind))continue;const x=toX(d.c),z=toZ(d.r),color=d.col||['#e75d55','#46a9d8','#f3ca54','#62bd75'][i%4],mat=new THREE.MeshStandardMaterial({color,roughness:.72});if(d.kind==='towel'){const towel=new THREE.Mesh(new THREE.PlaneGeometry(2.4,4),mat);towel.rotation.x=-Math.PI/2;towel.rotation.z=d.ang;towel.position.set(x,.13,z);scene.add(towel);}else if(d.kind==='chair'){const chair=box(x,z,1.4,1.6,.3,mat);chair.position.y=.65;chair.rotation.y=d.ang;const back=box(x,z-.65,1.4,.22,1.5,mat);back.position.y=1.05;back.rotation.y=d.ang;}else if(d.kind==='surfboard'){const board=new THREE.Mesh(new THREE.CapsuleGeometry(.42,2.4,6,12),mat);board.scale.set(1,.18,1);board.rotation.z=Math.PI/2+d.ang;board.position.set(x,.28,z);scene.add(board);}else if(d.kind==='ball'){const ball=new THREE.Mesh(new THREE.SphereGeometry(.55,14,10),mat);ball.position.set(x,.58,z);ball.castShadow=true;scene.add(ball);}else if(d.kind==='sandcastle'){const castle=new THREE.Mesh(new THREE.ConeGeometry(1.05,1.6,8),new THREE.MeshStandardMaterial({color:0xc89857,roughness:1}));castle.position.set(x,.8,z);scene.add(castle);}else if(d.kind==='boat'){const hull=box(x,z,5.5,2.2,1.1,mat);hull.position.y=.65;hull.rotation.y=d.ang;}else if(d.kind==='lifeguard'){const platform=box(x,z,3.6,3.2,.4,new THREE.MeshStandardMaterial({color:0xf0e2bd,roughness:.8}));platform.position.y=3.4;for(const dx of [-1.3,1.3])for(const dz of [-1.1,1.1]){const leg=box(x+dx,z+dz,.22,.22,3.4,metalMat);leg.position.y=1.7;}}else if(d.kind==='volleyball'){for(const dx of [-4,4]){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.08,.12,4,8),metalMat);pole.position.set(x+dx,2,z);scene.add(pole);}const net=box(x,z,8,.1,2,new THREE.MeshBasicMaterial({color:0xf3eee1,wireframe:true}));net.position.y=2;}else if(d.kind==='icecream_cart'){const cart=box(x,z,3,1.8,1.4,new THREE.MeshStandardMaterial({color:0xe8d7b2,roughness:.65}));cart.position.y=1;const canopy=box(x,z,3.4,2.2,.25,new THREE.MeshBasicMaterial({color:0xff5f75}));canopy.position.y=2.35;}else if(d.kind==='float_ring'){const ring=new THREE.Mesh(new THREE.TorusGeometry(.75,.22,8,18),mat);ring.rotation.x=Math.PI/2;ring.position.set(x,.18,z);scene.add(ring);}}
        // Fine beach relief: deterministic pebbles and shell fragments stay
        // sharp without creating hundreds of separate draw calls.
        const pebbleCount=180,pebbleMat=new THREE.MeshStandardMaterial({color:0x9e774d,roughness:1,vertexColors:true}),pebbles=new THREE.InstancedMesh(new THREE.IcosahedronGeometry(.18,1),pebbleMat,pebbleCount),pebbleMatrix=new THREE.Matrix4(),pebbleColor=new THREE.Color();for(let i=0;i<pebbleCount;i++){const c=2+((i*47.31)%Math.max(4,worldCols-4)),r=coast.beach.r0+2+((i*19.77)%Math.max(3,coast.beach.r1-coast.beach.r0-3)),scale=.45+(i%7)*.1;pebbleMatrix.compose(new THREE.Vector3(toX(c),.12,toZ(r)),new THREE.Quaternion().setFromEuler(new THREE.Euler(i*.31,i*.73,0)),new THREE.Vector3(scale,.3*scale,scale));pebbles.setMatrixAt(i,pebbleMatrix);pebbleColor.setHex([0xb58d5b,0xe3c58d,0x826448,0xc9a46e][i%4]);pebbles.setColorAt(i,pebbleColor);}pebbles.instanceMatrix.needsUpdate=true;pebbles.instanceColor.needsUpdate=true;pebbles.receiveShadow=true;scene.add(pebbles);
        const marine=coast.marine||{},marineGroup=new THREE.Group();scene.add(marineGroup);const buoyMat=new THREE.MeshStandardMaterial({color:0xe44036,roughness:.42,metalness:.18}),buoyWhiteMat=new THREE.MeshStandardMaterial({color:0xf4efe2,roughness:.55}),buoyDarkMat=new THREE.MeshStandardMaterial({color:0x25343b,roughness:.38,metalness:.68}),ringRedMat=new THREE.MeshStandardMaterial({color:0xe73f35,roughness:.5}),foamMat=new THREE.MeshBasicMaterial({color:0xdffcff,transparent:true,opacity:.78,depthWrite:false,toneMapped:false}),fishMat=new THREE.MeshStandardMaterial({color:0x3ec6b3,roughness:.35,metalness:.18}),dolphinMat=new THREE.MeshStandardMaterial({color:0x55879b,roughness:.38,metalness:.12}),birdMat=new THREE.MeshStandardMaterial({color:0xe8e6df,roughness:.72,side:THREE.DoubleSide}),birdDarkMat=new THREE.MeshStandardMaterial({color:0x39434c,roughness:.7,side:THREE.DoubleSide});
        const buoyActors=(marine.buoys||[]).map((q,i)=>{const g=new THREE.Group(),float=new THREE.Mesh(new THREE.CylinderGeometry(.42,.58,1.05,14),i%2?buoyMat:buoyWhiteMat);float.position.y=.5;g.add(float);const stripe=new THREE.Mesh(new THREE.CylinderGeometry(.45,.52,.28,14),i%2?buoyWhiteMat:buoyMat);stripe.position.y=.55;g.add(stripe);const mast=new THREE.Mesh(new THREE.CylinderGeometry(.07,.1,1.3,8),buoyDarkMat);mast.position.y=1.55;g.add(mast);const cap=new THREE.Mesh(new THREE.SphereGeometry(.16,10,7),new THREE.MeshBasicMaterial({color:i%2?0xffd05b:0xff4a3f,toneMapped:false}));cap.position.y=2.18;g.add(cap);g.position.set(toX(q.c),.02,toZ(q.r));g.userData={baseX:g.position.x,baseZ:g.position.z,seed:q.seed||i};marineGroup.add(g);return g;});
        if((marine.buoys||[]).length>1){const pts=(marine.buoys||[]).map(q=>new THREE.Vector3(toX(q.c),.13,toZ(q.r))),rope=new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts),new THREE.LineBasicMaterial({color:0xe9e0c7,transparent:true,opacity:.58}));marineGroup.add(rope);}
        const ringActors=(marine.rings||[]).map((q,i)=>{const g=new THREE.Group(),ring=new THREE.Mesh(new THREE.TorusGeometry(.78,.21,9,24),ringRedMat);ring.rotation.x=Math.PI/2;g.add(ring);for(let k=0;k<4;k++){const band=new THREE.Mesh(new THREE.BoxGeometry(.32,.13,.5),buoyWhiteMat);band.position.set(Math.cos(k*Math.PI/2)*.69,.02,Math.sin(k*Math.PI/2)*.69);band.rotation.y=-k*Math.PI/2;g.add(band);}g.position.set(toX(q.c),.22,toZ(q.r));g.userData={baseX:g.position.x,baseZ:g.position.z,seed:q.seed||i};marineGroup.add(g);return g;});
        const makeSplash=()=>{const g=new THREE.Group(),ring=new THREE.Mesh(new THREE.TorusGeometry(.9,.055,7,28),foamMat.clone());ring.rotation.x=Math.PI/2;g.add(ring);for(let i=0;i<7;i++){const drop=new THREE.Mesh(new THREE.SphereGeometry(.07,7,5),foamMat.clone());drop.position.set(Math.cos(i*.9)*.5,.2+(i%3)*.17,Math.sin(i*.9)*.5);g.add(drop);}g.userData.ring=ring;return g;};
        const fishActors=(marine.fish||[]).map((q,i)=>{const root=new THREE.Group(),fish=new THREE.Group(),body=new THREE.Mesh(new THREE.CapsuleGeometry(.2,.75,5,9),fishMat);body.rotation.z=Math.PI/2;fish.add(body);const tail=new THREE.Mesh(new THREE.ConeGeometry(.32,.52,3),fishMat);tail.rotation.z=-Math.PI/2;tail.position.x=-.62;fish.add(tail);root.add(fish);const splash=makeSplash();root.add(splash);root.position.set(toX(q.c),.16,toZ(q.r));root.userData={fish,splash,baseX:root.position.x,baseZ:root.position.z,seed:q.seed||i};marineGroup.add(root);return root;});
        const dolphinActors=(marine.dolphins||[]).map((q,i)=>{const root=new THREE.Group(),animal=new THREE.Group(),body=new THREE.Mesh(new THREE.CapsuleGeometry(.48,2.1,7,14),dolphinMat);body.rotation.z=Math.PI/2;animal.add(body);const snout=new THREE.Mesh(new THREE.ConeGeometry(.2,.75,10),dolphinMat);snout.rotation.z=-Math.PI/2;snout.position.x=1.72;animal.add(snout);const fin=new THREE.Mesh(new THREE.ConeGeometry(.35,.82,3),dolphinMat);fin.position.set(0,.5,0);fin.rotation.z=Math.PI;animal.add(fin);for(const sy of [-1,1]){const tail=new THREE.Mesh(new THREE.ConeGeometry(.42,.9,3),dolphinMat);tail.rotation.z=sy*Math.PI*.42;tail.position.set(-1.65,sy*.32,0);animal.add(tail);}root.add(animal);const splash=makeSplash();splash.scale.setScalar(1.55);root.add(splash);root.position.set(toX(q.c),.1,toZ(q.r));root.userData={animal,splash,baseX:root.position.x,baseZ:root.position.z,seed:q.seed||i};marineGroup.add(root);return root;});
        const birdActors=(marine.birds||[]).map((q,i)=>{const root=new THREE.Group(),body=new THREE.Mesh(new THREE.SphereGeometry(.28,10,7),i%3?birdMat:birdDarkMat);body.scale.set(1.65,.75,.72);root.add(body);const head=new THREE.Mesh(new THREE.SphereGeometry(.16,9,6),birdMat);head.position.set(.42,.08,0);root.add(head);const beak=new THREE.Mesh(new THREE.ConeGeometry(.065,.32,6),new THREE.MeshStandardMaterial({color:0xe9a83e,roughness:.7}));beak.rotation.z=-Math.PI/2;beak.position.set(.65,.06,0);root.add(beak);const wingGeo=new THREE.BufferGeometry();wingGeo.setAttribute('position',new THREE.Float32BufferAttribute([0,0,0,-.72,.08,.2,-.18,.02,.04],3));wingGeo.computeVertexNormals();const left=new THREE.Mesh(wingGeo,birdMat),right=new THREE.Mesh(wingGeo.clone(),birdMat);left.position.z=.06;right.position.z=-.06;right.scale.z=-1;root.add(left,right);root.position.set(toX(q.c),.45,toZ(q.r));root.userData={left,right,baseX:root.position.x,baseZ:root.position.z,seed:q.seed||i};marineGroup.add(root);return root;});
        coastalAnimation=(t,lowFps=false)=>{const sec=t*.001,px=player.position.x,pz=player.position.z,near=o=>(o.position.x-px)**2+(o.position.z-pz)**2<155**2;waterUniforms.uTime.value=sec;waterUniforms.uOpacity.value=.91+Math.sin(sec*.7)*.025;buoyActors.forEach((g,i)=>{g.visible=near(g);if(!g.visible)return;const s=sec+g.userData.seed*.37;g.position.y=.16+Math.sin(s*1.7)*.16;g.rotation.z=Math.sin(s*1.21)*.055;g.rotation.x=Math.cos(s*1.48)*.035;});ringActors.forEach(g=>{g.visible=near(g);if(!g.visible)return;const s=sec+g.userData.seed;g.position.y=.2+Math.sin(s*1.45)*.11;g.position.x=g.userData.baseX+Math.sin(s*.28)*.75;g.position.z=g.userData.baseZ+Math.cos(s*.31)*.48;g.rotation.z=s*.08;});if(!lowFps||Math.floor(t/50)%2===0)fishActors.forEach(g=>{g.visible=near(g);if(!g.visible)return;const cycle=8+(g.userData.seed%5),phase=(sec+g.userData.seed*1.71)%cycle,active=phase<1.18,u=Math.min(1,phase/1.18);g.userData.fish.visible=active;g.userData.splash.visible=active&&(u<.25||u>.78);if(active){g.position.x=g.userData.baseX+(u-.5)*3.4;g.position.y=.1+Math.sin(u*Math.PI)*1.7;g.userData.fish.rotation.z=-.7+u*1.4;const pulse=u<.25?u/.25:(1-u)/.22;g.userData.splash.scale.setScalar(Math.max(.05,pulse*1.6));g.userData.splash.children.forEach((p,k)=>{if(k)p.position.y=.12+Math.max(0,pulse)*(.18+(k%3)*.16);});}});dolphinActors.forEach(g=>{g.visible=near(g);if(!g.visible)return;const cycle=19+(g.userData.seed%7),phase=(sec+g.userData.seed*2.13)%cycle,active=phase<2.65,u=Math.min(1,phase/2.65);g.userData.animal.visible=active;g.userData.splash.visible=active&&(u<.18||u>.82);if(active){g.position.x=g.userData.baseX+(u-.5)*8;g.position.y=.05+Math.sin(u*Math.PI)*4.1;g.position.z=g.userData.baseZ+Math.sin(u*Math.PI*2)*.8;g.userData.animal.rotation.z=-.95+u*1.9;const pulse=u<.18?u/.18:(1-u)/.18;g.userData.splash.scale.setScalar(Math.max(.05,pulse*2.1));}});birdActors.forEach((g,i)=>{const cycle=14+(g.userData.seed%9),phase=(sec+g.userData.seed*.41)%cycle,landed=phase>cycle*.72,flight=phase/(cycle*.72),wing=Math.sin(sec*9+i)*.72;g.visible=((g.userData.baseX-px)**2+(g.userData.baseZ-pz)**2<185**2);if(!g.visible)return;if(landed){g.position.set(g.userData.baseX,.4+Math.sin(sec*2+i)*.025,g.userData.baseZ);g.rotation.y=Math.sin(sec*.33+i)*.8;g.userData.left.rotation.x=.12;g.userData.right.rotation.x=-.12;}else{const radius=9+(i%4)*3,a=flight*Math.PI*2+i*.8;g.position.set(g.userData.baseX+Math.cos(a)*radius,5.5+(i%3)*1.8+Math.sin(a*2)*1.2,g.userData.baseZ+Math.sin(a)*radius*.65);g.rotation.y=-a;g.userData.left.rotation.x=wing;g.userData.right.rotation.x=-wing;}});};
        coast.containers.forEach((q,i)=>{const color=coast.containerColors[q.presetIndex]||'#c45b3d';const container=box(toX(q.c),toZ(q.r),q.w*2*WORLD_SCALE,q.h*2*WORLD_SCALE,q.height*WORLD_SCALE,new THREE.MeshStandardMaterial({color,roughness:.58,metalness:.32}));container.position.y=q.height*WORLD_SCALE/2+.4;if(q.stackIndex>=0){const top=container.clone();top.material=new THREE.MeshStandardMaterial({color:coast.containerColors[q.stackIndex]||'#3b79a8',roughness:.58,metalness:.32});top.position.y+=q.height*WORLD_SCALE;scene.add(top);}});
      }
      let refreshCustomGangHqs=()=>{},refreshBusinessOwnership=()=>{},casinoExteriorAnimation=()=>{};
      const authoredLandmarkStaticDetails=[],bankExteriors=[],bankDoorActors=[];
      // Architectural heights are also consumed by streamed city buildings
      // below, so keep the table in the renderer scope rather than inside the
      // optional landmarks branch. Otherwise 3D crashes before its first frame.
      const architecturalHeights={pizza:7,coffee:8,carwash:5.8,barbershop:8,garage:6.4,bar:8.5,club:10,warehouse:7.2,port:7,casino:13,hospital:12,hospital_east:12,firestation:7.5,junkyard:4.5,police:10,mafia_hq:38,market:8,factory:9,mansion:12,gym:9,job_office:10,blackmarket:8,blackmarket_bellini:9,blackmarket_moretti:9};
      // Building architecture and landmarks share the same premium roof signs.
      // Keep this factory outside the optional landmarks branch so streamed
      // themed buildings can create labels before landmarks are processed.
      const labelSprite=(text,color='#65e7ff')=>{
        const label=String(text).slice(0,28),cv=document.createElement('canvas');cv.width=896;cv.height=224;
        const c=cv.getContext('2d');c.clearRect(0,0,896,224);
        c.fillStyle='rgba(10,17,27,.96)';c.fillRect(12,16,872,192);
        c.strokeStyle='rgba(3,6,11,.96)';c.lineWidth=16;c.strokeRect(17,21,862,182);
        c.strokeStyle=color;c.lineWidth=7;c.strokeRect(21,25,854,174);
        c.fillStyle=color;c.fillRect(35,39,826,7);
        let fontSize=92;c.textAlign='center';c.textBaseline='middle';
        do{c.font=`850 ${fontSize}px system-ui, Arial, sans-serif`;if(c.measureText(label).width<=790)break;fontSize-=4;}while(fontSize>60);
        c.lineJoin='round';c.strokeStyle='rgba(0,0,0,.94)';c.lineWidth=10;c.strokeText(label,448,126);
        c.fillStyle='#fff2cf';c.fillText(label,448,126);
        const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());tx.generateMipmaps=false;tx.minFilter=THREE.LinearFilter;tx.magFilter=THREE.LinearFilter;tx.needsUpdate=true;
        const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:tx,transparent:true,depthTest:false,depthWrite:false,alphaTest:.04,toneMapped:false}));
        sprite.scale.set(Math.min(13.8,Math.max(9.5,7.4+label.length*.3)),2.55,1);sprite.renderOrder=58;sprite.userData.buildingLabel=true;return sprite;
      };
      // Exterior names are part of the building, not camera-facing HUD sprites.
      // The opaque board, rim and roof posts keep one stable sign attached to the roof.
      const roofSignTextureCache=new Map(),roofMountedSign=(text,color='#65e7ff',width=11,height=1.75)=>{
        const label=String(text).slice(0,32),key=`${label}|${color}`,cached=roofSignTextureCache.get(key);let tx=cached;
        if(!tx){const cv=document.createElement('canvas');cv.width=1024;cv.height=256;const c=cv.getContext('2d');c.fillStyle='#0a111b';c.fillRect(0,0,cv.width,cv.height);c.strokeStyle=color;c.lineWidth=18;c.strokeRect(15,15,cv.width-30,cv.height-30);let fontSize=112;c.textAlign='center';c.textBaseline='middle';do{c.font=`900 ${fontSize}px system-ui, Arial, sans-serif`;if(c.measureText(label).width<=900)break;fontSize-=5;}while(fontSize>58);c.lineJoin='round';c.strokeStyle='rgba(0,0,0,.96)';c.lineWidth=12;c.strokeText(label,cv.width/2,cv.height/2+5);c.fillStyle='#fff2cf';c.fillText(label,cv.width/2,cv.height/2+5);tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());tx.generateMipmaps=true;tx.minFilter=THREE.LinearMipmapLinearFilter;tx.magFilter=THREE.LinearFilter;roofSignTextureCache.set(key,tx);}
        const root=new THREE.Group(),boardMat=new THREE.MeshStandardMaterial({color:0x101720,roughness:.4,metalness:.62}),rimMat=new THREE.MeshStandardMaterial({color:new THREE.Color(color),roughness:.34,metalness:.55,emissive:new THREE.Color(color).multiplyScalar(.16),emissiveIntensity:.32}),faceMat=new THREE.MeshBasicMaterial({map:tx,transparent:false,toneMapped:false});
        const board=new THREE.Mesh(new THREE.BoxGeometry(width,height,.28),boardMat);board.position.y=height*.5+.62;board.castShadow=true;board.receiveShadow=true;root.add(board);const face=new THREE.Mesh(new THREE.PlaneGeometry(width-.28,height-.24),faceMat);face.position.set(0,height*.5+.62,.146);root.add(face);
        for(const sx of [-width*.39,width*.39]){const post=new THREE.Mesh(new THREE.BoxGeometry(.16,.72,.16),rimMat);post.position.set(sx,.36,0);post.castShadow=true;root.add(post);}for(const yy of [.62,.62+height]){const rail=new THREE.Mesh(new THREE.BoxGeometry(width+.18,.11,.38),rimMat);rail.position.set(0,yy,0);rail.castShadow=true;root.add(rail);}root.userData={buildingSign:true,label};return root;
      };
      const apartmentLabelSprite=(title,subtitle,color='#e5c66b')=>{
        const heading=String(title||'КВАРТИРА').trim().slice(0,24),detail=String(subtitle||'ГОРОД').trim().slice(0,34),cv=document.createElement('canvas');cv.width=1280;cv.height=384;
        const c=cv.getContext('2d');c.clearRect(0,0,cv.width,cv.height);
        const bg=c.createLinearGradient(0,24,0,360);bg.addColorStop(0,'rgba(22,28,38,.985)');bg.addColorStop(1,'rgba(7,11,18,.985)');c.fillStyle=bg;c.fillRect(24,22,1232,338);
        c.strokeStyle='rgba(2,5,10,.98)';c.lineWidth=22;c.strokeRect(34,32,1212,318);c.strokeStyle=color;c.lineWidth=8;c.strokeRect(47,45,1186,292);
        c.fillStyle=color;c.fillRect(64,64,1152,10);c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';
        let headingSize=116;do{c.font=`900 ${headingSize}px Georgia, serif`;if(c.measureText(heading).width<=1080)break;headingSize-=4;}while(headingSize>78);
        c.strokeStyle='rgba(0,0,0,.96)';c.lineWidth=14;c.strokeText(heading,640,158);c.fillStyle='#fff1c8';c.fillText(heading,640,158);
        let detailSize=64;do{c.font=`850 ${detailSize}px system-ui, Arial, sans-serif`;if(c.measureText(detail).width<=1080)break;detailSize-=3;}while(detailSize>46);
        c.fillStyle=color;c.fillRect(246,224,788,3);c.strokeStyle='rgba(0,0,0,.96)';c.lineWidth=10;c.strokeText(detail,640,278);c.fillStyle='#f5e7c6';c.fillText(detail,640,278);
        const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());tx.generateMipmaps=false;tx.minFilter=THREE.LinearFilter;tx.magFilter=THREE.LinearFilter;tx.needsUpdate=true;
        const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:tx,transparent:true,depthTest:false,depthWrite:false,alphaTest:.035,toneMapped:false}));sprite.scale.set(17.5,5.25,1);sprite.renderOrder=59;sprite.userData.buildingLabel=true;return sprite;
      };
      const brigadirSpeechSprite=()=>{
        const cv=document.createElement('canvas');cv.width=1024;cv.height=272;
        const c=cv.getContext('2d'),tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());tx.generateMipmaps=false;tx.minFilter=THREE.LinearFilter;tx.magFilter=THREE.LinearFilter;
        const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:tx,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}));sprite.scale.set(19.2,5.1,1);sprite.renderOrder=61;sprite.visible=false;
        let last='';sprite.userData.setText=value=>{const text=String(value||'').trim().slice(0,96);if(text===last)return;last=text;c.clearRect(0,0,1024,272);if(!text){sprite.visible=false;tx.needsUpdate=true;return;}
          const bg=c.createLinearGradient(0,20,0,228);bg.addColorStop(0,'rgba(38,22,20,.98)');bg.addColorStop(1,'rgba(10,12,17,.98)');c.fillStyle=bg;c.fillRect(24,20,976,208);c.strokeStyle='#0b0909';c.lineWidth=18;c.strokeRect(31,27,962,194);c.strokeStyle='#d5ad57';c.lineWidth=6;c.strokeRect(39,35,946,178);c.fillStyle='#861f28';c.fillRect(43,39,938,34);c.fillStyle='#f7d98c';c.font='900 30px Georgia,serif';c.textAlign='left';c.textBaseline='middle';c.fillText('БРИГАДИР',67,56);c.fillStyle='#d5ad57';c.beginPath();c.moveTo(450,228);c.lineTo(512,266);c.lineTo(574,228);c.closePath();c.fill();
          c.font='850 58px system-ui,Arial,sans-serif';c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';const words=text.split(/\s+/),lines=[''];for(const word of words){const i=lines.length-1,next=(lines[i]+' '+word).trim();if(c.measureText(next).width>870&&lines.length<2)lines.push(word);else lines[i]=next;}const ys=lines.length===1?[150]:[126,186];for(let i=0;i<lines.length;i++){c.strokeStyle='rgba(0,0,0,.94)';c.lineWidth=11;c.strokeText(lines[i],512,ys[i]);c.fillStyle='#fff2cf';c.fillText(lines[i],512,ys[i]);}sprite.visible=true;tx.needsUpdate=true;renderer.domElement.dataset.brigadirSpeechProfile='large-readable-v201';};
        return sprite;
      };
      // Shared 3D presentation layer for gameplay objects that used to exist
      // only on the hidden Canvas. The bridge keeps authoritative coordinates
      // and supplies a nearby open visual anchor when a building covers them.
      const gameplayObjectGroup=new THREE.Group();gameplayObjectGroup.name='gameplay-object-layer';scene.add(gameplayObjectGroup);
      const gameplayObjectActors=new Map();
      const objectColor=value=>{try{return new THREE.Color(value||'#ffd76b');}catch(_){return new THREE.Color('#ffd76b');}};
      const disposeObjectActor=actor=>{gameplayObjectGroup.remove(actor);actor.traverse?.(o=>{o.geometry?.dispose?.();if(o.material){const mats=Array.isArray(o.material)?o.material:[o.material];for(const mat of mats){mat.map?.dispose?.();mat.dispose?.();}}});};
      const createGameplayObjectActor=src=>{
        const root=new THREE.Group(),color=objectColor(src.color),solid=new THREE.MeshStandardMaterial({color,roughness:.62,metalness:.12}),glow=new THREE.MeshBasicMaterial({color,transparent:true,opacity:.82,depthWrite:false,toneMapped:false}),kind=String(src.kind||'marker');
        root.userData={kind,id:String(src.id),solid,glow,source:src};
        if(kind==='pet'){
          const cat=src.petKind==='cat',furColors=cat?[0x292725,0xd3c7b2,0x9a633c,0xd79542,0x6e7477]:[0x8a6847,0x3c2b20,0xb78b5c,0x68635f],variant=Math.abs([...String(src.id)].reduce((a,ch)=>a+ch.charCodeAt(0),0))%furColors.length;
          solid.color.set(src.color||furColors[variant]);solid.roughness=.88;const cream=new THREE.MeshStandardMaterial({color:variant===0?0xb8afa2:0xe4d7c1,roughness:.92}),eyeMat=new THREE.MeshBasicMaterial({color:cat?0xb9e75f:0x5b351d,toneMapped:false}),dark=new THREE.MeshStandardMaterial({color:0x25211f,roughness:.82});
          const bodyPivot=new THREE.Group();bodyPivot.position.y=cat?.7:.78;root.add(bodyPivot);const body=new THREE.Mesh(new THREE.CapsuleGeometry(cat?.3:.36,cat?.86:1.02,6,12),solid);body.rotation.z=Math.PI/2;body.scale.set(1,.9,cat?.76:.82);bodyPivot.add(body);
          const chest=new THREE.Mesh(new THREE.SphereGeometry(cat?.3:.36,12,8),cream);chest.scale.set(.72,1.05,.78);chest.position.set(.35,.02,0);bodyPivot.add(chest);
          const neck=new THREE.Group();neck.position.set(cat?.66:.78,.14,0);bodyPivot.add(neck);const head=new THREE.Mesh(new THREE.SphereGeometry(cat?.34:.39,14,10),solid);head.scale.set(1,.96,.9);neck.add(head);
          const muzzle=new THREE.Mesh(new THREE.SphereGeometry(cat?.16:.2,10,7),cream);muzzle.scale.set(1,.68,.86);muzzle.position.set(.25,-.07,0);neck.add(muzzle);const nose=new THREE.Mesh(new THREE.SphereGeometry(cat?.055:.07,8,6),dark);nose.position.set(cat?.39:.45,-.045,0);neck.add(nose);
          for(const side of [-1,1]){const eye=new THREE.Mesh(new THREE.SphereGeometry(cat?.052:.06,8,6),eyeMat);eye.position.set(cat?.285:.32,.08,side*(cat?.19:.22));neck.add(eye);if(cat){const ear=new THREE.Mesh(new THREE.ConeGeometry(.13,.31,3),solid);ear.position.set(-.03,.32,side*.2);ear.rotation.z=-.08;ear.rotation.x=side*.08;neck.add(ear);}}
          const legs=[];for(const [x,z] of [[-.38,-.19],[-.38,.19],[.42,-.19],[.42,.19]]){const pivot=new THREE.Group();pivot.position.set(x,-.12,z);bodyPivot.add(pivot);const leg=new THREE.Mesh(new THREE.CapsuleGeometry(cat?.065:.085,cat?.3:.38,3,7),solid);leg.position.y=-.25;legs.push(pivot);pivot.add(leg);const paw=new THREE.Mesh(new THREE.SphereGeometry(cat?.085:.11,8,6),dark);paw.scale.set(1.25,.55,1);paw.position.set(.08,-.48,0);pivot.add(paw);}
          const tailPivot=new THREE.Group();tailPivot.position.set(cat?-.72:-.88,.12,0);bodyPivot.add(tailPivot);const tailSegments=[];for(let i=0;i<(cat?4:3);i++){const segment=new THREE.Mesh(new THREE.CapsuleGeometry(cat?.055:.07,cat?.3:.34,3,7),solid);segment.position.x=-(i+.5)*(cat?.25:.29);segment.rotation.z=Math.PI/2;tailPivot.add(segment);tailSegments.push(segment);}
          root.userData={...root.userData,body,bodyPivot,neck,legs,tailPivot,tailSegments,cat,animalPhase:variant*.93,lastAnimalUpdate:0,lastAnimalX:NaN,lastAnimalZ:NaN};
        }else if(kind==='money_bag'){
          const bag=new THREE.Mesh(new THREE.SphereGeometry(.62,12,9),solid);bag.scale.set(.78,1,.68);bag.position.y=.67;root.add(bag);
          const neck=new THREE.Mesh(new THREE.CylinderGeometry(.18,.27,.32,9),solid);neck.position.y=1.3;root.add(neck);
          const ring=new THREE.Mesh(new THREE.TorusGeometry(.92,.1,8,28),glow);ring.rotation.x=Math.PI/2;ring.position.y=.08;root.add(ring);root.userData.pulse=ring;
        }else if(kind==='bus_stop'){
          const pole=new THREE.Mesh(new THREE.CylinderGeometry(.08,.11,3.8,8),solid);pole.position.y=1.9;root.add(pole);
          const sign=new THREE.Mesh(new THREE.BoxGeometry(1.25,1.05,.16),solid);sign.position.set(0,3.35,0);root.add(sign);
          const curb=new THREE.Mesh(new THREE.BoxGeometry(2.6,.18,.7),new THREE.MeshStandardMaterial({color:0x71808b,roughness:.9}));curb.position.y=.09;root.add(curb);
        }else if(kind==='jet_ski'){
          const hull=new THREE.Mesh(new THREE.CapsuleGeometry(.42,1.45,5,10),solid);hull.rotation.z=Math.PI/2;hull.position.y=.38;hull.scale.z=.72;root.add(hull);
          const nose=new THREE.Mesh(new THREE.ConeGeometry(.43,.9,10),solid);nose.rotation.z=-Math.PI/2;nose.position.set(.98,.43,0);root.add(nose);
          const seat=new THREE.Mesh(new THREE.BoxGeometry(.78,.28,.48),new THREE.MeshStandardMaterial({color:0x20262d,roughness:.8}));seat.position.set(-.24,.75,0);root.add(seat);
          const wake=new THREE.Mesh(new THREE.RingGeometry(.65,1.05,24),new THREE.MeshBasicMaterial({color:0xbcecff,transparent:true,opacity:.42,depthWrite:false,side:THREE.DoubleSide}));wake.rotation.x=-Math.PI/2;wake.position.y=.04;root.add(wake);root.userData.pulse=wake;
        }else if(kind==='mission_box'){
          const crate=new THREE.Mesh(new THREE.BoxGeometry(1.15,1.05,1.15),solid);crate.position.y=.55;root.add(crate);
          for(const z of [-.59,.59]){const brace=new THREE.Mesh(new THREE.BoxGeometry(1.28,.13,.08),glow);brace.position.set(0,.55,z);root.add(brace);}
          const ring=new THREE.Mesh(new THREE.TorusGeometry(.9,.09,8,28),glow);ring.rotation.x=Math.PI/2;ring.position.y=.08;root.add(ring);root.userData.pulse=ring;
        }else if(kind==='race_board'){
          const pole=new THREE.Mesh(new THREE.CylinderGeometry(.1,.14,3.6,8),solid);pole.position.y=1.8;root.add(pole);
          const board=new THREE.Mesh(new THREE.BoxGeometry(3.1,1.65,.22),new THREE.MeshStandardMaterial({color:0x171b22,roughness:.55,metalness:.25,emissive:color,emissiveIntensity:.18}));board.position.y=3.35;root.add(board);
        }else if(kind==='graffiti'){
          const panel=new THREE.Mesh(new THREE.PlaneGeometry(3.5,1.7),new THREE.MeshBasicMaterial({color,transparent:true,opacity:.78,side:THREE.DoubleSide,depthTest:false,toneMapped:false}));panel.position.y=2.25;panel.renderOrder=54;root.add(panel);
        }else if(kind==='brigadir'){
          const figure=new THREE.Group();figure.scale.setScalar(1.24);root.add(figure);const coat=new THREE.MeshStandardMaterial({color:0x221a1c,roughness:.7}),shirt=new THREE.MeshStandardMaterial({color:0xe2d6c1,roughness:.8}),red=new THREE.MeshStandardMaterial({color:0x8e2027,roughness:.62}),skin=new THREE.MeshStandardMaterial({color:0xc88e68,roughness:.82}),leather=new THREE.MeshStandardMaterial({color:0x2a1a14,roughness:.5}),metal=new THREE.MeshStandardMaterial({color:0xb89a58,metalness:.7,roughness:.28});
          const torso=new THREE.Mesh(new THREE.CapsuleGeometry(.48,1.18,6,12),coat);torso.position.y=1.75;torso.scale.set(1.08,1,.72);figure.add(torso);const lapelL=new THREE.Mesh(new THREE.BoxGeometry(.34,.82,.08),shirt),lapelR=lapelL.clone();lapelL.position.set(-.19,2.02,.49);lapelR.position.set(.19,2.02,.49);lapelL.rotation.z=-.27;lapelR.rotation.z=.27;figure.add(lapelL,lapelR);const tie=new THREE.Mesh(new THREE.ConeGeometry(.12,.68,4),red);tie.rotation.z=Math.PI;tie.position.set(0,1.92,.56);figure.add(tie);
          const head=new THREE.Mesh(new THREE.SphereGeometry(.43,16,11),skin);head.position.y=3.03;head.scale.set(.92,1.08,.9);figure.add(head);const hair=new THREE.Mesh(new THREE.SphereGeometry(.445,14,9,0,Math.PI*2,0,Math.PI*.48),leather);hair.position.set(0,3.18,0);figure.add(hair);const cigar=new THREE.Mesh(new THREE.CylinderGeometry(.035,.045,.5,7),leather);cigar.rotation.z=Math.PI/2;cigar.position.set(.42,2.89,.28);figure.add(cigar);const ember=new THREE.Mesh(new THREE.SphereGeometry(.055,7,5),new THREE.MeshBasicMaterial({color:0xff6a25,toneMapped:false}));ember.position.set(.68,2.89,.28);figure.add(ember);
          const arms=[],legs=[],shoes=[];for(const side of [-1,1]){const arm=new THREE.Mesh(new THREE.CapsuleGeometry(.15,.92,4,8),coat);arm.position.set(side*.67,1.9,.03);arm.rotation.z=side*.16;figure.add(arm);arms.push(arm);const hand=new THREE.Mesh(new THREE.SphereGeometry(.17,10,7),skin);hand.position.set(side*.78,1.25,.04);figure.add(hand);const leg=new THREE.Mesh(new THREE.CapsuleGeometry(.19,.9,4,8),coat);leg.position.set(side*.27,.62,0);figure.add(leg);legs.push(leg);const shoe=new THREE.Mesh(new THREE.CapsuleGeometry(.15,.34,4,8),leather);shoe.rotation.z=Math.PI/2;shoe.position.set(side*.27,.12,.18);figure.add(shoe);shoes.push(shoe);}
          const chain=new THREE.Mesh(new THREE.TorusGeometry(.24,.035,7,18,Math.PI),metal);chain.position.set(0,1.75,.58);chain.rotation.z=Math.PI;figure.add(chain);const dossier=new THREE.Mesh(new THREE.BoxGeometry(.42,.58,.07),new THREE.MeshStandardMaterial({color:0xb79055,roughness:.9}));dossier.position.set(-.72,1.28,.18);dossier.rotation.z=.18;figure.add(dossier);const speech=brigadirSpeechSprite();speech.position.y=8.15;root.add(speech);root.userData.figure=figure;root.userData.speech=speech;root.userData.body=torso;root.userData.arms=arms;root.userData.legs=legs;root.userData.shoes=shoes;root.userData.lastBrigadirX=NaN;root.userData.lastBrigadirZ=NaN;
        }else{
          const radius=Math.max(1.1,Math.min(6,+src.radius||2.2))*WORLD_SCALE*.42,ring=new THREE.Mesh(new THREE.RingGeometry(radius*.82,radius,48),glow);ring.rotation.x=-Math.PI/2;ring.position.y=.16;ring.renderOrder=18;root.add(ring);root.userData.pulse=ring;
          const post=new THREE.Mesh(new THREE.CylinderGeometry(.08,.15,3.4,9),solid);post.position.y=1.7;root.add(post);
          const beacon=new THREE.Mesh(new THREE.OctahedronGeometry(.52,1),glow);beacon.position.y=3.6;beacon.renderOrder=19;root.add(beacon);
        }
        if(src.label){const label=labelSprite(`${src.moved?'↗ ':''}${src.label}`,src.color||'#ffd76b');label.position.y=kind==='graffiti'?4.2:kind==='pet'?2.5:5.1;label.scale.multiplyScalar((kind==='territory'||kind==='district_hq') ? 0.82 : 0.72);root.add(label);root.userData.label=label;}
        if(src.moved){
          const dx=(src.sourceC-src.visualC)*WORLD_SCALE,dz=(src.sourceR-src.visualR)*WORLD_SCALE,line=new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0,.2,0),new THREE.Vector3(dx,.2,dz)]),new THREE.LineBasicMaterial({color,transparent:true,opacity:.72,depthTest:false}));line.renderOrder=17;root.add(line);root.userData.anchorLine=line;
        }
        gameplayObjectGroup.add(root);return root;
      };
      const syncGameplayObjects=(defs,t)=>{
        const live=new Set(),interior=!!bridge?.getPlayerState?.().interior;gameplayObjectGroup.visible=!interior;
        for(const src of defs||[]){
          const id=String(src.id);live.add(id);let actor=gameplayObjectActors.get(id);
          const dynamicActor=['brigadir','pet','jet_ski'].includes(src.kind),signature=dynamicActor?`${src.kind}:${src.label}:${src.color}`:`${src.kind}:${src.label}:${src.color}:${src.moved?1:0}:${(+src.sourceR||0).toFixed(1)}:${(+src.sourceC||0).toFixed(1)}`;
          if(!actor||actor.userData.signature!==signature){if(actor)disposeObjectActor(actor);actor=createGameplayObjectActor(src);actor.userData.signature=signature;gameplayObjectActors.set(id,actor);}
          actor.userData.source=src;const x=(+src.visualC-originC)*WORLD_SCALE,z=(+src.visualR-originR)*WORLD_SCALE,instant=!Number.isFinite(actor.userData.lastX)||Math.hypot(x-actor.userData.lastX,z-actor.userData.lastZ)>14,alpha=instant?1:.34;
          actor.position.x=THREE.MathUtils.lerp(actor.position.x,x,alpha);actor.position.z=THREE.MathUtils.lerp(actor.position.z,z,alpha);actor.userData.lastX=x;actor.userData.lastZ=z;
          if(src.kind==='pet'){
            const ud=actor.userData,dx=x-(Number.isFinite(ud.lastAnimalX)?ud.lastAnimalX:x),dz=z-(Number.isFinite(ud.lastAnimalZ)?ud.lastAnimalZ:z),travel=Math.hypot(dx,dz),distanceToPlayer=Math.hypot(actor.position.x-player.position.x,actor.position.z-player.position.z),updateAnimal=distanceToPlayer<85||t-(ud.lastAnimalUpdate||0)>140;
            if(updateAnimal){ud.lastAnimalUpdate=t;const desired=travel>.018?Math.atan2(dx,dz):-(+src.ang||0),turnDelta=Math.atan2(Math.sin(desired-actor.rotation.y),Math.cos(desired-actor.rotation.y));actor.rotation.y+=turnDelta*Math.min(.38,travel*.22+.08);const moving=!!src.walking&&travel>.004,phase=(+src.walkPhase||t*.006)+ud.animalPhase,run=moving&&(+src.speed||0)>1.45,step=Math.sin(phase*(run?1.38:1)),threat=!!src.alerted,sitting=!moving&&!threat&&!!src.sitting;ud.bodyPivot.position.y=THREE.MathUtils.lerp(ud.bodyPivot.position.y,sitting?.48:(ud.cat?.7:.78)+Math.abs(step)*(moving?.055:0),.24);ud.bodyPivot.rotation.z=THREE.MathUtils.lerp(ud.bodyPivot.rotation.z,sitting?-.12:moving?step*.025:0,.2);ud.legs.forEach((leg,i)=>{const fore=i>1,swing=moving?Math.sin(phase+(i%2?Math.PI:0)+(fore?Math.PI*.12:0))*(run?.72:.46):0;leg.rotation.z=THREE.MathUtils.lerp(leg.rotation.z,sitting?(fore?-.42:.82):swing,.28);leg.visible=!sitting||fore;});ud.neck.rotation.y=THREE.MathUtils.lerp(ud.neck.rotation.y,threat?Math.sin(t*.006+ud.animalPhase)*.48:!moving?Math.sin(t*.0013+ud.animalPhase)*.34:0,.12);ud.neck.rotation.z=THREE.MathUtils.lerp(ud.neck.rotation.z,threat?.12:sitting?-.16:0,.15);ud.tailPivot.rotation.y=Math.sin(t*(threat?.009:.0035)+ud.animalPhase)*(threat?.58:.34);ud.tailPivot.rotation.z=THREE.MathUtils.lerp(ud.tailPivot.rotation.z,threat?.38:sitting?-.55:-.15,.12);ud.tailSegments.forEach((segment,i)=>segment.rotation.y=Math.sin(t*.004+ud.animalPhase+i*.65)*(threat?.32:.17));actor.position.y=THREE.MathUtils.lerp(actor.position.y,.03,.35);}
            ud.lastAnimalX=x;ud.lastAnimalZ=z;
          }else if(src.kind==='brigadir'){
            const ud=actor.userData,lastX=Number.isFinite(ud.lastBrigadirX)?ud.lastBrigadirX:x,lastZ=Number.isFinite(ud.lastBrigadirZ)?ud.lastBrigadirZ:z,dx=x-lastX,dz=z-lastZ,travel=Math.hypot(dx,dz),moving=!!src.walking||travel>.004,phase=+src.walkPhase||t*.007,step=Math.sin(phase),targetYaw=travel>.004?Math.atan2(dx,dz):Math.PI/2-(+src.ang||0),turn=Math.atan2(Math.sin(targetYaw-actor.rotation.y),Math.cos(targetYaw-actor.rotation.y));actor.rotation.y+=turn*Math.min(1,.18+travel*.35);ud.arms.forEach((arm,i)=>{arm.rotation.x=THREE.MathUtils.lerp(arm.rotation.x,moving?step*(i ? .4 : -.4):Math.sin(t*.0017+i)*.025,.28);arm.rotation.z=THREE.MathUtils.lerp(arm.rotation.z,(i?1:-1)*(moving?.025+Math.abs(step)*.018:.012),.24);});ud.legs.forEach((leg,i)=>{leg.rotation.x=THREE.MathUtils.lerp(leg.rotation.x,moving?step*(i ? -.72 : .72):0,.32);});ud.shoes.forEach((shoe,i)=>{shoe.rotation.x=THREE.MathUtils.lerp(shoe.rotation.x,moving?step*(i ? -.45 : .45):0,.3);});ud.body.rotation.z=THREE.MathUtils.lerp(ud.body.rotation.z,moving?step*.035:Math.sin(t*.0015)*.012,.22);actor.position.y=THREE.MathUtils.lerp(actor.position.y,moving?Math.abs(step)*.11:Math.sin(t*.0018)*.025,.3);ud.speech?.userData?.setText?.(src.speech||'');ud.lastBrigadirX=x;ud.lastBrigadirZ=z;renderer.domElement.dataset.brigadirMotion=moving?'walking-arm-swing':'idle';renderer.domElement.dataset.brigadirSpeech=src.speech?'visible':'hidden';renderer.domElement.dataset.brigadirContractState=src.contractState||'available';
          }else if(src.kind==='jet_ski')actor.rotation.y=-(+src.ang||0);
          if(actor.userData.pulse){const p=1+Math.sin(t*.004+(id.length%7))*.08;actor.userData.pulse.scale.setScalar(p);actor.userData.pulse.material.opacity=src.active?.96:.68;}
        }
        for(const [id,actor] of gameplayObjectActors)if(!live.has(id)){disposeObjectActor(actor);gameplayObjectActors.delete(id);}
        const ambientPets=(defs||[]).filter(x=>x.kind==='pet'),ambientCats=ambientPets.filter(x=>x.petKind==='cat');renderer.domElement.dataset.gameplayObjects=String(gameplayObjectActors.size);renderer.domElement.dataset.relocatedObjects=String((defs||[]).filter(x=>x.moved).length);renderer.domElement.dataset.ambientPets=String(ambientPets.length);renderer.domElement.dataset.ambientCats=String(ambientCats.length);renderer.domElement.dataset.petPopulation=`${ambientCats.length}/${ambientPets.length}`;
      };
      let junkyardVisualBuilt=false;
      let ensureJunkyardVisual=()=>false;
      // The release grille is driven from the local player's jail timer. Two
      // players can therefore see a different gate state without changing the
      // shared prison model or the authoritative server collision.
      let prisonReleaseGate=null,prisonReleaseGateLight=null,prisonReleaseGateVisual=0,prisonVehicleLockGate=null,prisonVehicleLockVisual=0;
      const prisonAlarmBeacons=[],prisonAlarmBeaconPreview=(location.hostname==='127.0.0.1'||location.hostname==='localhost')&&rendererParams.has('previewprisonbeacons'),prisonBeaconDoublePulse=(phase,start)=>{const d=(phase-start+1280)%1280;if(d<105)return Math.sin(Math.PI*d/105)**2;if(d>=165&&d<270)return Math.sin(Math.PI*(d-165)/105)**2;return 0;};
      if(worldSnapshot?.landmarks){
        const toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;
        const architecturalKindAt=(r,c)=>{const all=[...(worldSnapshot.landmarks?.businesses||[]),...(worldSnapshot.pois||[]),...(worldSnapshot.landmarks?.mafiaHq?[worldSnapshot.landmarks.mafiaHq]:[])];let best=null,bestD=6.2;for(const p of all){const d=Math.hypot((+p.r||0)-r,(+p.c||0)-c);if(d<bestD){bestD=d;best=p;}}return best?.id||null;};
        const roofAnchorAt=(r,c,fallback=7)=>{let best=null,bestD=1e9;for(const block of worldSnapshot.blocks||[]){for(const q of block.buildingParts||[block.building]){if(!q)continue;const inside=r>=+q.minR-.7&&r<=+q.maxR+1.2&&c>=+q.minC-.7&&c<=+q.maxC+1.2;if(inside){const kind=architecturalKindAt(r,c),height=architecturalHeights[kind]||+q.height||fallback;return{x:toX(q.c),y:height+3,z:toZ(q.r),onRoof:true};}const d=Math.hypot(q.r-r,q.c-c);if(d<bestD){bestD=d;best=q;}}}return best&&bestD<14?{x:toX(best.c),y:(architecturalHeights[architecturalKindAt(r,c)]||+best.height||fallback)+3,z:toZ(best.r),onRoof:true}:{x:toX(c),y:fallback,z:toZ(r),onRoof:false};};
        const customGangHqGroup=new THREE.Group();scene.add(customGangHqGroup);let customGangHqSig='';
        const customGangFlagTexture=flag=>{const cv=document.createElement('canvas');cv.width=512;cv.height=288;const c=cv.getContext('2d'),primary=flag.primary||'#9b1f2d',secondary=flag.secondary||'#e0b83e',symbol={crown:'♛',skull:'☠',diamond:'◆',wolf:'W',eagle:'♜',star:'★'}[flag.emblem]||'♛';c.fillStyle=primary;c.fillRect(0,0,512,288);c.fillStyle=secondary;c.fillRect(0,210,512,78);c.strokeStyle='rgba(255,255,255,.22)';c.lineWidth=10;c.strokeRect(5,5,502,278);c.textAlign='center';c.textBaseline='middle';c.font='900 154px Georgia, serif';c.lineWidth=13;c.strokeStyle='rgba(0,0,0,.72)';c.strokeText(symbol,256,120);c.fillStyle=secondary;c.fillText(symbol,256,120);const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());tx.needsUpdate=true;return tx;};
        refreshCustomGangHqs=()=>{const fresh=bridge?.getCustomGangHqs?.()||bridge?.getWorldSnapshot?.(90)?.landmarks?.customGangHqs||[],sig=JSON.stringify(fresh.map(h=>[h.id,h.name,h.r,h.c,h.flag]));if(sig===customGangHqSig)return;customGangHqSig=sig;while(customGangHqGroup.children.length)disposeTransientObjectTree(customGangHqGroup.children[customGangHqGroup.children.length-1]);for(const hq of fresh){const roof=roofAnchorAt(+hq.r+.5,+hq.c+.5,9),flag=hq.flag||{},primary=flag.primary||'#9b1f2d',g=new THREE.Group(),pole=new THREE.Mesh(new THREE.CylinderGeometry(.09,.12,6,10),new THREE.MeshStandardMaterial({color:0xcaa86d,metalness:.65,roughness:.32}));pole.position.y=3;g.add(pole);const cloth=new THREE.Mesh(new THREE.PlaneGeometry(4.8,2.7,8,3),new THREE.MeshStandardMaterial({map:customGangFlagTexture(flag),side:THREE.DoubleSide,roughness:.78,emissive:new THREE.Color(primary),emissiveIntensity:.06}));cloth.position.set(2.45,4.65,0);cloth.rotation.y=.08;g.add(cloth);g.position.set(roof.x,roof.y,roof.z);customGangHqGroup.add(g);const label=labelSprite(`🚩 ${hq.name}`,primary);label.position.set(roof.x,roof.y+8.2,roof.z);customGangHqGroup.add(label);}};refreshCustomGangHqs();
        const jail=worldSnapshot.landmarks.jail;
        if(jail){
          const visual=jail.visual||{},centerR=+jail.r+(+visual.centerOffsetR||0),centerC=+jail.c+(+visual.centerOffsetC||0),widthTiles=Math.max(+jail.radius*2,+visual.widthTiles||+jail.radius*2),depthTiles=Math.max(+jail.radius*2,+visual.depthTiles||+jail.radius*2),x=toX(centerC),z=toZ(centerR),spanX=widthTiles*WORLD_SCALE,spanZ=depthTiles*WORLD_SCALE,halfX=spanX/2,halfZ=spanZ/2,northAccessLocalZ=toZ(worldSnapshot.canal?.bridge?.r1??56)-z;
          const vehicleGate=visual.vehicleGate||{r:centerR-6.45,c:centerC-widthTiles/2,stopR:centerR-6.45,stopC:centerC-widthTiles/2-2.35},westGateLocalZ=toZ(+vehicleGate.r)-z,westStopLocalX=toX(+vehicleGate.stopC)-x;
          const prison=new THREE.Group();prison.name='mafiosi-correctional-complex';prison.position.set(x,0,z);scene.add(prison);
          const concrete=new THREE.MeshStandardMaterial({color:0x929ba0,map:concreteTexture,roughness:.9,bumpMap:concreteTexture,bumpScale:.032}),concreteDark=new THREE.MeshStandardMaterial({color:0x4d575e,map:concreteTexture,roughness:.92,bumpMap:concreteTexture,bumpScale:.03}),paintedWall=new THREE.MeshStandardMaterial({color:0xb6bec1,roughness:.84}),darkSteel=new THREE.MeshStandardMaterial({color:0x202930,roughness:.34,metalness:.76}),galvanized=new THREE.MeshStandardMaterial({color:0x78858c,roughness:.28,metalness:.82}),yardMat=new THREE.MeshStandardMaterial({color:0x626d72,map:concreteTexture,roughness:.94,bumpMap:concreteTexture,bumpScale:.04}),curbMat=new THREE.MeshStandardMaterial({color:0x2b343a,roughness:.7,metalness:.3}),markMat=new THREE.MeshBasicMaterial({color:0xe8c65b,toneMapped:false}),warningMat=new THREE.MeshBasicMaterial({color:0xf2a33a,toneMapped:false}),cellLightMat=new THREE.MeshBasicMaterial({color:0xcbeaff,toneMapped:false}),mattressMat=new THREE.MeshStandardMaterial({color:0x526d7c,roughness:.92}),blanketMat=new THREE.MeshStandardMaterial({color:0x304d60,roughness:.96}),pillowMat=new THREE.MeshStandardMaterial({color:0xd5d8d3,roughness:1}),ceramicMat=new THREE.MeshStandardMaterial({color:0xbfc8c9,roughness:.32,metalness:.12}),glassMat=new THREE.MeshPhysicalMaterial({color:0x7ec9e5,roughness:.08,metalness:.08,transparent:true,opacity:.58,transmission:.22,thickness:.2,clearcoat:1}),courtMat=new THREE.MeshBasicMaterial({color:0xe1ddd0,toneMapped:false}),rubberMat=new THREE.MeshStandardMaterial({color:0x1c2428,roughness:.88});
          const pbox=(px,pz,w,d,h,mat,bottom=0)=>{const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);mesh.position.set(px,bottom+h/2,pz);mesh.castShadow=mesh.receiveShadow=true;prison.add(mesh);return mesh;};
          const pcylinder=(px,pz,rt,rb,h,mat,bottom=0,segments=12)=>{const mesh=new THREE.Mesh(new THREE.CylinderGeometry(rt,rb,h,segments),mat);mesh.position.set(px,bottom+h/2,pz);mesh.castShadow=mesh.receiveShadow=true;prison.add(mesh);return mesh;};
          const instance=(name,geometry,material,defs,shadow=true)=>{if(!defs.length)return null;const mesh=new THREE.InstancedMesh(geometry,material,defs.length),dummy=new THREE.Object3D();mesh.name=name;defs.forEach((q,i)=>{const [px,py,pz,rx=0,ry=0,rz=0,sx=1,sy=1,sz=1]=q;dummy.position.set(px,py,pz);dummy.rotation.set(rx,ry,rz);dummy.scale.set(sx,sy,sz);dummy.updateMatrix();mesh.setMatrixAt(i,dummy.matrix);});mesh.instanceMatrix.needsUpdate=true;mesh.castShadow=shadow;mesh.receiveShadow=shadow;mesh.computeBoundingSphere?.();prison.add(mesh);return mesh;};
          const panel=(text,px,py,pz,w=8,h=1.5,accent='#9edcff')=>{const label=String(text||'').toUpperCase(),cv=document.createElement('canvas');cv.width=1536;cv.height=320;const c=cv.getContext('2d'),g=c.createLinearGradient(0,0,1536,0);g.addColorStop(0,'#07111a');g.addColorStop(.5,'#203746');g.addColorStop(1,'#07111a');c.fillStyle=g;c.fillRect(12,12,1512,296);c.strokeStyle='rgba(0,0,0,.98)';c.lineWidth=24;c.strokeRect(20,20,1496,280);c.strokeStyle=accent;c.lineWidth=10;c.strokeRect(36,36,1464,248);c.fillStyle=accent;c.fillRect(58,58,1420,10);let size=118;c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';do{c.font=`900 ${size}px system-ui,Arial,sans-serif`;if(c.measureText(label).width<=1370)break;size-=4;}while(size>58);c.strokeStyle='rgba(0,0,0,1)';c.lineWidth=18;c.strokeText(label,768,181);c.fillStyle='#fff6d8';c.fillText(label,768,181);const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());tx.generateMipmaps=false;tx.minFilter=THREE.LinearFilter;tx.magFilter=THREE.LinearFilter;const mesh=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({map:tx,transparent:true,alphaTest:.03,side:THREE.DoubleSide,toneMapped:false}));mesh.position.set(px,py,pz);mesh.renderOrder=32;prison.add(mesh);return mesh;};
          let prisonZoneBadgeCount=0;
          const prisonZoneBadge=(text,px,pz,accent='#9edcff',scale=1,y=5.8)=>{const label=String(text||'').toUpperCase(),badge=labelSprite(label,accent);badge.position.set(px,y,pz);badge.scale.set(Math.max(7.8,Math.min(15.5,label.length*.72))*scale,2.15*scale,1);badge.renderOrder=62;badge.material.depthTest=false;prison.add(badge);prisonZoneBadgeCount++;return badge;};
          const gateSteel=new THREE.MeshStandardMaterial({color:0xd2dde1,roughness:.22,metalness:.9,emissive:0x31444b,emissiveIntensity:.28});

          // Raised dry slab: visual only. Jail collision and all authoritative
          // player state continue to come from world.html and the server.
          const foundation=pbox(0,0,spanX+1.4,spanZ+1.4,.68,yardMat);foundation.receiveShadow=true;outline(foundation);
          for(const [px,pz,pw,pd] of [[0,-halfZ,spanX+1.2,.5],[0,halfZ,spanX+1.2,.5],[-halfX,0,.5,spanZ],[halfX,0,.5,spanZ]])pbox(px,pz,pw,pd,.34,curbMat,.68);

          // The main vehicle port is aligned with the police building and the
          // city road. The former center opening is now an uninterrupted wall.
          const wallH=4.25,wallT=.82,westGateW=13,westGateOpen=9.4,northGateW=9.5,northGateOpen=6.5,southGateW=9.5,southGateOpen=6.8,sideWallW=(spanX-northGateW)/2,southSideWallW=(spanX-southGateW)/2;
          const westWallNorthD=Math.max(.5,westGateLocalZ-westGateW/2+halfZ),westWallNorthZ=(-halfZ+westGateLocalZ-westGateW/2)/2,westWallSouthD=Math.max(.5,halfZ-westGateLocalZ-westGateW/2),westWallSouthZ=(westGateLocalZ+westGateW/2+halfZ)/2;
          const perimeter=[
            pbox(-(southGateW+southSideWallW)/2,halfZ,southSideWallW,wallT,wallH,concrete,.68),pbox((southGateW+southSideWallW)/2,halfZ,southSideWallW,wallT,wallH,concrete,.68),pbox(halfX,0,wallT,spanZ,wallH,concrete,.68),
            pbox(-(northGateW+sideWallW)/2,-halfZ,sideWallW,wallT,wallH,concrete,.68),pbox((northGateW+sideWallW)/2,-halfZ,sideWallW,wallT,wallH,concrete,.68),
            pbox(-halfX,westWallNorthZ,wallT,westWallNorthD,wallH,concrete,.68),pbox(-halfX,westWallSouthZ,wallT,westWallSouthD,wallH,concrete,.68),
          ];perimeter.forEach(outline);
          // The north and west sally ports stay permanently open. The south
          // opening into the holding room is authored separately below.
          const gateLeafBars=[],leafH=4.45,northLeafL=northGateOpen/2-.28;
          for(const side of [-1,1]){
            const northHingeX=side*(northGateOpen/2+.2),northLeafCenterZ=-halfZ-northLeafL/2-.16;
            for(let step=0;step<=7;step++)gateLeafBars.push([northHingeX,.68+leafH/2,-halfZ-.18-step*(northLeafL-.18)/7]);
            for(const gy of [.15,2.12,4.3])pbox(northHingeX,northLeafCenterZ,.18,northLeafL,.16,gy===2.12?gateSteel:warningMat,.68+gy);
            pbox(northHingeX,-halfZ-.18,.24,.24,leafH,warningMat,.68);pbox(northHingeX,-halfZ-northLeafL-.07,.24,.24,leafH,warningMat,.68);
            const northBrace=pbox(northHingeX,northLeafCenterZ,.13,Math.hypot(northLeafL-.32,leafH-.35),.15,warningMat,.68+leafH/2-.075);northBrace.rotation.x=side*Math.atan2(leafH-.35,northLeafL-.32);
          }
          instance('prison-open-north-gate-leaf-bars',new THREE.BoxGeometry(.15,leafH,.15),gateSteel,gateLeafBars);
          for(const side of [-1,1]){
            const westPost=pbox(-halfX,westGateLocalZ+side*(westGateW/2+.48),1.3,1.05,5.5,concreteDark,.68);outline(westPost);
            const northPost=pbox(side*(northGateW/2+.48),-halfZ,1.05,1.3,5.5,concreteDark,.68);outline(northPost);
            const southPost=pbox(side*(southGateW/2+.48),halfZ,1.05,1.3,5.5,concreteDark,.68);outline(southPost);
            pbox(-halfX,westGateLocalZ+side*westGateOpen/2,.42,.42,4.75,darkSteel,.68);pbox(side*northGateOpen/2,-halfZ,.42,.42,4.75,darkSteel,.68);
            pbox(side*southGateOpen/2,halfZ,.42,.42,4.75,darkSteel,.68);
            for(let band=0;band<4;band++){pbox(-halfX-.67,westGateLocalZ+side*(westGateW/2+.48),.08,.98,.28,band%2?warningMat:darkSteel,1.2+band*.62);pbox(side*(northGateW/2+.48),-halfZ-.67,.98,.08,.28,band%2?warningMat:darkSteel,1.2+band*.62);pbox(side*(southGateW/2+.48),halfZ+.67,.98,.08,.28,band%2?warningMat:darkSteel,1.2+band*.62);}
          }
          // Bright checkpoint arches make the openings legible from the
          // isometric camera even when the dark perimeter is in shadow.
          pbox(-halfX,westGateLocalZ,.78,westGateW+.9,.32,darkSteel,5.2);pbox(-halfX-.43,westGateLocalZ,.1,westGateW+.25,.18,warningMat,5.27);
          pbox(0,-halfZ,northGateW+.9,.78,.32,darkSteel,5.2);pbox(0,-halfZ-.43,northGateW+.25,.1,.18,warningMat,5.27);
          pbox(0,halfZ,southGateW+.9,.78,.32,darkSteel,5.2);pbox(0,halfZ+.43,southGateW+.25,.1,.18,warningMat,5.27);

          // Intake and release room. Its nine-tile width is exactly half the
          // main prison width. It extends from the screen-left/south edge over
          // empty canal water and therefore covers no city road or building.
          const intake=visual.intakeRoom||{north:91,south:103,west:85,east:94},intakeNorthZ=toZ(+intake.north)-z,intakeSouthZ=toZ(+intake.south)-z,intakeWestX=toX(+intake.west)-x,intakeEastX=toX(+intake.east)-x,intakeCenterX=(intakeWestX+intakeEastX)/2,intakeCenterZ=(intakeNorthZ+intakeSouthZ)/2,intakeSpanX=intakeEastX-intakeWestX,intakeSpanZ=intakeSouthZ-intakeNorthZ;
          const intakeSlab=pbox(intakeCenterX,intakeCenterZ,intakeSpanX+1.35,intakeSpanZ+1.35,.68,yardMat);outline(intakeSlab);
          for(const [px,pz,pw,pd] of [[intakeCenterX,intakeNorthZ,intakeSpanX+1.2,.5],[intakeCenterX,intakeSouthZ,intakeSpanX+1.2,.5],[intakeWestX,intakeCenterZ,.5,intakeSpanZ]])pbox(px,pz,pw,pd,.34,curbMat,.68);
          const intakeWalls=[pbox(intakeCenterX,intakeSouthZ,intakeSpanX,wallT,wallH,concrete,.68),pbox(intakeWestX,intakeCenterZ,wallT,intakeSpanZ,wallH,concrete,.68),pbox(intakeEastX,intakeCenterZ,wallT,intakeSpanZ,wallH,concrete,.68)];intakeWalls.forEach(outline);
          // Reinforced open roof frame keeps the room readable from the
          // isometric camera while still making it feel enclosed and secure.
          for(const rz of [intakeNorthZ+1.05,intakeSouthZ-1.05])pbox(intakeCenterX,rz,intakeSpanX-.8,.26,.34,darkSteel,5.04);
          for(let rx=intakeWestX+1.1;rx<intakeEastX-.8;rx+=4.1)pbox(rx,intakeCenterZ,.24,intakeSpanZ-1.4,.28,galvanized,5.08);
          const intakeCoils=[];for(let rx=intakeWestX+1.1;rx<=intakeEastX-1;rx+=2.25)intakeCoils.push([rx,5.35,intakeSouthZ,0,Math.PI/2,0]);for(let rz=intakeNorthZ+1.2;rz<=intakeSouthZ-1.2;rz+=2.25){intakeCoils.push([intakeWestX,5.35,rz]);intakeCoils.push([intakeEastX,5.35,rz]);}instance('prison-intake-razor-wire',new THREE.TorusGeometry(.62,.038,5,12),galvanized,intakeCoils,false);

          // Benches, booking counter, lockers, search arch, hygiene corner and
          // mugshot wall give the room a real intake/release purpose.
          const benchWood=new THREE.MeshStandardMaterial({color:0x704b2e,roughness:.9}),lockerMat=new THREE.MeshStandardMaterial({color:0x53636b,roughness:.54,metalness:.52}),screenMat=new THREE.MeshBasicMaterial({color:0x5ed8ff,toneMapped:false}),sanitaryDivider=new THREE.MeshStandardMaterial({color:0x8d979b,roughness:.78});
          // Keep the gate axis clear: the complete waiting set (both benches
          // and its blue information screen) belongs in the far south-west
          // corner, opposite the northern release gate.
          const waitingCornerZ=intakeSouthZ-6.2,waitingBenchNearX=intakeWestX+4.2,waitingBenchFarX=intakeWestX+7.2;
          for(const bx of [waitingBenchNearX,waitingBenchFarX]){pbox(bx,waitingCornerZ,1.2,11.6,.28,benchWood,1.18);for(const bz of [waitingCornerZ-4.8,waitingCornerZ+4.8])pbox(bx,bz,.82,.42,1.18,darkSteel,.68);pbox(bx+.48,waitingCornerZ,.24,11.8,1.55,darkSteel,1.36);}
          const deskX=intakeWestX+5.0,deskZ=intakeCenterZ;pbox(deskX,deskZ,2.35,9.2,1.18,concreteDark,.68);pbox(deskX+1.22,deskZ,1.0,9.25,.18,warningMat,1.7);
          for(const dz of [-2.65,0,2.65]){const monitor=pbox(deskX+1.25,deskZ+dz,.16,1.24,.78,darkSteel,1.92);monitor.rotation.z=-.12;pbox(deskX+1.34,deskZ+dz,.035,.94,.53,screenMat,2.03);}
          for(let li=0;li<5;li++){const lz=intakeNorthZ+3.35+li*3.0;pbox(intakeWestX+1.05,lz,1.5,2.48,3.35,lockerMat,.68);pbox(intakeWestX+1.84,lz,.035,2.08,2.72,darkSteel,.98);for(const hy of [1.42,2.02,2.62])pbox(intakeWestX+1.88,lz,.04,1.45,.06,galvanized,.68+hy);}
          const mugshotZ=intakeNorthZ+8.15;pbox(intakeWestX+.49,mugshotZ,.08,8.1,3.45,paintedWall,1.0);for(let sy=0;sy<7;sy++)pbox(intakeWestX+.55,mugshotZ,.04,7.4,.045,sy%2?darkSteel:warningMat,1.35+sy*.43);
          const mugshotSign=panel('ФОТО И ОТПЕЧАТКИ',intakeWestX+.61,4.82,mugshotZ,7.2,1.05,'#e8ad48');mugshotSign.rotation.y=Math.PI/2;
          const hygieneX=intakeCenterX+7.75,hygieneZ=intakeSouthZ-5.1;pbox(hygieneX-2.2,hygieneZ,4.4,.24,2.8,sanitaryDivider,.68);pbox(hygieneX,hygieneZ-2.25,.24,4.7,2.8,sanitaryDivider,.68);pcylinder(hygieneX-1.0,hygieneZ-1.25,.62,.5,.46,ceramicMat,.68,14);pbox(hygieneX-1.0,hygieneZ-1.77,1.25,.7,.72,ceramicMat,.68);pbox(hygieneX-2.05,hygieneZ+1.15,.7,1.75,.36,ceramicMat,1.12);
          const searchX=intakeWestX+1.15,searchZ=waitingCornerZ;for(const sz of [-1.75,1.75])pbox(searchX,searchZ+sz,.46,.46,3.8,darkSteel,.68);pbox(searchX,searchZ,.46,4.0,.38,darkSteel,4.1);pbox(searchX+.04,searchZ,.08,3.25,2.8,screenMat,1.18);pbox(searchX+3.05,searchZ,1.35,3.65,1.12,concreteDark,.68);
          for(const lz of [intakeNorthZ+2.1,intakeSouthZ-2.1]){const lamp=pbox(intakeCenterX,lz,8.5,.26,.2,cellLightMat,4.84);lamp.castShadow=false;const glow=new THREE.PointLight(0xccefff,3.8,17,2);glow.position.set(intakeCenterX,4.65,lz);prison.add(glow);}
          const intakeTitle=panel('ПРИЁМ И ОСВОБОЖДЕНИЕ',intakeCenterX,4.35,intakeSouthZ-.48,13.8,1.35,'#f0b13d');
          const waitTitle=panel('ОЖИДАЙ ОКОНЧАНИЯ СРОКА',intakeCenterX,4.28,intakeNorthZ+2.05,13.4,1.2,'#9edcff');waitTitle.rotation.y=Math.PI;
          prisonZoneBadge('ПРИЁМНАЯ',intakeCenterX,intakeCenterZ,'#f0b13d',1.08,6.35);
          for(let arrow=0;arrow<3;arrow++){const shaft=pbox(intakeCenterX+arrow*3.6-3.6,0,.18,6.1,.04,markMat,.705);shaft.rotation.y=-Math.PI/2;}

          // A single heavy portcullis slides vertically. Only this group is
          // animated; its target comes from the current local player's timer.
          prisonReleaseGate=new THREE.Group();prisonReleaseGate.name='prison-personal-release-portcullis';prisonReleaseGate.position.set(0,.68,halfZ);prison.add(prisonReleaseGate);
          const gatePart=(w,h,d,mat,px,py,pz)=>{const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);mesh.position.set(px,py,pz);mesh.castShadow=mesh.receiveShadow=true;prisonReleaseGate.add(mesh);return mesh;};
          for(let gi=0;gi<13;gi++)gatePart(.18,leafH,.18,gateSteel,-southGateOpen*.46+gi*(southGateOpen*.92/12),leafH/2,0);
          for(const gy of [.18,2.12,4.27])gatePart(southGateOpen*.96,.2,.28,gy===2.12?warningMat:gateSteel,0,gy,0);
          for(const side of [-1,1])gatePart(.34,leafH,.42,warningMat,side*southGateOpen*.49,leafH/2,0);
          prisonReleaseGateLight=new THREE.Mesh(new THREE.SphereGeometry(.32,12,8),new THREE.MeshBasicMaterial({color:0xff3b3b,toneMapped:false}));prisonReleaseGateLight.position.set(0,5.78,halfZ+.56);prison.add(prisonReleaseGateLight);
          const releaseSign=panel('ВЫХОД ПО ТАЙМЕРУ',-8.2,4.28,halfZ+.43,8.6,1.18,'#f0b13d');

          const northCausewayLength=Math.max(4,Math.abs(-halfZ-northAccessLocalZ)),northCausewayCenterZ=(-halfZ+northAccessLocalZ)/2,northCausewayWidth=northGateW*.72;
          const northCauseway=pbox(0,northCausewayCenterZ,northCausewayWidth,northCausewayLength+1.15,.58,concreteDark,.16);outline(northCauseway);
          for(const side of [-1,1]){pbox(side*northCausewayWidth*.5,northCausewayCenterZ,.12,northCausewayLength+1.2,1.12,darkSteel,.74);for(let cz=northAccessLocalZ+.9;cz<-halfZ;cz+=2.25){pcylinder(side*(northCausewayWidth*.5-.18),cz,.09,.13,1.85,galvanized,.74,9);const cap=pcylinder(side*(northCausewayWidth*.5-.18),cz,.18,.18,.18,cellLightMat,2.55,10);cap.castShadow=false;cap.receiveShadow=false;}}
          const westLaneWidth=westGateOpen*.78,westLaneLength=Math.max(5,Math.abs(-halfX-westStopLocalX)),westLaneCenterX=(-halfX+westStopLocalX)/2;
          const westVehicleLane=pbox(westLaneCenterX,westGateLocalZ,westLaneLength+1.25,westLaneWidth,.62,concreteDark,.14);outline(westVehicleLane);
          for(const side of [-1,1])pbox(westLaneCenterX,westGateLocalZ+side*westLaneWidth*.5,westLaneLength+1.25,.13,1.05,darkSteel,.76);
          for(let lx=westStopLocalX+.8;lx<-halfX-.4;lx+=2.6)pbox(lx,westGateLocalZ,.92,.16,.045,markMat,.79);
          const checkpointX=westLaneCenterX-.2,checkpointZ=westGateLocalZ-westLaneWidth*.5-2.5,checkpointBooth=pbox(checkpointX,checkpointZ,4.9,4.2,3.5,concreteDark,.68);outline(checkpointBooth);pbox(checkpointX+2.48,checkpointZ,0.06,2.85,1.55,glassMat,1.72);
          for(const side of [-1,1]){const barrier=pbox(-halfX-2.15,westGateLocalZ+side*2.75,.22,4.25,.22,warningMat,1.25);barrier.rotation.x=side*.03;pcylinder(-halfX-2.15,westGateLocalZ+side*4.9,.18,.24,1.42,darkSteel,.68,10);}
          const vehicleGateSign=panel('ОСНОВНОЙ ВЪЕЗД · КПП',-halfX-.55,5.82,westGateLocalZ,12.5,1.35,'#f0b13d');vehicleGateSign.rotation.y=Math.PI/2;
          prisonZoneBadge('ПРИЁМ КОНВОЯ',-halfX-4.2,westGateLocalZ,'#f0b13d',1.04,6.45);
          prisonVehicleLockGate=new THREE.Group();prisonVehicleLockGate.name='prison-assault-lockdown-portcullis';prisonVehicleLockGate.position.set(-halfX-.12,6.3,westGateLocalZ);prison.add(prisonVehicleLockGate);
          const lockGatePart=(w,h,d,mat,px,py,pz)=>{const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);mesh.position.set(px,py,pz);mesh.castShadow=mesh.receiveShadow=true;prisonVehicleLockGate.add(mesh);return mesh;};
          for(let gi=0;gi<15;gi++)lockGatePart(.2,4.75,.2,gateSteel,0,2.375,-westGateOpen*.47+gi*(westGateOpen*.94/14));
          for(const gy of [.2,2.35,4.52])lockGatePart(.3,.2,westGateOpen*.98,gy===2.35?warningMat:gateSteel,0,gy,0);
          // Professional fixed lightbars: dark housings remain visible while
          // clear lenses, inner emitters and soft additive bloom perform a
          // two-flash emergency cadence. Only the two existing gate fixtures
          // own PointLights, keeping the city's compiled light count stable.
          const prisonBeaconBaseGeometry=new THREE.BoxGeometry(2.05,.2,.78),prisonBeaconLensGeometry=new THREE.BoxGeometry(.78,.34,.58),prisonBeaconCoreGeometry=new THREE.BoxGeometry(.55,.2,.42),prisonBeaconDividerGeometry=new THREE.BoxGeometry(.1,.4,.66),prisonBeaconGlowGeometry=new THREE.SphereGeometry(.58,12,8),prisonBeaconMountGeometry=new THREE.CylinderGeometry(.17,.25,.42,12),prisonBeaconHousingMaterial=new THREE.MeshStandardMaterial({color:0x161d22,roughness:.3,metalness:.82}),prisonBeaconDividerMaterial=new THREE.MeshStandardMaterial({color:0x303940,roughness:.26,metalness:.88});
          const addPrisonBeacon=(bx,by,bz,lit=false,orientation=0)=>{const root=new THREE.Group(),base=new THREE.Mesh(prisonBeaconBaseGeometry,prisonBeaconHousingMaterial),mount=new THREE.Mesh(prisonBeaconMountGeometry,prisonBeaconHousingMaterial),divider=new THREE.Mesh(prisonBeaconDividerGeometry,prisonBeaconDividerMaterial),redMaterial=new THREE.MeshStandardMaterial({color:0x34080b,emissive:0xff1d2c,emissiveIntensity:.08,roughness:.18,metalness:.08,transparent:true,opacity:.78}),blueMaterial=new THREE.MeshStandardMaterial({color:0x071b38,emissive:0x2488ff,emissiveIntensity:.08,roughness:.18,metalness:.08,transparent:true,opacity:.78}),red=new THREE.Mesh(prisonBeaconLensGeometry,redMaterial),blue=new THREE.Mesh(prisonBeaconLensGeometry,blueMaterial),redCore=new THREE.Mesh(prisonBeaconCoreGeometry,new THREE.MeshBasicMaterial({color:0xff2638,transparent:true,opacity:.05,toneMapped:false})),blueCore=new THREE.Mesh(prisonBeaconCoreGeometry,new THREE.MeshBasicMaterial({color:0x3197ff,transparent:true,opacity:.05,toneMapped:false})),redGlow=new THREE.Mesh(prisonBeaconGlowGeometry,new THREE.MeshBasicMaterial({color:0xff1d32,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false})),blueGlow=new THREE.Mesh(prisonBeaconGlowGeometry,new THREE.MeshBasicMaterial({color:0x268dff,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}));base.position.y=-.16;mount.position.y=-.46;divider.position.y=.06;red.position.set(-.46,.06,0);blue.position.set(.46,.06,0);redCore.position.set(-.46,.06,.1);blueCore.position.set(.46,.06,.1);redGlow.position.set(-.46,.08,0);blueGlow.position.set(.46,.08,0);for(const part of [base,mount,divider,red,blue]){part.castShadow=true;part.receiveShadow=true;}for(const glow of [redGlow,blueGlow]){glow.visible=false;glow.renderOrder=24;}root.add(base,mount,divider,red,blue,redCore,blueCore,redGlow,blueGlow);let alarmLight=null;if(lit){alarmLight=new THREE.PointLight(0xff2638,0,28,2);alarmLight.position.y=.35;root.add(alarmLight);}root.position.set(bx,by,bz);root.rotation.y=orientation;prison.add(root);prisonAlarmBeacons.push({root,red,blue,redCore,blueCore,redGlow,blueGlow,alarmLight});};
          addPrisonBeacon(-halfX-.7,6.55,westGateLocalZ,true,Math.PI/2);addPrisonBeacon(0,6.65,-halfZ,true,0);
          for(const [sx,sz] of [[-1,-1],[1,-1],[-1,1],[1,1]])addPrisonBeacon(sx*(halfX-1.8),10.15,sz*(halfZ-1.8),false,Math.atan2(sx,sz));
          renderer.domElement.dataset.jailGateLeaves='main-west-vehicle-open-old-center-sealed-south-personal-lift';renderer.domElement.dataset.jailGateStyle='main-west-vehicle-sally-port-v266';renderer.domElement.dataset.jailConvoyAccess='road-stop-open-gate-handoff-inside-v266';renderer.domElement.dataset.jailIntakeRoom='9x12-tiles-half-main-width-over-water';

          // Razor coils are instanced so the detailed perimeter remains cheap.
          const coilDefs=[],coilStep=2.35;for(let q=-halfX+2;q<=halfX-2;q+=coilStep){if(Math.abs(q)>northGateW/2+.6)coilDefs.push([q,5.35,-halfZ,0,Math.PI/2,0]);if(Math.abs(q)>southGateW/2+.6)coilDefs.push([q,5.35,halfZ,0,Math.PI/2,0]);}for(let q=-halfZ+2;q<=halfZ-2;q+=coilStep){if(Math.abs(q-westGateLocalZ)>westGateW/2+.6)coilDefs.push([-halfX,5.35,q,0,0,0]);coilDefs.push([halfX,5.35,q,0,0,0]);}instance('prison-razor-wire',new THREE.TorusGeometry(.62,.038,5,12),galvanized,coilDefs,false);

          // Four full guard towers with enclosed glass cabins and floodlights.
          for(const [sx,sz] of [[-1,-1],[1,-1],[-1,1],[1,1]]){const tx=sx*(halfX-1.8),tz=sz*(halfZ-1.8),base=pbox(tx,tz,4.4,4.4,6.6,concreteDark,.68);outline(base);const cabin=pbox(tx,tz,5.35,5.35,2.15,darkSteel,7.28);outline(cabin);for(const [dx,dz,w,d] of [[0,2.71,4.15,.08],[0,-2.71,4.15,.08],[2.71,0,.08,4.15],[-2.71,0,.08,4.15]]){const pane=pbox(tx+dx,tz+dz,w,d,1.18,glassMat,7.72);pane.castShadow=false;}const roof=pbox(tx,tz,6.05,6.05,.32,darkSteel,9.43);outline(roof);const lamp=new THREE.PointLight(0xc9e9ff,12,27,2);lamp.position.set(tx,10.25,tz);lamp.castShadow=false;prison.add(lamp);for(const [lx,lz] of [[-1.55,0],[1.55,0]]){const flood=pbox(tx+lx,tz+sz*3.15,.62,.45,.34,cellLightMat,8.58);flood.castShadow=false;}}

          // Two open-gallery cell wings: five cells per floor, two floors and
          // two wings = twenty double cells / forty inmate places.
          const cellSpan=5.75,wingLen=cellSpan*5,westOuterX=halfX-7,eastOuterX=halfX-2.45,barX=12.25,floorBases=[.72,5.12],barDefs=[],railDefs=[],bedPostDefs=[],bedRailDefs=[],mattressDefs=[],blanketDefs=[],pillowDefs=[],toiletDefs=[],tankDefs=[],sinkDefs=[],lightDefs=[];
          let authoredCells=0;
          for(const side of [-1,1]){
            const outerX=side<0?westOuterX:eastOuterX,wingDepth=outerX-barX,rear=side*outerX,front=side*barX,wingCenter=(rear+front)/2;
            for(const [floorIndex,floorY] of floorBases.entries()){
              pbox(wingCenter,0,wingDepth+.55,wingLen+.65,.26,concreteDark,floorY-.04);
              pbox(rear,0,.42,wingLen+.65,4.25,paintedWall,floorY+.22);
              pbox(wingCenter,0,wingDepth+.75,.42,.3,darkSteel,floorY+4.42);
              for(let divider=0;divider<=5;divider++){const dz=-wingLen/2+divider*cellSpan;pbox(wingCenter,dz,wingDepth,.26,4.15,concrete,floorY+.22);}
              // The inmate corridor is wide on both levels; the upper gallery
              // has a continuous guard rail looking into the common yard.
              const corridorX=front-side*1.72,innerRailX=front-side*3.35;
              pbox(corridorX,0,3.45,wingLen+.45,.22,galvanized,floorY+.03);
              if(floorIndex===1){for(let rz=-wingLen/2;rz<=wingLen/2+.01;rz+=2.55)railDefs.push([innerRailX,floorY+1.02,rz]);for(const ry of [.42,1.15])railDefs.push([innerRailX,floorY+ry,0,0,0,0,1,.07,wingLen/.1]);}
              for(let cell=0;cell<5;cell++){
                const cz=-wingLen/2+(cell+.5)*cellSpan,cellNo=(side<0?0:10)+floorIndex*5+cell+1;authoredCells++;
                for(let bi=0;bi<7;bi++)barDefs.push([front,floorY+2.3,cz-cellSpan*.42+bi*(cellSpan*.84/6)]);
                for(const by of [floorY+1.18,floorY+3.2])barDefs.push([front,by,cz,0,0,0,1,.03,cellSpan/.12]);
                // One steel bunk with two separate berths makes every room
                // visibly and unambiguously double occupancy.
                const bunkX=side*(outerX-3.0),bunkZ=cz-.7;
                for(const bx of [bunkX-1.55,bunkX+1.55])for(const bz of [bunkZ-.44,bunkZ+.44])bedPostDefs.push([bx,floorY+1.53,bz]);
                for(const level of [.68,2.05]){mattressDefs.push([bunkX,floorY+level,bunkZ]);blanketDefs.push([bunkX-side*.72,floorY+level+.15,bunkZ]);pillowDefs.push([bunkX+side*1.16,floorY+level+.16,bunkZ]);for(const bz of [bunkZ-.45,bunkZ+.45])bedRailDefs.push([bunkX,floorY+level+.03,bz]);}
                const toiletX=side*(outerX-1.35),toiletZ=cz+1.45;toiletDefs.push([toiletX,floorY+.48,toiletZ]);tankDefs.push([side*(outerX-.62),floorY+.88,toiletZ]);sinkDefs.push([side*(outerX-.55),floorY+1.12,cz+.42]);lightDefs.push([(rear+front)/2,floorY+4.36,cz]);
                // Amber cell-number plate beside every barred door.
                pbox(front-side*.09,cz+cellSpan*.41,.26,.46,.26,warningMat,floorY+3.54);
                const door=pbox(front-side*.04,cz+cellSpan*.28,.24,cellSpan*.25,3.78,darkSteel,floorY+.25);door.castShadow=true;
                door.userData.cellNumber=cellNo;
              }
              // Range boards are fixed flat to the central facade. The old
              // end-mounted panels projected past the wing like long spikes
              // and were seen edge-on from the yard.
              const rangeStart=(side<0?1:11)+floorIndex*5,rangeEnd=rangeStart+4;
              pbox(front-side*.12,0,.24,9.5,1.35,concreteDark,floorY+3.45);
              const sign=panel(`${side<0?'КРЫЛО A':'КРЫЛО B'} · ${String(rangeStart).padStart(2,'0')}–${String(rangeEnd).padStart(2,'0')}`,front-side*.32,floorY+4.12,0,8.6,1.08,'#e8ad48');sign.rotation.y=side<0?Math.PI/2:-Math.PI/2;
            }
            prisonZoneBadge(side<0?'КРЫЛО A · КАМЕРЫ 01–10':'КРЫЛО B · КАМЕРЫ 11–20',side*17.2,-1.5,'#e8ad48',.88,8.7);
            // Roof canopy covers the cells but deliberately leaves both
            // galleries and the central yard open to the isometric camera.
            const canopy=pbox((rear+side*(barX+2.2))/2,0,wingDepth-2.2,wingLen+1.0,.4,darkSteel,9.72);outline(canopy);
          }
          instance('cell-front-bars',new THREE.BoxGeometry(.12,4.12,.12),darkSteel,barDefs);
          instance('cell-gallery-rails',new THREE.BoxGeometry(.1,1.45,.1),galvanized,railDefs);
          instance('double-bunk-posts',new THREE.BoxGeometry(.1,2.65,.1),darkSteel,bedPostDefs);
          instance('double-bunk-rails',new THREE.BoxGeometry(3.25,.1,.1),darkSteel,bedRailDefs);
          instance('prison-mattresses',new THREE.BoxGeometry(3.12,.24,.82),mattressMat,mattressDefs);
          instance('prison-blankets',new THREE.BoxGeometry(1.18,.08,.84),blanketMat,blanketDefs);
          instance('prison-pillows',new THREE.BoxGeometry(.55,.14,.7),pillowMat,pillowDefs);
          instance('prison-toilets',new THREE.CylinderGeometry(.28,.34,.38,12),ceramicMat,toiletDefs);
          instance('prison-toilet-tanks',new THREE.BoxGeometry(.42,.7,.62),ceramicMat,tankDefs);
          instance('prison-sinks',new THREE.BoxGeometry(.46,.2,.7),ceramicMat,sinkDefs);
          instance('cell-ceiling-lights',new THREE.BoxGeometry(2.05,.08,.38),cellLightMat,lightDefs,false);

          // Two opposite staircases connect the lower corridors to the upper
          // galleries. Every tread is modelled, with steel stringers and rails.
          for(const [side,dir] of [[-1,-1],[1,1]]){const sx=side*10.45,startZ=dir*(wingLen/2+4.2);for(let step=0;step<13;step++){const sy=.82+step*.335,sz=startZ-dir*step*.48;pbox(sx,sz,3.25,.58,.18,galvanized,sy);for(const edge of [-1,1])pbox(sx+edge*1.52,sz,.09,.62,.92,darkSteel,sy+.12);}const stringer=pbox(sx,startZ-dir*3.0,3.48,.14,.14,darkSteel,2.95);stringer.rotation.x=dir*.62;}

          // The island's common sector uses the extra canal length: a full
          // court, a broad exercise field, fixed tables and a covered pavilion.
          const courtZ=-10,courtW=16.6,courtD=26;pbox(0,courtZ,courtW,courtD,.055,new THREE.MeshStandardMaterial({color:0x59666b,roughness:.98}),.69);for(const [lx,lz,lw,ld] of [[0,courtZ-courtD/2,courtW,.12],[0,courtZ+courtD/2,courtW,.12],[-courtW/2,courtZ,.12,courtD],[courtW/2,courtZ,.12,courtD],[0,courtZ,courtW,.1]])pbox(lx,lz,lw,ld,.035,courtMat,.75);
          const circle=new THREE.Mesh(new THREE.RingGeometry(2.3,2.43,40),courtMat);circle.rotation.x=-Math.PI/2;circle.position.set(0,.79,courtZ);prison.add(circle);
          for(const hz of [courtZ-courtD/2+1.1,courtZ+courtD/2-1.1]){const post=pcylinder(0,hz,.11,.16,4.2,darkSteel,.76);post.rotation.z=0;pbox(0,hz-Math.sign(hz-courtZ)*.42,3.2,.18,1.85,paintedWall,4.05);const hoop=new THREE.Mesh(new THREE.TorusGeometry(.72,.075,8,24),warningMat);hoop.rotation.x=Math.PI/2;hoop.position.set(0,3.72,hz-Math.sign(hz-courtZ)*.92);prison.add(hoop);}
          const tableTops=[],stoolDefs=[];for(const tx of [-5,0,5]){tableTops.push([tx,1.63,8]);for(const [dx,dz] of [[-1.25,0],[1.25,0],[0,-1.25],[0,1.25]])stoolDefs.push([tx+dx,1.05,8+dz]);}instance('common-zone-tables',new THREE.CylinderGeometry(1.05,1.05,.18,18),galvanized,tableTops);instance('common-zone-stools',new THREE.CylinderGeometry(.42,.48,.22,14),galvanized,stoolDefs);for(const tx of [-5,0,5])pcylinder(tx,8,.12,.16,.85,darkSteel,.75);
          // A dedicated southern exercise field fills the enlarged platform.
          const exerciseZ=27,exerciseW=18,exerciseD=20;pbox(0,exerciseZ,exerciseW,exerciseD,.045,rubberMat,.71);for(const [lx,lz,lw,ld] of [[0,exerciseZ-exerciseD/2,exerciseW,.14],[0,exerciseZ+exerciseD/2,exerciseW,.14],[-exerciseW/2,exerciseZ,.14,exerciseD],[exerciseW/2,exerciseZ,.14,exerciseD]])pbox(lx,lz,lw,ld,.04,markMat,.76);
          prisonZoneBadge('ОБЩАЯ ЗОНА',0,8,'#e8c65b',1,5.7);prisonZoneBadge('СПОРТИВНЫЙ ДВОР',0,exerciseZ,'#e8c65b',1.05,5.7);
          for(const ex of [4.2,7.2])pcylinder(ex,exerciseZ,.11,.15,3.4,darkSteel,.75);pbox(5.7,exerciseZ,3.2,.12,.12,galvanized,4.0);pbox(-4.7,exerciseZ,3.5,1.05,.28,concreteDark,.84);for(const wx of [-6.8,-2.6])pcylinder(wx,exerciseZ,.72,.72,.32,rubberMat,1.5,16);pbox(-4.7,exerciseZ,5.0,.16,.16,galvanized,1.56);
          for(const dz of [-5.7,5.7]){for(const px of [-6.7,0,6.7])pcylinder(px,exerciseZ+dz,.16,.2,.58,galvanized,.75,12);}

          // Six open-front service rooms complete the daily prison routine.
          // They remain visual-only and leave the central south-gate route clear.
          const serviceRooms=[[-17,21,'СТОЛОВАЯ'],[17,21,'КУХНЯ'],[-17,27,'ДУШЕВЫЕ'],[17,27,'МЕДПУНКТ'],[-17,33,'СВИДАНИЯ'],[17,33,'ПРАЧЕЧНАЯ']];
          for(const [rx,rz,title] of serviceRooms){pbox(rx,rz,6.2,4.05,.08,title==='МЕДПУНКТ'?paintedWall:concreteDark,.74);pbox(rx,rz+1.95,6.2,.22,3.15,paintedWall,.76);for(const sx of [-3,3])pbox(rx+sx,rz,.22,4.05,3.15,concrete,.76);const accent=title==='МЕДПУНКТ'?'#8de9d8':'#e8c65b',roomLabel=panel(title,rx,3.62,rz+2.08,5.45,.78,accent);roomLabel.rotation.y=Math.PI;prisonZoneBadge(title,rx,rz,accent,.72,5.05);}
          // Canteen and kitchen.
          for(const tx of [-18.3,-15.7]){pbox(tx,20.65,1.9,.82,.18,galvanized,1.05);for(const sx of [-.7,.7])pcylinder(tx+sx,20.65,.16,.2,.62,darkSteel,.74);}
          pbox(16.6,20.7,4.7,1.05,1.05,galvanized,.76);for(const bx of [15.4,17.8]){const burner=pcylinder(bx,20.8,.32,.32,.08,darkSteel,1.86,16);burner.rotation.x=Math.PI/2;}pbox(20.1,20.65,1.05,1.2,2.35,lockerMat,.76);
          // Showers and infirmary.
          for(const sx of [-18.7,-17,-15.3]){pbox(sx,27,.12,3.1,2.5,glassMat,.76);pcylinder(sx+.55,28.15,.16,.2,.18,galvanized,2.86,12);}
          for(const bz of [26.35,27.75]){pbox(17,bz,4.4,1.05,.28,galvanized,.94);pbox(17,bz,4.05,.9,.32,pillowMat,1.22);pbox(18.45,bz,.14,.14,2.4,galvanized,.76);pbox(18.45,bz,.55,.08,.72,cellLightMat,2.52);}
          // Visitation booths and laundry machines.
          for(const vx of [-18.65,-17,-15.35]){pbox(vx,33,1.35,1.55,.82,concreteDark,.76);const screen=pbox(vx,32.62,1.1,.06,1.45,glassMat,1.38);screen.castShadow=false;pcylinder(vx-.35,32.6,.05,.06,.55,darkSteel,1.46,8);}
          for(const lx of [15.2,17,18.8]){pcylinder(lx,33.05,.72,.72,1.45,lockerMat,.76,18);const door=pcylinder(lx,33.52,.48,.48,.08,glassMat,1.45,18);door.rotation.x=Math.PI/2;for(const y of [1.0,1.8])pbox(lx,32.12,1.45,.52,.12,galvanized,y);}

          // Northern administration block: a visible police-station facade
          // with a real door anchor leading to the existing station interior.
          const pavilionZ=-34,adminFrontZ=pavilionZ+5.35;pbox(0,pavilionZ,18,11,.16,concreteDark,.72);const pavilionRoof=pbox(0,pavilionZ,19,12,.32,darkSteel,5.5);outline(pavilionRoof);
          pbox(0,pavilionZ-5.25,18,.42,4.55,paintedWall,.78);pbox(-8.78,pavilionZ,.42,10.5,4.55,paintedWall,.78);pbox(8.78,pavilionZ,.42,10.5,4.55,paintedWall,.78);
          for(const side of [-1,1]){pbox(side*5.35,adminFrontZ,7.2,.42,4.55,paintedWall,.78);pbox(side*1.92,adminFrontZ+.03,.28,.52,4.55,darkSteel,.78);const window=pbox(side*5.4,adminFrontZ+.23,3.9,.08,1.55,glassMat,2.05);window.castShadow=false;}
          const adminDoor=pbox(0,adminFrontZ+.24,3.35,.12,3.58,glassMat,.82);adminDoor.castShadow=false;pbox(0,adminFrontZ+.18,3.75,.18,.28,darkSteel,4.28);
          const adminStep=pbox(0,adminFrontZ+1.0,4.6,1.55,.18,concrete,.70);outline(adminStep);
          panel('ПОЛИЦЕЙСКИЙ УЧАСТОК',0,4.86,adminFrontZ+.28,15.2,1.36,'#58b9ff');
          prisonZoneBadge('ПОЛИЦЕЙСКИЙ УЧАСТОК',0,pavilionZ+1.4,'#58b9ff',1.02,7.15);
          for(const [px,pz] of [[-8.4,-4.8],[8.4,-4.8],[-8.4,4.8],[8.4,4.8]])pcylinder(px,pavilionZ+pz,.13,.18,4.75,galvanized,.75,10);
          for(const pz of [pavilionZ-2.4,pavilionZ+2.4])for(const px of [-5.5,5.5]){pbox(px,pz,3.7,.88,.18,galvanized,1.35);pbox(px,pz,3.9,.16,.16,darkSteel,.95);}

          // Elevated west control room watches the causeway and both galleries.
          const boothX=-halfX+5.7,boothZ=-9,booth=pbox(boothX,boothZ,5.1,10.2,4.85,concreteDark,.7);outline(booth);for(const [px,pz,w,d] of [[boothX-2.58,boothZ,.08,7.8],[boothX,boothZ-5.12,3.6,.08],[boothX,boothZ+5.12,3.6,.08]]){const pane=pbox(px,pz,w,d,1.6,glassMat,3.05);pane.castShadow=false;}pbox(boothX,boothZ,5.9,11,.34,darkSteel,5.55);pbox(boothX-1.45,boothZ,1.0,5.8,1.0,darkSteel,.75);for(const dz of [-2,-.7,.7,2]){const screen=pbox(boothX-2.03,boothZ+dz,.09,1.15,.75,new THREE.MeshBasicMaterial({color:dz<0?0x5ad5ff:0x73ff9c,toneMapped:false}),1.8);screen.castShadow=false;}
          const prisonTitle=panel('ИСПРАВИТЕЛЬНЫЙ КОМПЛЕКС № 20',-halfX-.46,8.3,0,22.5,2.7,'#e5b44d');prisonTitle.rotation.y=-Math.PI/2;const capacityTitle=panel(`${jail.cells||20} КАМЕР · ${jail.capacity||40} МЕСТ`,-halfX-.48,5.65,0,15.5,1.75,'#91d7ff');capacityTitle.rotation.y=-Math.PI/2;
          panel('ОБЩАЯ ЗОНА',0,1.22,8,10.5,1.45,'#e8c65b').rotation.x=-Math.PI/2;panel('СПОРТИВНЫЙ ДВОР',0,1.22,exerciseZ,11.8,1.45,'#e8c65b').rotation.x=-Math.PI/2;
          // Camera-facing entrance badges remain readable at the normal city
          // zoom, while the physical wall/floor signs still belong to the scene.
          const entranceBadge=labelSprite('ТЮРЬМА № 20','#e5b44d');entranceBadge.position.set(-halfX+4.5,13.2,0);entranceBadge.scale.set(14.8,3.25,1);entranceBadge.renderOrder=64;prison.add(entranceBadge);
          const capacityBadge=labelSprite(`${jail.cells||20} КАМЕР · ${jail.capacity||40} МЕСТ`,'#91d7ff');capacityBadge.position.set(-halfX+4.5,10.35,0);capacityBadge.scale.set(17.5,3.05,1);capacityBadge.renderOrder=63;prison.add(capacityBadge);

          // CCTV housings and blue-white gallery lighting complete the secure
          // institutional look without introducing any gameplay behaviour.
          for(const [cx,cy,cz,ry] of [[-halfX+6.8,8.75,-halfZ+8,0],[halfX-6.8,8.75,-halfZ+8,Math.PI],[-halfX+6.8,8.75,halfZ-8,0],[halfX-6.8,8.75,halfZ-8,Math.PI]]){const arm=pbox(cx,cz,.14,.14,1.25,galvanized,cy-1.1);arm.rotation.z=.65;const cam=pbox(cx+(ry?-.55:.55),cz,.95,.52,.52,darkSteel,cy);cam.rotation.y=ry;const lens=pcylinder(cx+(ry?-.98:.98),cz,.16,.2,.18,cellLightMat,cy+.16,12);lens.rotation.z=Math.PI/2;}
          renderer.domElement.dataset.jailArchitecture=jail.architecture||'open-gallery-correctional-complex';renderer.domElement.dataset.jailCells=String(authoredCells);renderer.domElement.dataset.jailCapacity=String(jail.capacity||authoredCells*2);renderer.domElement.dataset.jailFloors='2';renderer.domElement.dataset.jailCommonZone='court-exercise-admin-waiting-intake-release-canteen-kitchen-showers-infirmary-visitation-laundry';renderer.domElement.dataset.jailServiceRooms='6:open-front-visual-only';renderer.domElement.dataset.jailFootprint=`${widthTiles}x${depthTiles}-tiles`;renderer.domElement.dataset.jailFootprintScale=String(visual.footprintScale||((widthTiles*depthTiles)/(jail.radius*jail.radius*4)).toFixed(2));renderer.domElement.dataset.jailPlacement=visual.placement||'canal-island';renderer.domElement.dataset.jailCollision=visual.collisionProfile||'visible-perimeter-new-west-vehicle-gate-old-center-gate-sealed-v5';renderer.domElement.dataset.jailEntrances=String(visual.entrances||2);renderer.domElement.dataset.jailGateStyle='main-west-vehicle-sally-port-v266';renderer.domElement.dataset.jailPoliceStation='north-admin-door-existing-interior';renderer.domElement.dataset.jailResidentPolicy=visual.staffOnly?'staff-only':'world-default';renderer.domElement.dataset.jailSignage=`large-camera-facing-zone-badges-v264:${prisonZoneBadgeCount}`;renderer.domElement.dataset.jailIntakeWaitingCorner='south-west-opposite-release-gate-v313';renderer.domElement.dataset.jailVisualOnly='true';
        }
        const lair=worldSnapshot.landmarks.lair;
        if(lair){
          const x=toX(lair.c),z=toZ(lair.r),rad=Math.min(55,lair.radius*WORLD_SCALE),dirt=new THREE.MeshStandardMaterial({color:0x543b2d,roughness:1});
          const yard=new THREE.Mesh(new THREE.CircleGeometry(rad,48),dirt);yard.rotation.x=-Math.PI/2;yard.position.set(x,.09,z);yard.receiveShadow=true;scene.add(yard);
          const tentMats=[0x6e3d31,0x4a573b,0x725c36].map(color=>new THREE.MeshStandardMaterial({color,roughness:.9}));
          for(let i=0;i<8;i++){const a=i/8*Math.PI*2,tx=x+Math.cos(a)*rad*.64,tz=z+Math.sin(a)*rad*.64;const tent=new THREE.Mesh(new THREE.ConeGeometry(4.2,5.2,4),tentMats[i%3]);tent.position.set(tx,2.6,tz);tent.rotation.y=Math.PI/4-a;tent.castShadow=true;scene.add(tent);}
          const fire=new THREE.PointLight(0xff6b2c,28,28,2);fire.position.set(x,2,z);scene.add(fire);const flame=new THREE.Mesh(new THREE.ConeGeometry(.9,2.3,8),new THREE.MeshBasicMaterial({color:0xffb02e}));flame.position.set(x,1.2,z);scene.add(flame);
          const timber=new THREE.MeshStandardMaterial({color:0x543722,roughness:.92}),steel=new THREE.MeshStandardMaterial({color:0x34383b,metalness:.55,roughness:.58}),rope=new THREE.MeshStandardMaterial({color:0xc6ab75,roughness:1});
          for(let i=0;i<24;i++){const a=i/24*Math.PI*2,post=new THREE.Mesh(new THREE.CylinderGeometry(.16,.22,3.4,7),timber);post.position.set(x+Math.cos(a)*rad*.92,1.7,z+Math.sin(a)*rad*.92);post.castShadow=true;scene.add(post);}
          for(const [dx,dz] of [[-8,-6],[8,-6],[-8,7],[8,7]]){const crate=box(x+dx,z+dz,3,2.6,2.1,timber);outline(crate);}
          const ringFloor=box(x,z+rad*.3,11,9,.45,new THREE.MeshStandardMaterial({color:0x81705a,roughness:.96}));ringFloor.position.y=.24;
          for(const [dx,dz] of [[-5,-4.2],[5,-4.2],[-5,4.2],[5,4.2]]){const post=new THREE.Mesh(new THREE.CylinderGeometry(.14,.18,4.2,8),steel);post.position.set(x+dx,2.1,z+rad*.3+dz);scene.add(post);}
          for(const zz of [-4.2,4.2])for(let h=0;h<3;h++){const rail=box(x,z+rad*.3+zz,10,.1,.09,rope);rail.position.y=1.5+h*.7;}
          for(const xx of [-5,5])for(let h=0;h<3;h++){const rail=box(x+xx,z+rad*.3,.1,8.4,.09,rope);rail.position.y=1.5+h*.7;}
          for(const side of [-1,1]){const tower=box(x+side*rad*.72,z-rad*.6,3.4,3.4,5.8,timber);tower.position.y=2.9;outline(tower);const lamp=new THREE.PointLight(0xffb35a,12,20,2);lamp.position.set(tower.position.x,6.2,tower.position.z);scene.add(lamp);}
        }
        // Purchasable businesses build their own exact exterior later. Do not
        // attach their labels to an arbitrary nearby roof here.
        const districtDecor=(worldSnapshot.coast?.decor||[]).filter(d=>d&&Number.isFinite(+d.r)&&Number.isFinite(+d.c));
        const stoneDecor=new THREE.MeshStandardMaterial({color:0xb9b3a8,roughness:.75}),waterDecor=new THREE.MeshPhysicalMaterial({color:0x4bc8ed,roughness:.08,metalness:.06,transparent:true,opacity:.82,clearcoat:1}),woodDecor=new THREE.MeshStandardMaterial({color:0x765034,roughness:.88}),leafDecor=windLeafMaterial(0x256c38),trunkDecor=windTrunkMaterial(0x67432b);
        for(const d of districtDecor){
          const probe=bridge?.collisionProbe?.(+d.r,+d.c)||{blocked:true,tile:null},tile=probe.tile,x=toX(+d.c),z=toZ(+d.r),kind=String(d.kind||'');
          if(probe.blocked||tile===16)continue;
          if(kind==='city_fountain'||kind==='luxury_fountain'){
            const scale=(+d.scale||1)*(kind==='luxury_fountain'?1.15:1),basin=new THREE.Mesh(new THREE.CylinderGeometry(4.1*scale,4.55*scale,.75,40),stoneDecor);basin.position.set(x,.38,z);basin.castShadow=basin.receiveShadow=true;scene.add(basin);
            const pool=new THREE.Mesh(new THREE.CylinderGeometry(3.65*scale,3.65*scale,.12,40),waterDecor);pool.position.set(x,.81,z);scene.add(pool);
            const pedestal=new THREE.Mesh(new THREE.CylinderGeometry(.58*scale,.9*scale,2.3*scale,18),stoneDecor);pedestal.position.set(x,1.75*scale,z);pedestal.castShadow=true;scene.add(pedestal);
            for(let i=0;i<8;i++){const a=i/8*Math.PI*2,jet=new THREE.Mesh(new THREE.CylinderGeometry(.035,.055,1.9*scale,6),new THREE.MeshBasicMaterial({color:0xa9efff,transparent:true,opacity:.78}));jet.position.set(x+Math.cos(a)*1.8*scale,1.75*scale,z+Math.sin(a)*1.8*scale);jet.rotation.z=Math.cos(a)*.46;jet.rotation.x=Math.sin(a)*.46;scene.add(jet);}
            const crown=new THREE.Mesh(new THREE.SphereGeometry(.52*scale,16,10),new THREE.MeshBasicMaterial({color:0xd9f8ff}));crown.position.set(x,3.2*scale,z);scene.add(crown);
          }else if(kind==='modern_bench'||kind==='picnic_table'){
            const seat=box(x,z,3.7,1,.34,woodDecor);seat.position.y=1.05;for(const dx of [-1.45,1.45]){const leg=box(x+dx,z,.24,.65,1.05,stoneDecor);leg.position.y=.53;}if(kind==='modern_bench'){const back=box(x,z-.42,3.7,.22,1.4,woodDecor);back.position.y=1.7;}
          }else if(kind==='oak_tree'||kind==='pine_tree'||kind==='topiary'){
            const trunk=new THREE.Mesh(new THREE.CylinderGeometry(.34,.5,4.2,10),trunkDecor);trunk.position.set(x,2.1,z);trunk.castShadow=true;scene.add(trunk);if(kind==='pine_tree'){for(let i=0;i<3;i++){const crown=new THREE.Mesh(new THREE.ConeGeometry(2.8-i*.45,3.5,12),leafDecor);crown.position.set(x,4.4+i*1.45,z);crown.castShadow=true;scene.add(crown);}}else{for(const [dx,dy,dz] of [[0,5.2,0],[-1.1,4.8,.2],[1,4.9,.3],[0,5.5,-.8]]){const crown=new THREE.Mesh(new THREE.DodecahedronGeometry(kind==='topiary'?1.5:2.1,0),leafDecor);crown.position.set(x+dx,dy,z+dz);crown.castShadow=true;scene.add(crown);}}
          }
        }
        for(const hq of worldSnapshot.landmarks.districtHqs||[]){const x=toX(hq.c),z=toZ(hq.r),color=new THREE.Color(hq.color||'#e0b94a'),ring=new THREE.Mesh(new THREE.RingGeometry(5.4,5.85,48),new THREE.MeshBasicMaterial({color,transparent:true,opacity:.72,side:THREE.DoubleSide}));ring.rotation.x=-Math.PI/2;ring.position.set(x,.18,z);scene.add(ring);const beacon=new THREE.PointLight(color,15,22,2);beacon.position.set(x,3,z);scene.add(beacon);const roof=roofAnchorAt(hq.r,hq.c,9),label=labelSprite(`ШТАБ · ${hq.name}`,hq.color||'#e0b94a');label.position.set(roof.x,roof.y,roof.z);scene.add(label);}
        const buildAuthoredBankExterior3D=bank=>{
          const centerOffset={small:1,medium:1.5,large:1.5}[bank.size]||1.5,
            footprintTiles={small:2,medium:3,large:4}[bank.size]||3,
            x=toX(bank.c+centerOffset),z=toZ(bank.r+centerOffset),scale={small:.82,medium:1,large:1.24}[bank.size]||1;
          const root=new THREE.Group();root.position.set(x,0,z);root.name=`bank-exterior-${bank.id||bank.size}`;scene.add(root);
          const stone=new THREE.MeshStandardMaterial({color:bank.size==='small'?0xc2b89f:bank.size==='large'?0xa8adb0:0xbab19d,roughness:.58,metalness:.06});
          const stoneDark=new THREE.MeshStandardMaterial({color:bank.size==='large'?0x3d454c:0x625d52,roughness:.62,metalness:.18});
          const granite=new THREE.MeshStandardMaterial({color:0x242a30,roughness:.34,metalness:.42});
          const gold=new THREE.MeshStandardMaterial({color:0xd5ad45,roughness:.25,metalness:.82,envMap:cityEnvironment,envMapIntensity:1.2});
          const bronze=new THREE.MeshStandardMaterial({color:0x725126,roughness:.3,metalness:.78});
          const glass=new THREE.MeshPhysicalMaterial({color:0x79a9be,emissive:0x102b38,emissiveIntensity:.2,roughness:.07,metalness:.1,transparent:true,opacity:.62,transmission:.18,clearcoat:1});
          const roofMat=new THREE.MeshStandardMaterial({color:bank.size==='small'?0x314e69:0x27323d,roughness:.48,metalness:.42});
          const stepMat=new THREE.MeshStandardMaterial({color:0x85898b,roughness:.7,metalness:.08});
          const redCarpet=new THREE.MeshStandardMaterial({color:0x7d1722,roughness:.82});
          const screen=new THREE.MeshBasicMaterial({color:0x54c9f4,toneMapped:false});
          const addBox=(px,py,pz,w,h,d,mat,parent=root)=>{const q=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);q.position.set(px,py,pz);q.castShadow=q.receiveShadow=true;parent.add(q);return q;};
          const addCylinder=(px,py,pz,rt,rb,h,mat,segments=16,parent=root)=>{const q=new THREE.Mesh(new THREE.CylinderGeometry(rt,rb,h,segments),mat);q.position.set(px,py,pz);q.castShadow=q.receiveShadow=true;parent.add(q);return q;};
          // Keep the authored mass inside the same authoritative 2/3/4-tile footprint as Canvas and collisions.
          const footprint=footprintTiles*WORLD_SCALE,width=footprint*.9,depth=footprint*.74,bodyH=(bank.size==='small'?5.3:bank.size==='medium'?6.8:8.5)*scale,front=depth*.48;
          addBox(0,.24,0,width+1.4*scale,.48,depth+1.1*scale,granite);
          const bankBody=addBox(0,bodyH*.5,0,width,bodyH,depth,stone);
          if(bank.size!=='small'){
            const wingW=width*.24;
            addBox(-width*.58,bodyH*.38,-depth*.03,wingW,bodyH*.76,depth*.82,stoneDark);
            addBox(width*.58,bodyH*.38,-depth*.03,wingW,bodyH*.76,depth*.82,stoneDark);
            for(const side of [-1,1])addBox(side*width*.58,bodyH*.79,-depth*.03,wingW+.25,.26,depth*.9,gold);
          }
          addBox(0,bodyH+.22,0,width+.5,.44,depth+.45,roofMat);
          for(const side of [-1,1])addBox(side*(width*.5-.18),bodyH+.78,0,.36,1.15,depth+.25,stoneDark);
          for(const zSide of [-1,1])addBox(0,bodyH+.78,zSide*(depth*.5-.18),width+.25,1.15,.36,stoneDark);
          const porticoW=width*(bank.size==='small'?.72:.64),porticoDepth=2.45*scale,columnH=bodyH*(bank.size==='small'?.72:.68),porticoZ=front+porticoDepth*.38;
          addBox(0,columnH+.62*scale,porticoZ,porticoW+.65*scale,.52*scale,porticoDepth,stoneDark);
          const columnCount=bank.size==='small'?4:bank.size==='medium'?5:6;
          for(let i=0;i<columnCount;i++){
            const px=-porticoW*.43+i*(porticoW*.86/(columnCount-1));
            addCylinder(px,columnH*.5+.28,front+porticoDepth*.72,.22*scale,.31*scale,columnH,stone,14);
            addCylinder(px,columnH+.27,front+porticoDepth*.72,.36*scale,.27*scale,.32*scale,gold,14);
            addBox(px,.18,front+porticoDepth*.72,.76*scale,.34,.76*scale,stepMat);
          }
          const pedimentShape=new THREE.Shape();pedimentShape.moveTo(-porticoW*.53,0);pedimentShape.lineTo(0,2.35*scale);pedimentShape.lineTo(porticoW*.53,0);pedimentShape.closePath();
          const pediment=new THREE.Mesh(new THREE.ExtrudeGeometry(pedimentShape,{depth:.42*scale,bevelEnabled:false}),stoneDark);pediment.position.set(0,columnH+.88*scale,front+porticoDepth*.91);pediment.rotation.y=Math.PI;pediment.castShadow=true;root.add(pediment);
          const doorwayW=(bank.size==='small'?2.6:3.25)*scale;
          const doorH=bodyH*.58,doorGap=.12*scale,leafW=(doorwayW-doorGap)*.5;
          addBox(0,bodyH*.34,front-.04,doorwayW+.12*scale,doorH+.18*scale,.18,granite);
          const leftPivot=new THREE.Group(),rightPivot=new THREE.Group();
          leftPivot.position.set(-doorGap*.5-leafW,bodyH*.34,front+.19);rightPivot.position.set(doorGap*.5+leafW,bodyH*.34,front+.19);
          root.add(leftPivot,rightPivot);
          const leftLeaf=addBox(leafW*.5,0,0,leafW,doorH,.13,glass,leftPivot),rightLeaf=addBox(-leafW*.5,0,0,leafW,doorH,.13,glass,rightPivot);
          for(const leaf of [leftLeaf,rightLeaf])leaf.castShadow=false;
          addBox(leafW*.5,0,.08,.055*scale,doorH,.06,gold,leftPivot).castShadow=false;
          addBox(-leafW*.5,0,.08,.055*scale,doorH,.06,gold,rightPivot).castShadow=false;
          bankDoorActors.push({id:String(bank.id),left:leftPivot,right:rightPivot,open:0});
          addBox(0,bodyH*.34,front+.16,doorGap,doorH,.14,gold);
          for(const side of [-1,1])addBox(side*(doorwayW*.5+.17*scale),bodyH*.34,front+.18,.26*scale,bodyH*.64,.3*scale,bronze);
          for(let step=0;step<4;step++)addBox(0,.12+step*.16,front+porticoDepth*(.95+step*.2),porticoW*(1.04-step*.07),.24,1.2*scale,stepMat);
          addBox(0,.53,front+porticoDepth*1.72,2.15*scale,.08,4.6*scale,redCarpet);
          const windowRows=bank.size==='large'?3:2,windowCols=bank.size==='small'?3:bank.size==='medium'?5:7;
          for(let row=0;row<windowRows;row++)for(let col=0;col<windowCols;col++){
            const px=-width*.39+col*(width*.78/(windowCols-1));
            if(Math.abs(px)<doorwayW*.65&&row===0)continue;
            const py=bodyH*(.32+row*.22),pane=addBox(px,py,front+.105,width*.075,bodyH*.13,.1,glass);pane.castShadow=false;
            addBox(px,py,front+.18,.055,bodyH*.13+.08,.08,bronze).castShadow=false;
            addBox(px,py,front+.18,width*.075+.08,.055,.08,bronze).castShadow=false;
          }
          const seal=addCylinder(0,bodyH*.81,front+porticoDepth*.96,1.08*scale,1.08*scale,.22,gold,32);seal.rotation.x=Math.PI/2;
          const sealCore=addCylinder(0,bodyH*.81,front+porticoDepth*1.02,.76*scale,.76*scale,.12,granite,32);sealCore.rotation.x=Math.PI/2;
          for(let k=0;k<8;k++){const a=k/8*Math.PI*2,ray=addBox(Math.cos(a)*.54*scale,bodyH*.81+Math.sin(a)*.54*scale,front+porticoDepth*1.1,.09*scale,.62*scale,.08,gold);ray.rotation.z=a;ray.castShadow=false;}
          const sign=roofMountedSign(bank.size==='large'?'ЦЕНТРАЛЬНЫЙ БАНК':bank.name,'#e4bd55',bank.size==='small'?7.8:bank.size==='large'?13:10.5,1.65);sign.position.set(0,bodyH+.08,depth*.18);root.add(sign);
          const atmCount=bank.size==='large'?2:1;
          for(let i=0;i<atmCount;i++){
            const side=i===0?-1:1,ax=side*(porticoW*.5+1.05*scale),az=front+.52*scale;
            addBox(ax,1.18*scale,az,.9*scale,2.35*scale,.72*scale,granite);
            const atmScreen=addBox(ax,1.52*scale,az+.4*scale,.58*scale,.52*scale,.05,screen);atmScreen.castShadow=false;
            addBox(ax,.78*scale,az+.42*scale,.5*scale,.12*scale,.08,bronze).castShadow=false;
          }
          for(const side of [-1,1])for(let i=0;i<3;i++)addCylinder(side*(porticoW*.62),.68,front+2.2*scale+i*1.2*scale,.12,.18,1.15,gold,12);
          const serviceSide=bank.size==='small'?-1:1;
          addBox(serviceSide*(width*.5+.16),1.45,-depth*.18,.24,2.9,2.35*scale,granite);
          const serviceDoor=addBox(serviceSide*(width*.5+.31),1.4,-depth*.18,.08,2.55,1.85*scale,stoneDark);serviceDoor.castShadow=false;
          const dockLabel=roofMountedSign('ИНКАССАЦИЯ','#8fdcff',4.6,.78);dockLabel.position.set(serviceSide*(width*.5+.48),2.45,-depth*.18);dockLabel.rotation.y=serviceSide<0?Math.PI/2:-Math.PI/2;root.add(dockLabel);
          for(const [cx,cz,ry] of [[-width*.43,front+.12,0],[width*.43,front+.12,Math.PI]]){const arm=addBox(cx,bodyH*.7,cz,.12,.12,.62,bronze);arm.rotation.y=ry;const camera=addBox(cx+(ry?-.28:.28),bodyH*.7,cz+.23,.55,.32,.36,granite);camera.rotation.y=ry;}
          if(bank.size==='large'){
            const clock=addCylinder(0,bodyH+.95,-depth*.06,1.12,1.12,.28,stone,32);clock.rotation.x=Math.PI/2;
            const face=addCylinder(0,bodyH+.95,-depth*.19,.91,.91,.08,new THREE.MeshBasicMaterial({color:0xf4e7bd}),32);face.rotation.x=Math.PI/2;
            for(let k=0;k<12;k++){const a=k/12*Math.PI*2,mark=addBox(Math.cos(a)*.68,bodyH+.95+Math.sin(a)*.68,-depth*.25,.08,.18,.06,bronze);mark.rotation.z=-a;}
          }
          root.userData.bank=bank;root.userData.main=bankBody;root.userData.footprintTiles=footprintTiles;
          root.traverse(o=>{if(o.isMesh){o.userData.visualOnly=true;o.userData.bank=bank;}});
          return root;
        };
        for(const bank of worldSnapshot.landmarks.banks||[])bankExteriors.push(buildAuthoredBankExterior3D(bank));
        renderer.domElement.dataset.bankExterior='authored-bank-complex-v5';renderer.domElement.dataset.bankExteriorCount=String(bankExteriors.length);renderer.domElement.dataset.bankExteriorFeatures='portico-pediment-steps-wings-windows-atms-armored-dock-cctv-clock-proximity-double-doors';
        const gasRed=new THREE.MeshStandardMaterial({color:0xd74137,roughness:.48}),gasWhite=new THREE.MeshStandardMaterial({color:0xe9e5d9,roughness:.65}),gasDark=new THREE.MeshStandardMaterial({color:0x272d33,metalness:.42,roughness:.45});
        for(const gas of worldSnapshot.landmarks.gasStations||[]){const x=toX(gas.c+.7),z=toZ(gas.r+.7),canopy=box(x,z,10,7,.65,gasRed);canopy.position.y=5;for(const [dx,dz] of [[-4,-2.5],[4,-2.5],[-4,2.5],[4,2.5]]){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.18,.22,5,8),gasWhite);pole.position.set(x+dx,2.5,z+dz);scene.add(pole);}for(const dx of [-2,2]){const pump=box(x+dx,z,1.15,1.1,2.3,gasDark);pump.position.y=1.15;const screen=box(x+dx,z+.58,.55,.08,.48,new THREE.MeshBasicMaterial({color:0x63d8ff}));screen.position.y=1.55;}const label=roofMountedSign('АЗС','#ff554b',6.2,1.35);label.position.set(x,5.34,z+1.25);scene.add(label);}
        const buildGrandCasinoExterior3D=poi=>{
          const x=toX(poi.c),z=toZ(poi.r),root=new THREE.Group();root.position.set(x,0,z);root.name='grand-casino-exterior';scene.add(root);
          const burgundy=new THREE.MeshStandardMaterial({color:0x4b0b22,roughness:.46,metalness:.18}),wine=new THREE.MeshStandardMaterial({color:0x761330,roughness:.4,metalness:.22}),blackMarble=new THREE.MeshStandardMaterial({color:0x100b12,roughness:.22,metalness:.5}),cream=new THREE.MeshStandardMaterial({color:0xd8c7a4,roughness:.48,metalness:.2}),gold=new THREE.MeshStandardMaterial({color:0xd7a947,roughness:.22,metalness:.82,envMap:cityEnvironment,envMapIntensity:1.3}),glass=new THREE.MeshPhysicalMaterial({color:0x4d9fbd,emissive:0x16394a,emissiveIntensity:.32,roughness:.08,metalness:.08,transmission:.22,thickness:.32,clearcoat:1}),redCarpet=new THREE.MeshStandardMaterial({color:0x8f0d24,roughness:.72}),neonGold=new THREE.MeshBasicMaterial({color:0xffd76a,toneMapped:false}),neonRose=new THREE.MeshBasicMaterial({color:0xff315f,toneMapped:false}),bulbMaterial=new THREE.MeshBasicMaterial({color:0xffd86a,transparent:true,opacity:.9,toneMapped:false});
          const addBox=(xx,yy,zz,w,h,d,mat)=>{const q=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);q.position.set(xx,yy,zz);q.castShadow=q.receiveShadow=true;root.add(q);return q;};
          // A low, wide resort silhouette mirrors the lavish pre-3D casino instead of reading as another tower.
          addBox(0,.24,7.25,16.8,.48,8.6,blackMarble);addBox(0,.5,10.1,3.45,.1,10.2,redCarpet);
          addBox(-5.35,3.45,4.15,4.8,6.45,3.45,burgundy);addBox(5.35,3.45,4.15,4.8,6.45,3.45,burgundy);
          addBox(0,5.35,3.85,6.5,10.25,3.9,wine);addBox(0,10.7,3.85,7.05,.42,4.15,gold);
          addBox(-5.35,6.82,4.15,5.1,.28,3.7,gold);addBox(5.35,6.82,4.15,5.1,.28,3.7,gold);
          for(const sx of [-6.35,-5.35,-4.35,4.35,5.35,6.35])for(const y of [2.6,4.35])addBox(sx,y,5.91,.54,.82,.08,(Math.round(sx+y*10)&1)?neonGold:neonRose);
          for(const sx of [-1.9,-.65,.65,1.9])for(const y of [4.25,6.05,7.85])addBox(sx,y,5.83,.66,.9,.09,(Math.round((sx+3)*10+y)&1)?neonGold:neonRose);
          // Grand portico: gold columns, glass double doors and a deep marquee canopy.
          addBox(0,2.15,6.05,4.35,4.1,.22,glass);addBox(0,2.2,6.18,.1,4.05,.13,gold);
          for(const sx of [-3.25,-1.75,1.75,3.25]){const column=new THREE.Mesh(new THREE.CylinderGeometry(.24,.34,4.9,16),gold);column.position.set(sx,2.45,6.65);column.castShadow=true;root.add(column);const cap=new THREE.Mesh(new THREE.CylinderGeometry(.43,.34,.25,16),cream);cap.position.set(sx,4.86,6.65);root.add(cap);}
          addBox(0,5.1,7.15,8.3,.45,3.2,gold);addBox(0,5.38,7.15,7.65,.16,2.72,blackMarble);
          const makeSignTexture=()=>{const cv=document.createElement('canvas');cv.width=1024;cv.height=320;const c=cv.getContext('2d'),g=c.createLinearGradient(0,0,1024,320);g.addColorStop(0,'#160710');g.addColorStop(.5,'#4c0b23');g.addColorStop(1,'#160710');c.fillStyle=g;c.fillRect(0,0,1024,320);c.strokeStyle='#ff396b';c.lineWidth=22;c.strokeRect(15,15,994,290);c.strokeStyle='#f3c858';c.lineWidth=9;c.strokeRect(42,42,940,236);for(let i=0;i<22;i++){c.fillStyle=i%2?'#ffe584':'#ff547a';c.beginPath();c.arc(58+i*43.2,58,7,0,Math.PI*2);c.fill();c.beginPath();c.arc(58+i*43.2,262,7,0,Math.PI*2);c.fill();}c.textAlign='center';c.textBaseline='middle';c.shadowColor='#ffcf59';c.shadowBlur=24;c.fillStyle='#fff0a8';c.font='900 104px Georgia,serif';c.fillText('GRAND CASINO',512,154);c.shadowBlur=0;c.fillStyle='#f4c85a';c.font='700 30px system-ui,sans-serif';c.fillText('GAMES  •  SHOWS  •  JACKPOT',512,228);const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());tx.minFilter=THREE.LinearFilter;tx.generateMipmaps=false;return tx;};
          const sign=new THREE.Mesh(new THREE.PlaneGeometry(11.6,3.62),new THREE.MeshBasicMaterial({map:makeSignTexture(),transparent:true,side:THREE.DoubleSide,toneMapped:false}));sign.position.set(0,8.05,5.96);sign.renderOrder=7;root.add(sign);
          // Roof crown and jackpot ticker reproduce the landmark silhouette of the Canvas casino.
          addBox(0,11.25,3.85,5.8,.64,.72,gold);for(const [sx,h] of [[-2.25,2.1],[-1.1,2.75],[0,3.25],[1.1,2.75],[2.25,2.1]]){const spike=new THREE.Mesh(new THREE.ConeGeometry(.42,h,4),sx===0?neonRose:gold);spike.position.set(sx,11.55+h/2,3.85);spike.rotation.y=Math.PI/4;root.add(spike);}
          const jackpot=addBox(0,10.35,4.28,5.3,1.05,.24,blackMarble),jackpotText=labelSprite('JACKPOT $1,004,998','#ffd45a');jackpotText.position.set(0,10.35,4.48);jackpotText.scale.set(5.1,.92,1);jackpotText.material.depthTest=true;root.add(jackpotText);
          // Velvet ropes and brass bollards frame the carpet without adding collision geometry.
          for(const sx of [-2.15,2.15])for(const zz of [8.2,11.1,14]){const post=new THREE.Mesh(new THREE.CylinderGeometry(.1,.15,1.35,12),gold);post.position.set(sx,.9,zz);root.add(post);const cap=new THREE.Mesh(new THREE.SphereGeometry(.2,12,8),neonGold);cap.position.set(sx,1.62,zz);root.add(cap);}
          for(const sx of [-2.15,2.15])for(const zz of [9.65,12.55]){const rope=new THREE.Mesh(new THREE.TorusGeometry(1.46,.07,7,20,Math.PI),new THREE.MeshStandardMaterial({color:0x9e1733,roughness:.5}));rope.rotation.set(0,Math.PI/2,Math.PI/2);rope.position.set(sx,1.35,zz);root.add(rope);}
          const bulbPositions=[];for(let i=0;i<18;i++){const px=-4.05+i*(8.1/17);bulbPositions.push([px,5.18,8.76],[px,5.18,5.54]);}for(const side of [-1,1])for(let i=0;i<6;i++)bulbPositions.push([side*4.05,5.18,6+i*.48]);const bulbs=new THREE.InstancedMesh(new THREE.SphereGeometry(.13,8,6),bulbMaterial,bulbPositions.length),matrix=new THREE.Matrix4();bulbPositions.forEach((p,i)=>{matrix.makeTranslation(...p);bulbs.setMatrixAt(i,matrix);});bulbs.instanceMatrix.needsUpdate=true;root.add(bulbs);
          const entranceGlow=new THREE.PointLight(0xffb84b,26,26,2);entranceGlow.position.set(0,5.2,8);root.add(entranceGlow);for(const side of [-1,1]){const beam=new THREE.SpotLight(0xffe2a1,42,56,.26,.72,1.4);beam.position.set(side*5.4,7.4,4.5);beam.target.position.set(side*10,0,24);root.add(beam,beam.target);}
          casinoExteriorAnimation=(t,night)=>{const pulse=.72+.28*Math.sin(t*.0052);bulbMaterial.opacity=.42+night*.55*pulse;entranceGlow.intensity=4+night*(18+8*pulse);root.children.forEach(q=>{if(q.isSpotLight)q.intensity=night*(30+12*Math.sin(t*.0007+(q.position.x>0?1:0)));});jackpot.visible=true;};
          renderer.domElement.dataset.casinoExterior='grand-resort-canvas-parity';
        };
        const specialColors={hospital:'#e64b55',hospital_east:'#e64b55',firestation:'#f05a45',junkyard:'#e1a33a',police:null,casino:null,mansion:'#e4c267',factory:'#e58b3c',market:'#47d79b',arena:'#ffcf4d',blackmarket:'#7d6cff',blackmarket_bellini:'#22242a',blackmarket_moretti:'#eee8da',gym:'#66b8ff',job_office:'#e7c75d'};
        const poiWithAuthoredSign=new Set(['hospital','hospital_east','factory','market','blackmarket','blackmarket_bellini','blackmarket_moretti']);
        for(const poi of worldSnapshot.pois||[]){const accent=specialColors[poi.id];if(!accent)continue;const x=toX(poi.c),z=toZ(poi.r),mat=new THREE.MeshBasicMaterial({color:accent}),steel=new THREE.MeshStandardMaterial({color:0x46515a,metalness:.55,roughness:.42});if(poi.id==='hospital'){const a=box(x,z,1.2,.35,5.2,mat);a.position.y=8;const b=box(x,z,4.2,.35,1.2,mat);b.position.y=8;}else if(poi.id==='factory'){renderer.domElement.dataset.factoryPoiChimneys='handled-by-authored-architecture';}else if(poi.id==='casino'){const crown=new THREE.Mesh(new THREE.TorusGeometry(3.3,.28,10,32),mat);crown.rotation.x=Math.PI/2;crown.position.set(x,11,z);scene.add(crown);const glow=new THREE.PointLight(accent,22,24,2);glow.position.set(x,9,z);scene.add(glow);}else if(poi.id==='firestation'){for(const dx of [-2.4,0,2.4]){const door=box(x+dx,z+4.1,2.05,.16,3.1,new THREE.MeshStandardMaterial({color:0x8e2525,roughness:.65}));door.position.y=1.55;}const mast=new THREE.Mesh(new THREE.CylinderGeometry(.1,.14,8,8),steel);mast.position.set(x-4,4,z+3);scene.add(mast);}else if(poi.id==='arena'){const ring=new THREE.Mesh(new THREE.TorusGeometry(5,.32,8,40),mat);ring.rotation.x=-Math.PI/2;ring.position.set(x,.3,z);scene.add(ring);for(let i=0;i<6;i++){const a=i/6*Math.PI*2,pole=new THREE.Mesh(new THREE.CylinderGeometry(.12,.16,4.5,8),steel);pole.position.set(x+Math.cos(a)*5,2.25,z+Math.sin(a)*5);scene.add(pole);}}else if(poi.id==='gym'){for(const dx of [-2.4,2.4]){const bar=new THREE.Mesh(new THREE.CylinderGeometry(.18,.18,4.2,10),steel);bar.rotation.z=Math.PI/2;bar.position.set(x+dx,6,z);scene.add(bar);for(const sx of [-1.7,1.7]){const weight=new THREE.Mesh(new THREE.CylinderGeometry(.65,.65,.35,14),mat);weight.rotation.z=Math.PI/2;weight.position.set(x+dx+sx,6,z);scene.add(weight);}}}else if(poi.id.startsWith('blackmarket')){const portal=new THREE.Mesh(new THREE.TorusGeometry(2.6,.32,10,32),mat);portal.position.set(x,4.5,z+3.6);scene.add(portal);const glow=new THREE.PointLight(accent,16,18,2);glow.position.set(x,4,z+3);scene.add(glow);}else if(poi.id==='market'){for(let i=-2;i<=2;i++){const awning=box(x+i*2.1,z+4,1.8,2.1,.18,new THREE.MeshStandardMaterial({color:i%2?0xf3d560:0x48b887,roughness:.6}));awning.position.y=3.4;}}else if(poi.id==='job_office'){const clockFace=new THREE.Mesh(new THREE.CylinderGeometry(1.45,1.45,.22,24),new THREE.MeshBasicMaterial({color:0xffe59a}));clockFace.rotation.x=Math.PI/2;clockFace.position.set(x,8,z+3.7);scene.add(clockFace);}if(!poiWithAuthoredSign.has(poi.id)){const roof=roofAnchorAt(poi.r,poi.c,9),sign=roofMountedSign(poi.label,accent,Math.min(12,Math.max(8,6.6+String(poi.label||'').length*.24)),1.55);sign.position.set(roof.x,roof.y-2.92,roof.z);scene.add(sign);}renderer.domElement.dataset.poiDuplicateLabels='removed-v326';}
        // The major market is an open civic plaza in the 2D canon. Build the
        // full five-department landmark here instead of leaving five roof slabs.
        const majorMarketPoi=(worldSnapshot.pois||[]).find(p=>p.id==='market');
        if(majorMarketPoi){
          const staticDetailStart=scene.children.length;
          const mx=toX(majorMarketPoi.c),mz=toZ(majorMarketPoi.r),stone=new THREE.MeshStandardMaterial({color:0xa98962,roughness:.88}),stoneDark=new THREE.MeshStandardMaterial({color:0x6d513b,roughness:.9}),marketWood=new THREE.MeshStandardMaterial({color:0x684022,roughness:.82}),marketGold=new THREE.MeshStandardMaterial({color:0xcf9c35,roughness:.36,metalness:.58}),marketCream=new THREE.MeshStandardMaterial({color:0xead9b7,roughness:.78}),marketGreen=new THREE.MeshStandardMaterial({color:0x357757,roughness:.72}),marketSteel=new THREE.MeshStandardMaterial({color:0x59636a,roughness:.4,metalness:.72}),marketSpiceMaterials=[0xdb9c31,0xb94c38,0x6e8b3b].map(color=>new THREE.MeshStandardMaterial({color,roughness:.9})),marketBulbMaterials=[0xff6f62,0xffd36b,0x71e5bd].map(color=>new THREE.MeshBasicMaterial({color,toneMapped:false}));
          const marketProduceAccentMaterials=[new THREE.MeshStandardMaterial({color:0xe0b43c,roughness:.92}),new THREE.MeshStandardMaterial({color:0x6b9a43,roughness:.92})],marketProductGeometries={fruitSmall:new THREE.SphereGeometry(.12,9,7),fruitLarge:new THREE.SphereGeometry(.145,9,7),spice:new THREE.ConeGeometry(.12,.38,8),fish:new THREE.CapsuleGeometry(.09,.32,5,10),meat:new THREE.CapsuleGeometry(.13,.22,6,10)},marketProductBatches=new Map();
          const queueMarketProduct=(geometryKey,material,x,y,z,rotationZ=0)=>{const key=`${geometryKey}:${material.uuid}`;if(!marketProductBatches.has(key))marketProductBatches.set(key,{geometry:marketProductGeometries[geometryKey],material,items:[]});marketProductBatches.get(key).items.push({x,y,z,rotationZ});};
          const flushMarketProducts=()=>{const matrix=new THREE.Matrix4(),position=new THREE.Vector3(),rotation=new THREE.Quaternion(),scale=new THREE.Vector3(1,1,1),euler=new THREE.Euler();for(const {geometry,material,items} of marketProductBatches.values()){const batch=new THREE.InstancedMesh(geometry,material,items.length);items.forEach((item,index)=>{rotation.setFromEuler(euler.set(0,0,item.rotationZ));matrix.compose(position.set(item.x,item.y,item.z),rotation,scale);batch.setMatrixAt(index,matrix);});batch.instanceMatrix.needsUpdate=true;batch.castShadow=true;batch.receiveShadow=true;scene.add(batch);}};
          const plaza=box(mx,mz,23,18,.24,stone);plaza.position.y=.12;plaza.receiveShadow=true;outline(plaza);
          for(let stripe=-4;stripe<=4;stripe++){const paver=box(mx+stripe*2.45,mz,2.28,17.35,.035,stripe%2?stone:stoneDark);paver.position.y=.265;paver.receiveShadow=true;}
          const stallData=[[-6,-3.4,'FRUTTA',0xb93636,0xc84232],[-.5,-4.25,'VERDURA',0x2f8a4f,0x60a946],[5.8,-3.1,'SPEZIE',0x9c47a5,0xdc9b32],[-3.2,3.05,'PESCE',0x397eb3,0x80b9ca],[3.6,3.15,'CARNE',0xb94e36,0xa8383d]];
          for(let stallIndex=0;stallIndex<stallData.length;stallIndex++){
            const [dx,dz,title,canopyColor,productColor]=stallData[stallIndex],sx=mx+dx,sz=mz+dz,canopyMat=new THREE.MeshStandardMaterial({color:canopyColor,roughness:.67}),productMat=new THREE.MeshStandardMaterial({color:productColor,roughness:.9}),produceMaterials=[productMat,...marketProduceAccentMaterials];
            const counter=box(sx,sz,4.5,2.2,.82,marketWood);counter.position.y=.68;outline(counter);
            for(let slat=-4;slat<=4;slat++){const slatMesh=box(sx+slat*.43,sz+1.12,.055,.08,.68,marketGold);slatMesh.position.y=.68;}
            for(const px of [-1.95,1.95])for(const pz of [-.82,.82]){const post=box(sx+px,sz+pz,.14,.14,3.45,marketWood);post.position.y=1.86;}
            const canopy=box(sx,sz,4.85,2.65,.16,canopyMat);canopy.position.y=3.48;canopy.rotation.z=(stallIndex%2?1:-1)*.035;
            for(let stripe=-3;stripe<=3;stripe++){const band=box(sx+stripe*.65,sz,canopyColor===0x2f8a4f?.32:.34,2.7,.045,stripe%2?marketCream:canopyMat);band.position.y=3.58;band.rotation.z=canopy.rotation.z;}
            for(let crateIndex=-1;crateIndex<=1;crateIndex++){const crate=box(sx+crateIndex*1.28,sz+.12,1.04,1.25,.36,marketWood);crate.position.y=1.18;for(let product=0;product<8;product++){const itemX=sx+crateIndex*1.28+(product%4-1.5)*.2,itemY=1.48+Math.floor(product/4)*.18,itemZ=sz+(product%2-.5)*.5;if(title==='PESCE')queueMarketProduct('fish',productMat,itemX,itemY,itemZ,Math.PI/2);else if(title==='CARNE')queueMarketProduct('meat',productMat,itemX,itemY,itemZ,Math.PI/2);else if(title==='SPEZIE')queueMarketProduct('spice',marketSpiceMaterials[(crateIndex+product+12)%3],itemX,itemY,itemZ);else queueMarketProduct(product%2?'fruitLarge':'fruitSmall',produceMaterials[(product+crateIndex+4)%3],itemX,itemY,itemZ);}}
            const stallSign=roofMountedSign(title,title==='PESCE'?'#aeeeff':title==='VERDURA'?'#b8f69a':'#ffe0a0',4.3,.82);stallSign.position.set(sx,3.15,sz+.72);scene.add(stallSign);
          }
          flushMarketProducts();
          // Formal entrance arch and clock pavilion give the outdoor market a strong silhouette.
          for(const ax of [-5.7,5.7]){const column=new THREE.Mesh(new THREE.CylinderGeometry(.34,.46,5.4,16),marketCream);column.position.set(mx+ax,2.95,mz+8);column.castShadow=true;scene.add(column);const cap=box(mx+ax,mz+8,1.05,1.05,.28,marketGold);cap.position.y=5.72;}
          const lintel=box(mx,mz+8,12.1,.72,.52,marketGold);lintel.position.y=5.45;const arch=new THREE.Mesh(new THREE.TorusGeometry(3.55,.28,10,32,Math.PI),marketGold);arch.position.set(mx,5.15,mz+8.42);arch.rotation.z=Math.PI;scene.add(arch);
          const towerBase=box(mx,mz-8,4.2,3.15,4.8,marketCream);towerBase.position.y=2.65;outline(towerBase);const towerRoof=new THREE.Mesh(new THREE.ConeGeometry(3.2,2.5,4),marketGreen);towerRoof.rotation.y=Math.PI/4;towerRoof.position.set(mx,6.25,mz-8);towerRoof.castShadow=true;scene.add(towerRoof);
          const clockFace=new THREE.Mesh(new THREE.CylinderGeometry(1.03,1.03,.18,28),marketCream);clockFace.rotation.x=Math.PI/2;clockFace.position.set(mx,4.15,mz-6.38);scene.add(clockFace);const clockRim=new THREE.Mesh(new THREE.TorusGeometry(1.03,.11,9,28),marketGold);clockRim.position.copy(clockFace.position);clockRim.position.z+=.11;scene.add(clockRim);for(const [length,angle] of [[.72,-.55],[.92,.92]]){const hand=box(mx,mz-6.15,.07,.06,length,marketSteel);hand.position.y=4.15+Math.cos(angle)*length*.22;hand.rotation.z=angle;}
          for(const poleX of [-9,9]){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.07,.1,5.7,9),marketSteel);pole.position.set(mx+poleX,2.95,mz);scene.add(pole);}for(let bulbIndex=0;bulbIndex<13;bulbIndex++){const bx=mx-9+bulbIndex*1.5,by=5.35-.75*Math.sin(bulbIndex/12*Math.PI),bulb=new THREE.Mesh(new THREE.SphereGeometry(.11,9,6),marketBulbMaterials[bulbIndex%3]);bulb.position.set(bx,by,mz);scene.add(bulb);}
          for(const [dx,dz] of [[-8,6],[-7.1,6.2],[-6.3,5.8]]){const sack=new THREE.Mesh(new THREE.SphereGeometry(.42,12,8),new THREE.MeshStandardMaterial({color:0x9b7848,roughness:.95}));sack.position.set(mx+dx,.65,mz+dz);sack.scale.set(.82,1.15,.66);scene.add(sack);}for(const [dx,dz] of [[7.4,6.2],[8.3,5.7]]){const amphora=new THREE.Mesh(new THREE.LatheGeometry([new THREE.Vector2(.08,0),new THREE.Vector2(.34,.15),new THREE.Vector2(.42,.65),new THREE.Vector2(.24,1),new THREE.Vector2(.14,1.18),new THREE.Vector2(.18,1.32)],16),new THREE.MeshStandardMaterial({color:0x9d5734,roughness:.88}));amphora.position.set(mx+dx,.26,mz+dz);scene.add(amphora);}
          authoredLandmarkStaticDetails.push(...scene.children.slice(staticDetailStart));
          renderer.domElement.dataset.majorMarketExterior='open-air-five-departments-clock-plaza-v1';
        }
        // Свалка занимает почти квартал: ограда, штабеля остовов и пресс.
        // Она может отсутствовать в начальном снимке и приехать позднее вместе
        // с сектором, поэтому сборка вынесена в одноразовый потоковый helper.
        ensureJunkyardVisual=(snapshot,source='initial')=>{
        if(junkyardVisualBuilt)return true;
        for(const poi of snapshot?.pois||[])if(poi.id==='junkyard'){
          junkyardVisualBuilt=true;
          const steel=new THREE.MeshStandardMaterial({color:0x3d464b,metalness:.68,roughness:.44}),rust=new THREE.MeshStandardMaterial({color:0x754326,roughness:.8,metalness:.42}),dirtMat=new THREE.MeshStandardMaterial({color:0x332f29,roughness:1}),trashMats=[0x596249,0x675844,0x454b50,0x72573f,0x3f554f].map(color=>new THREE.MeshStandardMaterial({color,roughness:.97,metalness:.08})),wreckMats=[0x17191a,0x512e27,0x38433d,0x4b3d2d].map(color=>new THREE.MeshStandardMaterial({color,roughness:.9,metalness:.38}));
          const lots=[[86.5,66.5],[86.5,76.5],[96.5,66.5],[96.5,76.5],[106.5,66.5],[106.5,76.5]];
          for(const [lr,lc] of lots){const lx=toX(lc),lz=toZ(lr),pad=new THREE.Mesh(new THREE.PlaneGeometry(WORLD_SCALE*5.75,WORLD_SCALE*5.75),dirtMat);pad.rotation.x=-Math.PI/2;pad.position.set(lx,.17,lz);pad.receiveShadow=true;scene.add(pad);for(let k=-2;k<=2;k++){for(const side of [-1,1]){const post=new THREE.Mesh(new THREE.CylinderGeometry(.075,.11,2.35,6),steel);post.position.set(lx+side*WORLD_SCALE*2.85,1.17,lz+k*WORLD_SCALE*1.18);scene.add(post);}}}
          const moundDefs=[[84.9,65.5,2.5,4.8],[87.1,68,2.1,3.7],[84.9,75.5,2.8,5.4],[87.3,78,2.15,4.1],[94.8,64.9,2.7,5.1],[97.4,68,2.35,4.5],[95,75.5,3,5.8],[97.5,78,2.2,4.2],[104.8,65.3,3.1,6],[107.4,68,2.2,4.3],[105,75.4,2.7,5.2],[107.5,78.1,2.25,4.4]];
          moundDefs.forEach(([r,c,s,h],i)=>{const root=new THREE.Group();root.position.set(toX(c),.2,toZ(r));for(let q=0;q<7;q++){const chunk=new THREE.Mesh(new THREE.DodecahedronGeometry(s*(.52+(q%3)*.13),0),trashMats[(i+q)%trashMats.length]);const a=q*2.399;chunk.position.set(Math.cos(a)*s*.72,(q%3)*h*.16,Math.sin(a)*s*.6);chunk.scale.set(1.25,.72+(q%2)*.28,1);chunk.rotation.set(q*.31,a,q*.19);chunk.castShadow=true;root.add(chunk);}scene.add(root);});
          const wreckDefs=[[85.2,67.7,0,0],[86.4,65.7,.3,0],[87.5,67.2,-.2,1],[85,77.5,.2,0],[87.2,75.3,-.3,1],[94.7,67.7,.15,1],[97.2,65.2,-.22,0],[95.2,77.7,.28,1],[97.5,75.3,-.18,0],[96.4,77,0,1],[104.8,67.7,.2,1],[107.3,65.2,-.25,0],[105.1,77.7,.3,0],[107.4,75.2,-.2,1]];
          wreckDefs.forEach(([r,c,turn,burning],i)=>{const wx=toX(c),wz=toZ(r),body=box(wx,wz,4.5,2.55,.68,wreckMats[i%wreckMats.length]);body.position.y=.62+(i%3===2?.7:0);body.rotation.set(0,turn,(i%2?-.08:.06));for(const sx of [-1,1])for(const sz of [-1,1]){const tire=new THREE.Mesh(new THREE.TorusGeometry(.38,.13,8,15),new THREE.MeshStandardMaterial({color:0x111213,roughness:1}));tire.position.set(wx+sx*1.42,.38+(i%3===2?.7:0),wz+sz*.95);tire.rotation.x=Math.PI/2;scene.add(tire);}if(burning){const glow=new THREE.PointLight(0xff5b18,18,18,2);glow.position.set(wx,1.6,wz);scene.add(glow);for(let f=0;f<4;f++){const flame=new THREE.Mesh(new THREE.ConeGeometry(.42+f*.07,1.5+f*.22,7),new THREE.MeshBasicMaterial({color:f%2?0xff7a16:0xffd04a,transparent:true,opacity:.88,toneMapped:false}));flame.position.set(wx+(f-1.5)*.45,1.3+(f%2)*.24,wz+(f%2?-.3:.28));flame.rotation.z=(f-1.5)*.08;scene.add(flame);}for(let s=0;s<4;s++){const smoke=new THREE.Mesh(new THREE.SphereGeometry(.58+s*.17,8,6),new THREE.MeshBasicMaterial({color:0x17191b,transparent:true,opacity:.28-s*.035,depthWrite:false}));smoke.position.set(wx+(s%2?-.35:.35),2.4+s*1.05,wz+(s%2?.2:-.18));scene.add(smoke);}}});
          for(const [r,c] of [[84.8,78.1],[88,74.9],[94.8,68.2],[98,64.8]])for(let t=0;t<4;t++){const tire=new THREE.Mesh(new THREE.TorusGeometry(.58,.2,8,16),new THREE.MeshStandardMaterial({color:0x111315,roughness:1}));tire.position.set(toX(c),.3+t*.38,toZ(r));tire.rotation.x=Math.PI/2;tire.rotation.z=t*.22;scene.add(tire);}
          const crusher=box(toX(76.8),toZ(96.7),5.2,5.6,4.5,rust);crusher.position.y=2.25;outline(crusher);const claw=new THREE.Mesh(new THREE.TorusGeometry(1.3,.18,8,18,Math.PI*1.45),steel);claw.rotation.set(Math.PI/2,0,.7);claw.position.set(toX(76.8),6.2,toZ(95.3));scene.add(claw);
          if(source!=='initial'){const label=roofMountedSign('ГОРОДСКАЯ СВАЛКА','#e1a33a',11.5,1.65);label.position.set(toX(poi.c),7.08,toZ(poi.r));scene.add(label);}
          renderer.domElement.dataset.junkyardProfile='sector-streamed-six-lot-scrap-mountains-burning-wrecks-v226';
          renderer.domElement.dataset.junkyardStreamState=`built:${source}`;
          return true;
        }
        renderer.domElement.dataset.junkyardStreamState='waiting-for-sector';
        return false;
        };
        ensureJunkyardVisual(worldSnapshot,'initial');
        for(const casino of worldSnapshot.pois||[])if(casino.id==='casino')buildGrandCasinoExterior3D(casino);
        const track=worldSnapshot.landmarks.raceTrack||[],trackMat=new THREE.MeshStandardMaterial({color:0x20252a,roughness:.48,metalness:.18});
        for(let i=0;i<track.length;i++){const a=track[i],b=track[(i+1)%track.length],ax=toX(a.c),az=toZ(a.r),bx=toX(b.c),bz=toZ(b.r),dx=bx-ax,dz=bz-az,len=Math.hypot(dx,dz);const seg=new THREE.Mesh(new THREE.PlaneGeometry(13,len),trackMat);seg.rotation.x=-Math.PI/2;seg.rotation.z=-Math.atan2(dz,dx)+Math.PI/2;seg.position.set((ax+bx)/2,.13,(az+bz)/2);seg.receiveShadow=true;scene.add(seg);}
      }
      const roadMat = new THREE.MeshStandardMaterial({color:0xaab2b7,map:asphaltTexture,roughness:selectedWeather==='rain'?.24:.84,roughnessMap:asphaltTexture,metalness:selectedWeather==='rain'?.22:.06,bumpMap:asphaltTexture,bumpScale:.07,envMap:cityEnvironment,envMapIntensity:selectedWeather==='rain'?1.3:.16});
      const curbMat = new THREE.MeshStandardMaterial({color:0x7a8285,map:concreteTexture,roughness:.94,bumpMap:concreteTexture,bumpScale:.035});
      const lineMat = new THREE.MeshBasicMaterial({ color: 0xd4ae3f });
      if(worldSnapshot){
        const cityPaving=new THREE.MeshStandardMaterial({color:0x626d72,map:concreteTexture,roughness:.96,bumpMap:concreteTexture,bumpScale:.025}),parkPaving=new THREE.MeshStandardMaterial({color:0x276545,roughness:1}),sandPaving=new THREE.MeshStandardMaterial({color:0xd0aa6a,roughness:1}),waterPaving=new THREE.MeshPhysicalMaterial({color:0x087b9d,roughness:.1,metalness:.15,transmission:.08,clearcoat:1,clearcoatRoughness:.08,transparent:true,opacity:.91,envMap:cityEnvironment,envMapIntensity:1.2});
        const pavingBuckets=new Map([[cityPaving,[]],[parkPaving,[]],[sandPaving,[]],[waterPaving,[]]]);
        for(const b of worldSnapshot.blocks){
          const x=(b.c0+6.5-originC)*WORLD_SCALE,z=(b.r0+6.5-originR)*WORLD_SCALE;
          // Mixed coastal blocks can still contain live roads and pavements.
          // Never flood the whole decorative pad unless the block is genuinely
          // water-only; the authored coast/canal meshes render the real water.
          const waterOnly=b.water>80&&!b.roads&&!b.pavement&&!b.buildings;
          const material=waterOnly?waterPaving:b.sand>20?sandPaving:b.grass>20?parkPaving:cityPaving;
          pavingBuckets.get(material).push([x,z]);
        }
        const padGeo=new THREE.PlaneGeometry(WORLD_SCALE*6,WORLD_SCALE*6),matrix=new THREE.Matrix4(),rotation=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0)),scale=new THREE.Vector3(1,1,1);
        for(const [material,items] of pavingBuckets){if(!items.length)continue;const pads=new THREE.InstancedMesh(padGeo,material,items.length);items.forEach(([x,z],i)=>{matrix.compose(new THREE.Vector3(x,.018,z),rotation,scale);pads.setMatrixAt(i,matrix);});pads.receiveShadow=true;pads.instanceMatrix.needsUpdate=true;scene.add(pads);}
      }
      const snapshotBlockAt=(r,c)=>(worldSnapshot?.blocks||[]).find(q=>r>=q.r0&&r<q.r0+(envSnapshot?.blockSize||10)&&c>=q.c0&&c<q.c0+(envSnapshot?.blockSize||10));
      const snapshotStyleAt=(r,c)=>snapshotBlockAt(r,c)?.styleId||null;
      const roadAxes=worldSnapshot ? (()=>{
        const out=[],maxR=Math.min(envSnapshot?.beachRow||140,envSnapshot?.mapRows||140),maxC=envSnapshot?.mapCols||80;
        for(let c=0;c<maxC;c+=10)out.push({axis:'v',p:(c+1.5-originC)*WORLD_SCALE,center:(maxR*.5-originR)*WORLD_SCALE,length:maxR*WORLD_SCALE,min:0,max:maxR});
        for(let r=0;r<maxR;r+=10)out.push({axis:'h',p:(r+1.5-originR)*WORLD_SCALE,center:(maxC*.5-originC)*WORLD_SCALE,length:maxC*WORLD_SCALE,min:0,max:maxC});
        return out;
      })() : Array.from({length:5},(_,i)=>({axis:'both',p:-72+i*36}));
      const roadMarks=[];
      for (const road of roadAxes) {
        const p=road.p;
        if(road.axis==='v'||road.axis==='both'){
        const rv = new THREE.Mesh(new THREE.PlaneGeometry(WORLD_SCALE*4, road.length||190), roadMat); rv.rotation.x = -Math.PI / 2; rv.position.set(p, .025, road.center||0); scene.add(rv);
        }
        if(road.axis==='h'||road.axis==='both'){
        const rh = new THREE.Mesh(new THREE.PlaneGeometry(road.length||190, WORLD_SCALE*4), roadMat); rh.rotation.x = -Math.PI / 2; rh.position.set(road.center||0, .026, p); scene.add(rh);
        }
        for (let q = road.min??-86; q <= (road.max??86); q += worldSnapshot?3:9) {
          if(road.axis==='v'||road.axis==='both')roadMarks.push([p,.04,worldSnapshot?(q-originR)*WORLD_SCALE:q,0]);
          if(road.axis==='h'||road.axis==='both')roadMarks.push([worldSnapshot?(q-originC)*WORLD_SCALE:q,.041,p,Math.PI/2]);
        }
      }
      if(roadMarks.length){const markGeo=new THREE.PlaneGeometry(WORLD_SCALE*.1,WORLD_SCALE*1.23),marks=new THREE.InstancedMesh(markGeo,lineMat,roadMarks.length),matrix=new THREE.Matrix4(),scale=new THREE.Vector3(1,1,1);roadMarks.forEach(([x,y,z,turn],i)=>matrix.compose(new THREE.Vector3(x,y,z),new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,turn)),scale)&&marks.setMatrixAt(i,matrix));marks.instanceMatrix.needsUpdate=true;scene.add(marks);}

      // Street storytelling stays instanced: recessed manholes, oil, repaired
      // asphalt, litter, paired tyre marks and reflective puddles add scale
      // without turning the road layer into hundreds of draw calls.
      const manholeDefs=[],stainDefs=[],patchDefs=[],litterDefs=[],skidDefs=[],puddleDefs=[];
      roadAxes.forEach((road,ri)=>{const len=road.length||190,center=road.center||0;for(let i=0;i<7;i++){const q=center-len*.43+i*len*.143,vertical=road.axis==='v'||(road.axis==='both'&&ri%2===0),x=vertical?road.p:q,z=vertical?q:road.p,target=(ri+i)%3===0?manholeDefs:(ri+i)%3===1?stainDefs:patchDefs;target.push([x+(vertical?((i&1)?2.3:-2.2):0),z+(!vertical?((i&1)?2.3:-2.2):0),(ri*.71+i*.93)%Math.PI]);if((ri+i)%2===0)litterDefs.push([x+(vertical?3.8:-3.8),z+(!vertical?3.6:-3.6),(ri+i)*.54]);}});
      roadAxes.forEach((road,ri)=>{const len=road.length||190,center=road.center||0,vertical=road.axis==='v'||(road.axis==='both'&&ri%2===0),turn=vertical?Math.PI/2:0;for(let i=0;i<4;i++){const q=center-len*.34+i*len*.225,x=vertical?road.p:q,z=vertical?q:road.p,side=(i&1)?.32:-.32;skidDefs.push([x+(vertical?side:0),z+(!vertical?side:0),turn],[x-(vertical?side:0),z-(!vertical?side:0),turn]);if((ri+i)%2===0)puddleDefs.push([x+(vertical?2.8:-2.8),z+(!vertical?2.5:-2.5),(ri+i)*.67]);}});
      const roadMatrix=new THREE.Matrix4(),roadScale=new THREE.Vector3(1,1,1),roadQuat=new THREE.Quaternion();
      const sealStaticInstanceBounds=mesh=>{mesh.computeBoundingBox?.();mesh.computeBoundingSphere?.();mesh.frustumCulled=true;return mesh;};
      const addRoadInstances=(geometry,material,defs,y,flat=true)=>{const mesh=new THREE.InstancedMesh(geometry,material,defs.length);defs.forEach(([x,z,a],i)=>{roadQuat.setFromEuler(new THREE.Euler(flat?-Math.PI/2:0,0,a||0));roadMatrix.compose(new THREE.Vector3(x,y,z),roadQuat,roadScale);mesh.setMatrixAt(i,roadMatrix);});mesh.instanceMatrix.needsUpdate=true;sealStaticInstanceBounds(mesh);scene.add(mesh);return mesh;};
      addRoadInstances(new THREE.CylinderGeometry(.72,.72,.085,18),new THREE.MeshStandardMaterial({color:0x343c41,metalness:.78,roughness:.38}),manholeDefs,.075,false);
      addRoadInstances(new THREE.CircleGeometry(1.3,18),new THREE.MeshBasicMaterial({color:0x090d10,transparent:true,opacity:.38,depthWrite:false}),stainDefs,.069);
      addRoadInstances(new THREE.PlaneGeometry(2.8,1.45),new THREE.MeshBasicMaterial({color:0x394047,transparent:true,opacity:.74,depthWrite:false}),patchDefs,.068);
      addRoadInstances(new THREE.PlaneGeometry(.48,.25),new THREE.MeshBasicMaterial({color:0xd7d0bd,side:THREE.DoubleSide}),litterDefs,.082);
      addRoadInstances(new THREE.PlaneGeometry(5.4,.15),new THREE.MeshBasicMaterial({color:0x11161a,transparent:true,opacity:.48,depthWrite:false}),skidDefs,.074);
      const puddleMaterial=new THREE.MeshPhysicalMaterial({color:0x456d80,roughness:.06,metalness:.18,clearcoat:1,clearcoatRoughness:.03,transparent:true,opacity:selectedWeather==='rain'?.62:.27,depthWrite:false,envMap:cityEnvironment,envMapIntensity:1.55});addRoadInstances(new THREE.CircleGeometry(1.45,24),puddleMaterial,puddleDefs,.078);

      // Загородные кварталы — не городская сетка магистралей. Сплошной
      // асфальт и его декор перекрываются землёй, травой и узкими тропами.
      const countrysideBlocks=(worldSnapshot?.blocks||[]).filter(b=>b.styleId==='countryside');
      if(countrysideBlocks.length){
        const ruralGroup=new THREE.Group();ruralGroup.name='countryside-terrain';scene.add(ruralGroup);
        const grassMat=new THREE.MeshStandardMaterial({color:0x345238,roughness:.98,metalness:0}),grassAltMat=new THREE.MeshStandardMaterial({color:0x416044,roughness:1}),dirtMat=new THREE.MeshStandardMaterial({color:0x806044,roughness:1,metalness:0}),dirtEdgeMat=new THREE.MeshStandardMaterial({color:0x5e4935,roughness:1}),trunkRuralMat=windTrunkMaterial(0x59402d),pineMat=windLeafMaterial(0x234b35),leafRuralMat=windLeafMaterial(0x386844),rockRuralMat=new THREE.MeshStandardMaterial({color:0x77766c,roughness:.94});
        const blockSize=envSnapshot?.blockSize||10,blockWorld=blockSize*WORLD_SCALE;
        for(const [index,b] of countrysideBlocks.entries()){
          const cx=(b.c0+blockSize*.5-originC)*WORLD_SCALE,cz=(b.r0+blockSize*.5-originR)*WORLD_SCALE,seed=(Math.abs(+b.seed||index*977)+17)>>>0;
          const meadow=new THREE.Mesh(new THREE.PlaneGeometry(blockWorld+.18,blockWorld+.18),index%3?grassMat:grassAltMat);meadow.rotation.x=-Math.PI/2;meadow.position.set(cx,.088,cz);meadow.receiveShadow=true;ruralGroup.add(meadow);
          const vertical=(seed&1)===0,pathWidth=WORLD_SCALE*(1.05+(seed%4)*.1),mainPath=new THREE.Mesh(new THREE.PlaneGeometry(vertical?pathWidth:blockWorld+.25,vertical?blockWorld+.25:pathWidth),dirtMat);mainPath.rotation.x=-Math.PI/2;mainPath.rotation.z=((seed%5)-2)*.025;mainPath.position.set(cx,.102,cz);mainPath.receiveShadow=true;ruralGroup.add(mainPath);
          const spur=new THREE.Mesh(new THREE.PlaneGeometry(blockWorld*.58,WORLD_SCALE*.72),dirtEdgeMat);spur.rotation.x=-Math.PI/2;spur.rotation.z=(vertical?Math.PI/2:0)+((seed%7)-3)*.08;spur.position.set(cx+(vertical?WORLD_SCALE*1.65:0),.104,cz+(vertical?0:WORLD_SCALE*1.65));spur.receiveShadow=true;ruralGroup.add(spur);
          for(let i=0;i<11;i++){
            const side=i&1?1:-1,laneOffset=WORLD_SCALE*(2.1+(i%3)*.82),along=WORLD_SCALE*(-4.1+((i*2.17+seed*.013)%8.2)),x=cx+(vertical?side*laneOffset:along),z=cz+(vertical?along:side*laneOffset),trunk=new THREE.Mesh(new THREE.CylinderGeometry(.24,.42,2.9+(i%3)*.35,8),trunkRuralMat);trunk.position.set(x,1.55,z);trunk.castShadow=true;ruralGroup.add(trunk);const crown=i%3===0?new THREE.Mesh(new THREE.ConeGeometry(1.7+(i%2)*.25,4.4+(i%3)*.45,9),pineMat):new THREE.Mesh(new THREE.IcosahedronGeometry(1.55+(i%3)*.22,1),leafRuralMat);crown.position.set(x,4.2+(i%3)*.28,z);crown.castShadow=true;ruralGroup.add(crown);
          }
          for(let i=0;i<4;i++){const rock=new THREE.Mesh(new THREE.DodecahedronGeometry(.32+(i%2)*.18,0),rockRuralMat);rock.scale.y=.55;rock.position.set(cx+WORLD_SCALE*(-3.6+i*2.3),.25,cz+WORLD_SCALE*((i&1)?3.5:-3.2));rock.rotation.y=i*.71;ruralGroup.add(rock);}
        }
        renderer.domElement.dataset.countrysideTerrain=`${countrysideBlocks.length}:forest-paths`;
      }

      const particleTexture=(core,edge)=>{const cv=document.createElement('canvas');cv.width=cv.height=96;const c=cv.getContext('2d'),g=c.createRadialGradient(48,48,3,48,48,46);g.addColorStop(0,core);g.addColorStop(.42,edge);g.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=g;c.fillRect(0,0,96,96);const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;tx.needsUpdate=true;return tx;};
      const industrialBuildings=(worldSnapshot?.blocks||[]).filter(b=>b.styleId==='industrial'&&b.building).slice(0,5),factoryPois=(worldSnapshot?.pois||[]).filter(p=>p.id==='factory');
      const smokeSources=[...factoryPois.map((p,i)=>({x:(p.c-originC)*WORLD_SCALE+(i%3-1)*2.2,y:10+i%3*2,z:(p.r-originR)*WORLD_SCALE})),...industrialBuildings.map((b,i)=>({x:(b.building.c-originC)*WORLD_SCALE+(i%2?2:-2),y:(+b.building.height||10)+2.5,z:(b.building.r-originR)*WORLD_SCALE}))];
      if(!smokeSources.length)smokeSources.push({x:-18,y:12,z:-18});
      const smokeCount=Math.min(72,smokeSources.length*10),smokePositions=new Float32Array(smokeCount*3),smokeState=[];
      for(let i=0;i<smokeCount;i++){const source=smokeSources[i%smokeSources.length],phase=(i/smokeCount)*13;smokeState.push({source,phase,side:(i%5-2)*.24});smokePositions[i*3]=source.x;smokePositions[i*3+1]=source.y;smokePositions[i*3+2]=source.z;}
      const smokeGeometry=new THREE.BufferGeometry();smokeGeometry.setAttribute('position',new THREE.BufferAttribute(smokePositions,3));const smokePoints=new THREE.Points(smokeGeometry,new THREE.PointsMaterial({map:particleTexture('rgba(210,220,225,.72)','rgba(80,91,103,.22)'),color:0xb8c2c8,size:3.4,sizeAttenuation:true,transparent:true,opacity:.42,depthWrite:false,blending:THREE.NormalBlending}));smokePoints.renderOrder=18;scene.add(smokePoints);
      const steamSources=manholeDefs.slice(0,20),steamCount=Math.max(12,steamSources.length*3),steamPositions=new Float32Array(steamCount*3),steamState=[];
      for(let i=0;i<steamCount;i++){const source=steamSources[i%Math.max(1,steamSources.length)]||[0,0],phase=i*.73;steamState.push({source,phase});steamPositions[i*3]=source[0];steamPositions[i*3+1]=.2;steamPositions[i*3+2]=source[1];}
      const steamGeometry=new THREE.BufferGeometry();steamGeometry.setAttribute('position',new THREE.BufferAttribute(steamPositions,3));const steamPoints=new THREE.Points(steamGeometry,new THREE.PointsMaterial({map:particleTexture('rgba(240,248,255,.64)','rgba(190,215,225,.18)'),color:0xdde8ed,size:1.5,sizeAttenuation:true,transparent:true,opacity:.25,depthWrite:false}));steamPoints.renderOrder=17;scene.add(steamPoints);
      const atmosphereTreeDefs=(worldSnapshot?.blocks||[]).filter((b,i)=>b.grass>10||b.styleId==='rich'||i%7===0).slice(0,24).map((b,i)=>[(b.c0+4+i%3-originC)*WORLD_SCALE,(b.r0+5+(i%2)*2-originR)*WORLD_SCALE,1]);if(!atmosphereTreeDefs.length)atmosphereTreeDefs.push([0,0,1]);
      const leafCount=48,leafState=[],fallingLeafGeometry=new THREE.CircleGeometry(.27,7),fallingLeafMaterial=new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.92,side:THREE.DoubleSide,transparent:true,opacity:.9,depthWrite:false}),fallingLeaves=new THREE.InstancedMesh(fallingLeafGeometry,fallingLeafMaterial,leafCount),leafMatrix=new THREE.Matrix4(),leafQuat=new THREE.Quaternion(),leafScale=new THREE.Vector3(),leafHiddenScale=new THREE.Vector3(0,0,0),leafEuler=new THREE.Euler();
      for(let i=0;i<leafCount;i++){const tree=atmosphereTreeDefs[i%atmosphereTreeDefs.length],phase=i*3.71+(i%5)*1.23,radius=1.1+(i%7)*.31,color=i%4===0?0xe69a35:i%4===1?0x72a747:i%4===2?0xb5a845:0x4f8b43;leafState.push({tree,phase,radius,cycle:17+(i%9)*1.8,fall:4.4+(i%5)*.55,rest:4.2+(i%4)*.8});fallingLeaves.setColorAt(i,new THREE.Color(color));leafMatrix.compose(new THREE.Vector3(0,-30,0),leafQuat.identity(),leafHiddenScale);fallingLeaves.setMatrixAt(i,leafMatrix);}
      fallingLeaves.instanceMatrix.setUsage(THREE.DynamicDrawUsage);fallingLeaves.instanceMatrix.needsUpdate=true;fallingLeaves.instanceColor.needsUpdate=true;fallingLeaves.renderOrder=19;fallingLeaves.frustumCulled=false;scene.add(fallingLeaves);
      let lastAtmosphereUpdate=0;
      const updateAtmosphere=(t,slow)=>{if(t-lastAtmosphereUpdate<(slow?70:34))return;lastAtmosphereUpdate=t;const time=t*.001;
        smokeState.forEach((p,i)=>{const rise=(time*.72+p.phase)%10,spread=.2+rise*.16;smokePositions[i*3]=p.source.x+Math.sin(time*.52+p.phase)*spread+p.side;smokePositions[i*3+1]=p.source.y+rise;smokePositions[i*3+2]=p.source.z+Math.cos(time*.39+p.phase*1.3)*spread;});smokeGeometry.attributes.position.needsUpdate=true;
        steamState.forEach((p,i)=>{const rise=(time*.9+p.phase)%3.4;steamPositions[i*3]=p.source[0]+Math.sin(time+p.phase)*rise*.18;steamPositions[i*3+1]=.2+rise;steamPositions[i*3+2]=p.source[1]+Math.cos(time*.8+p.phase)*rise*.13;});steamGeometry.attributes.position.needsUpdate=true;
        leafState.forEach((p,i)=>{const tree=streetTreeDefs.length?streetTreeDefs[i%streetTreeDefs.length]:p.tree,scale=tree[2]||1,top=5.65*scale,age=(time+p.phase)%p.cycle,wait=p.cycle-p.fall-p.rest;if(age<wait){leafMatrix.compose(new THREE.Vector3(0,-30,0),leafQuat.identity(),leafHiddenScale);fallingLeaves.setMatrixAt(i,leafMatrix);return;}const local=age-wait,falling=local<p.fall,u=falling?local/p.fall:1,restAge=Math.max(0,local-p.fall),a=time*(1.15+(i%3)*.12)+p.phase,gust=.55+Math.pow(.5+.5*Math.sin(time*.43+i*.7),4)*1.15;let x=tree[0]+Math.sin(a)*p.radius+u*u*gust*2.3,z=tree[1]+Math.cos(a*.77)*p.radius+u*gust*1.15;const y=falling?Math.max(.11,top*(1-u*u*.93)):.095;if(!falling){x+=Math.min(1.1,restAge*.18)*gust;z+=Math.sin(p.phase)*Math.min(.65,restAge*.1);}leafEuler.set(falling?a*1.8:-Math.PI/2,falling?a*.73:p.phase,falling?a*2.25:Math.sin(p.phase)*.08);leafQuat.setFromEuler(leafEuler);const size=(.72+(i%4)*.1)*(falling?1:1-Math.min(.38,restAge/p.rest*.38));leafScale.set(size*.62,size*1.18,size);leafMatrix.compose(new THREE.Vector3(x,y,z),leafQuat,leafScale);fallingLeaves.setMatrixAt(i,leafMatrix);});fallingLeaves.instanceMatrix.needsUpdate=true;
      };

      // Keep signals readable and useful without turning every crossing into a
      // forest of poles. The stable grid hash retains one key junction in four,
      // so streamed sectors always choose the same intersections.
      const trafficSignalDefs=[];let trafficSignalCandidates=0;
      if(worldSnapshot){
        const maxR=Math.min(envSnapshot?.beachRow||140,envSnapshot?.mapRows||140),maxC=envSnapshot?.mapCols||80,block=envSnapshot?.blockSize||10;
        const isStreetTile=(r,c)=>[0,18,19].includes(bridge?.collisionProbe?.(r,c)?.tile);
        for(let r=2;r<maxR;r+=block)for(let c=2;c<maxC;c+=block){
          const rr=r+.5,cc=c+.5,cross=isStreetTile(rr,cc),horizontal=isStreetTile(rr,cc-1.2)&&isStreetTile(rr,cc+1.2),vertical=isStreetTile(rr-1.2,cc)&&isStreetTile(rr+1.2,cc),blockAtSignal=snapshotBlockAt(rr,cc);
          const dryNeighborhood=[[-2,0],[2,0],[0,-2],[0,2],[-2,-2],[-2,2],[2,-2],[2,2]].every(([dr,dc])=>bridge?.collisionProbe?.(rr+dr,cc+dc)?.tile!==16);
          if(snapshotStyleAt(rr,cc)==='countryside'||!dryNeighborhood||(blockAtSignal?.water||0)>0)continue;
          if(cross&&horizontal&&vertical){
            trafficSignalCandidates++;
            const gridR=Math.floor(r/block),gridC=Math.floor(c/block),junctionHash=(Math.imul(gridR,73856093)^Math.imul(gridC,19349663))>>>0;
            if(junctionHash%4===0)trafficSignalDefs.push([(cc-originC)*WORLD_SCALE,(rr-originR)*WORLD_SCALE]);
          }
        }
      }
      const trafficHaloCanvas=document.createElement('canvas');trafficHaloCanvas.width=trafficHaloCanvas.height=96;const trafficHaloContext=trafficHaloCanvas.getContext('2d'),trafficHaloGradient=trafficHaloContext.createRadialGradient(48,48,4,48,48,46);trafficHaloGradient.addColorStop(0,'rgba(255,255,255,1)');trafficHaloGradient.addColorStop(.3,'rgba(255,255,255,.72)');trafficHaloGradient.addColorStop(.68,'rgba(255,255,255,.2)');trafficHaloGradient.addColorStop(1,'rgba(255,255,255,0)');trafficHaloContext.fillStyle=trafficHaloGradient;trafficHaloContext.fillRect(0,0,96,96);const trafficHaloTexture=new THREE.CanvasTexture(trafficHaloCanvas);trafficHaloTexture.colorSpace=THREE.SRGBColorSpace;trafficHaloTexture.generateMipmaps=false;
      const trafficPoleMat=new THREE.MeshStandardMaterial({color:0x4d5b61,metalness:.84,roughness:.25}),trafficTrimMat=new THREE.MeshStandardMaterial({color:0x839097,metalness:.9,roughness:.2}),trafficCaseMat=new THREE.MeshStandardMaterial({color:0x13191e,metalness:.3,roughness:.52}),trafficBackMat=new THREE.MeshStandardMaterial({color:0xe0ad2b,metalness:.18,roughness:.48}),trafficVisorMat=new THREE.MeshStandardMaterial({color:0x090d10,metalness:.26,roughness:.6}),trafficLensMat=new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,toneMapped:false}),trafficHaloMat=new THREE.MeshBasicMaterial({map:trafficHaloTexture,color:0xffffff,vertexColors:true,toneMapped:false,transparent:true,opacity:.96,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),trafficCount=trafficSignalDefs.length,trafficHeadCount=trafficCount*2,trafficLampCount=trafficHeadCount*3;
      const trafficPole=new THREE.InstancedMesh(new THREE.CylinderGeometry(.16,.28,7.1,12),trafficPoleMat,trafficCount),trafficBase=new THREE.InstancedMesh(new THREE.CylinderGeometry(.5,.6,.32,16),trafficTrimMat,trafficCount),trafficCollar=new THREE.InstancedMesh(new THREE.CylinderGeometry(.31,.31,.2,16),trafficTrimMat,trafficCount),trafficArm=new THREE.InstancedMesh(new THREE.BoxGeometry(3.4,.22,.22),trafficPoleMat,trafficHeadCount),trafficBackboard=new THREE.InstancedMesh(new THREE.BoxGeometry(1.38,3.28,.18),trafficBackMat,trafficHeadCount),trafficCase=new THREE.InstancedMesh(new THREE.BoxGeometry(1.12,2.98,.6),trafficCaseMat,trafficHeadCount),trafficBezel=new THREE.InstancedMesh(new THREE.TorusGeometry(.43,.075,8,22),trafficTrimMat,trafficLampCount),trafficVisor=new THREE.InstancedMesh(new THREE.BoxGeometry(1.02,.14,.68),trafficVisorMat,trafficLampCount),trafficRed=new THREE.InstancedMesh(new THREE.SphereGeometry(.41,16,10),trafficLensMat,trafficHeadCount),trafficYellow=new THREE.InstancedMesh(new THREE.SphereGeometry(.41,16,10),trafficLensMat,trafficHeadCount),trafficGreen=new THREE.InstancedMesh(new THREE.SphereGeometry(.41,16,10),trafficLensMat,trafficHeadCount),trafficRedHalo=new THREE.InstancedMesh(new THREE.CircleGeometry(.92,24),trafficHaloMat,trafficHeadCount),trafficYellowHalo=new THREE.InstancedMesh(new THREE.CircleGeometry(.92,24),trafficHaloMat,trafficHeadCount),trafficGreenHalo=new THREE.InstancedMesh(new THREE.CircleGeometry(.92,24),trafficHaloMat,trafficHeadCount);
      const trafficMatrix=new THREE.Matrix4(),trafficQuat=new THREE.Quaternion(),trafficScale=new THREE.Vector3(1,1,1),trafficPosition=new THREE.Vector3(),trafficEuler=new THREE.Euler(),trafficColor=new THREE.Color(),setTrafficPart=(mesh,index,x,y,z,ry=0,sx=1,sy=1,sz=1)=>{trafficPosition.set(x,y,z);trafficQuat.setFromEuler(trafficEuler.set(0,ry,0));trafficScale.set(sx,sy,sz);trafficMatrix.compose(trafficPosition,trafficQuat,trafficScale);mesh.setMatrixAt(index,trafficMatrix);};
      trafficSignalDefs.forEach(([x,z],i)=>{setTrafficPart(trafficPole,i,x,3.55,z);setTrafficPart(trafficBase,i,x,.16,z);setTrafficPart(trafficCollar,i,x,6.62,z);for(let direction=0;direction<2;direction++){const headIndex=i*2+direction,ry=direction*Math.PI/2,hx=x+(direction?0:1.82),hz=z+(direction?1.82:0);setTrafficPart(trafficArm,headIndex,x+(direction?0:.86),6.62,z+(direction?.86:0),ry);setTrafficPart(trafficBackboard,headIndex,hx,6.62,hz,ry);setTrafficPart(trafficCase,headIndex,hx,6.62,hz+(direction?0:.14),ry);for(let lamp=0;lamp<3;lamp++){const lampIndex=headIndex*3+lamp,ly=7.48-lamp*.86,faceX=hx+(direction?.42:0),faceZ=hz+(direction?0:.42),visorX=hx+(direction?.57:0),visorZ=hz+(direction?0:.57);setTrafficPart(trafficBezel,lampIndex,faceX,ly,faceZ,ry);setTrafficPart(trafficVisor,lampIndex,visorX,ly+.32,visorZ,ry);}const faceX=hx+(direction?.43:0),faceZ=hz+(direction?0:.43),haloX=faceX+(direction?.04:0),haloZ=faceZ+(direction?0:.04);setTrafficPart(trafficRed,headIndex,faceX,7.48,faceZ,ry);setTrafficPart(trafficYellow,headIndex,faceX,6.62,faceZ,ry);setTrafficPart(trafficGreen,headIndex,faceX,5.76,faceZ,ry);setTrafficPart(trafficRedHalo,headIndex,haloX,7.48,haloZ,ry);setTrafficPart(trafficYellowHalo,headIndex,haloX,6.62,haloZ,ry);setTrafficPart(trafficGreenHalo,headIndex,haloX,5.76,haloZ,ry);}});
      const trafficLamps=[trafficRed,trafficYellow,trafficGreen],trafficHalos=[trafficRedHalo,trafficYellowHalo,trafficGreenHalo],trafficMeshes=[trafficPole,trafficBase,trafficCollar,trafficArm,trafficBackboard,trafficCase,trafficBezel,trafficVisor,...trafficLamps,...trafficHalos];for(const mesh of trafficMeshes){mesh.instanceMatrix.needsUpdate=true;sealStaticInstanceBounds(mesh);mesh.castShadow=!([...trafficLamps,...trafficHalos].includes(mesh));mesh.receiveShadow=mesh.castShadow;scene.add(mesh);}for(const mesh of [...trafficLamps,...trafficHalos]){mesh.renderOrder=24;for(let i=0;i<trafficHeadCount;i++)mesh.setColorAt(i,trafficColor.setHex(0x101010));mesh.instanceColor.needsUpdate=true;}
      let trafficSignalPhase='';const setTrafficSignals=phase=>{const ew=phase?.ew||'g',ns=phase?.ns||'r',sig=`${ew}:${ns}`;if(sig===trafficSignalPhase)return;trafficSignalPhase=sig;const bright={r:0xff304b,y:0xffd12f,g:0x3dff78},dim={r:0x1b0508,y:0x1b1604,g:0x041b0a};for(let i=0;i<trafficCount;i++)for(let direction=0;direction<2;direction++){const index=i*2+direction,state=direction?ns:ew;for(const [mesh,halo,key] of [[trafficRed,trafficRedHalo,'r'],[trafficYellow,trafficYellowHalo,'y'],[trafficGreen,trafficGreenHalo,'g']]){mesh.setColorAt(index,trafficColor.setHex(state===key?bright[key]:dim[key]));halo.setColorAt(index,trafficColor.setHex(state===key?bright[key]:0x000000));}}for(const mesh of [...trafficLamps,...trafficHalos])mesh.instanceColor.needsUpdate=true;renderer.domElement.dataset.trafficPhase=sig;renderer.domElement.dataset.trafficSignals=String(trafficCount);renderer.domElement.dataset.trafficSignalCandidates=String(trafficSignalCandidates);renderer.domElement.dataset.trafficSignalsDry='true';renderer.domElement.dataset.trafficSignalLayout='key-junctions-quarter-density-dry-land';renderer.domElement.dataset.trafficSignalLightProfile='radial-halo-readable-lens-v330';};setTrafficSignals(envSnapshot?.traffic);

      // Stable architectural families prevent whole districts from looking
      // like one cloned brick block. They change materials and facade rhythm,
      // while the authored footprint remains the only collision source.
      const architectureFamilies=[
        {id:'glass',base:'#214e65',roughness:.19,metalness:.34,env:1.08,bump:.006,roof:0x20333f},
        {id:'brick',base:'#844638',roughness:.92,metalness:.015,env:.12,bump:.058,roof:0x3c3030},
        {id:'limestone',base:'#aaa087',roughness:.7,metalness:.06,env:.28,bump:.026,roof:0x42535b},
        {id:'concrete',base:'#69747a',roughness:.84,metalness:.11,env:.2,bump:.038,roof:0x353f45},
        {id:'deco',base:'#45625e',roughness:.52,metalness:.2,env:.48,bump:.018,roof:0x2d3f41},
        {id:'industrial',base:'#505a5e',roughness:.78,metalness:.28,env:.34,bump:.044,roof:0x30393d},
      ],architectureFamilyById=new Map(architectureFamilies.map(q=>[q.id,q])),architectureFacadeTextures=new Map(),facades=[];
      for(const family of architectureFamilies){const variants=[];for(let variant=0;variant<2;variant++){const tx=facadeTexture(family,variant);variants.push(tx);facades.push(tx);}architectureFacadeTextures.set(family.id,variants);}
      const architectureFamilyPools={
        poor:['brick','brick','concrete','limestone','brick','industrial'],
        downtown:['glass','deco','limestone','concrete','glass','brick'],
        nightlife:['deco','glass','brick','concrete','glass','deco'],
        rich:['limestone','deco','glass','limestone','brick','glass'],
        countryside:['brick','limestone','concrete','brick'],
        industrial:['industrial','brick','concrete','industrial','brick'],
        coast:['glass','limestone','deco','concrete','glass'],
        chinatown_poor:['brick','brick','concrete','industrial'],
        chinatown_market:['brick','deco','limestone','concrete'],
        chinatown_neon:['deco','glass','brick','concrete'],
        chinatown_rich:['limestone','deco','glass','limestone'],
        chinatown_docks:['industrial','brick','concrete','industrial'],
      };
      const architectureFamilyFor=(districtStyle,seed,height)=>{
        const pool=architectureFamilyPools[districtStyle]||architectureFamilyPools.downtown,mixed=(seed^(seed>>>11)^Math.imul(seed>>>5,0x9e3779b1))>>>0;
        let id=pool[mixed%pool.length];
        if(height>25&&(districtStyle==='downtown'||districtStyle==='rich'||districtStyle==='coast')&&mixed%4===0)id='glass';
        return architectureFamilyById.get(id)||architectureFamilies[0];
      };
      const roofMat = new THREE.MeshStandardMaterial({color:0x41515d,map:roofTexture,roughness:.48,roughnessMap:roofTexture,metalness:.62,envMap:cityEnvironment,envMapIntensity:.72});
      const neonMats = [0xff496f, 0x46d9ff, 0xffc247].map(color => new THREE.MeshBasicMaterial({ color }));
      const fallbackBuildingDefs = [
        [-24,-23,14,13,15,1,'BAR'],[-8,-24,11,13,11,3,'DELI'],[11,-23,14,14,18,0,'HOTEL'],[27,-23,11,13,13,2,'CAFE'],
        [-25,23,13,14,13,4,'CLUB'],[-9,23,12,13,17,0,'BANK'],[10,23,14,14,14,2,'MARKET'],[27,23,11,13,18,1,''],
      ];
      const styleIndexes={poor:1,downtown:0,nightlife:4,rich:3,countryside:2,industrial:1,coast:2,chinatown_poor:1,chinatown_market:3,chinatown_neon:4,chinatown_rich:0,chinatown_docks:1};
      let suppressedDedicatedExteriorOverlaps=0;
      const defsFromSnapshot=snapshot=>(snapshot?.blocks||[]).flatMap(b=>(b.buildingParts?.length?b.buildingParts:(b.building?[b.building]:[])).flatMap((q,partIndex)=>{
        const candidates=[...(snapshot.pois||[]),...(snapshot.landmarks?.mafiaHq?[snapshot.landmarks.mafiaHq]:[])],nearPoi=candidates.map(p=>({p,d:Math.hypot((+p.r||0)-q.r,(+p.c||0)-q.c)})).filter(x=>x.d<6.2).sort((a,b)=>a.d-b.d)[0]?.p||null,architecturalKind=partIndex===0?nearPoi?.id||null:null;
        // Dedicated business exteriors already own their whole authored
        // footprint. Suppress the generic streamed mass underneath instead of
        // rendering two unrelated buildings in the same place.
        const ownsDedicatedBusiness=(snapshot.landmarks?.businesses||[]).some(p=>{
          const br=Number.isFinite(+p.tileR)?+p.tileR:+p.r,bc=Number.isFinite(+p.tileC)?+p.tileC:+p.c;
          return Number.isFinite(+q.minR)
            ? br>=+q.minR&&br<=+q.maxR&&bc>=+q.minC&&bc<=+q.maxC
            : Math.abs(br-(+q.r||0))<=Math.max(1,(+q.d||1)*.5)&&Math.abs(bc-(+q.c||0))<=Math.max(1,(+q.w||1)*.5);
        });
          const ownsBankTile=(snapshot.landmarks?.banks||[]).some(bank=>{
            const centerOffset={small:1,medium:1.5,large:1.5}[bank.size]||1.5,br=+bank.r+centerOffset,bc=+bank.c+centerOffset;
            return Number.isFinite(+q.minR)
              ? br>=+q.minR&&br<=+q.maxR&&bc>=+q.minC&&bc<=+q.maxC
              : Math.abs(br-(+q.r||0))<=Math.max(1,(+q.d||1)*.5)&&Math.abs(bc-(+q.c||0))<=Math.max(1,(+q.w||1)*.5);
          });
          const ownsCasinoTile=nearPoi?.id==='casino'&&+q.minR<=+nearPoi.r&&+q.maxR>=+nearPoi.r&&+q.minC<=+nearPoi.c&&+q.maxC>=+nearPoi.c;
          const ownsFactoryTile=nearPoi?.id==='factory'&&+q.minR<=+nearPoi.r&&+q.maxR>=+nearPoi.r&&+q.minC<=+nearPoi.c&&+q.maxC>=+nearPoi.c;
          const ownsMarketTile=nearPoi?.id==='market'&&+q.minR<=+nearPoi.r&&+q.maxR>=+nearPoi.r&&+q.minC<=+nearPoi.c&&+q.maxC>=+nearPoi.c;
          const jail=snapshot.landmarks?.jail,ownsPrisonTile=!!jail&&(Number.isFinite(+q.minR)?+jail.r>=+q.minR&&+jail.r<=+q.maxR&&+jail.c>=+q.minC&&+jail.c<=+q.maxC:Math.hypot((+q.r||0)-(+jail.r||0),(+q.c||0)-(+jail.c||0))<2.2);
          if(ownsCasinoTile||ownsFactoryTile||ownsMarketTile||ownsDedicatedBusiness||ownsPrisonTile||ownsBankTile){if(ownsDedicatedBusiness||ownsPrisonTile||ownsBankTile||ownsMarketTile)suppressedDedicatedExteriorOverlaps++;return [];}
        return [[(q.c-originC)*WORLD_SCALE,(q.r-originR)*WORLD_SCALE,q.w*WORLD_SCALE,q.d*WORLD_SCALE,q.height,styleIndexes[b.styleId]??0,(nearPoi?.name||nearPoi?.label||'').toString().slice(0,14).toUpperCase(),b.styleId||'downtown',{r:q.r,c:q.c,w:q.w,d:q.d,minR:q.minR,maxR:q.maxR,minC:q.minC,maxC:q.maxC,tiles:q.tiles,primary:partIndex===0,architecturalKind}]];
      }));
      const buildingDefs=worldSnapshot ? defsFromSnapshot(worldSnapshot) : fallbackBuildingDefs;
      renderer.domElement.dataset.suppressedBuildingOverlaps=String(suppressedDedicatedExteriorOverlaps);
      const initialBuildingCount=buildingDefs.length;
      const loadedBuildingKeys=new Set(buildingDefs.map(d=>`${d[8]?.minR}:${d[8]?.minC}:${d[8]?.maxR}:${d[8]?.maxC}`));
      const occluders=[],buildingPickables=[],facadeMaterials=[],shopMaterials=[],buildingCurbDefs=[],businessExteriorById=new Map();
      // Authored banks replace their generic streamed masses but remain selectable through the same building metadata path.
      for(const root of bankExteriors){
        const bank=root.userData.bank,main=root.userData.main,tiles=root.userData.footprintTiles||3,centerOffset={small:1,medium:1.5,large:1.5}[bank?.size]||1.5;
        if(!bank||!main)continue;
        const meta={r:+bank.r+centerOffset,c:+bank.c+centerOffset,w:tiles,d:tiles,minR:+bank.r,maxR:+bank.r+tiles,minC:+bank.c,maxC:+bank.c+tiles,primary:true,architecturalKind:'bank',bankId:String(bank.id)};
        const fadeMaterials=[];root.traverse(o=>{if(o.isMesh){for(const material of (Array.isArray(o.material)?o.material:[o.material]))if(material&&!material.transparent&&!fadeMaterials.includes(material))fadeMaterials.push(material);}});
        main.userData.building=meta;main.userData.mainBuilding=true;main.userData.bankId=String(bank.id);main.userData.fadeMaterials=fadeMaterials;buildingPickables.push(main);occluders.push(main);
      }
      const streamedSectorGroups=new Map(),persistentStreamResources=new WeakSet();
      let persistentStreamResourcesCaptured=false,streamedEvictionAnchor='';
      const rememberResource=resource=>{if(resource&&typeof resource==='object')persistentStreamResources.add(resource);};
      const capturePersistentStreamResources=()=>{
        if(persistentStreamResourcesCaptured)return;
        persistentStreamResourcesCaptured=true;
        scene.traverse(object=>{
          rememberResource(object.geometry);
          const materials=Array.isArray(object.material)?object.material:[object.material];
          for(const material of materials){if(!material)continue;rememberResource(material);for(const value of Object.values(material))if(value?.isTexture)rememberResource(value);}
        });
      };
      const streamSectorKeyForDefinition=definition=>{const meta=definition?.[8]||{},r=Number.isFinite(+meta.r)?+meta.r:originR+(+definition?.[1]||0)/WORLD_SCALE,c=Number.isFinite(+meta.c)?+meta.c:originC+(+definition?.[0]||0)/WORLD_SCALE;return `${Math.floor(r/STREAM_SECTOR_SIZE)}:${Math.floor(c/STREAM_SECTOR_SIZE)}`;};
      const placeStreamedBuildingRoots=(definition,roots)=>{
        const sectorKey=streamSectorKeyForDefinition(definition);
        let group=streamedSectorGroups.get(sectorKey);
        if(!group){group=new THREE.Group();group.name=`streamed-building-sector:${sectorKey}`;group.userData.buildingKeys=new Set();scene.add(group);streamedSectorGroups.set(sectorKey,group);}
        const meta=definition?.[8]||{},buildingKey=`${meta.minR}:${meta.minC}:${meta.maxR}:${meta.maxC}`;group.userData.buildingKeys.add(buildingKey);
        for(const root of roots){if(root===group)continue;root.parent?.remove(root);group.add(root);root.traverse?.(object=>object.userData.mfzStreamSector=sectorKey);}
      };
      const evictFarStreamedSectors=(playerR,playerC)=>{
        const centerR=Math.floor(playerR/STREAM_SECTOR_SIZE),centerC=Math.floor(playerC/STREAM_SECTOR_SIZE),keepRadius=Math.ceil(WORLD_SNAPSHOT_RADIUS/STREAM_SECTOR_SIZE)+1;
        const evictionAnchor=`${centerR}:${centerC}`;if(evictionAnchor===streamedEvictionAnchor)return;streamedEvictionAnchor=evictionAnchor;
        for(const [sectorKey,group] of streamedSectorGroups){
          const [sr,sc]=sectorKey.split(':').map(Number);
          if(Math.abs(sr-centerR)<=keepRadius&&Math.abs(sc-centerC)<=keepRadius)continue;
          let warmupInFlight=false;group.traverse(object=>{if(object.userData?.mfzWarmupInFlight)warmupInFlight=true;});if(warmupInFlight)continue;
          const objects=new Set(),geometries=new Set(),materials=new Set(),textures=new Set();
          group.traverse(object=>{objects.add(object);if(object.geometry&&!persistentStreamResources.has(object.geometry))geometries.add(object.geometry);const list=Array.isArray(object.material)?object.material:[object.material];for(const material of list){if(!material||persistentStreamResources.has(material))continue;materials.add(material);for(const value of Object.values(material))if(value?.isTexture&&!persistentStreamResources.has(value))textures.add(value);}});
          for(const key of group.userData.buildingKeys||[])loadedBuildingKeys.delete(key);
          for(let i=occluders.length-1;i>=0;i--)if(objects.has(occluders[i]))occluders.splice(i,1);
          for(let i=buildingPickables.length-1;i>=0;i--)if(objects.has(buildingPickables[i]))buildingPickables.splice(i,1);
          for(let i=facadeMaterials.length-1;i>=0;i--)if(materials.has(facadeMaterials[i]))facadeMaterials.splice(i,1);
          for(let i=shopMaterials.length-1;i>=0;i--)if(materials.has(shopMaterials[i]))shopMaterials.splice(i,1);
          for(let i=deferredRevealRoots.length-1;i>=0;i--)if(objects.has(deferredRevealRoots[i]))deferredRevealRoots.splice(i,1);
          if(objects.has(highlightedBuildingObject))clearBuildingHighlight();
          if(objects.has(nearbyBuildingObject))nearbyBuildingObject=null;
          for(const material of materials)occlusionMaterialStates.delete(material);
          scene.remove(group);textures.forEach(texture=>texture.dispose?.());geometries.forEach(geometry=>geometry.dispose?.());materials.forEach(material=>material.dispose?.());streamedSectorGroups.delete(sectorKey);
        }
        renderer.domElement.dataset.residentBuildingSectors=String(streamedSectorGroups.size);
      };
      const glassMat=new THREE.MeshPhysicalMaterial({color:0x5fbfe0,emissive:0x10394b,emissiveIntensity:.25,metalness:.08,roughness:.08,transmission:.14,thickness:.28,clearcoat:1,clearcoatRoughness:.06,envMap:cityEnvironment,envMapIntensity:1.45});
      const districtProps=new THREE.Group();scene.add(districtProps);
      const propBox=(x,z,w,d,h,mat,y=h/2)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;districtProps.add(m);return m;};
      const chinaRedMat=new THREE.MeshStandardMaterial({color:0x781f29,roughness:.62,metalness:.18}),chinaGoldMat=new THREE.MeshStandardMaterial({color:0xc39a3d,roughness:.32,metalness:.72}),chinaJadeMat=new THREE.MeshStandardMaterial({color:0x174f47,roughness:.48,metalness:.28}),chinaBrickMat=new THREE.MeshStandardMaterial({color:0x694039,roughness:.95}),chinaSteelMat=new THREE.MeshStandardMaterial({color:0x39434a,roughness:.48,metalness:.68}),chinaNeonRed=new THREE.MeshBasicMaterial({color:0xff3652,toneMapped:false}),chinaNeonJade=new THREE.MeshBasicMaterial({color:0x33efc2,toneMapped:false}),chinaNeonGold=new THREE.MeshBasicMaterial({color:0xffc84c,toneMapped:false}),chinaNeonViolet=new THREE.MeshBasicMaterial({color:0xd14dff,toneMapped:false});
      const chinaGlowMats=[chinaNeonRed,chinaNeonJade,chinaNeonGold,chinaNeonViolet];
      const addChinaVerticalSign=(x,z,y,seed,side=1)=>{const glow=chinaGlowMats[Math.abs(seed)%chinaGlowMats.length],frame=propBox(x,z,.86,.16,Math.min(6.6,3.7+(seed%4)),chinaRedMat,y);frame.rotation.z=(seed%3-1)*.025;for(let gy=-1;gy<=1;gy++){const bar=propBox(x+side*((gy&1)?.17:-.12),z+.1,.42,.08,.12,glow,y+gy*.82);bar.rotation.z=(gy&1)?.45:-.45;}const top=propBox(x,z+.11,1.08,.1,.11,chinaGoldMat,y+2.15);return frame;};
      const addChinaLantern=(x,z,y,seed)=>{const wire=new THREE.Mesh(new THREE.CylinderGeometry(.025,.025,.85,6),chinaSteelMat);wire.position.set(x,y+.42,z);districtProps.add(wire);const lantern=new THREE.Mesh(new THREE.SphereGeometry(.24,12,8),seed%2?chinaNeonRed:chinaNeonGold);lantern.scale.y=1.25;lantern.position.set(x,y,z);districtProps.add(lantern);};
      const addDistrictCharacter=(x,z,w,d,h,kind,seed)=>{
        const front=z+d/2+1.15,side=x+w/2+1.1;
        if(kind==='poor'){
          const brick=new THREE.MeshStandardMaterial({color:seed%2?0x75493d:0x66514a,roughness:.98});
          propBox(side,z,.6,d*.7,2.6,brick,1.3);propBox(x-w*.25,front,w*.28,.8,.22,new THREE.MeshStandardMaterial({color:0xa94935,roughness:.8}),3.4);
          for(let i=0;i<2;i++){const bin=new THREE.Mesh(new THREE.CylinderGeometry(.45,.52,1.25,10),detailMat);bin.position.set(x+w*.28+i*1.2,.63,front);districtProps.add(bin);}
          for(let floor=3.4;floor<h-1;floor+=3.1){propBox(side+.38,z-d*.18,2.3,.62,.16,detailMat,floor);for(const dz of [-.85,.85])propBox(side+.48,z-d*.18+dz,.12,.12,1.05,detailMat,floor+.48);}
        }else if(kind==='nightlife'){
          const color=[0xff3e83,0x42dcff,0xa564ff][seed%3],glow=new THREE.MeshBasicMaterial({color});
          propBox(x-w*.31,front,w*.18,.18,3.8,glow,6);propBox(x+w*.31,front,w*.18,.18,3.8,glow,8.2);
        }else if(kind==='industrial'){
          const pipeMat=new THREE.MeshStandardMaterial({color:0x6d7477,metalness:.65,roughness:.42});
          for(const sx of [-1,1]){const pipe=new THREE.Mesh(new THREE.CylinderGeometry(.22,.3,Math.max(4,h*.55),10),pipeMat);pipe.position.set(side+sx*.7,h*.27,z);districtProps.add(pipe);}
          propBox(x,front,w*.65,1.15,.8,new THREE.MeshStandardMaterial({color:0xb88b2f,roughness:.8}),.4);
        }else if(kind==='rich'){
          const stone=new THREE.MeshStandardMaterial({color:0xe0d2b0,roughness:.72});
          for(const sx of [-w*.3,w*.3]){const col=new THREE.Mesh(new THREE.CylinderGeometry(.28,.34,4.4,12),stone);col.position.set(x+sx,2.2,front);districtProps.add(col);}
          const hedge=new THREE.MeshStandardMaterial({color:0x245f3f,roughness:1});propBox(x-w*.3,front+1.1,w*.22,.75,1.05,hedge,.53);propBox(x+w*.3,front+1.1,w*.22,.75,1.05,hedge,.53);
        }else if(kind==='countryside'){
          const wood=new THREE.MeshStandardMaterial({color:0x84552e,roughness:1});
          for(let i=-2;i<=2;i++)propBox(x+i*1.5,front+1.2,.18,.18,1.1,wood,.55);
          propBox(x,front+1.2,7,.14,.14,wood,.55);
        }else if(kind==='coast'){
          const aqua=new THREE.MeshStandardMaterial({color:seed%2?0x27cbbb:0xff8b5c,roughness:.5});
          propBox(x,front,w*.62,1.5,.25,aqua,3.5);for(const sx of [-w*.22,w*.22])propBox(x+sx,front+1,.22,.22,2.5,detailMat,1.25);
        }else if(kind==='chinatown_poor'){
          // Tight tenements: external fire escapes, patched awnings and laundry lines.
          propBox(side,z,.72,d*.76,2.8,chinaBrickMat,1.4);propBox(x-w*.24,front,w*.34,.95,.2,chinaRedMat,3.15);
          for(let floor=3.2;floor<h-1;floor+=2.85){propBox(side+.34,z-d*.12,2.45,.82,.16,chinaSteelMat,floor);for(const dz of [-.92,.92])propBox(side+.43,z-d*.12+dz,.1,.1,1.18,chinaSteelMat,floor+.48);}
          for(let line=0;line<2;line++){const y=4.2+line*1.25;propBox(x,front+.82,w*.62,.035,.035,chinaSteelMat,y);for(let k=-2;k<=2;k++){const cloth=propBox(x+k*w*.1,front+.84,.48,.035,.65,[chinaRedMat,chinaJadeMat,chinaGoldMat][Math.abs(seed+k)%3],y-.36);cloth.rotation.z=(k%2)*.08;}}
          addChinaLantern(x-w*.32,front+.5,4.05,seed);
        }else if(kind==='chinatown_market'){
          // Layered shopfronts turn every super-block into a readable market street.
          for(let k=-1;k<=1;k++){const awning=propBox(x+k*w*.27,front+.7,w*.22,1.35,.2,k===0?chinaGoldMat:chinaRedMat,3.35);awning.rotation.x=-.15;addChinaLantern(x+k*w*.27,front+1.15,3.02,seed+k);}
          addChinaVerticalSign(side+.2,z+d*.18,6.2,seed,1);propBox(x,front+.1,w*.82,.14,.18,chinaNeonGold,4.15);
          for(let k=-2;k<=2;k++)propBox(x+k*w*.14,front+1.1,.9,.75,.72,k%2?chinaJadeMat:chinaRedMat,.38);
        }else if(kind==='chinatown_neon'){
          // Dense vertical neon is deliberately geometric and crisp at the fixed camera distance.
          addChinaVerticalSign(side+.18,z+d*.2,6.4,seed,1);addChinaVerticalSign(x-w*.28,front+.12,8.1,seed+1,-1);
          for(let y=3.5;y<h-1;y+=3.4){const band=propBox(x,front-.98,w*.78,.08,.12,chinaGlowMats[(seed+Math.floor(y))%chinaGlowMats.length],y);band.castShadow=false;}
          for(let k=-2;k<=2;k++)addChinaLantern(x+k*w*.13,front+.72,4.45,seed+k);
        }else if(kind==='chinatown_rich'){
          // Stone entrance, guarded jade planters and gold balcony rails distinguish the wealthy enclave.
          for(const sx of [-w*.3,w*.3]){const col=new THREE.Mesh(new THREE.CylinderGeometry(.3,.4,5.4,14),chinaGoldMat);col.position.set(x+sx,2.7,front);districtProps.add(col);}
          for(let floor=5;floor<h-2;floor+=4){propBox(x,front-.72,w*.68,.72,.16,chinaGoldMat,floor);for(let k=-2;k<=2;k++)propBox(x+k*w*.11,front-.35,.07,.07,.65,chinaGoldMat,floor+.28);}
          for(const sx of [-w*.3,w*.3]){const planter=propBox(x+sx,front+.95,1.35,1.35,.75,chinaJadeMat,.38);const crown=new THREE.Mesh(new THREE.SphereGeometry(.72,10,7),new THREE.MeshStandardMaterial({color:0x27664c,roughness:1}));crown.position.set(planter.position.x,1.2,planter.position.z);districtProps.add(crown);}
        }else if(kind==='chinatown_docks'){
          propBox(side,z,.85,d*.8,Math.max(3,h*.56),chinaSteelMat,Math.max(3,h*.56)/2);propBox(x,front,w*.7,1.4,.72,chinaRedMat,.36);
          for(let k=-2;k<=2;k++)propBox(x+k*w*.13,front+1.05,1.15,.85,.65,[chinaRedMat,chinaJadeMat,chinaGoldMat][Math.abs(seed+k)%3],.33+(Math.abs(k)%2)*.35);
          for(const sx of [-1,1]){const pipe=new THREE.Mesh(new THREE.CylinderGeometry(.18,.26,Math.max(4,h*.48),9),chinaSteelMat);pipe.position.set(side+sx*.58,h*.24,z);districtProps.add(pipe);}
          addChinaVerticalSign(x-w*.31,front+.12,5.7,seed,-1);
        }
      };
      const addChinatownRoof=(x,z,w,d,h,seed)=>{const tier1=box(x,z,w*.82,d*.82,.48,chinaJadeMat);tier1.position.y=h+.28;const tier2=box(x,z,w*.62,d*.62,.42,chinaRedMat);tier2.position.y=h+.73;const tier3=box(x,z,w*.38,d*.38,.34,chinaGoldMat);tier3.position.y=h+1.12;for(const [sx,sz] of [[-1,-1],[-1,1],[1,-1],[1,1]]){const finial=new THREE.Mesh(new THREE.ConeGeometry(.13,.72,8),chinaGoldMat);finial.position.set(x+sx*w*.4,h+.76,z+sz*d*.4);districtProps.add(finial);}if(seed%2===0)addChinaLantern(x,z,h+2.05,seed);};
      const addRoofDetails=(x,z,w,d,h,variant)=>{
        // Strong silhouettes are readable even from the fixed isometric camera.
        const parapet=box(x,z,w+.65,d+.65,.38,detailMat);parapet.position.y=h+.19;
        const acMat=new THREE.MeshStandardMaterial({color:0x68757d,metalness:.48,roughness:.46});
        for(let i=0;i<2+(variant%2);i++){const ac=box(x-w*.23+i*w*.23,z+d*.16,1.45,1.05,.72,acMat);ac.position.y=h+.55;const fan=new THREE.Mesh(new THREE.CylinderGeometry(.31,.31,.08,12),new THREE.MeshBasicMaterial({color:0x222a30}));fan.rotation.x=Math.PI/2;fan.position.set(ac.position.x,h+.62,ac.position.z+.55);scene.add(fan);}
        if(variant===2||variant===3){const antenna=new THREE.Mesh(new THREE.CylinderGeometry(.07,.11,5.2,7),detailMat);antenna.position.set(x-w*.24,h+2.6,z-d*.2);scene.add(antenna);for(let y=1;y<4;y++){const arm=new THREE.Mesh(new THREE.BoxGeometry(2.5,.07,.07),detailMat);arm.position.set(antenna.position.x,h+y,antenna.position.z);arm.rotation.y=y*.73;scene.add(arm);}}
        if(variant===0||variant===3){
          const tank=new THREE.Mesh(new THREE.CylinderGeometry(1.2,1.35,2.1,12),new THREE.MeshStandardMaterial({color:0x80543a,roughness:.75}));tank.position.set(x+w*.2,h+2.2,z-d*.12);tank.castShadow=true;scene.add(tank);
          for(const sx of [-.72,.72]){const leg=new THREE.Mesh(new THREE.CylinderGeometry(.1,.1,1.5,6),detailMat);leg.position.set(tank.position.x+sx,h+.85,tank.position.z);scene.add(leg);}
        }else if(variant===1){
          const pent=box(x+w*.16,z-d*.08,w*.42,d*.44,2.2,roofMat);pent.position.y=h+1.1;outline(pent);
          for(let i=-1;i<=1;i++){const vent=new THREE.Mesh(new THREE.CylinderGeometry(.24,.32,1.7,8),detailMat);vent.position.set(x+i*1.2,h+1.15,z+d*.22);scene.add(vent);}
        }else{
          const billboard=box(x,z-d*.08,5.6,.28,2.7,neonMats[variant%3]);billboard.position.y=h+2;outline(billboard);
        }
      };
      const themedWhite=new THREE.MeshStandardMaterial({color:0xe5e7e3,roughness:.74}),themedRed=new THREE.MeshStandardMaterial({color:0xb93636,roughness:.56}),themedBlue=new THREE.MeshStandardMaterial({color:0x347da1,roughness:.48,metalness:.16}),themedBrick=new THREE.MeshStandardMaterial({color:0x8d4938,roughness:.92}),themedDark=new THREE.MeshStandardMaterial({color:0x252a30,roughness:.62,metalness:.32}),themedGold=new THREE.MeshStandardMaterial({color:0xc79836,roughness:.36,metalness:.72}),themedGlass=new THREE.MeshPhysicalMaterial({color:0x75cce4,roughness:.08,metalness:.05,transmission:.18,clearcoat:1}),pizzaCheese=new THREE.MeshStandardMaterial({color:0xe9ad36,roughness:.66}),pizzaPepper=new THREE.MeshStandardMaterial({color:0xb62d2d,roughness:.6});
      const factorySmokePuffs=[],blackmarketDoorActors=[],blackmarketGuardActors=[];
      const addThemedArchitecture=(kind,x,z,w,d,h,seed)=>{const front=z+d/2+.08,add=(xx,zz,ww,dd,hh,mat,yy=hh/2)=>{const q=box(xx,zz,ww,dd,hh,mat);q.position.y=yy;return q;};
        if(kind==='mafia_hq'){
          const burjGlass=new THREE.MeshPhysicalMaterial({color:0x315f83,emissive:0x112a42,emissiveIntensity:.28,roughness:.1,metalness:.32,transmission:.12,thickness:.4,clearcoat:1,clearcoatRoughness:.04,envMap:cityEnvironment,envMapIntensity:1.5}),burjBlack=new THREE.MeshStandardMaterial({color:0x101820,roughness:.24,metalness:.78,envMap:cityEnvironment,envMapIntensity:.9}),burjLight=new THREE.MeshBasicMaterial({color:0x9fdcff,toneMapped:false}),burjWarm=new THREE.MeshBasicMaterial({color:0xffd47b,toneMapped:false});
          // Three buttresses and staggered upper tiers reproduce the unmistakable Burj-style silhouette.
          add(x,z,w+1,d+1,.68,burjBlack,h+.22);for(let arm=0;arm<3;arm++){const a=arm*Math.PI*2/3,wing=add(x+Math.cos(a)*w*.17,z+Math.sin(a)*d*.17,w*.38,d*.72,h*.76,burjGlass,h*.38);wing.rotation.y=-a;outline(wing);}
          const core=add(x,z,w*.54,d*.54,h+1.2,burjGlass,(h+1.2)/2);outline(core);const tiers=[[.46,.46,5,h+2.5],[.36,.36,4,h+7],[.27,.27,3,h+10.5],[.18,.18,2,h+13]];for(const [sw,sd,th,yy] of tiers){const tier=add(x,z,w*sw,d*sd,th,burjGlass,yy);outline(tier);const collar=add(x,z,w*(sw+.04),d*(sd+.04),.28,burjLight,yy-th/2+.18);collar.castShadow=false;}
          for(let y=4;y<h;y+=3.4){const band=add(x,z+d*.275,w*.48,.08,.11,(Math.round(y)%3)?burjLight:burjWarm,y);band.castShadow=false;}
          // A long two-stage spire and aviation beacon make the headquarters visible across the city.
          const spireBase=new THREE.Mesh(new THREE.CylinderGeometry(.42,.72,3.5,12),burjBlack);spireBase.position.set(x,h+15,z);spireBase.castShadow=true;scene.add(spireBase);const spire=new THREE.Mesh(new THREE.CylinderGeometry(.07,.24,6,10),themedGold);spire.position.set(x,h+19.5,z);spire.castShadow=true;scene.add(spire);const beacon=new THREE.Mesh(new THREE.SphereGeometry(.28,12,8),new THREE.MeshBasicMaterial({color:0xff3d48,toneMapped:false}));beacon.position.set(x,h+22.8,z);scene.add(beacon);
          // Premium ground floor: black marble porte-cochère, gold columns and the family marque.
          add(x,front+1.3,w*.62,2.7,.42,themedGold,4.7);add(x,front+.45,w*.38,.28,4.2,burjGlass,2.1);for(const sx of [-w*.25,w*.25]){const column=new THREE.Mesh(new THREE.CylinderGeometry(.28,.36,4.9,16),themedGold);column.position.set(x+sx,2.45,front+.8);column.castShadow=true;scene.add(column);}add(x,front+4,w*.72,6,.18,burjBlack,.09);
          const hqSign=roofMountedSign('BURJ MAFIA · BELLINI','#ffd266',12.8,1.7);hqSign.position.set(x,h+.08,z+d*.22);scene.add(hqSign);for(const sx of [-w*.35,w*.35]){const spot=new THREE.SpotLight(sx<0?0x8fd8ff:0xffd17c,24,48,.3,.72,1.5);spot.position.set(x+sx,5.5,front);spot.target.position.set(x+sx*.35,h*.7,z);scene.add(spot,spot.target);}renderer.domElement.dataset.mafiaHqArchitecture='burj-mafia-premium-tower';
        }else if(kind==='mansion'){
          const ivory=new THREE.MeshStandardMaterial({color:0xd8cfb7,roughness:.62,metalness:.08}),mansionStone=new THREE.MeshStandardMaterial({color:0x8e8476,roughness:.78,metalness:.12}),mansionRoof=new THREE.MeshStandardMaterial({color:0x263847,roughness:.38,metalness:.55,envMap:cityEnvironment,envMapIntensity:.7}),mansionWood=new THREE.MeshStandardMaterial({color:0x4b241d,roughness:.55,metalness:.12}),hedgeMat=new THREE.MeshStandardMaterial({color:0x1f5a39,roughness:.96}),mansionGlow=new THREE.MeshBasicMaterial({color:0xffd87a,toneMapped:false});
          // Low symmetrical estate massing: central hall, two wings and a dark mansard roof.
          add(x-w*.33,z,w*.3,d*.78,6.2,ivory,3.1);add(x+w*.33,z,w*.3,d*.78,6.2,ivory,3.1);add(x,z-d*.08,w*.38,d*.7,9.2,ivory,4.6);for(const [xx,ww,dd,yy] of [[x-w*.33,w*.34,d*.82,6.45],[x+w*.33,w*.34,d*.82,6.45],[x,w*.44,d*.75,9.55]]){const roof=add(xx,z,ww,dd,.75,mansionRoof,yy);outline(roof);}
          // Classical portico and carved double doors.
          add(x,front+.9,w*.48,1.9,.34,themedGold,5.05);for(const sx of [-w*.2,-w*.07,w*.07,w*.2]){const col=new THREE.Mesh(new THREE.CylinderGeometry(.25,.34,4.9,16),ivory);col.position.set(x+sx,2.45,front+.58);col.castShadow=true;scene.add(col);}add(x,front+.25,w*.17,.2,3.85,mansionWood,1.93);add(x,front+.38,.08,.24,3.65,themedGold,1.92);
          // Warm arched windows are repeated deliberately, so the house remains rich at the fixed camera distance.
          for(const sx of [-w*.4,-w*.29,-w*.12,w*.12,w*.29,w*.4])for(const y of [2.35,4.45]){const pane=add(x+sx,front+.12,w*.065,.08,.92,mansionGlow,y);pane.castShadow=false;const arch=new THREE.Mesh(new THREE.TorusGeometry(w*.036,.065,7,18,Math.PI),themedGold);arch.position.set(x+sx,y+.46,front+.2);arch.rotation.z=Math.PI;scene.add(arch);}
          // Gated forecourt, clipped hedges, fountain and a gold family crest create a real estate compound.
          add(x,front+6.4,w*.84,9.2,.18,mansionStone,.09);for(const sx of [-w*.43,w*.43]){add(x+sx,front+6.4,.72,9.2,1.1,hedgeMat,.55);const gatePost=add(x+sx,front+10.8,.86,.86,3.3,mansionStone,1.65);add(gatePost.position.x,gatePost.position.z,1.12,1.12,.22,themedGold,3.35);}for(const sx of [-2.2,2.2]){add(x+sx,front+10.8,4.15,.16,2.35,mansionWood,1.18);for(let k=-1;k<=1;k++)add(x+sx+k*1.1,front+10.92,.07,.08,2.1,themedGold,1.2);}
          const basin=new THREE.Mesh(new THREE.CylinderGeometry(2.25,2.55,.55,32),mansionStone);basin.position.set(x,.28,front+6.1);basin.castShadow=basin.receiveShadow=true;scene.add(basin);const water=new THREE.Mesh(new THREE.CylinderGeometry(2.05,2.05,.09,32),new THREE.MeshPhysicalMaterial({color:0x52bddd,roughness:.08,transparent:true,opacity:.82,clearcoat:1}));water.position.set(x,.61,front+6.1);scene.add(water);const jet=new THREE.Mesh(new THREE.CylinderGeometry(.045,.07,2.3,7),new THREE.MeshBasicMaterial({color:0xcdf6ff,transparent:true,opacity:.82}));jet.position.set(x,1.75,front+6.1);scene.add(jet);
          const crestShape=new THREE.Shape();crestShape.moveTo(0,1.05);crestShape.lineTo(.9,.65);crestShape.lineTo(.68,-.58);crestShape.quadraticCurveTo(0,-1.25,-.68,-.58);crestShape.lineTo(-.9,.65);crestShape.closePath();const crest=new THREE.Mesh(new THREE.ExtrudeGeometry(crestShape,{depth:.16,bevelEnabled:true,bevelSize:.06,bevelThickness:.06,bevelSegments:2}),themedGold);crest.position.set(x,7.55,front+.26);crest.castShadow=true;scene.add(crest);const label=roofMountedSign('RESIDENZA DEL DON','#e4c267',11.5,1.65);label.position.set(x,h+.08,z+d*.22);scene.add(label);renderer.domElement.dataset.mansionArchitecture='don-premium-estate';
        }else if(String(kind).startsWith('blackmarket')){
          const accent=kind==='blackmarket_bellini'?0xd3aa52:kind==='blackmarket_moretti'?0xb83f48:0x8d62ff;
          const marketBrick=new THREE.MeshStandardMaterial({color:0x241f24,roughness:.92,metalness:.06}),marketSteel=new THREE.MeshStandardMaterial({color:0x171d23,roughness:.34,metalness:.82}),marketTrim=new THREE.MeshStandardMaterial({color:0x6d737a,roughness:.42,metalness:.76}),marketGlow=new THREE.MeshBasicMaterial({color:accent,toneMapped:false}),marketGlass=new THREE.MeshPhysicalMaterial({color:0x292238,emissive:new THREE.Color(accent),emissiveIntensity:.28,roughness:.12,metalness:.18,transmission:.08,clearcoat:1});
          // Dark masonry, steel cornice and barred windows replace the generic
          // apartment frontage without changing the authoritative footprint.
          add(x,z,w+.36,d+.36,.42,marketSteel,h+.18);
          for(const sx of [-w*.46,-w*.23,0,w*.23,w*.46])add(x+sx,front+.11,.24,.22,h*.82,marketTrim,h*.41);
          for(const sx of [-w*.34,-w*.17,w*.17,w*.34])for(const y of [3.15,5.75]){
            add(x+sx,front+.145,w*.105,.12,1.18,marketGlass,y);
            for(let slat=-1;slat<=1;slat++)add(x+sx+slat*w*.026,front+.23,.045,.08,1.34,marketSteel,y);
          }
          // Recessed entrance and a real two-leaf armored door.
          const entryZ=front+.32,doorW=Math.min(1.55,w*.095),doorH=4.05;
          add(x,entryZ,w*.27,.48,4.8,marketSteel,2.4);add(x,front+1.05,w*.36,1.85,.28,marketTrim,4.82);
          for(const sx of [-w*.18,w*.18])add(x+sx,front+.72,.34,.34,5.15,marketSteel,2.58);
          const leftPivot=new THREE.Group(),rightPivot=new THREE.Group();leftPivot.position.set(x-doorW,doorH*.5,entryZ+.28);rightPivot.position.set(x+doorW,doorH*.5,entryZ+.28);scene.add(leftPivot,rightPivot);
          const leftDoor=new THREE.Mesh(new THREE.BoxGeometry(doorW,doorH,.24),marketGlass),rightDoor=new THREE.Mesh(new THREE.BoxGeometry(doorW,doorH,.24),marketGlass);leftDoor.position.x=doorW*.5;rightDoor.position.x=-doorW*.5;leftDoor.castShadow=rightDoor.castShadow=true;leftPivot.add(leftDoor);rightPivot.add(rightDoor);
          for(const door of [leftDoor,rightDoor])for(let y=-1.5;y<=1.5;y+=.75){const bar=new THREE.Mesh(new THREE.BoxGeometry(doorW*.82,.055,.08),marketTrim);bar.position.set(0,y,.17);door.add(bar);}
          blackmarketDoorActors.push({left:leftPivot,right:rightPivot,x,z:front+1.25,open:0});
          // Neon identity, surveillance cameras, ventilation and unloading props.
          const sign=roofMountedSign(kind==='blackmarket'?'ЧЁРНЫЙ РЫНОК':kind==='blackmarket_bellini'?'MERCATO BELLINI':'MERCATO MORETTI',`#${accent.toString(16).padStart(6,'0')}`,Math.min(13,w*.72),1.65);sign.position.set(x,h+.08,z+d*.22);scene.add(sign);
          add(x,front+.77,w*.58,.3,.16,marketGlow,6.55);
          for(const sx of [-w*.38,w*.38]){const mount=add(x+sx,front+.68,.18,.18,.62,marketTrim,5.45),cameraBody=add(x+sx+(sx<0?.28:-.28),front+.88,.62,.36,.34,marketSteel,5.22);cameraBody.rotation.z=sx<0?-.16:.16;cameraBody.rotation.y=sx<0?.18:-.18;mount.castShadow=cameraBody.castShadow=false;}
          for(const sx of [-w*.27,0,w*.27]){const vent=new THREE.Mesh(new THREE.CylinderGeometry(.32,.42,1.8,10),marketSteel);vent.position.set(x+sx,h+.9,z-d*.12);vent.castShadow=true;scene.add(vent);const cap=new THREE.Mesh(new THREE.CylinderGeometry(.52,.36,.28,10),marketTrim);cap.position.set(x+sx,h+1.82,z-d*.12);scene.add(cap);}
          const apron=add(x,front+3.1,w*.66,5.3,.18,new THREE.MeshStandardMaterial({color:0x35383c,roughness:.94}),.09);apron.receiveShadow=true;
          for(const sx of [-w*.3,w*.3])for(let i=0;i<2;i++){const crate=add(x+sx,front+2.15+i*.9,1.15,.82,.72,new THREE.MeshStandardMaterial({color:0x654126,roughness:.9}),.36);crate.rotation.y=(sx<0?-1:1)*.08;}
          // Authored guard is visual-only and never consumes gameplay NPC slots.
          const guard=new THREE.Group(),guardBody=new THREE.Mesh(new THREE.BoxGeometry(1.05,1.65,.65),marketSteel),guardHead=new THREE.Mesh(new THREE.SphereGeometry(.42,12,9),new THREE.MeshStandardMaterial({color:0xb98363,roughness:.9})),guardCap=new THREE.Mesh(new THREE.CylinderGeometry(.48,.52,.3,12),marketSteel),guardArmL=new THREE.Mesh(new THREE.BoxGeometry(.3,1.45,.34),marketBrick),guardArmR=guardArmL.clone(),guardLegL=new THREE.Mesh(new THREE.BoxGeometry(.38,1.5,.44),marketSteel),guardLegR=guardLegL.clone(),guardGun=new THREE.Mesh(new THREE.BoxGeometry(.18,.18,1.55),marketTrim);
          guardBody.position.y=2.05;guardHead.position.y=3.25;guardCap.position.y=3.62;guardArmL.position.set(-.68,2.05,.12);guardArmR.position.set(.68,2.05,.12);guardLegL.position.set(-.28,.75,0);guardLegR.position.set(.28,.75,0);guardGun.position.set(.55,1.95,.5);guardGun.rotation.x=-.22;guard.add(guardBody,guardHead,guardCap,guardArmL,guardArmR,guardLegL,guardLegR,guardGun);guard.position.set(x+w*.23,0,front+1.45);guard.rotation.y=Math.PI;scene.add(guard);blackmarketGuardActors.push({root:guard,head:guardHead,leftArm:guardArmL,rightArm:guardArmR,baseY:guard.position.y,phase:(seed%17)*.37});
          renderer.domElement.dataset.blackmarketArchitecture='armored-brick-neon-guarded-v1';renderer.domElement.dataset.blackmarketDoors=String(blackmarketDoorActors.length);renderer.domElement.dataset.blackmarketGuards=String(blackmarketGuardActors.length);
        }else if(kind==='hospital'||kind==='hospital_east'){add(x-w*.34,z,w*.3,d*.82,5.4,themedWhite,2.7);add(x+w*.34,z,w*.3,d*.82,5.4,themedWhite,2.7);add(x,front+.62,w*.34,1.45,3.7,themedGlass,1.85);add(x,front+1.3,w*.5,2.2,.28,themedRed,3.85);const v=add(x,z,1.2,.5,5,themedRed,h+2.5),q=add(x,z,4.4,.5,1.2,themedRed,h+2.5);v.castShadow=q.castShadow=true;const helipad=new THREE.Mesh(new THREE.RingGeometry(2.1,2.55,32),new THREE.MeshBasicMaterial({color:0xe04a4a,side:THREE.DoubleSide}));helipad.rotation.x=-Math.PI/2;helipad.position.set(x-w*.25,h+.08,z-d*.18);scene.add(helipad);
        }else if(kind==='pizza'){add(x,z,w+.35,d+.35,.42,themedRed,h+.18);for(let k=-2;k<=2;k++)add(x+k*w*.13,front+.72,w*.12,1.35,.2,k%2?themedWhite:themedRed,3.15);const sign=new THREE.Mesh(new THREE.CylinderGeometry(1.65,1.65,.24,28),pizzaCheese);sign.rotation.x=Math.PI/2;sign.position.set(x,h+2.05,front+.18);scene.add(sign);for(let i=0;i<5;i++){const p=new THREE.Mesh(new THREE.CylinderGeometry(.22,.22,.08,12),pizzaPepper);const a=i/5*Math.PI*2;p.rotation.x=Math.PI/2;p.position.set(x+Math.cos(a)*.85,h+2.05+Math.sin(a)*.85,front+.34);scene.add(p);}const chimney=add(x-w*.28,z-d*.18,1.05,1.05,3.2,themedBrick,h+1.6);add(chimney.position.x,chimney.position.z,1.35,1.35,.25,themedDark,h+3.18);
        }else if(kind==='coffee'){add(x,z,w+.3,d+.3,.38,themedBrick,h+.16);for(let k=-2;k<=2;k++)add(x+k*w*.13,front+.7,w*.12,1.3,.22,k%2?themedWhite:themedGold,3.45);for(const sx of [-w*.24,w*.24]){const table=new THREE.Mesh(new THREE.CylinderGeometry(.72,.72,.16,18),themedGold);table.position.set(x+sx,.85,front+2);scene.add(table);add(x+sx,front+2,.15,.15,1.4,themedDark,.7);}
        }else if(kind==='carwash'){add(x,z,w*.88,d*.86,.4,themedBlue,h+.18);for(const sx of [-w*.27,w*.27]){add(x+sx,front+.2,w*.2,.22,3.5,themedDark,1.75);const roller=new THREE.Mesh(new THREE.CylinderGeometry(.72,.72,3.1,16),new THREE.MeshStandardMaterial({color:sx<0?0x2f8fd0:0xf05a55,roughness:.8}));roller.position.set(x+sx,1.65,front+.75);scene.add(roller);}add(x,front+1.25,w*.72,1.8,.28,themedBlue,3.65);
        }else if(kind==='barbershop'){for(let k=-2;k<=2;k++)add(x+k*w*.13,front+.68,w*.12,1.3,.22,k%2?themedWhite:themedRed,3.35);const pole=new THREE.Group();for(let i=0;i<8;i++){const band=new THREE.Mesh(new THREE.CylinderGeometry(.25,.25,.42,12),i%2?themedWhite:themedRed);band.position.y=i*.39;pole.add(band);}pole.position.set(x+w*.42,1.05,front+.82);scene.add(pole);add(x,z,w+.25,d+.25,.35,themedBlue,h+.14);
        }else if(kind==='police'){
          const policeStone=new THREE.MeshStandardMaterial({color:0xaeb8bd,roughness:.62,metalness:.12}),policeNavy=new THREE.MeshStandardMaterial({color:0x163d68,roughness:.34,metalness:.5}),policeGlow=new THREE.MeshBasicMaterial({color:0x66c8ff,toneMapped:false}),policeRedGlow=new THREE.MeshBasicMaterial({color:0xff4053,toneMapped:false});
          // Broad civic wings and a central entrance keep the station low, authoritative and distinct from offices.
          add(x,z,w+.45,d+.45,.46,policeNavy,h+.18);add(x-w*.34,z,w*.28,d*.84,6.4,policeStone,3.2);add(x+w*.34,z,w*.28,d*.84,6.4,policeStone,3.2);add(x,z-d*.08,w*.4,d*.7,8.25,themedWhite,4.13);
          add(x,front+.48,w*.34,1.25,4.65,themedGlass,2.33);add(x,front+.57,.1,1.32,4.52,themedGold,2.3);add(x,front+1.38,w*.52,2.15,.36,policeNavy,4.55);
          for(const sx of [-w*.24,w*.24]){const column=new THREE.Mesh(new THREE.CylinderGeometry(.3,.39,4.65,14),policeStone);column.position.set(x+sx,2.33,front+.72);column.castShadow=true;scene.add(column);}
          for(let step=0;step<3;step++)add(x,front+1.58+step*.42,w*(.48+step*.08),.82,.22,policeStone,.11+step*.11);
          // Two operational vehicle bays, with crisp segmented shutters and warning lights.
          for(const sx of [-w*.34,w*.34]){add(x+sx,front+.18,w*.22,.16,3.35,themedDark,1.68);for(let y=.48;y<3.2;y+=.55)add(x+sx,front+.28,w*.2,.06,.055,policeStone,y);const lamp=add(x+sx,front+.42,.55,.12,.18,sx<0?policeGlow:policeRedGlow,3.55);lamp.castShadow=false;}
          const signCv=document.createElement('canvas');signCv.width=1024;signCv.height=230;const signCtx=signCv.getContext('2d'),signGradient=signCtx.createLinearGradient(0,0,1024,0);signGradient.addColorStop(0,'#0d2746');signGradient.addColorStop(.5,'#1d568b');signGradient.addColorStop(1,'#0d2746');signCtx.fillStyle=signGradient;signCtx.fillRect(0,0,1024,230);signCtx.strokeStyle='#89d7ff';signCtx.lineWidth=13;signCtx.strokeRect(10,10,1004,210);signCtx.textAlign='center';signCtx.textBaseline='middle';signCtx.shadowColor='#58bfff';signCtx.shadowBlur=20;signCtx.fillStyle='#edf9ff';signCtx.font='900 92px Georgia,serif';signCtx.fillText('POLICE',512,101);signCtx.shadowBlur=0;signCtx.fillStyle='#a9dfff';signCtx.font='800 31px system-ui,sans-serif';signCtx.fillText('CITY PRECINCT  •  24 HOURS',512,176);const signTx=new THREE.CanvasTexture(signCv);signTx.colorSpace=THREE.SRGBColorSpace;signTx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());signTx.generateMipmaps=false;const stationSign=new THREE.Mesh(new THREE.PlaneGeometry(Math.min(11,w*.7),2.48),new THREE.MeshBasicMaterial({map:signTx,toneMapped:false}));stationSign.position.set(x,7.25,front+.75);stationSign.renderOrder=8;scene.add(stationSign);
          // Extruded shield and star make the building readable even before the sign text resolves.
          const shieldShape=new THREE.Shape();shieldShape.moveTo(0,1.42);shieldShape.lineTo(1.16,.92);shieldShape.lineTo(.92,-.72);shieldShape.quadraticCurveTo(0,-1.65,-.92,-.72);shieldShape.lineTo(-1.16,.92);shieldShape.closePath();const shield=new THREE.Mesh(new THREE.ExtrudeGeometry(shieldShape,{depth:.2,bevelEnabled:true,bevelSize:.08,bevelThickness:.08,bevelSegments:2}),themedGold);shield.position.set(x,h+1.45,front-.2);shield.castShadow=true;scene.add(shield);const badgeStar=new THREE.Mesh(new THREE.CircleGeometry(.5,5),policeGlow);badgeStar.position.set(x,h+1.45,front+.1);badgeStar.rotation.z=Math.PI/10;scene.add(badgeStar);
          // Radio mast, antenna array and dual precinct floodlights finish the roof silhouette.
          const mast=new THREE.Mesh(new THREE.CylinderGeometry(.09,.16,7.2,9),themedDark);mast.position.set(x-w*.24,h+3.6,z-d*.18);mast.castShadow=true;scene.add(mast);for(let y=0;y<3;y++){const arm=add(x-w*.24,z-d*.18,2.8-y*.45,.08,.08,policeStone,h+2.15+y*1.25);arm.rotation.y=y*.7;}for(const sx of [-w*.39,w*.39]){const flood=new THREE.SpotLight(sx<0?0x6ccaff:0xff5a67,18,24,.42,.72,1.5);flood.position.set(x+sx,h+.8,front-.5);flood.target.position.set(x+sx*.7,0,front+5);scene.add(flood,flood.target);}
          add(x,front+4,w*.88,6.1,.2,policeStone,.1);for(const sx of [-w*.42,w*.42])add(x+sx,front+4,.28,6.1,1.05,policeNavy,.53);renderer.domElement.dataset.policeArchitecture='premium-city-precinct';
        }else if(kind==='garage'||kind==='firestation'){const doorMat=kind==='firestation'?themedRed:themedDark;for(const sx of [-w*.27,0,w*.27]){add(x+sx,front+.14,w*.22,.18,3.5,doorMat,1.75);for(let y=.5;y<3.4;y+=.62)add(x+sx,front+.25,w*.2,.05,.06,themedWhite,y);}add(x,z,w*.9,d*.85,.4,kind==='firestation'?themedWhite:themedBlue,h+.18);for(const sx of [-w*.38,w*.38])add(x+sx,z-d*.12,.55,.55,3.6,themedDark,h+1.8);
        }else if(kind==='warehouse'||kind==='port'){add(x,z,w+.3,d+.3,.42,themedDark,h+.18);for(const sx of [-w*.3,0,w*.3])add(x+sx,front+.15,w*.22,.2,3.4,new THREE.MeshStandardMaterial({color:sx?0x526b75:0xa54a34,roughness:.72}),1.7);for(let i=-2;i<=2;i++)add(x+i*w*.13,front+1.3,w*.1,1.5,.72,[themedRed,themedBlue,themedGold][Math.abs(i)%3],.36);
        }else if(kind==='bar'||kind==='club'||kind==='casino'){const glow=neonMats[kind==='bar'?0:kind==='club'?1:2];add(x,z,w+.32,d+.32,.38,themedDark,h+.16);add(x,front+1,w*.62,2,.26,glow,3.75);for(const sx of [-w*.34,w*.34])add(x+sx,front+.25,.16,.16,4.8,glow,2.4);if(kind==='casino'){const crown=new THREE.Mesh(new THREE.TorusGeometry(2.8,.3,10,32),themedGold);crown.rotation.x=Math.PI/2;crown.position.set(x,h+2.2,z);scene.add(crown);}
        }else if(kind==='market'){
          const marketGreen=new THREE.MeshStandardMaterial({color:0x2f7552,roughness:.74}),marketCream=new THREE.MeshStandardMaterial({color:0xe7d7b7,roughness:.82}),marketWood=new THREE.MeshStandardMaterial({color:0x603a25,roughness:.8}),marketGlow=new THREE.MeshBasicMaterial({color:0xffd36a,toneMapped:false});
          add(x,z,w+.4,d+.4,.42,themedBrick,h+.18);
          // A deep stone arcade and striped awnings make the hall read as a public market from street level.
          for(let bay=-2;bay<=2;bay++){
            const bx=x+bay*w*.16;
            for(const side of [-1,1]){const col=new THREE.Mesh(new THREE.CylinderGeometry(.24,.32,4.15,14),marketCream);col.position.set(bx+side*w*.055,2.08,front+.34);col.castShadow=true;scene.add(col);}
            const arch=new THREE.Mesh(new THREE.TorusGeometry(w*.055,.16,8,22,Math.PI),bay===0?themedGold:marketCream);arch.position.set(bx,3.87,front+.43);arch.rotation.z=Math.PI;scene.add(arch);
            add(bx,front+.13,w*.1,.16,2.95,bay===0?themedGlass:marketWood,1.5);
            const awning=add(bx,front+1.05,w*.135,1.55,.18,bay%2?marketGreen:themedGold,3.33);awning.rotation.x=-.08;
            for(let stripe=-2;stripe<=2;stripe++)add(bx+stripe*w*.021,front+1.14,w*.018,1.5,.04,stripe%2?marketCream:marketGreen,3.38).rotation.x=-.08;
          }
          // Central roof pavilion, clock and produce crates replace the anonymous rectangular silhouette.
          add(x,z-d*.12,w*.3,d*.3,2.65,marketCream,h+1.32);add(x,z-d*.12,w*.35,d*.35,.32,themedGold,h+2.82);
          const clockFace=new THREE.Mesh(new THREE.CylinderGeometry(1.16,1.16,.22,32),marketCream);clockFace.rotation.x=Math.PI/2;clockFace.position.set(x,h+1.45,front+.19);scene.add(clockFace);
          const clockRim=new THREE.Mesh(new THREE.TorusGeometry(1.16,.12,10,32),themedGold);clockRim.position.copy(clockFace.position);clockRim.position.z+=.14;scene.add(clockRim);
          for(const angle of [0,Math.PI/2]){const hand=add(x,front+.36,angle?1.02:.72,.07,.07,themedDark,h+1.45);hand.rotation.z=angle?-.58:.2;}
          const roof=new THREE.Mesh(new THREE.ConeGeometry(w*.22,2.25,4),marketGreen);roof.rotation.y=Math.PI/4;roof.position.set(x,h+4.05,z-d*.12);roof.castShadow=true;scene.add(roof);
          const finial=new THREE.Mesh(new THREE.ConeGeometry(.2,.9,10),themedGold);finial.position.set(x,h+5.55,z-d*.12);scene.add(finial);
          for(const side of [-1,1])for(let i=0;i<3;i++){const crate=add(x+side*(w*.35+i*.68),front+2.25+i*.34,1.05,.82,.58,marketWood,.29);for(let f=0;f<5;f++){const fruit=new THREE.Mesh(new THREE.SphereGeometry(.13,9,6),new THREE.MeshStandardMaterial({color:[0xc84a35,0xe2ae36,0x5e9545][(i+f)%3],roughness:.9}));fruit.position.set(crate.position.x+(f-2)*.16,.7,crate.position.z);scene.add(fruit);}}
          const sign=roofMountedSign('MERCATO CENTRALE','#ffd263',Math.min(13,w*.75),1.65);sign.position.set(x,h+.08,z+d*.22);scene.add(sign);
          for(const sx of [-w*.42,w*.42]){const lantern=add(x+sx,front+.65,.24,.24,.72,marketGlow,4.5);lantern.castShadow=false;}
          renderer.domElement.dataset.marketArchitecture='central-market-arcade-clock-v1';
        }else if(kind==='factory'){
          const factoryConcrete=new THREE.MeshStandardMaterial({color:0x4b5156,roughness:.86,metalness:.12}),factoryBrick=new THREE.MeshStandardMaterial({color:0x843e34,roughness:.94}),factorySteel=new THREE.MeshStandardMaterial({color:0x39454d,roughness:.38,metalness:.76}),factoryOrange=new THREE.MeshStandardMaterial({color:0xe27a2e,roughness:.56,metalness:.18}),factoryGlass=new THREE.MeshPhysicalMaterial({color:0x79b7c5,roughness:.12,metalness:.16,transmission:.16,clearcoat:.8}),factoryWood=new THREE.MeshStandardMaterial({color:0x705032,roughness:.86}),hazardYellow=new THREE.MeshStandardMaterial({color:0xf0b42f,roughness:.6}),hazardBlack=new THREE.MeshStandardMaterial({color:0x16191c,roughness:.7});
          add(x,z,w+.42,d+.42,.46,factorySteel,h+.18);
          // Lower dispatch wing and three saw-tooth roof bays break the box silhouette.
          add(x+w*.35,z+d*.05,w*.28,d*.72,5.3,factoryConcrete,2.65);add(x+w*.35,z+d*.18,w*.22,d*.46,.22,factoryGlass,5.42);
          for(let bay=0;bay<4;bay++){
            const bx=x-w*.34+bay*w*.18,profile=new THREE.Shape();profile.moveTo(0,0);profile.lineTo(w*.17,0);profile.lineTo(w*.17,1.65);profile.closePath();const roofBay=new THREE.Mesh(new THREE.ExtrudeGeometry(profile,{depth:d*.66,bevelEnabled:false}),bay%2?factorySteel:factoryGlass);roofBay.position.set(bx,h+.2,z-d*.33);roofBay.castShadow=true;scene.add(roofBay);
            const skylight=add(bx+w*.12,z,w*.08,d*.58,.12,factoryGlass,h+1.12);skylight.rotation.z=.43;
          }
          // Two dominant brick stacks with steel hoops; the old duplicate POI stacks are suppressed above.
          for(const [index,sx] of [[0,-w*.27],[1,-w*.08]]){
            const stackH=index?10.5:13.2,chimney=new THREE.Mesh(new THREE.CylinderGeometry(.48,.82,stackH,16),factoryBrick);chimney.position.set(x+sx,h+stackH*.5-.1,z-d*.24);chimney.castShadow=true;scene.add(chimney);
            for(let ring=1;ring<=4;ring++){const hoop=new THREE.Mesh(new THREE.TorusGeometry(.52+(ring-1)*.04,.07,8,20),factorySteel);hoop.rotation.x=Math.PI/2;hoop.position.set(x+sx,h+ring*stackH/5-.1,z-d*.24);scene.add(hoop);}const rim=new THREE.Mesh(new THREE.TorusGeometry(.52,.11,9,24),hazardYellow);rim.rotation.x=Math.PI/2;rim.position.set(x+sx,h+stackH-.02,z-d*.24);scene.add(rim);
          }
          for(const [stack,sx,stackH] of [[0,-w*.27,13.2],[1,-w*.08,10.5]])for(let puff=0;puff<4;puff++){const material=new THREE.MeshStandardMaterial({color:stack?0x8d9294:0x777d80,transparent:true,opacity:.25,depthWrite:false,roughness:1}),smoke=new THREE.Mesh(new THREE.SphereGeometry(.72+puff*.12,10,7),material);smoke.castShadow=false;smoke.receiveShadow=false;smoke.position.set(x+sx,h+stackH+1+puff*1.65,z-d*.24);smoke.userData.factorySmoke={baseX:x+sx,baseY:h+stackH+.6,baseZ:z-d*.24,phase:(puff/4+stack*.13)%1,drift:stack?1:-1};scene.add(smoke);factorySmokePuffs.push(smoke);}
          // Twelve narrow workshop windows and rust-like vertical service fins.
          for(let row=0;row<2;row++)for(let col=-2;col<=2;col++){const wx=x+col*w*.145,wy=3.15+row*2.25;add(wx,front+.13,w*.095,.12,1.22,factoryGlass,wy);for(const side of [-1,1])add(wx+side*w*.052,front+.2,.055,.08,1.42,factoryOrange,wy);}
          // Loading shutter, dock and crash protection are readable at road level.
          add(x-w*.16,front+.15,w*.29,.2,4.15,factorySteel,2.08);for(let y=.42;y<4.05;y+=.5)add(x-w*.16,front+.28,w*.27,.06,.065,factoryConcrete,y).castShadow=false;
          add(x-w*.16,front+1.45,w*.36,2.55,.35,factoryConcrete,.18);for(const sx of [-w*.34,w*.02])add(x+sx,front+1.12,.32,.42,1.05,hazardYellow,.53);
          for(let stripe=-4;stripe<=4;stripe++){const stripeMesh=add(x-w*.16+stripe*w*.032,front+.39,w*.025,.08,.24,stripe%2?hazardYellow:hazardBlack,4.25);stripeMesh.rotation.z=stripe%2?.62:-.62;}
          // Exterior pipe rack, two silos, service ladder and catwalk.
          for(const y of [2.25,3.25,4.25]){const pipe=add(x-w*.47,z, .18,d*.76,.18,y%2>1?factoryOrange:factorySteel,y);pipe.rotation.x=Math.PI/2;}for(const rz of [-d*.26,d*.05,d*.28])add(x-w*.48,z+rz,.22,.22,4.7,factorySteel,2.35);
          for(const sz of [-d*.18,d*.16]){const silo=new THREE.Mesh(new THREE.CylinderGeometry(.82,1.02,4.6,16),factorySteel);silo.position.set(x+w*.47,2.35,z+sz);silo.castShadow=true;scene.add(silo);const cone=new THREE.Mesh(new THREE.ConeGeometry(1.02,1.15,16),factoryOrange);cone.position.set(x+w*.47,5.22,z+sz);scene.add(cone);}
          add(x+w*.45,z-d*.34,.16,d*.58,6.6,factorySteel,3.3);for(let rung=0;rung<9;rung++)add(x+w*.4,z-d*.34,.82,.08,.07,hazardYellow,.55+rung*.66);
          const catwalk=add(x,z-d*.34,w*.72,.92,.16,factorySteel,h+1.9);for(let rail=-3;rail<=3;rail++)add(x+rail*w*.1,z-d*.77,.07,.08,1.05,hazardYellow,h+2.43);
          // Pallets, oil drums and a forklift stage the yard without changing collision.
          for(let palletIndex=0;palletIndex<3;palletIndex++){const pallet=add(x+w*.18+palletIndex*1.28,front+1.65,1.08,.86,.18,factoryWood,.12);for(let crateIndex=0;crateIndex<2;crateIndex++)add(pallet.position.x+crateIndex*.46-.23,front+1.65,.42,.62,.72,crateIndex%2?factoryOrange:factoryConcrete,.54);}
          for(const sx of [w*.3,w*.39]){const drum=new THREE.Mesh(new THREE.CylinderGeometry(.38,.38,1.15,16),sx>w*.34?factoryOrange:factorySteel);drum.position.set(x+sx,.58,front+2.2);scene.add(drum);for(const yy of [.18,.95]){const ring=new THREE.Mesh(new THREE.TorusGeometry(.38,.035,7,16),hazardYellow);ring.rotation.x=Math.PI/2;ring.position.set(x+sx,yy,front+2.2);scene.add(ring);}}
          const forkliftBody=add(x+w*.34,front+4.1,2.35,1.45,.72,hazardYellow,.72);for(const sx of [-.72,.72])for(const sz of [-.46,.46]){const wheel=new THREE.Mesh(new THREE.CylinderGeometry(.28,.28,.24,14),hazardBlack);wheel.rotation.z=Math.PI/2;wheel.position.set(forkliftBody.position.x+sx,.34,front+4.1+sz);scene.add(wheel);}for(const sx of [.62,.82])add(x+w*.34+sx,front+3.65,.12,.12,2.65,factorySteel,1.32);
          // Gear emblem and large works sign make the function unmistakable.
          const gear=new THREE.Mesh(new THREE.TorusGeometry(1.12,.24,10,28),hazardYellow);gear.position.set(x+w*.23,6.75,front+.22);scene.add(gear);for(let tooth=0;tooth<12;tooth++){const a=tooth/12*Math.PI*2,toothMesh=add(x+w*.23+Math.cos(a)*1.35,front+.22,.28,.16,.52,hazardYellow,6.75+Math.sin(a)*1.35);toothMesh.rotation.z=a;}
          renderer.domElement.dataset.factoryArchitecture='sawtooth-works-twin-stacks-loading-yard-v1';
        }else if(kind==='gym'){for(const sx of [-w*.23,w*.23]){const bar=new THREE.Mesh(new THREE.CylinderGeometry(.16,.16,4,10),themedDark);bar.rotation.z=Math.PI/2;bar.position.set(x+sx,h+1.5,z);scene.add(bar);for(const dx of [-1.65,1.65]){const plate=new THREE.Mesh(new THREE.CylinderGeometry(.65,.65,.32,14),themedBlue);plate.rotation.z=Math.PI/2;plate.position.set(x+sx+dx,h+1.5,z);scene.add(plate);}}}
        else if(kind==='job_office'){const clock=new THREE.Mesh(new THREE.CylinderGeometry(1.4,1.4,.24,24),themedWhite);clock.rotation.x=Math.PI/2;clock.position.set(x,h+1.7,front+.2);scene.add(clock);add(x,front+.72,w*.55,1.35,.25,themedGold,3.7);}
      };
      // Major factory is a standalone POI, not a normal city building. The old
      // renderer placed only three detached chimneys at its interaction point.
      // Give that exact gameplay location a real hall before adding the authored details.
      let majorFactoryExteriorBuilt=false;
      const ensureMajorFactoryExterior=(snapshot,source='initial')=>{
        if(majorFactoryExteriorBuilt)return;
        const majorFactoryPoi=(snapshot?.pois||[]).find(p=>p.id==='factory');
        if(!majorFactoryPoi)return;
        majorFactoryExteriorBuilt=true;
        // The gameplay anchor sits in the loading yard. Keep the opaque hall
        // one tile behind it so both the real entrance and QA approach remain outside.
        const fx=(majorFactoryPoi.c-originC)*WORLD_SCALE,fz=(majorFactoryPoi.r-1-originR)*WORLD_SCALE,factoryFacade=new THREE.MeshStandardMaterial({color:0x555c61,roughness:.82,metalness:.16,emissive:0x5d2d18,emissiveIntensity:.055}),factoryRoof=new THREE.MeshStandardMaterial({color:0x20262b,roughness:.48,metalness:.62});
        const hall=buildingBox(fx,fz,22,15,9,factoryFacade,factoryRoof);hall.userData.fadeMaterials=[factoryFacade,factoryRoof];outline(hall);occluders.push(hall);const staticDetailStart=scene.children.length;
        addThemedArchitecture('factory',fx,fz,22,15,9,Math.abs(Math.round(majorFactoryPoi.r*37+majorFactoryPoi.c*53)));
        const yard=box(fx,fz+11.5,24,8,.22,new THREE.MeshStandardMaterial({color:0x4a4f52,roughness:.94}));yard.position.y=.11;yard.receiveShadow=true;
        for(let lane=-2;lane<=2;lane++){const stripe=box(fx+lane*4.25,fz+11.5,.16,7.2,.035,lane%2?themedGold:themedWhite);stripe.position.y=.24;}
        const factoryPoiLabel=roofMountedSign('INDUSTRIAL WORKS · PROMZONA','#ffb54e',13.5,1.75);factoryPoiLabel.position.set(fx,9.08,fz+5.1);scene.add(factoryPoiLabel);authoredLandmarkStaticDetails.push(...scene.children.slice(staticDetailStart));
        renderer.domElement.dataset.majorFactoryExterior=`poi-bound-sawtooth-industrial-complex-v2:${source}`;
      };
      ensureMajorFactoryExterior(worldSnapshot,'initial');
      // Purchasable businesses need to read from the street by silhouette, not
      // only by a floating label. These are visual-only props: gameplay entry,
      // collision and the authoritative business state still use the original
      // server coordinates and the main building mesh above.
      const businessExteriorFx=[];
      const addBusinessIdentityArchitecture=(kind,x,z,w,d,h,seed)=>{
        const front=z+d/2+.12,add=(xx,zz,ww,dd,hh,mat,yy=hh/2)=>{const q=box(xx,zz,ww,dd,hh,mat);q.position.y=yy;return q;};
        const metal=new THREE.MeshStandardMaterial({color:0x424d55,roughness:.42,metalness:.72}),black=new THREE.MeshStandardMaterial({color:0x101319,roughness:.72,metalness:.26}),rubber=new THREE.MeshStandardMaterial({color:0x111315,roughness:.98}),wood=new THREE.MeshStandardMaterial({color:0x684126,roughness:.84}),warm=new THREE.MeshBasicMaterial({color:0xffc568,toneMapped:false}),cyan=new THREE.MeshBasicMaterial({color:0x65e8ff,toneMapped:false}),pink=new THREE.MeshBasicMaterial({color:0xff4fad,toneMapped:false}),redGlow=new THREE.MeshBasicMaterial({color:0xff4a45,toneMapped:false}),green=new THREE.MeshStandardMaterial({color:0x24583b,roughness:.94}),water=new THREE.MeshPhysicalMaterial({color:0x69d8ef,transparent:true,opacity:.42,roughness:.06,metalness:.08,transmission:.28,depthWrite:false,side:THREE.DoubleSide}),crateMat=new THREE.MeshStandardMaterial({color:0x8d6036,roughness:.92}),hazard=new THREE.MeshStandardMaterial({color:0xe2aa2e,roughness:.48,metalness:.42});
        const sign=(text,color,_y=h+2.5,scale=1)=>{const s=roofMountedSign(text,color,Math.min(w*.82,12.4)*scale,1.65);s.position.set(x,h+.08,z+d*.22);scene.add(s);return s;};
        const cylinder=(geo,mat,xx,yy,zz,rx=0,ry=0,rz=0)=>{const m=new THREE.Mesh(geo,mat);m.position.set(xx,yy,zz);m.rotation.set(rx,ry,rz);m.castShadow=m.receiveShadow=true;scene.add(m);return m;};
        const planter=(xx,zz)=>{const pot=cylinder(new THREE.CylinderGeometry(.48,.62,.72,14),wood,xx,.36,zz),leaf=cylinder(new THREE.DodecahedronGeometry(.72,1),green,xx,1.18,zz);leaf.scale.set(.75,1.15,.75);return pot;};
        if(kind==='coffee'){
          // Caffe terrace, roof cup and steam make the small corner building unmistakable.
          add(x,front+2.2,w*.86,3.8,.18,wood,.09);for(const sx of [-w*.31,w*.31]){const table=cylinder(new THREE.CylinderGeometry(.68,.68,.16,20),wood,x+sx,.86,front+2.35);cylinder(new THREE.CylinderGeometry(.09,.12,.78,8),metal,x+sx,.43,front+2.35);for(const dz of [-1,1])add(x+sx,front+2.35+dz*.9,.72,.72,.62,green,.31);}for(const sx of [-w*.45,w*.45])planter(x+sx,front+2.75);
          const cup=cylinder(new THREE.CylinderGeometry(1.05,.78,1.25,24,1,true),themedWhite,x,h+1.25,z,0,0,0),coffee=cylinder(new THREE.CylinderGeometry(.82,.82,.05,24),new THREE.MeshStandardMaterial({color:0x3a1e12,roughness:.82}),x,h+1.88,z);const handle=cylinder(new THREE.TorusGeometry(.62,.13,8,20,Math.PI*1.6),themedGold,x+1.05,h+1.3,z,0,0,Math.PI/2);for(let i=0;i<3;i++){const steam=cylinder(new THREE.TorusGeometry(.34+i*.08,.045,6,18,Math.PI*1.2),new THREE.MeshBasicMaterial({color:0xf3ede4,transparent:true,opacity:.48-i*.08}),x-.42+i*.42,h+2.45+i*.48,z,0,0,.35);steam.castShadow=false;}sign('CAFFE DEL DON','#ffd27a',h+3.25,.9);
        }else if(kind==='carwash'){
          // Repeated wash arches and a transparent water curtain form a real drive-through bay.
          for(let lane=-1;lane<=1;lane++){const zz=front+.55+lane*1.15;for(const sx of [-w*.34,w*.34])add(x+sx,zz,.22,.26,3.65,themedBlue,1.83);add(x,zz,w*.68,.28,.24,themedBlue,3.65);}const curtain=new THREE.Mesh(new THREE.PlaneGeometry(w*.62,3.05),water);curtain.position.set(x,1.72,front+.72);curtain.renderOrder=5;scene.add(curtain);for(const sx of [-w*.43,w*.43]){cylinder(new THREE.CylinderGeometry(.48,.48,2.45,18),sx<0?cyan:themedRed,x+sx,1.24,front+1.05);add(x+sx,front+2.5,1.05,1.05,1.8,metal,.9);const hose=cylinder(new THREE.TorusGeometry(.6,.065,7,20,Math.PI*1.7),black,x+sx,1.75,front+2.5,Math.PI/2,0,0);hose.castShadow=false;}const dropShape=new THREE.Shape();dropShape.moveTo(0,1.45);dropShape.bezierCurveTo(1.2,.1,.95,-1.2,0,-1.3);dropShape.bezierCurveTo(-.95,-1.2,-1.2,.1,0,1.45);const drop=new THREE.Mesh(new THREE.ExtrudeGeometry(dropShape,{depth:.22,bevelEnabled:true,bevelSize:.08,bevelThickness:.08,bevelSegments:2}),cyan);drop.position.set(x,h+2.5,front+.32);drop.castShadow=true;scene.add(drop);sign('RICO CAR WASH','#88efff',h+4.45,.92);
          for(const sx of [-w*.43,w*.43]){const brush=cylinder(new THREE.CylinderGeometry(.56,.56,2.3,16),sx<0?cyan:themedRed,x+sx,1.3,front+1.08);businessExteriorFx.push({kind:'wash-brush',mesh:brush,phase:sx});}businessExteriorFx.push({kind:'wash-water',mesh:curtain,phase:seed});
        }else if(kind==='barbershop'){
          // Two oversized barber poles, scissors and a waiting bench replace the generic shopfront.
          for(const sx of [-w*.42,w*.42]){const pole=new THREE.Group();for(let i=0;i<12;i++){const band=new THREE.Mesh(new THREE.CylinderGeometry(.31,.31,.3,14),[themedRed,themedWhite,themedBlue][i%3]);band.position.y=i*.28;pole.add(band);}for(const y of [-.22,3.28]){const cap=new THREE.Mesh(new THREE.SphereGeometry(.39,14,9),themedGold);cap.position.y=y;pole.add(cap);}pole.position.set(x+sx,.6,front+.7);scene.add(pole);}add(x-w*.22,front+2.15,w*.44,.65,.62,wood,.31);for(const sx of [-w*.4,-w*.04])add(x+sx,front+2.15,.16,.62,.9,metal,.45);for(const sx of [-.58,.58]){const ring=cylinder(new THREE.TorusGeometry(.43,.11,8,20),themedGold,x+sx,h+2.5,z,0,0,0);ring.scale.y=1.3;}for(const s of [-1,1]){const blade=add(x+s*.78,z,.16,.22,2.5,themedGold,h+1.4);blade.rotation.z=s*.55;}sign('ENZO BARBER','#f5efe3',h+4.3,.88);
        }else if(kind==='pizza'){
          // Street tables, an oven mouth and a roof pizza sign sell the restaurant before text is readable.
          const oven=add(x,front+.24,w*.36,.24,3.05,themedBrick,1.53),mouth=cylinder(new THREE.TorusGeometry(1.18,.22,10,24,Math.PI),black,x,1.45,front+.39,0,0,Math.PI);mouth.castShadow=false;const fire=cylinder(new THREE.CircleGeometry(.72,18),redGlow,x,.83,front+.41);fire.castShadow=false;for(const sx of [-w*.35,w*.35]){const table=cylinder(new THREE.CylinderGeometry(.72,.72,.15,20),wood,x+sx,.82,front+2.2);cylinder(new THREE.CylinderGeometry(.08,.11,.72,8),metal,x+sx,.4,front+2.2);}for(let i=-2;i<=2;i++)add(x+i*w*.13,front+1.05,w*.12,1.5,.18,i%2?themedWhite:themedRed,3.45);const pizza=cylinder(new THREE.CylinderGeometry(1.7,1.7,.25,28),pizzaCheese,x,h+2.2,z,Math.PI/2,0,0);for(let i=0;i<7;i++){const a=i/7*Math.PI*2;cylinder(new THREE.CylinderGeometry(.2,.2,.08,12),pizzaPepper,x+Math.cos(a)*1.05,h+2.2+Math.sin(a)*1.05,z+.18,Math.PI/2,0,0);}sign('TONYS PIZZA','#ffd56c',h+4.6,.92);
        }else if(kind==='garage'){
          // The roof tyre is deliberately oversized: this must read as tyre service from the city camera.
          add(x,front+2.2,w*.92,4.2,.2,hazard,.1);for(const sx of [-w*.43,w*.43]){add(x+sx,front+2.2,.28,4.2,2.4,hazard,1.2);for(let i=0;i<4;i++){const tire=cylinder(new THREE.TorusGeometry(.52,.18,9,20),rubber,x+sx,.3+i*.38,front+3);tire.rotation.x=Math.PI/2;}}const roofTyre=cylinder(new THREE.TorusGeometry(2.65,.82,14,34),rubber,x,h+2.9,z,0,0,0),rim=cylinder(new THREE.CylinderGeometry(1.45,1.45,.34,24),metal,x,h+2.9,z,Math.PI/2,0,0);for(let k=0;k<6;k++){const a=k*Math.PI/3,spoke=add(x,z,.16,.34,1.25,themedWhite,h+2.9);spoke.rotation.z=a;}for(const sx of [-w*.3,0,w*.3]){add(x+sx,front+.28,w*.22,.22,3.65,black,1.83);for(let y=.55;y<3.45;y+=.55)add(x+sx,front+.42,w*.2,.07,.055,themedWhite,y);}sign('ШИНОМОНТАЖ','#ffd54a',h+6.25,1.08);renderer.domElement.dataset.garageRoofSign='giant-tyre-service';
          for(let spark=0;spark<7;spark++){const ember=cylinder(new THREE.SphereGeometry(.055,7,5),warm,x+w*.27,.55,front+2.45);ember.castShadow=false;businessExteriorFx.push({kind:'garage-spark',mesh:ember,phase:spark/7,baseX:x+w*.27,baseZ:front+2.45});}
        }else if(kind==='bar'){
          // Noir alley bar: barrel tables, fire escape and a bottle-shaped roof beacon.
          for(const sx of [-w*.36,w*.36]){const barrel=cylinder(new THREE.CylinderGeometry(.58,.68,1.1,16),wood,x+sx,.55,front+2.15);for(const y of [.18,.55,.92])cylinder(new THREE.TorusGeometry(.62,.045,6,18),metal,x+sx,y,front+2.15,Math.PI/2,0,0);}for(let y=3.3;y<h-1;y+=1.65){add(x-w*.48,z,1.4,d*.46,.14,metal,y);for(const dz of [-d*.18,d*.18])add(x-w*.56,z+dz,.08,.08,1.05,metal,y+.45);}const bottleBody=cylinder(new THREE.CylinderGeometry(.72,.92,2.6,18),green,x,h+2.25,z),bottleNeck=cylinder(new THREE.CylinderGeometry(.28,.42,1.15,14),green,x,h+4,z);add(x,front+.94,w*.7,1.7,.24,pink,3.7);sign('BLACK WIDOW','#ff5ead',h+5.35,.95);
          businessExteriorFx.push({kind:'bar-neon',material:pink,phase:seed});
        }else if(kind==='club'){
          // A rooftop equalizer and a real VIP lane distinguish the club from the bar at any zoom.
          add(x,front+4.3,w*.62,7.2,.15,new THREE.MeshStandardMaterial({color:0x771d3b,roughness:.72}),.08);const vipRopeMaterial=new THREE.MeshStandardMaterial({color:0x9b1d32,roughness:.7});for(const sx of [-w*.28,w*.28])for(let k=0;k<3;k++){cylinder(new THREE.CylinderGeometry(.07,.09,1.25,9),themedGold,x+sx,.63,front+2.2+k*1.65);cylinder(new THREE.SphereGeometry(.12,10,7),themedGold,x+sx,1.28,front+2.2+k*1.65);if(sx<0)add(x,front+2.2+k*1.65,w*.56,.06,.08,vipRopeMaterial,.92);}for(let i=0;i<11;i++){const bh=1.1+((i*7+seed)%5)*.72,mat=[pink,cyan,warm][i%3];add(x-w*.42+i*w*.084,z,.42,.42,bh,mat,h+bh/2+.25);}renderer.domElement.dataset.clubExteriorLighting='emissive-no-runtime-spots';sign('SOTTO CLUB','#f56dff',h+6.1,1);
          for(let i=0;i<9;i++){const meter=add(x-w*.34+i*w*.085,front+.5,.32,.18,.4+i%4*.28,[pink,cyan,warm][i%3],h+.5);businessExteriorFx.push({kind:'club-meter',mesh:meter,phase:i/9,baseY:meter.position.y});}
        }else if(kind==='warehouse'){
          // Loading ramp, stacked cargo and a forklift give the long shed a working logistics yard.
          add(x,front+3.1,w*.9,5.6,.22,metal,.11);for(const sx of [-w*.42,w*.42])add(x+sx,front+3.1,.22,5.6,.75,hazard,.38);for(let i=0;i<8;i++){const col=i%4,row=Math.floor(i/4),crate=add(x-w*.32+col*w*.21,front+2.2+row*1.05,1.65,1.65,1.25,crateMat,.63);crate.rotation.y=(i%3-1)*.06;}const forkX=x+w*.28;add(forkX,front+3.2,2.5,1.7,1.15,hazard,.58);for(const sx of [-.82,.82])cylinder(new THREE.CylinderGeometry(.34,.34,.32,14),rubber,forkX+sx,.34,front+3.65,0,0,Math.PI/2);for(const sx of [.82,1.02]){add(forkX+sx,front+2.55,.12,.12,2.8,metal,1.4);add(forkX+sx,front+1.9,.12,1.4,.1,metal,.18);}for(const sx of [-w*.36,0,w*.36]){const lamp=add(x+sx,front+.45,.6,.16,.22,warm,4.1);lamp.castShadow=false;}sign('CARLO LOGISTICS','#ffc35f',h+3.4,.92);
          const beacon=cylinder(new THREE.SphereGeometry(.16,10,7),redGlow,forkX,2.08,front+3.2);beacon.castShadow=false;businessExteriorFx.push({kind:'forklift-beacon',mesh:beacon,phase:seed});
        }else if(kind==='casino'){
          // Art-deco tower, giant dice and a bulb marquee link the small casino to the GRAND CASINO language.
          add(x,front+3.5,w*.72,5.8,.16,new THREE.MeshStandardMaterial({color:0x8e1734,roughness:.76}),.08);for(const sx of [-w*.28,w*.14,w*.28])add(x+sx,front+.3,.2,.32,Math.max(4,h*.68),themedGold,Math.max(4,h*.68)/2+1.1);for(let tier=0;tier<3;tier++)add(x,z,w*(.5-tier*.1),d*(.5-tier*.1),.45,themedGold,h+.25+tier*.48);const die=cylinder(new THREE.BoxGeometry(2.8,2.8,2.8),themedWhite,x,h+3.15,z,0,.35,.12);for(const [dx,dy] of [[-.7,-.7],[.7,-.7],[0,0],[-.7,.7],[.7,.7]]){const pip=cylinder(new THREE.SphereGeometry(.18,10,7),black,x+dx,h+3.15+dy,z+1.46);pip.castShadow=false;}add(x,front+1.1,w*.72,2.1,.34,themedGold,4.1);for(let i=0;i<13;i++){const sx=x-w*.32+i*w*.64/12,bulb=cylinder(new THREE.SphereGeometry(.1,9,6),i%2?warm:redGlow,sx,3.92,front+2.18);bulb.castShadow=false;}for(const sx of [-w*.31,w*.31]){const post=cylinder(new THREE.CylinderGeometry(.07,.1,1.15,9),themedGold,x+sx,.58,front+2.2);cylinder(new THREE.SphereGeometry(.12,9,6),themedGold,x+sx,1.18,front+2.2);}sign('GOLDEN DICE','#ffe06c',h+5.55,1.04);
        }else if(kind==='port'){
          // Private dock office with crane, containers, anchor and navigation lamps.
          for(const [sx,col] of [[-w*.33,themedRed],[-w*.08,themedBlue]]){add(x+sx,front+2.3,w*.24,2.45,2.35,col,1.18);for(let i=-2;i<=2;i++)add(x+sx+i*w*.022,front+2.3,.06,2.5,2.1,black,1.18);}const craneX=x+w*.28;add(craneX,z,.32,.32,8,metal,h+4);const boom=add(craneX-w*.08,z-d*.05,w*.62,.28,.28,hazard,h+7.8);boom.rotation.z=.04;const cable=cylinder(new THREE.CylinderGeometry(.035,.035,5.4,7),metal,craneX+w*.18,h+5.05,z-d*.05);const hook=cylinder(new THREE.TorusGeometry(.34,.08,7,16,Math.PI*1.4),metal,craneX+w*.18,h+2.25,z-d*.05,0,0,.25);for(const sx of [-w*.43,w*.43]){const lamp=cylinder(new THREE.SphereGeometry(.18,10,7),sx<0?redGlow:cyan,x+sx,h+1.4,z);lamp.castShadow=false;}const anchor=new THREE.Group(),ring=new THREE.Mesh(new THREE.TorusGeometry(.38,.1,8,18),themedWhite),stem=new THREE.Mesh(new THREE.CylinderGeometry(.09,.09,2.25,8),themedWhite),bar=new THREE.Mesh(new THREE.BoxGeometry(1.55,.13,.13),themedWhite),arms=new THREE.Mesh(new THREE.TorusGeometry(.8,.1,8,18,Math.PI),themedWhite);ring.position.y=1.15;stem.position.y=.05;bar.position.y=.55;arms.position.y=-.75;arms.rotation.z=Math.PI;anchor.add(ring,stem,bar,arms);anchor.position.set(x,h+2.2,front+.35);scene.add(anchor);sign('RIZZO DOCKS','#9deaff',h+4.65,.96);
        }
        renderer.domElement.dataset.businessExteriorIdentity='authored-v3-roof-mounted-signs';
      };
      const identityStone=new THREE.MeshStandardMaterial({color:0x8b9294,roughness:.72,metalness:.16}),identityDark=new THREE.MeshStandardMaterial({color:0x26313a,roughness:.48,metalness:.58}),identityWood=new THREE.MeshStandardMaterial({color:0x70452d,roughness:.66,metalness:.08}),identityGlass=new THREE.MeshPhysicalMaterial({color:0x72bad0,roughness:.1,metalness:.08,transmission:.1,clearcoat:1,envMap:cityEnvironment,envMapIntensity:1.2}),identityGlow=new THREE.MeshBasicMaterial({color:0xffd27a,toneMapped:false}),identityAccents=[0xb75a45,0x3f8099,0xb28a43,0x4b8465,0x76568d].map(color=>new THREE.MeshStandardMaterial({color,roughness:.48,metalness:.24}));
      const addProceduralBuildingIdentity=(x,z,w,d,h,seed,districtStyle,familyId='concrete')=>{
        const familyVariants={glass:[3,5],brick:[0,2],limestone:[4,1],concrete:[5,4],deco:[1,4],industrial:[2,5]},variantPool=familyVariants[familyId]||[0,5],front=z+d/2+.11,accent=identityAccents[(seed+variantPool.length)%identityAccents.length],variant=variantPool[(seed>>>3)%variantPool.length],floors=Math.max(1,Math.floor((h-4)/3.4)),add=(xx,zz,ww,dd,hh,mat,yy=hh/2)=>{const q=box(xx,zz,ww,dd,hh,mat);q.position.y=yy;return q;};
        // Every ordinary building receives a readable entrance, address light
        // and cornice before its individual architectural variant is applied.
        add(x,front+.13,Math.min(3.1,w*.27),.2,3.2,identityGlass,1.6);add(x,front+.27,.1,.24,3.05,identityDark,1.58);
        for(const sx of [-1,1])add(x+sx*Math.min(2,w*.18),front+.22,.24,.3,3.65,identityStone,1.83);
        const canopy=add(x,front+.78,Math.min(5.1,w*.46),1.35,.22,accent,3.65);canopy.rotation.x=-.09;
        const addressLamp=add(x+Math.min(2.6,w*.24),front+.34,.62,.1,.3,identityGlow,3.05);addressLamp.castShadow=false;
        add(x,z,w+.82,d+.82,.32,accent,h-.55);add(x,z,w+.48,d+.48,.24,identityStone,Math.max(4.1,h*.48));
        // The first floor carries the same architectural language as the
        // facade, so the difference remains obvious at street-camera height.
        if(familyId==='glass'){
          add(x,front+.07,w*.76,.16,3.3,identityGlass,1.65);
          for(const sx of [-.36,-.12,.12,.36])add(x+sx*w,front+.18,.11,.2,3.55,identityDark,1.78);
        }else if(familyId==='brick'){
          add(x,front+.08,w*.86,.24,.68,identityStone,.34);
          for(const sx of [-w*.38,w*.38])add(x+sx,front+.13,w*.13,.24,3.05,identityDark,1.53);
        }else if(familyId==='limestone'){
          for(const sx of [-w*.33,-w*.17,w*.17,w*.33])add(x+sx,front+.2,.28,.3,3.9,identityStone,1.95);
          add(x,front+.42,w*.78,.74,.24,accent,4.02);
        }else if(familyId==='concrete'){
          add(x,front+.08,w*.82,.22,2.9,identityDark,1.45);
          for(const sx of [-w*.31,0,w*.31])add(x+sx,front+.2,w*.18,.12,2.18,identityGlass,1.42);
        }else if(familyId==='deco'){
          for(const sx of [-w*.29,w*.29])add(x+sx,front+.2,.32,.3,4.55,accent,2.28);
          add(x,front+.36,w*.62,.55,.22,identityStone,4.38);
        }else if(familyId==='industrial'){
          add(x,front+.08,w*.58,.24,3.25,identityDark,1.63);
          for(let y=.55;y<3.1;y+=.55)add(x,front+.22,w*.52,.08,.08,identityStone,y);
        }
        if(variant===0){
          // Deep stacked balconies with railings.
          for(let floor=0;floor<Math.min(4,floors);floor++){const y=5.1+floor*3.35,b=add(x,front+.55,w*.62,1.05,.18,identityStone,y);for(let k=-2;k<=2;k++)add(x+k*w*.11,front+1.02,.07,.08,.72,identityDark,y+.39);}
        }else if(variant===1){
          // Tall art-deco fins and a stepped crown.
          for(const sx of [-.31,-.1,.1,.31])add(x+sx*w,front+.2,.18,.28,Math.max(4,h-3),sx<0?accent:identityStone,(Math.max(4,h-3))/2+2.4);
          add(x,z,w*.72,d*.72,.55,accent,h+.28);add(x,z,w*.46,d*.46,.42,identityStone,h+.76);
        }else if(variant===2){
          // Side fire escape gives older blocks a strong silhouette.
          const side=x+w/2+.42;for(let floor=0;floor<Math.min(4,floors);floor++){const y=4.6+floor*3.3;add(side,z+d*.08,1.05,d*.42,.13,identityDark,y);for(const sz of [-.16,.16])add(side+.45,z+sz*d,.08,.08,.82,identityDark,y+.43);}for(let y=3.4;y<Math.min(h-1,16);y+=1.15){const rung=add(side+.48,z-d*.2,.08,1.45,.07,identityDark,y);rung.rotation.z=.03;}
        }else if(variant===3){
          // Projecting glass bay and contrasting vertical spine.
          add(x,front+.5,w*.38,.92,Math.max(4,h-4),identityGlass,Math.max(4,h-4)/2+2.1);add(x-w*.25,front+.23,.38,.3,Math.max(4,h-3),accent,Math.max(4,h-3)/2+2.2);for(let y=5;y<h-1;y+=3.4)add(x,front+1,w*.44,1.12,.16,identityStone,y);
        }else if(variant===4){
          // Classical pilasters and repeated stone belt courses.
          for(const sx of [-.4,-.2,.2,.4])add(x+sx*w,front+.2,.3,.35,Math.max(4,h-2.5),identityStone,Math.max(4,h-2.5)/2+1.7);for(let y=5.1;y<h-1&&y<18;y+=3.5)add(x,front+.26,w*.9,.35,.2,accent,y);
        }else{
          // Modern roof garden/pergola and asymmetrical facade frame.
          const terrace=add(x,z,w*.68,d*.62,.34,identityStone,h+.17);for(const sx of [-.27,.27])for(const sz of [-.22,.22])add(x+sx*w,z+sz*d,.16,.16,2.2,identityWood,h+1.25);for(let k=-2;k<=2;k++)add(x+k*w*.11,z,d*.58,.1,.12,identityWood,h+2.3);add(x+w*.28,front+.25,w*.18,.28,Math.max(4,h*.62),accent,Math.max(4,h*.62)/2+1.8);terrace.castShadow=true;
        }
        if(districtStyle==='industrial'){add(x-w*.28,z-d*.18,1.15,1.15,2.4,identityDark,h+1.2);}
      };
      const STATIC_DETAIL_CHUNK_WORLD=80;
      const staticDetailBuckets=new Map();
      const deferredRevealRoots=[];
      const buildingIdentitySignatures=new Set();
      const buildingArchitectureFamilyCounts=new Map();
      const queueStaticBuildingDetail=mesh=>{
        if(!mesh?.isMesh||Array.isArray(mesh.material)||mesh.userData?.building||mesh.userData?.mainBuilding)return;
        // Small facade details remain visible and receive the main building
        // shadow, but do not each trigger another expensive shadow draw.
        mesh.castShadow=false;
        const geometry=mesh.geometry,attributes=geometry?.attributes||{},attributeNames=Object.keys(attributes);
        // The merge copies exact transformed vertices, so cylinders, planes,
        // rings and other authored static details are just as safe as boxes.
        // Keep unusual/animated buffer layouts separate: dropping one of their
        // custom attributes could alter a shader even when the mesh looks static.
        if(!geometry?.isBufferGeometry||geometry.isInstancedBufferGeometry||mesh.isSkinnedMesh||mesh.material?.transparent||mesh.material?.skinning||mesh.material?.vertexColors||Object.hasOwn(mesh,'onBeforeRender')||mesh.customDepthMaterial||mesh.customDistanceMaterial||attributeNames.some(name=>!['position','normal','uv'].includes(name))||!attributes.position||!attributes.normal||!attributes.uv||Object.keys(geometry.morphAttributes||{}).length)return;
        // A material-wide city batch kept perfect visuals but defeated frustum
        // culling: one visible roof detail submitted every matching detail in
        // the loaded sector. Spatial batches preserve the exact same geometry
        // and material while giving Three.js useful per-chunk bounds.
        const chunkX=Math.floor(mesh.position.x/STATIC_DETAIL_CHUNK_WORLD),chunkZ=Math.floor(mesh.position.z/STATIC_DETAIL_CHUNK_WORLD);
        const sectorR=Math.floor((originR+mesh.position.z/WORLD_SCALE)/STREAM_SECTOR_SIZE),sectorC=Math.floor((originC+mesh.position.x/WORLD_SCALE)/STREAM_SECTOR_SIZE);
        const layout=attributeNames.sort().map(name=>`${name}:${attributes[name].itemSize}:${attributes[name].normalized?1:0}:${attributes[name].array.constructor.name}`).join(',');
        const key=`${mesh.material.uuid}:${layout}:${sectorR}:${sectorC}:${chunkX}:${chunkZ}`;
        if(!staticDetailBuckets.has(key))staticDetailBuckets.set(key,{material:mesh.material,meshes:[]});
        staticDetailBuckets.get(key).meshes.push(mesh);
      };
      const createBuilding=(definition,bi)=>{
        const [x,z,w,d,rawH,style,sign,districtStyle='downtown',sourceMeta]=definition,buildingMeta=sourceMeta||{r:originR+z/WORLD_SCALE,c:originC+x/WORLD_SCALE,w:w/WORLD_SCALE,d:d/WORLD_SCALE},architecturalKind=buildingMeta.architecturalKind||null,h=architecturalHeights[architecturalKind]||rawH,buildingSeed=(Math.imul(Math.round((buildingMeta.r??z/WORLD_SCALE)*97),73856093)^Math.imul(Math.round((buildingMeta.c??x/WORLD_SCALE)*97),19349663)^Math.imul(Math.round(w*10),83492791)^Math.imul(Math.round(d*10),2654435761))>>>0,architectureFamily=architectureFamilyFor(districtStyle,buildingSeed,h);
        buildingIdentitySignatures.add(`${districtStyle}:${architecturalKind||architectureFamily.id}:${style}:${buildingSeed%3}:${(buildingSeed>>>3)%6}:${(buildingSeed>>>5)%6}:${Math.round(w*10)}:${Math.round(d*10)}:${Math.round(h*10)}`);
        renderer.domElement.dataset.buildingIdentitySignatures=String(buildingIdentitySignatures.size);
        if(!architecturalKind){buildingArchitectureFamilyCounts.set(architectureFamily.id,(buildingArchitectureFamilyCounts.get(architectureFamily.id)||0)+1);renderer.domElement.dataset.buildingArchitectureFamilies=[...buildingArchitectureFamilyCounts].map(([id,count])=>`${id}:${count}`).join(',');}
        buildingCurbDefs.push([x,z,w+2,d+2]);
        if(bi>=initialBuildingCount){const streamedCurb=box(x,z,w+2,d+2,.65,curbMat);streamedCurb.position.y=.325;const streamedShadow=makeContactShadow(w*1.08,d*1.08,contactShadowMaterial);streamedShadow.position.set(x,.058,z);scene.add(streamedShadow);}
        const familyFacades=architectureFacadeTextures.get(architectureFamily.id)||architectureFacadeTextures.get('concrete'),facade=familyFacades[buildingSeed%familyFacades.length].clone();facade.repeat.set(Math.max(1,w/24),Math.max(1.35,h/16));facade.needsUpdate=true;
        const wall = new THREE.MeshStandardMaterial({map:facade,bumpMap:facade,bumpScale:architectureFamily.bump,roughness:architectureFamily.roughness,metalness:architectureFamily.metalness,envMap:cityEnvironment,envMapIntensity:architectureFamily.env,emissive:architectureFamily.id==='glass'?0x8dd8ef:0xffb24c,emissiveMap:facade,emissiveIntensity:architectureFamily.id==='glass'?.105:.075});
        wall.userData.mfzOcclusionOpacity=.52;
        facadeMaterials.push(wall);
        const localRoof=roofMat.clone();localRoof.color.setHex(architectureFamily.roof);localRoof.userData.mfzOcclusionOpacity=.28;
        if(architecturalKind){const palette={hospital:0xdfe7e5,hospital_east:0xdfe7e5,police:0xaeb8bd,mafia_hq:0x20364b,mansion:0xd0c6ad,pizza:0xc96b43,coffee:0x8f553b,carwash:0x5496ab,barbershop:0xd6d2c8,garage:0x596872,firestation:0xd7d4ca,warehouse:0x667177,port:0x59666d,bar:0x4a2934,club:0x332c4d,casino:0x5a3b52,market:0x98734a,factory:0x655b54,gym:0x556d82,job_office:0x84745b,blackmarket:0x211c23,blackmarket_bellini:0x29251d,blackmarket_moretti:0x281d20}[architecturalKind];if(palette)wall.color.setHex(palette);wall.emissiveIntensity=['bar','club','casino','mafia_hq','blackmarket','blackmarket_bellini','blackmarket_moretti'].includes(architecturalKind)?.18:.035;}
        // Keep every visible facade at full fidelity, but do not construct
        // balconies, roof HVAC, railings and signs for blocks well beyond the
        // orthographic camera. Their main textured mass and silhouette remain,
        // so approaching them is seamless after the next sector stream.
        const detailDistanceTiles=Math.hypot(x/WORLD_SCALE,z/WORLD_SCALE);
        const detailRadius=Math.max(20,Math.min(WORLD_SNAPSHOT_RADIUS,+rendererConfig.detailRadius||24));
        const detailed=buildingMeta.primary!==false&&detailDistanceTiles<=detailRadius,steppedTower=detailed&&!architecturalKind&&(districtStyle==='downtown'||districtStyle==='rich'||districtStyle==='chinatown_rich')&&h>24,lowerH=steppedTower?h*.64:h;
        const mainBuilding=buildingBox(x,z,w,d,lowerH,wall,localRoof);mainBuilding.userData.fadeMaterials=[wall,localRoof];mainBuilding.userData.building=buildingMeta;mainBuilding.userData.mainBuilding=true;occluders.push(mainBuilding);buildingPickables.push(mainBuilding);if(detailed)outline(mainBuilding);
        const detailSceneStart=scene.children.length;
        if(detailed){if(steppedTower){const upperH=h-lowerH,upper=buildingBox(x,z,w*.72,d*.72,upperH,wall,localRoof);upper.position.y=lowerH+upperH/2;upper.userData.fadeMaterials=[wall,localRoof];upper.userData.building=buildingMeta;occluders.push(upper);buildingPickables.push(upper);outline(upper);const crownBand=box(x,z,w*.78,d*.78,.42,neonMats[buildingSeed%3]);crownBand.position.y=lowerH+.2;}
        // A second mass breaks the repetitive box silhouette.
        if(districtStyle==='downtown'){
          wall.metalness=.22;wall.roughness=.48;
          if(h>24){const crown=box(x,z,w*.58,d*.58,4.2,glassMat);crown.position.y=h+2.1;outline(crown);const mast=new THREE.Mesh(new THREE.CylinderGeometry(.12,.2,5.5,8),detailMat);mast.position.set(x,h+6.8,z);scene.add(mast);}
        }
        if(districtStyle==='nightlife'){
          for(let y=4;y<h;y+=4){const band=box(x,z+d/2+.04,w*.9,.12,.12,neonMats[(buildingSeed+y)%3]);band.position.y=y;}
        }
        if(districtStyle==='industrial'){
          for(let sx=-w*.25;sx<=w*.25;sx+=Math.max(2,w*.25)){const vent=new THREE.Mesh(new THREE.CylinderGeometry(.32,.45,2.5,8),detailMat);vent.position.set(x+sx,h+1.25,z);scene.add(vent);}
        }
        if(districtStyle==='rich'){
          const terrace=box(x,z,w*.72,d*.72,2.4,wall);terrace.position.y=h+1.2;outline(terrace);
        }
        if(districtStyle==='chinatown_poor'||districtStyle==='chinatown_docks'){wall.color.setHex(districtStyle==='chinatown_poor'?0x8b5a4b:0x5e4b43);wall.roughness=.9;}
        if(districtStyle==='chinatown_market'){wall.color.setHex(0x956347);wall.emissive.setHex(0x4b2112);wall.emissiveIntensity=.18;}
        if(districtStyle==='chinatown_neon'){wall.color.setHex(0x443554);wall.emissive.setHex(0x28123c);wall.emissiveIntensity=.32;wall.roughness=.48;}
        if(districtStyle==='chinatown_rich'){wall.color.setHex(0x416568);wall.metalness=.24;wall.roughness=.4;const terrace=box(x,z,w*.74,d*.74,2.1,wall);terrace.position.y=h+1.05;outline(terrace);}
        if(!architecturalKind){addDistrictCharacter(x,z,w,d,h,districtStyle,buildingSeed);addProceduralBuildingIdentity(x,z,w,d,h,buildingSeed,districtStyle,architectureFamily.id);}
        if(sign==='HOTEL'){const tower=box(x-2,z-1,w*.52,d*.58,5.5,wall);tower.position.y=h+2.75;outline(tower);}
        if(sign==='BANK'){const crown=box(x,z,w*.68,d*.7,3.3,wall);crown.position.y=h+1.65;outline(crown);}
        const roofVariantPools={glass:[2,4],brick:[0,3],limestone:[1,5],concrete:[1,4],deco:[2,1],industrial:[4,0]},roofPool=roofVariantPools[architectureFamily.id]||[0,5],roofVariant=roofPool[(buildingSeed>>>5)%roofPool.length];
        box(x,z,w+.65,d+.65,.48,detailMat).position.y=h-.24;if(architecturalKind)addThemedArchitecture(architecturalKind,x,z,w,d,h,buildingSeed);else if(districtStyle==='chinatown_rich'||districtStyle==='chinatown_market'||districtStyle==='chinatown_neon')addChinatownRoof(x,z,w,d,h,buildingSeed);else addRoofDetails(x,z,w,d,h,roofVariant);
        if(!String(architecturalKind||'').startsWith('blackmarket')){const shopGlow=new THREE.MeshBasicMaterial({color:sign==='CLUB'?0xff397d:sign==='CAFE'?0xffa13b:0xffd38a});shopMaterials.push(shopGlow);const shop=new THREE.Mesh(new THREE.PlaneGeometry(Math.min(w-2,8),2.8),shopGlow);shop.position.set(x,2.25,z+d/2+.012);scene.add(shop);}
        // Street-level identity: columns, awnings and window canopies.
        if(sign==='BANK')for(let sx=-3;sx<=3;sx+=2){const col=new THREE.Mesh(new THREE.CylinderGeometry(.25,.32,3.7,10),detailMat);col.position.set(x+sx,2.2,z+d/2+.45);col.castShadow=true;scene.add(col);}
        if(sign==='CAFE'||sign==='DELI'){const awning=box(x,z+d/2+.75,Math.min(8,w-1),1.5,.24,new THREE.MeshStandardMaterial({color:sign==='CAFE'?0xe85f43:0x58b8a2,roughness:.5}));awning.position.y=3.65;awning.rotation.x=-.16;}
        if(sign==='CLUB'){const canopy=box(x,z+d/2+1.15,8,2.2,.3,neonMats[0]);canopy.position.y=3.5;}
        if(sign==='HOTEL')for(let floor=6;floor<h-1;floor+=3.2){const balcony=box(x,z+d/2+.5,w*.62,.8,.18,detailMat);balcony.position.y=floor;}
        if(sign){
          const signCv=document.createElement('canvas');signCv.width=512;signCv.height=128;const sc=signCv.getContext('2d');sc.fillStyle='#15131b';sc.fillRect(0,0,512,128);sc.strokeStyle=['#ff496f','#46d9ff','#ffc247'][style%3];sc.lineWidth=12;sc.strokeRect(8,8,496,112);sc.fillStyle='#fff2c6';sc.font='bold 68px sans-serif';sc.textAlign='center';sc.textBaseline='middle';sc.fillText(sign,256,68);
          const signTx=new THREE.CanvasTexture(signCv);signTx.colorSpace=THREE.SRGBColorSpace;signTx.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());const sm=new THREE.MeshBasicMaterial({map:signTx,transparent:false});const sgn=new THREE.Mesh(new THREE.PlaneGeometry(7.6,1.9),sm);sgn.position.set(x,h+2.15,z+d*.18);scene.add(sgn);
        }
        }
        for(const child of scene.children.slice(detailSceneStart))queueStaticBuildingDetail(child);
      };
      // Только здания непосредственно вокруг камеры нужны для первого кадра.
      // Остальной уже полученный сектор строится idle-пакетами после входа:
      // коллизии остаются авторитетными в world.html, геометрия и материалы
      // те же, но старт больше не блокируется десятками тяжёлых фасадов.
      const INITIAL_BUILDING_SYNC_CAP=12;
      const initialBuildingPlan=buildingDefs.map((definition,index)=>({definition,index,distance:Math.hypot(+definition[0]||0,+definition[1]||0)})).sort((a,b)=>a.distance-b.distance);
      const bootBuildingMaterials=[0x425c70,0x6b4d48,0x485f55,0x56536d].map(color=>new THREE.MeshBasicMaterial({color}));
      for(const {definition} of initialBuildingPlan.slice(0,INITIAL_BUILDING_SYNC_CAP)){
        const [x,z,w,d,rawH,style]=definition,h=Math.max(3.5,+rawH||8),proxy=new THREE.Mesh(new THREE.BoxGeometry(Math.max(1,w),h,Math.max(1,d)),bootBuildingMaterials[Math.abs(+style||0)%bootBuildingMaterials.length]);
        proxy.position.set(x,h*.5,z);bootScene.add(proxy);
      }
      const deferredInitialBuildings=[];
      initialBuildingPlan.forEach((entry,order)=>{
        if(order<INITIAL_BUILDING_SYNC_CAP)createBuilding(entry.definition,entry.index);
        else deferredInitialBuildings.push([entry.definition,initialBuildingCount+entry.index]);
      });
      const STATIC_DETAIL_MERGE_CAP=48;
      const pendingStaticDetailBatches=[];
      let batchedStaticDetailMeshes=0,batchedStaticDetailSources=0;
      const stageStaticDetailBuckets=()=>{
        for(const [key,{material,meshes}] of staticDetailBuckets){
          staticDetailBuckets.delete(key);
          if(meshes.length<3)continue;
          for(let offset=0;offset<meshes.length;offset+=STATIC_DETAIL_MERGE_CAP){
            const chunk=meshes.slice(offset,offset+STATIC_DETAIL_MERGE_CAP);
            if(chunk.length>=3)pendingStaticDetailBatches.push({material,meshes:chunk});
          }
        }
      };
      const mergeStaticDetailBatch=({material,meshes})=>{
        const geometries=[];
        for(const mesh of meshes){
          mesh.updateMatrixWorld(true);
          const geometry=mesh.geometry.index?mesh.geometry.toNonIndexed():mesh.geometry.clone();
          geometry.applyMatrix4(mesh.matrixWorld);
          geometries.push(geometry);
        }
        const attributes=['position','normal','uv'];
        if(!attributes.every(name=>geometries.every(g=>g.getAttribute(name)))){geometries.forEach(g=>g.dispose());return;}
        const merged=new THREE.BufferGeometry();
        for(const name of attributes){
          const source=geometries[0].getAttribute(name),total=geometries.reduce((sum,g)=>sum+g.getAttribute(name).array.length,0),ArrayType=source.array.constructor,values=new ArrayType(total);
          let offset=0;
          for(const geometry of geometries){const array=geometry.getAttribute(name).array;values.set(array,offset);offset+=array.length;}
          merged.setAttribute(name,new THREE.BufferAttribute(values,source.itemSize,source.normalized));
        }
        merged.computeBoundingBox();merged.computeBoundingSphere();
        const needsWarmup=meshes.some(mesh=>mesh.userData?.mfzDeferredReveal),targetParent=meshes[0]?.parent||scene;
        const batch=new THREE.Mesh(merged,material);batch.name='batched-static-building-detail';batch.castShadow=false;batch.receiveShadow=true;batch.visible=!needsWarmup;if(needsWarmup){batch.userData.mfzDeferredReveal=true;deferredRevealRoots.push(batch);}targetParent.add(batch);
        for(const mesh of meshes){mesh.parent?.remove(mesh);mesh.geometry.dispose();}
        geometries.forEach(geometry=>geometry.dispose());
        batchedStaticDetailMeshes++;batchedStaticDetailSources+=meshes.length;
      };
      const publishStaticDetailStats=()=>{
        renderer.domElement.dataset.batchedStaticDetailMeshes=String(batchedStaticDetailMeshes);
        renderer.domElement.dataset.batchedStaticDetailSources=String(batchedStaticDetailSources);
        renderer.domElement.dataset.pendingStaticDetailBatches=String(pendingStaticDetailBatches.length);
      };
      const flushStaticDetailBuckets=()=>{
        stageStaticDetailBuckets();
        while(pendingStaticDetailBatches.length)mergeStaticDetailBatch(pendingStaticDetailBatches.shift());
        publishStaticDetailStats();
      };
      flushStaticDetailBuckets();
      for(const detail of authoredLandmarkStaticDetails)queueStaticBuildingDetail(detail);
      flushStaticDetailBuckets();
      renderer.domElement.dataset.initialBuildingSync=`${Math.min(INITIAL_BUILDING_SYNC_CAP,buildingDefs.length)}/${buildingDefs.length}`;
      startupMark('initial-buildings');
      renderer.domElement.dataset.staticDetailChunkWorld=String(STATIC_DETAIL_CHUNK_WORLD);
      // Purchasable businesses are one-tile authored establishments in Canvas,
      // not ordinary block buildings. Build them at their exact authoritative
      // coordinates so labels, prompts, entrances and architecture agree.
      const businessExteriorSpecs={coffee:[9,8,8,0x704431,'#d89a55'],carwash:[12,9,5.8,0x386879,'#55d6e8'],barbershop:[9,8,8,0x735348,'#ef5261'],pizza:[10,9,7,0x8b392d,'#f3c044'],garage:[13,10,6.4,0x46525c,'#f0b72f'],bar:[11,9,8.5,0x351c28,'#ef4b9c'],club:[12,10,10,0x241632,'#a85cff'],warehouse:[15,12,7.2,0x56534b,'#e0a84a'],casino:[13,11,13,0x4c1828,'#ffd24b'],port:[16,12,7,0x40535d,'#ff9a3c']};
      const bounds=worldSnapshot?.bounds||{minR:-Infinity,maxR:Infinity,minC:-Infinity,maxC:Infinity};
      const businessStaticDetailStart=scene.children.length;
      for(const biz of worldSnapshot?.landmarks?.businesses||[]){if(biz.r<bounds.minR-3||biz.r>bounds.maxR+3||biz.c<bounds.minC-3||biz.c>bounds.maxC+3)continue;const spec=businessExteriorSpecs[biz.id];if(!spec)continue;const [w,d,h,color,accent]=spec,x=(biz.c-originC)*WORLD_SCALE,z=(biz.r-originR)*WORLD_SCALE,facade=facades[(Math.abs(Math.round(biz.r*7+biz.c*11))%facades.length)].clone();facade.repeat.set(Math.max(1,w/18),Math.max(1,h/10));const wall=new THREE.MeshStandardMaterial({color,map:facade,bumpMap:facade,bumpScale:.035,roughness:.62,metalness:.08,emissive:new THREE.Color(color).multiplyScalar(.18),emissiveIntensity:.18}),localRoof=roofMat.clone(),main=buildingBox(x,z,w,d,h,wall,localRoof),meta={r:+biz.r,c:+biz.c,w:w/WORLD_SCALE,d:d/WORLD_SCALE,minR:+biz.r-1,maxR:+biz.r+1,minC:+biz.c-1,maxC:+biz.c+1,primary:true,architecturalKind:biz.id,businessId:String(biz.id)};main.userData.fadeMaterials=[wall,localRoof];main.userData.building=meta;main.userData.mainBuilding=true;main.userData.businessId=String(biz.id);occluders.push(main);buildingPickables.push(main);outline(main);const businessSeed=Math.abs(Math.round(biz.r*37+biz.c*53));addThemedArchitecture(biz.id,x,z,w,d,h,businessSeed);addBusinessIdentityArchitecture(biz.id,x,z,w,d,h,businessSeed);const frontZ=z+d/2+.72,propertyLabel=roofMountedSign('СОБСТВЕННОСТЬ','#6ff0ad',Math.min(8.4,w*.66),1.05);propertyLabel.position.set(x,h+1.77,z+d*.22);propertyLabel.visible=!!biz.owned;scene.add(propertyLabel);const entranceGlow=new THREE.Mesh(new THREE.RingGeometry(1.05,1.48,32),new THREE.MeshBasicMaterial({color:accent,transparent:true,opacity:.92,side:THREE.DoubleSide,depthTest:false,toneMapped:false}));entranceGlow.rotation.x=-Math.PI/2;entranceGlow.position.set(x,.17,frontZ+1.05);entranceGlow.renderOrder=18;scene.add(entranceGlow);const doorway=new THREE.Mesh(new THREE.PlaneGeometry(Math.min(3.6,w*.32),3.7),new THREE.MeshPhysicalMaterial({color:0x73bad1,emissive:new THREE.Color(accent),emissiveIntensity:.18,roughness:.08,transmission:.16,clearcoat:1}));doorway.position.set(x,2,frontZ-.57);scene.add(doorway);businessExteriorById.set(String(biz.id),{main,entrance:new THREE.Vector3(x,.18,frontZ+1.05),propertyLabel,biz,x,z,w,d,h,owned:!!biz.owned});}
      const propertyFrameMaterial=new THREE.MeshBasicMaterial({color:0x6ff0ad,transparent:true,opacity:.94,depthTest:false,depthWrite:false,toneMapped:false}),propertyFrameBatch=new THREE.InstancedMesh(new THREE.BoxGeometry(1,.13,1),propertyFrameMaterial,Math.max(1,businessExteriorById.size*4)),propertyFrameMatrix=new THREE.Matrix4(),propertyFramePosition=new THREE.Vector3(),propertyFrameQuaternion=new THREE.Quaternion(),propertyFrameScale=new THREE.Vector3();propertyFrameBatch.instanceMatrix.setUsage(THREE.DynamicDrawUsage);propertyFrameBatch.renderOrder=50;propertyFrameBatch.frustumCulled=false;scene.add(propertyFrameBatch);let businessOwnershipSignature=null;
      const syncBusinessOwnership=ownership=>{const ownedIds=(ownership||[]).filter(q=>q?.owned).map(q=>String(q.id)).sort(),signature=ownedIds.join('|');if(signature===businessOwnershipSignature)return;businessOwnershipSignature=signature;const ownedSet=new Set(ownedIds);let index=0;for(const [id,entry] of businessExteriorById){const owned=ownedSet.has(id);entry.owned=owned;entry.main.userData.ownedByPlayer=owned;entry.propertyLabel.visible=owned;if(!owned)continue;const y=entry.h+.28,pad=.22;for(const [px,pz,sx,sz] of [[entry.x,entry.z-entry.d/2-pad,entry.w+.65,.24],[entry.x,entry.z+entry.d/2+pad,entry.w+.65,.24],[entry.x-entry.w/2-pad,entry.z,.24,entry.d+.65],[entry.x+entry.w/2+pad,entry.z,.24,entry.d+.65]]){propertyFrameMatrix.compose(propertyFramePosition.set(px,y,pz),propertyFrameQuaternion,propertyFrameScale.set(sx,1,sz));propertyFrameBatch.setMatrixAt(index++,propertyFrameMatrix);}}propertyFrameBatch.count=index;propertyFrameBatch.instanceMatrix.needsUpdate=true;renderer.domElement.dataset.businessPropertyMarkers=`${ownedIds.length}:authoritative-roof-sign-v328`;};
      syncBusinessOwnership(worldSnapshot?.landmarks?.businesses||[]);
      refreshBusinessOwnership=()=>syncBusinessOwnership(bridge?.getBusinessOwnership?.()||bridge?.getWorldSnapshot?.(90)?.landmarks?.businesses||[]);
      for(const detail of scene.children.slice(businessStaticDetailStart))queueStaticBuildingDetail(detail);
      flushStaticDetailBuckets();
      // Drive-through and loading businesses already have authored gates. Hide
      // only the legacy glass plane at the same anchor, never the gameplay marker.
      for(const id of ['garage','carwash','warehouse']){const entry=businessExteriorById.get(id);if(!entry)continue;const expectedZ=entry.entrance.z-1.62;for(const child of scene.children){if(!child.isMesh||child.geometry?.type!=='PlaneGeometry')continue;if(Math.abs(child.position.x-entry.entrance.x)<.04&&Math.abs(child.position.z-expectedZ)<.04&&Math.abs(child.position.y-2)<.04)child.visible=false;}}
      renderer.domElement.dataset.businessExteriorCoverage=`${businessExteriorById.size}/${Object.keys(businessExteriorSpecs).length}`;
      const neighborhoodSurfaceKeys=new Set(),neighborhoodSurfaceGroup=new THREE.Group();scene.add(neighborhoodSurfaceGroup);
      const neighborhoodConcreteMat=new THREE.MeshStandardMaterial({color:0x596168,roughness:.9,metalness:.04}),neighborhoodRoadMat=new THREE.MeshStandardMaterial({color:0xa4adb3,map:asphaltTexture,roughness:.86}),neighborhoodGrassMat=new THREE.MeshStandardMaterial({color:0x31543a,roughness:.98}),chinaOldPavingMat=new THREE.MeshStandardMaterial({color:0x594741,roughness:.96}),chinaMarketPavingMat=new THREE.MeshStandardMaterial({color:0x75533c,roughness:.9}),chinaRichPavingMat=new THREE.MeshStandardMaterial({color:0x536b68,roughness:.72,metalness:.08}),chinaDockPavingMat=new THREE.MeshStandardMaterial({color:0x4b4b49,roughness:.94});
      const addNeighborhoodSurfaces=snapshot=>{for(const n of snapshot?.neighborhoods||[]){const key=`${n.r0}:${n.c0}`;if(neighborhoodSurfaceKeys.has(key))continue;neighborhoodSurfaceKeys.add(key);const x=(n.c0+12-originC)*WORLD_SCALE,z=(n.r0+12-originR)*WORLD_SCALE,paving=n.styleId==='chinatown_poor'?chinaOldPavingMat:n.styleId==='chinatown_market'||n.styleId==='chinatown_neon'?chinaMarketPavingMat:n.styleId==='chinatown_rich'?chinaRichPavingMat:n.styleId==='chinatown_docks'?chinaDockPavingMat:neighborhoodConcreteMat,slab=new THREE.Mesh(new THREE.PlaneGeometry(16*WORLD_SCALE,16*WORLD_SCALE),paving);slab.rotation.x=-Math.PI/2;slab.position.set(x,.07,z);slab.receiveShadow=true;neighborhoodSurfaceGroup.add(slab);const stem=new THREE.Mesh(new THREE.PlaneGeometry((n.vertical?3:11)*WORLD_SCALE,(n.vertical?11:3)*WORLD_SCALE),neighborhoodRoadMat);stem.rotation.x=-Math.PI/2;stem.position.set((n.c0+(n.vertical?11:9)-originC)*WORLD_SCALE,.105,(n.r0+(n.vertical?9:11)-originR)*WORLD_SCALE);stem.receiveShadow=true;neighborhoodSurfaceGroup.add(stem);const bulb=new THREE.Mesh(new THREE.CircleGeometry(3.15*WORLD_SCALE,32),neighborhoodRoadMat);bulb.rotation.x=-Math.PI/2;bulb.position.set((n.c0+(n.vertical?11:14)-originC)*WORLD_SCALE,.11,(n.r0+(n.vertical?14:11)-originR)*WORLD_SCALE);neighborhoodSurfaceGroup.add(bulb);const yard=new THREE.Mesh(new THREE.PlaneGeometry((n.vertical?5:4)*WORLD_SCALE,(n.vertical?4:5)*WORLD_SCALE),n.styleId==='chinatown_rich'?chinaJadeMat:neighborhoodGrassMat);yard.rotation.x=-Math.PI/2;yard.position.set((n.c0+(n.vertical?11:17)-originC)*WORLD_SCALE,.12,(n.r0+(n.vertical?17:11)-originR)*WORLD_SCALE);yard.receiveShadow=true;neighborhoodSurfaceGroup.add(yard);}};
      addNeighborhoodSurfaces(worldSnapshot);
      // Every blocked decorative MAP tile must have a visible 3D object.
      // Canvas already drew these, but the previous 3D snapshot omitted them,
      // leaving invisible collisions (2 car, 3 crate, 4 barrel, 6 tree).
      const mapObstacleGroup=new THREE.Group();mapObstacleGroup.name='map-collision-visuals';scene.add(mapObstacleGroup);
      const obstacleWood=new THREE.MeshStandardMaterial({color:0x785235,roughness:.9}),obstacleWoodDark=new THREE.MeshStandardMaterial({color:0x3f2c21,roughness:.94}),obstacleMetal=new THREE.MeshStandardMaterial({color:0x66727a,metalness:.68,roughness:.38}),obstacleLeaf=windLeafMaterial(0x2c693f),obstacleCarColors=[0x9e3540,0x376991,0xb28b42,0x4e7b61];
      const MAP_OBSTACLE_INSTANCE_CAP=2048,obstacleMatrix=new THREE.Matrix4(),obstacleQuat=new THREE.Quaternion(),obstacleScale=new THREE.Vector3(),obstacleColor=new THREE.Color();
      const makeObstaclePool=(geometry,material,castShadow=true,receiveShadow=false)=>{const mesh=new THREE.InstancedMesh(geometry,material,MAP_OBSTACLE_INSTANCE_CAP);mesh.count=0;mesh.instanceMatrix.setUsage(THREE.StaticDrawUsage);mesh.frustumCulled=false;mesh.castShadow=castShadow;mesh.receiveShadow=receiveShadow;mapObstacleGroup.add(mesh);return mesh;};
      const obstaclePools={
        treeTrunk:makeObstaclePool(new THREE.CylinderGeometry(.32,.5,3.9,9),obstacleWoodDark),
        treeCrown:makeObstaclePool(new THREE.IcosahedronGeometry(1,1),obstacleLeaf),
        crate:makeObstaclePool(new THREE.BoxGeometry(2.15,1.65,2.05),obstacleWood,true,true),
        crateBand:makeObstaclePool(new THREE.BoxGeometry(2.23,.13,2.13),obstacleWoodDark,false),
        barrel:makeObstaclePool(new THREE.CylinderGeometry(.72,.78,1.75,14),obstacleMetal),
        barrelHoop:makeObstaclePool(new THREE.TorusGeometry(.75,.07,7,18),obstacleMetal,false),
        carBody:makeObstaclePool(new THREE.BoxGeometry(5.35,1.12,2.55),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.48,metalness:.32})),
        carRoof:makeObstaclePool(new THREE.BoxGeometry(2.72,.88,2.12),new THREE.MeshPhysicalMaterial({color:0x506b78,roughness:.12,metalness:.18,clearcoat:1})),
        carHood:makeObstaclePool(new THREE.BoxGeometry(1.48,.24,2.32),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.42,metalness:.36})),
        carWheel:makeObstaclePool(new THREE.BoxGeometry(.82,.72,.34),new THREE.MeshStandardMaterial({color:0x0b0d11,roughness:.9,metalness:.04}))
      };
      const addObstacleInstance=(mesh,x,y,z,rotationY=0,sx=1,sy=1,sz=1,color=null,rotationX=0)=>{const index=mesh.count;if(index>=MAP_OBSTACLE_INSTANCE_CAP)return;obstacleQuat.setFromEuler(new THREE.Euler(rotationX,rotationY,0));obstacleMatrix.compose(new THREE.Vector3(x,y,z),obstacleQuat,obstacleScale.set(sx,sy,sz));mesh.setMatrixAt(index,obstacleMatrix);if(color!==null)mesh.setColorAt(index,obstacleColor.setHex(color));mesh.count=index+1;mesh.instanceMatrix.needsUpdate=true;if(color!==null&&mesh.instanceColor)mesh.instanceColor.needsUpdate=true;};
      const mapObstacleKeys=new Set(),addMapCollisionVisuals=snapshot=>{for(const o of snapshot?.obstacles||[]){const key=`${o.type}:${o.r}:${o.c}`;if(mapObstacleKeys.has(key))continue;mapObstacleKeys.add(key);const x=(o.c-originC)*WORLD_SCALE,z=(o.r-originR)*WORLD_SCALE,seed=+o.seed||0;
        if(o.type===6){addObstacleInstance(obstaclePools.treeTrunk,x,1.95,z);for(const [dx,dy,dz,s] of [[0,4.7,0,1.65],[-.8,4.35,.25,1.25],[.75,4.45,-.2,1.35]])addObstacleInstance(obstaclePools.treeCrown,x+dx,dy,z+dz,0,s,s,s);}
        else if(o.type===3){const yaw=(seed%4)*Math.PI/2;addObstacleInstance(obstaclePools.crate,x,.83,z,yaw);for(const y of [.22,1.42])addObstacleInstance(obstaclePools.crateBand,x,y,z,yaw);}
        else if(o.type===4){addObstacleInstance(obstaclePools.barrel,x,.88,z);for(const y of [.25,1.5])addObstacleInstance(obstaclePools.barrelHoop,x,y,z,0,1,1,1,null,Math.PI/2);}
        else if(o.type===2){const yaw=(seed&1)?0:Math.PI/2,color=obstacleCarColors[seed%obstacleCarColors.length],cos=Math.cos(yaw),sin=Math.sin(yaw),place=(dx,dz)=>[x+cos*dx+sin*dz,z-sin*dx+cos*dz];addObstacleInstance(obstaclePools.carBody,x,.73,z,yaw,1,1,1,color);const [roofX,roofZ]=place(-.28,0),[hoodX,hoodZ]=place(1.83,0);addObstacleInstance(obstaclePools.carRoof,roofX,1.68,roofZ,yaw);addObstacleInstance(obstaclePools.carHood,hoodX,1.18,hoodZ,yaw,1,1,1,color);for(const dx of [-1.82,1.82])for(const dz of [-1.28,1.28]){const [wheelX,wheelZ]=place(dx,dz);addObstacleInstance(obstaclePools.carWheel,wheelX,.42,wheelZ,yaw);}}
      }renderer.domElement.dataset.mapCollisionVisuals=String(mapObstacleKeys.size);renderer.domElement.dataset.mapCollisionDrawCalls=String(Object.values(obstaclePools).filter(mesh=>mesh.count>0).length);};addMapCollisionVisuals(worldSnapshot);
      const buildingContactShadows=new THREE.InstancedMesh(new THREE.PlaneGeometry(1,1),contactShadowMaterial,buildingDefs.length),buildingShadowMatrix=new THREE.Matrix4(),buildingShadowQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0));
      buildingDefs.forEach(([x,z,w,d],i)=>{buildingShadowMatrix.compose(new THREE.Vector3(x,.058,z),buildingShadowQuat,new THREE.Vector3(w*1.08,d*1.08,1));buildingContactShadows.setMatrixAt(i,buildingShadowMatrix);});
      buildingContactShadows.instanceMatrix.needsUpdate=true;sealStaticInstanceBounds(buildingContactShadows);buildingContactShadows.renderOrder=3;scene.add(buildingContactShadows);
      if(buildingCurbDefs.length){const curbInstances=new THREE.InstancedMesh(new THREE.BoxGeometry(1,.65,1),curbMat,buildingCurbDefs.length),curbMatrix=new THREE.Matrix4();buildingCurbDefs.forEach(([x,z,w,d],i)=>{curbMatrix.compose(new THREE.Vector3(x,.325,z),new THREE.Quaternion(),new THREE.Vector3(w,1,d));curbInstances.setMatrixAt(i,curbMatrix);});curbInstances.instanceMatrix.needsUpdate=true;curbInstances.receiveShadow=true;sealStaticInstanceBounds(curbInstances);scene.add(curbInstances);}
      // Zebra crossings at the central intersection.
      const zebraMat=new THREE.MeshBasicMaterial({color:0xe8edf0});
      for(let i=-4;i<=4;i+=2){const a=new THREE.Mesh(new THREE.PlaneGeometry(1.1,4.6),zebraMat);a.rotation.x=-Math.PI/2;a.position.set(i,.055,-6.7);scene.add(a);const b=new THREE.Mesh(new THREE.PlaneGeometry(4.6,1.1),zebraMat);b.rotation.x=-Math.PI/2;b.position.set(6.7,.056,i);scene.add(b);}

      const lampMat = new THREE.MeshStandardMaterial({ color: 0x35434a, metalness: .82, roughness: .26 }),lampTrimMat=new THREE.MeshStandardMaterial({color:0x7a878d,metalness:.9,roughness:.2}),lampShadeMat=new THREE.MeshStandardMaterial({color:0x182127,metalness:.56,roughness:.4});
      const bulbMat = new THREE.MeshBasicMaterial({ color: 0x24292e, toneMapped:false });
      const streetLights=[];
      const fixedLampDefs=[],addLampDef=(r,c)=>{if(snapshotStyleAt(r+.5,c+.5)==='countryside')return;const probe=bridge?.collisionProbe?.(r+.5,c+.5);if(probe&&!probe.blocked&&probe.tile!==16)fixedLampDefs.push([(c-originC)*WORLD_SCALE,(r-originR)*WORLD_SCALE]);};for(let r=6;r<(envSnapshot?.mapRows||worldSnapshot?.bounds?.maxR||80)-2;r+=10)for(let c=3;c<(envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||200)-2;c+=10){addLampDef(r,c);if(c+14<(envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||200)-2)addLampDef(r,c+14);}
      const lampHeadGlowCanvas=document.createElement('canvas');lampHeadGlowCanvas.width=lampHeadGlowCanvas.height=96;const lampHeadGlowContext=lampHeadGlowCanvas.getContext('2d'),lampHeadGlowGradient=lampHeadGlowContext.createRadialGradient(48,48,3,48,48,47);lampHeadGlowGradient.addColorStop(0,'rgba(255,244,205,1)');lampHeadGlowGradient.addColorStop(.18,'rgba(255,205,119,.78)');lampHeadGlowGradient.addColorStop(.5,'rgba(255,166,70,.24)');lampHeadGlowGradient.addColorStop(1,'rgba(255,135,40,0)');lampHeadGlowContext.fillStyle=lampHeadGlowGradient;lampHeadGlowContext.fillRect(0,0,96,96);const lampHeadGlowTexture=new THREE.CanvasTexture(lampHeadGlowCanvas);lampHeadGlowTexture.colorSpace=THREE.SRGBColorSpace;lampHeadGlowTexture.generateMipmaps=false;const lampHeadGlowMat=new THREE.MeshBasicMaterial({map:lampHeadGlowTexture,color:0xffc36b,toneMapped:false,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),fixedLampHeadGlows=new THREE.InstancedMesh(new THREE.PlaneGeometry(2.6,2.6),lampHeadGlowMat,fixedLampDefs.length),fixedPostMatrices=new THREE.InstancedMesh(new THREE.CylinderGeometry(.15,.25,7.2,12),lampMat,fixedLampDefs.length),fixedLampBases=new THREE.InstancedMesh(new THREE.CylinderGeometry(.42,.5,.3,14),lampTrimMat,fixedLampDefs.length),fixedLampCollars=new THREE.InstancedMesh(new THREE.CylinderGeometry(.23,.23,.18,12),lampTrimMat,fixedLampDefs.length),fixedLampArms=new THREE.InstancedMesh(new THREE.BoxGeometry(2.25,.16,.16),lampMat,fixedLampDefs.length),fixedLampShades=new THREE.InstancedMesh(new THREE.CylinderGeometry(.42,.56,.34,12),lampShadeMat,fixedLampDefs.length),fixedBulbMatrices=new THREE.InstancedMesh(new THREE.SphereGeometry(.38,14,10),bulbMat,fixedLampDefs.length),fixedLampMatrix=new THREE.Matrix4(),fixedLampQuat=new THREE.Quaternion(),fixedLampScale=new THREE.Vector3(1,1,1),lampGlowFacingOffset=new THREE.Vector3(0,0,.22).applyQuaternion(camera.quaternion),fixedLampHeads=[];fixedLampDefs.forEach(([x,z],i)=>{const turn=(i%2)*Math.PI/2,dx=Math.cos(turn)*1.08,dz=-Math.sin(turn)*1.08,hx=x+dx*1.72,hz=z+dz*1.72;fixedLampHeads.push([hx,hz]);fixedLampMatrix.compose(new THREE.Vector3(x,3.6,z),fixedLampQuat.identity(),fixedLampScale);fixedPostMatrices.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.compose(new THREE.Vector3(x,.15,z),fixedLampQuat.identity(),fixedLampScale);fixedLampBases.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.compose(new THREE.Vector3(x,6.72,z),fixedLampQuat.identity(),fixedLampScale);fixedLampCollars.setMatrixAt(i,fixedLampMatrix);fixedLampQuat.setFromEuler(new THREE.Euler(0,turn,0));fixedLampMatrix.compose(new THREE.Vector3(x+dx*.82,6.82,z+dz*.82),fixedLampQuat,fixedLampScale);fixedLampArms.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.compose(new THREE.Vector3(hx,6.72,hz),fixedLampQuat.identity(),fixedLampScale);fixedLampShades.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.compose(new THREE.Vector3(hx,6.45,hz),fixedLampQuat.identity(),new THREE.Vector3(1,.7,1));fixedBulbMatrices.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.compose(new THREE.Vector3(hx+lampGlowFacingOffset.x,6.45+lampGlowFacingOffset.y,hz+lampGlowFacingOffset.z),camera.quaternion,fixedLampScale);fixedLampHeadGlows.setMatrixAt(i,fixedLampMatrix);});for(const mesh of [fixedPostMatrices,fixedLampBases,fixedLampCollars,fixedLampArms,fixedLampShades,fixedBulbMatrices,fixedLampHeadGlows]){mesh.instanceMatrix.needsUpdate=true;sealStaticInstanceBounds(mesh);mesh.castShadow=![fixedBulbMatrices,fixedLampHeadGlows].includes(mesh);mesh.receiveShadow=mesh.castShadow;if(mesh===fixedLampHeadGlows)mesh.renderOrder=19;scene.add(mesh);}
      const lampGlowCanvas=document.createElement('canvas');lampGlowCanvas.width=lampGlowCanvas.height=256;const lampGlowContext=lampGlowCanvas.getContext('2d'),lampGlowGradient=lampGlowContext.createRadialGradient(128,128,3,128,128,126);lampGlowGradient.addColorStop(0,'rgba(255,225,150,.72)');lampGlowGradient.addColorStop(.24,'rgba(255,194,92,.34)');lampGlowGradient.addColorStop(.62,'rgba(255,151,55,.1)');lampGlowGradient.addColorStop(1,'rgba(255,130,35,0)');lampGlowContext.fillStyle=lampGlowGradient;lampGlowContext.fillRect(0,0,256,256);const lampGlowTexture=new THREE.CanvasTexture(lampGlowCanvas);lampGlowTexture.colorSpace=THREE.SRGBColorSpace;lampGlowTexture.minFilter=THREE.LinearFilter;lampGlowTexture.magFilter=THREE.LinearFilter;lampGlowTexture.generateMipmaps=false;const lampGlowMat=new THREE.MeshBasicMaterial({map:lampGlowTexture,color:0xffd08a,transparent:true,opacity:.02,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),fixedLampGlows=new THREE.InstancedMesh(new THREE.PlaneGeometry(13,13),lampGlowMat,fixedLampHeads.length),lampGlowQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0)),lampGlowScale=new THREE.Vector3(1,1,1);fixedLampHeads.forEach(([x,z],i)=>{fixedLampMatrix.compose(new THREE.Vector3(x,.075,z),lampGlowQuat,lampGlowScale);fixedLampGlows.setMatrixAt(i,fixedLampMatrix);});fixedLampGlows.instanceMatrix.needsUpdate=true;fixedLampGlows.frustumCulled=false;fixedLampGlows.renderOrder=2;scene.add(fixedLampGlows);
      const lampSpots=[[-14,-7],[14,-7],[-14,7],[14,7]];
      lampSpots.forEach(([x,z],i) => {
        const light = new THREE.PointLight(0xffb45e, 0, 25, 2); light.position.set(x, 6.7, z); light.castShadow = false; scene.add(light);streetLights.push({light});
      });

      if(staticOutlineGeometries.length){
        const totalOutlineValues=staticOutlineGeometries.reduce((sum,g)=>sum+(g.getAttribute('position')?.array.length||0),0);
        const mergedOutlineGeometry=totalOutlineValues?new THREE.BufferGeometry():null;
        if(mergedOutlineGeometry){
          const mergedPositions=new Float32Array(totalOutlineValues);
          let mergedOffset=0;
          for(const g of staticOutlineGeometries){
            const values=g.getAttribute('position').array;
            mergedPositions.set(values,mergedOffset);
            mergedOffset+=values.length;
          }
          mergedOutlineGeometry.setAttribute('position',new THREE.BufferAttribute(mergedPositions,3));
          mergedOutlineGeometry.computeBoundingSphere();
        }
        if(mergedOutlineGeometry){
          const staticOutlines=new THREE.LineSegments(mergedOutlineGeometry,sharedOutlineMaterial);
          staticOutlines.name='batched-static-building-outlines';
          staticOutlines.castShadow=false;
          staticOutlines.receiveShadow=false;
          scene.add(staticOutlines);
          renderer.domElement.dataset.batchedOutlineGeometries=String(staticOutlineGeometries.length);
          renderer.domElement.dataset.outlineTransformProfile='parent-chain-world-matrix-v323';
        }
        staticOutlineGeometries.forEach(g=>g.dispose());
      }
      batchStaticOutlines=false;
      const player = new THREE.Group();
      const playerContactShadow=makeContactShadow(3.6,2.7);player.add(playerContactShadow);
      const suitMat=new THREE.MeshStandardMaterial({color:0x731f24,roughness:.58,emissive:0x1a0d10,emissiveIntensity:.48}),skinMat=new THREE.MeshStandardMaterial({color:0xd39b78,roughness:.7,emissive:0x211611,emissiveIntensity:.35}),darkMat=new THREE.MeshStandardMaterial({color:0x151922,roughness:.48,metalness:.25});
      const body = new THREE.Mesh(new THREE.CapsuleGeometry(.66,1.03,8,18),suitMat); body.position.y=2.65;body.castShadow=true;player.add(body);
      const armorRig=new THREE.Group(),armorFabricMat=new THREE.MeshStandardMaterial({color:0x34393d,roughness:.74,metalness:.12}),armorPlateMat=new THREE.MeshStandardMaterial({color:0x252c31,roughness:.34,metalness:.62}),armorAccentMat=new THREE.MeshStandardMaterial({color:0x89aab8,roughness:.3,metalness:.72,emissive:0x000000,emissiveIntensity:0}),armorWarnMat=new THREE.MeshBasicMaterial({color:0xff4f46,toneMapped:false});
      const armorPart=(geometry,material,x,y,z)=>{const mesh=new THREE.Mesh(geometry,material);mesh.position.set(x,y,z);mesh.castShadow=true;armorRig.add(mesh);return mesh;};
      const armorFront=armorPart(new THREE.BoxGeometry(1.82,1.72,.19),armorFabricMat,0,.02,.62),armorBack=armorPart(new THREE.BoxGeometry(1.76,1.62,.16),armorFabricMat,0,.02,-.61),armorPlate=armorPart(new THREE.BoxGeometry(1.38,1.22,.13),armorPlateMat,0,.1,.76),armorCollar=armorPart(new THREE.BoxGeometry(1.18,.22,.76),armorFabricMat,0,.86,.04),armorBelt=armorPart(new THREE.BoxGeometry(1.9,.22,1.22),armorFabricMat,0,-.76,0);
      const armorSides=[-1,1].map(side=>armorPart(new THREE.BoxGeometry(.18,1.24,.94),armorFabricMat,side*.88,-.03,0)),armorShoulders=[-1,1].map(side=>{const mesh=armorPart(new THREE.BoxGeometry(.42,.25,.86),armorPlateMat,side*1.03,.59,.02);mesh.rotation.z=side*.18;return mesh;});
      const armorPouches=[-.5,0,.5].map(x=>armorPart(new THREE.BoxGeometry(.4,.42,.25),armorFabricMat,x,-.48,.82)),armorSegments=[-.46,0,.46].map(x=>armorPart(new THREE.BoxGeometry(.4,.83,.1),armorPlateMat,x,.12,.86));
      const armorRails=[-1,1].map(side=>{const mesh=armorPart(new THREE.BoxGeometry(.12,1.7,.12),armorAccentMat,side*.78,.05,.88);mesh.rotation.z=side*.08;return mesh;});
      const armorBadge=armorPart(new THREE.BoxGeometry(.47,.22,.045),armorAccentMat,.37,.43,.87),armorCracks=[-1,1].map(side=>{const mesh=armorPart(new THREE.BoxGeometry(.035,.72,.035),armorWarnMat,side*.24,.08,.94);mesh.rotation.z=side*.47;return mesh;});
      body.add(armorRig);armorRig.visible=false;
      const armorPalette={leather_jacket:[0x65412d,0x3d291f,0xb37a4d],bulletproof:[0x33393d,0x242a2e,0x8a9aa0],kevlar_vest:[0x626246,0x414333,0xb3aa67],tactical_vest:[0x273a31,0x1b2822,0x65a77d],army_armor:[0x4d5438,0x323827,0x98a367],swat_suit:[0x182530,0x111a21,0x4ea7dc],composite_armor:[0x4b5158,0x252b31,0x9fb8c8],exo_armor:[0x202b32,0x0f171c,0x55e8ff],titanium_vest:[0x58636c,0x29323a,0xd2e6ef]};
      const configureArmorVisual=(id,durability,maxDurability)=>{const key=String(id||''),palette=armorPalette[key],pct=Math.max(0,Math.min(1,(+durability||0)/Math.max(1,+maxDurability||1)));armorRig.visible=!!palette;if(!palette){renderer.domElement.dataset.playerArmor='none';renderer.domElement.dataset.playerArmorDurability='0';return;}const damaged=new THREE.Color(palette[0]).lerp(new THREE.Color(0x4b2422),(1-pct)*.58),advanced=['composite_armor','titanium_vest','exo_armor'].includes(key),heavy=['army_armor','swat_suit'].includes(key)||advanced;armorFabricMat.color.copy(damaged);armorPlateMat.color.setHex(palette[1]).lerp(new THREE.Color(0x351b1a),(1-pct)*.48);armorAccentMat.color.setHex(palette[2]);armorAccentMat.emissive.setHex(key==='exo_armor'?0x064b58:pct<.25?0x47100d:0x000000);armorAccentMat.emissiveIntensity=key==='exo_armor'?.72:pct<.25?.5:0;armorFront.scale.z=key==='leather_jacket'?.72:1;armorPlate.visible=key!=='leather_jacket';armorBack.visible=key!=='leather_jacket'||pct>.2;armorCollar.visible=heavy||advanced;armorBelt.visible=key!=='leather_jacket';armorSides.forEach(part=>part.visible=key!=='leather_jacket');armorShoulders.forEach(part=>part.visible=heavy||advanced);armorPouches.forEach(part=>part.visible=['tactical_vest','army_armor','swat_suit'].includes(key));armorSegments.forEach(part=>part.visible=advanced);armorRails.forEach(part=>part.visible=key==='exo_armor');armorBadge.visible=['bulletproof','swat_suit','exo_armor'].includes(key);armorCracks.forEach((part,index)=>part.visible=pct<(index ? .28 : .55));renderer.domElement.dataset.playerArmor=key;renderer.domElement.dataset.playerArmorDurability=`${Math.round(pct*100)}`;};
      const head = new THREE.Mesh(new THREE.SphereGeometry(.68,20,16),skinMat);head.position.y=4.35;head.castShadow=true;player.add(head);
      const eyeWhiteMat=new THREE.MeshBasicMaterial({color:0xf8fbff}),irisMat=new THREE.MeshBasicMaterial({color:0x23384b}),hairMat=new THREE.MeshStandardMaterial({color:0x251a17,roughness:.82});
      for(const sx of [-.25,.25]){const eye=new THREE.Mesh(new THREE.SphereGeometry(.13,12,8),eyeWhiteMat);eye.scale.set(1,.78,.42);eye.position.set(sx,4.46,.625);player.add(eye);const pupil=new THREE.Mesh(new THREE.SphereGeometry(.065,10,7),irisMat);pupil.scale.z=.45;pupil.position.set(sx,4.46,.685);player.add(pupil);}
      const nose=new THREE.Mesh(new THREE.ConeGeometry(.105,.3,10),skinMat);nose.rotation.x=Math.PI/2;nose.position.set(0,4.25,.7);player.add(nose);const hair=new THREE.Mesh(new THREE.SphereGeometry(.695,18,10,0,Math.PI*2,0,Math.PI*.46),hairMat);hair.position.y=4.42;player.add(hair);
      const hairBun=new THREE.Mesh(new THREE.SphereGeometry(.34,14,10),hairMat);hairBun.position.set(0,4.7,-.44);hairBun.visible=false;player.add(hairBun);
      const hairBack=new THREE.Mesh(new THREE.CapsuleGeometry(.32,1.15,7,12),hairMat);hairBack.position.set(0,3.76,-.48);hairBack.scale.x=1.45;hairBack.visible=false;player.add(hairBack);
      const hairMohawk=new THREE.Mesh(new THREE.BoxGeometry(.24,.48,1.18),hairMat);hairMohawk.position.set(0,4.78,-.04);hairMohawk.visible=false;player.add(hairMohawk);
      const hairQuiff=new THREE.Mesh(new THREE.SphereGeometry(.42,14,10),hairMat);hairQuiff.position.set(.18,4.78,.16);hairQuiff.scale.set(1.25,.65,.86);hairQuiff.visible=false;player.add(hairQuiff);
      const hairFringe=new THREE.Mesh(new THREE.BoxGeometry(.58,.38,.16),hairMat);hairFringe.position.set(-.22,4.57,.58);hairFringe.rotation.z=-.24;hairFringe.visible=false;player.add(hairFringe);
      const hairCurls=new THREE.Group();for(const [x,y,z] of [[-.47,4.57,0],[0,4.76,-.04],[.47,4.57,0],[-.35,4.38,-.4],[.35,4.38,-.4],[0,4.5,-.5]]){const curl=new THREE.Mesh(new THREE.SphereGeometry(.29,11,8),hairMat);curl.position.set(x,y,z);curl.castShadow=true;hairCurls.add(curl);}hairCurls.visible=false;player.add(hairCurls);
      const faceDetailMat=new THREE.MeshStandardMaterial({color:0x7f2c2e,roughness:.86}),playerScar=new THREE.Group(),scarLine=new THREE.Mesh(new THREE.BoxGeometry(.035,.48,.025),faceDetailMat);scarLine.position.set(.34,4.33,.688);scarLine.rotation.z=-.45;playerScar.add(scarLine);for(let i=-1;i<=1;i++){const stitch=new THREE.Mesh(new THREE.BoxGeometry(.12,.022,.024),faceDetailMat);stitch.position.set(.34+i*.055,4.33-i*.075,.7);stitch.rotation.z=.72;playerScar.add(stitch);}playerScar.visible=false;player.add(playerScar);
      const playerBeard=new THREE.Mesh(new THREE.SphereGeometry(.7,18,11,0,Math.PI*2,Math.PI*.46,Math.PI*.38),hairMat);playerBeard.position.y=4.22;playerBeard.visible=false;player.add(playerBeard);
      const playerMoustache=new THREE.Group();for(const sx of [-.13,.13]){const side=new THREE.Mesh(new THREE.CapsuleGeometry(.045,.2,4,8),hairMat);side.position.set(sx,4.09,.705);side.rotation.z=sx>0?-.88:.88;playerMoustache.add(side);}playerMoustache.visible=false;player.add(playerMoustache);
      const playerFemaleFace=new THREE.Group(),femaleDetailMat=new THREE.MeshStandardMaterial({color:0x161116,roughness:.78}),femaleLipMat=new THREE.MeshStandardMaterial({color:0xa92f44,roughness:.62}),femaleJewelryMat=new THREE.MeshStandardMaterial({color:0xd1a84b,metalness:.72,roughness:.24});for(const sx of [-.25,.25]){for(const dx of [-.07,.07]){const lash=new THREE.Mesh(new THREE.BoxGeometry(.1,.022,.025),femaleDetailMat);lash.position.set(sx+dx,4.53,.704);lash.rotation.z=sx>0?-dx*2:dx*2;playerFemaleFace.add(lash);}}const femaleLips=new THREE.Mesh(new THREE.BoxGeometry(.24,.055,.03),femaleLipMat);femaleLips.position.set(0,4.01,.71);playerFemaleFace.add(femaleLips);for(const sx of [-.71,.71]){const earring=new THREE.Mesh(new THREE.SphereGeometry(.055,9,7),femaleJewelryMat);earring.position.set(sx,4.14,.04);playerFemaleFace.add(earring);}playerFemaleFace.visible=false;player.add(playerFemaleFace);
      const playerHatMat=darkMat.clone(),playerTrouserMat=darkMat.clone();
      const hatBrim=new THREE.Mesh(new THREE.CylinderGeometry(.9,.9,.12,20),playerHatMat);hatBrim.position.y=4.92;player.add(hatBrim);
      const hatTop=new THREE.Mesh(new THREE.CylinderGeometry(.58,.68,.55,20),playerHatMat);hatTop.position.y=5.18;player.add(hatTop);
      const playerHatHairLocks=new THREE.Group();for(const sx of [-1,1]){const lock=new THREE.Mesh(new THREE.CapsuleGeometry(.075,.26,5,8),hairMat);lock.position.set(sx*.59,4.35,-.08);lock.rotation.z=sx*.08;playerHatHairLocks.add(lock);}playerHatHairLocks.visible=false;player.add(playerHatHairLocks);
      const accessoryDark=new THREE.MeshStandardMaterial({color:0x111318,roughness:.72}),accessoryGold=new THREE.MeshStandardMaterial({color:0xd1a84b,roughness:.24,metalness:.72});
      const playerGlasses=new THREE.Group();for(const sx of [-.25,.25]){const lens=new THREE.Mesh(new THREE.TorusGeometry(.2,.035,8,18),accessoryDark);lens.position.set(sx,4.46,.72);lens.scale.y=.82;playerGlasses.add(lens);}const glassesBridge=new THREE.Mesh(new THREE.BoxGeometry(.18,.035,.035),accessoryDark);glassesBridge.position.set(0,4.46,.72);playerGlasses.add(glassesBridge);playerGlasses.visible=false;player.add(playerGlasses);
      const playerEyePatch=new THREE.Group(),eyePatch=new THREE.Mesh(new THREE.SphereGeometry(.16,12,8),accessoryDark),eyePatchStrap=new THREE.Mesh(new THREE.TorusGeometry(.7,.025,6,24,Math.PI),accessoryDark);eyePatch.scale.set(1,.72,.24);eyePatch.position.set(.25,4.46,.69);eyePatchStrap.position.set(0,4.45,.04);eyePatchStrap.rotation.z=Math.PI;playerEyePatch.add(eyePatch,eyePatchStrap);playerEyePatch.visible=false;player.add(playerEyePatch);
      const playerChain=new THREE.Mesh(new THREE.TorusGeometry(.5,.055,8,24,Math.PI),accessoryGold);playerChain.position.set(0,3.6,.7);playerChain.rotation.z=Math.PI;playerChain.visible=false;player.add(playerChain);
      const shirtFront=new THREE.Mesh(new THREE.BoxGeometry(.72,1.55,.06),new THREE.MeshStandardMaterial({color:0xf4f1e8,roughness:.7}));shirtFront.position.set(0,2.72,.56);player.add(shirtFront);
      const tie=new THREE.Mesh(new THREE.ConeGeometry(.16,.9,4),new THREE.MeshStandardMaterial({color:0x811c25,roughness:.58}));tie.rotation.z=Math.PI;tie.position.set(0,2.78,.61);player.add(tie);
      const carriedMoneyBag=new THREE.Group(),bagCloth=new THREE.MeshStandardMaterial({color:0x8c7042,roughness:.94}),bagBody=new THREE.Mesh(new THREE.SphereGeometry(.58,14,10),bagCloth),bagNeck=new THREE.Mesh(new THREE.CylinderGeometry(.16,.28,.34,9),bagCloth),bagTie=new THREE.Mesh(new THREE.TorusGeometry(.2,.045,6,12),new THREE.MeshStandardMaterial({color:0x4b3320,roughness:.8}));bagBody.scale.set(.85,1.08,.72);bagNeck.position.y=.57;bagTie.position.y=.43;bagTie.rotation.x=Math.PI/2;carriedMoneyBag.add(bagBody,bagNeck,bagTie);carriedMoneyBag.position.set(-.86,2.45,-.64);carriedMoneyBag.rotation.set(.2,0,-.18);carriedMoneyBag.visible=false;player.add(carriedMoneyBag);
      const policeCapBand=new THREE.Mesh(new THREE.CylinderGeometry(.7,.72,.2,20),new THREE.MeshStandardMaterial({color:0x2b5f91,roughness:.46,metalness:.12}));policeCapBand.position.y=5.02;policeCapBand.visible=false;player.add(policeCapBand);
      const policeBadge=new THREE.Mesh(new THREE.OctahedronGeometry(.17,0),new THREE.MeshStandardMaterial({color:0xf0c64c,metalness:.82,roughness:.2}));policeBadge.position.set(.42,3.12,.59);policeBadge.visible=false;player.add(policeBadge);
      const prisonerBadge=new THREE.Mesh(new THREE.BoxGeometry(.62,.32,.065),new THREE.MeshStandardMaterial({color:0x17191d,roughness:.76}));prisonerBadge.position.set(.38,3.03,.595);prisonerBadge.visible=false;player.add(prisonerBadge);
      const leftLeg=new THREE.Mesh(new THREE.CapsuleGeometry(.275,1.15,6,12),playerTrouserMat),rightLeg=leftLeg.clone();leftLeg.position.set(-.47,.88,0);rightLeg.position.set(.47,.88,0);leftLeg.castShadow=rightLeg.castShadow=true;player.add(leftLeg,rightLeg);
      const leftArm=new THREE.Mesh(new THREE.CapsuleGeometry(.24,1.32,6,12),suitMat),rightArm=leftArm.clone();leftArm.position.set(-1.02,2.75,0);rightArm.position.set(1.02,2.75,0);leftArm.castShadow=rightArm.castShadow=true;player.add(leftArm,rightArm);
      const leftForearm=new THREE.Mesh(new THREE.CapsuleGeometry(.215,.79,6,12),suitMat),rightForearm=leftForearm.clone(),leftHand=new THREE.Mesh(new THREE.SphereGeometry(.27,12,9),skinMat),rightHand=leftHand.clone();
      for(const part of [leftForearm,rightForearm,leftHand,rightHand]){part.castShadow=true;part.visible=false;player.add(part);}
      const playerBelly=new THREE.Mesh(new THREE.SphereGeometry(.72,18,12),suitMat);playerBelly.position.set(0,-.28,.08);playerBelly.visible=false;body.add(playerBelly);
      const playerChest=new THREE.Mesh(new THREE.SphereGeometry(.7,18,12),suitMat);playerChest.position.set(0,.28,.02);playerChest.scale.set(1.2,.72,.86);playerChest.visible=false;body.add(playerChest);
      const playerFemaleHips=new THREE.Mesh(new THREE.SphereGeometry(.68,18,12),playerTrouserMat);playerFemaleHips.position.set(0,-.83,0);playerFemaleHips.scale.set(1.42,.62,.86);playerFemaleHips.visible=false;body.add(playerFemaleHips);
      const playerFemaleBust=new THREE.Group();for(const sx of [-.28,.28]){const bust=new THREE.Mesh(new THREE.SphereGeometry(.34,16,11),suitMat);bust.position.set(sx,.32,.5);bust.scale.set(.9,.72,.62);playerFemaleBust.add(bust);}playerFemaleBust.visible=false;body.add(playerFemaleBust);
      const PLAYER_BODY_PROFILES=[
        {bodyX:.78,bodyZ:.74,shoulderX:.84,arm:.76,armZ:.76,leg:.76,legZ:.78,legX:.82,hand:.86},
        {bodyX:1,bodyZ:1,shoulderX:1,arm:1,armZ:1,leg:1,legZ:1,legX:1,hand:1},
        {bodyX:1.20,bodyZ:1.25,shoulderX:1.12,arm:1.13,armZ:1.16,leg:1.14,legZ:1.18,legX:1.14,hand:1.1},
        {bodyX:1.18,bodyZ:1.08,shoulderX:1.18,arm:1.2,armZ:1.14,leg:1.08,legZ:1.06,legX:1.06,hand:1.12}
      ];
      let playerBodyProfile=PLAYER_BODY_PROFILES[1],playerShoulderX=1.02;
      const applyPlayerBodyProfile=(bodyIndex,female)=>{playerBodyProfile=PLAYER_BODY_PROFILES[Math.abs(bodyIndex)%PLAYER_BODY_PROFILES.length];const shoulderScale=female?.82:1,hipScale=female?1.08:1;playerShoulderX=1.02*playerBodyProfile.shoulderX*shoulderScale;body.scale.x=playerBodyProfile.bodyX*shoulderScale;body.scale.z=playerBodyProfile.bodyZ*(female?.94:1);leftArm.position.x=-playerShoulderX;rightArm.position.x=playerShoulderX;leftArm.scale.set(playerBodyProfile.arm*(female?.9:1),1,playerBodyProfile.armZ*(female?.92:1));rightArm.scale.copy(leftArm.scale);leftLeg.position.x=-.47*playerBodyProfile.legX*hipScale;rightLeg.position.x=.47*playerBodyProfile.legX*hipScale;leftLeg.scale.set(playerBodyProfile.leg*(female?.92:1),1,playerBodyProfile.legZ*(female?.94:1));rightLeg.scale.copy(leftLeg.scale);playerBelly.visible=bodyIndex===2;playerBelly.scale.set(1.02*(female?.88:1),.94,1.08);playerChest.visible=bodyIndex===3&&!female;playerChest.scale.set(1.24,.72,.9);playerFemaleHips.visible=female;playerFemaleHips.scale.x=1.42*hipScale/Math.max(.72,body.scale.x);playerFemaleBust.visible=female;shirtFront.scale.x=body.scale.x*(female?.82:1);shirtFront.position.z=female?.69:.56;playerChain.position.z=bodyIndex===2?1.16:Math.max(.72,.53*playerBodyProfile.bodyZ+.2);playerChain.scale.x=Math.min(1.22,playerBodyProfile.shoulderX*shoulderScale);};
      const gun=new THREE.Group(),gunMetal=new THREE.MeshStandardMaterial({color:0x343b45,metalness:.9,roughness:.18}),gunDark=new THREE.MeshStandardMaterial({color:0x171b20,metalness:.58,roughness:.34}),gunWood=new THREE.MeshStandardMaterial({color:0x754326,roughness:.62});
      const gunReceiver=new THREE.Mesh(new THREE.BoxGeometry(.46,.42,1.18),gunMetal);gunReceiver.position.z=.55;
      const gunSlide=new THREE.Mesh(new THREE.BoxGeometry(.34,.16,.92),new THREE.MeshStandardMaterial({color:0x687482,metalness:.92,roughness:.16}));gunSlide.position.set(0,.24,.72);
      const gunBarrel=new THREE.Mesh(new THREE.CylinderGeometry(.09,.11,1.35,10),gunMetal);gunBarrel.rotation.x=Math.PI/2;gunBarrel.position.set(0,.06,1.73);
      const gunMuzzle=new THREE.Mesh(new THREE.CylinderGeometry(.16,.16,.18,12),gunDark);gunMuzzle.rotation.x=Math.PI/2;gunMuzzle.position.set(0,.06,2.42);
      const gunGrip=new THREE.Mesh(new THREE.BoxGeometry(.3,.74,.38),gunWood);gunGrip.position.set(0,-.48,.25);gunGrip.rotation.x=-.22;
      const gunMagazine=new THREE.Mesh(new THREE.BoxGeometry(.3,.82,.38),gunDark);gunMagazine.position.set(0,-.54,.82);gunMagazine.rotation.x=.13;
      const gunStock=new THREE.Mesh(new THREE.BoxGeometry(.48,.58,1.05),gunWood);gunStock.position.set(0,-.06,-.58);
      const gunScope=new THREE.Mesh(new THREE.CylinderGeometry(.14,.14,.68,10),gunDark);gunScope.rotation.x=Math.PI/2;gunScope.position.set(0,.43,.76);
      const rpgTube=new THREE.Mesh(new THREE.CylinderGeometry(.23,.31,3.4,12),new THREE.MeshStandardMaterial({color:0x536b4a,metalness:.3,roughness:.62}));rpgTube.rotation.x=Math.PI/2;rpgTube.position.set(0,.08,.9);rpgTube.visible=false;
      const rpgRocket=new THREE.Group(),rpgRocketBody=new THREE.Mesh(new THREE.CylinderGeometry(.13,.17,.92,10),new THREE.MeshStandardMaterial({color:0x687653,metalness:.34,roughness:.56})),rpgRocketNose=new THREE.Mesh(new THREE.ConeGeometry(.24,.68,10),new THREE.MeshStandardMaterial({color:0x596447,metalness:.28,roughness:.61}));rpgRocketBody.rotation.x=rpgRocketNose.rotation.x=Math.PI/2;rpgRocketNose.position.z=.78;rpgRocket.add(rpgRocketBody,rpgRocketNose);rpgRocket.position.set(0,.08,2.28);rpgRocket.visible=false;
      const weaponGold=new THREE.MeshStandardMaterial({color:0xe9b927,metalness:.92,roughness:.14,emissive:0x4a2600,emissiveIntensity:.22}),weaponBlue=new THREE.MeshBasicMaterial({color:0x5ee8ff,toneMapped:false}),weaponGlass=new THREE.MeshPhysicalMaterial({color:0x9cdfff,metalness:.08,roughness:.08,transmission:.36,transparent:true,opacity:.82});
      const revolverCylinder=new THREE.Mesh(new THREE.CylinderGeometry(.25,.25,.4,12),gunMetal);revolverCylinder.rotation.z=Math.PI/2;revolverCylinder.position.set(0,.02,.55);
      // Sidearms deliberately use different silhouettes instead of recolouring
      // the same pistol mesh.  The revolvers expose a cylinder/hammer and their
      // own barrel, the heavy pistol has a broad squared slide, and the gold
      // pistol receives a raised rib and contrasting inlays.
      const revolverBarrel=new THREE.Mesh(new THREE.CylinderGeometry(.085,.11,1.16,10),gunMetal);revolverBarrel.rotation.x=Math.PI/2;revolverBarrel.position.set(0,.08,1.28);
      const revolverHammer=new THREE.Mesh(new THREE.BoxGeometry(.18,.28,.16),gunDark);revolverHammer.position.set(0,.31,.08);revolverHammer.rotation.x=-.32;
      const heavySlide=new THREE.Mesh(new THREE.BoxGeometry(.52,.34,1.58),gunMetal);heavySlide.position.set(0,.2,.88);
      const heavyBarrel=new THREE.Mesh(new THREE.CylinderGeometry(.13,.15,1.55,12),gunDark);heavyBarrel.rotation.x=Math.PI/2;heavyBarrel.position.set(0,.06,1.68);
      const heavyRearSight=new THREE.Mesh(new THREE.BoxGeometry(.34,.15,.16),gunDark);heavyRearSight.position.set(0,.43,.26);
      const goldTopRib=new THREE.Mesh(new THREE.BoxGeometry(.18,.11,1.02),weaponGold);goldTopRib.position.set(0,.38,.74);
      const goldInlay=new THREE.Mesh(new THREE.BoxGeometry(.5,.1,.48),gunDark);goldInlay.position.set(0,.02,.48);
      const shotgunPump=new THREE.Mesh(new THREE.BoxGeometry(.54,.45,.9),gunWood);shotgunPump.position.set(0,-.04,1.32);
      const tommyDrum=new THREE.Mesh(new THREE.CylinderGeometry(.43,.43,.24,18),gunDark);tommyDrum.rotation.z=Math.PI/2;tommyDrum.position.set(0,-.43,.72);
      const rifleForegrip=new THREE.Mesh(new THREE.BoxGeometry(.4,.34,1.02),gunWood);rifleForegrip.position.set(0,-.04,1.38);
      const sniperLens=new THREE.Mesh(new THREE.CylinderGeometry(.18,.18,.12,12),weaponGlass);sniperLens.rotation.x=Math.PI/2;sniperLens.position.set(0,.43,1.12);
      const taserCoil=new THREE.Mesh(new THREE.TorusGeometry(.2,.055,8,16),weaponBlue);taserCoil.rotation.x=Math.PI/2;taserCoil.position.set(0,.08,1.23);
      const muzzleBrake=new THREE.Mesh(new THREE.BoxGeometry(.3,.24,.38),gunDark);muzzleBrake.position.set(0,.06,2.45);
      const grenadeModel=new THREE.Group(),grenadeBody=new THREE.Mesh(new THREE.SphereGeometry(.3,12,9),new THREE.MeshStandardMaterial({color:0x4e6040,metalness:.3,roughness:.7})),grenadeLever=new THREE.Mesh(new THREE.BoxGeometry(.1,.42,.18),gunMetal);grenadeLever.position.set(.22,.18,0);grenadeModel.add(grenadeBody,grenadeLever);grenadeModel.position.set(0,0,.34);
      const molotovModel=new THREE.Group(),molotovBottle=new THREE.Mesh(new THREE.CylinderGeometry(.18,.24,.82,12),new THREE.MeshPhysicalMaterial({color:0x6f3b22,transparent:true,opacity:.82,roughness:.18,transmission:.2})),molotovRag=new THREE.Mesh(new THREE.ConeGeometry(.14,.5,8),new THREE.MeshBasicMaterial({color:0xff7a18,toneMapped:false}));molotovRag.position.y=.62;molotovModel.add(molotovBottle,molotovRag);molotovModel.rotation.x=Math.PI/2;molotovModel.position.set(0,0,.45);
      const c4Model=new THREE.Group(),c4Pack=new THREE.Mesh(new THREE.BoxGeometry(.66,.42,.9),new THREE.MeshStandardMaterial({color:0x9c3e32,roughness:.72})),c4Timer=new THREE.Mesh(new THREE.BoxGeometry(.42,.22,.08),weaponBlue);c4Timer.position.set(0,.05,.49);c4Model.add(c4Pack,c4Timer);c4Model.position.set(0,0,.35);
      const reloadRound=new THREE.Mesh(new THREE.CylinderGeometry(.065,.08,.32,8),new THREE.MeshStandardMaterial({color:0xd8a338,metalness:.86,roughness:.24}));reloadRound.rotation.z=Math.PI/2;reloadRound.visible=false;
      // Semantic detail meshes are reused by every arsenal profile. Only the
      // active weapon exposes a small subset, keeping quality bounded to one
      // held model instead of creating a separate hidden hierarchy per item.
      const weaponTriggerGuard=new THREE.Mesh(new THREE.TorusGeometry(.2,.035,7,18,Math.PI),gunDark),weaponFrontSight=new THREE.Mesh(new THREE.BoxGeometry(.075,.16,.1),gunDark),weaponRearSight=new THREE.Mesh(new THREE.BoxGeometry(.28,.12,.1),gunDark),weaponEjectionPort=new THREE.Mesh(new THREE.BoxGeometry(.08,.16,.42),gunDark),weaponTopRail=new THREE.Mesh(new THREE.BoxGeometry(.24,.07,.9),gunDark),weaponBarrelShroud=new THREE.Mesh(new THREE.CylinderGeometry(.13,.13,1.2,10),gunMetal),weaponStockPad=new THREE.Mesh(new THREE.BoxGeometry(.58,.7,.16),gunDark),weaponBipodLeft=new THREE.Mesh(new THREE.BoxGeometry(.07,.74,.07),gunMetal),weaponBipodRight=new THREE.Mesh(new THREE.BoxGeometry(.07,.74,.07),gunMetal),weaponSlingRing=new THREE.Mesh(new THREE.TorusGeometry(.13,.035,7,14),gunMetal),weaponSpecialPin=new THREE.Mesh(new THREE.TorusGeometry(.12,.025,7,14),gunMetal),weaponSpecialWire=new THREE.Mesh(new THREE.TorusGeometry(.22,.025,7,18),weaponBlue);
      const weaponDetailParts=[weaponTriggerGuard,weaponFrontSight,weaponRearSight,weaponEjectionPort,weaponTopRail,weaponBarrelShroud,weaponStockPad,weaponBipodLeft,weaponBipodRight,weaponSlingRing,weaponSpecialPin,weaponSpecialWire];
      ['trigger-guard','front-sight','rear-sight','ejection-port','top-rail','barrel-shroud','stock-pad','bipod-left','bipod-right','sling-ring','safety-pin','special-wire'].forEach((name,i)=>weaponDetailParts[i].userData.detailName=name);
      const showWeaponDetail=(part,x,y,z,sx=1,sy=1,sz=1,rx=0,ry=0,rz=0,material=null)=>{part.visible=true;part.position.set(x,y,z);part.scale.set(sx,sy,sz);part.rotation.set(rx,ry,rz);if(material)part.material=material;};
      const configureWeaponDetails=(family,id)=>{
        for(const part of weaponDetailParts)part.visible=false;
        if(['','none','fists','unarmed'].includes(id)){renderer.domElement.dataset.weaponDetailProfile=`${id||'none'}:none`;return;}
        const firearm=!['rpg','grenade','molotov','c4'].includes(family),longGun=['shotgun','smg','tommy','gold-tommy','rifle','sniper','water-hose'].includes(family),gold=family==='gold-pistol'||family==='gold-tommy',detailMetal=gold?weaponGold:gunDark;
        if(firearm){showWeaponDetail(weaponTriggerGuard,0,-.2,.25,1,1,1,0,0,0,detailMetal);showWeaponDetail(weaponFrontSight,0,.31,longGun?2.28:1.18,1,1,1,0,0,0,detailMetal);showWeaponDetail(weaponRearSight,0,.35,.28,1,1,1,0,0,0,detailMetal);showWeaponDetail(weaponEjectionPort,.22,.18,family==='revolver'?.55:.78,1,1,1,0,0,0,detailMetal);}
        if(['heavy-pistol','gold-pistol','smg','rifle','sniper','taser'].includes(family))showWeaponDetail(weaponTopRail,0,.35,family==='sniper'?.78:.82,family==='sniper'?1.45:1,1,1,0,0,0,gold?weaponGold:gunDark);
        if(family==='revolver')showWeaponDetail(weaponBarrelShroud,.16,-.01,1.12,.45,.45,.72,Math.PI/2,0,0,gunDark);
        if(family==='shotgun'){showWeaponDetail(weaponBarrelShroud,0,.08,1.56,1.22,1,1.7,Math.PI/2,0,0,gunMetal);showWeaponDetail(weaponTopRail,0,.27,1.5,.72,1,1.8,0,0,0,gunDark);}
        if(family==='smg'){showWeaponDetail(weaponBarrelShroud,0,.06,1.5,.72,.72,.82,Math.PI/2,0,0,gunDark);showWeaponDetail(weaponSlingRing,.3,-.04,-.1,1,1,1,0,Math.PI/2,0,gunMetal);}
        if(family==='tommy'||family==='gold-tommy'){showWeaponDetail(weaponBarrelShroud,0,.06,1.62,.64,.64,1.12,Math.PI/2,0,0,gold?weaponGold:gunMetal);showWeaponDetail(weaponSlingRing,.31,.08,-.82,1,1,1,0,Math.PI/2,0,gold?weaponGold:gunMetal);}
        if(family==='rifle'||family==='sniper'){showWeaponDetail(weaponBarrelShroud,0,.07,1.7,.72,.72,1.45,Math.PI/2,0,0,gunDark);showWeaponDetail(weaponStockPad,0,-.06,-1.14,1,1,1,0,0,0,gunDark);showWeaponDetail(weaponSlingRing,.31,-.02,-.52,1,1,1,0,Math.PI/2,0,gunMetal);}
        if(family==='sniper'){showWeaponDetail(weaponBipodLeft,-.23,-.38,1.62,1,1,1,-.28,0,-.2,gunMetal);showWeaponDetail(weaponBipodRight,.23,-.38,1.62,1,1,1,-.28,0,.2,gunMetal);}
        if(family==='water-hose'){showWeaponDetail(weaponBarrelShroud,0,.07,1.7,1.22,1.22,1.5,Math.PI/2,0,0,weaponBlue);showWeaponDetail(weaponSlingRing,0,-.05,.85,1.35,1.35,1.35,Math.PI/2,0,0,weaponBlue);}
        if(family==='taser'){showWeaponDetail(weaponBipodLeft,-.12,.1,1.34,.8,.32,.8,Math.PI/2,0,0,weaponBlue);showWeaponDetail(weaponBipodRight,.12,.1,1.34,.8,.32,.8,Math.PI/2,0,0,weaponBlue);}
        if(family==='rpg'){showWeaponDetail(weaponFrontSight,0,.42,1.32,1.3,1.3,1.3,0,0,0,gunDark);showWeaponDetail(weaponRearSight,0,.38,.08,1,1,1,0,0,0,gunDark);showWeaponDetail(weaponTriggerGuard,0,-.32,.35,1.2,1.2,1.2,0,0,0,gunDark);showWeaponDetail(weaponSlingRing,.32,.02,-.55,1.25,1.25,1.25,0,Math.PI/2,0,gunMetal);}
        if(family==='grenade'){showWeaponDetail(weaponSpecialPin,.28,.25,.34,1,1,1,0,Math.PI/2,0,gunMetal);showWeaponDetail(weaponSlingRing,.13,.35,.34,.8,.8,.8,Math.PI/2,0,0,gunMetal);}
        if(family==='molotov'){showWeaponDetail(weaponSpecialWire,0,.12,.92,.58,.58,.58,Math.PI/2,0,0,gunMetal);showWeaponDetail(weaponSlingRing,0,-.08,.43,1.05,1.05,1.05,Math.PI/2,0,0,gunDark);}
        if(family==='c4'){showWeaponDetail(weaponSpecialWire,0,.25,.37,1.15,.72,1,0,0,0,weaponBlue);showWeaponDetail(weaponEjectionPort,0,-.13,.84,2.8,.75,1,0,0,0,gunDark);showWeaponDetail(weaponSpecialPin,.28,.03,.84,.75,.75,.75,0,0,0,weaponGold);}
        renderer.domElement.dataset.weaponDetailProfile=`${id}:${weaponDetailParts.filter(part=>part.visible).map(part=>part.userData.detailName).join(',')}`;
      };
      const weaponExtraParts=[revolverCylinder,revolverBarrel,revolverHammer,heavySlide,heavyBarrel,heavyRearSight,goldTopRib,goldInlay,shotgunPump,tommyDrum,rifleForegrip,sniperLens,taserCoil,muzzleBrake,grenadeModel,molotovModel,c4Model,rpgRocket,reloadRound,...weaponDetailParts];
      gun.add(gunReceiver,gunSlide,gunBarrel,gunMuzzle,gunGrip,gunMagazine,gunStock,gunScope,rpgTube,...weaponExtraParts);gun.position.set(.78,2.72,.55);gun.rotation.x=-.08;gun.traverse(o=>{if(o.isMesh)o.castShadow=true;});player.add(gun);
      const weaponPoseAuditObjects=[gun,gunMagazine,tommyDrum,revolverCylinder,shotgunPump,gunSlide,heavySlide,rpgTube,rpgRocket,reloadRound,leftArm,rightArm,leftForearm,rightForearm,leftHand,rightHand],weaponPoseQaEnabled=(location.hostname==='127.0.0.1'||location.hostname==='localhost')&&rendererParams.has('previewreload');
      const limbUp=new THREE.Vector3(0,1,0),limbDir=new THREE.Vector3(),limbMid=new THREE.Vector3(),leftShoulder=new THREE.Vector3(),rightShoulder=new THREE.Vector3(),leftElbow=new THREE.Vector3(),rightElbow=new THREE.Vector3(),leftHandTarget=new THREE.Vector3(),rightHandTarget=new THREE.Vector3(),reloadHandTarget=new THREE.Vector3();
      const posePlayerLimb=(mesh,start,end,baseLength)=>{limbDir.subVectors(end,start);const len=Math.max(.01,limbDir.length());limbMid.addVectors(start,end).multiplyScalar(.5);mesh.position.copy(limbMid);mesh.quaternion.setFromUnitVectors(limbUp,limbDir.multiplyScalar(1/len));mesh.scale.set(playerBodyProfile.arm,len/baseLength,playerBodyProfile.armZ);mesh.visible=true;};
      const hidePlayerGripParts=()=>{for(const part of [leftForearm,rightForearm,leftHand,rightHand])part.visible=false;leftArm.scale.set(playerBodyProfile.arm,1,playerBodyProfile.armZ);rightArm.scale.copy(leftArm.scale);};
      const showPlayerIdleHands=()=>{const handScale=playerBodyProfile.hand,reach=.98;leftHand.position.set(-playerShoulderX,leftArm.position.y-Math.cos(leftArm.rotation.x)*reach,leftArm.position.z-Math.sin(leftArm.rotation.x)*reach);rightHand.position.set(playerShoulderX,rightArm.position.y-Math.cos(rightArm.rotation.x)*reach,rightArm.position.z-Math.sin(rightArm.rotation.x)*reach);leftHand.scale.set(.88*handScale,1.06*handScale,.78*handScale);rightHand.scale.copy(leftHand.scale);leftHand.visible=rightHand.visible=true;};
      const poseTwoHandedGrip=(kick=0,reload=0)=>{
        gun.updateMatrix();
        const family=currentWeaponFx.family,foregripZ=family==='rpg'?1.3:family==='shotgun'?1.34:family==='sniper'?1.44:family==='rifle'?1.34:1.12;
        rightHandTarget.set(0,-.43,.24).applyMatrix4(gun.matrix);
        leftHandTarget.set(0,-.05,foregripZ).applyMatrix4(gun.matrix);
        if(reload>0){
          const handling=Math.sin(Math.min(1,reload)*Math.PI);
          if(family==='smg'||family==='tommy'||family==='gold-tommy'||family==='rifle'){reloadHandTarget.set(-.08,-.62,.2).applyMatrix4(gun.matrix);leftHandTarget.lerp(reloadHandTarget,handling*.92);}
          else if(family==='sniper'){const bolt=Math.sin(Math.max(0,Math.min(1,(reload-.68)/.28))*Math.PI);reloadHandTarget.set(.26,-.02,.78).applyMatrix4(gun.matrix);rightHandTarget.lerp(reloadHandTarget,bolt*.94);}
          else if(family==='shotgun'){const pump=Math.sin(Math.max(0,Math.min(1,(reload-.62)/.35))*Math.PI);reloadHandTarget.set(0,-.05,foregripZ-pump*.5).applyMatrix4(gun.matrix);leftHandTarget.lerp(reloadHandTarget,pump);}
          else if(family==='rpg'){reloadHandTarget.set(-.12,.02,.58).applyMatrix4(gun.matrix);leftHandTarget.lerp(reloadHandTarget,handling*.86);}
        }
        rightShoulder.set(playerShoulderX*.75,3.38,.02-kick*.08);leftShoulder.set(-playerShoulderX*.75,3.38,.02-kick*.07);
        rightElbow.lerpVectors(rightShoulder,rightHandTarget,.52);rightElbow.x+=.34;rightElbow.y-=.16+reload*.08;rightElbow.z-=.08;
        leftElbow.lerpVectors(leftShoulder,leftHandTarget,.48);leftElbow.x-=.24;leftElbow.y-=.12+reload*.1;leftElbow.z-=.04;
        posePlayerLimb(rightArm,rightShoulder,rightElbow,1.8);posePlayerLimb(rightForearm,rightElbow,rightHandTarget,1.22);
        posePlayerLimb(leftArm,leftShoulder,leftElbow,1.8);posePlayerLimb(leftForearm,leftElbow,leftHandTarget,1.22);
        rightHand.position.copy(rightHandTarget);leftHand.position.copy(leftHandTarget);rightHand.scale.setScalar(playerBodyProfile.hand);leftHand.scale.copy(rightHand.scale);rightHand.visible=leftHand.visible=true;
      };
      const holsteredPistol=new THREE.Group(),holsterBody=new THREE.Mesh(new THREE.BoxGeometry(.42,.72,.3),new THREE.MeshStandardMaterial({color:0x3b251a,roughness:.72})),holsterGrip=new THREE.Mesh(new THREE.BoxGeometry(.28,.52,.24),gunDark);holsterBody.position.y=-.18;holsterGrip.position.set(.06,.42,0);holsterGrip.rotation.z=-.22;holsteredPistol.add(holsterBody,holsterGrip);holsteredPistol.position.set(.92,1.92,.12);holsteredPistol.rotation.set(.08,0,-.16);holsteredPistol.visible=false;holsteredPistol.traverse(o=>{if(o.isMesh)o.castShadow=true;});player.add(holsteredPistol);
      const arrestCuffs=new THREE.Group(),cuffMetal=new THREE.MeshStandardMaterial({color:0xaeb8c3,metalness:.96,roughness:.16});
      for(const side of [-1,1]){const ring=new THREE.Mesh(new THREE.TorusGeometry(.25,.065,8,20),cuffMetal);ring.position.x=side*.32;ring.castShadow=true;arrestCuffs.add(ring);}
      const cuffChain=new THREE.Mesh(new THREE.BoxGeometry(.22,.08,.08),cuffMetal);cuffChain.castShadow=true;arrestCuffs.add(cuffChain);arrestCuffs.position.set(0,2.18,-.53);arrestCuffs.visible=false;player.add(arrestCuffs);
      const localMuzzleFlash=new THREE.Group(),visualMuzzlePoint=new THREE.Vector3(),localFlashCore=new THREE.Mesh(new THREE.IcosahedronGeometry(.31,1),new THREE.MeshBasicMaterial({color:0xffdf77,transparent:true,depthTest:false,toneMapped:false,blending:THREE.AdditiveBlending}));localMuzzleFlash.add(localFlashCore);for(let i=0;i<5;i++){const ray=new THREE.Mesh(new THREE.ConeGeometry(.11,.9,6),localFlashCore.material.clone());ray.rotation.x=Math.PI/2;ray.rotation.z=i*Math.PI*.4;ray.position.z=.37;localMuzzleFlash.add(ray);}localMuzzleFlash.position.set(0,.06,2.72);localMuzzleFlash.visible=false;localMuzzleFlash.renderOrder=50;gun.add(localMuzzleFlash);
      const WEAPON_VISUALS={
        pistol:{family:'pistol',grip:'one',recoil:1.0,decay:11,flash:1,color:0xffdc74},nagan:{family:'revolver',grip:'one',recoil:1.45,decay:8.5,flash:1.2,color:0xa9e4ff},revolver:{family:'revolver',grip:'one',recoil:2.1,decay:7,flash:1.55,color:0xffbd55},pistol_heavy:{family:'heavy-pistol',grip:'one',recoil:2.45,decay:7.5,flash:1.75,color:0xff7f2a},pistol_gold:{family:'gold-pistol',grip:'one',recoil:1.2,decay:10.5,flash:1.25,color:0xffd700},
        shotgun:{family:'shotgun',grip:'two',recoil:3.35,decay:6.2,flash:2.15,color:0xffa338,holdZ:.72,recoilBack:.18,recoilPitch:.2,recoilRise:.08,pumpTravel:.38},smg:{family:'smg',grip:'two',recoil:.72,decay:14,flash:.95,color:0xffe68a},tommy_gun:{family:'tommy',grip:'two',recoil:.9,decay:12,flash:1.1,color:0xffcf70,holdZ:.68,stockZ:-.38,stockScaleZ:.72},golden_tommy:{family:'gold-tommy',grip:'two',recoil:.9,decay:12,flash:1.2,color:0xffd700,holdZ:.68,stockZ:-.38,stockScaleZ:.72},rifle:{family:'rifle',grip:'two',recoil:1.65,decay:9,flash:1.5,color:0xffd16b},sniper:{family:'sniper',grip:'two',recoil:4.2,decay:5.4,flash:2.25,color:0xff5252},water_hose:{family:'water-hose',grip:'two',recoil:.18,decay:14,flash:.25,color:0x70cfff},taser:{family:'taser',grip:'one',recoil:.28,decay:14,flash:.8,color:0x58ddff},rpg:{family:'rpg',grip:'two',recoil:5.4,decay:4.8,flash:2.8,color:0xff6728},grenade:{family:'grenade',grip:'throw',recoil:0,decay:10,flash:0,color:0x7b8c5e},molotov:{family:'molotov',grip:'throw',recoil:0,decay:10,flash:0,color:0xff7a18},c4:{family:'c4',grip:'one',recoil:0,decay:10,flash:0,color:0xd94c3f}
      };
      const WEAPON_VISUAL_ALIASES={tt:'pistol',tt_pistol:'pistol',pm:'pistol',glock:'pistol',desert_eagle:'pistol_heavy',deagle:'pistol_heavy',golden_colt:'pistol_gold',sawn_off:'shotgun',uzi:'smg',ump:'smg',mp5:'smg',golden_uzi:'smg',ak:'rifle',ak74:'rifle',m4:'rifle',m16:'rifle'};
      let currentWeaponFx=WEAPON_VISUALS.pistol,currentWeaponId='pistol';
      const configureWeaponVisual=id=>{
        const rawId=String(id||'').toLowerCase();currentWeaponId=WEAPON_VISUALS[rawId]?rawId:(WEAPON_VISUAL_ALIASES[rawId]||rawId);currentWeaponFx=WEAPON_VISUALS[currentWeaponId]||WEAPON_VISUALS.pistol;
        const f=currentWeaponFx.family,unarmed=currentWeaponId===''||currentWeaponId==='none'||currentWeaponId==='fists'||currentWeaponId==='unarmed',specialOnly=f==='rpg'||f==='grenade'||f==='molotov'||f==='c4',specialSidearm=f==='revolver'||f==='heavy-pistol',isLong=currentWeaponFx.grip==='two',isGold=f==='gold-pistol'||f==='gold-tommy',isNagan=currentWeaponId==='nagan',boxMagazine=f==='pistol'||f==='heavy-pistol'||f==='gold-pistol'||f==='smg'||f==='rifle'||f==='sniper';
        gun.visible=!unarmed;for(const part of [gunReceiver,gunSlide,gunBarrel,gunMuzzle,gunGrip])part.visible=!unarmed&&!specialOnly;for(const part of weaponExtraParts)part.visible=false;
        rpgTube.visible=rpgRocket.visible=f==='rpg';reloadRound.visible=false;gunMagazine.visible=!unarmed&&boxMagazine;gunMagazine.position.set(0,-.54,(f==='pistol'||f==='heavy-pistol'||f==='gold-pistol')?.28:.82);gunMagazine.rotation.set(.13,0,0);
        gunStock.visible=f==='shotgun'||f==='tommy'||f==='gold-tommy'||f==='rifle'||f==='sniper';gunScope.visible=f==='rifle'||f==='sniper';if(specialSidearm)gunSlide.visible=gunBarrel.visible=gunMuzzle.visible=false;
        revolverCylinder.visible=revolverBarrel.visible=revolverHammer.visible=f==='revolver';heavySlide.visible=heavyBarrel.visible=heavyRearSight.visible=f==='heavy-pistol';goldTopRib.visible=goldInlay.visible=f==='gold-pistol';shotgunPump.visible=f==='shotgun';tommyDrum.visible=f==='tommy'||f==='gold-tommy';rifleForegrip.visible=f==='rifle'||f==='sniper';sniperLens.visible=f==='sniper';taserCoil.visible=f==='taser';muzzleBrake.visible=f==='heavy-pistol'||f==='sniper'||f==='rifle';grenadeModel.visible=f==='grenade';molotovModel.visible=f==='molotov';c4Model.visible=f==='c4';
        gunReceiver.material=isGold?weaponGold:gunMetal;gunSlide.material=isGold?weaponGold:gunMetal;gunGrip.material=f==='revolver'?gunWood:isGold?weaponGold:gunWood;gunMagazine.material=isGold?weaponGold:gunDark;tommyDrum.material=isGold?weaponGold:gunDark;revolverCylinder.material=revolverBarrel.material=isNagan?gunMetal:gunDark;revolverCylinder.scale.setScalar(isNagan?.86:1.14);revolverBarrel.scale.set(1,1,isNagan?.84:1.18);heavySlide.material=currentWeaponId==='pistol_heavy'?gunMetal:gunDark;
        gunReceiver.scale.set(f==='gold-pistol'?1.08:1,f==='heavy-pistol'?1.16:1,f==='revolver'?.86:1);gunSlide.scale.set(f==='gold-pistol'?1.13:1,f==='gold-pistol'?1.12:1,f==='gold-pistol'?.9:1);gunBarrel.scale.set(1,1,f==='gold-pistol'?.82:1);gunStock.position.z=currentWeaponFx.stockZ??-.58;gunStock.scale.set(1,1,currentWeaponFx.stockScaleZ??1);gun.scale.setScalar(f==='rpg'?1.08:isLong?1.03:(f==='grenade'||f==='molotov')?1.35:f==='heavy-pistol'?.84:f==='revolver'?(isNagan?.78:.86):f==='gold-pistol'?.8:.76);gun.position.set(currentWeaponFx.grip==='one'?.76:.18,isLong?2.98:2.75,currentWeaponFx.holdZ??(isLong?.3:.62));gun.userData.baseY=gun.position.y;gun.userData.baseZ=gun.position.z;
        tommyDrum.position.set(0,-.43,.72);tommyDrum.rotation.set(0,0,Math.PI/2);revolverCylinder.position.x=0;rpgTube.position.z=.9;rpgTube.rotation.z=0;rpgRocket.position.set(0,.08,2.28);rpgRocket.rotation.set(0,0,0);configureWeaponDetails(f,currentWeaponId);
        renderer.domElement.dataset.weaponModel=f;renderer.domElement.dataset.weaponVariant=currentWeaponId;renderer.domElement.dataset.weaponAnimationProfile=f==='revolver'?(isNagan?'nagan-cylinder-hammer':'magnum-cylinder-hammer'):f==='heavy-pistol'?'heavy-slide-kick':f==='gold-pistol'?'gold-quick-slide':f==='tommy'||f==='gold-tommy'?'drum-feed':boxMagazine?'detachable-magazine':'special-action';renderer.domElement.dataset.weaponGrip=currentWeaponFx.grip;renderer.domElement.dataset.weaponStockFit=`${gunStock.position.z.toFixed(2)}:${gunStock.scale.z.toFixed(2)}`;
      };
      const WEAPON_ANIMATION_QA_IDS=Object.freeze(['pistol','nagan','revolver','pistol_heavy','pistol_gold','shotgun','smg','tommy_gun','golden_tommy','rifle','sniper','taser','rpg','grenade','molotov','c4','none']);
      const weaponVisualSnapshot=requested=>{
        const family=currentWeaponFx.family,parts={magazine:gunMagazine.visible,drum:tommyDrum.visible,stock:gunStock.visible,scope:gunScope.visible,revolver:revolverCylinder.visible,heavy:heavySlide.visible,gold:goldTopRib.visible,pump:shotgunPump.visible,foregrip:rifleForegrip.visible,sniperLens:sniperLens.visible,taser:taserCoil.visible,rpgTube:rpgTube.visible,rpgRocket:rpgRocket.visible,grenade:grenadeModel.visible,molotov:molotovModel.visible,c4:c4Model.visible},faults=[];
        const boxMagazine=family==='pistol'||family==='heavy-pistol'||family==='gold-pistol'||family==='smg'||family==='rifle'||family==='sniper',tommy=family==='tommy'||family==='gold-tommy',unarmed=currentWeaponId==='none'||currentWeaponId==='fists'||currentWeaponId==='unarmed'||currentWeaponId==='';
        if(parts.magazine!==(!unarmed&&boxMagazine))faults.push('box-magazine');if(parts.drum!==(!unarmed&&tommy))faults.push('drum');if(parts.magazine&&parts.drum)faults.push('double-feed');if(unarmed&&gun.visible)faults.push('unarmed-visible');if(family==='revolver'&&(!parts.revolver||gunSlide.visible))faults.push('revolver-rig');if(family==='shotgun'&&(!parts.pump||!parts.stock||parts.magazine))faults.push('shotgun-rig');if(family==='sniper'&&(!parts.scope||!parts.sniperLens||!parts.magazine))faults.push('sniper-rig');if(family==='rpg'&&(!parts.rpgTube||!parts.rpgRocket||gunReceiver.visible))faults.push('rpg-rig');if(family==='grenade'&&!parts.grenade)faults.push('grenade-rig');if(family==='molotov'&&!parts.molotov)faults.push('molotov-rig');if(family==='c4'&&!parts.c4)faults.push('c4-rig');
        const details=weaponDetailParts.filter(part=>part.visible).map(part=>part.userData.detailName);if(!unarmed&&details.length<2)faults.push('insufficient-detail');
        return {requested,id:currentWeaponId,family,grip:currentWeaponFx.grip,gunVisible:gun.visible,parts,details,faults,valid:faults.length===0};
      };
      if(location.hostname==='127.0.0.1'||location.hostname==='localhost')renderer.domElement.__animationQaWeapons=()=>{const original=currentWeaponId,weapons=WEAPON_ANIMATION_QA_IDS.map(id=>{configureWeaponVisual(id);return weaponVisualSnapshot(id);}),aliases=Object.keys(WEAPON_VISUAL_ALIASES).map(id=>{configureWeaponVisual(id);return {requested:id,id:currentWeaponId,family:currentWeaponFx.family};});configureWeaponVisual(original);renderer.domElement.dataset.weaponQaCount=String(weapons.length);renderer.domElement.dataset.weaponQaFaults=String(weapons.reduce((sum,item)=>sum+item.faults.length,0));return {version:356,weapons,aliases};};
      if((location.hostname==='127.0.0.1'||location.hostname==='localhost')&&new URLSearchParams(location.search).has('previewallweaponsqa'))setTimeout(()=>{const qa=renderer.domElement.__animationQaWeapons?.();if(!qa)return;renderer.domElement.dataset.weaponQaResult=`${qa.weapons.length}:${qa.aliases.length}:${qa.weapons.reduce((sum,item)=>sum+item.faults.length,0)}`;renderer.domElement.dataset.weaponQaDetailCounts=qa.weapons.map(item=>`${item.id}:${item.details.length}`).join(',');renderer.domElement.dataset.weaponQaProjectileProfiles='pistol,nagan,revolver,pistol_heavy,pistol_gold,shotgun,smg,tommy_gun,golden_tommy,rifle,sniper,taser,rpg';renderer.domElement.dataset.weaponQaNonProjectileProfiles='grenade,molotov,c4,none';},900);
      const resolveWeaponReloadStage=(family,p)=>family==='shotgun'?(p<.64?'load-shell':'pump'):family==='revolver'?(p<.22?'open':p<.78?'load-round':'close'):family==='rpg'?(p<.28?'prepare-rocket':p<.82?'seat-rocket':'lock'):family==='sniper'?(p<.28?'remove-mag':p<.68?'insert-mag':'bolt'):family==='tommy'||family==='gold-tommy'?(p<.3?'remove-drum':p<.72?'insert-drum':'charge'):p<.28?'remove-mag':p<.72?'insert-mag':'chamber';
      const paintHealthFade=(c,x,y,w,h,pct,background)=>{const health=THREE.MathUtils.clamp(Number.isFinite(+pct)?+pct:1,0,1),visibleW=w*health;if(visibleW<=0)return health;c.save();c.beginPath();c.rect(x,y,w,h);c.clip();c.fillStyle=background;c.fillRect(x,y,visibleW,h);if(health<.995){const feather=Math.min(54,visibleW),gradient=c.createLinearGradient(x+visibleW-feather,0,x+visibleW,0);gradient.addColorStop(0,'rgba(0,0,0,0)');gradient.addColorStop(1,'rgba(0,0,0,1)');c.globalCompositeOperation='destination-out';c.fillStyle=gradient;c.fillRect(x+visibleW-feather,y,feather,h);}c.restore();return health;};
      const strokeHealthFadeFrame=(c,x,y,w,h,pct,accent,lineWidth)=>{c.strokeStyle=accent;c.lineWidth=lineWidth;c.strokeRect(x,y,w,h);};
      const playerNameCanvas=document.createElement('canvas');playerNameCanvas.width=512;playerNameCanvas.height=128;const playerNameContext=playerNameCanvas.getContext('2d'),playerNameTexture=new THREE.CanvasTexture(playerNameCanvas);playerNameTexture.colorSpace=THREE.SRGBColorSpace;playerNameTexture.generateMipmaps=false;playerNameTexture.minFilter=THREE.LinearFilter;playerNameTexture.magFilter=THREE.LinearFilter;let playerNameHealthSig=-1;const paintPlayerNameHealth=pct=>{const health=Math.round(THREE.MathUtils.clamp(+pct||0,0,1)*100);if(health===playerNameHealthSig)return;playerNameHealthSig=health;const c=playerNameContext;c.clearRect(0,0,512,128);paintHealthFade(c,5,5,502,118,health/100,'rgba(5,10,18,.94)');strokeHealthFadeFrame(c,9,9,494,110,health/100,'#d8b750',7);c.fillStyle='#fff';c.font='900 48px system-ui';c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';c.lineWidth=12;c.strokeStyle='rgba(0,0,0,.95)';const name=String(initialState?.name||'Игрок').slice(0,18);c.strokeText(name,256,62);c.fillText(name,256,62);playerNameTexture.needsUpdate=true;};paintPlayerNameHealth(1);
      const playerName=new THREE.Sprite(new THREE.SpriteMaterial({map:playerNameTexture,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}));playerName.position.y=7.45;playerName.scale.set(8.5,1.98,1);playerName.renderOrder=45;player.add(playerName);renderer.domElement.dataset.playerHpVisual='identity-card-right-to-left-fade-v351';
      player.position.set(0,0,0);scene.add(player);
      // Pooled foot contacts: no allocations while walking and no particle
      // emitter cost. The rings also make planted steps readable at isometric
      // camera distance without turning the street into dust clouds.
      const footContactPool=[];
      const footContactMaterial=new THREE.MeshBasicMaterial({color:0xc9b18d,transparent:true,opacity:0,depthWrite:false,side:THREE.DoubleSide});
      for(let i=0;i<6;i++){const ring=new THREE.Mesh(new THREE.RingGeometry(.12,.34,14),footContactMaterial.clone());ring.rotation.x=-Math.PI/2;ring.position.y=.07;ring.visible=false;ring.renderOrder=8;scene.add(ring);footContactPool.push({mesh:ring,born:0,life:0});}
      player.traverse(o=>o.layers.enable(1));
      const weatherMode=selectedWeather,weatherCount=weatherMode==='rain'?150:weatherMode==='snow'?110:0,weatherPositions=new Float32Array(weatherCount*(weatherMode==='rain'?6:3)),weatherSeeds=[];
      for(let i=0;i<weatherCount;i++)weatherSeeds.push({x:(Math.random()-.5)*82,y:Math.random()*48,z:(Math.random()-.5)*82,speed:.65+Math.random()*.8,phase:Math.random()*10});
      let weatherObject=null;
      if(weatherMode==='rain'){for(let i=0;i<weatherCount;i++){const p=weatherSeeds[i],j=i*6;weatherPositions[j]=weatherPositions[j+3]=p.x;weatherPositions[j+1]=p.y;weatherPositions[j+4]=p.y-2.4;weatherPositions[j+2]=p.z;weatherPositions[j+5]=p.z+.45;}const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(weatherPositions,3));weatherObject=new THREE.LineSegments(geo,new THREE.LineBasicMaterial({color:0x9fc9df,transparent:true,opacity:.34,depthWrite:false}));scene.add(weatherObject);}
      else if(weatherMode==='snow'){const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(weatherPositions,3));weatherObject=new THREE.Points(geo,new THREE.PointsMaterial({map:particleTexture('rgba(255,255,255,.95)','rgba(220,240,255,.3)'),color:0xeaf7ff,size:.48,sizeAttenuation:true,transparent:true,opacity:.82,depthWrite:false}));scene.add(weatherObject);}
      const updateWeather=(dt,t)=>{if(!weatherObject)return;for(let i=0;i<weatherCount;i++){const p=weatherSeeds[i];p.y-=dt*(weatherMode==='rain'?32:5)*p.speed;if(p.y<0){p.y+=48;p.x=(Math.random()-.5)*82;p.z=(Math.random()-.5)*82;}const x=player.position.x+p.x+(weatherMode==='snow'?Math.sin(t*.001+p.phase)*2.2:0),z=player.position.z+p.z+(weatherMode==='rain'?3:Math.cos(t*.0008+p.phase));if(weatherMode==='rain'){const j=i*6;weatherPositions[j]=x;weatherPositions[j+1]=p.y;weatherPositions[j+2]=z;weatherPositions[j+3]=x-.6;weatherPositions[j+4]=p.y-2.4;weatherPositions[j+5]=z+.45;}else{const j=i*3;weatherPositions[j]=x;weatherPositions[j+1]=p.y;weatherPositions[j+2]=z;}}weatherObject.geometry.attributes.position.needsUpdate=true;};
      renderer.domElement.dataset.gameplayBridge=bridge?'connected':'fallback';
      renderer.domElement.dataset.worldMapBridge=worldSnapshot?'connected':'fallback';
      renderer.domElement.dataset.worldScale=String(WORLD_SCALE);
      renderer.domElement.dataset.worldBuildings=String(buildingDefs.length);
      renderer.domElement.dataset.pickableBuildings=String(buildingPickables.length);
      renderer.domElement.dataset.buildingRenderGroups='walls-roof-2';
      renderer.domElement.dataset.contactShadows='buildings-cars-player';
      renderer.domElement.dataset.weather=weatherMode;
      let collisionSamples=0,collisionMismatches=0,visualFootprintSamples=0,visualFootprintMismatches=0;for(const def of buildingDefs){const meta=def[8];if(!meta||!Array.isArray(meta.tiles))continue;for(const [r,c] of meta.tiles){collisionSamples++;if(!bridge?.collisionProbe?.(r+.5,c+.5)?.blocked)collisionMismatches++;}for(let r=meta.minR;r<=meta.maxR;r++)for(let c=meta.minC;c<=meta.maxC;c++){visualFootprintSamples++;if(!bridge?.collisionProbe?.(r+.5,c+.5)?.blocked)visualFootprintMismatches++;}}renderer.domElement.dataset.collisionSamples=String(collisionSamples);renderer.domElement.dataset.collisionMismatches=String(collisionMismatches);renderer.domElement.dataset.visualFootprintSamples=String(visualFootprintSamples);renderer.domElement.dataset.visualFootprintMismatches=String(visualFootprintMismatches);
      const auditedEntrances=[...(worldSnapshot?.landmarks?.businesses||[]),...(worldSnapshot?.pois||[])].filter(p=>Number.isFinite(+p.entryR)&&Number.isFinite(+p.entryC));let entranceCollisionMismatches=0;for(const entry of auditedEntrances)if(bridge?.collisionProbe?.(+entry.entryR,+entry.entryC)?.blocked)entranceCollisionMismatches++;renderer.domElement.dataset.entranceCollisionSamples=String(auditedEntrances.length);renderer.domElement.dataset.entranceCollisionMismatches=String(entranceCollisionMismatches);
      const auditedBusinessExteriors=worldSnapshot?.landmarks?.businesses||[];let businessExteriorCollisionMismatches=0;for(const biz of auditedBusinessExteriors)if(!bridge?.collisionProbe?.(+biz.r,+biz.c)?.blocked)businessExteriorCollisionMismatches++;renderer.domElement.dataset.businessExteriorCollisionSamples=String(auditedBusinessExteriors.length);renderer.domElement.dataset.businessExteriorCollisionMismatches=String(businessExteriorCollisionMismatches);
      console.info(`[ThreePreview] gameplay bridge: ${bridge?'connected':'fallback'}; real map blocks: ${worldSnapshot?.blocks?.length||0}`);

      const cars = [],wreckedCarColor=new THREE.Color(0x171513);
      const newsRedMat=new THREE.MeshPhysicalMaterial({color:0xc91f2b,metalness:.36,roughness:.24,clearcoat:1,clearcoatRoughness:.08,envMap:cityEnvironment,envMapIntensity:1.3}),newsWhiteMat=new THREE.MeshStandardMaterial({color:0xf3f0e6,roughness:.42,metalness:.16}),newsGlassMat=new THREE.MeshPhysicalMaterial({color:0x17364c,roughness:.06,metalness:.1,transmission:.18,clearcoat:1,clearcoatRoughness:.03,envMap:cityEnvironment,envMapIntensity:1.7});
      const vehicleCrackCanvas=document.createElement('canvas');vehicleCrackCanvas.width=128;vehicleCrackCanvas.height=128;const vehicleCrackCtx=vehicleCrackCanvas.getContext('2d');vehicleCrackCtx.translate(64,64);vehicleCrackCtx.strokeStyle='rgba(225,250,255,.92)';vehicleCrackCtx.lineCap='round';for(let ray=0;ray<15;ray++){const a=ray*2.399+(ray%3)*.09,len=23+(ray%5)*6;vehicleCrackCtx.lineWidth=ray%4===0?2.1:1.05;vehicleCrackCtx.beginPath();vehicleCrackCtx.moveTo(Math.cos(a)*2,Math.sin(a)*2);vehicleCrackCtx.lineTo(Math.cos(a+.08)*len*.52,Math.sin(a+.08)*len*.52);vehicleCrackCtx.lineTo(Math.cos(a-.06)*len,Math.sin(a-.06)*len);vehicleCrackCtx.stroke();if(ray%3===0){vehicleCrackCtx.beginPath();vehicleCrackCtx.moveTo(Math.cos(a)*len*.48,Math.sin(a)*len*.48);vehicleCrackCtx.lineTo(Math.cos(a+.5)*len*.78,Math.sin(a+.5)*len*.78);vehicleCrackCtx.stroke();}}for(const radius of [8,15,25]){vehicleCrackCtx.globalAlpha=.62-radius*.012;vehicleCrackCtx.beginPath();vehicleCrackCtx.arc(0,0,radius,-.55,Math.PI*.95);vehicleCrackCtx.stroke();}const vehicleCrackTexture=new THREE.CanvasTexture(vehicleCrackCanvas);vehicleCrackTexture.colorSpace=THREE.SRGBColorSpace;vehicleCrackTexture.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());const vehicleCrackMaterial=new THREE.MeshBasicMaterial({map:vehicleCrackTexture,color:0xdaf7ff,transparent:true,opacity:.94,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-4,side:THREE.DoubleSide,toneMapped:false}),vehicleHoleMaterial=new THREE.MeshBasicMaterial({color:0x050403,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-3}),vehicleHoleGeometries=[.12,.144,.168].map(radius=>new THREE.CircleGeometry(radius,12)),vehicleCrackGeometries=[new THREE.PlaneGeometry(.78,.78),new THREE.PlaneGeometry(.9,.9)];
      const makeVehiclePunctureGeometry=radius=>{const positions=[],colors=[],N=12,outerColor=[.62,.49,.35],innerColor=[.075,.052,.038],backColor=[.002,.0015,.001],addVertex=(p,col)=>{positions.push(...p);colors.push(...col);},tri=(a,b,c,ca,cb,cc)=>{addVertex(a,ca);addVertex(b,cb);addVertex(c,cc);};for(let i=0;i<N;i++){const a=i*Math.PI*2/N,b=(i+1)*Math.PI*2/N,ja=1+Math.sin(i*12.9898+radius*73.1)*.11,jb=1+Math.sin((i+1)*12.9898+radius*73.1)*.11,oa=[Math.cos(a)*radius*ja,Math.sin(a)*radius*ja,0],ob=[Math.cos(b)*radius*jb,Math.sin(b)*radius*jb,0],ia=[Math.cos(a)*radius*.66,Math.sin(a)*radius*.66,-.026],ib=[Math.cos(b)*radius*.66,Math.sin(b)*radius*.66,-.026],ba=[Math.cos(a)*radius*.43,Math.sin(a)*radius*.43,-.074],bb=[Math.cos(b)*radius*.43,Math.sin(b)*radius*.43,-.074],center=[0,0,-.08];tri(oa,ob,ib,outerColor,outerColor,innerColor);tri(oa,ib,ia,outerColor,innerColor,innerColor);tri(ia,ib,bb,innerColor,innerColor,backColor);tri(ia,bb,ba,innerColor,backColor,backColor);tri(ba,bb,center,backColor,backColor,backColor);}const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));geometry.computeVertexNormals();return geometry;},vehiclePunctureMaterial=new THREE.MeshStandardMaterial({vertexColors:true,metalness:.72,roughness:.43,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-5}),vehiclePunctureCoreMaterial=new THREE.MeshBasicMaterial({color:0x020101,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-6,toneMapped:false}),vehiclePunctureRimMaterial=new THREE.MeshStandardMaterial({color:0xb38b63,metalness:.82,roughness:.34,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-7}),vehiclePunctureSootMaterial=new THREE.MeshBasicMaterial({color:0x100b08,transparent:true,opacity:.5,depthWrite:false,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-3,toneMapped:false}),vehiclePunctureSizes=[.16,.185,.21],vehiclePunctureGeometries=vehiclePunctureSizes.map(makeVehiclePunctureGeometry);
      const newsLabelCanvas=document.createElement('canvas');newsLabelCanvas.width=768;newsLabelCanvas.height=224;const newsLabelContext=newsLabelCanvas.getContext('2d');newsLabelContext.fillStyle='#f4f0e8';newsLabelContext.fillRect(0,0,768,224);newsLabelContext.fillStyle='#c91f2b';newsLabelContext.fillRect(0,0,768,28);newsLabelContext.fillRect(0,196,768,28);newsLabelContext.textAlign='center';newsLabelContext.textBaseline='middle';newsLabelContext.lineJoin='round';newsLabelContext.strokeStyle='#111820';newsLabelContext.lineWidth=15;newsLabelContext.font='900 106px system-ui';newsLabelContext.strokeText('NEWS',384,90);newsLabelContext.fillStyle='#c91f2b';newsLabelContext.fillText('NEWS',384,90);newsLabelContext.lineWidth=9;newsLabelContext.font='900 47px system-ui';newsLabelContext.strokeText('НОВОСТИ',384,168);newsLabelContext.fillStyle='#20262d';newsLabelContext.fillText('НОВОСТИ',384,168);const newsLabelTexture=new THREE.CanvasTexture(newsLabelCanvas);newsLabelTexture.colorSpace=THREE.SRGBColorSpace;newsLabelTexture.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());const newsLabelMat=new THREE.MeshBasicMaterial({map:newsLabelTexture,toneMapped:false,side:THREE.DoubleSide}),newsBeamMaterial=new THREE.MeshBasicMaterial({color:0xffefbd,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide});
      const vehicleMarkBaseRadius=vehiclePunctureSizes[0],vehiclePunctureSootGeometry=new THREE.RingGeometry(vehicleMarkBaseRadius*.72,vehicleMarkBaseRadius*1.72,20).translate(0,0,-.001),vehiclePunctureCoreGeometry=new THREE.CircleGeometry(vehicleMarkBaseRadius*.48,16).translate(0,0,-.086),vehiclePunctureRimGeometry=new THREE.TorusGeometry(vehicleMarkBaseRadius*.84,vehicleMarkBaseRadius*.145,7,18).translate(0,0,.012);
      const vehicleDamageSmokeGeometry=new THREE.DodecahedronGeometry(.3,1),vehicleDamageFlameGeometry=new THREE.ConeGeometry(.12,.52,7),vehicleWreckFlameGeometry=new THREE.ConeGeometry(.24,1.12,8),vehicleWreckSmokeGeometry=new THREE.DodecahedronGeometry(.48,1),vehicleWreckDebrisGeometry=new THREE.BoxGeometry(.16,.08,.48);
      const sharedVehicleFxMaterials={
        damageSmoke:new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.34,depthWrite:false}),
        damageFlame:new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.92,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),
        wreckMetal:new THREE.MeshStandardMaterial({color:0x161513,metalness:.64,roughness:.68}),
        wreckEdge:new THREE.MeshStandardMaterial({color:0x4c382b,metalness:.78,roughness:.46}),
        wreckGlass:new THREE.MeshPhysicalMaterial({color:0x080b0d,roughness:.38,metalness:.25,transparent:true,opacity:.82}),
        wreckHeat:new THREE.MeshBasicMaterial({color:0xff4c0a,transparent:true,opacity:.48,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),
        wreckFlame:new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.96,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),
        wreckSmoke:new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.38,depthWrite:false}),
        wreckDebris:new THREE.MeshStandardMaterial({color:0xffffff,metalness:.7,roughness:.57})
      };
      const pooledVehicleFxMatrix=new THREE.Matrix4(),pooledVehicleFxQuat=new THREE.Quaternion(),pooledVehicleFxPosition=new THREE.Vector3(),pooledVehicleFxScale=new THREE.Vector3(),pooledVehicleFxEuler=new THREE.Euler();
      const createPooledVehicleFx=(geometry,material,count)=>{
        const mesh=new THREE.InstancedMesh(geometry,material,count),items=Array.from({length:count},()=>({visible:true,position:new THREE.Vector3(),rotation:new THREE.Euler(),scale:new THREE.Vector3(1,1,1),baseScale:new THREE.Vector3(1,1,1),material}));
        mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.frustumCulled=false;mesh.castShadow=mesh.receiveShadow=false;
        return {mesh,items,forEach(fn){for(let i=0;i<items.length;i++){const item=items[i];fn(item,i);pooledVehicleFxQuat.setFromEuler(item.rotation);const s=item.visible!==false?pooledVehicleFxScale.set(item.scale.x*item.baseScale.x,item.scale.y*item.baseScale.y,item.scale.z*item.baseScale.z):pooledVehicleFxScale.set(0,0,0);pooledVehicleFxMatrix.compose(pooledVehicleFxPosition.copy(item.position),pooledVehicleFxQuat,s);mesh.setMatrixAt(i,pooledVehicleFxMatrix);}mesh.instanceMatrix.needsUpdate=true;}};
      };
      const flameCanvas=document.createElement('canvas');flameCanvas.width=128;flameCanvas.height=192;const flameCtx=flameCanvas.getContext('2d'),flameGradient=flameCtx.createLinearGradient(0,192,0,0);flameGradient.addColorStop(0,'rgba(255,32,0,0)');flameGradient.addColorStop(.12,'rgba(255,48,0,.96)');flameGradient.addColorStop(.48,'rgba(255,132,8,.94)');flameGradient.addColorStop(.78,'rgba(255,222,92,.74)');flameGradient.addColorStop(1,'rgba(255,245,202,0)');const flameGlow=flameCtx.createRadialGradient(64,132,3,64,128,62);flameGlow.addColorStop(0,'rgba(255,246,174,.96)');flameGlow.addColorStop(.28,'rgba(255,171,28,.76)');flameGlow.addColorStop(1,'rgba(255,37,0,0)');flameCtx.fillStyle=flameGlow;flameCtx.fillRect(0,50,128,142);flameCtx.beginPath();flameCtx.moveTo(16,180);flameCtx.bezierCurveTo(4,140,35,125,23,92);flameCtx.bezierCurveTo(15,66,48,70,45,31);flameCtx.bezierCurveTo(67,54,63,76,78,72);flameCtx.bezierCurveTo(107,68,88,111,111,127);flameCtx.bezierCurveTo(130,144,112,176,107,180);flameCtx.closePath();flameCtx.fillStyle=flameGradient;flameCtx.fill();flameCtx.beginPath();flameCtx.moveTo(41,179);flameCtx.bezierCurveTo(31,148,58,139,49,110);flameCtx.bezierCurveTo(45,92,70,101,68,66);flameCtx.bezierCurveTo(91,99,73,124,92,137);flameCtx.bezierCurveTo(104,151,91,174,87,179);flameCtx.closePath();const innerFlame=flameCtx.createLinearGradient(0,180,0,66);innerFlame.addColorStop(0,'rgba(255,72,0,.15)');innerFlame.addColorStop(.38,'rgba(255,230,82,.95)');innerFlame.addColorStop(.75,'rgba(255,255,220,.92)');innerFlame.addColorStop(1,'rgba(255,255,245,0)');flameCtx.fillStyle=innerFlame;flameCtx.fill();const realFlameTexture=new THREE.CanvasTexture(flameCanvas);realFlameTexture.colorSpace=THREE.SRGBColorSpace;realFlameTexture.minFilter=realFlameTexture.magFilter=THREE.LinearFilter;realFlameTexture.generateMipmaps=false;const realFlameGeometry=new THREE.PlaneGeometry(.85,1.7),realFlameMaterial=new THREE.MeshBasicMaterial({map:realFlameTexture,color:0xffffff,transparent:true,opacity:.96,depthWrite:false,depthTest:true,side:THREE.DoubleSide,toneMapped:false,blending:THREE.AdditiveBlending});
      const explosionCoreGeometry=new THREE.IcosahedronGeometry(1.4,2),explosionFireGeometry=new THREE.SphereGeometry(1.15,18,12),explosionShockGeometry=new THREE.TorusGeometry(1.35,.13,10,36),explosionGroundGeometry=new THREE.RingGeometry(.9,1.45,40),explosionSmokeGeometry=new THREE.DodecahedronGeometry(.65,1),explosionEmberGeometry=new THREE.TetrahedronGeometry(.09,0),explosionDebrisGeometry=new THREE.BoxGeometry(.08,.1,.32);
      const VEHICLE_RENDER_CAP=18;
      const INITIAL_VEHICLE_SYNC_CAP=6;
      const vehicleSlotDefs=Array.from({length:VEHICLE_RENDER_CAP},(_,i)=>({v:[-25+i*3,-2,[0xe9a126,0x15202e,0x8b1825,0x376da3,0xd9d9d2][i%5]],i}));
      const createVehicleSlot=({v,i})=>{
        const car = new THREE.Group();
        car.name=`vehicle-slot-${i}`;
        const paint = new THREE.MeshPhysicalMaterial({color:v[2],metalness:.42,roughness:.2,clearcoat:1,clearcoatRoughness:.075,envMap:cityEnvironment,envMapIntensity:1.28});
        const long=i%6===0,utility=i%7===0,L=long?7.1:utility?6.4:5.8,H=utility?1.7:1.25;
        const base = new THREE.Mesh(new THREE.BoxGeometry(L, H, utility?3.05:2.75), paint); base.position.y = H*.5+.38; base.castShadow = true; car.add(base);
        const glass=new THREE.MeshPhysicalMaterial({color:0x172b3e,metalness:.08,roughness:.07,transmission:.16,thickness:.22,clearcoat:1,clearcoatRoughness:.04,envMap:cityEnvironment,envMapIntensity:1.65});
        const cab = new THREE.Mesh(new THREE.BoxGeometry(utility?3.8:3.1, utility?1.35:1.05, utility?2.7:2.45), glass); cab.position.set(utility?-.25:.15, utility?2.15:1.95, 0); cab.castShadow = true; car.add(cab);
        const hood=new THREE.Mesh(new THREE.BoxGeometry(L*.27,.32,utility?2.82:2.5),paint);hood.position.set(L*.34,H+1.02,0);hood.castShadow=true;car.add(hood);
        const bumperMat=new THREE.MeshStandardMaterial({color:0x727b82,metalness:.82,roughness:.22});
        for(const sx of [-1,1]){const bumper=new THREE.Mesh(new THREE.BoxGeometry(.18,.24,utility?2.95:2.66),bumperMat);bumper.position.set(sx*(L/2+.13),.58,0);car.add(bumper);}
        const wheelPositions=[];for(const sx of [-1.8,1.8])for(const sz of [-1.38,1.38])wheelPositions.push([sx,.62,sz]);
        const headLamp=new THREE.MeshBasicMaterial({color:0xfff0bd,toneMapped:false}),tailLamp=new THREE.MeshBasicMaterial({color:0x791812,toneMapped:false});
        for(const z of [-.82,.82]){const front=new THREE.Mesh(new THREE.BoxGeometry(.12,.35,.42),headLamp);front.position.set(L/2+.04,.95,z);front.onBeforeRender=()=>headLamp.color.setHex(environmentNight>.12?0xfff1bd:0xb8c0bd);car.add(front);const rear=new THREE.Mesh(new THREE.BoxGeometry(.12,.32,.4),tailLamp);rear.position.set(-L/2-.04,.88,z);rear.onBeforeRender=()=>{const src=car.userData.source,braking=!!src?.braking||(src&&Math.hypot(+src.velR||0,+src.velC||0)<.035);tailLamp.color.setHex(braking&&environmentNight>.08?0xff3027:environmentNight>.08?0xa51c17:0x651713);};car.add(rear);}
        const siren=new THREE.Group();for(const [z,color] of [[-.36,0xff2929],[.36,0x278cff]]){const lamp=new THREE.Mesh(new THREE.BoxGeometry(.75,.22,.55),new THREE.MeshBasicMaterial({color}));lamp.position.set(0,2.82,z);siren.add(lamp);}siren.visible=false;car.add(siren);
        const plate=new THREE.Mesh(new THREE.PlaneGeometry(1.15,.38),new THREE.MeshBasicMaterial({color:0xe9e3c9}));plate.rotation.y=-Math.PI/2;plate.position.set(-L/2-.11,.72,0);car.add(plate);
        const chrome=new THREE.MeshStandardMaterial({color:0xb8c2c9,metalness:.92,roughness:.18}),rubber=new THREE.MeshStandardMaterial({color:0x111419,roughness:.86});
        for(const side of [-1,1]){const mirrorStem=new THREE.Mesh(new THREE.BoxGeometry(.42,.16,.16),chrome);mirrorStem.position.set(.9,2.14,side*(utility?1.55:1.4));car.add(mirrorStem);const mirror=new THREE.Mesh(new THREE.SphereGeometry(.26,12,8),paint);mirror.scale.set(1,.62,.45);mirror.position.set(1.1,2.16,side*(utility?1.7:1.56));car.add(mirror);const sill=new THREE.Mesh(new THREE.BoxGeometry(L*.56,.09,.08),chrome);sill.position.set(-.2,1.16,side*(utility?1.54:1.39));car.add(sill);}
        const wheelRubber=new THREE.MeshStandardMaterial({color:0x090a0c,roughness:.86}),wheelInstances=new THREE.InstancedMesh(new THREE.CylinderGeometry(.48,.48,.34,14),wheelRubber,wheelPositions.length),hubInstances=new THREE.InstancedMesh(new THREE.CylinderGeometry(.25,.25,.355,12),chrome,wheelPositions.length),tireLipInstances=new THREE.InstancedMesh(new THREE.TorusGeometry(.37,.075,7,16),rubber,wheelPositions.length),wheelMatrix=new THREE.Matrix4(),wheelQuat=new THREE.Quaternion(),wheelUnit=new THREE.Vector3(1,1,1);
        wheelPositions.forEach(([wx,wy,wz],wi)=>{wheelQuat.setFromEuler(new THREE.Euler(Math.PI/2,0,0));wheelMatrix.compose(new THREE.Vector3(wx,wy,wz),wheelQuat,wheelUnit);wheelInstances.setMatrixAt(wi,wheelMatrix);hubInstances.setMatrixAt(wi,wheelMatrix);wheelQuat.setFromEuler(new THREE.Euler(0,Math.PI/2,0));wheelMatrix.compose(new THREE.Vector3(wx,wy,wz),wheelQuat,wheelUnit);tireLipInstances.setMatrixAt(wi,wheelMatrix);});for(const wheelMesh of [wheelInstances,hubInstances,tireLipInstances]){wheelMesh.instanceMatrix.needsUpdate=true;wheelMesh.castShadow=true;wheelMesh.receiveShadow=true;car.add(wheelMesh);}const wheelMeshes=[wheelInstances,hubInstances,tireLipInstances];
        for(const side of [-1,1])for(const dx of [-.75,1.05]){const doorLine=new THREE.Mesh(new THREE.PlaneGeometry(.035,1.05),new THREE.MeshBasicMaterial({color:0x14191d,transparent:true,opacity:.55}));doorLine.position.set(dx,1.62,side*(utility?1.536:1.386));doorLine.rotation.y=side<0?Math.PI:0;car.add(doorLine);}
        const driverDoorPivot=new THREE.Group(),driverDoor=new THREE.Mesh(new THREE.BoxGeometry(1.72,1.08,.13),paint);driverDoor.position.set(-.86,0,0);driverDoor.castShadow=true;driverDoorPivot.position.set(1.08,1.62,utility?1.59:1.44);driverDoorPivot.add(driverDoor);car.add(driverDoorPivot);
        const exhaust=new THREE.Mesh(new THREE.CylinderGeometry(.11,.14,.62,10),chrome);exhaust.rotation.z=Math.PI/2;exhaust.position.set(-L/2-.25,.43,-(utility?1.05:.92));car.add(exhaust);
        const standardParts=[...car.children];
        const contactShadow=makeContactShadow(L*1.08,(utility?3.05:2.75)*1.18);car.add(contactShadow);
        const taxiSign=new THREE.Mesh(new THREE.BoxGeometry(1.35,.38,.58),new THREE.MeshBasicMaterial({color:0xffe34a}));taxiSign.position.set(0,2.75,0);taxiSign.visible=false;car.add(taxiSign);
        const spoiler=new THREE.Group(),spoilerWing=new THREE.Mesh(new THREE.BoxGeometry(.28,.22,2.35),paint);spoilerWing.position.set(-2.25,1.72,0);spoiler.add(spoilerWing);for(const z of [-.75,.75]){const stay=new THREE.Mesh(new THREE.BoxGeometry(.16,.62,.14),bumperMat);stay.position.set(-2.25,1.4,z);spoiler.add(stay);}spoiler.visible=false;car.add(spoiler);
        const pickupBed=new THREE.Group(),bedMat=new THREE.MeshStandardMaterial({color:0x20252a,roughness:.78,metalness:.25}),bedFloor=new THREE.Mesh(new THREE.BoxGeometry(2.35,.18,2.55),bedMat);bedFloor.position.set(-1.55,1.15,0);pickupBed.add(bedFloor);for(const z of [-1.22,1.22]){const rail=new THREE.Mesh(new THREE.BoxGeometry(2.45,.7,.16),paint);rail.position.set(-1.55,1.45,z);pickupBed.add(rail);}pickupBed.visible=false;car.add(pickupBed);
        const roofRack=new THREE.Group();for(const z of [-.92,.92]){const rail=new THREE.Mesh(new THREE.BoxGeometry(3.4,.12,.12),bumperMat);rail.position.set(0,2.95,z);roofRack.add(rail);}for(const x of [-1.3,0,1.3]){const cross=new THREE.Mesh(new THREE.BoxGeometry(.12,.12,1.95),bumperMat);cross.position.set(x,2.95,0);roofRack.add(cross);}roofRack.visible=false;car.add(roofRack);
        const cabrioSeats=new THREE.Group();for(const x of [-.55,.55]){const seat=new THREE.Mesh(new THREE.BoxGeometry(.65,.72,.82),new THREE.MeshStandardMaterial({color:0x7d2b25,roughness:.75}));seat.position.set(x,1.62,0);cabrioSeats.add(seat);}cabrioSeats.visible=false;car.add(cabrioSeats);
        const stripe=new THREE.Mesh(new THREE.BoxGeometry(L*.72,.16,utility?3.08:2.78),new THREE.MeshBasicMaterial({color:0xe53b32}));stripe.position.set(0,1.18,0);stripe.visible=false;car.add(stripe);
        // Built once per bounded vehicle slot: runtime only toggles the group.
        const policeLivery=new THREE.Group(),policeWhite=new THREE.MeshStandardMaterial({color:0xe8f1f6,roughness:.46,metalness:.18}),policeNavy=new THREE.MeshStandardMaterial({color:0x102f50,roughness:.5,metalness:.3}),policeGold=new THREE.MeshStandardMaterial({color:0xe1b84e,roughness:.34,metalness:.65});
        for(const side of [-1,1]){const doorPanel=new THREE.Mesh(new THREE.BoxGeometry(1.72,.76,.055),policeWhite);doorPanel.position.set(.05,1.57,side*(utility?1.558:1.408));policeLivery.add(doorPanel);const shield=new THREE.Mesh(new THREE.OctahedronGeometry(.22,0),policeGold);shield.scale.set(.72,1,.22);shield.position.set(.05,1.62,side*(utility?1.598:1.448));policeLivery.add(shield);const rocker=new THREE.Mesh(new THREE.BoxGeometry(L*.7,.22,.065),policeNavy);rocker.position.set(-.1,.88,side*(utility?1.565:1.415));policeLivery.add(rocker);}
        const pushBar=new THREE.Group();for(const z of [-.82,.82]){const upright=new THREE.Mesh(new THREE.BoxGeometry(.14,.72,.14),policeNavy);upright.position.set(L/2+.28,.72,z);pushBar.add(upright);}for(const y of [.5,.92]){const rail=new THREE.Mesh(new THREE.BoxGeometry(.14,.12,2.05),policeNavy);rail.position.set(L/2+.28,y,0);pushBar.add(rail);}policeLivery.add(pushBar);
        const roofPanel=new THREE.Mesh(new THREE.BoxGeometry(1.42,.055,1.12),policeWhite);roofPanel.position.set(-.08,2.69,0);policeLivery.add(roofPanel);const antenna=new THREE.Mesh(new THREE.CylinderGeometry(.025,.035,.78,7),policeNavy);antenna.position.set(-1.08,3.12,0);policeLivery.add(antenna);
        const policeTactical=new THREE.Group();for(const side of [-1,1]){const step=new THREE.Mesh(new THREE.BoxGeometry(3.35,.18,.24),policeNavy);step.position.set(-.28,.54,side*(utility?1.73:1.58));policeTactical.add(step);}const tacticalRoof=new THREE.Mesh(new THREE.BoxGeometry(2.05,.16,1.7),policeNavy);tacticalRoof.position.set(-.35,2.82,0);policeTactical.add(tacticalRoof);policeLivery.add(policeTactical);
        const policeHeavy=new THREE.Group();for(const side of [-1,1]){const armor=new THREE.Mesh(new THREE.BoxGeometry(3.7,.92,.13),policeNavy);armor.position.set(-.35,1.62,side*(utility?1.68:1.53));policeHeavy.add(armor);const wheelGuard=new THREE.Mesh(new THREE.BoxGeometry(1.18,.68,.18),policeNavy);wheelGuard.position.set(-1.8,.78,side*(utility?1.7:1.55));policeHeavy.add(wheelGuard);}const ram=new THREE.Mesh(new THREE.BoxGeometry(.32,1.05,2.45),policeNavy);ram.position.set(L/2+.38,.78,0);policeHeavy.add(ram);policeLivery.add(policeHeavy);policeLivery.visible=false;car.add(policeLivery);
        // Спецтранспорт получает читаемый силуэт и в 3D: цистерну, рукава и
        // лестницы у пожарной машины; платформу, лебёдку и стрелу у эвакуатора.
        const serviceSteel=new THREE.MeshStandardMaterial({color:0x59636b,metalness:.74,roughness:.3}),serviceWhite=new THREE.MeshStandardMaterial({color:0xe8edf0,metalness:.2,roughness:.48}),fireEquipment=new THREE.Group(),fireTank=new THREE.Mesh(new THREE.CylinderGeometry(.72,.72,2.75,18),serviceWhite);fireTank.rotation.z=Math.PI/2;fireTank.position.set(-1.15,2.18,0);fireEquipment.add(fireTank);
        for(const side of [-1,1]){const reel=new THREE.Mesh(new THREE.TorusGeometry(.47,.105,8,18),serviceSteel);reel.position.set(-1.2,2.25,side*1.26);fireEquipment.add(reel);const ladderRail=new THREE.Mesh(new THREE.BoxGeometry(3.55,.11,.11),serviceWhite);ladderRail.position.set(-.35,3.08,side*.58);fireEquipment.add(ladderRail);}for(let rung=-1.55;rung<=1.55;rung+=.5){const bar=new THREE.Mesh(new THREE.BoxGeometry(.1,.09,1.22),serviceWhite);bar.position.set(rung,3.08,0);fireEquipment.add(bar);}const hoseCannon=new THREE.Mesh(new THREE.CylinderGeometry(.085,.12,1.35,10),serviceSteel);hoseCannon.rotation.z=Math.PI/2;hoseCannon.position.set(.55,3.18,0);fireEquipment.add(hoseCannon);fireEquipment.visible=false;car.add(fireEquipment);
        // Непрерывная объёмная струя пожарной машины. Раньше тушение было
        // цепочкой маленьких «водяных пуль», из-за чего на экране читался
        // тонкий пунктир. Сегменты дают плотное ядро и мягкий голубой объём,
        // а отдельные брызги и кольца показывают место попадания воды.
        const fireWaterGroup=new THREE.Group(),fireWaterSegments=[],fireWaterOuterMat=new THREE.MeshBasicMaterial({color:0x49c8f2,transparent:true,opacity:.48,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}),fireWaterCoreMat=new THREE.MeshBasicMaterial({color:0xe8fbff,transparent:true,opacity:.9,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false});
        for(let s=0;s<11;s++){const segment=new THREE.Group(),outer=new THREE.Mesh(new THREE.CylinderGeometry(.22,.3,1,12,1,true),fireWaterOuterMat),core=new THREE.Mesh(new THREE.CylinderGeometry(.09,.16,1,10,1,true),fireWaterCoreMat);outer.renderOrder=31;core.renderOrder=32;segment.add(outer,core);fireWaterGroup.add(segment);fireWaterSegments.push(segment);}
        const fireWaterImpact=new THREE.Group(),fireWaterImpactDisc=new THREE.Mesh(new THREE.RingGeometry(.35,1.55,32),fireWaterOuterMat),fireWaterImpactCore=new THREE.Mesh(new THREE.RingGeometry(.12,.72,24),fireWaterCoreMat),fireWaterMist=[];fireWaterImpactDisc.rotation.x=fireWaterImpactCore.rotation.x=-Math.PI/2;fireWaterImpactDisc.renderOrder=30;fireWaterImpactCore.renderOrder=31;fireWaterImpact.add(fireWaterImpactDisc,fireWaterImpactCore);for(let d=0;d<14;d++){const drop=new THREE.Mesh(new THREE.SphereGeometry(.075+(d%3)*.025,7,5),(d%4?fireWaterOuterMat:fireWaterCoreMat).clone());drop.renderOrder=33;fireWaterImpact.add(drop);fireWaterMist.push(drop);}fireWaterGroup.add(fireWaterImpact);fireWaterGroup.visible=false;car.add(fireWaterGroup);
        const towEquipment=new THREE.Group(),towEdges=[],towDeck=new THREE.Mesh(new THREE.BoxGeometry(3.55,.2,2.72),serviceSteel);towDeck.position.set(-1.25,1.38,0);towDeck.rotation.z=-.07;towEquipment.add(towDeck);for(const side of [-1,1]){const edge=new THREE.Mesh(new THREE.BoxGeometry(3.45,.19,.13),serviceWhite);edge.position.set(-1.25,1.56,side*1.28);edge.rotation.z=-.07;towEquipment.add(edge);towEdges.push(edge);}const winch=new THREE.Mesh(new THREE.CylinderGeometry(.3,.3,.72,14),serviceSteel);winch.rotation.x=Math.PI/2;winch.position.set(.08,2.03,0);towEquipment.add(winch);const boom=new THREE.Mesh(new THREE.BoxGeometry(2.35,.2,.22),serviceSteel);boom.position.set(-.72,2.43,0);boom.rotation.z=.58;towEquipment.add(boom);const hookCable=new THREE.Mesh(new THREE.CylinderGeometry(.035,.035,1.05,7),serviceSteel);hookCable.position.set(-1.7,1.84,0);towEquipment.add(hookCable);towEquipment.visible=false;car.add(towEquipment);
        const policeTurret=new THREE.Group(),turretDark=new THREE.MeshStandardMaterial({color:0x111820,metalness:.7,roughness:.34}),turretUniform=new THREE.MeshStandardMaterial({color:0x17283a,roughness:.66}),turretSkin=new THREE.MeshStandardMaterial({color:0xc99773,roughness:.78}),turretHatch=new THREE.Mesh(new THREE.CylinderGeometry(.72,.78,.18,18),turretDark);turretHatch.position.y=2.86;policeTurret.add(turretHatch);const turretTorso=new THREE.Mesh(new THREE.BoxGeometry(.72,.92,.62),turretUniform);turretTorso.position.y=3.35;policeTurret.add(turretTorso);const turretHead=new THREE.Mesh(new THREE.SphereGeometry(.31,14,10),turretSkin);turretHead.position.y=4.03;policeTurret.add(turretHead);const turretHelmet=new THREE.Mesh(new THREE.SphereGeometry(.35,14,8,0,Math.PI*2,0,Math.PI*.58),turretDark);turretHelmet.position.y=4.1;policeTurret.add(turretHelmet);const policeTurretGunPivot=new THREE.Group(),turretGun=new THREE.Mesh(new THREE.BoxGeometry(2.05,.18,.2),turretDark);turretGun.position.set(1.05,3.55,0);policeTurretGunPivot.add(turretGun);const policeTurretMuzzle=new THREE.Mesh(new THREE.SphereGeometry(.18,10,7),new THREE.MeshBasicMaterial({color:0xffdf68,toneMapped:false}));policeTurretMuzzle.position.set(2.14,3.55,0);policeTurretGunPivot.add(policeTurretMuzzle);policeTurret.add(policeTurretGunPivot);policeTurret.visible=false;car.add(policeTurret);
        // Heavy-response roof weapon: shielded hatch, ammunition box and a
        // visibly longer supported barrel make the escalation readable.
        const turretShield=new THREE.Mesh(new THREE.BoxGeometry(.18,.72,1.18),turretDark);turretShield.position.set(.36,3.48,0);policeTurret.add(turretShield);const turretAmmo=new THREE.Mesh(new THREE.BoxGeometry(.62,.48,.56),turretDark);turretAmmo.position.set(-.5,3.24,-.52);policeTurret.add(turretAmmo);const turretBarrel=new THREE.Mesh(new THREE.CylinderGeometry(.065,.085,1.42,9),turretDark);turretBarrel.rotation.z=Math.PI/2;turretBarrel.position.set(1.76,3.55,0);policeTurretGunPivot.add(turretBarrel);const turretSight=new THREE.Mesh(new THREE.BoxGeometry(.28,.16,.18),policeGold);turretSight.position.set(.92,3.72,0);policeTurretGunPivot.add(turretSight);
        const ambulanceRearDoors=new THREE.Group(),ambulanceRearDoorPivots=[],medicalRed=new THREE.MeshStandardMaterial({color:0xc92934,roughness:.42,metalness:.18});
        for(const side of [-1,1]){
          const pivot=new THREE.Group(),panel=new THREE.Mesh(new THREE.BoxGeometry(.14,1.72,1.25),serviceWhite);
          pivot.position.set(-L/2-.14,1.62,side*1.3);panel.position.z=-side*.61;panel.castShadow=true;pivot.add(panel);
          const crossV=new THREE.Mesh(new THREE.BoxGeometry(.155,.72,.18),medicalRed),crossH=new THREE.Mesh(new THREE.BoxGeometry(.155,.22,.68),medicalRed);
          crossV.position.set(-.078,0,-side*.61);crossH.position.set(-.082,0,-side*.61);pivot.add(crossV,crossH);
          ambulanceRearDoors.add(pivot);ambulanceRearDoorPivots.push(pivot);
        }
        ambulanceRearDoors.visible=false;car.add(ambulanceRearDoors);
        const roadDustMat=new THREE.MeshStandardMaterial({color:0x493e35,roughness:1,transparent:true,opacity:.34});for(const z of [-1,1]){const grime=new THREE.Mesh(new THREE.PlaneGeometry(L*.72,.62),roadDustMat);grime.rotation.y=z>0?0:Math.PI;grime.position.set(-.12,.72,z*(utility?1.535:1.385));car.add(grime);}
        const helicopter=new THREE.Group(),heliBody=new THREE.Mesh(new THREE.SphereGeometry(1.2,18,12),paint);heliBody.scale.set(2.15,1.05,1.18);heliBody.position.y=3.1;helicopter.add(heliBody);const tailBoom=new THREE.Mesh(new THREE.CylinderGeometry(.18,.42,4.5,10),paint);tailBoom.rotation.z=Math.PI/2;tailBoom.position.set(-3.1,3.25,0);helicopter.add(tailBoom);const rotor=new THREE.Group();for(let k=0;k<2;k++){const blade=new THREE.Mesh(new THREE.BoxGeometry(7.8,.08,.18),new THREE.MeshStandardMaterial({color:0x232a30,metalness:.6,roughness:.35}));blade.rotation.y=k*Math.PI/2;rotor.add(blade);}rotor.position.y=4.55;helicopter.add(rotor);for(const z of [-.85,.85]){const skid=new THREE.Mesh(new THREE.BoxGeometry(3.2,.12,.12),bumperMat);skid.position.set(.1,1.65,z);helicopter.add(skid);}const newsCabin=new THREE.Mesh(new THREE.SphereGeometry(1.05,18,12),newsGlassMat);newsCabin.scale.set(1.12,.72,1.08);newsCabin.position.set(1.58,3.33,0);newsCabin.castShadow=true;helicopter.add(newsCabin);const newsStripe=new THREE.Mesh(new THREE.BoxGeometry(3.75,.24,2.88),newsWhiteMat);newsStripe.position.set(.05,2.93,0);helicopter.add(newsStripe);const newsLabels=[];for(const side of [-1,1]){const label=new THREE.Mesh(new THREE.PlaneGeometry(3.45,1.02),newsLabelMat);label.position.set(.05,3.25,side*1.44);if(side<0)label.rotation.y=Math.PI;label.renderOrder=26;helicopter.add(label);newsLabels.push(label);}const newsLightPod=new THREE.Mesh(new THREE.CylinderGeometry(.22,.34,.42,12),newsWhiteMat);newsLightPod.position.set(.72,1.95,0);helicopter.add(newsLightPod);const newsSearchLight=new THREE.SpotLight(0xffe9b0,0,45,Math.PI/8,.58,1.35),newsSearchTarget=new THREE.Object3D();newsSearchLight.position.set(.72,1.9,0);newsSearchTarget.position.set(0,-5.5,0);newsSearchLight.target=newsSearchTarget;newsSearchLight.castShadow=false;helicopter.add(newsSearchLight,newsSearchTarget);const newsBeamPivot=new THREE.Group(),newsBeamCone=new THREE.Mesh(new THREE.ConeGeometry(4.35,7.2,28,1,true),newsBeamMaterial);newsBeamPivot.position.set(.72,1.9,0);newsBeamCone.position.y=-3.6;newsBeamCone.renderOrder=9;newsBeamPivot.add(newsBeamCone);helicopter.add(newsBeamPivot);helicopter.visible=false;car.add(helicopter);
        const damageFx=new THREE.Group(),bodyHoles=[],glassCracks=[],bodyHoleLayers=[createPooledVehicleFx(vehiclePunctureSootGeometry,vehiclePunctureSootMaterial,10),createPooledVehicleFx(vehiclePunctureGeometries[0],vehiclePunctureMaterial,10),createPooledVehicleFx(vehiclePunctureCoreGeometry,vehiclePunctureCoreMaterial,10),createPooledVehicleFx(vehiclePunctureRimGeometry,vehiclePunctureRimMaterial,10)],damageSmoke=createPooledVehicleFx(vehicleDamageSmokeGeometry,new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.34,depthWrite:false}),8),damageFlames=createPooledVehicleFx(vehicleDamageFlameGeometry,new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.92,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),4);damageFx.position.set(L*.27,2.05,0);car.add(damageFx);damageSmoke.items.forEach((puff,s)=>{puff.baseScale.setScalar((.3+(s%4)*.055)/.3);damageSmoke.mesh.setColorAt(s,new THREE.Color(s%3?0x302d2b:0x5b554f));});damageSmoke.mesh.instanceColor.needsUpdate=true;damageFlames.items.forEach((flame,s)=>{flame.baseScale.set((.12+s*.025)/.12,(.52+s*.08)/.52,(.12+s*.025)/.12);damageFlames.mesh.setColorAt(s,new THREE.Color(s%2?0xff6b12:0xffd24a));});damageFlames.mesh.instanceColor.needsUpdate=true;damageFx.add(damageSmoke.mesh,damageFlames.mesh);for(const layer of bodyHoleLayers){layer.mesh.visible=false;layer.mesh.renderOrder=11;car.add(layer.mesh);}for(let h=0;h<6;h++){const crack=new THREE.Mesh(vehicleCrackGeometries[h%2],vehicleCrackMaterial);crack.visible=false;crack.renderOrder=10;car.add(crack);glassCracks.push(crack);}
        const wreckGroup=new THREE.Group(),wreckMetal=new THREE.MeshStandardMaterial({color:0x161513,metalness:.64,roughness:.68}),wreckEdge=new THREE.MeshStandardMaterial({color:0x4c382b,metalness:.78,roughness:.46}),wreckGlass=new THREE.MeshPhysicalMaterial({color:0x080b0d,roughness:.38,metalness:.25,transparent:true,opacity:.82}),wreckShell=new THREE.Mesh(new THREE.BoxGeometry(L*.96,.58,utility?2.96:2.67),wreckMetal),wreckCab=new THREE.Mesh(new THREE.BoxGeometry(L*.43,.5,utility?2.58:2.28),wreckGlass);wreckShell.position.y=.68;wreckShell.rotation.z=.045;wreckCab.position.set(-.18,1.2,0);wreckCab.rotation.z=-.14;wreckGroup.add(wreckShell,wreckCab);for(const z of [-1,1]){const rail=new THREE.Mesh(new THREE.BoxGeometry(L*.48,.11,.11),wreckEdge);rail.position.set(-.08,1.52,z*(utility?1.33:1.18));rail.rotation.z=z*.11;wreckGroup.add(rail);}for(const x of [-1.24,1.05]){const bow=new THREE.Mesh(new THREE.BoxGeometry(.12,.8,utility?2.6:2.32),wreckEdge);bow.position.set(x,1.16,0);bow.rotation.z=x<0?.18:-.22;wreckGroup.add(bow);}const wreckDoor=new THREE.Mesh(new THREE.BoxGeometry(1.72,.12,1.05),wreckMetal);wreckDoor.position.set(-1.05,.28,utility?2.05:1.88);wreckDoor.rotation.set(.18,.26,-.42);wreckGroup.add(wreckDoor);const wreckWheels=[];for(const [wx,wz,tilt] of [[-1.78,-1.32,.18],[1.82,1.28,-.22],[-2.35,1.65,.72]]){const tire=new THREE.Mesh(new THREE.TorusGeometry(.42,.13,8,16),rubber);tire.position.set(wx,.34,wz);tire.rotation.set(Math.PI/2,tilt,.14);wreckGroup.add(tire);wreckWheels.push(tire);}const wreckHeat=new THREE.Mesh(new THREE.SphereGeometry(.82,12,8),new THREE.MeshBasicMaterial({color:0xff4c0a,transparent:true,opacity:.48,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}));wreckHeat.scale.set(2.15,.72,1.45);wreckHeat.position.set(L*.16,.82,0);wreckGroup.add(wreckHeat);const wreckGlow=new THREE.PointLight(0xff5010,0,19,2);wreckGlow.position.set(L*.14,1.2,0);wreckGroup.add(wreckGlow);const wreckFlames=createPooledVehicleFx(vehicleWreckFlameGeometry,new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.96,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),6),wreckSmoke=createPooledVehicleFx(vehicleWreckSmokeGeometry,new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.38,depthWrite:false}),6),wreckDebris=createPooledVehicleFx(vehicleWreckDebrisGeometry,new THREE.MeshStandardMaterial({color:0xffffff,metalness:.7,roughness:.57}),6),wreckBreakaway=[];wreckFlames.items.forEach((flame,f)=>{flame.baseScale.set((.24+(f%3)*.075)/.24,(1.12+(f%4)*.24)/1.12,(.24+(f%3)*.075)/.24);wreckFlames.mesh.setColorAt(f,new THREE.Color(f%3===0?0xffff9a:f%3===1?0xff9a17:0xff4210));});wreckFlames.mesh.instanceColor.needsUpdate=true;wreckSmoke.items.forEach((puff,s)=>{puff.baseScale.setScalar((.48+(s%3)*.12)/.48);wreckSmoke.mesh.setColorAt(s,new THREE.Color(s%2?0x18191c:0x333238));});wreckSmoke.mesh.instanceColor.needsUpdate=true;wreckDebris.items.forEach((shard,d)=>{shard.baseScale.set((.16+(d%3)*.12)/.16,1,(.48+(d%4)*.14)/.48);wreckDebris.mesh.setColorAt(d,new THREE.Color(d%3?0x161513:0x4c382b));});wreckDebris.mesh.instanceColor.needsUpdate=true;wreckGroup.add(wreckFlames.mesh,wreckSmoke.mesh,wreckDebris.mesh);const breakawayDefs=[['hood',new THREE.BoxGeometry(L*.27,.16,utility?2.72:2.42),wreckMetal,0,5.8,2.8],['doorL',new THREE.BoxGeometry(1.72,.12,1.05),wreckMetal,2.4,5.1,3.7],['doorR',new THREE.BoxGeometry(1.72,.12,1.05),wreckMetal,-2.3,4.8,3.4],['bumper',new THREE.BoxGeometry(.16,.22,utility?2.9:2.62),wreckEdge,3.5,4.2,2.5],['axle',new THREE.CylinderGeometry(.09,.12,2.5,8),wreckEdge,-3.2,3.9,2.2]];breakawayDefs.forEach(([kind,geo,mat,tx,tz,lift],bi)=>{const part=new THREE.Mesh(geo,mat);part.userData={kind,tx,tz,lift,spinX:3.2+bi*.71,spinY:4.1+bi*.63,spinZ:2.7+bi*.83};wreckGroup.add(part);wreckBreakaway.push(part);});const looseWheel=new THREE.Mesh(new THREE.TorusGeometry(.48,.15,9,18),rubber);looseWheel.rotation.x=Math.PI/2;looseWheel.userData={kind:'wheel',tx:-4.4,tz:-2.7,lift:4.4,spinX:7.2,spinY:4.1,spinZ:8.3};wreckGroup.add(looseWheel);wreckBreakaway.push(looseWheel);wreckGroup.visible=false;car.add(wreckGroup);
        car.userData={entityId:null,paint,wheelMeshes,wheelPositions,wheelSpin:0,wheelSteer:0,bodyRoll:0,bodyPitch:0,lastVehicleYaw:0,siren,cab,base,baseBaseY:base.position.y,hood,hoodBaseY:hood.position.y,driverDoorPivot,doorOpen:0,standardParts,damageBlend:0,wreckVisibilityApplied:false,taxiSign,spoiler,pickupBed,roofRack,cabrioSeats,stripe,fireEquipment,hoseCannon,fireWaterGroup,fireWaterSegments,fireWaterImpact,fireWaterImpactDisc,fireWaterImpactCore,fireWaterMist,fireWaterUp:new THREE.Vector3(0,1,0),fireWaterDirection:new THREE.Vector3(),fireWaterA:new THREE.Vector3(),fireWaterB:new THREE.Vector3(),towEquipment,towDeck,towEdges,towBoom:boom,towHookCable:hookCable,policeTurret,policeTurretGunPivot,policeTurretMuzzle,ambulanceRearDoors,ambulanceRearDoorPivots,medicalDoorOpen:0,helicopter,heliBody,tailBoom,rotor,newsCabin,newsStripe,newsLabels,newsLightPod,newsSearchLight,newsTarget:newsSearchTarget,newsSearchTarget,newsBeamPivot,newsBeamCone,contactShadow,damageFx,damageSmoke,damageFlames,bodyHoles,bodyHoleLayers,glassCracks,vehicleLength:L,vehicleHalfWidth:utility?1.551:1.401,wreckGroup,wreckShell,wreckCab,wreckDoor,wreckWheels,wreckHeat,wreckGlow,wreckFlames,wreckSmoke,wreckDebris,wreckBreakaway,lastPosition:new THREE.Vector3(v[0],0,v[1]),hitMarkSignature:''};car.position.set(v[0], 0, v[1]);car.visible=false;car.frustumCulled=false;scene.add(car);cars.push(car);
        car.userData.policeLivery=policeLivery;car.userData.policeTactical=policeTactical;car.userData.policeHeavy=policeHeavy;
      };
      const shareVehicleEffectMaterials=car=>{
        const ux=car.userData,s=sharedVehicleFxMaterials,oldDamageSmoke=ux.damageSmoke.mesh.material,oldDamageFlame=ux.damageFlames.mesh.material,oldMetal=ux.wreckShell.material,oldGlass=ux.wreckCab.material,oldHeat=ux.wreckHeat.material,oldWreckFlame=ux.wreckFlames.mesh.material,oldWreckSmoke=ux.wreckSmoke.mesh.material,oldWreckDebris=ux.wreckDebris.mesh.material,oldEdges=new Set();
        ux.wreckGroup.traverse(object=>{const material=object.material;if(material?.color?.getHex?.()===0x4c382b&&material.metalness>.7)oldEdges.add(material);});
        const replacements=new Map([[oldMetal,s.wreckMetal],[oldGlass,s.wreckGlass],[oldHeat,s.wreckHeat],[oldWreckFlame,s.wreckFlame],[oldWreckSmoke,s.wreckSmoke],[oldWreckDebris,s.wreckDebris],[oldDamageSmoke,s.damageSmoke],[oldDamageFlame,s.damageFlame]]);for(const material of oldEdges)replacements.set(material,s.wreckEdge);
        car.traverse(object=>{if(replacements.has(object.material))object.material=replacements.get(object.material);});
        for(const [pool,material] of [[ux.damageSmoke,s.damageSmoke],[ux.damageFlames,s.damageFlame],[ux.wreckFlames,s.wreckFlame],[ux.wreckSmoke,s.wreckSmoke],[ux.wreckDebris,s.wreckDebris]]){pool.mesh.material=material;pool.items.forEach(item=>item.material=material);}
        for(const material of replacements.keys())if(material&&!Object.values(s).includes(material))material.dispose();
      };
      vehicleSlotDefs.slice(0,INITIAL_VEHICLE_SYNC_CAP).forEach(def=>{createVehicleSlot(def);shareVehicleEffectMaterials(cars[cars.length-1]);});
      const deferredVehicleSlots=vehicleSlotDefs.slice(INITIAL_VEHICLE_SYNC_CAP);
      let vehicleSlotPumpStarted=false;
      const pumpDeferredVehicleSlots=()=>{
        const next=deferredVehicleSlots.shift();
        if(next){createVehicleSlot(next);shareVehicleEffectMaterials(cars[cars.length-1]);}
        renderer.domElement.dataset.vehicleSlots=`${cars.length}/${VEHICLE_RENDER_CAP}`;
        if(deferredVehicleSlots.length)setTimeout(pumpDeferredVehicleSlots,34);
        else if(materialCompileStarted&&!fullMaterialsReady)compileLoadedScene();
      };
      renderer.domElement.dataset.vehicleSlots=`${cars.length}/${VEHICLE_RENDER_CAP}`;
      startupMark('initial-vehicles');
      const medicalFrameMat=new THREE.MeshStandardMaterial({color:0xb8c7cf,metalness:.86,roughness:.2}),medicalMattressMat=new THREE.MeshStandardMaterial({color:0xeaf3f5,roughness:.62}),medicalBodyMat=new THREE.MeshStandardMaterial({color:0x485866,roughness:.72}),medicalSkinMat=new THREE.MeshStandardMaterial({color:0xd8a17d,roughness:.7}),medicalStrapMat=new THREE.MeshStandardMaterial({color:0xc92934,roughness:.52}),medicalBlanketMat=new THREE.MeshStandardMaterial({color:0xc9e4ec,roughness:.8}),medicalRubberMat=new THREE.MeshStandardMaterial({color:0x171b1e,roughness:.82}),medicalOxygenMat=new THREE.MeshStandardMaterial({color:0x1b9a83,metalness:.46,roughness:.3}),medicalCaseMat=new THREE.MeshStandardMaterial({color:0xd93b43,roughness:.48});
      const medicalScenePool=Array.from({length:4},()=>{
        const root=new THREE.Group(),frame=new THREE.Group(),mattress=new THREE.Mesh(new THREE.BoxGeometry(3,.18,1.18),medicalMattressMat);
        mattress.position.y=.86;mattress.castShadow=true;frame.add(mattress);
        for(const side of [-1,1]){const rail=new THREE.Mesh(new THREE.BoxGeometry(3.24,.1,.1),medicalFrameMat);rail.position.set(0,.78,side*.65);frame.add(rail);for(const x of [-1.25,1.25]){const handle=new THREE.Mesh(new THREE.CylinderGeometry(.035,.035,.34,7),medicalFrameMat);handle.rotation.z=Math.PI/2;handle.position.set(x+(x<0?-.12:.12),.8,side*.65);frame.add(handle);}}
        for(const x of [-1.18,1.18])for(const z of [-.56,.56]){const leg=new THREE.Mesh(new THREE.CylinderGeometry(.045,.045,.58,7),medicalFrameMat);leg.position.set(x,.48,z);frame.add(leg);const wheel=new THREE.Mesh(new THREE.TorusGeometry(.135,.05,7,12),medicalRubberMat);wheel.position.set(x,.19,z);wheel.rotation.y=Math.PI/2;frame.add(wheel);}
        const body=new THREE.Group(),torso=new THREE.Mesh(new THREE.BoxGeometry(1.05,.28,.76),medicalBodyMat),head=new THREE.Mesh(new THREE.SphereGeometry(.28,12,8),medicalSkinMat);
        torso.position.set(-.18,1.09,0);head.position.set(-.92,1.12,0);body.add(torso,head);
        for(const z of [-.23,.23]){const leg=new THREE.Mesh(new THREE.BoxGeometry(1.05,.18,.22),medicalBodyMat);leg.position.set(.82,1.06,z);body.add(leg);}
        const pillow=new THREE.Mesh(new THREE.BoxGeometry(.58,.13,.82),medicalMattressMat);pillow.position.set(-1.04,.98,0);body.add(pillow);pillow.renderOrder=-1;
        const blanket=new THREE.Mesh(new THREE.BoxGeometry(1.58,.12,.88),medicalBlanketMat);blanket.position.set(.36,1.25,0);body.add(blanket);
        for(const x of [-.35,.3]){const strap=new THREE.Mesh(new THREE.BoxGeometry(.13,.32,1),medicalStrapMat);strap.position.set(x,1.13,0);body.add(strap);}
        const cross=new THREE.Group();for(const geometry of [new THREE.BoxGeometry(.38,.025,.12),new THREE.BoxGeometry(.12,.025,.38)]){const mark=new THREE.Mesh(geometry,medicalStrapMat);mark.position.y=1.325;cross.add(mark);}cross.position.set(.35,0,0);
        const equipment=new THREE.Group(),oxygen=new THREE.Mesh(new THREE.CylinderGeometry(.15,.15,.82,12),medicalOxygenMat);oxygen.rotation.z=Math.PI/2;oxygen.position.set(.48,.48,0);equipment.add(oxygen);const valve=new THREE.Mesh(new THREE.CylinderGeometry(.06,.08,.14,8),medicalFrameMat);valve.rotation.z=Math.PI/2;valve.position.set(.96,.48,0);equipment.add(valve);const caseBody=new THREE.Mesh(new THREE.BoxGeometry(.58,.4,.46),medicalCaseMat);caseBody.position.set(-.4,.48,0);equipment.add(caseBody);for(const geometry of [new THREE.BoxGeometry(.18,.03,.055),new THREE.BoxGeometry(.055,.03,.18)]){const mark=new THREE.Mesh(geometry,medicalMattressMat);mark.position.set(-.4,.69,0);equipment.add(mark);}
        root.add(frame,body,cross,equipment);root.visible=false;root.frustumCulled=false;scene.add(root);return{root,frame,body,cross,equipment,wheels:frame.children.filter(x=>x.geometry?.type==='TorusGeometry'),lastPosition:new THREE.Vector3(),wheelRoll:0};
      });
      const syncCarSlots=sources=>{const wanted=new Map((sources||[]).map(src=>[String(src.id),src])),claimed=new Set();for(const car of cars){const id=car.userData.entityId;if(id!==null&&wanted.has(id)){car.userData.source=wanted.get(id);wanted.delete(id);claimed.add(car);}else{car.userData.entityId=null;car.userData.source=null;car.visible=false;}}for(const [id,src] of wanted){const car=cars.find(candidate=>!claimed.has(candidate)&&candidate.userData.entityId===null);if(!car)break;car.userData.entityId=id;car.userData.source=src;car.userData.lastPosition.set((src.c-originC)*WORLD_SCALE,0,(src.r-originR)*WORLD_SCALE);claimed.add(car);}};
      const updateVehicleHitMarks=(car,src,wrecked)=>{
        const ux=car.userData,L=ux.vehicleLength||5.8,W=ux.vehicleHalfWidth||1.4,sourceMarks=Array.isArray(src.bulletMarks)?src.bulletMarks:null,lastSourceMark=sourceMarks?.[sourceMarks.length-1],signature=`${ux.entityId}:${wrecked?1:0}:${src.helicopter?1:0}:${sourceMarks?.length||0}:${+lastSourceMark?.id||0}:${+src.bulletHoles||0}`;
        if(signature===ux.hitMarkSignature)return;ux.hitMarkSignature=signature;
        const marks=sourceMarks?sourceMarks.slice(-10):[];
        if(!marks.length&&+src.bulletHoles>0)for(let i=0;i<Math.min(10,+src.bulletHoles||0);i++)marks.push({id:i+1,u:-.72+(i%4)*.46,v:i<5?1:-1,y:.25+(i%3)*.22,panel:'side',surface:'metal',heavy:false});
        const metalMarks=marks.filter(m=>m.surface!=='glass'),glassMarks=marks.filter(m=>m.surface==='glass');
        for(const layer of ux.bodyHoleLayers){layer.mesh.visible=metalMarks.length>0&&!wrecked&&!src.helicopter;layer.forEach((hole,i)=>{const mark=metalMarks[i];hole.visible=!!mark&&!wrecked&&!src.helicopter;if(!hole.visible)return;const u=Math.max(-1,Math.min(1,+mark.u||0)),v=Math.max(-1,Math.min(1,+mark.v||0)),y=Math.max(.08,Math.min(.95,+mark.y||.5)),side=v>=0?1:-1,size=vehiclePunctureSizes[(+mark.id||i)%vehiclePunctureSizes.length]/vehicleMarkBaseRadius*(mark.heavy?1.12:1);hole.rotation.set(0,0,((+mark.id||i)*1.73)%Math.PI);hole.scale.setScalar(size);if(mark.panel==='front'||mark.panel==='rear'){const front=mark.panel==='front';hole.position.set((front?1:-1)*(L*.5+.095),.55+y*1.35,v*W*.84);hole.rotation.y=front?Math.PI/2:-Math.PI/2;}else{hole.position.set(u*L*.47,.52+y*1.42,side*(W+.095));hole.rotation.y=side>0?0:Math.PI;}});}
        ux.glassCracks.forEach((crack,i)=>{
          const mark=glassMarks[i];crack.visible=!!mark&&!wrecked&&!src.helicopter;if(!crack.visible)return;
          const u=Math.max(-1,Math.min(1,+mark.u||0)),v=Math.max(-1,Math.min(1,+mark.v||0)),side=v>=0?1:-1;
          crack.rotation.set(0,0,((+mark.id||i)*2.17)%Math.PI);crack.scale.setScalar(mark.heavy?1.28:1);
          if(mark.panel==='front'||mark.panel==='rear'){const front=mark.panel==='front';crack.position.set((front?1:-1)*L*(front ? .295 : .255),2.08,v*W*.7);crack.rotation.y=front?Math.PI/2:-Math.PI/2;}
          else{crack.position.set(u*L*.4,2.06,side*(W*.91+.018));crack.rotation.y=side>0?0:Math.PI;}
        });
      };
      const beamCanvas=document.createElement('canvas');beamCanvas.width=512;beamCanvas.height=192;const beamContext=beamCanvas.getContext('2d'),beamGradient=beamContext.createLinearGradient(0,0,512,0);beamGradient.addColorStop(0,'rgba(255,242,185,.5)');beamGradient.addColorStop(.42,'rgba(255,225,135,.18)');beamGradient.addColorStop(1,'rgba(255,220,120,0)');beamContext.fillStyle=beamGradient;beamContext.fillRect(0,0,512,192);const beamTexture=new THREE.CanvasTexture(beamCanvas);beamTexture.colorSpace=THREE.SRGBColorSpace;const vehicleBeamMaterial=new THREE.MeshBasicMaterial({map:beamTexture,color:0xffe7a0,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),vehicleLightBeams=new THREE.InstancedMesh(new THREE.PlaneGeometry(8.5,3.6),vehicleBeamMaterial,VEHICLE_RENDER_CAP),vehicleBeamMatrix=new THREE.Matrix4(),vehicleBeamQuat=new THREE.Quaternion(),vehicleBeamScale=new THREE.Vector3(1,1,1),vehicleBeamHidden=new THREE.Vector3(0,0,0);
      vehicleLightBeams.frustumCulled=false;vehicleLightBeams.renderOrder=8;scene.add(vehicleLightBeams);let environmentNight=0,environmentLampPower=0;const newsBeamDown=new THREE.Vector3(0,-1,0),newsBeamDirection=new THREE.Vector3();
      const updateVehicleBeams=()=>{vehicleBeamMaterial.opacity=environmentNight*.24;cars.forEach((car,i)=>{const src=car.userData.source,shown=car.visible&&src&&!src.helicopter&&environmentNight>.04;if(!shown){vehicleBeamMatrix.compose(new THREE.Vector3(0,-1000,0),vehicleBeamQuat.identity(),vehicleBeamHidden);vehicleLightBeams.setMatrixAt(i,vehicleBeamMatrix);return;}const yaw=car.rotation.y,fx=Math.cos(yaw),fz=-Math.sin(yaw);vehicleBeamQuat.setFromEuler(new THREE.Euler(-Math.PI/2,0,-yaw));vehicleBeamMatrix.compose(new THREE.Vector3(car.position.x+fx*5.2,.09,car.position.z+fz*5.2),vehicleBeamQuat,vehicleBeamScale);vehicleLightBeams.setMatrixAt(i,vehicleBeamMatrix);});vehicleLightBeams.instanceMatrix.needsUpdate=true;};
      const NPC_CAP=72,REMOTE_CAP=12,BULLET_CAP=48,hiddenScale=new THREE.Vector3(0,0,0),unitScale=new THREE.Vector3(1,1,1),npcScale=new THREE.Vector3(1.32,1.32,1.32),instanceMatrix=new THREE.Matrix4(),rootMatrix=new THREE.Matrix4(),localMatrix=new THREE.Matrix4(),instanceQuat=new THREE.Quaternion(),instanceColor=new THREE.Color(),instancePosition=new THREE.Vector3(),instanceScale=new THREE.Vector3(),instanceEuler=new THREE.Euler(),trailPosition=new THREE.Vector3();
      const npcElevationLookup=new Map(),rootMatrixSetPosition=rootMatrix.setPosition.bind(rootMatrix);rootMatrix.setPosition=(x,y,z)=>rootMatrixSetPosition(x,y+(npcElevationLookup.get(`${(+x).toFixed(3)}:${(+z).toFixed(3)}`)||0),z);
      const eyeScale=new THREE.Vector3(1,.78,.42),pupilScale=new THREE.Vector3(1,.78,.3),npcBodyScale=new THREE.Vector3(1,1,1),gangAuraScale=new THREE.Vector3(1.3,1.3,1.3),npcLimbOffset=new THREE.Vector3(),npcElbowOffset=new THREE.Vector3(),npcForearmOffset=new THREE.Vector3(),npcLimbQuat=new THREE.Quaternion();
      const NPC_BODY_PROFILES=[
        {bodyX:.8,bodyZ:.76,shoulder:.84,arm:.8,leg:.8,hip:.86},
        {bodyX:1,bodyZ:1,shoulder:1,arm:1,leg:1,hip:1},
        {bodyX:1.22,bodyZ:1.28,shoulder:1.13,arm:1.16,leg:1.14,hip:1.16},
        {bodyX:1.18,bodyZ:1.08,shoulder:1.2,arm:1.2,leg:1.08,hip:1.08}
      ];
      // Characters still cast a grounding shadow, but do not receive the huge
      // building shadow maps. At sunset those maps covered the whole small
      // model and turned every skin/clothing instance into a black silhouette.
      const makeInstances=(geometry,material,count,castShadow=true)=>{material.vertexColors=geometry.hasAttribute('color');const mesh=new THREE.InstancedMesh(geometry,material,count),defaultInstanceColor=new THREE.Color(0xffffff);mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.castShadow=castShadow;mesh.receiveShadow=false;mesh.layers.enable(1);mesh.frustumCulled=false;for(let i=0;i<count;i++){instanceMatrix.compose(new THREE.Vector3(0,-1000,0),instanceQuat,hiddenScale);mesh.setMatrixAt(i,instanceMatrix);mesh.setColorAt(i,defaultInstanceColor);}mesh.instanceMatrix.needsUpdate=true;mesh.instanceColor.setUsage(THREE.DynamicDrawUsage);mesh.instanceColor.needsUpdate=true;material.needsUpdate=true;scene.add(mesh);return mesh;};
      // Repeated street furniture is authored for the high isometric camera:
      // broad crowns and bright hydrants read clearly without hundreds of meshes.
      const blackmarketPois=(worldSnapshot?.pois||[]).filter(p=>String(p.id||'').startsWith('blackmarket'));
      const streetTreeDefs=[],hydrantDefs=[],bollardDefs=[],benchDefs=[];buildingDefs.forEach((b,i)=>{const [x,z,w,d,,style,,districtStyle,sourceMeta]=b,marketBuilding=blackmarketPois.some(p=>p.r>=sourceMeta?.minR&&p.r<=sourceMeta?.maxR&&p.c>=sourceMeta?.minC&&p.c<=sourceMeta?.maxC);if(!marketBuilding&&(districtStyle==='rich'||districtStyle==='coast'||districtStyle==='countryside'||i%5===0)&&streetTreeDefs.length<42)streetTreeDefs.push([x+w/2+2.2,z+d*.28,.8+(i%3)*.1]);if(districtStyle!=='countryside'&&i%4===1&&hydrantDefs.length<72)hydrantDefs.push([x-w/2-1.45,z+d*.3]);if((districtStyle==='downtown'||districtStyle==='nightlife')&&i%3===0&&bollardDefs.length<48)for(const dz of [-2.2,0,2.2])bollardDefs.push([x+w/2+1.2,z+dz]);if((districtStyle==='rich'||districtStyle==='coast'||i%9===0)&&benchDefs.length<22)benchDefs.push([x-w*.25,z+d/2+1.55,i%2?0:Math.PI]);});
      const staticInstances=(geo,mat,defs,place)=>{const mesh=new THREE.InstancedMesh(geo,mat,defs.length);mesh.castShadow=true;mesh.receiveShadow=true;defs.forEach((def,i)=>{place(def,i);mesh.setMatrixAt(i,instanceMatrix);});mesh.instanceMatrix.needsUpdate=true;scene.add(mesh);return mesh;};
      staticInstances(new THREE.CylinderGeometry(.18,.42,4.2,10),windTrunkMaterial(0x75482d),streetTreeDefs,([x,z,s])=>instanceMatrix.compose(new THREE.Vector3(x,2.1*s,z),instanceQuat.identity(),new THREE.Vector3(s,s,s)));
      staticInstances(new THREE.DodecahedronGeometry(1.8,1),windLeafMaterial(0x287848),streetTreeDefs,([x,z,s])=>instanceMatrix.compose(new THREE.Vector3(x,4.45*s,z),instanceQuat.identity(),new THREE.Vector3(s*1.16,s,s*1.12)));
      staticInstances(new THREE.IcosahedronGeometry(1.34,1),windLeafMaterial(0x47a45f),streetTreeDefs,([x,z,s],i)=>instanceMatrix.compose(new THREE.Vector3(x+(i%2?1:-1)*.78*s,4.82*s,z+(i%3-1)*.42*s),instanceQuat.identity(),new THREE.Vector3(s,s*.9,s)));
      staticInstances(new THREE.DodecahedronGeometry(1.05,0),windLeafMaterial(0x70ba63),streetTreeDefs,([x,z,s],i)=>instanceMatrix.compose(new THREE.Vector3(x-(i%2?1:-1)*.7*s,5.15*s,z+(i%3-1)*.55*s),instanceQuat.identity(),new THREE.Vector3(s*.92,s*.78,s*.92)));
      renderer.domElement.dataset.treeWind=`${windLeafMaterials.length}:gpu-sway-branches-trunks-gusts-v3`;renderer.domElement.dataset.fallingLeaves=`${leafCount}:detach-fall-drift-rest`;
      const treeAoMaterial=contactShadowMaterial.clone();treeAoMaterial.opacity=.2;const treeAo=new THREE.InstancedMesh(new THREE.PlaneGeometry(4.8,4.2),treeAoMaterial,streetTreeDefs.length),treeAoQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0));streetTreeDefs.forEach(([x,z,s],i)=>{instanceMatrix.compose(new THREE.Vector3(x,.061,z),treeAoQuat,new THREE.Vector3(s,s,1));treeAo.setMatrixAt(i,instanceMatrix);});treeAo.instanceMatrix.needsUpdate=true;sealStaticInstanceBounds(treeAo);treeAo.renderOrder=3;scene.add(treeAo);
      staticInstances(new THREE.CylinderGeometry(.13,.18,1.1,8),new THREE.MeshStandardMaterial({color:0x202a32,roughness:.45,metalness:.62}),bollardDefs,([x,z])=>instanceMatrix.compose(new THREE.Vector3(x,.55,z),instanceQuat.identity(),unitScale));
      const benchMat=new THREE.MeshStandardMaterial({color:0x8a532f,roughness:.8});staticInstances(new THREE.BoxGeometry(3.4,.28,.8),benchMat,benchDefs,([x,z,a])=>instanceMatrix.compose(new THREE.Vector3(x,.78,z),instanceQuat.setFromAxisAngle(new THREE.Vector3(0,1,0),a),unitScale));staticInstances(new THREE.BoxGeometry(3.4,1.15,.22),benchMat,benchDefs,([x,z,a])=>{instanceQuat.setFromAxisAngle(new THREE.Vector3(0,1,0),a);const side=new THREE.Vector3(Math.sin(a)*.38,0,Math.cos(a)*.38);instanceMatrix.compose(new THREE.Vector3(x+side.x,1.45,z+side.z),instanceQuat,unitScale);});
      // Detailed shootable hydrants. A hit removes the cap and starts a timed
      // pressure jet with droplets and a ground splash.
      const hydrantRed=new THREE.MeshStandardMaterial({color:0xd93632,roughness:.42,metalness:.32}),hydrantMetal=new THREE.MeshStandardMaterial({color:0xb8a76e,roughness:.28,metalness:.82}),hydrantDark=new THREE.MeshStandardMaterial({color:0x3b3330,roughness:.42,metalness:.7}),waterJetBase=new THREE.MeshBasicMaterial({color:0x8eeaff,transparent:true,opacity:.72,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}),hydrantActors=[];
      for(const [x,z] of hydrantDefs.sort((a,b)=>a[0]*a[0]+a[1]*a[1]-b[0]*b[0]-b[1]*b[1]).slice(0,28)){const root=new THREE.Group();root.position.set(x,0,z);root.rotation.y=((Math.abs(Math.round(x*13+z*7))%4)*Math.PI)/2;scene.add(root);const add=(geo,mat,px,py,pz)=>{const m=new THREE.Mesh(geo,mat);m.position.set(px,py,pz);m.castShadow=m.receiveShadow=true;root.add(m);return m;};add(new THREE.CylinderGeometry(.34,.44,.28,16),hydrantDark,0,.14,0);add(new THREE.CylinderGeometry(.3,.36,1.28,14),hydrantRed,0,.88,0);add(new THREE.CylinderGeometry(.45,.45,.16,16),hydrantMetal,0,1.5,0);const dome=add(new THREE.SphereGeometry(.36,14,9,0,Math.PI*2,0,Math.PI/2),hydrantRed,0,1.58,0),cap=add(new THREE.CylinderGeometry(.24,.29,.25,12),hydrantMetal,.45,1.02,0);cap.rotation.z=Math.PI/2;const rear=add(new THREE.CylinderGeometry(.2,.25,.22,12),hydrantDark,-.39,1.02,0);rear.rotation.z=Math.PI/2;for(let k=0;k<6;k++){const bolt=add(new THREE.SphereGeometry(.055,7,5),hydrantMetal,Math.cos(k*Math.PI/3)*.34,.55,Math.sin(k*Math.PI/3)*.34);bolt.castShadow=false;}const jetMat=waterJetBase.clone(),jet=add(new THREE.CylinderGeometry(.12,.34,6.2,12,1,true),jetMat,3.35,1.08,0);jet.rotation.z=Math.PI/2;jet.visible=false;jet.castShadow=jet.receiveShadow=false;const splash=new THREE.Mesh(new THREE.RingGeometry(.55,1.45,28),jetMat.clone());splash.rotation.x=-Math.PI/2;splash.position.set(6.35,.08,0);splash.visible=false;root.add(splash);const drops=[];for(let i=0;i<9;i++){const drop=new THREE.Mesh(new THREE.SphereGeometry(.09+(i%3)*.025,7,5),jetMat.clone());drop.visible=false;root.add(drop);drops.push(drop);}hydrantActors.push({root,cap,dome,jet,splash,drops,x,z,activeUntil:0,hitAt:0});}
      const hitHydrantWithShot=(origin,dir,now)=>{let best=null,bestAlong=38;for(const h of hydrantActors){const dx=h.x-origin.x,dz=h.z-origin.z,along=dx*dir.x+dz*dir.z;if(along<0||along>bestAlong)continue;const side=Math.abs(dx*dir.z-dz*dir.x);if(side<1.05){best=h;bestAlong=along;}}if(!best)return false;best.activeUntil=Math.max(best.activeUntil,now+12000);best.hitAt=now;best.cap.visible=false;renderer.domElement.dataset.lastHydrantHit=`${best.x.toFixed(1)}:${best.z.toFixed(1)}`;return true;};

      // Cast-iron manholes are generated only on authoritative asphalt tiles.
      // Each has a recessed rim, radial bolts and three independent steam wisps.
      const manholeActors=[],manholeIron=new THREE.MeshStandardMaterial({color:0x30383d,roughness:.54,metalness:.76}),manholeGroove=new THREE.MeshStandardMaterial({color:0x151b1f,roughness:.7,metalness:.5}),steamTexture=particleTexture('rgba(225,238,240,.58)','rgba(145,165,172,.08)');
      const mapRows=envSnapshot?.mapRows||worldSnapshot?.bounds?.maxR||80,mapCols=envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||200;
      const streetManholeDefs=[];for(let r=5;r<mapRows-3;r+=9)for(let c=7;c<mapCols-3;c+=13){if(bridge?.collisionProbe?.(r+.5,c+.5)?.tile!==0)continue;const x=(c+.5-originC)*WORLD_SCALE,z=(r+.5-originR)*WORLD_SCALE;streetManholeDefs.push({r,c,x,z,d:x*x+z*z});}for(const {r,c,x,z} of streetManholeDefs.sort((a,b)=>a.d-b.d).slice(0,18)){const root=new THREE.Group();root.position.set(x,.09,z);scene.add(root);const rim=new THREE.Mesh(new THREE.TorusGeometry(.92,.14,10,28),manholeIron);rim.rotation.x=Math.PI/2;rim.castShadow=true;root.add(rim);const lid=new THREE.Mesh(new THREE.CylinderGeometry(.82,.82,.12,28),manholeGroove);lid.position.y=.01;root.add(lid);for(let k=0;k<8;k++){const a=k*Math.PI/4,bolt=new THREE.Mesh(new THREE.CylinderGeometry(.045,.045,.05,7),manholeIron);bolt.position.set(Math.cos(a)*.62,.09,Math.sin(a)*.62);root.add(bolt);}for(let k=-2;k<=2;k++){const groove=new THREE.Mesh(new THREE.BoxGeometry(1.18,.035,.055),manholeIron);groove.position.set(0,.085,k*.2);groove.rotation.y=(r+c)%2?0:Math.PI/2;root.add(groove);}const wisps=[];for(let i=0;i<3;i++){const mat=new THREE.SpriteMaterial({map:steamTexture,color:0xdce8e8,transparent:true,opacity:.2,depthWrite:false,blending:THREE.NormalBlending}),sprite=new THREE.Sprite(mat);sprite.scale.set(1.2,1.65,1);root.add(sprite);wisps.push(sprite);}manholeActors.push({root,wisps,seed:r*31+c*17});}

      // A persistent flock alternates between formation flight, approach,
      // rooftop rest and take-off. Roof anchors come from the actual buildings.
      const roofBirdTargets=buildingDefs.filter(b=>b[8]?.primary!==false).sort((a,b)=>a[0]*a[0]+a[1]*a[1]-b[0]*b[0]-b[1]*b[1]).slice(0,28).map(([x,z,w,d,rawH,,, ,meta],i)=>({x:x+((i%3)-1)*Math.min(2,w*.12),z:z+((i%2)-.5)*Math.min(2,d*.12),y:(architecturalHeights[meta?.architecturalKind]||rawH)+1.15})),birdPalette=[new THREE.MeshStandardMaterial({color:0x26313b,roughness:.74}),new THREE.MeshStandardMaterial({color:0x8c9698,roughness:.68}),new THREE.MeshStandardMaterial({color:0xd8d1c2,roughness:.72})],birdBeak=new THREE.MeshStandardMaterial({color:0xd8a342,roughness:.6}),birdEye=new THREE.MeshBasicMaterial({color:0x090b0c,toneMapped:false}),birdBodyGeo=new THREE.SphereGeometry(.32,12,8),birdHeadGeo=new THREE.SphereGeometry(.19,10,7),birdWingGeo=new THREE.BufferGeometry(),birdTailGeo=new THREE.BufferGeometry(),flock=[];
      birdWingGeo.setAttribute('position',new THREE.Float32BufferAttribute([0,0,0,-.25,.03,.08,-.82,.01,.62,-.62,.02,.12,-.18,.02,.02],3));birdWingGeo.setIndex([0,1,2,0,2,3,0,3,4]);birdWingGeo.computeVertexNormals();birdTailGeo.setAttribute('position',new THREE.Float32BufferAttribute([0,0,0,-.72,.02,.28,-.64,.01,0,-.72,.02,-.28],3));birdTailGeo.setIndex([0,1,2,0,2,3]);birdTailGeo.computeVertexNormals();
      for(let i=0;i<11;i++){const root=new THREE.Group(),animal=new THREE.Group(),mat=birdPalette[i%birdPalette.length],body=new THREE.Mesh(birdBodyGeo,mat);body.scale.set(1.55,.74,.76);animal.add(body);const headBird=new THREE.Mesh(birdHeadGeo,mat);headBird.position.set(.43,.09,0);animal.add(headBird);const beak=new THREE.Mesh(new THREE.ConeGeometry(.065,.3,7),birdBeak);beak.rotation.z=-Math.PI/2;beak.position.set(.67,.07,0);animal.add(beak);for(const side of [-1,1]){const eye=new THREE.Mesh(new THREE.SphereGeometry(.028,6,5),birdEye);eye.position.set(.555,.135,side*.155);animal.add(eye);}const leftWing=new THREE.Group(),rightWing=new THREE.Group(),leftFeather=new THREE.Mesh(birdWingGeo,mat),rightFeather=new THREE.Mesh(birdWingGeo,mat);leftFeather.rotation.x=Math.PI/2;rightFeather.rotation.x=-Math.PI/2;rightFeather.scale.z=-1;leftWing.add(leftFeather);rightWing.add(rightFeather);leftWing.position.z=.12;rightWing.position.z=-.12;animal.add(leftWing,rightWing);const tail=new THREE.Mesh(birdTailGeo,mat);tail.position.x=-.38;tail.rotation.x=Math.PI/2;animal.add(tail);root.add(animal);root.scale.setScalar(.78+(i%3)*.09);scene.add(root);flock.push({root,animal,leftWing,rightWing,tail,offsetX:(i%4-1.5)*1.2,offsetZ:(Math.floor(i/4)-1)*1.05,phase:i*.71,timeOffset:i*2.37+(i%3)*.81});}
      const updateStreetLife=t=>{for(const h of hydrantActors){const active=t<h.activeUntil,pulse=.9+Math.sin(t*.025+h.x)*.08;h.jet.visible=h.splash.visible=active;if(active){h.jet.scale.set(pulse,1,pulse);h.jet.material.opacity=.58+Math.sin(t*.018)*.13;h.splash.scale.setScalar(.9+Math.sin(t*.012)*.18);for(let i=0;i<h.drops.length;i++){const drop=h.drops[i],u=((t-h.hitAt)*(.00055+i*.00007)+i*.113)%1;drop.visible=true;drop.position.set(.7+u*6.2,1.05+Math.sin(u*Math.PI)*(2.5+(i%3)*.35),((i%3)-1)*.24+Math.sin(t*.01+i)*.12);drop.scale.setScalar(.65+(1-u)*.55);}}else for(const drop of h.drops)drop.visible=false;}
        for(const m of manholeActors)for(let i=0;i<m.wisps.length;i++){const w=m.wisps[i],u=((t*.00013+i*.31+m.seed*.001)%1);w.position.set(Math.sin(t*.0008+m.seed+i)*.28,u*4.3,Math.cos(t*.00065+m.seed-i)*.24);w.scale.set(1.05+u*1.5,1.35+u*2.1,1);w.material.opacity=Math.sin(u*Math.PI)*(.12+i*.035);}
        if(roofBirdTargets.length){const cycle=38,seconds=t*.001;for(let i=0;i<flock.length;i++){const b=flock[i],local=seconds+b.timeOffset,phase=local%cycle,targetIndex=Math.floor(local/cycle)%roofBirdTargets.length,previous=roofBirdTargets[(targetIndex+roofBirdTargets.length-1)%roofBirdTargets.length],target=roofBirdTargets[targetIndex],formation=.62+i*.024,approach=phase>=18&&phase<22,perched=phase>=22&&phase<31,takeoff=phase>=31;if(phase<18){const u=THREE.MathUtils.smoothstep(phase/18,0,1),arc=Math.sin(u*Math.PI)*(15+(i%4)*1.7),bank=Math.sin(u*Math.PI*2+b.phase);b.root.position.set(THREE.MathUtils.lerp(previous.x,target.x,u)+b.offsetX*formation+Math.sin(local*.37+b.phase)*1.2,THREE.MathUtils.lerp(previous.y+9,target.y+8,u)+arc+i*.14,THREE.MathUtils.lerp(previous.z,target.z,u)+b.offsetZ*formation+Math.cos(local*.31+b.phase)*.9);b.animal.rotation.z=bank*.16;}else if(approach){const u=THREE.MathUtils.smoothstep((phase-18)/4,0,1);b.root.position.set(THREE.MathUtils.lerp(target.x+b.offsetX,target.x+b.offsetX*.3,u),THREE.MathUtils.lerp(target.y+8+i*.12,target.y+.08,u),THREE.MathUtils.lerp(target.z+b.offsetZ,target.z+b.offsetZ*.3,u));b.animal.rotation.z*=.82;}else if(perched){b.root.position.set(target.x+b.offsetX*.3,target.y+.08+Math.sin(t*.0017+b.phase)*.018,target.z+b.offsetZ*.3);b.animal.rotation.z=0;b.animal.rotation.x=THREE.MathUtils.lerp(b.animal.rotation.x,.08,.08);b.root.rotation.y=(i%3-1)*.35+Math.sin(local*.24+b.phase)*.18;}else{const u=THREE.MathUtils.smoothstep((phase-31)/7,0,1);b.root.position.set(target.x+b.offsetX*(.3+u),target.y+u*(12+(i%3))+Math.sin(u*Math.PI)*2,target.z+b.offsetZ*(.3+u)-u*11);b.animal.rotation.x=THREE.MathUtils.lerp(b.animal.rotation.x,-.12,.12);}const glide=!perched&&(Math.sin(local*.72+b.phase)>.38),flap=perched?.08:glide?.18:Math.sin(t*.015+b.phase)*.92;b.leftWing.rotation.x=flap;b.rightWing.rotation.x=-flap;b.tail.rotation.y=perched?0:Math.sin(local*.85+b.phase)*.12;if(!perched)b.root.rotation.y=Math.atan2(target.x-previous.x,target.z-previous.z)+Math.sin(local*.21+b.phase)*.08;}}
      };
      // One authored silhouette is shared by the complete population. The
      // lathed profile adds neck, shoulders, chest and waist without another
      // mesh or draw call per NPC; X/Z body profiles still provide variety.
      const npcTorsoGeometry=new THREE.LatheGeometry([
        new THREE.Vector2(.36,-.88),new THREE.Vector2(.43,-.68),new THREE.Vector2(.39,-.26),
        new THREE.Vector2(.48,.22),new THREE.Vector2(.58,.55),new THREE.Vector2(.55,.7),
        new THREE.Vector2(.28,.86)
      ],14);npcTorsoGeometry.computeVertexNormals();
      const npcShirtPanelGeometry=new THREE.BoxGeometry(.76,1.12,.05);{
        const p=npcShirtPanelGeometry.attributes.position;for(let v=0;v<p.count;v++){const y=p.getY(v),waist=THREE.MathUtils.lerp(.78,1,THREE.MathUtils.clamp((y+.56)/1.12,0,1));p.setX(v,p.getX(v)*waist);}p.needsUpdate=true;npcShirtPanelGeometry.computeVertexNormals();
      }
      const npcCollarGeometry=new THREE.BufferGeometry();npcCollarGeometry.setAttribute('position',new THREE.Float32BufferAttribute([-.34,.16,0,-.04,.16,0,-.02,-.22,0,.34,.16,0,.04,.16,0,.02,-.22,0],3));npcCollarGeometry.setIndex([0,2,1,3,4,5]);npcCollarGeometry.computeVertexNormals();
      const npcParts={
        body:makeInstances(npcTorsoGeometry,new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.7,metalness:0,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP),
        head:makeInstances(new THREE.SphereGeometry(.44,14,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.84,metalness:0,emissive:0x24160f,emissiveIntensity:.38}),NPC_CAP),
        jaw:makeInstances(new THREE.SphereGeometry(.34,12,8),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.84,emissive:0x24160f,emissiveIntensity:.3}),NPC_CAP,false),
        beard:makeInstances(new THREE.SphereGeometry(.445,12,6,0,Math.PI*2,Math.PI*.5,Math.PI*.5),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.94,emissive:0x0d0b09,emissiveIntensity:.3}),NPC_CAP,false),
        shirtFront:makeInstances(npcShirtPanelGeometry,new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.72}),NPC_CAP,false),
        collar:makeInstances(npcCollarGeometry,new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.66}),NPC_CAP,false),
        leftLeg:makeInstances(new THREE.CapsuleGeometry(.19,.87,5,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP),
        rightLeg:makeInstances(new THREE.CapsuleGeometry(.19,.87,5,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP),
        leftArm:makeInstances(new THREE.CapsuleGeometry(.15,.52,5,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.76,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP),
        rightArm:makeInstances(new THREE.CapsuleGeometry(.15,.52,5,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.76,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP),
        forearm:makeInstances(new THREE.CapsuleGeometry(.135,.44,5,10),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.76,emissive:0x15181d,emissiveIntensity:.42}),NPC_CAP*2),
        hand:makeInstances(new THREE.SphereGeometry(.18,10,8),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.72,emissive:0x211611,emissiveIntensity:.3}),NPC_CAP*2),
        nose:makeInstances(new THREE.ConeGeometry(.065,.19,8),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.76}),NPC_CAP,false),
        mouth:makeInstances(new THREE.BoxGeometry(.2,.035,.025),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8}),NPC_CAP,false),
        brow:makeInstances(new THREE.BoxGeometry(.18,.035,.025),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.86}),NPC_CAP*2,false),
        ear:makeInstances(new THREE.SphereGeometry(.1,8,6),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8}),NPC_CAP*2,false),
        femaleLashes:makeInstances(new THREE.BoxGeometry(.46,.025,.025),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8}),NPC_CAP,false),
        femaleLips:makeInstances(new THREE.BoxGeometry(.2,.055,.028),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.62}),NPC_CAP,false),
        femaleHips:makeInstances(new THREE.SphereGeometry(.49,12,8),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.8}),NPC_CAP),
        roleHem:makeInstances(new THREE.CylinderGeometry(.48,.58,.82,12),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.78,emissive:0x11151a,emissiveIntensity:.3}),NPC_CAP),
        hat:makeInstances(new THREE.CylinderGeometry(.52,.58,.3,12),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.7,emissive:0x111418,emissiveIntensity:.42}),NPC_CAP),
        hatBrim:makeInstances(new THREE.CylinderGeometry(.76,.76,.09,16),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.7,emissive:0x111418,emissiveIntensity:.42}),NPC_CAP),
        gun:makeInstances(new THREE.BoxGeometry(.2,.24,1.05),darkMat,NPC_CAP),
        uniqueGunBody:makeInstances(new THREE.BoxGeometry(.42,.34,1.15),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.38,metalness:.56,emissive:0x181818,emissiveIntensity:.5}),NPC_CAP,false),
        uniqueGunRail:makeInstances(new THREE.BoxGeometry(.12,.12,1.42),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.2,metalness:.88,emissive:0x222222,emissiveIntensity:.7}),NPC_CAP,false),
        uniqueGunCharm:makeInstances(new THREE.OctahedronGeometry(.16,0),new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,toneMapped:false}),NPC_CAP,false),
        uniqueGunStock:makeInstances(new THREE.BoxGeometry(.34,.32,.72),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.38,metalness:.64,emissive:0x171717,emissiveIntensity:.52}),NPC_CAP,false),
        uniqueGunMuzzle:makeInstances(new THREE.CylinderGeometry(.1,.14,.46,8),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.2,metalness:.88,emissive:0x222222,emissiveIntensity:.7}),NPC_CAP,false),
        uniqueGunGrip:makeInstances(new THREE.BoxGeometry(.24,.62,.28),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.62,metalness:.3}),NPC_CAP,false),
        uniqueGunDrum:makeInstances(new THREE.CylinderGeometry(.32,.32,.22,14),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.34,metalness:.72}),NPC_CAP,false),
        uniqueGunBlade:makeInstances(new THREE.ConeGeometry(.16,.72,4),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.18,metalness:.92}),NPC_CAP,false),
        uniqueGunLimb:makeInstances(new THREE.BoxGeometry(.13,.16,1.18),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.42,metalness:.58}),NPC_CAP*2,false),
        uniqueGunSpike:makeInstances(new THREE.ConeGeometry(.075,.34,6),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.2,metalness:.9}),NPC_CAP*4,false),
        phone:makeInstances(new THREE.BoxGeometry(.18,.42,.07),new THREE.MeshStandardMaterial({color:0x111820,roughness:.28,metalness:.35,emissive:0x3ca8d8,emissiveIntensity:.35}),NPC_CAP,false),
        wound:makeInstances(new THREE.SphereGeometry(.18,9,7),new THREE.MeshBasicMaterial({color:0x8f0710,toneMapped:false}),NPC_CAP,false),
        bloodDrop:makeInstances(new THREE.SphereGeometry(.075,8,6),new THREE.MeshBasicMaterial({color:0xbd0c18,toneMapped:false}),NPC_CAP,false),
        gangBand:makeInstances(new THREE.BoxGeometry(1.24,.24,.8),new THREE.MeshBasicMaterial({color:0xffffff,toneMapped:false}),NPC_CAP,false),
        gangAura:makeInstances(new THREE.RingGeometry(1.05,1.42,28),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.82,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}),NPC_CAP,false),
        securityBadge:makeInstances(new THREE.BoxGeometry(.32,.36,.07),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.32,metalness:.7,emissive:0x5a3b08,emissiveIntensity:.42}),NPC_CAP,false),
        policeBelt:makeInstances(new THREE.BoxGeometry(1.28,.2,.84),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.58,metalness:.24}),NPC_CAP,false),
        policeRadio:makeInstances(new THREE.BoxGeometry(.2,.42,.13),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.45,metalness:.38}),NPC_CAP,false),
        policePatch:makeInstances(new THREE.BoxGeometry(.16,.3,.08),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.36,metalness:.2,emissive:0x12385a,emissiveIntensity:.32}),NPC_CAP*2,false),
        ownerLapel:makeInstances(new THREE.BoxGeometry(.28,.82,.08),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.42,metalness:.12,emissive:0x18130d,emissiveIntensity:.3}),NPC_CAP*2,false),
        ownerPocket:makeInstances(new THREE.BoxGeometry(.3,.12,.075),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.32,metalness:.2,emissive:0x211608,emissiveIntensity:.36}),NPC_CAP,false)
      };
      npcParts.eyeWhite=makeInstances(new THREE.SphereGeometry(.105,10,7),new THREE.MeshBasicMaterial({color:0xf8fbff,toneMapped:false}),NPC_CAP*2,false);npcParts.pupil=makeInstances(new THREE.SphereGeometry(.052,8,6),new THREE.MeshBasicMaterial({color:0x17212b,toneMapped:false}),NPC_CAP*2,false);npcParts.hair=makeInstances(new THREE.SphereGeometry(.455,12,8,0,Math.PI*2,0,Math.PI*.48),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.9,emissive:0x11100f,emissiveIntensity:.38}),NPC_CAP,false);npcParts.hairBun=makeInstances(new THREE.SphereGeometry(.24,10,7),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.9,emissive:0x11100f,emissiveIntensity:.38}),NPC_CAP,false);npcParts.hairMohawk=makeInstances(new THREE.BoxGeometry(.16,.42,.72),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.88,emissive:0x11100f,emissiveIntensity:.38}),NPC_CAP,false);npcParts.hairCurls=makeInstances(new THREE.SphereGeometry(.18,9,7),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.9,emissive:0x11100f,emissiveIntensity:.38}),NPC_CAP*4,false);npcParts.shoe=makeInstances(new THREE.CapsuleGeometry(.17,.38,4,8).rotateX(Math.PI/2),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.6,metalness:.08,emissive:0x101216,emissiveIntensity:.4}),NPC_CAP*2,false);
      npcParts.glasses=makeInstances(new THREE.BoxGeometry(.58,.12,.08),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.24,metalness:.45,emissive:0x10151a,emissiveIntensity:.5}),NPC_CAP,false);npcParts.eyePatch=makeInstances(new THREE.SphereGeometry(.115,9,6),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.76}),NPC_CAP,false);npcParts.chain=makeInstances(new THREE.TorusGeometry(.34,.04,6,18,Math.PI),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.24,metalness:.72}),NPC_CAP,false);npcParts.neckAccent=makeInstances(new THREE.ConeGeometry(.11,.52,4),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.7,emissive:0x161414,emissiveIntensity:.42}),NPC_CAP,false);npcParts.bag=makeInstances(new THREE.BoxGeometry(.52,.68,.24),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.82,metalness:.04,emissive:0x15110e,emissiveIntensity:.34}),NPC_CAP,false);npcParts.moustache=makeInstances(new THREE.BoxGeometry(.3,.075,.055),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.94,emissive:0x0d0b09,emissiveIntensity:.36}),NPC_CAP,false);
      npcParts.ownerHairSide=makeInstances(new THREE.BoxGeometry(.22,.26,.66),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.82,emissive:0x11100f,emissiveIntensity:.4}),NPC_CAP,false);npcParts.ownerHairBack=makeInstances(new THREE.BoxGeometry(.56,.38,.18),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.86,emissive:0x11100f,emissiveIntensity:.38}),NPC_CAP,false);npcParts.ownerHairQuiff=makeInstances(new THREE.SphereGeometry(.25,10,7),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.82,emissive:0x11100f,emissiveIntensity:.4}),NPC_CAP,false);
      // Prison-only tactical kit. Guards receive the full riot set with a
      // shield; police alternate between cap, tactical helmet and bare head.
      npcParts.prisonHelmet=makeInstances(new THREE.SphereGeometry(.58,14,9,0,Math.PI*2,0,Math.PI*.62),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.48,metalness:.18,emissive:0x101713,emissiveIntensity:.34}),NPC_CAP,false);
      npcParts.prisonHelmetBand=makeInstances(new THREE.CylinderGeometry(.59,.6,.18,14),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.42,metalness:.3}),NPC_CAP,false);
      npcParts.prisonVisor=makeInstances(new THREE.BoxGeometry(.82,.24,.075),new THREE.MeshPhysicalMaterial({color:0x8ccde2,transparent:true,opacity:.62,roughness:.08,metalness:.12,depthWrite:false,clearcoat:1}),NPC_CAP,false);
      npcParts.prisonVest=makeInstances(new THREE.BoxGeometry(1.36,1.42,.84),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.68,metalness:.16,emissive:0x10151a,emissiveIntensity:.3}),NPC_CAP,false);
      npcParts.riotShield=makeInstances(new THREE.BoxGeometry(1.08,1.9,.16),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.36,metalness:.62,emissive:0x101820,emissiveIntensity:.38}),NPC_CAP,false);
      npcParts.shieldViewport=makeInstances(new THREE.BoxGeometry(.72,.24,.055),new THREE.MeshPhysicalMaterial({color:0x90d7ee,transparent:true,opacity:.72,roughness:.06,metalness:.18,depthWrite:false,clearcoat:1}),NPC_CAP,false);
      const npcPairedPartKeys=new Set(['eyeWhite','pupil','shoe','forearm','hand','brow','ear','uniqueGunLimb','ownerLapel','policePatch']),npcQuadPartKeys=new Set(['uniqueGunSpike','hairCurls']);
      npcParts.gangAura.renderOrder=12;
      npcParts.gangBand.renderOrder=13;renderer.domElement.dataset.npcInstanceColors='physically-lit-instance-colors-with-night-fill';
      const EMPIRE_HQ_CAP=19,empireHqRingGeometry=new THREE.RingGeometry(3.5,4.15,40),empireHqPoleGeometry=new THREE.CylinderGeometry(.07,.1,6,8),empireHqFlagGeometry=new THREE.PlaneGeometry(3.5,1.75),empireHqMarkers=[];
      const redrawEmpireHqLabel=(marker,src)=>{const g=marker.context,c=marker.canvas,color=src.color||'#872f3b',accent=src.accent||'#e8bd67',name=String(src.gangName||'Криминальная семья').toUpperCase();g.clearRect(0,0,c.width,c.height);g.fillStyle='rgba(7,9,13,.96)';g.strokeStyle=color;g.lineWidth=8;g.fillRect(8,8,c.width-16,c.height-16);g.strokeRect(8,8,c.width-16,c.height-16);g.fillStyle=accent;g.font='900 31px Arial';g.textAlign='center';g.textBaseline='middle';g.fillText(`🚩 ШТАБ · ${name}`,c.width/2,c.height/2,470);marker.texture.needsUpdate=true;};
      const redrawEmpireHqFlag=(marker,src)=>{const g=marker.flagContext,c=marker.flagCanvas,color=src.color||'#872f3b',accent=src.accent||'#e8bd67';g.clearRect(0,0,c.width,c.height);g.fillStyle=color;g.fillRect(0,0,c.width,c.height);g.fillStyle=accent;g.fillRect(0,0,c.width,13);g.fillRect(0,c.height-13,c.width,13);g.beginPath();g.moveTo(0,13);g.lineTo(78,c.height/2);g.lineTo(0,c.height-13);g.closePath();g.fill();g.strokeStyle=accent;g.lineWidth=8;g.strokeRect(4,4,c.width-8,c.height-8);g.font='900 66px Georgia,serif';g.textAlign='center';g.textBaseline='middle';g.lineJoin='round';g.strokeStyle='rgba(0,0,0,.74)';g.lineWidth=11;g.strokeText('♛',160,67);g.fillStyle=accent;g.fillText('♛',160,67);marker.flagTexture.needsUpdate=true;};
      const empireHqRoofYAt=(r,c)=>{let bestY=.15,bestD=14;for(const object of buildingPickables){const m=object.userData?.building;if(!m)continue;const inside=Number.isFinite(+m.minR)?r>=+m.minR-.7&&r<=+m.maxR+1.2&&c>=+m.minC-.7&&c<=+m.maxC+1.2:false,d=inside?0:Math.hypot((+m.r||0)-r,(+m.c||0)-c);if(d>bestD)continue;if(!object.geometry.boundingBox)object.geometry.computeBoundingBox();const top=object.position.y+(object.geometry.boundingBox?.max.y||0)*Math.abs(object.scale?.y||1);if(inside||d<bestD){bestD=d;bestY=Math.max(.15,top);}}return bestY;};
      for(let i=0;i<EMPIRE_HQ_CAP;i++){
        const root=new THREE.Group(),ringMaterial=new THREE.MeshBasicMaterial({color:0x872f3b,transparent:true,opacity:.78,side:THREE.DoubleSide,depthWrite:false,toneMapped:false}),ring=new THREE.Mesh(empireHqRingGeometry,ringMaterial);ring.rotation.x=-Math.PI/2;ring.position.y=.13;ring.renderOrder=14;root.add(ring);
        const pole=new THREE.Mesh(empireHqPoleGeometry,new THREE.MeshStandardMaterial({color:0xc9b78c,roughness:.45,metalness:.68}));pole.position.y=3.05;root.add(pole);const flagCanvas=document.createElement('canvas');flagCanvas.width=256;flagCanvas.height=128;const flagContext=flagCanvas.getContext('2d'),flagTexture=new THREE.CanvasTexture(flagCanvas);flagTexture.colorSpace=THREE.SRGBColorSpace;flagTexture.generateMipmaps=false;flagTexture.minFilter=THREE.LinearFilter;const flagMaterial=new THREE.MeshBasicMaterial({color:0xffffff,map:flagTexture,side:THREE.DoubleSide,toneMapped:false}),flag=new THREE.Mesh(empireHqFlagGeometry,flagMaterial),flagPivot=new THREE.Group();flag.position.x=1.78;flag.renderOrder=18;flagPivot.position.y=5.05;flagPivot.add(flag);root.add(flagPivot);
        const canvas=document.createElement('canvas');canvas.width=512;canvas.height=96;const context=canvas.getContext('2d'),texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.generateMipmaps=false;const labelMaterial=new THREE.SpriteMaterial({map:texture,transparent:true,depthWrite:false,toneMapped:false}),label=new THREE.Sprite(labelMaterial);label.position.y=7.25;label.scale.set(10.2,1.92,1);label.renderOrder=24;root.add(label);root.visible=false;scene.add(root);empireHqMarkers.push({root,ring,ringMaterial,pole,flagPivot,flag,flagCanvas,flagContext,flagTexture,flagMaterial,canvas,context,texture,label,signature:''});
      }
      const npcEmpireWeaponShapes={
        leila_mercy:{shape:'dart',primary:0xf4f6f8,accent:0xd73b58,body:[.72,.68,.8],barrel:1.05,stock:.25},
        rustam_wrench:{shape:'bat',primary:0x8b522f,accent:0xc7d0d4,body:[.72,.72,1.9],barrel:0,stock:0,spikes:4,melee:true},
        marco_road:{shape:'thompson',primary:0xff62ad,accent:0xffd2e8,body:[1.08,.9,1.22],barrel:1.45,stock:1.15,drum:1},
        vera_verdict:{shape:'revolver',primary:0x6e4a98,accent:0xf0dc7a,body:[.9,.86,.78],barrel:.82,stock:.2,drum:.56},
        arsen_forge:{shape:'forge',primary:0x3a3026,accent:0xff8b35,body:[1.04,1.05,1.32],barrel:1.55,stock:1.18,blade:.5},
        damir_oath:{shape:'silenced',primary:0x174b3e,accent:0x79d6a8,body:[.86,.76,1.05],barrel:1.75,stock:.72},
        marat_wall:{shape:'breacher',primary:0x263448,accent:0x65a8dc,body:[1.28,1.18,1.25],barrel:1.2,stock:1.25,limbs:.45},
        zara_dividend:{shape:'cannon',primary:0x8a3d17,accent:0xffd46f,body:[1.12,1.02,.95],barrel:1.15,stock:.4,drum:.7},
        niko_whisper:{shape:'sniper',primary:0x334a36,accent:0x9ad06f,body:[.78,.72,1.55],barrel:2.15,stock:1.3,scope:1},
        alisa_signal:{shape:'coil',primary:0x1d4d70,accent:0x62c7ef,body:[.92,.86,1.05],barrel:1.2,stock:.65,limbs:.7},
        boris_tow:{shape:'harpoon',primary:0x8c4a12,accent:0xffe06d,body:[1.02,1.02,1.35],barrel:1.75,stock:.8,blade:1},
        inga_deed:{shape:'flechette',primary:0xb24b72,accent:0xffd0df,body:[.75,.78,.88],barrel:1.15,stock:.3,blade:.45},
        timur_express:{shape:'crossbow',primary:0x3d6eaa,accent:0xffcf4d,body:[.72,.62,1.42],barrel:1.35,stock:.72,limbs:1.6},
        emil_champion:{shape:'knuckle',primary:0x8f2525,accent:0xf5e7d0,body:[1.18,.7,.52],barrel:0,stock:0,spikes:3,melee:true},
        roman_plate:{shape:'armor',primary:0x535c66,accent:0xbcd0dc,body:[1.35,1.22,1.38],barrel:1.7,stock:1.35,limbs:.5},
        sofia_headline:{shape:'flash',primary:0xd7c33e,accent:0xfff4a1,body:[.78,.72,.82],barrel:.7,stock:.18,scope:.55},
        viktor_night:{shape:'shadow',primary:0x17151c,accent:0xb28ad9,body:[.72,.68,1.65],barrel:2.35,stock:1.4,scope:1.15},
        yana_frequency:{shape:'sonic',primary:0x17666a,accent:0x6de0d7,body:[1.08,.95,1.08],barrel:.9,stock:.7,drum:.72,limbs:.45},
        musa_caravan:{shape:'caravan',primary:0x6b5125,accent:0xe6c56a,body:[1.22,1.04,1.45],barrel:1.55,stock:1.25,drum:.6}
      },npcEmpireWeaponColors=Object.fromEntries(Object.entries(npcEmpireWeaponShapes).map(([id,c])=>[id,c.accent]));
      const selectedNpcRing=new THREE.Group(),selectedNpcOuter=new THREE.Mesh(new THREE.RingGeometry(1.55,1.82,40),new THREE.MeshBasicMaterial({color:0xffdf62,transparent:true,opacity:.98,side:THREE.DoubleSide,depthTest:false})),selectedNpcInner=new THREE.Mesh(new THREE.RingGeometry(1.08,1.22,40),new THREE.MeshBasicMaterial({color:0x69ffc2,transparent:true,opacity:.94,side:THREE.DoubleSide,depthTest:false}));for(const ring of [selectedNpcOuter,selectedNpcInner]){ring.rotation.x=-Math.PI/2;ring.renderOrder=55;selectedNpcRing.add(ring);}selectedNpcRing.visible=false;scene.add(selectedNpcRing);
      const nearbyNpcBrassMaterial=new THREE.MeshBasicMaterial({color:0xe2b653,transparent:true,opacity:.9,side:THREE.DoubleSide,depthTest:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2,toneMapped:false}),nearbyNpcAccentMaterial=new THREE.MeshBasicMaterial({color:0x78e3ad,transparent:true,opacity:.88,side:THREE.DoubleSide,depthTest:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3,toneMapped:false}),nearbyNpcGlowMaterial=new THREE.MeshBasicMaterial({color:0x78e3ad,transparent:true,opacity:.11,side:THREE.DoubleSide,depthTest:true,depthWrite:false,blending:THREE.AdditiveBlending,toneMapped:false}),nearbyNpcRing=new THREE.Group(),nearbyNpcGlow=new THREE.Mesh(new THREE.RingGeometry(1.04,1.48,64),nearbyNpcGlowMaterial),nearbyNpcBrassRing=new THREE.Mesh(new THREE.RingGeometry(1.2,1.34,64),nearbyNpcBrassMaterial),nearbyNpcMarkers=new THREE.Group();for(const ring of [nearbyNpcGlow,nearbyNpcBrassRing]){ring.rotation.x=-Math.PI/2;ring.renderOrder=19;nearbyNpcRing.add(ring);}for(let i=0;i<4;i++){const a=i*Math.PI/2,diamond=new THREE.Mesh(new THREE.CircleGeometry(.13,4),nearbyNpcAccentMaterial);diamond.position.set(Math.cos(a)*1.52,.012,Math.sin(a)*1.52);diamond.rotation.x=-Math.PI/2;diamond.rotation.z=Math.PI/4;diamond.renderOrder=20;nearbyNpcMarkers.add(diamond);}nearbyNpcRing.add(nearbyNpcMarkers);nearbyNpcRing.visible=false;scene.add(nearbyNpcRing);renderer.domElement.dataset.npcProximityMarker='brass-ring-four-diamonds-v305';
      const nearbyVehicleMaterial=new THREE.MeshBasicMaterial({color:0xe7b84f,transparent:true,opacity:.82,side:THREE.DoubleSide,depthTest:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2,toneMapped:false}),nearbyVehicleRing=new THREE.Mesh(new THREE.RingGeometry(1.5,1.68,64),nearbyVehicleMaterial);nearbyVehicleRing.rotation.x=-Math.PI/2;nearbyVehicleRing.renderOrder=19;nearbyVehicleRing.visible=false;scene.add(nearbyVehicleRing);renderer.domElement.dataset.vehicleProximityMarker='close-door-single-brass-ring-v304';renderer.domElement.dataset.proximityScanCadence='140ms-shared-npc-vehicle-building-v270';renderer.domElement.dataset.promptLayoutReads='none-static-stage-metrics-v270';
      const citizenPool=Array.from({length:NPC_CAP},()=>({}));renderer.domElement.dataset.npcHpVisual='identity-card-right-to-left-fade-no-bars-v351';
      const npcLabels=[];for(let i=0;i<NPC_CAP;i++){const canvas=document.createElement('canvas');canvas.width=768;canvas.height=192;const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.generateMipmaps=false;texture.minFilter=THREE.LinearFilter;texture.magFilter=THREE.LinearFilter;texture.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}));sprite.scale.set(12.2,3.05,1);sprite.renderOrder=46;sprite.layers.enable(1);sprite.visible=false;scene.add(sprite);npcLabels.push({canvas,texture,sprite,sig:'',layoutSig:''});}renderer.domElement.dataset.npcLabelProfile='empire-family-card-v360';renderer.domElement.dataset.npcLabelCanvas='768x192';renderer.domElement.dataset.policeResponseLabelProfile='readable-staggered-plus-15-v342';
      // One shared texture and a bounded sprite pool provide a permanent role
      // badge even while the main NPC label is temporarily replaced by speech.
      const guardBadgeCanvas=document.createElement('canvas');guardBadgeCanvas.width=512;guardBadgeCanvas.height=128;const guardBadgeContext=guardBadgeCanvas.getContext('2d');guardBadgeContext.fillStyle='rgba(12,15,18,.97)';guardBadgeContext.fillRect(8,8,496,112);guardBadgeContext.strokeStyle='#d4a84f';guardBadgeContext.lineWidth=8;guardBadgeContext.strokeRect(13,13,486,102);guardBadgeContext.font='900 58px system-ui';guardBadgeContext.textAlign='center';guardBadgeContext.textBaseline='middle';guardBadgeContext.lineJoin='round';guardBadgeContext.strokeStyle='#000';guardBadgeContext.lineWidth=13;guardBadgeContext.strokeText('ОХРАНА',256,67);guardBadgeContext.fillStyle='#ffd36a';guardBadgeContext.fillText('ОХРАНА',256,67);const guardBadgeTexture=new THREE.CanvasTexture(guardBadgeCanvas);guardBadgeTexture.colorSpace=THREE.SRGBColorSpace;guardBadgeTexture.generateMipmaps=false;guardBadgeTexture.minFilter=THREE.LinearFilter;guardBadgeTexture.magFilter=THREE.LinearFilter;const guardBadgeMaterial=new THREE.SpriteMaterial({map:guardBadgeTexture,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}),guardRoleBadges=[];for(let i=0;i<NPC_CAP;i++){const badge=new THREE.Sprite(guardBadgeMaterial);badge.scale.set(6.2,1.55,1);badge.renderOrder=48;badge.layers.enable(1);badge.visible=false;scene.add(badge);guardRoleBadges.push(badge);}renderer.domElement.dataset.guardRoleBadge='shared-texture-bounded-pool-v1';
      const ownerBadgeCanvas=document.createElement('canvas');ownerBadgeCanvas.width=768;ownerBadgeCanvas.height=128;const ownerBadgeContext=ownerBadgeCanvas.getContext('2d');ownerBadgeContext.fillStyle='rgba(20,15,9,.98)';ownerBadgeContext.fillRect(8,8,752,112);ownerBadgeContext.strokeStyle='#e0b95c';ownerBadgeContext.lineWidth=8;ownerBadgeContext.strokeRect(13,13,742,102);ownerBadgeContext.font='900 48px system-ui';ownerBadgeContext.textAlign='center';ownerBadgeContext.textBaseline='middle';ownerBadgeContext.lineJoin='round';ownerBadgeContext.strokeStyle='#000';ownerBadgeContext.lineWidth=13;ownerBadgeContext.strokeText('ВЛАДЕЛЕЦ ЗАВЕДЕНИЯ',384,67);ownerBadgeContext.fillStyle='#ffe08a';ownerBadgeContext.fillText('ВЛАДЕЛЕЦ ЗАВЕДЕНИЯ',384,67);const ownerBadgeTexture=new THREE.CanvasTexture(ownerBadgeCanvas);ownerBadgeTexture.colorSpace=THREE.SRGBColorSpace;ownerBadgeTexture.generateMipmaps=false;ownerBadgeTexture.minFilter=THREE.LinearFilter;ownerBadgeTexture.magFilter=THREE.LinearFilter;const ownerBadgeMaterial=new THREE.SpriteMaterial({map:ownerBadgeTexture,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}),ownerRoleBadges=[];for(let i=0;i<NPC_CAP;i++){const badge=new THREE.Sprite(ownerBadgeMaterial);badge.scale.set(9.2,1.53,1);badge.renderOrder=48;badge.layers.enable(1);badge.visible=false;scene.add(badge);ownerRoleBadges.push(badge);}renderer.domElement.dataset.ownerRoleBadge='shared-texture-speech-fallback-v1';
      startupMark('npc-pools');
      const outlinedLabelText=(c,text,x,y,font,color)=>{c.font=font;c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';c.lineWidth=17;c.strokeStyle='rgba(0,0,0,1)';c.strokeText(text,x,y);c.fillStyle=color;c.fillText(text,x,y);};
      const fitOutlinedLabelText=(c,text,x,y,maxWidth,startSize,color)=>{const safe=String(text||'');let size=startSize;for(;size>30;size-=2){c.font=`900 ${size}px system-ui`;if(c.measureText(safe).width<=maxWidth)break;}outlinedLabelText(c,safe,x,y,`900 ${size}px system-ui`,color);};
      const empireLabelColor=(value,fallback)=>/^#[0-9a-f]{6}$/i.test(String(value||''))?String(value):fallback;
      const empireLabelRgba=(value,alpha)=>{const hex=empireLabelColor(value,'#872f3b'),n=parseInt(hex.slice(1),16);return `rgba(${n>>16&255},${n>>8&255},${n&255},${alpha})`;};
      const fadeDarkCardBackground=(c,pct)=>{const health=THREE.MathUtils.clamp(Number.isFinite(+pct)?+pct:1,0,1);if(health>=.995)return;const image=c.getImageData(0,0,c.canvas.width,c.canvas.height),data=image.data,edge=c.canvas.width*health,feather=54;for(let py=0;py<c.canvas.height;py++)for(let px=Math.max(0,Math.floor(edge-feather));px<c.canvas.width;px++){const i=(py*c.canvas.width+px)*4,maxChannel=Math.max(data[i],data[i+1],data[i+2]);if(maxChannel>112||data[i+3]===0)continue;const visibility=THREE.MathUtils.clamp((edge-px)/feather,0,1);data[i+3]=Math.round(data[i+3]*visibility);}c.putImageData(image,0,0);};
      const updateNpcLabel=(entry,src,x,y,z)=>{
        const healthPct=THREE.MathUtils.clamp(Number.isFinite(+src.hp)?(+src.hp/Math.max(1,+src.maxHp||60)):1,0,1),healthBucket=Math.round(healthPct*100);if(entry.healthBucket!==healthBucket){entry.healthBucket=healthBucket;entry.sig='';}
        if(src.empireBoss){if(_LOCAL_PREVIEW&&_UP.has('previewweaponmodels')){entry.sprite.visible=false;return;}const name=String(src.name||'БОСС').toUpperCase(),gang=String(src.empireGang||'КРИМИНАЛЬНАЯ СЕМЬЯ').toUpperCase(),action=String(src.empireAction||'').toUpperCase(),sub=action?`${gang} · ${action}`:`ГЛАВА БАНДЫ · ${gang}`,sig=`empire-boss-v2:${name}:${sub}:${src.speech||''}`;if(sig!==entry.sig){entry.sig=sig;const c=entry.canvas.getContext('2d');c.clearRect(0,0,768,192);c.fillStyle='rgba(18,8,8,.98)';c.fillRect(24,8,720,176);c.strokeStyle='#efb94f';c.lineWidth=11;c.strokeRect(30,14,708,164);fitOutlinedLabelText(c,`♛ ${name} · БОСС`,384,57,660,50,'#ffd76b');fitOutlinedLabelText(c,sub,384,135,660,35,'#ffffff');entry.sprite.scale.set(18.4,4.6,1);entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y+.35,z);return;}
        if(src.uniqueNpc||src.said){const name=String(src.name||'СПЕЦИАЛИСТ').toUpperCase(),title=String(src.specialistTitle||(src.said?'Правая рука':'Специалист')),salary=Math.max(0,+src.salary||0),sub=src.said?(src.hired?'СТАТУС: НАНЯТ · ПРАВАЯ РУКА':'СТАТУС: НЕ НАНЯТ · $500/ДЕНЬ'):`${title} · $${salary.toLocaleString('ru')}/день · услуги скоро`,sig=`unique-v2:${name}:${sub}:${src.speech||''}`;if(sig!==entry.sig){entry.sig=sig;const c=entry.canvas.getContext('2d');c.clearRect(0,0,768,192);c.fillStyle=src.said?(src.hired?'rgba(7,38,24,.98)':'rgba(43,22,15,.98)'):'rgba(12,10,7,.98)';c.fillRect(24,8,720,176);c.strokeStyle=src.said?(src.hired?'#58e990':'#e7a15c'):'#e5bd55';c.lineWidth=11;c.strokeRect(30,14,708,164);fitOutlinedLabelText(c,src.said?`👔 ${name}`:`${name} · УНИКАЛЬНЫЙ NPC`,384,57,660,50,src.said?(src.hired?'#8dffb1':'#ffd09a'):'#ffd76b');fitOutlinedLabelText(c,sub,384,135,660,42,'#ffffff');entry.sprite.scale.set(18.4,4.6,1);entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y+.35,z);return;}
        const role=String(src.role||'civilian').toLowerCase(),behavior=String(src.behavior||''),prisonStaff=behavior==='prison_patrol'||role.startsWith('prison_'),empireCrew=!!src.empireCrew,gang=empireCrew||!!src.gang||role.includes('gang')||role.includes('boss')||role.includes('district_')||role.includes('occupier'),police=!!src.police||role.includes('police')||role.includes('cop'),guard=role.includes('guard'),owner=src.visualRole==='owner',medic=role.includes('medic'),civilian=!police&&!gang&&!guard&&!owner;
        const rawFamily=String(src.family||'').trim(),familyKey=rawFamily.toLowerCase(),family=(familyKey==='purple'||familyKey==='bellini'||familyKey==='беллини')?'Беллини':(familyKey==='yellow'||familyKey==='moretti'||familyKey==='моретти')?'Моретти':rawFamily.slice(0,20);
        const title=police?'ПОЛИЦИЯ':gang?(behavior==='follows_player'?'ТВОЙ БОЕЦ':behavior==='guards_nest'?'ОХРАНА ГНЕЗДА':behavior==='guards_lair'?'ОХРАНА ЛОГОВА':behavior==='hostile_zone'?(family?`БАНДА ${family.toUpperCase()}`:'БАНДА'):'БОЕЦ БАНДЫ'):guard?'ОХРАНА':owner?'ВЛАДЕЛЕЦ ЗАВЕДЕНИЯ':medic?'МЕДИК':'ЖИТЕЛЬ';
        const familyPrimary=empireCrew?empireLabelColor(src.bossColor,'#d4aa32'):'',familyAccent=empireCrew?empireLabelColor(src.bossAccent,'#fff0a0'):'',accent=police?'#58b9ff':empireCrew?familyPrimary:gang?'#ff5367':guard?'#ffc857':owner?'#ffe08a':medic?'#64e7dd':'#7ee7a5',name=String(src.name||title).slice(0,28),hp=Math.max(0,Math.round(+src.hp||0)),maxHp=Math.max(1,Math.round(+src.maxHp||60)),level=gang?Math.max(1,Math.round(+src.level||1)):null,rankText=gang?` · ${level} ур.`:'',familyText=behavior==='hostile_zone'?'':(family?` · ${family}`:''),subline=owner?name:prisonStaff?`${police?'ПАТРУЛЬ':'КАРАУЛ'} · ${hp}/${maxHp}`:`${name} · HP ${hp}/${maxHp}`,sig=`v360:${title}:${subline}:${rankText}:${familyText}:${familyPrimary}:${familyAccent}`;
        if(sig!==entry.sig){entry.sig=sig;const c=entry.canvas.getContext('2d');c.clearRect(0,0,768,192);if(civilian){c.fillStyle='rgba(5,10,17,.97)';c.fillRect(84,8,600,176);c.strokeStyle=accent;c.lineWidth=10;c.strokeRect(90,14,588,164);fitOutlinedLabelText(c,title,384,57,520,56,accent);fitOutlinedLabelText(c,subline,384,135,540,51,'#ffffff');entry.sprite.scale.set(15.5,3.88,1);}else{if(empireCrew){const bg=c.createLinearGradient(8,8,760,184);bg.addColorStop(0,empireLabelRgba(familyPrimary,.44));bg.addColorStop(.46,'rgba(3,8,14,.98)');bg.addColorStop(1,empireLabelRgba(familyAccent,.3));c.fillStyle=bg;}else c.fillStyle=owner?'rgba(22,16,8,.98)':'rgba(3,8,14,.98)';c.fillRect(8,8,752,176);c.strokeStyle=accent;c.lineWidth=11;c.strokeRect(14,14,740,164);c.fillStyle=empireCrew?familyAccent:accent;c.fillRect(30,88,708,5);fitOutlinedLabelText(c,`${title}${rankText}${familyText}`,384,55,690,owner?49:prisonStaff?62:54,empireCrew?familyPrimary:accent);fitOutlinedLabelText(c,subline,384,137,680,owner?56:prisonStaff?60:51,empireCrew?familyAccent:'#ffffff');entry.sprite.scale.set(owner?18.2:prisonStaff?17.8:17.2,owner?4.55:prisonStaff?4.75:4.3,1);}entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y,z);
        const healthFadeSig=`${entry.sig}:${healthBucket}`;if(entry.healthFadeSig!==healthFadeSig){entry.healthFadeSig=healthFadeSig;fadeDarkCardBackground(entry.canvas.getContext('2d'),healthPct);entry.texture.needsUpdate=true;}
      };
      const updateDeadNpcLabel=(entry,src,x,z)=>{const name=String(src.name||'').trim().slice(0,28),sig=`dead-v343:${name}`;if(sig!==entry.sig){entry.sig=sig;const c=entry.canvas.getContext('2d');c.clearRect(0,0,768,192);c.fillStyle='rgba(12,3,5,.97)';c.fillRect(112,18,544,156);c.strokeStyle='#8e1826';c.lineWidth=12;c.strokeRect(119,25,530,142);c.fillStyle='#2a050a';c.fillRect(136,91,496,4);fitOutlinedLabelText(c,'☠ МЁРТВ',384,62,460,62,'#ff5367');if(name)fitOutlinedLabelText(c,name.toUpperCase(),384,133,460,42,'#ead9d3');entry.sprite.scale.set(12.2,3.05,1);entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,3.15,z);};
      const speechTextLayout=(c,value,maxWidth=680)=>{const words=String(value||'').trim().split(/\s+/).filter(Boolean);let size=50,lines=[];const wrap=()=>{lines=[''];for(const word of words){const i=lines.length-1,test=(lines[i]+' '+word).trim();if(lines[i]&&c.measureText(test).width>maxWidth&&lines.length<3)lines.push(word);else lines[i]=test;}};for(;size>=28;size-=2){c.font=`900 ${size}px system-ui`;wrap();if(lines.every(line=>c.measureText(line).width<=maxWidth))break;}size=Math.max(28,size);c.font=`900 ${size}px system-ui`;lines=lines.slice(0,3).map(line=>{if(c.measureText(line).width<=maxWidth)return line;let short=line;while(short.length>1&&c.measureText(short+'…').width>maxWidth)short=short.slice(0,-1);return short+'…';});return {lines,size};};
      const paintSpeechBubble=(c,speech)=>{c.clearRect(0,0,768,192);c.fillStyle='rgba(255,250,226,.98)';c.fillRect(18,6,732,150);c.strokeStyle='#d2a947';c.lineWidth=10;c.strokeRect(24,12,720,138);c.fillStyle='rgba(255,250,226,.98)';c.beginPath();c.moveTo(326,156);c.lineTo(384,190);c.lineTo(442,156);c.closePath();c.fill();const {lines,size}=speechTextLayout(c,speech);c.font=`900 ${size}px system-ui`;c.textAlign='center';c.textBaseline='middle';c.fillStyle='#17130d';const ys=lines.length===1?[82]:lines.length===2?[56,112]:[38,82,126];c.save();c.beginPath();c.rect(30,18,708,126);c.clip();lines.forEach((line,i)=>c.fillText(line,384,ys[i]));c.restore();};
      const updateNpcSpeechLabel=(entry,src,x,y,z)=>{const speech=String(src.speech||'').trim();if(!speech){updateNpcLabel(entry,src,x,y,z);return;}const sig=`speech-v304:${speech}`;if(sig!==entry.sig){entry.sig=sig;paintSpeechBubble(entry.canvas.getContext('2d'),speech);entry.sprite.scale.set(16.8,4.2,1);entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y+.78,z);};
      // Во время конвоя большие таблички ближайших NPC закрывали самого
      // заключённого. Оставляем лишь две компактные подписи принимающей смены.
      const updateCustodyAwareNpcLabel=(entry,src,x,y,z)=>{
        const custody=['escort','loading','unloading','handoff','prison_escort','booking'].includes(activeArrestLabelPhase),
          name=String(src?.name||''),escortOfficer=/Тюремный конвой|Приёмный офицер/i.test(name),
          responseOfficer=String(src?.kind||'')==='murder_response',formation=Math.max(0,+src?._formationIndex||0),
          nearPlayer=Math.hypot(x-player.position.x,z-player.position.z)<WORLD_SCALE*26;
        if(custody&&nearPlayer&&!escortOfficer){entry.sprite.visible=false;return;}
        updateNpcSpeechLabel(entry,src,x,y,z);
        if(!String(src?.speech||'').trim()){const healthPct=THREE.MathUtils.clamp(Number.isFinite(+src?.hp)?(+src.hp/Math.max(1,+src.maxHp||60)):1,0,1),healthBucket=Math.round(healthPct*100),healthFadeSig=`${entry.sig}:${healthBucket}`;if(entry.healthFadeSig!==healthFadeSig){entry.healthFadeSig=healthFadeSig;fadeDarkCardBackground(entry.canvas.getContext('2d'),healthPct);entry.texture.needsUpdate=true;}}
        if(entry.sprite.visible)entry.sprite.position.y+=1.35;
        // Постоянные NPC-плашки занимают примерно треть прежней площади.
        // Реплики и уникальные NPC остаются крупнее, потому что появляются
        // временно или являются важным взаимодействием.
        const speech=String(src?.speech||'').trim(),role=String(src?.role||'').toLowerCase(),prisonStaff=String(src?.behavior||'')==='prison_patrol'||role.startsWith('prison_');
        let layoutSig=(src?.uniqueNpc||src?.said)?'unique':speech?'speech':prisonStaff?'prison':'standard',layoutScale=(src?.uniqueNpc||src?.said)?[18.4,4.6]:speech?[16.8,4.2]:prisonStaff?[13.6,3.52]:[12.2,3.05];
        if(custody&&escortOfficer){
          layoutSig='custody-escort';layoutScale=[8.7,2.18];
          entry.sprite.position.set(x+(name.includes('Приёмный')?-.48:.48),5.55+(name.includes('Приёмный')?0:.72),z);
        }else if(responseOfficer){
          layoutSig='response-officer';layoutScale=[9.9,2.47];
          entry.sprite.position.set(x+((formation%2)-.5)*.44,6.05+(formation%3)*.34,z);
        }
        if(entry.sprite.visible&&(custody&&escortOfficer||responseOfficer))entry.sprite.position.y+=1.35;
        if(layoutSig!==entry.layoutSig){entry.layoutSig=layoutSig;entry.sprite.scale.set(layoutScale[0],layoutScale[1],1);}
      };
      // NPC source angles use the 2D convention (zero points east), while the
      // character mesh faces local +Z. Track real snapshot displacement and
      // smoothly turn the mesh into its actual walking direction.
      const npcFacingStates=new Map(),npcMotionStates=new Map(),npcFacingYaws=new Float32Array(NPC_CAP),npcVisualXs=new Float32Array(NPC_CAP),npcVisualZs=new Float32Array(NPC_CAP),npcVisualPhases=new Float32Array(NPC_CAP),npcRootQuat=new THREE.Quaternion(),wrapAngle=value=>{while(value>Math.PI)value-=Math.PI*2;while(value<-Math.PI)value+=Math.PI*2;return value;},npcIsDead=src=>!!src?.dead||(Number.isFinite(+src?.hp)&&+src.hp<=0);
      const npcAppearanceSignatures=new Set(),npcAppearanceSlotSignatures=new Array(NPC_CAP).fill(''),npcShirts=[0x52b8ee,0xf0717f,0x8acb63,0xefae46,0xa184dc,0x42b9ad,0xc9689c,0xa08059,0x5d708e,0x9d5c47,0x3c8b78,0xd46f42],npcTrousers=[0x344b69,0x574640,0x3e5949,0x48405d,0x596b82,0x2f343c,0x705c4d],npcSkins=[0xf6cfae,0xe8b38d,0xd4936c,0xb97855,0x925c40,0x70442f],npcHairs=[0x211c18,0x513222,0x8a6036,0xd19a58,0xc34b39,0xe2d2ad,0x8b8b90],npcShoes=[0x1d252e,0x443129,0x4b3c35,0x303945],npcHats=[0x35445c,0x75483a,0x91384a,0x45765a,0xd2a54a],npcAccents=[0xb92f42,0x315b9d,0xd5aa42,0x3d916e,0x78499d],npcBags=[0x6e4934,0x3e5265,0x765f3d,0x43394d];
      const npcFramePoses=new Array(NPC_CAP),gangColorSignatures=new Array(NPC_CAP).fill(''),remoteColorSignatures=new Array(REMOTE_CAP).fill(''),npcEmpireWeaponColorSignatures=new Array(NPC_CAP).fill(''),corpseBloodMatrixSignatures=new Array(NPC_CAP).fill('');
      const SECURITY_UNIFORMS=Object.freeze({
        business:[0x243246,0x151b24,0xc99a43],casino:[0x221d20,0x0d1015,0xd7ae55],
        market:[0x29443a,0x17251f,0xd1aa51],factory:[0x3f454d,0x20252b,0xe18b38],
        mansion:[0x351f29,0x181319,0xc7a16a],port:[0x203b4f,0x122430,0x68b9d4],
        generic:[0x2a3440,0x171d24,0xcaa452]
      });
      const projectileColorSignatures=new Array(BULLET_CAP).fill(''),projectileMatrixSignatures=new Array(BULLET_CAP).fill(''),shellMatrixSignatures=new Array(30).fill(''),bulletHoleMatrixSignatures=new Array(32).fill(''),bulletHoleColorSignatures=new Array(32).fill(''),bloodMatrixSignatures=new Array(48).fill(''),bloodColorSignatures=new Array(48).fill(''),goreColorSignatures=new Array(12).fill(''),goreMatrixSignatures=new Array(12).fill('');
      const remoteParts={body:makeInstances(new THREE.BoxGeometry(1.45,2.15,.9),new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,toneMapped:false}),REMOTE_CAP),head:makeInstances(new THREE.SphereGeometry(.53,14,10),new THREE.MeshBasicMaterial({color:0xc58c68,toneMapped:false}),REMOTE_CAP),hat:makeInstances(new THREE.CylinderGeometry(.68,.68,.28,14),new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,toneMapped:false}),REMOTE_CAP)},remotePartMeshes=Object.values(remoteParts);
      const createPlayerSpeechEntry=()=>{const canvas=document.createElement('canvas');canvas.width=768;canvas.height=192;const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.generateMipmaps=false;texture.minFilter=THREE.LinearFilter;texture.magFilter=THREE.LinearFilter;texture.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false,depthWrite:false,toneMapped:false}));sprite.scale.set(16.8,4.2,1);sprite.renderOrder=62;sprite.layers.enable(1);sprite.visible=false;scene.add(sprite);return {canvas,texture,sprite,sig:''};};
      const localPlayerSpeech=createPlayerSpeechEntry(),remotePlayerSpeech=Array.from({length:REMOTE_CAP},createPlayerSpeechEntry);
      const updatePlayerSpeech=(entry,value,x,y,z)=>{const speech=String(value||'').trim();if(!speech){entry.sprite.visible=false;entry.sig='';return;}const sig=`player-chat-v304:${speech}`;if(sig!==entry.sig){entry.sig=sig;paintSpeechBubble(entry.canvas.getContext('2d'),speech);entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y,z);};
      const worldBullets=makeInstances(new THREE.CapsuleGeometry(.085,.42,4,8),new THREE.MeshBasicMaterial({color:0xffffff,depthTest:false,vertexColors:true,toneMapped:false}),BULLET_CAP,false);worldBullets.renderOrder=36;
      const worldBulletTrails=makeInstances(new THREE.CylinderGeometry(.035,.085,1.55,7),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.78,depthTest:false,depthWrite:false,vertexColors:true,toneMapped:false,blending:THREE.AdditiveBlending}),BULLET_CAP,false);worldBulletTrails.renderOrder=35;
      const worldBulletGlows=makeInstances(new THREE.SphereGeometry(.28,8,6),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.42,depthTest:false,depthWrite:false,vertexColors:true,toneMapped:false,blending:THREE.AdditiveBlending}),BULLET_CAP,false);worldBulletGlows.renderOrder=34;
      const worldBulletCores=makeInstances(new THREE.CapsuleGeometry(.04,.28,3,7),new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.96,depthTest:false,depthWrite:false,vertexColors:true,toneMapped:false,blending:THREE.AdditiveBlending}),BULLET_CAP,false);worldBulletCores.renderOrder=37;
      const worldArrowShafts=makeInstances(new THREE.CylinderGeometry(.045,.045,1.55,7),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.58,metalness:.18}),BULLET_CAP,false),worldArrowHeads=makeInstances(new THREE.ConeGeometry(.15,.42,6),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.2,metalness:.9}),BULLET_CAP,false),worldArrowFletching=makeInstances(new THREE.BoxGeometry(.42,.32,.035),new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,toneMapped:false}),BULLET_CAP,false);worldArrowShafts.renderOrder=worldArrowHeads.renderOrder=worldArrowFletching.renderOrder=38;
      renderer.domElement.dataset.bulletRendering='profiled-four-layer-instanced-v198';
      const shellPool=makeInstances(new THREE.CylinderGeometry(.055,.055,.28,7),new THREE.MeshStandardMaterial({color:0xd6a638,metalness:.9,roughness:.23}),30,false);
      const BLOOD_DECAL_CAP=48,bloodDecals=makeInstances(new THREE.CircleGeometry(1,20),new THREE.MeshBasicMaterial({color:0xffffff,vertexColors:true,transparent:true,opacity:.72,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}),BLOOD_DECAL_CAP,false);bloodDecals.renderOrder=11;
      const corpseBloodCanvas=document.createElement('canvas');corpseBloodCanvas.width=corpseBloodCanvas.height=192;const corpseBloodContext=corpseBloodCanvas.getContext('2d');corpseBloodContext.clearRect(0,0,192,192);for(const [x,y,rx,ry,turn] of [[96,98,66,49,-.12],[61,104,34,27,.34],[132,83,40,30,-.46],[112,126,43,25,.18]]){corpseBloodContext.save();corpseBloodContext.translate(x,y);corpseBloodContext.rotate(turn);corpseBloodContext.scale(rx,ry);const gradient=corpseBloodContext.createRadialGradient(-.12,-.16,.05,0,0,1);gradient.addColorStop(0,'rgba(64,2,8,.98)');gradient.addColorStop(.42,'rgba(111,5,14,.94)');gradient.addColorStop(.76,'rgba(78,3,10,.82)');gradient.addColorStop(1,'rgba(42,0,5,0)');corpseBloodContext.fillStyle=gradient;corpseBloodContext.beginPath();corpseBloodContext.arc(0,0,1,0,Math.PI*2);corpseBloodContext.fill();corpseBloodContext.restore();}for(let i=0;i<18;i++){const a=i*2.399,r=66+(i%5)*4.8,s=1.7+(i%4)*.85;corpseBloodContext.fillStyle=`rgba(${64+i%3*15},2,8,${.38+(i%3)*.12})`;corpseBloodContext.beginPath();corpseBloodContext.ellipse(96+Math.cos(a)*r,98+Math.sin(a)*r,s*1.45,s,a,0,Math.PI*2);corpseBloodContext.fill();}const corpseBloodTexture=new THREE.CanvasTexture(corpseBloodCanvas);corpseBloodTexture.colorSpace=THREE.SRGBColorSpace;corpseBloodTexture.generateMipmaps=true;corpseBloodTexture.minFilter=THREE.LinearMipmapLinearFilter;corpseBloodTexture.magFilter=THREE.LinearFilter;const corpseBloodDecals=makeInstances(new THREE.CircleGeometry(1,24),new THREE.MeshBasicMaterial({map:corpseBloodTexture,color:0xffffff,transparent:true,opacity:.96,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}),NPC_CAP,false);corpseBloodDecals.renderOrder=10;renderer.domElement.dataset.corpseBloodVisual='organic-shared-texture-v343';
      const GORE_LIMB_CAP=12,GORE_CHUNK_CAP=24,goreLimbs=makeInstances(new THREE.BoxGeometry(.36,1.18,.4),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.82,metalness:0}),GORE_LIMB_CAP,false),goreChunks=makeInstances(new THREE.IcosahedronGeometry(.14,1),new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,roughness:.9,metalness:0}),GORE_CHUNK_CAP,false);goreLimbs.count=0;goreChunks.count=0;goreLimbs.renderOrder=27;goreChunks.renderOrder=28;
      const bulletHoleCanvas=document.createElement('canvas');bulletHoleCanvas.width=96;bulletHoleCanvas.height=96;const bulletHoleCtx=bulletHoleCanvas.getContext('2d'),bulletHoleGradient=bulletHoleCtx.createRadialGradient(48,48,3,48,48,42);bulletHoleGradient.addColorStop(0,'rgba(0,0,0,1)');bulletHoleGradient.addColorStop(.18,'rgba(10,8,7,.98)');bulletHoleGradient.addColorStop(.34,'rgba(86,69,53,.94)');bulletHoleGradient.addColorStop(.48,'rgba(28,22,18,.76)');bulletHoleGradient.addColorStop(1,'rgba(0,0,0,0)');bulletHoleCtx.fillStyle=bulletHoleGradient;bulletHoleCtx.fillRect(0,0,96,96);bulletHoleCtx.strokeStyle='rgba(226,204,166,.62)';bulletHoleCtx.lineWidth=2;for(let i=0;i<8;i++){const a=i*2.399;bulletHoleCtx.beginPath();bulletHoleCtx.moveTo(48+Math.cos(a)*12,48+Math.sin(a)*12);bulletHoleCtx.lineTo(48+Math.cos(a)*31,48+Math.sin(a)*31);bulletHoleCtx.stroke();}const bulletHoleTexture=new THREE.CanvasTexture(bulletHoleCanvas);bulletHoleTexture.colorSpace=THREE.SRGBColorSpace;const bulletHoleDecals=makeInstances(new THREE.PlaneGeometry(1,1),new THREE.MeshBasicMaterial({map:bulletHoleTexture,transparent:true,opacity:.94,depthWrite:false,depthTest:true,side:THREE.DoubleSide,toneMapped:false,polygonOffset:true,polygonOffsetFactor:-4,polygonOffsetUnits:-4}),32,false);bulletHoleDecals.renderOrder=29;renderer.domElement.dataset.bulletHoleRendering='oriented-instanced-wall-decals-v198';
      const bulletUp=new THREE.Vector3(0,1,0),bulletDirection=new THREE.Vector3();
      const setPart=(mesh,index,root,px,py,pz,rx=0,scale=unitScale,ry=0,rz=0)=>{instanceQuat.setFromEuler(instanceEuler.set(rx,ry,rz));localMatrix.compose(instancePosition.set(px,py,pz),instanceQuat,scale);instanceMatrix.multiplyMatrices(root,localMatrix);mesh.setMatrixAt(index,instanceMatrix);};
      const NPC_ANIM_CRAWL=1,NPC_ANIM_LIMP=2,NPC_ANIM_PANIC=4,NPC_ANIM_COWER=8,NPC_ANIM_SURRENDER=16,NPC_ANIM_HELP=32,NPC_ANIM_TALK=64,NPC_ANIM_ALERT=128,NPC_SOCIAL_GESTURES=new Set(['talk','talking','explain','argue','point','wave']);
      const npcAnimationBits=(src,t,dead=npcIsDead(src))=>{
        if(dead)return 0;
        const state=String(src.lifeState||src.animationState||src.animState||src.state||src.action||src.act||'').toLowerCase(),gesture=String(src.gesture||'').toLowerCase(),stateUntil=+src.stateUntil||0,stateActive=!stateUntil||stateUntil>t;
        let bits=0;
        if(src.crawling||src.crawl||src.forcedCrawl||((+src.severMask||0)&12)!==0||(stateActive&&(state==='crawl'||state==='crawling'||state==='downed')))bits|=NPC_ANIM_CRAWL;
        if(src.injured||src.limping||src.limp||(stateActive&&(state==='injured'||state==='limp'||state==='limping')))bits|=NPC_ANIM_LIMP;
        if(src.panic||src.panicking||src.flee||src.fleeing||gesture==='flee'||gesture==='call'||(+src.panicUntil||0)>t||(stateActive&&(state==='panic'||state==='panicking'||state==='flee'||state==='fleeing')))bits|=NPC_ANIM_PANIC;
        if(src.cowering||src.cower||src.inCover||src.takingCover||gesture==='cower'||gesture==='cover'||gesture==='freeze'||(stateActive&&(state==='cower'||state==='cowering'||state==='cover'||state==='take_cover'||state==='taking_cover'||state==='freeze'||state==='frozen')))bits|=NPC_ANIM_COWER;
        if(src.surrendering||src.surrendered||src.surrender||gesture==='hands_up'||(stateActive&&(state==='surrender'||state==='surrendering'||state==='surrendered')))bits|=NPC_ANIM_SURRENDER;
        if(src.helping||src.helpingInjured||src.givingAid||gesture==='help'||gesture==='aid'||(stateActive&&(state==='help'||state==='helping'||state==='aiding'||state==='first_aid')))bits|=NPC_ANIM_HELP;
        if(src.talking||src.social||src.socializing||NPC_SOCIAL_GESTURES.has(gesture)||(stateActive&&(state==='talk'||state==='talking'||state==='social'||state==='socializing')))bits|=NPC_ANIM_TALK;
        if(src.alerted||src.alert||gesture==='lookout'||(stateActive&&(state==='alert'||state==='alerted'||state==='watching')))bits|=NPC_ANIM_ALERT;
        return bits;
      };
      const npcLifeAnimationPose=(src,i,t)=>{
        const key=String(src.id??src.uid??i),motion=npcMotionStates.get(key),dead=npcIsDead(src),animBits=Number.isFinite(+motion?.animBits)?motion.animBits:npcAnimationBits(src,t,dead);
        const role=String(src.role||'').toLowerCase(),combatActor=!!src.police||!!src.gang||role.includes('police')||role.includes('cop')||role.includes('guard')||role.includes('gang')||role.includes('boss');
        const shotAge=Math.max(0,t-(+src._shotAt||+src.shotAt||0)),weaponKey=String(src._shotWeapon||src.weapon||'').toLowerCase(),longGun=/rifle|shotgun|smg|automatic/.test(weaponKey),firing=!dead&&combatActor&&shotAge<460,firePhase=Math.min(1,shotAge/460),recoil=firing?Math.pow(Math.sin(Math.min(1,shotAge/210)*Math.PI),1.35)*(longGun?.42:.31):0;
        if(i===0){renderer.domElement.dataset.npcLifeSystem=document.documentElement.dataset.npcLifeSystem||'active:v1';renderer.domElement.dataset.npcLifeStates=document.documentElement.dataset.npcLifeStates||'warming';renderer.domElement.dataset.npcLifePools=document.documentElement.dataset.npcLifePools||`shown:${dynamicState?.npcs?.length||0}:cap:${NPC_CAP}`;renderer.domElement.dataset.npcLifeMemory=document.documentElement.dataset.npcLifeMemory||'bounded';}
        const hpPct=Math.max(0,Math.min(1,(+src.hp||0)/(+src.maxHp||60)));
        const phoneCalling=!dead&&!!src.phoneCalling,crawling=!!(animBits&NPC_ANIM_CRAWL),cowering=!phoneCalling&&!crawling&&!!(animBits&NPC_ANIM_COWER),surrendering=!phoneCalling&&!crawling&&!cowering&&!!(animBits&NPC_ANIM_SURRENDER),helping=!phoneCalling&&!crawling&&!cowering&&!surrendering&&!!(animBits&NPC_ANIM_HELP),panicking=!phoneCalling&&!crawling&&!cowering&&!surrendering&&!helping&&!!(animBits&NPC_ANIM_PANIC),talking=!phoneCalling&&!crawling&&!cowering&&!surrendering&&!helping&&!panicking&&!!(animBits&NPC_ANIM_TALK),alerted=!phoneCalling&&!crawling&&!cowering&&!surrendering&&!helping&&!panicking&&!talking&&!!(animBits&NPC_ANIM_ALERT);
        const limping=!dead&&!crawling&&(!!(animBits&NPC_ANIM_LIMP)||(hpPct>0&&hpPct<=.35));
        const crawlBlend=Math.max(0,Math.min(1,+motion?.crawlBlend||(crawling?1:0)));
        const phase=npcVisualPhases[i]||t*.008+i*.73,idle=Math.sin(t*.0018+i*1.7);
        const step=Math.sin(phase*(limping?.78:1));
        const hitRemaining=Math.max(0,(motion?.hitUntil||0)-t);
        const hit=hitRemaining?Math.sin(Math.min(1,hitRemaining/650)*Math.PI)*Math.max(.7,+motion?.hitStrength||1):0;
        const hitSide=motion?.hitSide||1,hitForward=Number.isFinite(+motion?.hitForward)?+motion.hitForward:0,gait=Math.max(0,Math.min(1,+motion?.gaitBlend||0)),walking=gait>.035&&!dead&&!cowering&&!surrendering&&!helping;
        let ambientSeed=motion?.ambientSeed;if(!Number.isFinite(ambientSeed)){ambientSeed=i*17;for(let k=0;k<key.length;k++)ambientSeed+=key.charCodeAt(k);if(motion)motion.ambientSeed=ambientSeed;}const ambientClock=((t*.001+ambientSeed*.83)%19),ambientDistance=motion?Math.hypot(motion.visualX-player.position.x,motion.visualZ-player.position.z):Infinity,ambientKind=ambientDistance<90&&!combatActor&&!walking&&!dead&&!cowering&&!surrendering&&!helping&&!panicking&&!talking&&!alerted&&ambientClock>5.5&&ambientClock<11?(ambientSeed%3)+1:0;
        const measuredSpeed=Math.hypot(+motion?.velocityX||0,+motion?.velocityZ||0),pace=Math.max(0,Math.min(1,measuredSpeed/9));
        // The player's gait is the visual baseline: a restrained .72 leg swing,
        // .21 step lift and small lateral weight shift. NPC-specific injury
        // modifiers are layered on top instead of replacing that cadence.
        const strideScale=walking?(.9+pace*.1)*(panicking?1.14:1):1,swing=walking?step*(crawling?.28:limping?.42:.72)*gait*strideScale:idle*.025;
        const leftSwing=crawling?step*.34*gait:limping?(step>0?step*.16:step*.46)*gait:swing;
        const rightSwing=crawling?-step*.34*gait:limping?-step*.62*gait:-swing;
        const leftLift=walking?Math.pow(Math.max(0,step),1.35)*(crawling?.035:limping?.06:.21)*gait:0;
        const rightLift=walking?Math.pow(Math.max(0,-step),1.35)*(crawling?.035:limping?.22:.21)*gait:0;
        const uprightBob=walking?(limping?Math.max(0,-step)*.06+Math.abs(step)*.02:Math.abs(step)*(.055+pace*.015+(panicking?.022:0))*gait):idle*.012;
        const bob=crawling?THREE.MathUtils.lerp(uprightBob,.42+(walking?Math.abs(step)*.012:idle*.008),crawlBlend):uprightBob;
        const roll=(crawling?step*.016*gait:(limping?.105+step*.04*gait:step*.026*gait))+hit*hitSide*(.16+(1-Math.abs(hitForward))*.13)+(firing?(longGun?-.035:.025)*Math.sin(firePhase*Math.PI):0);
        const crouch=cowering?.86:helping?.42:0,statePitch=cowering?.28:helping?.38:panicking?-.055:alerted?-.025:0,pitch=(crawling?1.22*crawlBlend:(walking?-(.025+pace*.035)*gait:0))+statePitch+hit*(.07+hitForward*.2)+(firing?-.045+recoil*.11:0);
        // Shoes counter-rotate during the planted half of each stride, keeping
        // the sole close to the road instead of rotating with the whole leg.
        const leftPlanted=step<0,rightPlanted=step>0;
        const leftFootPitch=walking?leftSwing*(leftPlanted?.12:.58)-leftLift*.38:0;
        const rightFootPitch=walking?rightSwing*(rightPlanted?.12:.58)-rightLift*.38:0;
        const torsoTwist=walking&&!crawling?-step*(.022+pace*.012)*gait:talking?Math.sin(t*.004+i)*.075:0;
        const naturalArmSwing=(.3+pace*.1)*gait;
        let leftArmPitch=crawling?-step*.62*gait:limping?-step*.28*gait:walking?-step*naturalArmSwing:idle*.025,rightArmPitch=crawling?step*.62*gait:limping?step*.2*gait:walking?step*naturalArmSwing:-idle*.02,leftArmRoll=walking?-.025-Math.abs(step)*.015*gait:0,rightArmRoll=walking?.025+Math.abs(step)*.015*gait:0,leftArmYaw=walking?-step*.018*gait:0,rightArmYaw=walking?step*.018*gait:0,leftArmX=-.78,rightArmX=.78,armY=2.05,armZ=0;
        if(phoneCalling){armY=2.72;armZ=.18;rightArmX=.52;rightArmPitch=-1.34;rightArmRoll=.56;leftArmPitch=-.18+Math.sin(t*.006+i)*.12;leftArmRoll=-.08;}
        else if(panicking){const wave=Math.sin(t*.014+i*1.91);armY=3.12;armZ=.08;leftArmPitch=-.12+wave*.2;rightArmPitch=.12-wave*.17;leftArmRoll=-.28-wave*.08;rightArmRoll=.28+wave*.08;}
        else if(cowering){const tremble=Math.sin(t*.019+i*2.3)*.035;leftArmX=-.52;rightArmX=.52;armY=2.56-crouch*.24;armZ=.27;leftArmPitch=-.52+tremble;rightArmPitch=-.72-tremble;leftArmRoll=-.7;rightArmRoll=.7;}
        else if(surrendering){const tremble=Math.sin(t*.012+i*1.37)*.035;leftArmX=-.68;rightArmX=.68;armY=3.38;armZ=.02;leftArmPitch=tremble;rightArmPitch=-tremble;leftArmRoll=-.22;rightArmRoll=.22;}
        else if(helping){const tend=Math.sin(t*.006+i)*.08;leftArmX=-.64;rightArmX=.64;armY=1.92-crouch*.48;armZ=.4;leftArmPitch=-1.02+tend;rightArmPitch=-.92-tend;leftArmRoll=-.12;rightArmRoll=.12;}
        else if(talking){const gestureWave=Math.sin(t*.0075+i*1.83),otherWave=Math.sin(t*.0052+i*.71);armY=2.32;armZ=.18;leftArmPitch=-.48+gestureWave*.34;rightArmPitch=-.18-otherWave*.2;leftArmRoll=-.18-gestureWave*.08;rightArmRoll=.1;}
        else if(alerted){armY=2.18;armZ=.13;leftArmPitch=-.28-(walking?step*.14*gait:0);rightArmPitch=-.46+(walking?step*.12*gait:0);leftArmRoll=-.08;rightArmRoll=.08;}
        else if(ambientKind===1){const tap=Math.sin(t*.009+i)*.08;leftArmX=-.46;rightArmX=.46;armY=2.42;armZ=.42;leftArmPitch=-.92+tap;rightArmPitch=-1.05-tap;leftArmRoll=-.42;rightArmRoll=.42;}
        else if(ambientKind===2){const drag=Math.sin(t*.004+i)*.06;armY=2.5;armZ=.18;rightArmPitch=-1.16+drag;rightArmRoll=.34;leftArmPitch=-.08;}
        else if(ambientKind===3){const stretch=Math.sin(Math.min(1,(ambientClock-5.5)/2.2)*Math.PI);armY=2.68+stretch*.35;leftArmPitch=-stretch*.18;rightArmPitch=stretch*.12;leftArmRoll=-stretch*.72;rightArmRoll=stretch*.72;}
        if(firing){armY=longGun?2.38:2.31;armZ=(longGun?.53:.46)-recoil*.27;leftArmX=longGun?-.43:-.48;rightArmX=longGun?.46:.5;leftArmPitch=(longGun?-1.22:-1.1)-recoil*.32;rightArmPitch=(longGun?-1.34:-1.24)-recoil*.44;leftArmRoll=longGun?-.3:-.2;rightArmRoll=longGun?.14:.2;leftArmYaw=longGun?-.14:-.08;rightArmYaw=longGun?.1:.08;}
        const headScan=firing?Math.sin(firePhase*Math.PI)*-.08:panicking?Math.sin(t*.008+i*2.11)*.48:cowering?Math.sin(t*.014+i)*.08:talking?Math.sin(t*.0038+i*.67)*.24:alerted?Math.sin(t*.0029+i)*.34:ambientKind===1?Math.sin(t*.0015+i)*.05:ambientKind===2?.26:Math.sin(t*.0012+i)*.08,headCounter=-torsoTwist*.7+headScan,headTilt=cowering?.08*Math.sin(t*.011+i):panicking?.04*Math.sin(t*.013+i):ambientKind===1?-.12:0,shoulderSway=walking?Math.sin(phase+Math.PI*.5)*(.025+pace*.012+(panicking?.018:0))*gait:idle*.008,legBend=cowering?.72:helping?.34:0,activeState=firing?'firing':cowering?'cower':surrendering?'surrender':helping?'helping':panicking?'panic':talking?'social':alerted?'alert':ambientKind===1?'ambient-phone':ambientKind===2?'ambient-smoke':ambientKind===3?'ambient-stretch':crawling?'crawl':limping?'limp':walking?'walk':'idle';
        return {key,motion,dead,hpPct,phoneCalling,crawling,limping,cowering,surrendering,helping,panicking,talking,alerted,ambientKind,activeState,crawlBlend,phase,idle,step,hit,hitSide,hitForward,gait,walking,leftSwing,rightSwing,leftLift,rightLift,leftFootPitch,rightFootPitch,leftArmPitch,rightArmPitch,leftArmRoll,rightArmRoll,leftArmYaw,rightArmYaw,leftArmX,rightArmX,armY,armZ,torsoTwist,headCounter,headTilt,shoulderSway,legBend,crouch,bob,roll,pitch,firing,recoil};
      };
      const npcAnimationPose=npcLifeAnimationPose;
      const setNpcRoot=(pose,i,x,z)=>{npcRootQuat.setFromEuler(new THREE.Euler(pose.pitch,npcFacingYaws[i],pose.roll,'YXZ'));rootMatrix.compose(new THREE.Vector3(x,pose.bob,z),npcRootQuat,npcScale);};
      const hidePart=(mesh,index)=>{instanceMatrix.compose(instancePosition.set(0,-1000,0),instanceQuat.identity(),hiddenScale);mesh.setMatrixAt(index,instanceMatrix);};
      const hideNpcVisual=i=>{for(const [key,mesh] of Object.entries(npcParts)){if(npcPairedPartKeys.has(key)){hidePart(mesh,i*2);hidePart(mesh,i*2+1);}else if(npcQuadPartKeys.has(key)){for(let k=0;k<4;k++)hidePart(mesh,i*4+k);}else hidePart(mesh,i);}};
      const npcEmpireWeaponMeshes=[npcParts.uniqueGunBody,npcParts.uniqueGunRail,npcParts.uniqueGunCharm,npcParts.uniqueGunStock,npcParts.uniqueGunMuzzle,npcParts.uniqueGunGrip,npcParts.uniqueGunDrum,npcParts.uniqueGunBlade,npcParts.uniqueGunLimb,npcParts.uniqueGunSpike];
      const hideNpcEmpireWeapon=i=>{for(const mesh of [npcParts.uniqueGunBody,npcParts.uniqueGunRail,npcParts.uniqueGunCharm,npcParts.uniqueGunStock,npcParts.uniqueGunMuzzle,npcParts.uniqueGunGrip,npcParts.uniqueGunDrum,npcParts.uniqueGunBlade])hidePart(mesh,i);for(let k=0;k<2;k++)hidePart(npcParts.uniqueGunLimb,i*2+k);for(let k=0;k<4;k++)hidePart(npcParts.uniqueGunSpike,i*4+k);};
      const renderNpcEmpireWeapon=(src,i,root,pose,severMask,t)=>{
        const id=String(src.uniqueWeaponId||''),cfg=npcEmpireWeaponShapes[id],gestureDisarms=pose.phoneCalling||pose.surrendering||pose.cowering||pose.helping||pose.panicking||(!src.empireBoss&&pose.talking)||!!pose.ambientKind,show=!gestureDisarms&&!(severMask&2);
        hideNpcEmpireWeapon(i);hidePart(npcParts.gun,i);if(!show)return false;
        if(!cfg){setPart(npcParts.gun,i,root,.34,2.22-pose.crouch*.3,.72,-.06-pose.recoil*.08);return false;}
        const melee=!!cfg.melee,swing=pose.firing?Math.sin(Math.min(1,Math.max(0,(t-(+src._shotAt||0))/460))*Math.PI):0;
        const x=melee ? .58 : .18,y=melee?2.02:2.25-pose.crouch*.28,z=melee ? .42 : .72;
        const pitch=melee?(-.72+swing*1.28):(-.055-pose.recoil*.09),bodyScale=instanceScale.set(cfg.body[0],cfg.body[1],cfg.body[2]);
        setPart(npcParts.uniqueGunBody,i,root,x,y,z,pitch,bodyScale);
        setPart(npcParts.uniqueGunGrip,i,root,x+(melee?0:.12),y-.35,z-.22,pitch-.16,instanceScale.set(melee ? .8 : 1,.82,melee ? .8 : 1));
        if(cfg.barrel)setPart(npcParts.uniqueGunMuzzle,i,root,x,y+.02,z+.78+cfg.barrel*.23,pitch+Math.PI/2,instanceScale.set(cfg.shape==='harpoon'?1.18:.82,cfg.barrel,.82));
        if(cfg.stock)setPart(npcParts.uniqueGunStock,i,root,x,y-.04,z-.62,pitch,instanceScale.set(.82,.82,cfg.stock));
        if(cfg.scope)setPart(npcParts.uniqueGunRail,i,root,x,y+.31,z+.08,pitch,instanceScale.set(cfg.scope,.75,.48));
        if(cfg.drum)setPart(npcParts.uniqueGunDrum,i,root,x,y-.3,z-.02,pitch,instanceScale.set(cfg.drum,cfg.drum,.85),0,Math.PI/2);
        if(cfg.blade)setPart(npcParts.uniqueGunBlade,i,root,x,y+.02,z+1.18,pitch+Math.PI/2,instanceScale.set(cfg.blade,cfg.blade*1.25,cfg.blade));
        if(cfg.limbs){for(const [k,side] of [[0,-1],[1,1]])setPart(npcParts.uniqueGunLimb,i*2+k,root,x+side*cfg.limbs*.34,y+.04,z+.35,pitch,instanceScale.set(.72,.72,cfg.limbs),Math.PI/2,side*.18);}
        if(cfg.spikes){for(let k=0;k<cfg.spikes;k++){const side=k%2?-1:1,along=(k+.7)/(cfg.spikes+1);setPart(npcParts.uniqueGunSpike,i*4+k,root,x+side*.18,y+.04,z-.38+along*1.35,pitch,instanceScale.setScalar(.9),0,side*Math.PI/2);}}
        if(cfg.shape==='crossbow'||cfg.shape==='harpoon')setPart(npcParts.uniqueGunRail,i,root,x,y+.16,z+.46,pitch,instanceScale.set(.72,.58,1.42));
        if(cfg.shape==='bat')setPart(npcParts.uniqueGunCharm,i,root,x,y,z+1.02,pitch+t*.001,instanceScale.setScalar(.92));
        // Both hands meet the grip/fore-end. The weapon stays at chest height and
        // points along local +Z, so it cannot rotate through the head anymore.
        if(melee){setPart(npcParts.rightArm,i,root,.61,2.12,.2,-.82+swing*.72,unitScale,.08,.14);setPart(npcParts.leftArm,i,root,-.42,2.08,.28,-.58+swing*.42,unitScale,-.12,-.24);}
        else{setPart(npcParts.rightArm,i,root,.48,2.34,.38,-1.2-pose.recoil*.18,unitScale,.08,.18);setPart(npcParts.leftArm,i,root,-.43,2.35,.48,-1.08-pose.recoil*.12,unitScale,-.12,-.28);}
        const colorSig=`${id}:${cfg.primary}:${cfg.accent}`;if(npcEmpireWeaponColorSignatures[i]===colorSig)return false;npcEmpireWeaponColorSignatures[i]=colorSig;
        for(const mesh of [npcParts.uniqueGunBody,npcParts.uniqueGunStock,npcParts.uniqueGunGrip,npcParts.uniqueGunDrum])mesh.setColorAt(i,instanceColor.setHex(cfg.primary));
        for(const mesh of [npcParts.uniqueGunRail,npcParts.uniqueGunCharm,npcParts.uniqueGunMuzzle,npcParts.uniqueGunBlade])mesh.setColorAt(i,instanceColor.setHex(cfg.accent));
        for(let k=0;k<2;k++)npcParts.uniqueGunLimb.setColorAt(i*2+k,instanceColor.setHex(cfg.accent));for(let k=0;k<4;k++)npcParts.uniqueGunSpike.setColorAt(i*4+k,instanceColor.setHex(cfg.accent));return true;
      };
      const muzzlePool=[],impactPool=[],explosionPool=[],throwablePool=[],firePool=[],burningActorPool=[];
      for(let i=0;i<16;i++){const flash=new THREE.Group(),core=new THREE.Mesh(new THREE.SphereGeometry(.34,10,7),new THREE.MeshBasicMaterial({color:0xffc35a,transparent:true,depthTest:false,toneMapped:false,blending:THREE.AdditiveBlending}));flash.add(core);for(let p=0;p<4;p++){const petal=new THREE.Mesh(new THREE.ConeGeometry(.16,1.05,7),core.material.clone());petal.rotation.x=Math.PI/2;petal.rotation.z=p*Math.PI/2;petal.position.z=.42;flash.add(petal);}const smoke=new THREE.Mesh(new THREE.DodecahedronGeometry(.28,1),new THREE.MeshBasicMaterial({color:0x5a6269,transparent:true,opacity:.35,depthWrite:false}));smoke.position.set(0,.3,-.15);flash.add(smoke);flash.userData={core,smoke};flash.layers.enable(1);flash.renderOrder=37;flash.visible=false;scene.add(flash);muzzlePool.push(flash);const impact=new THREE.Group(),impactCore=new THREE.Mesh(new THREE.IcosahedronGeometry(.3,1),new THREE.MeshBasicMaterial({color:0xffd36a,transparent:true,depthTest:false,toneMapped:false,blending:THREE.AdditiveBlending}));impact.add(impactCore);const sparks=[];for(let s=0;s<8;s++){const spark=new THREE.Mesh(new THREE.CylinderGeometry(.018,.04,.8,5),impactCore.material.clone());spark.rotation.z=(s/8)*Math.PI*2;spark.position.set(Math.cos(s/8*Math.PI*2)*.35,.15+Math.sin(s)*.12,Math.sin(s/8*Math.PI*2)*.35);impact.add(spark);sparks.push(spark);}const bloodDrops=[];for(let d=0;d<12;d++){const drop=new THREE.Mesh(new THREE.SphereGeometry(.055+(d%3)*.025,7,5),new THREE.MeshBasicMaterial({color:d%4?0xc30d1b:0x5c0509,transparent:true,opacity:.94,depthWrite:false,toneMapped:false}));impact.add(drop);bloodDrops.push(drop);}const bloodSplat=new THREE.Mesh(new THREE.CircleGeometry(.72,18),new THREE.MeshBasicMaterial({color:0x65070c,transparent:true,opacity:.72,depthWrite:false,side:THREE.DoubleSide,toneMapped:false}));bloodSplat.rotation.x=-Math.PI/2;bloodSplat.position.y=.015;impact.add(bloodSplat);impact.userData={core:impactCore,sparks,bloodDrops,bloodSplat};impact.layers.enable(1);impact.renderOrder=38;impact.visible=false;scene.add(impact);impactPool.push(impact);}
      for(let i=0;i<4;i++){
        const blast=new THREE.Group(),core=new THREE.Mesh(explosionCoreGeometry,new THREE.MeshBasicMaterial({color:0xff7b25,transparent:true,depthTest:true,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending})),fireShell=new THREE.Mesh(explosionFireGeometry,new THREE.MeshBasicMaterial({color:0xffb32b,transparent:true,opacity:.7,depthTest:true,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));
        blast.add(core,fireShell);
        const shock=new THREE.Mesh(explosionShockGeometry,new THREE.MeshBasicMaterial({color:0xffd27a,transparent:true,opacity:.9,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));shock.rotation.x=-Math.PI/2;blast.add(shock);
        const groundRing=new THREE.Mesh(explosionGroundGeometry,new THREE.MeshBasicMaterial({color:0xff6418,transparent:true,opacity:.8,side:THREE.DoubleSide,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));groundRing.rotation.x=-Math.PI/2;groundRing.position.y=.08;blast.add(groundRing);
        // A PointLight that appeared only during a blast changed Three's light
        // signature and recompiled hundreds of city materials on that frame.
        // The additive shells provide the flash without a dynamic scene light.
        const flashLight={intensity:0,visible:false};
        const smoke=createPooledVehicleFx(explosionSmokeGeometry,new THREE.MeshStandardMaterial({color:0xffffff,transparent:true,opacity:.78,roughness:1,depthWrite:false}),8);
        smoke.items.forEach((puff,s)=>{const k=(.65+(s%3)*.15)/.65;puff.baseScale.setScalar(k);smoke.mesh.setColorAt(s,new THREE.Color(s%2?0x292b30:0x444147));});smoke.mesh.instanceColor.needsUpdate=true;blast.add(smoke.mesh);
        const embers=createPooledVehicleFx(explosionEmberGeometry,new THREE.MeshBasicMaterial({color:0xffffff,toneMapped:false,blending:THREE.AdditiveBlending}),20);
        embers.items.forEach((ember,s)=>{const k=(.09+(s%3)*.035)/.09;ember.baseScale.setScalar(k);embers.mesh.setColorAt(s,new THREE.Color(s%3?0xff8b24:0xfff0a0));});embers.mesh.instanceColor.needsUpdate=true;blast.add(embers.mesh);
        const debris=createPooledVehicleFx(explosionDebrisGeometry,new THREE.MeshStandardMaterial({color:0xffffff,metalness:.55,roughness:.62}),10);
        debris.items.forEach((shard,s)=>{shard.baseScale.z=(.32+(s%3)*.12)/.32;debris.mesh.setColorAt(s,new THREE.Color(s%2?0x312b29:0x75614d));});debris.mesh.instanceColor.needsUpdate=true;blast.add(debris.mesh);
        const plumes=createPooledVehicleFx(realFlameGeometry,realFlameMaterial,10);plumes.items.forEach((flame,s)=>flame.baseScale.set(.72+(s%3)*.16,1.18+(s%4)*.22,1));blast.add(plumes.mesh);
        blast.userData={core,fireShell,shock,groundRing,flashLight,smoke,embers,debris,plumes};blast.visible=false;scene.add(blast);explosionPool.push(blast);
      }
      for(let i=0;i<8;i++){const item=new THREE.Group(),grenade=new THREE.Mesh(new THREE.SphereGeometry(.24,10,8),new THREE.MeshStandardMaterial({color:0x536547,metalness:.42,roughness:.58})),bottle=new THREE.Mesh(new THREE.CylinderGeometry(.12,.19,.7,10),new THREE.MeshPhysicalMaterial({color:0x8a4b22,transparent:true,opacity:.8,transmission:.18,roughness:.2})),wick=new THREE.Mesh(new THREE.ConeGeometry(.12,.42,7),new THREE.MeshBasicMaterial({color:0xff8b1e,toneMapped:false,blending:THREE.AdditiveBlending}));wick.position.y=.55;item.add(grenade,bottle,wick);item.userData={grenade,bottle,wick};item.visible=false;scene.add(item);throwablePool.push(item);}
      const groundFireSmokeGeometry=new THREE.DodecahedronGeometry(.5,1),actorFireFlameGeometry=new THREE.ConeGeometry(.18,.75,7);
      for(let i=0;i<12;i++){const fire=new THREE.Group(),glow=new THREE.Mesh(new THREE.CircleGeometry(2.2,28),new THREE.MeshBasicMaterial({color:0xff5a12,transparent:true,opacity:.18,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}));glow.rotation.x=-Math.PI/2;glow.position.y=.07;fire.add(glow);const flames=createPooledVehicleFx(realFlameGeometry,realFlameMaterial,10),smokes=createPooledVehicleFx(groundFireSmokeGeometry,new THREE.MeshBasicMaterial({color:0x17171a,transparent:true,opacity:.38,depthWrite:false}),5);flames.items.forEach((flame,s)=>flame.baseScale.set(.72+(s%3)*.16,1.2+(s%4)*.24,1));fire.add(flames.mesh,smokes.mesh);fire.userData={glow,flames,smokes};fire.visible=false;scene.add(fire);firePool.push(fire);}
      for(let i=0;i<12;i++){const actorFire=new THREE.Group(),flames=createPooledVehicleFx(actorFireFlameGeometry,new THREE.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:.9,toneMapped:false,blending:THREE.AdditiveBlending,depthWrite:false}),5);flames.items.forEach((flame,s)=>{flame.baseScale.y=(.75+s*.1)/.75;flames.mesh.setColorAt(s,new THREE.Color(s%2?0xff7517:0xffdd55));});flames.mesh.instanceColor.needsUpdate=true;actorFire.add(flames.mesh);actorFire.userData={flames};actorFire.visible=false;scene.add(actorFire);burningActorPool.push(actorFire);}
      for(const fx of [...muzzlePool,...impactPool,...explosionPool,...throwablePool,...firePool,...burningActorPool])fx.traverse(o=>o.layers.enable(1));
      startupMark('combat-fx-pools');
      const vehicleFxWarmupSources=[],vehicleFxWarmupActive=[];
      for(const layer of cars[0]?.userData?.bodyHoleLayers||[])vehicleFxWarmupSources.push(layer.mesh);
      explosionPool[0]?.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      firePool[0]?.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      // Police fire is often the first combat seen in a fresh session. Pooled
      // meshes have count=0 / visible=false at startup, so Three otherwise
      // compiles their shader variants on the first shot and can block a WebView
      // for several seconds. Render one invisible proxy of every essential
      // combat variant while the loading screen is still up.
      for(const source of [worldBullets,worldBulletTrails,worldBulletGlows,worldBulletCores,worldArrowShafts,worldArrowHeads,worldArrowFletching,...npcEmpireWeaponMeshes,shellPool,bloodDecals,corpseBloodDecals,goreLimbs,goreChunks,bulletHoleDecals])vehicleFxWarmupSources.push(source);
      // Riot visors are zero-scaled until the first prison response arrives.
      // Keep their instanced physical-material variants in the same bounded
      // startup queue so that response animation cannot compile them mid-shot.
      vehicleFxWarmupSources.push(npcParts.prisonVisor,npcParts.shieldViewport);
      // Each pooled muzzle/impact owns material instances because opacity and
      // tint animate independently. Warm every instance, not just slot zero.
      for(const fx of muzzlePool)fx.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      for(const fx of impactPool)fx.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      throwablePool[0]?.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      burningActorPool[0]?.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      arrestCuffs.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
      // Wrecks reuse the already-uploaded live car shell, so only one reference
      // effect set needs shader warm-up; there is no per-slot wreck upload spike.
      const warmupCar=cars[0];let matteWreckWarmMaterial=null;
      if(warmupCar){
        vehicleFxWarmupSources.push(warmupCar.userData.damageSmoke.mesh,warmupCar.userData.damageFlames.mesh);
        warmupCar.userData.wreckGroup.traverse(o=>{if(o.isMesh)vehicleFxWarmupSources.push(o);});
        matteWreckWarmMaterial=warmupCar.userData.paint.clone();matteWreckWarmMaterial.color.copy(wreckedCarColor);matteWreckWarmMaterial.roughness=.98;matteWreckWarmMaterial.metalness=.12;matteWreckWarmMaterial.clearcoat=0;
      }
      const vehicleFxWarmupMatrix=new THREE.Matrix4(),startupFxWarmupGroup=new THREE.Group();let vehicleFxWarmupCursor=0,vehicleFxWarmupDone=false;
      for(const source of vehicleFxWarmupSources){const proxy=source.isInstancedMesh?new THREE.InstancedMesh(source.geometry,source.material,1):new THREE.Mesh(source.geometry,source.material);if(proxy.isInstancedMesh){proxy.setMatrixAt(0,vehicleFxWarmupMatrix.identity());if(source.instanceColor)proxy.setColorAt(0,new THREE.Color(0xffffff));proxy.instanceMatrix.needsUpdate=true;if(proxy.instanceColor)proxy.instanceColor.needsUpdate=true;}proxy.position.set(0,-900,0);proxy.frustumCulled=false;proxy.castShadow=proxy.receiveShadow=false;proxy.layers.set(0);startupFxWarmupGroup.add(proxy);}scene.add(startupFxWarmupGroup);renderer.domElement.dataset.combatFxWarmup=`queued:${startupFxWarmupGroup.children.length}`;
      const finishStartupFxWarmup=()=>{scene.remove(startupFxWarmupGroup);startupFxWarmupGroup.clear();vehicleFxWarmupActive.length=0;vehicleFxWarmupSources.length=0;vehicleFxWarmupCursor=0;vehicleFxWarmupDone=true;renderer.domElement.dataset.vehicleFxWarmup='ready';renderer.domElement.dataset.combatFxWarmup='ready-before-gameplay';};
      const stepVehicleFxWarmup=()=>{
        if(vehicleFxWarmupDone)return;
        while(vehicleFxWarmupActive.length)scene.remove(vehicleFxWarmupActive.pop());
        for(let n=0;n<3&&vehicleFxWarmupCursor<vehicleFxWarmupSources.length;n++){
          const source=vehicleFxWarmupSources[vehicleFxWarmupCursor++],proxy=source.isInstancedMesh?new THREE.InstancedMesh(source.geometry,source.material,1):new THREE.Mesh(source.geometry,source.material);
          if(proxy.isInstancedMesh){proxy.setMatrixAt(0,vehicleFxWarmupMatrix.identity());if(source.instanceColor)proxy.setColorAt(0,new THREE.Color(0xffffff));proxy.instanceMatrix.needsUpdate=true;if(proxy.instanceColor)proxy.instanceColor.needsUpdate=true;}
          proxy.position.set(0,-900,0);proxy.frustumCulled=false;proxy.castShadow=proxy.receiveShadow=false;proxy.layers.set(0);scene.add(proxy);vehicleFxWarmupActive.push(proxy);
        }
        const remaining=vehicleFxWarmupSources.length-vehicleFxWarmupCursor;renderer.domElement.dataset.vehicleFxWarmup=remaining?`warming:${remaining}`:'ready';
        if(!remaining&&!vehicleFxWarmupActive.length){vehicleFxWarmupDone=true;vehicleFxWarmupSources.length=0;}
      };
      renderer.domElement.dataset.vehicleHitMarkDrawCalls='4-instanced-layers';
      renderer.domElement.dataset.vehicleExplosionDrawCalls='7-pooled-layers';
      renderer.domElement.dataset.vehicleExplosionCapacity='4-overlapping-bursts';
      renderer.domElement.dataset.wreckFxCap='0-static-charred-live-shells';
      renderer.domElement.dataset.weaponFx='profiled-recoil-tracers-casings-blood-decals-hit-reactions-explosions-fire';
      const interiorGroup=new THREE.Group(),interiorVisualFx=[];interiorGroup.layers.set(1);interiorGroup.visible=false;scene.add(interiorGroup);const interiorAmbient=new THREE.HemisphereLight(0xffead1,0x4a3542,3.35);interiorAmbient.layers.set(1);scene.add(interiorAmbient);let interiorSignature='',interiorFloor=null,interiorLightingActive=false;
      // rebuildInterior historically pops direct children. Hook that one local
      // array so nested meshes, material arrays and canvas textures are released
      // as well; shared renderer resources are marked persistent by the disposer.
      const popInteriorChild=interiorGroup.children.pop.bind(interiorGroup.children);
      interiorGroup.children.pop=()=>{const child=popInteriorChild();if(child)disposeTransientObjectTree(child);return child;};
      const interiorMatFor=type=>({hospital:0xc8ddd8,gym:0x775543,police_st:0x53677d,business:0x6a5142,blackmarket:0x342d3b,bank:0x8a816f,generic:0x493a31}[type]||0x62584f);
      const rebuildInterior=data=>{interiorVisualFx.length=0;while(interiorGroup.children.length){const o=interiorGroup.children.pop();o.geometry?.dispose?.();if(o.material&&!Array.isArray(o.material))o.material.dispose?.();}const W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,floorMat=new THREE.MeshStandardMaterial({color:interiorMatFor(data.type),roughness:.86}),wallMat=new THREE.MeshStandardMaterial({color:0x313943,roughness:.74}),trimMat=new THREE.MeshStandardMaterial({color:0xb89a61,roughness:.56,metalness:.18}),redMat=new THREE.MeshStandardMaterial({color:0x9f2f32,roughness:.62}),softMat=new THREE.MeshStandardMaterial({color:0x315978,roughness:.82}),whiteMat=new THREE.MeshStandardMaterial({color:0xe6ecec,roughness:.7});const add=(geo,mat,x,y,z)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;};interiorFloor=add(new THREE.PlaneGeometry(W,H),floorMat,cx,.02,cz);interiorFloor.rotation.x=-Math.PI/2;const grid=new THREE.GridHelper(Math.max(W,H),Math.max(8,Math.floor(Math.max(data.width,data.height))),0x4b3f35,0x4b3f35);grid.position.set(cx,.055,cz);grid.material.transparent=true;grid.material.opacity=.2;grid.layers.set(1);interiorGroup.add(grid);add(new THREE.BoxGeometry(W,5,.7),wallMat,cx,2.5,(.1-originR)*WORLD_SCALE);add(new THREE.BoxGeometry(.7,5,H),wallMat,(.1-originC)*WORLD_SCALE,2.5,cz);add(new THREE.BoxGeometry(.7,1.25,H),wallMat,(data.width-.1-originC)*WORLD_SCALE,.625,cz);const backZ=(data.height-.1-originR)*WORLD_SCALE;add(new THREE.BoxGeometry(W*.38,1.25,.7),wallMat,cx-W*.31,.625,backZ);add(new THREE.BoxGeometry(W*.38,1.25,.7),wallMat,cx+W*.31,.625,backZ);const exitGlow=add(new THREE.BoxGeometry(4.2,.2,1.1),new THREE.MeshBasicMaterial({color:0x4dff8a}),cx,.35,backZ-.5);exitGlow.rotation.x=-Math.PI/2;if(data.type==='bank'||data.kind==='bank'){if(data.room==='vault'){const vault=add(new THREE.CylinderGeometry(5.2,5.2,1.25,32),new THREE.MeshStandardMaterial({color:0x69747c,metalness:.88,roughness:.24}),cx,3.2,cz-H*.25);vault.rotation.x=Math.PI/2;for(let i=-2;i<=2;i++)add(new THREE.BoxGeometry(3.2,2.2,2.2),trimMat,cx+i*4.1,1.1,cz+H*.12);}else{for(let i=-2;i<=2;i++)add(new THREE.BoxGeometry(W*.1,1.5,2.1),trimMat,cx+i*W*.14,.75,cz-H*.18);for(const sx of [-W*.32,W*.32])add(new THREE.CylinderGeometry(.38,.48,4.8,14),whiteMat,cx+sx,2.4,cz+H*.2);}}else if(data.type==='hospital'){for(let i=-1;i<=1;i++){add(new THREE.BoxGeometry(4.2,.75,2),whiteMat,cx+i*6,1,cz-H*.12);add(new THREE.BoxGeometry(.25,1.6,1.7),new THREE.MeshBasicMaterial({color:0x62d7ec}),cx+i*6-1.8,1.35,cz-H*.12);}}else if(data.bizId==='barbershop'){for(const dx of [-7,0,7]){add(new THREE.CylinderGeometry(1.05,1.2,.55,16),redMat,cx+dx,.72,cz);add(new THREE.BoxGeometry(2.2,2.8,.22),new THREE.MeshStandardMaterial({color:0x9ed5e6,metalness:.72,roughness:.12}),cx+dx,2.4,cz-H*.28);}}else if(['coffee','pizza','bar'].includes(data.bizId)){for(const [dx,dz] of [[-7,-4],[0,-4],[7,-4],[-4,4],[4,4]]){add(new THREE.CylinderGeometry(1.45,1.45,.35,16),trimMat,cx+dx,1.1,cz+dz);for(let i=0;i<3;i++){const a=i*Math.PI*2/3;add(new THREE.BoxGeometry(.8,.8,.8),wallMat,cx+dx+Math.cos(a)*2,.4,cz+dz+Math.sin(a)*2);}}if(data.bizId==='bar')add(new THREE.BoxGeometry(W*.58,1.5,2.4),redMat,cx,.75,cz-H*.28);}else if(['warehouse','port'].includes(data.bizId)){for(let i=0;i<12;i++)add(new THREE.BoxGeometry(2.2,1.8,2.2),new THREE.MeshStandardMaterial({color:i%3?0x8c5732:0x526f78,roughness:.8}),cx-9+(i%4)*6,.9,cz-6+Math.floor(i/4)*5);}else if(['garage','carwash'].includes(data.bizId)){for(const dx of [-6,6]){add(new THREE.BoxGeometry(5,.35,10),new THREE.MeshStandardMaterial({color:0x38444b,metalness:.5,roughness:.45}),cx+dx,.3,cz);add(new THREE.BoxGeometry(.45,3,.45),trimMat,cx+dx-2,1.5,cz);add(new THREE.BoxGeometry(.45,3,.45),trimMat,cx+dx+2,1.5,cz);}}else if(['club','casino'].includes(data.bizId)){add(new THREE.BoxGeometry(W*.5,.18,H*.42),new THREE.MeshBasicMaterial({color:0x7d38bf}),cx,.1,cz);const neon=new THREE.PointLight(0xff42d0,12,28,2);neon.position.set(cx,5,cz);neon.layers.set(1);interiorGroup.add(neon);}else if(!(data.kind==='building'&&data.type==='generic'&&!data.bizId)){add(new THREE.BoxGeometry(7,1.3,3),softMat,cx-5,.65,cz);add(new THREE.BoxGeometry(5.5,1.05,3.2),trimMat,cx+6,.53,cz-4);add(new THREE.BoxGeometry(6,.55,7),whiteMat,cx+7,.28,cz+5);add(new THREE.BoxGeometry(2.5,3.2,.8),wallMat,cx+W*.28,1.6,cz-H*.25);}if(data.loot){const lootMat=new THREE.MeshStandardMaterial({color:data.loot.hp?0x5bdc83:0xd6aa42,emissive:data.loot.hp?0x123d20:0x4a2f08,emissiveIntensity:.9,metalness:.24,roughness:.45}),loot=add(new THREE.BoxGeometry(1.6,1.1,1.35),lootMat,(data.loot.c-originC)*WORLD_SCALE,.65,(data.loot.r-originR)*WORLD_SCALE);outline(loot);}const ceiling=new THREE.RectAreaLight(0xffe2b0,7,W*.7,H*.55);ceiling.position.set(cx,9,cz);ceiling.lookAt(cx,0,cz);ceiling.layers.set(1);interiorGroup.add(ceiling);interiorGroup.visible=true;};
      const decorateBankInterior=data=>{
        if(data.kind!=='bank'||!data.bank)return false;
        const B=data.bank,W=+data.width||18,H=+data.height||16,S=WORLD_SCALE,x=c=>(c-originC)*S,z=r=>(r-originR)*S;
        // children.pop is wrapped above with recursive disposal; do not dispose the same tree a second time.
        while(interiorGroup.children.length)interiorGroup.children.pop();
        const addRaw=(geo,material,px,y,pz,parent=interiorGroup)=>{const mesh=new THREE.Mesh(geo,material);mesh.position.set(px,y,pz);mesh.castShadow=mesh.receiveShadow=true;mesh.layers.set(1);parent.add(mesh);return mesh;};
        const add=(geo,material,c,y,r,parent=interiorGroup)=>addRaw(geo,material,x(c),y,z(r),parent);
        const std=(color,roughness=.72,metalness=.05)=>new THREE.MeshStandardMaterial({color,roughness,metalness});
        const brass=std(0xb68b38,.25,.82),gold=std(0xd0aa52,.3,.72),steel=std(0x67737c,.22,.88),steelDark=std(0x343e47,.32,.78);
        const wall=std(0xd4cab7,.72,.04),wallDark=std(0x37414b,.58,.32),wood=std(0x5a3422,.7),woodDark=std(0x2e1d19,.66,.1);
        const marble=std(0xe5ded0,.3,.12),marbleDark=std(0x8e897f,.38,.18),carpet=std(0x273d59,.95),loungeWood=std(0x745039,.72);
        const fabric=std(0x284e67,.94),fabricWarm=std(0x713744,.94),cream=std(0xe8dfcd,.82),black=std(0x11151b,.42,.38),green=std(0x315f45,.9);
        const cash=std(0x739153,.84),bagMat=std(0x81623b,.95),red=std(0x8f2630,.72),paper=std(0xeee6d4,.94);
        const glass=new THREE.MeshPhysicalMaterial({color:0x96c9d7,transparent:true,opacity:.3,transmission:.38,roughness:.06,metalness:.08,side:THREE.DoubleSide});
        const screenBlue=new THREE.MeshBasicMaterial({color:0x4fc3f2,toneMapped:false}),screenGreen=new THREE.MeshBasicMaterial({color:0x69d28c,toneMapped:false});
        const floorZone=(c,r,w,d,material,y=.04)=>{const floor=add(new THREE.PlaneGeometry(w*S,d*S),material,c,y,r);floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;return floor;};
        const hWall=(c0,c1,r,height=4.35,material=wall)=>{if(c1-c0<.08)return;add(new THREE.BoxGeometry((c1-c0)*S,height,.28*S),material,(c0+c1)/2,height/2,r);add(new THREE.BoxGeometry((c1-c0)*S+.05,.22,.36*S),material===wallDark?steelDark:woodDark,(c0+c1)/2,.11,r);add(new THREE.BoxGeometry((c1-c0)*S+.05,.14,.36*S),material===wallDark?steel:brass,(c0+c1)/2,height-.07,r).castShadow=false;};
        const vWall=(c,r0,r1,height=4.35,material=wall)=>{if(r1-r0<.08)return;add(new THREE.BoxGeometry(.28*S,height,(r1-r0)*S),material,c,height/2,(r0+r1)/2);add(new THREE.BoxGeometry(.36*S,.22,(r1-r0)*S+.05),material===wallDark?steelDark:woodDark,c,.11,(r0+r1)/2);add(new THREE.BoxGeometry(.36*S,.14,(r1-r0)*S+.05),material===wallDark?steel:brass,c,height-.07,(r0+r1)/2).castShadow=false;};
        const signSprite=(text,color='#d4b35c')=>{const canvas=document.createElement('canvas');canvas.width=512;canvas.height=144;const ctx=canvas.getContext('2d');ctx.fillStyle='rgba(15,22,29,.94)';ctx.fillRect(5,5,502,134);ctx.strokeStyle=color;ctx.lineWidth=7;ctx.strokeRect(10,10,492,124);ctx.font='900 50px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillStyle='#f6edd9';ctx.fillText(text,256,74);const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false,toneMapped:false}));sprite.renderOrder=65;sprite.layers.set(1);return sprite;};
        const roomSign=(text,c,r,y=4.7,color='#d4b35c',scale=1)=>{const sprite=signSprite(text,color);sprite.position.set(x(c),y,z(r));sprite.scale.set(4.7*scale,1.35*scale,1);interiorGroup.add(sprite);return sprite;};
        const chair=(c,r,angle=0,upholstery=fabric)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=angle;g.layers.set(1);interiorGroup.add(g);addRaw(new THREE.CylinderGeometry(.3,.4,.12,16),black,0,.09,0,g);addRaw(new THREE.CylinderGeometry(.06,.09,.48,10),steel,0,.36,0,g);const seat=addRaw(new THREE.SphereGeometry(.48,16,10),upholstery,0,.72,0,g);seat.scale.set(1.15,.32,1);const back=addRaw(new THREE.CapsuleGeometry(.3,.58,7,14),upholstery,0,1.25,-.42,g);back.scale.set(1.25,1,.32);for(const side of [-1,1])addRaw(new THREE.BoxGeometry(.08,.08,.62),brass,side*.48,.93,-.03,g).castShadow=false;};
        const sofa=(c,r,width=3.2,angle=0,upholstery=fabricWarm)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=angle;g.layers.set(1);interiorGroup.add(g);const seat=addRaw(new THREE.CapsuleGeometry(.42,Math.max(.4,width*S-.84),8,18),upholstery,0,.55,0,g);seat.rotation.z=Math.PI/2;seat.scale.z=1.05;const back=addRaw(new THREE.CapsuleGeometry(.38,Math.max(.4,width*S-.76),8,18),upholstery,0,1.16,-.47*S,g);back.rotation.z=Math.PI/2;back.scale.z=.36;for(const side of [-1,1]){const arm=addRaw(new THREE.CapsuleGeometry(.26,.48,7,12),upholstery,side*(width*S/2-.28),.72,0,g);arm.scale.z=.72;addRaw(new THREE.CylinderGeometry(.06,.08,.18,8),brass,side*(width*S/2-.28),.1,0,g);}for(const side of [-.5,.5]){const cushion=addRaw(new THREE.SphereGeometry(.36,12,8),side>0?cream:upholstery,side*width*S*.42,.83,-.08,g);cushion.scale.set(1.05,.34,.78);}};
        const monitor=(c,r,y=1.85,turn=0,glow=screenBlue)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);addRaw(new THREE.CylinderGeometry(.04,.07,.55,8),steel,0,y-.35,0,g);addRaw(new THREE.BoxGeometry(.92*S,.72,.12),black,0,y,.02*S,g);addRaw(new THREE.PlaneGeometry(.8*S,.58),glow,0,y,.09*S,g).castShadow=false;for(let line=0;line<3;line++)addRaw(new THREE.BoxGeometry(.55*S,.025,.012),paper,-.06*S,y+.18-line*.17,.105*S,g).castShadow=false;};
        const desk=(c,r,w=3.1,d=1.15,turn=0)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);addRaw(new THREE.BoxGeometry(w*S,.2,d*S),wood,0,1.05,0,g);for(const side of [-1,1])addRaw(new THREE.BoxGeometry(.28*S,1.02,(d-.12)*S),woodDark,side*(w*S/2-.22*S),.52,0,g);const form=addRaw(new THREE.BoxGeometry(.9*S,.12,.65*S),paper,-.55*S,1.18,.02*S,g);form.rotation.y=.08;};
        const plant=(c,r,scale=1)=>{add(new THREE.CylinderGeometry(.42*scale,.58*scale,.62*scale,14),std(0x7b4b32,.9),c,.31*scale,r);for(let k=0;k<7;k++){const a=k/7*Math.PI*2,leaf=add(new THREE.SphereGeometry(.34*scale,10,7),green,c+Math.sin(a)*.3*scale,1+(k%3)*.24*scale,r+Math.cos(a)*.28*scale);leaf.scale.set(.65,1.45,.5);leaf.rotation.z=Math.sin(a)*.4;}};
        const cameraProp=(c,r,y=3.85,turn=0)=>{const g=new THREE.Group();g.position.set(x(c),y,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);addRaw(new THREE.BoxGeometry(.1,.1,.65),steel,0,0,-.25,g);const body=addRaw(new THREE.CapsuleGeometry(.17,.45,6,12),steelDark,0,-.04,.16,g);body.rotation.x=Math.PI/2;body.scale.z=.65;const lens=addRaw(new THREE.CylinderGeometry(.12,.12,.12,12),black,0,-.04,.5,g);lens.rotation.x=Math.PI/2;addRaw(new THREE.SphereGeometry(.035,7,5),new THREE.MeshBasicMaterial({color:0xff3030,toneMapped:false}),.11,.03,.49,g).castShadow=false;};
        const moneyBag=(c,r,rotation=0)=>{const g=new THREE.Group();g.position.set(x(c),.45,z(r));g.rotation.y=rotation;g.scale.setScalar(S*.38);g.layers.set(1);interiorGroup.add(g);const body=addRaw(new THREE.SphereGeometry(.47,14,10),bagMat,0,0,0,g);body.scale.set(.92,.82,.72);addRaw(new THREE.CylinderGeometry(.11,.2,.3,10),bagMat,0,.42,0,g);const tie=addRaw(new THREE.TorusGeometry(.15,.035,6,12),brass,0,.34,0,g);tie.rotation.x=Math.PI/2;addRaw(new THREE.TorusGeometry(.14,.035,6,12),gold,0,.02,.36,g).castShadow=false;};
        const bankDoor=(c,r,face=1,open=false)=>{const pivot=new THREE.Group();pivot.position.set(x(c),0,z(r));pivot.layers.set(1);interiorGroup.add(pivot);const g=new THREE.Group();g.position.x=open?-2*S:0;g.rotation.y=open?-.48*face:0;g.layers.set(1);pivot.add(g);const frame=addRaw(new THREE.TorusGeometry(2.15,.24,12,36),steelDark,0,2.45,0,g);frame.rotation.x=Math.PI/2;const door=addRaw(new THREE.CylinderGeometry(1.92,1.92,.58,36),steel,0,2.45,.03*face,g);door.rotation.x=Math.PI/2;for(let k=0;k<12;k++){const a=k/12*Math.PI*2,bolt=addRaw(new THREE.CylinderGeometry(.09,.09,.18,9),brass,Math.cos(a)*1.48,2.45+Math.sin(a)*1.48,.36*face,g);bolt.rotation.x=Math.PI/2;}const wheel=addRaw(new THREE.TorusGeometry(.62,.1,9,24),brass,0,2.45,.39*face,g);wheel.rotation.x=Math.PI/2;for(let k=0;k<6;k++){const a=k/6*Math.PI*2,spoke=addRaw(new THREE.BoxGeometry(1.18,.055,.055),brass,Math.cos(a)*.3,2.45+Math.sin(a)*.3,.41*face,g);spoke.rotation.z=a;spoke.castShadow=false;}};
        const ceilingLight=(c,r,color=0xffe8c4,intensity=2.2)=>{add(new THREE.BoxGeometry(2.4*S,.12,.55*S),steel,c,5.55,r).castShadow=false;add(new THREE.BoxGeometry(2.1*S,.08,.42*S),new THREE.MeshBasicMaterial({color,toneMapped:true}),c,5.48,r).castShadow=false;const light=new THREE.PointLight(color,intensity,12*S,2);light.position.set(x(c),5.15,z(r));light.layers.set(1);interiorGroup.add(light);};
        const alarm=(c,r)=>{add(new THREE.CylinderGeometry(.25,.32,.28,14),red,c,4.45,r);const dome=add(new THREE.SphereGeometry(.24,12,8),new THREE.MeshBasicMaterial({color:B.alarmTriggered?0xff1d22:0x682126,toneMapped:false}),c,4.67,r);dome.scale.y=.72;dome.castShadow=false;if(B.alarmTriggered){const warning=new THREE.PointLight(0xff1822,18,28*S,2);warning.position.set(x(c),4.8,z(r));warning.layers.set(1);interiorGroup.add(warning);}};
        const framedDoor=(c,r,turn=0,secure=false)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);for(const side of [-1,1])addRaw(new THREE.BoxGeometry(.18*S,3.75,.22*S),secure?steelDark:woodDark,side*1.05*S,1.88,0,g);addRaw(new THREE.BoxGeometry(2.28*S,.22,.24*S),secure?steel:brass,0,3.74,0,g);const leaf=addRaw(new THREE.BoxGeometry(1.82*S,3.36,.12*S),secure?steelDark:wood,secure ? .82*S : 0,1.68,.04*S,g);leaf.rotation.y=secure ? -.48 : 0;addRaw(new THREE.SphereGeometry(.07,8,6),secure?screenGreen:brass,secure ? .18*S : .7*S,1.72,.13*S,g).castShadow=false;};
        const fileCabinets=(c,r,count=4,turn=0)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);for(let i=0;i<count;i++){const px=(i-(count-1)/2)*1.08*S;addRaw(new THREE.BoxGeometry(.98*S,3.15,.74*S),steelDark,px,1.58,0,g);for(let row=0;row<4;row++){addRaw(new THREE.BoxGeometry(.84*S,.57,.08*S),steel,px,.48+row*.69,.42*S,g).castShadow=false;addRaw(new THREE.BoxGeometry(.2*S,.035,.03*S),brass,px,.48+row*.69,.48*S,g).castShadow=false;}}};
        const conferenceTable=(c,r,w=4.1,d=1.75)=>{add(new THREE.BoxGeometry(w*S,.22,d*S),wood,c,1.08,r);for(const dc of [-w*.36,w*.36])for(const dr of [-d*.28,d*.28])add(new THREE.CylinderGeometry(.08,.11,1.02,9),brass,c+dc,.52,r+dr);for(let i=-2;i<=2;i++){const folder=add(new THREE.BoxGeometry(.48*S,.035,.34*S),i%2?paper:carpet,c+i*w*.14,1.22,r+(i%2?-.2:.2));folder.rotation.y=i*.06;folder.castShadow=false;}for(const side of [-1,1])for(let i=-1;i<=1;i++)chair(c+i*w*.28,r+side*(d*.72),side<0?0:Math.PI,side<0?fabric:fabricWarm);};
        const cashSorter=(c,r,turn=0)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);addRaw(new THREE.BoxGeometry(1.62*S,1.08,1.1*S),cream,0,.54,0,g);addRaw(new THREE.BoxGeometry(1.42*S,.18,.92*S),steel,0,1.14,0,g);addRaw(new THREE.BoxGeometry(.58*S,.38,.08*S),screenGreen,-.34*S,1.39,.5*S,g).castShadow=false;for(let slot=0;slot<3;slot++)addRaw(new THREE.BoxGeometry(.3*S,.08,.42*S),black,(slot-1)*.42*S,.93,.54*S,g).castShadow=false;for(let bundle=0;bundle<5;bundle++)addRaw(new THREE.BoxGeometry(.3*S,.1,.2*S),cash,(bundle-2)*.31*S,1.32,(bundle%2-.5)*.24*S,g);};
        const glassPartition=(c0,c1,r,doorC=null)=>{const postAt=c=>add(new THREE.CylinderGeometry(.055,.075,3.45,8),brass,c,1.73,r);for(let c=c0;c<=c1+.01;c+=1.42)postAt(Math.min(c,c1));for(let c=c0+.71;c<c1;c+=1.42){if(doorC!==null&&Math.abs(c-doorC)<1.25)continue;const pane=add(new THREE.BoxGeometry(1.28*S,3.05,.045*S),glass,c,1.68,r);pane.castShadow=false;}add(new THREE.BoxGeometry((c1-c0)*S,.12,.12*S),brass,(c0+c1)/2,3.42,r).castShadow=false;};
        const wireCagePanel=(c,r,length=4,turn=0,doorGap=false)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);for(let i=0;i<=Math.round(length*2);i++){const px=(-length/2+i*.5)*S;if(doorGap&&Math.abs(px)<.62*S)continue;addRaw(new THREE.CylinderGeometry(.018*S,.018*S,3.55,6),steel,px,1.78,0,g).castShadow=false;}for(let y=.25;y<3.55;y+=.42)addRaw(new THREE.BoxGeometry(length*S,.022*S,.022*S),steel,0,y,0,g).castShadow=false;for(const side of [-1,1])addRaw(new THREE.BoxGeometry(.1*S,3.75,.12*S),steelDark,side*length*S*.5,1.88,0,g);};
        const ventilationFan=(c,r,y=4.25,turn=0)=>{const g=new THREE.Group();g.position.set(x(c),y,z(r));g.rotation.y=turn;g.layers.set(1);interiorGroup.add(g);const ring=addRaw(new THREE.TorusGeometry(.48*S,.08*S,8,22),steel,0,0,0,g);ring.rotation.x=Math.PI/2;for(let k=0;k<5;k++){const blade=addRaw(new THREE.BoxGeometry(.12*S,.7*S,.04*S),steelDark,0,0,.03*S,g);blade.rotation.z=k/5*Math.PI*2+.35;blade.castShadow=false;}addRaw(new THREE.CylinderGeometry(.12*S,.12*S,.1,10),brass,0,0,.08*S,g).rotation.x=Math.PI/2;};

        if(data.room==='vault'){
          interiorFloor=floorZone(W/2,H/2,W,H,steelDark,.025);
          for(let r=.4;r<H;r+=2)for(let c=.4;c<W;c+=2){const plate=add(new THREE.PlaneGeometry(1.82*S,1.82*S),(Math.floor(r)+Math.floor(c))%2?std(0x232d35,.5,.58):std(0x2c3740,.45,.64),c,.045,r);plate.rotation.x=-Math.PI/2;for(const dc of [-.78,.78])for(const dr of [-.78,.78])add(new THREE.CylinderGeometry(.045,.045,.035,8),steel,c+dc,.08,r+dr);}
          hWall(0,W,.12,5.2,wallDark);vWall(.12,0,H,5.2,wallDark);vWall(W-.12,0,H,1.45,wallDark);hWall(0,W/2-.56,H-.12,1.45,wallDark);hWall(W/2+.56,W,H-.12,1.45,wallDark);
          bankDoor(W/2,H-.22,-1,true);roomSign('ХРАНИЛИЩЕ',W/2,.22,5.75,'#cde6ef',1.28);
          for(let c=1.1;c<W-1;c+=1.35){add(new THREE.BoxGeometry(1.18*S,3.45,.62*S),steelDark,c,1.82,.55);for(let row=0;row<5;row++){add(new THREE.BoxGeometry(1.02*S,.48,.1*S),row%2?steel:marbleDark,c,.52+row*.62,.9).castShadow=false;add(new THREE.BoxGeometry(.34*S,.035,.025*S),black,c,.52+row*.62,.98).castShadow=false;const knob=add(new THREE.CylinderGeometry(.045,.045,.12,8),brass,c+.34,.52+row*.62,1.01);knob.rotation.x=Math.PI/2;}}
          for(const side of [-1,1]){const c=side<0?.62:W-.62;for(let r=1.7;r<H-2.4;r+=1.45){add(new THREE.BoxGeometry(.64*S,3.3,1.2*S),steelDark,c,1.74,r);for(let row=0;row<4;row++){add(new THREE.BoxGeometry(.1*S,.55,1.02*S),row%2?steel:marbleDark,c-side*.34,.58+row*.7,r).castShadow=false;const handle=add(new THREE.CylinderGeometry(.045,.045,.12,8),brass,c-side*.42,.58+row*.7,r+.28);handle.rotation.z=Math.PI/2;}}}
          const rack=(c,r)=>{const g=new THREE.Group();g.position.set(x(c),0,z(r));g.layers.set(1);interiorGroup.add(g);for(const sx of [-1,1])addRaw(new THREE.BoxGeometry(.12,3.4,.12),steel,sx*1.15*S,1.7,0,g);for(const y of [.55,1.45,2.35,3.2])addRaw(new THREE.BoxGeometry(2.5*S,.12,1.35*S),steelDark,0,y,0,g);for(let level=0;level<3;level++)for(let i=-2;i<=2;i++){const bundle=addRaw(new THREE.BoxGeometry(.36*S,.13,.62*S),cash,i*.43*S,.72+level*.9,(i%2?-.16:.18)*S,g);bundle.rotation.y=(i%2)*.08;addRaw(new THREE.BoxGeometry(.38*S,.025,.1*S),paper,bundle.position.x,bundle.position.y+.075,bundle.position.z,g).castShadow=false;}};
          rack(W*.38,H*.48);rack(W*.64,H*.48);
          for(const c of [W*.28,W*.72]){add(new THREE.BoxGeometry(2.1*S,3.25,1.75*S),steelDark,c,1.63,3.35);add(new THREE.BoxGeometry(1.82*S,2.83,.14*S),steel,c,1.63,4.29);const dial=add(new THREE.TorusGeometry(.36,.085,8,20),brass,c,1.75,4.39);dial.rotation.x=Math.PI/2;for(let k=0;k<4;k++){const a=k/4*Math.PI*2,spoke=add(new THREE.BoxGeometry(.66,.045,.045),brass,c+Math.cos(a)*.16,1.75+Math.sin(a)*.16,4.43);spoke.rotation.z=a;spoke.castShadow=false;}}
          add(new THREE.BoxGeometry(2.15*S,.22,1.25*S),steel,1.55,.48,H-1.45);for(const dc of [-.78,.78])for(const dr of [-.42,.42]){const wheel=add(new THREE.CylinderGeometry(.15,.15,.18,10),black,1.55+dc,.2,H-1.45+dr);wheel.rotation.z=Math.PI/2;}
          for(const bag of B.bags||[])moneyBag(bag.c,bag.r,(String(bag.id).length*1.73)%6.28);
          const countC=W*.5,countR=H*.72;
          add(new THREE.BoxGeometry(3.1*S,1.05,1.5*S),woodDark,countC,.53,countR);
          add(new THREE.BoxGeometry(3.25*S,.16,1.62*S),steel,countC,1.12,countR);
          for(let i=0;i<18;i++){const bundle=add(new THREE.BoxGeometry(.42*S,.14,.28*S),cash,countC-1.05+(i%6)*.42,1.29+Math.floor(i/6)*.15,countR-.32+(i%2)*.28);bundle.rotation.y=(i%3-1)*.08;add(new THREE.BoxGeometry(.44*S,.025,.08*S),paper,bundle.position.x,1.38+Math.floor(i/6)*.15,bundle.position.z).castShadow=false;}
          for(let i=0;i<12;i++){const ingot=add(new THREE.BoxGeometry(.34*S,.16,.22*S),gold,countC-.95+(i%6)*.38,1.27+Math.floor(i/6)*.17,countR+.48);ingot.rotation.y=(i%2?-.08:.08);}
          chair(countC,countR+1.35,Math.PI,black);chair(countC,countR-1.35,0,black);
          const workC=W-1.65,workR=H-1.55;add(new THREE.BoxGeometry(2.15*S,1.05,1.2*S),woodDark,workC,.53,workR);for(const dc of [-.55,0,.55]){const tool=add(new THREE.CylinderGeometry(.055,.08,.72,8),dc?steel:red,workC+dc,1.42,workR);tool.rotation.z=.38+dc*.2;}
          for(const c of [W*.3,W*.7])for(let r=3.2;r<H-2;r+=3.6)ceilingLight(c,r,0xe1edff,2.6);
          cameraProp(W-.45,.55,4.45,-Math.PI*.75);cameraProp(.45,H*.62,4.15,Math.PI*.25);alarm(W-.65,.55);
          for(const c of [W*.28,W*.72]){const pipe=add(new THREE.CylinderGeometry(.08,.08,H*.72*S,10),steel,c,4.65,H*.42);pipe.rotation.x=Math.PI/2;}
          wireCagePanel(W*.22,H*.43,Math.max(4,H*.38),Math.PI/2);wireCagePanel(W*.78,H*.43,Math.max(4,H*.38),Math.PI/2);
          wireCagePanel(W*.5,H*.24,Math.max(5,W*.34),0,true);framedDoor(W*.5,H*.24,0,true);
          cashSorter(W*.5,H*.62);fileCabinets(W*.5,H-1.15,Math.max(3,Math.floor(W/4)));
          ventilationFan(.38,H*.28,4.38,Math.PI/2);ventilationFan(W-.38,H*.7,4.38,-Math.PI/2);
          const bioC=W*.5+1.75,bioR=H-.55;add(new THREE.BoxGeometry(.55*S,1.55,.48*S),steelDark,bioC,.78,bioR);const bioScreen=add(new THREE.PlaneGeometry(.4*S,.5),screenGreen,bioC,1.02,bioR-.26);bioScreen.rotation.x=-Math.PI/2;bioScreen.castShadow=false;
          if(B.alarmTriggered)for(let beam=0;beam<4;beam++){const laser=add(new THREE.BoxGeometry(W*.42*S,.025,.025),new THREE.MeshBasicMaterial({color:0xff2333,transparent:true,opacity:.76,toneMapped:false}),W*.5,1.1+beam*.58,H*.32);laser.castShadow=false;}
          renderer.domElement.dataset.bankInterior='vault-volumetric-v4';renderer.domElement.dataset.bankRooms='vault-deposit-walls-cash-racks-safe-bay-counting-table-service-bay-secure-cages-biometric-airlock';renderer.domElement.dataset.bankVolumetricProps='deposit-drawers-number-slots-handles-safes-dials-cash-bundles-gold-ingots-racks-carts-large-bags-counting-table-tools-cameras-alarm-pipes-wire-cages-cash-sorter-biometric-console-ventilation-laser-grid';
        }else{
          const cr=Math.max(7,Math.min(H-4,+B.counterRow||Math.floor(H*.58))),archR=Math.max(4.8,cr-3.6),staffEnd=W*.38,loungeStart=W*.62;
          interiorFloor=floorZone(W/2,H/2,W,H,marble,.025);floorZone(staffEnd/2,archR/2,staffEnd-.35,archR-.35,carpet,.04);for(let r=.45;r<archR;r+=.72)floorZone((loungeStart+W)/2,r+.3,W-loungeStart-.35,.62,loungeWood,.045);floorZone(W/2,archR/2,loungeStart-staffEnd-.55,archR-.35,steelDark,.045);floorZone(W/2,(cr+H)/2,4.2,H-cr-1.1,carpet,.055);
          hWall(0,W/2-.56,.12,4.9);hWall(W/2+.56,W,.12,4.9);vWall(.12,0,H,4.7);vWall(W-.12,0,H,1.25);hWall(0,W/2-2.1,H-.12,1.2);hWall(W/2+2.1,W,H-.12,1.2);vWall(staffEnd,.15,archR,4.15);vWall(loungeStart,.15,archR,4.15);
          const gaps=[[Math.max(.8,staffEnd*.23),Math.min(staffEnd-.4,staffEnd*.23+2.4)],[W/2-1.65,W/2+1.65],[loungeStart+.45,Math.min(W-.6,loungeStart+2.85)]];let cursor=.15;for(const [g0,g1] of gaps){hWall(cursor,g0,archR,4.1);cursor=g1;}hWall(cursor,W-.15,archR,4.1);for(const [g0,g1] of gaps){for(const c of [g0,g1])add(new THREE.CylinderGeometry(.13,.18,4.25,12),brass,c,2.12,archR);add(new THREE.BoxGeometry((g1-g0)*S+.25,.24,.34*S),brass,(g0+g1)/2,4.1,archR);}
          bankDoor(W/2,.24,1,B.phase==='vault_open');roomSign('СЛУЖЕБНАЯ ЗОНА',staffEnd/2,archR-.05,4.7,'#8cc7e8',.78);roomSign('ХРАНИЛИЩЕ',W/2,.42,5.55,'#d9e9f0',1.02);roomSign('КОМНАТА ОТДЫХА',(loungeStart+W)/2,archR-.05,4.7,'#efc58c',.78);roomSign(B.name||'ГОРОДСКОЙ БАНК',W/2,cr-.65,5.2,'#d4b35c',1.22);
          let tellerNo=0;for(let c=1.8;c<W-1.3;c+=3.05){tellerNo++;add(new THREE.BoxGeometry(2.55*S,1.25,1.08*S),wood,c,.63,cr);add(new THREE.BoxGeometry(2.67*S,.16,1.18*S),marble,c,1.32,cr);add(new THREE.BoxGeometry(2.36*S,1.55,.06*S),glass,c,2.2,cr-.48);for(const dc of [-1.05,1.05])add(new THREE.CylinderGeometry(.035,.035,1.62,7),brass,c+dc,2.2,cr-.48);const speaker=add(new THREE.TorusGeometry(.16,.025,6,16),brass,c,2.25,cr-.42);speaker.rotation.x=Math.PI/2;speaker.castShadow=false;for(let hole=0;hole<5;hole++)add(new THREE.SphereGeometry(.016,5,4),black,c+(hole-2)*.06,2.25,cr-.35).castShadow=false;add(new THREE.BoxGeometry(.86*S,.06,.52*S),steel,c,1.44,cr+.58).rotation.x=-.05;add(new THREE.BoxGeometry(.68*S,.035,.08*S),black,c,1.42,cr+.87).castShadow=false;monitor(c-.62,cr-.72,1.85,0,tellerNo%2?screenBlue:screenGreen);const number=signSprite(String(tellerNo));number.position.set(x(c+.78),3.45,z(cr-.52));number.scale.set(1.05,.48,1);interiorGroup.add(number);}
          for(const r of [cr+2,H-3.8])for(let c=2.3;c<W-2;c+=2.25){add(new THREE.CylinderGeometry(.07,.1,1.1,10),brass,c,.55,r);if(c+2.25<W-1.8){const rope=add(new THREE.CylinderGeometry(.045,.045,2.25*S,8),red,c+1.125,.88,r);rope.rotation.z=Math.PI/2;rope.castShadow=false;}}
          const guardC=Math.min(3.35,W*.22),guardR=H-4.45;floorZone(guardC,guardR,5.2,3.4,std(0x26323d,.72,.15),.065);hWall(.65,Math.min(6,guardC+2.7),guardR-1.65,2.25,wallDark);vWall(Math.min(6,guardC+2.7),guardR-1.65,guardR+1.55,2.25,wallDark);add(new THREE.BoxGeometry(4.8*S,1.25,.05*S),glass,guardC,2.55,guardR-1.48).castShadow=false;add(new THREE.BoxGeometry(.05*S,1.25,2.75*S),glass,Math.min(5.82,guardC+2.48),2.55,guardR).castShadow=false;desk(guardC,guardR+.2,4.2,1.05);for(const dc of [-1.28,0,1.28])monitor(guardC+dc,guardR-.42,2.02,0,dc?screenBlue:screenGreen);chair(guardC,guardR+1.05,Math.PI,black);for(let key=0;key<10;key++)add(new THREE.SphereGeometry(.035,6,4),key%3?screenBlue:screenGreen,guardC-1+(key%5)*.5,1.22+Math.floor(key/5)*.16,guardR+.48).castShadow=false;roomSign('ОХРАНА',guardC,guardR-1.48,4.05,'#67d5ff',.72);cameraProp(.45,H-.65,4.2,-Math.PI*.25);cameraProp(W-.45,H-.65,4.2,Math.PI*.25);cameraProp(W-.45,archR+.25,4.2,Math.PI*.65);alarm(Math.min(5.7,guardC+2.4),guardR-1.48);
          const atmR=[cr+1.5,cr+3.8,H-2.15].filter((r,i,a)=>r<H-1&&a.findIndex(v=>Math.abs(v-r)<1.2)===i);for(const [i,r] of atmR.entries()){add(new THREE.BoxGeometry(.75*S,2.35,1*S),steelDark,W-.72,1.18,r);add(new THREE.BoxGeometry(.08*S,.72,.78*S),steel,W-1.13,1.62,r).castShadow=false;const display=add(new THREE.PlaneGeometry(.62*S,.52),i%2?screenBlue:screenGreen,W-1.19,1.67,r);display.rotation.y=-Math.PI/2;display.castShadow=false;add(new THREE.BoxGeometry(.08*S,.62,.58*S),black,W-1.16,.83,r).castShadow=false;for(let row=0;row<3;row++)for(let col=0;col<3;col++)add(new THREE.BoxGeometry(.025*S,.08,.1*S),cream,W-1.21,.95-row*.13,r+(col-1)*.17).castShadow=false;add(new THREE.BoxGeometry(.08*S,.07,.48*S),brass,W-1.2,.47,r).castShadow=false;}roomSign('БАНКОМАТЫ',W-.75,Math.min(H-3,cr+2.5),3.75,'#62d4ff',.62);
          desk(staffEnd*.48,2.15,Math.max(2.7,staffEnd*.7));monitor(staffEnd*.48,1.68,1.9);chair(staffEnd*.48,3.05,Math.PI);if(staffEnd>5.3){desk(staffEnd*.52,4.55,Math.max(2.7,staffEnd*.7),1.15,Math.PI);monitor(staffEnd*.52,5,1.9,Math.PI,screenGreen);chair(staffEnd*.52,3.72);}for(let i=0;i<Math.max(2,Math.floor(staffEnd/2.2));i++){const c=.85+i*1.45;add(new THREE.BoxGeometry(1.18*S,3.1,.76*S),steelDark,c,1.55,.62);for(let row=0;row<4;row++){add(new THREE.BoxGeometry(.94*S,.58,.08*S),steel,c,.47+row*.69,1.02).castShadow=false;add(new THREE.BoxGeometry(.22*S,.03,.03*S),brass,c,.47+row*.69,1.08).castShadow=false;}}const printerC=Math.max(1.3,staffEnd-1.15);add(new THREE.BoxGeometry(1.25*S,.72,.85*S),cream,printerC,.47,archR-1.05);add(new THREE.BoxGeometry(.92*S,.12,.65*S),paper,printerC,.88,archR-.95).rotation.x=-.1;
          const loungeC=(loungeStart+W)/2;sofa(loungeC,2.15,Math.max(2.8,(W-loungeStart)*.72));sofa(loungeC,archR-1.25,Math.max(2.8,(W-loungeStart)*.72),Math.PI,fabric);add(new THREE.CylinderGeometry(1.05*S,1.05*S,.18,24),wood,loungeC,.6,archR*.53);for(let i=0;i<4;i++){const magazine=add(new THREE.BoxGeometry(.6*S,.035,.42*S),[red,screenBlue,gold,green][i],loungeC+(i-1.5)*.28,.72+i*.035,archR*.53+(i%2)*.18);magazine.rotation.y=(i-1.5)*.12;magazine.castShadow=false;}const coffeeC=loungeStart+.85;add(new THREE.BoxGeometry(1.15*S,1.72,.82*S),black,coffeeC,.86,1.15);add(new THREE.BoxGeometry(.72*S,.48,.08*S),steel,coffeeC,1.12,1.62);add(new THREE.CylinderGeometry(.07,.11,.42,8),brass,coffeeC-.18,.55,1.65);add(new THREE.BoxGeometry(2.5*S,1.45,.14),black,loungeC,2.75,.38);add(new THREE.PlaneGeometry(2.3*S,1.25),screenBlue,loungeC,2.75,.46).castShadow=false;for(const c of [loungeStart+.55,W-.55])plant(c,archR-1,.82);
          if(archR>7){for(const c of [staffEnd*.28,staffEnd*.72]){desk(c,archR*.68,2.55,1.05);monitor(c,archR*.61,1.86,0,c<staffEnd*.5?screenBlue:screenGreen);chair(c,archR*.78,Math.PI,fabric);}sofa(loungeStart+1.25,archR*.55,3.2,Math.PI/2,fabricWarm);sofa(W-1.25,archR*.55,3.2,-Math.PI/2,fabric);}
          const secureHalf=(loungeStart-staffEnd)*.5,scanR=archR*.72;
          for(const c of [W/2-1.35,W/2+1.35]){add(new THREE.BoxGeometry(.22*S,3.25,.3*S),steelDark,c,1.63,scanR);add(new THREE.SphereGeometry(.08*S,9,6),screenGreen,c,2.55,scanR+.18).castShadow=false;}
          add(new THREE.BoxGeometry(2.92*S,.28,.38*S),steel,W/2,3.18,scanR).castShadow=false;
          for(const c of [W/2-secureHalf*.72,W/2+secureHalf*.72])for(const r of [archR*.28,archR*.54])add(new THREE.CylinderGeometry(.24,.34,4.15,12),steel,c,2.08,r);
          desk(W/2,archR*.42,Math.max(3.1,(loungeStart-staffEnd)*.62),1.15);monitor(W/2,archR*.35,1.9,0,screenGreen);chair(W/2,archR*.52,Math.PI,black);
          for(const side of [-1,1]){add(new THREE.BoxGeometry(.95*S,.18,.75*S),steel,W/2+side*secureHalf*.52,.44,archR*.18);for(const dc of [-.28,.28])for(const dr of [-.2,.2]){const wheel=add(new THREE.CylinderGeometry(.1,.1,.12,8),black,W/2+side*secureHalf*.52+dc,.18,archR*.18+dr);wheel.rotation.z=Math.PI/2;}}
          desk(Math.min(3.2,W*.22),cr+2.15,3.4);monitor(Math.min(3.2,W*.22),cr+1.7,1.9,0,screenGreen);chair(Math.min(3.2,W*.22),cr+3.05,Math.PI,fabricWarm);roomSign('АДМИНИСТРАТОР',Math.min(3.2,W*.22),cr+1.55,3.55,'#d4b35c',.62);sofa(W*.5,H-2.35,Math.min(3.8,W*.22),Math.PI);if(W>18)sofa(W*.72,H-2.35,Math.min(3.4,W*.18),Math.PI,fabric);for(const c of [1.2,W-1.2])plant(c,H-1.35,.95);
          const staffSplitR=Math.max(5.5,archR*.54),loungeSplitR=Math.max(5.2,archR*.58);
          glassPartition(.35,staffEnd-.22,staffSplitR,staffEnd*.52);framedDoor(staffEnd*.52,staffSplitR,0,false);
          glassPartition(loungeStart+.22,W-.35,loungeSplitR,(loungeStart+W)*.5);framedDoor((loungeStart+W)*.5,loungeSplitR,0,false);
          roomSign('АРХИВ',Math.max(1.5,staffEnd*.28),staffSplitR+.12,3.85,'#8cc7e8',.58);roomSign('КАБИНЕТ УПРАВЛЯЮЩЕГО',Math.max(3.2,staffEnd*.62),staffSplitR+.12,3.85,'#d4b35c',.58);
          roomSign('ПЕРЕГОВОРНАЯ',(loungeStart+W)*.5,loungeSplitR+.12,3.85,'#efc58c',.58);
          fileCabinets(Math.max(1.8,staffEnd*.28),staffSplitR+1.15,Math.max(3,Math.floor(staffEnd/2.3)));
          if(W>=36)conferenceTable((loungeStart+W)*.5,Math.min(archR-2.1,loungeSplitR+2.55),Math.max(3.6,(W-loungeStart)*.58),1.65);
          cashSorter(W*.5,Math.min(archR-1.5,scanR+2.15));framedDoor(W*.5,Math.min(archR-.65,scanR+1.1),0,true);
          const coolerC=loungeStart+.8,coolerR=Math.min(archR-1.2,loungeSplitR+1.1);add(new THREE.CylinderGeometry(.32*S,.38*S,1.45,14),cream,coolerC,.74,coolerR);const waterJug=add(new THREE.SphereGeometry(.38*S,14,10),new THREE.MeshPhysicalMaterial({color:0x7bd8ed,transparent:true,opacity:.48,roughness:.08}),coolerC,1.75,coolerR);waterJug.scale.y=1.25;add(new THREE.BoxGeometry(.12*S,.1,.12*S),screenBlue,coolerC-.16,.96,coolerR+.36).castShadow=false;add(new THREE.BoxGeometry(.12*S,.1,.12*S),red,coolerC+.16,.96,coolerR+.36).castShadow=false;
          const extinguisherC=Math.min(W-1.25,loungeStart+.42),extinguisherR=archR-.45;add(new THREE.CylinderGeometry(.18*S,.22*S,1.15,12),red,extinguisherC,.62,extinguisherR);add(new THREE.TorusGeometry(.18*S,.035*S,6,12),black,extinguisherC,.95,extinguisherR).rotation.x=Math.PI/2;
          for(const c of [W*.23,W*.5,W*.77])for(const r of [archR*.55,(cr+H)/2])ceilingLight(c,r);const logoR=Math.min(H-3,cr+3),logo=add(new THREE.RingGeometry(1.5*S,1.92*S,32),gold,W/2,.09,logoR);logo.rotation.x=-Math.PI/2;for(let k=0;k<8;k++){const a=k/8*Math.PI*2,ray=add(new THREE.BoxGeometry(.12*S,.02,.62*S),brass,W/2+Math.sin(a)*1.35,.105,logoR+Math.cos(a)*1.35);ray.rotation.y=a;ray.castShadow=false;}const fill=new THREE.RectAreaLight(0xffdfbb,3.3,Math.max(8,W*.78*S),Math.max(7,(H-archR)*.76*S));fill.position.set(x(W/2),8.2,z((archR+H)/2));fill.lookAt(x(W/2),0,z((archR+H)/2));fill.layers.set(1);interiorGroup.add(fill);
          renderer.domElement.dataset.bankInterior='lobby-volumetric-v4';renderer.domElement.dataset.bankRooms='main-hall-teller-line-staff-office-manager-office-archive-security-booth-break-room-conference-room-screening-corridor-cash-processing-vault-approach-atm-zone';renderer.domElement.dataset.bankVolumetricProps='teller-glass-speakers-trays-monitors-queue-posts-security-cctv-staff-desk-pods-files-printer-lounge-sofas-coffee-tv-atms-screening-gate-document-desk-carts-vault-door-glass-partitions-office-doors-conference-table-cash-sorter-water-cooler-fire-extinguisher';
        }
        renderer.domElement.dataset.bankState=B.phase||'lobby';renderer.domElement.dataset.bankVisualVersion='4';interiorGroup.visible=true;return true;
      };

      const decorateBusinessInterior=data=>{
        const layout=data.businessLayout,id=String(data.bizId||'');
        if(!layout||!id||id==='major_casino')return false;
        const S=WORLD_SCALE,W=+data.width||18,H=+data.height||13,x=c=>(c-originC)*S,z=r=>(r-originR)*S;
        let propCount=0;
        const materialCache=new Map(),std=(color,roughness=.72,metalness=.05,emissive=null,intensity=0)=>{
          const key=`${color}:${roughness}:${metalness}:${emissive||''}:${intensity}`;
          if(!materialCache.has(key))materialCache.set(key,new THREE.MeshStandardMaterial({color,roughness,metalness,emissive:emissive||0x000000,emissiveIntensity:intensity}));
          return materialCache.get(key);
        };
        const basic=(color,transparent=false,opacity=1)=>new THREE.MeshBasicMaterial({color,transparent,opacity,toneMapped:true,side:THREE.DoubleSide});
        const glass=new THREE.MeshPhysicalMaterial({color:0xa8dce8,transparent:true,opacity:.34,roughness:.08,metalness:.12,transmission:.28,side:THREE.DoubleSide});
        const steel=std('#65727b',.28,.82),dark=std('#171b20',.52,.38),black=std('#0d1116',.4,.48),wood=std('#5b3423',.72,.02),brass=std('#c49a3e',.28,.72),cream=std('#e0d7c5',.88,.02),felt=std('#176342',.88,.01),rubber=std('#181b20',.92,.02);
        const metal=steel,pink=basic('#ff4fad'),cyan=basic('#65e8ff'),warm=basic('#ffc568');
        const add=(geometry,material,c,y,r,parent=interiorGroup)=>{
          const mesh=new THREE.Mesh(geometry,material);mesh.position.set(x(c),y,z(r));mesh.castShadow=mesh.receiveShadow=true;mesh.layers.set(1);parent.add(mesh);propCount++;return mesh;
        };
        const addBox=(q,material=std(q.color),heightScale=1.55)=>{
          const h=Math.max(.08,(+q.h||1)*heightScale);
          return add(new THREE.BoxGeometry(Math.max(.12,(+q.w||1)*S),h,Math.max(.12,(+q.d||1)*S)),material,q.c,h/2,q.r);
        };
        const floorZone=(q,material=std(q.color,.52,.08))=>{
          const floor=add(new THREE.PlaneGeometry(q.w*S,q.d*S),material,q.c,.075,q.r);floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;floor.castShadow=false;return floor;
        };
        const chair=(r,c,color='#303944',rotation=0)=>{
          const upholstery=std(color,.82,.04),base=add(new THREE.CylinderGeometry(.38*S,.48*S,.12,18),brass,c,.08,r);
          const stem=add(new THREE.CylinderGeometry(.065*S,.09*S,.48,12),metal,c,.32,r);
          const seat=add(new THREE.SphereGeometry(.48*S,18,10),upholstery,c,.62,r);seat.scale.set(1.18,.34,1.02);seat.rotation.y=rotation;
          const backC=c-Math.sin(rotation)*.36,backR=r-Math.cos(rotation)*.36;
          const back=add(new THREE.CapsuleGeometry(.28*S,.48,8,14),upholstery,backC,1.12,backR);back.scale.set(1.18,1,.34);back.rotation.y=rotation;
          const rim=add(new THREE.TorusGeometry(.47*S,.035*S,7,18),brass,c,.66,r);rim.rotation.x=Math.PI/2;rim.rotation.z=rotation;rim.castShadow=false;
        };
        const table=q=>{
          const top=add(new THREE.CylinderGeometry(q.w*S*.34,q.w*S*.34,.3,20),std(q.color,.62),q.c,1.02,q.r);
          for(const dc of [-q.w*.22,q.w*.22])for(const dr of [-q.d*.22,q.d*.22])add(new THREE.CylinderGeometry(.09,.13,.88,8),dark,q.c+dc,.47,q.r+dr);
          chair(q.r-q.d*.75,q.c,std(q.color).color.getStyle(),0);chair(q.r+q.d*.75,q.c,std(q.color).color.getStyle(),Math.PI);
        };
        const counter=q=>{
          const body=addBox(q,std(q.color,.7,.06));
          add(new THREE.BoxGeometry((q.w+.18)*S,.18,(q.d+.16)*S),brass,q.c,(q.h||1)*1.55+.09,q.r);
          const register=add(new THREE.BoxGeometry(.72*S,.48,.52*S),dark,q.c+q.w*.28,(q.h||1)*1.55+.35,q.r);register.rotation.x=-.08;
        };
        const sofa=q=>{
          const seatH=Math.max(.5,q.h*1.05);add(new THREE.BoxGeometry(q.w*S,seatH,q.d*S),std(q.color,.92),q.c,seatH/2,q.r);
          add(new THREE.BoxGeometry(q.w*S,1.25,.26*S),std(q.color,.92),q.c,seatH+.55,q.r-q.d*.38);
          for(const dc of [-q.w*.44,q.w*.44])add(new THREE.BoxGeometry(.28*S,.85,q.d*S),std(q.color,.92),q.c+dc,seatH*.68,q.r);
        };
        const vehicle=q=>{
          const body=add(new THREE.BoxGeometry(q.w*S*.92,.72,q.d*S*.88),std(q.color,.38,.34),q.c,.72,q.r);
          const cabin=add(new THREE.BoxGeometry(q.w*S*.5,.7,q.d*S*.72),glass,q.c,.98,q.r-.08);cabin.castShadow=false;
          for(const dc of [-q.w*.34,q.w*.34])for(const dr of [-q.d*.44,q.d*.44]){const wheel=add(new THREE.CylinderGeometry(.32*S,.32*S,.2*S,14),rubber,q.c+dc,.38,q.r+dr);wheel.rotation.z=Math.PI/2;}
          add(new THREE.BoxGeometry(q.w*S*.12,.16,q.d*S*.9),brass,q.c+q.w*.38,.82,q.r).castShadow=false;
        };
        const rack=q=>{
          for(const dc of [-q.w*.45,q.w*.45])add(new THREE.BoxGeometry(.12*S,q.h*1.55,.16*S),steel,q.c+dc,q.h*.775,q.r);
          for(let row=0;row<3;row++){const y=.48+row*q.h*.55;add(new THREE.BoxGeometry(q.w*S,.13,.82*q.d*S),steel,q.c,y,q.r).castShadow=false;for(let i=-2;i<=2;i++)add(new THREE.BoxGeometry(.5*S,.42,.55*S),std(['#9b6336','#5f7144','#784a45'][(i+row+5)%3],.9),q.c+i*q.w*.17,y+.25,q.r);}
        };
        const crateStack=q=>{
          for(let i=0;i<6;i++){const col=i%3,row=Math.floor(i/3),crate=add(new THREE.BoxGeometry(q.w*S*.28,q.h*.7,q.d*S*.42),std(i%2?q.color:'#7c542f',.9),q.c+(col-1)*q.w*.3,.36+row*q.h*.7,q.r+(i%2-.5)*q.d*.34);crate.rotation.y=(i%3-1)*.05;}
        };
        const barrelCluster=q=>{
          for(let i=0;i<3;i++){const drum=add(new THREE.CylinderGeometry(.34*S,.34*S,q.h*1.05,16),std(i%2?q.color:'#3b596a',.48,.5),q.c+(i-1)*q.w*.28,q.h*.53,q.r);for(const y of [.22,q.h*.52,q.h*.83])add(new THREE.TorusGeometry(.35*S,.035*S,6,16),steel,drum.position.x/S+originC,y,drum.position.z/S+originR);}
        };
        const gamingTable=q=>{
          const pedestal=add(new THREE.CylinderGeometry(.46*S,.72*S,.82,18),dark,q.c,.43,q.r);
          const top=add(new THREE.CylinderGeometry(q.w*S*.46,q.w*S*.46,.34,32),felt,q.c,1.02,q.r);
          const rail=add(new THREE.TorusGeometry(q.w*S*.46,.09*S,8,32),brass,q.c,1.2,q.r);rail.rotation.x=Math.PI/2;
          const wheel=add(new THREE.CylinderGeometry(.58*S,.58*S,.2,28),black,q.c,1.31,q.r);
          const wheelRim=add(new THREE.TorusGeometry(.56*S,.055*S,7,28),brass,q.c,1.43,q.r);wheelRim.rotation.x=Math.PI/2;
          add(new THREE.CylinderGeometry(.055*S,.1*S,.38,12),brass,q.c,1.56,q.r);
          for(let k=0;k<16;k++){
            const a=k/16*Math.PI*2,pocket=add(new THREE.BoxGeometry(.18*S,.055,.34*S),k%2?std('#b72235',.58):black,q.c+Math.cos(a)*.42*S,1.43,q.r+Math.sin(a)*.42);
            pocket.rotation.y=-a;pocket.castShadow=false;
          }
          for(let k=0;k<10;k++){const a=k/10*Math.PI*2,chip=add(new THREE.CylinderGeometry(.09,.09,.06,12),std(['#e4c34f','#bc3347','#e8e5d7','#386fd2'][k%4],.4,.18),q.c+Math.cos(a)*q.w*.3,1.25,q.r+Math.sin(a)*q.d*.32);chip.castShadow=false;}
          for(let k=0;k<6;k++){const a=Math.PI*(.08+.84*k/5);chair(q.r+Math.cos(a)*q.d*.9,q.c+Math.sin(a)*q.w*.64,'#562139',-a);}
        };
        const diningTable=q=>{
          const diningWood=std(q.color||'#713922',.72,.12),chairColor='#6f2836';
          add(new THREE.BoxGeometry(q.w*S,.38,q.d*S),diningWood,q.c,1.08,q.r);
          for(const dc of [-q.w*.42,q.w*.42])for(const dr of [-q.d*.34,q.d*.34]){
            add(new THREE.CylinderGeometry(.1*S,.14*S,.9,9),diningWood,q.c+dc,.47,q.r+dr);
          }
          const sideSeats=Math.max(3,Math.min(5,Math.floor(q.w/1.5)));
          for(let i=0;i<sideSeats;i++){
            const c=q.c-q.w*.38+i*(q.w*.76/Math.max(1,sideSeats-1));
            chair(q.r-q.d*.72,c,chairColor,0);
            chair(q.r+q.d*.72,c,chairColor,Math.PI);
            add(new THREE.CylinderGeometry(.18*S,.18*S,.045,12),cream,c,1.3,q.r+(i%2?-.35:.35)).castShadow=false;
          }
          chair(q.r,q.c-q.w*.64,chairColor,-Math.PI/2);
          chair(q.r,q.c+q.w*.64,chairColor,Math.PI/2);
          for(const dc of [-.7,.7]){
            const candle=add(new THREE.CylinderGeometry(.045*S,.055*S,.48,8),cream,q.c+dc,1.52,q.r);
            candle.castShadow=false;
            const flame=add(new THREE.SphereGeometry(.075*S,8,6),basic('#ffb43c'),q.c+dc,1.82,q.r);
            flame.scale.set(.72,1.5,.72);flame.castShadow=false;
          }
        };
        const slotBank=q=>{
          const count=Math.max(2,Math.floor(q.w/1.15));
          for(let i=0;i<count;i++){
            const c=q.c-q.w*.42+i*(q.w*.84/Math.max(1,count-1)),glow=i%3===0?'#ffbf39':i%3===1?'#36d8ff':'#ff4eab',cabinet=std(i%2?q.color:'#382449',.34,.42);
            const base=add(new THREE.CylinderGeometry(.42*S,.52*S,.28,16),dark,c,.14,q.r);
            const body=add(new THREE.CapsuleGeometry(.43*S,Math.max(.6,q.h*1.05),8,14),cabinet,c,1.18,q.r);body.scale.z=.72;
            const bezel=add(new THREE.TorusGeometry(.31*S,.055*S,7,18),brass,c,1.62,q.r+.34);bezel.scale.y=1.28;bezel.rotation.x=Math.PI/2;bezel.castShadow=false;
            const screen=add(new THREE.PlaneGeometry(.56*S,.66),basic('#f3ead4'),c,1.62,q.r+.405);screen.castShadow=false;
            for(let reel=0;reel<3;reel++){
              const reelMat=basic(reel===i%3?glow:reel===1?'#fff0bd':'#e8d8cc');
              const reelFace=add(new THREE.CircleGeometry(.095*S,16),reelMat,c+(reel-1)*.18*S,1.63,q.r+.416);reelFace.castShadow=false;
              const symbol=add(new THREE.TorusGeometry(.045*S,.016*S,5,10),reel===1?pink:cyan,c+(reel-1)*.18*S,1.63,q.r+.425);symbol.castShadow=false;
            }
            const controls=add(new THREE.CylinderGeometry(.3*S,.36*S,.18,16),brass,c,.74,q.r+.39);controls.rotation.x=Math.PI/2;
            for(let b=-1;b<=1;b++)add(new THREE.SphereGeometry(.055*S,9,6),b?pink:warm,c+b*.16*S,.79,q.r+.5).castShadow=false;
            const lever=add(new THREE.CylinderGeometry(.035*S,.045*S,.72,8),metal,c+.5,.98,q.r+.02);lever.rotation.z=-.38;
            add(new THREE.SphereGeometry(.1*S,10,7),basic(glow),c+.63,1.3,q.r+.02).castShadow=false;
            const crown=add(new THREE.TorusGeometry(.3*S,.065*S,8,18,Math.PI),basic(glow),c,2.45,q.r+.05);crown.rotation.z=Math.PI;crown.castShadow=false;
            chair(q.r+1.05,c,'#4a1837',Math.PI);
          }
        };
        const casinoRoomWall=q=>{
          const wall=addBox(q,std(q.color,.78,.06));
          add(new THREE.BoxGeometry((q.w+.08)*S,.18,(q.d+.08)*S),brass,q.c,q.h*1.55-.08,q.r).castShadow=false;
          add(new THREE.BoxGeometry((q.w+.05)*S,.22,(q.d+.05)*S),wood,q.c,.12,q.r).castShadow=false;
          const vertical=q.d>q.w;
          for(const offset of [-.46,.46]){
            const c=q.c+(vertical?0:offset*q.w),r=q.r+(vertical?offset*q.d:0);
            add(new THREE.CylinderGeometry(.11*S,.15*S,q.h*1.45,10),brass,c,q.h*.72,r);
          }
          return wall;
        };
        const casinoStairs=q=>{
          const steps=9,run=q.d/steps,topY=q.h*1.55;
          for(let i=0;i<steps;i++){
            const h=topY*(i+1)/steps,r=q.r+q.d*.5-(i+.5)*run;
            add(new THREE.BoxGeometry(q.w*S,h,run*S*.98),i%2?std(q.color,.72):wood,q.c,h/2,r);
            add(new THREE.BoxGeometry(q.w*S+.08,.07,.07*S),brass,q.c,h+.035,r-run*.49).castShadow=false;
          }
          for(const side of [-1,1]){
            const c=q.c+side*q.w*.52;
            for(let i=0;i<=steps;i+=2){const y=.55+topY*i/steps,r=q.r+q.d*.5-i*run;add(new THREE.CylinderGeometry(.04*S,.055*S,1.15,8),brass,c,y+.54,r);}
            const rail=add(new THREE.CylinderGeometry(.055*S,.055*S,Math.hypot(q.d*S,topY),9),brass,c,topY*.5+1.05,q.r);rail.rotation.x=Math.atan2(q.d*S,topY);
          }
          const landing=add(new THREE.BoxGeometry((q.w+.35)*S,.28,1.05*S),std(q.color,.68),q.c,topY,q.r-q.d*.55);landing.castShadow=true;
        };
        const fireplace=q=>{
          addBox(q,std(q.color,.88));const opening=add(new THREE.PlaneGeometry(q.w*S*.54,q.h*1.05),black,q.c,q.h*.72,q.r+q.d*.505);opening.castShadow=false;
          const glow=add(new THREE.PlaneGeometry(q.w*S*.38,q.h*.62),basic('#ff8c2f'),q.c,q.h*.55,q.r+q.d*.52);glow.castShadow=false;
          const light=new THREE.PointLight(0xff7a24,7,11,2);light.position.set(x(q.c),1.1,z(q.r+1));light.layers.set(1);interiorGroup.add(light);
        };
        const washArch=q=>{
          for(const c of [q.c-q.w*.46,q.c+q.w*.46])add(new THREE.BoxGeometry(.22*S,q.h*1.55,.28*S),std(q.color,.35,.54),c,q.h*.775,q.r);
          add(new THREE.BoxGeometry(q.w*S,.25,q.d*S*.36),std(q.color,.35,.54),q.c,q.h*1.55,q.r);
          for(let i=-2;i<=2;i++){const spray=add(new THREE.CylinderGeometry(.035,.07,q.h*1.1,7),basic('#8eefff',true,.52),q.c+i*q.w*.16,q.h*.82,q.r);spray.castShadow=false;}
        };
        const barberStation=q=>{
          const stem=add(new THREE.CylinderGeometry(.12*S,.18*S,.78,12),brass,q.c,.4,q.r),seat=add(new THREE.CylinderGeometry(.52*S,.58*S,.44,18),std(q.color,.8),q.c,.87,q.r);
          add(new THREE.BoxGeometry(1.1*S,1.25,.18*S),std(q.color,.8),q.c,1.55,q.r-.46);
          const mirror=add(new THREE.PlaneGeometry(1.3*S,2.2),glass,q.c,2.65,q.r-.78);mirror.castShadow=false;
        };
        const pizzaOven=q=>{
          addBox(q,std(q.color,.9));const mouth=add(new THREE.CircleGeometry(q.w*S*.22,24,0,Math.PI),black,q.c,q.h*.72,q.r+q.d*.51);mouth.rotation.z=Math.PI;mouth.castShadow=false;
          const fire=add(new THREE.CircleGeometry(q.w*S*.16,18),basic('#ff942d'),q.c,q.h*.45,q.r+q.d*.52);fire.castShadow=false;
          const light=new THREE.PointLight(0xff7b27,8,12,2);light.position.set(x(q.c),1.1,z(q.r+1));light.layers.set(1);interiorGroup.add(light);
        };
        const garageLift=q=>{
          const railMat=std(q.color,.34,.62);for(const c of [q.c-q.w*.43,q.c+q.w*.43]){add(new THREE.BoxGeometry(.18*S,q.h*1.55,.2*S),railMat,c,q.h*.775,q.r);add(new THREE.BoxGeometry(.72*S,.18,.42*S),railMat,c,1.25,q.r);}
          add(new THREE.BoxGeometry(q.w*S,.16,.24*S),railMat,q.c,q.h*1.55,q.r).castShadow=false;
        };
        const portYellow=std('#e3aa2f',.46,.42),portOrange=std('#cf692d',.52,.3),portBlue=std('#365d70',.45,.48),portGrey=std('#59666e',.48,.54),portPaper=std('#e6dfc9',.88,.01),portRed=std('#c63c35',.46,.28);
        const portLabel=(text,color,c,r,y=2.75,scale=1)=>{
          const sign=labelSprite(String(text||'CARGO'),color||'#d9eff4');sign.position.set(x(c),y,z(r));sign.scale.multiplyScalar(scale);sign.layers.set(1);interiorGroup.add(sign);propCount++;return sign;
        };
        const portBeacon=(c,r,y=2.4,color='#ff9f32')=>{
          const base=add(new THREE.CylinderGeometry(.11*S,.14*S,.12,12),dark,c,y-.1,r),lamp=add(new THREE.SphereGeometry(.1*S,10,7),basic(color),c,y,r);lamp.castShadow=false;return lamp;
        };
        const portFloor=q=>{
          const floor=floorZone(q,std(q.color,.84,.1)),kind=String(q.kind||''),hazard=kind.includes('loading')||kind.includes('work')||kind.includes('customs');
          if(hazard)for(let lane=-3;lane<=3;lane++){const stripe=add(new THREE.PlaneGeometry(Math.max(.18,q.w*S*.08),Math.max(.7,q.d*S*.16)),basic(lane%2?'#e8aa28':'#20252a',true,.76),q.c+lane*q.w*.11,.088,q.r);stripe.rotation.x=-Math.PI/2;stripe.rotation.z=.55;stripe.castShadow=false;}
          if(kind.includes('sort')||kind.includes('container'))for(let lane=-2;lane<=2;lane++){const guide=add(new THREE.PlaneGeometry(.045*S,q.d*S*.88),basic(lane%2?'#e7b03b':'#d5e0df',true,.58),q.c+lane*q.w*.17,.09,q.r);guide.rotation.x=-Math.PI/2;guide.castShadow=false;}
          if(kind.includes('vehicle_lane')){const centre=add(new THREE.PlaneGeometry(.1*S,q.d*S*.9),basic('#f1c34d',true,.82),q.c,.094,q.r);centre.rotation.x=-Math.PI/2;centre.castShadow=false;}
          return floor;
        };
        const portDispatchBooth=q=>{
          const frame=std(q.color,.42,.48),h=Math.max(2.65,q.h*1.55),halfW=q.w*.47,halfD=q.d*.43;
          add(new THREE.BoxGeometry(q.w*S,.24,q.d*S),frame,q.c,.12,q.r);
          for(const dc of [-halfW,halfW])for(const dr of [-halfD,halfD])add(new THREE.BoxGeometry(.14*S,h,.14*S),steel,q.c+dc,h/2,q.r+dr);
          add(new THREE.BoxGeometry(q.w*S,.18,q.d*S),portGrey,q.c,h,q.r);
          for(const dc of [-q.w*.25,q.w*.02,q.w*.3]){const pane=add(new THREE.BoxGeometry(q.w*S*.22,h*.62,.055*S),glass,q.c+dc,h*.58,q.r+halfD);pane.castShadow=false;}
          for(const dr of [-q.d*.21,q.d*.02,q.d*.24]){const pane=add(new THREE.BoxGeometry(.055*S,h*.62,q.d*S*.2),glass,q.c-halfW,h*.58,q.r+dr);pane.castShadow=false;}
          add(new THREE.BoxGeometry(.78*S,h*.72,.08*S),portBlue,q.c+q.w*.35,h*.36,q.r+halfD+.02);
          add(new THREE.BoxGeometry(.08*S,.42,.04*S),brass,q.c+q.w*.15,1.15,q.r+halfD+.08);
          const map=add(new THREE.PlaneGeometry(2.4*S,1.2),basic('#9fc8cf'),q.c,1.85,q.r-halfD-.08);map.castShadow=false;
          for(let route=0;route<4;route++){const line=add(new THREE.BoxGeometry(1.65*S,.025,.018*S),route%2?portRed:portYellow,q.c+(route-1.5)*.16,1.55+route*.2,q.r-halfD-.12);line.rotation.z=(route-1.5)*.14;line.castShadow=false;}
          const shelf=add(new THREE.BoxGeometry(2.6*S,.14,.52*S),wood,q.c,1.02,q.r-halfD+.32);for(let log=0;log<5;log++)add(new THREE.BoxGeometry(.34*S,.12,.42*S),std(log%2?'#c48a42':'#4f7383',.82),q.c+(log-2)*.42,1.18,q.r-halfD+.32);
          const life=add(new THREE.TorusGeometry(.38*S,.12*S,10,22),std('#ef7039',.52),q.c-q.w*.35,1.62,q.r-halfD-.12);life.rotation.x=Math.PI/2;
          portLabel('DISPATCH', '#9deaff',q.c,q.r+halfD+.08,h+.55,.68);
        };
        const portConsole=q=>{
          const shell=std(q.color,.58,.3),topY=Math.max(.88,q.h*1.55);
          add(new THREE.BoxGeometry(q.w*S*.96,topY*.78,q.d*S),shell,q.c,topY*.39,q.r);
          const lip=add(new THREE.BoxGeometry(q.w*S, .14,q.d*S*1.05),steel,q.c,topY*.8,q.r);lip.rotation.x=-.06;
          const monitors=Math.max(2,Math.min(4,+q.monitors||+q.cctv||2));
          for(let i=0;i<monitors;i++){const c=q.c+(i-(monitors-1)/2)*q.w*.22,screen=add(new THREE.BoxGeometry(q.w*S*.18,.68,.12*S),dark,c,topY+ .48,q.r-q.d*.28);screen.rotation.x=-.08;const glow=add(new THREE.PlaneGeometry(q.w*S*.14,.45),basic(i%2?'#68d9ef':'#88edbd'),c,topY+.5,q.r-q.d*.35);glow.castShadow=false;add(new THREE.CylinderGeometry(.035,.05,.28,7),steel,c,topY+.08,q.r-q.d*.28);}
          for(let button=0;button<6;button++)add(new THREE.SphereGeometry(.045*S,8,5),button%3===0?portRed:button%3===1?portYellow:std('#4dc881',.36,.2),q.c+(button-2.5)*q.w*.09,topY+.12,q.r+q.d*.48).castShadow=false;
          const radio=add(new THREE.BoxGeometry(.48*S,.42,.38*S),dark,q.c-q.w*.39,topY+.26,q.r);for(let knob=-1;knob<=1;knob++)add(new THREE.SphereGeometry(.04*S,7,5),brass,q.c-q.w*.39+knob*.12,topY+.28,q.r+q.d*.21).castShadow=false;add(new THREE.CylinderGeometry(.025,.03,.75,6),steel,q.c-q.w*.48,topY+.82,q.r).rotation.z=-.18;
          add(new THREE.BoxGeometry(.56*S,.2,.4*S),portRed,q.c+q.w*.38,topY+.2,q.r);add(new THREE.TorusGeometry(.18*S,.035*S,7,14,Math.PI*1.5),dark,q.c+q.w*.38,topY+.42,q.r).rotation.x=Math.PI/2;
          for(let book=0;book<3;book++){const log=add(new THREE.BoxGeometry(.72*S,.04,.46*S),book%2?portPaper:std('#c5a66a',.9),q.c+(book-1)*.42,topY+.18+book*.045,q.r+q.d*.16);log.rotation.y=(book-1)*.08;}
        };
        const portContainer=q=>{
          const levels=Math.max(1,Math.min(2,+q.levels||Math.round((+q.h||2.35)/2.35))),totalH=Math.max(3.25,q.h*1.55),levelH=totalH/levels,containerMat=std(q.color,.63,.32),doorColor=new THREE.Color(q.color).offsetHSL(0,0,-.08).getHex(),serial=String(q.serial||q.code||'MFIU 204871');
          for(let level=0;level<levels;level++){
            const y=levelH*(level+.5),body=add(new THREE.BoxGeometry(q.w*S,levelH*.92,q.d*S),containerMat,q.c,y,q.r);
            for(let rib=-4;rib<=4;rib++){const c=q.c+rib*q.w*.105;add(new THREE.BoxGeometry(.055*S,levelH*.82,.055*S),portGrey,c,y,q.r+q.d*.505).castShadow=false;add(new THREE.BoxGeometry(.055*S,levelH*.82,.055*S),portGrey,c,y,q.r-q.d*.505).castShadow=false;}
            const doorR=q.r+q.d*.515;
            for(const dc of [-q.w*.24,q.w*.24]){add(new THREE.BoxGeometry(q.w*S*.46,levelH*.78,.06*S),std(doorColor,.62,.34),q.c+dc,y,doorR);for(const bar of [-.13,.13])add(new THREE.CylinderGeometry(.025*S,.025*S,levelH*.7,7),steel,q.c+dc+bar*q.w,y,doorR+.08);}
            for(const dc of [-q.w*.45,q.w*.45])for(const dy of [-levelH*.34,levelH*.34])add(new THREE.BoxGeometry(.14*S,.13,.1*S),brass,q.c+dc,y+dy,doorR+.1).castShadow=false;
            if(level===0){portLabel(serial,'#eff7eb',q.c-q.w*.12,doorR+.08,y+.12,.38);portLabel(String(q.weight||'30T'),'#ffd276',q.c+q.w*.34,doorR+.08,y-.48,.27);}
          }
        };
        const portCraneLeg=q=>{
          const h=Math.max(5.6,q.h*1.55),mat=std(q.color,.46,.46);add(new THREE.BoxGeometry(q.w*S*.72,h,q.d*S*.68),mat,q.c,h/2,q.r);
          for(let stripe=0;stripe<5;stripe++){const band=add(new THREE.BoxGeometry(q.w*S*.78,.18,q.d*S*.72),stripe%2?portYellow:dark,q.c,.35+stripe*.38,q.r);band.rotation.y=stripe%2?.15:-.15;}
          for(const dr of [-q.d*.34,q.d*.34]){const wheel=add(new THREE.CylinderGeometry(.22*S,.22*S,.2*S,12),rubber,q.c,.25,q.r+dr);wheel.rotation.z=Math.PI/2;}
        };
        const portCrane=(q,major=false)=>{
          const mat=std(q.color,.42,.55),h=Math.max(6.1,q.h*1.55),span=q.w*S,depth=q.d*S;
          for(const dc of [-q.w*.44,q.w*.44])for(const dr of [-q.d*.36,q.d*.36]){const leg=add(new THREE.BoxGeometry(.24*S,h,.3*S),mat,q.c+dc,h/2,q.r+dr);leg.rotation.z=dc<0?-.045:.045;add(new THREE.BoxGeometry(.65*S,.18,.75*S),dark,q.c+dc,.14,q.r+dr);}
          add(new THREE.BoxGeometry(span,.32,.34*S),mat,q.c,h,q.r-q.d*.34);add(new THREE.BoxGeometry(span,.32,.34*S),mat,q.c,h,q.r+q.d*.34);
          for(let brace=-3;brace<=3;brace++){const b=add(new THREE.BoxGeometry(.11*S,.13,depth*.72),brace%2?portGrey:portYellow,q.c+brace*q.w*.12,h+.16,q.r);b.rotation.y=brace%2?.08:-.08;}
          const trolleyC=q.c+q.w*(major?.16:.28),trolley=add(new THREE.BoxGeometry(1.25*S,.55,1.05*S),dark,trolleyC,h-.42,q.r);
          for(const dr of [-.34,.34])for(const dc of [-.42,.42]){const wheel=add(new THREE.CylinderGeometry(.12*S,.12*S,.16,10),rubber,trolleyC+dc,h-.18,q.r+dr);wheel.rotation.z=Math.PI/2;}
          const cabC=q.c-q.w*.31,cab=add(new THREE.BoxGeometry(1.55*S,1.4,1.25*S),portBlue,cabC,h-1.25,q.r+q.d*.16);for(const side of [-.42,.42]){const pane=add(new THREE.PlaneGeometry(.52*S,.58),basic('#80d6e7',true,.68),cabC+side,h-1.14,q.r+q.d*.5);pane.castShadow=false;}
          const cableY=h-2.05;add(new THREE.CylinderGeometry(.028,.028,3.4,7),steel,trolleyC,cableY,q.r);add(new THREE.BoxGeometry(2.25*S,.18,.5*S),portYellow,trolleyC,h-3.72,q.r);
          for(const dc of [-.88,.88])for(const dr of [-.18,.18])add(new THREE.CylinderGeometry(.025,.025,.62,7),steel,trolleyC+dc,h-4.06,q.r+dr);
          const hook=add(new THREE.TorusGeometry(.22*S,.055*S,8,18,Math.PI*1.45),steel,trolleyC,h-4.45,q.r);hook.rotation.z=.25;portBeacon(q.c,q.r,h+.55);
        };
        const portWorkerStation=q=>{
          add(new THREE.BoxGeometry(q.w*S,.22,q.d*S),wood,q.c,1.02,q.r);for(const c of [q.c-q.w*.42,q.c+q.w*.42])add(new THREE.BoxGeometry(.2*S,1,.18*S),steel,c,.5,q.r);
          const boardR=q.r-q.d*.48;add(new THREE.BoxGeometry(q.w*S*.96,1.5,.12*S),portGrey,q.c,2.02,boardR);
          for(let tool=-3;tool<=3;tool++){const handle=add(new THREE.CylinderGeometry(.025,.035,.58,7),tool%2?portRed:portYellow,q.c+tool*q.w*.11,2.1,boardR-.08);handle.rotation.z=(tool%3-1)*.34;}
          for(let hat=0;hat<3;hat++){const helmet=add(new THREE.SphereGeometry(.2*S,12,7,0,Math.PI*2,0,Math.PI/2),hat%2?portYellow:portOrange,q.c+(hat-1)*q.w*.26,1.36,q.r);helmet.castShadow=false;}
          for(const dc of [-q.w*.34,q.w*.34]){const vest=add(new THREE.CapsuleGeometry(.2*S,.55,6,10),std('#ef8b2f',.78),q.c+dc,2.15,boardR-.14);vest.scale.set(.85,1,.28);add(new THREE.BoxGeometry(.38*S,.06,.025*S),basic('#e9ee9a'),q.c+dc,2.16,boardR-.25).castShadow=false;}
          const clip=add(new THREE.BoxGeometry(.62*S,.04,.44*S),portPaper,q.c+q.w*.25,1.18,q.r);clip.rotation.y=.08;const chain=add(new THREE.TorusGeometry(.33*S,.045*S,7,18),steel,q.c-q.w*.32,1.33,q.r);chain.rotation.x=Math.PI/2;
        };
        const portForklift=q=>{
          const yellow=std(q.color,.48,.4),h=Math.max(2.5,q.h*1.55);
          add(new THREE.BoxGeometry(q.w*S*.62,.72,q.d*S*.75),yellow,q.c-q.w*.13,.68,q.r);add(new THREE.BoxGeometry(q.w*S*.3,.92,q.d*S*.7),portOrange,q.c-q.w*.38,.86,q.r);
          for(const dc of [-q.w*.31,q.w*.31])for(const dr of [-q.d*.34,q.d*.34]){const wheel=add(new THREE.CylinderGeometry(.26*S,.26*S,.2*S,14),rubber,q.c+dc,.34,q.r+dr);wheel.rotation.z=Math.PI/2;}
          for(const dc of [-q.w*.06,q.w*.34])for(const dr of [-q.d*.3,q.d*.3])add(new THREE.BoxGeometry(.1*S,h*.68,.1*S),steel,q.c+dc,1.2+h*.34,q.r+dr);
          add(new THREE.BoxGeometry(q.w*S*.52,.14,q.d*S*.76),steel,q.c+q.w*.14,h+1.18,q.r);
          for(const dc of [q.w*.39,q.w*.48])add(new THREE.BoxGeometry(.11*S,h+1.25,.12*S),dark,q.c+dc,(h+1.25)/2,q.r);
          for(const dc of [q.w*.37,q.w*.52])add(new THREE.BoxGeometry(.12*S,.12,q.d*S*1.35),steel,q.c+dc,.16,q.r+q.d*.42).rotation.y=Math.PI/2;
          const seat=add(new THREE.BoxGeometry(.65*S,.48,.62*S),dark,q.c-q.w*.03,1.16,q.r);seat.rotation.x=-.06;portBeacon(q.c-q.w*.1,q.r,h+1.48);
        };
        const portPalletBase=(q,y=.08)=>{
          for(let slat=-2;slat<=2;slat++)add(new THREE.BoxGeometry(q.w*S*.18,.14,q.d*S),wood,q.c+slat*q.w*.19,y,q.r);
          for(const dc of [-q.w*.34,0,q.w*.34])add(new THREE.BoxGeometry(.18*S,.22,q.d*S*.88),wood,q.c+dc,y+.12,q.r);
        };
        const portCargoPallet=q=>{
          portPalletBase(q);const crates=Math.max(4,Math.min(8,+q.crates||+q.crateCount||5));
          for(let i=0;i<crates;i++){const col=i%3,row=Math.floor(i/3),crate=add(new THREE.BoxGeometry(q.w*S*.28,.58,q.d*S*.42),std(i%2?q.color:'#7a5430',.88),q.c+(col-1)*q.w*.29,.48+row*.58,q.r+(i%2-.5)*q.d*.38);crate.rotation.y=(i%3-1)*.04;for(const side of [-1,1])add(new THREE.BoxGeometry(q.w*S*.29,.035,.025*S),dark,crate.position.x/S+originC,.48+row*.58+side*.18,q.r+(i%2-.5)*q.d*.39).castShadow=false;}
          for(const dc of [-q.w*.36,q.w*.36])add(new THREE.BoxGeometry(.045*S,1.45,q.d*S*.98),portYellow,q.c+dc,.82,q.r).castShadow=false;
          portLabel(q.stencil||'SEALED CARGO','#f0d5a0',q.c,q.r+q.d*.54,1.55,.34);
        };
        const portBarrels=q=>{
          const count=Math.max(3,Math.min(4,+q.barrels||4));for(let i=0;i<count;i++){const col=i%2,row=Math.floor(i/2),c=q.c+(col-.5)*q.w*.44,r=q.r+(row-.5)*q.d*.46,drum=add(new THREE.CylinderGeometry(.29*S,.29*S,1.2,16),i%2?std(q.color,.4,.58):portBlue,c,.6,r);for(const y of [.18,.58,1.02]){const ring=add(new THREE.TorusGeometry(.29*S,.035*S,7,16),steel,c,y,r);ring.rotation.x=Math.PI/2;}add(new THREE.PlaneGeometry(.28*S,.2),basic(i%2?'#ffbe45':'#ef5b45'),c,.67,r+q.d*.23).castShadow=false;}
        };
        const portSacks=q=>{
          const count=Math.max(5,Math.min(7,+q.sacks||7));for(let i=0;i<count;i++){const col=i%3,row=Math.floor(i/3),sack=add(new THREE.SphereGeometry(.3*S,12,8),std(i%2?q.color:'#b79f73',.98),q.c+(col-1)*q.w*.25,.38+row*.45,q.r+(i%2-.5)*q.d*.32);sack.scale.set(1,.72,.68);add(new THREE.CylinderGeometry(.025,.04,.24,6),brass,sack.position.x/S+originC,.72+row*.45,sack.position.z/S+originR).rotation.z=.4;}
        };
        const portCargoNet=q=>{
          for(let i=0;i<6;i++){const col=i%3,row=Math.floor(i/3);add(new THREE.BoxGeometry(q.w*S*.27,.5,q.d*S*.42),std(i%2?'#8b6238':'#66757c',.8),q.c+(col-1)*q.w*.28,.35+row*.5,q.r+(i%2-.5)*q.d*.35);}
          for(let line=-2;line<=2;line++){add(new THREE.BoxGeometry(.035*S,1.25,q.d*S*.98),std('#b49a63',.9),q.c+line*q.w*.19,.72,q.r).rotation.z=line*.08;const cross=add(new THREE.BoxGeometry(q.w*S*.96,.035,q.d*S*.045),std('#b49a63',.9),q.c,.35+line*.18,q.r);cross.rotation.z=-line*.07;}
        };
        const portPalletJack=q=>{
          const yellow=std(q.color,.5,.36);for(const dc of [-.28,.28])add(new THREE.BoxGeometry(.18*S,.13,q.w*S*.84),yellow,q.c+dc,.15,q.r).rotation.y=Math.PI/2;add(new THREE.BoxGeometry(.72*S,.28,.56*S),yellow,q.c-q.w*.38,.26,q.r);
          for(const dc of [-.31,.31])for(const dr of [-q.d*.25,q.d*.25]){const wheel=add(new THREE.CylinderGeometry(.09*S,.09*S,.12,10),rubber,q.c+dc,.1,q.r+dr);wheel.rotation.z=Math.PI/2;}
          const shaft=add(new THREE.CylinderGeometry(.035,.055,1.55,8),steel,q.c-q.w*.48,1.05,q.r);shaft.rotation.z=-.28;const grip=add(new THREE.TorusGeometry(.2*S,.04*S,7,14,Math.PI),dark,q.c-q.w*.6,1.75,q.r);grip.rotation.z=-.28;
        };
        const portCargoCart=q=>{
          add(new THREE.BoxGeometry(q.w*S,.2,q.d*S),portGrey,q.c,.5,q.r);for(const dc of [-q.w*.4,q.w*.4])for(const dr of [-q.d*.38,q.d*.38]){const wheel=add(new THREE.CylinderGeometry(.17*S,.17*S,.14*S,12),rubber,q.c+dc,.22,q.r+dr);wheel.rotation.z=Math.PI/2;}
          for(const dc of [-q.w*.45,q.w*.45])for(const dr of [-q.d*.42,q.d*.42])add(new THREE.BoxGeometry(.08*S,1.15,.08*S),steel,q.c+dc,1.02,q.r+dr);
          for(let i=0;i<4;i++)add(new THREE.BoxGeometry(q.w*S*.36,.48,q.d*S*.42),std(i%2?'#9a6335':'#506d79',.8),q.c+(i%2-.5)*q.w*.42,.84+Math.floor(i/2)*.48,q.r+(i%2-.5)*q.d*.4);
        };
        const portLoadingRamp=q=>{
          const steps=6;for(let step=0;step<steps;step++){const y=(step+1)/steps*Math.max(.7,q.h*1.55),r=q.r+q.d*.5-(step+.5)*q.d/steps;add(new THREE.BoxGeometry(q.w*S,y,q.d*S/steps*.97),std(q.color,.5,.5),q.c,y/2,r);}
          for(const side of [-1,1]){const c=q.c+side*q.w*.48;for(let post=0;post<=steps;post+=2)add(new THREE.BoxGeometry(.07*S,1.05,.07*S),portYellow,c,.75,q.r+q.d*.45-post*q.d/steps);const rail=add(new THREE.CylinderGeometry(.035,.035,q.d*S,8),portYellow,c,1.28,q.r);rail.rotation.x=Math.PI/2;}
        };
        const portLeveller=q=>{
          const plate=add(new THREE.BoxGeometry(q.w*S,.18,q.d*S),std(q.color,.38,.66),q.c,.26,q.r);plate.rotation.x=-.08;const hinge=add(new THREE.CylinderGeometry(.09*S,.09*S,q.w*S,12),steel,q.c,.31,q.r-q.d*.44);hinge.rotation.z=Math.PI/2;
          for(let stripe=-4;stripe<=4;stripe++){const band=add(new THREE.BoxGeometry(q.w*S*.07,.035,q.d*S*.92),stripe%2?portYellow:dark,q.c+stripe*q.w*.09,.38,q.r);band.rotation.z=stripe%2?.48:-.48;}
        };
        const portBumper=q=>{
          add(new THREE.BoxGeometry(q.w*S,Math.max(.7,q.h*1.55),q.d*S),rubber,q.c,Math.max(.7,q.h*1.55)/2,q.r);for(const dc of [-q.w*.28,q.w*.28])for(const y of [.25,.72])add(new THREE.CylinderGeometry(.045*S,.045*S,.12,8),steel,q.c+dc,y,q.r+q.d*.53).rotation.x=Math.PI/2;
        };
        const portRope=q=>{
          for(let coil=0;coil<5;coil++){const rope=add(new THREE.TorusGeometry((.3+coil*.055)*S,.045*S,8,24),std(q.color,.92),q.c,.1+coil*.055,q.r);rope.rotation.x=Math.PI/2;}for(const side of [-1,1]){const tie=add(new THREE.CylinderGeometry(.025,.025,1.15*S,7),dark,q.c+side*.24,.22,q.r);tie.rotation.x=Math.PI/2;}
        };
        const portBollard=q=>{
          add(new THREE.CylinderGeometry(.28*S,.38*S,Math.max(1.1,q.h*1.55),16),std(q.color,.36,.68),q.c,.56,q.r);add(new THREE.CylinderGeometry(.42*S,.42*S,.16,16),steel,q.c,1.15,q.r);for(const axis of [-1,1]){const cleat=add(new THREE.CylinderGeometry(.07*S,.07*S,.8*S,10),steel,q.c,1.03,q.r);cleat.rotation.z=Math.PI/2;cleat.rotation.y=axis*.18;}
        };
        const portWireWall=q=>{
          const horizontal=q.w>=q.d,len=horizontal?q.w:q.d,posts=Math.max(2,Math.min(8,Math.round(len/1.15))),h=Math.max(3.2,q.h*1.55);
          for(let i=0;i<=posts;i++){const p=i/posts-.5,c=q.c+(horizontal?p*q.w:0),r=q.r+(horizontal?0:p*q.d);add(new THREE.BoxGeometry(horizontal?.07*S:.12*S,h,horizontal?.12*S:.07*S),steel,c,h/2,r);}
          for(let row=1;row<=5;row++){const rail=add(new THREE.BoxGeometry((horizontal?q.w:.05)*S,.035,(horizontal?.05:q.d)*S),portGrey,q.c,row*h/6,q.r);rail.castShadow=false;}
          for(let i=1;i<posts*2;i++){const p=i/(posts*2)-.5,wire=add(new THREE.BoxGeometry(horizontal?.018*S:.045*S,h*.9,horizontal?.045*S:.018*S),portGrey,q.c+(horizontal?p*q.w:0),h*.5,q.r+(horizontal?0:p*q.d));wire.castShadow=false;}
        };
        const portSafeCage=q=>{
          for(const dc of [-q.w*.47,q.w*.47])for(const dr of [-q.d*.47,q.d*.47])add(new THREE.BoxGeometry(.12*S,3.75,.12*S),steel,q.c+dc,1.88,q.r+dr);
          for(let beam=-3;beam<=3;beam++){add(new THREE.BoxGeometry(q.w*S*.94,.045,.06*S),portGrey,q.c,3.58,q.r+beam*q.d*.14);add(new THREE.BoxGeometry(.06*S,.045,q.d*S*.94),portGrey,q.c+beam*q.w*.14,3.6,q.r);}
          const gateR=q.r+q.d*.48;for(let bar=-3;bar<=3;bar++)add(new THREE.BoxGeometry(.045*S,3.25,.05*S),steel,q.c+bar*q.w*.1,1.7,gateR);add(new THREE.BoxGeometry(q.w*S*.8,.12,.08*S),portYellow,q.c,3.3,gateR);
          portLabel('SAFE CAGE','#ffd26d',q.c,gateR+.05,4.05,.66);
        };
        const portCashLockers=q=>{
          const count=Math.max(6,Math.min(12,+q.lockers||12)),cols=Math.ceil(count/2);add(new THREE.BoxGeometry(q.w*S,q.h*1.55,q.d*S),std(q.color,.42,.58),q.c,q.h*.775,q.r);
          for(let i=0;i<count;i++){const col=i%cols,row=Math.floor(i/cols),c=q.c+(col-(cols-1)/2)*q.w/cols,y=.58+row*q.h*.72;add(new THREE.BoxGeometry(q.w*S/cols*.86,q.h*.62,.055*S),i%2?portGrey:steel,c,y,q.r+q.d*.52);add(new THREE.BoxGeometry(.04*S,.15,.03*S),brass,c+q.w/cols*.27,y,q.r+q.d*.57);for(let vent=-1;vent<=1;vent++)add(new THREE.BoxGeometry(q.w*S/cols*.35,.018,.02*S),dark,c,y+.18+vent*.07,q.r+q.d*.59).castShadow=false;}
          for(let doc=0;doc<3;doc++)add(new THREE.BoxGeometry(.45*S,.035,.3*S),doc%2?portPaper:std('#c9a969',.88),q.c+(doc-1)*.45,q.h*1.62+doc*.04,q.r).rotation.y=(doc-1)*.12;
        };
        const portInspectionGate=q=>{
          const h=Math.max(3.5,q.h*1.55);for(const dc of [-q.w*.46,q.w*.46]){add(new THREE.BoxGeometry(.28*S,h,.48*S),std(q.color,.42,.48),q.c+dc,h/2,q.r);for(let lamp=0;lamp<3;lamp++)add(new THREE.SphereGeometry(.07*S,8,6),lamp===0?portRed:lamp===1?portYellow:std('#4bcf78',.35,.2),q.c+dc,h*.55+lamp*.28,q.r+q.d*.26).castShadow=false;}add(new THREE.BoxGeometry(q.w*S,.28,.5*S),portYellow,q.c,h,q.r);
          for(let ray=-2;ray<=2;ray++){const beam=add(new THREE.BoxGeometry(.025*S,h*.72,.025*S),basic('#69dcea',true,.35),q.c+ray*q.w*.12,h*.48,q.r);beam.castShadow=false;}
          portLabel('CUSTOMS SCAN','#ffd56e',q.c,q.r+q.d*.32,h+.52,.58);
        };
        const portCustomsTable=q=>{
          add(new THREE.BoxGeometry(q.w*S,.18,q.d*S),wood,q.c,.9,q.r);for(const dc of [-q.w*.4,q.w*.4])for(const dr of [-q.d*.34,q.d*.34])add(new THREE.BoxGeometry(.11*S,.86,.11*S),steel,q.c+dc,.43,q.r+dr);
          const crate=add(new THREE.BoxGeometry(1.2*S,.62,.86*S),std('#8c5c34',.9),q.c-q.w*.18,1.22,q.r);for(const side of [-1,1]){const lid=add(new THREE.BoxGeometry(.62*S,.08,.86*S),wood,q.c-q.w*.18+side*.32,1.62,q.r);lid.rotation.z=side*.42;}
          for(let item=0;item<4;item++)add(new THREE.BoxGeometry(.22*S,.16,.18*S),std(item%2?'#456b78':'#c28a3c',.72),q.c-q.w*.2+(item-1.5)*.24,1.62,q.r);
          for(let doc=0;doc<4;doc++){const paper=add(new THREE.PlaneGeometry(.42*S,.3*S),basic(doc%2?'#e8e1cc':'#b7d8db'),q.c+q.w*.28+(doc-1.5)*.15,1.02+doc*.01,q.r);paper.rotation.x=-Math.PI/2;paper.rotation.z=(doc-1.5)*.08;paper.castShadow=false;}
        };
        const portXray=q=>{
          const h=Math.max(2.7,q.h*1.55);add(new THREE.BoxGeometry(q.w*S,h,q.d*S),std(q.color,.42,.52),q.c,h/2,q.r);add(new THREE.BoxGeometry(q.w*S*.58,h*.58,q.d*S*1.04),dark,q.c-q.w*.08,h*.48,q.r);
          add(new THREE.BoxGeometry(q.w*S*1.28,.24,q.d*S*.72),steel,q.c,.54,q.r+q.d*.62);for(let roll=-4;roll<=4;roll++){const roller=add(new THREE.CylinderGeometry(.07*S,.07*S,q.w*S*.11,10),portGrey,q.c+roll*q.w*.12,.71,q.r+q.d*.62);roller.rotation.z=Math.PI/2;}
          const screen=add(new THREE.BoxGeometry(.8*S,.7,.1*S),dark,q.c+q.w*.36,1.75,q.r+q.d*.54);const glow=add(new THREE.PlaneGeometry(.62*S,.48),basic('#73e1d1'),q.c+q.w*.36,1.76,q.r+q.d*.6);glow.castShadow=false;for(let key=-2;key<=2;key++)add(new THREE.SphereGeometry(.035*S,7,5),key?portYellow:portRed,q.c+q.w*.36+key*.1,1.34,q.r+q.d*.6).castShadow=false;
        };
        const portSecurityPost=q=>{
          portConsole(q);for(let camera=0;camera<Math.max(2,+q.cctv||4);camera++){const a=camera/4*Math.PI*2,c=q.c+Math.cos(a)*q.w*.42,r=q.r+Math.sin(a)*q.d*.55;add(new THREE.BoxGeometry(.28*S,.2,.42*S),dark,c,2.75,r);const lens=add(new THREE.CylinderGeometry(.06*S,.08*S,.18,10),basic('#67d9ff'),c,2.72,r+Math.sign(Math.sin(a)||1)*.28);lens.rotation.x=Math.PI/2;}add(new THREE.BoxGeometry(q.w*S*1.25,.12,.16*S),portRed,q.c+q.w*.72,1.05,q.r);add(new THREE.CylinderGeometry(.09*S,.12*S,1.05,10),steel,q.c+q.w*.1,.54,q.r);
        };
        const portPalletStack=q=>{
          const levels=Math.max(3,Math.min(5,+q.pallets||5));for(let level=0;level<levels;level++){const qq={...q,w:q.w*(1-level*.035),d:q.d*(1-level*.025),c:q.c+(level%2-.5)*.06,r:q.r};portPalletBase(qq,.08+level*.22);}
          portLabel('PALLETS','#ecd29b',q.c,q.r+q.d*.54,1.5,.34);
        };
        const portCrateStack=q=>{
          const count=Math.max(6,Math.min(8,+q.crates||8));for(let i=0;i<count;i++){const col=i%3,row=Math.floor(i/3),crate=add(new THREE.BoxGeometry(q.w*S*.28,.58,q.d*S*.38),std(i%2?q.color:'#80552f',.88),q.c+(col-1)*q.w*.29,.3+row*.58,q.r+(i%2-.5)*q.d*.38);crate.rotation.y=(i%3-1)*.045;for(const edge of [-1,1])add(new THREE.BoxGeometry(q.w*S*.29,.035,.03*S),dark,crate.position.x/S+originC,.3+row*.58+edge*.2,crate.position.z/S+originR).castShadow=false;}
          portLabel('SEALED CARGO','#f0d5a0',q.c,q.r+q.d*.54,2.15,.36);
        };
        const portOffice=q=>{
          portDispatchBooth(q);portLabel('PORT CONTROL','#9deaff',q.c,q.r+q.d*.5,4.7,.72);
          const clock=add(new THREE.CylinderGeometry(.38*S,.38*S,.08,24),cream,q.c+q.w*.3,2.45,q.r-q.d*.46);clock.rotation.x=Math.PI/2;const rim=add(new THREE.TorusGeometry(.38*S,.04*S,7,24),brass,q.c+q.w*.3,2.45,q.r-q.d*.51);rim.rotation.x=Math.PI/2;
          for(let camera=0;camera<4;camera++){const c=q.c-q.w*.34+camera*q.w*.22,screen=add(new THREE.BoxGeometry(.78*S,.55,.08*S),dark,c,2.1,q.r-q.d*.47);add(new THREE.PlaneGeometry(.61*S,.39),basic(camera%2?'#78dbe8':'#80e0aa'),c,2.1,q.r-q.d*.53).castShadow=false;}
        };
        const portMapTable=q=>{
          add(new THREE.BoxGeometry(q.w*S,.16,q.d*S),wood,q.c,.84,q.r);for(const dc of [-q.w*.4,q.w*.4])for(const dr of [-q.d*.34,q.d*.34])add(new THREE.BoxGeometry(.1*S,.78,.1*S),steel,q.c+dc,.39,q.r+dr);
          const chart=add(new THREE.PlaneGeometry(q.w*S*.84,q.d*S*.78),basic('#b8d7d8'),q.c,.94,q.r);chart.rotation.x=-Math.PI/2;chart.castShadow=false;
          for(let route=0;route<5;route++){const line=add(new THREE.BoxGeometry(q.w*S*.55,.025,.025*S),route%2?portRed:portBlue,q.c+(route-2)*.08,.96,q.r+(route-2)*q.d*.1);line.rotation.y=(route-2)*.15;line.castShadow=false;}
          const compass=add(new THREE.TorusGeometry(.22*S,.025*S,7,18),brass,q.c+q.w*.3,.98,q.r);compass.rotation.x=Math.PI/2;
        };
        const portCashDesk=q=>{
          portConsole(q);const tray=add(new THREE.BoxGeometry(1.15*S,.12,.7*S),brass,q.c+q.w*.28,1.18,q.r+q.d*.2);for(let cash=0;cash<5;cash++)add(new THREE.BoxGeometry(.24*S,.05,.42*S),std(cash%2?'#6ca16b':'#bd9854',.8),q.c+q.w*.28+(cash-2)*.18,1.27,q.r+q.d*.2);add(new THREE.CylinderGeometry(.18*S,.18*S,.16,18),dark,q.c-q.w*.3,1.26,q.r);portLabel('CASH OFFICE','#ffd36b',q.c,q.r+q.d*.54,2.45,.5);
        };
        const marketStall=q=>{
          const type=String(q.stallType||'produce'),index=+q.stallIndex||0;
          const stallThemes={produce:['#2f7750','#ffe099','FRESH PRODUCE'],bakery:['#a85d35','#ffd58a','PANETTERIA'],fish:['#347d8c','#bcefff','PESCHERIA'],butcher:['#8f2f36','#ffd0c3','MACELLERIA'],cheese:['#d39d2d','#fff0a6','FORMAGGI'],flowers:['#8b3b78','#ffd0f2','FIORI']};
          const theme=stallThemes[type]||stallThemes.produce,frame=std(q.color,.88),canopyMat=std(theme[0],.7,.04),productMat=color=>std(color,.88,.02);
          // Slatted timber counter, angled display shelf, corner posts and a real fabric canopy.
          add(new THREE.BoxGeometry(q.w*S,.72,q.d*S),frame,q.c,.36,q.r);
          for(let slat=-4;slat<=4;slat++)add(new THREE.BoxGeometry(.055*S,.58,q.d*S*1.02),wood,q.c+slat*q.w*.1,.38,q.r).castShadow=false;
          const tray=add(new THREE.BoxGeometry(q.w*S*.92,.12,q.d*S*.82),std('#8a5b32',.84),q.c,.9,q.r);tray.rotation.x=-.12;
          for(const c of [q.c-q.w*.44,q.c+q.w*.44]){add(new THREE.BoxGeometry(.12*S,2.5,.12*S),wood,c,1.25,q.r);add(new THREE.BoxGeometry(.23*S,.18,.23*S),brass,c,2.46,q.r).castShadow=false;}
          const canopy=add(new THREE.BoxGeometry((q.w+.22)*S,.12,(q.d+.35)*S),canopyMat,q.c,2.5,q.r);canopy.rotation.z=(index%2?1:-1)*.035;
          for(let stripe=-3;stripe<=3;stripe++){const strip=add(new THREE.BoxGeometry(q.w*S*.105,.035,(q.d+.36)*S),stripe%2?cream:canopyMat,q.c+stripe*q.w*.12,2.57,q.r);strip.rotation.z=canopy.rotation.z;strip.castShadow=false;}
          const sign=labelSprite(theme[2],theme[1]);sign.position.set(x(q.c),2.9,z(q.r-.12));sign.scale.set(4.4,1.05,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;
          if(type==='produce'){
            for(let crateIndex=0;crateIndex<4;crateIndex++){const cc=q.c+(crateIndex-1.5)*q.w*.22,crate=add(new THREE.BoxGeometry(q.w*S*.2,.24,q.d*S*.64),std('#76502c',.9),cc,1.04,q.r);for(let itemIndex=0;itemIndex<6;itemIndex++){const palette=[['#c53d32','#d9ad34'],['#5c9143','#78a852'],['#db7d28','#e8a13b'],['#693b86','#a24d86']][crateIndex],fruit=add(new THREE.SphereGeometry((.09+(itemIndex%2)*.025)*S,9,7),productMat(palette[itemIndex%2]),cc+(itemIndex%3-1)*.18,1.22+Math.floor(itemIndex/3)*.13,q.r+(itemIndex%2-.5)*.32);fruit.scale.y=crateIndex===2?1.4:.9;}}
          }else if(type==='bakery'){
            for(let i=-3;i<=3;i++){const loaf=add(new THREE.CapsuleGeometry(.1*S,.34*S,6,12),productMat(i%2?'#d69b4b':'#b87332'),q.c+i*q.w*.115,1.23,q.r+(i%2-.5)*.28);loaf.rotation.z=Math.PI/2;for(let cut=-1;cut<=1;cut++){const score=add(new THREE.BoxGeometry(.025,.035,.12*S),cream,q.c+i*q.w*.115+cut*.12,1.36,q.r+(i%2-.5)*.28);score.rotation.z=-.45;score.castShadow=false;}}
            for(let i=-2;i<=2;i++){const roll=add(new THREE.TorusGeometry(.11*S,.045*S,7,14,Math.PI*1.55),productMat('#e6b566'),q.c+i*q.w*.16,1.16,q.r+.35);roll.rotation.x=Math.PI/2;roll.rotation.z=.7;}
          }else if(type==='fish'){
            const ice=add(new THREE.BoxGeometry(q.w*S*.88,.11,q.d*S*.68),new THREE.MeshPhysicalMaterial({color:0xc8f4ff,transparent:true,opacity:.7,roughness:.16,transmission:.22}),q.c,1.12,q.r);ice.rotation.x=-.08;
            for(let i=-3;i<=3;i++){const fish=add(new THREE.CapsuleGeometry(.075*S,.28*S,5,10),productMat(i%2?'#6aa1a8':'#8eb4b6'),q.c+i*q.w*.115,1.25,q.r+(i%2-.5)*.3);fish.rotation.z=Math.PI/2;const tail=add(new THREE.ConeGeometry(.12*S,.2*S,3),productMat(i%2?'#467883':'#70989d'),q.c+i*q.w*.115-.23,1.25,q.r+(i%2-.5)*.3);tail.rotation.z=Math.PI/2;add(new THREE.SphereGeometry(.025*S,6,5),black,q.c+i*q.w*.115+.2,1.3,q.r+(i%2-.5)*.3).castShadow=false;}
          }else if(type==='butcher'){
            const chilled=add(new THREE.BoxGeometry(q.w*S*.9,.18,q.d*S*.72),std('#e7d7cb',.48,.08),q.c,1.1,q.r);chilled.rotation.x=-.08;
            for(let i=-2;i<=2;i++){const cut=add(new THREE.CapsuleGeometry(.12*S,.22*S,6,12),productMat(i%2?'#a9343a':'#c4574f'),q.c+i*q.w*.16,1.3,q.r+(i%2-.5)*.28);cut.rotation.z=Math.PI/2;add(new THREE.BoxGeometry(.05*S,.025,.38*S),cream,q.c+i*q.w*.16,1.37,q.r+(i%2-.5)*.28).castShadow=false;}
            for(const c of [q.c-q.w*.28,q.c,q.c+q.w*.28]){const hook=add(new THREE.TorusGeometry(.1*S,.025*S,6,12,Math.PI*1.35),steel,c,2.12,q.r);hook.rotation.z=.35;const hanging=add(new THREE.CapsuleGeometry(.13*S,.34*S,6,12),productMat('#9d3438'),c,1.72,q.r);hanging.scale.set(.8,1.25,.62);}
          }else if(type==='cheese'){
            for(let i=-3;i<=3;i++){const wheel=add(new THREE.CylinderGeometry(.2*S,.2*S,.15,20),productMat(i%2?'#edbd43':'#d99b2f'),q.c+i*q.w*.115,1.22,q.r+(i%2-.5)*.28);wheel.rotation.x=Math.PI/2;for(let hole=0;hole<3;hole++){const dot=add(new THREE.SphereGeometry(.025*S,6,5),std('#9d752c',.8),q.c+i*q.w*.115+(hole-1)*.07,1.27,q.r+(i%2-.5)*.19);dot.castShadow=false;}}
            const board=add(new THREE.CylinderGeometry(.46*S,.46*S,.08,22),wood,q.c,1.16,q.r+.28);add(new THREE.ConeGeometry(.38*S,.24,3),productMat('#f2cd5d'),q.c,1.32,q.r+.28).rotation.y=.35;
          }else{
            for(let i=-3;i<=3;i++){const cc=q.c+i*q.w*.115;add(new THREE.CylinderGeometry(.1*S,.14*S,.25,12),std(i%2?'#80512f':'#9a6339',.9),cc,1.1,q.r);const stem=add(new THREE.CylinderGeometry(.018,.025,.7,7),std('#3f7944',.8),cc,1.55,q.r);for(let petal=0;petal<6;petal++){const a=petal/6*Math.PI*2,flower=add(new THREE.SphereGeometry(.06*S,8,6),productMat(['#e94e73','#f0c34f','#9a62d7'][Math.abs(i+petal)%3]),cc+Math.cos(a)*.08,1.92+Math.sin(a)*.03,q.r+Math.sin(a)*.08);flower.scale.set(1.25,.55,1);}}
          }
        };
        const marketStore=q=>{
          const wall=std(q.color,.82),trim=std('#d6b15a',.34,.45),shelf=std('#60402b',.8),storeH=3.7;
          // Open-front storeroom with shelving and a raised rolling shutter, not a solid block.
          add(new THREE.BoxGeometry(q.w*S,.22,q.d*S),std('#5e4936',.92),q.c,.11,q.r);
          add(new THREE.BoxGeometry(q.w*S,storeH,.22*S),wall,q.c,storeH/2,q.r+q.d*.48);
          for(const c of [q.c-q.w*.48,q.c+q.w*.48])add(new THREE.BoxGeometry(.25*S,storeH,q.d*S),wall,c,storeH/2,q.r);
          add(new THREE.BoxGeometry(q.w*S,.28,q.d*S),trim,q.c,storeH-.12,q.r);
          for(const side of [-1,1]){const rackC=q.c+side*q.w*.31;for(const y of [.58,1.35,2.12,2.9])add(new THREE.BoxGeometry(q.w*S*.26,.11,q.d*S*.7),shelf,rackC,y,q.r+.32);for(let level=0;level<4;level++)for(let i=-2;i<=2;i++){const pack=add(new THREE.BoxGeometry(.36*S,.34,.42*S),std(['#8e5635','#637a43','#9a3f3d','#be9134'][(level+i+8)%4],.88),rackC+i*.42,.82+level*.77,q.r+.32+(i%2-.5)*.52);pack.rotation.y=(i%2)*.07;}}
          for(let slat=0;slat<6;slat++)add(new THREE.BoxGeometry(q.w*S*.82,.08,.08*S),steel,q.c,storeH-.4-slat*.13,q.r-q.d*.49).castShadow=false;
          for(let i=0;i<5;i++){const crate=add(new THREE.BoxGeometry(.72*S,.46,.68*S),std(i%2?'#7c512f':'#906238',.92),q.c-q.w*.28+i*.88,.35,q.r-q.d*.3);crate.rotation.y=(i-2)*.04;}
          const sign=labelSprite('MAGAZZINO','#ffd66b');sign.position.set(x(q.c),4.15,z(q.r-q.d*.51));sign.scale.set(6.4,1.35,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;
        };
        const marketScale=q=>{
          const enamel=std('#e7c45d',.38,.42),dialMat=std('#f3ecd5',.52,.08),base=add(new THREE.CylinderGeometry(.58*S,.7*S,.35,18),dark,q.c,.18,q.r);
          add(new THREE.CylinderGeometry(.13*S,.18*S,1.55,12),enamel,q.c,1.03,q.r);
          const tray=add(new THREE.SphereGeometry(.7*S,24,12,0,Math.PI*2,0,Math.PI/2),steel,q.c,1.86,q.r);tray.scale.y=.34;
          const dial=add(new THREE.CylinderGeometry(.48*S,.48*S,.18,28),dialMat,q.c,1.44,q.r-.06);dial.rotation.x=Math.PI/2;
          const rim=add(new THREE.TorusGeometry(.48*S,.055*S,8,28),brass,q.c,1.44,q.r-.17);rim.rotation.x=Math.PI/2;
          for(let tick=0;tick<12;tick++){const a=tick/12*Math.PI*2,mark=add(new THREE.BoxGeometry(.025*S,.11,.025),black,q.c+Math.cos(a)*.36,1.44+Math.sin(a)*.36,q.r-.275);mark.rotation.z=a;mark.castShadow=false;}
          const pointer=add(new THREE.BoxGeometry(.04*S,.34,.035),std('#b33a34',.5),q.c,1.58,q.r-.29);pointer.rotation.z=-.68;pointer.castShadow=false;
          const sign=labelSprite('PESO','#ffe48a');sign.position.set(x(q.c),2.55,z(q.r));sign.scale.set(2.8,.78,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;
        };
        const factoryHoist=q=>{
          const frame=std(q.color,.32,.7),safety=std('#efad2f',.55,.3),hydraulic=std('#39464d',.34,.78),topY=4.15;
          // Portal hoist: two full side frames, I-beam, travelling trolley, chain and a different suspended load per production line.
          for(const c of [q.c-q.w*.44,q.c+q.w*.44]){
            for(const r of [q.r-q.d*.35,q.r+q.d*.35])add(new THREE.BoxGeometry(.2*S,topY,.2*S),frame,c,topY/2,r);
            add(new THREE.BoxGeometry(.72*S,.16,q.d*S*.88),safety,c,.15,q.r);
            add(new THREE.BoxGeometry(.55*S,.32,.32*S),dark,c,2.25,q.r+q.d*.45);
          }
          add(new THREE.BoxGeometry(q.w*S,.24,.4*S),frame,q.c,topY,q.r);add(new THREE.BoxGeometry(q.w*S,.1,.72*S),hydraulic,q.c,topY+.16,q.r);
          const trolleyC=q.c+(Math.round(q.r)%3-1)*q.w*.16;add(new THREE.BoxGeometry(.82*S,.48,.74*S),hydraulic,trolleyC,topY-.35,q.r);
          for(const dr of [-.16,.16]){const wheel=add(new THREE.CylinderGeometry(.11*S,.11*S,.18*S,12),rubber,trolleyC,topY-.08,q.r+dr);wheel.rotation.z=Math.PI/2;}
          const chain=add(new THREE.CylinderGeometry(.035,.035,1.55,7),steel,trolleyC,topY-1.34,q.r);const hook=add(new THREE.TorusGeometry(.19*S,.05*S,7,15,Math.PI*1.45),safety,trolleyC,topY-2.15,q.r);hook.rotation.z=.34;interiorVisualFx.push({kind:'factory-hoist',meshes:[chain,hook],baseY:[chain.position.y,hook.position.y],phase:q.r*.17});
          const loadKind=Math.round(q.r/5)%3;
          if(loadKind===0){const engine=add(new THREE.BoxGeometry(1.5*S,.85,1.05*S),std('#4e5a60',.34,.66),trolleyC,1.42,q.r);for(const dc of [-.48,0,.48]){const piston=add(new THREE.CylinderGeometry(.18*S,.18*S,.65,12),dark,trolleyC+dc,1.9,q.r);piston.rotation.z=Math.PI/2;}for(const dr of [-.42,.42])add(new THREE.TorusGeometry(.28*S,.11*S,9,18),rubber,trolleyC,1.35,q.r+dr).rotation.y=Math.PI/2;
          }else if(loadKind===1){for(const dr of [-.34,0,.34]){const beam=add(new THREE.BoxGeometry(2.4*S,.18,.38*S),std('#7b4d37',.56,.46),trolleyC,1.35+dr*.28,q.r+dr);for(const side of [-1,1])add(new THREE.BoxGeometry(2.4*S,.08,.08*S),safety,trolleyC,1.49+dr*.28,q.r+dr);}
          }else{const gear=add(new THREE.TorusGeometry(.68*S,.2*S,10,24),frame,trolleyC,1.55,q.r);gear.rotation.x=Math.PI/2;for(let tooth=0;tooth<10;tooth++){const a=tooth/10*Math.PI*2,toothMesh=add(new THREE.BoxGeometry(.25*S,.18,.18*S),safety,trolleyC+Math.cos(a)*.86,1.55,q.r+Math.sin(a)*.86);toothMesh.rotation.y=-a;}}
          const controlC=q.c+q.w*.52;add(new THREE.BoxGeometry(.62*S,1.15,.38*S),hydraulic,controlC,1.65,q.r+q.d*.32);add(new THREE.PlaneGeometry(.38*S,.28),basic('#62d9ef'),controlC,1.91,q.r+q.d*.54).castShadow=false;for(const [dc,color] of [[-.13,'#39c86b'],[.13,'#dd3e3e']])add(new THREE.SphereGeometry(.055*S,8,6),std(color,.4,.18),controlC+dc,1.48,q.r+q.d*.55).castShadow=false;
        };
        const factoryConveyor=q=>{
          const frame=std('#465159',.38,.7),belt=std('#20252a',.78,.08),guard=std(q.color,.48,.34),topY=1.48;
          for(const side of [-1,1])for(let leg=-4;leg<=4;leg+=2)add(new THREE.BoxGeometry(.12*S,1.15,.12*S),frame,q.c+leg*q.w*.1,.58,q.r+side*q.d*.42);
          for(const side of [-1,1])add(new THREE.BoxGeometry(q.w*S,.18,.14*S),frame,q.c,1.08,q.r+side*q.d*.44);
          add(new THREE.BoxGeometry(q.w*S*.94,.08,q.d*S*.72),belt,q.c,topY-.08,q.r);
          for(let roller=-5;roller<=5;roller++){const roll=add(new THREE.CylinderGeometry(.13*S,.13*S,q.d*S*.76,12),roller%2?steel:std('#768187',.3,.72),q.c+roller*q.w*.082,topY,q.r);roll.rotation.x=Math.PI/2;}
          for(const side of [-1,1])add(new THREE.BoxGeometry(q.w*S,.2,.1*S),guard,q.c,topY+.2,q.r+side*q.d*.48);
          const motorC=q.c+q.w*.48,motor=add(new THREE.CylinderGeometry(.34*S,.34*S,.72*S,16),std('#35546a',.3,.72),motorC,.8,q.r+q.d*.58);motor.rotation.x=Math.PI/2;add(new THREE.BoxGeometry(.62*S,.48,.58*S),frame,motorC,.72,q.r+q.d*.36);
          const line=Math.round(q.r/5)%3;
          for(let item=-3;item<=3;item++){
            const c=q.c+item*q.w*.115;
            if(line===0){const blank=add(new THREE.CylinderGeometry(.22*S,.22*S,.12,18),std(item%2?'#8a9398':'#b25b32',.38,.62),c,topY+.24,q.r);blank.rotation.x=Math.PI/2;interiorVisualFx.push({kind:'factory-belt',mesh:blank,baseX:blank.position.x,span:q.w*S,phase:(item+3)/7});
            }else if(line===1){const housing=add(new THREE.BoxGeometry(.62*S,.42,.52*S),std(item%2?'#7a4e36':'#566670',.48,.46),c,topY+.23,q.r);interiorVisualFx.push({kind:'factory-belt',mesh:housing,baseX:housing.position.x,span:q.w*S,phase:(item+3)/7});for(const side of [-1,1])add(new THREE.CylinderGeometry(.08*S,.08*S,.2,10),steel,c+side*.22,topY+.47,q.r);
            }else{const part=add(new THREE.TorusGeometry(.2*S,.075*S,8,16),std(item%2?'#d08c2f':'#68757b',.38,.56),c,topY+.24,q.r);part.rotation.x=Math.PI/2;interiorVisualFx.push({kind:'factory-belt',mesh:part,baseX:part.position.x,span:q.w*S,phase:(item+3)/7});}
          }
          const stop=add(new THREE.BoxGeometry(.32*S,.55,.25*S),guard,q.c-q.w*.51,1.32,q.r+q.d*.58);add(new THREE.SphereGeometry(.075*S,9,7),std('#e33a37',.34,.24),q.c-q.w*.51,1.49,q.r+q.d*.74).castShadow=false;
        };
        const factoryPress=q=>{
          const body=std(q.color,.34,.68),beam=std('#3d484f',.28,.78),hazard=std('#efad2f',.55,.28),pressRed=std('#a93232',.45,.34),baseY=.34,topY=5.15;
          // Open H-frame with a readable working throat, ram, die and hydraulic unit.
          add(new THREE.BoxGeometry(q.w*S*.92,.34,q.d*S*.78),beam,q.c,baseY,q.r);
          for(const c of [q.c-q.w*.36,q.c+q.w*.36]){add(new THREE.BoxGeometry(.58*S,topY-.45,.72*S),body,c,(topY+.1)/2,q.r);for(const y of [1.4,3.55])add(new THREE.BoxGeometry(.72*S,.17,q.d*S*.66),hazard,c,y,q.r);}
          add(new THREE.BoxGeometry(q.w*S*.86,.72,q.d*S*.72),beam,q.c,topY,q.r);
          const cylinder=add(new THREE.CylinderGeometry(.58*S,.72*S,2.2,18),body,q.c,topY-.86,q.r),ram=add(new THREE.CylinderGeometry(.2*S,.28*S,1.65,14),steel,q.c,topY-2.55,q.r);
          const platen=add(new THREE.BoxGeometry(q.w*S*.48,.38,q.d*S*.54),pressRed,q.c,2.16,q.r);interiorVisualFx.push({kind:'factory-press',meshes:[ram,platen],baseY:[ram.position.y,platen.position.y],phase:q.r*.11});add(new THREE.BoxGeometry(q.w*S*.5,.32,q.d*S*.58),beam,q.c,1.16,q.r);add(new THREE.BoxGeometry(q.w*S*.26,.28,q.d*S*.3),std('#8b5837',.5,.42),q.c,1.48,q.r);
          for(const side of [-1,1])for(let bar=-2;bar<=2;bar++){const fence=add(new THREE.BoxGeometry(.055*S,3.2,.055*S),hazard,q.c+side*q.w*.49,2.1,q.r+bar*q.d*.18);fence.castShadow=false;}for(const side of [-1,1])for(let ray=-2;ray<=2;ray++){const lightRay=add(new THREE.CylinderGeometry(.016,.016,2.5,6),basic('#ff4a38',true,.48),q.c+side*q.w*.43,2.18,q.r+ray*q.d*.15);lightRay.castShadow=false;}
          const pumpC=q.c+q.w*.58;add(new THREE.BoxGeometry(1.3*S,1.62,1.1*S),body,pumpC,.82,q.r-q.d*.28);const tank=add(new THREE.CylinderGeometry(.4*S,.4*S,1.25,14),pressRed,pumpC,1.95,q.r-q.d*.28);const gauge=add(new THREE.CylinderGeometry(.28*S,.28*S,.12,20),cream,pumpC,2.75,q.r-q.d*.12);gauge.rotation.x=Math.PI/2;add(new THREE.BoxGeometry(.025*S,.31,.025),dark,pumpC,2.85,q.r-q.d*.02).rotation.z=-.65;add(new THREE.SphereGeometry(.1*S,10,7),pressRed,pumpC+.54,1.35,q.r+.18).castShadow=false;
        };
        const factoryStore=q=>{
          const cage=std('#5e6870',.4,.7),shelf=std('#37434a',.38,.72),lock=std('#d6a72f',.34,.6),storeH=3.75;
          // Mesh cage with visible stock and a locked sliding gate instead of an opaque cube.
          add(new THREE.BoxGeometry(q.w*S,.2,q.d*S),std('#30363b',.82),q.c,.1,q.r);
          for(const c of [q.c-q.w*.47,q.c+q.w*.47])for(const r of [q.r-q.d*.46,q.r+q.d*.46])add(new THREE.BoxGeometry(.18*S,storeH,.18*S),cage,c,storeH/2,r);
          for(const side of [-1,1]){const c=q.c+side*q.w*.48;for(let bar=-4;bar<=4;bar++)add(new THREE.BoxGeometry(.04*S,storeH-.35,.04*S),cage,c,(storeH-.35)/2,q.r+bar*q.d*.105).castShadow=false;for(let y=.45;y<storeH;y+=.58)add(new THREE.BoxGeometry(.045*S,.04,q.d*S*.92),cage,c,y,q.r).castShadow=false;}
          for(let bar=-7;bar<=7;bar++)add(new THREE.BoxGeometry(.04*S,storeH-.35,.04*S),cage,q.c+bar*q.w*.06,(storeH-.35)/2,q.r+q.d*.48).castShadow=false;
          for(const side of [-1,1]){const rackC=q.c+side*q.w*.28;for(const y of [.55,1.35,2.15,2.95])add(new THREE.BoxGeometry(q.w*S*.28,.12,q.d*S*.64),shelf,rackC,y,q.r);for(let level=0;level<4;level++)for(let item=-2;item<=2;item++){const stock=add(new THREE.BoxGeometry(.42*S,.36,.54*S),std(['#7a5135','#526a76','#a04b3c','#8a7b3e'][(level+item+8)%4],.78,.18),rackC+item*.46,.8+level*.8,q.r+(item%2-.5)*.54);stock.rotation.y=(item%2)*.06;}}
          for(let barrel=-1;barrel<=1;barrel++){const drum=add(new THREE.CylinderGeometry(.34*S,.34*S,1.05,14),barrel%2?std('#a85d31',.52,.42):cage,q.c+barrel*.92,.53,q.r-q.d*.27);for(const y of [.12,.91]){const ring=add(new THREE.TorusGeometry(.34*S,.035*S,7,15),lock,q.c+barrel*.92,y,q.r-q.d*.27);ring.rotation.x=Math.PI/2;}}
          for(let gearIndex=0;gearIndex<3;gearIndex++){const gear=add(new THREE.TorusGeometry((.26+gearIndex*.05)*S,.09*S,8,16),cage,q.c-q.w*.3+gearIndex*.52,1.2+gearIndex*.38,q.r+q.d*.27);gear.rotation.x=Math.PI/2;}
          const gate=add(new THREE.BoxGeometry(q.w*S*.34,.16,.16*S),lock,q.c-q.w*.22,storeH-.12,q.r-q.d*.49);for(let bar=-3;bar<=3;bar++)add(new THREE.BoxGeometry(.045*S,storeH-.55,.045*S),cage,q.c-q.w*.22+bar*q.w*.04,(storeH-.55)/2,q.r-q.d*.5).castShadow=false;const padlock=add(new THREE.BoxGeometry(.28*S,.32,.16*S),lock,q.c-q.w*.04,1.6,q.r-q.d*.54);const shackle=add(new THREE.TorusGeometry(.12*S,.035*S,6,12,Math.PI),cage,q.c-q.w*.04,1.86,q.r-q.d*.55);shackle.rotation.x=Math.PI/2;
          const sign=labelSprite('SECURE PARTS STORE','#ffc05a');sign.position.set(x(q.c),4.25,z(q.r-q.d*.52));sign.scale.set(7.2,1.35,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;
        };
        const factorySafe=q=>{
          const safe=add(new THREE.BoxGeometry(1.55*S,2.05,1.32*S),steel,q.c,1.03,q.r);outline(safe);const face=add(new THREE.BoxGeometry(1.35*S,1.82,.12*S),std(q.opened?'#43515a':'#69757c',.25,.84),q.c,1.05,q.r+.72);face.rotation.y=q.opened?-.82:0;const wheel=add(new THREE.TorusGeometry(.34*S,.075*S,8,18),brass,q.c,1.1,q.r+.81);wheel.rotation.x=Math.PI/2;for(let spoke=0;spoke<4;spoke++){const a=spoke/4*Math.PI*2,bar=add(new THREE.BoxGeometry(.62,.045,.045),brass,q.c+Math.cos(a)*.14,1.1+Math.sin(a)*.14,q.r+.84);bar.rotation.z=a;}if(q.opened)for(let bundle=0;bundle<6;bundle++)add(new THREE.BoxGeometry(.32*S,.1,.48*S),std('#6f914f',.82),q.c+(bundle%3-1)*.34,.32+Math.floor(bundle/3)*.16,q.r+.1);
        };
        const factoryControlBooth=q=>{
          const shell=std('#404a51',.4,.68),orange=std(q.color,.48,.32),consoleMat=std('#252c31',.4,.65);
          add(new THREE.BoxGeometry(q.w*S,.68,q.d*S),shell,q.c,.34,q.r);add(new THREE.BoxGeometry(q.w*S*1.03,.16,q.d*S*1.1),orange,q.c,.76,q.r);
          for(const c of [q.c-q.w*.48,q.c+q.w*.48])add(new THREE.BoxGeometry(.12*S,2.45,.12*S),shell,c,1.58,q.r);
          const pane=add(new THREE.BoxGeometry(q.w*S*.94,1.62,.08*S),glass,q.c,1.67,q.r+q.d*.48);pane.castShadow=false;
          add(new THREE.BoxGeometry(q.w*S*.72,.18,q.d*S*.82),consoleMat,q.c,1.02,q.r);
          for(let monitorIndex=0;monitorIndex<3;monitorIndex++){const c=q.c+(monitorIndex-1)*q.w*.22;add(new THREE.BoxGeometry(1.05*S,.78,.12*S),dark,c,1.72,q.r+q.d*.38);const screen=add(new THREE.PlaneGeometry(.88*S,.6),basic(['#59b7dc','#74d38c','#e3ad54'][monitorIndex]),c,1.72,q.r+q.d*.46);screen.castShadow=false;for(let line=0;line<3;line++)add(new THREE.BoxGeometry(.55*S,.025,.012),cream,c-.07,1.92-line*.18,q.r+q.d*.49).castShadow=false;}
          for(let key=-4;key<=4;key++)add(new THREE.BoxGeometry(.11*S,.035,.16*S),key%3?cream:orange,q.c+key*.18,1.17,q.r+q.d*.08).castShadow=false;
          const radio=add(new THREE.BoxGeometry(.42*S,.52,.28*S),dark,q.c+q.w*.36,1.36,q.r);add(new THREE.CylinderGeometry(.018,.025,.62,7),steel,q.c+q.w*.45,1.9,q.r).rotation.z=-.18;
          // Access turnstile and helmet rack make this a real staffed checkpoint.
          const gateC=q.c-q.w*.58;add(new THREE.CylinderGeometry(.08*S,.1*S,1.25,10),steel,gateC,.64,q.r);for(let arm=0;arm<3;arm++){const a=arm/3*Math.PI*2,rail=add(new THREE.CylinderGeometry(.035,.045,1.25*S,8),steel,gateC,1.1,q.r);rail.rotation.z=Math.PI/2;rail.rotation.y=a;}
          for(let helmet=0;helmet<4;helmet++){const hardhat=add(new THREE.SphereGeometry(.2*S,12,7,0,Math.PI*2,0,Math.PI/2),helmet%2?orange:std('#f1c23f',.48),q.c+q.w*.24+helmet*.42,2.72,q.r);add(new THREE.BoxGeometry(.42*S,.055,.18*S),helmet%2?orange:std('#f1c23f',.48),q.c+q.w*.24+helmet*.42,2.72,q.r+.1);}
        };
        const factoryElectricalPanel=q=>{
          const panel=std(q.color,.34,.72),trim=std('#242b30',.42,.66),warning=std('#e1a431',.46,.38);addBox(q,panel,1.55);add(new THREE.BoxGeometry(q.w*S*1.03,.12,q.d*S*1.08),trim,q.c,q.h*1.55+.08,q.r);
          for(let meter=0;meter<6;meter++){const col=meter%3,row=Math.floor(meter/3),c=q.c+(col-1)*q.w*.25,y=2.65-row*.74,dial=add(new THREE.CylinderGeometry(.23*S,.23*S,.08,20),cream,c,y,q.r+q.d*.53);dial.rotation.x=Math.PI/2;const needle=add(new THREE.BoxGeometry(.025*S,.22,.02),dark,c,y+.07,q.r+q.d*.59);needle.rotation.z=-.7+meter*.18;}
          for(let button=0;button<8;button++){const c=q.c+(button%4-1.5)*q.w*.17,y=1.08-Math.floor(button/4)*.42,light=add(new THREE.SphereGeometry(.07*S,9,6),std(button%3===0?'#df423b':button%3===1?'#4bd676':'#e0ad39',.35,.22),c,y,q.r+q.d*.57);light.castShadow=false;}
          for(let conduit=-2;conduit<=2;conduit++){const pipe=add(new THREE.CylinderGeometry(.035,.035,1.8,7),conduit%2?warning:steel,q.c+conduit*q.w*.17,4.1,q.r);pipe.castShadow=false;}
        };
        const factoryRoomWall=q=>{
          const wall=addBox(q,std(q.color,.78));const horizontal=q.w>q.d;for(let stud=-2;stud<=2;stud++){const c=q.c+(horizontal?stud*q.w*.19:0),r=q.r+(horizontal?0:stud*q.d*.19);add(new THREE.BoxGeometry(horizontal?.055*S:.14*S,q.h*1.5,horizontal?.14*S:.055*S),std('#69747b',.35,.68),c,q.h*.75,r).castShadow=false;}add(new THREE.BoxGeometry((horizontal?q.w:.18)*S,.12,(horizontal?.18:q.d)*S),std('#d49a2e',.44,.42),q.c,q.h*1.52,q.r).castShadow=false;
        };
        const factoryLockerBank=q=>{
          const body=std(q.color,.42,.62),door=std('#7b8790',.5,.5),count=Math.max(3,+q.lockers||6);addBox(q,body);
          for(let locker=0;locker<count;locker++){const c=q.c+(locker-(count-1)/2)*q.w/count,frontR=q.r+q.d*.52;add(new THREE.BoxGeometry(q.w*S/count*.86,q.h*1.39,.08*S),locker%2?door:body,c,q.h*.75,frontR);for(let vent=-1;vent<=1;vent++)add(new THREE.BoxGeometry(q.w*S/count*.45,.025,.02*S),dark,c,q.h*1.15+vent*.1,frontR+.06).castShadow=false;add(new THREE.BoxGeometry(.035*S,.25,.03*S),brass,c+q.w/count*.28,q.h*.72,frontR+.07);}
          for(let helmet=0;helmet<3;helmet++){const cap=add(new THREE.SphereGeometry(.19*S,12,7,0,Math.PI*2,0,Math.PI/2),std(helmet%2?'#efad2f':'#e7772f',.5),q.c+(helmet-1)*q.w*.25,q.h*1.62,q.r);cap.castShadow=false;}
        };
        const factoryStaffBench=q=>{
          add(new THREE.BoxGeometry(q.w*S,.18,q.d*S*.8),wood,q.c,.62,q.r);for(const c of [q.c-q.w*.4,q.c+q.w*.4])add(new THREE.BoxGeometry(.16*S,.62,.16*S),steel,c,.31,q.r);
          add(new THREE.BoxGeometry(q.w*S*.92,.18,.14*S),wood,q.c,1.24,q.r-q.d*.36);for(let hook=0;hook<4;hook++){const c=q.c+(hook-1.5)*q.w*.2;add(new THREE.CylinderGeometry(.025,.035,.38,7),steel,c,1.73,q.r-q.d*.34).rotation.z=.38;const coat=add(new THREE.CapsuleGeometry(.18*S,.42,6,10),std(hook%2?'#38566a':'#7b4c36',.88),c,1.35,q.r-q.d*.28);coat.scale.set(.75,1,.3);}
        };
        const factoryBreakTable=q=>{
          add(new THREE.BoxGeometry(q.w*S,.18,q.d*S),wood,q.c,.86,q.r);for(const c of [q.c-q.w*.4,q.c+q.w*.4])for(const r of [q.r-q.d*.35,q.r+q.d*.35])add(new THREE.BoxGeometry(.12*S,.82,.12*S),steel,c,.42,r);
          for(const [dc,dr,ang] of [[-q.w*.58,0,Math.PI/2],[q.w*.58,0,-Math.PI/2],[0,-q.d*.85,0],[0,q.d*.85,Math.PI]])chair(q.r+dr,q.c+dc,'#4b5a62',ang);
          const kettle=add(new THREE.CylinderGeometry(.24*S,.31*S,.48,14),steel,q.c+q.w*.25,1.22,q.r);add(new THREE.TorusGeometry(.23*S,.045*S,6,13,Math.PI),dark,q.c+q.w*.25,1.43,q.r).rotation.z=Math.PI/2;const mug=add(new THREE.CylinderGeometry(.11*S,.1*S,.23,12),cream,q.c-q.w*.18,1.12,q.r);
          const firstAid=add(new THREE.BoxGeometry(.85*S,.8,.2*S),std('#e4e6df',.74),q.c-q.w*.42,2.5,q.r-q.d*.56);add(new THREE.BoxGeometry(.48*S,.12,.04*S),std('#cc3639',.5),q.c-q.w*.42,2.5,q.r-q.d*.68);add(new THREE.BoxGeometry(.12*S,.5,.04*S),std('#cc3639',.5),q.c-q.w*.42,2.5,q.r-q.d*.69);
        };
        const factoryWorkbench=q=>{
          const bench=std(q.color,.7),peg=std('#5a6267',.68,.36);add(new THREE.BoxGeometry(q.w*S,.24,q.d*S),bench,q.c,1.05,q.r);for(const c of [q.c-q.w*.43,q.c+q.w*.43])add(new THREE.BoxGeometry(.3*S,1.02,q.d*S*.85),dark,c,.52,q.r);
          add(new THREE.BoxGeometry(q.w*S*.96,1.65,.12*S),peg,q.c,2.02,q.r-q.d*.46);for(let holeC=-7;holeC<=7;holeC++)for(let holeY=0;holeY<5;holeY++){const hole=add(new THREE.SphereGeometry(.018*S,5,4),dark,q.c+holeC*q.w*.055,1.43+holeY*.27,q.r-q.d*.54);hole.castShadow=false;}
          for(let tool=-3;tool<=3;tool++){const c=q.c+tool*q.w*.105,handle=add(new THREE.CylinderGeometry(.035,.045,.62,7),std(tool%2?'#d38a2f':'#a63d36',.58),c,2.13,q.r-q.d*.58);handle.rotation.z=(tool%3-1)*.35;add(new THREE.BoxGeometry(.28*S,.1,.08*S),steel,c,2.42,q.r-q.d*.59).rotation.z=(tool%3-1)*.35;}
          const viseC=q.c+q.w*.32;add(new THREE.BoxGeometry(.6*S,.42,.54*S),std('#3f6478',.32,.72),viseC,1.32,q.r);for(const side of [-1,1])add(new THREE.BoxGeometry(.24*S,.32,.42*S),steel,viseC+side*.25,1.55,q.r);add(new THREE.CylinderGeometry(.04,.06,.95*S,8),steel,viseC,.98,q.r+.44).rotation.z=Math.PI/2;
        };
        const factoryPartsRack=q=>{
          const frame=std(q.color,.4,.68);for(const c of [q.c-q.w*.45,q.c+q.w*.45])add(new THREE.BoxGeometry(.12*S,q.h*1.55,.16*S),frame,c,q.h*.775,q.r);for(let row=0;row<4;row++){const y=.36+row*.62;add(new THREE.BoxGeometry(q.w*S,.1,q.d*S),frame,q.c,y,q.r);for(let bin=-2;bin<=2;bin++){const binMesh=add(new THREE.BoxGeometry(q.w*S*.17,.34,q.d*S*.72),std(['#bf7035','#466d81','#8c4d42'][Math.abs(row+bin)%3],.76,.18),q.c+bin*q.w*.18,y+.22,q.r);add(new THREE.BoxGeometry(.16*S,.08,.025*S),cream,q.c+bin*q.w*.18,y+.26,q.r+q.d*.39).castShadow=false;}}
        };
        const factoryWelder=q=>{
          const body=std(q.color,.38,.66);add(new THREE.BoxGeometry(q.w*S*.58,1.2,q.d*S*.72),body,q.c,.6,q.r);add(new THREE.BoxGeometry(.62*S,.18,.12*S),basic('#68d8f0'),q.c,1.02,q.r+q.d*.38).castShadow=false;for(const c of [q.c+q.w*.25,q.c+q.w*.47]){const tank=add(new THREE.CylinderGeometry(.17*S,.17*S,1.4,13),c>q.c+q.w*.3?std('#3d735b',.36,.62):std('#a84c3f',.42,.54),c,.72,q.r-q.d*.1);add(new THREE.TorusGeometry(.18*S,.025*S,6,13),brass,c,1.38,q.r-q.d*.1).rotation.x=Math.PI/2;}
          const hose=add(new THREE.TorusGeometry(.54*S,.045*S,8,22,Math.PI*1.6),rubber,q.c,1.52,q.r);hose.rotation.x=Math.PI/2;const mask=add(new THREE.SphereGeometry(.28*S,12,8),dark,q.c-q.w*.3,1.42,q.r);mask.scale.set(1,.78,.38);add(new THREE.BoxGeometry(.42*S,.2,.04*S),basic('#65cce8'),q.c-q.w*.3,1.42,q.r+q.d*.2).castShadow=false;
        };
        const factoryLoadingBay=q=>{
          const frame=std('#30383e',.36,.72),door=std(q.color,.5,.48),hazard=std('#e6aa2e',.54,.32);add(new THREE.BoxGeometry(q.w*S,.22,.18*S),frame,q.c,q.h*1.55,q.r);for(const c of [q.c-q.w*.49,q.c+q.w*.49])add(new THREE.BoxGeometry(.22*S,q.h*1.55,.22*S),frame,c,q.h*.775,q.r);
          for(let slat=0;slat<7;slat++)add(new THREE.BoxGeometry(q.w*S*.92,.08,.12*S),door,q.c,.42+slat*.52,q.r+.12).castShadow=false;for(let stripe=-5;stripe<=5;stripe++){const s=add(new THREE.BoxGeometry(q.w*S*.055,.12,.18*S),stripe%2?hazard:dark,q.c+stripe*q.w*.075,.22,q.r+.25);s.rotation.z=stripe%2?.55:-.55;}
          for(const c of [q.c-q.w*.36,q.c+q.w*.36])add(new THREE.BoxGeometry(.65*S,.72,.62*S),dark,c,.36,q.r+.55);const sign=labelSprite(`LOADING BAY ${q.dockNumber||3}`,'#ffc04c');sign.position.set(x(q.c),4.85,z(q.r));sign.scale.set(5.5,1.15,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;
        };
        const factoryPalletJack=q=>{
          const yellow=std(q.color,.5,.36);for(const dc of [-.32,.32])add(new THREE.BoxGeometry(.22*S,.14,q.w*S*.82),yellow,q.c+dc,.18,q.r).rotation.y=Math.PI/2;add(new THREE.BoxGeometry(.86*S,.28,.62*S),yellow,q.c-q.w*.38,.27,q.r);for(const dc of [-.36,.36]){const wheel=add(new THREE.CylinderGeometry(.11*S,.11*S,.15,10),rubber,q.c+dc,.11,q.r+q.d*.34);wheel.rotation.z=Math.PI/2;}const handle=add(new THREE.CylinderGeometry(.035,.055,1.6,8),steel,q.c-q.w*.5,1.1,q.r);handle.rotation.z=-.25;const grip=add(new THREE.TorusGeometry(.22*S,.045*S,7,14,Math.PI),dark,q.c-q.w*.6,1.87,q.r);grip.rotation.z=-.25;
        };
        const factoryCargoPallet=q=>{
          for(let slat=-2;slat<=2;slat++)add(new THREE.BoxGeometry(q.w*S*.18,.16,q.d*S),wood,q.c+slat*q.w*.19,.08,q.r);for(let crate=0;crate<6;crate++){const col=crate%3,row=Math.floor(crate/3),boxMesh=add(new THREE.BoxGeometry(q.w*S*.28,.64,q.d*S*.45),std(crate%2?q.color:'#6b7480',.78,.16),q.c+(col-1)*q.w*.3,.48+row*.64,q.r+(crate%2-.5)*q.d*.42);boxMesh.rotation.y=(crate%3-1)*.035;}const wrap=add(new THREE.BoxGeometry(q.w*S*.96,1.45,q.d*S*.94),new THREE.MeshPhysicalMaterial({color:0xd9f4f5,transparent:true,opacity:.13,roughness:.08,transmission:.35,side:THREE.DoubleSide}),q.c,.82,q.r);wrap.castShadow=false;
        };
        const mansionStairs=q=>{for(let i=0;i<8;i++){const p=(i+1)/8,h=q.h*1.55*p;add(new THREE.BoxGeometry(q.w*S,h,q.d*S/8),std(i%2?q.color:'#745132',.72),q.c,h/2,q.r+q.d*.5-(i+.5)*q.d/8);}};
        const bookshelf=q=>{
          addBox(q,wood);for(let row=0;row<4;row++){add(new THREE.BoxGeometry(q.w*S*.94,.12,q.d*S*1.02),brass,q.c,.45+row*q.h*.38,q.r).castShadow=false;for(let i=-3;i<=3;i++)add(new THREE.BoxGeometry(q.w*S*.09,.48,q.d*S*.55),std(['#713a3c','#32556a','#817047'][Math.abs(i+row)%3],.92),q.c+i*q.w*.105,.72+row*q.h*.38,q.r+q.d*.28);}
        };
        const piano=q=>{
          addBox(q,black);const lid=add(new THREE.BoxGeometry(q.w*S,.16,q.d*S*.9),std('#24262b',.32,.36),q.c,q.h*1.55+.25,q.r);lid.rotation.z=-.08;
          for(let i=-7;i<=7;i++)add(new THREE.BoxGeometry(q.w*S/17,.08,.48*S),i%2?cream:black,q.c+i*q.w/17,q.h*1.55+.12,q.r+q.d*.46).castShadow=false;
        };
        // Remove the old category placeholders but keep authored walls, exit and ceiling fill.
        for(const [i,o] of [...interiorGroup.children].entries()){
          if(o.type!=='GridHelper'&&!(i>7&&o.type!=='RectAreaLight'))continue;
          interiorGroup.remove(o);o.geometry?.dispose?.();if(o.material&&!Array.isArray(o.material))o.material.dispose?.();
        }
        if(interiorFloor){const old=interiorFloor.material;interiorFloor.material=std(layout.floor?.[0]||'#62584f',.84);old?.dispose?.();}
        const wallMat=std(layout.wall||'#313943',.88),accentMat=std(layout.accent||'#d7ae4c',.42,.36);
        add(new THREE.BoxGeometry((W-.7)*S,2.85,.12*S),wallMat,W/2,1.75,.19);
        add(new THREE.BoxGeometry(.12*S,2.85,(H-.7)*S),wallMat,.19,1.75,H/2);
        add(new THREE.BoxGeometry((W-.7)*S,.14,.16*S),accentMat,W/2,3.1,.22).castShadow=false;
        add(new THREE.BoxGeometry(.16*S,.14,(H-.7)*S),accentMat,.22,3.1,H/2).castShadow=false;
        const secondFloor=layout.floor?.[1]||layout.floor?.[0]||'#55483d';
        for(let r=1.1;r<H-.8;r+=2.4)floorZone({r,c:W/2,w:W-.8,d:1.15,color:secondFloor},std(secondFloor,.9));
        for(const q of layout.items||[]){
          switch(q.kind){
            case 'wet_floor':case 'dance_floor':floorZone(q,q.kind==='wet_floor'?new THREE.MeshPhysicalMaterial({color:q.color,transparent:true,opacity:.52,roughness:.08,metalness:.12}):std(q.color,.32,.18,q.color,.22));break;
            case 'table':table(q);break;
            case 'cashier':case 'service_counter':case 'prep_counter':case 'pickup_counter':case 'bar_counter':case 'dispatch_desk':case 'security_desk':case 'don_desk':counter(q);break;
            case 'waiting_sofa':case 'booth':case 'vip_sofa':case 'mansion_sofa':sofa(q);break;
            case 'vehicle':vehicle(q);break;
            case 'warehouse_rack':case 'parts_rack':case 'tool_wall':case 'towel_cabinet':case 'tool_cabinet':case 'delivery_rack':case 'wine_cabinet':rack(q);break;
            case 'crate_stack':case 'contraband':case 'cargo':case 'pallets':case 'pizza_boxes':crateStack(q);break;
            case 'oil_drums':case 'chemical_tank':barrelCluster(q);break;
            case 'gaming_table':gamingTable(q);break;
            case 'dining_table':diningTable(q);break;
            case 'slot_bank':slotBank(q);break;
            case 'fireplace':fireplace(q);break;
            case 'wash_arch':washArch(q);break;
            case 'wash_brush':{const brush=add(new THREE.CylinderGeometry(q.w*S*.48,q.w*S*.48,q.h*1.55,16),std(q.color,.96),q.c,q.h*.775,q.r);for(let i=0;i<12;i++){const a=i/12*Math.PI*2,bristle=add(new THREE.BoxGeometry(.06*S,q.h*1.35,.16*S),std(i%2?q.color:'#9aeef5',.98),q.c+Math.cos(a)*q.w*.48,q.h*.75,q.r+Math.sin(a)*q.d*.48);bristle.rotation.y=-a;}}break;
            case 'barber_station':barberStation(q);break;
            case 'pizza_oven':pizzaOven(q);break;
            case 'garage_lift':garageLift(q);break;
            case 'production_lift':factoryHoist(q);break;
            case 'bar_shelves':{rack(q);for(let row=0;row<3;row++)for(let i=-5;i<=5;i++)add(new THREE.CylinderGeometry(.07*S,.1*S,.52,8),std(['#5aa064','#a36c35','#94385d','#426f9a'][(i+row+12)%4],.35,.12),q.c+i*q.w*.075,.72+row*.62,q.r+q.d*.32);}break;
            case 'coffee_machine':{addBox(q,steel);const screen=add(new THREE.PlaneGeometry(q.w*S*.48,.6),basic('#8fe4f3'),q.c,1.25,q.r+q.d*.51);screen.castShadow=false;for(const c of [q.c-.28,q.c+.28]){add(new THREE.CylinderGeometry(.035,.05,.58,7),steel,c,.62,q.r+q.d*.58);add(new THREE.CylinderGeometry(.12*S,.14*S,.22,12),cream,c,.19,q.r+q.d*.68);}}break;
            case 'pastry_case':{addBox(q,wood);const pane=add(new THREE.BoxGeometry(q.w*S*.92,.72,q.d*S*.72),glass,q.c,1.45,q.r);pane.castShadow=false;for(let i=-2;i<=2;i++)add(new THREE.CylinderGeometry(.16*S,.16*S,.08,14),std('#d6a35a',.92),q.c+i*q.w*.16,1.18,q.r);}break;
            case 'bean_sacks':{for(let i=0;i<4;i++){const sack=add(new THREE.SphereGeometry(.32*S,12,8),std(q.color,.98),q.c+(i%2-.5)*q.w*.38,.48+Math.floor(i/2)*.55,q.r+(i%2-.5)*q.d*.35);sack.scale.set(1,.78,.72);}}break;
            case 'newspaper_rack':{addBox(q,wood);for(let i=0;i<5;i++){const paper=add(new THREE.PlaneGeometry(q.w*S*.72,.35*S),basic(i%2?'#d8d0ba':'#aeb8bc'),q.c,.55+i*.08,q.r+q.d*.52);paper.rotation.x=-1.05;paper.rotation.z=(i-2)*.04;paper.castShadow=false;}}break;
            case 'wash_sink':{addBox(q,cream);const bowl=add(new THREE.TorusGeometry(.42*S,.1*S,10,20),steel,q.c,1.38,q.r);bowl.rotation.x=Math.PI/2;}break;
            case 'fridge':{addBox(q,steel);add(new THREE.BoxGeometry(.05*S,.8,.08*S),brass,q.c+q.w*.35,1.65,q.r+q.d*.51);}break;
            case 'ingredients':{addBox(q,std(q.color,.8));for(let i=-2;i<=2;i++)add(new THREE.CylinderGeometry(.13*S,.15*S,.24,12),std(['#bd3d35','#63964c','#d7bd55'][i+2>=3?1:i+2],.88),q.c+i*q.w*.16,1.82,q.r);}break;
            case 'engine_stand':{addBox(q,steel);for(let i=-2;i<=2;i++)add(new THREE.CylinderGeometry(.14*S,.14*S,.55,12),dark,q.c+i*q.w*.15,1.25,q.r);}break;
            case 'tire_stack':{for(let i=0;i<4;i++){const tire=add(new THREE.TorusGeometry(.48*S,.15*S,10,22),rubber,q.c,.35+i*.36,q.r);tire.rotation.x=Math.PI/2;}}break;
            case 'welder':{addBox(q,std(q.color,.46,.55));const tank=add(new THREE.CylinderGeometry(.22*S,.22*S,1.35,14),std('#477765',.4,.45),q.c+q.w*.28,1.15,q.r);add(new THREE.SphereGeometry(.09,8,6),basic('#55d8ff'),q.c-q.w*.34,1.5,q.r+q.d*.48);}break;
            case 'beer_taps':{addBox(q,wood);for(let i=-2;i<=2;i++){add(new THREE.CylinderGeometry(.035,.05,.9,8),brass,q.c+i*q.w*.17,1.7,q.r);add(new THREE.SphereGeometry(.09,10,7),std(i%2?'#d34c75':'#d8a53c',.35,.2),q.c+i*q.w*.17,2.15,q.r);}}break;
            case 'stage':addBox(q,std(q.color,.8));break;
            case 'microphone':{add(new THREE.CylinderGeometry(.035,.05,q.h*1.45,8),steel,q.c,q.h*.72,q.r);add(new THREE.SphereGeometry(.12*S,10,8),black,q.c,q.h*1.47,q.r);}break;
            case 'pool_table':{
              add(new THREE.BoxGeometry(q.w*S*.96,.45,q.d*S*.92),wood,q.c,.84,q.r);
              add(new THREE.BoxGeometry(q.w*S*.84,.11,q.d*S*.76),felt,q.c,1.12,q.r);
              for(const dr of [-q.d*.43,q.d*.43])add(new THREE.BoxGeometry(q.w*S*.98,.18,.16*S),brass,q.c,1.22,q.r+dr);
              for(const dc of [-q.w*.46,q.w*.46])add(new THREE.BoxGeometry(.16*S,.18,q.d*S*.84),brass,q.c+dc,1.22,q.r);
              for(const dc of [-q.w*.42,0,q.w*.42])for(const dr of [-q.d*.38,q.d*.38]){const pocket=add(new THREE.TorusGeometry(.12*S,.035*S,7,14),black,q.c+dc,1.31,q.r+dr);pocket.rotation.x=Math.PI/2;}
              for(const dc of [-q.w*.35,q.w*.35])for(const dr of [-q.d*.3,q.d*.3])add(new THREE.CylinderGeometry(.1*S,.17*S,.78,10),wood,q.c+dc,.39,q.r+dr);
              for(let i=0;i<10;i++){const row=Math.floor((Math.sqrt(8*i+1)-1)/2),first=row*(row+1)/2,col=i-first;add(new THREE.SphereGeometry(.075*S,12,8),std(['#e5d04d','#b73b43','#eff1e8','#3c67b8'][i%4],.32,.08),q.c-q.w*.18+row*q.w*.055,1.36,q.r+(col-row/2)*q.d*.09);}
              add(new THREE.SphereGeometry(.078*S,12,8),cream,q.c+q.w*.28,1.36,q.r+.08);
              for(const dr of [-q.d*.62,q.d*.62]){const cue=add(new THREE.CylinderGeometry(.025*S,.045*S,q.w*S*.88,8),std('#d6a769',.42),q.c,1.38,q.r+dr);cue.rotation.z=Math.PI/2;}
            }break;
            case 'dryer':{
              const shell=std(q.color,.34,.64);addBox(q,shell);
              for(let nozzle=-2;nozzle<=2;nozzle++){const c=q.c+nozzle*q.w*.17,duct=add(new THREE.CylinderGeometry(.16*S,.24*S,.72,12),steel,c,1.55,q.r+q.d*.54);duct.rotation.x=Math.PI/2;const fan=add(new THREE.TorusGeometry(.18*S,.045*S,7,16),cyan,c,1.55,q.r+q.d*.72);fan.rotation.x=Math.PI/2;fan.castShadow=false;}
              add(new THREE.PlaneGeometry(q.w*S*.58,.34),basic('#6ae8ff'),q.c,2.36,q.r+q.d*.52).castShadow=false;
            }break;
            case 'pumps':{
              const cabinet=addBox(q,std(q.color,.38,.58));
              for(const c of [q.c-q.w*.27,q.c+q.w*.27]){const gauge=add(new THREE.CylinderGeometry(.2*S,.2*S,.09,18),cream,c,1.35,q.r+q.d*.54);gauge.rotation.x=Math.PI/2;const needle=add(new THREE.BoxGeometry(.025*S,.22,.02*S),red,c,1.42,q.r+q.d*.61);needle.rotation.z=c<q.c?-.45:.62;const hose=add(new THREE.TorusGeometry(.38*S,.055*S,8,20,Math.PI*1.55),rubber,c,.72,q.r+q.d*.58);hose.rotation.x=Math.PI/2;}
              add(new THREE.BoxGeometry(q.w*S*.72,.18,.2*S),brass,q.c,1.92,q.r).castShadow=false;
            }break;
            case 'vacuums':{
              for(const c of [q.c-q.w*.25,q.c+q.w*.25]){add(new THREE.CylinderGeometry(.34*S,.42*S,1.15,16),std(q.color,.42,.48),c,.58,q.r);add(new THREE.CylinderGeometry(.19*S,.28*S,.42,14),steel,c,1.36,q.r);const hose=add(new THREE.TorusGeometry(.47*S,.055*S,8,22,Math.PI*1.65),rubber,c,1.18,q.r+q.d*.22);hose.rotation.x=Math.PI/2;add(new THREE.CylinderGeometry(.045*S,.07*S,.78,8),steel,c+.42,1.74,q.r+q.d*.15).rotation.z=-.38;}
            }break;
            case 'wardrobe':{
              addBox(q,std(q.color,.84));for(let bay=-2;bay<=2;bay++){const c=q.c+bay*q.w*.18;add(new THREE.BoxGeometry(.05*S,q.h*1.42,.08*S),brass,c,q.h*.72,q.r+q.d*.49).castShadow=false;const hanger=add(new THREE.TorusGeometry(.25*S,.025*S,6,12,Math.PI),steel,c,q.h*1.16,q.r+q.d*.57);hanger.rotation.z=Math.PI;add(new THREE.CapsuleGeometry(.22*S,.58,6,10),std(['#4a315f','#712f4b','#294f62'][Math.abs(bay)%3],.9),c,q.h*.72,q.r+q.d*.55).scale.set(.82,1,.25);}
            }break;
            case 'coffee_table':{
              add(new THREE.BoxGeometry(q.w*S,.18,q.d*S),wood,q.c,.62,q.r);for(const dc of [-q.w*.38,q.w*.38])for(const dr of [-q.d*.32,q.d*.32])add(new THREE.CylinderGeometry(.07*S,.11*S,.55,9),brass,q.c+dc,.28,q.r+dr);
              for(let book=0;book<3;book++){const volume=add(new THREE.BoxGeometry(.62*S,.06,.42*S),std(['#713a3c','#315b6d','#9c7a42'][book],.88),q.c+(book-1)*.42,.76+book*.055,q.r-.18);volume.rotation.y=(book-1)*.09;}
              const decanter=add(new THREE.CylinderGeometry(.12*S,.22*S,.54,12),glass,q.c+.62,.98,q.r+.18);add(new THREE.SphereGeometry(.09*S,10,7),brass,q.c+.62,1.3,q.r+.18).castShadow=false;
            }break;
            case 'casino_room_wall':casinoRoomWall(q);break;
            case 'casino_stairs':casinoStairs(q);break;
            case 'dj_stage':{addBox(q,std(q.color,.65));for(let i=-3;i<=3;i++)add(new THREE.BoxGeometry(.35*S,.55,.24*S),std(i%2?'#ef4dff':'#58e6ff',.25,.2,i%2?'#ef4dff':'#58e6ff',1),q.c+i*q.w*.1,1.45,q.r+q.d*.42);for(const c of [q.c-q.w*.32,q.c+q.w*.32]){const disc=add(new THREE.CylinderGeometry(.32*S,.32*S,.12,20),black,c,1.65,q.r);disc.rotation.x=Math.PI/2;}}break;
            case 'laser_rig':{for(let i=-2;i<=2;i++){const beam=add(new THREE.CylinderGeometry(.025,.055,8,7),basic(i%2?'#ff46df':'#42dcff',true,.48),q.c+i*.32,4.2,q.r);beam.rotation.z=(i-1)*.14;beam.castShadow=false;}}break;
            case 'forklift':{addBox(q,std(q.color,.48,.4));for(const c of [q.c-q.w*.3,q.c+q.w*.3]){const wheel=add(new THREE.CylinderGeometry(.27*S,.27*S,.2*S,14),rubber,c,.35,q.r+q.d*.4);wheel.rotation.z=Math.PI/2;}for(const c of [q.c+q.w*.28,q.c+q.w*.4])add(new THREE.BoxGeometry(.1*S,2.1,.12*S),steel,c,1.15,q.r-q.d*.28);for(const c of [q.c+q.w*.28,q.c+q.w*.4])add(new THREE.BoxGeometry(.12*S,.12,.9*S),steel,c,.18,q.r-q.d*.55);}break;
            case 'container':{addBox(q,std(q.color,.62,.38));for(let i=-3;i<=3;i++)add(new THREE.BoxGeometry(.045*S,q.h*1.42,q.d*S*1.02),dark,q.c+i*q.w*.12,q.h*.75,q.r).castShadow=false;}break;
            case 'port_dispatch_floor':case 'port_work_floor':case 'port_sort_floor':case 'port_loading_floor':portFloor(q);break;
            case 'port_dispatch_booth':portDispatchBooth(q);break;
            case 'port_dispatch_desk':portConsole(q);break;
            case 'port_dispatch_chair':chair(q.r,q.c,q.color||'#26323a',Math.PI);break;
            case 'port_container':portContainer(q);break;
            case 'port_crane':portCrane(q,false);break;
            case 'port_worker_station':portWorkerStation(q);break;
            case 'port_forklift':portForklift(q);break;
            case 'port_cargo_pallet':portCargoPallet(q);break;
            case 'port_cargo_barrels':portBarrels(q);break;
            case 'port_cargo_sacks':portSacks(q);break;
            case 'port_cargo_net':portCargoNet(q);break;
            case 'port_pallet_jack':portPalletJack(q);break;
            case 'port_loading_ramp':portLoadingRamp(q);break;
            case 'port_dock_leveller':portLeveller(q);break;
            case 'port_dock_bumper':portBumper(q);break;
            case 'port_rope_coil':portRope(q);break;
            case 'port_mooring_bollard':portBollard(q);break;
            case 'major_port_container_floor':case 'major_port_vehicle_lane':case 'major_port_safe_floor':case 'major_port_customs_floor':case 'major_port_storage_floor':case 'major_port_dispatch_floor':case 'major_port_staff_floor':case 'major_port_security_floor':portFloor(q);break;
            case 'major_port_container_stack':portContainer(q);break;
            case 'major_port_gantry_crane':portCrane(q,true);break;
            case 'major_port_crane_leg':portCraneLeg(q);break;
            case 'major_port_forklift':portForklift(q);break;
            case 'major_port_cargo_cart':portCargoCart(q);break;
            case 'major_port_pallet_jack':portPalletJack(q);break;
            case 'major_port_cash_desk':portCashDesk(q);break;
            case 'major_port_safe_cage':portSafeCage(q);break;
            case 'major_port_cage_wall':portWireWall(q);break;
            case 'major_port_cash_lockers':portCashLockers(q);break;
            case 'major_port_inspection_gate':portInspectionGate(q);break;
            case 'major_port_customs_table':portCustomsTable(q);break;
            case 'major_port_xray':portXray(q);break;
            case 'major_port_security_post':portSecurityPost(q);break;
            case 'major_port_pallet_stack':portPalletStack(q);break;
            case 'major_port_crate_stack':portCrateStack(q);break;
            case 'major_port_barrel_cluster':portBarrels(q);break;
            case 'major_port_sack_stack':portSacks(q);break;
            case 'major_port_dispatch_office':portOffice(q);break;
            case 'major_port_office_wall':factoryRoomWall(q);break;
            case 'major_port_dispatch_console':portConsole(q);break;
            case 'major_port_map_table':portMapTable(q);break;
            case 'major_port_repair_bench':factoryWorkbench(q);break;
            case 'major_port_tool_cabinet':factoryPartsRack(q);break;
            case 'major_port_welder':factoryWelder(q);break;
            case 'major_port_locker_bank':factoryLockerBank(q);break;
            case 'major_port_docker_bench':factoryStaffBench(q);break;
            case 'market_stall':marketStall(q);break;
            case 'market_store':marketStore(q);break;
            case 'market_scale':marketScale(q);break;
            case 'factory_control_floor':case 'factory_staff_floor':case 'factory_workshop_floor':case 'factory_loading_floor':floorZone(q,std(q.color,.82,.08));break;
            case 'factory_control_booth':factoryControlBooth(q);break;
            case 'factory_electrical_panel':factoryElectricalPanel(q);break;
            case 'factory_room_wall':factoryRoomWall(q);break;
            case 'factory_locker_bank':factoryLockerBank(q);break;
            case 'factory_staff_bench':factoryStaffBench(q);break;
            case 'factory_break_table':factoryBreakTable(q);break;
            case 'factory_workbench':factoryWorkbench(q);break;
            case 'factory_parts_rack':factoryPartsRack(q);break;
            case 'factory_welder':factoryWelder(q);break;
            case 'factory_loading_bay':factoryLoadingBay(q);break;
            case 'factory_pallet_jack':factoryPalletJack(q);break;
            case 'factory_cargo_pallet':factoryCargoPallet(q);break;
            case 'conveyor':factoryConveyor(q);break;
            case 'industrial_press':factoryPress(q);break;
            case 'factory_store':factoryStore(q);break;
            case 'mansion_column':{const shaft=add(new THREE.CylinderGeometry(.31*S,.38*S,q.h*1.55,18),std('#d8ccb2',.5,.12),q.c,q.h*.775,q.r);add(new THREE.CylinderGeometry(.48*S,.48*S,.24,18),brass,q.c,.12,q.r);add(new THREE.CylinderGeometry(.48*S,.48*S,.24,18),brass,q.c,q.h*1.55,q.r);}break;
            case 'mansion_stairs':mansionStairs(q);break;
            case 'portrait':{const art=add(new THREE.PlaneGeometry(q.w*S,q.h*1.55),basic(q.color),q.c,3.05,q.r+.1);art.castShadow=false;for(const [dc,dy,w,h] of [[0,-2.48,q.w*S+.35,.16],[0,2.48,q.w*S+.35,.16],[-q.w*S/2,0,.16,q.h*1.55],[q.w*S/2,0,.16,q.h*1.55]])add(new THREE.BoxGeometry(w,h,.12),brass,q.c+dc/S,3.05+dy,q.r);}break;
            case 'bookshelf':bookshelf(q);break;
            case 'grand_piano':piano(q);break;
            case 'safe':{const safe=addBox(q,steel);outline(safe);const dial=add(new THREE.TorusGeometry(.38*S,.08*S,8,18),brass,q.c,1.85,q.r+q.d*.51);dial.rotation.x=Math.PI/2;}break;
            case 'statue':{add(new THREE.BoxGeometry(q.w*S,.55,q.d*S),brass,q.c,.28,q.r);add(new THREE.CylinderGeometry(.22*S,.3*S,1.35,16),std('#d9d2c2',.42,.05),q.c,1.25,q.r);add(new THREE.SphereGeometry(.3*S,16,10),std('#d9d2c2',.42,.05),q.c,2.18,q.r);}break;
            default:addBox(q);break;
          }
        }
        if(id.startsWith('major_'))for(const safe of layout.safes||[])factorySafe({...safe,c:+safe.c||0,r:+safe.r||0,opened:!!safe.opened});
        // Final authored layer: lighting, wall branding and service details.
        // These meshes deliberately have no gameplay collider; the matching
        // Canvas layout above remains the source for movement and encounters.
        const wallSign=(text,color=layout.accent||'#d7ae4c',c=W/2,r=.36,y=2.35,scale=.78)=>{const s=labelSprite(text,color);s.position.set(x(c),y,z(r));s.scale.multiplyScalar(scale);s.layers.set(1);interiorGroup.add(s);propCount++;return s;};
        const pendant=(c,r,color='#ffd087',height=4.35)=>{add(new THREE.CylinderGeometry(.025,.025,1.25,7),dark,c,height+.55,r).castShadow=false;const shade=add(new THREE.ConeGeometry(.34*S,.38,18,1,true),std(color,.34,.3,color,.2),c,height,r);shade.rotation.x=Math.PI;const bulb=add(new THREE.SphereGeometry(.1*S,10,7),basic(color),c,height-.18,r);bulb.castShadow=false;};
        const floorLine=(c,r,w,d,color='#e1aa2d')=>{const q=add(new THREE.PlaneGeometry(w*S,d*S),basic(color,true,.78),c,.095,r);q.rotation.x=-Math.PI/2;q.castShadow=false;return q;};
        switch(id){
          case 'coffee':
            wallSign('CAFFE DEL DON','#ffd08a',W/2,.34,2.42,.86);for(const [r,c] of [[6.2,3.2],[8.3,8.8],[6.4,14.2]])pendant(c,r,'#ffc46b',4.15);
            for(let i=0;i<6;i++){const mug=add(new THREE.CylinderGeometry(.11*S,.1*S,.22,12),cream,11.9+i*.43,1.93,4.5);const handle=add(new THREE.TorusGeometry(.07*S,.018*S,5,10,Math.PI*1.5),brass,12.05+i*.43,1.94,4.5);handle.rotation.y=Math.PI/2;}
            break;
          case 'carwash':
            wallSign('RICO CAR WASH','#86efff',W/2,.34,2.42,.84);for(const c of [5.9,8.8,11.7])floorLine(c,7.2,.16,7.8,'#19242b');
            for(const c of [2.1,W-2.1]){const pipe=add(new THREE.CylinderGeometry(.07*S,.07*S,7.8*S,9),steel,c,3.35,H/2);pipe.rotation.x=Math.PI/2;for(const r of [3,6.5,10])add(new THREE.TorusGeometry(.16*S,.035*S,7,14),cyan,c,3.35,r).rotation.x=Math.PI/2;}
            break;
          case 'barbershop':
            wallSign('ENZO BARBER','#f4eee0',W/2,.34,2.42,.84);for(const c of [3.5,9,14.5]){pendant(c,4.2,'#f8e5ba',4.15);for(const dc of [-.5,.5])add(new THREE.SphereGeometry(.075*S,9,6),basic(dc<0?'#ff5a62':'#5ca8ff'),c+dc,3.42,3.42).castShadow=false;}
            floorLine(W/2,10.8,W*.72,.16,'#d5cdbb');
            break;
          case 'pizza':
            wallSign('TONYS PIZZA','#ffd56b',W/2,.34,2.42,.87);for(const c of [3.3,9,14.3])pendant(c,8.1,'#ffb15b',4.05);
            for(let row=0;row<2;row++)for(let col=0;col<8;col++){const tile=floorLine(1.25+col*.72,3.1+row*.72,.68,.68,(row+col)%2?'#efe3c8':'#7d251f');tile.material.opacity=.42;}
            break;
          case 'garage':
            wallSign('ШИНОМОНТАЖ','#ffd24c',W/2,.34,2.42,.94);for(const c of [5.7,8.8,11.9])floorLine(c,7.1,.18,8.4,(Math.round(c*10)&1)?'#f1b92f':'#15191d');
            for(const c of [3.1,14.6]){const hose=add(new THREE.TorusGeometry(.68*S,.055*S,8,22,Math.PI*1.75),rubber,c,3.65,4.8);hose.rotation.x=Math.PI/2;add(new THREE.CylinderGeometry(.07*S,.11*S,1.1,9),metal,c+.62,2.8,4.8).rotation.z=.35;}
            break;
          case 'bar':
            wallSign('BLACK WIDOW','#ff58ad',W/2,.34,2.42,.9);for(const [r,c] of [[6.8,3.4],[9.5,8.8],[8,12]])pendant(c,r,'#ff9f55',3.95);
            for(let i=0;i<7;i++){const frame=add(new THREE.BoxGeometry(.18*S,.12,.08*S),i%2?pink:cyan,5.5+i*.65,2.9,.48);frame.castShadow=false;}
            break;
          case 'club':
            wallSign('SOTTO CLUB','#f56dff',W/2,.34,2.42,.9);for(const c of [5.8,8.8,11.8]){const ring=add(new THREE.TorusGeometry(.62*S,.055*S,8,22),c===8.8?pink:cyan,c,4.45,7);ring.rotation.x=Math.PI/2;ring.castShadow=false;}
            for(let c=5.2;c<=12.4;c+=1.2){const truss=add(new THREE.BoxGeometry(.08*S,.08,.08*S),metal,c,4.65,7);truss.scale.z=36;truss.castShadow=false;}
            break;
          case 'warehouse':
            wallSign('CARLO LOGISTICS','#ffc45b',W/2,.34,2.42,.86);for(const c of [5.7,11.8]){floorLine(c,H*.62,.16,H*.7,'#e6ad2b');for(const r of [3.2,7,10.4]){const lamp=add(new THREE.BoxGeometry(2.1*S,.12,.32*S),cream,c,4.25,r);lamp.castShadow=false;add(new THREE.PlaneGeometry(1.8*S,.22*S),basic('#e6f3ff'),c,4.17,r).rotation.x=Math.PI/2;}}
            break;
          case 'casino':
            wallSign('GOLDEN DICE','#ffe06c',W/2,.34,2.42,.92);floorLine(W/2,H*.58,2.6,H*.7,'#8f1634');
            {const crown=add(new THREE.TorusGeometry(1.2*S,.12*S,10,26),brass,W/2,4.1,H*.48);crown.rotation.x=Math.PI/2;for(let i=0;i<9;i++){const a=i/9*Math.PI*2,drop=add(new THREE.SphereGeometry(.08*S,9,6),i%2?pink:warm,W/2+Math.cos(a)*1.2,3.7,H*.48+Math.sin(a)*1.2);drop.castShadow=false;}}
            break;
          case 'major_market':{
            wallSign('MERCATO CENTRALE','#ffd36b',W/2,.34,2.55,1.18);
            // Brass aisle guides, pendant rows and suspended department signs organise the large hall.
            for(const c of [8,14,20,26])floorLine(c,12,.12,15.7,c%4?'#d5a33f':'#efe0b5');
            for(const c of [5,11,17,23,29])for(const r of [6,14])pendant(c,r,(c+Math.round(r))%2?'#ffd17a':'#fff0bd',4.55);
            const categories=[['FRUTTA',5,'#7fca63'],['PANE',11,'#ffbd68'],['PESCE',17,'#75d9ef'],['CARNE',23,'#ef7b75'],['FIORI',29,'#f58dcc']];
            for(const [textLabel,c,color] of categories){const sign=labelSprite(textLabel,color);sign.position.set(x(c),4.02,z(3.9));sign.scale.set(3.7,.9,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;add(new THREE.CylinderGeometry(.025,.025,.78,7),dark,c,4.48,3.9).castShadow=false;}
            // Checkout lane: moving belt, scanner glow, receipt printer and a stack of hand baskets.
            const checkoutC=W/2,checkoutR=3.25;
            add(new THREE.BoxGeometry(4.8*S,.62,1.2*S),std('#78522f',.75),checkoutC,.36,checkoutR);
            add(new THREE.BoxGeometry(2.7*S,.1,.82*S),rubber,checkoutC-.72,.73,checkoutR);
            for(let roller=-3;roller<=3;roller++){const beltRoller=add(new THREE.CylinderGeometry(.09*S,.09*S,.74*S,10),steel,checkoutC-.72+roller*.35,.78,checkoutR);beltRoller.rotation.x=Math.PI/2;}
            add(new THREE.BoxGeometry(.58*S,.34,.48*S),dark,checkoutC+1.58,.98,checkoutR);add(new THREE.PlaneGeometry(.36*S,.18),basic('#71f2cf'),checkoutC+1.58,1.07,checkoutR+.25).castShadow=false;
            for(let basketIndex=0;basketIndex<5;basketIndex++){const basket=add(new THREE.BoxGeometry(.7*S,.16,.55*S),std(basketIndex%2?'#c45437':'#377f63',.52,.18),2.2,.18+basketIndex*.14,3.25);for(const side of [-1,1]){const handle=add(new THREE.TorusGeometry(.23*S,.025*S,6,12,Math.PI),steel,2.2,.36+basketIndex*.14,3.25+side*.12);handle.rotation.y=Math.PI/2;}};
            // Two push carts near the entrance and a vintage wall clock complete the readable market furniture.
            for(const c of [W-4.5,W-2.6]){add(new THREE.BoxGeometry(1.35*S,.64,1*S),steel,c,.72,3.35);for(const dc of [-.48,.48])for(const dr of [-.34,.34]){const wheel=add(new THREE.CylinderGeometry(.09*S,.09*S,.12,9),rubber,c+dc,.18,3.35+dr);wheel.rotation.z=Math.PI/2;}add(new THREE.CylinderGeometry(.035,.035,1.2*S,7),steel,c- .63,1.25,3.35).rotation.x=Math.PI/2;}
            const clock=add(new THREE.CylinderGeometry(.62*S,.62*S,.12,28),cream,W-3.1,2.45,.45);clock.rotation.x=Math.PI/2;const clockRim=add(new THREE.TorusGeometry(.62*S,.055*S,8,28),brass,W-3.1,2.45,.37);clockRim.rotation.x=Math.PI/2;const hour=add(new THREE.BoxGeometry(.035*S,.32,.025),dark,W-3.1,2.58,.29);hour.rotation.z=-.55;const minute=add(new THREE.BoxGeometry(.035*S,.45,.025),dark,W-3.1,2.6,.28);minute.rotation.z=.82;
            renderer.domElement.dataset.marketInterior='six-departments-store-scale-checkout-v1';
          }break;
          case 'major_factory':{
            wallSign('PROMZONA  ·  SHOP 03','#ffad48',W/2,.34,2.55,1.16);
            // Marked pedestrian spine and machine clearances keep the huge hall readable.
            floorLine(12,12,.16,20,'#f1b02d');floorLine(17,20,2.2,.16,'#f1b02d');
            for(const r of [6,11,16]){for(const c of [12.7,23.3])floorLine(c,r,.14,2.75,'#ece5d0');for(const side of [-1,1])floorLine(29+side*3.05,9,.13,5.9,side<0?'#15191d':'#eab02f');}
            for(const [line,r] of [[1,6],[2,11],[3,16]]){const sign=labelSprite(`LINE 0${line}`,'#ffc85b');sign.position.set(x(18),4.45,z(r));sign.scale.set(3.4,.84,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;for(const c of [7,18])pendant(c,r,'#e9f3f2',4.72);}
            // Bridge crane spans the machine and assembly areas with trolley, chain and hook.
            for(const c of [3,23])add(new THREE.BoxGeometry(.28*S,.42,17*S),std('#434f57',.34,.7),c,5.45,11.5);
            const bridgeBeam=add(new THREE.BoxGeometry(20*S,.4,.55*S),std('#dc842f',.44,.46),13,5.58,11.5);for(const c of [4,22])add(new THREE.BoxGeometry(.55*S,.15,.9*S),steel,c,5.3,11.5);
            add(new THREE.BoxGeometry(1.15*S,.62,.82*S),dark,14.5,5.15,11.5);add(new THREE.CylinderGeometry(.04,.04,2.35,7),steel,14.5,3.75,11.5);const craneHook=add(new THREE.TorusGeometry(.22*S,.06*S,7,16,Math.PI*1.4),std('#f0b12e',.42,.44),14.5,2.55,11.5);craneHook.rotation.z=.3;
            // Ventilation trunks, cable trays and hard industrial ceiling lights.
            for(const c of [12.6,23.8]){const duct=add(new THREE.CylinderGeometry(.28*S,.28*S,19*S,12),std('#66747c',.32,.7),c,5.1,11.6);duct.rotation.x=Math.PI/2;for(const r of [3,8,13,18]){const collar=add(new THREE.TorusGeometry(.29*S,.035*S,7,16),std('#d38a2f',.48,.36),c,5.1,r);collar.rotation.x=Math.PI/2;}}
            for(const [c,r] of [[4,4],[10,4],[16,4],[22,4],[28,4],[4,17],[10,17],[16,17],[22,17],[28,17]]){add(new THREE.BoxGeometry(2.1*S,.14,.42*S),steel,c,5.25,r).castShadow=false;add(new THREE.PlaneGeometry(1.8*S,.3*S),basic('#e9f5ff'),c,5.16,r).rotation.x=Math.PI/2;}
            // Signed rooms, emergency equipment and direction arrows finish the authored layer.
            for(const [textLabel,c,r,color] of [['CONTROL',17,1.55,'#71d8ed'],['STAFF',6,18.35,'#d9d2b5'],['WORKSHOP',21,18.35,'#ffc15a'],['SECURE STORE',28,16.25,'#ff9b4d']]){const s=labelSprite(textLabel,color);s.position.set(x(c),3.58,z(r));s.scale.set(4.4,.95,1);s.layers.set(1);interiorGroup.add(s);propCount++;}
            for(const [c,r] of [[1.2,17.8],[24.1,18.1],[32.6,13]]){add(new THREE.CylinderGeometry(.16*S,.18*S,.88,12),std('#c93635',.48,.3),c,.54,r);add(new THREE.BoxGeometry(.3*S,.16,.12*S),dark,c,.98,r);add(new THREE.TorusGeometry(.25*S,.035*S,7,14,Math.PI*1.45),rubber,c,1.42,r).rotation.z=.55;}
            for(const r of [5.2,10.2,15.2]){const arrow=add(new THREE.ConeGeometry(.35*S,.92*S,3),basic('#f3bb34',true,.82),12,.12,r);arrow.rotation.x=-Math.PI/2;arrow.rotation.z=Math.PI;}
            renderer.domElement.dataset.factoryInterior='control-machine-lines-press-staff-workshop-loading-v1';
          }break;
          case 'port':{
            wallSign('RIZZO DOCKS','#9deaff',W/2,.34,2.48,.92);
            for(const c of [4,10,W/2,W-10,W-4])floorLine(c,H*.6,.12,H*.75,c===W/2?'#eef0df':'#e3aa2f');
            for(const [textLabel,c,r,color] of [['DISPATCH',W/2,3.65,'#9deaff'],['CONTAINER YARD',4.2,10.7,'#ffc36a'],['CARGO SORT',6,19.1,'#d9e9df'],['LOADING DOCK',W-6,19.1,'#ffb34e']]){const sign=labelSprite(textLabel,color);sign.position.set(x(c),3.62,z(r));sign.scale.set(4.2,.9,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;}
            for(const c of [4.2,W/2,W-4.2])for(const r of [5.2,11.2,17.2])pendant(c,r,c===W/2?'#ffd06b':'#d9eff6',4.7);
            for(const r of [8.2,10.5]){add(new THREE.BoxGeometry(12.4*S,.16,.18*S),portGrey,W/2,5.35,r);for(let brace=-4;brace<=4;brace++)add(new THREE.BoxGeometry(.05*S,.5,.08*S),brace%2?portYellow:steel,W/2+brace*1.25,5.12,r).castShadow=false;}
            for(const [c,r] of [[1.2,18.2],[W-1.2,18.2]]){const life=add(new THREE.TorusGeometry(.38*S,.12*S,10,22),portOrange,c,1.55,r);life.rotation.x=Math.PI/2;add(new THREE.BoxGeometry(.5*S,.1,.04*S),cream,c,1.55,r+.16).castShadow=false;}
            renderer.domElement.dataset.portInterior='dispatch-containers-gantry-sort-loading-marine-v2';
          }break;
          case 'major_port':{
            wallSign('RIZZO CARGO TERMINAL','#9deaff',W/2,.34,2.6,1.14);
            for(const c of [4.2,7.1,10.5])floorLine(c,11,.1,15.5,'#e3aa2f');
            floorLine(17,13,.15,18,'#f1c34d');for(const r of [5.4,10.2,15,19.4])floorLine(17,r,4.5,.06,'#e8ece6');
            for(const [textLabel,c,r,color] of [['CONTAINER YARD',7.1,2.6,'#ffc15a'],['SAFE CAGE',28,2.7,'#ffd36b'],['CUSTOMS',28,10.2,'#7ee6f4'],['CARGO STORE',27.2,14.1,'#e6c68f'],['DISPATCH',29,17.1,'#9deaff'],['SECURITY',22.7,18.9,'#ffb15a'],['DOCKERS PPE',7.4,18.3,'#e4eef0'],['REPAIR',4.3,18.2,'#ffc05a']]){const sign=labelSprite(textLabel,color);sign.position.set(x(c),3.72,z(r));sign.scale.set(4.5,.94,1);sign.layers.set(1);interiorGroup.add(sign);propCount++;}
            for(const c of [4.2,10.5,17,23,29.5])for(const r of [5.2,11.2,17.4])pendant(c,r,(Math.round(c+r)&1)?'#d9eff6':'#ffd17a',4.85);
            for(const r of [7.35,9.65]){add(new THREE.BoxGeometry(11*S,.2,.22*S),portGrey,17,6.2,r);for(let brace=-4;brace<=4;brace++){const hanger=add(new THREE.BoxGeometry(.06*S,.62,.08*S),brace%2?portYellow:steel,17+brace*1.12,5.82,r);hanger.rotation.z=brace%2?.12:-.12;}}
            for(const r of [6.3,12.2,18.1]){const arrow=add(new THREE.ConeGeometry(.32*S,.85*S,3),basic('#f4c64d',true,.8),17,.11,r);arrow.rotation.x=-Math.PI/2;arrow.rotation.z=Math.PI;}
            for(const [c,r] of [[1.2,20.6],[32.7,20.6],[23.7,12.2]]){add(new THREE.CylinderGeometry(.16*S,.18*S,.9,12),portRed,c,.46,r);add(new THREE.BoxGeometry(.28*S,.14,.12*S),dark,c,.94,r);const hose=add(new THREE.TorusGeometry(.24*S,.035*S,7,14,Math.PI*1.45),rubber,c,1.36,r);hose.rotation.z=.55;}
            renderer.domElement.dataset.portInterior='major-terminal-eight-zones-gantry-customs-cage-dispatch-v2';
          }break;
        }
        const accentColor=new THREE.Color(layout.accent||'#d7ae4c'),mood=/club|casino/.test(id)?12:/carwash|garage|factory|port/.test(id)?6:8;
        const moodLight=new THREE.PointLight(accentColor,mood,Math.max(22,Math.min(48,W*S*.65)),2);moodLight.position.set(x(W*.72),5.2,z(H*.34));moodLight.layers.set(1);interiorGroup.add(moodLight);
        if(/coffee|pizza|bar|mansion/.test(id)){const warm=new THREE.PointLight(0xffb86b,8,24,2);warm.position.set(x(W*.28),5.5,z(H*.68));warm.layers.set(1);interiorGroup.add(warm);}
        renderer.domElement.dataset.businessInterior=`${id}:layout-v${layout.version||0}`;
        renderer.domElement.dataset.businessInteriorProps=String(propCount);
        renderer.domElement.dataset.businessInteriorSource='canvas-authored-layout-v7-volumetric-port-complete';
        return true;
      };

      const decorateServiceInterior=data=>{
        const type=String(data.type||'');if(!['hospital','police_st'].includes(type))return false;
        const W=+data.width||12,H=+data.height||9,S=WORLD_SCALE,x=c=>(c-originC)*S,z=r=>(r-originR)*S;
        for(const [i,o] of [...interiorGroup.children].entries()){if(o.type!=='GridHelper'&&!(i>7&&o.type!=='RectAreaLight'))continue;interiorGroup.remove(o);disposeTransientObjectTree(o);}
        const std=(color,roughness=.72,metalness=.06)=>new THREE.MeshStandardMaterial({color,roughness,metalness}),basic=color=>new THREE.MeshBasicMaterial({color,toneMapped:false}),steel=std(0x65717a,.35,.7),steelDark=std(0x2b343c,.48,.58),wood=std(0x654126,.78),black=std(0x11151b,.48,.35),cream=std(0xe8e4d8,.82),blue=std(0x315f78,.72),red=std(0xa52f37,.64),brass=std(0xb88d3d,.3,.72),glass=new THREE.MeshPhysicalMaterial({color:0x8ed0df,transparent:true,opacity:.28,roughness:.07,transmission:.34,side:THREE.DoubleSide});
        const add=(geo,mat,c,y,r)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x(c),y,z(r));m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;};
        const sign=(text,color)=>{const s=labelSprite(text,color);s.position.set(x(W/2),4.1,z(.38));s.scale.set(5.2,1.12,1);s.layers.set(1);interiorGroup.add(s);};
        const desk=(c,r,w=2.4)=>{add(new THREE.BoxGeometry(w*S,.2,1.05*S),wood,c,1,r);for(const dc of [-w*.42,w*.42])add(new THREE.BoxGeometry(.16*S,.95,.16*S),black,c+dc,.48,r);};
        const monitor=(c,r,color='#65d8ef')=>{add(new THREE.BoxGeometry(.75*S,.58,.12*S),black,c,1.82,r);add(new THREE.PlaneGeometry(.62*S,.44),basic(color),c,1.84,r+.08).castShadow=false;add(new THREE.CylinderGeometry(.035*S,.055*S,.38,7),steel,c,1.35,r);};
        const chair=(c,r,angle=0)=>{const seat=add(new THREE.BoxGeometry(.72*S,.18,.68*S),blue,c,.72,r);seat.rotation.y=angle;const back=add(new THREE.BoxGeometry(.72*S,.82,.15*S),blue,c,1.15,r-.32);back.rotation.y=angle;add(new THREE.CylinderGeometry(.05*S,.07*S,.52,8),steel,c,.38,r);};
        const cabinet=(c,r)=>{add(new THREE.BoxGeometry(1.05*S,2.75,.72*S),steelDark,c,1.38,r);for(let row=0;row<4;row++){add(new THREE.BoxGeometry(.86*S,.5,.08*S),steel,c,.45+row*.61,r+.4).castShadow=false;add(new THREE.BoxGeometry(.2*S,.03,.03*S),brass,c,.45+row*.61,r+.46).castShadow=false;}};
        if(type==='hospital'){
          sign('CITY HOSPITAL','#8ee8df');const bed=(c,r)=>{add(new THREE.BoxGeometry(2.15*S,.26,1*S),steel,c,.5,r);add(new THREE.BoxGeometry(1.98*S,.3,.88*S),cream,c,.76,r);add(new THREE.BoxGeometry(.5*S,.18,.72*S),basic('#ffffff'),c-.68,.98,r).castShadow=false;add(new THREE.CylinderGeometry(.025*S,.035*S,2.6,7),steel,c+1.15,1.45,r);add(new THREE.BoxGeometry(.4*S,.55,.07*S),glass,c+1.15,2.32,r).castShadow=false;for(const dc of [-.85,.85])for(const dr of [-.35,.35]){const wheel=add(new THREE.CylinderGeometry(.08*S,.08*S,.1*S,8),black,c+dc,.18,r+dr);wheel.rotation.z=Math.PI/2;}};
          for(const [c,r] of [[2.3,3],[5.4,3],[2.3,6],[5.4,6]])bed(c,r);desk(W-2.35,H-2.05,3.1);monitor(W-2.35,H-2.45,'#69e89a');chair(W-2.35,H-1,Math.PI);cabinet(W-1.1,2);add(new THREE.BoxGeometry(1.2*S,1.25,.82*S),steelDark,W-1.55,.68,H*.5);add(new THREE.PlaneGeometry(.82*S,.52),basic('#62e89a'),W-1.55,1.13,H*.5+.43).castShadow=false;
          for(const r of [4.45,7.2]){const curtain=add(new THREE.PlaneGeometry(2.9*S,2.35),glass,4,1.8,r);curtain.rotation.y=Math.PI/2;curtain.castShadow=false;}
        }else{
          sign('POLICE DEPARTMENT','#75cfff');desk(W/2,2.15,4.7);for(const c of [W/2-1.35,W/2,W/2+1.35])monitor(c,1.7,c===W/2?'#75e6aa':'#6dd4ff');for(const c of [W/2-1.3,W/2+1.3])chair(c,3.2,Math.PI);
          const cellC=W*.7;for(let cell=0;cell<2;cell++){const cc=cellC+(cell-.5)*3;for(let bar=-3;bar<=3;bar++)add(new THREE.CylinderGeometry(.025*S,.025*S,3,6),steel,cc+bar*.35,1.5,4.35);for(const side of [-1,1])add(new THREE.CylinderGeometry(.045*S,.045*S,3.1,7),steel,cc+side*1.25,1.55,5.2);add(new THREE.BoxGeometry(2.3*S,.28,.72*S),steelDark,cc,.32,6.15);}cabinet(1.1,3.2);cabinet(1.1,6.2);
          add(new THREE.BoxGeometry(5*S,2.55,.3*S),wood,W*.32,1.28,H-1.1);for(let gun=0;gun<4;gun++){const weapon=add(new THREE.BoxGeometry(1.55*S,.11,.11*S),black,W*.32+(gun-1.5)*1.05,.82+gun%2*.72,H-.88);weapon.rotation.z=gun%2?.08:-.08;add(new THREE.BoxGeometry(.35*S,.48,.13*S),wood,W*.32+(gun-1.5)*1.05+.4,.62+gun%2*.72,H-.87);}
          desk(W*.72,H-1.75,3.8);for(const c of [W*.72-.85,W*.72+.85])monitor(c,H-2.15,'#6ad9ec');
        }
        renderer.domElement.dataset.serviceInterior=`${type}:authored-volumetric-v1`;return true;
      };

      const decorateVenueInterior=data=>{
        const type=String(data.type||'');if(!['gym','job','blackmarket'].includes(type))return false;
        const W=+data.width||12,H=+data.height||9,S=WORLD_SCALE,x=c=>(c-originC)*S,z=r=>(r-originR)*S;
        for(const [i,o] of [...interiorGroup.children].entries()){if(o.type!=='GridHelper'&&!(i>7&&o.type!=='RectAreaLight'))continue;interiorGroup.remove(o);disposeTransientObjectTree(o);}
        const std=(color,rough=.7,metal=.08)=>new THREE.MeshStandardMaterial({color,roughness:rough,metalness:metal}),basic=color=>new THREE.MeshBasicMaterial({color,toneMapped:false}),steel=std(0x626e76,.34,.76),dark=std(0x171c22,.52,.42),wood=std(0x684329,.82),cream=std(0xd9d3c3,.86),red=std(0x8f2d38,.72),blue=std(0x2e5870,.72),green=std(0x285d42,.82),gold=std(0xb88a35,.34,.7),glass=new THREE.MeshPhysicalMaterial({color:0x8ccbd9,transparent:true,opacity:.3,roughness:.08,transmission:.32,side:THREE.DoubleSide});
        const add=(geo,mat,c,y,r)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x(c),y,z(r));m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;};
        const label=(text,color,c=W/2,r=.38,y=4.15)=>{const s=labelSprite(text,color);s.position.set(x(c),y,z(r));s.scale.set(Math.max(4.6,Math.min(7.8,text.length*.44)),1.2,1);s.layers.set(1);interiorGroup.add(s);};
        const desk=(c,r,w=2.5,mat=wood)=>{add(new THREE.BoxGeometry(w*S,.22,1.05*S),mat,c,1,r);for(const dc of [-w*.42,w*.42])add(new THREE.BoxGeometry(.16*S,.95,.16*S),dark,c+dc,.48,r);};
        const monitor=(c,r,color='#64d8ef')=>{add(new THREE.BoxGeometry(.78*S,.6,.12*S),dark,c,1.83,r);add(new THREE.PlaneGeometry(.65*S,.47),basic(color),c,1.85,r+.08).castShadow=false;add(new THREE.CylinderGeometry(.035*S,.055*S,.38,7),steel,c,1.36,r);};
        const chair=(c,r,mat=blue)=>{add(new THREE.BoxGeometry(.72*S,.18,.68*S),mat,c,.72,r);add(new THREE.BoxGeometry(.72*S,.82,.15*S),mat,c,1.14,r-.32);add(new THREE.CylinderGeometry(.05*S,.07*S,.52,8),steel,c,.38,r);};
        if(type==='gym'){
          label('IRON FIST GYM','#72c7ff');
          for(const [c,r] of [[3,3],[8,3]]){for(const dc of [-1.35,1.35])add(new THREE.BoxGeometry(.14*S,3.3,.14*S),steel,c+dc,1.65,r);add(new THREE.BoxGeometry(2.9*S,.12,.12*S),steel,c,2.75,r);const bar=add(new THREE.CylinderGeometry(.07*S,.07*S,3.2*S,10),steel,c,1.45,r);bar.rotation.z=Math.PI/2;for(const dc of [-1.35,-1.12,1.12,1.35]){const plate=add(new THREE.CylinderGeometry(.34*S,.34*S,.13*S,16),dc<0?red:blue,c+dc,1.45,r);plate.rotation.z=Math.PI/2;}add(new THREE.BoxGeometry(2.5*S,.28,.72*S),dark,c,.58,r+.9);}
          for(const c of [2.2,5.2,8.2,11.2]){add(new THREE.CylinderGeometry(.48*S,.36*S,2.5,18),c%2>1?red:blue,c,2.35,H-1.35);add(new THREE.CylinderGeometry(.04*S,.04*S,2.4,7),steel,c,5.05,H-1.35);}
          for(const [c,r] of [[W-2.3,3.1],[W-2.3,6.3]]){add(new THREE.BoxGeometry(2.3*S,.42,1.05*S),dark,c,.42,r);for(const dc of [-.92,.92])add(new THREE.CylinderGeometry(.34*S,.34*S,.32*S,14),steel,c+dc,.25,r).rotation.z=Math.PI/2;add(new THREE.BoxGeometry(1.6*S,1.45,.12*S),basic('#4b9fbd'),c,1.35,r-.48).castShadow=false;}
          desk(W/2,H-2,3.8);monitor(W/2,H-2.42,'#73e0a2');for(let i=0;i<6;i++)add(new THREE.BoxGeometry(.85*S,2.3,.7*S),i%2?steel:dark,1.05+i*.9,1.15,1.15);
        }else if(type==='job'){
          label('ГОРОДСКАЯ БИРЖА ТРУДА','#f3d46f');
          for(const c of [2.4,6,9.6]){desk(c,3,2.7,cream);monitor(c,2.58,c===6?'#78e19e':'#69cce3');chair(c,4.15,blue);const pane=add(new THREE.PlaneGeometry(2.45*S,1.65),glass,c,2.65,2.35);pane.castShadow=false;}
          for(const c of [2.1,4.25,6.4,8.55,10.7])chair(c,H-2.05,c%4>2?red:blue);
          for(const c of [3.1,6,8.9]){add(new THREE.CylinderGeometry(.07*S,.1*S,1.2,9),gold,c,.6,5.4);add(new THREE.SphereGeometry(.11*S,9,6),gold,c,1.22,5.4);if(c<8.8)add(new THREE.BoxGeometry(2.9*S,.07,.07*S),red,c+1.45,.88,5.4).castShadow=false;}
          add(new THREE.BoxGeometry(5.4*S,2.8,.28*S),wood,W-3.25,1.4,1.1);for(let row=0;row<3;row++)for(let col=0;col<4;col++)add(new THREE.PlaneGeometry(.82*S,.55),basic(['#d9c37b','#83aec1','#b57d70'][(row+col)%3]),W-5+col*1.15,.72+row*.78,1.27).castShadow=false;
          const clock=add(new THREE.CylinderGeometry(.72*S,.72*S,.14,24),cream,W/2,3.45,.72);clock.rotation.x=Math.PI/2;for(const angle of [-.55,1.2]){const hand=add(new THREE.BoxGeometry(.035*S,.62,.035*S),dark,W/2,3.45,.81);hand.rotation.z=angle;}
        }else{
          const family=String(data.venueFamily||''),accent=family==='bellini'?red:family==='moretti'?cream:new THREE.MeshStandardMaterial({color:0x51438f,roughness:.55}),accentGlow=family==='bellini'?'#e34d59':family==='moretti'?'#f2e9d2':'#8d72ff';
          label(family==='bellini'?'MERCATO BELLINI':family==='moretti'?'MERCATO MORETTI':'ЧЁРНЫЙ РЫНОК',accentGlow);
          for(const [c,r] of [[2.1,3],[5,3],[7.9,3]]){const counter=add(new THREE.BoxGeometry(2.3*S,1.05,1.25*S),wood,c,.53,r);add(new THREE.BoxGeometry(2.12*S,.12,1.1*S),glass,c,1.15,r);for(let item=0;item<5;item++){const prop=add(item%2?new THREE.CylinderGeometry(.08*S,.11*S,.48,8):new THREE.BoxGeometry(.35*S,.16,.22*S),item%3?steel:gold,c+(item-2)*.36,1.38,r);prop.rotation.z=item%2?.22:0;}}
          add(new THREE.BoxGeometry(5.2*S,3.1,.3*S),dark,W-3.2,1.55,H-1.05);for(let gun=0;gun<5;gun++){const wc=W-5+(gun%3)*1.55,weapon=add(new THREE.BoxGeometry(1.8*S,.12,.12*S),gun%2?steel:dark,wc,.72+Math.floor(gun/3)*1.05,H-.87);weapon.rotation.z=gun%2?.1:-.1;add(new THREE.BoxGeometry(.38*S,.52,.14*S),wood,wc+.42,.54+Math.floor(gun/3)*1.05,H-.86);}
          for(const [c,r] of [[1.4,H-2],[4,H-2],[6.6,H-2]]){add(new THREE.BoxGeometry(2.05*S,.2,1.25*S),wood,c,.2,r);for(let crate=0;crate<4;crate++)add(new THREE.BoxGeometry(.68*S,.62,.58*S),crate%2?green:accent,c+(crate%2-.5)*.72,.52+Math.floor(crate/2)*.58,r+(crate%2-.5)*.48);}
          desk(W-1.6,4.8,2.2,dark);monitor(W-1.6,4.38,accentGlow);for(const c of [2.5,5.2,7.9]){add(new THREE.CylinderGeometry(.04*S,.04*S,2.8,7),steel,c,4.85,5.4);const lamp=add(new THREE.ConeGeometry(.44*S,.62,14,1,true),accent,c,3.35,5.4);lamp.rotation.x=Math.PI;}
          for(let bar=0;bar<8;bar++)add(new THREE.CylinderGeometry(.025*S,.025*S,3.2,6),steel,W-.45,1.6,1.2+bar*(H-2.4)/7);
        }
        renderer.domElement.dataset.venueInterior=`${type}:${data.venueId||'default'}:authored-volumetric-v1`;return true;
      };

      const help=document.createElement('div');help.textContent='3D: W / ↑ — вперёд · S / ↓ — назад · A/D — шаг вбок · E — действия · удерживать E — машина · ПКМ — прицел · ЛКМ — огонь / бросок / установка C4';
      help.style.cssText='position:absolute;left:50%;top:82px;transform:translate(-50%,-8px);z-index:20;padding:7px 12px;border:1px solid #d5ab45;border-radius:9px;background:rgba(8,13,22,.9);color:#ffe7a3;font:700 12px system-ui;pointer-events:none;white-space:nowrap;opacity:0;transition:opacity .35s ease,transform .35s ease';stage.appendChild(help);
      const helpSessionKey='mafiozi-3d-controls-v217';let showControlsHelp=true;try{showControlsHelp=sessionStorage.getItem(helpSessionKey)!=='shown';if(showControlsHelp)sessionStorage.setItem(helpSessionKey,'shown');}catch(_){showControlsHelp=true;}
      if(showControlsHelp){requestAnimationFrame(()=>{help.style.opacity='1';help.style.transform='translate(-50%,0)';});renderer.domElement.dataset.controlsTutorial='visible:first-entry';setTimeout(()=>{help.style.opacity='0';help.style.transform='translate(-50%,-8px)';renderer.domElement.dataset.controlsTutorial='hidden:after-3000ms';setTimeout(()=>help.remove(),380);},3000);}else{help.remove();renderer.domElement.dataset.controlsTutorial='hidden:already-shown';}
      const buildingPromptStyle=document.createElement('style');buildingPromptStyle.textContent='@keyframes mfzBuildingPromptIn{0%{opacity:0}100%{opacity:1}}@keyframes mfzNpcPromptIn{0%{opacity:0}100%{opacity:1}}@keyframes mfzBuildingKeyPulse{0%,100%{box-shadow:0 3px 10px #0009,0 0 9px #ffd76b55}50%{box-shadow:0 3px 10px #0009,0 0 20px #fff0a8cc}}';document.head.appendChild(buildingPromptStyle);
      const buildingPrompt=document.createElement('div');buildingPrompt.style.cssText='position:absolute;left:0;top:0;transform:translate(-999px,-999px) translate(-50%,-100%);z-index:22;display:none;min-width:210px;max-width:min(340px,calc(100vw - 28px));padding:10px 16px 11px;border:1px solid rgba(255,225,118,.96);border-radius:14px;background:linear-gradient(145deg,rgba(9,16,27,.985),rgba(44,29,10,.965));color:#fff4bd;font:900 13px system-ui;line-height:1.2;text-align:center;pointer-events:none;white-space:normal;box-shadow:0 12px 34px #000e,0 0 0 1px rgba(255,190,45,.22) inset,0 0 28px #ffcb3c55;backdrop-filter:blur(9px)';stage.appendChild(buildingPrompt);
      const buildingPromptKey=document.createElement('span');buildingPromptKey.textContent='E';buildingPromptKey.style.cssText='display:inline-grid;place-items:center;min-width:23px;height:23px;margin-right:8px;border:1px solid #fff4b9;border-radius:7px;background:linear-gradient(#ffe27c,#b87519);color:#171008;font:1000 12px system-ui;animation:mfzBuildingKeyPulse 1.25s ease-in-out infinite';buildingPrompt.appendChild(buildingPromptKey);const buildingPromptText=document.createElement('span');buildingPrompt.appendChild(buildingPromptText);const buildingPromptHint=document.createElement('small');buildingPromptHint.style.cssText='display:block;margin:5px 0 0 31px;color:#8debd1;font:800 9px system-ui;letter-spacing:1.5px;text-transform:uppercase';buildingPrompt.appendChild(buildingPromptHint);
      const npcPrompt=document.createElement('div');npcPrompt.id='npcActionPrompt';npcPrompt.style.cssText='position:absolute;left:0;top:0;z-index:23;display:none;min-width:158px;padding:7px 11px 8px;border:1px solid #dfb75b;border-radius:11px;background:linear-gradient(145deg,#0a0f16,#2b180e);color:#fff0bd;font:900 13px system-ui;text-align:center;text-shadow:0 1px 0 #000;pointer-events:none;box-shadow:0 7px 20px #000c,0 0 16px #d49b3d55;transform:translate(-999px,-999px) translate(-50%,-100%);animation:mfzNpcPromptIn .12s linear both';npcPrompt.innerHTML='<span style="display:inline-grid;place-items:center;min-width:22px;height:22px;margin-right:7px;border:1px solid #fff4b9;border-radius:7px;background:linear-gradient(#ffe27c,#b87519);color:#171008;font:1000 12px Arial,sans-serif;text-shadow:none;animation:mfzBuildingKeyPulse 1.25s ease-in-out infinite">E</span><span>Действия</span>';stage.appendChild(npcPrompt);const npcPromptProjection=new THREE.Vector3();
      const vehicleHoldPrompt=document.createElement('div');vehicleHoldPrompt.style.cssText='position:absolute;left:0;top:0;transform:translate(-999px,-999px) translate(-50%,-100%);z-index:24;display:none;min-width:220px;max-width:min(330px,calc(100vw - 34px));padding:9px 13px 10px;border:1px solid #ffe07a;border-radius:12px;background:linear-gradient(145deg,rgba(9,15,24,.985),rgba(48,30,8,.97));color:#fff4c2;font:900 13px system-ui;text-align:center;text-shadow:0 1px #000;box-shadow:0 10px 32px #000d,0 0 22px #ffd24a45;pointer-events:none';vehicleHoldPrompt.innerHTML='<div>🚗 Угнать (удерживайте E)</div><div style="height:7px;margin-top:7px;border-radius:6px;background:#2b3038;overflow:hidden"><i style="display:block;width:0;height:100%;border-radius:inherit;background:linear-gradient(90deg,#d18b25,#ffe67e);box-shadow:0 0 10px #ffd86b"></i></div>';stage.appendChild(vehicleHoldPrompt);const vehicleHoldFill=vehicleHoldPrompt.querySelector('i'),vehiclePromptProjection=new THREE.Vector3(),bizConfirmModal=document.getElementById('bizConfirmModal');
      const rollback=document.createElement('button');rollback.type='button';rollback.textContent='↩ Вернуться в 2D';rollback.title='Безопасный откат на прежний Canvas-рендер';
      rollback.style.cssText='position:absolute;right:14px;top:72px;z-index:21;padding:8px 11px;border:1px solid #70b8ff;border-radius:9px;background:rgba(8,20,35,.92);color:#dff1ff;font:800 12px system-ui;cursor:pointer;box-shadow:0 5px 18px #0008';
      rollback.addEventListener('click',()=>{const url=new URL(location.href);url.searchParams.set('render',rendererConfig.rollbackRenderer||'canvas');location.href=url.href;});stage.appendChild(rollback);
      const clock=document.createElement('button');clock.type='button';clock.title='Нажмите, чтобы перемотать время на 6 часов';clock.style.cssText='position:absolute;right:14px;top:112px;z-index:20;min-width:112px;padding:7px 10px;border:1px solid #526f91;border-radius:9px;background:rgba(8,16,28,.86);color:#fff3c4;font:800 12px system-ui;text-align:center;box-shadow:0 5px 18px #0007;cursor:pointer';stage.appendChild(clock);
      // Production lighting follows only the authoritative city clock. The
      // former hidden click offset made equal displayed times use different
      // palettes. A deliberate offset remains available only for local QA.
      let timeOffset=rendererParams.has('previewtimeoffset')&&rendererParams.has('preview')?Number(rendererParams.get('previewtimeoffset'))||0:0;
      clock.title='Серверное время города';clock.style.cursor='default';
      const keys=new Set(),bullets=[],reloadDebris=[],vehicleHoldMs=650;let aimPoint=new THREE.Vector3(0,0,-10),lastShot=0,muzzleLife=0,recoilKick=0,recoilSide=1,recoilShotSeq=0,reloadWasActive=false,activeReloadProgress=0,triggerHeld=false,laserAimHeld=false,laserAimAllowed=true,laserShotPulseUntil=0,throwAimHeld=false,throwAimSecondary=false,throwAimStartedAt=0,throwAimKind='',throwAimAngle=0,throwAimRange=1.6,throwReleaseUntil=0,animationActionLocked=false,eHoldStarted=0,eHoldTimer=0,eHoldTriggered=false,eHoldVehicleId='',eHoldHasBuilding=false,eHoldNpcKey='',nearbyNpcState=null,nearbyVehicleState=null;
      const muzzle=new THREE.PointLight(0xffb14a,0,9,2);scene.add(muzzle);
      const laserBeamPositions=new Float32Array(6),laserBeamGeometry=new THREE.BufferGeometry();laserBeamGeometry.setAttribute('position',new THREE.BufferAttribute(laserBeamPositions,3));const laserMaterial=new THREE.LineBasicMaterial({color:0xe32238,transparent:true,opacity:.9,depthTest:false,depthWrite:false,toneMapped:false,blending:THREE.NormalBlending}),laserDotMaterial=new THREE.MeshBasicMaterial({color:0xef1f38,transparent:true,opacity:.98,depthTest:false,depthWrite:false,toneMapped:false,blending:THREE.NormalBlending}),laserHaloMaterial=new THREE.MeshBasicMaterial({color:0x8f1022,transparent:true,opacity:.34,side:THREE.DoubleSide,depthTest:false,depthWrite:false,toneMapped:false,blending:THREE.NormalBlending}),laserBeam=new THREE.Line(laserBeamGeometry,laserMaterial),laserDot=new THREE.Mesh(new THREE.SphereGeometry(.085,12,8),laserDotMaterial),laserHalo=new THREE.Mesh(new THREE.RingGeometry(.13,.24,24),laserHaloMaterial),laserOriginPoint=new THREE.Vector3(),laserTargetPoint=new THREE.Vector3(),laserDirection=new THREE.Vector3();laserBeam.renderOrder=76;laserDot.renderOrder=77;laserHalo.renderOrder=75;laserHalo.rotation.x=-Math.PI/2;for(const part of [laserBeam,laserDot,laserHalo]){part.visible=false;part.layers.enable(1);scene.add(part);}
      const laserReticle=document.createElement('div');laserReticle.style.cssText='position:absolute;z-index:31;display:none;width:36px;height:36px;transform:translate(-50%,-50%);pointer-events:none;filter:drop-shadow(0 2px 4px #000d);transition:transform 55ms ease-out';laserReticle.innerHTML='<span style="position:absolute;inset:7px;border:1px solid #8d1626;border-radius:50%;box-shadow:0 0 0 1px #08090b,0 0 6px #7f102288"></span><i style="position:absolute;left:50%;top:0;width:2px;height:10px;transform:translateX(-50%);background:linear-gradient(#d8ad4f 0 70%,transparent 71%)"></i><i style="position:absolute;left:50%;bottom:0;width:2px;height:10px;transform:translateX(-50%);background:linear-gradient(transparent 0 29%,#d8ad4f 30%)"></i><i style="position:absolute;left:0;top:50%;width:10px;height:2px;transform:translateY(-50%);background:linear-gradient(90deg,#d8ad4f 0 70%,transparent 71%)"></i><i style="position:absolute;right:0;top:50%;width:10px;height:2px;transform:translateY(-50%);background:linear-gradient(90deg,transparent 0 29%,#d8ad4f 30%)"></i><b style="position:absolute;left:50%;top:50%;width:4px;height:4px;transform:translate(-50%,-50%) rotate(45deg);background:#f02b3e;border:1px solid #2b070c;box-shadow:0 0 5px #e51f38"></b>';stage.appendChild(laserReticle);renderer.domElement.dataset.laserReticleProfile='compact-brass-burgundy-v267';
      const throwAimPositions=new Float32Array(17*3),throwAimGeometry=new THREE.BufferGeometry();throwAimGeometry.setAttribute('position',new THREE.BufferAttribute(throwAimPositions,3));const throwAimMaterial=new THREE.LineDashedMaterial({color:0xffd65a,dashSize:.55,gapSize:.34,transparent:true,opacity:.95,depthTest:false,toneMapped:false}),throwAimLine=new THREE.Line(throwAimGeometry,throwAimMaterial),throwLandingMaterial=new THREE.MeshBasicMaterial({color:0xffd65a,transparent:true,opacity:.92,side:THREE.DoubleSide,depthTest:false,toneMapped:false}),throwLandingRing=new THREE.Mesh(new THREE.RingGeometry(.48,.7,32),throwLandingMaterial);throwLandingRing.rotation.x=-Math.PI/2;throwAimLine.renderOrder=79;throwLandingRing.renderOrder=79;throwAimLine.visible=throwLandingRing.visible=false;for(const part of [throwAimLine,throwLandingRing]){part.layers.enable(1);scene.add(part);}renderer.domElement.dataset.throwAimProfile='hold-lmb-arc-release-v213';
      const triggerVehicleEntry=()=>{if(!eHoldVehicleId)return null;clearTimeout(eHoldTimer);const result=bridge?.activateNearbyVehicle?.(eHoldVehicleId);eHoldTriggered=!!result?.ok;vehicleHoldFill.style.width=eHoldTriggered?'100%':'0';renderer.domElement.dataset.vehicleHold=eHoldTriggered?'complete':`rejected:${result?.reason||'none'}`;if(eHoldTriggered)renderer.domElement.dataset.vehicleAction=result.kind;return result;};
      const npcActionMenuOpen=()=>!!document.documentElement.dataset.npcActionMenu;
      const nearestNpcInteraction=()=>{const state=bridge?.getPlayerState?.();if(npcActionMenuOpen()||!dynamicState?.npcs?.length||state?.driving||state?.dead||state?.vehicleEntry||state?.arrestPhase||state?.cuffed)return null;const pr=originR+player.position.z/WORLD_SCALE,pc=originC+player.position.x/WORLD_SCALE;let best=null,bestD=3.05;for(let i=0;i<dynamicState.npcs.length&&i<NPC_CAP;i++){const src=dynamicState.npcs[i];if(!src||src.dead)continue;const r=+src.r,c=+src.c;if(!Number.isFinite(r)||!Number.isFinite(c))continue;const d=Math.hypot(r-pr,c-pc),key=String(src.id||src.sourceId||'');if(key&&d<bestD){bestD=d;best={src,index:i,key,distance:d};}}return best;};
      const showNearbyNpc=(near,t)=>{if(!near){if(nearbyNpcRing.visible){npcPrompt.style.display='none';nearbyNpcRing.visible=false;renderer.domElement.dataset.nearbyNpc='none';}return;}const {src,key,distance}=near,x=(+src.c-originC)*WORLD_SCALE,z=(+src.r-originR)*WORLD_SCALE,role=String(src.role||'').toLowerCase(),police=!!src.police||role.includes('police')||role.includes('cop'),empireMember=!!(src.empireBoss||src.empireCrew),gang=empireMember||!!src.gang||role.includes('gang')||role.includes('boss')||role.includes('guard');let accent=police?0x6fc5ff:gang?0xd95662:0x79d9aa;if(empireMember&&src.bossColor)try{accent=instanceColor.set(src.bossColor).getHex();}catch(_){}if(!nearbyNpcRing.visible)nearbyNpcRing.position.set(x,.105,z);else{nearbyNpcRing.position.x=THREE.MathUtils.lerp(nearbyNpcRing.position.x,x,.34);nearbyNpcRing.position.z=THREE.MathUtils.lerp(nearbyNpcRing.position.z,z,.34);}nearbyNpcAccentMaterial.color.setHex(accent);nearbyNpcGlowMaterial.color.setHex(accent);const wave=Math.sin(t*.0062),pulse=1+wave*.018;nearbyNpcRing.scale.setScalar(pulse);nearbyNpcMarkers.rotation.y=t*.00024;nearbyNpcBrassMaterial.opacity=.82+wave*.06;nearbyNpcAccentMaterial.opacity=.78+wave*.08;nearbyNpcGlowMaterial.opacity=.075+(wave+1)*.025;nearbyNpcRing.visible=true;npcPrompt.style.display='block';buildingPrompt.style.display='none';renderer.domElement.dataset.nearbyNpc=`${key}:${distance.toFixed(2)}:${police?'police':gang?'gang':'civilian'}`;renderer.domElement.dataset.npcActionPrompt='opaque-crisp-above-labels-v312';};
      const vehiclePromptLabel=near=>near?.kind==='exit'?'🚪 Выйти (удерживайте E)':'🚗 Угнать (удерживайте E)';
      const showNearbyVehicle=(near,t)=>{if(!near){nearbyVehicleRing.visible=false;vehicleHoldPrompt.style.display='none';vehicleHoldFill.style.width='0';renderer.domElement.dataset.nearbyVehicle='none';return;}const x=(+near.c-originC)*WORLD_SCALE,z=(+near.r-originR)*WORLD_SCALE,pulse=1+Math.sin(t*.0065)*.018;nearbyVehicleMaterial.color.setHex(near.kind==='hijack'?0xe7b84f:near.kind==='exit'?0xffcf69:0x8fd7a7);nearbyVehicleMaterial.opacity=.72+Math.sin(t*.007)*.08;if(!nearbyVehicleRing.visible)nearbyVehicleRing.position.set(x,.105,z);else{nearbyVehicleRing.position.x=THREE.MathUtils.lerp(nearbyVehicleRing.position.x,x,.3);nearbyVehicleRing.position.z=THREE.MathUtils.lerp(nearbyVehicleRing.position.z,z,.3);}nearbyVehicleRing.scale.setScalar(pulse);nearbyVehicleRing.visible=true;vehicleHoldPrompt.firstElementChild.textContent=vehiclePromptLabel(near);vehicleHoldPrompt.style.display='block';renderer.domElement.dataset.nearbyVehicle=`${near.id}:${near.kind}:${(+near.distance||0).toFixed(2)}`;};
      const updateNearbyVehiclePromptPosition=near=>{if(!near||vehicleHoldPrompt.style.display==='none')return;vehiclePromptProjection.set(nearbyVehicleRing.position.x,4.9,nearbyVehicleRing.position.z).project(camera);const anchorX=(vehiclePromptProjection.x*.5+.5)*lastW,anchorY=(-vehiclePromptProjection.y*.5+.5)*lastH,w=Math.min(280,lastW-24),h=54,pad=12,x=Math.round(Math.max(pad+w/2,Math.min(lastW-pad-w/2,anchorX))),y=Math.round(Math.max(pad+h,Math.min(lastH-pad,anchorY)));vehicleHoldPrompt.style.transform=`translate(${x}px,${y}px) translate(-50%,-100%)`;vehicleHoldPrompt.dataset.anchor='vehicle-roof-crisp-pixel-v321';};
      const updateNearbyNpcPromptPosition=near=>{if(!near||npcPrompt.style.display==='none')return;npcPromptProjection.set(nearbyNpcRing.position.x,12.3,nearbyNpcRing.position.z).project(camera);const anchorX=(npcPromptProjection.x*.5+.5)*lastW,anchorY=(-npcPromptProjection.y*.5+.5)*lastH,w=Math.min(190,lastW-24),h=44,pad=12,x=Math.round(Math.max(pad+w/2,Math.min(lastW-pad-w/2,anchorX))),y=Math.round(Math.max(pad+h,Math.min(lastH-pad,anchorY)));npcPrompt.style.transform=`translate(${x}px,${y}px) translate(-50%,-100%)`;npcPrompt.dataset.anchor='above-raised-npc-labels-v347';};
      addEventListener('keydown',e=>{if(npcActionMenuOpen()){keys.clear();return;}const typing=e.target?.matches?.('input,textarea,select,[contenteditable="true"]'),chatMode=document.documentElement.dataset.chatMode==='open';if(typing||chatMode){keys.clear();return;}keys.add(e.code);if(e.code==='KeyE'&&!e.repeat){const vehicle=nearbyVehicleState,building=nearbyActionState,npc=nearbyNpcState;eHoldStarted=performance.now();eHoldTriggered=false;eHoldVehicleId=String(vehicle?.id||'');eHoldHasBuilding=!!building;eHoldNpcKey=String(npc?.key||'');if(vehicle){vehicleHoldPrompt.firstElementChild.textContent=eHoldNpcKey?'Короткое E — действия NPC · удержание — машина':vehiclePromptLabel(vehicle);vehicleHoldPrompt.style.display='block';vehicleHoldFill.style.width='0';renderer.domElement.dataset.vehicleHold=`waiting:${eHoldVehicleId}`;renderer.domElement.dataset.interactionPriority=eHoldNpcKey?'tap-npc-hold-vehicle':eHoldHasBuilding?'tap-building-hold-vehicle':'hold-vehicle-only';eHoldTimer=setTimeout(()=>{if(keys.has('KeyE'))triggerVehicleEntry();},vehicleHoldMs);}else renderer.domElement.dataset.interactionPriority=eHoldNpcKey?'npc-actions':building?'building-only':'none';e.preventDefault();e.stopImmediatePropagation();}else if(e.code==='Escape'){bridge?.closeBuildingActions?.();}else if(e.code==='Space'){e.preventDefault();e.stopImmediatePropagation();if(currentWeaponId==='c4')bridge?.plantC4?.();else if(!isThrowablePrimary())shoot(performance.now());}},true);
      addEventListener('keyup',e=>{keys.delete(e.code);if(npcActionMenuOpen())return;const typing=e.target?.matches?.('input,textarea,select,[contenteditable="true"]'),chatMode=document.documentElement.dataset.chatMode==='open';if(typing||chatMode){if(e.code==='KeyE'){clearTimeout(eHoldTimer);vehicleHoldPrompt.style.display='none';eHoldStarted=0;eHoldVehicleId='';eHoldHasBuilding=false;eHoldNpcKey='';}return;}if(e.code!=='KeyE')return;clearTimeout(eHoldTimer);vehicleHoldPrompt.style.display='none';if(!eHoldTriggered){if(eHoldNpcKey){const result=bridge?.openNpcActions?.(eHoldNpcKey);renderer.domElement.dataset.npcAction=result?.ok?`open:${result.kind}:${eHoldNpcKey}`:`rejected:${result?.reason||'none'}`;renderer.domElement.dataset.interactionPriority=result?.ok?'npc-actions-open':'npc-actions-rejected';}else{const bankResult=bridge?.interactBank?.(),result=bankResult?.ok?bankResult:bridge?.toggleNearbyBuildingActions?.(innerWidth/2,innerHeight*.58);renderer.domElement.dataset.buildingAction=result?.ok?(result.closed?'closed':`${result.kind}:${result.id||''}`):`rejected:${result?.reason||'none'}`;renderer.domElement.dataset.interactionPriority=eHoldHasBuilding?'building-tap-complete':eHoldVehicleId?'vehicle-short-ignored':'building-only-complete';}}if(eHoldTriggered)renderer.domElement.dataset.vehicleHold='complete';else renderer.domElement.dataset.vehicleHold=eHoldNpcKey?'short-npc-action':'short-building-action';eHoldStarted=0;eHoldVehicleId='';eHoldHasBuilding=false;eHoldNpcKey='';},true);
      addEventListener('keyup',e=>{if(e.code==='KeyE')vehicleHoldFill.style.width='0';},true);
      const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),frameMove=new THREE.Vector3(),occlusionSight=new THREE.Vector3(),occlusionRaycaster=new THREE.Raycaster(),occlusionHits=[];let activeAimSurface=ground,mouseAimActive=false,mouseClientX=0,mouseClientY=0,selectedNpcSourceId='',selectedNpcUntil=0,activeGangShotSourceId='',activeNpcShotId='',activeVehicleShotId='';
      if(rendererParams.has('previewlaseraim')){laserAimHeld=true;mouseAimActive=true;mouseClientX=innerWidth*.68;mouseClientY=innerHeight*.52;renderer.domElement.dataset.laserAimPreview='forced-held-local-qa';}
      let highlightedBuildingObject=null,manualBuildingSelectionUntil=0,nearbyBuildingVisualKey='';const selectionFrameMat=new THREE.MeshBasicMaterial({color:0xffd05a,transparent:true,opacity:.98,depthTest:false,depthWrite:false,toneMapped:false,blending:THREE.NormalBlending}),selectionGlowMat=new THREE.MeshBasicMaterial({color:0xffb92e,transparent:true,opacity:.3,depthTest:false,depthWrite:false,toneMapped:false,blending:THREE.AdditiveBlending}),buildingSelectionFrame=new THREE.Group(),selectionBars=[],selectionGlowBars=[];for(let i=0;i<4;i++){const glow=new THREE.Mesh(new THREE.BoxGeometry(1,.08,1),selectionGlowMat);glow.renderOrder=47;buildingSelectionFrame.add(glow);selectionGlowBars.push(glow);}for(let i=0;i<4;i++){const bar=new THREE.Mesh(new THREE.BoxGeometry(1,.14,1),selectionFrameMat);bar.renderOrder=48;buildingSelectionFrame.add(bar);selectionBars.push(bar);}buildingSelectionFrame.visible=false;scene.add(buildingSelectionFrame);
      const entranceMarker=new THREE.Group(),entranceOuterMat=new THREE.MeshBasicMaterial({color:0xffd45c,transparent:true,opacity:.94,side:THREE.DoubleSide,depthTest:false,toneMapped:false,blending:THREE.AdditiveBlending}),entranceInnerMat=new THREE.MeshBasicMaterial({color:0x66ffcf,transparent:true,opacity:.9,side:THREE.DoubleSide,depthTest:false,toneMapped:false,blending:THREE.AdditiveBlending}),entranceOuter=new THREE.Mesh(new THREE.RingGeometry(.76,1.22,36),entranceOuterMat),entranceInner=new THREE.Mesh(new THREE.RingGeometry(.38,.62,28),entranceInnerMat),entranceBeam=new THREE.Mesh(new THREE.CylinderGeometry(.055,.18,2.35,10),entranceInnerMat),entranceArrow=new THREE.Mesh(new THREE.ConeGeometry(.34,.72,9),entranceOuterMat);entranceOuter.rotation.x=entranceInner.rotation.x=-Math.PI/2;entranceBeam.position.y=1.18;entranceArrow.position.y=2.45;entranceArrow.rotation.z=Math.PI;for(const part of [entranceOuter,entranceInner,entranceBeam,entranceArrow]){part.renderOrder=51;entranceMarker.add(part);}entranceMarker.position.y=.24;entranceMarker.visible=false;scene.add(entranceMarker);
      const clearBuildingHighlight=()=>{buildingSelectionFrame.visible=false;highlightedBuildingObject=null;renderer.domElement.dataset.buildingHighlight='none';};
      const highlightBuilding=object=>{if(!object){clearBuildingHighlight();return;}highlightedBuildingObject=object;for(const material of object.userData.fadeMaterials||[]){const state=occlusionMaterialStates.get(material);if(state){state.targetOpacity=state.baseOpacity;state.lastBlockedAt=-Infinity;}}if(!object.geometry.boundingBox)object.geometry.computeBoundingBox();const bounds=object.geometry.boundingBox,size=bounds?bounds.getSize(new THREE.Vector3()):new THREE.Vector3(3,3,3),sx=Math.abs(object.scale?.x||1),sy=Math.abs(object.scale?.y||1),sz=Math.abs(object.scale?.z||1),w=Math.max(.5,size.x*sx),h=Math.max(.5,size.y*sy),d=Math.max(.5,size.z*sz),pad=.03,hw=w/2+pad,hd=d/2+pad,line=.28,glow=.5,roofY=object.position.y+h/2+.18;buildingSelectionFrame.position.set(object.position.x,roofY,object.position.z);buildingSelectionFrame.rotation.set(0,object.rotation?.y||0,0);for(const [i,z] of [[0,-hd],[1,hd]]){selectionGlowBars[i].position.set(0,-.025,z);selectionGlowBars[i].scale.set(w+pad*2+glow,1,glow);selectionBars[i].position.set(0,.025,z);selectionBars[i].scale.set(w+pad*2+line,1,line);}for(const [i,x] of [[2,-hw],[3,hw]]){selectionGlowBars[i].position.set(x,-.025,0);selectionGlowBars[i].scale.set(glow,1,d+pad*2+glow);selectionBars[i].position.set(x,.025,0);selectionBars[i].scale.set(line,1,d+pad*2+line);}buildingSelectionFrame.visible=true;renderer.domElement.dataset.buildingHighlight='roof-contour-gold-outline-visible-facade-v330';renderer.domElement.dataset.buildingHighlightBounds=`${w.toFixed(2)}x${d.toFixed(2)}@${roofY.toFixed(2)}:roof-fit`;};
      const buildingObjectForEntry=entry=>entry?.kind==='business'?(businessExteriorById.get(String(entry.id))?.main||null):(buildingPickables.find(o=>{if(!o.userData.mainBuilding||o.userData.businessId)return false;const m=o.userData.building;if(Number.isFinite(m.minR))return entry.r>=m.minR-1&&entry.r<=m.maxR+1&&entry.c>=m.minC-1&&entry.c<=m.maxC+1;return Math.abs(entry.r-m.r)<=m.d*.5+1&&Math.abs(entry.c-m.c)<=m.w*.5+1;})||null);
      let nearbyBuildingEntry=null,nearbyBuildingObject=null;const promptProjection=new THREE.Vector3();
      // One building has one stable prompt anchor. Do not choose another side
      // based on the player's screen position: that made the prompt jump while
      // walking around the same facade.
      const updateBuildingPromptPosition=()=>{if(!nearbyBuildingEntry||buildingPrompt.style.display==='none')return;const entry=nearbyBuildingEntry,building=nearbyBuildingObject,anchorR=Number.isFinite(+entry.r)?+entry.r:originR,anchorC=Number.isFinite(+entry.c)?+entry.c:originC,buildingHeight=building?.geometry?.parameters?.height||6;if(building)promptProjection.set(building.position.x,building.position.y+buildingHeight*.55+1.2,building.position.z);else promptProjection.set((anchorC-originC)*WORLD_SCALE,5.2,(anchorR-originR)*WORLD_SCALE);promptProjection.project(camera);const anchorX=(promptProjection.x*.5+.5)*lastW,anchorY=(-promptProjection.y*.5+.5)*lastH,w=Math.min(250,lastW-24),h=64,pad=12,x=Math.round(Math.max(pad+w/2,Math.min(lastW-pad-w/2,anchorX))),y=Math.round(Math.max(pad+h,Math.min(lastH-pad,anchorY-18)));buildingPrompt.style.transform=`translate(${x}px,${y}px) translate(-50%,-100%)`;buildingPrompt.dataset.avoidsPlayer='fixed-building-anchor-crisp-every-frame-v324';};
      const showNearbyBuilding=entry=>{nearbyBuildingEntry=entry||null;if(!entry){nearbyBuildingObject=null;buildingPrompt.style.display='none';entranceMarker.visible=false;nearbyBuildingVisualKey='';manualBuildingSelectionUntil=0;clearBuildingHighlight();renderer.domElement.dataset.nearbyBuilding='none';renderer.domElement.dataset.buildingPrompt='hidden-out-of-range';renderer.domElement.dataset.entranceMarker='hidden-out-of-range';return;}const visualKey=`${entry.kind}:${entry.id}:${entry.owned?1:0}`;buildingPromptText.textContent=entry.owned?`Собственность: ${entry.name||'Бизнес'}`:`Действие: ${entry.name||'Здание'}`;buildingPromptHint.textContent=entry.owned?'Войти в свою собственность':entry.kind==='bank'?'Войти в банк':entry.kind==='building'&&entry.type==='police_st'?'Войти в участок':entry.kind==='building'&&!entry.type?'Войти в здание':'Выбрать вход или действие';if(visualKey!==nearbyBuildingVisualKey){nearbyBuildingVisualKey=visualKey;buildingPrompt.style.animation='none';requestAnimationFrame(()=>{if(nearbyBuildingVisualKey===visualKey)buildingPrompt.style.animation='mfzBuildingPromptIn .28s cubic-bezier(.2,.9,.25,1) both';});}buildingPrompt.style.display='block';renderer.domElement.dataset.nearbyBuilding=visualKey;renderer.domElement.dataset.buildingPrompt='visible-in-range';renderer.domElement.dataset.businessActionMode='proximity-prompt-explicit-e';const exterior=entry.kind==='business'?businessExteriorById.get(String(entry.id)):null,building=exterior?.main||buildingObjectForEntry(entry),markerR=Number.isFinite(+entry.entryR)?+entry.entryR:+entry.r+.5,markerC=Number.isFinite(+entry.entryC)?+entry.entryC:+entry.c+.5;nearbyBuildingObject=building;entranceMarker.position.set((markerC-originC)*WORLD_SCALE,.24,(markerR-originR)*WORLD_SCALE);entranceMarker.visible=true;renderer.domElement.dataset.entranceMarker=`visible:${markerR.toFixed(2)},${markerC.toFixed(2)}`;if(building!==highlightedBuildingObject){if(building)highlightBuilding(building);else clearBuildingHighlight();}};
      const syncMouseAim=()=>{if(!mouseAimActive)return;const r=renderer.domElement.getBoundingClientRect();if(!r.width||!r.height)return;pointer.set(((mouseClientX-r.left)/r.width)*2-1,-((mouseClientY-r.top)/r.height)*2+1);raycaster.layers.set(activeAimSurface===ground?0:1);raycaster.setFromCamera(pointer,camera);const hit=raycaster.intersectObject(activeAimSurface,false)[0];if(!hit)return;aimPoint.copy(hit.point);const dx=aimPoint.x-player.position.x,dz=aimPoint.z-player.position.z;if(dx*dx+dz*dz<.01)return;const angle=Math.atan2(dz,dx);bridge?.setAim?.(angle);renderer.domElement.dataset.aimMode='mouse';renderer.domElement.dataset.aimAngle=angle.toFixed(3);};
      addEventListener('pointermove',e=>{if(e.pointerType==='touch')return;mouseAimActive=true;mouseClientX=e.clientX;mouseClientY=e.clientY;syncMouseAim();},true);
      const canHoldLaserAim=()=>{const state=bridge?.getPlayerState?.();return !npcActionMenuOpen()&&!['','none','fists','unarmed'].includes(currentWeaponId)&&!state?.driving&&!state?.dead&&!state?.vehicleEntry;};
      const stopLaserAim=reason=>{laserAimHeld=false;bridge?.setAimHeld?.(false);if(throwAimSecondary&&throwAimHeld){throwAimHeld=false;throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.throwAim=`cancelled:${reason||'released'}`;}throwAimSecondary=false;laserBeam.visible=laserDot.visible=laserHalo.visible=false;laserReticle.style.display='none';renderer.domElement.style.cursor='default';renderer.domElement.dataset.laserAim=`off:${reason||'released'}`;renderer.domElement.dataset.laserBeamLength='0';};
      addEventListener('mafiozi-chat-mode',e=>{if(!e.detail?.open)return;keys.clear();clearTimeout(eHoldTimer);eHoldStarted=0;eHoldVehicleId='';eHoldHasBuilding=false;eHoldNpcKey='';vehicleHoldPrompt.style.display='none';stopLaserAim('chat');throwAimHeld=false;throwAimSecondary=false;throwAimLine.visible=throwLandingRing.visible=false;},true);
      addEventListener('mafiozi-npc-action-mode',e=>{if(!e.detail?.open)return;keys.clear();clearTimeout(eHoldTimer);eHoldStarted=0;eHoldVehicleId='';eHoldHasBuilding=false;eHoldNpcKey='';vehicleHoldPrompt.style.display='none';npcPrompt.style.display='none';nearbyNpcRing.visible=false;triggerHeld=false;stopLaserAim('npc-actions');throwAimHeld=false;throwAimSecondary=false;throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.inputLock='npc-actions';},true);
      addEventListener('mafiozi-custody-mode',e=>{keys.clear();clearTimeout(eHoldTimer);eHoldStarted=0;eHoldVehicleId='';eHoldHasBuilding=false;eHoldNpcKey='';vehicleHoldPrompt.style.display='none';npcPrompt.style.display='none';nearbyNpcRing.visible=false;triggerHeld=false;activeGangShotSourceId='';activeNpcShotId='';activeVehicleShotId='';stopLaserAim(e.detail?.released?'prison-release':'custody');throwAimHeld=false;throwAimSecondary=false;throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.inputLock=e.detail?.released?'prison-release-cleared-v311':'custody-cleared-v311';},true);
      const updateLaserAim=t=>{const active=laserAimHeld&&laserAimAllowed&&gun.visible;if(!active){laserBeam.visible=laserDot.visible=laserHalo.visible=false;laserReticle.style.display='none';return;}const stageRect=stage.getBoundingClientRect(),reticleKick=Math.min(.15,recoilKick*.032),shotPulse=t<laserShotPulseUntil?.9:1,reticleScale=(1+reticleKick+Math.sin(t*.01)*.012)*shotPulse;laserReticle.style.left=`${mouseClientX-stageRect.left}px`;laserReticle.style.top=`${mouseClientY-stageRect.top}px`;laserReticle.style.transform=`translate(-50%,-50%) scale(${reticleScale.toFixed(3)})`;laserReticle.style.display='block';renderer.domElement.dataset.laserReticleSpread=reticleScale.toFixed(3);if(isSpecialPrimary()){laserBeam.visible=laserDot.visible=laserHalo.visible=false;renderer.domElement.dataset.laserAim='throw-held-no-laser';renderer.domElement.dataset.laserBeamLength='0';return;}player.updateMatrixWorld(true);localMuzzleFlash.getWorldPosition(laserOriginPoint);laserTargetPoint.copy(aimPoint);laserTargetPoint.y=Math.max(playerFloorElevation+.16,.16);laserDirection.subVectors(laserTargetPoint,laserOriginPoint);let distance=laserDirection.length();const maxDistance=currentWeaponFx.family==='sniper'?52:currentWeaponFx.family==='rifle'?46:currentWeaponFx.family==='shotgun'?34:40;if(distance>maxDistance){laserDirection.multiplyScalar(maxDistance/Math.max(.001,distance));laserTargetPoint.copy(laserOriginPoint).add(laserDirection);distance=maxDistance;}if(distance<.3){laserBeam.visible=laserDot.visible=laserHalo.visible=false;return;}laserBeamPositions[0]=laserOriginPoint.x;laserBeamPositions[1]=laserOriginPoint.y;laserBeamPositions[2]=laserOriginPoint.z;laserBeamPositions[3]=laserTargetPoint.x;laserBeamPositions[4]=laserTargetPoint.y;laserBeamPositions[5]=laserTargetPoint.z;laserBeamGeometry.attributes.position.needsUpdate=true;laserDot.position.copy(laserTargetPoint);laserHalo.position.copy(laserTargetPoint);const pulse=1+Math.sin(t*.018)*.1;laserDot.scale.setScalar(pulse);laserHalo.scale.setScalar(1+Math.sin(t*.012)*.06);laserBeam.visible=laserDot.visible=laserHalo.visible=true;renderer.domElement.dataset.laserAim='held';renderer.domElement.dataset.laserBeamLength=distance.toFixed(2);};
      const isThrowablePrimary=()=>!animationActionLocked&&(currentWeaponId==='grenade'||currentWeaponId==='molotov');
      const isSpecialPrimary=()=>!animationActionLocked&&(isThrowablePrimary()||currentWeaponId==='c4');
      const updateThrowAim=t=>{
        if(!throwAimHeld){throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.throwAim='off';return;}
        const dirX=aimPoint.x-player.position.x,dirZ=aimPoint.z-player.position.z,len=Math.hypot(dirX,dirZ)||1,nx=dirX/len,nz=dirZ/len;
        throwAimAngle=Math.atan2(nz,nx);
        const charge=Math.max(0,Math.min(1,(t-throwAimStartedAt)/850));throwAimRange=throwAimKind==='c4'?1.05:1.6+charge*4.9;
        const distance=throwAimRange*WORLD_SCALE,endX=player.position.x+nx*distance,endZ=player.position.z+nz*distance,color=throwAimKind==='molotov'?0xff6a20:throwAimKind==='c4'?0xff3f45:0xffd65a;
        throwAimMaterial.color.setHex(color);throwLandingMaterial.color.setHex(color);throwLandingRing.position.set(endX,playerFloorElevation+.08,endZ);throwLandingRing.scale.setScalar(throwAimKind==='c4'?.72:1+charge*.22);throwLandingRing.visible=true;
        throwAimLine.visible=throwAimKind!=='c4';
        if(throwAimLine.visible){for(let i=0;i<=16;i++){const p=i/16,j=i*3;throwAimPositions[j]=player.position.x+nx*distance*p;throwAimPositions[j+1]=playerFloorElevation+1.7+Math.sin(Math.PI*p)*(2.05+charge*1.3)-p*1.58;throwAimPositions[j+2]=player.position.z+nz*distance*p;}throwAimGeometry.attributes.position.needsUpdate=true;throwAimLine.computeLineDistances();}
        renderer.domElement.dataset.throwAim=`held:${throwAimKind}:${throwAimRange.toFixed(2)}`;renderer.domElement.dataset.primaryActionRoute=throwAimKind==='c4'?'c4-place-preview':'throw-charge';
      };
      const releaseSpecialPrimary=()=>{
        if(!throwAimHeld)return false;updateThrowAim(performance.now());const kind=throwAimKind;throwAimHeld=false;throwAimSecondary=false;throwAimLine.visible=throwLandingRing.visible=false;throwReleaseUntil=performance.now()+420;
        let accepted=false;if(kind==='c4')accepted=!!bridge?.plantC4?.();else accepted=!!bridge?.throwSelected?.(kind,throwAimAngle,throwAimRange);
        renderer.domElement.dataset.throwAim=`released:${kind}:${throwAimRange.toFixed(2)}`;renderer.domElement.dataset.throwReleases=String((+renderer.domElement.dataset.throwReleases||0)+1);renderer.domElement.dataset.primaryActionRoute=accepted?(kind==='c4'?'c4-place':'throw-release'):`rejected:${kind}`;return accepted;
      };
      const vehiclePickProjection=new THREE.Vector3(),npcPickProjection=new THREE.Vector3(),npcPickMatrix=new THREE.Matrix4();
      const vehicleAtPointer=e=>{if(activeAimSurface!==ground){renderer.domElement.dataset.vehiclePick='miss:surface';return null;}const r=renderer.domElement.getBoundingClientRect();if(!r.width||!r.height)return null;pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);raycaster.layers.set(0);raycaster.setFromCamera(pointer,camera);for(const hit of raycaster.intersectObjects(cars,true)){let root=hit.object;while(root?.parent&&!cars.includes(root))root=root.parent;if(!root||!cars.includes(root))continue;const src=root.userData.source;if(!src||src.helicopter||src.wrecked||src.destroying)continue;renderer.domElement.dataset.vehiclePick=`mesh:${src.id}`;return {root,src,hit};}let nearest=null,best=1,probe=Infinity,probeId='',probeX=0,probeY=0;for(const root of cars){const src=root?.userData?.source;if(!src||src.helicopter||src.wrecked||src.destroying||!root.visible)continue;vehiclePickProjection.copy(root.position);vehiclePickProjection.y+=1.15;vehiclePickProjection.project(camera);if(vehiclePickProjection.z<-1||vehiclePickProjection.z>1)continue;const sx=r.left+(vehiclePickProjection.x*.5+.5)*r.width,sy=r.top+(-vehiclePickProjection.y*.5+.5)*r.height,score=((e.clientX-sx)/70)**2+((e.clientY-sy)/44)**2;if(score<probe){probe=score;probeId=String(src.id||'');probeX=sx;probeY=sy;}if(score<best){best=score;nearest={root,src,hit:{point:new THREE.Vector3(root.position.x,root.position.y+1.15,root.position.z)}};}}renderer.domElement.dataset.vehiclePick=nearest?`silhouette:${nearest.src.id}:${best.toFixed(2)}`:`miss:${probeId}:${probe.toFixed(2)}:${e.clientX.toFixed(0)},${e.clientY.toFixed(0)}>${probeX.toFixed(0)},${probeY.toFixed(0)}`;return nearest;};renderer.domElement.dataset.vehicleAimBridge=typeof bridge?.fireAtVehicle==='function'?'mesh-plus-silhouette-pick-direct-center-v229':'missing';
      const selectBuildingAtPointer=e=>{if(activeAimSurface!==ground)return false;const r=renderer.domElement.getBoundingClientRect();pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);raycaster.layers.set(0);raycaster.setFromCamera(pointer,camera);const hit=raycaster.intersectObjects(buildingPickables,false)[0];if(!hit?.object?.userData?.building)return false;const meta=hit.object.userData.building,result=bridge?.selectBuilding?.(meta.r,meta.c,e.clientX,e.clientY);if(!result?.ok)return false;manualBuildingSelectionUntil=result.near?performance.now()+800:0;if(result.near)highlightBuilding(hit.object);else clearBuildingHighlight();renderer.domElement.dataset.selectedBuilding=`${result.kind}:${result.id}:${result.near?'near':'far'}`;return true;};
      const npcAtPointer=(e,hireOnly=false)=>{if((activeAimSurface!==ground&&activeAimSurface!==interiorFloor)||!dynamicState?.npcs?.length)return null;const r=renderer.domElement.getBoundingClientRect();if(!r.width||!r.height)return null;pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);raycaster.layers.mask=camera.layers.mask;raycaster.setFromCamera(pointer,camera);const valid=src=>src&&!src.dead&&(!hireOnly||(src.gang&&src.sourceId&&src.hireable)),hits=raycaster.intersectObjects([npcParts.body,npcParts.head,npcParts.leftArm,npcParts.rightArm,npcParts.leftLeg,npcParts.rightLeg,npcParts.hat],false);for(const hit of hits){const i=hit.instanceId,src=Number.isInteger(i)?dynamicState.npcs[i]:null;if(valid(src)){renderer.domElement.dataset.npcPick=`mesh:${src.id}`;return src;}}let nearest=null,best=(activeAimSurface===interiorFloor?140:58)**2;for(let i=0;i<dynamicState.npcs.length&&i<NPC_CAP;i++){const src=dynamicState.npcs[i];if(!valid(src))continue;npcParts.body.getMatrixAt(i,npcPickMatrix);npcPickProjection.setFromMatrixPosition(npcPickMatrix).applyMatrix4(npcParts.body.matrixWorld).project(camera);if(npcPickProjection.z<-1||npcPickProjection.z>1)continue;const sx=r.left+(npcPickProjection.x*.5+.5)*r.width,sy=r.top+(-npcPickProjection.y*.5+.5)*r.height,dx=e.clientX-sx,dy=e.clientY-sy,d2=dx*dx+dy*dy;if(d2<best){best=d2;nearest=src;}}renderer.domElement.dataset.npcPick=nearest?`silhouette:${nearest.id}:${Math.sqrt(best).toFixed(1)}`:`miss:${hits.length}`;return nearest;};
      const gangNpcAtPointer=(e,hireOnly=false)=>{const src=npcAtPointer(e,hireOnly);return src?.gang&&src.sourceId?src:null;};
      const selectNpcAtPointer=e=>{const src=gangNpcAtPointer(e,true);if(!src)return false;const result=bridge?.selectGangNpc?.(src.sourceId);if(!result?.ok)return false;selectedNpcSourceId=String(src.sourceId);selectedNpcUntil=performance.now()+10000;selectedNpcRing.visible=true;renderer.domElement.dataset.selectedGangNpc=selectedNpcSourceId;return true;};
      const selectBrigadirAtPointer=e=>{const r=renderer.domElement.getBoundingClientRect();pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);raycaster.layers.set(0);raycaster.setFromCamera(pointer,camera);for(const hit of raycaster.intersectObjects(gameplayObjectGroup.children,true)){let q=hit.object;while(q&&q.parent!==gameplayObjectGroup)q=q.parent;if(q?.userData?.kind==='brigadir'){const result=bridge?.openBrigadirActions?.();if(result?.ok){renderer.domElement.dataset.brigadirActionCard='open';return true;}}}return false;};
      const beginFirearmAtPointer=(e,allowBuildingSelection=true)=>{mouseAimActive=true;mouseClientX=e.clientX;mouseClientY=e.clientY;syncMouseAim();const vehicle=vehicleAtPointer(e),target=vehicle?null:npcAtPointer(e,false);activeVehicleShotId='';activeNpcShotId='';if(vehicle){activeVehicleShotId=String(vehicle.src.id||'');aimPoint.set((vehicle.src.c-originC)*WORLD_SCALE,vehicle.hit.point.y,(vehicle.src.r-originR)*WORLD_SCALE);renderer.domElement.dataset.vehicleAim=`locked:${activeVehicleShotId}`;}else if(target){activeNpcShotId=String(target.id||'');aimPoint.set((target.c-originC)*WORLD_SCALE,1.9,(target.r-originR)*WORLD_SCALE);renderer.domElement.dataset.npcAim=`locked:${activeNpcShotId}`;}else if(allowBuildingSelection&&selectBuildingAtPointer(e))return false;activeGangShotSourceId=String((target?.gang&&target?.sourceId?target.sourceId:'')||(performance.now()<selectedNpcUntil?selectedNpcSourceId:'')||'');triggerHeld=true;renderer.domElement.dataset.primaryActionRoute=laserAimHeld?'laser-firearm':'firearm';return shoot(performance.now())===true;};
      if(location.hostname==='127.0.0.1'||location.hostname==='localhost'){renderer.domElement.__combatQaTargets=()=>{const r=renderer.domElement.getBoundingClientRect(),project=(x,y,z)=>{const p=new THREE.Vector3(x,y,z).project(camera);return {x:r.left+(p.x*.5+.5)*r.width,y:r.top+(-p.y*.5+.5)*r.height,visible:p.z>=-1&&p.z<=1};},projectNpc=i=>{npcParts.body.getMatrixAt(i,npcPickMatrix);const p=npcPickProjection.setFromMatrixPosition(npcPickMatrix).applyMatrix4(npcParts.body.matrixWorld).project(camera);return {x:r.left+(p.x*.5+.5)*r.width,y:r.top+(-p.y*.5+.5)*r.height,visible:p.z>=-1&&p.z<=1};},pr=originR+player.position.z/WORLD_SCALE,pc=originC+player.position.x/WORLD_SCALE;return {npcs:(dynamicState?.npcs||[]).slice(0,NPC_CAP).map((src,i)=>({...projectNpc(i),id:String(src?.id||''),distance:Math.hypot((+src?.r||0)-pr,(+src?.c||0)-pc),dead:!!src?.dead})),cars:cars.map(root=>{const src=root?.userData?.source||{};return {...project(root.position.x,root.position.y+1.15,root.position.z),id:String(src.id||''),distance:Math.hypot((+src.r||0)-pr,(+src.c||0)-pc),wrecked:!!(src.wrecked||src.destroying),visibleRoot:!!root.visible};})};};setInterval(()=>{renderer.domElement.dataset.combatQaTargets=JSON.stringify(renderer.domElement.__combatQaTargets());},180);}
      const isCombatCanvasCoordinate=e=>{const r=renderer.domElement.getBoundingClientRect(),x=+e.clientX,y=+e.clientY;return Number.isFinite(x)&&Number.isFinite(y)&&x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom;};
      const isCombatUiTarget=e=>{const target=e.target;if(!target||target===renderer.domElement||target===document||target===document.body||target===document.documentElement)return false;return !!target.closest?.('button,a,input,textarea,select,option,[contenteditable="true"],[role="button"],[role="dialog"]');};
      const isCombatSurfaceEvent=e=>e.target===renderer.domElement||((laserAimHeld||((+e.buttons||0)&2)!==0)&&isCombatCanvasCoordinate(e)&&!isCombatUiTarget(e));
      const markUiFireBlocked=e=>{const target=e.target,tag=String(target?.tagName||'unknown').toLowerCase(),id=String(target?.id||''),cls=String(target?.className||'').split(/\s+/)[0]||'';renderer.domElement.dataset.uiFireBlocked=String((+renderer.domElement.dataset.uiFireBlocked||0)+1);renderer.domElement.dataset.uiFireBlockedTarget=`${tag}${id?'#'+id:''}${cls?'.'+cls:''}`.slice(0,120);renderer.domElement.dataset.primaryActionRoute='blocked-ui-pointer';};
      renderer.domElement.dataset.combatInputProfile='canvas-pointerdown-mousedown-click-held-aim-v320';
      renderer.domElement.addEventListener('contextmenu',e=>{if(!canHoldLaserAim())return;e.preventDefault();e.stopImmediatePropagation();},true);
      addEventListener('pointerdown',e=>{if(e.button!==2||e.pointerType==='touch'||!isCombatSurfaceEvent(e))return;if(!canHoldLaserAim())return;e.preventDefault();e.stopImmediatePropagation();laserAimHeld=true;laserAimAllowed=true;mouseAimActive=true;mouseClientX=e.clientX;mouseClientY=e.clientY;renderer.domElement.dataset.laserAimPresses=String((+renderer.domElement.dataset.laserAimPresses||0)+1);renderer.domElement.style.cursor='none';syncMouseAim();if(isSpecialPrimary()){throwAimHeld=true;throwAimSecondary=true;throwAimStartedAt=performance.now();throwAimKind=currentWeaponId;renderer.domElement.dataset.throwPresses=String((+renderer.domElement.dataset.throwPresses||0)+1);renderer.domElement.dataset.primaryActionRoute=currentWeaponId==='c4'?'rmb-c4-aim':'rmb-throw-aim';updateThrowAim(throwAimStartedAt);}else bridge?.setAimHeld?.(true);updateLaserAim(performance.now());},true);
      addEventListener('pointerup',e=>{if(e.button===2){renderer.domElement.dataset.laserAimReleases=String((+renderer.domElement.dataset.laserAimReleases||0)+1);stopLaserAim('released');}},true);addEventListener('pointercancel',e=>{if(e.button===2||laserAimHeld)stopLaserAim('cancelled');},true);
      renderer.domElement.addEventListener('contextmenu',e=>{e.preventDefault();if(!selectBrigadirAtPointer(e)&&!selectNpcAtPointer(e))selectBuildingAtPointer(e);},true);
      let primaryCombatHandledAt=0;
      const handlePrimaryCombatDown=e=>{if(e.button!==0||e.pointerType==='touch')return false;if(!isCombatSurfaceEvent(e)){markUiFireBlocked(e);return false;}primaryCombatHandledAt=performance.now();e.preventDefault();e.stopImmediatePropagation();mouseAimActive=true;mouseClientX=e.clientX;mouseClientY=e.clientY;syncMouseAim();if(laserAimHeld){if(isSpecialPrimary()){const accepted=releaseSpecialPrimary();renderer.domElement.dataset.secondaryThrowChord=accepted?(currentWeaponId==='c4'?'rmb-aim-lmb-place':'rmb-aim-lmb-throw'):`rejected:${currentWeaponId}`;if(accepted)renderer.domElement.dataset.secondaryThrowCount=String((+renderer.domElement.dataset.secondaryThrowCount||0)+1);return accepted;}const fired=beginFirearmAtPointer(e,false);if(fired){renderer.domElement.dataset.laserFireChord='rmb-held-lmb-fired';renderer.domElement.dataset.laserFireChordCount=String((+renderer.domElement.dataset.laserFireChordCount||0)+1);}return fired;}if(isSpecialPrimary()){triggerHeld=false;activeGangShotSourceId='';activeNpcShotId='';activeVehicleShotId='';throwAimHeld=true;throwAimStartedAt=performance.now();throwAimKind=currentWeaponId;renderer.domElement.dataset.throwPresses=String((+renderer.domElement.dataset.throwPresses||0)+1);renderer.domElement.dataset.primaryActionRoute=currentWeaponId==='c4'?'c4-place-hold':'throw-charge';updateThrowAim(throwAimStartedAt);return true;}return beginFirearmAtPointer(e,true);};
      addEventListener('pointerdown',e=>{handlePrimaryCombatDown(e);},true);
      // Pointer Events fires pointerdown only when a mouse changes from no
      // buttons to at least one button. Pressing LMB while RMB remains held can
      // therefore produce mousedown without a second pointerdown. Handle that
      // chord explicitly, while suppressing browsers that emit both events.
      // Some embedded Chromium/WebView builds report `buttons === 1` for this
      // mousedown even though the already accepted RMB aim is still held. The
      // local laserAimHeld state is authoritative here; requiring bit 2 made
      // the visible reticle work while silently discarding the LMB shot.
      addEventListener('mousedown',e=>{if(e.button!==0||!laserAimHeld||!isCombatSurfaceEvent(e))return;if(performance.now()-primaryCombatHandledAt<32)return;renderer.domElement.dataset.mouseChordButtons=String(e.buttons);renderer.domElement.dataset.mouseChordFallbacks=String((+renderer.domElement.dataset.mouseChordFallbacks||0)+1);handlePrimaryCombatDown(e);},true);
      // Desktop Chromium can suppress the second pointerdown and, on some
      // systems, also retarget its mousedown while RMB remains held. A normal
      // primary click is still delivered after LMB release, so use it as the
      // last-resort shot route. The timestamp prevents pointerdown/mousedown
      // and click from producing two shots for one physical press.
      addEventListener('click',e=>{if(e.button!==0||!laserAimHeld||!isCombatSurfaceEvent(e))return;if(performance.now()-primaryCombatHandledAt<180)return;renderer.domElement.dataset.heldAimClickFallbacks=String((+renderer.domElement.dataset.heldAimClickFallbacks||0)+1);renderer.domElement.dataset.mouseChordButtons=String(e.buttons);handlePrimaryCombatDown(e);},true);
      addEventListener('pointerup',e=>{if(e.button===0&&throwAimHeld)releaseSpecialPrimary();triggerHeld=false;activeGangShotSourceId='';activeNpcShotId='';activeVehicleShotId='';},true);addEventListener('pointercancel',e=>{if(e.button===0&&throwAimHeld){throwAimHeld=false;throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.throwAim='cancelled';}},true);addEventListener('blur',()=>{triggerHeld=false;throwAimHeld=false;throwAimLine.visible=false;throwLandingRing.visible=false;activeGangShotSourceId='';activeNpcShotId='';activeVehicleShotId='';stopLaserAim('blur');},true);
      if((location.hostname==='127.0.0.1'||location.hostname==='localhost')&&rendererParams.has('previewmousechord'))setTimeout(async()=>{
        const rect=renderer.domElement.getBoundingClientRect(),clientX=rect.left+rect.width*.63,clientY=rect.top+rect.height*.52,before={shots:+renderer.domElement.dataset.confirmedShots||0,laserShots:+renderer.domElement.dataset.laserFireChordCount||0,special:+renderer.domElement.dataset.secondaryThrowCount||0,fallbacks:+renderer.domElement.dataset.mouseChordFallbacks||0};
        renderer.domElement.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,pointerType:'mouse',button:2,buttons:2,clientX,clientY}));
        await new Promise(resolve=>setTimeout(resolve,280));
        // Reproduce the incomplete bitmask observed in Telegram/embedded
        // Chromium: LMB is reported, while the held RMB bit is omitted.
        const clickFallbackQa=rendererParams.get('previewmousechord')==='click';
        renderer.domElement.dispatchEvent(new MouseEvent(clickFallbackQa?'click':'mousedown',{bubbles:true,cancelable:true,button:0,buttons:clickFallbackQa?0:1,clientX,clientY}));
        const after={shots:+renderer.domElement.dataset.confirmedShots||0,laserShots:+renderer.domElement.dataset.laserFireChordCount||0,special:+renderer.domElement.dataset.secondaryThrowCount||0,fallbacks:+renderer.domElement.dataset.mouseChordFallbacks||0,route:renderer.domElement.dataset.primaryActionRoute||'',throwRoute:document.documentElement.dataset.threeThrowableRoute||'',c4Route:document.documentElement.dataset.threeC4Route||'',laser:renderer.domElement.dataset.laserAim||''};
        renderer.domElement.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,pointerType:'mouse',button:2,buttons:0,clientX,clientY}));
        renderer.domElement.dataset.mouseChordQa=JSON.stringify({weapon:currentWeaponId,route:clickFallbackQa?'click':'mousedown',before,after,clickFallbacks:+renderer.domElement.dataset.heldAimClickFallbacks||0});
      },2200);
      function shoot(now){
        if(animationActionLocked){triggerHeld=false;renderer.domElement.dataset.primaryActionRoute='blocked-animation-state';return false;}
        if(isSpecialPrimary()){renderer.domElement.dataset.primaryActionRoute=`blocked-pistol-shot:${currentWeaponId}`;return false;}
        const shotDelay=({smg:92,tommy_gun:105,golden_tommy:105,rifle:150,pistol_gold:190,shotgun:650,sniper:950,rpg:1200}[currentWeaponId]||145);if(now-lastShot<shotDelay)return false;lastShot=now;
        const dir=new THREE.Vector3(aimPoint.x-player.position.x,0,aimPoint.z-player.position.z);if(dir.lengthSq()<.01)dir.set(Math.sin(player.rotation.y),0,Math.cos(player.rotation.y));dir.normalize();
        const worldAngle=Math.atan2(dir.z,dir.x);
        player.rotation.y=Math.atan2(dir.x,dir.z);player.updateMatrixWorld(true);localMuzzleFlash.getWorldPosition(visualMuzzlePoint);const visualMuzzleR=originR+visualMuzzlePoint.z/WORLD_SCALE,visualMuzzleC=originC+visualMuzzlePoint.x/WORLD_SCALE;
        if(bridge){const accepted=(activeGangShotSourceId&&bridge.fireAtGangNpc?.(activeGangShotSourceId,visualMuzzleR,visualMuzzleC))||(activeNpcShotId&&bridge.fireAtNpc?.(activeNpcShotId,visualMuzzleR,visualMuzzleC))||(activeVehicleShotId&&bridge.fireAtVehicle?.(activeVehicleShotId,visualMuzzleR,visualMuzzleC))||bridge.fire(worldAngle,visualMuzzleR,visualMuzzleC),perf=bridge.getShotPerformance?.();if(perf){renderer.domElement.dataset.shotGameplayMs=(+perf.gameplayMs||0).toFixed(2);renderer.domElement.dataset.shotSoundMs=(+perf.soundMs||0).toFixed(2);renderer.domElement.dataset.shotPerf=`game:${renderer.domElement.dataset.shotGameplayMs}:sound:${renderer.domElement.dataset.shotSoundMs}`;}if(!accepted)return;}
        renderer.domElement.dataset.confirmedShots=String((+renderer.domElement.dataset.confirmedShots||0)+1);if(laserAimHeld){laserShotPulseUntil=now+115;renderer.domElement.dataset.laserConfirmedShots=String((+renderer.domElement.dataset.laserConfirmedShots||0)+1);}
        hitHydrantWithShot(player.position,dir,now);
        recoilShotSeq++;recoilSide=(recoilShotSeq&1)?1:-1;
        recoilKick=Math.min((currentWeaponFx.recoil||.8)*3.15,recoilKick+(currentWeaponFx.recoil||.8)*1.18);
        localMuzzleFlash.visible=true;localMuzzleFlash.rotation.z=Math.random()*Math.PI;localMuzzleFlash.scale.setScalar(.82+(currentWeaponFx.flash||1)*.48);for(const child of localMuzzleFlash.children){child.material.color.setHex(currentWeaponFx.color||0xffcf62);child.material.opacity=1;}
        if(bridge){muzzle.color.setHex(currentWeaponFx.color||0xffb14a);muzzle.position.copy(visualMuzzlePoint);muzzle.intensity=74+52*(currentWeaponFx.flash||1);muzzleLife=.105+.035*(currentWeaponFx.flash||1);renderer.domElement.dataset.weaponMuzzleSource=`model:${visualMuzzleR.toFixed(3)},${visualMuzzleC.toFixed(3)}`;return true;}
        const mesh=new THREE.Mesh(new THREE.SphereGeometry(.3,12,8),new THREE.MeshBasicMaterial({color:0xffe08a,depthTest:false}));mesh.renderOrder=30;mesh.position.set(player.position.x+dir.x*1.8,2.75,player.position.z+dir.z*1.8);scene.add(mesh);
        bullets.push({mesh,vel:dir.multiplyScalar(27),life:1.5});muzzle.position.copy(mesh.position);muzzle.intensity=48;muzzleLife=.09;return true;
      }
      const spawnReloadDebris=()=>{
        const family=currentWeaponFx.family,origin=new THREE.Vector3(.55,2.55,.2);player.localToWorld(origin);
        const looseCount=family==='revolver'?(currentWeaponId==='nagan'?1:3):0;
        for(let i=0;i<looseCount;i++){const cartridge=new THREE.Mesh(new THREE.CylinderGeometry(.055,.07,.28,7),new THREE.MeshStandardMaterial({color:i%2?0xd6a638:0xa87425,metalness:.92,roughness:.2}));cartridge.position.copy(origin);cartridge.layers.enable(1);cartridge.castShadow=true;scene.add(cartridge);reloadDebris.push({mesh:cartridge,vel:new THREE.Vector3((Math.random()-.25)*2.2,2.1+Math.random()*1.7,(Math.random()-.5)*2.2),spin:new THREE.Vector3(Math.random()*9,Math.random()*12,Math.random()*10),life:1.35});}
        const boxMagazine=family==='pistol'||family==='heavy-pistol'||family==='gold-pistol'||family==='smg'||family==='rifle'||family==='sniper',drum=family==='tommy'||family==='gold-tommy';
        if(boxMagazine||drum){const droppedMag=new THREE.Mesh(drum?new THREE.CylinderGeometry(.4,.4,.22,14):new THREE.BoxGeometry(.28,.72,.38),family==='gold-pistol'||family==='gold-tommy'?weaponGold:gunDark);droppedMag.position.copy(origin);droppedMag.layers.enable(1);droppedMag.castShadow=true;scene.add(droppedMag);reloadDebris.push({mesh:droppedMag,vel:new THREE.Vector3((Math.random()-.5)*1.2,1.1,(Math.random()-.5)*1.2),spin:new THREE.Vector3(5,8,4),life:1.6});}
        renderer.domElement.dataset.reloadDebrisProfile=looseCount?`loose-rounds:${looseCount}`:boxMagazine?'box-magazine':drum?'drum-magazine':'none';
      };

      const decorateCasinoInterior=data=>{if(data.bizId!=='major_casino')return;const cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,add=(geo,mat,x,y,z)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;},gold=new THREE.MeshStandardMaterial({color:0xd7ad3e,metalness:.55,roughness:.32}),red=new THREE.MeshStandardMaterial({color:0x7d1534,roughness:.65}),felt=new THREE.MeshStandardMaterial({color:0x126442,roughness:.84}),dark=new THREE.MeshStandardMaterial({color:0x1b1422,metalness:.25,roughness:.52}),neon=new THREE.MeshBasicMaterial({color:0xff3bc8});const carpet=add(new THREE.PlaneGeometry(W*.72,H*.72),new THREE.MeshStandardMaterial({color:0x4e0928,roughness:.92}),cx,.08,cz);carpet.rotation.x=-Math.PI/2;for(let row=0;row<2;row++)for(let col=0;col<6;col++){const x=cx-10+col*4,z=cz-8+row*5,slot=add(new THREE.BoxGeometry(2.2,3.1,1.45),dark,x,1.55,z),screen=add(new THREE.PlaneGeometry(1.45,.95),new THREE.MeshBasicMaterial({color:(row+col)%3===0?0xffca3a:(row+col)%3===1?0x45d9ff:0xff4ba8}),x,1.85,z+.731);screen.layers.set(1);}for(const [dx,dz] of [[-9,5],[0,6],[9,5]]){const table=add(new THREE.CylinderGeometry(2.7,2.7,.5,24),felt,cx+dx,.75,cz+dz);for(let k=0;k<6;k++){const a=k*Math.PI/3;add(new THREE.BoxGeometry(.8,.75,.8),red,cx+dx+Math.cos(a)*3.5,.38,cz+dz+Math.sin(a)*3.5);}}const roulette=add(new THREE.CylinderGeometry(2.4,2.4,.6,32),red,cx-7,.85,cz+13),wheel=add(new THREE.TorusGeometry(1.55,.28,10,28),gold,cx-7,1.55,cz+13);wheel.rotation.x=Math.PI/2;const stage=add(new THREE.CylinderGeometry(5.2,5.2,.55,32),red,cx+8,.28,cz+14);for(const sx of [-3.2,0,3.2]){const beam=add(new THREE.BoxGeometry(.25,5,.25),neon,cx+8+sx,2.5,cz+14);beam.rotation.z=sx*.025;}const bar=add(new THREE.BoxGeometry(W*.4,1.6,2.6),gold,cx,.8,cz-H*.3);for(let k=-4;k<=4;k++)add(new THREE.CylinderGeometry(.42,.52,.72,12),red,cx+k*2.4,.36,cz-H*.3+2.2);const gallery=add(new THREE.BoxGeometry(W*.25,.45,H*.42),new THREE.MeshStandardMaterial({color:0x32152c,roughness:.78}),cx-W*.34,4.2,cz);for(let s=0;s<7;s++){const step=add(new THREE.BoxGeometry(3.2,.35,2.1),gold,cx-W*.18+s*.75,.18+s*.35,cz+H*.2-s*.75);step.layers.set(1);}const vip=add(new THREE.BoxGeometry(8,1.2,3),red,cx-W*.3,.6,cz-H*.22),safe=add(new THREE.BoxGeometry(4.5,4.2,3.2),new THREE.MeshStandardMaterial({color:0x5f6971,metalness:.82,roughness:.24}),cx+W*.32,2.1,cz-H*.26);outline(safe);const casinoLight=new THREE.PointLight(0xff35c8,14,42,2);casinoLight.position.set(cx,7,cz);casinoLight.layers.set(1);interiorGroup.add(casinoLight);for(const dx of [-W*.24,W*.24]){const warm=new THREE.PointLight(0xffd08a,22,32,2);warm.position.set(cx+dx,6,cz-H*.12);warm.layers.set(1);interiorGroup.add(warm);}};
      const decorateGrandCasinoInterior=data=>{
        if(data.bizId!=='major_casino')return;
        const layout=data.layout||{},xOf=c=>(c-originC)*WORLD_SCALE,zOf=r=>(r-originR)*WORLD_SCALE,galleryY=1.8*WORLD_SCALE;
        const add=(geo,mat,x,y,z,parent=interiorGroup)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);parent.add(m);return m;};
        const addLight=(light,x,y,z)=>{light.position.set(x,y,z);light.layers.set(1);interiorGroup.add(light);return light;};
        const casinoSignSprite=(text,color)=>{const canvas=document.createElement('canvas');canvas.width=768;canvas.height=180;const c=canvas.getContext('2d');c.fillStyle='rgba(8,5,12,.92)';c.fillRect(10,10,748,160);c.strokeStyle=color;c.lineWidth=10;c.strokeRect(15,15,738,150);c.font='900 72px system-ui';c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';c.strokeStyle='#07070a';c.lineWidth=15;c.strokeText(text,384,92);c.fillStyle='#fff1c7';c.fillText(text,384,92);const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false,toneMapped:false}));sprite.scale.set(Math.max(7.8,Math.min(13,text.length*.72)),2.65,1);sprite.renderOrder=62;sprite.layers.set(1);return sprite;};
        const gold=new THREE.MeshStandardMaterial({color:0xb88a2f,metalness:.72,roughness:.32}),brass=new THREE.MeshStandardMaterial({color:0x876222,metalness:.76,roughness:.3}),marble=new THREE.MeshPhysicalMaterial({color:0x2c1725,roughness:.44,clearcoat:.72,clearcoatRoughness:.22}),velvet=new THREE.MeshStandardMaterial({color:0x57162d,roughness:.84}),felt=new THREE.MeshStandardMaterial({color:0x0d3d29,roughness:.9}),darkWood=new THREE.MeshStandardMaterial({color:0x402319,roughness:.72}),black=new THREE.MeshStandardMaterial({color:0x18191e,metalness:.38,roughness:.5}),steel=new THREE.MeshStandardMaterial({color:0x68747b,metalness:.84,roughness:.28}),wallMat=new THREE.MeshStandardMaterial({color:0x2b1123,roughness:.74}),vaultWall=new THREE.MeshStandardMaterial({color:0x37434a,metalness:.58,roughness:.38}),curtain=new THREE.MeshStandardMaterial({color:0x461024,roughness:.95}),glass=new THREE.MeshPhysicalMaterial({color:0x87cbe4,transparent:true,opacity:.26,transmission:.42,roughness:.06}),cream=new THREE.MeshStandardMaterial({color:0xcbbd9e,roughness:.6});
        const neonMats=[0xff3d92,0x8e5cff,0x24d7ff,0xffbb32].map(color=>new THREE.MeshBasicMaterial({color,toneMapped:false}));
        if(interiorFloor){const oldFloorMaterial=interiorFloor.material;interiorFloor.material=new THREE.MeshStandardMaterial({color:0x251825,roughness:.78,metalness:.06,emissive:0x100812,emissiveIntensity:.18});oldFloorMaterial?.dispose?.();}
        const centerX=xOf(data.width/2),centerZ=zOf(data.height/2),genericTargets=[[centerX-5,.65,centerZ],[centerX+6,.53,centerZ-4],[centerX+7,.28,centerZ+5],[centerX+data.width*WORLD_SCALE*.28,1.6,centerZ-data.height*WORLD_SCALE*.25]];
        for(const child of [...interiorGroup.children]){if(!child.isMesh||child===interiorFloor)continue;if(!genericTargets.some(([x,y,z])=>Math.hypot(child.position.x-x,child.position.y-y,child.position.z-z)<.08))continue;interiorGroup.remove(child);child.geometry?.dispose?.();if(child.material&&!Array.isArray(child.material))child.material.dispose?.();}
        const floorZone=(c,r,w,d,mat,y=.075)=>{const floor=add(new THREE.PlaneGeometry(w*WORLD_SCALE,d*WORLD_SCALE),mat,xOf(c),y,zOf(r));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;return floor;};
        marble.emissive=new THREE.Color(0x160d12);marble.emissiveIntensity=.38;
        const rugMat=new THREE.MeshStandardMaterial({color:0x3a091c,roughness:.97}),vipRug=new THREE.MeshStandardMaterial({color:0x251326,roughness:.96}),serviceFloor=new THREE.MeshStandardMaterial({color:0x182229,roughness:.72,metalness:.08});
        for(const light of interiorGroup.children)if(light.isRectAreaLight)light.intensity=1.55;
        floorZone(22,12,28,16,marble);floorZone(22,15.5,5.3,25,rugMat,.085);floorZone(7.2,24.2,12,8,vipRug,.09);floorZone(40,15.5,6.4,30,serviceFloor,.09);
        for(const c of [19.35,24.65]){const trim=add(new THREE.BoxGeometry(.09,0.06,25*WORLD_SCALE),gold,xOf(c),.13,zOf(15.5));trim.castShadow=false;}
        const makeWall=w=>{const dx=(w.c1-w.c0)*WORLD_SCALE,dz=(w.r1-w.r0)*WORLD_SCALE,len=Math.max(.12,Math.hypot(dx,dz)),height=w.kind==='vault'?5.1:w.kind==='curtain'?4.6:4.05,mat=w.kind==='vault'?vaultWall:w.kind==='curtain'?curtain:wallMat,wall=add(new THREE.BoxGeometry(len,height,.38),mat,xOf((w.c0+w.c1)/2),height/2,zOf((w.r0+w.r1)/2));wall.rotation.y=-Math.atan2(dz,dx);const base=add(new THREE.BoxGeometry(len+.06,.34,.48),w.kind==='vault'?steel:darkWood,wall.position.x,.18,wall.position.z);base.rotation.y=wall.rotation.y;base.castShadow=false;if(w.kind!=='curtain'){const cap=add(new THREE.BoxGeometry(len+.1,.18,.5),gold,wall.position.x,height-.2,wall.position.z);cap.rotation.y=wall.rotation.y;cap.castShadow=false;}return wall;};
        for(const wall of layout.walls||[])makeWall(wall);
        const casinoDoorPortal=(c,r,axis='horizontal')=>{
          const vertical=axis==='vertical',span=2.05*WORLD_SCALE;
          for(const side of [-1,1]){
            const px=xOf(c+(vertical?0:side*1.02)),pz=zOf(r+(vertical?side*1.02:0));
            add(new THREE.CylinderGeometry(.16,.23,4.35,12),gold,px,2.18,pz);
            add(new THREE.CylinderGeometry(.27,.31,.22,12),brass,px,.11,pz);
            add(new THREE.CylinderGeometry(.25,.29,.2,12),brass,px,4.28,pz);
          }
          const lintel=add(new THREE.BoxGeometry(vertical?.42:span+.32,.42,vertical?span+.32:.42),gold,xOf(c),4.28,zOf(r));lintel.castShadow=false;
          const arch=add(new THREE.TorusGeometry(1.02*WORLD_SCALE,.12,9,24,Math.PI),brass,xOf(c),4.22,zOf(r));arch.rotation.z=Math.PI;arch.rotation.y=vertical?Math.PI/2:0;
          const leaf=add(new THREE.BoxGeometry(vertical?.22:1.55*WORLD_SCALE,3.35,vertical?1.55*WORLD_SCALE:.22),darkWood,xOf(c+(vertical?.18:-.2)),1.72,zOf(r+(vertical?.2:.18)));leaf.rotation.y=vertical?-.72:.72;
          for(const y of [1.05,2.35]){const panel=add(new THREE.TorusGeometry(.38,.045,7,18),gold,leaf.position.x,y,leaf.position.z);panel.rotation.y=leaf.rotation.y;panel.castShadow=false;}
          add(new THREE.SphereGeometry(.095,10,7),gold,leaf.position.x+(vertical?.18:.55),1.75,leaf.position.z+(vertical?.55:.18));
        };
        for(const portal of [[8.7,20,'horizontal'],[35.3,20,'horizontal'],[36.6,6.1,'vertical'],[36.6,13,'vertical'],[4.25,14,'horizontal']])casinoDoorPortal(...portal);
        for(const [r,c] of [[25,18.7],[25,25.3],[20,7.2],[20,10.2],[20,33.8],[20,36.8]]){const pillar=add(new THREE.CylinderGeometry(.32,.42,6.5,12),gold,xOf(c),3.25,zOf(r));pillar.castShadow=true;}
        const entranceArch=add(new THREE.TorusGeometry(3.3,.28,10,28,Math.PI),gold,xOf(22),5.2,zOf(25));entranceArch.rotation.x=Math.PI/2;entranceArch.rotation.z=Math.PI;
        const gallery=add(new THREE.BoxGeometry(6.2*WORLD_SCALE,.48,10.5*WORLD_SCALE),new THREE.MeshStandardMaterial({color:0x2d1027,roughness:.78}),xOf(3.8),galleryY,zOf(8.45));gallery.receiveShadow=true;
        const galleryRug=floorZone(3.8,8.45,5.25,9.55,new THREE.MeshStandardMaterial({color:0x721d3e,roughness:.9}),galleryY+.23);
        for(let i=0;i<12;i++){const t=(i+.5)/12,r=18.8-t*5.04,h=(i+1)/12*galleryY,step=add(new THREE.BoxGeometry(3.4*WORLD_SCALE,h,.44*WORLD_SCALE),i%2?darkWood:velvet,xOf(3.8),h/2,zOf(r));step.castShadow=true;const nose=add(new THREE.BoxGeometry(3.42*WORLD_SCALE,.09,.08*WORLD_SCALE),gold,xOf(3.8),h+.045,zOf(r-.21));nose.castShadow=false;}
        const railPost=(c,r,y=galleryY)=>{const post=add(new THREE.CylinderGeometry(.075,.1,2.35,8),brass,xOf(c),y+1.18,zOf(r));post.castShadow=true;return post;};
        for(let r=3.5;r<=13.5;r+=1.4){railPost(6.85,r);const rail=add(new THREE.BoxGeometry(.09,.09,1.4*WORLD_SCALE),gold,xOf(6.85),galleryY+2.25,zOf(r));rail.castShadow=false;}
        for(const c of [1,2.4,5.8,6.7])railPost(c,13.65);
        const casinoChair=(x,z,angle=0,color=velvet)=>{
          add(new THREE.CylinderGeometry(.38,.48,.12,18),brass,x,.08,z);
          add(new THREE.CylinderGeometry(.065,.1,.5,12),steel,x,.34,z);
          const seat=add(new THREE.SphereGeometry(.55,18,10),color,x,.66,z);seat.scale.set(1.3,.38,1.05);seat.rotation.y=angle;
          const backX=x-Math.sin(angle)*.55,backZ=z-Math.cos(angle)*.55,back=add(new THREE.CapsuleGeometry(.34,.62,8,16),color,backX,1.3,backZ);back.scale.set(1.25,1,.38);back.rotation.y=angle;
          const rim=add(new THREE.TorusGeometry(.54,.045,7,20),gold,x,.72,z);rim.rotation.x=Math.PI/2;rim.castShadow=false;
        };
        const roundedCasinoTop=(width,depth,thickness=.35)=>{
          const w=width/2,d=depth/2,r=Math.min(d*.88,w*.22),shape=new THREE.Shape();
          shape.moveTo(-w+r,-d);shape.lineTo(w-r,-d);shape.quadraticCurveTo(w,-d,w,-d+r);shape.lineTo(w,d-r);shape.quadraticCurveTo(w,d,w-r,d);shape.lineTo(-w+r,d);shape.quadraticCurveTo(-w,d,-w,d-r);shape.lineTo(-w,-d+r);shape.quadraticCurveTo(-w,-d,-w+r,-d);
          const geo=new THREE.ExtrudeGeometry(shape,{depth:thickness,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.08,bevelThickness:.06});geo.rotateX(Math.PI/2);return geo;
        };
        const slotMachine=p=>{
          const group=new THREE.Group();group.layers.set(1);group.position.set(xOf(p.c),0,zOf(p.r));interiorGroup.add(group);
          const idx=Math.abs(parseInt(String(p.id).split('_')[1])||0),glow=neonMats[idx%neonMats.length],cabinet=new THREE.MeshPhysicalMaterial({color:[0x39152f,0x241943,0x132f41,0x4b2d12][idx%4],metalness:.42,roughness:.31,clearcoat:.75,clearcoatRoughness:.18});
          add(new THREE.CylinderGeometry(.48*WORLD_SCALE,.58*WORLD_SCALE,.28,18),black,0,.14,0,group);
          const body=add(new THREE.CapsuleGeometry(.49*WORLD_SCALE,1.25,9,18),cabinet,0,1.45,0,group);body.scale.z=.54;
          for(const side of [-1,1])add(new THREE.TorusGeometry(.47*WORLD_SCALE,.045,7,20,Math.PI),gold,0,1.88,side*.04,group).rotation.z=side<0?Math.PI:0;
          const screenFrame=add(new THREE.BoxGeometry(.82*WORLD_SCALE,.86,.13),black,0,1.84,.49*WORLD_SCALE,group);
          const screen=add(new THREE.PlaneGeometry(.72*WORLD_SCALE,.68),cream,0,1.84,.565*WORLD_SCALE,group);screen.castShadow=false;
          for(const sx of [-.31,.31])add(new THREE.BoxGeometry(.035*WORLD_SCALE,.72,.035),gold,sx*WORLD_SCALE,1.84,.58*WORLD_SCALE,group).castShadow=false;
          for(let reel=0;reel<3;reel++){
            const rx=(reel-1)*.215*WORLD_SCALE,reelFace=add(new THREE.BoxGeometry(.17*WORLD_SCALE,.46,.025),reel===idx%3?glow:neonMats[(idx+reel+1)%4],rx,1.84,.585*WORLD_SCALE,group);reelFace.castShadow=false;
            for(const sy of [-.11,.11])add(new THREE.TorusGeometry(.035*WORLD_SCALE,.012*WORLD_SCALE,5,10),black,rx,1.84+sy,.603*WORLD_SCALE,group).castShadow=false;
            const sevenTop=add(new THREE.BoxGeometry(.08*WORLD_SCALE,.035,.018),cream,rx,1.91,.608*WORLD_SCALE,group),sevenStem=add(new THREE.BoxGeometry(.03*WORLD_SCALE,.12,.018),cream,rx+.025*WORLD_SCALE,1.855,.608*WORLD_SCALE,group);sevenTop.castShadow=sevenStem.castShadow=false;
          }
          const payLine=add(new THREE.BoxGeometry(.71*WORLD_SCALE,.025,.025),new THREE.MeshBasicMaterial({color:0xffd859,toneMapped:false}),0,1.84,.616*WORLD_SCALE,group);payLine.castShadow=false;
          const deck=add(new THREE.BoxGeometry(.78*WORLD_SCALE,.2,.46*WORLD_SCALE),gold,0,.9,.35*WORLD_SCALE,group);deck.rotation.x=-.16;
          for(let b=-1;b<=1;b++)add(new THREE.SphereGeometry(.06*WORLD_SCALE,10,7),b?neonMats[(idx+b+4)%4]:glow,b*.18*WORLD_SCALE,.92,.61*WORLD_SCALE,group).castShadow=false;
          const coinSlot=add(new THREE.BoxGeometry(.18*WORLD_SCALE,.055,.035),black,.25*WORLD_SCALE,.72,.565*WORLD_SCALE,group);coinSlot.castShadow=false;
          const tray=add(new THREE.BoxGeometry(.55*WORLD_SCALE,.12,.18*WORLD_SCALE),black,0,.49,.5*WORLD_SCALE,group);tray.rotation.x=-.12;
          const trayLip=add(new THREE.BoxGeometry(.58*WORLD_SCALE,.055,.055),gold,0,.42,.61*WORLD_SCALE,group);trayLip.castShadow=false;
          const lever=add(new THREE.CylinderGeometry(.035,.05,.82,9),steel,.6*WORLD_SCALE,1.25,.08*WORLD_SCALE,group);lever.rotation.z=-.35;
          add(new THREE.SphereGeometry(.12*WORLD_SCALE,12,8),glow,.72*WORLD_SCALE,1.61,.08*WORLD_SCALE,group);
          const crown=add(new THREE.TorusGeometry(.35*WORLD_SCALE,.07,8,22,Math.PI),glow,0,3.05,.06*WORLD_SCALE,group);crown.rotation.z=Math.PI;crown.castShadow=false;
          for(let k=0;k<5;k++){const a=Math.PI*(k/4),bulb=add(new THREE.SphereGeometry(.045*WORLD_SCALE,8,6),neonMats[(idx+k)%4],Math.cos(a)*.35*WORLD_SCALE,3.05+Math.sin(a)*.35*WORLD_SCALE,.09*WORLD_SCALE,group);bulb.castShadow=false;}
          const marquee=add(new THREE.BoxGeometry(.7*WORLD_SCALE,.38,.08),gold,0,2.72,.34*WORLD_SCALE,group),marqueeFace=add(new THREE.PlaneGeometry(.61*WORLD_SCALE,.28),new THREE.MeshBasicMaterial({color:idx%2?0xff356f:0xffcf43,toneMapped:false}),0,2.72,.385*WORLD_SCALE,group);marqueeFace.castShadow=false;
          for(const mx of [-.2,0,.2]){const seven=add(new THREE.BoxGeometry(.12*WORLD_SCALE,.035,.018),cream,mx*WORLD_SCALE,2.78,.405*WORLD_SCALE,group),stem=add(new THREE.BoxGeometry(.035*WORLD_SCALE,.15,.018),cream,(mx+.035)*WORLD_SCALE,2.705,.405*WORLD_SCALE,group);seven.castShadow=stem.castShadow=false;}
          casinoChair(xOf(p.c),zOf(p.r)+1.28*WORLD_SCALE,Math.PI,velvet);
        };
        const gamingTable=(p,label)=>{
          const x=xOf(p.c),z=zOf(p.r),roulette=String(p.id).startsWith('roulette');
          add(new THREE.CylinderGeometry(.46*WORLD_SCALE,.72*WORLD_SCALE,.82,18),darkWood,x,.43,z);
          const top=add(roundedCasinoTop((roulette?4.9:4.6)*WORLD_SCALE,(roulette?2.5:2.35)*WORLD_SCALE,.38),felt,x,1.2,z);top.castShadow=true;
          if(roulette){
            const wheelX=x-1.32*WORLD_SCALE,rail=add(new THREE.TorusGeometry(.93*WORLD_SCALE,.1,9,36),gold,wheelX,1.48,z);rail.rotation.x=Math.PI/2;
            add(new THREE.CylinderGeometry(.82*WORLD_SCALE,.82*WORLD_SCALE,.22,36),black,wheelX,1.48,z);
            add(new THREE.CylinderGeometry(.64*WORLD_SCALE,.64*WORLD_SCALE,.18,36),gold,wheelX,1.63,z);
            for(let k=0;k<18;k++){const a=k/18*Math.PI*2,pocket=add(new THREE.BoxGeometry(.1*WORLD_SCALE,.05,.28*WORLD_SCALE),k%2?velvet:black,wheelX+Math.cos(a)*.53*WORLD_SCALE,1.75,z+Math.sin(a)*.53*WORLD_SCALE);pocket.rotation.y=-a;pocket.castShadow=false;}
            add(new THREE.CylinderGeometry(.05,.12,.5,12),gold,wheelX,1.96,z);add(new THREE.SphereGeometry(.1,12,8),cream,wheelX,2.22,z);
            for(let row=0;row<3;row++)for(let col=0;col<5;col++){
              const cell=add(new THREE.BoxGeometry(.31*WORLD_SCALE,.035,.28*WORLD_SCALE),(row+col)%2?velvet:black,x+(.48+col*.36)*WORLD_SCALE,1.52,z+(-.37+row*.37)*WORLD_SCALE);cell.castShadow=false;
              const pip=add(new THREE.SphereGeometry(.035*WORLD_SCALE,7,5),cream,cell.position.x,1.56,cell.position.z);pip.castShadow=false;
            }
            const zero=add(new THREE.BoxGeometry(.3*WORLD_SCALE,.035,1.02*WORLD_SCALE),felt,x+.28*WORLD_SCALE,1.52,z);zero.castShadow=false;
            for(const dz of [-.38,0,.38])add(new THREE.SphereGeometry(.035*WORLD_SCALE,7,5),gold,x+.28*WORLD_SCALE,1.56,z+dz*WORLD_SCALE).castShadow=false;
          }else{
            const railGeo=roundedCasinoTop(4.82*WORLD_SCALE,2.57*WORLD_SCALE,.12),rail=add(railGeo,gold,x,1.38,z);rail.castShadow=false;
            const inner=add(roundedCasinoTop(4.45*WORLD_SCALE,2.18*WORLD_SCALE,.08),felt,x,1.47,z);inner.castShadow=false;
            for(let k=0;k<7;k++){const card=add(new THREE.PlaneGeometry(.42,.62),cream,x+(-1.45+k*.48)*WORLD_SCALE,1.57,z+.18*WORLD_SCALE);card.rotation.x=-Math.PI/2;card.rotation.z=(k-3)*.055;card.castShadow=false;const suit=add(new THREE.SphereGeometry(.045*WORLD_SCALE,7,5),k%2?velvet:black,card.position.x,1.6,card.position.z);suit.castShadow=false;}
            const shoe=add(new THREE.CapsuleGeometry(.18,.42,6,10),black,x,1.72,z-.72*WORLD_SCALE);shoe.rotation.z=Math.PI/2;
            for(let seat=-2;seat<=2;seat++){const bet=add(new THREE.RingGeometry(.16*WORLD_SCALE,.23*WORLD_SCALE,20),gold,x+seat*.72*WORLD_SCALE,1.535,z+.52*WORLD_SCALE);bet.rotation.x=-Math.PI/2;bet.castShadow=false;}
          }
          for(let k=0;k<13;k++){const a=k/13*Math.PI*2,chip=add(new THREE.CylinderGeometry(.1,.1,.07,12),neonMats[k%4],x+Math.cos(a)*1.55*WORLD_SCALE,1.58,z+Math.sin(a)*.7*WORLD_SCALE);chip.castShadow=false;}
          for(let k=0;k<7;k++){const a=Math.PI*(.05+.9*k/6);casinoChair(x+Math.sin(a)*3.05*WORLD_SCALE,z+Math.cos(a)*2.1*WORLD_SCALE,-a);}
        };
        const casinoSofa=(x,z,width=4.8*WORLD_SCALE,face=0)=>{
          const seat=add(new THREE.CapsuleGeometry(.48,Math.max(.5,width-.96),10,20),velvet,x,.72,z);seat.rotation.z=Math.PI/2;seat.rotation.y=face;seat.scale.z=1.18;
          const backZ=z-Math.cos(face)*.62,backX=x-Math.sin(face)*.62,back=add(new THREE.CapsuleGeometry(.45,Math.max(.5,width-.9),10,20),velvet,backX,1.42,backZ);back.rotation.z=Math.PI/2;back.rotation.y=face;back.scale.z=.48;
          for(const side of [-1,1]){
            const ax=x+Math.cos(face)*side*(width*.5-.38),az=z-Math.sin(face)*side*(width*.5-.38),arm=add(new THREE.CapsuleGeometry(.3,.58,8,14),velvet,ax,.83,az);arm.scale.z=.8;
            add(new THREE.CylinderGeometry(.09,.12,.22,9),gold,ax,.13,az);
          }
          for(let i=-2;i<=2;i++){const cx=x+Math.cos(face)*i*width*.17,cz=z-Math.sin(face)*i*width*.17,cushion=add(new THREE.SphereGeometry(.46,14,9),i%2?cream:velvet,cx,.98,cz);cushion.scale.set(.88,.38,.72);cushion.rotation.y=face;}
          return seat;
        };
        const billiardTable=p=>{
          const group=new THREE.Group();group.layers.set(1);group.position.set(xOf(p.c),+p.elevation*WORLD_SCALE||galleryY,zOf(p.r));interiorGroup.add(group);
          add(new THREE.BoxGeometry(3.65*WORLD_SCALE,.62,2.05*WORLD_SCALE),darkWood,0,.72,0,group);
          add(new THREE.BoxGeometry(3.32*WORLD_SCALE,.18,1.72*WORLD_SCALE),felt,0,1.08,0,group);
          for(const dz of [-.92,.92])add(new THREE.BoxGeometry(3.66*WORLD_SCALE,.18,.2*WORLD_SCALE),gold,0,1.2,dz*WORLD_SCALE,group);
          for(const dx of [-1.72,1.72])add(new THREE.BoxGeometry(.2*WORLD_SCALE,.18,1.7*WORLD_SCALE),gold,dx*WORLD_SCALE,1.2,0,group);
          for(const [px,pz] of [[-1.65,-.82],[0,-.88],[1.65,-.82],[-1.65,.82],[0,.88],[1.65,.82]]){const pocket=add(new THREE.CylinderGeometry(.16*WORLD_SCALE,.2*WORLD_SCALE,.12,16),black,px*WORLD_SCALE,1.29,pz*WORLD_SCALE,group);pocket.castShadow=false;}
          for(const dx of [-1.45,1.45])for(const dz of [-.68,.68])add(new THREE.CylinderGeometry(.12,.18,.78,10),darkWood,dx*WORLD_SCALE,.3,dz*WORLD_SCALE,group);
          for(const dx of [-1.05,-.35,.35,1.05])for(const dz of [-.93,.93]){const diamond=add(new THREE.BoxGeometry(.09*WORLD_SCALE,.035,.06*WORLD_SCALE),cream,dx*WORLD_SCALE,1.31,dz*WORLD_SCALE,group);diamond.rotation.y=Math.PI/4;diamond.castShadow=false;}
          const ballColors=[0xf5df53,0xc83d43,0xf2ede1,0x3f6fd1,0xa842a5,0xe88732,0x25272c];
          for(let i=0;i<10;i++){const row=Math.floor((Math.sqrt(8*i+1)-1)/2),first=row*(row+1)/2,col=i-first;add(new THREE.SphereGeometry(.115*WORLD_SCALE,12,9),new THREE.MeshStandardMaterial({color:ballColors[i%ballColors.length],roughness:.28,metalness:.05}),(-.55+row*.2)*WORLD_SCALE,1.38,(-.22+(col-row/2)*.21)*WORLD_SCALE,group);}
          add(new THREE.SphereGeometry(.12*WORLD_SCALE,12,9),cream,.78*WORLD_SCALE,1.38,.12*WORLD_SCALE,group);
          for(const dz of [-1.12,1.12]){const cue=add(new THREE.CylinderGeometry(.035,.055,3.25*WORLD_SCALE,9),new THREE.MeshStandardMaterial({color:0xd6a769,roughness:.42}),0,1.36,dz*WORLD_SCALE,group);cue.rotation.z=Math.PI/2;}
          const rack=add(new THREE.TorusGeometry(.48*WORLD_SCALE,.035*WORLD_SCALE,6,3),darkWood,-.35*WORLD_SCALE,1.39,-.08*WORLD_SCALE,group);rack.rotation.x=Math.PI/2;rack.rotation.z=Math.PI/6;rack.castShadow=false;
          for(const dx of [-.7,0,.7]){add(new THREE.CylinderGeometry(.035,.035,1.25,8),brass,dx*WORLD_SCALE,3.75,0,group);add(new THREE.CylinderGeometry(.42*WORLD_SCALE,.68*WORLD_SCALE,.52,16),new THREE.MeshStandardMaterial({color:0x17452f,roughness:.74}),dx*WORLD_SCALE,3.05,0,group);const lamp=new THREE.PointLight(0xffd58f,1.25,6,2);lamp.position.set(dx*WORLD_SCALE,2.78,0);lamp.layers.set(1);group.add(lamp);}
        };
        for(const p of layout.props||[]){if(String(p.id).startsWith('slot_'))slotMachine(p);else if(String(p.id).startsWith('roulette_'))gamingTable(p,'ROULETTE');else if(String(p.id).startsWith('card_'))gamingTable(p,'CARDS');else if(String(p.id).startsWith('billiard_'))billiardTable(p);}
        const wheelProp=(layout.props||[]).find(p=>p.id==='wheel');if(wheelProp){
          const x=xOf(wheelProp.c),z=zOf(wheelProp.r),wheel=add(new THREE.CylinderGeometry(3.05*WORLD_SCALE,3.05*WORLD_SCALE,.45,36),velvet,x,5.1,z);wheel.rotation.x=Math.PI/2;
          for(let k=0;k<12;k++){const sector=add(new THREE.RingGeometry(.44*WORLD_SCALE,2.88*WORLD_SCALE,32,1,k*Math.PI/6,Math.PI/6-.018),neonMats[k%4],x,5.1,z+.28);sector.castShadow=false;}
          const rim=add(new THREE.TorusGeometry(3.05*WORLD_SCALE,.18,10,36),gold,x,5.1,z+.32);
          for(let k=0;k<18;k++){const a=k/18*Math.PI*2,peg=add(new THREE.BoxGeometry(.1,2.75*WORLD_SCALE,.12),k%2?gold:cream,x,5.1,z+.5);peg.rotation.z=a;peg.castShadow=false;}
          const hub=add(new THREE.CylinderGeometry(.42,.42,.65,18),gold,x,5.1,z+.48);hub.rotation.x=Math.PI/2;
          for(const sx of [-3.55,3.55]){add(new THREE.CylinderGeometry(.12,.18,7.5,12),gold,x+sx*WORLD_SCALE,3.75,z);add(new THREE.CylinderGeometry(.32,.4,.24,14),brass,x+sx*WORLD_SCALE,.12,z);}
          const pointer=add(new THREE.ConeGeometry(.38*WORLD_SCALE,.85,3),cream,x,9.15,z+.58);pointer.rotation.z=Math.PI;pointer.castShadow=false;
        }
        const desk=(layout.props||[]).find(p=>p.id==='desk');if(desk){const x=xOf(22),z=zOf(2.9),counter=add(new THREE.BoxGeometry(6.2*WORLD_SCALE,1.25,1.15*WORLD_SCALE),darkWood,x,.63,z);for(const c of [19.4,24.6])add(new THREE.CylinderGeometry(.32,.42,4.6,12),gold,xOf(c),2.3,zOf(2.25));const sign=casinoSignSprite('GRAND CASINO','#ffd75d');sign.position.set(x,5.7,z);interiorGroup.add(sign);}
        const stageProp=(layout.props||[]).find(p=>p.id==='dance_stage');if(stageProp){const x=xOf(stageProp.c),z=zOf(stageProp.r),stageTop=add(new THREE.CylinderGeometry(3.2*WORLD_SCALE,3.2*WORLD_SCALE,.55,32),velvet,x,.28,z);for(const sx of [-3.1,3.1]){add(new THREE.BoxGeometry(.22,5.4,.22),steel,x+sx*WORLD_SCALE,2.7,z);for(let h=0;h<3;h++)add(new THREE.SphereGeometry(.22,12,8),neonMats[(h+(sx>0?1:0))%4],x+sx*WORLD_SCALE,1.6+h*1.45,z+.2);}for(const sx of [-1.15,1.15]){add(new THREE.CylinderGeometry(.055,.055,5.25,12),gold,x+sx*WORLD_SCALE,2.9,z+.35*WORLD_SCALE);add(new THREE.CylinderGeometry(.38,.48,.16,18),brass,x+sx*WORLD_SCALE,.63,z+.35*WORLD_SCALE);}add(new THREE.BoxGeometry(7.1*WORLD_SCALE,5.1,.3),curtain,x,2.55,z-1.55*WORLD_SCALE);const show=casinoSignSprite('GRAND SHOW','#ff4ebc');show.position.set(x,5.45,z-1.32*WORLD_SCALE);show.scale.set(8.6,2.0,1);interiorGroup.add(show);}
        const barProp=(layout.props||[]).find(p=>p.id==='bar');if(barProp){const x=xOf(barProp.c),z=zOf(barProp.r),counter=add(new THREE.BoxGeometry(barProp.w*WORLD_SCALE,1.4,barProp.d*WORLD_SCALE),darkWood,x,.72,z),counterTop=add(new THREE.BoxGeometry((barProp.w+.25)*WORLD_SCALE,.18,(barProp.d+.2)*WORLD_SCALE),gold,x,1.48,z);for(let i=-4;i<=4;i++){const stool=add(new THREE.CylinderGeometry(.38,.46,.72,12),velvet,x+i*.92*WORLD_SCALE,.38,z+1.45*WORLD_SCALE);const stem=add(new THREE.CylinderGeometry(.08,.12,.7,8),brass,stool.position.x,.35,stool.position.z);}for(let row=0;row<3;row++){const shelf=add(new THREE.BoxGeometry(7.6*WORLD_SCALE,.12,.35),brass,x,1.9+row*1.05,z-1.5*WORLD_SCALE);for(let i=-7;i<=7;i++){const bottle=add(new THREE.CylinderGeometry(.09,.13,.58,8),neonMats[(i+row+16)%4],x+i*.47*WORLD_SCALE,2.24+row*1.05,z-1.36*WORLD_SCALE);}}}
        const vipSofa=(layout.props||[]).find(p=>p.id==='vip_sofa_s');
        const vipTable=(layout.props||[]).find(p=>p.id==='vip_table');if(vipTable){
          const x=xOf(vipTable.c),z=zOf(vipTable.r);
          add(new THREE.CylinderGeometry(.34*WORLD_SCALE,.56*WORLD_SCALE,.78,18),brass,x,.4,z);
          const table=add(new THREE.CylinderGeometry(1.8*WORLD_SCALE,1.8*WORLD_SCALE,.32,32),darkWood,x,1.02,z),rim=add(new THREE.TorusGeometry(1.78*WORLD_SCALE,.09,8,32),gold,x,1.2,z);rim.rotation.x=Math.PI/2;
          if(vipSofa)casinoSofa(xOf(vipSofa.c),zOf(vipSofa.r),(vipSofa.w||4.7)*WORLD_SCALE,0);
          for(let i=0;i<5;i++){const glassCup=add(new THREE.CylinderGeometry(.09,.15,.42,10),glass,x+(i-2)*.42*WORLD_SCALE,1.38,z);glassCup.castShadow=false;add(new THREE.TorusGeometry(.08,.018,5,10),gold,glassCup.position.x,1.58,z).rotation.x=Math.PI/2;}
          const iceBucket=add(new THREE.CylinderGeometry(.34,.45,.52,18),steel,x,1.36,z-.58*WORLD_SCALE);iceBucket.castShadow=true;
        }
        const champagne=(layout.props||[]).find(p=>p.id==='champagne');if(champagne){const x=xOf(champagne.c),z=zOf(champagne.r),stand=add(new THREE.CylinderGeometry(1.05*WORLD_SCALE,1.2*WORLD_SCALE,.75,20),gold,x,.38,z);for(let i=0;i<6;i++){const a=i/6*Math.PI*2,bottle=add(new THREE.CylinderGeometry(.1,.16,.82,10),new THREE.MeshPhysicalMaterial({color:0x1d5634,roughness:.2,clearcoat:1}),x+Math.cos(a)*.62*WORLD_SCALE,1.17,z+Math.sin(a)*.62*WORLD_SCALE);}}
        const office=(layout.props||[]).find(p=>p.id==='office');if(office){
          const x=xOf(office.c),z=zOf(office.r),top=add(roundedCasinoTop(5.9*WORLD_SCALE,2.05*WORLD_SCALE,.28),darkWood,x,1.38,z);top.castShadow=true;
          for(const dx of [-2.35,2.35]){add(new THREE.CylinderGeometry(.16,.22,1.05,12),gold,x+dx*WORLD_SCALE,.54,z-.55*WORLD_SCALE);const drawers=add(new THREE.CapsuleGeometry(.34,1.05,7,12),darkWood,x+dx*WORLD_SCALE,.64,z+.45*WORLD_SCALE);drawers.rotation.z=Math.PI/2;drawers.scale.z=.55;for(const y of [.45,.76,.98])add(new THREE.TorusGeometry(.12,.025,5,10,Math.PI),gold,drawers.position.x,y,z+.85*WORLD_SCALE).rotation.z=Math.PI;}
          casinoChair(x,z+1.55*WORLD_SCALE,Math.PI,velvet);
          casinoSofa(x,z-2.25*WORLD_SCALE,3.9*WORLD_SCALE,0);
          const lampStem=add(new THREE.CylinderGeometry(.05,.08,1.25,9),brass,x-1.75*WORLD_SCALE,2.02,z);lampStem.rotation.z=-.38;const shade=add(new THREE.ConeGeometry(.42,.55,18,1,true),new THREE.MeshStandardMaterial({color:0x1b5639,roughness:.55}),x-2.0*WORLD_SCALE,2.58,z);shade.rotation.x=Math.PI;
          for(let i=-3;i<=3;i++){const frame=add(new THREE.BoxGeometry(.48*WORLD_SCALE,3.75,.82*WORLD_SCALE),darkWood,x+i*.58*WORLD_SCALE,2.05,z+2.15*WORLD_SCALE);for(let row=0;row<4;row++)for(let b=0;b<3;b++)add(new THREE.BoxGeometry(.1*WORLD_SCALE,.48,.46*WORLD_SCALE),new THREE.MeshStandardMaterial({color:[0x6d2f35,0x294a62,0x7c6331][(i+row+b+9)%3],roughness:.72}),frame.position.x+(b-1)*.13*WORLD_SCALE,.52+row*.82,z+1.75*WORLD_SCALE);}
        }
        const security=(layout.props||[]).find(p=>p.id==='security');if(security){
          const x=xOf(security.c),z=zOf(security.r),consoleTop=add(roundedCasinoTop(5.25*WORLD_SCALE,1.95*WORLD_SCALE,.26),black,x,1.28,z);consoleTop.castShadow=true;
          for(const dx of [-2,2])add(new THREE.CylinderGeometry(.16,.23,1.05,10),steel,x+dx*WORLD_SCALE,.54,z);
          for(const dx of [-1.65,0,1.65]){
            const stand=add(new THREE.CylinderGeometry(.055,.08,.7,8),steel,x+dx*WORLD_SCALE,1.72,z+.5*WORLD_SCALE),frame=add(new THREE.BoxGeometry(1.42*WORLD_SCALE,1.08,.16),steel,x+dx*WORLD_SCALE,2.25,z+.76*WORLD_SCALE),screen=add(new THREE.PlaneGeometry(1.25*WORLD_SCALE,.88),new THREE.MeshBasicMaterial({color:dx?0x3b9ec4:0x86d46b}),x+dx*WORLD_SCALE,2.25,z+.86*WORLD_SCALE);screen.rotation.x=-.08;screen.castShadow=false;
            for(let row=0;row<2;row++)for(let col=0;col<3;col++)add(new THREE.SphereGeometry(.035*WORLD_SCALE,7,5),row?neonMats[(col+2)%4]:neonMats[col],x+dx*WORLD_SCALE+(col-1)*.18*WORLD_SCALE,1.38+row*.15,z+.56*WORLD_SCALE).castShadow=false;
          }
          casinoChair(x,z-1.45*WORLD_SCALE,0,black);
          for(const c of [37.3,42.7]){add(new THREE.CylinderGeometry(.16,.2,3.8,10),steel,xOf(c),1.9,z);add(new THREE.SphereGeometry(.18,12,8),neonMats[c<40?2:0],xOf(c),3.9,z).castShadow=false;}
        }
        const vaultR=23.45,vaultC=36.58,vaultDoor=add(new THREE.CylinderGeometry(2.45,2.45,.7,32),steel,xOf(vaultC),3.05,zOf(vaultR));vaultDoor.rotation.z=Math.PI/2;const vaultRing=add(new THREE.TorusGeometry(1.45,.17,10,28),gold,xOf(vaultC)-.38,3.05,zOf(vaultR));vaultRing.rotation.y=Math.PI/2;for(let k=0;k<8;k++){const a=k/8*Math.PI*2,bolt=add(new THREE.SphereGeometry(.12,9,7),brass,xOf(vaultC)-.43,3.05+Math.sin(a)*1.9,zOf(vaultR)+Math.cos(a)*1.9);}
        for(const safe of layout.safes||[]){const x=xOf(safe.c),z=zOf(safe.r),body=add(new THREE.BoxGeometry(2.25*WORLD_SCALE,3.4,2*WORLD_SCALE),safe.opened?black:steel,x,1.7,z);outline(body);const dial=add(new THREE.TorusGeometry(.48,.1,8,20),safe.opened?black:gold,x,1.95,z+1.02*WORLD_SCALE);dial.rotation.x=Math.PI/2;}
        const cashX=xOf(40),cashZ=zOf(27);for(const c of [38.1,41.9])for(let r=25.3;r<=29.2;r+=1.3)add(new THREE.CylinderGeometry(.055,.075,3.5,7),steel,xOf(c),1.75,zOf(r));for(const r of [25.3,29.2])for(let c=38.2;c<=41.8;c+=1.15){const bar=add(new THREE.BoxGeometry(1.15*WORLD_SCALE,.07,.07),steel,xOf(c),3.45,zOf(r));bar.castShadow=false;}const cashDesk=add(new THREE.BoxGeometry(3.1*WORLD_SCALE,1.1,1.25*WORLD_SCALE),darkWood,cashX,.56,cashZ);for(let i=0;i<18;i++){const ingot=add(new THREE.BoxGeometry(.42,.15,.2),gold,cashX+((i%6)-2.5)*.46,.72+Math.floor(i/6)*.17,cashZ-.32);ingot.rotation.y=(i%2)*.12;}
        for(let c=19.4;c<=24.6;c+=1.3){const post=add(new THREE.CylinderGeometry(.07,.1,1.25,9),brass,xOf(c),.63,zOf(27.2));if(c<24){const rope=add(new THREE.BoxGeometry(1.3*WORLD_SCALE,.09,.09),velvet,xOf(c+.65),.92,zOf(27.2));rope.castShadow=false;}}
        // Парадный вестибюль больше не выглядит пустым шаблоном: две стойки,
        // гардероб, вазоны и арт-деко светильники формируют путь к главному залу.
        for(const [c,side] of [[15.7,-1],[28.3,1]]){add(new THREE.BoxGeometry(4.1*WORLD_SCALE,.18,1.05*WORLD_SCALE),marble,xOf(c),1.18,zOf(28));add(new THREE.BoxGeometry(4.14*WORLD_SCALE,.07,1.09*WORLD_SCALE),gold,xOf(c),1.31,zOf(28));add(new THREE.BoxGeometry(3.7*WORLD_SCALE,1.08,.92*WORLD_SCALE),darkWood,xOf(c),.55,zOf(28));for(const dc of [-1.35,1.35])add(new THREE.CylinderGeometry(.24,.34,1.25,10),brass,xOf(c+dc),.62,zOf(28));const lamp=add(new THREE.SphereGeometry(.42,14,9),new THREE.MeshBasicMaterial({color:0xffd486,toneMapped:true}),xOf(c),2.35,zOf(28));lamp.scale.y=.48;}
        for(const [c,r] of [[14.4,25.9],[29.6,25.9],[14.4,30],[29.6,30]]){add(new THREE.CylinderGeometry(.55,.76,.88,12),new THREE.MeshStandardMaterial({color:0x6c3828,roughness:.86}),xOf(c),.44,zOf(r));for(let k=0;k<6;k++){const leaf=add(new THREE.SphereGeometry(.4,10,7),new THREE.MeshStandardMaterial({color:k%2?0x2f6c43:0x244f35,roughness:.92}),xOf(c)+Math.sin(k*2.1)*.42,1.12+(k%3)*.28,zOf(r)+Math.cos(k*1.7)*.36);leaf.scale.y=1.5;}}
        for(let c=1;c<data.width;c+=5){add(new THREE.CylinderGeometry(.17,.23,6.4,10),gold,xOf(c),3.2,zOf(.45));add(new THREE.CylinderGeometry(.17,.23,6.4,10),gold,xOf(c),3.2,zOf(data.height-.45));}
        for(let r=4;r<data.height-2;r+=5){add(new THREE.CylinderGeometry(.17,.23,6.2,10),gold,xOf(.45),3.1,zOf(r));add(new THREE.CylinderGeometry(.17,.23,6.2,10),gold,xOf(data.width-.45),3.1,zOf(r));}
        const roomSign=(text,c,r,y,color)=>{const sign=casinoSignSprite(text,color);sign.position.set(xOf(c),y,zOf(r));sign.scale.multiplyScalar(.56);interiorGroup.add(sign);return sign;};
        roomSign('VIP LOUNGE',7.2,20.35,4.8,'#ffd75d');roomSign('VIP BILLIARDS',3.75,13.25,galleryY+4.2,'#75e0ad');roomSign('SECURITY',40,9.25,4.65,'#5bd4ff');roomSign('CASHIER',40,20.35,4.8,'#ffd75d');roomSign('VAULT',36.45,23.45,5.9,'#d9e7ef');roomSign('GRAND HALL',22,19.7,5.1,'#ffcf63');
        for(const [c,r] of [[12,14],[22,14],[32,14],[22,7],[7.2,23]]){const chain=add(new THREE.CylinderGeometry(.045,.045,2.1,7),brass,xOf(c),7.6,zOf(r)),lamp=add(new THREE.SphereGeometry(.62,16,10),new THREE.MeshBasicMaterial({color:0xffd9a0,toneMapped:true}),xOf(c),6.4,zOf(r));lamp.scale.y=.48;addLight(new THREE.PointLight(0xffc98a,3.1,19,2),xOf(c),6.2,zOf(r));}
        for(const [c,r,color] of [[10,6,0xb46a85],[34,6,0x668e9e],[22,11,0x756c91],[31.5,23.5,0x9a835b]])addLight(new THREE.PointLight(color,.32,8,2),xOf(c),4.8,zOf(r));
        const hallFill=new THREE.RectAreaLight(0xffd7b0,1.25,30*WORLD_SCALE,17*WORLD_SCALE);hallFill.position.set(xOf(22),9.5,zOf(13));hallFill.lookAt(xOf(22),0,zOf(13));hallFill.layers.set(1);interiorGroup.add(hallFill);
        // Premium detailing pass: static geometry only, built once when the casino opens.
        const mirrorMat=new THREE.MeshPhysicalMaterial({color:0xb7d8df,metalness:.72,roughness:.08,clearcoat:1}),cardMat=new THREE.MeshBasicMaterial({color:0xf4ead4,toneMapped:true});
        for(const c of [19.72,24.28])add(new THREE.BoxGeometry(.07,.045,24.5*WORLD_SCALE),brass,xOf(c),.145,zOf(15.5)).castShadow=false;
        for(const r of [5.5,12,18.5,25]){const medallion=add(new THREE.RingGeometry(.75*WORLD_SCALE,1.02*WORLD_SCALE,24),gold,xOf(22),.16,zOf(r));medallion.rotation.x=-Math.PI/2;medallion.castShadow=false;}
        for(const [c,r,rot] of [[10,.62,0],[16,.62,0],[28,.62,0],[34,.62,0],[.62,7,Math.PI/2],[.62,13,Math.PI/2],[43.38,6,Math.PI/2],[43.38,13,Math.PI/2]]){const panel=add(new THREE.PlaneGeometry(3.6*WORLD_SCALE,2.25),mirrorMat,xOf(c),2.35,zOf(r));panel.rotation.y=rot;for(const y of [1.15,3.55]){const bar=add(new THREE.BoxGeometry(3.9*WORLD_SCALE,.14,.16),gold,panel.position.x,y,panel.position.z);bar.rotation.y=rot;bar.castShadow=false;}}
        for(const p of layout.props||[]){
          const id=String(p.id||''),x=xOf(p.c),z=zOf(p.r);
          if(id.startsWith('slot_')){const lever=add(new THREE.CylinderGeometry(.055,.055,.78,8),brass,x+.68*WORLD_SCALE,1.28,z+.28*WORLD_SCALE);lever.rotation.z=-.28;add(new THREE.SphereGeometry(.13,10,8),neonMats[Math.abs(parseInt(id.split('_')[1])||0)%neonMats.length],x+.78*WORLD_SCALE,1.64,z+.28*WORLD_SCALE);add(new THREE.CylinderGeometry(.34,.4,.54,12),velvet,x,.28,z+1.18*WORLD_SCALE);}
          if(id.startsWith('card_')){for(let k=0;k<5;k++){const card=add(new THREE.PlaneGeometry(.45,.66),cardMat,x+(-1.1+k*.55)*WORLD_SCALE,1.43,z+.22*WORLD_SCALE);card.rotation.x=-Math.PI/2;card.rotation.z=(k-2)*.08;}}
        }
        if(stageProp){const x=xOf(stageProp.c),z=zOf(stageProp.r);add(new THREE.TorusGeometry(3.18*WORLD_SCALE,.13,8,32),gold,x,.58,z);for(let k=0;k<11;k++){const a=Math.PI*(.08+.84*k/10),bulb=add(new THREE.SphereGeometry(.1,8,6),neonMats[k%4],x+Math.cos(a)*3.05*WORLD_SCALE,.72,z+Math.sin(a)*3.05*WORLD_SCALE);bulb.castShadow=false;}}
        if(barProp){const x=xOf(barProp.c),z=zOf(barProp.r),mirror=add(new THREE.PlaneGeometry(7.5*WORLD_SCALE,3.25),mirrorMat,x,3.34,z-1.7*WORLD_SCALE);mirror.rotation.y=0;for(let i=-3;i<=3;i++){const glassCup=add(new THREE.CylinderGeometry(.08,.13,.4,10),glass,x+i*.65*WORLD_SCALE,1.84,z+.25*WORLD_SCALE);glassCup.castShadow=false;}}
        if(vipTable){const x=xOf(vipTable.c),z=zOf(vipTable.r);add(new THREE.TorusGeometry(1.8*WORLD_SCALE,.1,8,24),gold,x,1.03,z);for(const dz of [-1.7,1.7])for(const dx of [-1.55,0,1.55])add(new THREE.BoxGeometry(1.2*WORLD_SCALE,.28,.72*WORLD_SCALE),cream,x+dx*WORLD_SCALE,1.42,z+dz*WORLD_SCALE);}
        renderer.domElement.dataset.casinoWalls=String((layout.walls||[]).length);renderer.domElement.dataset.casinoProps=String((layout.props||[]).length);renderer.domElement.dataset.casinoDoors='5:arched-open-panels';renderer.domElement.dataset.casinoVolumetricProps='slot-reels-buttons-coin-trays-levers-roulette-wheel-betting-grid-card-suits-betting-rings-billiards-pockets-cues-stairs-show-poles';renderer.domElement.dataset.casinoPremium='server-layout-v7-readable-games';
      };
      const decorateApartmentInterior=data=>{
        if(!(data.kind==='building'&&data.type==='generic'&&!data.bizId))return false;
        const W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,apt=data.apartment||{},lvl=apt.levels||{},repair=Math.max(0,+lvl.repair||0),identity=String(apt.key||`${data.seed||0}:${data.width}x${data.height}`),seed=[...identity].reduce((h,ch)=>Math.imul(h^ch.charCodeAt(0),16777619)>>>0,2166136261),layoutVariant=seed%12,rich=repair>=2;
        const livingSlots=[[0,0],[.018,-.012],[-.016,.014],[.026,.006],[-.024,-.008],[.01,.02],[-.008,-.02],[.022,-.016],[-.02,.018],[.006,-.01],[-.012,.008],[.014,.012]],diningSlots=[[0,0],[.014,.008],[-.012,-.006],[.018,-.008],[-.016,.006],[.008,-.012],[-.006,.012],[.012,-.004],[-.01,.004],[.004,.01],[-.004,-.01],[.016,0]],bedSlots=[[0,0],[.01,.008],[-.008,-.006],[.012,-.008],[-.01,.006],[.006,-.012],[-.004,.012],[.009,-.004],[-.007,.004],[.003,.01],[-.003,-.01],[.011,0]];
        const [livingDxF,livingDzF]=livingSlots[layoutVariant],[diningDxF,diningDzF]=diningSlots[layoutVariant],[bedDxF,bedDzF]=bedSlots[layoutVariant],livingDx=livingDxF*W,livingDz=livingDzF*H,diningDx=diningDxF*W,diningDz=diningDzF*H,bedDx=bedDxF*W,bedDz=bedDzF*H;
        const add=(geo,mat,x,y,z,parent=interiorGroup)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);parent.add(m);return m;},floorZone=(x,z,w,d,mat,y=.075)=>{const m=add(new THREE.PlaneGeometry(w,d),mat,x,y,z);m.rotation.x=-Math.PI/2;m.receiveShadow=true;return m;};
        const wood=new THREE.MeshStandardMaterial({color:rich?0x74472d:0x543522,roughness:.72}),darkWood=new THREE.MeshStandardMaterial({color:0x2b1b17,roughness:.62}),wall=new THREE.MeshStandardMaterial({color:rich?0xb7a58d:0x827463,roughness:.9}),trim=new THREE.MeshStandardMaterial({color:rich?0xc09b57:0x66523c,metalness:rich?.28:.08,roughness:.56}),fabric=new THREE.MeshStandardMaterial({color:[0x31536a,0x5b2932,0x3f5b43][seed%3],roughness:.95}),cream=new THREE.MeshStandardMaterial({color:rich?0xe6dcc5:0xc8bda8,roughness:.88}),linen=new THREE.MeshStandardMaterial({color:0xe6dfd0,roughness:1}),tile=new THREE.MeshStandardMaterial({color:rich?0xb8c7c4:0x788d8b,roughness:.5}),steel=new THREE.MeshStandardMaterial({color:0x667078,metalness:.82,roughness:.25}),black=new THREE.MeshStandardMaterial({color:0x111419,metalness:.35,roughness:.4}),glass=new THREE.MeshPhysicalMaterial({color:0xa8ddec,transparent:true,opacity:.42,roughness:.08,transmission:.25}),green=new THREE.MeshStandardMaterial({color:0x315e3b,roughness:.92}),terracotta=new THREE.MeshStandardMaterial({color:0x8c4931,roughness:.9}),brass=new THREE.MeshStandardMaterial({color:rich?0xd5ad57:0x9b7841,metalness:.72,roughness:.28}),stone=new THREE.MeshStandardMaterial({color:rich?0xd8d0c2:0xaaa092,roughness:.42}),rugEdge=new THREE.MeshStandardMaterial({color:rich?0xd2aa60:0x8c6942,roughness:.7}),screenGlow=new THREE.MeshBasicMaterial({color:0x284b62,toneMapped:true});
        const technicalGrid=interiorGroup.children.find(o=>o.type==='GridHelper');if(technicalGrid){interiorGroup.remove(technicalGrid);technicalGrid.geometry?.dispose?.();technicalGrid.material?.dispose?.();}
        if(interiorFloor){const old=interiorFloor.material;interiorFloor.material=wood;old?.dispose?.();}
        const northZ=(.1-originR)*WORLD_SCALE+.39,leftX=(.1-originC)*WORLD_SCALE+.39,backZ=(data.height-.1-originR)*WORLD_SCALE;
        for(let i=0;i<7;i++){add(new THREE.BoxGeometry(W/7-.22,2.15,.18),wall,cx-W*.43+i*W/7,2.0,northZ);add(new THREE.BoxGeometry(W/7-.1,.12,.24),trim,cx-W*.43+i*W/7,.82,northZ+.05).castShadow=false;}
        for(let i=0;i<5;i++){add(new THREE.BoxGeometry(.18,2.15,H/5-.22),wall,leftX,2.0,cz-H*.4+i*H/5);add(new THREE.BoxGeometry(.24,.12,H/5-.1),trim,leftX+.05,.82,cz-H*.4+i*H/5).castShadow=false;}
        for(const dx of [-2.65,2.65])add(new THREE.BoxGeometry(.34,4.2,.55),trim,cx+dx,2.1,backZ-.45);add(new THREE.BoxGeometry(5.65,.32,.55),trim,cx,4.05,backZ-.45);floorZone(cx,backZ-1.15,5.2,2.25,new THREE.MeshStandardMaterial({color:0x39231f,roughness:1}),.09);
        // Room zoning: living room in front, kitchen left, bedroom and bath at the back.
        floorZone(cx-W*.18,cz+H*.12,W*.53,H*.42,new THREE.MeshStandardMaterial({color:rich?0x6b2430:0x49323a,roughness:1}),.085);
        floorZone(cx-W*.28,cz-H*.27,W*.4,H*.32,new THREE.MeshStandardMaterial({color:0x6a5037,roughness:.96}),.082);
        floorZone(cx+W*.3,cz-H*.28,W*.27,H*.3,tile,.084);
        // Architectural finish: crown moulding, skirting and a bordered living-room rug.
        for(const [x,z,w,d] of [[cx,northZ+.15,W-.9,.18],[leftX+.15,cz,.18,H-.9],[cx,backZ-.15,W-.9,.18]]){add(new THREE.BoxGeometry(w,.2,d),trim,x,4.82,z).castShadow=false;add(new THREE.BoxGeometry(w,.24,d),darkWood,x,.24,z).castShadow=false;}
        const rugX=cx-W*.18,rugZ=cz+H*.12,rugW=W*.53,rugD=H*.42;
        for(const [x,z,w,d] of [[rugX,rugZ-rugD/2+.16,rugW-.18,.18],[rugX,rugZ+rugD/2-.16,rugW-.18,.18],[rugX-rugW/2+.16,rugZ,.18,rugD-.18],[rugX+rugW/2-.16,rugZ,.18,rugD-.18]])floorZone(x,z,w,d,rugEdge,.105);
        const wallPart=(x,z,w,d,h=3.4)=>{const m=add(new THREE.BoxGeometry(w,h,d),wall,x,h/2,z);add(new THREE.BoxGeometry(w+.08,.13,d+.08),trim,x,.12,z).castShadow=false;return m;};
        wallPart(cx,cz-H*.08,W*.2,.26);wallPart(cx+W*.36,cz-H*.08,W*.25,.26);wallPart(cx+W*.18,cz-H*.3,.26,H*.32);
        // Windows, curtains and warm pools of light.
        for(const dx of [-W*.25,W*.2]){const pane=add(new THREE.PlaneGeometry(5.2,2.8),glass,cx+dx,3.25,(.32-originR)*WORLD_SCALE+.38);pane.rotation.y=Math.PI;for(const sx of [-2.85,2.85])add(new THREE.BoxGeometry(.45,3.6,.34),fabric,cx+dx+sx,3.05,pane.position.z+.2);add(new THREE.BoxGeometry(6.4,.16,.25),trim,cx+dx,4.95,pane.position.z+.15);}
        // Living room: articulated sofa, armchairs, coffee table, television and books.
        const sofaX=cx-W*.24+livingDx,sofaZ=cz+H*.2+livingDz,livingCenterX=cx-W*.02+livingDx*.45,livingCenterZ=cz+H*.08+livingDz*.55;add(new THREE.BoxGeometry(7.4,.78,2.8),fabric,sofaX,.48,sofaZ);add(new THREE.BoxGeometry(7.4,1.8,.62),fabric,sofaX,1.3,sofaZ-1.1);for(const dx of [-3.45,3.45])add(new THREE.BoxGeometry(.62,1.35,2.75),fabric,sofaX+dx,.78,sofaZ);for(const dx of [-2.25,0,2.25])add(new THREE.BoxGeometry(2.05,.35,2.02),cream,sofaX+dx,.96,sofaZ+.2);
        for(const dz of [-3.2,3.2]){const chair=add(new THREE.BoxGeometry(2.2,1.45,2.15),fabric,livingCenterX,.74,sofaZ+dz);chair.rotation.y=dz>0?-.38:.38;}
        add(new THREE.BoxGeometry(5.2,.34,2.55),rich?glass:wood,livingCenterX,.92,livingCenterZ);for(const dx of [-2.1,2.1])for(const dz of [-.92,.92])add(new THREE.CylinderGeometry(.1,.14,.82,8),trim,livingCenterX+dx,.43,livingCenterZ+dz);
        const tvZ=cz-H*.035;add(new THREE.BoxGeometry(6.1,1.05,1.35),darkWood,cx-W*.23,.55,tvZ);const tv=add(new THREE.BoxGeometry(5.3,3.05,.34),black,cx-W*.23,2.35,tvZ+.38);add(new THREE.PlaneGeometry(4.65,2.36),screenGlow,tv.position.x,2.38,tv.position.z+.18);add(new THREE.BoxGeometry(5.8,.12,.8),brass,tv.position.x,.16,tv.position.z+.15).castShadow=false;
        for(let i=0;i<5;i++){const shelf=add(new THREE.BoxGeometry(.72,3.9,1.35),darkWood,cx-W*.43+i*.78,1.95,cz-H*.035);for(let b=0;b<4;b++)add(new THREE.BoxGeometry(.5,.55,.55),new THREE.MeshStandardMaterial({color:[0x74383b,0x2f5264,0x817047,0x496448][(i+b)%4],roughness:.9}),shelf.position.x,.45+b*.82,shelf.position.z+.7);}
        // Kitchen: full cabinetry, worktop, cooker, sink, fridge and dining nook.
        const kitchenZ=cz-H*.39;for(let i=0;i<6;i++){const cabinet=add(new THREE.BoxGeometry(2.25,1.7,1.7),i===2?black:cream,cx-W*.37+i*2.27,.86,kitchenZ);if(i!==2)add(new THREE.BoxGeometry(.08,.42,.08),brass,cabinet.position.x+.62,1.03,kitchenZ+.88).castShadow=false;}add(new THREE.BoxGeometry(13.7,.24,2.02),rich?stone:darkWood,cx-W*.2,1.82,kitchenZ);
        add(new THREE.BoxGeometry(13.4,1.35,.16),new THREE.MeshStandardMaterial({color:rich?0x6f8584:0x665c50,roughness:.38}),cx-W*.2,2.72,kitchenZ-.98);
        for(let i=0;i<6;i++)add(new THREE.BoxGeometry(2.08,1.35,1.02),cream,cx-W*.37+i*2.27,3.72,kitchenZ-.42);
        const sink=add(new THREE.BoxGeometry(2.15,.15,1.18),steel,cx-W*.27,1.98,kitchenZ);const tap=add(new THREE.TorusGeometry(.42,.08,8,14,Math.PI),steel,sink.position.x,2.48,kitchenZ);tap.rotation.y=Math.PI/2;
        for(const dx of [-.58,.58])for(const dz of [-.38,.38]){const hob=add(new THREE.TorusGeometry(.3,.055,7,14),black,cx-W*.1+dx,2.02,kitchenZ+dz);hob.rotation.x=Math.PI/2;}
        add(new THREE.BoxGeometry(2.6,4.4,2),steel,cx-W*.47,2.2,kitchenZ);add(new THREE.BoxGeometry(2.2,.16,1.7),black,cx-W*.47,2.35,kitchenZ+1.02);
        const diningX=cx-W*.17+diningDx,diningZ=cz-H*.18+diningDz,diningTurn=layoutVariant%4===1||layoutVariant%4===3?Math.PI/2:0,diningPoint=(lx,lz)=>({x:diningX+lx*Math.cos(diningTurn)-lz*Math.sin(diningTurn),z:diningZ+lx*Math.sin(diningTurn)+lz*Math.cos(diningTurn)}),diningTable=add(new THREE.BoxGeometry(5.3,.34,3),wood,diningX,.92,diningZ);diningTable.rotation.y=-diningTurn;for(const dx of [-2.7,2.7])for(const dz of [-1.05,1.05]){const p=diningPoint(dx,dz),chair=add(new THREE.BoxGeometry(1.1,1.45,1.1),fabric,p.x,.72,p.z);chair.rotation.y=-diningTurn+(dx>0?Math.PI/2:-Math.PI/2);}for(const dx of [-1.55,0,1.55]){const p=diningPoint(dx,0),g=diningPoint(dx+.42,-.25),plate=add(new THREE.CylinderGeometry(.38,.38,.055,18),cream,p.x,1.13,p.z);plate.scale.z=.72;plate.rotation.y=-diningTurn;add(new THREE.CylinderGeometry(.08,.12,.42,10),glass,g.x,1.34,g.z);}
        // Bedroom: raised bed with separate mattress, pillows, blanket, nightstands and wardrobe.
        const bedX=cx+W*.29+bedDx,bedZ=cz+H*.17+bedDz;add(new THREE.BoxGeometry(7.1,.62,7.2),darkWood,bedX,.34,bedZ);add(new THREE.BoxGeometry(6.65,.7,6.75),linen,bedX,.84,bedZ);add(new THREE.BoxGeometry(6.65,.28,3.9),fabric,bedX,1.24,bedZ+1.35);for(const dx of [-1.85,1.85])add(new THREE.BoxGeometry(2.55,.45,1.35),cream,bedX+dx,1.28,bedZ-2.35);add(new THREE.BoxGeometry(7.2,2.45,.45),darkWood,bedX,1.58,bedZ-3.45);
        for(const dx of [-4.25,4.25]){add(new THREE.BoxGeometry(1.55,1.2,1.55),wood,bedX+dx,.62,bedZ-2.5);add(new THREE.CylinderGeometry(.12,.18,1.5,8),trim,bedX+dx,1.9,bedZ-2.5);const shade=add(new THREE.ConeGeometry(.65,.72,14,1,true),new THREE.MeshStandardMaterial({color:0xe0b97a,side:THREE.DoubleSide}),bedX+dx,2.78,bedZ-2.5);}
        add(new THREE.BoxGeometry(5.4,4.8,1.8),wood,cx+W*.45,2.4,cz+H*.18);for(const dx of [-1.45,1.45])add(new THREE.BoxGeometry(.09,4.25,.12),trim,cx+W*.45+dx,2.35,cz+H*.18+1);add(new THREE.BoxGeometry(4.4,.65,1.65),fabric,bedX,.36,bedZ+4.35);for(const dx of [-1.7,1.7])add(new THREE.BoxGeometry(.22,.55,1.3),darkWood,bedX+dx,.28,bedZ+4.35);
        // Bathroom fixtures behind a privacy wall.
        const bathX=cx+W*.34,bathZ=cz-H*.28;add(new THREE.BoxGeometry(5.2,1.25,2.35),cream,bathX,.64,bathZ-2.3);add(new THREE.BoxGeometry(4.55,.55,1.75),tile,bathX,1.18,bathZ-2.3);const toilet=add(new THREE.CylinderGeometry(.68,.82,.72,16),cream,bathX+3.3,.48,bathZ+1.65);toilet.scale.z=1.22;add(new THREE.BoxGeometry(1.45,1.6,.75),cream,bathX+3.3,1.1,bathZ+.75);add(new THREE.BoxGeometry(2.25,.5,1.35),cream,bathX-2.9,1.05,bathZ+1.25);add(new THREE.CylinderGeometry(.08,.12,.8,8),steel,bathX-2.9,1.68,bathZ+1.25);const mirror=add(new THREE.PlaneGeometry(2.4,2.1),glass,bathX-2.9,3.05,bathZ+.52);mirror.rotation.x=0;const showerPane=add(new THREE.PlaneGeometry(4.2,3.8),glass,bathX,2.1,bathZ-.95);showerPane.rotation.y=Math.PI/2;add(new THREE.CylinderGeometry(.07,.07,3.9,8),brass,bathX,2.1,bathZ-.93);add(new THREE.BoxGeometry(1.9,.12,.16),brass,bathX+3.0,2.55,bathZ+.35);add(new THREE.BoxGeometry(1.65,.85,.12),fabric,bathX+3.0,2.05,bathZ+.37);
        // Lived-in details: plants, framed art, ceiling lamps and upgrade hardware.
        const plantSlots=[[[cx-W*.43,cz+H*.34,1],[cx+W*.06,cz-H*.34,.82]],[[cx-W*.41,cz+H*.3,.9],[cx+W*.09,cz-H*.36,1]],[[cx-W*.45,cz+H*.31,1],[cx+W*.04,cz-H*.31,.78]]][layoutVariant%3];for(const [x,z,s] of plantSlots){add(new THREE.CylinderGeometry(.55,.72,.82,12),terracotta,x,.42,z);for(let k=0;k<7;k++){const leaf=add(new THREE.SphereGeometry(.48*s,10,7),green,x+Math.sin(k*2.2)*.45,1.15+(k%3)*.38,z+Math.cos(k*1.7)*.38);leaf.scale.y=1.55;}}
        for(const [x,z,col] of [[cx-W*.05,(.28-originR)*WORLD_SCALE+.4,0x7c4837],[cx+W*.28,(.28-originR)*WORLD_SCALE+.41,0x394f66]]){add(new THREE.PlaneGeometry(3.1,2.25),new THREE.MeshBasicMaterial({color:col,toneMapped:true}),x,3.45,z+.015);for(const [ox,oy,w,h] of [[0,-1.22,3.5,.18],[0,1.22,3.5,.18],[-1.66,0,.18,2.62],[1.66,0,.18,2.62]])add(new THREE.BoxGeometry(w,h,.14),trim,x+ox,3.45+oy,z-.08);}
        for(const [x,z] of [[sofaX-2.3,sofaZ-.72],[sofaX+2.2,sofaZ-.72]])add(new THREE.BoxGeometry(1.45,.18,.8),fabric,x,1.34,z);
        for(let i=0;i<3;i++)add(new THREE.CylinderGeometry(.11,.15,.62,9),new THREE.MeshStandardMaterial({color:[0x47714b,0x743b35,0x99763d][i],roughness:.55}),cx-W*.38+i*.5,1.34,tvZ+.55);
        for(const [x,z] of [[cx-W*.22,cz+H*.14],[cx+W*.28,cz+H*.16],[cx-W*.22,cz-H*.28]]){add(new THREE.CylinderGeometry(.045,.045,1.7,7),trim,x,6.5,z);const lamp=add(new THREE.SphereGeometry(.58,14,9),new THREE.MeshBasicMaterial({color:0xffd9a0,toneMapped:true}),x,5.55,z);lamp.scale.y=.45;const light=new THREE.PointLight(0xffc27a,rich?9:6,16,2);light.position.set(x,5.35,z);light.layers.set(1);interiorGroup.add(light);}
        if(+lvl.safe>0){const safe=add(new THREE.BoxGeometry(2.6,3.1,2.15),steel,cx+W*.44,1.55,cz-H*.39);outline(safe);const dial=add(new THREE.TorusGeometry(.42,.09,8,18),trim,safe.position.x,1.8,safe.position.z+1.1);dial.rotation.x=Math.PI/2;}
        if(+lvl.weaponRack>0){const rack=add(new THREE.BoxGeometry(4.5,3.4,.42),darkWood,cx-W*.02,2.05,(.35-originR)*WORLD_SCALE+.45);for(let i=0;i<Math.min(3,+lvl.weaponRack);i++){const gun=add(new THREE.BoxGeometry(2.8,.16,.16),black,rack.position.x,1.25+i*.82,rack.position.z+.32);gun.rotation.z=(i%2?-.08:.08);add(new THREE.BoxGeometry(.55,.7,.18),wood,rack.position.x+.75,1.03+i*.82,rack.position.z+.34);}}
        if(+lvl.cameras>0)for(const x of [cx-W*.43,cx+W*.43]){const cam=add(new THREE.BoxGeometry(.72,.48,1.05),black,x,4.65,cz-H*.39);cam.rotation.y=x<cx?.5:-.5;add(new THREE.SphereGeometry(.08,8,6),new THREE.MeshBasicMaterial({color:0xff3737}),x,4.67,cam.position.z+.58);}
        // Six strongly different lifestyle corners turn the twelve seeds into
        // visible homes rather than centimetre-level furniture offsets.
        const theme=layoutVariant%6,themeX=cx+W*.07,themeZ=cz+H*.34;
        if(theme===0){add(new THREE.BoxGeometry(4.8,.3,1.8),wood,themeX,.9,themeZ);add(new THREE.BoxGeometry(2.5,1.55,.2),black,themeX,2.0,themeZ-.82);add(new THREE.PlaneGeometry(2.15,1.22),screenGlow,themeX,2.02,themeZ-.7).castShadow=false;for(const dx of [-1.7,1.7])add(new THREE.BoxGeometry(.9,2.4,1.25),darkWood,themeX+dx,1.2,themeZ);}
        else if(theme===1){const piano=add(new THREE.BoxGeometry(5.4,1.55,2.1),black,themeX,.78,themeZ);for(let key=0;key<13;key++)add(new THREE.BoxGeometry(.34,.08,1.15),key%2?cream:black,themeX-2.05+key*.34,1.62,themeZ+.58).castShadow=false;for(const dx of [-2.2,2.2])add(new THREE.BoxGeometry(.18,1.5,.18),brass,themeX+dx,.75,themeZ);}
        else if(theme===2){const canvas=add(new THREE.PlaneGeometry(3.2,2.55),new THREE.MeshBasicMaterial({color:0x9b5a45}),themeX,2.65,themeZ);canvas.rotation.y=-.18;for(const dx of [-1.35,1.35]){const leg=add(new THREE.BoxGeometry(.13,3.8,.13),wood,themeX+dx,1.9,themeZ-.15);leg.rotation.z=dx<0?-.16:.16;}for(const c of [0xc84d45,0x3c7897,0xd3aa48])add(new THREE.CylinderGeometry(.22,.27,.32,12),new THREE.MeshStandardMaterial({color:c}),themeX+(c%3-1)*.55,.18,themeZ+1.2);}
        else if(theme===3){const bar=add(new THREE.CylinderGeometry(.07,.07,4.5,10),steel,themeX,1.45,themeZ);bar.rotation.z=Math.PI/2;for(const dx of [-2,-1.72,1.72,2]){const plate=add(new THREE.CylinderGeometry(.45,.45,.16,16),dx<0?fabric:trim,themeX+dx,1.45,themeZ);plate.rotation.z=Math.PI/2;}add(new THREE.BoxGeometry(4.2,.32,1.15),black,themeX,.45,themeZ+1.75);}
        else if(theme===4){add(new THREE.BoxGeometry(5.6,2.9,.42),darkWood,themeX,1.45,themeZ-.55);for(let row=0;row<2;row++)for(let i=-4;i<=4;i++)add(new THREE.CylinderGeometry(.1,.14,.62,9),new THREE.MeshStandardMaterial({color:[0x3c7047,0x744035,0xb08c45][Math.abs(i+row)%3]}),themeX+i*.54,.52+row*1.15,themeZ-.28);add(new THREE.BoxGeometry(5.8,.3,1.5),stone,themeX,.92,themeZ+1.05);}
        else{add(new THREE.BoxGeometry(4.8,1.25,1.8),wood,themeX,.63,themeZ);for(let tool=0;tool<7;tool++){const t=add(new THREE.BoxGeometry(.16,1.45,.12),tool%2?steel:brass,themeX-1.8+tool*.6,1.95,themeZ-.85);t.rotation.z=(tool-3)*.08;}for(const dx of [-1.4,0,1.4])add(new THREE.BoxGeometry(1.05,.82,.95),fabric,themeX+dx,.42,themeZ+1.2);}
        if(+lvl.garage>0){add(new THREE.BoxGeometry(3.8,2.15,.24),darkWood,cx+W*.28,2.25,northZ+.32);const model=add(new THREE.BoxGeometry(2.55,.55,.9),new THREE.MeshStandardMaterial({color:0x315f82,metalness:.45,roughness:.34}),cx+W*.28,2.15,northZ+.52);for(const dx of [-.82,.82]){const wheel=add(new THREE.CylinderGeometry(.24,.24,.18,14),black,model.position.x+dx,1.88,northZ+.6);wheel.rotation.z=Math.PI/2;}}
        const ownerTitle=apt.owned?'МОЯ КВАРТИРА':'КВАРТИРА',ownerDetail=apt.owned?(apt.district||'Городской район'):apt.ownerName?`Владелец: ${apt.ownerName}`:(apt.district||'Городской район'),ownerColor=apt.owned?'#8dffae':apt.ownerName?'#7ed8ff':'#e5c66b',ownerSign=apartmentLabelSprite(ownerTitle,ownerDetail,ownerColor);ownerSign.position.set(cx,6.2,northZ+.68);ownerSign.layers.set(1);interiorGroup.add(ownerSign);
        renderer.domElement.dataset.apartmentInterior=`furnished-v5:${layoutVariant}:theme-${theme}:${repair}:${+lvl.safe||0}:${+lvl.weaponRack||0}:${+lvl.cameras||0}:${+lvl.garage||0}`;
        renderer.domElement.dataset.apartmentLayout=`lifestyle-theme-${theme}:seed-${seed.toString(16)}`;
        return true;
      };
      const decoratePremiumInterior=data=>{const cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,add=(geo,mat,x,y,z)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;},wood=new THREE.MeshStandardMaterial({color:0x5b3423,roughness:.68}),leather=new THREE.MeshStandardMaterial({color:0x351b1c,roughness:.55}),brass=new THREE.MeshStandardMaterial({color:0xc59b3b,metalness:.72,roughness:.25}),marble=new THREE.MeshStandardMaterial({color:0xd8d3c8,roughness:.34}),steel=new THREE.MeshStandardMaterial({color:0x667078,metalness:.86,roughness:.2}),glass=new THREE.MeshPhysicalMaterial({color:0x9bdcf2,transparent:true,opacity:.32,roughness:.05,transmission:.42});
        if(data.bizId==='major_casino'){for(const dx of [-W*.24,0,W*.24]){const chain=add(new THREE.CylinderGeometry(.055,.055,2.2,7),brass,cx+dx,7.4,cz-H*.08),crown=add(new THREE.SphereGeometry(.72,16,10),new THREE.MeshBasicMaterial({color:0xffdf8a}),cx+dx,6.15,cz-H*.08);crown.scale.y=.42;}for(const z of [-H*.06,H*.19]){const wall=add(new THREE.BoxGeometry(.35,4.6,W*.16),wood,cx-W*.12,2.3,cz+z);wall.rotation.y=Math.PI/2;}return;}
        if(data.type==='bank'||data.kind==='bank'){if(data.room!=='vault'){const counter=add(new THREE.BoxGeometry(W*.52,1.55,2.5),marble,cx,.78,cz-H*.2);for(let i=-3;i<=3;i++){const window=add(new THREE.BoxGeometry(.08,3.2,3.4),glass,cx+i*W*.065,2.65,cz-H*.18);window.rotation.y=Math.PI/2;}for(const dx of [-W*.25,W*.25])for(const dz of [-H*.02,H*.14]){const post=add(new THREE.CylinderGeometry(.13,.18,1.2,10),brass,cx+dx,.6,cz+dz);const rope=add(new THREE.BoxGeometry(W*.5,.08,.08),leather,cx,.86,cz+dz);}}else{const vaultDoor=add(new THREE.CylinderGeometry(3.2,3.2,.8,32),steel,cx,3.2,cz-H*.3);vaultDoor.rotation.x=Math.PI/2;const wheel=add(new THREE.TorusGeometry(1.35,.18,10,28),brass,cx,3.2,cz-H*.3+.45);wheel.rotation.x=Math.PI/2;for(let i=0;i<14;i++){const bag=add(new THREE.SphereGeometry(.68,10,7),new THREE.MeshStandardMaterial({color:0x6e5a35,roughness:1}),cx-7+(i%7)*2.3,.68,cz+2+Math.floor(i/7)*2);bag.scale.set(1,.85,.72);}}return;}
        const residential=['mafia_hq','residence','apartment','home'].includes(String(data.type))||/residence|villa|mafia/i.test(String(data.bizId||''));if(!residential)return;
        const rug=add(new THREE.PlaneGeometry(W*.42,H*.35),new THREE.MeshStandardMaterial({color:0x6e1f25,roughness:.94}),cx,.09,cz);rug.rotation.x=-Math.PI/2;
        const table=add(new THREE.BoxGeometry(8,1,3.8),wood,cx,.85,cz-H*.08);for(const dx of [-5,5])for(const dz of [-2.3,2.3]){const chair=add(new THREE.BoxGeometry(1.4,1.6,1.4),leather,cx+dx,.8,cz-H*.08+dz);}
        const sofa=add(new THREE.BoxGeometry(7,1.6,2.5),leather,cx-W*.24,.8,cz+H*.2),desk=add(new THREE.BoxGeometry(5.8,1.2,2.6),wood,cx+W*.25,.6,cz+H*.18);for(let i=0;i<5;i++){const shelf=add(new THREE.BoxGeometry(.8,4.4,3),wood,cx-W*.35+i*1.05,2.2,cz-H*.34);}
        const safe=add(new THREE.BoxGeometry(3.3,3.8,2.6),steel,cx+W*.34,1.9,cz-H*.3);outline(safe);const portrait=add(new THREE.PlaneGeometry(4.2,3.1),new THREE.MeshBasicMaterial({color:0x8d704f}),cx,4.2,(.48-originR)*WORLD_SCALE);portrait.rotation.x=0;
        const warm=new THREE.PointLight(0xffc579,20,30,2);warm.position.set(cx,6.4,cz);warm.layers.set(1);interiorGroup.add(warm);
      };
      // A point light changes the shader program even when its finite range is
      // nowhere near the camera. Keep a stable, generous nearest-light budget:
      // all lamp meshes/emissive glows remain authored, while lights that cannot
      // reach the visible play area no longer inflate every material shader.
      const OUTDOOR_POINT_LIGHT_CAP=16,outdoorPointLights=[],outdoorPointLightRanking=[],streetLightSet=new Set(streetLights.map(entry=>entry.light)),outdoorLightPosition=new THREE.Vector3();
      let outdoorLightBudgetAt=-Infinity;
      const registerOutdoorPointLights=root=>root?.traverse?.(object=>{
        if(!object.isPointLight||object.layers.mask!==1||(!streetLightSet.has(object)&&object.intensity<=.001)||outdoorPointLights.includes(object))return;
        outdoorPointLights.push(object);outdoorPointLightRanking.push({light:object,score:0});
      });
      const updateOutdoorPointLightBudget=(t=0,force=false)=>{
        if(!force&&t-outdoorLightBudgetAt<250)return;
        outdoorLightBudgetAt=t;
        for(const item of outdoorPointLightRanking){
          item.light.getWorldPosition(outdoorLightPosition);
          const dx=outdoorLightPosition.x-player.position.x,dz=outdoorLightPosition.z-player.position.z;
          item.score=dx*dx+dz*dz+(item.light.intensity>.001?0:1e9);
        }
        outdoorPointLightRanking.sort((a,b)=>a.score-b.score);
        let activeOutdoorLights=0;for(let i=0;i<outdoorPointLightRanking.length;i++){const light=outdoorPointLightRanking[i].light,budgetVisible=i<OUTDOOR_POINT_LIGHT_CAP;light.userData.mfzBudgetVisible=budgetVisible;light.visible=budgetVisible&&environmentNight>.08;if(light.visible)activeOutdoorLights++;}
        renderer.domElement.dataset.outdoorPointLights=`${activeOutdoorLights}/${outdoorPointLightRanking.length}`;
      };
      registerOutdoorPointLights(scene);updateOutdoorPointLightBudget(0,true);
      stage.classList.add('three-mode');
      renderer.domElement.dataset.worldBounds=`${envSnapshot?.mapCols||80}x${envSnapshot?.mapRows||200}`;
      window.MafioziLoading?.set(89, 'Заселяем улицы и готовим первый кадр…');
      let lastW=size.W,lastH=size.H,lastT=performance.now(),lastPresentedAt=0,telemetryAt=0,walkPhase=0,lampAnchor='',fpsAt=performance.now(),fpsFrames=0,measuredFps=60,lastPixelRatioChangeAt=0,lastShadowAt=0,lastPrisonAlarmBatchRevision=-1,pendingPrisonAlarmShadow=false,lastOcclusionAt=0,dynamicAt=0,dynamicState=null,nearbyActionAt=0,nearbyActionState=null,nearbyActionVisualSig='',customGangHqAt=0,cameraZoomMode='world',cameraZoomKey='',worldZoom=1,playerFloorElevation=0,playerVisualSig='',vehicleEntryState=null,firstFramePresented=false,fullMaterialsReady=false,materialCompileStarted=false,deferredWorldLoadStarted=false,playerHpPct=1,lastPlayerHp=-1,playerHitUntil=0,playerHitSide=1,playerHitForward=0,playerHitPower=1,playerImpactStamp=-1,playerDeathStartedAt=0,playerDeathVariant=0,playerDead=false,activeArrestLabelPhase='';
      const OCCLUSION_DEFAULT_OPACITY=.46,OCCLUSION_RELEASE_HOLD_MS=280,occlusionMaterialStates=new Map(),occlusionBlockers=[];
      const markOcclusionMaterial=(material,t)=>{const fadeOpacity=THREE.MathUtils.clamp(+material.userData?.mfzOcclusionOpacity||OCCLUSION_DEFAULT_OPACITY,.24,.72);let state=occlusionMaterialStates.get(material);if(!state){state={baseOpacity:material.opacity,baseTransparent:material.transparent,baseDepthWrite:material.depthWrite,fadeOpacity,targetOpacity:fadeOpacity,lastBlockedAt:t};occlusionMaterialStates.set(material,state);}state.fadeOpacity=fadeOpacity;state.targetOpacity=fadeOpacity;state.lastBlockedAt=t;};
      const updateOcclusionMaterials=(dt,t)=>{let fading=0,restoring=0;for(const [material,state] of occlusionMaterialStates){if(state.targetOpacity===state.fadeOpacity&&t-state.lastBlockedAt>OCCLUSION_RELEASE_HOLD_MS)state.targetOpacity=state.baseOpacity;const towardFade=state.targetOpacity<state.baseOpacity-.001,ease=1-Math.exp(-dt*(towardFade?13:9)),next=THREE.MathUtils.lerp(material.opacity,state.targetOpacity,ease);if(towardFade){if(!material.transparent){material.transparent=true;material.needsUpdate=true;}material.depthWrite=false;fading++;}else restoring++;material.opacity=Math.abs(next-state.targetOpacity)<.004?state.targetOpacity:next;if(!towardFade&&material.opacity===state.baseOpacity){material.depthWrite=state.baseDepthWrite;if(material.transparent!==state.baseTransparent){material.transparent=state.baseTransparent;material.needsUpdate=true;}occlusionMaterialStates.delete(material);}}renderer.domElement.dataset.occlusionMaterials=`fade:${fading}:restore:${restoring}`;};
      renderer.domElement.dataset.roofOcclusionProfile='visible-facade-roof-split-highlight-restore-v330';
      if((location.hostname==='127.0.0.1'||location.hostname==='localhost')&&rendererParams.has('previewzoom')){worldZoom=THREE.MathUtils.clamp(+rendererParams.get('previewzoom')||1,.82,2.6);camera.zoom=worldZoom;camera.updateProjectionMatrix();renderer.domElement.dataset.worldZoom=worldZoom.toFixed(2);}
      const playerAnim={speed:0,gait:0,accel:0,rootYaw:0,legYaw:0,stepBucket:-1,lastStepAt:0,cameraKick:0};
      const expDamp=(value,target,rate,dt)=>THREE.MathUtils.lerp(value,target,1-Math.exp(-Math.max(0,rate)*dt));
      const smooth01=value=>{const q=Math.max(0,Math.min(1,value));return q*q*(3-2*q);};
      const localAngleDelta=(a,b)=>{let d=a-b;while(d>Math.PI)d-=Math.PI*2;while(d<-Math.PI)d+=Math.PI*2;return d;};
      const resolvePlayerAnimationLayer=state=>state?.arrestPhase?`arrest-${state.arrestPhase}`:state?.dead?'death':state?.driving?'driving':state?.vehicleEntry?'vehicle-entry':state?.reloading?'reload':state?.aiming?'aim-locomotion':'locomotion';
      window.Mafiozi3DAnimationDebug=Object.freeze({resolvePlayerAnimationLayer,resolveWeaponReloadStage,priority:'arrest>death>driving>vehicle-entry>reload>aim>locomotion',version:253});
      const emitFootContact=(t,side)=>{const slot=footContactPool.reduce((best,item)=>!item.mesh.visible||item.born<best.born?item:best,footContactPool[0]);slot.born=t;slot.life=.44;slot.mesh.visible=true;const lateral=side*.42,forward=.1,sy=Math.sin(player.rotation.y),cy=Math.cos(player.rotation.y);slot.mesh.position.set(player.position.x+cy*lateral+sy*forward,playerFloorElevation+.07,player.position.z-sy*lateral+cy*forward);slot.mesh.scale.setScalar(.72);slot.mesh.material.opacity=.34;};
      const updateFootContacts=dt=>{for(const fx of footContactPool){if(!fx.mesh.visible)continue;fx.life-=dt;if(fx.life<=0){fx.mesh.visible=false;continue;}const p=1-fx.life/.44;fx.mesh.scale.setScalar(.72+p*1.5);fx.mesh.material.opacity=(1-p)*.34;}};
      const vehicleAnimMatrix=new THREE.Matrix4(),vehicleAnimQuat=new THREE.Quaternion(),vehicleAnimPos=new THREE.Vector3(),vehicleAnimScale=new THREE.Vector3(1,1,1),vehicleAnimEuler=new THREE.Euler();
      const resetVehicleAnimation=car=>{const ux=car.userData;ux.wheelSteer=ux.bodyRoll=ux.bodyPitch=0;ux.lastVehicleYaw=car.rotation.y;ux.vehicleAnimReady=false;car.rotation.x=car.rotation.z=0;if(ux.base)ux.base.position.y=ux.baseBaseY;if(ux.cab)ux.lastCabBounce=0;};
      const updateVehicleAnimation=(car,src,dt)=>{const ux=car.userData;if(!src||!ux.wheelPositions)return;if(src.helicopter||src.wrecked||src.destroying){resetVehicleAnimation(car);return;}const speed=Math.hypot(+src.velR||0,+src.velC||0),previousYaw=ux.vehicleAnimReady&&Number.isFinite(ux.lastVehicleYaw)?ux.lastVehicleYaw:car.rotation.y,yawRate=localAngleDelta(car.rotation.y,previousYaw)/Math.max(.008,dt),steerTarget=Math.max(-.48,Math.min(.48,yawRate*.09+(src.turning?Math.sign(yawRate||1)*.16:0)));ux.vehicleAnimReady=true;ux.wheelSteer=expDamp(ux.wheelSteer||0,steerTarget,9,dt);ux.bodyRoll=expDamp(ux.bodyRoll||0,-ux.wheelSteer*Math.min(.12,speed*.035),7,dt);ux.bodyPitch=expDamp(ux.bodyPitch||0,src.braking?.07:-Math.min(.035,speed*.008),8,dt);ux.lastVehicleYaw=car.rotation.y;car.rotation.z=ux.bodyRoll;car.rotation.x=ux.bodyPitch;const bounce=Math.sin((ux.wheelSpin||0)*2)*Math.min(.035,speed*.006);ux.base.position.y=ux.baseBaseY+bounce;ux.cab.position.y+=bounce;ux.lastCabBounce=bounce;for(let wi=0;wi<ux.wheelPositions.length;wi++){const [wx,wy,wz]=ux.wheelPositions[wi],front=wx>0,steer=front?ux.wheelSteer:0,spin=ux.wheelSpin||0;vehicleAnimPos.set(wx,wy,wz);vehicleAnimQuat.setFromEuler(vehicleAnimEuler.set(Math.PI/2+spin,steer,0,'XYZ'));vehicleAnimMatrix.compose(vehicleAnimPos,vehicleAnimQuat,vehicleAnimScale);ux.wheelMeshes[0].setMatrixAt(wi,vehicleAnimMatrix);ux.wheelMeshes[1].setMatrixAt(wi,vehicleAnimMatrix);vehicleAnimQuat.setFromEuler(vehicleAnimEuler.set(spin,Math.PI/2+steer,0,'XYZ'));vehicleAnimMatrix.compose(vehicleAnimPos,vehicleAnimQuat,vehicleAnimScale);ux.wheelMeshes[2].setMatrixAt(wi,vehicleAnimMatrix);}for(const mesh of ux.wheelMeshes)mesh.instanceMatrix.needsUpdate=true;};
      const sceneDiagnosticsEnabled=rendererParams.has('perfdiag')||rendererParams.has('previewwrecks');
      const collectSceneDiagnostics=()=>{
        if(!sceneDiagnosticsEnabled)return;
        let visibleMeshes=0,visibleLights=0;const materials=new Set(),roots=[],invalidMaterials=[];
        const visit=(object,parentVisible=true)=>{const visible=parentVisible&&object.visible!==false;if(!visible)return 0;let count=0;if(object.isMesh||object.isLine||object.isPoints){count=1;visibleMeshes++;const list=Array.isArray(object.material)?object.material:[object.material];for(const material of list){if(material)materials.add(material.uuid);else invalidMaterials.push(object.name||object.type||'unnamed');}}if(object.isLight)visibleLights++;for(const child of object.children||[])count+=visit(child,visible);return count;};
        for(const child of scene.children){const count=visit(child,true);if(count>1)roots.push([child.name||child.type,count]);}
        roots.sort((a,b)=>b[1]-a[1]);window.Mafiozi3DDiagnostics={visibleMeshes,visibleLights,visibleMaterials:materials.size,invalidMaterials:invalidMaterials.slice(0,24),topRoots:roots.slice(0,24),drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles,fps:measuredFps};
        renderer.domElement.dataset.visibleMeshes=String(visibleMeshes);renderer.domElement.dataset.visibleMaterials=String(materials.size);renderer.domElement.dataset.visibleLights=String(visibleLights);renderer.domElement.dataset.sceneRoots=roots.slice(0,24).map(([name,count])=>`${name}:${count}`).join('|');
      };
      renderer.domElement.addEventListener('wheel',e=>{if(cameraZoomMode!=='world')return;e.preventDefault();worldZoom=THREE.MathUtils.clamp(worldZoom+(e.deltaY<0?.08:-.08),.82,1.3);camera.zoom=worldZoom;camera.updateProjectionMatrix();renderer.domElement.dataset.worldZoom=worldZoom.toFixed(2);},{passive:false});
      const onIdle=callback=>typeof requestIdleCallback==='function'?requestIdleCallback(callback,{timeout:180}):setTimeout(()=>callback({timeRemaining:()=>4}),16);
      let sectorAnchor=initialState?`${Math.floor((+initialState.r||0)/STREAM_SECTOR_SIZE)}:${Math.floor((+initialState.c||0)/STREAM_SECTOR_SIZE)}`:'',sectorLoadScheduled=false,sectorBuildQueue=deferredInitialBuildings.slice(),junkyardProbeAt=0;
      let buildingPumpStarted=false,staticDetailFlushScheduled=false,initialCompileRunning=false,deferredWarmupRunning=false;
      let compileLoadedScene=()=>{},warmDeferredSceneRoots=()=>{};
      const pumpStaticDetailBatches=deadline=>{
        const pumpStartedAt=performance.now();
        stageStaticDetailBuckets();
        if(pendingStaticDetailBatches.length&&(deadline.timeRemaining()>2||pendingStaticDetailBatches.length))mergeStaticDetailBatch(pendingStaticDetailBatches.shift());
        publishStaticDetailStats();
        const pumpElapsed=performance.now()-pumpStartedAt;renderer.domElement.dataset.staticDetailPumpMs=pumpElapsed.toFixed(1);renderer.domElement.dataset.staticDetailPumpMaxMs=Math.max(pumpElapsed,+renderer.domElement.dataset.staticDetailPumpMaxMs||0).toFixed(1);
        if(pendingStaticDetailBatches.length||staticDetailBuckets.size)onIdle(pumpStaticDetailBatches);
        else{staticDetailFlushScheduled=false;renderer.shadowMap.needsUpdate=true;if(materialCompileStarted&&!fullMaterialsReady)compileLoadedScene();else if(fullMaterialsReady)warmDeferredSceneRoots();}
      };
      const scheduleStaticDetailFlush=()=>{if(staticDetailFlushScheduled)return;staticDetailFlushScheduled=true;onIdle(pumpStaticDetailBatches);};
      const scheduleBuildingPump=()=>setTimeout(()=>onIdle(pumpSectorBuildings),34);
      const pumpSectorBuildings=deadline=>{const pumpStartedAt=performance.now();let made=0;while(sectorBuildQueue.length&&made<2&&(made===0||deadline.timeRemaining()>2)){const [def,index]=sectorBuildQueue.shift(),sceneStart=scene.children.length,districtStart=districtProps.children.length;createBuilding(def,index);const roots=scene.children.slice(sceneStart),districtRoots=districtProps.children.slice(districtStart);for(const root of districtRoots){districtProps.remove(root);roots.push(root);}for(const root of roots)registerOutdoorPointLights(root);updateOutdoorPointLightBudget(performance.now(),true);if(fullMaterialsReady)for(const root of roots){root.visible=false;root.userData.mfzDeferredReveal=true;deferredRevealRoots.push(root);}placeStreamedBuildingRoots(def,roots);made++;}const pumpElapsed=performance.now()-pumpStartedAt;renderer.domElement.dataset.buildingPumpMs=pumpElapsed.toFixed(1);renderer.domElement.dataset.buildingPumpMaxMs=Math.max(pumpElapsed,+renderer.domElement.dataset.buildingPumpMaxMs||0).toFixed(1);renderer.domElement.dataset.worldBuildings=String(buildingDefs.length);renderer.domElement.dataset.pendingBuildings=String(sectorBuildQueue.length);if(sectorBuildQueue.length)scheduleBuildingPump();else scheduleStaticDetailFlush();};
      const startDeferredWorldLoad=()=>{
        if(deferredWorldLoadStarted)return;
        deferredWorldLoadStarted=true;
        capturePersistentStreamResources();
        if(sectorBuildQueue.length&&!buildingPumpStarted){buildingPumpStarted=true;scheduleBuildingPump();}
        if(deferredVehicleSlots.length&&!vehicleSlotPumpStarted){vehicleSlotPumpStarted=true;setTimeout(pumpDeferredVehicleSlots,34);}
      };
      const activateFullScene=()=>{
        if(fullMaterialsReady)return;
        fullMaterialsReady=true;
        renderer.shadowMap.enabled=realTimeShadows;
        renderer.shadowMap.needsUpdate=true;
        renderer.domElement.dataset.materialCompile='ready';
        startupMark('materials-ready');
        window.MafioziLoading?.set(98,'Показываем готовый район…');
        startDeferredWorldLoad();
      };
      const finishInitialCompile=(mode,error=null)=>{
        if(error)console.warn('[ThreeStartup] material warmup fallback',error);
        initialCompileRunning=false;
        finishStartupFxWarmup();
        activateFullScene();
        renderer.domElement.dataset.materialCompile=mode;
        // The warmup render is already a complete authored frame. Mark loading
        // finished before yielding so the 25 s Canvas fallback cannot tear down
        // a successfully warmed renderer on a slow driver.
        window.MafioziLoading?.complete('Город готов');
      };
      compileLoadedScene=()=>{
        if(fullMaterialsReady||initialCompileRunning||pendingStaticDetailBatches.length||staticDetailBuckets.size)return;
        initialCompileRunning=true;
        renderer.domElement.dataset.materialCompile='warming-all-visible-materials';
        window.MafioziLoading?.set(96,'Прогреваем шейдеры города без потери качества…');
        try{
          // compileAsync hangs in Three r180 when pooled instanced materials have
          // no currentProgram. Queue programs synchronously, then force their
          // first use behind the loading screen instead of inside gameplay rAF.
          renderer.compile(scene,camera);
          renderer.render(scene,camera);
          // Keep the two authored prison PointLights in the scene graph even
          // while quiet (their intensity is zero). Hiding their roots here used
          // to compile a second, byte-identical one-point-light program for most
          // city materials; gameplay now keeps both roots visible at all times.
          const prisonLightRoots=prisonAlarmBeacons.filter(beacon=>beacon.alarmLight).map(beacon=>beacon.root);
          if(prisonLightRoots.length){
            const prisonWarmStartedAt=performance.now(),previousShadowEnabled=renderer.shadowMap.enabled,prisonLightVisibility=prisonLightRoots.map(root=>root.visible),warmCarVisible=warmupCar?.visible,warmCarPosition=warmupCar?.position.clone(),shadowWarmX=sun.target.position.x,shadowWarmZ=sun.target.position.z;
            let mappedShadowSource=null;
            scene.traverse(object=>{if(mappedShadowSource||!object.isMesh||!object.castShadow)return;const material=Array.isArray(object.material)?object.material.find(candidate=>candidate?.map):object.material;if(material?.map)mappedShadowSource={geometry:object.geometry,material};});
            const mappedShadowProxy=mappedShadowSource?new THREE.Mesh(mappedShadowSource.geometry,mappedShadowSource.material):null;
            if(mappedShadowProxy){mappedShadowProxy.name='startup-mapped-shadow-proxy';mappedShadowProxy.position.set(shadowWarmX,1,shadowWarmZ);mappedShadowProxy.frustumCulled=false;mappedShadowProxy.castShadow=true;mappedShadowProxy.receiveShadow=false;mappedShadowProxy.layers.mask=camera.layers.mask;scene.add(mappedShadowProxy);}
            if(warmupCar){warmupCar.visible=true;warmupCar.position.set(shadowWarmX+4,0,shadowWarmZ+4);}
            // Compile the clearcoat-free wreck body alongside the already
            // required prison light variants. A separate material proxy keeps
            // the live vehicle untouched and avoids two extra full-city frames.
            const matteWreckProxy=warmupCar&&matteWreckWarmMaterial?new THREE.Mesh(warmupCar.userData.base.geometry,matteWreckWarmMaterial):null;
            if(matteWreckProxy){matteWreckProxy.name='startup-matte-wreck-proxy';matteWreckProxy.position.set(shadowWarmX+7,1,shadowWarmZ+4);matteWreckProxy.frustumCulled=false;matteWreckProxy.castShadow=true;matteWreckProxy.receiveShadow=false;matteWreckProxy.layers.mask=camera.layers.mask;scene.add(matteWreckProxy);}
            const renderPrisonWarmFrame=()=>{
              renderer.compile(scene,camera);if(realTimeShadows)renderer.shadowMap.needsUpdate=true;renderer.render(scene,camera);
            };
            try{
              renderer.shadowMap.enabled=realTimeShadows;
              renderPrisonWarmFrame();
            }finally{
              renderer.shadowMap.enabled=previousShadowEnabled;
              if(matteWreckProxy)scene.remove(matteWreckProxy);
              if(mappedShadowProxy)scene.remove(mappedShadowProxy);
              if(warmupCar){warmupCar.visible=warmCarVisible;warmupCar.position.copy(warmCarPosition);}
              prisonLightRoots.forEach((root,index)=>{root.visible=prisonLightVisibility[index];});
            }
            renderer.domElement.dataset.prisonCombatWarmup=`ready:${prisonLightRoots.length}:dual-car-matte-wreck-${mappedShadowProxy?'mapped':'plain'}:${(performance.now()-prisonWarmStartedAt).toFixed(1)}ms`;
          }
          finishInitialCompile('ready-warmup-frame');
        }catch(error){finishInitialCompile('ready-normal-render',error);}
      };
      warmDeferredSceneRoots=()=>{
        if(!fullMaterialsReady||deferredWarmupRunning)return;
        const warmupStartedAt=performance.now();
        // Compiling every streamed facade in one giant scene caused 1-2 second
        // gameplay freezes on WebView GPUs. Warm a small slice, reveal it, then
        // yield before the next slice; authored geometry and materials stay the
        // same, only the scheduling changes.
        const roots=[...new Set(deferredRevealRoots.splice(0,mobileRenderProfile?1:2))].filter(root=>root?.parent);
        if(!roots.length)return;
        deferredWarmupRunning=true;
        const warmupScene=new THREE.Scene();warmupScene.environment=scene.environment;warmupScene.fog=scene.fog;
        for(const root of roots){root.userData.mfzWarmupInFlight=true;const clone=root.clone(true);clone.visible=true;clone.traverse?.(object=>{object.visible=true;object.frustumCulled=false;});warmupScene.add(clone);}
        scene.traverseVisible(object=>{if(object.isLight)warmupScene.add(object.clone());});
        let pendingCompile=null;
        try{pendingCompile=renderer.compileAsync?.(warmupScene,camera)||null;}catch(error){console.warn('[ThreeStream] parallel material warmup failed',error);}
        const warmupElapsed=performance.now()-warmupStartedAt;renderer.domElement.dataset.deferredWarmupSubmitMs=warmupElapsed.toFixed(1);renderer.domElement.dataset.deferredWarmupSubmitMaxMs=Math.max(warmupElapsed,+renderer.domElement.dataset.deferredWarmupSubmitMaxMs||0).toFixed(1);
        const reveal=()=>{warmupScene.clear();for(const root of roots){delete root.userData.mfzWarmupInFlight;if(root.parent){root.visible=true;delete root.userData.mfzDeferredReveal;}}deferredWarmupRunning=false;if(realTimeShadows)renderer.shadowMap.needsUpdate=true;if(deferredRevealRoots.length)onIdle(warmDeferredSceneRoots);};
        if(pendingCompile?.then)pendingCompile.then(reveal,error=>{console.warn('[ThreeStream] material warmup fallback',error);reveal();});
        else reveal();
      };
      const beginFullMaterialCompile=()=>{
        if(materialCompileStarted)return;
        materialCompileStarted=true;
        renderer.shadowMap.enabled=realTimeShadows;
        renderer.domElement.dataset.materialCompile='warming-start-area';
        window.MafioziLoading?.set(94,'Прогреваем материалы ближайшего района…');
        compileLoadedScene();
      };
      renderer.domElement.dataset.worldBuildings=String(buildingDefs.length);
      renderer.domElement.dataset.pendingBuildings=String(sectorBuildQueue.length);
      const scheduleSectorLoad=(r,c)=>{const key=`${Math.floor(r/STREAM_SECTOR_SIZE)}:${Math.floor(c/STREAM_SECTOR_SIZE)}`;if(key===sectorAnchor||sectorLoadScheduled)return;sectorAnchor=key;sectorLoadScheduled=true;renderer.domElement.dataset.streamAnchor=key;onIdle(()=>{sectorLoadScheduled=false;const snapshot=bridge?.getWorldSnapshot?.(WORLD_SNAPSHOT_RADIUS);if(!snapshot)return;ensureJunkyardVisual(snapshot,'sector');ensureMajorFactoryExterior(snapshot,'sector');addNeighborhoodSurfaces(snapshot);addMapCollisionVisuals(snapshot);registerOutdoorPointLights(scene);updateOutdoorPointLightBudget(performance.now(),true);const fresh=[];for(const def of defsFromSnapshot(snapshot)){const meta=def[8],buildingKey=`${meta?.minR}:${meta?.minC}:${meta?.maxR}:${meta?.maxC}`;if(loadedBuildingKeys.has(buildingKey))continue;loadedBuildingKeys.add(buildingKey);const index=buildingDefs.length;buildingDefs.push(def);fresh.push([def,index]);}sectorBuildQueue.push(...fresh);renderer.domElement.dataset.streamRadius=String(WORLD_SNAPSHOT_RADIUS);renderer.domElement.dataset.loadedSectors=String(new Set([...loadedBuildingKeys].map(k=>k.split(':').slice(0,2).map(Number).map(v=>Math.floor(v/STREAM_SECTOR_SIZE)).join(':'))).size);if(fresh.length&&sectorBuildQueue.length===fresh.length)onIdle(pumpSectorBuildings);});};
      // A single deterministic grade drives sky, fog, ambient bounce and sun.
      // Keep daylight in the same desaturated noir family as the city instead
      // of letting a cyan sky fight the dark asphalt and facade materials.
      const daySky=new THREE.Color(0x315f82),sunsetSky=new THREE.Color(0xa95a50),nightSky=new THREE.Color(0x071426),skyColor=new THREE.Color(),dayHorizon=new THREE.Color(0x78929d),nightHorizon=new THREE.Color(0x16263d),dayGround=new THREE.Color(0x46392e),nightGround=new THREE.Color(0x293448),daySun=new THREE.Color(0xffd69a),sunsetSun=new THREE.Color(0xff8a4f);
      const initialClockHour=Number.isFinite(+envSnapshot?.hour)?+envSnapshot.hour:12,initialClockMinute=Number.isFinite(+envSnapshot?.minute)?+envSnapshot.minute:0;
      let paletteDaylight=0,paletteSunset=0,paletteReady=false,paletteAt=performance.now(),lastServerHour=initialClockHour,lastServerMinute=initialClockMinute;
      const updateDayNight=t=>{
        // Production always reads the authoritative city minute. All visual
        // channels ease toward that same target, so no component can jump to
        // another palette while the clock still shows the same time.
        const serverTime=bridge?.getEnvironmentState?.();
        setTrafficSignals(serverTime?.traffic);
        if(Number.isFinite(+serverTime?.hour)&&Number.isFinite(+serverTime?.minute)){lastServerHour=+serverTime.hour;lastServerMinute=+serverTime.minute;}
        // A missing bridge sample must never invent a new time of day. This can
        // happen for one frame while an interior closes, so keep the last valid
        // city clock instead of falling back to animation uptime.
        const baseHour=lastServerHour+lastServerMinute/60;
        const hour=((baseHour+timeOffset)%24+24)%24,targetDaylight=THREE.MathUtils.smoothstep(Math.sin((hour-6)/24*Math.PI*2),-.18,.42),targetSunset=Math.max(0,1-Math.abs(hour-19)/2.2),paletteDt=Math.min(.1,Math.max(0,(t-paletteAt)/1000));paletteAt=t;if(!paletteReady){paletteDaylight=targetDaylight;paletteSunset=targetSunset;paletteReady=true;}else{const ease=1-Math.exp(-paletteDt*2.4);paletteDaylight=THREE.MathUtils.lerp(paletteDaylight,targetDaylight,ease);paletteSunset=THREE.MathUtils.lerp(paletteSunset,targetSunset,ease);}const daylight=paletteDaylight,sunset=paletteSunset;
        skyColor.copy(nightSky).lerp(daySky,daylight).lerp(sunsetSky,sunset*.48);scene.background.copy(skyColor);scene.fog.color.copy(skyColor);skyUniforms.uTop.value.copy(nightSky).lerp(daySky,daylight).lerp(sunsetSky,sunset*.2);skyUniforms.uHorizon.value.copy(nightHorizon).lerp(dayHorizon,daylight).lerp(sunsetSky,sunset*.22);skyUniforms.uNight.value=1-daylight;skyUniforms.uSunset.value=sunset;
        skyLight.color.setRGB(.4+.34*daylight,.48+.3*daylight,.68+.21*daylight);skyLight.groundColor.copy(nightGround).lerp(dayGround,daylight);skyLight.intensity=1.18+1.22*daylight;
        sun.color.copy(daySun).lerp(sunsetSun,THREE.MathUtils.smoothstep(sunset,0,.7));sun.intensity=.48+2.97*daylight;sunOffsetVector.set(Math.cos(hour/24*Math.PI*2)*75,18+daylight*72,Math.sin(hour/24*Math.PI*2)*65);
        const night=1-daylight,lampsScheduledOn=hour<7||hour>=17,lampPower=lampsScheduledOn?Math.max(.48,night):0;environmentNight=night;environmentLampPower=lampPower;renderer.toneMappingExposure=1.15+daylight*.15;scene.environmentIntensity=.42+daylight*.38;lampGlowMat.opacity=lampPower*.78;lampHeadGlowMat.opacity=lampPower*.64;newsBeamMaterial.opacity=Math.max(0,night-.1)*.24;starMaterial.opacity=Math.max(0,night-.18)*.92;postMaterial.uniforms.uBloom.value=.12+night*.12;postMaterial.uniforms.uWarmth.value=.08+sunset*.72;postMaterial.uniforms.uNight.value=night;if(waterUniforms){const day=1-night;waterUniforms.uShallow.value.setRGB(.137*day+.031*night,.659*day+.224*night,.714*day+.314*night);waterUniforms.uMid.value.setRGB(.031*day+.02*night,.451*day+.133*night,.584*day+.251*night);waterUniforms.uDeep.value.setRGB(.024*day+.008*night,.239*day+.071*night,.384*day+.165*night);waterUniforms.uSun.value.setRGB(.61*day+.12*night,.92*day+.28*night,1*day+.42*night);}
        facadeMaterials.forEach(m=>m.emissiveIntensity=.04+night*.42);shopMaterials.forEach((m,i)=>{const pulse=.965+.035*Math.sin(t*.0017+i*1.91),fault=(i%7===3&&night>.4&&Math.sin(t*.017+i*4.2)>.94)?.72:1;m.opacity=(.74+night*.26)*pulse*fault;});
        contactShadowMaterial.opacity=.2+daylight*.1;dynamicContactShadowMaterial.opacity=.34+daylight*.12;
        bulbMat.color.setRGB(.09+lampPower*.91,.1+lampPower*.68,.12+lampPower*.3);streetLights.forEach(({light},i)=>{const electrical=.97+.03*Math.sin(t*.0021+i*2.17),flicker=(i===2&&Math.sin(t*.021)> .965)?.66:1;light.intensity=lampPower*(i%2?17:25)*electrical*flicker;light.visible=light.userData.mfzBudgetVisible!==false&&lampPower>.05;});renderer.domElement.dataset.streetLampSchedule=lampsScheduledOn?'on-17-07':'off-07-17';renderer.domElement.dataset.streetLampPower=lampPower.toFixed(3);renderer.domElement.dataset.streetLampCount=String(fixedLampDefs.length);renderer.domElement.dataset.streetLampLightProfile='instanced-head-halo-ground-glow-bounded-pointlights-v330';renderer.domElement.dataset.environmentAnimationProfile='wind-water-wildlife-neon-electrical-v251';
        if(interiorLightingActive){
          // Interiors have their own authored fixtures. Never run them through
          // the outdoor sunset/night grade: otherwise identical rooms visibly
          // change palette while the player is standing still.
          scene.background.set(0x0a1018);scene.fog.color.set(0x0a1018);scene.fog.density=0;
          // Keep the same exposure and post-process grade on both sides of the
          // door. Interior fixtures shape the room; the whole screen no longer
          // flashes darker and then snaps back when the player exits.
        }
        const hh=Math.floor(hour),mm=Math.floor((hour-hh)*60);clock.textContent=`${daylight>.62?'☀ День':sunset>.15?'◐ Закат':'☾ Ночь'} · ${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}`;renderer.domElement.dataset.palette=`${hh}:${mm}:${daylight.toFixed(3)}:${sunset.toFixed(3)}`;renderer.domElement.dataset.paletteSource=serverTime?'server-clock':'cached-server-clock';renderer.domElement.dataset.paletteMotionLock='0';renderer.domElement.dataset.paletteTransition='continuous-shared-grade';renderer.domElement.dataset.paletteGrade=`${renderer.toneMappingExposure.toFixed(3)}:${postMaterial.uniforms.uWarmth.value.toFixed(3)}:${postMaterial.uniforms.uNight.value.toFixed(3)}`;
      };
      addEventListener('error',event=>{
        const message=String(event?.error?.stack||event?.error?.message||event?.message||'unknown frame error');
        renderer.domElement.dataset.runtimeFrameError=message.slice(0,1200);
      });
      const animate = t => {
        if(t-customGangHqAt>2000){customGangHqAt=t;refreshCustomGangHqs();refreshBusinessOwnership();}
        if (!document.body.contains(renderer.domElement)) return;
        // Queue the next frame before doing any scene work. A transient error in
        // one NPC/vehicle animation must drop one frame, not permanently stop
        // the whole 3D city until the player reloads the WebApp.
        requestAnimationFrame(animate);
        if(lastPresentedAt&&t-lastPresentedAt<threeFrameMinMs)return;
        lastPresentedAt=t;
        const telemetryDue=t>=telemetryAt;if(telemetryDue)telemetryAt=t+250;
        if(fullMaterialsReady)stepVehicleFxWarmup();
        const s = viewSize();
        if (s.W !== lastW || s.H !== lastH) { lastW = s.W; lastH = s.H; camera.left = -cameraSpan * s.W / s.H; camera.right = cameraSpan * s.W / s.H; camera.updateProjectionMatrix(); renderer.setSize(s.W, s.H, false); }
        updateOutdoorPointLightBudget(t);
        const frameGapMs=Math.max(0,t-lastT),dt=Math.min(.05,frameGapMs/1000);lastT=t;const tt=t*.00035;if(frameGapMs>16.8){renderer.domElement.dataset.lastFrameGapMs=frameGapMs.toFixed(1);renderer.domElement.dataset.maxFrameGapMs=Math.max(frameGapMs,+renderer.domElement.dataset.maxFrameGapMs||0).toFixed(1);}if(eHoldStarted&&!eHoldTriggered&&keys.has('KeyE'))vehicleHoldFill.style.width=`${Math.min(100,(t-eHoldStarted)/vehicleHoldMs*100).toFixed(1)}%`;updateDayNight(t);casinoExteriorAnimation(t,environmentNight);skyDome.position.copy(player.position);starField.position.copy(player.position);starField.rotation.y=t*.000004;windLeafMaterials.forEach(m=>{if(m.userData.shader)m.userData.shader.uniforms.mfzWindTime.value=t*.00115;});
        for(const fx of businessExteriorFx){const wave=Math.sin(t*.006+fx.phase*11);if(fx.kind==='wash-brush'){fx.mesh.rotation.y=t*.003*(fx.phase<0?-1:1);fx.mesh.scale.x=.92+wave*.08;}else if(fx.kind==='wash-water'){fx.mesh.material.opacity=.3+wave*.12;fx.mesh.position.y=1.72+wave*.08;}else if(fx.kind==='garage-spark'){const cycle=(t*.0018+fx.phase)%1;fx.mesh.position.set(fx.baseX+(cycle-.5)*1.2,.48+Math.sin(cycle*Math.PI)*1.35,fx.baseZ+(fx.phase-.5)*.65);fx.mesh.visible=cycle<.82;}else if(fx.kind==='bar-neon')fx.material.color.setHSL(.91,.9,.54+wave*.09);else if(fx.kind==='club-meter')fx.mesh.scale.y=.55+(wave+1)*.45;else if(fx.kind==='forklift-beacon'){fx.mesh.visible=wave>.05;fx.mesh.scale.setScalar(1.05+Math.max(0,wave)*.45);}}
        if(interiorLightingActive)for(const fx of interiorVisualFx){if(fx.kind==='factory-hoist'){const lift=(Math.sin(t*.0011+fx.phase)+1)*.42;fx.meshes.forEach((m,i)=>m.position.y=fx.baseY[i]-lift);}else if(fx.kind==='factory-belt'){const cycle=(t*.00012+fx.phase)%1;fx.mesh.position.x=fx.baseX+(cycle-.5)*fx.span*.78;}else if(fx.kind==='factory-press'){const press=(Math.sin(t*.00145+fx.phase)+1)*.42;fx.meshes.forEach((m,i)=>m.position.y=fx.baseY[i]-press*(i?.65:1));}}
        for(const smoke of factorySmokePuffs){const fx=smoke.userData.factorySmoke,cycle=(t*.000045+fx.phase)%1,wobble=Math.sin(t*.00065+fx.phase*9);smoke.position.set(fx.baseX+wobble*(.55+cycle)*fx.drift,fx.baseY+cycle*8.5,fx.baseZ+Math.cos(t*.00048+fx.phase*7)*.42);smoke.scale.setScalar(.72+cycle*1.65);smoke.material.opacity=.04+Math.sin(cycle*Math.PI)*.24;smoke.visible=!interiorLightingActive;}
        let activeBankDoor=null;for(const door of bankDoorActors){const near=!interiorLightingActive&&nearbyActionState?.kind==='bank'&&String(nearbyActionState.id)===door.id,target=near?1:0;door.open+=(target-door.open)*Math.min(1,dt*7.5);door.left.rotation.y=door.open*1.12;door.right.rotation.y=-door.open*1.12;door.left.visible=door.right.visible=!interiorLightingActive;if(near)activeBankDoor=door;}renderer.domElement.dataset.bankDoorState=activeBankDoor?(activeBankDoor.open>.82?`open:${activeBankDoor.id}`:`moving:${activeBankDoor.id}`):'closed';
        for(const door of blackmarketDoorActors){const distance=Math.hypot(player.position.x-door.x,player.position.z-door.z),near=!interiorLightingActive&&(nearbyActionState?.type==='blackmarket'||distance<12),target=near?1:0;door.open+=(target-door.open)*Math.min(1,dt*6.5);door.left.rotation.y=door.open*1.12;door.right.rotation.y=-door.open*1.12;door.left.visible=door.right.visible=!interiorLightingActive;renderer.domElement.dataset.blackmarketDoorDistance=distance.toFixed(2);renderer.domElement.dataset.blackmarketDoorState=door.open>.82?'open':door.open>.08?'moving':'closed';}
        for(const guard of blackmarketGuardActors){const breathe=Math.sin(t*.0021+guard.phase),scan=Math.sin(t*.00072+guard.phase)*.18;guard.root.visible=!interiorLightingActive;guard.root.position.y=guard.baseY+breathe*.035;guard.head.rotation.y=scan;guard.leftArm.rotation.x=.06+breathe*.025;guard.rightArm.rotation.x=-.24-breathe*.025;}
        const businessModalOpen=!!bizConfirmModal?.classList.contains('show');if(bridge&&t-nearbyActionAt>140){nearbyActionState=bridge.getNearbyBuildingInteraction?.()||null;nearbyNpcState=nearestNpcInteraction();nearbyVehicleState=bridge.getNearbyVehicleInteraction?.()||null;nearbyActionAt=t;const visualSig=businessModalOpen?'modal':`${nearbyActionState?.kind||''}:${nearbyActionState?.id||''}:${nearbyActionState?.owned?1:0}|${nearbyNpcState?.key||''}|${nearbyVehicleState?.id||''}`;if(visualSig!==nearbyActionVisualSig){nearbyActionVisualSig=visualSig;if(businessModalOpen){buildingPrompt.style.display='none';npcPrompt.style.display='none';vehicleHoldPrompt.style.display='none';nearbyNpcRing.visible=false;nearbyVehicleRing.visible=false;entranceMarker.visible=false;renderer.domElement.dataset.buildingPrompt='hidden-by-business-modal';}else showNearbyBuilding(nearbyActionState);}}if(!businessModalOpen){showNearbyNpc(nearbyNpcState,t);showNearbyVehicle(nearbyVehicleState,t);}
        if(waterSurface){waterSurface.position.y=.08+Math.sin(t*.00072)*.018;coastalAnimation?.(t,measuredFps<24);}
        if(buildingSelectionFrame.visible){const wave=Math.sin(t*.0065);selectionFrameMat.opacity=.88+(wave+1)*.05;selectionGlowMat.opacity=.2+(wave+1)*.08;}
        if(entranceMarker.visible){const wave=Math.sin(t*.009);entranceOuter.rotation.z=t*.00105;entranceInner.rotation.z=-t*.00145;entranceOuterMat.opacity=.78+(wave+1)*.1;entranceInnerMat.opacity=.68+(wave+1)*.13;const markerScale=1+(wave+1)*.045;entranceMarker.scale.set(markerScale,1,markerScale);entranceArrow.position.y=2.35+(wave+1)*.16;entranceBeam.scale.y=.88+(wave+1)*.08;}
        fpsFrames++;if(t-fpsAt>=1000){measuredFps=Math.round(fpsFrames*1000/(t-fpsAt));renderer.domElement.dataset.fps=String(measuredFps);renderer.domElement.dataset.drawCalls=String(renderer.info.render.calls);renderer.domElement.dataset.triangles=String(renderer.info.render.triangles);renderer.domElement.dataset.renderPixelRatio=renderPixelRatio.toFixed(2);renderer.domElement.dataset.renderResolutionPolicy='quality-locked-native-v234';collectSceneDiagnostics();fpsFrames=0;fpsAt=t;}
        // Keep authored native density stable. Runtime DPR reallocations both blur
        // the image and can themselves introduce a visible GPU stall.
        const lowFps=measuredFps<24,dynamicCadence=lowFps?70:45,occlusionCadence=lowFps?240:125,shadowCadence=220;
        updateAtmosphere(t,lowFps);
        if(telemetryDue){renderer.domElement.dataset.performanceTier=lowFps?'cadence':'full';renderer.domElement.dataset.shadowCadence=String(shadowCadence);}
        if(bridge&&t-dynamicAt>dynamicCadence){const bridgeStarted=performance.now();dynamicState=bridge.getDynamicEntities(65);syncCarSlots(dynamicState?.cars||[]);dynamicAt=t;renderer.domElement.dataset.dynamicBridgeMs=(performance.now()-bridgeStarted).toFixed(2);}const dynamic=dynamicState;if(dynamic)syncGameplayObjects(dynamic.objects||[],t);
        if(dynamic){
          const activeNpcInstances=Math.min(NPC_CAP,dynamic.npcs.length),activeRemoteInstances=Math.min(REMOTE_CAP,dynamic.players?.length||0),activeProjectileInstances=Math.min(BULLET_CAP,dynamic.projectiles?.length||0),activeBulletHoleInstances=Math.min(32,dynamic.bulletHoleFx?.length||0),activeShellInstances=Math.min(30,dynamic.shellFx?.length||0),activeBloodInstances=Math.min(BLOOD_DECAL_CAP,dynamic.bloodFx?.length||0),activeGoreInstances=Math.min(GORE_LIMB_CAP,dynamic.goreFx?.length||0);
          for(const [key,mesh] of Object.entries(npcParts))mesh.count=npcPairedPartKeys.has(key)?activeNpcInstances*2:npcQuadPartKeys.has(key)?activeNpcInstances*4:activeNpcInstances;
          corpseBloodDecals.count=activeNpcInstances;
          remotePartMeshes.forEach(mesh=>mesh.count=activeRemoteInstances);
          for(const mesh of [worldBullets,worldBulletTrails,worldBulletGlows,worldBulletCores,worldArrowShafts,worldArrowHeads,worldArrowFletching])mesh.count=activeProjectileInstances;
          bulletHoleDecals.count=activeBulletHoleInstances;shellPool.count=activeShellInstances;bloodDecals.count=activeBloodInstances;goreLimbs.count=activeGoreInstances;goreChunks.count=Math.min(GORE_CHUNK_CAP,activeGoreInstances*2);
          if(telemetryDue)renderer.domElement.dataset.activeInstanceBudget=`n${activeNpcInstances}:r${activeRemoteInstances}:p${activeProjectileInstances}:s${activeShellInstances}:b${activeBloodInstances}:g${activeGoreInstances}`;
          const liveNpcMotion=new Set(),walkingByRole={gang:0,police:0,bandit:0,civilian:0};let animatedWalkingNpcs=0,deathAnimatingNpcs=0,deathSettledNpcs=0;
          for(let i=0;i<Math.min(NPC_CAP,dynamic.npcs.length);i++){
            const src=dynamic.npcs[i],key=String(src.id??src.uid??i),sourceC=Number.isFinite(+src.visualC)?+src.visualC:Number.isFinite(+src.c)?+src.c:+src.x||0,sourceR=Number.isFinite(+src.visualR)?+src.visualR:Number.isFinite(+src.r)?+src.r:+src.y||0,rawX=(sourceC-originC)*WORLD_SCALE,rawZ=(sourceR-originR)*WORLD_SCALE,hpNow=Math.max(0,+src.hp||0),sourcePhase=+src.walkPhase||0,dead=npcIsDead(src),animBits=npcAnimationBits(src,t,dead);
            liveNpcMotion.add(key);
            let motion=npcMotionStates.get(key);
            if(!motion){const sourceDeadAt=+src.deadAt,deadStartedAt=dead&&Number.isFinite(sourceDeadAt)&&sourceDeadAt>0&&t-sourceDeadAt>=0&&t-sourceDeadAt<60000?sourceDeadAt:dead?t:0;motion={visualX:rawX,visualZ:rawZ,targetX:rawX,targetZ:rawZ,velocityX:0,velocityZ:0,lastSampleAt:t,lastMoveAt:0,gaitBlend:0,phase:sourcePhase||i*.73,lastSourcePhase:sourcePhase,lastHp:hpNow,lastSourceHitAt:+src.hitAt||0,hitUntil:0,hitSide:i%2?1:-1,deadStartedAt,deathX:dead?rawX:null,deathZ:dead?rawZ:null,animBits};npcMotionStates.set(key,motion);}else motion.animBits=animBits;
            if(dead&&(!Number.isFinite(motion.deathForward)||!Number.isFinite(motion.deathSide))){const deathImpactYaw=Number.isFinite(+src.hitAngle)?Math.PI/2-(+src.hitAngle):NaN,deathRelative=Number.isFinite(deathImpactYaw)?localAngleDelta(deathImpactYaw,npcFacingYaws[i]):NaN;motion.deathSide=Number.isFinite(deathRelative)?(Math.sin(deathRelative)>=0?1:-1):(motion.hitSide||1);motion.deathForward=Number.isFinite(deathRelative)?Math.cos(deathRelative):(Number.isFinite(motion.hitForward)?motion.hitForward:1);}
            if(dead&&!motion.deadStartedAt){motion.deadStartedAt=t;motion.deathX=motion.visualX;motion.deathZ=motion.visualZ;motion.deathSide=motion.hitSide||motion.deathSide||1;motion.deathForward=Number.isFinite(motion.hitForward)?motion.hitForward:motion.deathForward;motion.targetX=motion.visualX;motion.targetZ=motion.visualZ;motion.velocityX=motion.velocityZ=0;}else if(!dead){motion.deadStartedAt=0;motion.deathX=motion.deathZ=null;motion.deathSide=motion.deathForward=null;}
            const sourceHitAt=+src.hitAt||0,hpLost=Math.max(0,motion.lastHp-hpNow);
            if(!dead&&(hpLost>0||sourceHitAt>motion.lastSourceHitAt)){const impactYaw=Number.isFinite(+src.hitAngle)?Math.PI/2-(+src.hitAngle):NaN,relative=Number.isFinite(impactYaw)?localAngleDelta(impactYaw,npcFacingYaws[i]):NaN;motion.hitUntil=t+650;motion.hitSide=Number.isFinite(relative)?(Math.sin(relative)>=0?1:-1):(motion.hitSide>0?-1:1);motion.hitForward=Number.isFinite(relative)?Math.cos(relative):0;motion.hitStrength=Math.min(1.5,Math.max(.72,+src.hitPower||hpLost/Math.max(1,+src.maxHp||60)*3.4));motion.hitWeapon=String(src.hitWeapon||'generic');}
            motion.lastSourceHitAt=Math.max(motion.lastSourceHitAt||0,sourceHitAt);
            motion.lastHp=hpNow;
            const sourceWalking=!!(src.walking||src.moving||src.isMoving);
            motion.lastSourcePhase=sourcePhase;
            const targetDelta=Math.hypot(rawX-motion.targetX,rawZ-motion.targetZ);
            if(!dead&&targetDelta>.0005){
              const sampleDt=Math.max(.025,Math.min(.25,(t-motion.lastSampleAt)/1000)),dx=rawX-motion.targetX,dz=rawZ-motion.targetZ,speed=Math.hypot(dx,dz)/sampleDt,limit=speed>26?26/speed:1;
              if(targetDelta>14){motion.visualX=rawX;motion.visualZ=rawZ;motion.velocityX=motion.velocityZ=0;}
              else{motion.velocityX=THREE.MathUtils.lerp(motion.velocityX,dx/sampleDt*limit,.72);motion.velocityZ=THREE.MathUtils.lerp(motion.velocityZ,dz/sampleDt*limit,.72);if(targetDelta>.006)motion.lastMoveAt=t;}
              motion.targetX=rawX;motion.targetZ=rawZ;motion.lastSampleAt=t;
            }
            const measuredSpeed=Math.hypot(motion.velocityX,motion.velocityZ),recentMeasuredMove=t-motion.lastMoveAt<440&&measuredSpeed>.018,poseLocksGait=!!(animBits&(NPC_ANIM_COWER|NPC_ANIM_SURRENDER|NPC_ANIM_HELP)),panicMoving=!!(animBits&NPC_ANIM_PANIC),actuallyMoving=!dead&&!poseLocksGait&&(sourceWalking||recentMeasuredMove),motionFade=Math.max(0,1-dt*(actuallyMoving?1.8:7.5));
            if(!actuallyMoving){motion.velocityX*=motionFade;motion.velocityZ*=motionFade;}
            const gaitTarget=actuallyMoving?Math.min(1,(panicMoving?.88:.72)+Math.max(measuredSpeed,sourceWalking?2.4:0)*.075):0;
            motion.gaitBlend=THREE.MathUtils.lerp(motion.gaitBlend,gaitTarget,1-Math.exp(-dt*(actuallyMoving?14:7)));
            const crawlTarget=animBits&NPC_ANIM_CRAWL?1:0;
            if(!Number.isFinite(+motion.crawlBlend))motion.crawlBlend=0;
            motion.crawlBlend=THREE.MathUtils.lerp(motion.crawlBlend,crawlTarget,1-Math.exp(-dt*(crawlTarget?5.4:8)));
            if(motion.gaitBlend>.08&&!dead){
              animatedWalkingNpcs++;
              const role=String(src.role||src.visualRole||'').toLowerCase();
              if(src.police||src.visualRole==='police'||role.includes('police')||role.includes('cop'))walkingByRole.police++;
              else if(role.includes('bandit')||role.includes('thug')||role.includes('occupier'))walkingByRole.bandit++;
              else if(src.gang||src.visualRole==='gang'||role.includes('gang')||role.includes('boss'))walkingByRole.gang++;
              else walkingByRole.civilian++;
            }
            const prediction=recentMeasuredMove?Math.min(.055,Math.max(0,(t-motion.lastSampleAt)/1000)):0,desiredX=motion.targetX+motion.velocityX*prediction,desiredZ=motion.targetZ+motion.velocityZ*prediction,alpha=1-Math.exp(-dt*12),followDx=(desiredX-motion.visualX)*alpha,followDz=(desiredZ-motion.visualZ)*alpha,followDistance=Math.hypot(followDx,followDz),maxFollow=Math.max(.1,Math.min(.82,(Math.max(measuredSpeed,2.2)*1.25+1.2)*dt)),followScale=followDistance>maxFollow?maxFollow/followDistance:1;
            motion.visualX+=followDx*followScale;motion.visualZ+=followDz*followScale;
            if(motion.gaitBlend>.025&&!dead){const cadence=crawlTarget?1.25:panicMoving?Math.min(16.8,12.6+Math.max(measuredSpeed,sourceWalking?3.4:0)*.38):(hpNow>0&&hpNow<=Math.max(1,+src.maxHp||60)*.35?4.6:Math.min(13.2,7.6+Math.max(measuredSpeed,sourceWalking?2.4:0)*.34));motion.phase+=dt*cadence*Math.max(crawlTarget?.28:.38,motion.gaitBlend);}
            else motion.phase=THREE.MathUtils.lerp(motion.phase,sourcePhase||motion.phase,Math.min(1,dt*5));
            if(dead){motion.visualX=Number.isFinite(motion.deathX)?motion.deathX:motion.visualX;motion.visualZ=Number.isFinite(motion.deathZ)?motion.deathZ:motion.visualZ;motion.targetX=motion.visualX;motion.targetZ=motion.visualZ;motion.velocityX=motion.velocityZ=0;const deathAge=t-(motion.deadStartedAt||t);if(deathAge<760)deathAnimatingNpcs++;else deathSettledNpcs++;}
            npcVisualXs[i]=motion.visualX;npcVisualZs[i]=motion.visualZ;npcVisualPhases[i]=motion.phase;
          }
          for(const key of npcMotionStates.keys())if(!liveNpcMotion.has(key))npcMotionStates.delete(key);
          if(telemetryDue){renderer.domElement.dataset.animatedWalkingNpcs=String(animatedWalkingNpcs);renderer.domElement.dataset.walkingNpcRoles=`gang:${walkingByRole.gang},police:${walkingByRole.police},bandit:${walkingByRole.bandit},civilian:${walkingByRole.civilian}`;renderer.domElement.dataset.deathAnimatingNpcs=String(deathAnimatingNpcs);renderer.domElement.dataset.deathSettledNpcs=String(deathSettledNpcs);renderer.domElement.dataset.npcAnimationSystem='instanced-directional-life-state-v251';renderer.domElement.dataset.npcAnimationLod='near-ambient-mid-gait-far-root';}
          npcElevationLookup.clear();for(let i=0;i<(dynamic.npcs||[]).length;i++){const src=dynamic.npcs[i],x=npcVisualXs[i],z=npcVisualZs[i],lift=Math.max(0,+src.elevation||0)*WORLD_SCALE;if(lift)npcElevationLookup.set(`${x.toFixed(3)}:${z.toFixed(3)}`,lift);}
          if(telemetryDue){renderer.domElement.dataset.liveCars=String(dynamic.cars.length);renderer.domElement.dataset.liveNpcs=String(dynamic.npcs.length);renderer.domElement.dataset.liveProjectiles=String(dynamic.projectiles.length);}
          medicalScenePool.forEach((medical,i)=>{
            const src=dynamic.medicalFx?.[i];medical.root.visible=!!src;if(!src)return;
            const nx=(src.c-originC)*WORLD_SCALE,nz=(src.r-originR)*WORLD_SCALE,lift=Math.max(0,Math.min(1,+src.lift||0)),load=Math.max(0,Math.min(1,+src.load||0)),phase=String(src.phase||''),travel=Math.hypot(nx-medical.lastPosition.x,nz-medical.lastPosition.z);
            if(travel<8)medical.wheelRoll+=travel/.14;medical.lastPosition.set(nx,0,nz);
            const raised=src.carrying?.42:lift*.42,carryBob=phase==='carrying'?Math.sin(t*.014+i)*.022:0;
            medical.root.position.set(nx,.02+raised+load*.14+carryBob,nz);medical.root.rotation.y=-(+src.ang||0);medical.root.rotation.z=phase==='loading'?-load*.035:0;
            medical.body.visible=!!src.bodyVisible;medical.cross.visible=!!src.bodyVisible;medical.equipment.visible=phase!=='loading'||load<.84;
            medical.body.position.y=phase==='lifting'?(1-lift)*-.18:0;medical.cross.position.y=medical.body.position.y;
            medical.wheels.forEach((wheel,j)=>wheel.rotation.z=medical.wheelRoll*(j%2?1:-1));
          });
          if(telemetryDue){renderer.domElement.dataset.activeMedicalCrews=String(dynamic.medicalFx?.length||0);renderer.domElement.dataset.carriedBodies=String((dynamic.medicalFx||[]).filter(x=>x.bodyVisible).length);renderer.domElement.dataset.medicalRecoveryPhases=(dynamic.medicalFx||[]).map(x=>x.phase||'idle').join(',')||'idle';renderer.domElement.dataset.medicalRecoveryProfile='full-body-parking-outbound-load-moving-road-return-v232';}
          let trafficHeadingSamples=0,trafficHeadingMismatches=0;
          cars.forEach((car,i)=>{const src=car.userData.source;car.visible=!!src;if(!src)return;const nx=(src.c-originC)*WORLD_SCALE,nz=(src.r-originR)*WORLD_SCALE,travel=Math.hypot(nx-car.userData.lastPosition.x,nz-car.userData.lastPosition.z),model=String(src.model||'').toLowerCase(),isHeli=!!src.helicopter,newsHeli=isHeli&&model==='mafia_heli',police=model.includes('police')||model.includes('cop')||model.includes('paddy'),emergency=!!src.emergency,serviceKind=String(src.serviceKind||''),towLoad=!!src.towLoad,pickup=!!src.pickup,cabrio=!!src.cabrio,sport=!!src.sport,headingR=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velR:+src.dirR,headingC=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velC:+src.dirC,headingLen=Math.hypot(headingR,headingC),visualYaw=headingLen>.02?Math.atan2(-headingR,headingC):-(+src.ang||0);car.position.set(nx,isHeli?5.5:towLoad?1.38:0,nz);car.rotation.y=visualYaw;if(!isHeli&&headingLen>.03){trafficHeadingSamples++;const fx=Math.cos(car.rotation.y),fz=-Math.sin(car.rotation.y),dot=(fx*headingC+fz*headingR)/headingLen;if(dot<.985)trafficHeadingMismatches++;}car.userData.lastPosition.set(nx,0,nz);if(travel<5&&!isHeli)car.userData.wheelSpin=(car.userData.wheelSpin||0)+travel/Math.max(.35,(+src.wheelR||.18)*2.65);const sx=Math.max(.82,Math.min(1.45,(+src.length||1.7)/1.7)),sz=Math.max(.82,Math.min(1.3,(+src.width||.85)/.85)),sy=Math.max(.78,Math.min(1.32,(+src.height||.55)/.55));car.scale.set(sx,isHeli?1:sy,sz);car.userData.helicopter.visible=isHeli;car.userData.heliBody.material=newsHeli?newsRedMat:car.userData.paint;car.userData.tailBoom.material=newsHeli?newsRedMat:car.userData.paint;car.userData.newsStripe.visible=newsHeli;car.userData.newsLabels.forEach(label=>label.visible=newsHeli);car.userData.newsLightPod.visible=newsHeli;const newsLightOn=newsHeli&&environmentNight>.12,scanX=Math.sin(t*.00078+i*.73)*3.25,scanZ=Math.cos(t*.00061+i*.91)*2.75;car.userData.newsSearchTarget.position.set(scanX,-5.45,scanZ);newsBeamDirection.set(scanX-.72,-7.35,scanZ).normalize();car.userData.newsBeamPivot.quaternion.setFromUnitVectors(newsBeamDown,newsBeamDirection);car.userData.newsSearchLight.visible=newsLightOn;car.userData.newsSearchLight.intensity=newsLightOn?24+environmentNight*22:0;car.userData.newsBeamCone.visible=newsLightOn;car.userData.rotor.rotation.y=t*.018;for(const part of [car.userData.base,car.userData.hood,...car.userData.wheelMeshes])part.visible=!isHeli;car.userData.cab.visible=!isHeli&&!cabrio&&!pickup;car.userData.cab.position.set(pickup?.75:.15,sport?1.72:(src.van||src.suv?2.2:1.95),0);car.userData.pickupBed.visible=!isHeli&&pickup;car.userData.cabrioSeats.visible=!isHeli&&cabrio;car.userData.taxiSign.visible=!isHeli&&!!src.taxi;car.userData.spoiler.visible=!isHeli&&(sport||src.muscle);car.userData.roofRack.visible=!isHeli&&(src.suv||src.van)&&!emergency;car.userData.siren.visible=!isHeli&&(police||emergency);car.userData.stripe.visible=!isHeli&&(emergency||src.gang);car.userData.fireEquipment.visible=!isHeli&&serviceKind==='firetruck';car.userData.towEquipment.visible=!isHeli&&serviceKind==='tow';const showMedicalDoors=!isHeli&&serviceKind==='ambulance';car.userData.ambulanceRearDoors.visible=showMedicalDoors;car.userData.medicalDoorOpen=THREE.MathUtils.lerp(car.userData.medicalDoorOpen||0,src.medicalDoorsOpen?1:0,Math.min(1,dt*8));for(let door=0;door<car.userData.ambulanceRearDoorPivots.length;door++){const side=door?1:-1;car.userData.ambulanceRearDoorPivots[door].rotation.y=side*car.userData.medicalDoorOpen*1.32;}if(src.stripe)try{car.userData.stripe.material.color.set(src.stripe);}catch(_){}const fallbackPaint=[0xd69a2d,0x2d6e9d,0x8e2f38,0xd8d7cf,0x397b55][i%5];try{car.userData.paint.color.set(src.paint||fallbackPaint);if(car.userData.paint.color.getHex()<0x181818&&!src.gang)car.userData.paint.color.set(fallbackPaint);}catch(_){car.userData.paint.color.set(fallbackPaint);}const entry=vehicleEntryState,match=entry&&String(entry.vehicleId)===String(car.userData.entityId),p=match?Math.max(0,Math.min(1,+entry.progress||0)):0,doorTarget=match?(p<.22?p/.22:p<.72?1:Math.max(0,1-(p-.72)/.28)):(src.policeDoorsOpen?1:0);car.userData.doorOpen=THREE.MathUtils.lerp(car.userData.doorOpen||0,doorTarget,Math.min(1,dt*18));car.userData.driverDoorPivot.rotation.y=car.userData.doorOpen*1.18;car.userData.driverDoorPivot.visible=!isHeli;});if(telemetryDue){renderer.domElement.dataset.trafficHeadingSamples=String(trafficHeadingSamples);renderer.domElement.dataset.trafficHeadingMismatches=String(trafficHeadingMismatches);renderer.domElement.dataset.vehicleEntryDoor=vehicleEntryState?`${vehicleEntryState.vehicleId}:${(+vehicleEntryState.progress||0).toFixed(2)}`:'idle';renderer.domElement.dataset.fireServiceVehicles=String(dynamic.cars.filter(x=>x.serviceKind==='firetruck').length);renderer.domElement.dataset.towServiceVehicles=String(dynamic.cars.filter(x=>x.serviceKind==='tow').length);renderer.domElement.dataset.towLoadedVehicles=String(dynamic.cars.filter(x=>x.towLoad).length);renderer.domElement.dataset.ambulanceRearDoors=String(dynamic.cars.filter(x=>x.medicalDoorsOpen).length);renderer.domElement.dataset.policeArrestDoors=String(dynamic.cars.filter(x=>x.policeDoorsOpen).length);}
          if(telemetryDue){renderer.domElement.dataset.ambulanceFleetVisible=String(dynamic.cars.filter(x=>x.serviceKind==='ambulance').length);renderer.domElement.dataset.ambulanceParkedVisible=String(dynamic.cars.filter(x=>x.serviceKind==='ambulance'&&x.serviceState==='ambulance_parked').length);renderer.domElement.dataset.ambulanceResponseVisible=String(dynamic.cars.filter(x=>x.serviceKind==='ambulance'&&x.serviceState!=='ambulance_parked').length);renderer.domElement.dataset.ambulanceEmergencyVisible=String(dynamic.cars.filter(x=>x.serviceKind==='ambulance'&&x.emergencyLights).length);renderer.domElement.dataset.fireParkedVisible=String(dynamic.cars.filter(x=>x.serviceKind==='firetruck'&&x.serviceState==='firetruck_parked').length);renderer.domElement.dataset.towParkedVisible=String(dynamic.cars.filter(x=>x.serviceKind==='tow'&&x.serviceState==='tow_parked').length);}
          // Police identity may arrive on a civilian model (quest patrols).
          // The authoritative service flag therefore overrides cached paint.
          for(const car of cars){const src=car.userData.source,ux=car.userData;if(!car.visible||!src)continue;const police=!!src.policePatrol||src.emergency==='police'||src.serviceKind==='police_patrol'||/police|cop|paddy/.test(String(src.model||'').toLowerCase()),tier=Math.max(0,Math.min(3,+src.policeTier||0)),alive=!src.helicopter&&!src.wrecked&&!src.destroying&&(Number.isFinite(+src.damageRatio)?+src.damageRatio>0:true);ux.policeLivery.visible=police&&alive;ux.policeTactical.visible=police&&tier>=1;ux.policeHeavy.visible=police&&tier>=2;if(police){ux.paint.color.set(src.paint||'#19558c');ux.stripe.material.color.set(src.stripe||'#e7f0f5');ux.stripe.visible=alive;}}
          let towLoadingAnimations=0;
          cars.forEach(car=>{const src=car.userData.source,ux=car.userData;if(!car.visible||!src)return;const serviceKind=String(src.serviceKind||''),towProgress=Math.max(0,Math.min(1,+src.towLoadProgress||0)),towLoading=serviceKind==='tow'&&src.serviceState==='working',deckCycle=towLoading?(towProgress<.22?towProgress/.22:towProgress<.78?1:Math.max(0,1-(towProgress-.78)/.22)):0,deckTilt=THREE.MathUtils.lerp(-.07,-.34,deckCycle);ux.towDeck.rotation.z=deckTilt;ux.towEdges.forEach(edge=>edge.rotation.z=deckTilt);ux.towBoom.rotation.z=THREE.MathUtils.lerp(.58,.3,deckCycle);ux.towHookCable.scale.y=1+deckCycle*.72;ux.towHookCable.position.y=1.84-deckCycle*.34;if(towLoading)towLoadingAnimations++;const fireWorking=serviceKind==='firetruck'&&src.serviceState==='working'&&Number.isFinite(+src.fireHoseAngle)&&Number.isFinite(+src.fireTargetR)&&Number.isFinite(+src.fireTargetC);if(fireWorking){const rel=+src.fireHoseAngle-(+src.ang||0),worldDx=(+src.fireTargetC-(+src.c||0))*WORLD_SCALE,worldDz=(+src.fireTargetR-(+src.r||0))*WORLD_SCALE,cos=Math.cos(car.rotation.y),sin=Math.sin(car.rotation.y),targetX=(cos*worldDx-sin*worldDz)/Math.max(.01,car.scale.x),targetZ=(sin*worldDx+cos*worldDz)/Math.max(.01,car.scale.z),targetY=1.02/Math.max(.01,car.scale.y),startX=1.18,startY=3.18,startZ=0,arcLift=2.05+Math.min(1.65,Math.hypot(targetX-startX,targetZ)*.055),streamPulse=.94+Math.sin(t*.024)*.055;ux.hoseCannon.rotation.y=THREE.MathUtils.lerp(ux.hoseCannon.rotation.y||0,-rel,Math.min(1,dt*7));ux.fireWaterGroup.visible=true;for(let s=0;s<ux.fireWaterSegments.length;s++){const u0=s/ux.fireWaterSegments.length,u1=(s+1)/ux.fireWaterSegments.length,wobble0=Math.sin(t*.012+s*.94)*.055*u0,wobble1=Math.sin(t*.012+(s+1)*.94)*.055*u1;ux.fireWaterA.set(THREE.MathUtils.lerp(startX,targetX,u0),THREE.MathUtils.lerp(startY,targetY,u0)+Math.sin(Math.PI*u0)*arcLift,THREE.MathUtils.lerp(startZ,targetZ,u0)+wobble0);ux.fireWaterB.set(THREE.MathUtils.lerp(startX,targetX,u1),THREE.MathUtils.lerp(startY,targetY,u1)+Math.sin(Math.PI*u1)*arcLift,THREE.MathUtils.lerp(startZ,targetZ,u1)+wobble1);const segment=ux.fireWaterSegments[s];segment.position.copy(ux.fireWaterA).add(ux.fireWaterB).multiplyScalar(.5);ux.fireWaterDirection.copy(ux.fireWaterB).sub(ux.fireWaterA);const length=ux.fireWaterDirection.length();segment.quaternion.setFromUnitVectors(ux.fireWaterUp,ux.fireWaterDirection.normalize());const taper=streamPulse*(1-s/ux.fireWaterSegments.length*.28);segment.scale.set(taper,length*1.065,taper);}ux.fireWaterImpact.position.set(targetX,.1/Math.max(.01,car.scale.y),targetZ);const splashPulse=1+Math.sin(t*.017)*.16;ux.fireWaterImpactDisc.scale.setScalar(splashPulse);ux.fireWaterImpactCore.scale.setScalar(.76+splashPulse*.18);for(let d=0;d<ux.fireWaterMist.length;d++){const drop=ux.fireWaterMist[d],phase=(t*.00115+d*.137)%1,a=d*2.399+t*.0017,radius=.28+phase*1.65;drop.position.set(Math.cos(a)*radius,.18+Math.sin(phase*Math.PI)*(1.2+(d%4)*.22),Math.sin(a)*radius);drop.scale.setScalar(.75+(1-phase)*1.15);drop.material.opacity=(1-phase)*(d%4?.52:.86);}}else{ux.hoseCannon.rotation.y=THREE.MathUtils.lerp(ux.hoseCannon.rotation.y||0,0,Math.min(1,dt*5));ux.fireWaterGroup.visible=false;}});
          let visiblePoliceTurrets=0,activePoliceTurrets=0;for(const car of cars){const src=car.userData.source,ux=car.userData;if(!car.visible||!src)continue;const show=!!src.armoredPoliceVan&&!!src.roofGunner&&!src.turretDisabled;ux.policeTurret.visible=show;if(!show)continue;visiblePoliceTurrets++;const relative=-(+src.turretAng-(+src.ang||0));ux.policeTurretGunPivot.rotation.y=THREE.MathUtils.lerp(ux.policeTurretGunPivot.rotation.y||0,relative,Math.min(1,dt*9));ux.policeTurretMuzzle.visible=performance.now()-(+src.turretFlashAt||0)<95;if(src.turretActive)activePoliceTurrets++;}
          if(telemetryDue){renderer.domElement.dataset.policeArmoredVanTurrets=`visible:${visiblePoliceTurrets},active:${activePoliceTurrets}`;renderer.domElement.dataset.towLoadingAnimations=String(towLoadingAnimations);renderer.domElement.dataset.fireWaterProfile='continuous-volumetric-hose-splash-v273';renderer.domElement.dataset.persistentServiceFleetProfile='visible-parking-call-road-return-reuse-v230';}
          for(const car of cars){const src=car.userData.source;if(!src?.serviceKind)continue;const active=src.emergencyLights===true,police=!!src.policePatrol||src.emergency==='police'||src.serviceKind==='police_patrol';car.userData.siren.visible=active||police;car.userData.stripe.visible=true;for(let lamp=0;lamp<car.userData.siren.children.length;lamp++)car.userData.siren.children[lamp].visible=police&&!active||active&&lamp===Math.floor(t/170)%car.userData.siren.children.length;}
          for(const car of cars){const src=car.userData.source;if(src?.serviceKind==='tow'&&!src.helicopter&&!src.wrecked)car.userData.cab.visible=true;}
          const liveNpcFacing=new Set();let npcHeadingSamples=0,npcHeadingMismatches=0;for(let i=0;i<Math.min(NPC_CAP,dynamic.npcs.length);i++){const src=dynamic.npcs[i],key=String(src.id??src.uid??i),x=npcVisualXs[i],z=npcVisualZs[i],fallbackYaw=Math.PI/2-(+src.ang||0);liveNpcFacing.add(key);let state=npcFacingStates.get(key);if(!state){state={lastX:x,lastZ:z,targetYaw:fallbackYaw,visualYaw:fallbackYaw,lastMoveAt:0,moveX:0,moveZ:1};npcFacingStates.set(key,state);}const dx=x-state.lastX,dz=z-state.lastZ,distance=Math.hypot(dx,dz);if(distance>.004&&distance<14){state.targetYaw=Math.atan2(dx,dz);state.lastMoveAt=t;state.moveX=dx/distance;state.moveZ=dz/distance;}else if(distance>=14){state.targetYaw=fallbackYaw;state.visualYaw=fallbackYaw;}state.lastX=x;state.lastZ=z;state.visualYaw+=wrapAngle(state.targetYaw-state.visualYaw)*Math.min(1,dt*10);npcFacingYaws[i]=state.visualYaw;if(t-state.lastMoveAt<320){npcHeadingSamples++;const dot=Math.sin(state.visualYaw)*state.moveX+Math.cos(state.visualYaw)*state.moveZ;if(dot<.7)npcHeadingMismatches++;}}for(const key of npcFacingStates.keys())if(!liveNpcFacing.has(key))npcFacingStates.delete(key);if(telemetryDue){renderer.domElement.dataset.npcHeadingSamples=String(npcHeadingSamples);renderer.domElement.dataset.npcHeadingMismatches=String(npcHeadingMismatches);}
          cars.forEach(car=>{const src=car.userData.source;if(!car.visible||!src)return;const damageRatio=Math.max(0,Math.min(1,Number.isFinite(+src.damageRatio)?+src.damageRatio:1)),destroying=!!src.destroying,wrecked=!src.helicopter&&(!!src.wrecked||damageRatio<=0&&!destroying),burnedOut=!!src.burnedOut,smoking=!src.helicopter&&!wrecked&&(destroying||!!src.smoking||damageRatio<=.55),burning=!src.helicopter&&!destroying&&!burnedOut&&(wrecked||!!src.burning||damageRatio<=.24),wreckAge=Math.max(0,+src.wreckAge||0),destroyPct=destroying?Math.max(0,Math.min(1,(+src.destroyAge||0)/Math.max(1,+src.destroyDelay||1450))):0;car.userData.wreckGroup.visible=wrecked;car.userData.damageFx.visible=!wrecked&&(smoking||burning);car.userData.damageSmoke.forEach((puff,s)=>{puff.visible=smoking;const q=(t*(destroying?.0005:.00032)+s*.137)%1,drift=Math.sin(t*.0012+s*2.1)*(.22+destroyPct*.48);puff.position.set(drift,q*(2.6+destroyPct*2.2),Math.cos(s*1.7)*(.18+destroyPct*.34));puff.scale.setScalar(.55+q*1.5+destroyPct*(.65+s%3*.16));puff.material.opacity=(1-q)*(destroying?.5+.22*destroyPct:burning?.52:.3);});car.userData.damageFlames.forEach((flame,s)=>{flame.visible=burning&&!wrecked;const flick=.72+.28*Math.sin(t*.021+s*1.9);flame.position.set(Math.sin(s*2.4)*.22,.22+s*.11,Math.cos(s*2.1)*.2);flame.scale.set(.8,flick,.8);});car.userData.bodyHoles.forEach((hole,h)=>hole.visible=!wrecked&&!src.helicopter&&h<Math.min(10,+src.bulletHoles||0));if(wrecked){for(const part of [car.userData.base,car.userData.cab,car.userData.hood,...car.userData.wheelMeshes,car.userData.driverDoorPivot,car.userData.taxiSign,car.userData.spoiler,car.userData.pickupBed,car.userData.roofRack,car.userData.cabrioSeats,car.userData.stripe,car.userData.fireEquipment,car.userData.towEquipment])part.visible=false;const kick=Math.max(0,1-wreckAge/1350),landing=Math.sin(Math.min(1,wreckAge/950)*Math.PI*3)*kick;car.userData.wreckGroup.position.y=Math.max(0,landing*.48);car.userData.wreckGroup.rotation.x=Math.sin(Math.min(1,wreckAge/1050)*Math.PI)*kick*.1;car.userData.wreckGroup.rotation.z=.025+Math.sin(Math.min(1,wreckAge/1200)*Math.PI*2)*kick*.075;car.userData.wreckHeat.visible=burning;car.userData.wreckHeat.material.opacity=burning?.38+.2*Math.sin(t*.018):0;car.userData.wreckGlow.intensity=burning?12+Math.sin(t*.016)*4:0;car.userData.wreckFlames.forEach((flame,s)=>{flame.visible=burning;const a=s*2.31,flick=.68+.32*Math.sin(t*.022+s*1.73),spread=.42+(s%5)*.4;flame.position.set(Math.cos(a)*spread+.25,.82+(s%3)*.28,Math.sin(a)*Math.min(1.28,spread));flame.scale.set(1.15+flick*.42,flick*(1.72+(s%4)*.3),1.15+flick*.36);flame.rotation.z=Math.sin(t*.009+s)*.17;});car.userData.wreckSmoke.forEach((puff,s)=>{puff.visible=!burnedOut;const q=(t*.00024+s*.111)%1;puff.position.set(Math.sin(t*.0007+s*2.1)*(1+q*.55),1.05+q*5.1,Math.cos(s*1.71)*(1+q*.42));puff.scale.setScalar(.6+q*2.15);puff.material.opacity=(1-q)*(burning?.42:.25);});car.userData.wreckDebris.forEach((shard,s)=>{const flight=Math.min(1,wreckAge/1250),a=s*2.399,travel=(2.1+(s%4)*.72)*Math.sin(flight*Math.PI*.5);shard.visible=true;shard.position.set(Math.cos(a)*travel,.16+Math.sin(flight*Math.PI)*(1.4+(s%5)*.38),Math.sin(a)*travel);shard.rotation.set(flight*(s+2)*4.2,flight*(s+1)*5.1,flight*(s+3)*3.7);});car.userData.wreckBreakaway.forEach((part,s)=>{const flight=Math.max(0,Math.min(1,wreckAge/(1050+(s%3)*150))),ease=1-Math.pow(1-flight,2);part.visible=true;part.position.set(part.userData.tx*ease,.14+Math.sin(flight*Math.PI)*part.userData.lift,part.userData.tz*ease);part.rotation.set(flight*part.userData.spinX,flight*part.userData.spinY,flight*part.userData.spinZ);});car.userData.paint.color.lerp(wreckedCarColor,.3);car.userData.contactShadow.scale.set(1.22,1.18,1);}else{car.userData.wreckGlow.intensity=0;car.userData.contactShadow.scale.set(1,1,1);}});if(telemetryDue)renderer.domElement.dataset.damagedVehicles=String(dynamic.cars.filter(x=>(+x.damageRatio||1)<1||x.wrecked||x.destroying).length);
          // Only the two closest rendered wreck slots keep animated flame/smoke
          // layers. The other wrecks remain fully visible as static burned shells,
          // so a pile-up cannot multiply transparent draw calls without bound.
          let animatedWreckFx=0;
          for(const car of cars){
            const src=car.userData.source,ux=car.userData;if(!car.visible||!src)continue;
            const ratio=Math.max(0,Math.min(1,Number.isFinite(+src.damageRatio)?+src.damageRatio:1));
            const wrecked=!src.helicopter&&(!!src.wrecked||ratio<=0&&!src.destroying);
            // Keep the already-uploaded live shell and char it in place. Swapping
            // five cars to five unique wreck geometry trees on the explosion
            // frame was the remaining multi-second GPU upload hitch.
            if(wrecked){
              ux.wreckGroup.visible=false;ux.paint.color.setHex(0x080706);ux.paint.roughness=.98;ux.paint.metalness=.12;if('clearcoat' in ux.paint)ux.paint.clearcoat=0;ux.base.visible=ux.hood.visible=ux.driverDoorPivot.visible=true;
              ux.cab.visible=false;ux.wheelMeshes.forEach((part,wi)=>part.visible=wi===0);
              ux.pickupBed.visible=ux.cabrioSeats.visible=false;
              ux.taxiSign.visible=ux.spoiler.visible=ux.roofRack.visible=ux.stripe.visible=false;
              ux.fireEquipment.visible=ux.towEquipment.visible=ux.ambulanceRearDoors.visible=ux.siren.visible=false;
            }
            ux.wreckFlames.mesh.visible=false;ux.wreckSmoke.mesh.visible=false;ux.wreckDebris.mesh.visible=false;
          }
          if(telemetryDue){renderer.domElement.dataset.animatedWreckFx=String(animatedWreckFx);renderer.domElement.dataset.wreckRenderProfile='collapsed-charred-live-shell-v199';}
          let activeWreckLights=0;const maxWreckLights=0;
          for(const car of cars){
            const light=car.userData.wreckGlow,lit=car.visible&&car.userData.wreckGroup.visible&&light.intensity>0&&activeWreckLights<maxWreckLights;
            light.visible=lit;if(lit)activeWreckLights++;
          }
          if(telemetryDue)renderer.domElement.dataset.activeWreckLights=String(activeWreckLights);
          cars.forEach((car,i)=>{
            const src=car.userData.source;if(!car.visible||!src)return;
            const ux=car.userData,damageRatio=Math.max(0,Math.min(1,Number.isFinite(+src.damageRatio)?+src.damageRatio:1)),destroying=!!src.destroying,wrecked=!src.helicopter&&(!!src.wrecked||damageRatio<=0&&!destroying),isHeli=!!src.helicopter;
            if(wrecked){
              for(const part of ux.standardParts)part.visible=false;
              ux.wreckVisibilityApplied=true;
              const settle=Math.max(0,Math.min(1,(+src.wreckAge||0)/650)),ease=1-Math.pow(1-settle,3);
              ux.wreckGroup.scale.setScalar(.84+.16*ease);
              ux.hood.rotation.z=0;ux.hood.position.y=ux.hoodBaseY;
            }else{
              car.rotation.z=0;ux.paint.roughness=.2;ux.paint.metalness=.42;if('clearcoat' in ux.paint)ux.paint.clearcoat=1;ux.base.scale.set(1,1,1);ux.base.position.y=ux.baseBaseY;ux.base.rotation.z=0;ux.hood.rotation.y=0;
              if(ux.wreckVisibilityApplied){
                for(const part of ux.standardParts)part.visible=!isHeli;
                ux.base.visible=ux.hood.visible=!isHeli;
                ux.wheelMeshes.forEach(part=>part.visible=!isHeli);
                ux.cab.visible=!isHeli&&!src.cabrio&&!src.pickup;
                ux.driverDoorPivot.visible=!isHeli;
                ux.wreckVisibilityApplied=false;
              }
              ux.wreckGroup.scale.setScalar(1);
              ux.damageBlend=THREE.MathUtils.lerp(ux.damageBlend||0,1-damageRatio,Math.min(1,dt*8));
              const hitAge=Math.max(0,+src.hitAge||9999),hitPulse=Math.max(0,1-hitAge/175),destroyPct=destroying?Math.max(0,Math.min(1,(+src.destroyAge||0)/Math.max(1,+src.destroyDelay||1450))):0,criticalJolt=destroying?Math.sin(t*.034+i*1.7)*(.025+destroyPct*.055):0,jolt=Math.sin(hitAge*.105+i)*hitPulse+criticalJolt;
              ux.hood.position.y=ux.hoodBaseY+Math.max(0,ux.damageBlend-.32)*.085+hitPulse*.025+(destroying?destroyPct*.09:0);
              ux.hood.rotation.z=(ux.damageBlend>.46?-(ux.damageBlend-.46)*.11:0)+jolt*.028+(destroying?Math.sin(t*.019)*destroyPct*.035:0);
              ux.driverDoorPivot.rotation.x=ux.damageBlend>.72?(ux.damageBlend-.72)*.12:0;
            }
          });
          let visibleVehicleMarks=0;cars.forEach(car=>{const src=car.userData.source;if(!car.visible||!src)return;const wrecked=!src.helicopter&&(!!src.wrecked||Math.max(0,Math.min(1,Number.isFinite(+src.damageRatio)?+src.damageRatio:1))<=0&&!src.destroying);updateVehicleHitMarks(car,src,wrecked);visibleVehicleMarks+=Math.min(10,Array.isArray(src.bulletMarks)?src.bulletMarks.length:+src.bulletHoles||0);});if(telemetryDue)renderer.domElement.dataset.vehicleBulletMarks=String(visibleVehicleMarks);
          // Apply the light-weight wreck shell after every vehicle visibility
          // pass; the detailed wreck branch above intentionally hides live parts.
          for(const car of cars){const src=car.userData.source,ux=car.userData;if(!car.visible||!src)continue;const ratio=Math.max(0,Math.min(1,Number.isFinite(+src.damageRatio)?+src.damageRatio:1)),wrecked=!src.helicopter&&(!!src.wrecked||ratio<=0&&!src.destroying);if(!wrecked)continue;ux.wreckGroup.visible=false;car.rotation.z=-.035;ux.paint.color.setHex(0x080706);ux.paint.roughness=.98;ux.paint.metalness=.12;if('clearcoat' in ux.paint)ux.paint.clearcoat=0;ux.base.visible=ux.hood.visible=ux.driverDoorPivot.visible=true;ux.base.scale.set(1,.58,1);ux.base.position.y=.48;ux.base.rotation.z=-.055;ux.hood.position.y=ux.hoodBaseY+.18;ux.hood.rotation.y=.08;ux.hood.rotation.z=-.24;ux.driverDoorPivot.rotation.y=1.02;ux.driverDoorPivot.rotation.x=-.18;ux.cab.visible=false;ux.wheelMeshes.forEach((part,wi)=>part.visible=wi===0);ux.pickupBed.visible=ux.cabrioSeats.visible=false;ux.taxiSign.visible=ux.spoiler.visible=ux.roofRack.visible=ux.stripe.visible=false;ux.fireEquipment.visible=ux.towEquipment.visible=ux.ambulanceRearDoors.visible=ux.siren.visible=false;}
          let towCarriedWrecks=0;
          for(const car of cars){const src=car.userData.source;if(!car.visible||!src?.towLoad)continue;const p=Math.max(0,Math.min(1,+src.towLoadProgress||0)),lift=p*p*(3-2*p);car.position.y=THREE.MathUtils.lerp(.04,1.38,lift);car.rotation.z=THREE.MathUtils.lerp(-.16,-.035,lift);car.rotation.x=Math.sin(p*Math.PI)*.075;if(p>=.98)towCarriedWrecks++;}
          if(telemetryDue){renderer.domElement.dataset.towCarriedWrecks=String(towCarriedWrecks);renderer.domElement.dataset.towLoadingProfile='winch-deck-lift-carry-v230';}
          let crawlingNpcCount=0,limpingNpcCount=0,reactingNpcCount=0,bleedingNpcCount=0,panickingNpcCount=0,coweringNpcCount=0,surrenderingNpcCount=0,helpingNpcCount=0,socialNpcCount=0,alertedNpcCount=0,ambientNpcCount=0,firingPoliceCount=0,firingGuardCount=0,walkingArmNpcCount=0,blinkingNpcCount=0,npcEmpireWeaponColorsDirty=false;
          citizenPool.forEach((npc,i)=>{
            const src=dynamic.npcs[i];if(!src){hideNpcVisual(i);return;}
            const x=npcVisualXs[i],z=npcVisualZs[i],pose=npcFramePoses[i]=npcAnimationPose(src,i,t),role=String(src.role||'').toLowerCase(),look=src.look||{},police=src.visualRole==='police'||!!src.police||role.includes('police')||role.includes('cop'),medic=role.includes('medic'),empireBoss=!!src.empireBoss,armed=empireBoss||role.includes('gang')||role.includes('boss')||role.includes('guard')||police,bodyColor=medic?0xe8f2f4:police?0x245f9b:empireBoss?0x6b2730:role.includes('gang')||role.includes('boss')||role.includes('guard')?0xd94f61:[0x52b8ee,0xf0717f,0x8acb63,0xefae46,0xa184dc][i%5];
            if(pose.crawling)crawlingNpcCount++;else if(pose.limping)limpingNpcCount++;if(pose.hit>0)reactingNpcCount++;if(pose.walking&&!pose.firing)walkingArmNpcCount++;if(pose.firing&&police)firingPoliceCount++;if(pose.firing&&!police&&(src.visualRole==='guard'||role.includes('guard')))firingGuardCount++;if(pose.panicking)panickingNpcCount++;else if(pose.cowering)coweringNpcCount++;else if(pose.surrendering)surrenderingNpcCount++;else if(pose.helping)helpingNpcCount++;else if(pose.talking)socialNpcCount++;else if(pose.alerted)alertedNpcCount++;else if(pose.ambientKind)ambientNpcCount++;
            const medicAction=medic?String(src.medicAction||''):'',medicActionProgress=Math.max(0,Math.min(1,+src.medicActionProgress||0)),medicCrouch=medicAction==='assessing'?.38+.045*Math.sin(t*.012+i):medicAction==='lifting'?Math.sin(medicActionProgress*Math.PI)*.34:0,medicReach=medicAction==='assessing'||medicAction==='lifting';
            const bodyIndex=Math.abs(+look.body||0)%NPC_BODY_PROFILES.length,bodyProfile=NPC_BODY_PROFILES[bodyIndex],female=+look.gender===1,faceStyle=Math.abs(+look.face||0)%10,shoulderScale=female?.82:1,hipScale=female?1.08:1,depthScale=female?.94:1,shoulderX=.78*bodyProfile.shoulder*shoulderScale,armScale=bodyProfile.arm*(female?.9:1),legScale=bodyProfile.leg*(female?.92:1),hipWidth=bodyProfile.hip*hipScale;
            const breath=pose.walking||pose.firing?1:1+pose.idle*.014;
            setNpcRoot(pose,i,x,z);npcBodyScale.set(bodyProfile.bodyX*shoulderScale*breath,pose.cowering?.92:pose.walking?1:1+pose.idle*.018,bodyProfile.bodyZ*depthScale*breath);
            setPart(npcParts.body,i,rootMatrix,0,2.05-pose.crouch-pose.hit*.08-medicCrouch,0,-pose.hit*.09,npcBodyScale,pose.torsoTwist,pose.shoulderSway);
            setPart(npcParts.shirtFront,i,rootMatrix,0,2.18-pose.crouch-medicCrouch,.5*bodyProfile.bodyZ*depthScale,0,instanceScale.set(bodyProfile.bodyX*shoulderScale*(female?.78:1),1,1),pose.torsoTwist,pose.shoulderSway);
            const tailored=empireBoss||src.visualRole==='owner'||(!police&&!medic&&(bodyIndex+faceStyle)%3===0);tailored?setPart(npcParts.collar,i,rootMatrix,0,2.55-pose.crouch-medicCrouch,.54*bodyProfile.bodyZ*depthScale,0,instanceScale.set(bodyProfile.bodyX*shoulderScale,1,1),pose.torsoTwist,pose.shoulderSway):hidePart(npcParts.collar,i);
            const roleHemOn=empireBoss||police||medic||src.visualRole==='owner'||role.includes('guard')||(female&&(faceStyle+bodyIndex)%2===0);roleHemOn?setPart(npcParts.roleHem,i,rootMatrix,0,1.35-pose.crouch*.42-medicCrouch*.3,0,0,instanceScale.set(hipWidth*(female?1.08:.96),female?1.08:.9,bodyProfile.bodyZ*depthScale*.92),pose.torsoTwist,pose.shoulderSway):hidePart(npcParts.roleHem,i);
            if(female)setPart(npcParts.femaleHips,i,rootMatrix,0,1.35-pose.crouch*.45-medicCrouch*.35,0,0,instanceScale.set(hipWidth*1.14,.72,bodyProfile.bodyZ*depthScale*.94));else hidePart(npcParts.femaleHips,i);
            const faceX=(female?.94:1)*(faceStyle===7?1.08:faceStyle===5?.94:1),faceYScale=faceStyle===1?1.08:faceStyle===6?.94:1,faceZ=female?.95:1;
            setPart(npcParts.head,i,rootMatrix,pose.hit*pose.hitSide*.08,3.3-pose.crouch+(pose.walking?0:pose.idle*.025)-medicCrouch,0,pose.hit*.12*pose.hitSide,instanceScale.set(faceX,faceYScale,faceZ),pose.headCounter,pose.headTilt);
            const faceY=3.3-pose.crouch-medicCrouch;
            setPart(npcParts.jaw,i,rootMatrix,0,faceY-.19,.015,0,instanceScale.set(faceX*(faceStyle===7?1.06:.96),faceStyle===1?.7:.62,faceZ*.92),pose.headCounter,pose.headTilt);
            if(!female&&(faceStyle===2||faceStyle===9))setPart(npcParts.beard,i,rootMatrix,0,faceY,0,0,instanceScale.set(faceX,faceYScale,faceZ),pose.headCounter,pose.headTilt);else hidePart(npcParts.beard,i);
            setPart(npcParts.nose,i,rootMatrix,0,faceY-.08,.465,Math.PI/2,instanceScale.set(1+(faceStyle%3)*.09,1,1),pose.headCounter,pose.headTilt);
            setPart(npcParts.mouth,i,rootMatrix,0,faceY-.27,.455,0,instanceScale.set(faceStyle===3?1.35:1,1,1),pose.headCounter,faceStyle===5?-.18:faceStyle===6?.12:pose.headTilt);
            const browTilt=[0,.28,-.08,.05,.12,-.28,-.18,.1,.02,.2][faceStyle];for(const [browIndex,sx] of [[i*2,-.17],[i*2+1,.17]])setPart(npcParts.brow,browIndex,rootMatrix,sx,faceY+.2,.445,0,unitScale,pose.headCounter,sx>0?-browTilt:browTilt);
            for(const [earIndex,sx] of [[i*2,-.44],[i*2+1,.44]])setPart(npcParts.ear,earIndex,rootMatrix,sx,faceY-.01,0,0,instanceScale.set(.55,1,.55),pose.headCounter,pose.headTilt);
            if(female){setPart(npcParts.femaleLashes,i,rootMatrix,0,faceY+.13,.475,0,unitScale,pose.headCounter,pose.headTilt);setPart(npcParts.femaleLips,i,rootMatrix,0,faceY-.27,.478,0,unitScale,pose.headCounter,pose.headTilt);}else{hidePart(npcParts.femaleLashes,i);hidePart(npcParts.femaleLips,i);}
            // Player-proportioned hip overlap keeps the top of each rotating leg
            // inside the shirt throughout the stride instead of exposing it at
            // the waist on turquoise and other light-coloured outfits.
            const legX=.34*hipWidth;setPart(npcParts.leftLeg,i,rootMatrix,-legX,.72+pose.leftLift-pose.crouch*.16-medicCrouch*.16,0,pose.leftSwing+pose.legBend+medicCrouch*.52,instanceScale.set(legScale,1,legScale));
            setPart(npcParts.rightLeg,i,rootMatrix,legX,.72+pose.rightLift-pose.crouch*.16-medicCrouch*.16,0,pose.rightSwing-pose.legBend-medicCrouch*.52,instanceScale.set(legScale,1,legScale));
            setPart(npcParts.shoe,i*2,rootMatrix,-legX,.09+pose.leftLift,.18,pose.leftFootPitch,instanceScale.set(legScale,1,legScale));
            setPart(npcParts.shoe,i*2+1,rootMatrix,legX,.09+pose.rightLift,.18,pose.rightFootPitch,instanceScale.set(legScale,1,legScale));
            const medicArmY=src.medicCarry?1.94:medicReach?1.9-medicCrouch*.55:pose.armY,medicArmZ=src.medicCarry||medicReach?.34:pose.armZ,medicArmPitch=src.medicCarry?-.72:medicReach?-1.02:NaN,lifeArmPose=!Number.isFinite(medicArmPitch);
            const leftArmX=lifeArmPose?Math.sign(pose.leftArmX||-1)*shoulderX:-shoulderX,rightArmX=lifeArmPose?Math.sign(pose.rightArmX||1)*shoulderX:shoulderX,leftPitch=lifeArmPose?pose.leftArmPitch-pose.hit*.42*pose.hitSide:medicArmPitch,rightPitch=lifeArmPose?pose.rightArmPitch+pose.hit*.36*pose.hitSide:medicArmPitch,leftYaw=lifeArmPose?pose.leftArmYaw:0,rightYaw=lifeArmPose?pose.rightArmYaw:0,leftRoll=lifeArmPose?pose.leftArmRoll:0,rightRoll=lifeArmPose?pose.rightArmRoll:0,armPartScale=instanceScale.set(armScale,1,armScale*(female?.94:1));
            setPart(npcParts.leftArm,i,rootMatrix,leftArmX,medicArmY,medicArmZ,leftPitch,armPartScale,leftYaw,leftRoll);setPart(npcParts.rightArm,i,rootMatrix,rightArmX,medicArmY,medicArmZ,rightPitch,armPartScale,rightYaw,rightRoll);
            for(const side of [-1,1]){const pitch=side<0?leftPitch:rightPitch,yaw=side<0?leftYaw:rightYaw,roll=side<0?leftRoll:rightRoll,ax=side<0?leftArmX:rightArmX,handIndex=i*2+(side>0?1:0),elbowBend=pose.firing?.38:pose.phoneCalling?.5:medicReach?.42:pose.cowering?.32:pose.walking?.1+Math.abs(pitch)*.08:.08;npcLimbQuat.setFromEuler(instanceEuler.set(pitch,yaw,roll));npcElbowOffset.set(0,-.4,0).applyQuaternion(npcLimbQuat);npcLimbQuat.setFromEuler(instanceEuler.set(pitch+elbowBend,yaw,roll));npcForearmOffset.set(0,-.34,0).applyQuaternion(npcLimbQuat);npcLimbOffset.set(0,-.72,0).applyQuaternion(npcLimbQuat);setPart(npcParts.forearm,handIndex,rootMatrix,ax+npcElbowOffset.x+npcForearmOffset.x,medicArmY+npcElbowOffset.y+npcForearmOffset.y,medicArmZ+npcElbowOffset.z+npcForearmOffset.z,pitch+elbowBend,instanceScale.set(armScale*.94,1,armScale*(female?.9:1)),yaw,roll);setPart(npcParts.hand,handIndex,rootMatrix,ax+npcElbowOffset.x+npcLimbOffset.x,medicArmY+npcElbowOffset.y+npcLimbOffset.y,medicArmZ+npcElbowOffset.z+npcLimbOffset.z,0,instanceScale.set(armScale,armScale,armScale));}
            pose.phoneCalling?setPart(npcParts.phone,i,rootMatrix,.49,3.18,.35,-.12,instanceScale.set(.95,1,.95),.18,.1):hidePart(npcParts.phone,i);
            const severMask=+src.severMask||0;
            if(severMask&1){hidePart(npcParts.leftArm,i);hidePart(npcParts.forearm,i*2);hidePart(npcParts.hand,i*2);}
            if(severMask&2){hidePart(npcParts.rightArm,i);hidePart(npcParts.forearm,i*2+1);hidePart(npcParts.hand,i*2+1);}
            if(severMask&4){hidePart(npcParts.leftLeg,i);hidePart(npcParts.shoe,i*2);}
            if(severMask&8){hidePart(npcParts.rightLeg,i);hidePart(npcParts.shoe,i*2+1);}
            if(src.bleeding&&!pose.dead){
              bleedingNpcCount++;
              const woundSide=((i*1103515245+12345)&1)?1:-1,drip=((t+i*137)%620)/620;
              const bleedPower=Math.max(.7,Math.min(1.7,+src.bleedSeverity||1));
              setPart(npcParts.wound,i,rootMatrix,woundSide*.42,2.38,.39,pose.hit*.18*woundSide,instanceScale.setScalar(.82+bleedPower*.24));
              setPart(npcParts.bloodDrop,i,rootMatrix,woundSide*.44,2.22-drip*(1.5+bleedPower*.42),.4,0,instanceScale.setScalar(.72+bleedPower*.28));
            }else{hidePart(npcParts.wound,i);hidePart(npcParts.bloodDrop,i);}
            const blinkPhase=(t*.0015+i*.731)%4.6,blink=blinkPhase<.075?.08:1,gazeX=Math.sin(t*.00047+i*1.91)*.025,gazeY=Math.sin(t*.00031+i*.83)*.012,ageEye=faceStyle===8?.82:1;if(blink<1)blinkingNpcCount++;
            for(const [eyeIndex,sx] of [[i*2,-.17],[i*2+1,.17]]){setPart(npcParts.eyeWhite,eyeIndex,rootMatrix,sx,3.37-pose.crouch,.405,0,instanceScale.set(1,.78*blink*ageEye,.42),pose.headCounter,pose.headTilt);setPart(npcParts.pupil,eyeIndex,rootMatrix,sx+gazeX,3.37-pose.crouch+gazeY,.455,0,instanceScale.set(1,.78*blink*ageEye,.3),pose.headCounter,pose.headTilt);}
            armed?setPart(npcParts.hat,i,rootMatrix,0,3.77-pose.crouch,0):hidePart(npcParts.hat,i);
            if(armed)npcEmpireWeaponColorsDirty=renderNpcEmpireWeapon(src,i,rootMatrix,pose,severMask,t)||npcEmpireWeaponColorsDirty;
            else{hidePart(npcParts.gun,i);hideNpcEmpireWeapon(i);npcEmpireWeaponColorSignatures[i]='';}
          });
          Object.values(npcParts).forEach(mesh=>{mesh.instanceMatrix.needsUpdate=true;});if(npcEmpireWeaponColorsDirty)for(const mesh of npcEmpireWeaponMeshes)if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;if(telemetryDue){renderer.domElement.dataset.crawlingNpcs=String(crawlingNpcCount);renderer.domElement.dataset.limpingNpcs=String(limpingNpcCount);renderer.domElement.dataset.hitReactingNpcs=String(reactingNpcCount);renderer.domElement.dataset.bleedingNpcs=String(bleedingNpcCount);renderer.domElement.dataset.panickingNpcs=String(panickingNpcCount);renderer.domElement.dataset.coweringNpcs=String(coweringNpcCount);renderer.domElement.dataset.surrenderingNpcs=String(surrenderingNpcCount);renderer.domElement.dataset.helpingNpcs=String(helpingNpcCount);renderer.domElement.dataset.socialNpcs=String(socialNpcCount);renderer.domElement.dataset.alertedNpcs=String(alertedNpcCount);renderer.domElement.dataset.npcLifeAnimationStates=`panic:${panickingNpcCount},cower:${coweringNpcCount},surrender:${surrenderingNpcCount},help:${helpingNpcCount},social:${socialNpcCount},alert:${alertedNpcCount}`;renderer.domElement.dataset.npcLifeAnimationProfile='instanced-priority-poses-v234';renderer.domElement.dataset.injuryLocomotion='life-state-compatible-limp-critical-crawl-v234';renderer.domElement.dataset.npcFootPlant='player-stride-deep-hip-overlap-v212';renderer.domElement.dataset.npcGaitSource='player-character-plus-life-state-v234';renderer.domElement.dataset.npcHipOverlapMinimum=(.72+.625*Math.cos(.72)-1.15).toFixed(3);}
          if(telemetryDue){renderer.domElement.dataset.ambientNpcAnimations=String(ambientNpcCount);renderer.domElement.dataset.npcAmbientProfile='phone-smoke-stretch-deterministic-lod-v251';renderer.domElement.dataset.walkingArmNpcs=String(walkingArmNpcCount);renderer.domElement.dataset.blinkingNpcs=String(blinkingNpcCount);renderer.domElement.dataset.npcArmSwingProfile='all-humanoids-walk-firing-priority-v319';renderer.domElement.dataset.firingPolice=String(firingPoliceCount);renderer.domElement.dataset.firingGuards=String(firingGuardCount);renderer.domElement.dataset.policeFireAnimation='two-hand-aim-recoil-all-weapons-v1';renderer.domElement.dataset.guardFireAnimation='bridge-shot-pose-and-recoil-v1';}
          let visibleGuardBadges=0,visibleBusinessOwners=0,visibleNpcIdentityLabels=0,visibleDeadLabels=0,hiddenNpcIdentityLabels=0,focusedNpcIdentity='none';for(let i=0;i<NPC_CAP;i++){const src=dynamic.npcs[i],label=npcLabels[i],badge=guardRoleBadges[i],ownerBadge=ownerRoleBadges[i];if(!src){label.sprite.visible=false;badge.visible=false;ownerBadge.visible=false;continue;}const dead=npcIsDead(src);if(dead){updateDeadNpcLabel(label,src,npcVisualXs[i],npcVisualZs[i]);badge.visible=false;ownerBadge.visible=false;visibleNpcIdentityLabels++;visibleDeadLabels++;continue;}const role=String(src.role||'').toLowerCase(),prisonStaff=String(src.behavior||'')==='prison_patrol'||role.startsWith('prison_'),guard=src.visualRole==='guard'||role.includes('guard'),owner=src.visualRole==='owner',speech=String(src.speech||'').trim(),identityFocused=nearbyNpcRing.visible&&nearbyNpcState?.index===i&&nearbyNpcState.distance<=3.05,priorityLabel=!!src.empireBoss||!!src.uniqueNpc||!!src.said||!!speech,showIdentity=identityFocused||priorityLabel;if(showIdentity){updateCustodyAwareNpcLabel(label,src,npcVisualXs[i],7.3+(prisonStaff?(i%3)*.28:0),npcVisualZs[i]);if(label.sprite.visible)visibleNpcIdentityLabels++;if(identityFocused)focusedNpcIdentity=String(src.id||src.sourceId||i);}else{label.sprite.visible=false;hiddenNpcIdentityLabels++;}badge.visible=guard&&identityFocused&&!!speech;ownerBadge.visible=owner&&identityFocused&&!!speech;if(owner)visibleBusinessOwners++;if(badge.visible){visibleGuardBadges++;badge.position.set(npcVisualXs[i],5.55+Math.max(0,+src.elevation||0)*WORLD_SCALE,npcVisualZs[i]);}if(ownerBadge.visible)ownerBadge.position.set(npcVisualXs[i],5.55+Math.max(0,+src.elevation||0)*WORLD_SCALE,npcVisualZs[i]);}if(telemetryDue){const said3d=dynamic.npcs.find(n=>n.said);renderer.domElement.dataset.said3d=said3d?`visible:${said3d.hired?'hired':'available'}:important:${said3d.important?1:0}`:'out-of-range';renderer.domElement.dataset.visibleGuardBadges=String(visibleGuardBadges);renderer.domElement.dataset.visibleBusinessOwners=String(visibleBusinessOwners);renderer.domElement.dataset.visibleNpcIdentityLabels=String(visibleNpcIdentityLabels);renderer.domElement.dataset.visibleDeadLabels=String(visibleDeadLabels);renderer.domElement.dataset.hiddenNpcIdentityLabels=String(hiddenNpcIdentityLabels);renderer.domElement.dataset.focusedNpcIdentity=focusedNpcIdentity;renderer.domElement.dataset.npcIdentityRevealProfile='nearby-ring-focus-priority-dead-v343';}
          let visibleGangCount=0,gangColorsDirty=false;for(let i=0;i<NPC_CAP;i++){const src=dynamic.npcs[i];if(!src){gangColorSignatures[i]='';hidePart(npcParts.gangAura,i);hidePart(npcParts.gangBand,i);continue;}const role=String(src.role||'').toLowerCase(),gang=!!src.empireBoss||src.visualRole==='gang'||!!src.gang||role.includes('gang')||role.includes('boss')||role.includes('district_')||role.includes('occupier');if(!gang||src.dead){gangColorSignatures[i]='';hidePart(npcParts.gangAura,i);hidePart(npcParts.gangBand,i);continue;}visibleGangCount++;const faction=String(src.faction||src.family||'').toLowerCase();let auraColor=faction.includes('yellow')?0xffd83d:faction.includes('purple')?0xa668ff:faction.includes('moretti')?0xf5ead2:faction.includes('bellini')?0x596274:0xff4f68,bandColor=auraColor;try{if((src.empireBoss||src.empireCrew)&&src.bossColor)auraColor=instanceColor.set(src.bossColor).getHex();if((src.empireBoss||src.empireCrew)&&src.bossAccent)bandColor=instanceColor.set(src.bossAccent).getHex();}catch(_){}const x=npcVisualXs[i],z=npcVisualZs[i],phase=npcVisualPhases[i]||t*.008+i*.73,bob=src.walking?Math.abs(Math.sin(phase))*.13:Math.sin(t*.0018+i*1.7)*.018,colorSig=`${String(src.id??src.uid??i)}:${auraColor}:${bandColor}`;rootMatrix.makeRotationY(npcFacingYaws[i]);rootMatrix.scale(npcScale);rootMatrix.setPosition(x,bob,z);setPart(npcParts.gangBand,i,rootMatrix,0,2.25,.405);rootMatrix.makeRotationY(0);rootMatrix.setPosition(x,.11,z);setPart(npcParts.gangAura,i,rootMatrix,0,0,0,-Math.PI/2,src.empireBoss?instanceScale.set(1.16,1.16,1.16):gangAuraScale);if(gangColorSignatures[i]!==colorSig){gangColorSignatures[i]=colorSig;npcParts.gangBand.setColorAt(i,instanceColor.setHex(bandColor));npcParts.gangAura.setColorAt(i,instanceColor.setHex(auraColor));gangColorsDirty=true;}}npcParts.gangAura.instanceMatrix.needsUpdate=true;npcParts.gangBand.instanceMatrix.needsUpdate=true;if(gangColorsDirty){npcParts.gangAura.instanceColor.needsUpdate=true;npcParts.gangBand.instanceColor.needsUpdate=true;}if(telemetryDue)renderer.domElement.dataset.visibleGangs=String(visibleGangCount);const selectedIndex=performance.now()<selectedNpcUntil?dynamic.npcs.findIndex(n=>!n.dead&&String(n.sourceId||'')===selectedNpcSourceId):-1;if(selectedIndex>=0){selectedNpcRing.visible=true;selectedNpcRing.position.set(npcVisualXs[selectedIndex],.15,npcVisualZs[selectedIndex]);const pulse=1+Math.sin(t*.009)*.09;selectedNpcRing.scale.setScalar(pulse);selectedNpcRing.rotation.y=t*.0017;selectedNpcOuter.material.opacity=.82+Math.sin(t*.011)*.16;if(telemetryDue)renderer.domElement.dataset.selectedGangNpc=selectedNpcSourceId;}else{selectedNpcRing.visible=false;if(selectedNpcSourceId&&performance.now()>=selectedNpcUntil){selectedNpcSourceId='';renderer.domElement.dataset.selectedGangNpc='none';}}
          let visibleEmpireHqs=0;for(let i=0;i<EMPIRE_HQ_CAP;i++){const marker=empireHqMarkers[i],src=dynamic.empireHqs?.[i];marker.root.visible=!!src;if(!src){marker.signature='';continue;}visibleEmpireHqs++;marker.root.position.set((+src.c-originC)*WORLD_SCALE,0,(+src.r-originR)*WORLD_SCALE);const sig=`${src.leaderId}:${src.gangName}:${src.color}:${src.accent}:${src.r}:${src.c}`;if(marker.signature!==sig){marker.signature=sig;const roofY=empireHqRoofYAt(+src.r||0,+src.c||0);marker.pole.position.y=roofY+3.05;marker.flagPivot.position.y=roofY+5.05;marker.label.position.y=roofY+7.25;try{marker.ringMaterial.color.set(src.color||'#872f3b');}catch(_){marker.ringMaterial.color.setHex(0x872f3b);}redrawEmpireHqFlag(marker,src);redrawEmpireHqLabel(marker,src);}const pulse=1+Math.sin(t*.003+i*.67)*.055;marker.ring.scale.setScalar(pulse);marker.flagPivot.rotation.y=Math.atan2(camera.position.x-marker.root.position.x,camera.position.z-marker.root.position.z);marker.flag.scale.x=.96+Math.sin(t*.006+i)*.08;}if(telemetryDue){renderer.domElement.dataset.visibleEmpireHqs=String(visibleEmpireHqs);renderer.domElement.dataset.empireHqProfile='camera-facing-two-tone-family-banner-v362';}
          // Appearance is derived from the authoritative entity id instead of the
          // transient pool index. Citizens keep the same clothes, skin and hair
          // when the server reorders nearby NPCs or when an interior is rebuilt.
          npcAppearanceSignatures.clear();let npcColorBuffersDirty=false;
          for(let i=0;i<Math.min(NPC_CAP,dynamic.npcs.length);i++){
            const src=dynamic.npcs[i],key=String(src.id??src.uid??src.name??`${src.role||'npc'}:${Math.round((+src.r||0)*10)}:${Math.round((+src.c||0)*10)}`);
            let seed=2166136261;for(let k=0;k<key.length;k++){seed^=key.charCodeAt(k);seed=Math.imul(seed,16777619);}seed>>>=0;
            const pick=(arr,salt=0)=>arr[(((seed>>>salt)^Math.imul(seed,31+salt))>>>0)%arr.length],role=String(src.role||'').toLowerCase(),said=!!src.said||role==='said',uniqueNpc=!!src.uniqueNpc||said||role==='unique_npc',empireBoss=!!src.empireBoss,empireCrew=!!src.empireCrew,empireMember=empireBoss||empireCrew,bossStyle=Math.max(0,+src.bossStyle||0)%19,police=src.visualRole==='police'||!!src.police||role.includes('police')||role.includes('cop'),gang=empireMember||!!src.gang||role.includes('gang')||role.includes('boss')||role.includes('district_')||role.includes('occupier'),businessOwner=src.visualRole==='owner',ownerStyle=Math.abs(Number.isFinite(+src.ownerStyle)?+src.ownerStyle:+src.look?.ownerStyle||0)%10,prisonStaff=!!src.prisonStaff||String(src.behavior||'')==='prison_patrol'||role.startsWith('prison_'),securityGuard=!prisonStaff&&(src.visualRole==='guard'||role.includes('guard')),guardMajor=securityGuard&&String(src.guardClass||'')==='major',guardStyle=String(src.guardStyle||'generic'),securityUniform=SECURITY_UNIFORMS[guardMajor?guardStyle:'business']||SECURITY_UNIFORMS.generic,responseTier=Math.max(0,Math.min(3,+src.responseTier||0)),tactical=responseTier>0,prisonGuard=prisonStaff&&role.includes('guard'),staffVariant=Math.abs(+src.staffVariant||0)%3,prisonGear=String(src.prisonGear||''),armed=empireMember||gang||securityGuard||role.includes('guard')||police,look=src.look||{},gender=+look.gender===1,bodyIndex=Math.abs(+look.body||0)%4,faceIndex=Math.abs(+look.face||0)%10,creatorHatId=Math.abs(+look.hat||0)%10,fittedCreatorHat=[1,2,3,4,7,8].includes(creatorHatId);
            let authoredSuit=0,authoredTrousers=0,authoredHair=0,ownerAccent=0,empireColor=0,empireAccent=0;try{if(look.suit||src.outfit)authoredSuit=instanceColor.set(look.suit||src.outfit).getHex();if(look.trousers)authoredTrousers=instanceColor.set(look.trousers).getHex();if(look.hairColor)authoredHair=instanceColor.set(look.hairColor).getHex();if(look.accent)ownerAccent=instanceColor.set(look.accent).getHex();if(src.bossColor)empireColor=instanceColor.set(src.bossColor).getHex();if(src.bossAccent){empireAccent=instanceColor.set(src.bossAccent).getHex();ownerAccent=empireAccent;}}catch(_){authoredSuit=authoredTrousers=authoredHair=ownerAccent=empireColor=empireAccent=0;}
            const tacticalBody=[0x2b6fa8,0x245f96,0x1b4d7a,0x153d65][responseTier],tacticalLeg=[0x183b5c,0x163652,0x122c46,0x0e253c][responseTier],tacticalHat=[0x3277ae,0x28679d,0x205381,0x194267][responseTier];
            const faction=String(src.faction||src.family||'').toLowerCase(),bodyColor=said?0xf4f2e9:prisonStaff?(prisonGuard?[0x35483c,0x3e4937,0x2b4039][staffVariant]:[0x245f9b,0x31527d,0x1f6777][staffVariant]):police?tacticalBody:securityGuard?securityUniform[0]:empireMember?(empireColor||authoredSuit||pick([0x6b2730,0x263448,0x30234f],3)):gang?(faction.includes('yellow')?0xf1e4c4:faction.includes('purple')?0x7447aa:pick([0xb84a5d,0x5f6f85,0xb48a49],3)):authoredSuit||pick(npcShirts,1),legColor=said?0x17191c:prisonStaff?(prisonGuard?[0x1e2922,0x242a20,0x18251f][staffVariant]:[0x172536,0x202c3c,0x16313a][staffVariant]):police?tacticalLeg:securityGuard?securityUniform[1]:empireMember?(empireAccent||authoredTrousers||0x12151a):gang?(faction.includes('yellow')?0x5e523c:faction.includes('purple')?0x342a48:0x3b3740):uniqueNpc?(authoredTrousers||pick(npcTrousers,5)):businessOwner?(authoredTrousers||0x111318):pick(npcTrousers,5),skinColor=Number.isFinite(+look.skin)?npcSkins[Math.abs(+look.skin|0)%npcSkins.length]:pick(npcSkins,7),hairColor=uniqueNpc?(authoredHair||pick(npcHairs,9)):businessOwner?(authoredHair||pick(npcHairs,9)):pick(npcHairs,9),shoeColor=uniqueNpc||police||prisonStaff||securityGuard||businessOwner?0x090b0e:pick(npcShoes,11),hatColor=police?tacticalHat:securityGuard?securityUniform[1]:empireMember?(ownerAccent||bodyColor):gang?bodyColor:uniqueNpc?(ownerAccent||pick(npcHats,13)):pick(npcHats,13),hairStyle=businessOwner?ownerStyle:Number.isFinite(+look.hair)?Math.abs(+look.hair|0)%10:(seed>>>16)%10,accessory=(seed>>>20)%12,capOn=businessOwner?false:uniqueNpc?fittedCreatorHat:prisonStaff?prisonGear==='cap':tactical?false:police||armed||fittedCreatorHat,helmetOn=!uniqueNpc&&(prisonStaff||tactical)&&prisonGear.includes('helmet'),wearHat=capOn||helmetOn,glassesOn=uniqueNpc&&creatorHatId===5||empireBoss&&(bossStyle%5===0||bossStyle%7===3)||!uniqueNpc&&!said&&!armed&&!businessOwner&&(accessory===0||accessory===4||role.includes('staff')),eyePatchOn=uniqueNpc&&creatorHatId===6,chainOn=uniqueNpc&&creatorHatId===9,neckOn=!chainOn&&(businessOwner||uniqueNpc||armed||accessory%3===1),bagOn=!said&&!armed&&!businessOwner&&accessory%4===2,moustacheOn=empireBoss?(!gender&&bossStyle%3===1):(!said&&!armed&&!gender&&(faceIndex===3||(businessOwner?(ownerStyle===2||ownerStyle===5):(accessory===3||accessory===9)))),variantSig=`${gender?1:0}:${bodyIndex}:${faceIndex}:${bodyColor}:${legColor}:${skinColor}:${hairColor}:${shoeColor}:${hatColor}:${hairStyle}:${creatorHatId}:${prisonGear||'city'}:${responseTier}:${securityGuard?guardStyle:'none'}:${businessOwner?ownerStyle:'none'}:${empireMember?bossStyle:'none'}:${glassesOn?1:0}:${eyePatchOn?1:0}:${chainOn?1:0}:${neckOn?1:0}:${bagOn?1:0}:${moustacheOn?1:0}`,slotSig=`${key}:${variantSig}`;
            if(npcAppearanceSlotSignatures[i]!==slotSig){npcAppearanceSlotSignatures[i]=slotSig;npcColorBuffersDirty=true;
              for(const mesh of [npcParts.body,npcParts.leftArm,npcParts.rightArm,npcParts.roleHem])mesh.setColorAt(i,instanceColor.setHex(bodyColor));npcParts.forearm.setColorAt(i*2,instanceColor.setHex(bodyColor));npcParts.forearm.setColorAt(i*2+1,instanceColor.setHex(bodyColor));
              for(const mesh of [npcParts.femaleHips,npcParts.leftLeg,npcParts.rightLeg])mesh.setColorAt(i,instanceColor.setHex(legColor));
              for(const mesh of [npcParts.head,npcParts.jaw,npcParts.nose])mesh.setColorAt(i,instanceColor.setHex(skinColor));npcParts.hand.setColorAt(i*2,instanceColor.setHex(skinColor));npcParts.hand.setColorAt(i*2+1,instanceColor.setHex(skinColor));npcParts.ear.setColorAt(i*2,instanceColor.setHex(skinColor));npcParts.ear.setColorAt(i*2+1,instanceColor.setHex(skinColor));
              npcParts.shirtFront.setColorAt(i,instanceColor.setHex(gender?0xf0d9d8:0xe8e5dc));npcParts.collar.setColorAt(i,instanceColor.setHex(empireBoss||businessOwner?(ownerAccent||0xe7dfcf):gender?0xf8e8e6:0xf4f0e5));npcParts.mouth.setColorAt(i,instanceColor.setHex(faceIndex===3||gender?0x8d2d39:0x171318));npcParts.femaleLashes.setColorAt(i,instanceColor.setHex(0x151116));npcParts.femaleLips.setColorAt(i,instanceColor.setHex(0xa92f44));
              for(const mesh of [npcParts.hair,npcParts.hairBun,npcParts.hairMohawk,npcParts.ownerHairSide,npcParts.ownerHairBack,npcParts.ownerHairQuiff,npcParts.beard])mesh.setColorAt(i,instanceColor.setHex(hairColor));npcParts.brow.setColorAt(i*2,instanceColor.setHex(hairColor));npcParts.brow.setColorAt(i*2+1,instanceColor.setHex(hairColor));for(let curl=0;curl<4;curl++)npcParts.hairCurls.setColorAt(i*4+curl,instanceColor.setHex(hairColor));npcParts.hat.setColorAt(i,instanceColor.setHex(hatColor));npcParts.hatBrim.setColorAt(i,instanceColor.setHex(hatColor));npcParts.shoe.setColorAt(i*2,instanceColor.setHex(shoeColor));npcParts.shoe.setColorAt(i*2+1,instanceColor.setHex(shoeColor));npcParts.glasses.setColorAt(i,instanceColor.setHex(empireBoss?(ownerAccent||0xf2cf68):(accessory%2?0x26343e:0x4b3028)));npcParts.eyePatch.setColorAt(i,instanceColor.setHex(0x111318));npcParts.chain.setColorAt(i,instanceColor.setHex(ownerAccent||0xd6b45e));npcParts.neckAccent.setColorAt(i,instanceColor.setHex(uniqueNpc?(ownerAccent||0xd6b45e):businessOwner?(ownerAccent||0xd6b45e):pick(npcAccents,15)));npcParts.ownerLapel.setColorAt(i*2,instanceColor.setHex(empireBoss?(ownerAccent||0xe7c35c):businessOwner?0xe7dfcf:bodyColor));npcParts.ownerLapel.setColorAt(i*2+1,instanceColor.setHex(empireBoss?(ownerAccent||0xe7c35c):businessOwner?0xe7dfcf:bodyColor));npcParts.ownerPocket.setColorAt(i,instanceColor.setHex(ownerAccent||0xd6b45e));npcParts.bag.setColorAt(i,instanceColor.setHex(pick(npcBags,17)));npcParts.moustache.setColorAt(i,instanceColor.setHex(hairColor));
              npcParts.prisonHelmet.setColorAt(i,instanceColor.setHex(tactical?tacticalHat:prisonGuard?[0x334437,0x3d4936,0x2d4037][staffVariant]:[0x244b70,0x2d4058,0x24505c][staffVariant]));npcParts.prisonHelmetBand.setColorAt(i,instanceColor.setHex(responseTier>=3?0x8f202a:prisonGuard?0x161d19:0x152332));npcParts.prisonVest.setColorAt(i,instanceColor.setHex(securityGuard?securityUniform[0]:tactical?tacticalLeg:prisonGuard?0x29372f:0x1b2c42));npcParts.securityBadge.setColorAt(i,instanceColor.setHex(securityGuard?securityUniform[2]:0xcaa452));npcParts.riotShield.setColorAt(i,instanceColor.setHex(responseTier>=3?0x12161b:[0x26323a,0x30383a,0x202e31][staffVariant]));
              npcParts.policeBelt.setColorAt(i,instanceColor.setHex(0x101820));npcParts.policeRadio.setColorAt(i,instanceColor.setHex(0x162431));npcParts.policePatch.setColorAt(i*2,instanceColor.setHex(0x6ab5df));npcParts.policePatch.setColorAt(i*2+1,instanceColor.setHex(0x6ab5df));
            }
            const x=npcVisualXs[i],z=npcVisualZs[i],pose=npcFramePoses[i]||npcAnimationPose(src,i,t);
            setNpcRoot(pose,i,x,z);
            hidePart(npcParts.hair,i);hidePart(npcParts.hairBun,i);hidePart(npcParts.hairMohawk,i);for(let curl=0;curl<4;curl++)hidePart(npcParts.hairCurls,i*4+curl);hidePart(npcParts.ownerHairSide,i);hidePart(npcParts.ownerHairBack,i);hidePart(npcParts.ownerHairQuiff,i);hidePart(npcParts.ownerLapel,i*2);hidePart(npcParts.ownerLapel,i*2+1);hidePart(npcParts.ownerPocket,i);hidePart(npcParts.hat,i);hidePart(npcParts.hatBrim,i);hidePart(npcParts.glasses,i);hidePart(npcParts.eyePatch,i);hidePart(npcParts.chain,i);hidePart(npcParts.neckAccent,i);hidePart(npcParts.bag,i);hidePart(npcParts.moustache,i);hidePart(npcParts.prisonHelmet,i);hidePart(npcParts.prisonHelmetBand,i);hidePart(npcParts.prisonVisor,i);hidePart(npcParts.prisonVest,i);hidePart(npcParts.securityBadge,i);hidePart(npcParts.policeBelt,i);hidePart(npcParts.policeRadio,i);hidePart(npcParts.policePatch,i*2);hidePart(npcParts.policePatch,i*2+1);hidePart(npcParts.riotShield,i);hidePart(npcParts.shieldViewport,i);
            if(!businessOwner&&!wearHat&&![0,3,6].includes(hairStyle))setPart(npcParts.hair,i,rootMatrix,0,3.34-pose.crouch,0,0,unitScale,pose.headCounter,pose.headTilt);
            if(!businessOwner&&!wearHat&&hairStyle===2)setPart(npcParts.hairBun,i,rootMatrix,0,3.58-pose.crouch,-.34,0,unitScale,pose.headCounter,pose.headTilt);
            if(!businessOwner&&!wearHat&&hairStyle===3)setPart(npcParts.hairMohawk,i,rootMatrix,0,3.72-pose.crouch,-.02,0,unitScale,pose.headCounter,pose.headTilt);
            if(!businessOwner&&!wearHat&&hairStyle===5)setPart(npcParts.ownerHairBack,i,rootMatrix,0,3.08-pose.crouch,-.37,0,instanceScale.set(1.08,1.85,1.22),pose.headCounter,pose.headTilt);
            if(!businessOwner&&!wearHat&&(hairStyle===2||hairStyle===7))setPart(npcParts.ownerHairQuiff,i,rootMatrix,hairStyle===7?-.12:.12,3.62-pose.crouch,.1,0,hairStyle===7?instanceScale.set(1.35,.72,1.15):unitScale,pose.headCounter,pose.headTilt);
            if(!businessOwner&&!wearHat&&hairStyle===8)setPart(npcParts.ownerHairSide,i,rootMatrix,-.16,3.48-pose.crouch,.31,0,instanceScale.set(1.8,1.05,.45),pose.headCounter,-.24);
            if(!businessOwner&&!wearHat&&hairStyle===6)for(const [curl,[cx,cy,cz]] of [[0,[-.29,3.48,0]],[1,[.29,3.48,0]],[2,[-.2,3.62,-.25]],[3,[.2,3.62,-.25]]])setPart(npcParts.hairCurls,i*4+curl,rootMatrix,cx,cy-pose.crouch,cz,0,unitScale,pose.headCounter,pose.headTilt);
            if(businessOwner){
              if(ownerStyle!==5&&ownerStyle!==4&&ownerStyle!==8)setPart(npcParts.hair,i,rootMatrix,0,3.34-pose.crouch,0,0,unitScale,pose.headCounter,pose.headTilt);
              if(ownerStyle===1||ownerStyle===9)setPart(npcParts.ownerHairSide,i,rootMatrix,.32,3.44-pose.crouch,-.03,0,unitScale,pose.headCounter,pose.headTilt+.16);
              if(ownerStyle===2)setPart(npcParts.ownerHairBack,i,rootMatrix,0,3.43-pose.crouch,-.39,0,unitScale,pose.headCounter,pose.headTilt);
              if(ownerStyle===3||ownerStyle===7||ownerStyle===9)setPart(npcParts.ownerHairQuiff,i,rootMatrix,ownerStyle===7?-.2:.2,3.62-pose.crouch,.12,0,ownerStyle===7?instanceScale.set(1.35,.72,1.15):unitScale,pose.headCounter,pose.headTilt);
              if(ownerStyle===4||ownerStyle===8)setPart(npcParts.hairMohawk,i,rootMatrix,0,3.61-pose.crouch,-.03,0,ownerStyle===8?instanceScale.set(2.55,.48,1.16):instanceScale.set(1.55,.72,1.05),pose.headCounter,pose.headTilt);
              if(ownerStyle===6)setPart(npcParts.hairBun,i,rootMatrix,0,3.57-pose.crouch,-.36,0,unitScale,pose.headCounter,pose.headTilt);
              setPart(npcParts.ownerLapel,i*2,rootMatrix,-.23,2.27-pose.crouch,.405,0,unitScale,0,-.28);setPart(npcParts.ownerLapel,i*2+1,rootMatrix,.23,2.27-pose.crouch,.405,0,unitScale,0,.28);setPart(npcParts.ownerPocket,i,rootMatrix,.34,2.18-pose.crouch,.43);setPart(npcParts.neckAccent,i,rootMatrix,0,2.42-pose.crouch,.43);
            }
            if(empireBoss){setPart(npcParts.ownerLapel,i*2,rootMatrix,-.27,2.3-pose.crouch,.415,0,instanceScale.set(1.12,1.12,1.08),0,-.32);setPart(npcParts.ownerLapel,i*2+1,rootMatrix,.27,2.3-pose.crouch,.415,0,instanceScale.set(1.12,1.12,1.08),0,.32);setPart(npcParts.ownerPocket,i,rootMatrix,.35,2.16-pose.crouch,.44,0,instanceScale.set(1+(bossStyle%3)*.12,1,1));}
            if(capOn){setPart(npcParts.hat,i,rootMatrix,0,(police?3.69:3.77)-pose.crouch,0,0,police?instanceScale.set(1.08,.72,1.08):unitScale,pose.headCounter,pose.headTilt);if(police||armed||hairStyle===4||+look.hat>1)setPart(npcParts.hatBrim,i,rootMatrix,0,3.63-pose.crouch,.04,0,police?instanceScale.set(1.18,.68,1.32):unitScale,pose.headCounter,pose.headTilt);}
            if(helmetOn){setPart(npcParts.prisonHelmet,i,rootMatrix,0,3.53-pose.crouch,0,0,unitScale,pose.headCounter,pose.headTilt);setPart(npcParts.prisonHelmetBand,i,rootMatrix,0,3.59-pose.crouch,0,0,unitScale,pose.headCounter,pose.headTilt);setPart(npcParts.prisonVisor,i,rootMatrix,0,3.38-pose.crouch,.47,0,unitScale,pose.headCounter,pose.headTilt);}
            if(prisonStaff||police||securityGuard)setPart(npcParts.prisonVest,i,rootMatrix,0,2.02-pose.crouch,.02);
            if(securityGuard||police)setPart(npcParts.securityBadge,i,rootMatrix,.35,2.35-pose.crouch,.455);
            if(police){setPart(npcParts.policeBelt,i,rootMatrix,0,1.43-pose.crouch,.01);setPart(npcParts.policeRadio,i,rootMatrix,-.43,2.48-pose.crouch,.47);setPart(npcParts.policePatch,i*2,rootMatrix,-.68,2.55-pose.crouch,.02,0,unitScale,0,-Math.PI/2);setPart(npcParts.policePatch,i*2+1,rootMatrix,.68,2.55-pose.crouch,.02,0,unitScale,0,Math.PI/2);}
            if((prisonStaff||tactical)&&src.shield){setPart(npcParts.riotShield,i,rootMatrix,-.92,1.7-pose.crouch*.35,.62,0,unitScale,.12,-.08);setPart(npcParts.shieldViewport,i,rootMatrix,-.92,2.05-pose.crouch*.35,.72,0,unitScale,.12,-.08);}
            if(glassesOn)setPart(npcParts.glasses,i,rootMatrix,0,3.38-pose.crouch,.43,0,unitScale,pose.headCounter,pose.headTilt);
            if(eyePatchOn)setPart(npcParts.eyePatch,i,rootMatrix,.17,3.38-pose.crouch,.44,0,instanceScale.set(1,.72,.3),pose.headCounter,pose.headTilt);
            if(chainOn)setPart(npcParts.chain,i,rootMatrix,0,2.56-pose.crouch,.54*NPC_BODY_PROFILES[bodyIndex].bodyZ,0,instanceScale.set(Math.min(1.22,NPC_BODY_PROFILES[bodyIndex].shoulder),1,1),0,Math.PI);
            if(neckOn&&!businessOwner)setPart(npcParts.neckAccent,i,rootMatrix,0,2.42-pose.crouch,.42);
            if(bagOn)setPart(npcParts.bag,i,rootMatrix,.62,1.78-pose.crouch,-.28,.06);
            if(moustacheOn)setPart(npcParts.moustache,i,rootMatrix,0,3.17-pose.crouch,.435,0,unitScale,pose.headCounter,pose.headTilt);
            npcAppearanceSignatures.add(variantSig);
          }
          for(let i=Math.min(NPC_CAP,dynamic.npcs.length);i<NPC_CAP;i++){npcAppearanceSlotSignatures[i]='';npcEmpireWeaponColorSignatures[i]='';corpseBloodMatrixSignatures[i]='';}if(npcColorBuffersDirty)for(const mesh of Object.values(npcParts))if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
          if(telemetryDue){renderer.domElement.dataset.npcAppearanceVariants=String(npcAppearanceSignatures.size);renderer.domElement.dataset.npcAppearanceSystem='creator-grade-shared-instanced-rig-v356';renderer.domElement.dataset.npcDetailProfile='profiled-torso-jaw-beard-tailoring-blink-gaze-articulated-forearms-role-hems';renderer.domElement.dataset.npcJointProfile='shared-upper-arm-forearm-elbow-bend-v356';renderer.domElement.dataset.npcMicroExpressions='deterministic-blink-and-eye-saccade-no-allocation';renderer.domElement.dataset.jailStaffGear='guards:military-helmet-riot-shield;police:cap-tactical-helmet-bare';renderer.domElement.dataset.policeResponseTiers=String(dynamic.npcs.reduce((m,n)=>Math.max(m,+n.responseTier||0),0));renderer.domElement.dataset.jailStaffMaxHp='200';}
          // Единая смерть для всех 3D-NPC: мост сохраняет момент смерти,
          // поэтому падение не перезапускается при каждом новом snapshot.
          for(let i=0;i<Math.min(NPC_CAP,dynamic.npcs.length);i++){
            const src=dynamic.npcs[i];if(!npcIsDead(src))continue;
            const motion=npcMotionStates.get(String(src.id??src.uid??i)),age=Math.max(0,t-(motion?.deadStartedAt||t));
            const raw=Math.min(1,age/560),fall=raw*raw*(3-2*raw);
            const impact=age>480&&age<760?Math.sin((age-480)/280*Math.PI)*.13:0;
            const x=npcVisualXs[i],z=npcVisualZs[i];
            const deathForward=Number.isFinite(+motion?.deathForward)?+motion.deathForward:1,sideDominant=Math.abs(deathForward)<.5,deathSide=motion?.deathSide||1,fallPitch=-Math.PI*.5*fall*(sideDominant?.2:(deathForward>=0?1:-1)),fallRoll=(sideDominant?deathSide*Math.PI*.5:deathSide*.08)*fall;
            instanceQuat.setFromEuler(new THREE.Euler(fallPitch,npcFacingYaws[i],fallRoll,'XYZ'));
            rootMatrix.compose(new THREE.Vector3(x,.46+impact,z),instanceQuat,npcScale);
            setPart(npcParts.body,i,rootMatrix,0,2.05,0,0,npcBodyScale.set(1,1-.08*fall,1));
            setPart(npcParts.head,i,rootMatrix,0,3.3,0,.08*fall);
            setPart(npcParts.leftLeg,i,rootMatrix,-.34,.64,0,-.18*fall);
            setPart(npcParts.rightLeg,i,rootMatrix,.34,.64,0,.12*fall);
            setPart(npcParts.shoe,i*2,rootMatrix,-.34,.09,.18,-.18*fall);
            setPart(npcParts.shoe,i*2+1,rootMatrix,.34,.09,.18,.12*fall);
            setPart(npcParts.leftArm,i,rootMatrix,-.78,2.05,0,.34*fall);
            setPart(npcParts.rightArm,i,rootMatrix,.78,2.05,0,-.24*fall);
            const severMask=+src.severMask||0;
            if(severMask&1)hidePart(npcParts.leftArm,i);
            if(severMask&2)hidePart(npcParts.rightArm,i);
            if(severMask&4){hidePart(npcParts.leftLeg,i);hidePart(npcParts.shoe,i*2);}
            if(severMask&8){hidePart(npcParts.rightLeg,i);hidePart(npcParts.shoe,i*2+1);}
            for(const [eyeIndex,sx] of [[i*2,-.17],[i*2+1,.17]]){setPart(npcParts.eyeWhite,eyeIndex,rootMatrix,sx,3.37,.405,0,eyeScale);setPart(npcParts.pupil,eyeIndex,rootMatrix,sx,3.37,.455,0,pupilScale);}
            const key=String(src.id??i);let seed=2166136261;for(let k=0;k<key.length;k++){seed^=key.charCodeAt(k);seed=Math.imul(seed,16777619);}seed>>>=0;
            const role=String(src.role||'').toLowerCase(),police=src.visualRole==='police'||!!src.police||role.includes('police')||role.includes('cop'),armed=role.includes('gang')||role.includes('boss')||role.includes('guard')||police,prisonStaff=!!src.prisonStaff||String(src.behavior||'')==='prison_patrol'||role.startsWith('prison_'),responseTier=Math.max(0,+src.responseTier||0),tactical=responseTier>0,prisonGear=String(src.prisonGear||''),capOn=prisonStaff?prisonGear==='cap':tactical?false:armed,helmetOn=(prisonStaff||tactical)&&prisonGear.includes('helmet'),hairStyle=Number.isFinite(+src.look?.hair)?Math.abs(+src.look.hair|0)%6:(seed>>>16)%6;
            for(const part of ['shirtFront','collar','roleHem','jaw','beard','nose','mouth','femaleLashes','femaleLips','femaleHips'])hidePart(npcParts[part],i);for(const part of ['forearm','hand','brow','ear']){hidePart(npcParts[part],i*2);hidePart(npcParts[part],i*2+1);}hidePart(npcParts.hair,i);hidePart(npcParts.hairBun,i);hidePart(npcParts.hairMohawk,i);for(let curl=0;curl<4;curl++)hidePart(npcParts.hairCurls,i*4+curl);hidePart(npcParts.ownerHairSide,i);hidePart(npcParts.ownerHairBack,i);hidePart(npcParts.ownerHairQuiff,i);hidePart(npcParts.ownerLapel,i*2);hidePart(npcParts.ownerLapel,i*2+1);hidePart(npcParts.ownerPocket,i);hidePart(npcParts.hat,i);hidePart(npcParts.hatBrim,i);hidePart(npcParts.glasses,i);hidePart(npcParts.eyePatch,i);hidePart(npcParts.chain,i);hidePart(npcParts.neckAccent,i);hidePart(npcParts.bag,i);hidePart(npcParts.moustache,i);hidePart(npcParts.prisonHelmet,i);hidePart(npcParts.prisonHelmetBand,i);hidePart(npcParts.prisonVisor,i);hidePart(npcParts.prisonVest,i);hidePart(npcParts.securityBadge,i);hidePart(npcParts.policeBelt,i);hidePart(npcParts.policeRadio,i);hidePart(npcParts.policePatch,i*2);hidePart(npcParts.policePatch,i*2+1);hidePart(npcParts.riotShield,i);hidePart(npcParts.shieldViewport,i);
            if(!capOn&&!helmetOn&&hairStyle!==0)setPart(npcParts.hair,i,rootMatrix,0,3.34,0);
            if(!capOn&&!helmetOn&&hairStyle===2)setPart(npcParts.hairBun,i,rootMatrix,0,3.58,-.34);
            if(!capOn&&!helmetOn&&hairStyle===3){hidePart(npcParts.hair,i);setPart(npcParts.hairMohawk,i,rootMatrix,0,3.72,-.02);}
            if(capOn||(!prisonStaff&&(hairStyle===4||hairStyle===5))){setPart(npcParts.hat,i,rootMatrix,0,police?3.69:3.77,0,0,police?instanceScale.set(1.08,.72,1.08):unitScale);if(armed||hairStyle===4)setPart(npcParts.hatBrim,i,rootMatrix,0,3.63,police?.04:0,0,police?instanceScale.set(1.18,.68,1.32):unitScale);}
            if(helmetOn){setPart(npcParts.prisonHelmet,i,rootMatrix,0,3.53,0);setPart(npcParts.prisonHelmetBand,i,rootMatrix,0,3.59,0);setPart(npcParts.prisonVisor,i,rootMatrix,0,3.38,.47);}
            if(prisonStaff||tactical)setPart(npcParts.prisonVest,i,rootMatrix,0,2.02,.02);
            if((prisonStaff||tactical)&&src.shield){setPart(npcParts.riotShield,i,rootMatrix,-.92,1.7,.62,0,unitScale,.12,-.08);setPart(npcParts.shieldViewport,i,rootMatrix,-.92,2.05,.72,0,unitScale,.12,-.08);}
            armed&&!(severMask&2)?setPart(npcParts.gun,i,rootMatrix,.72,2,.52,.24*fall):hidePart(npcParts.gun,i);
          }
          let corpseBloodPoolCount=0,corpseBloodMatricesDirty=false;
          for(let i=0;i<activeNpcInstances;i++){
            const src=dynamic.npcs[i];if(!npcIsDead(src)){if(corpseBloodMatrixSignatures[i]!=='hidden'){corpseBloodMatrixSignatures[i]='hidden';hidePart(corpseBloodDecals,i);corpseBloodMatricesDirty=true;}continue;}
            const motion=npcMotionStates.get(String(src.id??src.uid??i)),age=Math.max(0,t-(motion?.deadStartedAt||t)),spread=Math.min(1,age/2400),seed=(i+1)*2.173;
            const x=Number.isFinite(motion?.deathX)?motion.deathX:npcVisualXs[i],z=Number.isFinite(motion?.deathZ)?motion.deathZ:npcVisualZs[i];
            const settled=spread>=1,matrixSig=settled?`${String(src.id??src.uid??i)}:${x}:${z}`:'';
            if(!settled||corpseBloodMatrixSignatures[i]!==matrixSig){corpseBloodMatrixSignatures[i]=matrixSig;instanceQuat.setFromEuler(instanceEuler.set(-Math.PI/2,0,seed));instanceMatrix.compose(instancePosition.set(x,.052,z),instanceQuat,instanceScale.set(.38+spread*1.12,.3+spread*.72,1));corpseBloodDecals.setMatrixAt(i,instanceMatrix);corpseBloodMatricesDirty=true;}corpseBloodPoolCount++;
          }
          if(corpseBloodMatricesDirty)corpseBloodDecals.instanceMatrix.needsUpdate=true;if(telemetryDue){renderer.domElement.dataset.corpseBloodPools=String(corpseBloodPoolCount);renderer.domElement.dataset.corpseBloodMatrixUpload=corpseBloodMatricesDirty?'dirty':'cached';renderer.domElement.dataset.corpseMotion='frozen-at-death-v205';}
          let remoteColorsDirty=false;for(let i=0;i<activeRemoteInstances;i++){const src=dynamic.players[i],x=(src.c-originC)*WORLD_SCALE,z=(src.r-originR)*WORLD_SCALE;rootMatrix.makeRotationY(Math.PI/2-(+src.ang||0));rootMatrix.setPosition(x,0,z);setPart(remoteParts.body,i,rootMatrix,0,2.05,0);setPart(remoteParts.head,i,rootMatrix,0,3.48,0);setPart(remoteParts.hat,i,rootMatrix,0,4,0);updatePlayerSpeech(remotePlayerSpeech[i],src.chat,x,8.15,z);const remoteRole=String(src.role||'civilian'),remoteFamily=String(src.mafiaFamily||'').toLowerCase(),remoteColor=remoteRole==='police'?0x419ee8:remoteRole==='mafia'?(remoteFamily.includes('moretti')?0xf0e8d8:0x4f5c70):(i%2?0x71839e:0xae825d),remoteColorSig=`${String(src.id||i)}:${remoteColor}`;if(remoteColorSignatures[i]!==remoteColorSig){remoteColorSignatures[i]=remoteColorSig;instanceColor.set(remoteColor);remoteParts.body.setColorAt(i,instanceColor);remoteParts.hat.setColorAt(i,instanceColor);remoteColorsDirty=true;}}for(let i=activeRemoteInstances;i<REMOTE_CAP;i++){remoteColorSignatures[i]='';updatePlayerSpeech(remotePlayerSpeech[i],'',0,0,0);}remotePartMeshes.forEach(mesh=>{if(activeRemoteInstances)mesh.instanceMatrix.needsUpdate=true;if(remoteColorsDirty&&mesh.instanceColor)mesh.instanceColor.needsUpdate=true;});
          let projectileColorsDirty=false,projectileMatricesDirty=false;
          for(let i=0;i<activeProjectileInstances;i++){
            const src=dynamic.projectiles[i],weapon=String(src.weapon||'pistol'),projectileKind=String(src.projectileKind||''),arrowKind=projectileKind==='arrow'||projectileKind==='harpoon'||projectileKind==='dart',rocket=weapon==='rpg',water=weapon==='water_hose',pellet=weapon==='shotgun',scale=(arrowKind?.001:rocket?2.7:src.thick?1.5:pellet?.65:1)*(+src.bulletScale||1),velocity=Math.hypot(+src.vr||0,+src.vc||0),speedStretch=THREE.MathUtils.clamp(velocity/20,.72,1.6),trail=(arrowKind?.001:rocket?2.4:water?.55:weapon==='sniper'?3.2:pellet?.6:1.35)*(+src.trailScale||1)*speedStretch,dr=+src.vr||Math.sin(+src.ang||0),dc=+src.vc||Math.cos(+src.ang||0),progress=Math.max(0,Math.min(1,(+src.dist||0)/Math.max(.01,+src.maxDist||1))),elevation=THREE.MathUtils.lerp(+src.startZ||0,+src.endZ||0,progress)*WORLD_SCALE,y=(rocket?2.8:2.2)+elevation,glowScale=scale*(rocket?2.2:1),coreScale=scale*(rocket?1.15:water?.52:.68),matrixSig=`${String(src.id??i)}:${src.c}:${src.r}:${y}:${dc}:${dr}:${scale}:${trail}:${glowScale}:${coreScale}:${projectileKind}`;
            if(projectileMatrixSignatures[i]!==matrixSig){
              projectileMatrixSignatures[i]=matrixSig;instancePosition.set((src.c-originC)*WORLD_SCALE,y,(src.r-originR)*WORLD_SCALE);bulletDirection.set(dc,0,dr).normalize();instanceQuat.setFromUnitVectors(bulletUp,bulletDirection);instanceMatrix.compose(instancePosition,instanceQuat,instanceScale.set(scale,scale*(rocket?1.18:1),scale));worldBullets.setMatrixAt(i,instanceMatrix);trailPosition.copy(instancePosition).addScaledVector(bulletDirection,-.55*trail);instanceMatrix.compose(trailPosition,instanceQuat,instanceScale.set(scale,trail,scale));worldBulletTrails.setMatrixAt(i,instanceMatrix);instanceMatrix.compose(instancePosition,instanceQuat,instanceScale.set(glowScale,glowScale,glowScale));worldBulletGlows.setMatrixAt(i,instanceMatrix);instanceMatrix.compose(instancePosition,instanceQuat,instanceScale.set(coreScale,coreScale*(rocket?1.35:1),coreScale));worldBulletCores.setMatrixAt(i,instanceMatrix);
              if(arrowKind){instanceMatrix.compose(instancePosition,instanceQuat,instanceScale.set(projectileKind==='harpoon'?1.55:1,projectileKind==='harpoon'?1.45:1,projectileKind==='harpoon'?1.55:1));worldArrowShafts.setMatrixAt(i,instanceMatrix);trailPosition.copy(instancePosition).addScaledVector(bulletDirection,.93);instanceMatrix.compose(trailPosition,instanceQuat,instanceScale.set(projectileKind==='harpoon'?1.5:1,projectileKind==='harpoon'?1.35:1,projectileKind==='harpoon'?1.5:1));worldArrowHeads.setMatrixAt(i,instanceMatrix);trailPosition.copy(instancePosition).addScaledVector(bulletDirection,-.74);instanceMatrix.compose(trailPosition,instanceQuat,instanceScale.set(projectileKind==='dart'?.55:1,projectileKind==='dart'?.65:1,projectileKind==='dart'?.55:1));worldArrowFletching.setMatrixAt(i,instanceMatrix);}else{for(const mesh of [worldArrowShafts,worldArrowHeads,worldArrowFletching]){instanceMatrix.compose(instancePosition.set(0,-1000,0),instanceQuat.identity(),hiddenScale);mesh.setMatrixAt(i,instanceMatrix);}}projectileMatricesDirty=true;
            }
            let bulletColor=0xffdc79;try{bulletColor=instanceColor.set(src.color).getHex();}catch(_){}const colorSig=`${bulletColor}:${rocket?1:0}:${water?1:0}:${projectileKind}`;if(projectileColorSignatures[i]!==colorSig){projectileColorSignatures[i]=colorSig;worldBullets.setColorAt(i,instanceColor.setHex(bulletColor));worldBulletTrails.setColorAt(i,instanceColor.setHex(bulletColor));worldBulletGlows.setColorAt(i,instanceColor.setHex(rocket?0xff6a20:bulletColor));worldBulletCores.setColorAt(i,instanceColor.setHex(water?0xd9f8ff:rocket?0xffe07a:0xfff5d0));worldArrowShafts.setColorAt(i,instanceColor.setHex(projectileKind==='dart'?0xf4f6f8:projectileKind==='harpoon'?0x6d4b2f:0x8a5a32));worldArrowHeads.setColorAt(i,instanceColor.setHex(projectileKind==='dart'?0xd73b58:0xd9e2e6));worldArrowFletching.setColorAt(i,instanceColor.setHex(projectileKind==='arrow'?0x3d6eaa:projectileKind==='dart'?0xd73b58:0xffe06d));projectileColorsDirty=true;}
          }
          for(const mesh of [worldBullets,worldBulletTrails,worldBulletGlows,worldBulletCores,worldArrowShafts,worldArrowHeads,worldArrowFletching]){if(projectileMatricesDirty)mesh.instanceMatrix.needsUpdate=true;if(projectileColorsDirty&&mesh.instanceColor)mesh.instanceColor.needsUpdate=true;}if(telemetryDue){renderer.domElement.dataset.projectileMatrixUpload=projectileMatricesDirty?'dirty':'cached';renderer.domElement.dataset.projectileMatrixProfile='bridge-snapshot-signature-all-firearms-and-arrows-v351';}
          if(telemetryDue)renderer.domElement.dataset.trackedVehicleProjectiles=String(dynamic.projectiles.filter(x=>x?.tracked).length);
          let shellMatricesDirty=false;for(let i=0;i<activeShellInstances;i++){const src=dynamic.shellFx[i],rot=+src.rot||0,matrixSig=`${src.id??i}:${src.r}:${src.c}:${src.z||0}:${rot}`;if(shellMatrixSignatures[i]===matrixSig)continue;shellMatrixSignatures[i]=matrixSig;instanceQuat.setFromEuler(instanceEuler.set(rot,rot*.7,rot*1.3));instanceMatrix.compose(instancePosition.set((src.c-originC)*WORLD_SCALE,.18+(+src.z||0)*WORLD_SCALE,(src.r-originR)*WORLD_SCALE),instanceQuat,unitScale);shellPool.setMatrixAt(i,instanceMatrix);shellMatricesDirty=true;}if(shellMatricesDirty)shellPool.instanceMatrix.needsUpdate=true;if(telemetryDue){renderer.domElement.dataset.shellMatrixUpload=shellMatricesDirty?'dirty':'cached';renderer.domElement.dataset.shellMatrixProfile='bridge-snapshot-signature-v346';}
          muzzlePool.forEach((flash,i)=>{const src=dynamic.muzzleFx[i];flash.visible=!!src;if(!src)return;const pct=Math.max(0,Math.min(1,src.life/src.max)),heavy=src.heavy||src.weapon==='shotgun'||src.weapon==='sniper'||src.weapon==='rpg',a=+src.angle||0;flash.position.set((src.c-originC)*WORLD_SCALE,2.45+(+src.z||0)*WORLD_SCALE,(src.r-originR)*WORLD_SCALE);flash.rotation.y=Math.PI/2-a;flash.scale.setScalar((heavy?1.3:.72)*(0.45+pct*1.55));for(const child of flash.children){if(child.material?.opacity!==undefined)child.material.opacity=child===flash.userData.smoke?Math.max(0,(1-pct)*.35):pct;try{if(child!==flash.userData.smoke)child.material.color.set(src.color);}catch(_){}}flash.userData.smoke.position.y=.25+(1-pct)*.55;});
          impactPool.forEach((impact,i)=>{
            const src=dynamic.impactFx[i];impact.visible=!!src;if(!src)return;
            const pct=Math.max(0,Math.min(1,src.life/src.max)),elapsed=1-pct,blood=!!src.blood,metal=!!src.metal,vehicle=!!src.vehicle;
            impact.position.set((src.c-originC)*WORLD_SCALE,.06,(src.r-originR)*WORLD_SCALE);
            impact.userData.core.position.y=blood?1.3:vehicle?1.02:metal?1.48:.55;
            impact.userData.core.scale.setScalar(vehicle?.06+pct*.16:blood?.3+pct*.72:metal?.2+pct*1.18:.25+pct*.9);
            impact.userData.core.material.opacity=vehicle?pct*.42:blood?pct*.72:pct;
            impact.userData.core.material.color.set(blood?0xb91520:vehicle?0xffbf55:metal?0xf2f8ff:0xffd36a);
            impact.userData.sparks.forEach((spark,s)=>{
              const part=src.parts?.[s],life=part?Math.max(0,Math.min(1,part.life/part.max)):pct,ang=Math.atan2(part?.vr||Math.sin(s),part?.vc||Math.cos(s)),travel=(1-life)*(vehicle?.72:metal?3.25:1.8);
              spark.visible=!blood&&life>0&&(!vehicle||s<(src.parts?.length||0));
              spark.position.set(Math.cos(ang)*travel,vehicle?.82+Math.sin(life*Math.PI)*.34:(metal?.7:.12)+Math.sin(life*Math.PI)*(metal?1.85:1.25),Math.sin(ang)*travel);
              spark.rotation.z=ang;
              spark.scale.set(vehicle?.2+life*.42:metal?.7+life*1.5:.5+life,vehicle?.16+life*.5:metal?.55+life*1.8:.5+life,vehicle?.2+life*.42:metal?.7+life*1.5:.5+life);
              spark.material.opacity=vehicle?life*.78:life;
              try{spark.material.color.set(part?.color||'#ffd36a');}catch(_){}
            });
            impact.userData.bloodDrops.forEach((drop,d)=>{const part=src.parts?.[d%Math.max(1,src.parts?.length||1)],ang=Math.atan2(part?.vr||Math.sin(d*2.19),part?.vc||Math.cos(d*2.19)),speed=.8+(d%5)*.38,travel=elapsed*speed*2.5;drop.visible=blood&&pct>0;drop.position.set(Math.cos(ang)*travel,1.15+Math.sin(Math.min(1,elapsed*1.3)*Math.PI)*(1.35+(d%4)*.28)-elapsed*.7,Math.sin(ang)*travel);drop.scale.setScalar(.72+pct*.52);drop.material.opacity=Math.max(0,pct*.96);});
            impact.userData.bloodSplat.visible=blood;impact.userData.bloodSplat.scale.setScalar(.25+elapsed*1.45);impact.userData.bloodSplat.material.opacity=blood?Math.max(.18,pct*.62):0;
          });
          impactPool.forEach((impact,i)=>{const src=dynamic.impactFx[i];if(!impact.visible||!src?.glass||src.vehicle)return;const pct=Math.max(0,Math.min(1,src.life/src.max));impact.userData.core.position.y=1.92;impact.userData.core.scale.setScalar(.16+pct*.82);impact.userData.core.material.color.set(0xcff7ff);impact.userData.sparks.forEach((spark,s)=>{if(!spark.visible)return;const scale=.36+pct*.76;spark.position.y=.85+Math.sin(pct*Math.PI)*(1.35+(s%4)*.24);spark.scale.set(scale,scale*1.08,scale);});});
          let bulletHoleMatricesDirty=false,bulletHoleColorsDirty=false;for(let i=0;i<activeBulletHoleInstances;i++){const src=dynamic.bulletHoleFx[i],ang=+src.ang||0,size=(src.heavy?1.12:.68)*(+src.scale||1),fade=Math.max(.48,1-Math.max(0,+src.age||0)/120000),height=1.82+((+src.id||i)*.37%1)*.72,matrixSig=`${src.id??i}:${src.r}:${src.c}:${ang}:${src.rot||0}:${size}`;if(bulletHoleMatrixSignatures[i]!==matrixSig){bulletHoleMatrixSignatures[i]=matrixSig;instanceQuat.setFromEuler(instanceEuler.set(0,-Math.PI/2-ang,+src.rot||0));instanceMatrix.compose(instancePosition.set((src.c-originC)*WORLD_SCALE-Math.cos(ang)*.055,height,(src.r-originR)*WORLD_SCALE-Math.sin(ang)*.055),instanceQuat,instanceScale.set(size,size,1));bulletHoleDecals.setMatrixAt(i,instanceMatrix);bulletHoleMatricesDirty=true;}const colorSig=`${matrixSig}:${fade}`;if(bulletHoleColorSignatures[i]!==colorSig){bulletHoleColorSignatures[i]=colorSig;bulletHoleDecals.setColorAt(i,instanceColor.setRGB(.52*fade,.46*fade,.39*fade));bulletHoleColorsDirty=true;}}if(bulletHoleMatricesDirty)bulletHoleDecals.instanceMatrix.needsUpdate=true;if(bulletHoleColorsDirty&&bulletHoleDecals.instanceColor)bulletHoleDecals.instanceColor.needsUpdate=true;
          let bloodMatricesDirty=false,bloodColorsDirty=false;for(let i=0;i<activeBloodInstances;i++){const src=dynamic.bloodFx[i],fade=Math.max(.12,Math.min(1,(+src.life||0)/Math.max(1,+src.max||1))),scale=Math.max(.28,Math.min(1.65,(+src.radius||5)*.105)),sx=src.trail?scale*.72:scale,sy=src.trail?scale*1.42:scale,matrixSig=`${src.id??i}:${src.r}:${src.c}:${src.rot||0}:${sx}:${sy}`;if(bloodMatrixSignatures[i]!==matrixSig){bloodMatrixSignatures[i]=matrixSig;instanceQuat.setFromEuler(instanceEuler.set(-Math.PI/2,0,+src.rot||0));instanceMatrix.compose(instancePosition.set((src.c-originC)*WORLD_SCALE,.045,(src.r-originR)*WORLD_SCALE),instanceQuat,instanceScale.set(sx,sy,1));bloodDecals.setMatrixAt(i,instanceMatrix);bloodMatricesDirty=true;}const colorSig=`${matrixSig}:${src.soot?1:0}:${src.crater?1:0}:${fade}`;if(bloodColorSignatures[i]!==colorSig){bloodColorSignatures[i]=colorSig;src.soot?bloodDecals.setColorAt(i,instanceColor.setRGB(src.crater?.025:.045,src.crater?.022:.038,src.crater?.02:.03)):bloodDecals.setColorAt(i,instanceColor.setRGB(.28+.22*fade,.008,.014));bloodColorsDirty=true;}}if(bloodMatricesDirty)bloodDecals.instanceMatrix.needsUpdate=true;if(bloodColorsDirty&&bloodDecals.instanceColor)bloodDecals.instanceColor.needsUpdate=true;if(telemetryDue){renderer.domElement.dataset.bloodDecals=String(activeBloodInstances);renderer.domElement.dataset.bulletHoleColorUpload=bulletHoleColorsDirty?'dirty':'cached';renderer.domElement.dataset.bloodColorUpload=bloodColorsDirty?'dirty':'cached';renderer.domElement.dataset.decalColorUploadProfile='bridge-snapshot-signature-v345';}
          let goreColorsDirty=false,goreMatricesDirty=false,settledGoreInstances=0;for(let i=0;i<activeGoreInstances;i++){
            const src=dynamic.goreFx[i];
            const age=Math.max(0,+src.age||0)/1000,vz=Math.max(1,+src.vz||4);
            const flightEnd=(vz+Math.sqrt(vz*vz+33.32))/9.8,flight=Math.min(age,flightEnd);
            const x=(+src.c+(+src.vc||0)*flight-originC)*WORLD_SCALE;
            const z=(+src.r+(+src.vr||0)*flight-originR)*WORLD_SCALE;
            const y=Math.max(.18,1.7+vz*flight-4.9*flight*flight);
            const leg=String(src.part||'').includes('Leg'),spin=(+src.spin||0)*flight,settled=age>=flightEnd,matrixSig=settled?`${String(src.id||i)}:${x}:${y}:${z}:${spin}:${leg?1:0}`:'';
            if(settled)settledGoreInstances++;
            const role=String(src.role||'').toLowerCase(),faction=String(src.faction||'').toLowerCase();
            const limbColor=leg?0x34363f:role.includes('police')||role.includes('cop')?0x3478b8:role.includes('gang')||role.includes('guard')?(faction.includes('purple')?0x7447aa:faction.includes('yellow')?0xd5c39c:0xb84a5d):[0x52b8ee,0xf0717f,0x8acb63,0xefae46][i%4];
            const goreColorSig=`${limbColor}`;if(goreColorSignatures[i]!==goreColorSig){goreColorSignatures[i]=goreColorSig;goreLimbs.setColorAt(i,instanceColor.setHex(limbColor));goreColorsDirty=true;}
            if(!settled||goreMatrixSignatures[i]!==matrixSig){goreMatrixSignatures[i]=matrixSig;instanceQuat.setFromEuler(instanceEuler.set(spin,spin*.63,spin*.38));instanceMatrix.compose(instancePosition.set(x,y,z),instanceQuat,instanceScale.set(1,leg?1.08:.86,1));goreLimbs.setMatrixAt(i,instanceMatrix);
            for(let k=0;k<2;k++){
              const ci=i*2+k,a=spin*.32+k*Math.PI,spread=.18+k*.13;
              instanceQuat.setFromEuler(instanceEuler.set(spin*(1.2+k*.25),spin*.7+k,spin*.45));
              instanceMatrix.compose(instancePosition.set(x+Math.cos(a)*spread,y+.12+k*.08,z+Math.sin(a)*spread),instanceQuat,instanceScale.setScalar(k?.72:.9));
              goreChunks.setMatrixAt(ci,instanceMatrix);
              if(goreColorsDirty)goreChunks.setColorAt(ci,instanceColor.setHex(k?0x68070b:0xc51b24));
            }goreMatricesDirty=true;}
          }
          if(goreMatricesDirty){goreLimbs.instanceMatrix.needsUpdate=true;goreChunks.instanceMatrix.needsUpdate=true;}
          if(goreColorsDirty&&goreLimbs.instanceColor)goreLimbs.instanceColor.needsUpdate=true;
          if(goreColorsDirty&&goreChunks.instanceColor)goreChunks.instanceColor.needsUpdate=true;
          if(telemetryDue){renderer.domElement.dataset.detachedLimbs=String(dynamic.goreFx?.length||0);renderer.domElement.dataset.settledGoreInstances=String(settledGoreInstances);renderer.domElement.dataset.goreMatrixUpload=goreMatricesDirty?'dirty':'cached';renderer.domElement.dataset.goreMatrixProfile='full-flight-settled-signature-v348';}
          explosionPool.forEach((blast,i)=>{
            const src=dynamic.explosionFx[i];blast.visible=!!src;if(!src)return;
            const pct=Math.max(0,Math.min(1,src.age/src.life)),burst=Math.sin(Math.min(1,pct*1.5)*Math.PI),seed=+src.seed||i,vehicle=src.kind==='vehicle';
            blast.position.set((src.c-originC)*WORLD_SCALE,.18,(src.r-originR)*WORLD_SCALE);
            const core=blast.userData.core;core.position.y=1.2+burst*(vehicle?2.7:2.05);core.scale.setScalar(.72+burst*(vehicle?3.65:3.05));core.material.opacity=Math.max(0,(1-pct*1.48)*.82);core.material.color.set(pct<.06?0xffef9b:pct<.28?0xffb928:pct<.64?0xff4309:0x681006);
            blast.userData.fireShell.position.y=1.3+burst*2.05;blast.userData.fireShell.scale.setScalar(.6+burst*(vehicle?4.25:3.45));blast.userData.fireShell.material.opacity=Math.max(0,(1-pct*1.5)*.62);
            blast.userData.shock.material.opacity=Math.max(0,(1-pct*1.85)*.98);blast.userData.shock.scale.setScalar(.55+pct*(vehicle?10.8:8.1));blast.userData.groundRing.material.opacity=Math.max(0,(1-pct*1.18)*.9);blast.userData.groundRing.scale.setScalar(.45+pct*(vehicle?8.5:6.1));
            blast.userData.plumes.forEach((flame,s)=>{const a=s*2.399+seed,fade=Math.max(0,1-pct*1.18),rad=.22+(s%5)*.34+pct*(vehicle?1.8:1.18),flick=.78+.22*Math.sin(t*.024+s*1.83);flame.visible=fade>.02;flame.position.set(Math.cos(a)*rad,.72+burst*(1.5+(s%4)*.52)+pct*1.25,Math.sin(a)*rad);flame.scale.set((1.05+burst*(vehicle?3.2:2.2))*flick,(1.15+burst*(vehicle?4.45:3.05))*fade,1);flame.rotation.y=camera.rotation.y+(s%3-1)*.18;flame.rotation.z=Math.sin(t*.008+s)*.18;});
            blast.userData.smoke.forEach((smoke,s)=>{const a=s*2.4+seed,stem=s%4===0,rad=stem?.38:.75+pct*(vehicle?3.7:2.8);smoke.position.set(Math.cos(a)*rad,1.05+pct*(vehicle?6.8:4.8)+(s%4)*.38,Math.sin(a)*rad);smoke.scale.setScalar(.68+pct*(vehicle?3.65:2.65)+(s%4)*.28);smoke.material.opacity=Math.max(0,Math.sin(Math.min(1,pct*1.08)*Math.PI)*.84);});
            blast.userData.embers.forEach((ember,s)=>{const a=s*2.399+seed,travel=Math.min(1,pct*1.72)*((vehicle?5.8:4.2)+(s%7)*.74),arc=Math.sin(Math.min(1,pct*1.42)*Math.PI)*(3.2+(s%6)*.92);ember.position.set(Math.cos(a)*travel,.82+arc,Math.sin(a)*travel);ember.scale.setScalar(Math.max(.16,1.16-pct*.9));});
            blast.userData.debris.forEach((shard,s)=>{const a=s*2.17+seed,flight=Math.min(1,pct*1.2),travel=flight*((vehicle?4.7:3.1)+(s%5)*1.15);shard.position.set(Math.cos(a)*travel,.32+Math.sin(flight*Math.PI)*(2.9+(s%6)*.82),Math.sin(a)*travel);shard.rotation.set(pct*(s+2)*6,pct*(s+1)*8,pct*(s+3)*5);});
          });if(telemetryDue){renderer.domElement.dataset.explosionProfile='textured-fireball-pooled-v199';renderer.domElement.dataset.explosionParticles='10-flame-plumes-8-smoke-20-embers-10-debris-no-lights';renderer.domElement.dataset.activeExplosionLights='0';}
          throwablePool.forEach((item,i)=>{const src=dynamic.throwableFx?.[i];item.visible=!!src;if(!src)return;const molotov=src.kind==='molotov';item.userData.grenade.visible=!molotov;item.userData.bottle.visible=item.userData.wick.visible=molotov;item.position.set((src.c-originC)*WORLD_SCALE,1.2+(+src.height||0)*WORLD_SCALE,(src.r-originR)*WORLD_SCALE);item.rotation.set(src.progress*9,src.progress*13,src.progress*7);item.userData.wick.scale.setScalar(.8+Math.sin(t*.03+i)*.2);});
          firePool.forEach((fire,i)=>{const src=dynamic.fireFx?.[i];fire.visible=!!src;if(!src)return;const lifePct=Math.max(0,Math.min(1,1-src.age/src.life)),seed=+src.seed||i,areaScale=src.kind==='ground'?Math.max(1,Math.min(2.15,(+src.radius||4.2)/2.5)):1;fire.position.set((src.c-originC)*WORLD_SCALE,.06,(src.r-originR)*WORLD_SCALE);fire.userData.glow.scale.setScalar((.72+lifePct*.38)*areaScale);fire.userData.glow.material.opacity=.08+lifePct*.13;fire.userData.flames.forEach((flame,s)=>{const a=s*2.399+seed,rad=(.24+(s%5)*.28)*areaScale,flick=.75+.25*Math.sin(t*.018+s*1.7);flame.visible=lifePct>.02;flame.position.set(Math.cos(a)*rad,.72+(s%3)*.22+flick*.28,Math.sin(a)*rad);flame.scale.set((.94+flick*.3)*(src.kind==='ground'?1.16:1),(.84+flick*.5)*Math.max(.22,lifePct),1);flame.rotation.y=camera.rotation.y+(s%3-1)*.16;flame.rotation.z=Math.sin(t*.008+s)*.14;});fire.userData.smokes.forEach((smoke,s)=>{const q=((t*.00028+s*.2+seed)%1);smoke.visible=true;smoke.position.set(Math.sin(seed+s*2.1)*.72*areaScale,1.15+q*4.9,Math.cos(seed+s*1.7)*.74*areaScale);smoke.scale.setScalar((.5+q*1.42)*(src.kind==='ground'?1.12:1));smoke.material.opacity=(1-q)*lifePct*.32;});});
          let activeWreckFireFx=0;
          firePool.forEach((fire,i)=>{const src=dynamic.fireFx?.[i];if(!fire.visible||src?.kind!=='vehicle_wreck')return;activeWreckFireFx++;const seed=+src.seed||i;fire.position.y=.18;fire.userData.glow.scale.setScalar(1.05);fire.userData.glow.material.opacity=.2;fire.userData.flames.forEach((flame,s)=>{const a=s*2.399+seed,rad=.2+(s%5)*.34,flick=.7+.3*Math.sin(t*.017+s*1.71);flame.visible=true;flame.position.set(Math.cos(a)*rad,.76+(s%3)*.3+flick*.34,Math.sin(a)*Math.min(1.34,rad));flame.scale.set(1.12+flick*.38,1.08+flick*.9+(s%3)*.22,1);flame.rotation.y=camera.rotation.y+(s%3-1)*.18;flame.rotation.z=Math.sin(t*.006+s)*.18;});fire.userData.smokes.forEach((smoke,s)=>{const q=(t*.00016+s*.2+seed)%1;smoke.position.set(Math.sin(seed+s*2.1)*.84,1.45+q*6.6,Math.cos(seed+s*1.7)*.86);smoke.scale.setScalar(.82+q*2.28);smoke.material.opacity=(1-q)*.52;});});if(telemetryDue){renderer.domElement.dataset.wreckFireFx=String(activeWreckFireFx);renderer.domElement.dataset.wreckFireProfile='collapsed-black-shell-textured-fire-v199';}
          const burningActors=dynamic.npcs.filter(x=>x?.burning&&!x.dead).slice(0,burningActorPool.length);burningActorPool.forEach((fire,i)=>{const src=burningActors[i];fire.visible=!!src;if(!src)return;const key=String(src.id??src.uid??dynamic.npcs.indexOf(src)),motion=npcMotionStates.get(key),x=motion?.visualX??(+src.c-originC)*WORLD_SCALE,z=motion?.visualZ??(+src.r-originR)*WORLD_SCALE;fire.position.set(x,.15+(+src.elevation||0)*WORLD_SCALE,z);fire.userData.flames.forEach((flame,s)=>{const a=s*2.31,flick=.72+.28*Math.sin(t*.02+s*1.9);flame.position.set(Math.cos(a)*.34,.6+s*.45,Math.sin(a)*.34);flame.scale.set(.8,flick,.8);flame.material.opacity=.72+.22*flick;});});
          if(telemetryDue){renderer.domElement.dataset.bulletHoles=String(dynamic.bulletHoleFx?.length||0);renderer.domElement.dataset.activeWeaponFx=`p${dynamic.projectiles.length}:m${dynamic.muzzleFx.length}:s${dynamic.shellFx?.length||0}:i${dynamic.impactFx.length}:h${dynamic.bulletHoleFx?.length||0}:x${dynamic.explosionFx.length}:f${dynamic.fireFx?.length||0}`;const life=dynamic.effectLifecycle||{};renderer.domElement.dataset.effectLifecycle=`b${life.bullets||0}:m${life.muzzles||0}:s${life.shells||0}:i${life.impacts||0}:d${life.blood||0}:h${life.holes||0}:g${life.gore||0}:x${life.explosions||0}:t${life.throwables||0}:f${life.fires||0}:q${life.pendingTimers||0}`;renderer.domElement.dataset.effectLifecycleProfile='bounded-source-expiry-v352';}
        }
        if(dynamic)for(let i=0;i<Math.min(NPC_CAP,dynamic.npcs.length);i++){const lift=Math.max(0,+dynamic.npcs[i]?.elevation||0)*WORLD_SCALE;if(!lift)continue;npcLabels[i].sprite.position.y+=lift;}
        // Bridge snapshots update less often than rendering. Preserve a visual
        // pose between snapshots so traffic accelerates, brakes and turns
        // continuously instead of jumping from sample to sample.
        let predictedVehicleCount=0;cars.forEach(car=>{const src=car.userData.source;if(!car.visible||!src)return;const ux=car.userData,rawX=car.position.x,rawZ=car.position.z,velocityX=(+src.velC||0)*WORLD_SCALE,velocityZ=(+src.velR||0)*WORLD_SCALE,speed=Math.hypot(velocityX,velocityZ),prediction=src.braking ? .012 : (speed>.02 ? .06 : 0);if(prediction)predictedVehicleCount++;if(ux.visualEntityId!==ux.entityId){ux.visualEntityId=ux.entityId;ux.visualX=rawX;ux.visualZ=rawZ;ux.visualYaw=car.rotation.y;resetVehicleAnimation(car);}const targetX=rawX+velocityX*prediction,targetZ=rawZ+velocityZ*prediction,headingR=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velR:+src.dirR,headingC=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velC:+src.dirC,headingLen=Math.hypot(headingR,headingC),targetYaw=headingLen>.02?Math.atan2(-headingR,headingC):car.rotation.y,targetDistance=Math.hypot(targetX-ux.visualX,targetZ-ux.visualZ),alpha=targetDistance>18?1:1-Math.exp(-dt*(src.braking?12:15));ux.visualX=THREE.MathUtils.lerp(ux.visualX,targetX,alpha);ux.visualZ=THREE.MathUtils.lerp(ux.visualZ,targetZ,alpha);let yawDelta=targetYaw-ux.visualYaw;while(yawDelta>Math.PI)yawDelta-=Math.PI*2;while(yawDelta<-Math.PI)yawDelta+=Math.PI*2;ux.visualYaw+=yawDelta*Math.min(1,dt*(src.turning?6.5:10));car.position.x=ux.visualX;car.position.z=ux.visualZ;car.rotation.y=ux.visualYaw;});if(telemetryDue){renderer.domElement.dataset.motionSmoothing='npc-capped-prediction-foot-plant-v3-vehicle-velocity';renderer.domElement.dataset.npcMotionStates=String(npcMotionStates.size);renderer.domElement.dataset.predictedVehicles=String(predictedVehicleCount);}
        let animatedVehicleRigs=0;cars.forEach((car,i)=>{const src=car.userData.source;if(!car.visible||!src)return;const distance=Math.hypot(car.position.x-player.position.x,car.position.z-player.position.z);if(distance>115&&lowFps&&((i+(t/100|0))&1))return;updateVehicleAnimation(car,src,dt);animatedVehicleRigs++;});if(telemetryDue){renderer.domElement.dataset.animatedVehicleRigs=String(animatedVehicleRigs);renderer.domElement.dataset.vehicleAnimationProfile='pool-reset-steering-wheel-roll-pitch-suspension-v252';}
        updateVehicleBeams();
        const move=frameMove.set((keys.has('KeyD')||keys.has('ArrowRight')?1:0)-(keys.has('KeyA')||keys.has('ArrowLeft')?1:0),0,(keys.has('KeyS')||keys.has('ArrowDown')?1:0)-(keys.has('KeyW')||keys.has('ArrowUp')?1:0));
        let moving=false,playerArrestPhase='',playerArrestProgress=0,playerArrestCuffed=false,playerArrestHidden=false,playerVoluntarySurrender=false,playerAnimationLayer='locomotion',playerTeleported=false;animationActionLocked=false;
        if(bridge){
          bridge.updateDistrictEntry?.();
          const state=bridge.getPlayerState();playerDead=!!state.dead;updatePlayerSpeech(localPlayerSpeech,state.chat,player.position.x,playerFloorElevation+8.15,player.position.z);
          playerArrestPhase=String(state.arrestPhase||'');activeArrestLabelPhase=playerArrestPhase;if(telemetryDue)renderer.domElement.dataset.custodyLabelMode=activeArrestLabelPhase||'normal';playerArrestProgress=Math.max(0,Math.min(1,+state.arrestProgress||0));playerArrestCuffed=!!state.cuffed;playerArrestHidden=!!state.arrestHidden;playerVoluntarySurrender=!!state.voluntarySurrender;playerAnimationLayer=resolvePlayerAnimationLayer(state);animationActionLocked=playerAnimationLayer==='death'||playerAnimationLayer==='driving'||playerAnimationLayer==='vehicle-entry'||playerAnimationLayer.startsWith('arrest-');if(animationActionLocked){triggerHeld=false;if(throwAimHeld){throwAimHeld=false;throwAimLine.visible=throwLandingRing.visible=false;renderer.domElement.dataset.throwAim='cancelled:animation-state';}}
          if(prisonReleaseGate){
            const gateTarget=Math.max(0,Math.min(1,+state.jailGateProgress||0)),gateAlpha=1-Math.exp(-dt*5.4);prisonReleaseGateVisual=THREE.MathUtils.lerp(prisonReleaseGateVisual,gateTarget,gateAlpha);
            const easedGate=prisonReleaseGateVisual*prisonReleaseGateVisual*(3-2*prisonReleaseGateVisual);prisonReleaseGate.position.y=.68+easedGate*5.35;
            const gateLocked=(+state.jailIn||0)>0||prisonReleaseGateVisual<.82;prisonReleaseGateLight?.material?.color?.setHex(gateLocked?0xff3b3b:0x57f08b);
            if(telemetryDue){renderer.domElement.dataset.jailReleaseGate=gateLocked?`locked:${Math.max(0,Math.ceil(+state.jailIn||0))}`:`open:${prisonReleaseGateVisual.toFixed(2)}`;renderer.domElement.dataset.jailGateProgress=prisonReleaseGateVisual.toFixed(3);}
          }
          const prisonAlarmActive=!!state.prisonAlarm?.active||prisonAlarmBeaconPreview,prisonAlarmBatchRevision=Math.max(0,+state.prisonAlarm?.batchRevision||0);
          if(prisonAlarmBatchRevision!==lastPrisonAlarmBatchRevision){lastPrisonAlarmBatchRevision=prisonAlarmBatchRevision;pendingPrisonAlarmShadow=true;renderer.domElement.dataset.prisonAlarmBatch=`pending:${prisonAlarmBatchRevision}`;}
          if(prisonVehicleLockGate){
            const lockAlpha=1-Math.exp(-dt*(prisonAlarmActive?8.5:4.8));prisonVehicleLockVisual=THREE.MathUtils.lerp(prisonVehicleLockVisual,prisonAlarmActive?1:0,lockAlpha);
            const eased=prisonVehicleLockVisual*prisonVehicleLockVisual*(3-2*prisonVehicleLockVisual);prisonVehicleLockGate.position.y=6.3-eased*5.62;
          }
          let prisonAlarmRedPower=0,prisonAlarmBluePower=0;
          prisonAlarmBeacons.forEach((beacon,i)=>{const phase=(t+i*43)%1280,redPower=prisonAlarmActive?prisonBeaconDoublePulse(phase,0):0,bluePower=prisonAlarmActive?prisonBeaconDoublePulse(phase,640):0,dominantRed=redPower>=bluePower,power=Math.max(redPower,bluePower);prisonAlarmRedPower=Math.max(prisonAlarmRedPower,redPower);prisonAlarmBluePower=Math.max(prisonAlarmBluePower,bluePower);beacon.root.visible=true;beacon.red.material.color.setRGB(.14+redPower*.72,.018+redPower*.035,.025+redPower*.035);beacon.blue.material.color.setRGB(.018+bluePower*.04,.055+bluePower*.24,.15+bluePower*.72);beacon.red.material.emissiveIntensity=.08+redPower*5.4;beacon.blue.material.emissiveIntensity=.08+bluePower*5.4;beacon.red.material.opacity=.72+redPower*.26;beacon.blue.material.opacity=.72+bluePower*.26;beacon.redCore.material.opacity=.04+redPower*.96;beacon.blueCore.material.opacity=.04+bluePower*.96;beacon.redGlow.visible=redPower>.01;beacon.blueGlow.visible=bluePower>.01;beacon.redGlow.material.opacity=redPower*.3;beacon.blueGlow.material.opacity=bluePower*.3;beacon.redGlow.scale.setScalar(1.15+redPower*1.15);beacon.blueGlow.scale.setScalar(1.15+bluePower*1.15);if(beacon.alarmLight){beacon.alarmLight.color.setHex(dominantRed?0xff2638:0x268dff);beacon.alarmLight.intensity=prisonAlarmActive?power*38:0;}});
          if(telemetryDue){renderer.domElement.dataset.prisonAlarmBeaconProfile='fixed-lightbar-double-pulse-soft-glow-v327';renderer.domElement.dataset.prisonAlarmVisual=prisonAlarmActive?`active:red-${prisonAlarmRedPower.toFixed(2)}:blue-${prisonAlarmBluePower.toFixed(2)}:${prisonAlarmBeacons.length}`:'quiet';renderer.domElement.dataset.prisonVehicleGateLock=prisonAlarmActive?'closed':'open';}
          if(!junkyardVisualBuilt&&t>=junkyardProbeAt&&Math.hypot((+state.r||0)-86,(+state.c||0)-66)<=WORLD_SNAPSHOT_RADIUS+4){
            junkyardProbeAt=t+750;
            ensureJunkyardVisual(bridge.getWorldSnapshot?.(WORLD_SNAPSHOT_RADIUS),'proximity');
          }
          vehicleEntryState=state.vehicleEntry||null;
          scheduleSectorLoad(+state.r||0,+state.c||0);
          evictFarStreamedSectors(+state.r||0,+state.c||0);
          const reloadLayerActive=playerAnimationLayer==='reload';activeReloadProgress=reloadLayerActive?Math.max(0,Math.min(1,+state.reloadProgress||0)):0;if(reloadLayerActive&&!reloadWasActive)spawnReloadDebris();reloadWasActive=reloadLayerActive;if(telemetryDue)renderer.domElement.dataset.reloadAnimation=reloadLayerActive?`${currentWeaponFx.family}:${activeReloadProgress.toFixed(2)}`:'idle';
           if(telemetryDue){renderer.domElement.dataset.playerR=(+state.r||0).toFixed(3);renderer.domElement.dataset.playerC=(+state.c||0).toFixed(3);renderer.domElement.dataset.playerAngle=(+state.ang||0).toFixed(3);renderer.domElement.dataset.playerHp=String(+state.hp||0);renderer.domElement.dataset.playerRole=String(state.role||'citizen');renderer.domElement.dataset.playerFamily=String(state.family||'');renderer.domElement.dataset.playerWeapon=String(state.weapon||'');renderer.domElement.dataset.playerInterior=state.interior?'1':'0';renderer.domElement.dataset.playerDriving=state.driving?'1':'0';renderer.domElement.dataset.moveMode=mouseAimActive&&!state.driving?'aim-relative':'legacy';}
          laserAimAllowed=!state.driving&&!state.dead&&!state.vehicleEntry&&!['','none','fists','unarmed'].includes(currentWeaponId);if(laserAimHeld&&!laserAimAllowed)stopLaserAim('weapon-or-state');
          const chosenHat=Math.max(0,+state.look?.hat||0),uniformHat=state.role==='police',creatorHat=[1,2,3,4,7,8].includes(chosenHat),wearPlayerHat=uniformHat||(state.role!=='prisoner'&&creatorHat),showCreatorAccessories=state.role!=='prisoner'&&!uniformHat,liveHairStyle=Math.abs(+state.look?.hair||0)%10,liveFaceStyle=Math.abs(+state.look?.face||0)%10,isFemaleLook=+state.look?.gender===1;policeCapBand.visible=uniformHat;policeBadge.visible=uniformHat;prisonerBadge.visible=state.role==='prisoner';shirtFront.visible=state.role==='mafia'&&!state.armor;tie.visible=state.role==='mafia'&&!state.armor;hatBrim.visible=hatTop.visible=wearPlayerHat;playerHatHairLocks.visible=wearPlayerHat&&liveHairStyle!==0;playerGlasses.visible=showCreatorAccessories&&chosenHat===5;playerEyePatch.visible=showCreatorAccessories&&chosenHat===6;playerChain.visible=showCreatorAccessories&&chosenHat===9;hair.visible=!wearPlayerHat&&![0,3,5,6].includes(liveHairStyle);hairBun.visible=!wearPlayerHat&&(liveHairStyle===2||liveHairStyle===7);hairBack.visible=!wearPlayerHat&&(liveHairStyle===5);hairMohawk.visible=!wearPlayerHat&&(liveHairStyle===3);hairQuiff.visible=!wearPlayerHat&&(liveHairStyle===2||liveHairStyle===7);hairFringe.visible=!wearPlayerHat&&(liveHairStyle===8);hairCurls.visible=!wearPlayerHat&&liveHairStyle===6;playerScar.visible=liveFaceStyle===4;playerBeard.visible=!isFemaleLook&&liveFaceStyle===2;playerMoustache.visible=!isFemaleLook&&liveFaceStyle===3;playerFemaleFace.visible=isFemaleLook;
          const visualSig=`${state.role}:${state.family||''}:${state.look?.gender??0}:${state.look?.skin??0}:${state.look?.body??0}:${state.look?.face??0}:${state.look?.hair??0}:${state.look?.hat??0}:${state.weapon||''}:${state.holsteredWeapon||''}:${state.armor||''}:${state.armorDurability||0}:${state.armorMax||0}:${state.driving?1:0}:${state.dead?1:0}:${state.vehicleEntry?.token||''}:${state.arrestPhase||''}`;if(visualSig!==playerVisualSig){playerVisualSig=visualSig;const bodyIndex=Math.abs(+state.look?.body||0)%4,hairIndex=Math.abs(+state.look?.hair||0)%10,hairStyle=hairIndex,faceIndex=Math.abs(+state.look?.face||0)%10,gender=+state.look?.gender===1,creatorSuit=[0x74262c,0x294761,0x31563f,0x6b5430,0x47345f,0x35383f,0x80502c,0x1f5360],creatorTrousers=[0x151922,0x202731,0x1c2a22,0x2d2924,0x211c2d,0x181a1d,0x30231b,0x14292d],creatorHairs=[0x251a17,0x120f0d,0x56351f,0xb17a3d,0xd6b46d,0x6c241f,0x241a35,0xd9d6cd,0x101923,0x8a4b24],creatorHats=[0x171a20,0x54331f,0x263c5a,0x6d252c,0xc9b98d,0x31543b,0x20242a,0x8c6a30,0x0b0c0f,0x4f315e],roleColor=state.role==='prisoner'?0xf07818:state.role==='police'?0x285c91:state.role==='mafia'?(state.family==='moretti'?0xe6e0d3:0x25272d):creatorSuit[bodyIndex];suitMat.color.setHex(roleColor);playerTrouserMat.color.setHex(state.role==='prisoner'?0x282522:state.role==='police'?0x182536:creatorTrousers[bodyIndex]);skinMat.color.set([0xf0c3a0,0xd8a07c,0xb87955,0x8b583e,0x633c2d,0xf4cbb1][Math.abs(+state.look?.skin||0)%6]);hairMat.color.setHex(creatorHairs[hairIndex]);playerHatMat.color.setHex(uniformHat?0x183a5c:creatorHats[chosenHat%creatorHats.length]);applyPlayerBodyProfile(bodyIndex,gender);head.scale.set(gender?.94:1,1+(faceIndex%3-1)*.035,gender?.94:1);configureWeaponVisual(state.weapon);configureArmorVisual(state.role==='prisoner'?null:state.armor,state.armorDurability,state.armorMax);gun.visible=gun.visible&&!state.driving&&!state.dead&&!state.vehicleEntry&&!state.arrestPhase&&state.role!=='prisoner';holsteredPistol.visible=!!state.holsteredWeapon&&!state.weapon&&!state.driving&&!state.dead&&!state.vehicleEntry&&!state.arrestPhase&&state.role!=='prisoner';renderer.domElement.dataset.holsteredWeapon=String(state.holsteredWeapon||'');renderer.domElement.dataset.playerUniform=state.role==='prisoner'?'orange-prisoner':state.role==='police'?'police-over-identity':'creator-identity';renderer.domElement.dataset.playerIdentityLook=`${gender?1:0}:${bodyIndex}:${hairIndex}:${chosenHat}`;renderer.domElement.dataset.playerBodyProfile=`${bodyIndex}:${playerBodyProfile.bodyX}:${playerBodyProfile.bodyZ}:${playerBodyProfile.arm}:${playerBodyProfile.leg}`;renderer.domElement.dataset.playerFaceDetails=faceIndex===4?'scar':faceIndex===2&&!gender?'beard':faceIndex===3&&!gender?'moustache':'base';renderer.domElement.dataset.playerHairProfile=wearPlayerHat?'tucked':String(hairStyle);renderer.domElement.dataset.playerAccessoryProfile=showCreatorAccessories&&chosenHat===5?'glasses':showCreatorAccessories&&chosenHat===6?'eye-patch':showCreatorAccessories&&chosenHat===9?'chain':wearPlayerHat?'hat':'none';}
          carriedMoneyBag.visible=!!state.carryingBag&&!state.driving&&!state.arrestPhase;playerHpPct=Math.max(0,Math.min(1,(+state.hp||0)/100));
          const impact=state.impact||null,impactStamp=impact&&impact.age<900?(+impact.stamp||t-impact.age):-1;
          if(impactStamp>playerImpactStamp+1){playerImpactStamp=impactStamp;playerHitUntil=t+Math.round(390+Math.max(0,+impact.power||0)*230);playerHitPower=Math.max(.55,Math.min(1.45,(+impact.power||.45)*1.45));const relative=localAngleDelta(+impact.angle||0,+state.ang||0);playerHitSide=Math.sin(relative)>=0?1:-1;playerHitForward=Math.cos(relative);}
          else if(lastPlayerHp>=0&&(+state.hp||0)<lastPlayerHp){playerHitUntil=t+480;playerHitSide=playerHitSide>0?-1:1;playerHitForward=0;playerHitPower=1;}
          if(playerDead&&!playerDeathStartedAt){playerDeathStartedAt=t;const rel=impact?localAngleDelta(+impact.angle||0,+state.ang||0):0;playerDeathVariant=Math.abs(Math.sin(rel))>.62?(Math.sin(rel)>0?2:3):(Math.cos(rel)>0?0:1);}
          else if(!playerDead)playerDeathStartedAt=0;
          lastPlayerHp=+state.hp||0;paintPlayerNameHealth(playerHpPct);
          const interiorData=state.interior?bridge.getInteriorState?.():null,showInterior=!!(interiorData&&rendererConfig.interiorsEnabled!==false),showThree=!state.interior||showInterior;
          renderer.domElement.style.display=showThree?'block':'none';stage.classList.toggle('three-mode',showThree);
          if(showInterior){
            interiorLightingActive=true;
            const layoutSig=interiorData.layout?`${interiorData.layout.props?.map(p=>p.id).join(',')||''}:${interiorData.layout.safes?.map(s=>`${s.id}:${s.opened?1:0}`).join(',')||''}`:'',
              businessSig=interiorData.businessLayout?`${interiorData.businessLayout.id}:v${interiorData.businessLayout.version}:${interiorData.businessLayout.items?.length||0}:${interiorData.businessLayout.safes?.map(s=>`${s.id}:${s.opened?1:0}`).join(',')||''}`:'',
              aptSig=interiorData.apartment?JSON.stringify({v:5,key:interiorData.apartment.key||'',owned:!!interiorData.apartment.owned,ownerUid:interiorData.apartment.ownerUid||'',ownerName:interiorData.apartment.ownerName||'',district:interiorData.apartment.district||'',levels:interiorData.apartment.levels||{}}):'',
              bankSig=interiorData.bank?`${interiorData.bank.visualVersion||0}:${interiorData.bank.phase}:${interiorData.bank.alarmTriggered?1:0}:${interiorData.bank.bags?.map(b=>b.id).join(',')||''}`:'',
              sig=`${interiorData.kind}:${interiorData.type}:${interiorData.bizId||''}:${interiorData.room||''}:${interiorData.width}:${interiorData.height}:${layoutSig}:${businessSig}:${aptSig}:${bankSig}:${interiorData.loot?`${interiorData.loot.r}:${interiorData.loot.c}:${interiorData.loot.hp?1:0}`:'none'}`;
            if(sig!==interiorSignature){
              interiorSignature=sig;
              // The authored bank builder owns its floor and walls, so do not construct and immediately discard a generic room.
              if(interiorData.kind==='bank')decorateBankInterior(interiorData);
              else{
                rebuildInterior(interiorData);
                if(interiorData.bizId==='major_casino')decorateGrandCasinoInterior(interiorData);
                else if(!decorateApartmentInterior(interiorData)&&!decorateBusinessInterior(interiorData)&&!decorateServiceInterior(interiorData)&&!decorateVenueInterior(interiorData))decoratePremiumInterior(interiorData);
              }
              interiorGroup.traverse(o=>o.layers.set(1));
            }
            playerFloorElevation=Math.max(0,+interiorData.playerElevation||0)*WORLD_SCALE;
            interiorGroup.visible=true;camera.layers.set(1);activeAimSurface=interiorFloor||ground;
            scene.background.set(interiorData.bizId==='major_casino'?0x09050b:0x0a1018);scene.fog.density=0;
            const bankRoom=interiorData.kind==='bank'?(interiorData.room||'lobby'):'',
              bankSize=interiorData.bank?.size||'small',
              nextCameraKey=interiorData.bizId==='major_casino'?'casino':interiorData.kind==='bank'?`bank:${bankSize}:${bankRoom}`:'standard';
            if(cameraZoomMode!=='interior'||cameraZoomKey!==nextCameraKey){
              cameraZoomMode='interior';cameraZoomKey=nextCameraKey;
              if(interiorData.bizId==='major_casino')camera.zoom=.68;
              else if(interiorData.kind==='bank'){
                const roomSpan=Math.max(+interiorData.width||1,+interiorData.height||1);
                camera.zoom=bankRoom==='vault'?THREE.MathUtils.clamp(14/roomSpan,.88,1.15):THREE.MathUtils.clamp(27/roomSpan,.58,.92);
              }else camera.zoom=1.08;
              camera.updateProjectionMatrix();
              renderer.domElement.dataset.interiorCamera=interiorData.bizId==='major_casino'?'architectural-fit-v2':interiorData.kind==='bank'?`bank-${bankRoom}-fit-v4-${bankSize}`:'standard';
            }
          }
          else{
            interiorLightingActive=false;playerFloorElevation=0;interiorGroup.visible=false;camera.layers.set(0);activeAimSurface=ground;
            scene.background.copy(skyColor);scene.fog.color.copy(skyColor);scene.fog.density=.0036;
            if(cameraZoomMode!=='world'){cameraZoomMode='world';cameraZoomKey='';camera.zoom=worldZoom;camera.updateProjectionMatrix();}
            if(!state.interior)interiorSignature='';
          }
          player.visible=!state.driving&&!playerArrestHidden;
          let targetR=+state.r||0,targetC=+state.c||0;if(state.vehicleEntry){const p=Math.max(0,Math.min(1,+state.vehicleEntry.progress||0)),sideFade=p<.52?1:Math.max(0,1-(p-.52)/.4),side=.7*sideFade;targetR=(+state.vehicleEntry.r||targetR)+Math.cos(+state.vehicleEntry.ang||0)*side;targetC=(+state.vehicleEntry.c||targetC)-Math.sin(+state.vehicleEntry.ang||0)*side;}const tx=(targetC-originC)*WORLD_SCALE,tz=(targetR-originR)*WORLD_SCALE;
          const delta=Math.hypot(tx-player.position.x,tz-player.position.z);playerTeleported=!!state.teleported||delta>24;
          if(playerTeleported){player.position.x=tx;player.position.z=tz;playerAnim.speed=playerAnim.gait=playerAnim.accel=0;playerAnim.stepBucket=-1;}else{player.position.x=THREE.MathUtils.lerp(player.position.x,tx,Math.min(1,dt*14));player.position.z=THREE.MathUtils.lerp(player.position.z,tz,Math.min(1,dt*14));}syncMouseAim();
          moving=!playerTeleported&&!state.vehicleEntry&&!playerDead&&!['downed','cuffing','loading','transport'].includes(playerArrestPhase)&&(state.walking||delta>.025);
          const aimYaw=state.vehicleEntry?Math.PI/2-(+state.vehicleEntry.ang||0):Math.atan2(Math.cos(+state.ang||0),Math.sin(+state.ang||0)),sourceMoveAngle=Number.isFinite(+state.moveAng)?+state.moveAng:(+state.ang||0),moveYaw=Math.PI/2-sourceMoveAngle,targetRootYaw=state.vehicleEntry?aimYaw:(state.aiming?aimYaw:moving?moveYaw:aimYaw);
          if(!Number.isFinite(playerAnim.rootYaw)||Math.abs(localAngleDelta(targetRootYaw,playerAnim.rootYaw))>2.9)playerAnim.rootYaw=targetRootYaw;
          playerAnim.rootYaw+=localAngleDelta(targetRootYaw,playerAnim.rootYaw)*(1-Math.exp(-dt*(moving?11:8)));player.rotation.y=playerAnim.rootYaw;
          playerAnim.legYaw=expDamp(playerAnim.legYaw,Math.max(-1.18,Math.min(1.18,localAngleDelta(moveYaw,playerAnim.rootYaw))),state.aiming?9:13,dt);
          const rawSpeed=Number.isFinite(+state.speed)?+state.speed:(moving?3.2:0);playerAnim.speed=expDamp(playerAnim.speed,moving?Math.max(1.8,rawSpeed):0,moving?8:6,dt);playerAnim.gait=expDamp(playerAnim.gait,moving?Math.min(1,playerAnim.speed/3.4):0,moving?10:6,dt);playerAnim.accel=expDamp(playerAnim.accel,Math.max(-18,Math.min(18,+state.accel||0)),8,dt);
          walkPhase=Number.isFinite(+state.walkPhase)?+state.walkPhase:walkPhase;
          const env=bridge.getEnvironmentState(),ar=Math.floor(state.r/10)*10,ac=Math.floor(state.c/10)*10,newAnchor=`${ar}:${ac}`;
          if(newAnchor!==lampAnchor){lampAnchor=newAnchor;const px=(state.c-originC)*WORLD_SCALE,pz=(state.r-originR)*WORLD_SCALE,nearest=fixedLampHeads.map(([x,z])=>({x,z,d:(x-px)**2+(z-pz)**2})).sort((a,b)=>a.d-b.d).slice(0,streetLights.length);streetLights.forEach((lamp,i)=>{const spot=nearest[i];lamp.light.visible=!!spot&&lamp.light.userData.mfzBudgetVisible!==false&&environmentLampPower>.05;if(spot)lamp.light.position.set(spot.x,6.45,spot.z);});}
        }else if(move.lengthSq()>0){move.normalize();player.position.addScaledVector(move,12*dt);player.position.x=Math.max(-34,Math.min(34,player.position.x));player.position.z=Math.max(-34,Math.min(34,player.position.z));const targetYaw=Math.atan2(move.x,move.z);playerAnim.rootYaw+=localAngleDelta(targetYaw,playerAnim.rootYaw)*(1-Math.exp(-dt*12));player.rotation.y=playerAnim.rootYaw;playerAnim.speed=expDamp(playerAnim.speed,4,9,dt);playerAnim.gait=expDamp(playerAnim.gait,1,10,dt);walkPhase+=dt*12;moving=true;}else{playerAnim.speed=expDamp(playerAnim.speed,0,6,dt);playerAnim.gait=expDamp(playerAnim.gait,0,6,dt);}
        const playerCrawling=playerHpPct>0&&playerHpPct<=.15&&!vehicleEntryState&&!playerArrestPhase&&!playerDead,playerLimping=playerHpPct>.15&&playerHpPct<=.35&&!vehicleEntryState&&!playerArrestPhase&&!playerDead;
        const gaitPhase=walkPhase*(playerCrawling?.42:playerLimping?.72:1),playerStep=Math.sin(gaitPhase),idleBreath=Math.sin(t*.0022),playerHitRemaining=Math.max(0,playerHitUntil-t),playerHitRaw=playerHitRemaining?Math.sin(Math.min(1,playerHitRemaining/Math.max(1,390+playerHitPower*230))*Math.PI)*playerHitPower:0,playerHitAllowed=playerAnimationLayer==='locomotion'||playerAnimationLayer==='aim-locomotion'||playerAnimationLayer==='reload',playerHitPulse=playerHitAllowed?playerHitRaw:0,gait=playerAnim.gait;
        leftLeg.rotation.y=rightLeg.rotation.y=playerAnim.legYaw;
        if(gait>.025&&!playerDead){
          if(!bridge)walkPhase+=dt*12;
          if(playerCrawling){leftLeg.rotation.x=playerStep*.18*gait;rightLeg.rotation.x=-playerStep*.18*gait;leftArm.rotation.x=-playerStep*.62*gait;rightArm.rotation.x=playerStep*.62*gait;leftLeg.position.y=.88;rightLeg.position.y=.88;body.rotation.z=playerStep*.025*gait;}
          else if(playerLimping){leftLeg.rotation.x=(playerStep>0?playerStep*.16:playerStep*.46)*gait;rightLeg.rotation.x=-playerStep*.62*gait;leftArm.rotation.x=-playerStep*.28*gait;rightArm.rotation.x=playerStep*.2*gait;leftLeg.position.y=.88+Math.max(0,playerStep)*.06*gait;rightLeg.position.y=.88+Math.max(0,-playerStep)*.22*gait;body.rotation.z=.105+playerStep*.04*gait;}
          else{const stride=.56+.16*gait;leftLeg.rotation.x=playerStep*stride;rightLeg.rotation.x=-playerStep*stride;leftArm.rotation.x=-playerStep*(.34+.12*gait);rightArm.rotation.x=playerStep*(.25+.09*gait);leftLeg.position.y=.88+Math.pow(Math.max(0,playerStep),1.35)*.21*gait;rightLeg.position.y=.88+Math.pow(Math.max(0,-playerStep),1.35)*.21*gait;body.rotation.z=playerStep*.026*gait;}
          const stepBucket=Math.floor((gaitPhase+Math.PI*.5)/Math.PI);if(stepBucket!==playerAnim.stepBucket&&t-playerAnim.lastStepAt>150&&gait>.42&&!playerCrawling&&!playerArrestPhase&&!vehicleEntryState){playerAnim.stepBucket=stepBucket;playerAnim.lastStepAt=t;emitFootContact(t,stepBucket&1?1:-1);}
          head.rotation.y=Math.sin(t*.00065)*.035;
        }else{leftLeg.rotation.x*=.72;rightLeg.rotation.x*=.72;leftArm.rotation.x=idleBreath*.025;rightArm.rotation.x=-idleBreath*.02;leftLeg.position.y=THREE.MathUtils.lerp(leftLeg.position.y,.88,.18);rightLeg.position.y=THREE.MathUtils.lerp(rightLeg.position.y,.88,.18);body.rotation.z=THREE.MathUtils.lerp(body.rotation.z,playerLimping?.09:0,.18);head.rotation.y=Math.sin(t*.00065)*.055;}
        carriedMoneyBag.rotation.z=-.18+playerStep*.07*gait;updateFootContacts(dt);
        if(telemetryDue){renderer.domElement.dataset.playerGait=playerArrestPhase?`arrest-${playerArrestPhase}`:playerDead?'dead':playerCrawling?'crawl':playerLimping?'limp':gait>.72?'run-blend':gait>.08?'walk-blend':'idle';renderer.domElement.dataset.playerHitReaction=playerHitPulse>0?`directional:${playerHitSide}:${playerHitForward.toFixed(2)}`:'idle';renderer.domElement.dataset.playerLocomotionBlend=`${playerAnim.speed.toFixed(2)}:${gait.toFixed(2)}:${playerAnim.legYaw.toFixed(2)}`;renderer.domElement.dataset.playerAnimationLayer=playerAnimationLayer;renderer.domElement.dataset.playerTeleportReset=playerTeleported?'active':'idle';renderer.domElement.dataset.animationActionLock=animationActionLocked?'locked':'open';renderer.domElement.dataset.animationConflictGuard='arrest-death-driving-entry-reload-v252';}
        const locomotionLeftArmPitch=leftArm.rotation.x,locomotionRightArmPitch=rightArm.rotation.x;
        if(gun.visible){const grip=currentWeaponFx.grip,kick=Math.min(1.9,recoilKick/Math.max(.7,currentWeaponFx.recoil||1));if(grip==='two'){gun.rotation.z=-recoilSide*kick*.042;}else if(grip==='throw'||currentWeaponFx.family==='c4'){hidePlayerGripParts();leftArm.quaternion.identity();rightArm.quaternion.identity();const charge=throwAimHeld?Math.max(0,Math.min(1,(t-throwAimStartedAt)/850)):0,release=Math.max(0,Math.min(1,(throwReleaseUntil-t)/420));leftArm.position.set(-playerShoulderX,2.75,0);rightArm.position.set(playerShoulderX*.8,3.08,.18);leftArm.rotation.set(moving?-playerStep*.25:idleBreath*.02,0,0);rightArm.rotation.set(currentWeaponFx.family==='c4'?(-.72-charge*.42):throwAimHeld?(-.72+charge*.92):release?(-1.86+release*.8):-.82,0,.2+charge*.2);gun.rotation.z=currentWeaponFx.family==='c4'?.02:.12+charge*.22;if(telemetryDue)renderer.domElement.dataset.throwPose=throwAimHeld?`windup:${charge.toFixed(2)}`:release?'release':'carry';}else{hidePlayerGripParts();leftArm.quaternion.identity();rightArm.quaternion.identity();leftArm.position.set(-playerShoulderX,2.75,0);rightArm.position.set(playerShoulderX*.8,2.98,.22-kick*.16);leftArm.rotation.set(moving?-playerStep*.34:idleBreath*.025,0,0);rightArm.rotation.set(-1.05-kick*.34,0,.18+kick*.055);gun.rotation.z=.03-recoilSide*kick*.065;}if(telemetryDue){renderer.domElement.dataset.weaponPose=`${grip}-grip`;renderer.domElement.dataset.playerUnarmedArmSwing='weapon-pose-priority';}}else{hidePlayerGripParts();leftArm.quaternion.identity();rightArm.quaternion.identity();leftArm.position.set(-playerShoulderX,2.75,0);rightArm.position.set(playerShoulderX,2.75,0);const freeWalk=gait>.025&&playerAnimationLayer==='locomotion'&&!playerCrawling&&!playerLimping;leftArm.rotation.set(locomotionLeftArmPitch,freeWalk?-playerStep*.018*gait:0,freeWalk?-.035-Math.abs(playerStep)*.012*gait:0);rightArm.rotation.set(locomotionRightArmPitch,freeWalk?playerStep*.018*gait:0,freeWalk?.035+Math.abs(playerStep)*.012*gait:0);showPlayerIdleHands();if(telemetryDue){renderer.domElement.dataset.weaponPose='unarmed';renderer.domElement.dataset.playerUnarmedArmSwing=freeWalk?`${locomotionLeftArmPitch.toFixed(3)}:${locomotionRightArmPitch.toFixed(3)}`:'idle';}}
        const entryProgress=vehicleEntryState?Math.max(0,Math.min(1,+vehicleEntryState.progress||0)):0;if(vehicleEntryState){hidePlayerGripParts();leftArm.quaternion.identity();rightArm.quaternion.identity();const reach=Math.sin(Math.min(1,entryProgress/.55)*Math.PI*.78),sit=Math.max(0,(entryProgress-.48)/.52);rightArm.position.set(.92,3.02,.5);rightArm.rotation.set(-1.28-reach*.42,0,.48);leftArm.position.set(-.88,2.72,.12);leftArm.rotation.set(-.35-sit*.72,0,-.2);leftLeg.rotation.x=-sit*1.18;rightLeg.rotation.x=-sit*.92;leftLeg.position.y=.88-sit*.3;rightLeg.position.y=.88-sit*.24;if(telemetryDue)renderer.domElement.dataset.weaponPose='vehicle-entry';}
        const recoilBody=Math.min(.19,recoilKick*.045),entrySit=vehicleEntryState?Math.max(0,(entryProgress-.45)/.55):0,playerGaitRoll=playerLimping?(moving?.105+playerStep*.04:.09):(moving?playerStep*.026*gait:0),accelLean=Math.max(-.09,Math.min(.09,playerAnim.accel*.005));body.scale.y=vehicleEntryState?1-entrySit*.18:(gait>.02?1:1+idleBreath*.018);body.position.y=2.65+(gait>.02?0:idleBreath*.025)-recoilBody-entrySit*.58-playerHitPulse*.08;body.rotation.x=vehicleEntryState?entrySit*.48:-recoilBody*.62-accelLean-playerHitPulse*(.1+.12*Math.max(0,playerHitForward));body.rotation.z=vehicleEntryState?Math.sin(entryProgress*Math.PI)*-.14:playerGaitRoll+playerHitPulse*playerHitSide*.2+recoilSide*recoilBody*.12;head.rotation.z=playerHitPulse*playerHitSide*.13+(playerLimping?.035:0);head.rotation.x=-playerHitPulse*playerHitForward*.08;player.rotation.x=playerCrawling?Math.PI/2:0;playerContactShadow.visible=!playerCrawling&&!playerDead;player.position.y=playerFloorElevation+(playerCrawling?.62:.08+(gait>.02?(playerLimping?Math.max(0,-playerStep)*.07:Math.abs(playerStep)*.095*gait):0));if(!playerArrestPhase&&!playerDead&&(triggerHeld||keys.has('Space'))&&['smg','tommy_gun','golden_tommy','rifle'].includes(currentWeaponId))shoot(t);updateWeather(dt,t);updateStreetLife(t);
        if(!playerDead&&!playerArrestPhase)player.rotation.z=expDamp(player.rotation.z,0,12,dt);
        if(playerDead&&!playerArrestPhase){
          const age=Math.max(0,t-playerDeathStartedAt),fall=smooth01(Math.min(1,age/620)),settle=Math.max(0,Math.min(1,(age-620)/520)),side=playerDeathVariant===2?1:playerDeathVariant===3?-1:0,forward=playerDeathVariant===0?1:playerDeathVariant===1?-1:0;
          gun.visible=false;holsteredPistol.visible=false;carriedMoneyBag.visible=false;localMuzzleFlash.visible=false;hidePlayerGripParts();
          player.rotation.x=forward*fall*Math.PI*.48;player.rotation.z=side*fall*Math.PI*.48;player.position.y=playerFloorElevation+THREE.MathUtils.lerp(.08,.58,fall)-Math.sin(settle*Math.PI)*.045;body.rotation.x=forward*fall*.18;body.rotation.z=side*fall*.14;head.rotation.x=-forward*fall*.16;head.rotation.z=-side*fall*.12;leftArm.rotation.x=.28+fall*.44;rightArm.rotation.x=-.16-fall*.3;leftLeg.rotation.x=-.12*fall;rightLeg.rotation.x=.24*fall;if(telemetryDue)renderer.domElement.dataset.playerDeathAnimation=`variant-${playerDeathVariant}:${fall.toFixed(2)}`;
        }else if(telemetryDue)renderer.domElement.dataset.playerDeathAnimation='idle';
        if(playerArrestPhase){
          const fallen=playerArrestPhase==='downed'||(playerArrestPhase==='cuffing'&&!playerVoluntarySurrender),fall=playerArrestPhase==='downed'?(playerArrestProgress*playerArrestProgress*(3-2*playerArrestProgress)):1;
          gun.visible=false;holsteredPistol.visible=false;carriedMoneyBag.visible=false;localMuzzleFlash.visible=false;hidePlayerGripParts();
          leftArm.quaternion.identity();rightArm.quaternion.identity();leftLeg.quaternion.identity();rightLeg.quaternion.identity();
          arrestCuffs.visible=playerArrestCuffed;player.rotation.z=0;
          if(fallen){
            player.rotation.x=fall*Math.PI*.5;player.position.y=playerFloorElevation+THREE.MathUtils.lerp(.08,.7,fall);playerContactShadow.visible=fall<.72;
            body.scale.y=1;body.position.y=2.65;body.rotation.set(0,0,-.08*fall);head.rotation.set(0,0,.12*fall);
            const bind=playerArrestPhase==='cuffing'?Math.max(.35,playerArrestProgress):0;
            leftArm.position.set(-.86,2.58,-.18*bind);rightArm.position.set(.86,2.58,-.18*bind);
            leftArm.rotation.set(.18+.68*bind,0,-.3*bind);rightArm.rotation.set(.18+.68*bind,0,.3*bind);
            leftLeg.rotation.x=-.18*fall;rightLeg.rotation.x=.28*fall;
          }else if(playerArrestPhase==='surrendering'){
            player.rotation.x=0;player.position.y=playerFloorElevation+.08;playerContactShadow.visible=true;
            body.scale.y=1;body.position.y=2.65;body.rotation.set(0,0,Math.sin(t*.005)*.018);head.rotation.set(0,0,0);
            leftArm.position.set(-.78,3.34,.02);rightArm.position.set(.78,3.34,.02);
            leftArm.rotation.set(-.08,0,-.28);rightArm.rotation.set(-.08,0,.28);
            leftLeg.rotation.x=0;rightLeg.rotation.x=0;
          }else{
            const loading=playerArrestPhase==='loading'?playerArrestProgress:0;
            player.rotation.x=0;player.position.y=playerFloorElevation+.08-loading*.12;playerContactShadow.visible=true;
            body.scale.y=1-loading*.08;body.position.y=2.65-loading*.28;body.rotation.set(loading*.34,0,Math.sin(t*.003)*.025);
            head.rotation.set(loading*.16,0,0);leftArm.position.set(-.62,2.48,-.28);rightArm.position.set(.62,2.48,-.28);
            leftArm.rotation.set(.88+loading*.18,0,-.34);rightArm.rotation.set(.88+loading*.18,0,.34);
            const cuffWalk=playerArrestPhase==='escort'||playerArrestPhase==='prisoner';
            leftLeg.rotation.x=cuffWalk?playerStep*.48:-loading*.58;rightLeg.rotation.x=cuffWalk?-playerStep*.48:-loading*.48;
            if(playerArrestPhase==='prisoner'){
              body.rotation.z=Math.sin(t*.0032)*.018;head.rotation.y=Math.sin(t*.0014)*.065;
              if(telemetryDue)renderer.domElement.dataset.prisonerCuffedPose=moving?'walking-hands-behind':'idle-hands-behind';
            }
          }
          if(telemetryDue){renderer.domElement.dataset.playerArrestAnimation=`${playerArrestPhase}:${playerArrestProgress.toFixed(2)}`;renderer.domElement.dataset.playerArrestCuffs=arrestCuffs.visible?'visible':'hidden';}
        }else{
          arrestCuffs.visible=false;if(telemetryDue){renderer.domElement.dataset.playerArrestAnimation='idle';renderer.domElement.dataset.playerArrestCuffs='hidden';renderer.domElement.dataset.prisonerCuffedPose='released';}
        }
        for(let i=bullets.length-1;i>=0;i--){const b=bullets[i];b.mesh.position.addScaledVector(b.vel,dt);b.life-=dt;if(b.life<=0){scene.remove(b.mesh);b.mesh.geometry.dispose();b.mesh.material.dispose();bullets.splice(i,1);}}
        recoilKick=Math.max(0,recoilKick-dt*(currentWeaponFx.decay||9));const gunBaseY=gun.userData.baseY===undefined?(gun.userData.baseY=gun.position.y):gun.userData.baseY,gunBaseZ=gun.userData.baseZ===undefined?(gun.userData.baseZ=gun.position.z):gun.userData.baseZ,kickNorm=recoilKick/Math.max(.7,currentWeaponFx.recoil||1),recoilPitch=currentWeaponFx.recoilPitch??.82,recoilBack=currentWeaponFx.recoilBack??.78,recoilRise=currentWeaponFx.recoilRise??.2,pumpTravel=currentWeaponFx.pumpTravel??.62;gun.rotation.x=-.08-Math.min(recoilPitch,kickNorm*(currentWeaponFx.family==='shotgun'?.18:currentWeaponFx.family==='heavy-pistol'?.68:currentWeaponFx.family==='revolver'?.44:.54));gun.rotation.y=recoilSide*Math.min(.07,kickNorm*.026);gun.position.y=gunBaseY+Math.min(recoilRise,kickNorm*(currentWeaponFx.family==='shotgun'?.07:.13));gun.position.z=gunBaseZ-Math.min(recoilBack,kickNorm*(currentWeaponFx.family==='shotgun'?.16:currentWeaponFx.family==='heavy-pistol'?.62:.52));gunSlide.position.z=.72-Math.min(currentWeaponFx.family==='gold-pistol'?.5:.42,kickNorm*(currentWeaponFx.family==='gold-pistol'?.42:.34));heavySlide.position.z=.88-Math.min(.32,kickNorm*.27);revolverHammer.rotation.x=-.32-Math.min(.7,kickNorm*.46);shotgunPump.position.z=1.32-Math.min(pumpTravel,kickNorm*(currentWeaponFx.family==='shotgun'?.34:.52));revolverCylinder.rotation.y+=dt*(recoilKick>0?(currentWeaponId==='nagan'?13:19):0);if(telemetryDue)renderer.domElement.dataset.weaponRecoil=kickNorm>.04?`active:${kickNorm.toFixed(2)}`:'settled';
        if(activeReloadProgress>0){
          const p=activeReloadProgress,family=currentWeaponFx.family,lift=Math.sin(p*Math.PI),magOut=smooth01(Math.min(1,p/.26)),magIn=smooth01(Math.max(0,Math.min(1,(p-.48)/.28))),settle=smooth01(Math.max(0,Math.min(1,(p-.8)/.2))),handling=magOut*(1-magIn);
          gun.rotation.x+=lift*(family==='rpg'?.72:.48);gun.position.y=gunBaseY+(family==='rpg'?.15:-.18)*lift;
          if(currentWeaponFx.grip!=='two'){leftArm.rotation.x=-.58-lift*.55;rightArm.rotation.x=-.72-lift*.34;leftArm.rotation.z=-handling*.22;}
          if(family==='pistol'||family==='heavy-pistol'||family==='gold-pistol'||family==='smg'||family==='rifle'||family==='sniper'){gunMagazine.visible=p<.24||p>.48;gunMagazine.position.y=-.54-handling*1.12+settle*.04;gunMagazine.rotation.z=handling*.62;gunMagazine.rotation.x=.13+handling*.24;if(family==='sniper'){const bolt=Math.sin(Math.max(0,Math.min(1,(p-.68)/.28))*Math.PI);gunSlide.position.z=.72-bolt*.52;gunScope.rotation.z=lift*.08;rightArm.rotation.x-=bolt*.26;}}
          else if(family==='tommy'||family==='gold-tommy'){tommyDrum.visible=p<.24||p>.48;tommyDrum.position.y=-.43-handling*.94;tommyDrum.rotation.x=handling*.72;tommyDrum.rotation.z=Math.PI/2+handling*.24;}
          else if(family==='shotgun'){const shellCycle=Math.sin(Math.max(0,Math.min(1,p/.64))*Math.PI),chamber=Math.sin(Math.max(0,Math.min(1,(p-.62)/.35))*Math.PI);reloadRound.visible=p<.64;reloadRound.position.set(-.38,-.56+shellCycle*.34,.42+shellCycle*.28);reloadRound.rotation.set(0,0,Math.PI/2-shellCycle*.55);shotgunPump.position.z=1.32-chamber*.5;gun.rotation.z=shellCycle*.14;leftArm.rotation.x=-.9-shellCycle*.38;}
          else if(family==='revolver'){const open=smooth01(Math.min(1,p/.22))*(1-smooth01(Math.max(0,Math.min(1,(p-.78)/.2)))),roundMove=smooth01(Math.max(0,Math.min(1,(p-.22)/.46)));reloadRound.visible=p>.22&&p<.78;reloadRound.position.set(.52-roundMove*.45,-.18+roundMove*.2,.5);reloadRound.rotation.set(0,0,Math.PI/2);revolverCylinder.position.x=open*.48;revolverCylinder.rotation.z=Math.PI/2+p*Math.PI*2.5;leftArm.rotation.x=-.78-open*.42;}
          else if(family==='rpg'){const rocketSeat=smooth01(Math.max(0,Math.min(1,(p-.28)/.54)));rpgRocket.visible=p>.12;rpgRocket.position.z=3.42-rocketSeat*1.14;rpgRocket.rotation.x=(1-rocketSeat)*.18;rpgTube.rotation.z=-lift*.18;leftArm.rotation.x=-.9+rocketSeat*.18;}
          if(telemetryDue){const stage=resolveWeaponReloadStage(family,p);renderer.domElement.dataset.reloadTimeline=`${family}:${stage}:${p.toFixed(2)}`;}
        }
        else{const family=currentWeaponFx.family,boxMagazine=family==='pistol'||family==='heavy-pistol'||family==='gold-pistol'||family==='smg'||family==='rifle'||family==='sniper';gunMagazine.visible=gun.visible&&boxMagazine;gunMagazine.position.y=-.54;gunMagazine.rotation.x=.13;gunMagazine.rotation.z=0;tommyDrum.visible=gun.visible&&(family==='tommy'||family==='gold-tommy');tommyDrum.position.y=-.43;tommyDrum.rotation.x=0;tommyDrum.rotation.z=Math.PI/2;reloadRound.visible=false;gunScope.rotation.z=0;revolverCylinder.position.x=0;revolverCylinder.rotation.z=Math.PI/2;rpgTube.rotation.z=0;rpgTube.position.z=.9;rpgRocket.visible=gun.visible&&family==='rpg';rpgRocket.position.z=2.28;rpgRocket.rotation.x=0;if(telemetryDue)renderer.domElement.dataset.reloadTimeline='idle';}
        if(gun.visible&&currentWeaponFx.grip==='two'&&!vehicleEntryState)poseTwoHandedGrip(Math.min(1.9,kickNorm),activeReloadProgress);else if(currentWeaponFx.grip==='two')hidePlayerGripParts();
        if(weaponPoseQaEnabled&&telemetryDue){let finite=true;for(const object of weaponPoseAuditObjects)finite=finite&&object.position.toArray().every(Number.isFinite)&&object.quaternion.toArray().every(Number.isFinite)&&object.scale.toArray().every(Number.isFinite)&&object.scale.x>0&&object.scale.y>0&&object.scale.z>0;renderer.domElement.dataset.weaponPoseIntegrity=finite?'finite':'invalid';renderer.domElement.dataset.weaponPoseQa=`${currentWeaponId}:${activeReloadProgress.toFixed(3)}`;}
        updateLaserAim(t);updateThrowAim(t);
        for(let i=reloadDebris.length-1;i>=0;i--){const d=reloadDebris[i];d.life-=dt;d.vel.y-=7.5*dt;d.mesh.position.addScaledVector(d.vel,dt);if(d.mesh.position.y<.12){d.mesh.position.y=.12;d.vel.y*=-.28;d.vel.x*=.72;d.vel.z*=.72;}d.mesh.rotation.x+=d.spin.x*dt;d.mesh.rotation.y+=d.spin.y*dt;d.mesh.rotation.z+=d.spin.z*dt;if(d.life<=0){scene.remove(d.mesh);d.mesh.geometry.dispose();if(d.mesh.material!==gunDark&&d.mesh.material!==weaponGold)d.mesh.material.dispose();reloadDebris.splice(i,1);}}
        if(muzzleLife>0&&!playerDead&&!playerArrestPhase&&!vehicleEntryState){muzzleLife-=dt;const flashFade=Math.max(0,muzzleLife/.14);muzzle.intensity=96*flashFade;localMuzzleFlash.visible=true;localMuzzleFlash.scale.multiplyScalar(.91);for(const child of localMuzzleFlash.children)child.material.opacity=flashFade;}else{muzzle.intensity=0;localMuzzleFlash.visible=false;}
        camera.position.set(player.position.x+54,62+playerFloorElevation,player.position.z+54);camera.lookAt(player.position.x,1.6+playerFloorElevation,player.position.z);updateBuildingPromptPosition();updateNearbyNpcPromptPosition(nearbyNpcState);updateNearbyVehiclePromptPosition(nearbyVehicleState);
        sun.position.copy(player.position).add(sunOffsetVector);sun.target.position.set(player.position.x,playerFloorElevation,player.position.z);sun.target.updateMatrixWorld();
        // Ray tests stay throttled, while material state persists between samples.
        // The release hold absorbs triangle-edge jitter and eased opacity prevents
        // roofs from flashing opaque/white as the camera follows the player.
        if(t-lastOcclusionAt>occlusionCadence){
          occlusionSight.subVectors(player.position,camera.position);const sightDistance=occlusionSight.length();occlusionRaycaster.set(camera.position,occlusionSight.normalize());occlusionRaycaster.near=.1;occlusionRaycaster.far=sightDistance;occlusionHits.length=0;occlusionRaycaster.intersectObjects(occluders,false,occlusionHits);
          occlusionBlockers.length=0;for(const hit of occlusionHits){if(hit.distance<=sightDistance-34||occlusionBlockers.includes(hit.object))continue;occlusionBlockers.push(hit.object);if(occlusionBlockers.length===2)break;}for(const object of occlusionBlockers){if(object===highlightedBuildingObject||object.userData.building===highlightedBuildingObject?.userData?.building)continue;for(const material of object.userData.fadeMaterials||[])markOcclusionMaterial(material,t);}renderer.domElement.dataset.occlusionBlockers=String(occlusionBlockers.length);
          lastOcclusionAt=t;
        }
        updateOcclusionMaterials(dt,t);
        if(!dynamic){cars.slice(0,3).forEach(x=>x.visible=true);cars[0].position.x = -30 + (tt * 13) % 60; cars[1].position.z = 29 - (tt * 11) % 58; cars[2].position.x = 27 - (tt * 9) % 54;}
        if(realTimeShadows&&t-lastShadowAt>shadowCadence){renderer.shadowMap.needsUpdate=true;lastShadowAt=t;if(pendingPrisonAlarmShadow){pendingPrisonAlarmShadow=false;renderer.domElement.dataset.prisonAlarmBatch=`shadowed:${lastPrisonAlarmBatchRevision}`;}}
        // Render the authored ACES/sRGB palette directly. The legacy fullscreen
        // pass sampled an already encoded target and darkened the whole city.
        bootPlayerMarker.position.set(player.position.x,0,player.position.z);
        bootPlayerMarker.rotation.y=player.rotation.y;
        const programsBefore=renderer.info.programs?.length||0,renderStartedAt=performance.now();renderer.setRenderTarget(null);renderer.render(fullMaterialsReady?scene:bootScene,camera);const renderElapsed=performance.now()-renderStartedAt,programsAfter=renderer.info.programs?.length||0,previousRenderMax=+renderer.domElement.dataset.renderMaxMs||0;if(programsAfter>programsBefore){const lightKinds={},pointDetails=[],newProgramDetails=(renderer.info.programs||[]).slice(programsBefore).map(program=>String(program.cacheKey||program.name||program.id||'program').slice(-360));scene.traverseVisible?.(object=>{if(!object.isLight||!object.layers.test(camera.layers))return;lightKinds[object.type]=(lightKinds[object.type]||0)+1;if(object.isPointLight){const source=object===muzzle?'muzzle':streetLightSet.has(object)?'street':outdoorPointLights.includes(object)?'outdoor':'other';pointDetails.push(`${source}@${object.parent?.name||object.parent?.type||'root'}:${(+object.intensity||0).toFixed(1)}:${object.position.x.toFixed(0)},${object.position.z.toFixed(0)}`);}});renderer.domElement.dataset.lastProgramGrowth=`${programsBefore}>${programsAfter}:${playerArrestPhase||'normal'}:${renderer.domElement.dataset.activeWeaponFx||'none'}`;renderer.domElement.dataset.lastProgramGrowthKeys=newProgramDetails.join('|').slice(0,1800);renderer.domElement.dataset.lastProgramGrowthLights=Object.entries(lightKinds).map(([kind,count])=>`${kind}:${count}`).join(',');renderer.domElement.dataset.lastProgramGrowthPointLights=pointDetails.join('|').slice(0,1200);renderer.domElement.dataset.lastProgramGrowthMuzzle=String(muzzle.intensity||0);renderer.domElement.dataset.lastProgramGrowthCameraLayer=String(camera.layers.mask);}renderer.domElement.dataset.renderMs=renderElapsed.toFixed(1);if(renderElapsed>previousRenderMax){renderer.domElement.dataset.renderMaxMs=renderElapsed.toFixed(1);renderer.domElement.dataset.renderMaxPhase=playerArrestPhase||'normal';renderer.domElement.dataset.renderMaxFx=renderer.domElement.dataset.activeWeaponFx||'none';renderer.domElement.dataset.renderMaxPrograms=String(programsAfter);renderer.domElement.dataset.renderMaxProgramGrowth=`${programsBefore}>${programsAfter}`;renderer.domElement.dataset.renderMaxDeferredRoots=String(deferredRevealRoots.length);renderer.domElement.dataset.renderMaxAt=String(Math.round(t));renderer.domElement.dataset.renderMaxLights=renderer.domElement.dataset.lastProgramGrowthLights||'';renderer.domElement.dataset.renderMaxPointLights=renderer.domElement.dataset.lastProgramGrowthPointLights||'';}
        if(telemetryDue){renderer.domElement.dataset.programCount=String(programsAfter);if((location.hostname==='127.0.0.1'||location.hostname==='localhost')&&rendererParams.has('previewprogramqa')){const list=renderer.info.programs||[],first=list[0],gl=renderer.getContext(),hash=s=>{let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return (h>>>0).toString(36);},groups=new Map();for(const p of list){const sourceKey=`${hash(gl.getShaderSource(p.vertexShader)||'')}:${hash(gl.getShaderSource(p.fragmentShader)||'')}`,group=groups.get(sourceKey)||[];group.push({id:p.id,used:+p.usedTimes||0,key:String(p.cacheKey||'')});groups.set(sourceKey,group);}const duplicates=[...groups].filter(([,group])=>group.length>1).map(([source,group])=>({source,count:group.length,programs:group.map(p=>({id:p.id,used:p.used,key:p.key.slice(-420)}))}));renderer.domElement.dataset.programQaShape=first?Object.keys(first).join(','):'';renderer.domElement.dataset.programQaSources=`${groups.size}/${list.length}`;renderer.domElement.dataset.programQaDuplicateSources=JSON.stringify(duplicates).slice(0,48000);}}
        const frameWorkMs=Math.max(0,performance.now()-t);renderer.domElement.dataset.frameWorkMs=frameWorkMs.toFixed(1);renderer.domElement.dataset.maxFrameWorkMs=Math.max(frameWorkMs,+renderer.domElement.dataset.maxFrameWorkMs||0).toFixed(1);
        renderer.domElement.dataset.palettePipeline='direct-aces-srgb';
        if(!materialCompileStarted){renderer.domElement.dataset.materialCompile='queued';setTimeout(()=>onIdle(beginFullMaterialCompile),48);}
        if(fullMaterialsReady&&!firstFramePresented){firstFramePresented=true;renderer.domElement.dataset.maxFrameGapMs='0';renderer.domElement.dataset.maxFrameWorkMs='0';renderer.domElement.dataset.renderMaxMs='0';renderer.domElement.dataset.renderMaxPhase='startup-reset';renderer.domElement.dataset.buildingPumpMaxMs='0';renderer.domElement.dataset.staticDetailPumpMaxMs='0';renderer.domElement.dataset.deferredWarmupSubmitMaxMs='0';startupMark('first-complete-frame');renderer.domElement.dataset.firstPresentedFrame='full-scene-v199';window.MafioziLoading?.complete('Город готов');}
      };
      requestAnimationFrame(animate);
      startupMark('animation-scheduled');
      renderer.domElement.dataset.rendererDefault='3d-unless-explicit-canvas';
      console.info('[ThreePreview] procedural 3D city enabled');
    } catch (error) {
      stage.classList.remove('three-mode');
      document.getElementById('threeCinematicGrade')?.remove();
      document.body.dataset.threeError=String(error?.stack||error?.message||error).slice(0,1200);
      console.warn('[ThreePreview] Canvas fallback:', error);
      window.MafioziLoading?.complete('3D недоступен — открыт безопасный режим');
    }
  })();
} else if (rendererParams.get('render') === '3d') {
  window.MafioziLoading?.complete('Открыт безопасный 2D-режим');
}
