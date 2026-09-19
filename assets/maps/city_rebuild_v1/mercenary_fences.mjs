export const MERCENARY_FENCE_SITE=Object.freeze({id:'service-yard:print_shop-001',buildingId:'REBUILD-VISUAL-print_shop-001',x:415.65,z:57.1,width:6,depth:5});
export function createMercenaryFences({THREE,groundHeight=()=>0,cutIds=[],onCollisionChange,persistCut=()=>{},site=MERCENARY_FENCE_SITE}){
 const y=groundHeight(site.x,site.z),object=new THREE.Group();object.name='Print_Shop_Service_Wire_Cage';object.position.set(site.x,y,site.z);
 const material=new THREE.MeshStandardMaterial({color:0x727872,metalness:.5,roughness:.75}),geometry=new THREE.CylinderGeometry(1,1,1,5),owned=[],all=[],id=site.id+':north-panel',panel=new THREE.Group();panel.name='WireFence_Cuttable_North';object.add(panel);panel.position.z=-2.5;
 let disposed=false,isCut=cutIds.includes(id),colliders=[];
 const v=new THREE.Vector3(),axis=new THREE.Vector3(0,1,0),q=new THREE.Quaternion(),scale=new THREE.Vector3(),matrix=new THREE.Matrix4();
 function rods(parent,segments){const mesh=new THREE.InstancedMesh(geometry,material,segments.length);mesh.castShadow=true;mesh.receiveShadow=true;segments.forEach(([a,b,r=.018],i)=>{v.set(b[0]-a[0],b[1]-a[1],b[2]-a[2]);scale.set(r,v.length(),r);q.setFromUnitVectors(axis,v.normalize());matrix.compose(new THREE.Vector3((a[0]+b[0])/2,(a[1]+b[1])/2,(a[2]+b[2])/2),q,scale);mesh.setMatrixAt(i,matrix);});mesh.computeBoundingSphere();parent.add(mesh);owned.push(mesh);return mesh;}
 function net(x1,z1,x2,z2){const segments=[],length=Math.hypot(x2-x1,z2-z1),n=Math.ceil(length/.16),point=(u,h)=>[x1+(x2-x1)*u,h,z1+(z2-z1)*u];for(let i=0;i<=n;i++){const u=i/n;segments.push([point(u,.12),point(u,1.95),.008]);}for(let h=.12;h<=1.96;h+=.16)segments.push([point(0,h),point(1,h),.008]);segments.push([point(0,2),point(1,2),.027]);return segments;}
 const sections=[[-3,-2.5,-1.2,-2.5],[1.2,-2.5,3,-2.5],[-3,-2.5,-3,2.5],[3,-2.5,3,2.5],[-3,2.5,3,2.5]];
 rods(object,sections.flatMap(s=>net(...s)));
 const posts=[];for(const[x,z]of[[-3,-2.5],[-1.2,-2.5],[1.2,-2.5],[3,-2.5],[-3,2.5],[3,2.5]])posts.push([[x,0,z],[x,2.22,z],.045]);rods(object,posts);
 // A fixed overhead mesh makes this a cage, with the same openable front. Bake
 // all roof rods into one instanced draw and retain a physical overhead collider.
 const roof=[];for(let x=-3;x<=3.001;x+=.2)roof.push([[x,2.18,-2.5],[x,2.18,2.5],.008]);for(let z=-2.5;z<=2.501;z+=.2)roof.push([[-3,2.18,z],[3,2.18,z],.008]);for(const z of[-2.5,0,2.5])roof.push([[-3,2.18,z],[3,2.18,z],.03]);rods(object,roof).name='Cage_Roof_Mesh';
 const left=new THREE.Group(),right=new THREE.Group();left.position.x=-1.2;right.position.x=1.2;panel.add(left,right);rods(left,net(0,0,1.2,0));rods(right,net(-1.2,0,0,0));
 function body(segment,key){const[x1,z1,x2,z2]=segment,w=.12,minX=Math.min(x1,x2)-w,maxX=Math.max(x1,x2)+w,minZ=Math.min(z1,z2)-w,maxZ=Math.max(z1,z2)+w;return {id:key,mercenaryFenceId:site.id,polygonCR:[[minX,minZ],[maxX,minZ],[maxX,maxZ],[minX,maxZ]].map(([x,z])=>[(site.x+x)/4.1,(site.z+z)/4.1]),minYM:y,maxYM:y+2.1};}
 sections.forEach((s,i)=>all.push(body(s,site.id+':fixed:'+i)));all.push({id:site.id+':roof',mercenaryFenceId:site.id,polygonCR:[[-3,-2.5],[3,-2.5],[3,2.5],[-3,2.5]].map(([x,z])=>[(site.x+x)/4.1,(site.z+z)/4.1]),minYM:y+2.14,maxYM:y+2.23});const cutBody=body([-1.2,-2.5,1.2,-2.5],id);all.push(cutBody);colliders=isCut?all.filter(b=>b!==cutBody):all.slice();
 function visual(){left.rotation.y=isCut?Math.PI-.06:0;right.rotation.y=isCut?-Math.PI+.06:0;panel.userData.mercenaryCut=isCut;panel.userData.mercenaryTarget.cuttable=!isCut;proxy.visible=!isCut;}
 function cut(context={}){
  if(disposed)return {ok:false,reason:'disposed'};if(isCut)return {ok:true,alreadyCut:true};if(typeof onCollisionChange!=='function')return {ok:false,reason:'collision_not_connected'};
  const next=colliders.filter(b=>b!==cutBody),receipt=onCollisionChange({removed:[cutBody],added:[],colliders:next,context});
  if(receipt!==true&&receipt?.ok!==true)return {ok:false,reason:'collision_rejected'};
  colliders=next;isCut=true;visual();try{persistCut(id);}catch{/* Physical success must not be reversed by storage failure. */}return {ok:true,cut:true,targetId:id};
 }
 const approach=new THREE.Vector3(),contact=new THREE.Vector3(),normal=new THREE.Vector3();panel.userData.mercenaryTarget={id,kind:'fence',workRange:.08,label:'Сетчатый забор · прорезать проход',highlightBounds:{min:[-1.22,.05,-.05],max:[1.22,2.03,.05]},cuttable:!isCut,cut,getApproachPosition(){panel.updateWorldMatrix(true,false);return panel.localToWorld(approach.set(0,0,-.92));},getWorkPoint(){return panel.localToWorld(contact.set(0,.65,-.018));},getWorkNormal(){return normal.set(0,0,-1).transformDirection(panel.matrixWorld);}};
 // Invisible ray proxy spans the mesh holes. It is never rendered or used as physics.
 const proxyGeometry=new THREE.BoxGeometry(2.4,2,.035),proxyMaterial=new THREE.MeshBasicMaterial({visible:false}),proxy=new THREE.Mesh(proxyGeometry,proxyMaterial);proxy.position.y=1;panel.add(proxy);visual();
 return {object,get colliders(){return colliders;},getTargets:()=>disposed?[]:[{id,kind:'fence',object:panel}],cut,dispose(){if(disposed)return;disposed=true;object.removeFromParent();for(const mesh of owned)mesh.dispose();geometry.dispose();material.dispose();proxyGeometry.dispose();proxyMaterial.dispose();}};
}
