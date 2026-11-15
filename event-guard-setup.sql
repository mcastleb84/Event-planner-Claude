-- Keep your review controls in your hands
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run. Safe to run again.
-- Hosts can still post and edit their own events, but only the site owner can:
--   * hide or un-hide an event
--   * mark an event as reviewed
--   * move an event to a different host
-- New events always start as "not reviewed" so they show up in your Review list.

create or replace function public.ce_events_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- SQL Editor and server jobs (no signed-in person) and the site owner are not limited.
  if auth.uid() is null or public.is_ce_admin() then return new; end if;

  if tg_op = 'INSERT' then
    if new.host_id is distinct from auth.uid() then raise exception 'You can only post events as yourself'; end if;
    new.admin_hidden := false;
    new.reviewed := false;
    return new;
  end if;

  -- UPDATE by a host
  new.host_id := old.host_id;
  new.admin_hidden := old.admin_hidden;
  if coalesce(new.reviewed, false) and not coalesce(old.reviewed, false) then new.reviewed := old.reviewed; end if;
  return new;
end;
$$;

drop trigger if exists ce_events_guard on public.ce_events;
create trigger ce_events_guard before insert or update on public.ce_events
  for each row execute function public.ce_events_guard();
