-- ====================================================================
-- StreamTunes · SCRIPT CONSOLIDADO DE CORRECCIÓN PARA SUPABASE
-- Copiar todo este contenido y pegarlo en:
-- Supabase Dashboard -> Proyecto -> SQL Editor -> New Query -> Run
-- ====================================================================

-- 1. PERMISOS GENERALES A NIVEL DE ESQUEMA Y TABLAS
-- Otorga permisos de lectura/escritura al rol authenticated (RLS se encarga de la seguridad)
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to authenticated;
grant all on all sequences in schema public to authenticated;
grant all on all routines in schema public to authenticated;

grant select on all tables in schema public to anon;
grant usage, select on all sequences in schema public to anon;

-- Permisos por defecto para futuras tablas
alter default privileges in schema public grant all on tables to authenticated;
alter default privileges in schema public grant all on sequences to authenticated;
alter default privileges in schema public grant select on tables to anon;

-- 2. HABILITAR PRIVILEGIOS EXPLÍCITOS EN SONGS, BANDS, DONATIONS, ALBUMS
grant insert, update, select, delete on public.songs to authenticated;
grant insert, update, select, delete on public.bands to authenticated;
grant insert, update, select, delete on public.albums to authenticated;
grant insert, update, select, delete on public.donations to authenticated;
grant insert, update, select, delete on public.profiles to authenticated;
grant insert, update, select, delete on public.band_members to authenticated;
grant insert, update, select, delete on public.play_events to authenticated;
grant insert, update, select, delete on public.playlists to authenticated;
grant insert, update, select, delete on public.playlist_songs to authenticated;

grant select on public.songs to anon;
grant select on public.bands to anon;
grant select on public.albums to anon;
grant select on public.donations to anon;
grant select on public.profiles to anon;

-- 3. COLUMNAS NUEVAS EN TABLAS EXISTENTES
alter table public.songs add column if not exists cover_url text;
alter table public.songs add column if not exists lyrics_lrc text;
alter table public.bands add column if not exists merch_url text;
alter table public.profiles add column if not exists is_public_profile boolean not null default false;

-- Estado de donación (pending / approved / refunded)
do $$
begin
  if not exists (select 1 from pg_type where typname = 'donation_status') then
    create type public.donation_status as enum ('pending', 'approved', 'refunded');
  end if;
end $$;

alter table public.donations
  add column if not exists status public.donation_status not null default 'approved';

-- 4. TABLAS DE KIWI (EVENTOS, FOTOS, SEGUIDORES)
create table if not exists public.band_events (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  title      text not null,
  venue      text not null,
  city       text not null default '',
  event_date timestamptz not null,
  ticket_url text,
  notes      text,
  created_at timestamptz not null default now()
);

create table if not exists public.band_photos (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  photo_url  text not null,
  caption    text,
  created_at timestamptz not null default now()
);

create table if not exists public.band_follows (
  band_id    uuid not null references public.bands(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (band_id, user_id)
);

-- RLS y permisos para las nuevas tablas
alter table public.band_events enable row level security;
alter table public.band_photos enable row level security;
alter table public.band_follows enable row level security;

grant all on public.band_events to authenticated;
grant select on public.band_events to anon;

grant all on public.band_photos to authenticated;
grant select on public.band_photos to anon;

grant all on public.band_follows to authenticated;
grant select on public.band_follows to anon;

-- Políticas RLS seguras
drop policy if exists "band_events_select" on public.band_events;
create policy "band_events_select" on public.band_events for select using (true);

drop policy if exists "band_events_write_member" on public.band_events;
create policy "band_events_write_member" on public.band_events for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

drop policy if exists "band_photos_select" on public.band_photos;
create policy "band_photos_select" on public.band_photos for select using (true);

drop policy if exists "band_photos_write_member" on public.band_photos;
create policy "band_photos_write_member" on public.band_photos for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

drop policy if exists "band_follows_select" on public.band_follows;
create policy "band_follows_select" on public.band_follows for select using (true);

drop policy if exists "band_follows_insert" on public.band_follows;
create policy "band_follows_insert" on public.band_follows for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "band_follows_delete" on public.band_follows;
create policy "band_follows_delete" on public.band_follows for delete to authenticated
  using (auth.uid() = user_id);

-- 5. FUNCIONES RPC DE ESTADÍSTICAS Y RANKING EN SERVIDOR
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
    greatest(1, coalesce(sum(pe.seconds_listened), 0) / 60) as minutes,
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
grant execute on function public.band_top_fans(uuid, int) to anon, authenticated;

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
grant execute on function public.band_aggregated_stats(uuid) to authenticated;

-- 6. POLÍTICA DE SUBIDA DE TEMAS (SONGS) EN RLS
-- Asegura que cualquier miembro de la banda o el creador de la banda pueda subir temas
drop policy if exists "banda gestiona songs" on public.songs;
create policy "banda gestiona songs" on public.songs for all to authenticated
  using (
    public.is_band_member(band_id)
    or exists (select 1 from public.bands b where b.id = band_id and b.created_by = auth.uid())
    or public.is_admin()
  )
  with check (
    public.is_band_member(band_id)
    or exists (select 1 from public.bands b where b.id = band_id and b.created_by = auth.uid())
    or public.is_admin()
  );

-- 7. STORAGE BUCKETS (AUDIO Y COVERS)
insert into storage.buckets (id, name, public, file_size_limit)
values ('audio', 'audio', true, 52428800)
on conflict (id) do update set public = true, file_size_limit = 52428800;

insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do update set public = true;

drop policy if exists "audio_select_public" on storage.objects;
create policy "audio_select_public" on storage.objects for select using (bucket_id = 'audio');

drop policy if exists "audio_insert_authenticated" on storage.objects;
create policy "audio_insert_authenticated" on storage.objects for insert to authenticated with check (bucket_id = 'audio');

drop policy if exists "covers_select_public" on storage.objects;
create policy "covers_select_public" on storage.objects for select using (bucket_id = 'covers');

drop policy if exists "covers_insert_authenticated" on storage.objects;
create policy "covers_insert_authenticated" on storage.objects for insert to authenticated with check (bucket_id = 'covers');

drop policy if exists "covers_update_authenticated" on storage.objects;
create policy "covers_update_authenticated" on storage.objects for update to authenticated using (bucket_id = 'covers');

