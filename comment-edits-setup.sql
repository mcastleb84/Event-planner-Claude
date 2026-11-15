-- Let people edit their own comments
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run.
-- People can only change the words of their own comments. Comments that were changed show "edited".

alter table public.ce_comments add column if not exists edited_at timestamptz;

create or replace function public.edit_my_comment(p_id text, p_body text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  if auth.uid() is null then return false; end if;
  p_body := btrim(coalesce(p_body, ''));
  if p_body = '' or length(p_body) > 1000 then raise exception 'comment must be 1 to 1000 characters'; end if;
  update public.ce_comments
     set body = p_body, edited_at = now()
   where id::text = p_id and user_id = auth.uid();
  get diagnostics n = row_count;
  return n = 1;
end;
$$;

revoke all on function public.edit_my_comment(text, text) from public, anon;
grant execute on function public.edit_my_comment(text, text) to authenticated;

notify pgrst, 'reload schema';
