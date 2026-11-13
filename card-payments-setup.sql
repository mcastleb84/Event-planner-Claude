-- Card & app payments for tickets
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run.
-- Lets each host choose how they get paid: debit/credit card link, Cash App, Venmo, PayPal, Zelle, at the door.

alter table public.ce_events
  add column if not exists pay_options jsonb not null default '{}'::jsonb;

-- Keep it small and tidy (only known keys, short values).
alter table public.ce_events drop constraint if exists ce_events_pay_options_ok;
alter table public.ce_events add constraint ce_events_pay_options_ok check (
  jsonb_typeof(pay_options) = 'object'
  and length(pay_options::text) < 1000
  and (pay_options - array['card','cashapp','venmo','paypal','zelle','door']) = '{}'::jsonb
);

-- Existing events that already had a payment link keep it as their card option.
update public.ce_events
   set pay_options = jsonb_build_object('card', ticket_link)
 where coalesce(ticket_link, '') <> '' and pay_options = '{}'::jsonb;

-- Refresh the API so the website sees the new column right away.
notify pgrst, 'reload schema';
