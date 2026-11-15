-- Report a post
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run. Safe to run again.
-- Anyone can report an event. A reported event goes back into your Review list with the reasons.
-- Only the site owner can read reports.

create table if not exists public.ce_reports (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.ce_events(id) on delete cascade,
  user_id uuid,
  email text,
  reason text not null,
  details text,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists ce_reports_event_idx on public.ce_reports (event_id) where not resolved;

alter table public.ce_reports enable row level security;

-- Nobody reads or writes the table directly except the site owner.
drop policy if exists ce_reports_owner_read on public.ce_reports;
create policy ce_reports_owner_read on public.ce_reports for select to authenticated using (public.is_ce_admin());
drop policy if exists ce_reports_owner_update on public.ce_reports;
create policy ce_reports_owner_update on public.ce_reports for update to authenticated using (public.is_ce_admin()) with check (public.is_ce_admin());
drop policy if exists ce_reports_owner_delete on public.ce_reports;
create policy ce_reports_owner_delete on public.ce_reports for delete to authenticated using (public.is_ce_admin());

-- Reports come in through this function, which checks the input and limits floods.
create or replace function public.report_event(p_event uuid, p_reason text, p_details text, p_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  p_reason  := btrim(coalesce(p_reason, ''));
  p_details := nullif(btrim(coalesce(p_details, '')), '');
  p_email   := nullif(lower(btrim(coalesce(p_email, ''))), '');
  if p_reason = '' or length(p_reason) > 80 then raise exception 'reason_needed'; end if;
  if length(coalesce(p_details, '')) > 1000 then raise exception 'details_too_long'; end if;
  if p_email is not null and (p_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or length(p_email) > 160) then raise exception 'bad_email'; end if;
  if not exists (select 1 from public.ce_events where id = p_event) then raise exception 'not_found'; end if;

  -- Enough open reports on one event, and per signed-in person.
  if (select count(*) from public.ce_reports where event_id = p_event and not resolved) >= 25 then raise exception 'too_many_reports'; end if;
  if auth.uid() is not null and exists (select 1 from public.ce_reports where event_id = p_event and user_id = auth.uid() and not resolved) then
    raise exception 'too_many_reports';
  end if;

  insert into public.ce_reports (event_id, user_id, email, reason, details)
  values (p_event, auth.uid(), p_email, p_reason, p_details);

  -- Put the event back on the owner's Review list.
  update public.ce_events set reviewed = false where id = p_event;
  return true;
end;
$$;

revoke all on function public.report_event(uuid, text, text, text) from public;
grant execute on function public.report_event(uuid, text, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
