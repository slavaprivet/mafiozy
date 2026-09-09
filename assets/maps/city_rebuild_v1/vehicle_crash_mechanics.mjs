// A bounded 45-node structural cage for the /walk vehicle adapter.
// Local metres: +Z forward, +X driver's left, +Y up. Contact normals point OUT.
// Driving owns rigid-body translation; this module owns residual plastic crush,
// elastic panel settling, attachment failures and mechanical consequences.
// This is a reduced node/beam model, not BeamNG's full vehicle solver.
export const CRASH_PART_IDS = Object.freeze([
  'hood', 'trunk', 'door_front_left', 'door_front_right',
  'door_rear_left', 'door_rear_right', 'bumper_front', 'bumper_rear',
  'wheel_front_left', 'wheel_front_right', 'wheel_rear_left', 'wheel_rear_right',
]);
export const CRASH_WHEEL_IDS = Object.freeze(['front_left', 'front_right', 'rear_left', 'rear_right']);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const finite = (v, fallback = 0) => Number.isFinite(v) ? v : fallback;
const vec = (x = 0, y = 0, z = 0) => ({x, y, z});
const length = v => Math.hypot(v.x, v.y, v.z);
const validVector = v => v && [v.x, v.y, v.z].every(Number.isFinite);
const distance = (a, b) => Math.hypot(a.x-b.x, a.y-b.y, a.z-b.z);
const healthLoss = (value, amount) => clamp(value-Math.max(0, amount), 0, 1);

// Longitudinal crumple zones have more travel than the passenger cell width.
// Every accumulated plastic displacement stays inside this finite ellipsoid.
export function crashCrushLimits(profile) {
  return {x:Math.min(1.30,profile.halfWidth*1.20),y:Math.min(.80,profile.height*.38),z:Math.min(1.65,profile.halfLength*.72)};
}

function buildParts(p) {
  const {halfWidth:w, halfLength:l, wheelBase:b, wheelTrack:t} = p;
  const ys=p.height/2.14,spread=clamp(w,.75,1.6);
  const parts = {};
  const add = (id, x, y, z, radius, strength) => {
    parts[id] = {id, point:p.partPoints[id]?{...p.partPoints[id]}:vec(x,y,z), radius:radius*spread, strength, health:1, detached:false};
  };
  add('hood', 0, .99*ys, l*.69, 1.25, 1.22);
  add('trunk', 0, .95*ys, -l*.87, 1.12, 1.15);
  add('bumper_front', 0, .55*ys, l, 1.25, .70);
  add('bumper_rear', 0, .55*ys, -l, 1.25, .70);
  for (const id of CRASH_WHEEL_IDS) {
    const side = id.endsWith('left') ? 1 : -1, front = id.startsWith('front');
    add('door_'+id, side*w, 1.05*ys, (front?.20:-.98)*l/2.15, .98, 1.30);
    const wheelPoint=p.wheelPositions[id]||vec(side*t/2,.42*ys,(front?1:-1)*b/2);
    add('wheel_'+id,wheelPoint.x,wheelPoint.y,wheelPoint.z,.94,1.24);
  }
  return parts;
}

