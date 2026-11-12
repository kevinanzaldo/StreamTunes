-- ====================================================================
-- StreamTunes · 0009_consolidated_grants_and_policy_fixes.sql
-- Restauración de permisos por columna de menor privilegio (0003/0007),
-- grants explícitos para tablas nuevas y hardening de seguridad.
-- Idempotente: revoca permisos masivos accidentales y fija el estado final.
-- ====================================================================

-- 1. Permiso de uso del esquema
grant usage on schema public to anon, authenticated;

-- 2. Revocar privilegios masivos a nivel tabla en caso de haberse aplicado scripts globales
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- 3. bands: privilegios por columna (0003 + 0007)
-- status y donations_collected NUNCA son editables por la app (solo triggers y RPC de admin)
grant select on public.bands to anon, authenticated;
grant insert (slug, name, bio, genre, location, cover_url, social_links, donation_goal, merch_url, created_by)
  on public.bands to authenticated;
grant update (name, bio, genre, location, cover_url, social_links, donation_goal, merch_url)
  on public.bands to authenticated;

-- 4. songs: privilegios por columna (0003 + 0006 + 0007)
-- hidden y play_count NUNCA son editables por la app (solo triggers y RPC de admin)
grant select on public.songs to anon, authenticated;
grant insert (id, band_id, album_id, title, duration_s, genre, audio_path, cover_url, lyrics_lrc)
  on public.songs to authenticated;
grant update (album_id, title, genre, cover_url, lyrics_lrc)
  on public.songs to authenticated;
grant delete on public.songs to authenticated;

-- 5. profiles: lectura restringida y edición protegida
-- DECISIÓN PENDIENTE / PRIVACIDAD:
-- anon necesita resolver el nombre del donante en el muro público; se otorgan únicamente
-- las columnas id y display_name para no filtrar datos privados de oyentes a visitantes anónimos.
revoke all on public.profiles from anon;
grant select (id, display_name) on public.profiles to anon;
grant select on public.profiles to authenticated;
grant update (display_name, avatar_url, is_public_profile) on public.profiles to authenticated;

-- 6. donations: acceso al muro público
-- DECISIÓN PENDIENTE / PRIVACIDAD:
-- La app ejecuta `*, bands(name), profiles:donor_id(display_name)`, por lo que anon requiere
-- SELECT a nivel tabla en donations (la policy RLS ya limita a is_public = true).
-- Como consecuencia, donor_id queda visible en la respuesta JSON pública de donaciones.
grant select on public.donations to anon, authenticated;
grant insert on public.donations to authenticated;

-- 7. band_events y band_photos (tablas de 0007)
grant select on public.band_events to anon, authenticated;
grant insert, update, delete on public.band_events to authenticated;

grant select on public.band_photos to anon, authenticated;
grant insert, update, delete on public.band_photos to authenticated;

-- 8. band_follows: privacidad protegida
-- anon no tiene acceso; authenticated solo gestiona y consulta sus propios registros o los de su banda
revoke all on public.band_follows from anon;
grant select, insert, delete on public.band_follows to authenticated;

drop policy if exists "band_follows_select_public" on public.band_follows;
drop policy if exists "band_follows_select_restricted" on public.band_follows;
create policy "band_follows_select_restricted" on public.band_follows
  for select to authenticated
  using (auth.uid() = user_id or public.is_band_member(band_id));

-- RPC security definer para conteo público de seguidores sin exponer identidades
create or replace function public.band_follower_count(p_band uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select count(*) from public.band_follows where band_id = p_band;
$$;
grant execute on function public.band_follower_count(uuid) to anon, authenticated;

-- 9. app_config: lectura pública de límites y topes
grant select on public.app_config to anon, authenticated;

-- 10. app_admins: consulta de moderadores para la app
grant select on public.app_admins to authenticated;

-- 11. albums, band_members, play_events, playlists y reports
grant select on public.albums to anon, authenticated;
grant insert, update, delete on public.albums to authenticated;

grant select on public.band_members to authenticated;
grant insert, delete on public.band_members to authenticated;

-- play_events: solo authenticated puede insertar y consultar reproducciones
grant select, insert on public.play_events to authenticated;

grant select, insert, update, delete on public.playlists to authenticated;
grant select, insert, update, delete on public.playlist_songs to authenticated;

grant select, insert on public.reports to authenticated;
grant update (status) on public.reports to authenticated;

-- 12. RPCs y funciones internas
revoke execute on function public.refresh_band_daily_stats(date) from public, anon, authenticated;
grant execute on function public.band_top_fans(uuid, int) to anon, authenticated;
grant execute on function public.band_aggregated_stats(uuid) to authenticated;
grant execute on function public.set_band_status(uuid, public.band_status) to authenticated;
grant execute on function public.set_song_hidden(uuid, boolean) to authenticated;

