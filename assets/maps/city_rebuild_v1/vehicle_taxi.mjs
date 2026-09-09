// A separately owned livery variant; the source GLB and ordinary sedan are intact.
export function decorateCityTaxi(T,RoundedBox,car){
 const paint=car.hoodSpec?.lid?.material;if(!paint?.color)throw Error('Taxi requires an owned body paint');paint.color.set('#f4bd22');paint.roughness=.38;
 car.profile={...car.profile,id:'city_taxi',label:'Easton Taxi',mapColor:'#f4bd22'};car.object.name='Vehicle_city_taxi';Object.assign(car.object.userData,{vehicleModelId:'city_taxi',vehicleProfile:car.profile,mapColor:'#f4bd22',service:'taxi'});
 const black=new T.MeshStandardMaterial({color:'#20272a',roughness:.63}),ivory=new T.MeshStandardMaterial({color:'#fff3c3',roughness:.42,emissive:'#f7ca62',emissiveIntensity:.12});
 const box=(name,w,h,d,x,y,z,material,parent=car.object)=>{const m=new T.Mesh(new RoundedBox(w,h,d,2,.006),material);m.name=name;m.position.set(x,y,z);m.castShadow=m.receiveShadow=true;parent.add(m);return m};
 const roof=car.diagnostics().bodyAssembly.roof,top=roof?.top??car.profile.height,roofY=Number.isFinite(top)?top:car.profile.height;
 // Read the real roof surface rather than the unadapted source profile height.
 let roofTop=-Infinity;car.object.updateWorldMatrix(true,true);const inverse=car.object.matrixWorld.clone().invert(),v=new T.Vector3();
 car.object.traverse(m=>{if(!m.isMesh||!/Roof|roof/.test(m.name)||m.material?.transparent)return;const a=m.geometry?.attributes?.position;if(a)for(let i=0;i<a.count;i++){v.fromBufferAttribute(a,i).applyMatrix4(m.matrixWorld).applyMatrix4(inverse);roofTop=Math.max(roofTop,v.y)}});
 const signY=(Number.isFinite(roofTop)?roofTop:roofY)+.17,signZ=-.05;
 for(const x of [-.22,.22])car.shell.push(box('Taxi_sign_mount',.07,.09,.18,x,signY-.15,signZ,black));
 const sign=box('Taxi_roof_sign',.68,.25,.20,0,signY,signZ,ivory);car.shell.push(sign);
 // Raised block lettering is readable from both approaches, with no canvas assets.
 const glyphs=['111010010010010','010101111101101','101101010101101','111010010010111'];
 for(const facing of [-1,1]){
  const positions=[],normals=[];
  for(let letter=0;letter<4;letter++)for(let i=0;i<15;i++)if(glyphs[letter][i]==='1'){
   const g=new T.BoxGeometry(.032,.030,.004).toNonIndexed();g.translate(facing*(-.238+letter*.15+(i%3)*.035),signY+.061-Math.floor(i/3)*.034,signZ+facing*.103);positions.push(...g.attributes.position.array);normals.push(...g.attributes.normal.array);g.dispose();
  }
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('normal',new T.Float32BufferAttribute(normals,3));const text=new T.Mesh(g,black);text.name='Taxi_letters_'+facing;car.object.add(text);car.shell.push(text);
 }
 for(const entry of car.anchors.doors){
  const door=car.doors.get(entry.id);if(!door)continue;const opening=entry.opening,y=car.anchors.floorTop+.48,x=entry.side*(car.profile.width*.51+.015),z0=opening.min[2]+.10,z1=opening.max[2]-.10,positions=[],normals=[];
  door.updateWorldMatrix(true,false);const toDoor=new T.Matrix4().copy(door.matrixWorld).invert().multiply(car.object.matrixWorld);
  for(let row=0;row<2;row++)for(let j=0;j<Math.floor((z1-z0)/.10);j++)if((row+j)%2===0){const g=new T.BoxGeometry(.008,.085,.095).toNonIndexed();g.translate(x,y+row*.085,z0+.05+j*.10);g.applyMatrix4(toDoor);positions.push(...g.attributes.position.array);normals.push(...g.attributes.normal.array);g.dispose()}
  const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute(positions,3));g.setAttribute('normal',new T.Float32BufferAttribute(normals,3));const checks=new T.Mesh(g,black);checks.name='Taxi_checkers_'+entry.id;door.add(checks);car.shell.push(checks);
 }
 return car;
}
