import {createClient} from 'npm:@supabase/supabase-js@2.117.3';
const headers={'Access-Control-Allow-Origin':'https://zhongyemay.github.io','Access-Control-Allow-Headers':'apikey, authorization, content-type','Access-Control-Allow-Methods':'GET, OPTIONS','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json; charset=utf-8'}});
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});if(req.method!=='GET')return json({error:'Method not allowed'},405);
 const url=new URL(req.url),token=url.searchParams.get('token')||'';
 // A UUID capability grants access to this public invitation's fields and cover only.
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token))return json({error:'邀请不存在或已失效'},404);
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await db.from('chat_invites').select('title,description,byline,button_label,accent,background,layout,cover_path,expires_at').eq('id',token).eq('revoked',false).gt('expires_at',new Date().toISOString()).maybeSingle();
 if(error)return json({error:'邀请暂时无法加载'},503);if(!data)return json({error:'邀请已撤销、过期或不存在'},404);
 if(url.searchParams.has('cover')){if(!data.cover_path||!/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.webp$/i.test(data.cover_path))return json({error:'封面不可用'},404);const {data:image,error}=await db.storage.from('chat-invite-covers').download(data.cover_path);if(error||!image||image.type!=='image/webp')return json({error:'封面不可用'},404);return new Response(image,{headers:{...headers,'Content-Type':'image/webp'}})}
 const {cover_path,...fields}=data;return json({...fields,cover_url:cover_path?`${Deno.env.get('SUPABASE_URL')}/functions/v1/registration-invite?token=${encodeURIComponent(token)}&cover=1`:null});
});
