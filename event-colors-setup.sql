-- Event colors and face photo
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run.
-- Lets each host pick a button color, a page color (or two blended), and whether the face photo fills its frame.
-- The face photo itself is just the first photo in the event's files, so it needs no new column.

alter table public.ce_events
  add column if not exists theme jsonb not null default '{}'::jsonb;

-- Only known keys, only #rrggbb colors, kept small.
alter table public.ce_events drop constraint if exists ce_events_theme_ok;
alter table public.ce_events add constraint ce_events_theme_ok check (
  jsonb_typeof(theme) = 'object'
  and length(theme::text) < 300
  and (theme - array['button','page','page2','fill']) = '{}'::jsonb
  and (theme->>'button' is null or theme->>'button' ~ '^#[0-9a-fA-F]{6}$')
  and (theme->>'page'   is null or theme->>'page'   ~ '^#[0-9a-fA-F]{6}$')
  and (theme->>'page2'  is null or theme->>'page2'  ~ '^#[0-9a-fA-F]{6}$')
  and (theme->'fill' is null or jsonb_typeof(theme->'fill') = 'boolean')
);

-- Refresh the API so the website sees the new column right away.
notify pgrst, 'reload schema';
