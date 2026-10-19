// Explicit owner-run static loopback server only. Does not open browser or game.
import fs from 'node:fs';import path from 'node:path';import http from 'node:http';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const base=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(fs.readFileSync(path.join(base,'package_manifest.json')));
if(manifest.schema!=='landmark-original-canvas-harness-preparation-v1'||manifest.ready!==false)throw Error('Prepared package required');
const allowed=new Map(manifest.files.map(record=>['/'+record.name,record]));
const server=http.createServer((request,response)=>{try{
 const pathname=new URL(request.url,'http://127.0.0.1').pathname,record=allowed.get(pathname==='/'?'/index.html':pathname);if(request.method!=='GET'||!record)throw Error('Path/method refused');
 const filename=path.join(base,record.name);if(fs.lstatSync(filename).isSymbolicLink())throw Error('Linked asset refused');const bytes=fs.readFileSync(filename);if(bytes.length!==record.bytes||crypto.createHash('sha256').update(bytes).digest('hex')!==record.sha256)throw Error('Prepared file changed');
 response.writeHead(200,{'Content-Type':record.name.endsWith('.json')?'application/json':record.name.endsWith('.html')?'text/html':'text/javascript','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self' blob:; style-src 'self' 'unsafe-inline'; object-src 'none'"});response.end(bytes);
}catch(error){response.writeHead(403,{'Content-Type':'text/plain'});response.end('Capture source refused: '+error.message);}});
server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({url:'http://127.0.0.1:'+server.address().port,ready:false,browserStarted:false,gpu:false})));
