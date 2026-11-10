-- =========================================================
-- StreamTunes · tests/rls_checks.sql
-- Verifica RLS, privilegios por columna y límites, simulando cada rol.
-- Requiere haber corrido migraciones 0001–0004 + seed.sql en un proyecto de PRUEBA.
-- Pegar en el SQL Editor de Supabase. Cada bloque corre en su transacción
-- y termina con ROLLBACK (no deja datos). Si algo falla, el bloque lanza
-- un error con código XX999 y el mensaje "FALLÓ: ...".
-- Usuarios del seed: ver supabase/seed.sql
-- NO EJECUTADO TODAVÍA.
-- =========================================================

-- ---------------------------------------------------------
-- 1. VISITANTE (anon)
-- ---------------------------------------------------------
begin;
set local role anon;
do $$
declare v int;
begin
  select count(*) into v from public.bands;
  assert v = 2, format('FALLÓ visitante: debería ver 2 bandas aprobadas y ve %s', v);

  select count(*) into v from public.songs;
  assert v = 4, format('FALLÓ visitante: debería ver 4 temas de bandas aprobadas y ve %s', v);

  select count(*) into v from public.play_events;
  assert v = 0, 'FALLÓ visitante: no debe ver play_events';

  select count(*) into v from public.band_daily_stats;
  assert v = 0, 'FALLÓ visitante: no debe ver estadísticas';

  select count(*) into v from public.playlists;
  assert v = 1, format('FALLÓ visitante: solo debería ver 1 playlist pública y ve %s', v);

  raise notice 'OK 1. visitante';
end $$;
rollback;

-- ---------------------------------------------------------
-- 2. USUARIO SIN BANDA APROBADA (Caro: oyente + banda pendiente)
-- ---------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
set local role authenticated;
do $$
declare v int; n int;
begin
  select count(*) into v from public.bands;
  assert v = 3, format('FALLÓ caro: debería ver 2 aprobadas + su pendiente y ve %s', v);

  -- no ve estadísticas de otra banda
  select count(*) into v from public.band_daily_stats
   where band_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  assert v = 0, 'FALLÓ caro: ve estadísticas ajenas';

  -- no puede editar una banda ajena (0 filas afectadas)
  update public.bands set bio = 'hackeado' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  assert n = 0, 'FALLÓ caro: pudo editar una banda ajena';

  -- no puede subir un tema a una banda ajena
  begin
    insert into public.songs (band_id, title, audio_path, duration_s)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'x', 'x.mp3', 10);
    raise exception 'FALLÓ caro: subió un tema a banda ajena' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  -- no puede aprobar su propia banda editando status
  begin
    update public.bands set status = 'approved' where id = 'aaaaaaaa-0000-0000-0000-000000000003';
    raise exception 'FALLÓ caro: cambió status de su banda' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  -- ni vía RPC
  begin
    perform public.set_band_status('aaaaaaaa-0000-0000-0000-000000000003', 'approved');
    raise exception 'FALLÓ caro: usó set_band_status sin ser admin' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  -- no puede donar a su banda pendiente
  begin
    insert into public.donations (band_id, donor_id, amount)
    values ('aaaaaaaa-0000-0000-0000-000000000003', auth.uid(), 100);
    raise exception 'FALLÓ caro: donó a banda no aprobada' using errcode = 'XX999';
  exception when raise_exception then null;   -- P0001 del trigger
  end;

  -- no puede hacerse pasar por otro donante
  begin
    insert into public.donations (band_id, donor_id, amount)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 100);
    raise exception 'FALLÓ caro: donó como otro usuario' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  raise notice 'OK 2. usuario sin banda aprobada';
end $$;
rollback;

