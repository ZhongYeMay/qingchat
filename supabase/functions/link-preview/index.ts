import {createClient} from 'npm:@supabase/supabase-js@2.117.3';
import {createHandler} from './handler.js';
// Validate each user's token with Auth; no service-role access or database writes.
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
Deno.serve(createHandler({authenticate:async(token:string)=>{const {data,error}=await db.auth.getUser(token);return error?null:data.user}}));
