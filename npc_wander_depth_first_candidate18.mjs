// Candidate-only scoped transform; no production file is loaded or modified.
export function depthFirstWanderCandidate18(pick){
 const marker='const node={r,c,key,depth:cur.depth+1,parent:cur.key};nodes.set(key,node);queue.push(node);';
 if(!pick.includes(marker))throw Error('wander frontier insertion marker missing');
 return pick.replace(marker,'const node={r,c,key,depth:cur.depth+1,parent:cur.key};nodes.set(key,node);if(resolver)queue.splice(search.qi+1,0,node);else queue.push(node);');
}
