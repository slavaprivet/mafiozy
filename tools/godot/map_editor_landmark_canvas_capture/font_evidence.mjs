// Existing owner-attached CDP client only: never creates browser/context/tab.
// Native Canvas has no resolved font-backend API; same-font DOM probes provide
// platform glyph provenance, while original native measureText is in pixel receipt.
export async function collectPlatformFontEvidence(existingCdp,receipt){
 if(!receipt||receipt.ready!==false||receipt.slots?.length!==43)throw Error('Original capture receipt required');
 await existingCdp.send('DOM.enable');await existingCdp.send('CSS.enable');
 const version=await existingCdp.send('Browser.getVersion'),{root}=await existingCdp.send('DOM.getDocument');
 const fonts=[];
 for(const slot of receipt.slots)for(const draw of slot.nativeTextDraws){
  const {nodeId}=await existingCdp.send('DOM.querySelector',{nodeId:root.nodeId,selector:'#'+draw.probeId});if(!nodeId)throw Error('Actual original source-font probe missing');
  const actual=await existingCdp.send('CSS.getPlatformFontsForNode',{nodeId});if(!actual.fonts?.length||actual.fonts.some(font=>font.glyphCount<=0))throw Error('No actual platform glyph evidence');
  fonts.push({slot:slot.id,probeId:draw.probeId,text:draw.text,font:draw.font,platformFonts:actual.fonts});
 }
 return {schema:'landmark-owner-platform-font-evidence-v1',captureCanonicalSha256:receipt.canonicalSha256,version,fonts,ready:false,warning:'DOM same-font glyph provenance, not direct Canvas font-engine attestation; owner must review expected system-ui backend, no font substitution'};
}
