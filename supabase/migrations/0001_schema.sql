-- =========================================================
-- StreamTunes · 0001_schema.sql
-- Tipos, tablas, funciones auxiliares y triggers de negocio.
-- NO EJECUTADO TODAVÍA: probar primero en un proyecto Supabase de prueba.
-- =========================================================

-- 0. Tipos ------------------------------------------------
create type public.band_status   as enum ('pending', 'approved', 'suspended');
create type public.member_role   as enum ('owner', 'member');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');

-- 1. Personas y configuración -----------------------------
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 50),
  avatar_url   text,
  created_at   timestamptz not null default now()
);

create table public.app_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade
);

-- Límites "por ahora" (Kiwi): se cambian con un UPDATE, sin tocar código
create table public.app_config (
  key   text primary key,
  value integer not null
);
insert into public.app_config (key, value) values
  ('max_songs_per_band',   20),
  ('max_albums_per_band',   2),
  ('max_donation_ars',   5000),
  ('reports_to_hide',       3),   -- reportes distintos que ocultan un tema hasta revisión
  ('spend_cap_active',      0);   -- 1 = la app muestra "alta demanda"

-- Crear el perfil automáticamente al registrarse
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'display_name', ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Bandas y membresías ----------------------------------
create table public.bands (
  id                  uuid primary key default gen_random_uuid(),
  slug                text not null unique check (slug ~ '^[a-z0-9-]{2,60}$'),
  name                text not null check (char_length(name) between 2 and 60),
  bio                 text,
  genre               text,
  location            text,
  cover_url           text,
  social_links        jsonb not null default '{}'::jsonb,
  donation_goal       numeric(12,2) not null default 0 check (donation_goal >= 0),
  donations_collected numeric(12,2) not null default 0,
  status              public.band_status not null default 'pending',
  created_by          uuid not null references public.profiles(id),
  created_at          timestamptz not null default now()
);
create index on public.bands (status);

create table public.band_members (
  band_id    uuid not null references public.bands(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.member_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (band_id, user_id)
);
create index on public.band_members (user_id);

-- Funciones auxiliares para RLS (security definer: evitan recursión de políticas)
create function public.is_band_member(p_band uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.band_members
    where band_id = p_band and user_id = auth.uid()
  );
$$;

create function public.is_band_owner(p_band uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.band_members
    where band_id = p_band and user_id = auth.uid() and role = 'owner'
  );
$$;

create function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

-- Quien crea la banda queda como owner
create function public.add_creator_as_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.band_members (band_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end $$;

create trigger on_band_created
  after insert on public.bands
  for each row execute function public.add_creator_as_owner();

-- 3. Música -----------------------------------------------
create table public.albums (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  title      text not null,
  cover_url  text,
  created_at timestamptz not null default now(),
  unique (band_id, title)
);

create table public.songs (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  album_id   uuid references public.albums(id) on delete set null,
  title      text not null check (char_length(title) between 1 and 120),
  genre      text,
  audio_path text not null,                    -- ruta en Storage: {band_id}/{song_id}.mp3
  duration_s integer not null check (duration_s > 0),
  play_count bigint not null default 0,
  hidden     boolean not null default false,   -- lo oculta un moderador o 3 reportes
  created_at timestamptz not null default now()
);
create index on public.songs (band_id);
create index on public.songs (created_at desc);   -- "últimos lanzamientos"

-- Límites reales (no se pueden saltear desde la app)
create function public.enforce_song_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_songs_per_band';
  select count(*) into v_actual from public.songs where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % temas por banda.', v_max
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger songs_limit before insert on public.songs
  for each row execute function public.enforce_song_limit();

create function public.enforce_album_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int; v_actual int;
begin
  select value into v_max from public.app_config where key = 'max_albums_per_band';
  select count(*) into v_actual from public.albums where band_id = new.band_id;
  if v_actual >= v_max then
    raise exception 'Límite de subida alcanzado: máximo % álbumes por banda.', v_max
      using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger albums_limit before insert on public.albums
  for each row execute function public.enforce_album_limit();

-- Un tema solo puede estar en un álbum de su misma banda
create function public.enforce_song_album_same_band()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.album_id is not null and not exists (
    select 1 from public.albums where id = new.album_id and band_id = new.band_id
  ) then
    raise exception 'El álbum no pertenece a la banda del tema.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger songs_album_same_band before insert or update of album_id, band_id on public.songs
  for each row execute function public.enforce_song_album_same_band();

-- 4. Playlists --------------------------------------------
create table public.playlists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  description text,
  is_public   boolean not null default false,
  created_at  timestamptz not null default now()
);
create index on public.playlists (user_id);

create table public.playlist_songs (
  playlist_id uuid not null references public.playlists(id) on delete cascade,
  song_id     uuid not null references public.songs(id)     on delete cascade,
  position    integer not null default 0,
  added_at    timestamptz not null default now(),
  primary key (playlist_id, song_id)
);

-- 5. Donaciones, reproducciones y estadísticas ------------
create table public.donations (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  donor_id   uuid not null references public.profiles(id),
  amount     numeric(12,2) not null check (amount > 0),
  currency   text not null default 'ARS',
  message    text check (char_length(message) <= 200),
  is_public  boolean not null default true,          -- ¿aparece en el muro público?
  created_at timestamptz not null default now()
);
create index on public.donations (band_id, created_at desc);

-- Valida el tope por donación (control de gasto) antes de insertar
create function public.validate_donation()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_max int;
begin
  select value into v_max from public.app_config where key = 'max_donation_ars';
  if new.amount > v_max then
    raise exception 'El monto máximo por donación es $% ARS.', v_max using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.bands where id = new.band_id and status = 'approved') then
    raise exception 'Solo se puede donar a bandas aprobadas.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger donations_validate before insert on public.donations
  for each row execute function public.validate_donation();

