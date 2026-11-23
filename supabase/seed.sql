-- Datos iniciales de catálogo (los mismos que tiene hoy tu proyecto).
-- Supabase lo ejecuta automáticamente con `supabase db reset` en local.

insert into public.zones (nombre, activa) values
  ('Mi ciudad (renombrar)', true);

insert into public.service_categories (nombre, activa, mano_obra_max) values
  ('Plomería',     true, null),
  ('Electricidad', true, null),
  ('Jardinería',   true, null);

-- Para promover a tu primer admin (después de registrarte en la app),
-- ejecuta en el SQL Editor con tu correo:
--
--   update public.profiles set rol = 'admin'
--    where id = (select id from auth.users where email = 'tu-correo@ejemplo.com');
