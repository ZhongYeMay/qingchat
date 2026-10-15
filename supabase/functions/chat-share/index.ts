import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
const headers={'Access-Control-Allow-Origin':'https://zhongyemay.github.io','Access-Control-Allow-Headers':'apikey, authorization, content-type','Access-Control-Allow-Methods':'GET, OPTIONS','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json; charset=utf-8'}});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='GET')return json({error:'Method not allowed'},405);
 const url=new URL(req.url),token=url.searchParams.get('token')||'';
 // The unguessable, revocable share token is a capability granting only this snapshot.
 if(!uuid.test(token))return json({error:'分享不存在或已失效'},404);
 const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!key)return json({error:'服务暂不可用'},503);
 const db=createClient(Deno.env.get('SUPABASE_URL')!,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:share,error}=await db.from('chat_shares').select('id,title,snapshot,expires_at,created_at,revoked').eq('id',token).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(error)return json({error:'分享暂时无法加载'},503);
 if(!share)return json({error:'分享不存在、已撤销或已过期'},404);
 if(url.searchParams.has('image')){
  const index=Number(url.searchParams.get('image'));if(!Number.isInteger(index)||index<0||index>=share.snapshot.length)return json({error:'Image not found'},404);
  const path=share.snapshot[index]?.image_path;if(typeof path!=='string'||!/^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/[a-z0-9_-]{1,100}\.(png|jpe?g|webp|gif)$/i.test(path))return json({error:'Image not found'},404);
  const {data,error}=await db.storage.from('qingchat-images').download(path);
  if(error||!data)return json({error:'图片暂时无法加载'},404);
  const type=['image/png','image/jpeg','image/webp','image/gif'].includes(data.type)?data.type:'application/octet-stream';
  return new Response(data,{headers:{...headers,'Content-Type':type}});
 }
 const items=share.snapshot.map((m:{sender:string,body:string,image_path?:string,created_at:string},i:number)=>({sender:m.sender,body:m.body,created_at:m.created_at,image_url:m.image_path?`${Deno.env.get('SUPABASE_URL')}/functions/v1/chat-share?token=${encodeURIComponent(token)}&image=${i}`:null}));
 return json({id:share.id,title:share.title,created_at:share.created_at,expires_at:share.expires_at,count:items.length,messages:items});
});