export function createCrashMechanicsState(profile = {}) {
  const points=input=>Object.fromEntries(Object.entries(input||{}).filter(([,v])=>validVector(v)).map(([id,v])=>[id,{x:v.x,y:v.y,z:v.z}]));
  const p = {
    massKg:clamp(finite(profile.massKg,1500),400,40000),
    halfWidth:clamp(finite(profile.halfWidth,1.0),.5,2.6),
    halfLength:clamp(finite(profile.halfLength,2.15),1.2,8),
    height:clamp(finite(profile.height,2.14),.8,4.8),
    wheelBase:clamp(finite(profile.wheelBase,2.65),1,8),
    wheelTrack:clamp(finite(profile.wheelTrack,1.88),.8,4.4),
    partPoints:points(profile.partPoints),wheelPositions:points(profile.wheelPositions),componentPoints:points(profile.componentPoints),
  };
  p.componentPoints.engine??=vec(0,.65*p.height/2.14,p.halfLength*.64);
  p.componentPoints.radiator??=vec(0,.65*p.height/2.14,p.halfLength*.91);
  const grid = {x:[-p.halfWidth,0,p.halfWidth], y:[.28,p.height*.46,p.height*.91], z:[-p.halfLength,-p.halfLength*.5,0,p.halfLength*.5,p.halfLength]};
  const nodes = [];
  const index = (x,y,z) => (z*3+y)*3+x;
  for (let z=0;z<5;z++) for (let y=0;y<3;y++) for (let x=0;x<3;x++) {
    const rest = vec(grid.x[x],grid.y[y],grid.z[z]);
    nodes.push({rest,plastic:{...rest},position:{...rest},velocity:vec()});
  }
  const beams = [];
  // Axial rails plus face diagonals keep the cage from shearing freely.
  const neighbors = [[1,0,0],[0,1,0],[0,0,1],[1,1,0],[-1,1,0],[1,0,1],[-1,0,1],[0,1,1],[0,-1,1]];
  for (let z=0;z<5;z++) for (let y=0;y<3;y++) for (let x=0;x<3;x++) {
    for (const [dx,dy,dz] of neighbors) {
      const xx=x+dx,yy=y+dy,zz=z+dz;
      if (xx<0||xx>=3||yy<0||yy>=3||zz<0||zz>=5) continue;
      const a=index(x,y,z),b=index(xx,yy,zz),restLength=distance(nodes[a].rest,nodes[b].rest);
      beams.push({a,b,originalLength:restLength,restLength,broken:false,plasticStrain:0});
    }
  }
  const wheels = Object.fromEntries(CRASH_WHEEL_IDS.map(id => [id,{health:1,toe:0,camber:0,sag:0,detached:false}]));
  return {
    profile:p, grid, nodes, beams, parts:buildParts(p), wheels,
    engine:1,radiator:1,steering:1,brakes:1,temperature:0,
    detachedParts:[],recentEvents:[],impacts:0,totalEnergyJ:0,absorbedEnergyJ:0,
    revision:0,active:false,accumulator:0,simulationTime:0,maxCrush:0,
  };
}

function locality(point, target, radius, verticalScale = 1) {
  const d2=((point.x-target.x)**2+((point.y-target.y)*verticalScale)**2+(point.z-target.z)**2)/(radius*radius);
  return d2>=5 ? 0 : Math.exp(-d2*1.5);
}

