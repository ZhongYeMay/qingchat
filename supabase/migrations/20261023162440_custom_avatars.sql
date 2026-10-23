alter table public.qing_profiles add column avatar_path text;
alter table public.qing_profiles add constraint qing_profiles_avatar_owner check(avatar_path is null or avatar_path ~ ('^'||id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'));
create unique index qing_profiles_avatar_path on public.qing_profiles(avatar_path) where avatar_path is not null;
grant update(avatar_path) on public.qing_profiles to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('chat-avatars','chat-avatars',false,1048576,array['image/webp']);
create policy chat_avatars_read on storage.objects for select to authenticated using(bucket_id='chat-avatars' and ((storage.foldername(name))[1]=(select auth.uid())::text or exists(select 1 from public.qing_profiles p where p.avatar_path=name)));
create policy chat_avatars_upload on storage.objects for insert to authenticated with check(bucket_id='chat-avatars' and name ~ ('^'||(select auth.uid())::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'));
create policy chat_avatars_delete_unused on storage.objects for delete to authenticated using(bucket_id='chat-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.qing_profiles p where p.avatar_path=name));
