import { build } from 'esbuild';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
await build({entryPoints:['src/app.js'],bundle:true,minify:true,format:'esm',outfile:'app.js'});
let html=await readFile('index.html','utf8');
for(const file of ['app.js','style.css']){
 const hash=createHash('sha256').update(await readFile(file)).digest('hex').slice(0,12);
 const pattern=new RegExp(file.replace('.','\\.')+'\\?v=[^"\\s]+','g');
 html=html.replace(pattern,`${file}?v=${hash}`);
}
await writeFile('index.html',html);
console.log('Built browser bundle and updated asset versions.');