-- ---------------------------------------------------------
-- 3. MIEMBRO / OWNER DE BANDA (Ana, Los Viñedos)
-- ---------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;
do $$
declare v int; n int; i int;
begin
  -- ve sus estadísticas y no las de Cumbre Sur
  select count(*) into v from public.band_daily_stats
   where band_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  assert v >= 1, 'FALLÓ ana: no ve sus estadísticas';
  select count(*) into v from public.band_daily_stats
   where band_id = 'aaaaaaaa-0000-0000-0000-000000000002';
  assert v = 0, 'FALLÓ ana: ve estadísticas de otra banda';

  -- ve el ranking de oyentes de su banda
  select count(*) into v from public.band_top_listeners('aaaaaaaa-0000-0000-0000-000000000001');
  assert v >= 1, 'FALLÓ ana: no ve su ranking de oyentes';
  select count(*) into v from public.band_top_listeners('aaaaaaaa-0000-0000-0000-000000000002');
  assert v = 0, 'FALLÓ ana: ve el ranking de otra banda';

  -- puede editar el perfil de su banda
  update public.bands set bio = 'bio nueva' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  assert n = 1, 'FALLÓ ana: no pudo editar su banda';

  -- NO puede tocar columnas protegidas
  begin
    update public.bands set donations_collected = 999999
     where id = 'aaaaaaaa-0000-0000-0000-000000000001';
    raise exception 'FALLÓ ana: editó donations_collected' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.songs set play_count = 999999
     where id = 'cccccccc-0000-0000-0000-000000000001';
    raise exception 'FALLÓ ana: editó play_count' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.songs set hidden = true where id = 'cccccccc-0000-0000-0000-000000000001';
    raise exception 'FALLÓ ana: editó hidden' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  -- límite de temas: ya tiene 2, puede llegar a 20 y el 21 se rechaza
  for i in 1..18 loop
    insert into public.songs (band_id, title, audio_path, duration_s)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'tema ' || i, 'x/' || i || '.mp3', 100);
  end loop;
  begin
    insert into public.songs (band_id, title, audio_path, duration_s)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'tema 21', 'x/21.mp3', 100);
    raise exception 'FALLÓ ana: superó el límite de 20 temas' using errcode = 'XX999';
  exception when raise_exception then null;   -- P0001 del trigger
  end;

  -- límite de álbumes: tiene 1, puede llegar a 2 y el 3 se rechaza
  insert into public.albums (band_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Segundo');
  begin
    insert into public.albums (band_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Tercero');
    raise exception 'FALLÓ ana: superó el límite de 2 álbumes' using errcode = 'XX999';
  exception when raise_exception then null;
  end;

  -- no puede cambiar el status (ni vía RPC)
  begin
    update public.bands set status = 'suspended' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
    raise exception 'FALLÓ ana: cambió status' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.set_song_hidden('cccccccc-0000-0000-0000-000000000001', true);
    raise exception 'FALLÓ ana: usó set_song_hidden sin ser admin' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  raise notice 'OK 3. miembro/owner de banda';
end $$;
rollback;

-- ---------------------------------------------------------
-- 4. DONACIONES (Beto dona a Los Viñedos)
-- ---------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
set local role authenticated;
do $$
declare v_before numeric; v_after numeric;
begin
  select donations_collected into v_before from public.bands
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';

  insert into public.donations (band_id, donor_id, amount, message)
  values ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), 500, 'gracias');

  select donations_collected into v_after from public.bands
   where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  assert v_after = v_before + 500, 'FALLÓ beto: no se acumuló la donación en la banda';

  begin
    insert into public.donations (band_id, donor_id, amount)
    values ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), 5001);
    raise exception 'FALLÓ beto: superó el tope de donación' using errcode = 'XX999';
  exception when raise_exception then null;
  end;

  raise notice 'OK 4. donaciones';
end $$;
rollback;

-- ---------------------------------------------------------
-- 5. REPRODUCCIONES (Caro registra una reproducción)
-- ---------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
set local role authenticated;
do $$
declare v_before bigint; v_after bigint;
begin
  -- play_count lo lee desde la tabla pública
  select play_count into v_before from public.songs where id = 'cccccccc-0000-0000-0000-000000000002';

  insert into public.play_events (song_id, band_id, user_id, seconds_listened, city)
  values ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), 90, 'Mendoza');

  select play_count into v_after from public.songs where id = 'cccccccc-0000-0000-0000-000000000002';
  assert v_after = v_before + 1, 'FALLÓ: el trigger no incrementó play_count';

  -- no puede registrar una reproducción con una banda que no corresponde al tema
  begin
    insert into public.play_events (song_id, band_id, user_id, seconds_listened)
    values ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002', auth.uid(), 90);
    raise exception 'FALLÓ: play_event con banda que no corresponde' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  -- no puede registrar reproducciones a nombre de otro usuario
  begin
    insert into public.play_events (song_id, band_id, user_id, seconds_listened)
    values ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001',
            '33333333-3333-3333-3333-333333333333', 90);
    raise exception 'FALLÓ: play_event a nombre de otro' using errcode = 'XX999';
  exception when insufficient_privilege then null;
  end;

  raise notice 'OK 5. reproducciones';
end $$;
rollback;

-- ---------------------------------------------------------
-- 6. ADMIN / MODERACIÓN (admin@streamtunes.test)
-- ---------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;
do $$
declare v int; v_status public.band_status;
begin
  select count(*) into v from public.bands;
  assert v = 3, format('FALLÓ admin: debería ver las 3 bandas y ve %s', v);

  perform public.set_band_status('aaaaaaaa-0000-0000-0000-000000000003', 'approved');
  select status into v_status from public.bands where id = 'aaaaaaaa-0000-0000-0000-000000000003';
  assert v_status = 'approved', 'FALLÓ admin: no pudo aprobar la banda';

  perform public.set_song_hidden('cccccccc-0000-0000-0000-000000000001', true);
  select count(*) into v from public.songs
   where id = 'cccccccc-0000-0000-0000-000000000001' and hidden;
  assert v = 1, 'FALLÓ admin: no pudo ocultar un tema';

  select count(*) into v from public.reports;
  assert v >= 1, 'FALLÓ admin: no ve los reportes';

  raise notice 'OK 6. admin';
end $$;
rollback;

-- ---------------------------------------------------------
-- 7. AUTO-OCULTAR con 3 reportes de usuarios distintos (se inserta como
--    superusuario para simular a los 3 reportantes; el trigger es lo que se prueba)
-- ---------------------------------------------------------
begin;
do $$
declare v_hidden boolean;
begin
  insert into public.reports (reporter_id, song_id, reason) values
    ('11111111-1111-1111-1111-111111111111', 'cccccccc-0000-0000-0000-000000000002', 'copia de otra banda'),
    ('33333333-3333-3333-3333-333333333333', 'cccccccc-0000-0000-0000-000000000002', 'copia de otra banda'),
    ('44444444-4444-4444-4444-444444444444', 'cccccccc-0000-0000-0000-000000000002', 'copia de otra banda');
  select hidden into v_hidden from public.songs where id = 'cccccccc-0000-0000-0000-000000000002';
  assert v_hidden, 'FALLÓ: 3 reportes distintos no ocultaron el tema';
  raise notice 'OK 7. auto-ocultar por reportes';
end $$;
rollback;
