import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js';

const SKINS=[0xf0c3a0,0xd8a07c,0xb87955,0x8b583e,0x633c2d,0xf4cbb1];
const SUITS=[0x74262c,0x294761,0x31563f,0x6b5430,0x47345f,0x35383f,0x80502c,0x1f5360];
const TROUSERS=[0x151922,0x202731,0x1c2a22,0x2d2924,0x211c2d,0x181a1d,0x30231b,0x14292d];
const HAIRS=[0x251a17,0x120f0d,0x56351f,0xb17a3d,0xd6b46d,0x6c241f,0x241a35,0xd9d6cd,0x101923,0x8a4b24];
const HATS=[0x171a20,0x54331f,0x263c5a,0x6d252c,0xc9b98d,0x31543b,0x20242a,0x8c6a30,0x0b0c0f,0x4f315e];

function material(color,roughness=.62){return new THREE.MeshStandardMaterial({color,roughness,metalness:.08});}
function part(geometry,mat,x,y,z,parent,cast=true){const mesh=new THREE.Mesh(geometry,mat);mesh.position.set(x,y,z);mesh.castShadow=cast;parent.add(mesh);return mesh;}
function disposeObject(root){root.traverse(o=>{o.geometry?.dispose?.();if(Array.isArray(o.material))o.material.forEach(m=>m.dispose?.());else o.material?.dispose?.();});}

