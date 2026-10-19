// Explicit local artifact receiver. Original capture validation never grants
// texture/font/GPU/owner admission and never accepts client filesystem paths.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parserTar as canonicalBrowserTar} from '../map_editor_landmark_canvas_capture/bundle.browser.mjs';

export const MAX_BYTES = 70 * 1024 * 1024;
const sourcePin = '4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c';
const closurePin = '0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81';
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const insist = (ok, message) => { if (!ok) throw Error(message); };
const sorted = value => Array.isArray(value) ? value.map(sorted) : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])])) : value;
const canonical = value => JSON.stringify(sorted(value));
const decoder = new TextDecoder('utf-8', {fatal:true});
const textField = field => {
  const end = field.indexOf(0), count = end < 0 ? field.length : end;
  insist(end < 0 || field.subarray(end).every(byte => byte === 0), 'Nonzero TAR field suffix');
  return decoder.decode(field.subarray(0, count));
};
const octal = field => {
  const text = decoder.decode(field).replace(/[\x00 ]+$/g, '').replace(/^ +/g, '');
  insist(/^[0-7]+$/.test(text), 'Invalid TAR octal');
  const value = Number.parseInt(text, 8);
  insist(Number.isSafeInteger(value) && value >= 0, 'Unsafe TAR number');
  return value;
};

export function parseTar(bytes) {
  insist(Buffer.isBuffer(bytes) && bytes.length <= MAX_BYTES && bytes.length % 512 === 0, 'Invalid bounded TAR bytes');
  // Exact same canonical USTAR fields used by the browser exporter/parser,
  // including87entries, uname/reserved zeros, size octal and two zero blocks.
  canonicalBrowserTar(new Uint8Array(bytes.buffer,bytes.byteOffset,bytes.byteLength));
  const files = new Map(); let offset = 0, previous = '';
  while (offset + 512 <= bytes.length) {
    const header = bytes.subarray(offset, offset + 512);
    if (header.every(byte => byte === 0)) {
      insist(offset + 1024 === bytes.length && bytes.subarray(offset).every(byte => byte === 0), 'Invalid TAR termination');
      return files;
    }
    let checksum = 0;
    for (let i = 0; i < 512; i++) checksum += i >= 148 && i < 156 ? 32 : header[i];
    insist(checksum === octal(header.subarray(148, 156)), 'TAR checksum mismatch');
    insist(textField(header.subarray(257, 263)) === 'ustar' && decoder.decode(header.subarray(263, 265)) === '00', 'USTAR only');
    insist(header[156] === 48 && textField(header.subarray(157, 257)) === '' && textField(header.subarray(345, 500)) === '', 'Regular unprefixed TAR files only');
    const name = textField(header.subarray(0, 100));
    insist(name === 'receipt.json' || /^images\/texture-\d+-image-\d+\.(rgba|png)$/.test(name), 'TAR path refused');
    insist(!files.has(name) && (previous === '' ? name === 'receipt.json' : previous === 'receipt.json' ? name.startsWith('images/') : previous < name), 'Duplicate/unsorted TAR path'); previous = name;
    insist(octal(header.subarray(100,108)) === 0o644 && octal(header.subarray(108,116)) === 0 && octal(header.subarray(116,124)) === 0 && octal(header.subarray(136,148)) === 0, 'Fixed TAR metadata required');
    const size = octal(header.subarray(124, 136));
    insist(size > 0 && size <= MAX_BYTES && offset + 512 + size <= bytes.length, 'TAR entry exceeds bounds');
    const end = offset + 512 + size, paddedEnd = offset + 512 + Math.ceil(size / 512) * 512;
    insist(paddedEnd <= bytes.length && bytes.subarray(end,paddedEnd).every(byte => byte === 0), 'Invalid TAR padding');
    files.set(name, bytes.subarray(offset + 512, end)); offset = paddedEnd;
  }
  throw Error('Missing TAR termination');
}

