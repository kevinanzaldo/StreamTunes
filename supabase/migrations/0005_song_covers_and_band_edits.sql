-- Migración 0005: Portadas individuales por canción y separación total de Artista / Álbum / Canción

-- 1. Permite que cada tema tenga su propia portada independiente en la tabla songs
alter table public.songs add column if not exists cover_url text;

-- 2. Desvincular temas que quedaron atrapados en el álbum 'Demo Indie' para que queden como canciones/sencillos independientes
update public.songs
set album_id = null
where album_id in (select id from public.albums where title ilike '%demo indie%');

-- 3. Asegurar políticas para que los creadores puedan editar datos y fotos de su banda
do $$
begin
  if not exists (
    select 1 from pg_policies where policyname = 'editar banda (owner)' and tablename = 'bands'
  ) then
    create policy "editar banda (owner)" on public.bands for update to authenticated
      using (public.is_band_owner(id) or public.is_admin())
      with check (public.is_band_owner(id) or public.is_admin());
  end if;
end $$;