function buildCharacter(rawLook={},options={}){
  const look={gender:+rawLook.gender||0,skin:+rawLook.skin||0,body:+rawLook.body||0,face:+rawLook.face||0,hair:+rawLook.hair||0,hat:+rawLook.hat||0};
  const root=new THREE.Group(),female=look.gender===1,bodyId=Math.abs(look.body)%4,faceId=Math.abs(look.face)%10,hairId=Math.abs(look.hair)%10,hatId=Math.abs(look.hat)%10;
  const authoredSuit=options.suit||SUITS[Math.abs(look.body)%SUITS.length],authoredAccent=options.accent||HATS[hatId];
  const skin=material(SKINS[Math.abs(look.skin)%SKINS.length],.68),skinDark=material(new THREE.Color(SKINS[Math.abs(look.skin)%SKINS.length]).multiplyScalar(.72),.8),suit=material(authoredSuit,.54),suitDark=material(new THREE.Color(authoredSuit).multiplyScalar(.56),.66),shirt=material(female?0xf0d9d8:0xe8e5dc,.72),trousers=material(options.boss?new THREE.Color(authoredSuit).multiplyScalar(.25):TROUSERS[Math.abs(look.body)%TROUSERS.length],.68),hairMat=material(HAIRS[hairId],.82),hatMat=material(options.boss?authoredAccent:HATS[hatId],.58),metal=material(options.boss?authoredAccent:0xd1a84b,.24),black=material(0x111318,.8),white=new THREE.MeshBasicMaterial({color:0xf8f8f3}),iris=new THREE.MeshBasicMaterial({color:[0x24384a,0x4b3829,0x31543a,0x202124][faceId%4]}),red=material(female?0xa92f44:0x603029,.7);
  const profiles=[
    {shoulder:1.30,waist:1.02,hip:1.08,depth:.76,arm:.31,leg:.39,torsoY:.98},
    {shoulder:1.62,waist:1.36,hip:1.34,depth:.96,arm:.42,leg:.49,torsoY:1},
    {shoulder:1.82,waist:1.82,hip:1.72,depth:1.30,arm:.52,leg:.60,torsoY:1.02},
    {shoulder:2.02,waist:1.28,hip:1.42,depth:1.08,arm:.56,leg:.55,torsoY:1.04}
  ],shape=profiles[bodyId],shoulderScale=female?.82:1,waistScale=female?.76:1,hipScale=female?1.06:1,depthScale=female?.94:1;
  const torso=part(new THREE.CapsuleGeometry(.66,1.02,8,18),suit,0,2.69,0,root);
  torso.scale.set(shape.shoulder*shoulderScale/1.32,shape.torsoY,shape.depth*depthScale/1.32);
  const waist=part(new THREE.CapsuleGeometry(.39,.34,6,16),suitDark,0,1.62,0,root);
  waist.scale.set(shape.waist*waistScale/.78,1,shape.depth*depthScale*.91/.78);
  const hips=part(new THREE.SphereGeometry(.58,18,12),trousers,0,1.34,0,root);
  hips.scale.set(shape.hip*hipScale/1.16,female?.66:.56,shape.depth*depthScale*.92/1.16);
  const neck=part(new THREE.CylinderGeometry(.25,.29,.42,14),skin,0,3.79,0,root);
  if(bodyId===2){const belly=part(new THREE.SphereGeometry(.68,18,12),suit,0,2.2,.09,root);belly.scale.set(shape.waist*(female?.88:1)/1.28,.86,shape.depth*depthScale/1.24);}
  if(bodyId===3){const chest=part(new THREE.SphereGeometry(.73,18,12),suit,0,3.04,.02,root);chest.scale.set(shape.shoulder*shoulderScale/1.38,.72,shape.depth*depthScale/1.38);}
  if(female){for(const sx of [-.28,.28]){const bust=part(new THREE.SphereGeometry(.34,16,11),suit,sx,2.98,shape.depth*.34,root);bust.scale.set(.9,.72,.62);}}
  const garmentFront=shape.depth*depthScale/2+(female?.15:.03),shirtFront=part(new THREE.BoxGeometry(female?.5:.58,1.48,.055),shirt,0,2.76,garmentFront,root,false),lapelX=female?.27:.31,leftLapel=part(new THREE.BoxGeometry(female?.22:.26,.86,.07),suitDark,-lapelX,3.06,garmentFront+.045,root,false),rightLapel=leftLapel.clone();rightLapel.position.x=lapelX;leftLapel.rotation.z=-.38;rightLapel.rotation.z=.38;root.add(rightLapel);
  const belt=part(new THREE.BoxGeometry(shape.waist*waistScale+.08,.15,shape.depth*depthScale+.04),black,0,1.43,0,root),buckle=part(new THREE.BoxGeometry(.25,.18,.08),metal,0,1.43,shape.depth*depthScale/2+.06,root,false);
  const head=part(new THREE.SphereGeometry(.69,24,18),skin,0,4.32,0,root);head.scale.set((female?.94:1)*(faceId===7?1.08:faceId===5?.94:1),faceId===1?1.08:faceId===6?.94:1,female?.95:1);
  const chin=part(new THREE.SphereGeometry(.28,14,10),skinDark,0,3.88,.18,root);chin.scale.set(faceId===7?1.22:1,faceId===1?1.12:.72,.88);
  if(faceId===6||faceId===7){for(const sx of [-.43,.43]){const cheek=part(new THREE.SphereGeometry(.23,12,8),skin,sx,4.18,.49,root);cheek.scale.set(faceId===7?1.12:.92,.72,.62);}}
  for(const sx of [-.245,.245]){const eye=part(new THREE.SphereGeometry(.13,14,9),white,sx,4.42,.63,root,false);eye.scale.set(faceId===1?1.08:1,faceId===5?.62:.78,.42);const pupil=part(new THREE.SphereGeometry(.064,10,7),iris,sx,4.42,.69,root,false);pupil.scale.z=.45;}
  const nose=part(new THREE.ConeGeometry(.095+(faceId%3)*.014,.3,10),skinDark,0,4.19,.72,root);nose.rotation.x=Math.PI/2;
  const mouth=part(new THREE.BoxGeometry(faceId===3?.34:.25,faceId===3?.07:.035,.035),faceId===3?red:black,0,3.99,.69,root,false);mouth.rotation.z=faceId===5?-.18:faceId===6?.12:0;
  const browTilt=[0,.28,-.08,.05,.12,-.28,-.18,.1,.02,.2][faceId];for(const sx of [-.245,.245]){const brow=part(new THREE.BoxGeometry(.27,.045,.04),hairMat,sx,4.6,.68,root,false);brow.rotation.z=sx>0?-browTilt:browTilt;}
  if(female){for(const sx of [-.245,.245]){for(const dx of [-.07,.07]){const lash=part(new THREE.BoxGeometry(.1,.022,.025),black,sx+dx,4.53,.704,root,false);lash.rotation.z=sx>0?-dx*2:dx*2;}}part(new THREE.BoxGeometry(.24,.055,.03),red,0,3.99,.71,root,false);for(const sx of [-.73,.73])part(new THREE.SphereGeometry(.055,9,7),metal,sx,4.14,.04,root,false);}
  const earGeo=new THREE.SphereGeometry(.14,10,7);for(const sx of [-.69,.69]){const ear=part(earGeo,skin,sx,4.29,0,root);ear.scale.set(.55,1,.55);}
  if(!female&&faceId===2){const beard=part(new THREE.SphereGeometry(.7,20,12,0,Math.PI*2,Math.PI*.46,Math.PI*.38),hairMat,0,4.22,.01,root);beard.scale.set(1.01,1.05,1.01);}
  if(!female&&faceId===3){for(const sx of [-.13,.13]){const moustache=part(new THREE.CapsuleGeometry(.045,.2,4,8),hairMat,sx,4.08,.705,root,false);moustache.rotation.z=sx>0?-.88:.88;}}
  if(faceId===4){const scar=part(new THREE.BoxGeometry(.035,.48,.028),red,.35,4.32,.688,root,false);scar.rotation.z=-.45;for(let i=-1;i<=1;i++){const stitch=part(new THREE.BoxGeometry(.12,.022,.026),red,.35+i*.055,4.32-i*.075,.702,root,false);stitch.rotation.z=.72;}}
  if(faceId===7){const bruise=part(new THREE.TorusGeometry(.155,.035,7,18),red,-.245,4.42,.695,root,false);bruise.scale.y=.72;const bandage=part(new THREE.BoxGeometry(.18,.055,.035),shirt,.08,4.2,.744,root,false);bandage.rotation.z=-.2;}
  if(faceId===8){const cigarette=part(new THREE.CylinderGeometry(.025,.025,.48,8),white,.22,3.96,.82,root,false);cigarette.rotation.z=Math.PI/2;part(new THREE.SphereGeometry(.035,8,6),red,.47,3.96,.82,root,false);}
  if(faceId===9){const tattoo=part(new THREE.TorusGeometry(.13,.025,6,12,Math.PI*1.45),black,-.37,4.26,.68,root,false);tattoo.rotation.z=.35;}
  const legX=shape.hip*hipScale*.3,legRadius=shape.leg*(female?.45:.49),armRadius=shape.arm*(female?.43:.48),armX=shape.shoulder*shoulderScale*.58;
  for(const sx of [-1,1]){
    part(new THREE.CapsuleGeometry(legRadius,.58,6,12),trousers,sx*legX,1.02,0,root);
    const knee=part(new THREE.SphereGeometry(legRadius*.94,12,8),trousers,sx*legX,.66,0,root);knee.scale.z=.94;
    part(new THREE.CapsuleGeometry(legRadius*.86,.48,6,12),trousers,sx*legX,.35,0,root);
    const shoe=part(new THREE.BoxGeometry(shape.leg+.12,.25,.86),black,sx*legX,.08,.18,root);shoe.position.z=.13;
    const shoulder=part(new THREE.SphereGeometry(armRadius*1.12,14,9),suit,sx*armX,3.34,0,root);shoulder.scale.set(1.1,.92,1);
    part(new THREE.CapsuleGeometry(armRadius,.56,6,12),suit,sx*armX,2.91,0,root);
    part(new THREE.SphereGeometry(armRadius*.92,12,8),suitDark,sx*armX,2.5,0,root);
    const forearm=part(new THREE.CapsuleGeometry(armRadius*.86,.48,6,12),suit,sx*armX,2.12,0,root);forearm.rotation.z=sx*(bodyId===3?.025:.012);
    const hand=part(new THREE.SphereGeometry(Math.max(.2,armRadius*.92),14,10),skin,sx*armX,1.68,0,root);hand.scale.set(.88,1.08,.76);
  }
  if(bodyId===3){for(const sx of [-1,1]){const seam=part(new THREE.BoxGeometry(.08,.65,.035),metal,sx*.54*shoulderScale,2.8,shape.depth*depthScale/2+.065,root,false);seam.rotation.z=sx*.22;}}

  const hairGroup=new THREE.Group();root.add(hairGroup);
  const hairCap=()=>part(new THREE.SphereGeometry(.705,22,13,0,Math.PI*2,0,Math.PI*.5),hairMat,0,4.39,0,hairGroup);
  if(hairId===1){const cap=hairCap();cap.scale.set(1,.48,1);cap.rotation.x=-.14;part(new THREE.BoxGeometry(1.05,.18,.62),hairMat,0,4.82,-.08,hairGroup);}
  else if(hairId===2){for(const [x,y,s] of [[-.36,4.75,.34],[0,4.87,.42],[.36,4.76,.34]])part(new THREE.SphereGeometry(s,14,10),hairMat,x,y,-.02,hairGroup);}
  else if(hairId===3){for(let z=-.42;z<=.42;z+=.21){const spike=part(new THREE.ConeGeometry(.16,.46,8),hairMat,0,4.87,z,hairGroup);spike.position.y+=Math.cos(z*3)*.08;}}
  else if(hairId===4){const cap=hairCap();cap.scale.y=.56;for(const sx of [-.42,-.14,.14,.42]){const crop=part(new THREE.BoxGeometry(.18,.2,.2),hairMat,sx,4.72,.48,hairGroup);crop.rotation.z=-sx*.18;}}
  else if(hairId===5){hairCap();const back=part(new THREE.CapsuleGeometry(.32,1.25,7,12),hairMat,0,3.69,-.5,hairGroup);back.scale.x=1.55;for(const sx of [-.57,.57])part(new THREE.CapsuleGeometry(.14,.88,6,10),hairMat,sx,3.93,-.04,hairGroup);}
  else if(hairId===6){for(const [x,y,z] of [[-.48,4.56,0],[0,4.77,-.05],[.48,4.56,0],[-.38,4.35,-.42],[.38,4.35,-.42],[0,4.52,-.5]])part(new THREE.SphereGeometry(.31,12,9),hairMat,x,y,z,hairGroup);}
  else if(hairId===7){const cap=hairCap();cap.scale.set(.72,.72,.88);cap.position.x=.12;part(new THREE.BoxGeometry(.92,.25,.7),hairMat,.12,4.78,-.02,hairGroup);}
  else if(hairId===8){const cap=hairCap();cap.scale.y=.58;cap.rotation.z=.15;const fringe=part(new THREE.BoxGeometry(.55,.42,.16),hairMat,-.24,4.58,.57,hairGroup);fringe.rotation.z=-.24;}
  else if(hairId===9){const cap=hairCap();cap.scale.set(1,.23,1);for(let i=-2;i<=2;i++){const ridge=part(new THREE.BoxGeometry(.055,.08,.82),hairMat,i*.22,4.72,-.02,hairGroup);ridge.rotation.z=i*.025;}}

  const coversHair=[1,2,3,4,7,8].includes(hatId);
  if(coversHair&&hairId!==0){
    hairGroup.visible=false;
    for(const sx of [-1,1]){const lock=part(new THREE.CapsuleGeometry(.075,.26,5,8),hairMat,sx*.59,4.35,-.08,root);lock.rotation.z=sx*.08;}
    if(hairId===5){const tuckedBack=part(new THREE.CapsuleGeometry(.22,.72,6,10),hairMat,0,3.87,-.53,root);tuckedBack.scale.x=1.35;}
  }

  if([1,2,4,7,8].includes(hatId)){
    if(hatId===2){const crown=part(new THREE.SphereGeometry(.72,18,10,0,Math.PI*2,0,Math.PI*.5),hatMat,0,4.57,0,root);crown.scale.y=.62;const peak=part(new THREE.BoxGeometry(.82,.08,.48),hatMat,0,4.67,.58,root);peak.rotation.x=.08;}
    else if(hatId===7){const beret=part(new THREE.SphereGeometry(.76,18,10),hatMat,-.08,4.83,0,root);beret.scale.set(1,.25,.88);part(new THREE.CylinderGeometry(.025,.025,.18,7),hatMat,-.25,5.04,0,root);}
    else {const wide=hatId===4?1.12:hatId===8?1.02:.9,brim=part(new THREE.CylinderGeometry(wide,wide,.1,24),hatMat,0,4.86,0,root),top=part(new THREE.CylinderGeometry(hatId===4?.48:.57,hatId===4?.65:.67,hatId===8?.68:.53,22),hatMat,0,5.16,0,root);if(hatId===4){brim.scale.z=.78;top.rotation.z=.05;}if(hatId===8){part(new THREE.BoxGeometry(1.18,.12,.72),red,0,4.99,0,root);}}
  } else if(hatId===3){const band=part(new THREE.CylinderGeometry(.71,.71,.23,22),hatMat,0,4.64,0,root);const tail=part(new THREE.BoxGeometry(.22,.75,.08),hatMat,.48,4.35,-.52,root);tail.rotation.z=-.25;}
  else if(hatId===5){for(const sx of [-.25,.25]){const lens=part(new THREE.TorusGeometry(.2,.035,8,18),black,sx,4.42,.72,root,false);lens.scale.y=.82;}part(new THREE.BoxGeometry(.18,.035,.035),black,0,4.42,.72,root,false);}
  else if(hatId===6){part(new THREE.CylinderGeometry(.71,.71,.13,22),red,0,4.56,0,root);}
  else if(hatId===9){const chainFront=Math.max(.62,shape.depth*depthScale*.63+.17),chain=part(new THREE.TorusGeometry(.5,.055,8,24,Math.PI),metal,0,3.6,chainFront,root,false);chain.scale.x=Math.min(1.22,shape.shoulder*shoulderScale/1.55);chain.rotation.z=Math.PI;}
  if(options.boss){
    const weapon=String(options.weapon||'pistol'),longGun=/rifle|sniper|shotgun|tommy|smg/.test(weapon),gun=new THREE.Group();root.add(gun);
    gun.position.set(.72,2.12,.62);gun.rotation.z=longGun?-.22:-.08;
    part(new THREE.BoxGeometry(longGun?.22:.26,longGun?1.12:.58,.18),black,0,0,0,gun);
    part(new THREE.CylinderGeometry(longGun?.055:.045,longGun?.055:.045,longGun?.88:.45,10),metal,0,longGun?.94:.48,0,gun);
    const grip=part(new THREE.BoxGeometry(.18,.42,.14),suitDark,-.06,longGun?-.65:-.38,0,gun);grip.rotation.z=.25;
    if(longGun)part(new THREE.BoxGeometry(.34,.58,.2),material(authoredSuit,.52),0,-.83,0,gun);
    for(const sx of [-1,1]){const lapel=part(new THREE.BoxGeometry(.25,.92,.07),metal,sx*.29,3.05,garmentFront+.06,root,false);lapel.rotation.z=sx*.38;}
  }
  root.userData.look=look;
  return root;
}