export function validateBundle(bytes, sourceBytes, closureBytes, expectedCaptureSha256) {
  insist(typeof expectedCaptureSha256 === 'string' && /^[a-f0-9]{64}$/.test(expectedCaptureSha256), 'Host-observed capture receipt pin required');
  insist(hash(sourceBytes) === sourcePin && hash(closureBytes) === closurePin, 'Reviewed source/closure pins required');
  const source = JSON.parse(decoder.decode(sourceBytes)), closure = JSON.parse(decoder.decode(closureBytes));
  const files = parseTar(bytes);
  insist(files.size === 87 && files.has('receipt.json'), 'All43 PNG/RGBA pairs and receipt required');
  const receiptBytes = files.get('receipt.json');
  insist(receiptBytes.length < 1024*1024, 'Receipt exceeds bound');
  const receipt = JSON.parse(decoder.decode(receiptBytes));
  insist(receipt.schema === 'original-landmark-canvas-browser-capture-v1' && receipt.ready === false && receipt.zeroWebGL === true && receipt.webglAttempts === 0 && receipt.threeRevision === '180', 'Original capture/HOLD receipt required');
  insist(receipt.sourceManifestSha256 === sourcePin && receipt.sourceClosureSha256 === closurePin && receipt.samplerCapabilityInput === 16, 'Original provenance mismatch');
  insist(canonical(receipt.originalSources) === canonical(source.sourceReceipts), 'Original source receipts changed');
  insist(canonical(receipt.recipePins) === canonical(Object.fromEntries(Object.entries(source.recipes).map(([key,value]) => [key,value.sha256]))), 'Original recipe receipts changed');
  const unhashed = {...receipt}; delete unhashed.canonicalSha256;
  insist(hash(Buffer.from(canonical(unhashed))) === receipt.canonicalSha256 && receipt.canonicalSha256 === expectedCaptureSha256, 'Host-observed capture receipt checksum mismatch');
  insist(Array.isArray(receipt.slots) && receipt.slots.length === 43 && receipt.browser?.colorSpace === 'srgb', 'All43 original sRGB slots required');
  const expected = closure.textures.flatMap(texture => texture.images.map((image,ordinal) => ({id:texture.id+'-image-'+ordinal,texture,image,ordinal})));
  insist(expected.length === 43, 'Original closure changed');
  const records = [];
  for (let i=0; i<expected.length; i++) {
    const slot = receipt.slots[i], want = expected[i];
    insist(slot.id === want.id && slot.textureId === want.texture.id && slot.ordinal === want.ordinal && slot.width === want.image.width && slot.height === want.image.height, 'Original slot identity/dimensions changed');
    insist(slot.cubeFaceOrdinal === (want.texture.type === 'CubeTexture' ? want.ordinal : null), 'Original cube face order changed');
    insist(slot.sourceRecipeSha256 === want.image.sourceRecipeSha256 && slot.sourceRecipeKey === want.image.recipeKey && canonical(slot.sourceSampler) === canonical(want.texture.sampler), 'Original slot recipe/sampler changed');
    insist(Array.isArray(slot.nativeFontMeasurements) && Array.isArray(slot.nativeTextDraws) && slot.platformFonts === null, 'Native capture font receipt required, admission still HOLD');
    for (const kind of ['rgba','png']) {
      const name = 'images/'+slot.id+'.'+kind, data = files.get(name);
      insist(data && data.length === slot[kind+'Bytes'] && hash(data) === slot[kind+'Sha256'], 'Original '+kind+' byte hash mismatch: '+slot.id);
      if (kind === 'rgba') insist(data.length === slot.width * slot.height * 4, 'Exact RGBA8 length required');
      else insist(data.length >= 33 && data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) && data.readUInt32BE(8) === 13 && data.subarray(12,16).toString('ascii') === 'IHDR' && data.readUInt32BE(16) === slot.width && data.readUInt32BE(20) === slot.height && data[24] === 8, 'Native PNG dimensions/bit depth mismatch');
      records.push({name,bytes:data.length,sha256:hash(data)});
    }
  }
  records.push({name:'receipt.json',bytes:receiptBytes.length,sha256:hash(receiptBytes)});
  return {receipt,files,records,archiveSha256:hash(bytes),ready:false};
}

