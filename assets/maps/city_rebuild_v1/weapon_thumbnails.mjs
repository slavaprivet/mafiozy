import {createWeaponModel} from './hero_arsenal.mjs';

// Menu-only clenched hand. The actual unarmed prop remains empty and never
// replaces the character's rigged fingers or changes weapon grip attachments.
export function createWeaponFistModel(THREE){
 const root=new THREE.Group();root.name='weapon_menu_fist';root.weaponId='none';root.userData={menuOnly:true,gesture:'clenched_fist'};
 const skin=new THREE.MeshStandardMaterial({color:0xcc9474,roughness:.66,metalness:0}),knuckle=new THREE.MeshStandardMaterial({color:0xdda786,roughness:.61,metalness:0}),crease=new THREE.MeshStandardMaterial({color:0xa96e52,roughness:.85,metalness:0}),cuff=new THREE.MeshStandardMaterial({color:0x242b34,roughness:.83,metalness:0});
 const oval=(name,material,x,y,z,sx,sy,sz)=>{const mesh=new THREE.Mesh(new THREE.SphereGeometry(1,20,14),material);mesh.name=name;mesh.position.set(x,y,z);mesh.scale.set(sx,sy,sz);root.add(mesh);return mesh};
 const fold=(name,from,to,r=.006)=>{const start=new THREE.Vector3(...from),end=new THREE.Vector3(...to),delta=end.clone().sub(start);const mesh=new THREE.Mesh(new THREE.CylinderGeometry(r,r,delta.length(),8),crease);mesh.name=name;mesh.position.copy(start).add(end).multiplyScalar(.5);mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),delta.normalize());root.add(mesh)};
 oval('palm',skin,.005,.02,0,.15,.205,.245);
 oval('wrist',skin,.03,-.235,-.025,.113,.14,.137);
 oval('sleeve_cuff',cuff,.04,-.345,-.025,.139,.079,.16);
 // Knuckles form a shallow descending arch, not four identical floating beads.
 for(const [index,z,top,width] of [[0,-.186,.13,.071],[1,-.069,.176,.078],[2,.067,.164,.079],[3,.193,.115,.069]]){
  oval(`finger_${index}_knuckle`,knuckle,-.109,top,z,.114,.104,width);
  const finger=oval(`finger_${index}_folded`,skin,-.158,top-.12,z,.088,.107,width*.94);finger.rotation.z=-.13;
  oval(`finger_${index}_tip`,skin,-.119,top-.201,z,.066,.059,width*.88);
  fold(`finger_${index}_joint_crease`,[-.239,top-.07,z-width*.54],[-.245,top-.082,z+width*.49],.0045);
 }
 // The thumb crosses over the curled index/middle fingers on the near side.
 oval('thumb_base',skin,-.038,-.093,.229,.13,.132,.082).rotation.x=-.3;
 const thumb=oval('thumb_wrap',knuckle,-.198,-.094,.187,.095,.075,.147);thumb.rotation.x=.28;thumb.rotation.y=-.25;
 oval('thumb_tip',knuckle,-.23,-.058,.087,.077,.071,.068);
 fold('thumb_joint_crease',[-.282,-.075,.123],[-.271,-.035,.144],.004);
 root.updateMatrixWorld(true);return root;
}

// The menu photographs the actual held/dropped prop; there is no second set of gun art.
export function frameWeaponThumbnail(THREE,model,aspect=2){
 const bounds=new THREE.Box3().setFromObject(model),center=bounds.getCenter(new THREE.Vector3());
 model.position.sub(center);model.updateMatrixWorld(true);
 const camera=new THREE.OrthographicCamera(-1,1,1,-1,.01,100);
 camera.position.set(-4,1.3,1.5);camera.lookAt(0,0,0);camera.updateMatrixWorld(true);
 bounds.setFromObject(model);const point=new THREE.Vector3();let halfX=0,halfY=0;
 for(const x of [bounds.min.x,bounds.max.x])for(const y of [bounds.min.y,bounds.max.y])for(const z of [bounds.min.z,bounds.max.z]){
  point.set(x,y,z).applyMatrix4(camera.matrixWorldInverse);halfX=Math.max(halfX,Math.abs(point.x));halfY=Math.max(halfY,Math.abs(point.y));
 }
 const halfHeight=Math.max(halfY,halfX/aspect,.1)*1.16;
 camera.left=-halfHeight*aspect;camera.right=halfHeight*aspect;camera.top=halfHeight;camera.bottom=-halfHeight;camera.updateProjectionMatrix();
 return camera;
}

