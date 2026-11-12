-- =========================================================
-- StreamTunes · 0007_kiwi_profe_features.sql
-- Adaptaciones de segunda entrevista con Kiwi y criterios
-- técnicos de la devolución de la profesora.
-- =========================================================

-- 1. Opt-in de privacidad en profiles para el ranking público
alter table public.profiles
  add column if not exists is_public_profile boolean not null default false;

grant update (display_name, avatar_url, is_public_profile)
  on public.profiles to authenticated;

-- Permitir creación automática de perfil para usuarios anónimos (QR sin registro)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, is_public_profile)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'display_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Fan anónimo'
    ),
    false
  )
  on conflict (id) do nothing;
  return new;
end $$;

-- 2. Estado de donación (pending / approved / refunded)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'donation_status') then
    create type public.donation_status as enum ('pending', 'approved', 'refunded');
  end if;
end $$;

alter table public.donations
  add column if not exists status public.donation_status not null default 'approved';

-- Solo sumar al total acumulado cuando la donación está 'approved'
create or replace function public.accumulate_donation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' and (tg_op = 'INSERT' or old.status <> 'approved') then
    update public.bands
       set donations_collected = donations_collected + new.amount
     where id = new.band_id;
  elsif tg_op = 'UPDATE' and old.status = 'approved' and new.status = 'refunded' then
    update public.bands
       set donations_collected = greatest(0, donations_collected - old.amount)
     where id = new.band_id;
  end if;
  return new;
end $$;

drop trigger if exists donations_accumulate on public.donations;
create trigger donations_accumulate
  after insert or update of status on public.donations
  for each row execute function public.accumulate_donation();

-- 3. Letra sincronizada (LRC) en canciones y enlace de merch en bandas
alter table public.songs
  add column if not exists lyrics_lrc text;

alter table public.bands
  add column if not exists merch_url text;

grant update (bio, genre, location, cover_url, social_links, donation_goal, merch_url)
  on public.bands to authenticated;

grant insert (id, band_id, album_id, title, duration_s, genre, audio_path, cover_url, lyrics_lrc)
  on public.songs to authenticated;

-- 4. Agenda de fechas (band_events) con RLS
create table if not exists public.band_events (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  title      text not null check (char_length(title) between 2 and 100),
  venue      text not null check (char_length(venue) between 2 and 120),
  city       text not null default '',
  event_date timestamptz not null,
  ticket_url text,
  notes      text,
  created_at timestamptz not null default now()
);
create index if not exists band_events_band_date_idx on public.band_events (band_id, event_date);

alter table public.band_events enable row level security;

drop policy if exists "band_events_select_public" on public.band_events;
create policy "band_events_select_public" on public.band_events
  for select using (
    exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
    or public.is_band_member(band_id)
  );

drop policy if exists "band_events_insert_member" on public.band_events;
create policy "band_events_insert_member" on public.band_events
  for insert with check (public.is_band_member(band_id));

drop policy if exists "band_events_update_member" on public.band_events;
create policy "band_events_update_member" on public.band_events
  for update using (public.is_band_member(band_id));

drop policy if exists "band_events_delete_member" on public.band_events;
create policy "band_events_delete_member" on public.band_events
  for delete using (public.is_band_member(band_id));

-- 5. Galería de fotos de shows (band_photos) con RLS
create table if not exists public.band_photos (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  photo_url  text not null,
  caption    text,
  created_at timestamptz not null default now()
);
create index if not exists band_photos_band_idx on public.band_photos (band_id, created_at desc);

alter table public.band_photos enable row level security;

drop policy if exists "band_photos_select_public" on public.band_photos;
create policy "band_photos_select_public" on public.band_photos
  for select using (
    exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
    or public.is_band_member(band_id)
  );

drop policy if exists "band_photos_insert_member" on public.band_photos;
create policy "band_photos_insert_member" on public.band_photos
  for insert with check (public.is_band_member(band_id));

