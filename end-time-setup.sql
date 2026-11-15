-- Event end times
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run.
-- Adds an optional end time to events. An end time earlier than the start means it ends the next day.

alter table public.ce_events add column if not exists end_time time;

notify pgrst, 'reload schema';