function disposeObject(root){
 const geometries=new Set(),materials=new Set();root.traverse(node=>{if(node.geometry)geometries.add(node.geometry);for(const material of (Array.isArray(node.material)?node.material:[node.material]))if(material)materials.add(material)});
 for(const geometry of geometries)geometry.dispose();for(const material of materials)material.dispose();
}

export function createWeaponThumbnailRenderer({THREE,document:doc=globalThis.document,width=512,height=256}={}){
 const cache=new Map();let renderer=null,scene=null,environment=null,disposed=false,failed=false;
 function initialize(){
  if(renderer||failed||disposed||!THREE?.WebGLRenderer||!doc?.createElement)return false;
  try{
   renderer=new THREE.WebGLRenderer({canvas:doc.createElement('canvas'),alpha:true,antialias:true,preserveDrawingBuffer:true});
   renderer.setPixelRatio(1);renderer.setSize(width,height,false);renderer.setClearColor(0x000000,0);
   if(THREE.SRGBColorSpace)renderer.outputColorSpace=THREE.SRGBColorSpace;
   renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.2;
   scene=new THREE.Scene();scene.add(new THREE.HemisphereLight(0xe3efff,0x434047,2));
   for(const [color,intensity,x,y,z] of [[0xfff1d6,3,-3,5,4],[0xb5d5ff,2,4,2,-3],[0xffffff,1.5,-2,1,-4]]){const light=new THREE.DirectionalLight(color,intensity);light.position.set(x,y,z);scene.add(light)}
   // Large studio softboxes give real metal reflections instead of flat black receivers.
   if(THREE.PMREMGenerator){
    const studio=new THREE.Scene();studio.background=new THREE.Color(0x555960);
    for(const [x,y,z,sx,sy,color] of [[-4,3,1,5,3,0xffffff],[4,2,-2,3,5,0xb9cce8],[0,5,0,4,4,0xffe5bc]]){
     const panel=new THREE.Mesh(new THREE.PlaneGeometry(sx,sy),new THREE.MeshBasicMaterial({color,side:THREE.DoubleSide}));panel.position.set(x,y,z);panel.lookAt(0,0,0);studio.add(panel);
    }
    const pmrem=new THREE.PMREMGenerator(renderer);environment=pmrem.fromScene(studio,.04,.1,100);scene.environment=environment.texture;pmrem.dispose();disposeObject(studio);
   }
   return true;
  }catch{failed=true;environment?.dispose();renderer?.dispose();renderer?.forceContextLoss?.();renderer=null;return false}
 }
 return {
  render(id){
   if(disposed)return null;if(cache.has(id))return cache.get(id);
   if(!renderer&&!initialize())return null;
   let model=null;
   try{model=id==='none'?createWeaponFistModel(THREE):createWeaponModel({THREE,id});const camera=frameWeaponThumbnail(THREE,model,width/height);scene.add(model);renderer.render(scene,camera);const url=renderer.domElement.toDataURL('image/png');cache.set(id,url);return url}
   catch{return null}
   finally{if(model){scene.remove(model);disposeObject(model)}}
  },
  dispose(){if(disposed)return;disposed=true;cache.clear();environment?.dispose();renderer?.dispose();renderer?.forceContextLoss?.();scene=null;renderer=null},
  get size(){return cache.size},
 };
}
