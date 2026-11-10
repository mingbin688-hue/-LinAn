import fs from 'node:fs/promises';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {build} from 'esbuild';
import {gzipSync} from 'node:zlib';
const root=process.cwd();
for(const args of [['node_modules/vue-tsc/bin/vue-tsc.js','--noEmit','-p','frontend/tsconfig.json'],['node_modules/vite/bin/vite.js','build','--config','frontend/vite.config.ts','frontend']]){
 const r=spawnSync(process.execPath,args,{cwd:root,stdio:'inherit'});if(r.status!==0)process.exit(r.status||1);
}
const dir=path.join(root,'frontend/dist'),assets={};
async function walk(base){for(const entry of await fs.readdir(base,{withFileTypes:true})){const p=path.join(base,entry.name);if(entry.isDirectory())await walk(p);else{const key='/'+path.relative(dir,p).replaceAll('\\','/'),ext=path.extname(p);assets[key]={body:await fs.readFile(p,'utf8'),mime:({'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'})[ext]||'text/plain; charset=utf-8'}}}}
await walk(dir);await fs.mkdir('generated',{recursive:true});await fs.writeFile('generated/assets.json',JSON.stringify(assets));
await fs.mkdir('dist/server',{recursive:true});
await build({entryPoints:['worker/index.mjs'],outfile:'dist/server/index.js',bundle:true,format:'esm',platform:'browser',target:'es2022',minify:true,legalComments:'inline'});
await fs.mkdir('dist/.openai',{recursive:true});await fs.copyFile('.openai/hosting.json','dist/.openai/hosting.json');
await fs.cp('drizzle','dist/.openai/drizzle',{recursive:true});
const output=await fs.readFile('dist/server/index.js');console.log(JSON.stringify({workerBytes:output.length,gzipBytes:gzipSync(output).length,assets:Object.keys(assets).length}));
