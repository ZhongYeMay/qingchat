import {publicUrl} from './policy.js';
const headers={'Access-Control-Allow-Origin':'https://zhongyemay.github.io','Access-Control-Allow-Headers':'apikey, authorization, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json; charset=utf-8'}});
export function createHandler({authenticate,fetchMetadata=fetch,now=Date.now}){
 const cache=new Map(),rates=new Map(),pending=new Map();
 const put=(key,data,ttl)=>{cache.delete(key);cache.set(key,{data,until:now()+ttl});while(cache.size>300)cache.delete(cache.keys().next().value)};
 async function metadata(url){
  const cached=cache.get(url);if(cached&&cached.until>now())return cached.data;if(pending.has(url))return pending.get(url);
  const task=(async()=>{try{
   // Fixed provider origin. No user-supplied URL is fetched by this service.
   const endpoint=new URL('https://api.microlink.io/');endpoint.searchParams.set('url',url);
   const r=await fetchMetadata(endpoint.href,{signal:AbortSignal.timeout(12000),redirect:'error',headers:{Accept:'application/json'}});
   if(!r.ok||Number(r.headers.get('content-length'))>262144)throw new Error('Provider unavailable');
   const reader=r.body.getReader();let size=0;const chunks=[];try{while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>262144)throw new Error('Response too large');chunks.push(value)}}finally{await reader.cancel().catch(()=>{})}
   const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length}const payload=JSON.parse(new TextDecoder().decode(bytes));if(payload.status!=='success'||!payload.data)throw new Error('No metadata');
   const data=payload.data,clean=(v,n)=>typeof v==='string'?v.replace(/[\u0000-\u001f]/g,' ').trim().slice(0,n):'';
   // Use the original destination in the card; a redirect cannot silently replace its domain.
   const result={url,site:new URL(url).hostname,title:clean(data.title,200)||new URL(url).hostname,description:clean(data.description,400),image:publicUrl(data.image?.url),available:true};
   put(url,result,900000);return result;
  }catch{const result={url,site:new URL(url).hostname,available:false};put(url,result,60000);return result}finally{pending.delete(url)}})();pending.set(url,task);return task;
 }
 return async req=>{if(req.method==='OPTIONS')return new Response(null,{status:204,headers});if(req.method!=='POST')return json({error:'Method not allowed'},405);
  const auth=req.headers.get('authorization')||'';if(!/^Bearer \S+$/i.test(auth))return json({error:'请先登录'},401);
  let user;try{user=await authenticate(auth.slice(7))}catch{}if(!user)return json({error:'请先登录'},401);
  if(Number(req.headers.get('content-length'))>8192)return json({error:'Invalid request'},413);
  let input;try{const body=await req.text();if(body.length>8192)return json({error:'Invalid request'},413);input=JSON.parse(body)}catch{return json({error:'Invalid request'},400)}
  const url=publicUrl(input?.url);if(!url)return json({error:'此链接不提供自动预览'},400);
  const t=now(),rate=rates.get(user.id);if(rate&&rate.until>t&&rate.count>=40)return json({error:'预览请求较多，请稍后再试'},429);
  if(rate&&rate.until>t)rate.count++;else{rates.delete(user.id);rates.set(user.id,{count:1,until:t+60000})}while(rates.size>2000)rates.delete(rates.keys().next().value);
  if(pending.size>=8&&!pending.has(url))return json({error:'请稍后重试'},429);
  return json(await metadata(url));
 };
}
