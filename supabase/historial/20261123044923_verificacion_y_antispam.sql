-- ServiceHome: verificación con documentos, técnico no disponible, catálogo de
-- especialidades/zonas solo por admin y límites anti-spam (puntos 7 y 9)

-- =====================================================================
-- 7. Verificación de técnicos con documentación
-- =====================================================================

-- 7.1 Campos de seguimiento en el perfil del técnico
alter table public.technician_profiles
  add column if not exists motivo_rechazo text
    check (motivo_rechazo is null or char_length(motivo_rechazo) <= 500),
  add column if not exists rechazado_at timestamptz,
  add column if not exists verificacion_solicitada_at timestamptz;

comment on column public.technician_profiles.verificacion_solicitada_at is
  'Cuándo el técnico envió su documentación a revisión. NULL = aún no la envía.';
comment on column public.technician_profiles.rechazado_at is
  'Último rechazo. Para volver a solicitar, debe subir documentos posteriores a esta fecha.';

-- 7.2 Bucket privado para documentos (máx. 5 MB, PDF o imagen)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos-tecnicos', 'documentos-tecnicos', false, 5242880,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Ruta obligatoria: <uid del técnico>/<nombre-archivo>
create policy documentos_tecnicos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documentos-tecnicos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.my_role()) = 'tecnico'
  );

create policy documentos_tecnicos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documentos-tecnicos'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or (select public.is_admin()))
  );

-- 7.3 Registro de documentos (sin borrado: queda como historial para el admin)
create table if not exists public.technician_documents (
  id              bigint generated always as identity primary key,
  tecnico_id      uuid not null references public.technician_profiles (profile_id) on delete cascade,
  tipo            text not null
                  check (tipo in ('identificacion', 'comprobante_domicilio', 'certificacion', 'otro')),
  nombre_archivo  text not null check (char_length(btrim(nombre_archivo)) between 1 and 200),
  storage_path    text not null unique,
  created_at      timestamptz not null default now()
);

create index if not exists idx_techdocs_tecnico on public.technician_documents (tecnico_id, created_at);

alter table public.technician_documents enable row level security;

revoke all on public.technician_documents from anon, authenticated;
grant select on public.technician_documents to authenticated;
grant insert (tecnico_id, tipo, nombre_archivo, storage_path)
  on public.technician_documents to authenticated;

create policy techdocs_select on public.technician_documents
  for select to authenticated
  using (tecnico_id = (select auth.uid()) or (select public.is_admin()));

create policy techdocs_insert on public.technician_documents
  for insert to authenticated
  with check (
    tecnico_id = (select auth.uid())
    and (select public.my_role()) = 'tecnico'
    and storage_path like (select auth.uid())::text || '/%'
    -- el archivo debe existir realmente en el bucket
    and exists (select 1 from storage.objects o
                 where o.bucket_id = 'documentos-tecnicos' and o.name = storage_path)
    -- límite de 20 documentos por técnico
    and (select count(*) from public.technician_documents d
          where d.tecnico_id = (select auth.uid())) < 20
  );

-- =====================================================================
-- 9. Cancelación automática cuando un técnico deja de estar disponible
-- =====================================================================

