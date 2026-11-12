-- =========================================================
-- StreamTunes · seed.sql  (SOLO para proyecto de PRUEBA / demo)
-- NO EJECUTADO TODAVÍA. Correr después de las migraciones 0001–0004.
-- Contraseña de todos los usuarios de prueba: Test1234!
--
-- Usuarios:
--   admin@streamtunes.test  → moderador (app_admins)
--   ana@streamtunes.test    → owner de "Los Viñedos"   (approved)
--   beto@streamtunes.test   → owner de "Cumbre Sur"    (approved)
--   caro@streamtunes.test   → oyente + owner de "Nube Eléctrica" (pending)
--
-- Los audio_path son de relleno: para escuchar hay que subir MP3 reales a
-- Storage (bucket `audio`) con la ruta {band_id}/{song_id}.mp3.
-- Si el login por email falla, crear los usuarios desde el dashboard
-- (Authentication → Add user) y ajustar los UUID de abajo.
-- =========================================================

-- 1. Usuarios (el trigger on_auth_user_created crea los profiles) ----------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'admin@streamtunes.test', crypt('Test1234!', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Admin Colectivo"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'ana@streamtunes.test', crypt('Test1234!', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Ana Quiroga"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'beto@streamtunes.test', crypt('Test1234!', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Beto Salinas"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444',
   'authenticated', 'authenticated', 'caro@streamtunes.test', crypt('Test1234!', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"display_name":"Caro Funes"}', now(), now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from auth.users u
where u.email like '%@streamtunes.test';

insert into public.app_admins (user_id) values ('11111111-1111-1111-1111-111111111111');

-- 2. Bandas (el trigger agrega a created_by como owner) --------------------
insert into public.bands (id, slug, name, bio, genre, location, social_links, donation_goal, status, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'los-vinedos', 'Los Viñedos',
   'Rock folk de Mendoza. Tres amigos, una guitarra criolla y mucho vino.', 'Rock', 'Mendoza',
   '{"instagram":"https://instagram.com/losvinedos"}', 150000, 'approved', '22222222-2222-2222-2222-222222222222'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'cumbre-sur', 'Cumbre Sur',
   'Cumbia electrónica desde el sur.', 'Cumbia', 'Neuquén',
   '{"instagram":"https://instagram.com/cumbresur"}', 80000, 'approved', '33333333-3333-3333-3333-333333333333'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'nube-electrica', 'Nube Eléctrica',
   'Synth-pop en construcción.', 'Pop', 'Córdoba',
   '{}', 0, 'pending', '44444444-4444-4444-4444-444444444444');

-- 3. Álbumes y temas ---------------------------------------------------------
insert into public.albums (id, band_id, title) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Primera Cosecha');

insert into public.songs (id, band_id, album_id, title, genre, audio_path, duration_s) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
   'Tierra Colorada', 'Rock', 'aaaaaaaa-0000-0000-0000-000000000001/cccccccc-0000-0000-0000-000000000001.mp3', 214),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
   'Cosecha Tardía', 'Rock', 'aaaaaaaa-0000-0000-0000-000000000001/cccccccc-0000-0000-0000-000000000002.mp3', 187),
  ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', null,
   'Cumbia del Sur', 'Cumbia', 'aaaaaaaa-0000-0000-0000-000000000002/cccccccc-0000-0000-0000-000000000003.mp3', 201),
  ('cccccccc-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000002', null,
   'Neón y Polvo', 'Cumbia', 'aaaaaaaa-0000-0000-0000-000000000002/cccccccc-0000-0000-0000-000000000004.mp3', 236),
  ('cccccccc-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000003', null,
   'Demo Nube 1', 'Pop', 'aaaaaaaa-0000-0000-0000-000000000003/cccccccc-0000-0000-0000-000000000005.mp3', 160);

-- 4. Playlists ---------------------------------------------------------------
insert into public.playlists (id, user_id, name, is_public) values
  ('dddddddd-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'Para el colectivo', true),
  ('dddddddd-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'Privada de Caro', false);

insert into public.playlist_songs (playlist_id, song_id, position) values
  ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 0),
  ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 1),
  ('dddddddd-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000004', 0);

-- 5. Donación, reproducciones y un reporte de ejemplo ------------------------
insert into public.donations (band_id, donor_id, amount, message, is_public) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 1500, '¡Sigan así!', true);

insert into public.play_events (song_id, band_id, user_id, seconds_listened, city) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 210, 'Mendoza'),
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 120, 'Neuquén'),
  ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 200, 'Mendoza');

insert into public.reports (reporter_id, band_id, reason) values
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000003', 'Prueba de reporte: revisar si es música propia.');

-- Estadísticas de hoy (para que el panel tenga algo que mostrar en la demo)
select public.refresh_band_daily_stats(current_date);
