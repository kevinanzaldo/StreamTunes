-- =========================================================
-- StreamTunes · 0008_storage_audio_limits_and_stats_security.sql
-- Límites de audio en Supabase Storage (50 MB Free tier) y
-- seguridad RLS en estadísticas agregadas de bandas (RPC).
-- =========================================================

-- 1. Actualización de bucket `audio`: límite de 50 MB (52428800 bytes) y tipos MIME
--    permitidos (MP3, MP4 audio, M4A, WAV).
update storage.buckets
   set file_size_limit = 52428800,
       allowed_mime_types = array[
         'audio/mpeg',
         'audio/mp4',
         'audio/x-m4a',
         'audio/wav',
         'audio/x-wav',
         'audio/wave'
       ]
 where id = 'audio';

-- Si el bucket no existía aún en el entorno local, se crea con los límites estipulados.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'audio',
  'audio',
  true,
  52428800,
  array[
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/wav',
    'audio/x-wav',
    'audio/wave'
  ]
)
on conflict (id) do update
set file_size_limit = 52428800,
    allowed_mime_types = array[
      'audio/mpeg',
      'audio/mp4',
      'audio/x-m4a',
      'audio/wav',
      'audio/x-wav',
      'audio/wave'
    ];

-- 2. Restricción de seguridad en `band_aggregated_stats`
--    Solo miembros de la banda (o admin) pueden consultar las métricas agregadas privadas.
create or replace function public.band_aggregated_stats(p_band uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_total_plays bigint;
  v_total_minutes bigint;
  v_top_songs jsonb;
  v_daily_stats jsonb;
begin
  -- Validación de seguridad: solo miembros de la banda o administradores
  if not (public.is_band_member(p_band) or public.is_admin()) then
    raise exception 'Acceso denegado: solo los miembros de la banda o administradores pueden consultar estadísticas privadas.'
      using errcode = '42501';
  end if;

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

-- Otorgar ejecución a usuarios autenticados (la validación interna comprueba membresía o admin)
grant execute on function public.band_aggregated_stats(uuid) to authenticated;

-- `band_top_fans` sigue siendo de acceso público para anon y authenticated
grant execute on function public.band_top_fans(uuid, int) to anon, authenticated;