export function startReceiver(base, outputRoot, expectedCaptureSha256) {
  insist(typeof expectedCaptureSha256 === 'string' && /^[a-f0-9]{64}$/.test(expectedCaptureSha256), 'Pinned root-observed capture receipt required before receiver start');
  insist(path.isAbsolute(base) && fs.realpathSync(base).toLowerCase() === base.toLowerCase() && path.isAbsolute(outputRoot) && fs.realpathSync(outputRoot).toLowerCase() === outputRoot.toLowerCase() && !fs.lstatSync(outputRoot).isSymbolicLink(), 'Resolved existing local directories required');
  const manifest = JSON.parse(fs.readFileSync(path.join(base,'package_manifest.json')));
  insist(manifest.schema === 'landmark-original-canvas-harness-preparation-v1' && manifest.ready === false, 'Reviewed prepared package required');
  const allowed = new Map(manifest.files.map(record => ['/'+record.name,record]));
  const sourceBytes = fs.readFileSync(path.join(base,'source.json')), closureBytes = fs.readFileSync(path.join(base,'closure.json'));
  insist(hash(sourceBytes) === sourcePin && hash(closureBytes) === closurePin, 'Prepared original pins mismatch');
  let busy = false;
  const server = http.createServer({requestTimeout:30000,headersTimeout:30000,connectionsCheckingInterval:1000},async (request,response) => {
    let partial = null;
    try {
      const origin = 'http://127.0.0.1:'+server.address().port;
      insist(request.headers.host === '127.0.0.1:'+server.address().port, 'Loopback host required');
      const pathname = new URL(request.url, origin).pathname;
      if (request.method === 'GET') {
        const record = allowed.get(pathname === '/' ? '/index.html' : pathname);
        insist(record, 'Path refused');
        const filename = path.join(base,record.name);
        insist(!fs.lstatSync(filename).isSymbolicLink() && fs.realpathSync(filename).toLowerCase() === filename.toLowerCase(), 'Linked asset refused');
        const data = fs.readFileSync(filename);
        insist(data.length === record.bytes && hash(data) === record.sha256, 'Prepared file changed');
        response.writeHead(200,{'Content-Type':record.name.endsWith('.json')?'application/json':record.name.endsWith('.html')?'text/html':'text/javascript','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self'; img-src 'self' blob:; style-src 'self' 'unsafe-inline'; object-src 'none'"});
        response.end(data); return;
      }
      insist(request.method === 'POST' && pathname === '/capture-bundle' && !busy, 'Method/path/busy refused');
      insist(request.headers.origin === origin && request.headers['content-type'] === 'application/x-tar', 'Explicit same-origin TAR only');
      const size = Number(request.headers['content-length']);
      insist(Number.isSafeInteger(size) && size > 0 && size <= MAX_BYTES, 'Bounded content length required');
      busy = true; const chunks = []; let received = 0;
      try {
        for await (const chunk of request) { received += chunk.length; insist(received <= size, 'Body size overflow'); chunks.push(chunk); }
        insist(received === size, 'Truncated body');
        const bytes = Buffer.concat(chunks), result = validateBundle(bytes,sourceBytes,closureBytes,expectedCaptureSha256);
        // No output allocation or write precedes complete original byte validation.
        partial = fs.mkdtempSync(path.join(outputRoot,'landmark-canvas-capture-'));
        for (const [name,data] of result.files) {
          const filename = path.join(partial,name); fs.mkdirSync(path.dirname(filename),{recursive:true});
          const fd = fs.openSync(filename,'wx'); try { fs.writeFileSync(fd,data); fs.fsyncSync(fd); } finally {fs.closeSync(fd);}
          insist(hash(fs.readFileSync(filename)) === hash(data), 'Stored image readback mismatch');
        }
        const diskReceipt = {schema:'original-landmark-canvas-local-storage-v1',archiveSha256:result.archiveSha256,captureCanonicalSha256:result.receipt.canonicalSha256,records:result.records,ready:false,gpu:false,productionInstalled:false,fontBackendAccepted:false,iblAccepted:false};
        const storageBytes=Buffer.from(JSON.stringify(diskReceipt,null,2)+'\n'),storagePath=path.join(partial,'storage_receipt.json');
        const storageFD=fs.openSync(storagePath,'wx');
        try{fs.writeFileSync(storageFD,storageBytes);fs.fsyncSync(storageFD);}finally{fs.closeSync(storageFD);}
        insist(fs.readFileSync(storagePath).equals(storageBytes),'Storage receipt readback mismatch');
        response.writeHead(200,{'Content-Type':'application/json','Cache-Control':'no-store'});
        response.end(JSON.stringify({ok:true,directory:partial,images:43,files:87,captureCanonicalSha256:result.receipt.canonicalSha256,ready:false,gpu:false}));
      } finally {busy=false;}
    } catch(error) {
      // A refused/incomplete upload must not remain on a keep-alive connection
      // awaiting its declared body and block the next request on that socket.
      if(response.destroyed||response.headersSent){request.destroy();response.destroy();return;}
      response.writeHead(403,{'Content-Type':'application/json','Cache-Control':'no-store','Connection':'close'});
      response.end(JSON.stringify({ok:false,error:error.message,retainedPartial:partial,ready:false}),()=>request.destroy());
    }
  });
  server.setTimeout(30000,socket=>socket.destroy());
  server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({url:'http://127.0.0.1:'+server.address().port,ready:false,gpu:false,browserStarted:false})));
  return server;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  insist(process.argv.length === 5, 'Usage: receive.mjs <prepared-absolute-directory> <existing-output-directory> <root-observed-capture-sha256>');
  startReceiver(path.resolve(process.argv[2]),path.resolve(process.argv[3]),process.argv[4]);
}
