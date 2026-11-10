-- =========================================================
-- StreamTunes · 0004_storage_realtime.sql
-- Buckets, políticas de Storage y Realtime.
-- Convención de rutas: {band_id}/{archivo}
-- NO EJECUTADO TODAVÍA.
-- =========================================================

-- Buckets (públicos de lectura). Límites de tamaño orientativos:
--   audio  : MP3 192 kbps ≈ 1,4 MB/min → 20 MB cubre ~14 min
--   covers : imágenes
--   stories: videos ≤ 15 s
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('audio',   'audio',   true, 20971520, array['audio/mpeg']),
  ('covers',  'covers',  true,  5242880, array['image/jpeg','image/png','image/webp']),
  ('stories', 'stories', true, 31457280, array['video/mp4','video/webm'])
on conflict (id) do nothing;

-- Lectura pública
create policy "lectura publica audio"   on storage.objects for select using (bucket_id = 'audio');
create policy "lectura publica covers"  on storage.objects for select using (bucket_id = 'covers');
create policy "lectura publica stories" on storage.objects for select using (bucket_id = 'stories');

-- Escritura: solo miembros de la banda dueña de la carpeta
create policy "miembros suben archivos" on storage.objects for insert to authenticated
  with check (
    bucket_id in ('audio','covers','stories')
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );

create policy "miembros actualizan archivos" on storage.objects for update to authenticated
  using (
    bucket_id in ('audio','covers','stories')
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id in ('audio','covers','stories')
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );

create policy "miembros borran archivos" on storage.objects for delete to authenticated
  using (
    bucket_id in ('audio','covers','stories')
    and public.is_band_member(((storage.foldername(name))[1])::uuid)
  );

-- Realtime sobre donaciones (muro / alerta en vivo)
alter publication supabase_realtime add table public.donations;

-- Estadísticas diarias: habilitar la extensión pg_cron desde el dashboard y descomentar.
-- 06:00 UTC = 03:00 ART
-- select cron.schedule('stats-diarias', '0 6 * * *', $$select public.refresh_band_daily_stats()$$);
