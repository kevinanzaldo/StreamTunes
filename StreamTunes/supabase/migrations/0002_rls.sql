-- =========================================================
-- StreamTunes · 0002_rls.sql
-- Row Level Security. Sin políticas, nadie accede a nada.
-- NO EJECUTADO TODAVÍA.
-- =========================================================

-- Hace el script re-ejecutable: borra las políticas de `public` antes de recrearlas.
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.profiles         enable row level security;
alter table public.app_admins       enable row level security;
alter table public.app_config       enable row level security;
alter table public.bands            enable row level security;
alter table public.band_members     enable row level security;
alter table public.albums           enable row level security;
alter table public.songs            enable row level security;
alter table public.playlists        enable row level security;
alter table public.playlist_songs   enable row level security;
alter table public.donations        enable row level security;
alter table public.play_events      enable row level security;
alter table public.band_daily_stats enable row level security;
alter table public.stories          enable row level security;
alter table public.reports          enable row level security;

-- profiles: cualquiera logueado ve nombres; cada uno edita el suyo
create policy "perfiles visibles" on public.profiles for select to authenticated using (true);
create policy "editar mi perfil"  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- app_admins: cada admin ve solo su fila (nadie escribe desde la app)
create policy "ver si soy admin" on public.app_admins for select to authenticated
  using (user_id = auth.uid());

-- app_config: lectura pública, escritura solo desde el dashboard
create policy "config legible" on public.app_config for select using (true);

-- bands: público ve las aprobadas; miembros y admins ven las suyas
-- created_by = auth.uid(): necesario para que `insert ... returning` funcione antes de que
-- el trigger agregue al creador como owner.
create policy "ver bandas" on public.bands for select
  using (status = 'approved' or created_by = auth.uid()
         or public.is_band_member(id) or public.is_admin());
create policy "crear banda" on public.bands for insert to authenticated
  with check (created_by = auth.uid() and status = 'pending');
create policy "editar banda (owner)" on public.bands for update to authenticated
  using (public.is_band_owner(id) or public.is_admin())
  with check (public.is_band_owner(id) or public.is_admin());
-- status, donations_collected: bloqueados por privilegios de columna (0003)

-- band_members
create policy "ver miembros" on public.band_members for select to authenticated
  using (user_id = auth.uid() or public.is_band_member(band_id));
create policy "owner agrega miembros" on public.band_members for insert to authenticated
  with check (public.is_band_owner(band_id));
create policy "owner quita miembros" on public.band_members for delete to authenticated
  using (public.is_band_owner(band_id) or user_id = auth.uid());

-- albums / songs / stories: público si la banda está aprobada; escribe solo la banda
create policy "ver albums" on public.albums for select using (
  exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
  or public.is_band_member(band_id));
create policy "banda gestiona albums" on public.albums for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

create policy "ver songs" on public.songs for select using (
  (not hidden and exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved'))
  or public.is_band_member(band_id) or public.is_admin());
create policy "banda gestiona songs" on public.songs for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

create policy "ver stories" on public.stories for select using (
  exists (select 1 from public.bands b where b.id = band_id and b.status = 'approved')
  or public.is_band_member(band_id));
create policy "banda gestiona stories" on public.stories for all to authenticated
  using (public.is_band_member(band_id)) with check (public.is_band_member(band_id));

-- playlists: cada usuario las suyas (o públicas)
create policy "ver playlists" on public.playlists for select
  using (is_public or user_id = auth.uid());
create policy "gestionar mis playlists" on public.playlists for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "ver canciones de playlist" on public.playlist_songs for select using (
  exists (select 1 from public.playlists p
          where p.id = playlist_id and (p.is_public or p.user_id = auth.uid())));
create policy "gestionar canciones de mis playlists" on public.playlist_songs for all to authenticated
  using (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()))
  with check (exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = auth.uid()));

-- donaciones: donar logueado; ver las públicas, las propias y las de mi banda
create policy "donar" on public.donations for insert to authenticated
  with check (donor_id = auth.uid());
create policy "ver donaciones" on public.donations for select
  using (is_public or donor_id = auth.uid() or public.is_band_member(band_id));

-- reproducciones y estadísticas: se insertan solas; solo la banda las lee
create policy "registrar reproduccion" on public.play_events for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.songs s where s.id = song_id and s.band_id = play_events.band_id)
  );
create policy "banda ve sus reproducciones" on public.play_events for select to authenticated
  using (public.is_band_member(band_id));
create policy "banda ve sus stats" on public.band_daily_stats for select to authenticated
  using (public.is_band_member(band_id));   -- reemplaza a esDuenoDelPerfil

-- reportes
create policy "reportar" on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
create policy "ver reportes" on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_admin());
create policy "admin resuelve reportes" on public.reports for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
