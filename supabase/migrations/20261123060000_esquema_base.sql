


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."request_status" AS ENUM (
    'pendiente',
    'aceptado',
    'en_proceso',
    'finalizado',
    'rechazado',
    'cancelado'
);


ALTER TYPE "public"."request_status" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'cliente',
    'tecnico',
    'admin'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."verification_status" AS ENUM (
    'pendiente',
    'verificado',
    'rechazado'
);


ALTER TYPE "public"."verification_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_facturas_revision"("p_solo_excedidas" boolean DEFAULT true) RETURNS TABLE("factura_id" "uuid", "solicitud_id" "uuid", "categoria" "text", "tecnico" "text", "mano_obra" numeric, "mano_obra_max" numeric, "total_materiales" numeric, "total" numeric, "excede_referencia" boolean, "justificacion_mano_obra" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ver reportes';
  end if;
  return query
    select i.id, i.solicitud_id, c.nombre,
           nullif(btrim(p.nombre || ' ' || p.apellidos), ''),
           i.mano_obra, c.mano_obra_max, i.total_materiales, i.total,
           i.excede_referencia, i.justificacion_mano_obra, i.created_at
      from public.invoices i
      join public.service_requests r on r.id = i.solicitud_id
      join public.service_categories c on c.id = r.categoria_id
      join public.profiles p on p.id = i.tecnico_id
     where (not p_solo_excedidas) or i.excede_referencia
     order by i.created_at desc;
end $$;


ALTER FUNCTION "public"."admin_facturas_revision"("p_solo_excedidas" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_ranking_tecnicos"("p_limit" integer DEFAULT 10) RETURNS TABLE("tecnico_id" "uuid", "nombre" "text", "servicios_finalizados" bigint, "promedio" numeric, "total_calificaciones" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ver reportes';
  end if;
  return query
    select p.id,
           btrim(p.nombre || ' ' || p.apellidos),
           (select count(*) from public.service_requests r
             where r.tecnico_id = p.id and r.estado = 'finalizado'),
           t.promedio_calificacion,
           t.total_calificaciones
      from public.technician_profiles t
      join public.profiles p on p.id = t.profile_id
     order by t.promedio_calificacion desc, t.total_calificaciones desc
     limit greatest(p_limit, 1);
end $$;


ALTER FUNCTION "public"."admin_ranking_tecnicos"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_reporte_servicios"("p_desde" "date" DEFAULT NULL::"date", "p_hasta" "date" DEFAULT NULL::"date") RETURNS TABLE("categoria" "text", "estado" "public"."request_status", "total" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ver reportes';
  end if;
  return query
    select c.nombre, r.estado, count(*)
      from public.service_requests r
      join public.service_categories c on c.id = r.categoria_id
     where (p_desde is null or r.created_at >= p_desde)
       and (p_hasta is null or r.created_at <  p_hasta + 1)
     group by c.nombre, r.estado
     order by c.nombre, r.estado;
end $$;


ALTER FUNCTION "public"."admin_reporte_servicios"("p_desde" "date", "p_hasta" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_reporte_zonas"("p_desde" "date" DEFAULT NULL::"date", "p_hasta" "date" DEFAULT NULL::"date") RETURNS TABLE("zona" "text", "zona_padre" "text", "estado" "public"."request_status", "total" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ver reportes';
  end if;
  return query
    select z.nombre, zp.nombre, r.estado, count(*)
      from public.service_requests r
      join public.zones z on z.id = r.zona_id
      left join public.zones zp on zp.id = z.zona_padre_id
     where (p_desde is null or r.created_at >= p_desde)
       and (p_hasta is null or r.created_at <  p_hasta + 1)
     group by z.nombre, zp.nombre, r.estado
     order by z.nombre, r.estado;
end $$;


ALTER FUNCTION "public"."admin_reporte_zonas"("p_desde" "date", "p_hasta" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_resumen"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede ver reportes';
  end if;
  return jsonb_build_object(
    'usuarios_por_rol',
      (select coalesce(jsonb_object_agg(s.rol, s.n), '{}'::jsonb)
         from (select rol::text as rol, count(*) as n from public.profiles group by rol) s),
    'tecnicos_pendientes_verificacion',
      (select count(*) from public.technician_profiles where verificacion = 'pendiente'),
    'solicitudes_por_estado',
      (select coalesce(jsonb_object_agg(s.estado, s.n), '{}'::jsonb)
         from (select estado::text as estado, count(*) as n from public.service_requests group by estado) s),
    'calificacion_promedio_global',
      (select coalesce(round(avg(calificacion)::numeric, 2), 0) from public.reviews),
    'generado_en', now()
  );
end $$;


ALTER FUNCTION "public"."admin_resumen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_set_usuario_activo"("p_usuario" "uuid", "p_activo" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."admin_set_usuario_activo"("p_usuario" "uuid", "p_activo" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_verificar_tecnico"("p_tecnico" "uuid", "p_estado" "public"."verification_status", "p_motivo" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."admin_verificar_tecnico"("p_tecnico" "uuid", "p_estado" "public"."verification_status", "p_motivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buscar_tecnicos"("p_categoria" smallint, "p_zona" smallint) RETURNS TABLE("id" "uuid", "nombre" "text", "apellidos" "text", "experiencia_anios" smallint, "descripcion" "text", "promedio_calificacion" numeric, "total_calificaciones" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select t.id, t.nombre, t.apellidos, t.experiencia_anios, t.descripcion,
         t.promedio_calificacion, t.total_calificaciones
    from public.tecnicos_publicos t
   where exists (select 1 from public.service_categories c where c.id = p_categoria and c.activa)
     and exists (select 1 from public.zones z where z.id = p_zona and z.activa)
     and exists (select 1 from public.technician_categories tc
                  where tc.tecnico_id = t.id and tc.categoria_id = p_categoria)
     and public.zone_covers(t.id, p_zona)
   order by t.promedio_calificacion desc, t.total_calificaciones desc, t.nombre
$$;


ALTER FUNCTION "public"."buscar_tecnicos"("p_categoria" smallint, "p_zona" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancelar_solicitudes_tecnico"("p_tecnico" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."cancelar_solicitudes_tecnico"("p_tecnico" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cerrar_solicitud"("p_solicitud" "uuid", "p_mano_obra" numeric, "p_materiales" "jsonb" DEFAULT '[]'::"jsonb", "p_justificacion" "text" DEFAULT NULL::"text", "p_notas" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  r        public.service_requests;
  v_mat    jsonb := coalesce(p_materiales, '[]'::jsonb);
  v_max    numeric;
  v_total_mat numeric;
  v_excede boolean := false;
  v_id     uuid;
begin
  select * into r from public.service_requests where id = p_solicitud for update;
  if r.id is null or coalesce(r.tecnico_id <> auth.uid(), true)
     or public.my_role() is distinct from 'tecnico' then
    raise exception 'Solo el técnico asignado puede cerrar esta solicitud';
  end if;
  if r.estado <> 'en_proceso' then
    raise exception 'La solicitud debe estar en proceso para poder cerrarse';
  end if;
  if p_mano_obra is null or p_mano_obra < 0 or p_mano_obra > 99999999 then
    raise exception 'La mano de obra debe ser un monto válido (0 o mayor)';
  end if;
  p_mano_obra := round(p_mano_obra, 2);
  if char_length(btrim(coalesce(p_justificacion, ''))) > 500 then
    raise exception 'La justificación no puede exceder 500 caracteres';
  end if;
  if char_length(btrim(coalesce(p_notas, ''))) > 1000 then
    raise exception 'Las notas no pueden exceder 1000 caracteres';
  end if;
  if jsonb_typeof(v_mat) <> 'array' then
    raise exception 'Los materiales deben ser una lista de máximo 50 conceptos';
  end if;
  if jsonb_array_length(v_mat) > 50 then
    raise exception 'Los materiales deben ser una lista de máximo 50 conceptos';
  end if;
  if exists (select 1 from jsonb_array_elements(v_mat) e where jsonb_typeof(e) <> 'object') then
    raise exception 'Cada material necesita descripción, cantidad mayor a 0 y precio unitario válido';
  end if;

  -- Validacion y total con valores redondeados a 2 decimales (igual que lo que se guarda).
  -- Los errores de formato (p. ej. texto en lugar de numero) se traducen al mensaje normal.
  begin
    if exists (
      select 1 from jsonb_to_recordset(v_mat)
        as x(descripcion text, cantidad numeric, unidad text, precio_unitario numeric)
       where nullif(btrim(x.descripcion), '') is null or char_length(btrim(x.descripcion)) > 200
          or x.cantidad is null or round(x.cantidad, 2) <= 0 or x.cantidad > 99999
          or x.precio_unitario is null or x.precio_unitario < 0 or x.precio_unitario > 999999
          or char_length(btrim(coalesce(x.unidad, ''))) > 20
    ) then
      raise exception 'Cada material necesita descripción, cantidad mayor a 0 y precio unitario válido';
    end if;

    select coalesce(sum(round(round(x.cantidad, 2) * round(x.precio_unitario, 2), 2)), 0) into v_total_mat
      from jsonb_to_recordset(v_mat)
        as x(descripcion text, cantidad numeric, unidad text, precio_unitario numeric);
  exception when invalid_text_representation or numeric_value_out_of_range or invalid_parameter_value then
    raise exception 'Cada material necesita descripción, cantidad mayor a 0 y precio unitario válido';
  end;

  if v_total_mat > 10000000 then
    raise exception 'El total de materiales no puede exceder $10,000,000';
  end if;

  -- Control de mano de obra: tope de referencia por categoria
  select mano_obra_max into v_max from public.service_categories where id = r.categoria_id;
  if v_max is not null and p_mano_obra > v_max then
    if char_length(btrim(coalesce(p_justificacion, ''))) < 10 then
      raise exception 'La mano de obra excede la referencia de la categoría (máx. %). Agrega una justificación de al menos 10 caracteres', v_max;
    end if;
    v_excede := true;
  end if;

  insert into public.invoices (solicitud_id, tecnico_id, mano_obra, total_materiales,
                               excede_referencia, justificacion_mano_obra, notas)
  values (p_solicitud, r.tecnico_id, p_mano_obra, v_total_mat, v_excede,
          case when v_excede then btrim(p_justificacion) else nullif(btrim(p_justificacion), '') end,
          nullif(btrim(p_notas), ''))
  returning id into v_id;

  insert into public.invoice_items (factura_id, descripcion, cantidad, unidad, precio_unitario)
  select v_id, btrim(x.descripcion), round(x.cantidad, 2),
         coalesce(nullif(btrim(x.unidad), ''), 'pza'), round(x.precio_unitario, 2)
    from jsonb_to_recordset(v_mat)
      as x(descripcion text, cantidad numeric, unidad text, precio_unitario numeric);

  update public.service_requests set estado = 'finalizado' where id = p_solicitud;
  return v_id;
end $_$;


ALTER FUNCTION "public"."cerrar_solicitud"("p_solicitud" "uuid", "p_mano_obra" numeric, "p_materiales" "jsonb", "p_justificacion" "text", "p_notas" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
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
$_$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ select coalesce(public.my_role() = 'admin', false) $$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_request_status"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."log_request_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_role"() RETURNS "public"."user_role"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ select rol from public.profiles where id = auth.uid() and activo $$;


ALTER FUNCTION "public"."my_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_technician_rating"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update public.technician_profiles
     set promedio_calificacion = (select round(avg(calificacion)::numeric, 2)
                                    from public.reviews where tecnico_id = new.tecnico_id),
         total_calificaciones  = (select count(*)
                                    from public.reviews where tecnico_id = new.tecnico_id)
   where profile_id = new.tecnico_id;
  return new;
end $$;


ALTER FUNCTION "public"."refresh_technician_rating"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."require_invoice_to_finish"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if new.estado = 'finalizado' and old.estado is distinct from 'finalizado'
     and auth.uid() is not null and not public.is_admin()
     and not exists (select 1 from public.invoices where solicitud_id = new.id) then
    raise exception 'No se puede finalizar sin factura. Usa cerrar_solicitud()';
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."require_invoice_to_finish"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin new.updated_at = now(); return new; end $$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."solicitar_verificacion"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."solicitar_verificacion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_new_request"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."validate_new_request"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_review"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  r public.service_requests;
begin
  select * into r from public.service_requests where id = new.solicitud_id;
  if r.id is null or r.estado <> 'finalizado' then
    raise exception 'Solo se puede calificar un servicio finalizado';
  end if;
  if r.cliente_id <> new.cliente_id then
    raise exception 'Solo el cliente de la solicitud puede calificar';
  end if;
  new.tecnico_id := r.tecnico_id;       -- el cliente no puede calificar a otro tecnico
  return new;
end $$;


ALTER FUNCTION "public"."validate_review"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_status_transition"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if new.estado is distinct from old.estado and auth.uid() is not null then
    if public.my_role() is null then
      raise exception 'Usuario inactivo';
    end if;
    if not public.is_admin() and not (
      (old.estado = 'pendiente'  and new.estado in ('aceptado', 'rechazado') and auth.uid() = old.tecnico_id) or
      (old.estado in ('pendiente', 'aceptado') and new.estado = 'cancelado'  and auth.uid() = old.cliente_id) or
      (old.estado = 'aceptado'   and new.estado = 'en_proceso'               and auth.uid() = old.tecnico_id) or
      (old.estado = 'en_proceso' and new.estado = 'finalizado'               and auth.uid() = old.tecnico_id)
    ) then
      raise exception 'Transición de estado no permitida: % -> %', old.estado, new.estado;
    end if;
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."validate_status_transition"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_technician_document"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform pg_advisory_xact_lock(hashtextextended('documentos:' || new.tecnico_id::text, 0));
  if (select count(*) from public.technician_documents where tecnico_id = new.tecnico_id) >= 20 then
    raise exception 'Alcanzaste el máximo de 20 documentos. Contacta al administrador';
  end if;
  return new;
end
$$;


ALTER FUNCTION "public"."validate_technician_document"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_zone_parent"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.zona_padre_id is not null and exists (
    with recursive ancestros as (
      select id, zona_padre_id from public.zones where id = new.zona_padre_id
      union
      select z.id, z.zona_padre_id
        from public.zones z join ancestros a on z.id = a.zona_padre_id
    )
    select 1 from ancestros where id = new.id
  ) then
    raise exception 'Una zona no puede estar dentro de sí misma ni de una de sus subzonas';
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."validate_zone_parent"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."zone_covers"("p_tecnico" "uuid", "p_zona" smallint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with recursive ruta as (
    select id, zona_padre_id from public.zones where id = p_zona
    union
    select z.id, z.zona_padre_id
      from public.zones z join ruta r on z.id = r.zona_padre_id
  )
  select exists (
    select 1 from public.technician_zones tz
      join ruta r on r.id = tz.zona_id
     where tz.tecnico_id = p_tecnico
  )
$$;


ALTER FUNCTION "public"."zone_covers"("p_tecnico" "uuid", "p_zona" smallint) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."invoice_items" (
    "id" bigint NOT NULL,
    "factura_id" "uuid" NOT NULL,
    "descripcion" "text" NOT NULL,
    "cantidad" numeric(10,2) NOT NULL,
    "unidad" "text" DEFAULT 'pza'::"text" NOT NULL,
    "precio_unitario" numeric(10,2) NOT NULL,
    "importe" numeric(12,2) GENERATED ALWAYS AS ("round"(("cantidad" * "precio_unitario"), 2)) STORED,
    CONSTRAINT "invoice_items_cantidad_check" CHECK (("cantidad" > (0)::numeric)),
    CONSTRAINT "invoice_items_descripcion_check" CHECK ((("char_length"("btrim"("descripcion")) >= 1) AND ("char_length"("btrim"("descripcion")) <= 200))),
    CONSTRAINT "invoice_items_precio_unitario_check" CHECK (("precio_unitario" >= (0)::numeric)),
    CONSTRAINT "invoice_items_unidad_check" CHECK (("char_length"("unidad") <= 20))
);


ALTER TABLE "public"."invoice_items" OWNER TO "postgres";


ALTER TABLE "public"."invoice_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "solicitud_id" "uuid" NOT NULL,
    "tecnico_id" "uuid" NOT NULL,
    "mano_obra" numeric(10,2) NOT NULL,
    "total_materiales" numeric(12,2) DEFAULT 0 NOT NULL,
    "total" numeric(12,2) GENERATED ALWAYS AS (("mano_obra" + "total_materiales")) STORED,
    "excede_referencia" boolean DEFAULT false NOT NULL,
    "justificacion_mano_obra" "text",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "invoices_justificacion_mano_obra_check" CHECK ((("justificacion_mano_obra" IS NULL) OR ("char_length"("justificacion_mano_obra") <= 500))),
    CONSTRAINT "invoices_mano_obra_check" CHECK (("mano_obra" >= (0)::numeric)),
    CONSTRAINT "invoices_notas_check" CHECK ((("notas" IS NULL) OR ("char_length"("notas") <= 1000))),
    CONSTRAINT "invoices_total_materiales_check" CHECK (("total_materiales" >= (0)::numeric))
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" bigint NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "solicitud_id" "uuid",
    "mensaje" "text" NOT NULL,
    "leida" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


ALTER TABLE "public"."notifications" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."notifications_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "rol" "public"."user_role" DEFAULT 'cliente'::"public"."user_role" NOT NULL,
    "nombre" "text" DEFAULT ''::"text" NOT NULL,
    "apellidos" "text" DEFAULT ''::"text" NOT NULL,
    "telefono" "text",
    "direccion" "text",
    "zona_id" smallint,
    "activo" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "profiles_apellidos_check" CHECK (("char_length"("apellidos") <= 80)),
    CONSTRAINT "profiles_direccion_check" CHECK ((("direccion" IS NULL) OR ("char_length"("direccion") <= 250))),
    CONSTRAINT "profiles_nombre_check" CHECK (("char_length"("nombre") <= 80)),
    CONSTRAINT "profiles_telefono_check" CHECK ((("telefono" IS NULL) OR ("telefono" ~ '^[0-9+() -]{7,20}$'::"text")))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."request_status_history" (
    "id" bigint NOT NULL,
    "solicitud_id" "uuid" NOT NULL,
    "estado" "public"."request_status" NOT NULL,
    "cambiado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."request_status_history" OWNER TO "postgres";


ALTER TABLE "public"."request_status_history" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."request_status_history_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "solicitud_id" "uuid" NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "tecnico_id" "uuid" NOT NULL,
    "calificacion" smallint NOT NULL,
    "comentario" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reviews_calificacion_check" CHECK ((("calificacion" >= 1) AND ("calificacion" <= 5))),
    CONSTRAINT "reviews_comentario_check" CHECK ((("comentario" IS NULL) OR ("char_length"("comentario") <= 1000)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."service_categories" (
    "id" smallint NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "activa" boolean DEFAULT true NOT NULL,
    "mano_obra_max" numeric(10,2),
    CONSTRAINT "service_categories_mano_obra_max_check" CHECK ((("mano_obra_max" IS NULL) OR ("mano_obra_max" >= (0)::numeric))),
    CONSTRAINT "service_categories_nombre_check" CHECK (("char_length"("btrim"("nombre")) > 0))
);


ALTER TABLE "public"."service_categories" OWNER TO "postgres";


ALTER TABLE "public"."service_categories" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."service_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."service_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "tecnico_id" "uuid" NOT NULL,
    "categoria_id" smallint NOT NULL,
    "zona_id" smallint NOT NULL,
    "descripcion" "text" NOT NULL,
    "direccion_servicio" "text" NOT NULL,
    "fecha_programada" timestamp with time zone NOT NULL,
    "estado" "public"."request_status" DEFAULT 'pendiente'::"public"."request_status" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "service_requests_descripcion_check" CHECK ((("char_length"("descripcion") >= 10) AND ("char_length"("descripcion") <= 2000))),
    CONSTRAINT "service_requests_direccion_servicio_check" CHECK ((("char_length"("direccion_servicio") >= 5) AND ("char_length"("direccion_servicio") <= 250)))
);


ALTER TABLE "public"."service_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."technician_categories" (
    "tecnico_id" "uuid" NOT NULL,
    "categoria_id" smallint NOT NULL
);


ALTER TABLE "public"."technician_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."technician_documents" (
    "id" bigint NOT NULL,
    "tecnico_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "nombre_archivo" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "technician_documents_nombre_archivo_check" CHECK ((("char_length"("btrim"("nombre_archivo")) >= 1) AND ("char_length"("btrim"("nombre_archivo")) <= 200))),
    CONSTRAINT "technician_documents_tipo_check" CHECK (("tipo" = ANY (ARRAY['identificacion'::"text", 'comprobante_domicilio'::"text", 'certificacion'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."technician_documents" OWNER TO "postgres";


ALTER TABLE "public"."technician_documents" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."technician_documents_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."technician_profiles" (
    "profile_id" "uuid" NOT NULL,
    "rol" "public"."user_role" DEFAULT 'tecnico'::"public"."user_role" NOT NULL,
    "experiencia_anios" smallint DEFAULT 0 NOT NULL,
    "descripcion" "text",
    "verificacion" "public"."verification_status" DEFAULT 'pendiente'::"public"."verification_status" NOT NULL,
    "promedio_calificacion" numeric(3,2) DEFAULT 0 NOT NULL,
    "total_calificaciones" integer DEFAULT 0 NOT NULL,
    "motivo_rechazo" "text",
    "rechazado_at" timestamp with time zone,
    "verificacion_solicitada_at" timestamp with time zone,
    CONSTRAINT "technician_profiles_descripcion_check" CHECK ((("descripcion" IS NULL) OR ("char_length"("descripcion") <= 1000))),
    CONSTRAINT "technician_profiles_experiencia_anios_check" CHECK ((("experiencia_anios" >= 0) AND ("experiencia_anios" <= 60))),
    CONSTRAINT "technician_profiles_motivo_rechazo_check" CHECK ((("motivo_rechazo" IS NULL) OR ("char_length"("motivo_rechazo") <= 500))),
    CONSTRAINT "technician_profiles_promedio_calificacion_check" CHECK ((("promedio_calificacion" >= (0)::numeric) AND ("promedio_calificacion" <= (5)::numeric))),
    CONSTRAINT "technician_profiles_rol_check" CHECK (("rol" = 'tecnico'::"public"."user_role")),
    CONSTRAINT "technician_profiles_total_calificaciones_check" CHECK (("total_calificaciones" >= 0))
);


ALTER TABLE "public"."technician_profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."technician_profiles"."rechazado_at" IS 'Último rechazo. Para volver a solicitar, debe subir documentos posteriores a esta fecha.';



COMMENT ON COLUMN "public"."technician_profiles"."verificacion_solicitada_at" IS 'Cuándo el técnico envió su documentación a revisión. NULL = aún no la envía.';



CREATE TABLE IF NOT EXISTS "public"."technician_zones" (
    "tecnico_id" "uuid" NOT NULL,
    "zona_id" smallint NOT NULL
);


ALTER TABLE "public"."technician_zones" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tecnicos_publicos" AS
 SELECT "p"."id",
    "p"."nombre",
    "p"."apellidos",
    "t"."experiencia_anios",
    "t"."descripcion",
    "t"."promedio_calificacion",
    "t"."total_calificaciones",
    ARRAY( SELECT "tc"."categoria_id"
           FROM "public"."technician_categories" "tc"
          WHERE ("tc"."tecnico_id" = "p"."id")
          ORDER BY "tc"."categoria_id") AS "categoria_ids",
    ARRAY( SELECT "tz"."zona_id"
           FROM "public"."technician_zones" "tz"
          WHERE ("tz"."tecnico_id" = "p"."id")
          ORDER BY "tz"."zona_id") AS "zona_ids"
   FROM ("public"."profiles" "p"
     JOIN "public"."technician_profiles" "t" ON (("t"."profile_id" = "p"."id")))
  WHERE (("t"."verificacion" = 'verificado'::"public"."verification_status") AND "p"."activo");


ALTER VIEW "public"."tecnicos_publicos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."zones" (
    "id" smallint NOT NULL,
    "nombre" "text" NOT NULL,
    "zona_padre_id" smallint,
    "activa" boolean DEFAULT true NOT NULL,
    CONSTRAINT "zones_check" CHECK (("zona_padre_id" IS DISTINCT FROM "id")),
    CONSTRAINT "zones_nombre_check" CHECK (("char_length"("btrim"("nombre")) > 0))
);


ALTER TABLE "public"."zones" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_solicitudes" WITH ("security_invoker"='true') AS
 SELECT "r"."id",
    "r"."estado",
    "r"."categoria_id",
    "c"."nombre" AS "categoria",
    "r"."zona_id",
    "z"."nombre" AS "zona",
    "r"."descripcion",
    "r"."direccion_servicio",
    "r"."fecha_programada",
    "r"."created_at",
    "r"."updated_at",
    "r"."cliente_id",
    NULLIF("btrim"((("pc"."nombre" || ' '::"text") || "pc"."apellidos")), ''::"text") AS "cliente_nombre",
    "r"."tecnico_id",
    NULLIF("btrim"((("tp"."nombre" || ' '::"text") || "tp"."apellidos")), ''::"text") AS "tecnico_nombre",
    "rv"."calificacion",
    "rv"."comentario"
   FROM ((((("public"."service_requests" "r"
     JOIN "public"."service_categories" "c" ON (("c"."id" = "r"."categoria_id")))
     JOIN "public"."zones" "z" ON (("z"."id" = "r"."zona_id")))
     LEFT JOIN "public"."profiles" "pc" ON (("pc"."id" = "r"."cliente_id")))
     LEFT JOIN "public"."tecnicos_publicos" "tp" ON (("tp"."id" = "r"."tecnico_id")))
     LEFT JOIN "public"."reviews" "rv" ON (("rv"."solicitud_id" = "r"."id")));


ALTER VIEW "public"."v_solicitudes" OWNER TO "postgres";


ALTER TABLE "public"."zones" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."zones_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."invoice_items"
    ADD CONSTRAINT "invoice_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_solicitud_id_key" UNIQUE ("solicitud_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_rol_key" UNIQUE ("id", "rol");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."request_status_history"
    ADD CONSTRAINT "request_status_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_solicitud_id_key" UNIQUE ("solicitud_id");



ALTER TABLE ONLY "public"."service_categories"
    ADD CONSTRAINT "service_categories_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."service_categories"
    ADD CONSTRAINT "service_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_requests"
    ADD CONSTRAINT "service_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."technician_categories"
    ADD CONSTRAINT "technician_categories_pkey" PRIMARY KEY ("tecnico_id", "categoria_id");



ALTER TABLE ONLY "public"."technician_documents"
    ADD CONSTRAINT "technician_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."technician_documents"
    ADD CONSTRAINT "technician_documents_storage_path_key" UNIQUE ("storage_path");



ALTER TABLE ONLY "public"."technician_profiles"
    ADD CONSTRAINT "technician_profiles_pkey" PRIMARY KEY ("profile_id");



ALTER TABLE ONLY "public"."technician_zones"
    ADD CONSTRAINT "technician_zones_pkey" PRIMARY KEY ("tecnico_id", "zona_id");



ALTER TABLE ONLY "public"."zones"
    ADD CONSTRAINT "zones_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_hist_cambiado_por" ON "public"."request_status_history" USING "btree" ("cambiado_por");



CREATE INDEX "idx_hist_solicitud" ON "public"."request_status_history" USING "btree" ("solicitud_id");



CREATE INDEX "idx_invoice_items_factura" ON "public"."invoice_items" USING "btree" ("factura_id");



CREATE INDEX "idx_invoices_revision" ON "public"."invoices" USING "btree" ("created_at" DESC) WHERE "excede_referencia";



CREATE INDEX "idx_invoices_tecnico" ON "public"."invoices" USING "btree" ("tecnico_id", "created_at" DESC);



CREATE INDEX "idx_notif_solicitud" ON "public"."notifications" USING "btree" ("solicitud_id");



CREATE INDEX "idx_notif_usuario" ON "public"."notifications" USING "btree" ("usuario_id", "leida", "created_at" DESC);



CREATE INDEX "idx_profiles_rol" ON "public"."profiles" USING "btree" ("rol");



CREATE INDEX "idx_profiles_zona" ON "public"."profiles" USING "btree" ("zona_id");



CREATE INDEX "idx_req_categoria" ON "public"."service_requests" USING "btree" ("categoria_id");



CREATE INDEX "idx_req_cliente" ON "public"."service_requests" USING "btree" ("cliente_id", "created_at" DESC);



CREATE INDEX "idx_req_tecnico" ON "public"."service_requests" USING "btree" ("tecnico_id", "created_at" DESC);



CREATE INDEX "idx_req_tecnico_activas" ON "public"."service_requests" USING "btree" ("tecnico_id", "fecha_programada") WHERE ("estado" = ANY (ARRAY['pendiente'::"public"."request_status", 'aceptado'::"public"."request_status", 'en_proceso'::"public"."request_status"]));



CREATE INDEX "idx_req_zona" ON "public"."service_requests" USING "btree" ("zona_id");



CREATE INDEX "idx_reviews_cliente" ON "public"."reviews" USING "btree" ("cliente_id");



CREATE INDEX "idx_reviews_tecnico" ON "public"."reviews" USING "btree" ("tecnico_id");



CREATE INDEX "idx_teccat_categoria" ON "public"."technician_categories" USING "btree" ("categoria_id");



CREATE INDEX "idx_techdocs_tecnico" ON "public"."technician_documents" USING "btree" ("tecnico_id", "created_at");



CREATE INDEX "idx_tecprof_profile_rol" ON "public"."technician_profiles" USING "btree" ("profile_id", "rol");



CREATE INDEX "idx_teczona_zona" ON "public"."technician_zones" USING "btree" ("zona_id");



CREATE INDEX "idx_zones_padre" ON "public"."zones" USING "btree" ("zona_padre_id");



CREATE UNIQUE INDEX "uq_req_pendiente_cliente_tecnico" ON "public"."service_requests" USING "btree" ("cliente_id", "tecnico_id") WHERE ("estado" = 'pendiente'::"public"."request_status");



CREATE UNIQUE INDEX "uq_zones_nombre" ON "public"."zones" USING "btree" (COALESCE(("zona_padre_id")::integer, 0), "lower"("btrim"("nombre")));



CREATE OR REPLACE TRIGGER "trg_log_status_insert" AFTER INSERT ON "public"."service_requests" FOR EACH ROW EXECUTE FUNCTION "public"."log_request_status"();



CREATE OR REPLACE TRIGGER "trg_log_status_update" AFTER UPDATE OF "estado" ON "public"."service_requests" FOR EACH ROW WHEN (("old"."estado" IS DISTINCT FROM "new"."estado")) EXECUTE FUNCTION "public"."log_request_status"();



CREATE OR REPLACE TRIGGER "trg_profiles_updated" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_refresh_rating" AFTER INSERT ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."refresh_technician_rating"();



CREATE OR REPLACE TRIGGER "trg_requests_updated" BEFORE UPDATE ON "public"."service_requests" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_require_invoice" BEFORE UPDATE OF "estado" ON "public"."service_requests" FOR EACH ROW EXECUTE FUNCTION "public"."require_invoice_to_finish"();



CREATE OR REPLACE TRIGGER "trg_validate_new_request" BEFORE INSERT ON "public"."service_requests" FOR EACH ROW EXECUTE FUNCTION "public"."validate_new_request"();



CREATE OR REPLACE TRIGGER "trg_validate_review" BEFORE INSERT ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."validate_review"();



CREATE OR REPLACE TRIGGER "trg_validate_status" BEFORE UPDATE OF "estado" ON "public"."service_requests" FOR EACH ROW EXECUTE FUNCTION "public"."validate_status_transition"();



CREATE OR REPLACE TRIGGER "trg_validate_technician_document" BEFORE INSERT ON "public"."technician_documents" FOR EACH ROW EXECUTE FUNCTION "public"."validate_technician_document"();



CREATE OR REPLACE TRIGGER "trg_zone_parent" BEFORE UPDATE OF "zona_padre_id" ON "public"."zones" FOR EACH ROW EXECUTE FUNCTION "public"."validate_zone_parent"();



ALTER TABLE ONLY "public"."invoice_items"
    ADD CONSTRAINT "invoice_items_factura_id_fkey" FOREIGN KEY ("factura_id") REFERENCES "public"."invoices"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."service_requests"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."service_requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_zona_id_fkey" FOREIGN KEY ("zona_id") REFERENCES "public"."zones"("id");



ALTER TABLE ONLY "public"."request_status_history"
    ADD CONSTRAINT "request_status_history_cambiado_por_fkey" FOREIGN KEY ("cambiado_por") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."request_status_history"
    ADD CONSTRAINT "request_status_history_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."service_requests"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."service_requests"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id");



ALTER TABLE ONLY "public"."service_requests"
    ADD CONSTRAINT "service_requests_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."service_categories"("id");



ALTER TABLE ONLY "public"."service_requests"
    ADD CONSTRAINT "service_requests_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."profiles"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."service_requests"
    ADD CONSTRAINT "service_requests_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."service_requests"
    ADD CONSTRAINT "service_requests_zona_id_fkey" FOREIGN KEY ("zona_id") REFERENCES "public"."zones"("id");



ALTER TABLE ONLY "public"."technician_categories"
    ADD CONSTRAINT "technician_categories_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."service_categories"("id");



ALTER TABLE ONLY "public"."technician_categories"
    ADD CONSTRAINT "technician_categories_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."technician_documents"
    ADD CONSTRAINT "technician_documents_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."technician_profiles"
    ADD CONSTRAINT "technician_profiles_profile_id_rol_fkey" FOREIGN KEY ("profile_id", "rol") REFERENCES "public"."profiles"("id", "rol") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."technician_zones"
    ADD CONSTRAINT "technician_zones_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."technician_profiles"("profile_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."technician_zones"
    ADD CONSTRAINT "technician_zones_zona_id_fkey" FOREIGN KEY ("zona_id") REFERENCES "public"."zones"("id");



ALTER TABLE ONLY "public"."zones"
    ADD CONSTRAINT "zones_zona_padre_id_fkey" FOREIGN KEY ("zona_padre_id") REFERENCES "public"."zones"("id") ON DELETE RESTRICT;



CREATE POLICY "categories_admin_delete" ON "public"."service_categories" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "categories_admin_insert" ON "public"."service_categories" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "categories_admin_update" ON "public"."service_categories" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "categories_select" ON "public"."service_categories" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "hist_select" ON "public"."request_status_history" FOR SELECT TO "authenticated" USING ((( SELECT "public"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."service_requests" "r"
  WHERE (("r"."id" = "request_status_history"."solicitud_id") AND (("r"."cliente_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("r"."tecnico_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "inv_select" ON "public"."invoices" FOR SELECT TO "authenticated" USING ((("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."service_requests" "r"
  WHERE (("r"."id" = "invoices"."solicitud_id") AND ("r"."cliente_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "invitem_select" ON "public"."invoice_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."invoices" "i"
  WHERE ("i"."id" = "invoice_items"."factura_id"))));



ALTER TABLE "public"."invoice_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notif_select" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("usuario_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notif_update" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("usuario_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("usuario_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."service_requests" "r"
  WHERE (("r"."tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("r"."cliente_id" = "profiles"."id")))) OR (EXISTS ( SELECT 1
   FROM "public"."service_requests" "r"
  WHERE (("r"."cliente_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("r"."tecnico_id" = "profiles"."id") AND ("r"."estado" = ANY (ARRAY['aceptado'::"public"."request_status", 'en_proceso'::"public"."request_status", 'finalizado'::"public"."request_status"])))))));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "req_insert" ON "public"."service_requests" FOR INSERT TO "authenticated" WITH CHECK ((("cliente_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("estado" = 'pendiente'::"public"."request_status") AND (( SELECT "public"."my_role"() AS "my_role") = 'cliente'::"public"."user_role")));



CREATE POLICY "req_select" ON "public"."service_requests" FOR SELECT TO "authenticated" USING ((("cliente_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "req_update" ON "public"."service_requests" FOR UPDATE TO "authenticated" USING ((("cliente_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin"))) WITH CHECK ((("cliente_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."request_status_history" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "rev_insert" ON "public"."reviews" FOR INSERT TO "authenticated" WITH CHECK (("cliente_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "rev_select" ON "public"."reviews" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "teccat_admin_delete" ON "public"."technician_categories" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "teccat_admin_insert" ON "public"."technician_categories" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "public"."is_admin"() AS "is_admin") AND (EXISTS ( SELECT 1
   FROM "public"."service_categories" "c"
  WHERE (("c"."id" = "technician_categories"."categoria_id") AND "c"."activa")))));



CREATE POLICY "teccat_select" ON "public"."technician_categories" FOR SELECT TO "authenticated" USING ((("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "techdocs_insert" ON "public"."technician_documents" FOR INSERT TO "authenticated" WITH CHECK ((("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) AND (( SELECT "public"."my_role"() AS "my_role") = 'tecnico'::"public"."user_role") AND ("storage_path" ~~ ((( SELECT "auth"."uid"() AS "uid"))::"text" || '/%'::"text")) AND (EXISTS ( SELECT 1
   FROM "storage"."objects" "o"
  WHERE (("o"."bucket_id" = 'documentos-tecnicos'::"text") AND ("o"."name" = "technician_documents"."storage_path"))))));



CREATE POLICY "techdocs_select" ON "public"."technician_documents" FOR SELECT TO "authenticated" USING ((("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."technician_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."technician_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."technician_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."technician_zones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tecprof_select" ON "public"."technician_profiles" FOR SELECT TO "authenticated" USING ((("profile_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "tecprof_update_own" ON "public"."technician_profiles" FOR UPDATE TO "authenticated" USING (("profile_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("profile_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "teczona_admin_delete" ON "public"."technician_zones" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "teczona_admin_insert" ON "public"."technician_zones" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "public"."is_admin"() AS "is_admin") AND (EXISTS ( SELECT 1
   FROM "public"."zones" "z"
  WHERE (("z"."id" = "technician_zones"."zona_id") AND "z"."activa")))));



CREATE POLICY "teczona_select" ON "public"."technician_zones" FOR SELECT TO "authenticated" USING ((("tecnico_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."zones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "zones_admin_delete" ON "public"."zones" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "zones_admin_insert" ON "public"."zones" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "zones_admin_update" ON "public"."zones" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "zones_select_anon" ON "public"."zones" FOR SELECT TO "anon" USING ("activa");



CREATE POLICY "zones_select_auth" ON "public"."zones" FOR SELECT TO "authenticated" USING (true);





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."service_requests";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































REVOKE ALL ON FUNCTION "public"."admin_facturas_revision"("p_solo_excedidas" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_facturas_revision"("p_solo_excedidas" boolean) TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_facturas_revision"("p_solo_excedidas" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_ranking_tecnicos"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_ranking_tecnicos"("p_limit" integer) TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_ranking_tecnicos"("p_limit" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_reporte_servicios"("p_desde" "date", "p_hasta" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_reporte_servicios"("p_desde" "date", "p_hasta" "date") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_reporte_servicios"("p_desde" "date", "p_hasta" "date") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_reporte_zonas"("p_desde" "date", "p_hasta" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_reporte_zonas"("p_desde" "date", "p_hasta" "date") TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_reporte_zonas"("p_desde" "date", "p_hasta" "date") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_resumen"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_resumen"() TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_resumen"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_set_usuario_activo"("p_usuario" "uuid", "p_activo" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_set_usuario_activo"("p_usuario" "uuid", "p_activo" boolean) TO "service_role";
GRANT ALL ON FUNCTION "public"."admin_set_usuario_activo"("p_usuario" "uuid", "p_activo" boolean) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_verificar_tecnico"("p_tecnico" "uuid", "p_estado" "public"."verification_status", "p_motivo" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_verificar_tecnico"("p_tecnico" "uuid", "p_estado" "public"."verification_status", "p_motivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_verificar_tecnico"("p_tecnico" "uuid", "p_estado" "public"."verification_status", "p_motivo" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."buscar_tecnicos"("p_categoria" smallint, "p_zona" smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."buscar_tecnicos"("p_categoria" smallint, "p_zona" smallint) TO "service_role";
GRANT ALL ON FUNCTION "public"."buscar_tecnicos"("p_categoria" smallint, "p_zona" smallint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."cancelar_solicitudes_tecnico"("p_tecnico" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancelar_solicitudes_tecnico"("p_tecnico" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cerrar_solicitud"("p_solicitud" "uuid", "p_mano_obra" numeric, "p_materiales" "jsonb", "p_justificacion" "text", "p_notas" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cerrar_solicitud"("p_solicitud" "uuid", "p_mano_obra" numeric, "p_materiales" "jsonb", "p_justificacion" "text", "p_notas" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."cerrar_solicitud"("p_solicitud" "uuid", "p_mano_obra" numeric, "p_materiales" "jsonb", "p_justificacion" "text", "p_notas" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."log_request_status"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."log_request_status"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_role"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_role"() TO "service_role";
GRANT ALL ON FUNCTION "public"."my_role"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."refresh_technician_rating"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_technician_rating"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."require_invoice_to_finish"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."require_invoice_to_finish"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_updated_at"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."solicitar_verificacion"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."solicitar_verificacion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."solicitar_verificacion"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_new_request"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_new_request"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_review"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_review"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_status_transition"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_status_transition"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_technician_document"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_technician_document"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."validate_zone_parent"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_zone_parent"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."zone_covers"("p_tecnico" "uuid", "p_zona" smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."zone_covers"("p_tecnico" "uuid", "p_zona" smallint) TO "service_role";


















GRANT ALL ON TABLE "public"."invoice_items" TO "service_role";
GRANT SELECT ON TABLE "public"."invoice_items" TO "authenticated";



GRANT ALL ON SEQUENCE "public"."invoice_items_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."invoices" TO "service_role";
GRANT SELECT ON TABLE "public"."invoices" TO "authenticated";



GRANT ALL ON TABLE "public"."notifications" TO "service_role";
GRANT SELECT ON TABLE "public"."notifications" TO "authenticated";



GRANT UPDATE("leida") ON TABLE "public"."notifications" TO "authenticated";



GRANT ALL ON SEQUENCE "public"."notifications_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "service_role";
GRANT SELECT ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("nombre") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("apellidos") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("telefono") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("direccion") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("zona_id") ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."request_status_history" TO "service_role";
GRANT SELECT ON TABLE "public"."request_status_history" TO "authenticated";



GRANT ALL ON SEQUENCE "public"."request_status_history_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "service_role";
GRANT SELECT ON TABLE "public"."reviews" TO "authenticated";



GRANT INSERT("solicitud_id") ON TABLE "public"."reviews" TO "authenticated";



GRANT INSERT("cliente_id") ON TABLE "public"."reviews" TO "authenticated";



GRANT INSERT("tecnico_id") ON TABLE "public"."reviews" TO "authenticated";



GRANT INSERT("calificacion") ON TABLE "public"."reviews" TO "authenticated";



GRANT INSERT("comentario") ON TABLE "public"."reviews" TO "authenticated";



GRANT ALL ON TABLE "public"."service_categories" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."service_categories" TO "authenticated";
GRANT SELECT ON TABLE "public"."service_categories" TO "anon";



GRANT ALL ON SEQUENCE "public"."service_categories_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."service_requests" TO "service_role";
GRANT SELECT ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("cliente_id") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("tecnico_id") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("categoria_id") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("zona_id") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("descripcion") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("direccion_servicio") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("fecha_programada") ON TABLE "public"."service_requests" TO "authenticated";



GRANT INSERT("estado"),UPDATE("estado") ON TABLE "public"."service_requests" TO "authenticated";



GRANT ALL ON TABLE "public"."technician_categories" TO "service_role";
GRANT SELECT,INSERT,DELETE ON TABLE "public"."technician_categories" TO "authenticated";



GRANT ALL ON TABLE "public"."technician_documents" TO "service_role";
GRANT SELECT ON TABLE "public"."technician_documents" TO "authenticated";



GRANT INSERT("tecnico_id") ON TABLE "public"."technician_documents" TO "authenticated";



GRANT INSERT("tipo") ON TABLE "public"."technician_documents" TO "authenticated";



GRANT INSERT("nombre_archivo") ON TABLE "public"."technician_documents" TO "authenticated";



GRANT INSERT("storage_path") ON TABLE "public"."technician_documents" TO "authenticated";



GRANT ALL ON SEQUENCE "public"."technician_documents_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."technician_documents_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."technician_documents_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."technician_profiles" TO "service_role";
GRANT SELECT ON TABLE "public"."technician_profiles" TO "authenticated";



GRANT UPDATE("experiencia_anios") ON TABLE "public"."technician_profiles" TO "authenticated";



GRANT UPDATE("descripcion") ON TABLE "public"."technician_profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."technician_zones" TO "service_role";
GRANT SELECT,INSERT,DELETE ON TABLE "public"."technician_zones" TO "authenticated";



GRANT ALL ON TABLE "public"."tecnicos_publicos" TO "service_role";
GRANT SELECT ON TABLE "public"."tecnicos_publicos" TO "authenticated";



GRANT ALL ON TABLE "public"."zones" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."zones" TO "authenticated";
GRANT SELECT ON TABLE "public"."zones" TO "anon";



GRANT ALL ON TABLE "public"."v_solicitudes" TO "service_role";
GRANT SELECT ON TABLE "public"."v_solicitudes" TO "authenticated";



GRANT ALL ON SEQUENCE "public"."zones_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";

-- Crea el perfil automáticamente al registrarse un usuario
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Bucket privado para documentos de técnicos (máx. 5 MB, PDF o imagen)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos-tecnicos', 'documentos-tecnicos', false, 5242880,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- El técnico sube archivos solo a su carpeta: <uid>/<archivo>
create policy documentos_tecnicos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documentos-tecnicos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.my_role()) = 'tecnico'
  );

-- Lee sus propios archivos; el admin lee todos
create policy documentos_tecnicos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documentos-tecnicos'
    and ((storage.foldername(name))[1] = (select auth.uid())::text
         or (select public.is_admin()))
  );


































