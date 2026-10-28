-- Blue Shark Airways portal — Supabase PostgreSQL schema
create extension if not exists pgcrypto;

create type public.member_status as enum ('pending','approved','rejected','suspended');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default '',
  callsign text unique,
  status public.member_status not null default 'pending',
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id)
);

create table public.fleet (
  id uuid primary key default gen_random_uuid(),
  registration text not null unique,
  aircraft_family text not null,
  aircraft_model text not null,
  home_hub text,
  seats integer check (seats is null or seats >= 0),
  status text not null default 'available' check (status in ('available','maintenance','retired')),
  created_at timestamptz not null default now()
);

create table public.flights (
  id uuid primary key default gen_random_uuid(),
  pilot_id uuid not null references public.profiles(id),
  fleet_id uuid references public.fleet(id),
  callsign text,
  origin_icao char(4),
  destination_icao char(4),
  source text not null default 'manual' check (source in ('acars','vatsim','manual')),
  status text not null default 'planned' check (status in ('planned','boarding','enroute','landed','cancelled')),
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.live_positions (
  id uuid primary key default gen_random_uuid(),
  flight_id uuid references public.flights(id) on delete cascade,
  pilot_id uuid references public.profiles(id) on delete cascade,
  source text not null check (source in ('acars','vatsim')),
  callsign text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  altitude_ft integer,
  ground_speed_kt integer,
  heading integer,
  observed_at timestamptz not null default now(),
  unique (source, callsign)
);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null check (category in ('documentation','acars','livery')),
  description text,
  file_path text,
  public_url text,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create index live_positions_observed_at_idx on public.live_positions(observed_at desc);
create index flights_pilot_created_idx on public.flights(pilot_id, created_at desc);

-- New accounts get a pending profile. Never accept is_admin/status from signup metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, display_name, callsign)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(upper(trim(coalesce(new.raw_user_meta_data ->> 'callsign', ''))), '')
  );
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_approved_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.status = 'approved');
$$;
create or replace function public.is_portal_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_admin = true and p.status = 'approved');
$$;

alter table public.profiles enable row level security;
alter table public.fleet enable row level security;
alter table public.flights enable row level security;
alter table public.live_positions enable row level security;
alter table public.resources enable row level security;

create policy "members can read own profile" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.is_portal_admin());
-- No direct profile UPDATE policy: sensitive fields (status/is_admin) are changed only by admin RPC.
create or replace function public.admin_review_member(target_user_id uuid, new_status public.member_status)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_portal_admin() then raise exception 'admin access required'; end if;
  if new_status not in ('approved','rejected','suspended') then raise exception 'invalid review status'; end if;
  update public.profiles set status = new_status, reviewed_at = now(), reviewed_by = (select auth.uid())
  where id = target_user_id;
end;
$$;
revoke all on function public.admin_review_member(uuid, public.member_status) from public;
grant execute on function public.admin_review_member(uuid, public.member_status) to authenticated;
create policy "approved members read fleet" on public.fleet for select to authenticated using (public.is_approved_member());
create policy "admins manage fleet" on public.fleet for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());
create policy "pilots read own flights and admins read all" on public.flights for select to authenticated using (pilot_id = (select auth.uid()) or public.is_portal_admin());
create policy "approved pilots create own flights" on public.flights for insert to authenticated with check (pilot_id = (select auth.uid()) and public.is_approved_member());
create policy "pilots update own flights and admins manage" on public.flights for update to authenticated using ((pilot_id = (select auth.uid()) and public.is_approved_member()) or public.is_portal_admin()) with check ((pilot_id = (select auth.uid()) and public.is_approved_member()) or public.is_portal_admin());
create policy "approved members read fresh positions" on public.live_positions for select to authenticated using (public.is_approved_member());
create policy "admins manage positions" on public.live_positions for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());
create policy "published resources visible to approved members" on public.resources for select to authenticated using (published and public.is_approved_member());
create policy "admins manage resources" on public.resources for all to authenticated using (public.is_portal_admin()) with check (public.is_portal_admin());

-- First administrator: after signing up, run the one-time SQL below in Supabase SQL Editor,
-- replacing the email. Do not expose service_role keys in browser code.
-- update public.profiles set is_admin = true, status = 'approved', reviewed_at = now()
-- where email = 'YOUR_ADMIN_EMAIL';

-- Initial aircraft visible in the supplied fleet screenshots. Expand via the admin UI later.
insert into public.fleet (registration, aircraft_family, aircraft_model, home_hub, seats) values
('4L-BRX','A319','Airbus A319','UGTB',150),
('RA-73063','A319','Airbus A319','UNNT',150),
('RA-73026','A319','Airbus A319','UUEE',150),
('RA-73320','A320','Airbus A320','UUEE',180),
('RA-73321','A320','Airbus A320','ULLI',180),
('RA-73322','A320','Airbus A320neo','UNNT',180),
('RA-73319','A319','Airbus A319','UUEE',150)
on conflict (registration) do nothing;
