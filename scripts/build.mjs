import { build } from 'esbuild';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
await build({entryPoints:['src/app.js','src/share-page.js'],entryNames:'[name]',bundle:true,minify:true,format:'esm',outdir:'.',outExtension:{'.js':'.js'}});
// Keep established public entry names stable.
await writeFile('share.js',await readFile('share-page.js'));
const {unlink}=await import('node:fs/promises');await unlink('share-page.js');
for(const page of ['index.html','share.html']){
 let html=await readFile(page,'utf8');
 for(const file of ['app.js','share.js','style.css']){
  const hash=createHash('sha256').update(await readFile(file)).digest('hex').slice(0,12);
  const pattern=new RegExp(file.replace('.','\\.')+'\\?v=[^"\\s]+','g');
  html=html.replace(pattern,`${file}?v=${hash}`);
 }
 await writeFile(page,html);
}
console.log('Built Chat and sharing page with content-versioned assets.');
