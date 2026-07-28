// Reversible Three.js city prototype. Canvas stays the default and emergency
// fallback. The central flag can disable 3D without removing this module.
const rendererParams = new URLSearchParams(location.search);
const rendererConfig = window.MAFIOZI_RENDERER_CONFIG || {};
if (rendererParams.get('render') === '3d' && rendererConfig.threeEnabled !== false) {
  (async () => {
    const stage = document.getElementById('stage');
    try {
      const THREE = await import('https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js');
      const viewSize = () => ({ W: Math.max(1, stage.clientWidth || innerWidth), H: Math.max(1, stage.clientHeight || innerHeight) });
      const size = viewSize();
      const scene = new THREE.Scene();
      scene.background = new THREE.Color(0x0c1b2c);
      scene.fog = new THREE.FogExp2(0x10233a, 0.0036);

      const cameraSpan=40;
      const camera = new THREE.OrthographicCamera(-cameraSpan * size.W / size.H, cameraSpan * size.W / size.H, cameraSpan, -cameraSpan, 0.1, 1000);
      // Classic 2:1-ish isometric angle instead of the near top-down test view.
      camera.position.set(54, 62, 54);
      camera.lookAt(0, 0, 0);

      const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
      // Render above CSS resolution even on desktop DPR=1; this removes the
      // soft upscaling visible in the in-app browser and on Telegram tablets.
      const renderPixelRatio=Math.min(2.35,Math.max(2,devicePixelRatio||1));
      renderer.setPixelRatio(renderPixelRatio);
      renderer.setSize(size.W, size.H, false);
      renderer.shadowMap.enabled = true;
      renderer.shadowMap.type = THREE.PCFSoftShadowMap;
      renderer.shadowMap.autoUpdate = false;
      renderer.shadowMap.needsUpdate = true;
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.32;
      renderer.domElement.id = 'threePreview';
      renderer.domElement.style.cursor = 'crosshair';
      renderer.domElement.style.pointerEvents = 'auto';
      renderer.domElement.style.filter = 'saturate(1.09) contrast(1.035)';
      stage.appendChild(renderer.domElement);
      const cinematicGrade=document.createElement('div');cinematicGrade.id='threeCinematicGrade';cinematicGrade.style.cssText='position:absolute;inset:0;z-index:4;pointer-events:none;background:radial-gradient(circle at 50% 45%,transparent 48%,rgba(3,8,15,.08) 72%,rgba(2,5,11,.23) 100%);mix-blend-mode:multiply';stage.appendChild(cinematicGrade);
      const postTarget=new THREE.WebGLRenderTarget(Math.max(1,Math.floor(size.W*renderPixelRatio)),Math.max(1,Math.floor(size.H*renderPixelRatio)),{depthBuffer:true,stencilBuffer:false});postTarget.texture.colorSpace=THREE.SRGBColorSpace;postTarget.samples=renderer.capabilities.isWebGL2?2:0;
      const postScene=new THREE.Scene(),postCamera=new THREE.OrthographicCamera(-1,1,1,-1,0,1),postMaterial=new THREE.ShaderMaterial({depthTest:false,depthWrite:false,uniforms:{tDiffuse:{value:postTarget.texture},uResolution:{value:new THREE.Vector2(postTarget.width,postTarget.height)},uBloom:{value:.18}},vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position,1.0);}',fragmentShader:`uniform sampler2D tDiffuse;uniform vec2 uResolution;uniform float uBloom;varying vec2 vUv;
        float lum(vec3 c){return dot(c,vec3(.2126,.7152,.0722));}
        void main(){vec2 px=1.0/uResolution;vec3 base=texture2D(tDiffuse,vUv).rgb;vec3 glow=vec3(0.0);float weight=0.0;
          for(int x=-2;x<=2;x++)for(int y=-2;y<=2;y++){vec2 o=vec2(float(x),float(y))*px*2.1;vec3 s=texture2D(tDiffuse,vUv+o).rgb;float w=max(0.0,lum(s)-.68)*(1.0/(1.0+float(x*x+y*y)));glow+=s*w;weight+=w;}
          if(weight>0.0001)glow/=weight;vec3 nw=texture2D(tDiffuse,vUv+vec2(-px.x,px.y)).rgb,se=texture2D(tDiffuse,vUv+vec2(px.x,-px.y)).rgb;float edge=clamp(abs(lum(nw)-lum(se))*1.7,0.0,.32);base=mix(base,(base+nw+se)/3.0,edge);
          vec3 color=base+glow*uBloom;float gray=lum(color);color=mix(vec3(gray),color,1.08);float vig=smoothstep(.82,.2,length(vUv-.5));color*=mix(.93,1.035,vig);gl_FragColor=vec4(color,1.0);}`});
      postScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2,2),postMaterial));

      const bridge=window.Mafiozi3DBridge||null;
      const initialState=bridge?.getPlayerState?.()||null;
      const worldSnapshot=bridge?.getWorldSnapshot?.(240)||null;
      const envSnapshot=bridge?.getEnvironmentState?.()||null;
      const originR=initialState?.r||0,originC=initialState?.c||0,WORLD_SCALE=Math.max(3,Math.min(5,+rendererConfig.worldScale||4.1));

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
      const asphaltTexture=surfaceTexture('asphalt','#20262c','rgba(4,7,10,.34)'),concreteTexture=surfaceTexture('concrete','#687176','rgba(235,240,235,.3)'),roofTexture=surfaceTexture('metal','#34424c','rgba(210,225,232,.28)');
      const environmentFaces=Array.from({length:6},(_,face)=>{const cv=document.createElement('canvas');cv.width=cv.height=256;const c=cv.getContext('2d'),g=c.createLinearGradient(0,0,0,256);g.addColorStop(0,face===2?'#d9efff':'#78b9e3');g.addColorStop(.52,'#7fa0b5');g.addColorStop(.54,'#d8b982');g.addColorStop(1,'#26333c');c.fillStyle=g;c.fillRect(0,0,256,256);return cv;});
      const cityEnvironment=new THREE.CubeTexture(environmentFaces);cityEnvironment.colorSpace=THREE.SRGBColorSpace;cityEnvironment.needsUpdate=true;scene.environment=cityEnvironment;scene.environmentIntensity=.72;

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
      const outline = mesh => {
        const edges = new THREE.LineSegments(
          new THREE.EdgesGeometry(mesh.geometry, 24),
          new THREE.LineBasicMaterial({ color: 0x0a111b, transparent: true, opacity: .78 })
        );
        if(mesh.layers.mask===2){edges.layers.set(1);mesh.add(edges);}
        else{edges.position.copy(mesh.position);edges.rotation.copy(mesh.rotation);edges.scale.copy(mesh.scale);scene.add(edges);}
        return edges;
      };
      const detailMat=new THREE.MeshStandardMaterial({color:0x4c5964,roughness:.68,metalness:.18});
      const facadeTexture = (base, seed) => {
        const cv = document.createElement('canvas');
        cv.width = cv.height = 1536;
        const c = cv.getContext('2d');
        c.scale(3, 3);
        const pattern=seed%5;c.fillStyle = base; c.fillRect(0, 0, 512, 512);
        if(pattern===0){c.fillStyle='rgba(76,169,205,.24)';for(let x=12;x<512;x+=52)c.fillRect(x,0,37,512);c.fillStyle='rgba(220,244,255,.12)';for(let x=13;x<512;x+=52)c.fillRect(x,0,3,512);}
        else if(pattern===1){c.fillStyle='rgba(35,15,12,.16)';for(let y=0;y<512;y+=18)c.fillRect(0,y,512,2);for(let y=0;y<512;y+=36)for(let x=(y/36%2)*24;x<512;x+=48)c.fillRect(x,y,2,18);}
        else if(pattern===2){c.fillStyle='rgba(255,232,190,.08)';for(let y=0;y<512;y+=96)c.fillRect(0,y,512,8);c.fillStyle='rgba(20,25,28,.2)';for(let x=0;x<512;x+=128)c.fillRect(x,0,5,512);}
        else if(pattern===3){c.fillStyle='rgba(230,237,225,.12)';for(let y=0;y<512;y+=64)c.fillRect(0,y,512,10);c.fillStyle='rgba(0,0,0,.15)';for(let x=0;x<512;x+=96)c.fillRect(x,0,4,512);}
        else{c.fillStyle='rgba(255,255,255,.055)';for(let y=0;y<512;y+=32)c.fillRect(0,y,512,2);}
        const stepX=pattern===0?52:pattern===3?68:56,stepY=pattern===2?64:48;
        for (let y = 24, iy = 0; y < 488; y += stepY, iy++) for (let x = 20, ix = 0; x < 488; x += stepX, ix++) {
          const lit = ((ix * 17 + iy * 31 + seed * 13) % 7) < 3;
          const ww=pattern===0?34:pattern===3?38:28,hh=pattern===2?28:22;
          c.fillStyle = '#080e17'; c.fillRect(x-3, y-3, ww+6, hh+6);
          c.fillStyle = lit ? '#ffd77d' : pattern===0?'#174963':'#13283b'; c.fillRect(x, y, ww, hh);
          c.fillStyle = lit ? 'rgba(255,250,204,.72)' : 'rgba(115,190,225,.32)'; c.fillRect(x + 4, y + 3, Math.max(7,ww*.28), hh-6);
          c.fillStyle = 'rgba(5,10,18,.72)'; c.fillRect(x+ww*.5-1,y,2,hh);
        }
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

      const groundMaterial=new THREE.MeshStandardMaterial({color:0x202830,map:asphaltTexture,roughness:.88,roughnessMap:asphaltTexture,metalness:.08,bumpMap:asphaltTexture,bumpScale:.055}),worldCols=envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||80,worldRows=envSnapshot?.mapRows||worldSnapshot?.bounds?.maxR||200,worldWidth=worldCols*WORLD_SCALE,worldDepth=worldRows*WORLD_SCALE;
      const ground = new THREE.Mesh(new THREE.PlaneGeometry(worldSnapshot?worldWidth+WORLD_SCALE*4:190,worldSnapshot?worldDepth+WORLD_SCALE*4:190),groundMaterial);
      ground.rotation.x = -Math.PI / 2;ground.position.set(worldSnapshot?(worldCols*.5-originC)*WORLD_SCALE:0,0,worldSnapshot?(worldRows*.5-originR)*WORLD_SCALE:0);ground.receiveShadow = true; scene.add(ground);
      let waterSurface=null;
      if(worldSnapshot?.coast){
        const coast=worldSnapshot.coast,toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE,coastWidth=worldCols*WORLD_SCALE,coastCenter=worldCols*.5;
        const sandMat=new THREE.MeshStandardMaterial({color:0xe1bd7c,roughness:.96}),waterMat=new THREE.MeshStandardMaterial({color:0x087fa5,roughness:.16,metalness:.25,transparent:true,opacity:.92}),woodMat=new THREE.MeshStandardMaterial({color:0x775036,roughness:.8}),shipMat=new THREE.MeshStandardMaterial({color:0x253845,roughness:.5,metalness:.35});
        const beach=new THREE.Mesh(new THREE.PlaneGeometry(coastWidth,(coast.beach.r1-coast.beach.r0)*WORLD_SCALE),sandMat);beach.rotation.x=-Math.PI/2;beach.position.set(toX(coastCenter),.04,toZ((coast.beach.r0+coast.beach.r1)/2));beach.receiveShadow=true;scene.add(beach);
        const water=new THREE.Mesh(new THREE.PlaneGeometry(coastWidth,(coast.water.r1-coast.water.r0)*WORLD_SCALE),waterMat);water.rotation.x=-Math.PI/2;water.position.set(toX(coastCenter),.07,toZ((coast.water.r0+coast.water.r1)/2));scene.add(water);waterSurface=water;
        const pier=box(toX((coast.pier.c0+coast.pier.c1)/2),toZ((coast.pier.r0+coast.pier.r1)/2),(coast.pier.c1-coast.pier.c0)*WORLD_SCALE,(coast.pier.r1-coast.pier.r0)*WORLD_SCALE,.55,woodMat);pier.position.y=.28;
        const ship=box(toX((coast.ship.c0+coast.ship.c1)/2),toZ((coast.ship.r0+coast.ship.r1)/2),(coast.ship.c1-coast.ship.c0)*WORLD_SCALE,(coast.ship.r1-coast.ship.r0)*WORLD_SCALE,3.3,shipMat);outline(ship);
        const deck=box(ship.position.x,ship.position.z-2,38,17,4.5,new THREE.MeshStandardMaterial({color:0xe7e1d1,roughness:.7}));deck.position.y=4.3;outline(deck);
        const palmTrunk=new THREE.MeshStandardMaterial({color:0x754b2e,roughness:.85}),palmLeaf=new THREE.MeshStandardMaterial({color:0x218f5a,roughness:.78});
        const addPalm=(r,c,s=1)=>{const g=new THREE.Group();const trunk=new THREE.Mesh(new THREE.CylinderGeometry(.32*s,.52*s,6.4*s,9),palmTrunk);trunk.position.y=3.2*s;trunk.castShadow=true;g.add(trunk);for(let i=0;i<8;i++){const leaf=new THREE.Mesh(new THREE.ConeGeometry(.55*s,4*s,5),palmLeaf);leaf.position.y=6.5*s;leaf.rotation.z=Math.PI/2.35;leaf.rotation.y=i*Math.PI/4;leaf.position.x=Math.cos(leaf.rotation.y)*1.05*s;leaf.position.z=Math.sin(leaf.rotation.y)*1.05*s;leaf.castShadow=true;g.add(leaf);}g.position.set(toX(c),0,toZ(r));scene.add(g);};
        for(let c=7;c<76;c+=8)addPalm(154+(c%3),c,.82+(c%5)*.035);
        const promenadeMat=new THREE.MeshStandardMaterial({color:0xcaa77b,roughness:.9}),benchMat=new THREE.MeshStandardMaterial({color:0x8a532f,roughness:.78}),metalMat=new THREE.MeshStandardMaterial({color:0x2e3c43,roughness:.48,metalness:.55});
        const promenade=new THREE.Mesh(new THREE.PlaneGeometry(Math.max(24,coastWidth-WORLD_SCALE*4),WORLD_SCALE*4),promenadeMat);promenade.rotation.x=-Math.PI/2;promenade.position.set(toX(coastCenter),.1,toZ(152));promenade.receiveShadow=true;scene.add(promenade);
        for(let c=8;c<74;c+=11){const x=toX(c),z=toZ(153);const seat=box(x,z,4,.72,.3,benchMat);seat.position.y=1.05;for(const dx of [-1.45,1.45]){const leg=box(x+dx,z,.22,.5,1,metalMat);leg.position.y=.5;}const lampPost=new THREE.Mesh(new THREE.CylinderGeometry(.12,.18,5.2,8),metalMat);lampPost.position.set(x+3.4,2.6,z);scene.add(lampPost);const lampBulb=new THREE.Mesh(new THREE.SphereGeometry(.34,10,7),new THREE.MeshBasicMaterial({color:0xffce75}));lampBulb.position.set(x+3.4,5.3,z);scene.add(lampBulb);}
        const umbrellaColors=[0xff5d62,0x36b8d4,0xffc74e,0x64c887];for(let i=0;i<12;i++){const r=158+(i%3)*2.1,c=8+Math.floor(i/3)*19+(i%2)*3,x=toX(c),z=toZ(r),pole=new THREE.Mesh(new THREE.CylinderGeometry(.07,.09,2.5,7),metalMat);pole.position.set(x,1.25,z);scene.add(pole);const shade=new THREE.Mesh(new THREE.ConeGeometry(2.2,.9,14),new THREE.MeshStandardMaterial({color:umbrellaColors[i%4],roughness:.7}));shade.position.set(x,2.65,z);shade.castShadow=true;scene.add(shade);}
        const beachBar=box(toX(68),toZ(156),14,8,4.2,new THREE.MeshStandardMaterial({color:0x3e5960,roughness:.68}));outline(beachBar);const barAwning=box(toX(68),toZ(157.8),12,2,.28,new THREE.MeshBasicMaterial({color:0x20dfbd}));barAwning.position.y=3.2;const barLight=new THREE.PointLight(0x20dfbd,18,24,2);barLight.position.set(toX(68),4,toZ(158));scene.add(barLight);
        for(const [i,d] of (coast.decor||[]).entries()){if(['palm','big_palm','umbrella','tiki_bar','beach_lamp','sand_path','grass','starfish','shell','crab','puddle'].includes(d.kind))continue;const x=toX(d.c),z=toZ(d.r),color=d.col||['#e75d55','#46a9d8','#f3ca54','#62bd75'][i%4],mat=new THREE.MeshStandardMaterial({color,roughness:.72});if(d.kind==='towel'){const towel=new THREE.Mesh(new THREE.PlaneGeometry(2.4,4),mat);towel.rotation.x=-Math.PI/2;towel.rotation.z=d.ang;towel.position.set(x,.13,z);scene.add(towel);}else if(d.kind==='chair'){const chair=box(x,z,1.4,1.6,.3,mat);chair.position.y=.65;chair.rotation.y=d.ang;const back=box(x,z-.65,1.4,.22,1.5,mat);back.position.y=1.05;back.rotation.y=d.ang;}else if(d.kind==='surfboard'){const board=new THREE.Mesh(new THREE.CapsuleGeometry(.42,2.4,6,12),mat);board.scale.set(1,.18,1);board.rotation.z=Math.PI/2+d.ang;board.position.set(x,.28,z);scene.add(board);}else if(d.kind==='ball'){const ball=new THREE.Mesh(new THREE.SphereGeometry(.55,14,10),mat);ball.position.set(x,.58,z);ball.castShadow=true;scene.add(ball);}else if(d.kind==='sandcastle'){const castle=new THREE.Mesh(new THREE.ConeGeometry(1.05,1.6,8),new THREE.MeshStandardMaterial({color:0xc89857,roughness:1}));castle.position.set(x,.8,z);scene.add(castle);}else if(d.kind==='boat'){const hull=box(x,z,5.5,2.2,1.1,mat);hull.position.y=.65;hull.rotation.y=d.ang;}else if(d.kind==='lifeguard'){const platform=box(x,z,3.6,3.2,.4,new THREE.MeshStandardMaterial({color:0xf0e2bd,roughness:.8}));platform.position.y=3.4;for(const dx of [-1.3,1.3])for(const dz of [-1.1,1.1]){const leg=box(x+dx,z+dz,.22,.22,3.4,metalMat);leg.position.y=1.7;}}else if(d.kind==='volleyball'){for(const dx of [-4,4]){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.08,.12,4,8),metalMat);pole.position.set(x+dx,2,z);scene.add(pole);}const net=box(x,z,8,.1,2,new THREE.MeshBasicMaterial({color:0xf3eee1,wireframe:true}));net.position.y=2;}else if(d.kind==='icecream_cart'){const cart=box(x,z,3,1.8,1.4,new THREE.MeshStandardMaterial({color:0xe8d7b2,roughness:.65}));cart.position.y=1;const canopy=box(x,z,3.4,2.2,.25,new THREE.MeshBasicMaterial({color:0xff5f75}));canopy.position.y=2.35;}else if(d.kind==='float_ring'){const ring=new THREE.Mesh(new THREE.TorusGeometry(.75,.22,8,18),mat);ring.rotation.x=Math.PI/2;ring.position.set(x,.18,z);scene.add(ring);}}
        coast.containers.forEach((q,i)=>{const color=coast.containerColors[q.presetIndex]||'#c45b3d';const container=box(toX(q.c),toZ(q.r),q.w*2*WORLD_SCALE,q.h*2*WORLD_SCALE,q.height*WORLD_SCALE,new THREE.MeshStandardMaterial({color,roughness:.58,metalness:.32}));container.position.y=q.height*WORLD_SCALE/2+.4;if(q.stackIndex>=0){const top=container.clone();top.material=new THREE.MeshStandardMaterial({color:coast.containerColors[q.stackIndex]||'#3b79a8',roughness:.58,metalness:.32});top.position.y+=q.height*WORLD_SCALE;scene.add(top);}});
      }
      if(worldSnapshot?.landmarks){
        const toX=c=>(c-originC)*WORLD_SCALE,toZ=r=>(r-originR)*WORLD_SCALE;
        const roofAnchorAt=(r,c,fallback=7)=>{let best=null,bestD=1e9;for(const block of worldSnapshot.blocks||[]){const q=block.building;if(!q)continue;const d=Math.hypot(q.r-r,q.c-c);if(d<bestD){bestD=d;best=q;}}return best&&bestD<14?{x:toX(best.c),y:(+best.height||fallback)+3,z:toZ(best.r),onRoof:true}:{x:toX(c),y:fallback,z:toZ(r),onRoof:false};};
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
        const jail=worldSnapshot.landmarks.jail;
        if(jail){
          const x=toX(jail.c),z=toZ(jail.r),span=jail.radius*2*WORLD_SCALE,concrete=new THREE.MeshStandardMaterial({color:0x9aa2a7,roughness:.86}),darkSteel=new THREE.MeshStandardMaterial({color:0x252d34,roughness:.45,metalness:.65});
          const wallN=box(x,z-span/2,span,1,3.2,concrete),wallS=box(x,z+span/2,span,1,3.2,concrete),wallW=box(x-span/2,z,1,span,3.2,concrete),wallE=box(x+span/2,z,1,span,3.2,concrete);[wallN,wallS,wallW,wallE].forEach(outline);
          for(const [sx,sz] of [[-1,-1],[1,-1],[-1,1],[1,1]]){const tower=box(x+sx*span/2,z+sz*span/2,3.5,3.5,6.8,darkSteel);outline(tower);const lamp=new THREE.PointLight(0xc8e7ff,10,22,2);lamp.position.set(tower.position.x,7.2,tower.position.z);scene.add(lamp);}
          const jailBlock=box(x,z,span*.48,span*.38,8.5,new THREE.MeshStandardMaterial({color:0x59646d,roughness:.72}));outline(jailBlock);
        }
        const lair=worldSnapshot.landmarks.lair;
        if(lair){
          const x=toX(lair.c),z=toZ(lair.r),rad=Math.min(55,lair.radius*WORLD_SCALE),dirt=new THREE.MeshStandardMaterial({color:0x543b2d,roughness:1});
          const yard=new THREE.Mesh(new THREE.CircleGeometry(rad,48),dirt);yard.rotation.x=-Math.PI/2;yard.position.set(x,.09,z);yard.receiveShadow=true;scene.add(yard);
          const tentMats=[0x6e3d31,0x4a573b,0x725c36].map(color=>new THREE.MeshStandardMaterial({color,roughness:.9}));
          for(let i=0;i<8;i++){const a=i/8*Math.PI*2,tx=x+Math.cos(a)*rad*.64,tz=z+Math.sin(a)*rad*.64;const tent=new THREE.Mesh(new THREE.ConeGeometry(4.2,5.2,4),tentMats[i%3]);tent.position.set(tx,2.6,tz);tent.rotation.y=Math.PI/4-a;tent.castShadow=true;scene.add(tent);}
          const fire=new THREE.PointLight(0xff6b2c,28,28,2);fire.position.set(x,2,z);scene.add(fire);const flame=new THREE.Mesh(new THREE.ConeGeometry(.9,2.3,8),new THREE.MeshBasicMaterial({color:0xffb02e}));flame.position.set(x,1.2,z);scene.add(flame);
        }
        for(const b of worldSnapshot.landmarks.businesses||[]){const x=toX(b.c),z=toZ(b.r),ring=new THREE.Mesh(new THREE.RingGeometry(2.1,2.55,32),new THREE.MeshBasicMaterial({color:0x42e8a1,transparent:true,opacity:.78,side:THREE.DoubleSide}));ring.rotation.x=-Math.PI/2;ring.position.set(x,.16,z);scene.add(ring);const roof=roofAnchorAt(b.r,b.c),label=labelSprite(`${b.emoji||'◆'} ${b.name}`,'#42e8a1');label.position.set(roof.x,roof.y,roof.z);scene.add(label);}
        for(const hq of worldSnapshot.landmarks.districtHqs||[]){const x=toX(hq.c),z=toZ(hq.r),color=new THREE.Color(hq.color||'#e0b94a'),ring=new THREE.Mesh(new THREE.RingGeometry(5.4,5.85,48),new THREE.MeshBasicMaterial({color,transparent:true,opacity:.72,side:THREE.DoubleSide}));ring.rotation.x=-Math.PI/2;ring.position.set(x,.18,z);scene.add(ring);const beacon=new THREE.PointLight(color,15,22,2);beacon.position.set(x,3,z);scene.add(beacon);const roof=roofAnchorAt(hq.r,hq.c,9),label=labelSprite(`ШТАБ · ${hq.name}`,hq.color||'#e0b94a');label.position.set(roof.x,roof.y,roof.z);scene.add(label);}
        const bankStone=new THREE.MeshStandardMaterial({color:0xb7aa8c,roughness:.72}),bankGold=new THREE.MeshStandardMaterial({color:0xd5ad45,roughness:.3,metalness:.72});
        for(const bank of worldSnapshot.landmarks.banks||[]){const x=toX(bank.c+1.5),z=toZ(bank.r+1.5),scale={small:.8,medium:1,large:1.25}[bank.size]||1;for(let i=-2;i<=2;i++){const col=new THREE.Mesh(new THREE.CylinderGeometry(.28*scale,.36*scale,4.4*scale,12),bankStone);col.position.set(x+i*1.3*scale,2.2*scale,z+3.4*scale);col.castShadow=true;scene.add(col);}const seal=new THREE.Mesh(new THREE.CylinderGeometry(1.35*scale,1.35*scale,.25,24),bankGold);seal.rotation.x=Math.PI/2;seal.position.set(x,5.4*scale,z+3.65*scale);scene.add(seal);const label=labelSprite(`🏦 ${bank.name}`,'#d5ad45');label.position.set(x,7*scale,z+3.8*scale);scene.add(label);}
        const gasRed=new THREE.MeshStandardMaterial({color:0xd74137,roughness:.48}),gasWhite=new THREE.MeshStandardMaterial({color:0xe9e5d9,roughness:.65}),gasDark=new THREE.MeshStandardMaterial({color:0x272d33,metalness:.42,roughness:.45});
        for(const gas of worldSnapshot.landmarks.gasStations||[]){const x=toX(gas.c+.7),z=toZ(gas.r+.7),canopy=box(x,z,10,7,.65,gasRed);canopy.position.y=5;for(const [dx,dz] of [[-4,-2.5],[4,-2.5],[-4,2.5],[4,2.5]]){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.18,.22,5,8),gasWhite);pole.position.set(x+dx,2.5,z+dz);scene.add(pole);}for(const dx of [-2,2]){const pump=box(x+dx,z,1.15,1.1,2.3,gasDark);pump.position.y=1.15;const screen=box(x+dx,z+.58,.55,.08,.48,new THREE.MeshBasicMaterial({color:0x63d8ff}));screen.position.y=1.55;}const label=labelSprite('⛽ АЗС','#ff554b');label.position.set(x,6.8,z);scene.add(label);}
        const specialColors={hospital:'#e64b55',firestation:'#f05a45',casino:'#d957ff',factory:'#e58b3c',market:'#47d79b',arena:'#ffcf4d',blackmarket:'#7d6cff',blackmarket_bellini:'#22242a',blackmarket_moretti:'#eee8da',gym:'#66b8ff',job_office:'#e7c75d'};
        for(const poi of worldSnapshot.pois||[]){const accent=specialColors[poi.id];if(!accent)continue;const x=toX(poi.c),z=toZ(poi.r),mat=new THREE.MeshBasicMaterial({color:accent}),steel=new THREE.MeshStandardMaterial({color:0x46515a,metalness:.55,roughness:.42});if(poi.id==='hospital'){const a=box(x,z,1.2,.35,5.2,mat);a.position.y=8;const b=box(x,z,4.2,.35,1.2,mat);b.position.y=8;}else if(poi.id==='factory'){for(let i=-1;i<=1;i++){const chimney=new THREE.Mesh(new THREE.CylinderGeometry(.55,.75,8+i*2,12),new THREE.MeshStandardMaterial({color:i%2?0xb64a3e:0x515b60,roughness:.8}));chimney.position.set(x+i*2.2,7+i,z);scene.add(chimney);}}else if(poi.id==='casino'){const crown=new THREE.Mesh(new THREE.TorusGeometry(3.3,.28,10,32),mat);crown.rotation.x=Math.PI/2;crown.position.set(x,11,z);scene.add(crown);const glow=new THREE.PointLight(accent,22,24,2);glow.position.set(x,9,z);scene.add(glow);}else if(poi.id==='firestation'){for(const dx of [-2.4,0,2.4]){const door=box(x+dx,z+4.1,2.05,.16,3.1,new THREE.MeshStandardMaterial({color:0x8e2525,roughness:.65}));door.position.y=1.55;}const mast=new THREE.Mesh(new THREE.CylinderGeometry(.1,.14,8,8),steel);mast.position.set(x-4,4,z+3);scene.add(mast);}else if(poi.id==='arena'){const ring=new THREE.Mesh(new THREE.TorusGeometry(5,.32,8,40),mat);ring.rotation.x=-Math.PI/2;ring.position.set(x,.3,z);scene.add(ring);for(let i=0;i<6;i++){const a=i/6*Math.PI*2,pole=new THREE.Mesh(new THREE.CylinderGeometry(.12,.16,4.5,8),steel);pole.position.set(x+Math.cos(a)*5,2.25,z+Math.sin(a)*5);scene.add(pole);}}else if(poi.id==='gym'){for(const dx of [-2.4,2.4]){const bar=new THREE.Mesh(new THREE.CylinderGeometry(.18,.18,4.2,10),steel);bar.rotation.z=Math.PI/2;bar.position.set(x+dx,6,z);scene.add(bar);for(const sx of [-1.7,1.7]){const weight=new THREE.Mesh(new THREE.CylinderGeometry(.65,.65,.35,14),mat);weight.rotation.z=Math.PI/2;weight.position.set(x+dx+sx,6,z);scene.add(weight);}}}else if(poi.id.startsWith('blackmarket')){const portal=new THREE.Mesh(new THREE.TorusGeometry(2.6,.32,10,32),mat);portal.position.set(x,4.5,z+3.6);scene.add(portal);const glow=new THREE.PointLight(accent,16,18,2);glow.position.set(x,4,z+3);scene.add(glow);}else if(poi.id==='market'){for(let i=-2;i<=2;i++){const awning=box(x+i*2.1,z+4,1.8,2.1,.18,new THREE.MeshStandardMaterial({color:i%2?0xf3d560:0x48b887,roughness:.6}));awning.position.y=3.4;}}else if(poi.id==='job_office'){const clockFace=new THREE.Mesh(new THREE.CylinderGeometry(1.45,1.45,.22,24),new THREE.MeshBasicMaterial({color:0xffe59a}));clockFace.rotation.x=Math.PI/2;clockFace.position.set(x,8,z+3.7);scene.add(clockFace);}const roof=roofAnchorAt(poi.r,poi.c,9),label=labelSprite(`${poi.id==='firestation'?'🚒':poi.id==='arena'?'🎯':'◆'} ${poi.label}`,accent);label.position.set(roof.x,roof.y,roof.z);scene.add(label);}
        const track=worldSnapshot.landmarks.raceTrack||[],trackMat=new THREE.MeshStandardMaterial({color:0x20252a,roughness:.48,metalness:.18});
        for(let i=0;i<track.length;i++){const a=track[i],b=track[(i+1)%track.length],ax=toX(a.c),az=toZ(a.r),bx=toX(b.c),bz=toZ(b.r),dx=bx-ax,dz=bz-az,len=Math.hypot(dx,dz);const seg=new THREE.Mesh(new THREE.PlaneGeometry(13,len),trackMat);seg.rotation.x=-Math.PI/2;seg.rotation.z=-Math.atan2(dz,dx)+Math.PI/2;seg.position.set((ax+bx)/2,.13,(az+bz)/2);seg.receiveShadow=true;scene.add(seg);}
      }
      const roadMat = new THREE.MeshStandardMaterial({color:0x252a2f,map:asphaltTexture,roughness:.84,roughnessMap:asphaltTexture,metalness:.06,bumpMap:asphaltTexture,bumpScale:.07});
      const curbMat = new THREE.MeshStandardMaterial({color:0x7a8285,map:concreteTexture,roughness:.94,bumpMap:concreteTexture,bumpScale:.035});
      const lineMat = new THREE.MeshBasicMaterial({ color: 0xd4ae3f });
      if(worldSnapshot){
        const cityPaving=new THREE.MeshStandardMaterial({color:0x626d72,map:concreteTexture,roughness:.96,bumpMap:concreteTexture,bumpScale:.025}),parkPaving=new THREE.MeshStandardMaterial({color:0x276545,roughness:1}),sandPaving=new THREE.MeshStandardMaterial({color:0xd0aa6a,roughness:1}),waterPaving=new THREE.MeshPhysicalMaterial({color:0x087b9d,roughness:.1,metalness:.15,transmission:.08,clearcoat:1,clearcoatRoughness:.08,transparent:true,opacity:.91,envMap:cityEnvironment,envMapIntensity:1.2});
        const pavingBuckets=new Map([[cityPaving,[]],[parkPaving,[]],[sandPaving,[]],[waterPaving,[]]]);
        for(const b of worldSnapshot.blocks){
          const x=(b.c0+6.5-originC)*WORLD_SCALE,z=(b.r0+6.5-originR)*WORLD_SCALE;
          const material=b.water>20?waterPaving:b.sand>20?sandPaving:b.grass>20?parkPaving:cityPaving;
          pavingBuckets.get(material).push([x,z]);
        }
        const padGeo=new THREE.PlaneGeometry(WORLD_SCALE*6,WORLD_SCALE*6),matrix=new THREE.Matrix4(),rotation=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0)),scale=new THREE.Vector3(1,1,1);
        for(const [material,items] of pavingBuckets){if(!items.length)continue;const pads=new THREE.InstancedMesh(padGeo,material,items.length);items.forEach(([x,z],i)=>{matrix.compose(new THREE.Vector3(x,.018,z),rotation,scale);pads.setMatrixAt(i,matrix);});pads.receiveShadow=true;pads.instanceMatrix.needsUpdate=true;scene.add(pads);}
      }
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

      // Cheap street storytelling: manholes, oil stains, patched asphalt and
      // paper litter are all instanced, so the city gains detail for four
      // extra draw calls instead of hundreds of individual meshes.
      const manholeDefs=[],stainDefs=[],patchDefs=[],litterDefs=[];
      roadAxes.forEach((road,ri)=>{const len=road.length||190,center=road.center||0;for(let i=0;i<7;i++){const q=center-len*.43+i*len*.143,vertical=road.axis==='v'||(road.axis==='both'&&ri%2===0),x=vertical?road.p:q,z=vertical?q:road.p,target=(ri+i)%3===0?manholeDefs:(ri+i)%3===1?stainDefs:patchDefs;target.push([x+(vertical?((i&1)?2.3:-2.2):0),z+(!vertical?((i&1)?2.3:-2.2):0),(ri*.71+i*.93)%Math.PI]);if((ri+i)%2===0)litterDefs.push([x+(vertical?3.8:-3.8),z+(!vertical?3.6:-3.6),(ri+i)*.54]);}});
      const roadMatrix=new THREE.Matrix4(),roadScale=new THREE.Vector3(1,1,1),roadQuat=new THREE.Quaternion();
      const addRoadInstances=(geometry,material,defs,y,flat=true)=>{const mesh=new THREE.InstancedMesh(geometry,material,defs.length);defs.forEach(([x,z,a],i)=>{roadQuat.setFromEuler(new THREE.Euler(flat?-Math.PI/2:0,0,a||0));roadMatrix.compose(new THREE.Vector3(x,y,z),roadQuat,roadScale);mesh.setMatrixAt(i,roadMatrix);});mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;scene.add(mesh);return mesh;};
      addRoadInstances(new THREE.CylinderGeometry(.72,.72,.085,18),new THREE.MeshStandardMaterial({color:0x343c41,metalness:.78,roughness:.38}),manholeDefs,.075,false);
      addRoadInstances(new THREE.CircleGeometry(1.3,18),new THREE.MeshBasicMaterial({color:0x090d10,transparent:true,opacity:.38,depthWrite:false}),stainDefs,.069);
      addRoadInstances(new THREE.PlaneGeometry(2.8,1.45),new THREE.MeshBasicMaterial({color:0x394047,transparent:true,opacity:.74,depthWrite:false}),patchDefs,.068);
      addRoadInstances(new THREE.PlaneGeometry(.48,.25),new THREE.MeshBasicMaterial({color:0xd7d0bd,side:THREE.DoubleSide}),litterDefs,.082);

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
      const leafCount=48,leafPositions=new Float32Array(leafCount*3),leafColors=new Float32Array(leafCount*3),leafState=[];
      for(let i=0;i<leafCount;i++){const tree=atmosphereTreeDefs[i%atmosphereTreeDefs.length],phase=i*.91,radius=1.4+(i%7)*.35;leafState.push({tree,phase,radius});leafColors.set(i%3===0?[.95,.58,.18]:i%3===1?[.38,.75,.25]:[.77,.72,.2],i*3);}
      const leafGeometry=new THREE.BufferGeometry();leafGeometry.setAttribute('position',new THREE.BufferAttribute(leafPositions,3));leafGeometry.setAttribute('color',new THREE.BufferAttribute(leafColors,3));const leafPoints=new THREE.Points(leafGeometry,new THREE.PointsMaterial({map:particleTexture('rgba(255,255,255,.92)','rgba(255,255,255,.22)'),vertexColors:true,size:.42,sizeAttenuation:true,transparent:true,opacity:.78,depthWrite:false}));leafPoints.renderOrder=19;scene.add(leafPoints);
      let lastAtmosphereUpdate=0;
      const updateAtmosphere=(t,slow)=>{if(t-lastAtmosphereUpdate<(slow?70:34))return;lastAtmosphereUpdate=t;const time=t*.001;
        smokeState.forEach((p,i)=>{const rise=(time*.72+p.phase)%10,spread=.2+rise*.16;smokePositions[i*3]=p.source.x+Math.sin(time*.52+p.phase)*spread+p.side;smokePositions[i*3+1]=p.source.y+rise;smokePositions[i*3+2]=p.source.z+Math.cos(time*.39+p.phase*1.3)*spread;});smokeGeometry.attributes.position.needsUpdate=true;
        steamState.forEach((p,i)=>{const rise=(time*.9+p.phase)%3.4;steamPositions[i*3]=p.source[0]+Math.sin(time+p.phase)*rise*.18;steamPositions[i*3+1]=.2+rise;steamPositions[i*3+2]=p.source[1]+Math.cos(time*.8+p.phase)*rise*.13;});steamGeometry.attributes.position.needsUpdate=true;
        leafState.forEach((p,i)=>{const fall=(time*.42+p.phase)%5.5,a=time*.55+p.phase;leafPositions[i*3]=p.tree[0]+Math.sin(a)*p.radius+Math.sin(time*.17)*2.2;leafPositions[i*3+1]=5.8-fall;leafPositions[i*3+2]=p.tree[1]+Math.cos(a*.73)*p.radius;});leafGeometry.attributes.position.needsUpdate=true;
      };

      // Authoritative traffic signals: the same intersections and the same
      // 16-second phase used by Canvas carCanGo(). Instancing keeps the full
      // city visible for a handful of draw calls.
      const trafficSignalDefs=[];
      if(worldSnapshot){const maxR=Math.min(envSnapshot?.beachRow||140,envSnapshot?.mapRows||140),maxC=envSnapshot?.mapCols||80,block=envSnapshot?.blockSize||10;for(let r=2;r<maxR;r+=block)for(let c=2;c<maxC;c+=block)trafficSignalDefs.push([(c+.5-originC)*WORLD_SCALE,(r+.5-originR)*WORLD_SCALE]);}
      const trafficPoleMat=new THREE.MeshStandardMaterial({color:0x19222a,metalness:.72,roughness:.34}),trafficCaseMat=new THREE.MeshStandardMaterial({color:0x0c1117,metalness:.48,roughness:.4}),trafficEwBulbMat=new THREE.MeshBasicMaterial({color:0x42f57b,depthTest:false,depthWrite:false,toneMapped:false}),trafficNsBulbMat=new THREE.MeshBasicMaterial({color:0xff3b3b,depthTest:false,depthWrite:false,toneMapped:false});
      const trafficMatrix=new THREE.Matrix4(),trafficQuat=new THREE.Quaternion(),trafficFaceQuat=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),Math.PI/4),trafficScale=new THREE.Vector3(1,1,1),trafficPole=new THREE.InstancedMesh(new THREE.CylinderGeometry(.16,.22,5.8,6),trafficPoleMat,trafficSignalDefs.length),trafficCase=new THREE.InstancedMesh(new THREE.BoxGeometry(1.22,2.45,.68),trafficCaseMat,trafficSignalDefs.length),trafficBulbGeometry=new THREE.BoxGeometry(1.05,.7,.34),trafficEwBulbs=new THREE.InstancedMesh(trafficBulbGeometry,trafficEwBulbMat,trafficSignalDefs.length),trafficNsBulbs=new THREE.InstancedMesh(trafficBulbGeometry,trafficNsBulbMat,trafficSignalDefs.length);
      trafficSignalDefs.forEach(([x,z],i)=>{trafficMatrix.compose(new THREE.Vector3(x,2.9,z),trafficQuat,trafficScale);trafficPole.setMatrixAt(i,trafficMatrix);trafficMatrix.compose(new THREE.Vector3(x,6.2,z),trafficQuat,trafficScale);trafficCase.setMatrixAt(i,trafficMatrix);trafficMatrix.compose(new THREE.Vector3(x+.76,6.65,z+.76),trafficFaceQuat,trafficScale);trafficEwBulbs.setMatrixAt(i,trafficMatrix);trafficMatrix.compose(new THREE.Vector3(x+.76,5.75,z+.76),trafficFaceQuat,trafficScale);trafficNsBulbs.setMatrixAt(i,trafficMatrix);});
      for(const mesh of [trafficPole,trafficCase,trafficEwBulbs,trafficNsBulbs]){mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;scene.add(mesh);}trafficEwBulbs.renderOrder=trafficNsBulbs.renderOrder=24;trafficPole.castShadow=true;trafficCase.castShadow=true;
      let trafficSignalPhase='';const setTrafficSignals=phase=>{const ew=phase?.ew||'g',ns=phase?.ns||'r',sig=`${ew}:${ns}`;if(sig===trafficSignalPhase)return;trafficSignalPhase=sig;const colorOf=v=>v==='g'?0x42f57b:v==='y'?0xffce3a:0xff3b3b;trafficEwBulbMat.color.setHex(colorOf(ew));trafficNsBulbMat.color.setHex(colorOf(ns));renderer.domElement.dataset.trafficPhase=sig;};setTrafficSignals(envSnapshot?.traffic);

      const facadeBases=['#31516c','#80483b','#3c7059','#796943','#554d75'],facades=[];
      facadeBases.forEach((base,style)=>{for(let variant=0;variant<3;variant++)facades.push(facadeTexture(base,style*3+variant));});
      const roofMat = new THREE.MeshStandardMaterial({color:0x41515d,map:roofTexture,roughness:.48,roughnessMap:roofTexture,metalness:.62,envMap:cityEnvironment,envMapIntensity:.72});
      const neonMats = [0xff496f, 0x46d9ff, 0xffc247].map(color => new THREE.MeshBasicMaterial({ color }));
      const fallbackBuildingDefs = [
        [-24,-23,14,13,15,1,'BAR'],[-8,-24,11,13,11,3,'DELI'],[11,-23,14,14,18,0,'HOTEL'],[27,-23,11,13,13,2,'CAFE'],
        [-25,23,13,14,13,4,'CLUB'],[-9,23,12,13,17,0,'BANK'],[10,23,14,14,14,2,'MARKET'],[27,23,11,13,18,1,''],
      ];
      const styleIndexes={poor:1,downtown:0,nightlife:4,rich:3,countryside:2,industrial:1,coast:2};
      const buildingDefs=worldSnapshot ? worldSnapshot.blocks.filter(b=>b.building).map(b=>{
        const q=b.building,nearPoi=worldSnapshot.pois.find(p=>Math.abs(p.r-q.r)<5&&Math.abs(p.c-q.c)<5);
        return [(q.c-originC)*WORLD_SCALE,(q.r-originR)*WORLD_SCALE,q.w*WORLD_SCALE,q.d*WORLD_SCALE,q.height,styleIndexes[b.styleId]??0,(nearPoi?.label||'').toString().slice(0,10).toUpperCase(),b.styleId||'downtown',{r:q.r,c:q.c,w:q.w,d:q.d,minR:q.minR,maxR:q.maxR,minC:q.minC,maxC:q.maxC,tiles:q.tiles,primary:true}];
      }) : fallbackBuildingDefs;
      const occluders=[],buildingPickables=[],facadeMaterials=[],shopMaterials=[],buildingCurbDefs=[];
      const glassMat=new THREE.MeshPhysicalMaterial({color:0x5fbfe0,emissive:0x10394b,emissiveIntensity:.25,metalness:.08,roughness:.08,transmission:.14,thickness:.28,clearcoat:1,clearcoatRoughness:.06,envMap:cityEnvironment,envMapIntensity:1.45});
      const districtProps=new THREE.Group();scene.add(districtProps);
      const propBox=(x,z,w,d,h,mat,y=h/2)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;districtProps.add(m);return m;};
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
        }
      };
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
      for (let bi=0;bi<buildingDefs.length;bi++) {
        const [x,z,w,d,h,style,sign,districtStyle='downtown',sourceMeta]=buildingDefs[bi],buildingMeta=sourceMeta||{r:originR+z/WORLD_SCALE,c:originC+x/WORLD_SCALE,w:w/WORLD_SCALE,d:d/WORLD_SCALE};
        buildingCurbDefs.push([x,z,w+2,d+2]);
        const facade=facades[style*3+(bi%3)].clone();facade.repeat.set(Math.max(1,w/24),Math.max(1.35,h/16));facade.needsUpdate=true;
        const wall = new THREE.MeshStandardMaterial({ map:facade, roughness:.68, metalness:.05, emissive:0xffb24c, emissiveMap:facade, emissiveIntensity:.075 });
        facadeMaterials.push(wall);
        const localRoof=roofMat.clone();
        const detailed=buildingMeta.primary!==false,steppedTower=detailed&&(districtStyle==='downtown'||districtStyle==='rich')&&h>24,lowerH=steppedTower?h*.64:h;
        const mainBuilding=buildingBox(x,z,w,d,lowerH,wall,localRoof);mainBuilding.userData.fadeMaterials=[wall,localRoof];mainBuilding.userData.building=buildingMeta;mainBuilding.userData.mainBuilding=true;occluders.push(mainBuilding);buildingPickables.push(mainBuilding);if(detailed)outline(mainBuilding);
        if(detailed){if(steppedTower){const upperH=h-lowerH,upper=buildingBox(x,z,w*.72,d*.72,upperH,wall,localRoof);upper.position.y=lowerH+upperH/2;upper.userData.fadeMaterials=[wall,localRoof];upper.userData.building=buildingMeta;occluders.push(upper);buildingPickables.push(upper);outline(upper);const crownBand=box(x,z,w*.78,d*.78,.42,neonMats[bi%3]);crownBand.position.y=lowerH+.2;}
        // A second mass breaks the repetitive box silhouette.
        if(districtStyle==='downtown'){
          wall.metalness=.22;wall.roughness=.48;
          if(h>24){const crown=box(x,z,w*.58,d*.58,4.2,glassMat);crown.position.y=h+2.1;outline(crown);const mast=new THREE.Mesh(new THREE.CylinderGeometry(.12,.2,5.5,8),detailMat);mast.position.set(x,h+6.8,z);scene.add(mast);}
        }
        if(districtStyle==='nightlife'){
          for(let y=4;y<h;y+=4){const band=box(x,z+d/2+.04,w*.9,.12,.12,neonMats[(bi+y)%3]);band.position.y=y;}
        }
        if(districtStyle==='industrial'){
          for(let sx=-w*.25;sx<=w*.25;sx+=Math.max(2,w*.25)){const vent=new THREE.Mesh(new THREE.CylinderGeometry(.32,.45,2.5,8),detailMat);vent.position.set(x+sx,h+1.25,z);scene.add(vent);}
        }
        if(districtStyle==='rich'){
          const terrace=box(x,z,w*.72,d*.72,2.4,wall);terrace.position.y=h+1.2;outline(terrace);
        }
        addDistrictCharacter(x,z,w,d,h,districtStyle,bi);
        if(sign==='HOTEL'){const tower=box(x-2,z-1,w*.52,d*.58,5.5,wall);tower.position.y=h+2.75;outline(tower);}
        if(sign==='BANK'){const crown=box(x,z,w*.68,d*.7,3.3,wall);crown.position.y=h+1.65;outline(crown);}
        box(x,z,w+.65,d+.65,.48,detailMat).position.y=h-.24;addRoofDetails(x,z,w,d,h,bi%4);
        const shopGlow=new THREE.MeshBasicMaterial({color:sign==='CLUB'?0xff397d:sign==='CAFE'?0xffa13b:0xffd38a});shopMaterials.push(shopGlow);
        const shop=new THREE.Mesh(new THREE.PlaneGeometry(Math.min(w-2,8),2.8),shopGlow);
        shop.position.set(x,2.25,z+d/2+.012); scene.add(shop);
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
      }
      const buildingContactShadows=new THREE.InstancedMesh(new THREE.PlaneGeometry(1,1),contactShadowMaterial,buildingDefs.length),buildingShadowMatrix=new THREE.Matrix4(),buildingShadowQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0));
      buildingDefs.forEach(([x,z,w,d],i)=>{buildingShadowMatrix.compose(new THREE.Vector3(x,.058,z),buildingShadowQuat,new THREE.Vector3(w*1.08,d*1.08,1));buildingContactShadows.setMatrixAt(i,buildingShadowMatrix);});
      buildingContactShadows.instanceMatrix.needsUpdate=true;buildingContactShadows.frustumCulled=false;buildingContactShadows.renderOrder=3;scene.add(buildingContactShadows);
      if(buildingCurbDefs.length){const curbInstances=new THREE.InstancedMesh(new THREE.BoxGeometry(1,.65,1),curbMat,buildingCurbDefs.length),curbMatrix=new THREE.Matrix4();buildingCurbDefs.forEach(([x,z,w,d],i)=>{curbMatrix.compose(new THREE.Vector3(x,.325,z),new THREE.Quaternion(),new THREE.Vector3(w,1,d));curbInstances.setMatrixAt(i,curbMatrix);});curbInstances.instanceMatrix.needsUpdate=true;curbInstances.receiveShadow=true;curbInstances.frustumCulled=false;scene.add(curbInstances);}
      // Small park makes the quarter readable instead of a wall of towers.
      box(-24,0,15,13,.45,new THREE.MeshStandardMaterial({color:0x294834,roughness:1}));
      const trunkMat=new THREE.MeshStandardMaterial({color:0x5b3826}),leafMat=new THREE.MeshStandardMaterial({color:0x39744b,roughness:.9});
      for(const [x,z] of [[-28,-3],[-21,3],[-26,4]]){const tr=new THREE.Mesh(new THREE.CylinderGeometry(.25,.35,3,8),trunkMat);tr.position.set(x,1.5,z);scene.add(tr);const crown=new THREE.Mesh(new THREE.IcosahedronGeometry(2.1,1),leafMat);crown.position.set(x,4,z);crown.castShadow=true;scene.add(crown);}
      // Zebra crossings at the central intersection.
      const zebraMat=new THREE.MeshBasicMaterial({color:0xe8edf0});
      for(let i=-4;i<=4;i+=2){const a=new THREE.Mesh(new THREE.PlaneGeometry(1.1,4.6),zebraMat);a.rotation.x=-Math.PI/2;a.position.set(i,.055,-6.7);scene.add(a);const b=new THREE.Mesh(new THREE.PlaneGeometry(4.6,1.1),zebraMat);b.rotation.x=-Math.PI/2;b.position.set(6.7,.056,i);scene.add(b);}

      const lampMat = new THREE.MeshStandardMaterial({ color: 0x202631, metalness: .72, roughness: .34 });
      const bulbMat = new THREE.MeshBasicMaterial({ color: 0xffd486 });
      const streetLights=[];
      const fixedLampDefs=[];for(let r=6;r<(envSnapshot?.mapRows||worldSnapshot?.bounds?.maxR||80)-2;r+=10)for(let c=3;c<(envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||200)-2;c+=10){fixedLampDefs.push([(c-originC)*WORLD_SCALE,(r-originR)*WORLD_SCALE]);if(c+14<(envSnapshot?.mapCols||worldSnapshot?.bounds?.maxC||200)-2)fixedLampDefs.push([((c+14)-originC)*WORLD_SCALE,(r-originR)*WORLD_SCALE]);}
      const fixedPostMatrices=new THREE.InstancedMesh(new THREE.CylinderGeometry(.18,.24,7,8),lampMat,fixedLampDefs.length),fixedBulbMatrices=new THREE.InstancedMesh(new THREE.SphereGeometry(.48,12,8),bulbMat,fixedLampDefs.length),fixedLampMatrix=new THREE.Matrix4();fixedLampDefs.forEach(([x,z],i)=>{fixedLampMatrix.makeTranslation(x,3.5,z);fixedPostMatrices.setMatrixAt(i,fixedLampMatrix);fixedLampMatrix.makeTranslation(x,7,z);fixedBulbMatrices.setMatrixAt(i,fixedLampMatrix);});fixedPostMatrices.instanceMatrix.needsUpdate=fixedBulbMatrices.instanceMatrix.needsUpdate=true;fixedPostMatrices.castShadow=true;fixedPostMatrices.receiveShadow=true;fixedPostMatrices.frustumCulled=fixedBulbMatrices.frustumCulled=false;scene.add(fixedPostMatrices,fixedBulbMatrices);
      const lampGlowCanvas=document.createElement('canvas');lampGlowCanvas.width=lampGlowCanvas.height=256;const lampGlowContext=lampGlowCanvas.getContext('2d'),lampGlowGradient=lampGlowContext.createRadialGradient(128,128,3,128,128,126);lampGlowGradient.addColorStop(0,'rgba(255,225,150,.72)');lampGlowGradient.addColorStop(.24,'rgba(255,194,92,.34)');lampGlowGradient.addColorStop(.62,'rgba(255,151,55,.1)');lampGlowGradient.addColorStop(1,'rgba(255,130,35,0)');lampGlowContext.fillStyle=lampGlowGradient;lampGlowContext.fillRect(0,0,256,256);const lampGlowTexture=new THREE.CanvasTexture(lampGlowCanvas);lampGlowTexture.colorSpace=THREE.SRGBColorSpace;lampGlowTexture.minFilter=THREE.LinearFilter;lampGlowTexture.magFilter=THREE.LinearFilter;lampGlowTexture.generateMipmaps=false;const lampGlowMat=new THREE.MeshBasicMaterial({map:lampGlowTexture,color:0xffd08a,transparent:true,opacity:.02,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),fixedLampGlows=new THREE.InstancedMesh(new THREE.PlaneGeometry(13,13),lampGlowMat,fixedLampDefs.length),lampGlowQuat=new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI/2,0,0)),lampGlowScale=new THREE.Vector3(1,1,1);fixedLampDefs.forEach(([x,z],i)=>{fixedLampMatrix.compose(new THREE.Vector3(x,.075,z),lampGlowQuat,lampGlowScale);fixedLampGlows.setMatrixAt(i,fixedLampMatrix);});fixedLampGlows.instanceMatrix.needsUpdate=true;fixedLampGlows.frustumCulled=false;fixedLampGlows.renderOrder=2;scene.add(fixedLampGlows);
      const lampSpots=[[-14,-7],[14,-7],[-14,7],[14,7],[-34,-7],[34,-7],[-34,7],[34,7]];
      lampSpots.forEach(([x,z],i) => {
        const light = new THREE.PointLight(0xffb45e, 0, 25, 2); light.position.set(x, 6.7, z); light.castShadow = false; scene.add(light);streetLights.push({light});
      });

      const player = new THREE.Group();
      const playerContactShadow=makeContactShadow(3.6,2.7);player.add(playerContactShadow);
      const suitMat=new THREE.MeshStandardMaterial({color:0x731f24,roughness:.58}),skinMat=new THREE.MeshStandardMaterial({color:0xd39b78,roughness:.7}),darkMat=new THREE.MeshStandardMaterial({color:0x151922,roughness:.48,metalness:.25});
      const body = new THREE.Mesh(new THREE.BoxGeometry(1.65,2.35,1.05),suitMat); body.position.y=2.65;body.castShadow=true;player.add(body);
      const head = new THREE.Mesh(new THREE.SphereGeometry(.68,20,16),skinMat);head.position.y=4.35;head.castShadow=true;player.add(head);
      const eyeWhiteMat=new THREE.MeshBasicMaterial({color:0xf8fbff}),irisMat=new THREE.MeshBasicMaterial({color:0x23384b}),hairMat=new THREE.MeshStandardMaterial({color:0x251a17,roughness:.82});
      for(const sx of [-.25,.25]){const eye=new THREE.Mesh(new THREE.SphereGeometry(.13,12,8),eyeWhiteMat);eye.scale.set(1,.78,.42);eye.position.set(sx,4.46,.625);player.add(eye);const pupil=new THREE.Mesh(new THREE.SphereGeometry(.065,10,7),irisMat);pupil.scale.z=.45;pupil.position.set(sx,4.46,.685);player.add(pupil);}
      const nose=new THREE.Mesh(new THREE.ConeGeometry(.105,.3,10),skinMat);nose.rotation.x=Math.PI/2;nose.position.set(0,4.25,.7);player.add(nose);const hair=new THREE.Mesh(new THREE.SphereGeometry(.695,18,10,0,Math.PI*2,0,Math.PI*.46),hairMat);hair.position.y=4.42;player.add(hair);
      const hatBrim=new THREE.Mesh(new THREE.CylinderGeometry(.9,.9,.12,20),darkMat);hatBrim.position.y=4.92;player.add(hatBrim);
      const hatTop=new THREE.Mesh(new THREE.CylinderGeometry(.58,.68,.55,20),darkMat);hatTop.position.y=5.18;player.add(hatTop);
      const leftLeg=new THREE.Mesh(new THREE.BoxGeometry(.55,1.7,.62),darkMat),rightLeg=leftLeg.clone();leftLeg.position.set(-.47,.88,0);rightLeg.position.set(.47,.88,0);leftLeg.castShadow=rightLeg.castShadow=true;player.add(leftLeg,rightLeg);
      const leftArm=new THREE.Mesh(new THREE.BoxGeometry(.48,1.8,.5),suitMat),rightArm=leftArm.clone();leftArm.position.set(-1.02,2.75,0);rightArm.position.set(1.02,2.75,0);leftArm.castShadow=rightArm.castShadow=true;player.add(leftArm,rightArm);
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
      gun.add(gunReceiver,gunSlide,gunBarrel,gunMuzzle,gunGrip,gunMagazine,gunStock,gunScope,rpgTube);gun.position.set(.78,2.72,.55);gun.rotation.x=-.08;gun.traverse(o=>{if(o.isMesh)o.castShadow=true;});player.add(gun);
      const playerNameTexture=(()=>{const cv=document.createElement('canvas');cv.width=512;cv.height=128;const c=cv.getContext('2d');c.fillStyle='rgba(5,10,18,.9)';c.fillRect(5,5,502,118);c.strokeStyle='#d8b750';c.lineWidth=7;c.strokeRect(9,9,494,110);c.fillStyle='#fff';c.font='900 48px system-ui';c.textAlign='center';c.textBaseline='middle';c.fillText(String(initialState?.name||'Игрок').slice(0,18),256,62);const tx=new THREE.CanvasTexture(cv);tx.colorSpace=THREE.SRGBColorSpace;return tx;})();
      const playerName=new THREE.Sprite(new THREE.SpriteMaterial({map:playerNameTexture,transparent:true,depthTest:false}));playerName.position.y=6.75;playerName.scale.set(7.4,1.72,1);playerName.renderOrder=45;const playerHpBg=new THREE.Sprite(new THREE.SpriteMaterial({color:0x33151a,depthTest:false}));playerHpBg.position.y=5.92;playerHpBg.scale.set(4.15,.34,1);playerHpBg.renderOrder=44;const playerHpBar=new THREE.Sprite(new THREE.SpriteMaterial({color:0x55e778,depthTest:false}));playerHpBar.position.y=5.94;playerHpBar.scale.set(3.9,.21,1);playerHpBar.renderOrder=45;player.add(playerName,playerHpBg,playerHpBar);
      player.position.set(0,0,0);scene.add(player);
      player.traverse(o=>o.layers.enable(1));
      const weatherMode=(rendererParams.get('weather')||envSnapshot?.weather||'clear').toLowerCase(),weatherCount=weatherMode==='rain'?150:weatherMode==='snow'?110:0,weatherPositions=new Float32Array(weatherCount*(weatherMode==='rain'?6:3)),weatherSeeds=[];
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
      console.info(`[ThreePreview] gameplay bridge: ${bridge?'connected':'fallback'}; real map blocks: ${worldSnapshot?.blocks?.length||0}`);

      const cars = [];
      Array.from({length:24},(_,i)=>[-25+i*3,-2,[0xe9a126,0x15202e,0x8b1825,0x376da3,0xd9d9d2][i%5]]).forEach((v, i) => {
        const car = new THREE.Group();
        const paint = new THREE.MeshPhysicalMaterial({color:v[2],metalness:.42,roughness:.2,clearcoat:1,clearcoatRoughness:.075,envMap:cityEnvironment,envMapIntensity:1.28});
        const long=i%6===0,utility=i%7===0,L=long?7.1:utility?6.4:5.8,H=utility?1.7:1.25;
        const base = new THREE.Mesh(new THREE.BoxGeometry(L, H, utility?3.05:2.75), paint); base.position.y = H*.5+.38; base.castShadow = true; car.add(base);
        const glass=new THREE.MeshPhysicalMaterial({color:0x172b3e,metalness:.08,roughness:.07,transmission:.16,thickness:.22,clearcoat:1,clearcoatRoughness:.04,envMap:cityEnvironment,envMapIntensity:1.65});
        const cab = new THREE.Mesh(new THREE.BoxGeometry(utility?3.8:3.1, utility?1.35:1.05, utility?2.7:2.45), glass); cab.position.set(utility?-.25:.15, utility?2.15:1.95, 0); cab.castShadow = true; car.add(cab);
        const hood=new THREE.Mesh(new THREE.BoxGeometry(L*.27,.32,utility?2.82:2.5),paint);hood.position.set(L*.34,H+1.02,0);hood.castShadow=true;car.add(hood);
        const bumperMat=new THREE.MeshStandardMaterial({color:0x727b82,metalness:.82,roughness:.22});
        for(const sx of [-1,1]){const bumper=new THREE.Mesh(new THREE.BoxGeometry(.18,.24,utility?2.95:2.66),bumperMat);bumper.position.set(sx*(L/2+.13),.58,0);car.add(bumper);}
        const wheels=[];for (const sx of [-1.8, 1.8]) for (const sz of [-1.38, 1.38]) { const wheel = new THREE.Mesh(new THREE.CylinderGeometry(.48, .48, .34, 14), new THREE.MeshStandardMaterial({ color: 0x090a0c })); wheel.rotation.x = Math.PI / 2; wheel.position.set(sx, .62, sz); car.add(wheel);wheels.push(wheel); }
        const headLamp=new THREE.MeshBasicMaterial({color:0xfff0bd,toneMapped:false}),tailLamp=new THREE.MeshBasicMaterial({color:0x791812,toneMapped:false});
        for(const z of [-.82,.82]){const front=new THREE.Mesh(new THREE.BoxGeometry(.12,.35,.42),headLamp);front.position.set(L/2+.04,.95,z);front.onBeforeRender=()=>headLamp.color.setHex(environmentNight>.12?0xfff1bd:0xb8c0bd);car.add(front);const rear=new THREE.Mesh(new THREE.BoxGeometry(.12,.32,.4),tailLamp);rear.position.set(-L/2-.04,.88,z);rear.onBeforeRender=()=>{const src=car.userData.source,braking=!!src?.braking||(src&&Math.hypot(+src.velR||0,+src.velC||0)<.035);tailLamp.color.setHex(braking&&environmentNight>.08?0xff3027:environmentNight>.08?0xa51c17:0x651713);};car.add(rear);}
        const siren=new THREE.Group();for(const [z,color] of [[-.36,0xff2929],[.36,0x278cff]]){const lamp=new THREE.Mesh(new THREE.BoxGeometry(.75,.22,.55),new THREE.MeshBasicMaterial({color}));lamp.position.set(0,2.82,z);siren.add(lamp);}siren.visible=false;car.add(siren);
        const plate=new THREE.Mesh(new THREE.PlaneGeometry(1.15,.38),new THREE.MeshBasicMaterial({color:0xe9e3c9}));plate.rotation.y=-Math.PI/2;plate.position.set(-L/2-.11,.72,0);car.add(plate);
        const standardParts=[...car.children];
        const contactShadow=makeContactShadow(L*1.08,(utility?3.05:2.75)*1.18);car.add(contactShadow);
        const taxiSign=new THREE.Mesh(new THREE.BoxGeometry(1.35,.38,.58),new THREE.MeshBasicMaterial({color:0xffe34a}));taxiSign.position.set(0,2.75,0);taxiSign.visible=false;car.add(taxiSign);
        const spoiler=new THREE.Group(),spoilerWing=new THREE.Mesh(new THREE.BoxGeometry(.28,.22,2.35),paint);spoilerWing.position.set(-2.25,1.72,0);spoiler.add(spoilerWing);for(const z of [-.75,.75]){const stay=new THREE.Mesh(new THREE.BoxGeometry(.16,.62,.14),bumperMat);stay.position.set(-2.25,1.4,z);spoiler.add(stay);}spoiler.visible=false;car.add(spoiler);
        const pickupBed=new THREE.Group(),bedMat=new THREE.MeshStandardMaterial({color:0x20252a,roughness:.78,metalness:.25}),bedFloor=new THREE.Mesh(new THREE.BoxGeometry(2.35,.18,2.55),bedMat);bedFloor.position.set(-1.55,1.15,0);pickupBed.add(bedFloor);for(const z of [-1.22,1.22]){const rail=new THREE.Mesh(new THREE.BoxGeometry(2.45,.7,.16),paint);rail.position.set(-1.55,1.45,z);pickupBed.add(rail);}pickupBed.visible=false;car.add(pickupBed);
        const roofRack=new THREE.Group();for(const z of [-.92,.92]){const rail=new THREE.Mesh(new THREE.BoxGeometry(3.4,.12,.12),bumperMat);rail.position.set(0,2.95,z);roofRack.add(rail);}for(const x of [-1.3,0,1.3]){const cross=new THREE.Mesh(new THREE.BoxGeometry(.12,.12,1.95),bumperMat);cross.position.set(x,2.95,0);roofRack.add(cross);}roofRack.visible=false;car.add(roofRack);
        const cabrioSeats=new THREE.Group();for(const x of [-.55,.55]){const seat=new THREE.Mesh(new THREE.BoxGeometry(.65,.72,.82),new THREE.MeshStandardMaterial({color:0x7d2b25,roughness:.75}));seat.position.set(x,1.62,0);cabrioSeats.add(seat);}cabrioSeats.visible=false;car.add(cabrioSeats);
        const stripe=new THREE.Mesh(new THREE.BoxGeometry(L*.72,.16,utility?3.08:2.78),new THREE.MeshBasicMaterial({color:0xe53b32}));stripe.position.set(0,1.18,0);stripe.visible=false;car.add(stripe);
        const roadDustMat=new THREE.MeshStandardMaterial({color:0x493e35,roughness:1,transparent:true,opacity:.34});for(const z of [-1,1]){const grime=new THREE.Mesh(new THREE.PlaneGeometry(L*.72,.62),roadDustMat);grime.rotation.y=z>0?0:Math.PI;grime.position.set(-.12,.72,z*(utility?1.535:1.385));car.add(grime);}
        const helicopter=new THREE.Group(),heliBody=new THREE.Mesh(new THREE.SphereGeometry(1.2,16,10),paint);heliBody.scale.set(2.15,1.05,1.18);heliBody.position.y=3.1;helicopter.add(heliBody);const tailBoom=new THREE.Mesh(new THREE.CylinderGeometry(.18,.42,4.5,8),paint);tailBoom.rotation.z=Math.PI/2;tailBoom.position.set(-3.1,3.25,0);helicopter.add(tailBoom);const rotor=new THREE.Group();for(let k=0;k<2;k++){const blade=new THREE.Mesh(new THREE.BoxGeometry(7.8,.08,.18),new THREE.MeshStandardMaterial({color:0x232a30,metalness:.6,roughness:.35}));blade.rotation.y=k*Math.PI/2;rotor.add(blade);}rotor.position.y=4.55;helicopter.add(rotor);for(const z of [-.85,.85]){const skid=new THREE.Mesh(new THREE.BoxGeometry(3.2,.12,.12),bumperMat);skid.position.set(.1,1.65,z);helicopter.add(skid);}helicopter.visible=false;car.add(helicopter);
        car.userData={entityId:null,paint,wheels,siren,cab,base,hood,standardParts,taxiSign,spoiler,pickupBed,roofRack,cabrioSeats,stripe,helicopter,rotor,contactShadow,lastPosition:new THREE.Vector3(v[0],0,v[1])};car.position.set(v[0], 0, v[1]);car.visible=false;car.frustumCulled=false;scene.add(car);cars.push(car);
      });
      const syncCarSlots=sources=>{const wanted=new Map((sources||[]).map(src=>[String(src.id),src])),claimed=new Set();for(const car of cars){const id=car.userData.entityId;if(id!==null&&wanted.has(id)){car.userData.source=wanted.get(id);wanted.delete(id);claimed.add(car);}else{car.userData.entityId=null;car.userData.source=null;car.visible=false;}}for(const [id,src] of wanted){const car=cars.find(candidate=>!claimed.has(candidate)&&candidate.userData.entityId===null);if(!car)break;car.userData.entityId=id;car.userData.source=src;car.userData.lastPosition.set((src.c-originC)*WORLD_SCALE,0,(src.r-originR)*WORLD_SCALE);claimed.add(car);}};
      const beamCanvas=document.createElement('canvas');beamCanvas.width=512;beamCanvas.height=192;const beamContext=beamCanvas.getContext('2d'),beamGradient=beamContext.createLinearGradient(0,0,512,0);beamGradient.addColorStop(0,'rgba(255,242,185,.5)');beamGradient.addColorStop(.42,'rgba(255,225,135,.18)');beamGradient.addColorStop(1,'rgba(255,220,120,0)');beamContext.fillStyle=beamGradient;beamContext.fillRect(0,0,512,192);const beamTexture=new THREE.CanvasTexture(beamCanvas);beamTexture.colorSpace=THREE.SRGBColorSpace;const vehicleBeamMaterial=new THREE.MeshBasicMaterial({map:beamTexture,color:0xffe7a0,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}),vehicleLightBeams=new THREE.InstancedMesh(new THREE.PlaneGeometry(8.5,3.6),vehicleBeamMaterial,cars.length),vehicleBeamMatrix=new THREE.Matrix4(),vehicleBeamQuat=new THREE.Quaternion(),vehicleBeamScale=new THREE.Vector3(1,1,1),vehicleBeamHidden=new THREE.Vector3(0,0,0);
      vehicleLightBeams.frustumCulled=false;vehicleLightBeams.renderOrder=8;scene.add(vehicleLightBeams);let environmentNight=0;
      const updateVehicleBeams=()=>{vehicleBeamMaterial.opacity=environmentNight*.24;cars.forEach((car,i)=>{const src=car.userData.source,shown=car.visible&&src&&!src.helicopter&&environmentNight>.04;if(!shown){vehicleBeamMatrix.compose(new THREE.Vector3(0,-1000,0),vehicleBeamQuat.identity(),vehicleBeamHidden);vehicleLightBeams.setMatrixAt(i,vehicleBeamMatrix);return;}const yaw=car.rotation.y,fx=Math.cos(yaw),fz=-Math.sin(yaw);vehicleBeamQuat.setFromEuler(new THREE.Euler(-Math.PI/2,0,-yaw));vehicleBeamMatrix.compose(new THREE.Vector3(car.position.x+fx*5.2,.09,car.position.z+fz*5.2),vehicleBeamQuat,vehicleBeamScale);vehicleLightBeams.setMatrixAt(i,vehicleBeamMatrix);});vehicleLightBeams.instanceMatrix.needsUpdate=true;};
      const NPC_CAP=18,REMOTE_CAP=12,BULLET_CAP=48,hiddenScale=new THREE.Vector3(0,0,0),unitScale=new THREE.Vector3(1,1,1),npcScale=new THREE.Vector3(1.32,1.32,1.32),instanceMatrix=new THREE.Matrix4(),rootMatrix=new THREE.Matrix4(),localMatrix=new THREE.Matrix4(),instanceQuat=new THREE.Quaternion(),instanceColor=new THREE.Color();
      const eyeScale=new THREE.Vector3(1,.78,.42),pupilScale=new THREE.Vector3(1,.78,.3),npcBodyScale=new THREE.Vector3(1,1,1);
      const makeInstances=(geometry,material,count,castShadow=true)=>{const mesh=new THREE.InstancedMesh(geometry,material,count),defaultInstanceColor=new THREE.Color(0xffffff);mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.castShadow=castShadow;mesh.receiveShadow=castShadow;mesh.layers.enable(1);mesh.frustumCulled=false;for(let i=0;i<count;i++){instanceMatrix.compose(new THREE.Vector3(0,-1000,0),instanceQuat,hiddenScale);mesh.setMatrixAt(i,instanceMatrix);if(material.vertexColors)mesh.setColorAt(i,defaultInstanceColor);}mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor){mesh.instanceColor.setUsage(THREE.DynamicDrawUsage);mesh.instanceColor.needsUpdate=true;material.needsUpdate=true;}scene.add(mesh);return mesh;};
      // Repeated street furniture is authored for the high isometric camera:
      // broad crowns and bright hydrants read clearly without hundreds of meshes.
      const streetTreeDefs=[],hydrantDefs=[],bollardDefs=[],benchDefs=[];buildingDefs.forEach((b,i)=>{const [x,z,w,d,,style,,districtStyle]=b;if((districtStyle==='rich'||districtStyle==='coast'||districtStyle==='countryside'||i%5===0)&&streetTreeDefs.length<42)streetTreeDefs.push([x+w/2+2.2,z+d*.28,.8+(i%3)*.1]);if(i%4===1&&hydrantDefs.length<28)hydrantDefs.push([x-w/2-1.45,z+d*.3]);if((districtStyle==='downtown'||districtStyle==='nightlife')&&i%3===0&&bollardDefs.length<48)for(const dz of [-2.2,0,2.2])bollardDefs.push([x+w/2+1.2,z+dz]);if((districtStyle==='rich'||districtStyle==='coast'||i%9===0)&&benchDefs.length<22)benchDefs.push([x-w*.25,z+d/2+1.55,i%2?0:Math.PI]);});
      const staticInstances=(geo,mat,defs,place)=>{const mesh=new THREE.InstancedMesh(geo,mat,defs.length);mesh.castShadow=true;mesh.receiveShadow=true;defs.forEach((def,i)=>{place(def,i);mesh.setMatrixAt(i,instanceMatrix);});mesh.instanceMatrix.needsUpdate=true;scene.add(mesh);return mesh;};
      const windLeafMaterials=[];
      const windLeafMaterial=color=>{const mat=new THREE.MeshStandardMaterial({color,roughness:.86});mat.onBeforeCompile=shader=>{shader.uniforms.mfzWindTime={value:0};shader.vertexShader='uniform float mfzWindTime;\n'+shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nfloat mfzWind=sin(mfzWindTime+position.y*1.7+position.x*.8)*.07;\ntransformed.x+=mfzWind*(.35+abs(position.y));\ntransformed.z+=cos(mfzWindTime*.83+position.z)*.035*(.3+abs(position.y));');mat.userData.shader=shader;};mat.customProgramCacheKey=()=>`mfz-wind-${color}`;windLeafMaterials.push(mat);return mat;};
      staticInstances(new THREE.CylinderGeometry(.22,.35,3.8,8),new THREE.MeshStandardMaterial({color:0x70452c,roughness:.9}),streetTreeDefs,([x,z,s])=>instanceMatrix.compose(new THREE.Vector3(x,1.9*s,z),instanceQuat.identity(),new THREE.Vector3(s,s,s)));
      staticInstances(new THREE.IcosahedronGeometry(1.75,1),windLeafMaterial(0x2d824e),streetTreeDefs,([x,z,s])=>instanceMatrix.compose(new THREE.Vector3(x,4.3*s,z),instanceQuat.identity(),new THREE.Vector3(s*1.12,s,s*1.12)));
      staticInstances(new THREE.IcosahedronGeometry(1.3,1),windLeafMaterial(0x49a765),streetTreeDefs,([x,z,s],i)=>instanceMatrix.compose(new THREE.Vector3(x+(i%2?1:-1)*.72*s,4.65*s,z+(i%3-1)*.38*s),instanceQuat.identity(),new THREE.Vector3(s,s*.88,s)));
      staticInstances(new THREE.CylinderGeometry(.22,.28,1.05,10),new THREE.MeshStandardMaterial({color:0xe44735,roughness:.5,metalness:.22}),hydrantDefs,([x,z])=>instanceMatrix.compose(new THREE.Vector3(x,.53,z),instanceQuat.identity(),unitScale));
      staticInstances(new THREE.CylinderGeometry(.13,.18,1.1,8),new THREE.MeshStandardMaterial({color:0x202a32,roughness:.45,metalness:.62}),bollardDefs,([x,z])=>instanceMatrix.compose(new THREE.Vector3(x,.55,z),instanceQuat.identity(),unitScale));
      const benchMat=new THREE.MeshStandardMaterial({color:0x8a532f,roughness:.8});staticInstances(new THREE.BoxGeometry(3.4,.28,.8),benchMat,benchDefs,([x,z,a])=>instanceMatrix.compose(new THREE.Vector3(x,.78,z),instanceQuat.setFromAxisAngle(new THREE.Vector3(0,1,0),a),unitScale));staticInstances(new THREE.BoxGeometry(3.4,1.15,.22),benchMat,benchDefs,([x,z,a])=>{instanceQuat.setFromAxisAngle(new THREE.Vector3(0,1,0),a);const side=new THREE.Vector3(Math.sin(a)*.38,0,Math.cos(a)*.38);instanceMatrix.compose(new THREE.Vector3(x+side.x,1.45,z+side.z),instanceQuat,unitScale);});
      const npcParts={
        body:makeInstances(new THREE.BoxGeometry(1.15,1.8,.75),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.68,metalness:0,vertexColors:true}),NPC_CAP),
        head:makeInstances(new THREE.SphereGeometry(.44,12,9),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.78,metalness:0,vertexColors:true}),NPC_CAP),
        leftLeg:makeInstances(new THREE.BoxGeometry(.38,1.25,.38),new THREE.MeshStandardMaterial({color:0x536b83,roughness:.82}),NPC_CAP),
        rightLeg:makeInstances(new THREE.BoxGeometry(.38,1.25,.38),new THREE.MeshStandardMaterial({color:0x536b83,roughness:.82}),NPC_CAP),
        leftArm:makeInstances(new THREE.BoxGeometry(.3,1.35,.38),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.7,metalness:0,vertexColors:true}),NPC_CAP),
        rightArm:makeInstances(new THREE.BoxGeometry(.3,1.35,.38),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.7,metalness:0,vertexColors:true}),NPC_CAP),
        hat:makeInstances(new THREE.CylinderGeometry(.52,.58,.3,12),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.62,metalness:0,vertexColors:true}),NPC_CAP),
        gun:makeInstances(new THREE.BoxGeometry(.2,.24,1.05),darkMat,NPC_CAP)
      };
      npcParts.eyeWhite=makeInstances(new THREE.SphereGeometry(.105,10,7),new THREE.MeshBasicMaterial({color:0xf8fbff}),NPC_CAP*2,false);npcParts.pupil=makeInstances(new THREE.SphereGeometry(.052,8,6),new THREE.MeshBasicMaterial({color:0x17212b}),NPC_CAP*2,false);npcParts.hair=makeInstances(new THREE.SphereGeometry(.455,12,8,0,Math.PI*2,0,Math.PI*.48),new THREE.MeshBasicMaterial({color:0x30211b}),NPC_CAP,false);npcParts.shoe=makeInstances(new THREE.BoxGeometry(.42,.24,.68),new THREE.MeshBasicMaterial({color:0x161b22}),NPC_CAP*2,false);
      const citizenPool=[];for(let i=0;i<NPC_CAP;i++){const hpGroup=new THREE.Group(),hpBg=new THREE.Sprite(new THREE.SpriteMaterial({color:0x35181c,depthTest:false})),hpBar=new THREE.Sprite(new THREE.SpriteMaterial({color:0x58e67c,depthTest:false}));hpBg.position.y=4.25;hpBg.scale.set(1.7,.2,1);hpBar.position.y=4.26;hpBar.scale.set(1.55,.11,1);hpBar.renderOrder=42;hpBg.renderOrder=41;hpGroup.add(hpBg,hpBar);hpGroup.layers.enable(1);hpGroup.visible=false;scene.add(hpGroup);citizenPool.push({hpGroup,hpBar});}
      const npcLabels=[];for(let i=0;i<NPC_CAP;i++){const canvas=document.createElement('canvas');canvas.width=768;canvas.height=160;const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.minFilter=THREE.LinearMipmapLinearFilter;texture.anisotropy=Math.min(16,renderer.capabilities.getMaxAnisotropy());const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:texture,transparent:true,depthTest:false}));sprite.scale.set(10.5,2.25,1);sprite.renderOrder=46;sprite.layers.enable(1);sprite.visible=false;scene.add(sprite);npcLabels.push({canvas,texture,sprite,sig:''});}
      const outlinedLabelText=(c,text,x,y,font,color)=>{c.font=font;c.textAlign='center';c.textBaseline='middle';c.lineJoin='round';c.lineWidth=14;c.strokeStyle='rgba(0,0,0,.96)';c.strokeText(text,x,y);c.fillStyle=color;c.fillText(text,x,y);};
      const updateNpcLabel=(entry,src,x,y,z)=>{const role=String(src.role||'civilian').toLowerCase(),gang=!!src.gang||role.includes('gang')||role.includes('boss')||role.includes('district_'),police=!!src.police||role.includes('police')||role.includes('cop'),guard=role.includes('guard'),civilian=!police&&!gang&&!guard,title=police?'ПОЛИЦИЯ':gang?'БОЕЦ БАНДЫ':'ОХРАНА',accent=police?'#58b9ff':gang?'#ff5367':guard?'#ffc857':'#7ee7a5',name=String(src.name||title).slice(0,18),hp=Math.max(0,Math.round(+src.hp||0)),maxHp=Math.max(1,Math.round(+src.maxHp||60)),level=gang?Math.max(1,Math.round(+src.level||1)):null,family=String(src.family||'').slice(0,14),rankText=gang?` · ${level} ур.`:'',sig=`${civilian?'hp':title}:${name}:${rankText}:${hp}:${maxHp}:${family}`;if(sig!==entry.sig){entry.sig=sig;const c=entry.canvas.getContext('2d');c.clearRect(0,0,768,160);if(civilian){c.fillStyle='rgba(5,10,17,.92)';c.fillRect(154,19,460,122);c.strokeStyle=accent;c.lineWidth=10;c.strokeRect(159,24,450,112);outlinedLabelText(c,`HP ${hp}/${maxHp}`,384,82,'900 66px system-ui','#ffffff');entry.sprite.scale.set(11.8,2.65,1);}else{c.fillStyle='rgba(5,10,17,.94)';c.fillRect(8,8,752,144);c.strokeStyle=accent;c.lineWidth=9;c.strokeRect(13,13,742,134);outlinedLabelText(c,`${title}${rankText}${family?` · ${family}`:''}`,384,52,'900 46px system-ui',accent);outlinedLabelText(c,`${name} · HP ${hp}/${maxHp}`,384,111,'900 42px system-ui','#ffffff');entry.sprite.scale.set(13,2.8,1);}entry.texture.needsUpdate=true;}entry.sprite.visible=true;entry.sprite.position.set(x,y,z);};
      const remoteParts={body:makeInstances(new THREE.BoxGeometry(1.45,2.15,.9),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.58,vertexColors:true}),REMOTE_CAP),head:makeInstances(new THREE.SphereGeometry(.53,14,10),new THREE.MeshStandardMaterial({color:0xc58c68,roughness:.76}),REMOTE_CAP),hat:makeInstances(new THREE.CylinderGeometry(.68,.68,.28,14),new THREE.MeshStandardMaterial({color:0xffffff,roughness:.58,vertexColors:true}),REMOTE_CAP)};
      const worldBullets=makeInstances(new THREE.SphereGeometry(.18,8,6),new THREE.MeshBasicMaterial({color:0xffffff,depthTest:false,vertexColors:true}),BULLET_CAP,false);worldBullets.renderOrder=35;
      const setPart=(mesh,index,root,px,py,pz,rx=0,scale=unitScale)=>{instanceQuat.setFromEuler(new THREE.Euler(rx,0,0));localMatrix.compose(new THREE.Vector3(px,py,pz),instanceQuat,scale);instanceMatrix.multiplyMatrices(root,localMatrix);mesh.setMatrixAt(index,instanceMatrix);};
      const hidePart=(mesh,index)=>{instanceMatrix.compose(new THREE.Vector3(0,-1000,0),instanceQuat.identity(),hiddenScale);mesh.setMatrixAt(index,instanceMatrix);};
      const hideNpcVisual=i=>{for(const [key,mesh] of Object.entries(npcParts)){if(key==='eyeWhite'||key==='pupil'||key==='shoe'){hidePart(mesh,i*2);hidePart(mesh,i*2+1);}else hidePart(mesh,i);}};
      const muzzlePool=[],impactPool=[],explosionPool=[];
      for(let i=0;i<16;i++){const flash=new THREE.Mesh(new THREE.SphereGeometry(.45,10,7),new THREE.MeshBasicMaterial({color:0xffc35a,transparent:true,depthTest:false}));flash.layers.enable(1);flash.renderOrder=37;flash.visible=false;scene.add(flash);muzzlePool.push(flash);const impact=new THREE.Mesh(new THREE.IcosahedronGeometry(.42,1),new THREE.MeshBasicMaterial({color:0xffd36a,transparent:true,depthTest:false}));impact.layers.enable(1);impact.renderOrder=37;impact.visible=false;scene.add(impact);impactPool.push(impact);}
      for(let i=0;i<10;i++){const blast=new THREE.Mesh(new THREE.IcosahedronGeometry(1.4,2),new THREE.MeshBasicMaterial({color:0xff7b25,transparent:true,depthTest:false,blending:THREE.AdditiveBlending}));blast.layers.enable(1);blast.renderOrder=39;blast.visible=false;scene.add(blast);explosionPool.push(blast);}
      const interiorGroup=new THREE.Group();interiorGroup.layers.set(1);interiorGroup.visible=false;scene.add(interiorGroup);const interiorAmbient=new THREE.HemisphereLight(0xffead1,0x243342,2.25);interiorAmbient.layers.set(1);scene.add(interiorAmbient);let interiorSignature='',interiorFloor=null;
      const interiorMatFor=type=>({hospital:0xc8ddd8,gym:0x775543,police_st:0x53677d,business:0x6a5142,blackmarket:0x342d3b,bank:0x8a816f}[type]||0x62584f);
      const rebuildInterior=data=>{while(interiorGroup.children.length){const o=interiorGroup.children.pop();o.geometry?.dispose?.();if(o.material&&!Array.isArray(o.material))o.material.dispose?.();}const W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,floorMat=new THREE.MeshStandardMaterial({color:interiorMatFor(data.type),roughness:.86}),wallMat=new THREE.MeshStandardMaterial({color:0x313943,roughness:.74}),trimMat=new THREE.MeshStandardMaterial({color:0xb89a61,roughness:.56,metalness:.18}),redMat=new THREE.MeshStandardMaterial({color:0x9f2f32,roughness:.62}),softMat=new THREE.MeshStandardMaterial({color:0x315978,roughness:.82}),whiteMat=new THREE.MeshStandardMaterial({color:0xe6ecec,roughness:.7});const add=(geo,mat,x,y,z)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;};interiorFloor=add(new THREE.PlaneGeometry(W,H),floorMat,cx,.02,cz);interiorFloor.rotation.x=-Math.PI/2;const grid=new THREE.GridHelper(Math.max(W,H),Math.max(8,Math.floor(Math.max(data.width,data.height))),0x4b3f35,0x4b3f35);grid.position.set(cx,.055,cz);grid.material.transparent=true;grid.material.opacity=.2;grid.layers.set(1);interiorGroup.add(grid);add(new THREE.BoxGeometry(W,5,.7),wallMat,cx,2.5,(.1-originR)*WORLD_SCALE);add(new THREE.BoxGeometry(.7,5,H),wallMat,(.1-originC)*WORLD_SCALE,2.5,cz);add(new THREE.BoxGeometry(.7,5,H),wallMat,(data.width-.1-originC)*WORLD_SCALE,2.5,cz);const backZ=(data.height-.1-originR)*WORLD_SCALE;add(new THREE.BoxGeometry(W*.38,5,.7),wallMat,cx-W*.31,2.5,backZ);add(new THREE.BoxGeometry(W*.38,5,.7),wallMat,cx+W*.31,2.5,backZ);const exitGlow=add(new THREE.BoxGeometry(4.2,.2,1.1),new THREE.MeshBasicMaterial({color:0x4dff8a}),cx,.35,backZ-.5);exitGlow.rotation.x=-Math.PI/2;if(data.type==='bank'||data.kind==='bank'){if(data.room==='vault'){const vault=add(new THREE.CylinderGeometry(5.2,5.2,1.25,32),new THREE.MeshStandardMaterial({color:0x69747c,metalness:.88,roughness:.24}),cx,3.2,cz-H*.25);vault.rotation.x=Math.PI/2;for(let i=-2;i<=2;i++)add(new THREE.BoxGeometry(3.2,2.2,2.2),trimMat,cx+i*4.1,1.1,cz+H*.12);}else{for(let i=-2;i<=2;i++)add(new THREE.BoxGeometry(W*.1,1.5,2.1),trimMat,cx+i*W*.14,.75,cz-H*.18);for(const sx of [-W*.32,W*.32])add(new THREE.CylinderGeometry(.38,.48,4.8,14),whiteMat,cx+sx,2.4,cz+H*.2);}}else if(data.type==='hospital'){for(let i=-1;i<=1;i++){add(new THREE.BoxGeometry(4.2,.75,2),whiteMat,cx+i*6,1,cz-H*.12);add(new THREE.BoxGeometry(.25,1.6,1.7),new THREE.MeshBasicMaterial({color:0x62d7ec}),cx+i*6-1.8,1.35,cz-H*.12);}}else if(data.bizId==='barbershop'){for(const dx of [-7,0,7]){add(new THREE.CylinderGeometry(1.05,1.2,.55,16),redMat,cx+dx,.72,cz);add(new THREE.BoxGeometry(2.2,2.8,.22),new THREE.MeshStandardMaterial({color:0x9ed5e6,metalness:.72,roughness:.12}),cx+dx,2.4,cz-H*.28);}}else if(['coffee','pizza','bar'].includes(data.bizId)){for(const [dx,dz] of [[-7,-4],[0,-4],[7,-4],[-4,4],[4,4]]){add(new THREE.CylinderGeometry(1.45,1.45,.35,16),trimMat,cx+dx,1.1,cz+dz);for(let i=0;i<3;i++){const a=i*Math.PI*2/3;add(new THREE.BoxGeometry(.8,.8,.8),wallMat,cx+dx+Math.cos(a)*2,.4,cz+dz+Math.sin(a)*2);}}if(data.bizId==='bar')add(new THREE.BoxGeometry(W*.58,1.5,2.4),redMat,cx,.75,cz-H*.28);}else if(['warehouse','port'].includes(data.bizId)){for(let i=0;i<12;i++)add(new THREE.BoxGeometry(2.2,1.8,2.2),new THREE.MeshStandardMaterial({color:i%3?0x8c5732:0x526f78,roughness:.8}),cx-9+(i%4)*6,.9,cz-6+Math.floor(i/4)*5);}else if(['garage','carwash'].includes(data.bizId)){for(const dx of [-6,6]){add(new THREE.BoxGeometry(5,.35,10),new THREE.MeshStandardMaterial({color:0x38444b,metalness:.5,roughness:.45}),cx+dx,.3,cz);add(new THREE.BoxGeometry(.45,3,.45),trimMat,cx+dx-2,1.5,cz);add(new THREE.BoxGeometry(.45,3,.45),trimMat,cx+dx+2,1.5,cz);}}else if(['club','casino'].includes(data.bizId)){add(new THREE.BoxGeometry(W*.5,.18,H*.42),new THREE.MeshBasicMaterial({color:0x7d38bf}),cx,.1,cz);const neon=new THREE.PointLight(0xff42d0,12,28,2);neon.position.set(cx,5,cz);neon.layers.set(1);interiorGroup.add(neon);}else{add(new THREE.BoxGeometry(7,1.3,3),softMat,cx-5,.65,cz);add(new THREE.BoxGeometry(5.5,1.05,3.2),trimMat,cx+6,.53,cz-4);add(new THREE.BoxGeometry(6,.55,7),whiteMat,cx+7,.28,cz+5);add(new THREE.BoxGeometry(2.5,3.2,.8),wallMat,cx+W*.28,1.6,cz-H*.25);}if(data.loot){const lootMat=new THREE.MeshStandardMaterial({color:data.loot.hp?0x5bdc83:0xd6aa42,emissive:data.loot.hp?0x123d20:0x4a2f08,emissiveIntensity:.9,metalness:.24,roughness:.45}),loot=add(new THREE.BoxGeometry(1.6,1.1,1.35),lootMat,(data.loot.c-originC)*WORLD_SCALE,.65,(data.loot.r-originR)*WORLD_SCALE);outline(loot);}const ceiling=new THREE.RectAreaLight(0xffe2b0,7,W*.7,H*.55);ceiling.position.set(cx,9,cz);ceiling.lookAt(cx,0,cz);ceiling.layers.set(1);interiorGroup.add(ceiling);interiorGroup.visible=true;};

      const help=document.createElement('div');help.textContent='3D: W / ↑ — вперёд к курсору · S / ↓ — назад · A/D — шаг вбок · E — здание · клик — огонь';
      help.style.cssText='position:absolute;left:50%;top:82px;transform:translateX(-50%);z-index:20;padding:7px 12px;border:1px solid #d5ab45;border-radius:9px;background:rgba(8,13,22,.82);color:#ffe7a3;font:700 12px system-ui;pointer-events:none;white-space:nowrap';stage.appendChild(help);
      const buildingPrompt=document.createElement('div');buildingPrompt.style.cssText='position:absolute;left:50%;top:122px;transform:translateX(-50%);z-index:22;display:none;padding:9px 14px;border:2px solid #ffd45b;border-radius:10px;background:rgba(12,17,24,.94);color:#fff4bd;font:900 13px system-ui;pointer-events:none;white-space:nowrap;box-shadow:0 7px 24px #000b,0 0 18px #ffcb3c55';stage.appendChild(buildingPrompt);
      const rollback=document.createElement('button');rollback.type='button';rollback.textContent='↩ Вернуться в 2D';rollback.title='Безопасный откат на прежний Canvas-рендер';
      rollback.style.cssText='position:absolute;right:14px;top:72px;z-index:21;padding:8px 11px;border:1px solid #70b8ff;border-radius:9px;background:rgba(8,20,35,.92);color:#dff1ff;font:800 12px system-ui;cursor:pointer;box-shadow:0 5px 18px #0008';
      rollback.addEventListener('click',()=>{const url=new URL(location.href);url.searchParams.set('render',rendererConfig.rollbackRenderer||'canvas');location.href=url.href;});stage.appendChild(rollback);
      const clock=document.createElement('button');clock.type='button';clock.title='Нажмите, чтобы перемотать время на 6 часов';clock.style.cssText='position:absolute;right:14px;top:112px;z-index:20;min-width:112px;padding:7px 10px;border:1px solid #526f91;border-radius:9px;background:rgba(8,16,28,.86);color:#fff3c4;font:800 12px system-ui;text-align:center;box-shadow:0 5px 18px #0007;cursor:pointer';stage.appendChild(clock);
      let timeOffset=0;clock.addEventListener('click',()=>{timeOffset=(timeOffset+6)%24;});
      const keys=new Set(),bullets=[];let aimPoint=new THREE.Vector3(0,0,-10),lastShot=0,muzzleLife=0;
      const muzzle=new THREE.PointLight(0xffb14a,0,9,2);scene.add(muzzle);
      addEventListener('keydown',e=>{keys.add(e.code);const typing=e.target?.matches?.('input,textarea,select,[contenteditable="true"]');if(e.code==='KeyE'&&!e.repeat&&!typing){const result=bridge?.toggleNearbyBuildingActions?.(innerWidth/2,innerHeight*.58);if(result?.ok){e.preventDefault();e.stopImmediatePropagation();renderer.domElement.dataset.buildingAction=result.closed?'closed':`${result.kind}:${result.id}`;}}else if(e.code==='Escape'&&!typing){bridge?.closeBuildingActions?.();}else if(e.code==='Space'&&!typing){e.preventDefault();e.stopImmediatePropagation();shoot(performance.now());}},true);
      addEventListener('keyup',e=>keys.delete(e.code));
      const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2();let activeAimSurface=ground,mouseAimActive=false,mouseClientX=0,mouseClientY=0;
      let highlightedBuildingObject=null,manualBuildingSelectionUntil=0;const selectionFrameMat=new THREE.MeshBasicMaterial({color:0xffcf4c,transparent:true,opacity:.94,depthTest:false}),selectionCornerMat=new THREE.MeshBasicMaterial({color:0x68f7c0,transparent:true,opacity:.96,depthTest:false}),buildingSelectionFrame=new THREE.Group(),selectionBars=[];for(let i=0;i<4;i++){const bar=new THREE.Mesh(new THREE.BoxGeometry(1,.12,1),selectionFrameMat);bar.renderOrder=49;buildingSelectionFrame.add(bar);selectionBars.push(bar);}for(let i=0;i<4;i++){const corner=new THREE.Mesh(new THREE.BoxGeometry(.28,1.35,.28),selectionCornerMat);corner.renderOrder=50;buildingSelectionFrame.add(corner);selectionBars.push(corner);}buildingSelectionFrame.visible=false;scene.add(buildingSelectionFrame);
      const entranceMarker=new THREE.Mesh(new THREE.RingGeometry(.68,1.08,32),new THREE.MeshBasicMaterial({color:0x66ffad,transparent:true,opacity:.92,side:THREE.DoubleSide,depthTest:false}));entranceMarker.rotation.x=-Math.PI/2;entranceMarker.position.y=.24;entranceMarker.renderOrder=50;entranceMarker.visible=false;scene.add(entranceMarker);
      const highlightBuilding=object=>{if(!object)return;highlightedBuildingObject=object;const w=object.geometry?.parameters?.width||3,d=object.geometry?.parameters?.depth||3,pad=.42,hw=w/2+pad,hd=d/2+pad,thickness=.18;buildingSelectionFrame.position.set(object.position.x,.23,object.position.z);selectionBars[0].position.set(0,0,-hd);selectionBars[0].scale.set(w+pad*2,1,thickness);selectionBars[1].position.set(0,0,hd);selectionBars[1].scale.set(w+pad*2,1,thickness);selectionBars[2].position.set(-hw,0,0);selectionBars[2].scale.set(thickness,1,d+pad*2);selectionBars[3].position.set(hw,0,0);selectionBars[3].scale.set(thickness,1,d+pad*2);for(let i=0;i<4;i++){const corner=selectionBars[4+i],sx=i<2?-1:1,sz=i%2?-1:1;corner.position.set(sx*hw,.55,sz*hd);}buildingSelectionFrame.visible=true;};
      const buildingObjectForEntry=entry=>buildingPickables.find(o=>{if(!o.userData.mainBuilding)return false;const m=o.userData.building;if(Number.isFinite(m.minR))return entry.r>=m.minR-1&&entry.r<=m.maxR+1&&entry.c>=m.minC-1&&entry.c<=m.maxC+1;return Math.abs(entry.r-m.r)<=m.d*.5+1&&Math.abs(entry.c-m.c)<=m.w*.5+1;})||null;
      const showNearbyBuilding=entry=>{if(!entry){buildingPrompt.style.display='none';entranceMarker.visible=false;renderer.domElement.dataset.nearbyBuilding='none';if(performance.now()>manualBuildingSelectionUntil){buildingSelectionFrame.visible=false;highlightedBuildingObject=null;}return;}buildingPrompt.textContent=`E — действия: ${entry.name}`;buildingPrompt.style.display='block';renderer.domElement.dataset.nearbyBuilding=`${entry.kind}:${entry.id}`;const object=buildingObjectForEntry(entry);if(!object){entranceMarker.visible=false;return;}highlightBuilding(object);const hw=(object.geometry?.parameters?.width||3)/2+.16,hd=(object.geometry?.parameters?.depth||3)/2+.16,dx=player.position.x-object.position.x,dz=player.position.z-object.position.z,sideX=Math.abs(dx/Math.max(.1,hw))>Math.abs(dz/Math.max(.1,hd));entranceMarker.position.set(sideX?object.position.x+Math.sign(dx||1)*hw:THREE.MathUtils.clamp(player.position.x,object.position.x-hw,object.position.x+hw),.24,sideX?THREE.MathUtils.clamp(player.position.z,object.position.z-hd,object.position.z+hd):object.position.z+Math.sign(dz||1)*hd);entranceMarker.visible=true;};
      const syncMouseAim=()=>{if(!mouseAimActive)return;const r=renderer.domElement.getBoundingClientRect();if(!r.width||!r.height)return;pointer.set(((mouseClientX-r.left)/r.width)*2-1,-((mouseClientY-r.top)/r.height)*2+1);raycaster.layers.set(activeAimSurface===ground?0:1);raycaster.setFromCamera(pointer,camera);const hit=raycaster.intersectObject(activeAimSurface,false)[0];if(!hit)return;aimPoint.copy(hit.point);const dx=aimPoint.x-player.position.x,dz=aimPoint.z-player.position.z;if(dx*dx+dz*dz<.01)return;const angle=Math.atan2(dz,dx);bridge?.setAim?.(angle);player.rotation.y=Math.atan2(dx,dz);renderer.domElement.dataset.aimMode='mouse';renderer.domElement.dataset.aimAngle=angle.toFixed(3);};
      addEventListener('pointermove',e=>{if(e.pointerType==='touch')return;mouseAimActive=true;mouseClientX=e.clientX;mouseClientY=e.clientY;syncMouseAim();},true);
      renderer.domElement.addEventListener('contextmenu',e=>{e.preventDefault();renderer.domElement.dataset.contextAttempt=`${Math.round(e.clientX)},${Math.round(e.clientY)}`;if(activeAimSurface!==ground){renderer.domElement.dataset.contextHit='interior';return;}const r=renderer.domElement.getBoundingClientRect();pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);raycaster.layers.set(0);raycaster.setFromCamera(pointer,camera);const hit=raycaster.intersectObjects(buildingPickables,false)[0];if(!hit?.object?.userData?.building){renderer.domElement.dataset.contextHit='none';return;}const meta=hit.object.userData.building;renderer.domElement.dataset.contextHit=`${meta.r.toFixed(1)},${meta.c.toFixed(1)}`;const result=bridge?.selectBuilding?.(meta.r,meta.c,e.clientX,e.clientY);renderer.domElement.dataset.contextResult=result?.ok?`${result.kind}:${result.id}`:'rejected';if(result?.ok){manualBuildingSelectionUntil=performance.now()+8000;highlightBuilding(hit.object);renderer.domElement.dataset.selectedBuilding=`${result.kind}:${result.id}`;}},true);
      addEventListener('pointerdown',e=>{if(e.button===0&&!(e.target.closest&&e.target.closest('button,input,textarea,#joyL,#joyR'))){e.preventDefault();e.stopImmediatePropagation();shoot(performance.now());}},true);
      function shoot(now){
        if(now-lastShot<145)return;lastShot=now;
        const dir=new THREE.Vector3(aimPoint.x-player.position.x,0,aimPoint.z-player.position.z);if(dir.lengthSq()<.01)dir.set(Math.sin(player.rotation.y),0,Math.cos(player.rotation.y));dir.normalize();
        const worldAngle=Math.atan2(dir.z,dir.x);
        if(bridge&&!bridge.fire(worldAngle))return;
        player.rotation.y=Math.atan2(dir.x,dir.z);
        if(bridge){muzzle.position.set(player.position.x+dir.x*1.8,2.75,player.position.z+dir.z*1.8);muzzle.intensity=48;muzzleLife=.09;return;}
        const mesh=new THREE.Mesh(new THREE.SphereGeometry(.3,12,8),new THREE.MeshBasicMaterial({color:0xffe08a,depthTest:false}));mesh.renderOrder=30;mesh.position.set(player.position.x+dir.x*1.8,2.75,player.position.z+dir.z*1.8);scene.add(mesh);
        bullets.push({mesh,vel:dir.multiplyScalar(27),life:1.5});muzzle.position.copy(mesh.position);muzzle.intensity=48;muzzleLife=.09;
      }

      const decorateCasinoInterior=data=>{if(data.bizId!=='major_casino')return;const cx=(data.width/2-originC)*WORLD_SCALE,cz=(data.height/2-originR)*WORLD_SCALE,W=data.width*WORLD_SCALE,H=data.height*WORLD_SCALE,add=(geo,mat,x,y,z)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;m.layers.set(1);interiorGroup.add(m);return m;},gold=new THREE.MeshStandardMaterial({color:0xd7ad3e,metalness:.55,roughness:.32}),red=new THREE.MeshStandardMaterial({color:0x7d1534,roughness:.65}),felt=new THREE.MeshStandardMaterial({color:0x126442,roughness:.84}),dark=new THREE.MeshStandardMaterial({color:0x1b1422,metalness:.25,roughness:.52}),neon=new THREE.MeshBasicMaterial({color:0xff3bc8});const carpet=add(new THREE.PlaneGeometry(W*.72,H*.72),new THREE.MeshStandardMaterial({color:0x4e0928,roughness:.92}),cx,.08,cz);carpet.rotation.x=-Math.PI/2;for(let row=0;row<2;row++)for(let col=0;col<6;col++){const x=cx-10+col*4,z=cz-8+row*5,slot=add(new THREE.BoxGeometry(2.2,3.1,1.45),dark,x,1.55,z),screen=add(new THREE.PlaneGeometry(1.45,.95),new THREE.MeshBasicMaterial({color:(row+col)%3===0?0xffca3a:(row+col)%3===1?0x45d9ff:0xff4ba8}),x,1.85,z+.731);screen.layers.set(1);}for(const [dx,dz] of [[-9,5],[0,6],[9,5]]){const table=add(new THREE.CylinderGeometry(2.7,2.7,.5,24),felt,cx+dx,.75,cz+dz);for(let k=0;k<6;k++){const a=k*Math.PI/3;add(new THREE.BoxGeometry(.8,.75,.8),red,cx+dx+Math.cos(a)*3.5,.38,cz+dz+Math.sin(a)*3.5);}}const roulette=add(new THREE.CylinderGeometry(2.4,2.4,.6,32),red,cx-7,.85,cz+13),wheel=add(new THREE.TorusGeometry(1.55,.28,10,28),gold,cx-7,1.55,cz+13);wheel.rotation.x=Math.PI/2;const stage=add(new THREE.CylinderGeometry(5.2,5.2,.55,32),red,cx+8,.28,cz+14);for(const sx of [-3.2,0,3.2]){const beam=add(new THREE.BoxGeometry(.25,5,.25),neon,cx+8+sx,2.5,cz+14);beam.rotation.z=sx*.025;}const bar=add(new THREE.BoxGeometry(W*.4,1.6,2.6),gold,cx,.8,cz-H*.3);for(let k=-4;k<=4;k++)add(new THREE.CylinderGeometry(.42,.52,.72,12),red,cx+k*2.4,.36,cz-H*.3+2.2);const gallery=add(new THREE.BoxGeometry(W*.25,.45,H*.42),new THREE.MeshStandardMaterial({color:0x32152c,roughness:.78}),cx-W*.34,4.2,cz);for(let s=0;s<7;s++){const step=add(new THREE.BoxGeometry(3.2,.35,2.1),gold,cx-W*.18+s*.75,.18+s*.35,cz+H*.2-s*.75);step.layers.set(1);}const vip=add(new THREE.BoxGeometry(8,1.2,3),red,cx-W*.3,.6,cz-H*.22),safe=add(new THREE.BoxGeometry(4.5,4.2,3.2),new THREE.MeshStandardMaterial({color:0x5f6971,metalness:.82,roughness:.24}),cx+W*.32,2.1,cz-H*.26);outline(safe);const casinoLight=new THREE.PointLight(0xff35c8,14,42,2);casinoLight.position.set(cx,7,cz);casinoLight.layers.set(1);interiorGroup.add(casinoLight);for(const dx of [-W*.24,W*.24]){const warm=new THREE.PointLight(0xffd08a,22,32,2);warm.position.set(cx+dx,6,cz-H*.12);warm.layers.set(1);interiorGroup.add(warm);}};
      stage.classList.add('three-mode');
      let lastW=size.W,lastH=size.H,lastT=performance.now(),walkPhase=0,lampAnchor='',fpsAt=performance.now(),fpsFrames=0,measuredFps=60,lastShadowAt=0,lastOcclusionAt=0,dynamicAt=0,dynamicState=null,nearbyActionAt=0,nearbyActionState=null,cameraZoomMode='world',playerVisualSig='',fadedMaterials=[];
      const daySky=new THREE.Color(0x62b9ee),sunsetSky=new THREE.Color(0xe56a58),nightSky=new THREE.Color(0x071426),skyColor=new THREE.Color();
      const updateDayNight=t=>{
        // One complete showcase day lasts four minutes; later this can read the authoritative game clock.
        const serverTime=bridge?.getEnvironmentState?.();
        setTrafficSignals(serverTime?.traffic);
        const baseHour=serverTime ? serverTime.hour + serverTime.minute/60 : (t/1000)/10;
        const hour=(baseHour+timeOffset)%24,daylight=THREE.MathUtils.smoothstep(Math.sin((hour-6)/24*Math.PI*2),-.18,.42),sunset=Math.max(0,1-Math.abs(hour-19)/2.2);
        skyColor.copy(nightSky).lerp(daySky,daylight).lerp(sunsetSky,sunset*.58);scene.background.copy(skyColor);scene.fog.color.copy(skyColor);
        skyLight.color.setRGB(.4+.34*daylight,.48+.3*daylight,.68+.21*daylight);skyLight.groundColor.set(daylight>.35?0x46392e:0x293448);skyLight.intensity=1.18+1.22*daylight;
        sun.color.set(sunset>.12?0xff8a4f:0xffd69a);sun.intensity=.48+2.97*daylight;sunOffsetVector.set(Math.cos(hour/24*Math.PI*2)*75,18+daylight*72,Math.sin(hour/24*Math.PI*2)*65);
        const night=1-daylight;environmentNight=night;renderer.toneMappingExposure=1.15+daylight*.15;lampGlowMat.opacity=.01+night*.72;postMaterial.uniforms.uBloom.value=.12+night*.12;
        facadeMaterials.forEach(m=>m.emissiveIntensity=.04+night*.42);shopMaterials.forEach(m=>m.opacity=.74+night*.26);
        contactShadowMaterial.opacity=.2+daylight*.1;dynamicContactShadowMaterial.opacity=.34+daylight*.12;
        bulbMat.color.setRGB(1,.55+daylight*.28,.2+daylight*.45);streetLights.forEach(({light},i)=>{light.intensity=night*(i%2?17:25);});
        const hh=Math.floor(hour),mm=Math.floor((hour-hh)*60);clock.textContent=`${daylight>.62?'☀ День':sunset>.15?'◐ Закат':'☾ Ночь'} · ${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}`;
      };
      const animate = t => {
        if (!document.body.contains(renderer.domElement)) return;
        const s = viewSize();
        if (s.W !== lastW || s.H !== lastH) { lastW = s.W; lastH = s.H; camera.left = -cameraSpan * s.W / s.H; camera.right = cameraSpan * s.W / s.H; camera.updateProjectionMatrix(); renderer.setSize(s.W, s.H, false);postTarget.setSize(Math.max(1,Math.floor(s.W*renderPixelRatio)),Math.max(1,Math.floor(s.H*renderPixelRatio)));postMaterial.uniforms.uResolution.value.set(postTarget.width,postTarget.height); }
        const dt=Math.min(.05,(t-lastT)/1000);lastT=t;const tt=t*.00035;updateDayNight(t);windLeafMaterials.forEach(m=>{if(m.userData.shader)m.userData.shader.uniforms.mfzWindTime.value=t*.00115;});
        if(bridge&&t-nearbyActionAt>120){nearbyActionState=bridge.getNearbyBuildingInteraction?.()||null;nearbyActionAt=t;}showNearbyBuilding(nearbyActionState);
        if(waterSurface){waterSurface.position.y=.07+Math.sin(t*.0012)*.045;waterSurface.material.opacity=.88+Math.sin(t*.0017)*.035;}
        if(buildingSelectionFrame.visible){const pulse=.78+Math.sin(t*.007)*.18;selectionFrameMat.opacity=pulse;selectionCornerMat.opacity=.82+Math.sin(t*.007)*.14;entranceMarker.material.opacity=.8+Math.sin(t*.009)*.18;}
        fpsFrames++;if(t-fpsAt>=1000){measuredFps=Math.round(fpsFrames*1000/(t-fpsAt));renderer.domElement.dataset.fps=String(measuredFps);renderer.domElement.dataset.drawCalls=String(renderer.info.render.calls);renderer.domElement.dataset.triangles=String(renderer.info.render.triangles);fpsFrames=0;fpsAt=t;}
        // Keep full native render resolution. On slower devices only expensive
        // auxiliary world snapshots, raycasts and shadow-map refreshes back off;
        // movement, aiming, shooting and the authoritative Canvas simulation
        // continue to run every frame unchanged.
        const lowFps=measuredFps<24,dynamicCadence=lowFps?70:45,occlusionCadence=lowFps?240:125,shadowCadence=lowFps?420:220;
        updateAtmosphere(t,lowFps);
        renderer.domElement.dataset.performanceTier=lowFps?'cadence':'full';
        renderer.domElement.dataset.shadowCadence=String(shadowCadence);
        if(bridge&&t-dynamicAt>dynamicCadence){dynamicState=bridge.getDynamicEntities(65);syncCarSlots(dynamicState?.cars||[]);dynamicAt=t;}const dynamic=dynamicState;
        if(dynamic){
          renderer.domElement.dataset.liveCars=String(dynamic.cars.length);renderer.domElement.dataset.liveNpcs=String(dynamic.npcs.length);renderer.domElement.dataset.liveProjectiles=String(dynamic.projectiles.length);
          let trafficHeadingSamples=0,trafficHeadingMismatches=0;
          cars.forEach((car,i)=>{const src=car.userData.source;car.visible=!!src;if(!src)return;const nx=(src.c-originC)*WORLD_SCALE,nz=(src.r-originR)*WORLD_SCALE,travel=Math.hypot(nx-car.userData.lastPosition.x,nz-car.userData.lastPosition.z),model=String(src.model||'').toLowerCase(),isHeli=!!src.helicopter,police=model.includes('police')||model.includes('cop')||model.includes('paddy'),emergency=!!src.emergency,pickup=!!src.pickup,cabrio=!!src.cabrio,sport=!!src.sport,headingR=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velR:+src.dirR,headingC=Math.abs(+src.velR)+Math.abs(+src.velC)>.03?+src.velC:+src.dirC,headingLen=Math.hypot(headingR,headingC),visualYaw=headingLen>.02?Math.atan2(-headingR,headingC):-(+src.ang||0);car.position.set(nx,isHeli?5.5:0,nz);car.rotation.y=visualYaw;if(!isHeli&&headingLen>.03){trafficHeadingSamples++;const fx=Math.cos(car.rotation.y),fz=-Math.sin(car.rotation.y),dot=(fx*headingC+fz*headingR)/headingLen;if(dot<.985)trafficHeadingMismatches++;}car.userData.lastPosition.set(nx,0,nz);if(travel<5&&!isHeli)for(const wheel of car.userData.wheels)wheel.rotateY(travel/Math.max(.35,(+src.wheelR||.18)*2.65));const sx=Math.max(.82,Math.min(1.45,(+src.length||1.7)/1.7)),sz=Math.max(.82,Math.min(1.3,(+src.width||.85)/.85)),sy=Math.max(.78,Math.min(1.32,(+src.height||.55)/.55));car.scale.set(sx,isHeli?1:sy,sz);car.userData.helicopter.visible=isHeli;car.userData.rotor.rotation.y=t*.018;for(const part of [car.userData.base,car.userData.hood,...car.userData.wheels])part.visible=!isHeli;car.userData.cab.visible=!isHeli&&!cabrio&&!pickup;car.userData.cab.position.set(pickup?.75:.15,sport?1.72:(src.van||src.suv?2.2:1.95),0);car.userData.pickupBed.visible=!isHeli&&pickup;car.userData.cabrioSeats.visible=!isHeli&&cabrio;car.userData.taxiSign.visible=!isHeli&&!!src.taxi;car.userData.spoiler.visible=!isHeli&&(sport||src.muscle);car.userData.roofRack.visible=!isHeli&&(src.suv||src.van)&&!emergency;car.userData.siren.visible=!isHeli&&(police||emergency);car.userData.stripe.visible=!isHeli&&(emergency||src.gang);if(src.stripe)try{car.userData.stripe.material.color.set(src.stripe);}catch(_){}const fallbackPaint=[0xd69a2d,0x2d6e9d,0x8e2f38,0xd8d7cf,0x397b55][i%5];try{car.userData.paint.color.set(src.paint||fallbackPaint);if(car.userData.paint.color.getHex()<0x181818&&!src.gang)car.userData.paint.color.set(fallbackPaint);}catch(_){car.userData.paint.color.set(fallbackPaint);}});renderer.domElement.dataset.trafficHeadingSamples=String(trafficHeadingSamples);renderer.domElement.dataset.trafficHeadingMismatches=String(trafficHeadingMismatches);
          citizenPool.forEach((npc,i)=>{const src=dynamic.npcs[i];if(!src){npc.hpGroup.visible=false;hideNpcVisual(i);return;}const x=(src.c-originC)*WORLD_SCALE,z=(src.r-originR)*WORLD_SCALE,phase=src.walkPhase||t*.008+i*.73,idle=Math.sin(t*.0018+i*1.7),step=Math.sin(phase),bob=src.walking?Math.abs(step)*.13:idle*.018,swing=src.walking?step*.52:idle*.035,liftL=src.walking?Math.max(0,step)*.18:0,liftR=src.walking?Math.max(0,-step)*.18:0,role=String(src.role||'').toLowerCase(),armed=role.includes('gang')||role.includes('boss')||role.includes('guard')||role.includes('police')||role.includes('cop'),bodyColor=role.includes('police')||role.includes('cop')?0x3478b8:role.includes('gang')||role.includes('boss')||role.includes('guard')?0xa93c45:[0x4b9bd0,0xd86d75,0x7ca955,0xd6a04d,0x8a72b5][i%5];rootMatrix.makeRotationY(-src.ang);rootMatrix.scale(npcScale);rootMatrix.setPosition(x,bob,z);npcBodyScale.set(1,src.walking?1:1+idle*.018,1);setPart(npcParts.body,i,rootMatrix,0,2.05,0,0,npcBodyScale);setPart(npcParts.head,i,rootMatrix,0,3.3+(src.walking?0:idle*.025),0);setPart(npcParts.hair,i,rootMatrix,0,3.34,0);setPart(npcParts.leftLeg,i,rootMatrix,-.34,.64+liftL,0,swing);setPart(npcParts.rightLeg,i,rootMatrix,.34,.64+liftR,0,-swing);setPart(npcParts.shoe,i*2,rootMatrix,-.34,.09+liftL,.18,swing);setPart(npcParts.shoe,i*2+1,rootMatrix,.34,.09+liftR,.18,-swing);setPart(npcParts.leftArm,i,rootMatrix,-.78,2.05,0,-swing);setPart(npcParts.rightArm,i,rootMatrix,.78,2.05,0,swing);for(const [eyeIndex,sx] of [[i*2,-.17],[i*2+1,.17]]){setPart(npcParts.eyeWhite,eyeIndex,rootMatrix,sx,3.37,.405,0,eyeScale);setPart(npcParts.pupil,eyeIndex,rootMatrix,sx,3.37,.455,0,pupilScale);}armed?setPart(npcParts.hat,i,rootMatrix,0,3.77,0):hidePart(npcParts.hat,i);armed?setPart(npcParts.gun,i,rootMatrix,.72,2,.52):hidePart(npcParts.gun,i);instanceColor.set(bodyColor);npcParts.body.setColorAt(i,instanceColor);npcParts.leftArm.setColorAt(i,instanceColor);npcParts.rightArm.setColorAt(i,instanceColor);instanceColor.set([0xd7a17c,0x9a6649,0xe0b18e][i%3]);npcParts.head.setColorAt(i,instanceColor);const pct=Math.max(.03,Math.min(1,(+src.hp||0)/(+src.maxHp||60)));npc.hpGroup.visible=true;npc.hpGroup.position.set(x,bob+.45,z);npc.hpBar.scale.x=1.7*pct;npc.hpBar.material.color.set(pct>.55?0x58e67c:pct>.25?0xffc94d:0xff5252);});Object.values(npcParts).forEach(mesh=>{mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;});
          for(let i=0;i<NPC_CAP;i++){const src=dynamic.npcs[i],label=npcLabels[i];if(!src){label.sprite.visible=false;continue;}const x=(src.c-originC)*WORLD_SCALE,z=(src.r-originR)*WORLD_SCALE,role=String(src.role||'').toLowerCase(),gang=!!src.gang||role.includes('gang')||role.includes('boss'),police=!!src.police||role.includes('police')||role.includes('cop'),guard=role.includes('guard'),bright=police?0x328fe2:gang?0xd9364f:guard?0xc48a28:[0x3e9bd1,0xdb5c68,0x79a84f,0xd39b42,0x8a6dbe][i%5];instanceColor.set(bright);npcParts.body.setColorAt(i,instanceColor);npcParts.leftArm.setColorAt(i,instanceColor);npcParts.rightArm.setColorAt(i,instanceColor);npcParts.hat.setColorAt(i,instanceColor);updateNpcLabel(label,src,x,5.75,z);}for(const mesh of [npcParts.body,npcParts.leftArm,npcParts.rightArm,npcParts.hat])if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
          for(let i=0;i<REMOTE_CAP;i++){const src=dynamic.players[i];if(!src){Object.values(remoteParts).forEach(mesh=>hidePart(mesh,i));continue;}const x=(src.c-originC)*WORLD_SCALE,z=(src.r-originR)*WORLD_SCALE;rootMatrix.makeRotationY(-src.ang);rootMatrix.setPosition(x,0,z);setPart(remoteParts.body,i,rootMatrix,0,2.05,0);setPart(remoteParts.head,i,rootMatrix,0,3.48,0);setPart(remoteParts.hat,i,rootMatrix,0,4,0);instanceColor.set(i%2?0x586378:0x8c6847);remoteParts.body.setColorAt(i,instanceColor);remoteParts.hat.setColorAt(i,instanceColor);}Object.values(remoteParts).forEach(mesh=>{mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;});
          for(let i=0;i<BULLET_CAP;i++){const src=dynamic.projectiles[i];if(!src){hidePart(worldBullets,i);continue;}const scale=src.weapon==='rpg'?2.7:src.thick?1.55:1;instanceQuat.identity();instanceMatrix.compose(new THREE.Vector3((src.c-originC)*WORLD_SCALE,src.weapon==='rpg'?2.8:2.15,(src.r-originR)*WORLD_SCALE),instanceQuat,new THREE.Vector3(scale,scale,scale));worldBullets.setMatrixAt(i,instanceMatrix);try{worldBullets.setColorAt(i,instanceColor.set(src.color));}catch(_){worldBullets.setColorAt(i,instanceColor.set(0xffdc79));}}worldBullets.instanceMatrix.needsUpdate=true;if(worldBullets.instanceColor)worldBullets.instanceColor.needsUpdate=true;
          muzzlePool.forEach((flash,i)=>{const src=dynamic.muzzleFx[i];flash.visible=!!src;if(src){const pct=Math.max(0,Math.min(1,src.life/src.max));flash.position.set((src.c-originC)*WORLD_SCALE,2.5,(src.r-originR)*WORLD_SCALE);flash.scale.setScalar(.5+pct*1.8);flash.material.opacity=pct;try{flash.material.color.set(src.color);}catch(_){}}});
          impactPool.forEach((impact,i)=>{const src=dynamic.impactFx[i];impact.visible=!!src;if(src){const pct=Math.max(0,Math.min(1,src.life/src.max));impact.position.set((src.c-originC)*WORLD_SCALE,.55+pct*1.5,(src.r-originR)*WORLD_SCALE);impact.scale.setScalar(.35+pct*1.6);impact.rotation.y=t*.02+i;impact.material.opacity=pct;impact.material.color.set(src.blood?0xb91520:0xffd36a);}});
          explosionPool.forEach((blast,i)=>{const src=dynamic.explosionFx[i];blast.visible=!!src;if(src){const pct=Math.max(0,Math.min(1,src.age/src.life)),size=1.2+Math.sin(Math.min(1,pct)*Math.PI)*7;blast.position.set((src.c-originC)*WORLD_SCALE,2.2+size*.22,(src.r-originR)*WORLD_SCALE);blast.scale.setScalar(size);blast.material.opacity=Math.max(0,1-pct);blast.material.color.set(pct<.35?0xffed8a:pct<.7?0xff6b24:0x3b4148);}});
        }
        updateVehicleBeams();
        const move=new THREE.Vector3((keys.has('KeyD')||keys.has('ArrowRight')?1:0)-(keys.has('KeyA')||keys.has('ArrowLeft')?1:0),0,(keys.has('KeyS')||keys.has('ArrowDown')?1:0)-(keys.has('KeyW')||keys.has('ArrowUp')?1:0));
        let moving=false;
        if(bridge){
          const state=bridge.getPlayerState();
           renderer.domElement.dataset.playerR=(+state.r||0).toFixed(3);renderer.domElement.dataset.playerC=(+state.c||0).toFixed(3);renderer.domElement.dataset.playerAngle=(+state.ang||0).toFixed(3);renderer.domElement.dataset.playerHp=String(+state.hp||0);renderer.domElement.dataset.playerRole=String(state.role||'citizen');renderer.domElement.dataset.playerFamily=String(state.family||'');renderer.domElement.dataset.playerWeapon=String(state.weapon||'');renderer.domElement.dataset.playerInterior=state.interior?'1':'0';renderer.domElement.dataset.moveMode=mouseAimActive&&!state.driving?'aim-relative':'legacy';
          const visualSig=`${state.role}:${state.family||''}:${state.look?.skin??0}:${state.weapon||''}:${state.driving?1:0}`;if(visualSig!==playerVisualSig){playerVisualSig=visualSig;const roleColor=state.role==='police'?0x285c91:state.role==='mafia'?(state.family==='moretti'?0xe6e0d3:0x25272d):0x7a3035;suitMat.color.set(roleColor);skinMat.color.set([0xf0c3a0,0xd8a07c,0xb87955,0x8b583e,0x633c2d][Math.max(0,Math.min(4,+state.look?.skin||0))]);const weaponId=String(state.weapon||'').toLowerCase(),unarmed=['','none','fists','unarmed'].includes(weaponId),heavy=weaponId==='rpg'||weaponId.includes('launcher'),longGun=heavy||/(rifle|shotgun|tommy|ak|m4|smg|uzi|nagan|sniper)/.test(weaponId);gun.visible=!unarmed&&!state.driving;rpgTube.visible=heavy;for(const part of [gunReceiver,gunSlide,gunBarrel,gunMuzzle,gunGrip])part.visible=!heavy;gunMagazine.visible=!heavy&&longGun;gunStock.visible=!heavy&&longGun;gunScope.visible=!heavy&&/(rifle|sniper|m4)/.test(weaponId);gun.scale.setScalar(heavy?1.08:longGun?1.02:.72);gun.position.set(.78,longGun?2.82:2.68,longGun?.42:.62);renderer.domElement.dataset.weaponModel=heavy?'launcher':longGun?'long-gun':'pistol';}
          const hpPct=Math.max(0,Math.min(1,(+state.hp||0)/100));playerHpBar.scale.x=3.9*Math.max(.02,hpPct);playerHpBar.material.color.set(hpPct>.55?0x55e778:hpPct>.25?0xffc94d:0xff4d55);
          const interiorData=state.interior?bridge.getInteriorState?.():null,showInterior=!!(interiorData&&rendererConfig.interiorsEnabled!==false),showThree=!state.interior||showInterior;
          renderer.domElement.style.display=showThree?'block':'none';stage.classList.toggle('three-mode',showThree);
          if(showInterior){const sig=`${interiorData.kind}:${interiorData.type}:${interiorData.bizId||''}:${interiorData.room||''}:${interiorData.width}:${interiorData.height}:${interiorData.loot?`${interiorData.loot.r}:${interiorData.loot.c}:${interiorData.loot.hp?1:0}`:'none'}`;if(sig!==interiorSignature){interiorSignature=sig;rebuildInterior(interiorData);decorateCasinoInterior(interiorData);}interiorGroup.visible=true;camera.layers.set(1);activeAimSurface=interiorFloor||ground;scene.background.set(0x0a1018);scene.fog.density=0;if(cameraZoomMode!=='interior'){cameraZoomMode='interior';camera.zoom=1.08;camera.updateProjectionMatrix();}}
          else{interiorGroup.visible=false;camera.layers.set(0);activeAimSurface=ground;scene.fog.density=.0036;if(cameraZoomMode!=='world'){cameraZoomMode='world';camera.zoom=1;camera.updateProjectionMatrix();}if(!state.interior)interiorSignature='';}
          player.visible=!state.driving;
          const tx=(state.c-originC)*WORLD_SCALE,tz=(state.r-originR)*WORLD_SCALE;
          const delta=Math.hypot(tx-player.position.x,tz-player.position.z);
          player.position.x=THREE.MathUtils.lerp(player.position.x,tx,Math.min(1,dt*14));player.position.z=THREE.MathUtils.lerp(player.position.z,tz,Math.min(1,dt*14));syncMouseAim();
          player.rotation.y=Math.atan2(Math.cos(state.ang),Math.sin(state.ang));moving=state.walking||delta>.025;walkPhase=state.walkPhase||walkPhase;
          const env=bridge.getEnvironmentState(),ar=Math.floor(state.r/10)*10,ac=Math.floor(state.c/10)*10,newAnchor=`${ar}:${ac}`;
          if(newAnchor!==lampAnchor){lampAnchor=newAnchor;const px=(state.c-originC)*WORLD_SCALE,pz=(state.r-originR)*WORLD_SCALE,nearest=fixedLampDefs.map(([x,z])=>({x,z,d:(x-px)**2+(z-pz)**2})).sort((a,b)=>a.d-b.d).slice(0,streetLights.length);streetLights.forEach((lamp,i)=>{const spot=nearest[i];lamp.light.visible=!!spot;if(spot)lamp.light.position.set(spot.x,6.7,spot.z);});}
        }else if(move.lengthSq()>0){move.normalize();player.position.addScaledVector(move,12*dt);player.position.x=Math.max(-34,Math.min(34,player.position.x));player.position.z=Math.max(-34,Math.min(34,player.position.z));player.rotation.y=Math.atan2(move.x,move.z);walkPhase+=dt*12;moving=true;}
        const playerStep=Math.sin(walkPhase),idleBreath=Math.sin(t*.0022);if(moving){if(!bridge)walkPhase+=0;leftLeg.rotation.x=playerStep*.68;rightLeg.rotation.x=-playerStep*.68;leftArm.rotation.x=-playerStep*.42;rightArm.rotation.x=playerStep*.3;leftLeg.position.y=.88+Math.max(0,playerStep)*.2;rightLeg.position.y=.88+Math.max(0,-playerStep)*.2;body.rotation.z=playerStep*.025;}else{leftLeg.rotation.x*=.72;rightLeg.rotation.x*=.72;leftArm.rotation.x=idleBreath*.025;rightArm.rotation.x=-idleBreath*.02;leftLeg.position.y=THREE.MathUtils.lerp(leftLeg.position.y,.88,.18);rightLeg.position.y=THREE.MathUtils.lerp(rightLeg.position.y,.88,.18);body.rotation.z*=.72;head.rotation.y=Math.sin(t*.00065)*.055;}
        body.scale.y=moving?1:1+idleBreath*.018;body.position.y=2.65+(moving?0:idleBreath*.025);player.position.y=.08+Math.abs(playerStep)*(moving?.09:0);updateWeather(dt,t);
        for(let i=bullets.length-1;i>=0;i--){const b=bullets[i];b.mesh.position.addScaledVector(b.vel,dt);b.life-=dt;if(b.life<=0){scene.remove(b.mesh);b.mesh.geometry.dispose();b.mesh.material.dispose();bullets.splice(i,1);}}
        if(muzzleLife>0){muzzleLife-=dt;muzzle.intensity=42*Math.max(0,muzzleLife/.075);}else muzzle.intensity=0;
        camera.position.set(player.position.x+54,62,player.position.z+54);camera.lookAt(player.position.x,1.6,player.position.z);
        sun.position.copy(player.position).add(sunOffsetVector);sun.target.position.set(player.position.x,0,player.position.z);sun.target.updateMatrixWorld();
        // Occlusion is spatially stable while walking; checking it at 8 Hz avoids
        // 105 building ray tests and hundreds of material writes every frame.
        if(t-lastOcclusionAt>occlusionCadence){
          for(const m of fadedMaterials){m.opacity=1;m.depthWrite=true;}fadedMaterials=[];
          const sight=new THREE.Vector3().subVectors(player.position,camera.position),sightDistance=sight.length();
          const sightRay=new THREE.Raycaster(camera.position,sight.normalize(),.1,sightDistance);
          const blockers=sightRay.intersectObjects(occluders,false).filter(hit=>hit.distance>sightDistance-34).slice(0,2);
          for(const hit of blockers){if(hit.object===highlightedBuildingObject||hit.object.userData.building===highlightedBuildingObject?.userData?.building)continue;for(const m of hit.object.userData.fadeMaterials){m.transparent=true;m.opacity=.22;m.depthWrite=false;fadedMaterials.push(m);}}
          lastOcclusionAt=t;
        }
        if(!dynamic){cars.slice(0,3).forEach(x=>x.visible=true);cars[0].position.x = -30 + (tt * 13) % 60; cars[1].position.z = 29 - (tt * 11) % 58; cars[2].position.x = 27 - (tt * 9) % 54;}
        if(t-lastShadowAt>shadowCadence){renderer.shadowMap.needsUpdate=true;lastShadowAt=t;}
        if(lowFps){renderer.setRenderTarget(null);renderer.render(scene,camera);}
        else{renderer.setRenderTarget(postTarget);renderer.render(scene,camera);renderer.setRenderTarget(null);renderer.render(postScene,postCamera);}
        requestAnimationFrame(animate);
      };
      requestAnimationFrame(animate);
      console.info('[ThreePreview] procedural 3D city enabled');
    } catch (error) {
      stage.classList.remove('three-mode');
      document.getElementById('threeCinematicGrade')?.remove();
      document.body.dataset.threeError=String(error?.stack||error?.message||error).slice(0,1200);
      console.warn('[ThreePreview] Canvas fallback:', error);
    }
  })();
}
