// Keep the accessible text unchanged and never interpret object names as HTML.
const formattedPrompts=new WeakSet();
export function setInteractionPromptText(element,text){
 if(!element||formattedPrompts.has(element)&&element.textContent===text)return;
 const parts=String(text).split(/(\bE\b)/g);
 element.replaceChildren(...parts.map(part=>{if(part!=='E')return part;const key=element.ownerDocument.createElement('kbd');key.textContent='E';key.style.fontWeight='900';return key;}));
 formattedPrompts.add(element);
}