export function applyCrashMechanicsImpact(state, contact = {}) {
  const rejected = {applied:false,energyJ:0,detached:[],deformedNodes:0};
  if (!validVector(contact.point)||!validVector(contact.normal)||!Number.isFinite(contact.impactSpeed)) return rejected;
  const nl=length(contact.normal), speed=clamp(contact.impactSpeed,0,90);
  if (nl<1e-8||speed<2.5) return rejected;
  if (contact.eventId!=null&&state.recentEvents.includes(contact.eventId)) return rejected;
  const point=contact.point,n=vec(contact.normal.x/nl,contact.normal.y/nl,contact.normal.z/nl);
  const p=state.profile;
  // Reject a bad/world-space payload instead of damaging an unrelated car.
  if (Math.abs(point.x)>p.halfWidth+1.5||Math.abs(point.z)>p.halfLength+1.5||point.y< -1.5||point.y>p.height+1.5) return rejected;
  const energyJ=.5*p.massKg*speed*speed;
  // Preserve parking/low-speed response; yield more progressively above 6 m/s.
  // Contact speed is delta-V. Mass remains in the incoming energy bookkeeping;
  // equal delta-V has equal specific crush for the same structural dimensions.
  const fast=clamp((speed-6)/12,0,1),yieldBlend=fast*fast*(3-2*fast);
  const severity=Math.max(0,speed*speed-2.5**2)/190*(1+.32*yieldBlend);
  const radius=clamp(.52+speed*.041,.58,2.05);
  const limits=crashCrushLimits(p),directionLimit=1/Math.hypot(n.x/limits.x,n.y/limits.y,n.z/limits.z);
  const depth=clamp((speed-2.5)**1.35*.016*(1+.85*yieldBlend),0,directionLimit);
  let deformedNodes=0;
  for (const node of state.nodes) {
    const r=node.rest, dx=r.x-point.x,dy=(r.y-point.y)*.74,dz=r.z-point.z;
    const d2=(dx*dx+dy*dy+dz*dz)/(radius*radius);
    const weight=d2<5?Math.exp(-d2*1.7):0;
    if (weight<.006) continue;
    // Material above/beside a compressed rail buckles outward, not just inward.
    // The deterministic symmetric term preserves mirrored crash responses.
    const buckle=depth*weight*.20;
    const x=-n.x*depth*weight + (Math.abs(n.z)>.55?Math.sign(r.x)*buckle*.5:0);
    const y=-n.y*depth*weight + (r.y>p.height*.4?buckle:0);
    const z=-n.z*depth*weight;
    node.plastic.x+=x;node.plastic.y+=y;node.plastic.z+=z;
    const shift=vec(node.plastic.x-r.x,node.plastic.y-r.y,node.plastic.z-r.z),envelope=Math.hypot(shift.x/limits.x,shift.y/limits.y,shift.z/limits.z);
    if (envelope>1) {
      const s=1/envelope;
      node.plastic.x=r.x+shift.x*s;node.plastic.y=r.y+shift.y*s;node.plastic.z=r.z+shift.z*s;
    }
    // Most crush is immediate; the small elastic remainder settles visibly.
    node.position.x+=(node.plastic.x-node.position.x)*.88;
    node.position.y+=(node.plastic.y-node.position.y)*.88;
    node.position.z+=(node.plastic.z-node.position.z)*.88;
    node.velocity.x=clamp(node.velocity.x-n.x*speed*weight*.045,-1.4,1.4);
    node.velocity.y=clamp(node.velocity.y-n.y*speed*weight*.045,-1.4,1.4);
    node.velocity.z=clamp(node.velocity.z-n.z*speed*weight*.045,-1.4,1.4);
    deformedNodes++;
  }
  for (const beam of state.beams) {
    const plasticLength=distance(state.nodes[beam.a].plastic,state.nodes[beam.b].plastic);
    const strain=Math.abs(plasticLength-beam.originalLength)/beam.originalLength;
    beam.plasticStrain=Math.max(beam.plasticStrain,strain);
    // Yielded rest lengths do not heal when impact force disappears.
    if (strain>.018) beam.restLength=clamp(plasticLength,beam.originalLength*.20,beam.originalLength*1.8);
    if (strain>.64) beam.broken=true;
  }
  const detached=[];
  for (const part of Object.values(state.parts)) {
    if (part.detached) continue;
    // Far-side door/wheel mounts are shielded by the near structural rail.
    const farSide=Math.abs(point.x)>.35&&Math.abs(part.point.x)>.35&&point.x*part.point.x<0 ? .035 : 1;
    const near=locality(point,part.point,part.radius,.65)*farSide;
    part.health=healthLoss(part.health,severity*near/part.strength);
    if (part.health<=.025) {
      part.detached=true;state.detachedParts.push(part.id);detached.push(part.id);
    }
  }
  // Engine and radiator reside up front; rear crashes must not directly
  // damage them simply because the whole vehicle lost speed.
  const enginePoint=p.componentPoints.engine,radiatorPoint=p.componentPoints.radiator;
  const componentScale=clamp(p.halfWidth,.75,1.6);
  if(point.z*Math.sign(enginePoint.z||1)>p.halfLength*.22)
    state.engine=healthLoss(state.engine,severity*locality(point,enginePoint,1.38*componentScale,.5)*.50);
  if(point.z*Math.sign(radiatorPoint.z||1)>p.halfLength*.22)
    state.radiator=healthLoss(state.radiator,severity*locality(point,radiatorPoint,1.20*componentScale,.5)*.75);
  for (const id of CRASH_WHEEL_IDS) {
    const wheel=state.wheels[id],part=state.parts['wheel_'+id],side=id.endsWith('left')?1:-1;
    const farSide=Math.abs(point.x)>.35&&point.x*side<0?.025:1;
    const near=locality(point,part.point,1.02*componentScale,.6)*farSide;
    const loss=severity*near*.70;
    wheel.health=healthLoss(wheel.health,loss);
    wheel.detached=part.detached;
    // Side load bends alignment more than a symmetric head-on load.
    wheel.toe=clamp(wheel.toe+loss*(n.x*.38+side*Math.abs(n.z)*.13),-.48,.48);
    wheel.camber=clamp(wheel.camber-side*loss*.24,-.48,.48);
    wheel.sag=clamp(wheel.sag+loss*.11,0,.25);
    if (id.startsWith('front')) state.steering=healthLoss(state.steering,loss*.24);
    state.brakes=healthLoss(state.brakes,loss*.075);
  }
  state.impacts++;state.totalEnergyJ+=energyJ;
  // Bookkeeping is bounded by available incoming normal kinetic energy.
  state.absorbedEnergyJ+=energyJ*clamp(.22+depth*.68,.22,.83);
  state.active=deformedNodes>0;state.revision++;
  state.maxCrush=Math.max(...state.nodes.map(node=>distance(node.rest,node.plastic)));
  if(contact.eventId!=null) state.recentEvents=[...state.recentEvents,contact.eventId].slice(-128);
  return {applied:true,energyJ,detached,deformedNodes};
}

