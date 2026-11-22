-- My passport: each person keeps their passport details and photos in their profile, private to them
-- Run once: Supabase dashboard -> your barbershop project -> SQL Editor -> New query -> paste -> Run. Safe to run again.
-- Only the signed-in owner can read or change their own row and photos. Hosts and the site owner
-- (is_ce_admin) can't see them through the site. Photos go in a PRIVATE bucket and are shown with
-- short-lived links, so a photo link stops working after an hour.

create table if not exists public.ce_passports (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '' check (length(full_name) <= 120),
  number      text not null default '' check (length(number) <= 20),
  country     text not null default '' check (length(country) <= 80),
  nationality text not null default '' check (length(nationality) <= 80),
  birth_date  date,
  issue_date  date,
  expiry_date date,
  notes       text not null default '' check (length(notes) <= 500),
  photos      jsonb not null default '[]'::jsonb check (jsonb_typeof(photos) = 'array' and jsonb_array_length(photos) <= 4),
  updated_at  timestamptz not null default now()
);

alter table public.ce_passports enable row level security;
revoke all on public.ce_passports from anon;
grant select, insert, update, delete on public.ce_passports to authenticated;

drop policy if exists "ce_passports own row" on public.ce_passports;
create policy "ce_passports own row" on public.ce_passports
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Private photo bucket (5 MB per photo, pictures only).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ce-passports', 'ce-passports', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Each person can only touch files in their own folder: ce-passports/<their user id>/...
drop policy if exists "ce_passports read own"   on storage.objects;
drop policy if exists "ce_passports add own"    on storage.objects;
drop policy if exists "ce_passports change own" on storage.objects;
drop policy if exists "ce_passports remove own" on storage.objects;

create policy "ce_passports read own" on storage.objects for select to authenticated
  using (bucket_id = 'ce-passports' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "ce_passports add own" on storage.objects for insert to authenticated
  with check (bucket_id = 'ce-passports' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "ce_passports change own" on storage.objects for update to authenticated
  using (bucket_id = 'ce-passports' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "ce_passports remove own" on storage.objects for delete to authenticated
  using (bucket_id = 'ce-passports' and (storage.foldername(name))[1] = auth.uid()::text);

notify pgrst, 'reload schema';
