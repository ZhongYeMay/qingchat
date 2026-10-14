-- Let uploaders remove unused files without deleting images already sent in a chat.
create policy qing_images_delete_unused on storage.objects for delete to authenticated
using (bucket_id='qingchat-images' and (storage.foldername(name))[2]=(select auth.uid())::text and not exists(select 1 from public.qing_messages m where m.image_path=storage.objects.name));