function fixedStep(state,h) {
  const forces=state.nodes.map(node=>vec(
    (node.plastic.x-node.position.x)*240-node.velocity.x*26,
    (node.plastic.y-node.position.y)*240-node.velocity.y*26,
    (node.plastic.z-node.position.z)*240-node.velocity.z*26,
  ));
  for (const beam of state.beams) {
    if (beam.broken) continue;
    const a=state.nodes[beam.a],b=state.nodes[beam.b];
    const dx=b.position.x-a.position.x,dy=b.position.y-a.position.y,dz=b.position.z-a.position.z;
    const len=Math.hypot(dx,dy,dz);if(len<1e-8)continue;
    const relative=((b.velocity.x-a.velocity.x)*dx+(b.velocity.y-a.velocity.y)*dy+(b.velocity.z-a.velocity.z)*dz)/len;
    const force=clamp((len-beam.restLength)*42+relative*1.8,-100,100)/len;
    forces[beam.a].x+=dx*force;forces[beam.a].y+=dy*force;forces[beam.a].z+=dz*force;
    forces[beam.b].x-=dx*force;forces[beam.b].y-=dy*force;forces[beam.b].z-=dz*force;
  }
  let moving=false;
  for (let i=0;i<state.nodes.length;i++) {
    const node=state.nodes[i],force=forces[i];
    for (const axis of ['x','y','z']) {
      node.velocity[axis]=clamp(node.velocity[axis]+force[axis]*h,-2,2);
      node.position[axis]+=node.velocity[axis]*h;
      const delta=node.position[axis]-node.plastic[axis];
      if(Math.abs(delta)>.15) {node.position[axis]=node.plastic[axis]+Math.sign(delta)*.15;node.velocity[axis]=0;}
    }
    if(length(node.velocity)>.0008)moving=true;
  }
  state.simulationTime+=h;
  return moving;
}

