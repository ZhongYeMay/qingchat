// Only public web links: never forward credentials or signed/private URLs to the metadata provider.
export function publicUrl(value){
 if(typeof value!=='string'||value.length>2048)return null;
 try{const u=new URL(value),host=u.hostname.toLowerCase().replace(/\.$/,'');
 if(!['http:','https:'].includes(u.protocol)||u.username||u.password||u.port||!host.includes('.')||host.includes(':')||/^[\d.]+$/.test(host)||/(^|\.)(localhost|local|internal|invalid|test|example|onion)$/.test(host)||host.endsWith('.home.arpa'))return null;
 for(const key of u.searchParams.keys())if(/token|password|secret|signature|credential|session/i.test(key)||/^(auth|authorization|api[_-]?key|access[_-]?key|key|sig|code|jwt)$/i.test(key)||/^x-amz-/i.test(key))return null;
 u.hash='';return u.href;
 }catch{return null}
}
export function extractLinks(text){
 const found=[];for(const m of String(text).matchAll(/(?:https?:\/\/|www\.)[^\s<>"'\u3000\u3001\u3002\uff0c\uff01\uff1f\uff1b\uff08\uff09]+/gi)){
  let raw=m[0].replace(/[.,!?;:\]\}]+$/,'');while(raw.endsWith(')')&&(raw.match(/\)/g)||[]).length>(raw.match(/\(/g)||[]).length)raw=raw.slice(0,-1);
  try{const u=new URL(/^www\./i.test(raw)?'https://'+raw:raw);if(['http:','https:'].includes(u.protocol)&&!u.username&&!u.password)found.push({url:u.href,text:raw,start:m.index,end:m.index+raw.length})}catch{}
 }return found;
}
