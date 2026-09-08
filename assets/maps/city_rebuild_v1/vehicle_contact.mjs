// Contact geometry in world metres; normal points from car toward obstacle.
export function polygonVehicleContact(car,obstacle){
 let depth=Infinity,normal=null;
 const center=p=>p.reduce((a,v)=>[a[0]+v[0]/p.length,a[1]+v[1]/p.length],[0,0]);
 const aCenter=center(car),bCenter=center(obstacle);
 for(const poly of [car,obstacle])for(let i=0;i<poly.length;i++){
  const a=poly[i],b=poly[(i+1)%poly.length],dx=b[0]-a[0],dz=b[1]-a[1],len=Math.hypot(dx,dz);if(len<1e-8)continue;
  let nx=-dz/len,nz=dx/len;
  const project=p=>p.map(v=>v[0]*nx+v[1]*nz),ap=project(car),bp=project(obstacle);
  const overlap=Math.min(Math.max(...ap),Math.max(...bp))-Math.max(Math.min(...ap),Math.min(...bp));
  if(overlap<0)return null;
  if(overlap<depth){if((bCenter[0]-aCenter[0])*nx+(bCenter[1]-aCenter[1])*nz<0){nx=-nx;nz=-nz}depth=overlap;normal={x:nx,y:0,z:nz}}
 }
 if(!normal)return null;const {x:nx,z:nz}=normal,tx=-nz,tz=nx;
 const along=p=>p.map(v=>v[0]*tx+v[1]*tz),ap=along(car),bp=along(obstacle);
 const tangentMid=(Math.max(Math.min(...ap),Math.min(...bp))+Math.min(Math.max(...ap),Math.max(...bp)))/2;
 const support=Math.max(...car.map(v=>v[0]*nx+v[1]*nz));
 // A rotated corner has only one support vertex. The midpoint of the full
 // tangent projection is not on that corner and can place a dent in empty air.
 const face=car.filter(v=>support-(v[0]*nx+v[1]*nz)<1e-6).map(v=>v[0]*tx+v[1]*tz);
 const tangent=Math.max(Math.min(...face),Math.min(Math.max(...face),tangentMid));
 return {point:{x:nx*support+tx*tangent,y:.8,z:nz*support+tz*tangent},normal,depth};
}

export function contactKinematics(contact,speed,travelYaw){
 const vx=Math.sin(travelYaw)*speed,vz=Math.cos(travelYaw)*speed;
 const normalSpeed=Math.max(0,vx*contact.normal.x+vz*contact.normal.z);
 return {...contact,impactSpeed:normalSpeed,slideSpeed:Math.abs(vx*contact.normal.z-vz*contact.normal.x),velocity:{x:vx,y:0,z:vz}};
}