export function stepCrashMechanics(state,dt,{speed=0,throttle=0}={}) {
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid crash mechanics timestep');
  if(dt===0)return false;
  // At most 24 substeps; no catch-up spiral after a background tab resumes.
  const elapsed=Math.min(dt,.1);
  let changed=false;
  if(state.active) {
    state.accumulator=Math.min(.1,state.accumulator+elapsed);
    let steps=0,moving=false;
    while(state.accumulator>=1/240-1e-10&&steps<24) {
      moving=fixedStep(state,1/240);state.accumulator=Math.max(0,state.accumulator-1/240);steps++;
    }
    if(steps) {
      state.active=moving;state.revision++;changed=true;
      // Freeze a settled configuration, preserving its permanent plastic form.
      if(!moving)for(const node of state.nodes)node.velocity=vec();
    }
  }
  if(state.radiator<.8&&state.engine>.015) {
    const load=clamp(Math.abs(finite(throttle)),0,1),roadSpeed=Math.abs(finite(speed));
    state.temperature=clamp(state.temperature+elapsed*((1-state.radiator)*(.008+load*.055)-(.004+roadSpeed*.0007)*state.radiator),0,1);
    if(state.temperature>.85) state.engine=healthLoss(state.engine,elapsed*(state.temperature-.85)*.018);
  } else if(state.temperature>0) state.temperature=Math.max(0,state.temperature-elapsed*.025);
  return changed;
}

function interval(values,value) {
  const v=clamp(value,values[0],values.at(-1));
  for(let i=0;i<values.length-1;i++)if(v<=values[i+1])return [i,(v-values[i])/(values[i+1]-values[i])];
  return [values.length-2,1];
}

export function sampleCrashDeformation(state,point) {
  if(!validVector(point))return vec();
  const [xi,xt]=interval(state.grid.x,point.x),[yi,yt]=interval(state.grid.y,point.y),[zi,zt]=interval(state.grid.z,point.z),out=vec();
  for(let z=0;z<2;z++)for(let y=0;y<2;y++)for(let x=0;x<2;x++) {
    const weight=(x?xt:1-xt)*(y?yt:1-yt)*(z?zt:1-zt),node=state.nodes[((zi+z)*3+yi+y)*3+xi+x];
    out.x+=(node.position.x-node.rest.x)*weight;
    out.y+=(node.position.y-node.rest.y)*weight;
    out.z+=(node.position.z-node.rest.z)*weight;
  }
  return out;
}

export function crashDriveEffects(state) {
  const wheels={},severity=id=>state.wheels[id].detached?1.8:1-state.wheels[id].health;
  for(const id of CRASH_WHEEL_IDS)wheels[id]={...state.wheels[id]};
  const fl=severity('front_left'),fr=severity('front_right'),rl=severity('rear_left'),rr=severity('rear_right');
  const total=fl+fr+rl+rr,missing=CRASH_WHEEL_IDS.filter(id=>state.wheels[id].detached).length;
  const engineDisabled=state.engine<=.025;
  return {
    speedFactor:engineDisabled?0:clamp((.38+.62*Math.sqrt(state.engine))/(1+total*.35+missing*.9),.07,1),
    powerFactor:engineDisabled?0:clamp(state.engine*(1-state.temperature*.50)/(1+total*.30+missing*.4),.025,1),
    frontGrip:clamp(1-(fl+fr)*.24-missing*.045,.12,1),
    rearGrip:clamp(1-(rl+rr)*.24-missing*.045,.12,1),
    pull:clamp((fl-fr)*.11+(rl-rr)*.04+(state.wheels.front_left.toe+state.wheels.front_right.toe)*.55,-.38,.38),
    steerFactor:clamp(state.steering*(1-(fl+fr)*.16),.08,1),
    brakeFactor:clamp(state.brakes*(1-total*.055),.24,1),
    rollingDrag:total*.60+missing*2.15+(1-state.engine)*.13,
    engineDisabled,wheels,
  };
}

