// Candidate only: root owns production review/apply. No source AI or steering edits.
export function createTrafficEmergencyLamps(root){
 const lamps=[],owned=[];
 root.traverse?.(mesh=>{
  if(!mesh.isMesh||!/_Lightbar(?:Red|Blue)$/.test(mesh.name))return;
  // Artist cars own materials per car but may share them with coloured trim.
  // Clone only these two lamp materials before the render-batch owner starts.
  const original=mesh.material,materials=(Array.isArray(mesh.material)?mesh.material:[mesh.material]).map(material=>{
   const owned=material.clone();owned.emissiveIntensity=0;return owned;
  });
  mesh.material=Array.isArray(mesh.material)?materials:materials[0];
  owned.push({mesh,original,assigned:mesh.material});
  for(const material of materials)lamps.push({material,phase:mesh.name.endsWith('Red')?0:1});
 });
 let previous=-1;
 return {count:lamps.length,update(active,time){
  const phase=active?Math.floor(Math.max(0,time)/.17)%2:-1;
  if(phase===previous)return false;previous=phase;
  for(const lamp of lamps)lamp.material.emissiveIntensity=phase===lamp.phase?3.2:0;
  return true;
 },dispose(){for(const entry of owned)if(entry.mesh.material===entry.assigned)entry.mesh.material=entry.original;for(const lamp of lamps)lamp.material.dispose();owned.length=0;lamps.length=0;}};
}
export function stagePoliceEmergencyVisuals(source){
 const replace=(before,after)=>{if(!source.includes(before))throw Error('Emergency visual source changed: '+before.slice(0,90));source=source.replace(before,after);};
 replace('export function createWorldTrafficPresentation(',createTrafficEmergencyLamps.toString()+'\nexport function createWorldTrafficPresentation(');
 replace('disposed=false,tail=Promise.resolve(),created=0;', 'disposed=false,tail=Promise.resolve(),created=0,emergencyClock=0;');
 replace('dt=Math.max(0,Math.min(.1,Number(dt)||0));','emergencyClock+=Math.max(0,Number(dt)||0);dt=Math.max(0,Math.min(.1,Number(dt)||0));');
 replace('const renderBatches=THREE?.BatchedMesh?', 'const emergencyLamps=createTrafficEmergencyLamps(actor.object);const renderBatches=THREE?.BatchedMesh?');
 replace('presentation,renderBatches,wheelRenderBatches});created++','presentation,renderBatches,wheelRenderBatches,emergencyLamps});created++');
 replace('record.renderBatches?.dispose();release(record.actor.object)', 'record.renderBatches?.dispose();record.emergencyLamps.dispose();release(record.actor.object)');
 replace('for(const {actor,renderBatches,wheelRenderBatches} of actors.values()){wheelRenderBatches?.dispose();renderBatches?.dispose();release(actor.object)', 'for(const {actor,renderBatches,wheelRenderBatches,emergencyLamps} of actors.values()){wheelRenderBatches?.dispose();renderBatches?.dispose();emergencyLamps.dispose();release(actor.object)');
 replace('   // Batched cabin parts are fixed', '   record.emergencyLamps.update(pose.presentation.emergencyLights&&!pose.presentation.wrecked&&object.visible!==false,emergencyClock);\n   // Batched cabin parts are fixed');
 replace("'source damage/sirens retained as metadata; no destructive effects applied'", "'source damage retained as metadata; no destructive effects or siren audio applied'");
 return source;
}
