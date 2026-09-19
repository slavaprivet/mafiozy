// Contact geometry in world metres; normal points from car toward obstacle.
export function polygonVehicleContact(car,obstacle){
 let depth=Infinity,hasNormal=false,nx=0,nz=0,aCenterX=0,aCenterZ=0,bCenterX=0,bCenterZ=0;
 // Keep the original summation order (divide each vertex before adding), but
 // avoid allocating reduce arrays for every contact candidate.
 for(let i=0;i<car.length;i++){aCenterX+=car[i][0]/car.length;aCenterZ+=car[i][1]/car.length}
 for(let i=0;i<obstacle.length;i++){bCenterX+=obstacle[i][0]/obstacle.length;bCenterZ+=obstacle[i][1]/obstacle.length}
 for(let source=0;source<2;source++){
  const poly=source?obstacle:car;
  for(let i=0;i<poly.length;i++){
   const a=poly[i],b=poly[(i+1)%poly.length],dx=b[0]-a[0],dz=b[1]-a[1],len=Math.hypot(dx,dz);if(len<1e-8)continue;
   let axisX=-dz/len,axisZ=dx/len,carMin=Infinity,carMax=-Infinity,obstacleMin=Infinity,obstacleMax=-Infinity;
   for(let j=0;j<car.length;j++){const value=car[j][0]*axisX+car[j][1]*axisZ;if(Number.isNaN(value)){carMin=carMax=NaN;break}if(value>carMax)carMax=value;if(value<carMin)carMin=value}
   for(let j=0;j<obstacle.length;j++){const value=obstacle[j][0]*axisX+obstacle[j][1]*axisZ;if(Number.isNaN(value)){obstacleMin=obstacleMax=NaN;break}if(value>obstacleMax)obstacleMax=value;if(value<obstacleMin)obstacleMin=value}
   const overlap=Math.min(carMax,obstacleMax)-Math.max(carMin,obstacleMin);
   if(overlap<0)return null;
   if(overlap<depth){if((bCenterX-aCenterX)*axisX+(bCenterZ-aCenterZ)*axisZ<0){axisX=-axisX;axisZ=-axisZ}depth=overlap;nx=axisX;nz=axisZ;hasNormal=true}
  }
 }
 if(!hasNormal)return null;const tx=-nz,tz=nx;
 let carMin=Infinity,carMax=-Infinity,obstacleMin=Infinity,obstacleMax=-Infinity;
 for(let i=0;i<car.length;i++){const value=car[i][0]*tx+car[i][1]*tz;if(Number.isNaN(value)){carMin=carMax=NaN;break}if(value>carMax)carMax=value;if(value<carMin)carMin=value}
 for(let i=0;i<obstacle.length;i++){const value=obstacle[i][0]*tx+obstacle[i][1]*tz;if(Number.isNaN(value)){obstacleMin=obstacleMax=NaN;break}if(value>obstacleMax)obstacleMax=value;if(value<obstacleMin)obstacleMin=value}
 const tangentMid=(Math.max(carMin,obstacleMin)+Math.min(carMax,obstacleMax))/2;
 let support=-Infinity;
 for(let i=0;i<car.length;i++){const value=car[i][0]*nx+car[i][1]*nz;if(Number.isNaN(value)){support=NaN;break}if(value>support)support=value}
 // A rotated corner has only one support vertex. The midpoint of the full
 // tangent projection is not on that corner and can place a dent in empty air.
 let faceMin=Infinity,faceMax=-Infinity;
 for(let i=0;i<car.length;i++){const v=car[i];if(support-(v[0]*nx+v[1]*nz)<1e-6){const value=v[0]*tx+v[1]*tz;if(Number.isNaN(value)){faceMin=faceMax=NaN;break}if(value>faceMax)faceMax=value;if(value<faceMin)faceMin=value}}
 const tangent=Math.max(faceMin,Math.min(faceMax,tangentMid));
 return {point:{x:nx*support+tx*tangent,y:.8,z:nz*support+tz*tangent},normal:{x:nx,y:0,z:nz},depth};
}

export function contactKinematics(contact,speed,travelYaw){
 const vx=Math.sin(travelYaw)*speed,vz=Math.cos(travelYaw)*speed;
 const normalSpeed=Math.max(0,vx*contact.normal.x+vz*contact.normal.z);
 return {...contact,impactSpeed:normalSpeed,slideSpeed:Math.abs(vx*contact.normal.z-vz*contact.normal.x),velocity:{x:vx,y:0,z:vz}};
}
