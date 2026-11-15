-- Buy tickets without a profile
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run. Safe to run again.
-- Guests give their name and email. Their tickets show up in the host's ticket list like any other,
-- so the host can mark them paid, check them in and email them.

-- Guest tickets have no profile behind them.
alter table public.ce_tickets alter column user_id drop not null;

create or replace function public.buy_tickets_guest(p_event uuid, p_name text, p_email text, p_qty int)
returns table (id uuid, code text, qty int, total numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.ce_events%rowtype;
  sold int;
  c text;
  new_id uuid;
begin
  p_name  := btrim(coalesce(p_name, ''));
  p_email := lower(btrim(coalesce(p_email, '')));
  if p_name = '' or length(p_name) > 120 then raise exception 'name_needed'; end if;
  if p_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' or length(p_email) > 160 then raise exception 'email_needed'; end if;
  if p_qty is null or p_qty < 1 or p_qty > 20 then raise exception 'qty_1_to_20'; end if;

  -- Lock the event so two buyers can't take the last tickets at the same time.
  select * into e from public.ce_events where ce_events.id = p_event for update;
  if not found or e.admin_hidden or e.status <> 'live' or not coalesce(e.tickets_on, false) or e.date::date < current_date then
    raise exception 'not_selling';
  end if;

  -- Same limit as signed-in buyers: 5 open orders per email per event.
  if (select count(*) from public.ce_tickets t where t.event_id = p_event and lower(t.email) = p_email and t.status <> 'cancelled') >= 5 then
    raise exception 'too_many_orders';
  end if;

  if e.ticket_limit is not null then
    select coalesce(sum(t.qty), 0) into sold from public.ce_tickets t where t.event_id = p_event and t.status <> 'cancelled';
    if sold + p_qty > e.ticket_limit then raise exception 'sold_out:%', greatest(e.ticket_limit - sold, 0); end if;
  end if;

  loop
    c := upper(substr(translate(md5(random()::text || clock_timestamp()::text), '01', ''), 1, 6));
    exit when length(c) = 6 and not exists (select 1 from public.ce_tickets t where t.event_id = p_event and t.code = c);
  end loop;

  insert into public.ce_tickets (event_id, user_id, name, email, qty, total, code, status, checked_in)
  values (p_event, null, p_name, p_email, p_qty, coalesce(e.ticket_price, 0) * p_qty, c, 'reserved', false)
  returning ce_tickets.id into new_id;

  return query select new_id, c, p_qty, coalesce(e.ticket_price, 0) * p_qty;
end;
$$;

revoke all on function public.buy_tickets_guest(uuid, text, text, int) from public;
grant execute on function public.buy_tickets_guest(uuid, text, text, int) to anon, authenticated;

notify pgrst, 'reload schema';
