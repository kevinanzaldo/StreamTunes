-- =========================================================
-- StreamTunes · 0003_hardening.sql
-- Cierra los pendientes de la §7.3 del plan:
--  (a) bands.status solo lo cambia un admin (vía RPC)
--  (b) play_count / donations_collected / hidden no se editan desde la app
-- Técnica: privilegios por COLUMNA para el rol `authenticated` + RPCs security definer.
-- =========================================================

-- bands ------------------------------------------------------------
revoke insert, update on public.bands from authenticated, anon;
grant insert (slug, name, bio, genre, location, cover_url, social_links, donation_goal, created_by)
  on public.bands to authenticated;
grant update (name, bio, genre, location, cover_url, social_links, donation_goal)
  on public.bands to authenticated;

-- songs ------------------------------------------------------------
revoke insert, update on public.songs from authenticated, anon;
grant insert (band_id, album_id, title, genre, audio_path, duration_s)
  on public.songs to authenticated;
grant update (album_id, title, genre)
  on public.songs to authenticated;

-- reports: el usuario solo crea; el admin cambia `status`
revoke update on public.reports from authenticated, anon;
grant update (status) on public.reports to authenticated;  -- RLS limita a admins

-- profiles: solo nombre y avatar
revoke update on public.profiles from authenticated, anon;
grant update (display_name, avatar_url) on public.profiles to authenticated;

-- RPCs de moderación ----------------------------------------------
create function public.set_band_status(p_band uuid, p_status public.band_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Solo moderadores pueden cambiar el estado de una banda.'
      using errcode = '42501';
  end if;
  update public.bands set status = p_status where id = p_band;
end $$;

create function public.set_song_hidden(p_song uuid, p_hidden boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Solo moderadores pueden ocultar o mostrar temas.'
      using errcode = '42501';
  end if;
  update public.songs set hidden = p_hidden where id = p_song;
end $$;

-- Las funciones nuevas se ejecutan solo por usuarios logueados
revoke execute on function public.set_band_status(uuid, public.band_status) from public, anon;
revoke execute on function public.set_song_hidden(uuid, boolean)             from public, anon;
grant  execute on function public.set_band_status(uuid, public.band_status) to authenticated;
grant  execute on function public.set_song_hidden(uuid, boolean)             to authenticated;

-- Funciones internas: no deben ser invocables como RPC por la app
revoke execute on function public.refresh_band_daily_stats(date) from public, anon, authenticated;
