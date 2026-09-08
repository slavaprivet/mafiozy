// Pure planar rigid-body contact. The normal points from A toward B.
// Distances are metres, mass is kg, velocity m/s, yawRate rad/s about +Y.
export function resolveVehiclePairImpulse(a,b,contact,{restitution=.12,angular=true}={}) {
  const finite=(value,fallback=0)=>Number.isFinite(value)?value:fallback;
  const velocity=body=>({vx:finite(body.vx),vz:finite(body.vz),yawRate:finite(body.yawRate)});
  const av=velocity(a),bv=velocity(b);
  const result={a:av,b:bv,impulse:0,impulseA:{x:0,z:0},impulseB:{x:0,z:0},deltaVA:0,deltaVB:0,closingSpeed:0,resolved:false};
  // Invalid bodies/contacts cannot introduce NaN into the simulation.
  if(!Number.isFinite(a.mass)||a.mass<=0||!Number.isFinite(b.mass)||b.mass<=0||!contact?.normal||!contact?.point)return result;
  const values=[a.x,a.z,b.x,b.z,contact.point.x,contact.point.z,contact.normal.x,contact.normal.z];
  if(!values.every(Number.isFinite))return result;
  const length=Math.hypot(contact.normal.x,contact.normal.z);
  if(length<1e-9)return result;
  const nx=contact.normal.x/length,nz=contact.normal.z/length;
  const invA=1/a.mass,invB=1/b.mass;
  const inverseInertia=body=>{
    const w=body.halfWidth,l=body.halfLength;
    return angular&&Number.isFinite(w)&&Number.isFinite(l)&&w>0&&l>0?3/(body.mass*(w*w+l*l)):0;
  };
  const ia=inverseInertia(a),ib=inverseInertia(b);
  const ax=contact.point.x-a.x,az=contact.point.z-a.z,bx=contact.point.x-b.x,bz=contact.point.z-b.z;
  const ca=az*nx-ax*nz,cb=bz*nx-bx*nz;
  const closing=(av.vx-bv.vx)*nx+(av.vz-bv.vz)*nz+(ia?av.yawRate*ca:0)-(ib?bv.yawRate*cb:0);
  if(!Number.isFinite(closing))return result;
  result.closingSpeed=Math.max(0,closing);
  if(closing<=0)return result;
  const denominator=invA+invB+ca*ca*ia+cb*cb*ib;
  const e=Math.max(0,Math.min(1,finite(restitution,.12)));
  const impulse=(1+e)*closing/denominator;
  const deltaVA=impulse*invA,deltaVB=impulse*invB;
  const nextA={vx:av.vx-deltaVA*nx,vz:av.vz-deltaVA*nz,yawRate:av.yawRate-impulse*ca*ia};
  const nextB={vx:bv.vx+deltaVB*nx,vz:bv.vz+deltaVB*nz,yawRate:bv.yawRate+impulse*cb*ib};
  if(![impulse,deltaVA,deltaVB,...Object.values(nextA),...Object.values(nextB)].every(Number.isFinite))return result;
  return {...result,a:nextA,b:nextB,impulse,impulseA:{x:-impulse*nx,z:-impulse*nz},impulseB:{x:impulse*nx,z:impulse*nz},deltaVA,deltaVB,resolved:true};
}
