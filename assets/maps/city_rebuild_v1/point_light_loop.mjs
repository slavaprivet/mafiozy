// Three r180 expands every point-light PBR expression once per light. With
// full-room lighting this creates very large programs and multi-minute driver
// compilation. An ordinary GLSL loop evaluates the same lights in the same
// order. Keep Three's original expansion for shadow-casting point lights,
// whose sampler array indexing requires compile-time indices.
const installed = new WeakSet();
const startups = new WeakMap();
export function configurePointLightLoop(THREE) {
  if (installed.has(THREE.ShaderChunk)) return {applied:true,alreadyInstalled:true};
  if (String(THREE.REVISION) !== '180') return {applied:false,reason:'unreviewed-three-revision'};
  const source = THREE.ShaderChunk.lights_fragment_begin;
  const start = source.indexOf('#if ( NUM_POINT_LIGHTS > 0 )');
  const end = source.indexOf('#if ( NUM_SPOT_LIGHTS > 0 )', start);
  if (start < 0 || end <= start) return {applied:false,reason:'unrecognized-shader-chunk'};
  const original = source.slice(start, end);
  if ((original.match(/#pragma unroll_loop_start/g)||[]).length !== 1 ||
      (original.match(/#pragma unroll_loop_end/g)||[]).length !== 1 ||
      !original.includes('for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ )')) {
    return {applied:false,reason:'unrecognized-point-loop'};
  }
  // GLSL ES rejects undefined names in #if expressions. In the no-point-shadow
  // branch, substituting zero keeps the shadow predicate false (0 < 0).
  const loop = original.replace(/\s*#pragma unroll_loop_start/g,'')
    .replace(/\s*#pragma unroll_loop_end/g,'').replace(/UNROLLED_LOOP_INDEX/g,'0')
    .replace('i < NUM_POINT_LIGHTS;', 'i < min( NUM_POINT_LIGHTS, pointLightLoopLimit );')
    // Zero-intensity slots and fragments beyond a finite light's cutoff have
    // exactly zero contribution. Avoid evaluating the PBR lobes for them.
    .replace('pointLight = pointLights[ i ];', `pointLight = pointLights[ i ];
        if ( all( equal( pointLight.color, vec3( 0.0 ) ) ) ) continue;
        vec3 pointDelta = pointLight.position - geometryPosition;
        if ( pointLight.distance > 0.0 && dot( pointDelta, pointDelta ) >= pointLight.distance * pointLight.distance ) continue;`);
  // A uniform upper bound prevents the driver from expanding the constant
  // loop again. INT_MAX exceeds the GPU's possible light-uniform capacity;
  // min therefore evaluates exactly NUM_POINT_LIGHTS, never a reduced count.
  THREE.ShaderChunk.lights_pars_begin = 'uniform int pointLightLoopLimit;\n' + THREE.ShaderChunk.lights_pars_begin;
  THREE.UniformsLib.lights.pointLightLoopLimit = {value:2147483647};
  for (const shader of Object.values(THREE.ShaderLib)) shader.uniforms.pointLightLoopLimit = {value:2147483647};
  THREE.ShaderChunk.lights_fragment_begin = source.slice(0,start) +
    '#if NUM_POINT_LIGHT_SHADOWS == 0\n' + loop + '\n#else\n' + original +
    '\n#endif\n' + source.slice(end);
  installed.add(THREE.ShaderChunk);
  return {applied:true};
}

// Install immediately after renderer construction. Offscreen environment
// rendering is untouched. The first world render waits for hero/car creation,
// avoiding a whole obsolete shader set before the car's fire light exists.
export function installFastWalkStartup({THREE,renderer,scene,camera,isReady}) {
  if (startups.has(renderer)) return startups.get(renderer);
  const shader = configurePointLightLoop(THREE), original = renderer.render;
  const report = {shader,phase:'waiting',compileMs:null,error:null};
  renderer.render = function (...args) {
    if (args[0] !== scene) return original.apply(this,args);
    if (report.phase === 'waiting') {
      if (!isReady()) return;
      report.phase = 'compiling';
      const begin = performance.now();
      // This submits independent material programs together, using
      // KHR_parallel_shader_compile when supported by the renderer.
      Promise.resolve().then(()=>renderer.compileAsync(scene,camera))
        .catch(error=>{report.error=String(error?.message||error)})
        .finally(()=>{report.compileMs=performance.now()-begin;report.phase='ready'});
      return;
    }
    if (report.phase === 'compiling') return;
    const result = original.apply(this,args);
    if (report.phase === 'ready') report.phase = 'rendered';
    return result;
  };
  const api = {report};
  startups.set(renderer,api);
  return api;
}