-- Función interna (no expuesta por la API)
create or replace function public.cancelar_solicitudes_tecnico(p_tecnico uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  perform set_config('app.motivo_cambio', 'tecnico_no_disponible', true);
  update public.service_requests
     set estado = 'cancelado'
   where tecnico_id = p_tecnico
     and estado in ('pendiente', 'aceptado', 'en_proceso');
  get diagnostics n = row_count;
  perform set_config('app.motivo_cambio', '', true);
  return n;
end
$$;

revoke execute on function public.cancelar_solicitudes_tecnico(uuid) from public, anon, authenticated;

-- Notificaciones: mensaje específico cuando se cancela porque el técnico no está disponible
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

  if new.estado = 'cancelado'
     and coalesce(current_setting('app.motivo_cambio', true), '') = 'tecnico_no_disponible' then
    insert into public.notifications (usuario_id, solicitud_id, mensaje)
    values (new.cliente_id, new.id,
            'El técnico asignado ya no está disponible, por lo que tu solicitud fue cancelada. Puedes buscar a otro técnico.');

  elsif v_actor = new.cliente_id then
    insert into public.notifications (usuario_id, solicitud_id, mensaje)
    values (new.tecnico_id, new.id, 'El cliente canceló la solicitud.');

  elsif v_actor = new.tecnico_id then
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

-- Desactivar un técnico cancela sus solicitudes abiertas
create or replace function public.admin_set_usuario_activo(p_usuario uuid, p_activo boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol public.user_role;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede activar o desactivar usuarios';
  end if;
  if p_usuario = auth.uid() and not p_activo then
    raise exception 'No puedes desactivar tu propia cuenta';
  end if;

  update public.profiles set activo = p_activo where id = p_usuario
  returning rol into v_rol;
  if not found then
    raise exception 'Usuario no encontrado';
  end if;

  if not p_activo and v_rol = 'tecnico' then
    perform public.cancelar_solicitudes_tecnico(p_usuario);
  end if;
end
$$;

-- Verificación por admin: requiere documentos, motivo obligatorio al rechazar,
-- y si un técnico verificado pierde la verificación se cancelan sus solicitudes
drop function if exists public.admin_verificar_tecnico(uuid, public.verification_status);

create function public.admin_verificar_tecnico(
  p_tecnico uuid,
  p_estado  public.verification_status,
  p_motivo  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_anterior public.verification_status;
  v_motivo   text := nullif(btrim(p_motivo), '');
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede verificar técnicos';
  end if;

  select verificacion into v_anterior
    from public.technician_profiles where profile_id = p_tecnico for update;
  if not found then
    raise exception 'Técnico no encontrado';
  end if;

  if p_estado = 'verificado' then
    if not exists (select 1 from public.technician_documents where tecnico_id = p_tecnico) then
      raise exception 'El técnico no ha subido documentación';
    end if;
    if not exists (select 1 from public.technician_categories where tecnico_id = p_tecnico)
       or not exists (select 1 from public.technician_zones where tecnico_id = p_tecnico) then
      raise exception 'Asigna al menos una especialidad y una zona al técnico antes de verificarlo';
    end if;
  end if;

  if p_estado = 'rechazado' and char_length(coalesce(v_motivo, '')) < 10 then
    raise exception 'Indica el motivo del rechazo (mínimo 10 caracteres)';
  end if;
  if char_length(coalesce(v_motivo, '')) > 500 then
    raise exception 'El motivo no puede exceder 500 caracteres';
  end if;

  update public.technician_profiles
     set verificacion   = p_estado,
         motivo_rechazo = case when p_estado = 'rechazado' then v_motivo end,
         rechazado_at   = case when p_estado = 'rechazado' then now() else rechazado_at end
   where profile_id = p_tecnico;

  if v_anterior = 'verificado' and p_estado <> 'verificado' then
    perform public.cancelar_solicitudes_tecnico(p_tecnico);
  end if;

  insert into public.notifications (usuario_id, mensaje)
  values (p_tecnico, case p_estado
    when 'verificado' then 'Tu perfil fue verificado. Ya puedes recibir solicitudes.'
    when 'rechazado'  then 'Tu verificación fue rechazada. Motivo: ' || v_motivo
                           || '. Sube nuevamente tu documentación y solicita una nueva revisión.'
    else 'Tu verificación está pendiente de revisión.' end);
end
$$;

revoke execute on function public.admin_verificar_tecnico(uuid, public.verification_status, text) from public, anon;
grant  execute on function public.admin_verificar_tecnico(uuid, public.verification_status, text) to authenticated;

-- El técnico envía (o reenvía) su documentación a revisión
create or replace function public.solicitar_verificacion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tp     public.technician_profiles;
  v_nombre text;
begin
  if public.my_role() is distinct from 'tecnico' then
    raise exception 'Solo un técnico activo puede solicitar verificación';
  end if;

  select * into v_tp from public.technician_profiles
   where profile_id = auth.uid() for update;

  if v_tp.verificacion = 'verificado' then
    raise exception 'Tu perfil ya está verificado';
  end if;
  if v_tp.verificacion = 'pendiente' and v_tp.verificacion_solicitada_at is not null then
    raise exception 'Tu solicitud de verificación ya está en revisión';
  end if;

  if not exists (
    select 1 from public.technician_documents d
     where d.tecnico_id = auth.uid()
       and (v_tp.rechazado_at is null or d.created_at > v_tp.rechazado_at)
  ) then
    if v_tp.verificacion = 'rechazado' then
      raise exception 'Debes subir nueva documentación antes de solicitar otra revisión';
    else
      raise exception 'Debes subir al menos un documento antes de solicitar la verificación';
    end if;
  end if;

  update public.technician_profiles
     set verificacion = 'pendiente',
         verificacion_solicitada_at = now()
   where profile_id = auth.uid();

  select nullif(btrim(nombre || ' ' || apellidos), '') into v_nombre
    from public.profiles where id = auth.uid();

  insert into public.notifications (usuario_id, mensaje)
  select p.id, 'El técnico ' || coalesce(v_nombre, 'sin nombre')
               || ' envió su documentación para verificación.'
    from public.profiles p
   where p.rol = 'admin' and p.activo;
end
$$;

revoke execute on function public.solicitar_verificacion() from public, anon;
grant  execute on function public.solicitar_verificacion() to authenticated;

-- =====================================================================
-- 9. Especialidades y zonas de técnicos: solo el admin las asigna
-- =====================================================================
drop policy if exists teccat_insert on public.technician_categories;
drop policy if exists teccat_delete on public.technician_categories;

create policy teccat_admin_insert on public.technician_categories
  for insert to authenticated
  with check (
    (select public.is_admin())
    and exists (select 1 from public.service_categories c
                 where c.id = categoria_id and c.activa)
  );

create policy teccat_admin_delete on public.technician_categories
  for delete to authenticated
  using ((select public.is_admin()));

drop policy if exists teczona_insert on public.technician_zones;
drop policy if exists teczona_delete on public.technician_zones;

create policy teczona_admin_insert on public.technician_zones
  for insert to authenticated
  with check (
    (select public.is_admin())
    and exists (select 1 from public.zones z
                 where z.id = zona_id and z.activa)
  );

create policy teczona_admin_delete on public.technician_zones
  for delete to authenticated
  using ((select public.is_admin()));

-- El registro ya no asigna la zona del técnico automáticamente
-- (queda en profiles.zona_id como referencia para el admin)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  m     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_rol public.user_role;
  v_tel text;
  v_dir text;
  v_zona smallint;
  v_exp  smallint;
begin
  v_rol := case when m->>'rol' = 'tecnico'
                then 'tecnico'::public.user_role
                else 'cliente'::public.user_role end;

  v_tel := nullif(btrim(m->>'telefono'), '');
  if v_tel is not null and v_tel !~ '^[0-9+() -]{7,20}$' then v_tel := null; end if;

  v_dir := left(nullif(btrim(m->>'direccion'), ''), 250);

  -- zona_id (opcional): solo si existe y esta activa; si no, se ignora sin romper el registro
  if (m->>'zona_id') ~ '^[0-9]{1,4}$' then
    select id into v_zona from public.zones
     where id = (m->>'zona_id')::smallint and activa;
  end if;

  insert into public.profiles (id, rol, nombre, apellidos, telefono, direccion, zona_id)
  values (
    new.id, v_rol,
    left(coalesce(m->>'nombre', ''), 80),
    left(coalesce(m->>'apellidos', ''), 80),
    v_tel, v_dir, v_zona
  );

  if v_rol = 'tecnico' then
    v_exp := case when (m->>'experiencia_anios') ~ '^[0-9]{1,2}$'
                  then least((m->>'experiencia_anios')::smallint, 60)
                  else 0 end;
    insert into public.technician_profiles (profile_id, experiencia_anios)
    values (new.id, v_exp);
  end if;
  return new;
end
$$;

-- =====================================================================
-- 9. Anti-spam de solicitudes
--   - 1 solicitud pendiente por cliente con el mismo técnico
--   - máx. 5 solicitudes pendientes por cliente
--   - máx. 10 solicitudes nuevas por cliente en 24 h
--   - si un técnico rechazó al cliente, espera de 24 h para volver a pedirle
-- =====================================================================
create or replace function public.validate_new_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.profiles
                 where id = new.cliente_id and rol = 'cliente' and activo) then
    raise exception 'El solicitante debe ser un cliente activo';
  end if;

  if not exists (select 1
                 from public.profiles p
                 join public.technician_profiles t on t.profile_id = p.id
                 where p.id = new.tecnico_id and p.activo and t.verificacion = 'verificado') then
    raise exception 'El técnico no está verificado o no está activo';
  end if;

  if not exists (select 1 from public.service_categories where id = new.categoria_id and activa) then
    raise exception 'La categoría de servicio no está disponible';
  end if;
  if not exists (select 1 from public.zones where id = new.zona_id and activa) then
    raise exception 'La zona no está disponible';
  end if;

  if not exists (select 1 from public.technician_categories
                 where tecnico_id = new.tecnico_id and categoria_id = new.categoria_id) then
    raise exception 'El técnico no ofrece esa categoría de servicio';
  end if;
  if not public.zone_covers(new.tecnico_id, new.zona_id) then
    raise exception 'El técnico no atiende esa zona';
  end if;

  if new.fecha_programada <= now() then
    raise exception 'La fecha programada debe ser futura';
  end if;

  -- Anti-spam: serializa las solicitudes simultáneas del mismo cliente
  perform pg_advisory_xact_lock(hashtextextended('solicitudes:' || new.cliente_id::text, 0));

  if exists (select 1 from public.service_requests
              where cliente_id = new.cliente_id and tecnico_id = new.tecnico_id
                and estado = 'pendiente') then
    raise exception 'Ya tienes una solicitud pendiente con este técnico. Espera su respuesta o cancélala antes de enviar otra';
  end if;

  if exists (select 1 from public.service_requests
              where cliente_id = new.cliente_id and tecnico_id = new.tecnico_id
                and estado = 'rechazado' and updated_at > now() - interval '24 hours') then
    raise exception 'Este técnico rechazó tu solicitud recientemente. Podrás enviarle otra después de 24 horas';
  end if;

  if (select count(*) from public.service_requests
       where cliente_id = new.cliente_id and estado = 'pendiente') >= 5 then
    raise exception 'Tienes 5 solicitudes pendientes, que es el máximo. Espera respuesta o cancela alguna';
  end if;

  if (select count(*) from public.service_requests
       where cliente_id = new.cliente_id and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'Alcanzaste el límite de 10 solicitudes en 24 horas. Intenta más tarde';
  end if;

  return new;
end
$$;

-- Respaldo a nivel de índice: nunca dos pendientes del mismo cliente al mismo técnico
create unique index if not exists uq_req_pendiente_cliente_tecnico
  on public.service_requests (cliente_id, tecnico_id)
  where estado = 'pendiente';
