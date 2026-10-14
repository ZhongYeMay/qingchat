-- Use invoker rights and column-limited UPDATE instead of granting edits to receipt owners.
create function public.qing_mark_read(p_friendship uuid, p_last_id bigint) returns void
language plpgsql security invoker set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  insert into public.qing_reads(friendship_id,user_id,last_read_id)
  values(p_friendship,auth.uid(),p_last_id)
  on conflict(friendship_id,user_id) do update set last_read_id=greatest(public.qing_reads.last_read_id,excluded.last_read_id);
end $$;
revoke all on function public.qing_mark_read(uuid,bigint) from public,anon;
grant execute on function public.qing_mark_read(uuid,bigint) to authenticated;
