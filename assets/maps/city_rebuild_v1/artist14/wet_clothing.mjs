// Wetness is stored per mesh vertex so it follows the same skinned clothing after leaving water.
export const WET_DRY_SECONDS = 90;
export function immersionAt(worldY, waterLevel, edge=.035) {
  if (waterLevel===null || !Number.isFinite(waterLevel)) return 0;
  const t=Math.max(0,Math.min(1,(waterLevel-worldY)/edge));
  return t*t*(3-2*t);
}
export function evolveWetness(previous, worldY, waterLevel, dt, drySeconds=WET_DRY_SECONDS) {
  return Math.max(immersionAt(worldY,waterLevel),Math.max(0,previous-Math.max(0,dt)/drySeconds));
}
export function createWetClothing(THREE,{drySeconds=WET_DRY_SECONDS,sampleInterval=.08}={}) {
  if(!(drySeconds>0))throw new Error('drySeconds must be positive');
  const records=new WeakMap(),point=new THREE.Vector3();
  let waterLevel=null;
  function attach(model) {
    if(records.has(model))return model;
    const root=model.root||model,record={meshes:[],elapsed:0};
    root.traverse(mesh=>{
      if(!mesh.isMesh||!mesh.geometry?.attributes.position)return;
      const originals=Array.isArray(mesh.material)?mesh.material:[mesh.material];
      // The merged HAIR material also covers shoes. SKIN includes eyes in these assets.
      // Only fragments below world water height wet; retained vertex moisture dries later.
      if(!originals.some(m=>m?.isMeshStandardMaterial&&/FABRIC|HAIR|SKIN/i.test(m.name)))return;
      mesh.geometry=mesh.geometry.clone();
      const wet=new THREE.BufferAttribute(new Float32Array(mesh.geometry.attributes.position.count),1);
      wet.setUsage(THREE.DynamicDrawUsage);mesh.geometry.setAttribute('aClothingWetness',wet);
      const uniforms={uClothingWater:{value:-1e6},uClothingInWater:{value:0}};
      const materials=originals.map(original=>{
        if(!original?.isMeshStandardMaterial||!/FABRIC|HAIR|SKIN/i.test(original.name))return original;
        const material=original.clone(),prior=original.onBeforeCompile,cache=original.customProgramCacheKey.bind(original);
        const skin=/SKIN/i.test(original.name),hair=/HAIR/i.test(original.name);
        // Broad damp highlights, not a glossy clearcoat. Skin hardly darkens.
        const response={uWetDarkening:{value:skin?.96:hair?.72:.64},uWetRoughnessScale:{value:skin?.76:hair?.58:.70},uWetRoughnessFloor:{value:skin?.38:hair?.34:.48},uWetVariation:{value:skin?0:hair?.025:.065}};
        material.onBeforeCompile=(shader,renderer)=>{
          prior.call(material,shader,renderer);
          Object.assign(shader.uniforms,uniforms,response);
          shader.vertexShader=shader.vertexShader.replace('#include <common>','#include <common>\nattribute float aClothingWetness;\nvarying float vClothingWetness;\nvarying float vClothingWorldY;\nvarying vec3 vClothingSurfacePosition;');
          shader.vertexShader=shader.vertexShader.replace('#include <project_vertex>','#include <project_vertex>\nvClothingWetness = aClothingWetness;\nvClothingSurfacePosition = position;\nvClothingWorldY = (modelMatrix * vec4(transformed, 1.0)).y;');
          shader.fragmentShader=shader.fragmentShader.replace('#include <common>','#include <common>\nvarying float vClothingWetness;\nvarying float vClothingWorldY;\nvarying vec3 vClothingSurfacePosition;\nuniform float uClothingWater;\nuniform float uClothingInWater;\nuniform float uWetDarkening;\nuniform float uWetRoughnessScale;\nuniform float uWetRoughnessFloor;\nuniform float uWetVariation;');
          shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>','#include <color_fragment>\nfloat clothingWet = max(vClothingWetness, uClothingInWater * smoothstep(0.0, 0.035, uClothingWater - vClothingWorldY));\nfloat dampVariation = 0.5 + 0.5 * sin(vClothingSurfacePosition.x * 23.0 + sin(vClothingSurfacePosition.y * 19.0)) * sin(vClothingSurfacePosition.z * 17.0 + vClothingSurfacePosition.y * 13.0);\ndiffuseColor.rgb *= mix(1.0, uWetDarkening + uWetVariation * dampVariation, clothingWet);');
          shader.fragmentShader=shader.fragmentShader.replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\nroughnessFactor = mix(roughnessFactor, min(roughnessFactor, max(uWetRoughnessFloor, roughnessFactor * uWetRoughnessScale)), clothingWet);');
        };
        material.customProgramCacheKey=()=>cache()+'|artist14-wet-clothing-v2|'+original.name;
        material.needsUpdate=true;return material;
      });
      mesh.material=Array.isArray(mesh.material)?materials:materials[0];
      record.meshes.push({mesh,wet,uniforms,hasWet:false});
    });
    records.set(model,record);return model;
  }
  function setWaterLevel(level) {
    if(level!==null&&!Number.isFinite(level))throw new Error('Water level must be finite world Y or null');
    waterLevel=level;
  }
  function update(model,time,dt) {
    attach(model);const record=records.get(model);record.elapsed+=Math.max(0,Number.isFinite(dt)?dt:0);
    for(const entry of record.meshes){entry.uniforms.uClothingWater.value=waterLevel??-1e6;entry.uniforms.uClothingInWater.value=waterLevel===null?0:1;}
    if(record.elapsed<sampleInterval)return;
    const elapsed=record.elapsed;record.elapsed=0;
    const root=model.root||model;root.updateWorldMatrix(true,true);
    for(const entry of record.meshes){
      if(waterLevel===null&&!entry.hasWet)continue;
      const {mesh,wet}=entry;mesh.skeleton?.update();let hasWet=false;
      for(let i=0;i<wet.count;i++){
        // getVertexPosition includes morphing and skinning, matching the rendered pose.
        mesh.getVertexPosition(i,point);point.applyMatrix4(mesh.matrixWorld);
        const value=evolveWetness(wet.array[i],point.y,waterLevel,elapsed,drySeconds);
        wet.array[i]=value;hasWet ||= value>0;
      }
      entry.hasWet=hasWet;wet.needsUpdate=true;
    }
  }
  function reset(model){const record=records.get(model);if(record)for(const e of record.meshes){e.wet.array.fill(0);e.wet.needsUpdate=true;e.hasWet=false;}}
  return {attach,setWaterLevel,update,reset};
}
