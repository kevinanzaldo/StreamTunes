-- Migración 0005: Portadas individuales por canción y edición de perfil de banda
-- Permite que cada tema tenga su propia portada independiente en la tabla songs
alter table public.songs add column if not exists cover_url text;

-- Asegurar políticas para actualizar información y fotos de la banda por parte de sus creadores/dueños
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
