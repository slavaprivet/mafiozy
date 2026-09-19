// Presentation only: one restrained rounded marker, no mesh silhouette/fill.
export function createMercenarySelectionView({THREE,scene}){
 const outlineMaterial=new THREE.ShaderMaterial({uniforms:{edgeColor:{value:new THREE.Color(0xf03532)}},vertexShader:`attribute float edgeAlpha;varying float vAlpha;void main(){vAlpha=edgeAlpha;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}`,fragmentShader:`uniform vec3 edgeColor;varying float vAlpha;void main(){gl_FragColor=vec4(edgeColor,vAlpha*.78);}`,transparent:true,depthTest:true,depthWrite:false,side:THREE.DoubleSide,toneMapped:false});
 const boundsCache=new WeakMap(),inverse=new THREE.Matrix4(),transform=new THREE.Matrix4(),instance=new THREE.Matrix4(),corner=new THREE.Vector3();
 let outline=null,outlineBuilds=0,outlineVertices=0,boundsComputed=0,outlineLimited=false,buildSliceMaxMs=0;
 function clearOutline(){outline?.removeFromParent();outline?.geometry.dispose();outline=null;outlineVertices=0;}
 function localBounds(object){
  const authored=object.userData?.mercenaryTarget?.highlightBounds,revision=object.userData?.mercenaryTarget?.boundsRevision??0,cached=boundsCache.get(object);
  if(cached&&cached.authored===authored&&cached.revision===revision)return cached.box;
  const box=new THREE.Box3();
  if(authored?.min?.length===3&&authored?.max?.length===3&&[...authored.min,...authored.max].every(Number.isFinite)){box.min.fromArray(authored.min);box.max.fromArray(authored.max);}
  else{
   object.updateWorldMatrix(true,true);inverse.copy(object.matrixWorld).invert();
   object.traverse(node=>{
    if(!node.isMesh||node.isBatchedMesh||!node.geometry?.attributes?.position)return;
    for(let p=node;p;p=p.parent){if(!p.visible||p.userData?.mercenaryPickIgnore)return;if(p===object)break;}
    const materials=Array.isArray(node.material)?node.material:[node.material];if(!materials.some(m=>m?.visible!==false&&(!m?.transparent||m.opacity>.01)))return;
    // Never compute/replace authored geometry bounds or normals on the source.
    const local=node.geometry.boundingBox||new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position);
    const count=node.isInstancedMesh?node.count:1;
    for(let i=0;i<count;i++){transform.multiplyMatrices(inverse,node.matrixWorld);if(node.isInstancedMesh){node.getMatrixAt(i,instance);transform.multiply(instance);}for(let x=0;x<2;x++)for(let y=0;y<2;y++)for(let z=0;z<2;z++){corner.set(x?local.max.x:local.min.x,y?local.max.y:local.min.y,z?local.max.z:local.min.z).applyMatrix4(transform);box.expandByPoint(corner);}}
   });
  }
  boundsComputed++;boundsCache.set(object,{box,authored,revision});return box;
 }
 function refreshOutline(object){
  if(outline)return;
  const start=performance.now(),box=localBounds(object);if(box.isEmpty()||![...box.min.toArray(),...box.max.toArray()].every(Number.isFinite))return;
  const size=box.getSize(new THREE.Vector3()),center=box.getCenter(new THREE.Vector3()),positions=[],alphas=[],indices=[];
  const rx=Math.max(.20,size.x*.5+.09),rz=Math.max(.22,size.z*.5+.08),hy=Math.max(.24,size.y*.5+.04),width=Math.max(.020,Math.min(.040,Math.max(size.x,size.y)*.012));
  // Four low elliptical arcs anchor the object; two open parentheses show
  // height without drawing a box or tracing the object's small details.
  function ribbon(sample,segments){let previous=null;
   for(let i=0;i<=segments;i++){const t=i/segments,p=sample(t),before=sample(Math.max(0,t-.001)),after=sample(Math.min(1,t+.001)),dx=after[0]-before[0],dy=after[1]-before[1],dz=after[2]-before[2];
    let nx,nz,ny;if(p[3]==='ground'){const length=Math.hypot(dx,dz)||1;nx=-dz/length;ny=0;nz=dx/length;}else{const length=Math.hypot(dx,dy)||1;nx=-dy/length;ny=dx/length;nz=0;}
    const end=Math.min(1,t/.10,(1-t)/.10),fade=end*end*(3-2*end),base=positions.length/3;
    for(const band of[-1,0,1]){positions.push(p[0]+nx*width*band,p[1]+ny*width*band,p[2]+nz*width*band);alphas.push(band===0?fade:0);}
    if(previous!==null)for(let j=0;j<2;j++)indices.push(previous+j,base+j,base+j+1,previous+j,base+j+1,previous+j+1);previous=base;
   }
  }
  for(let side=0;side<4;side++)ribbon(t=>{const a=side*Math.PI/2+.20+t*(Math.PI/2-.40);return[center.x+rx*Math.cos(a),box.min.y+.035,center.z+rz*Math.sin(a),'ground'];},28);
  for(const side of[-1,1])ribbon(t=>{const a=-1.20+t*2.40;return[center.x+side*rx*(1+.12*Math.cos(a)),center.y+hy*Math.sin(a),center.z];},40);
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setAttribute('edgeAlpha',new THREE.Float32BufferAttribute(alphas,1));geometry.setIndex(indices);geometry.computeBoundingSphere();
  outline=new THREE.Mesh(geometry,outlineMaterial);outline.name='Mercenary_Object_Focus_Arcs';outline.userData.mercenaryPickIgnore=true;outline.userData.focusBounds={min:box.min.toArray(),max:box.max.toArray()};outline.raycast=()=>{};outline.renderOrder=1;object.add(outline);outlineBuilds++;outlineVertices=positions.length/3;buildSliceMaxMs=Math.max(buildSliceMaxMs,performance.now()-start);
 }
 const marker=new THREE.Group();marker.name='Mercenary_Rally_Marker';marker.visible=false;scene.add(marker);
 const markerMaterial=new THREE.MeshBasicMaterial({color:0xe6c58a,vertexColors:true,transparent:true,opacity:.82,depthTest:true,depthWrite:false,side:THREE.DoubleSide});
 // Two merged meshes: a slim tapered cross of translucent vanes and broken
 // concentric brass arcs with four diamond accents. No glow pass or extra lights.
 function meshGeometry(triangles){const p=[],colors=[];for(const tri of triangles)for(const [x,y,z,tone=1]of tri){p.push(x,y,z);colors.push(tone,tone,tone);}const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(p,3));g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));g.computeBoundingSphere();return g;}
 const shaft=[];for(const axis of [0,1])for(let i=0;i<3;i++){const heights=[.045,.5,1.9,2.8],widths=[.09,.055,.025,.006],tones=[.42,1,.48,.08],a=axis?[-0,heights[i],-widths[i],tones[i]]:[-widths[i],heights[i],0,tones[i]],b=axis?[0,heights[i],widths[i],tones[i]]:[widths[i],heights[i],0,tones[i]],c=axis?[0,heights[i+1],widths[i+1],tones[i+1]]:[widths[i+1],heights[i+1],0,tones[i+1]],d=axis?[0,heights[i+1],-widths[i+1],tones[i+1]]:[-widths[i+1],heights[i+1],0,tones[i+1]];shaft.push([a,b,c],[a,c,d]);}
 const ornament=[],point=(angle,r)=>[Math.cos(angle)*r,.035,Math.sin(angle)*r];
 for(const radius of [.65,.82])for(let side=0;side<4;side++)for(let i=0;i<16;i++){const a=side*Math.PI/2+.16+i*(Math.PI/2-.32)/16,b=side*Math.PI/2+.16+(i+1)*(Math.PI/2-.32)/16,p=point(a,radius-.012),q=point(a,radius+.012),r=point(b,radius+.012),s=point(b,radius-.012);ornament.push([p,q,r],[p,r,s]);}
 for(let i=0;i<4;i++){const a=i*Math.PI/2,p=point(a,.94),q=point(a+.085,.76),r=point(a,.64),s=point(a-.085,.76);ornament.push([p,q,r],[p,r,s]);}
 const pillarGeometry=meshGeometry(shaft),ringGeometry=meshGeometry(ornament),pillar=new THREE.Mesh(pillarGeometry,markerMaterial),ring=new THREE.Mesh(ringGeometry,markerMaterial);pillar.name='Rally_Gold_Beacon';ring.name='Rally_Art_Deco_Arcs';marker.add(pillar,ring);
 for(const mesh of [pillar,ring]){mesh.raycast=()=>{};mesh.userData.mercenaryPickIgnore=true;}
 const npcTriangles=[],npcPoint=(angle,r,tone=1)=>[Math.cos(angle)*r,.035,Math.sin(angle)*r,tone];
 for(const [inner,outer,tone]of[[.49,.545,1],[.61,.635,.6]])for(let side=0;side<4;side++)for(let i=0;i<16;i++){const a=side*Math.PI/2+.17+i*(Math.PI/2-.34)/16,b=side*Math.PI/2+.17+(i+1)*(Math.PI/2-.34)/16,p=npcPoint(a,inner,tone),q=npcPoint(a,outer,tone),r=npcPoint(b,outer,tone),s=npcPoint(b,inner,tone);npcTriangles.push([p,q,r],[p,r,s]);}
 for(let i=0;i<4;i++){const a=i*Math.PI/2,tip=npcPoint(a,.50),left=npcPoint(a-.12,.81),middle=npcPoint(a,.69,.8),right=npcPoint(a+.12,.81);npcTriangles.push([tip,left,middle],[tip,middle,right]);}
 const npcGeometry=meshGeometry(npcTriangles),npcMaterial=new THREE.MeshBasicMaterial({color:0x91e7ba,vertexColors:true,transparent:true,opacity:.95,depthTest:true,depthWrite:false,side:THREE.DoubleSide}),npcRing=new THREE.Mesh(npcGeometry,npcMaterial);npcRing.name='Mercenary_Npc_Selection_Ring';npcRing.visible=false;npcRing.raycast=()=>{};npcRing.userData.mercenaryPickIgnore=true;scene.add(npcRing);
 const npcForward=new THREE.Vector3(),npcPosition=new THREE.Vector3(),npcQ=new THREE.Quaternion();
 let selected=null,selectedKind=null,npcDowned=false,disposed=false,phase=0,highlightAge=0;
 function updateNpcRing(){if(!selected||selectedKind!=='npc'){npcRing.visible=false;return;}let attached=false;for(let p=selected;p;p=p.parent){if(p.visible===false){npcRing.visible=false;return;}if(p.isScene)attached=true;}if(!attached){npcRing.visible=false;return;}selected.getWorldPosition(npcPosition);selected.getWorldQuaternion(npcQ);npcForward.set(0,0,1).applyQuaternion(npcQ);npcRing.position.copy(npcPosition);npcRing.rotation.y=Math.atan2(npcForward.x,npcForward.z);npcRing.scale.set(npcDowned?1.05:1,1,npcDowned?1.5:1);npcRing.visible=true;}
 function setTarget(target){
  if(disposed)return false;const targetKind=target?.kind||target?.object?.userData?.mercenaryTarget?.kind;
  // Vehicles keep their dedicated door interaction highlights. Completed objects
  // must lose the marker immediately, regardless of stale host aim.
  const data=target?.object?.userData,meta=data?.mercenaryTarget;
  const rejected=target?.valid===false||target?.invalid===true||target?.completed===true||target?.opened===true||data?.mercenaryOpened===true||meta?.opened===true||(targetKind==='fence'&&data?.mercenaryCut===true)||(targetKind==='power_panel'&&meta?.powered===false)||['completed','opened','invalid'].includes(target?.state)||targetKind==='vehicle';
  const object=rejected?null:target?.object;
  const markerColor=target?.working?0x61df89:target?.queued?0xd4aa62:0xf03532;
  const kind=['npc','member','player'].includes(target?.kind||object?.userData?.mercenaryTarget?.kind)?'npc':'object';npcDowned=!!(target?.downed||target?.dead||Number.isFinite(target?.hp)&&target.hp<=0);npcMaterial.color.setHex(target?.working?0x61df89:target?.queued?0xd4aa62:npcDowned?0xffce83:0x91e7ba);
  if(object===selected&&kind===selectedKind){if(selected&&kind==='object'){outlineMaterial.uniforms.edgeColor.value.setHex(markerColor);refreshOutline(selected)};updateNpcRing();return !!selected;}
  clearOutline();npcRing.visible=false;selected=null;selectedKind=null;if(!object?.isObject3D||object.isScene)return false;
  selected=object;selectedKind=kind;highlightAge=0;if(kind==='object'){outlineMaterial.uniforms.edgeColor.value.setHex(markerColor);refreshOutline(object);}updateNpcRing();return true;
 }
 function setRally(point){if(disposed)return false;if(!point||![point.x,point.y,point.z].every(Number.isFinite)){marker.visible=false;return false;}marker.position.set(point.x,point.y,point.z);phase=0;markerMaterial.opacity=.82;marker.visible=true;return true;}
 function update(dt=0){if(disposed)return;const step=Number.isFinite(dt)?Math.max(0,dt):0;if(selected){highlightAge+=step;npcMaterial.opacity=.88+Math.sin(highlightAge*2.4)*.06;updateNpcRing();}if(!marker.visible)return;phase=Math.min(3,phase+step);const t=phase/3,smooth=t*t*(3-2*t);markerMaterial.opacity=.82*(1-smooth);if(phase>=3)marker.visible=false;}
 function dispose(){if(disposed)return;disposed=true;clearOutline();outlineMaterial.dispose();marker.removeFromParent();npcRing.removeFromParent();npcGeometry.dispose();npcMaterial.dispose();pillarGeometry.dispose();ringGeometry.dispose();markerMaterial.dispose();selected=null;selectedKind=null;}
 return {setTarget,setRally,update,dispose,whenReady:()=>Promise.resolve(!!outline),stats:()=>({disposed,selected:!!selected,selectedKind,npcRing:!disposed&&npcRing.visible,rally:!disposed&&marker.visible,boundsComputed,outlineBuilds,outlineVertices,outlineLimited,building:false,buildSliceMaxMs,materialClones:0,geometries:disposed?0:3+Number(!!outline),materials:disposed?0:3})};
}