-- Acumula en la banda una vez insertada la donación
create function public.accumulate_donation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.bands
     set donations_collected = donations_collected + new.amount
   where id = new.band_id;
  return new;
end $$;
create trigger donations_accumulate after insert on public.donations
  for each row execute function public.accumulate_donation();

create table public.play_events (
  id               bigint generated always as identity primary key,
  song_id          uuid not null references public.songs(id) on delete cascade,
  band_id          uuid not null references public.bands(id) on delete cascade,
  user_id          uuid references public.profiles(id) on delete set null,
  seconds_listened integer not null check (seconds_listened >= 0),
  city             text,
  created_at       timestamptz not null default now()
);
create index on public.play_events (band_id, created_at);
create index on public.play_events (song_id);

-- play_count solo lo incrementa este trigger (la app no lo puede editar)
create function public.bump_play_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.songs set play_count = play_count + 1 where id = new.song_id;
  return new;
end $$;
create trigger play_events_bump after insert on public.play_events
  for each row execute function public.bump_play_count();

create table public.band_daily_stats (
  band_id          uuid not null references public.bands(id) on delete cascade,
  day              date not null,
  plays            integer not null default 0,
  minutes          integer not null default 0,
  unique_listeners integer not null default 0,
  primary key (band_id, day)
);

-- Recalcula un día completo (se programa cada madrugada)
create function public.refresh_band_daily_stats(p_day date default (current_date - 1))
returns void language sql security definer set search_path = public as $$
  insert into public.band_daily_stats (band_id, day, plays, minutes, unique_listeners)
  select band_id, p_day, count(*), coalesce(sum(seconds_listened), 0) / 60,
         count(distinct user_id)
  from public.play_events
  where (created_at at time zone 'America/Argentina/Buenos_Aires')::date = p_day
  group by band_id
  on conflict (band_id, day) do update
    set plays = excluded.plays,
        minutes = excluded.minutes,
        unique_listeners = excluded.unique_listeners;
$$;

-- Ranking de oyentes (solo lo puede pedir un miembro de esa banda)
create function public.band_top_listeners(p_band uuid, p_days int default 30)
returns table (user_id uuid, display_name text, minutes bigint)
language sql stable security definer set search_path = public as $$
  select pe.user_id, p.display_name, sum(pe.seconds_listened) / 60
  from public.play_events pe
  join public.profiles p on p.id = pe.user_id
  where pe.band_id = p_band
    and public.is_band_member(p_band)
    and pe.created_at >= now() - make_interval(days => p_days)
  group by pe.user_id, p.display_name
  order by 3 desc
  limit 10;
$$;

-- 6. Historias y reportes ---------------------------------
create table public.stories (
  id         uuid primary key default gen_random_uuid(),
  band_id    uuid not null references public.bands(id) on delete cascade,
  video_path text not null,
  duration_s integer not null check (duration_s between 1 and 15),
  created_at timestamptz not null default now()
);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id),
  band_id     uuid references public.bands(id) on delete cascade,
  song_id     uuid references public.songs(id) on delete cascade,
  reason      text not null check (char_length(reason) between 5 and 500),
  status      public.report_status not null default 'open',
  created_at  timestamptz not null default now(),
  check (band_id is not null or song_id is not null)
);
create index on public.reports (status);
-- Un usuario no puede reportar dos veces lo mismo mientras siga abierto
create unique index reports_unique_open_song
  on public.reports (reporter_id, song_id) where song_id is not null and status = 'open';
create unique index reports_unique_open_band
  on public.reports (reporter_id, band_id) where song_id is null and status = 'open';

-- N reportes abiertos de usuarios distintos → oculta el tema hasta revisión
create function public.auto_hide_reported_song()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_limit int; v_count int;
begin
  if new.song_id is null then return new; end if;
  select value into v_limit from public.app_config where key = 'reports_to_hide';
  select count(distinct reporter_id) into v_count
    from public.reports where song_id = new.song_id and status = 'open';
  if v_count >= v_limit then
    update public.songs set hidden = true where id = new.song_id;
  end if;
  return new;
end $$;
create trigger reports_auto_hide after insert on public.reports
  for each row execute function public.auto_hide_reported_song();
