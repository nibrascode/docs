-- Nibras Docs schema (matches Flutter SupabaseService)

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  is_premium boolean default false,
  premium_until timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled Document',
  content text default '',
  is_starred boolean default false,
  word_count int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists documents_user_id_idx on public.documents(user_id);
create index if not exists documents_updated_at_idx on public.documents(updated_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.documents enable row level security;

drop policy if exists "Users read own profile" on public.profiles;
drop policy if exists "Users update own profile" on public.profiles;
drop policy if exists "Users CRUD own documents" on public.documents;

create policy "Users read own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users update own profile"
  on public.profiles for update using (auth.uid() = id);

create policy "Users CRUD own documents"
  on public.documents for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
