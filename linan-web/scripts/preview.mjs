import http from 'node:http';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {localD1} from './d1-local.mjs';
fs.mkdirSync('runtime',{recursive:true});
const env={DB:localD1('runtime/cloud-preview.sqlite3')};
const worker=(await import(pathToFileURL(process.cwd()+'/dist/server/index.js').href)).default;
http.createServer(async(req,res)=>{
 try{const chunks=[];for await(const part of req)chunks.push(part);const body=Buffer.concat(chunks);
  const r=await worker.fetch(new Request('http://127.0.0.1:8787'+req.url,{method:req.method,headers:req.headers,...(body.length?{body,duplex:'half'}:{})}),env,{});
  res.writeHead(r.status,Object.fromEntries(r.headers));res.end(Buffer.from(await r.arrayBuffer()));
 }catch(e){console.error(e);res.writeHead(500);res.end('Local preview error')}
}).listen(8787,'127.0.0.1',()=>console.log('Cloud-compatible preview: http://127.0.0.1:8787'));
