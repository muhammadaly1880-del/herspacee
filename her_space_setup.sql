-- ============================================================
-- HER SPACE — Supabase setup script
-- Run this once in your Supabase project's SQL Editor
-- (Dashboard → SQL Editor → New query → paste all of this → Run)
-- ============================================================

create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql set search_path = public;

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "own profile" on public.profiles for all to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);
create trigger profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- journey_entries (MDCAT journey, one per user) ----------
create table public.journey_entries (
  user_id uuid primary key references auth.users(id) on delete cascade,
  hardest_part text default '',
  memorable_moment text default '',
  lessons text default '',
  proud_of text default '',
  advice text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.journey_entries enable row level security;
create policy "own journey" on public.journey_entries for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger journey_updated before update on public.journey_entries
  for each row execute function public.set_updated_at();

-- ---------- future_letters (Dear Future Me, one per user) ----------
create table public.future_letters (
  user_id uuid primary key references auth.users(id) on delete cascade,
  where_i_am text default '',
  hopes text default '',
  doctor_i_want text default '',
  never_forget text default '',
  proud_today text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.future_letters enable row level security;
create policy "own letter" on public.future_letters for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger letters_updated before update on public.future_letters
  for each row execute function public.set_updated_at();

-- ---------- goals ----------
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default 'Personal Goals',
  title text not null,
  description text default '',
  target_date date,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.goals enable row level security;
create policy "own goals" on public.goals for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger goals_updated before update on public.goals
  for each row execute function public.set_updated_at();

-- ---------- memories ----------
create table public.memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  memory_date date,
  photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.memories enable row level security;
create policy "own memories" on public.memories for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger memories_updated before update on public.memories
  for each row execute function public.set_updated_at();

-- ---------- achievements ----------
create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  achieved_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.achievements enable row level security;
create policy "own achievements" on public.achievements for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger achievements_updated before update on public.achievements
  for each row execute function public.set_updated_at();

-- ---------- dream_items ----------
create table public.dream_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'dream',
  content text not null default '',
  photo_path text,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.dream_items enable row level security;
create policy "own dream items" on public.dream_items for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger dream_items_updated before update on public.dream_items
  for each row execute function public.set_updated_at();

-- ---------- notes ----------
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled',
  content text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.notes enable row level security;
create policy "own notes" on public.notes for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger notes_updated before update on public.notes
  for each row execute function public.set_updated_at();

-- ---------- private photo storage ----------
insert into storage.buckets (id, name, public)
values ('her-space', 'her-space', false)
on conflict (id) do nothing;

create policy "own files read" on storage.objects for select to authenticated
  using (bucket_id = 'her-space' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "own files insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'her-space' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "own files update" on storage.objects for update to authenticated
  using (bucket_id = 'her-space' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "own files delete" on storage.objects for delete to authenticated
  using (bucket_id = 'her-space' and auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- Done. Every table only allows a signed-in user to see/edit
-- their own rows (auth.uid() = user_id), enforced by Postgres
-- itself — not by the frontend. Photos are private per-user too.
-- ============================================================