-- Migración 0006: Habilita insertar `id` (UUID v4 generado en el cliente)
-- y `cover_url` en `public.songs` cuando se aplican privilegios por columna.
-- Ejecutar manualmente en el SQL Editor del proyecto Supabase de prueba/destino.

grant insert (id, cover_url) on public.songs to authenticated;
grant update (cover_url) on public.songs to authenticated;