drop policy if exists "band_photos_delete_member" on public.band_photos;
create policy "band_photos_delete_member" on public.band_photos
  for delete using (public.is_band_member(band_id));

-- 6. Seguimiento de bandas por QR (anónimo o registrado)
create table if not exists public.band_follows (
  band_id    uuid not null references public.bands(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (band_id, user_id)
);
create index if not exists band_follows_band_idx on public.band_follows (band_id);

alter table public.band_follows enable row level security;

drop policy if exists "band_follows_select_public" on public.band_follows;
create policy "band_follows_select_public" on public.band_follows
  for select using (true);

drop policy if exists "band_follows_insert_own" on public.band_follows;
create policy "band_follows_insert_own" on public.band_follows
  for insert with check (auth.uid() = user_id);

drop policy if exists "band_follows_delete_own" on public.band_follows;
create policy "band_follows_delete_own" on public.band_follows
  for delete using (auth.uid() = user_id);

-- 7. Funciones RPC de agregación en SERVIDOR (Corrección de la profesora)
--    Reemplaza agregaciones en el cliente/Isolate sobre todos los oyentes.

create or replace function public.band_aggregated_stats(p_band uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_total_plays bigint;
  v_total_minutes bigint;
  v_top_songs jsonb;
  v_daily_stats jsonb;
begin
  select
    count(*),
    coalesce(sum(seconds_listened), 0) / 60
  into v_total_plays, v_total_minutes
  from public.play_events
  where band_id = p_band;

  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  into v_top_songs
  from (
    select
      s.id as song_id,
      s.title as title,
      count(pe.id) as plays,
      coalesce(sum(pe.seconds_listened), 0) / 60 as minutes
    from public.songs s
    left join public.play_events pe on pe.song_id = s.id
    where s.band_id = p_band and s.hidden = false
    group by s.id, s.title
    having count(pe.id) > 0
    order by plays desc, s.title asc
    limit 5
  ) t;

  select coalesce(jsonb_agg(row_to_json(d)), '[]'::jsonb)
  into v_daily_stats
  from (
    select
      to_char((created_at at time zone 'America/Argentina/Buenos_Aires')::date, 'YYYY-MM-DD') as day,
      count(*) as plays,
      coalesce(sum(seconds_listened), 0) / 60 as minutes
    from public.play_events
    where band_id = p_band
      and created_at >= now() - interval '7 days'
    group by 1
    order by 1 desc
  ) d;

  return jsonb_build_object(
    'total_plays', coalesce(v_total_plays, 0),
    'total_minutes', coalesce(v_total_minutes, 0),
    'top_songs', coalesce(v_top_songs, '[]'::jsonb),
    'daily_stats', coalesce(v_daily_stats, '[]'::jsonb)
  );
end $$;

-- Top 10 fans con opt-in de perfil público (anónimos si is_public_profile = false)
create or replace function public.band_top_fans(p_band uuid, p_days int default 30)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  minutes bigint,
  is_public boolean
)
language sql stable security definer set search_path = public as $$
  select
    pe.user_id,
    case when coalesce(p.is_public_profile, false) then p.display_name else 'Fan anónimo' end as display_name,
    case when coalesce(p.is_public_profile, false) then p.avatar_url else null end as avatar_url,
    greatest(1, sum(pe.seconds_listened) / 60) as minutes,
    coalesce(p.is_public_profile, false) as is_public
  from public.play_events pe
  left join public.profiles p on p.id = pe.user_id
  where pe.band_id = p_band
    and pe.user_id is not null
    and pe.created_at >= now() - make_interval(days => p_days)
  group by pe.user_id, p.is_public_profile, p.display_name, p.avatar_url
  order by sum(pe.seconds_listened) desc
  limit 10;
$$;

-- Actualizar Realtime publication para escuchar cambios en vivo de play_events
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'play_events'
  ) then
    alter publication supabase_realtime add table public.play_events;
  end if;
end $$;