export function resetCrashMechanics(state) {
  const pristine=createCrashMechanicsState(state.profile);
  for(const key of Object.keys(state))delete state[key];
  Object.assign(state,pristine);
  return state;
}

// Utility for real detached THREE assemblies. All fields are WORLD-space;
// transform position/quaternion into the debris root only when rendering.
export function createCrashDebrisState({position,velocity=vec(),angularVelocity=vec(),quaternion={x:0,y:0,z:0,w:1},radius=.18,massKg=15}={}) {
  if(!validVector(position))throw Error('Invalid debris position');
  // Read public components explicitly: renderer quaternions can expose
  // getters backed by _x/_y/_z/_w rather than enumerable x/y/z/w properties.
  const q={x:finite(quaternion?.x),y:finite(quaternion?.y),z:finite(quaternion?.z),w:finite(quaternion?.w,1)},norm=Math.hypot(q.x,q.y,q.z,q.w);
  if(norm<1e-8){q.x=q.y=q.z=0;q.w=1}else for(const axis of ['x','y','z','w'])q[axis]/=norm;
  return {position:vec(position.x,position.y,position.z),velocity:validVector(velocity)?vec(velocity.x,velocity.y,velocity.z):vec(),angularVelocity:validVector(angularVelocity)?vec(angularVelocity.x,angularVelocity.y,angularVelocity.z):vec(),quaternion:q,radius:clamp(finite(radius,.18),.02,2.5),massKg:clamp(finite(massKg,15),.1,1000),age:0,settled:false,restTime:0};
}

export function stepCrashDebris(state,dt,groundHeight=()=>0) {
  if(!Number.isFinite(dt)||dt<0)throw Error('Invalid debris timestep');
  if(state.settled||dt===0)return state;
  const elapsed=Math.min(dt,.1),n=Math.max(1,Math.ceil(elapsed*120)),h=elapsed/n;
  for(let i=0;i<n;i++) {
    state.age+=h;state.velocity.y-=9.81*h;
    const drag=Math.exp(-.10*h);
    state.velocity.x*=drag;state.velocity.z*=drag;
    state.position.x+=state.velocity.x*h;state.position.y+=state.velocity.y*h;state.position.z+=state.velocity.z*h;
    const ground=finite(groundHeight(state.position.x,state.position.z),0)+state.radius;
    if(state.position.y<=ground) {
      state.position.y=ground;
      if(state.velocity.y<0)state.velocity.y=Math.abs(state.velocity.y)>.6?-state.velocity.y*.24:0;
      const friction=Math.exp(-4.6*h);state.velocity.x*=friction;state.velocity.z*=friction;
      state.angularVelocity.x*=Math.exp(-3.8*h);state.angularVelocity.y*=Math.exp(-3.8*h);state.angularVelocity.z*=Math.exp(-3.8*h);
      if(length(state.velocity)<.08&&length(state.angularVelocity)<.10)state.restTime+=h;else state.restTime=0;
    } else state.restTime=0;
    const q=state.quaternion,w=state.angularVelocity,x=q.x,y=q.y,z=q.z,qw=q.w;
    // World angular velocity premultiplies orientation.
    q.x+=.5*(w.x*qw+w.y*z-w.z*y)*h;
    q.y+=.5*(-w.x*z+w.y*qw+w.z*x)*h;
    q.z+=.5*(w.x*y-w.y*x+w.z*qw)*h;
    q.w+=.5*(-w.x*x-w.y*y-w.z*z)*h;
    const norm=Math.hypot(q.x,q.y,q.z,q.w)||1;q.x/=norm;q.y/=norm;q.z/=norm;q.w/=norm;
    if(state.restTime>.45){state.settled=true;state.velocity=vec();state.angularVelocity=vec();break;}
  }
  return state;
}
