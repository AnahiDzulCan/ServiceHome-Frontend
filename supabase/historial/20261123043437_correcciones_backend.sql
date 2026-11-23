-- ServiceHome: correcciones de backend (puntos 1, 4, 5, 6, 8, 10 y 11)

-- =====================================================================
-- 1 + 10. zones: lectura pública de zonas activas y políticas consolidadas
-- =====================================================================
grant select on public.zones to anon;

drop policy if exists zona_select on public.zones;
drop policy if exists zona_admin  on public.zones;

create policy zones_select_anon on public.zones
  for select to anon
  using (activa);

create policy zones_select_auth on public.zones
  for select to authenticated
  using (true);

create policy zones_admin_insert on public.zones
  for insert to authenticated
  with check ((select public.is_admin()));

create policy zones_admin_update on public.zones
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy zones_admin_delete on public.zones
  for delete to authenticated
  using ((select public.is_admin()));

-- =====================================================================
-- 10. service_categories: una sola política de lectura + admin por comando
-- =====================================================================
drop policy if exists "Cualquiera puede ver categorías" on public.service_categories;
drop policy if exists cat_select on public.service_categories;
drop policy if exists cat_admin  on public.service_categories;

create policy categories_select on public.service_categories
  for select to anon, authenticated
  using (true);

create policy categories_admin_insert on public.service_categories
  for insert to authenticated
  with check ((select public.is_admin()));

create policy categories_admin_update on public.service_categories
  for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy categories_admin_delete on public.service_categories
  for delete to authenticated
  using ((select public.is_admin()));

-- =====================================================================
-- 4. El cliente ya no puede fijar id / created_at / updated_at al insertar
-- =====================================================================
revoke insert on public.service_requests from authenticated;
grant insert (cliente_id, tecnico_id, categoria_id, zona_id, descripcion,
              direccion_servicio, fecha_programada, estado)
  on public.service_requests to authenticated;

revoke insert on public.reviews from authenticated;
grant insert (solicitud_id, cliente_id, tecnico_id, calificacion, comentario)
  on public.reviews to authenticated;

-- =====================================================================
-- 5 + 6. technician_categories: solo categorías activas; el admin puede asignar
-- =====================================================================
drop policy if exists teccat_all on public.technician_categories;

create policy teccat_select on public.technician_categories
  for select to authenticated
  using (tecnico_id = (select auth.uid()) or (select public.is_admin()));

create policy teccat_insert on public.technician_categories
  for insert to authenticated
  with check (
    (tecnico_id = (select auth.uid()) or (select public.is_admin()))
    and exists (select 1 from public.service_categories c
                 where c.id = categoria_id and c.activa)
  );

create policy teccat_delete on public.technician_categories
  for delete to authenticated
  using (tecnico_id = (select auth.uid()) or (select public.is_admin()));

-- =====================================================================
-- 6. technician_zones: el admin también puede asignar (solo zonas activas)
-- =====================================================================
drop policy if exists teczona_all on public.technician_zones;

create policy teczona_select on public.technician_zones
  for select to authenticated
  using (tecnico_id = (select auth.uid()) or (select public.is_admin()));

create policy teczona_insert on public.technician_zones
  for insert to authenticated
  with check (
    (tecnico_id = (select auth.uid()) or (select public.is_admin()))
    and exists (select 1 from public.zones z
                 where z.id = zona_id and z.activa)
  );

create policy teczona_delete on public.technician_zones
  for delete to authenticated
  using (tecnico_id = (select auth.uid()) or (select public.is_admin()));

-- =====================================================================
-- 8. Notificar a cliente y técnico cuando el cambio lo hace un admin
-- =====================================================================
create or replace function public.log_request_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := auth.uid();
  v_msg    text;
  v_estado text;
begin
  insert into public.request_status_history (solicitud_id, estado, cambiado_por)
  values (new.id, new.estado, v_actor);

  if tg_op = 'INSERT' then
    insert into public.notifications (usuario_id, solicitud_id, mensaje) values
      (new.cliente_id, new.id, 'Tu solicitud fue registrada y está pendiente de respuesta del técnico.'),
      (new.tecnico_id, new.id, 'Tienes una nueva solicitud de servicio pendiente.');
    return new;
  end if;

  if v_actor = new.cliente_id then
    -- El cliente cambió el estado (cancelación): avisar al técnico
    insert into public.notifications (usuario_id, solicitud_id, mensaje)
    values (new.tecnico_id, new.id, 'El cliente canceló la solicitud.');

  elsif v_actor = new.tecnico_id then
    -- El técnico cambió el estado: avisar al cliente
    v_msg := case new.estado
      when 'aceptado'   then 'El técnico aceptó tu solicitud.'
      when 'rechazado'  then 'El técnico rechazó tu solicitud. Puedes elegir a otro técnico.'
      when 'en_proceso' then 'Tu servicio está en proceso.'
      when 'finalizado' then 'Tu servicio fue finalizado. Revisa la factura y califícalo.'
      when 'cancelado'  then 'La solicitud fue cancelada.'
      else 'Tu solicitud cambió de estado.'
    end;
    insert into public.notifications (usuario_id, solicitud_id, mensaje)
    values (new.cliente_id, new.id, v_msg);

  else
    -- Admin (o proceso del sistema): avisar a ambas partes
    v_estado := case new.estado
      when 'pendiente'  then 'pendiente'
      when 'aceptado'   then 'aceptada'
      when 'rechazado'  then 'rechazada'
      when 'en_proceso' then 'en proceso'
      when 'finalizado' then 'finalizada'
      when 'cancelado'  then 'cancelada'
    end;
    v_msg := 'Un administrador marcó la solicitud como ' || v_estado || '.';
    insert into public.notifications (usuario_id, solicitud_id, mensaje) values
      (new.cliente_id, new.id, v_msg),
      (new.tecnico_id, new.id, v_msg);
  end if;

  return new;
end
$$;

-- =====================================================================
-- 11. Índices para llaves foráneas sin cubrir
-- =====================================================================
create index if not exists idx_notif_solicitud        on public.notifications (solicitud_id);
create index if not exists idx_profiles_zona          on public.profiles (zona_id);
create index if not exists idx_hist_cambiado_por      on public.request_status_history (cambiado_por);
create index if not exists idx_reviews_cliente        on public.reviews (cliente_id);
create index if not exists idx_tecprof_profile_rol    on public.technician_profiles (profile_id, rol);