function makeScene(){
  const scene=new THREE.Scene();
  const camera=new THREE.PerspectiveCamera(24,300/390,.1,50);camera.position.set(0,3.05,13.2);camera.lookAt(0,2.55,0);
  scene.add(new THREE.HemisphereLight(0xffe1b5,0x172233,2.15));
  const key=new THREE.DirectionalLight(0xffd09a,3.4);key.position.set(-4,7,6);scene.add(key);
  const rim=new THREE.DirectionalLight(0x8cb9ff,2.1);rim.position.set(5,4,-4);scene.add(rim);
  const floor=new THREE.Mesh(new THREE.CircleGeometry(2.3,40),new THREE.MeshStandardMaterial({color:0x111318,roughness:.94,transparent:true,opacity:.88}));floor.rotation.x=-Math.PI/2;floor.position.y=.01;scene.add(floor);
  return {scene,camera};
}

function createRenderer(canvas,alpha=true){const renderer=new THREE.WebGLRenderer({canvas,alpha,antialias:true,preserveDrawingBuffer:true,powerPreference:'low-power'});renderer.setPixelRatio(Math.min(1.5,devicePixelRatio||1));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.08;renderer.setClearColor(0x000000,0);return renderer;}

let snapshot=null;
function paint(canvas,look={},options={}){
  if(!canvas)return false;
  if(!snapshot){const source=document.createElement('canvas');source.width=300;source.height=390;const base=makeScene();snapshot={source,renderer:createRenderer(source),...base,character:null};}
  const width=Math.max(48,canvas.width||300),height=Math.max(64,canvas.height||390),close=options.crop==='face';snapshot.source.width=width;snapshot.source.height=height;snapshot.renderer.setSize(width,height,false);snapshot.camera.aspect=width/height;snapshot.camera.position.set(0,close?4.34:3.05,close?7.1:13.2);snapshot.camera.lookAt(0,close?4.18:2.55,0);snapshot.camera.updateProjectionMatrix();
  if(snapshot.character){snapshot.scene.remove(snapshot.character);disposeObject(snapshot.character);}snapshot.character=buildCharacter(look,options);snapshot.character.rotation.y=Number.isFinite(+options.angle)?+options.angle:0;snapshot.scene.add(snapshot.character);snapshot.renderer.render(snapshot.scene,snapshot.camera);
  const ctx=canvas.getContext('2d');ctx.clearRect(0,0,width,height);ctx.drawImage(snapshot.source,0,0,width,height);return true;
}

function attach(canvas,look={},options={}){
  const renderer=createRenderer(canvas),base=makeScene();let character=buildCharacter(look,options),angle=+options.angle||0,disposed=false,frame=0;character.rotation.y=angle;base.scene.add(character);
  const resize=()=>{const width=Math.max(1,canvas.width||300),height=Math.max(1,canvas.height||390);renderer.setSize(width,height,false);base.camera.aspect=width/height;base.camera.updateProjectionMatrix();};resize();
  const render=()=>{if(disposed)return;character.rotation.y=angle+(options.idle===false?0:Math.sin(performance.now()*.00055)*.08);renderer.render(base.scene,base.camera);if(options.animate!==false)frame=requestAnimationFrame(render);};render();
  return {setLook(next){base.scene.remove(character);disposeObject(character);character=buildCharacter(next||{},options);character.rotation.y=angle;base.scene.add(character);if(options.animate===false)render();},setAngle(next){angle=+next||0;if(options.animate===false)render();},dispose(){disposed=true;cancelAnimationFrame(frame);base.scene.remove(character);disposeObject(character);renderer.dispose();}};
}

window.MafioziCharacter3D=Object.freeze({paint,attach});
window.dispatchEvent(new CustomEvent('mafiozi:character3dready'));
