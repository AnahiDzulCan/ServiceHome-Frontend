# ServiceHome — Frontend

Marketplace de servicios para el hogar. Los clientes buscan técnicos verificados por categoría y zona, crean solicitudes, y el técnico las atiende, factura y recibe una calificación. Hay un panel de administración.

## Stack

- React + Vite + TypeScript (modo `strict`)
- Ant Design (componentes, `Form`, `Table`, `message`/`notification` para feedback). Usar `ConfigProvider` con locale `es_ES` y dayjs en español.
- Supabase (`@supabase/supabase-js` v2) como backend completo: Auth, Postgres con RLS y funciones RPC. **No hay backend propio ni edge functions.**
- Tipos de la base: `src/types/supabase.ts` (generado; no editar a mano).

## Conexión a Supabase

- Proyecto: `ServiceHome` (ref `xmzdqxgfvqxuuxqqhuwa`)
- Variables en `.env.local` (no se suben al repo):
  ```
  VITE_SUPABASE_URL=https://xmzdqxgfvqxuuxqqhuwa.supabase.co
  VITE_SUPABASE_ANON_KEY=<publishable/anon key del dashboard>
  ```
- Cliente único en `src/lib/supabase.ts`:
  ```ts
  import { createClient } from '@supabase/supabase-js'
  import type { Database } from '@/types/supabase'
  export const supabase = createClient<Database>(
    import.meta.env.VITE_SUPABASE_URL,
    import.meta.env.VITE_SUPABASE_ANON_KEY,
  )
  ```
- **Nunca** usar la `service_role` key en el frontend.
- Regenerar tipos tras cualquier cambio de esquema:
  `pnpm supabase gen types typescript --project-id xmzdqxgfvqxuuxqqhuwa > src/types/supabase.ts`
- Gestor de paquetes: **pnpm** (nunca npm ni yarn). Comandos: `pnpm dev`, `pnpm build`, `pnpm add <paquete>`.

## Acceso a Supabase desde Claude Code (MCP)

- El servidor MCP `supabase` está configurado en `.mcp.json`, limitado a este proyecto y en **solo lectura**. Úsalo para consultar el esquema, políticas, funciones, logs y advisors **antes** de escribir código que dependa de la base. Si algo de este archivo contradice lo que dice la base, la base manda: avísame de la diferencia.
- **Nunca cambies el esquema desde el MCP.** Todo cambio de base va así:
  1. `pnpm supabase migration new <nombre>` crea el archivo en `supabase/migrations/`.
  2. Escribes el SQL ahí y me lo muestras para revisión.
  3. Yo lo aplico con `pnpm supabase db push` (target remoto).
  4. Regeneras los tipos (ver abajo) y actualizas este archivo si cambian reglas de negocio.
- **Nunca** ejecutes `pnpm supabase db reset` con `--remote`/`--linked`: borra la base en la nube.
- `supabase/historial/` es solo referencia; no lo uses como migraciones.

## Reglas de oro

1. **La base de datos es la fuente de verdad de las reglas de negocio.** RLS, permisos por columna y triggers validan todo. El frontend valida para dar buena UX, pero no duplica lógica ni intenta saltársela.
2. **Los errores de la base vienen en español y son legibles** (p. ej. "Transición de estado no permitida: pendiente -> finalizado"). Mostrar `error.message` con `message.error()`.
3. **Solo se pueden actualizar las columnas permitidas** (ver tabla de permisos). Un `update` con otras columnas falla con `permission denied`.
4. No cambiar el esquema desde el frontend. Cambios de base = migración SQL revisada aparte.

## Roles

`profiles.rol`: `cliente` | `tecnico` | `admin`. Obtener el rol actual con `rpc('my_role')` (devuelve `null` si el usuario está **desactivado**; en ese caso mostrar aviso y cerrar sesión). El rol no se puede cambiar desde el cliente; el admin se asigna por SQL.

## Registro (Auth)

`supabase.auth.signUp({ email, password, options: { data } })`. El trigger `handle_new_user` crea el perfil desde `data` con estas claves exactas:

| clave | tipo | notas |
|---|---|---|
| `nombre`, `apellidos` | string | máx. 80 |
| `telefono` | string | regex `^[0-9+() -]{7,20}$`, si no cumple se ignora |
| `direccion` | string | máx. 250 |
| `zona_id` | number | opcional; se ignora si no existe o está inactiva |
| `rol` | `'tecnico'` | cualquier otro valor = cliente |
| `experiencia_anios` | number | solo técnico, 0–60 |

`zones` (solo activas) y `service_categories` son legibles sin sesión, así que el formulario de registro puede listarlas. En un técnico, `zona_id` queda solo como referencia en su perfil: **no** se le asigna como zona de servicio (eso lo hace el admin).

## Verificación de técnicos

Estados de `technician_profiles.verificacion`: `pendiente` → `verificado` | `rechazado`.

1. El técnico se registra → `pendiente` con `verificacion_solicitada_at = null` (aún no envía nada).
2. Sube documentos:
   - Archivo a Storage, bucket privado `documentos-tecnicos`, ruta **obligatoria** `<uid>/<nombre-único>` (PDF, JPG, PNG o WEBP; máx. 5 MB). Usar `upsert: false` y nombres únicos (p. ej. `${uid}/${crypto.randomUUID()}.pdf`).
   - Luego `insert` en `technician_documents` (`tecnico_id`, `tipo`, `nombre_archivo`, `storage_path`). `tipo`: `identificacion` | `comprobante_domicilio` | `certificacion` | `otro`. Máx. 20 documentos. No se pueden borrar (historial para el admin).
3. `rpc('solicitar_verificacion')` → queda en revisión (`verificacion_solicitada_at` con fecha) y se notifica a los admins.
4. El admin revisa los documentos (`createSignedUrl` sobre el bucket), le **asigna especialidades y zonas** y llama `admin_verificar_tecnico`:
   - `verificado`: requiere al menos 1 documento, 1 especialidad y 1 zona.
   - `rechazado`: requiere `p_motivo` (10–500 caracteres). Se guarda en `motivo_rechazo` y `rechazado_at`, y se notifica al técnico.
5. Un técnico rechazado debe **subir documentos nuevos** (posteriores a `rechazado_at`) antes de volver a llamar `solicitar_verificacion`.

UI del técnico según estado:
- `pendiente` sin `verificacion_solicitada_at` → "Sube tus documentos y envía a revisión".
- `pendiente` con `verificacion_solicitada_at` → "En revisión".
- `rechazado` → mostrar `motivo_rechazo` y pedir documentos nuevos.
- `verificado` → acceso normal.

Bandeja del admin: técnicos con `verificacion = 'pendiente'` y `verificacion_solicitada_at` no nulo.

## Modelo de datos (schema `public`)

- `service_categories` (id, nombre, descripcion, activa, mano_obra_max)
- `zones` (id, nombre, zona_padre_id, activa). Son jerárquicas: un técnico que cubre una zona padre cubre sus subzonas.
- `profiles` (id = auth.users.id, rol, nombre, apellidos, telefono, direccion, zona_id, activo)
- `technician_profiles` (profile_id, experiencia_anios, descripcion, verificacion, motivo_rechazo, rechazado_at, verificacion_solicitada_at, promedio_calificacion, total_calificaciones)
- `technician_documents` (tecnico_id, tipo, nombre_archivo, storage_path, created_at)
- `technician_categories` (tecnico_id, categoria_id), `technician_zones` (tecnico_id, zona_id)
- `service_requests` (id, cliente_id, tecnico_id, categoria_id, zona_id, descripcion 10–2000, direccion_servicio 5–250, fecha_programada, estado)
- `request_status_history` (solicitud_id, estado, cambiado_por, created_at). Se llena solo por trigger.
- `invoices` (solicitud_id único, tecnico_id, mano_obra, total_materiales, total generado, excede_referencia, justificacion_mano_obra, notas)
- `invoice_items` (factura_id, descripcion, cantidad, unidad default 'pza', precio_unitario, importe generado)
- `reviews` (solicitud_id único, cliente_id, tecnico_id, calificacion 1–5, comentario ≤1000)
- `notifications` (usuario_id, solicitud_id, mensaje, leida). Se crean solas por trigger en cada cambio de estado.

### Vistas (preferirlas para listar)

- `v_solicitudes`: solicitud + nombres de categoría, zona, cliente, técnico + calificación/comentario. Respeta RLS (security invoker): cada quien ve solo lo suyo.
- `tecnicos_publicos`: técnicos verificados y activos con `categoria_ids[]` y `zona_ids[]`. Solo datos públicos (sin teléfono ni dirección).

## Qué puede escribir cada rol

| Tabla | Operación | Columnas permitidas | Quién |
|---|---|---|---|
| profiles | update | nombre, apellidos, telefono, direccion, zona_id | el propio usuario |
| technician_profiles | update | descripcion, experiencia_anios | el propio técnico |
| technician_categories / technician_zones | insert/delete | — | **solo admin** (solo categorías/zonas activas); el técnico solo las lee |
| technician_documents | insert | tecnico_id, tipo, nombre_archivo, storage_path | el propio técnico (sin update ni delete) |
| service_requests | insert | cliente_id, tecnico_id, categoria_id, zona_id, descripcion, direccion_servicio, fecha_programada, estado (`pendiente`) | cliente activo |
| service_requests | update | **solo `estado`** | cliente/técnico de la solicitud |
| reviews | insert | solicitud_id, calificacion, comentario, cliente_id | cliente, solo si está `finalizado` |
| notifications | update | **solo `leida`** | el destinatario |
| service_categories / zones | todo | — | admin |

## Ciclo de vida de una solicitud

| De | A | Quién | Cómo |
|---|---|---|---|
| pendiente | aceptado / rechazado | técnico asignado | `update({ estado })` |
| pendiente / aceptado | cancelado | cliente | `update({ estado })` |
| aceptado | en_proceso | técnico | `update({ estado })` |
| en_proceso | finalizado | técnico | **solo con `rpc('cerrar_solicitud')`** |

**Límites anti-spam** al crear solicitudes (la base responde con un mensaje en español):
- 1 solicitud `pendiente` por cliente con el mismo técnico.
- Si un técnico rechazó al cliente, debe esperar 24 h para volver a pedirle.
- Máx. 5 solicitudes `pendiente` por cliente.
- Máx. 10 solicitudes nuevas por cliente en 24 h.

**Técnico no disponible:** si el admin desactiva a un técnico (`admin_set_usuario_activo`) o le quita la verificación, sus solicitudes `pendiente`, `aceptado` y `en_proceso` pasan a `cancelado` automáticamente y el cliente recibe la notificación "El técnico asignado ya no está disponible…".

La UI debe mostrar únicamente las acciones válidas según rol + estado. Colores sugeridos para `Tag`: pendiente=gold, aceptado=blue, en_proceso=processing, finalizado=success, rechazado=error, cancelado=default.

El cliente **no** puede ver el teléfono/dirección del técnico vía `profiles` hasta que la solicitud está aceptada, en proceso o finalizada.

## Funciones RPC

**Cliente**
- `buscar_tecnicos({ p_categoria, p_zona })` → técnicos verificados que cubren esa categoría y zona, ordenados por calificación.

**Técnico**
- `cerrar_solicitud({ p_solicitud, p_mano_obra, p_materiales, p_justificacion?, p_notas? })` → crea factura + partidas y marca `finalizado`. Devuelve el id de la factura.
  - `p_materiales`: `Array<{ descripcion: string; cantidad: number; unidad?: string; precio_unitario: number }>`, máx. 50.
  - Si `p_mano_obra` > `service_categories.mano_obra_max`, `p_justificacion` es obligatoria (≥10 caracteres). Mostrar el tope en el formulario y pedir la justificación en ese caso.

**Técnico (verificación)**
- `solicitar_verificacion()` → envía sus documentos a revisión (ver sección Verificación).

**Admin** (todas fallan con error si no eres admin)
- `admin_resumen()` → JSON con usuarios por rol, técnicos pendientes, solicitudes por estado, etc.
- `admin_reporte_servicios({ p_desde?, p_hasta? })`, `admin_reporte_zonas({ p_desde?, p_hasta? })` (fechas `YYYY-MM-DD`)
- `admin_ranking_tecnicos({ p_limit? })`
- `admin_facturas_revision({ p_solo_excedidas? })`
- `admin_verificar_tecnico({ p_tecnico, p_estado, p_motivo? })`: `p_motivo` obligatorio al rechazar.
- `admin_set_usuario_activo({ p_usuario, p_activo })`: desactivar a un técnico cancela sus solicitudes abiertas.

**Utilidades**: `my_role()`, `is_admin()`.

## Pantallas

- **Público**: Login, Registro (cliente / técnico), Recuperar contraseña.
- **Cliente**: Buscar técnico → Crear solicitud · Mis solicitudes (lista + detalle con historial, factura y calificar) · Notificaciones · Perfil.
- **Técnico**: Verificación (subir documentos con `Upload`, ver estado y motivo de rechazo, enviar a revisión) · Perfil (descripción y experiencia; especialidades y zonas solo lectura) · Bandeja de solicitudes (aceptar / rechazar / iniciar) · Cerrar servicio (formulario de factura con `Form.List` para materiales) · Mis reseñas · Notificaciones.
- **Admin**: Dashboard (resumen + reportes) · Verificación de técnicos (ver documentos, asignar especialidades y zonas, verificar o rechazar con motivo) · Usuarios (activar/desactivar, con aviso de que se cancelan las solicitudes abiertas del técnico) · Facturas excedidas · Categorías · Zonas (árbol).

Rutas protegidas por sesión y por rol. Layout con `Layout` + `Menu` lateral según rol.

## Convenciones

- Estructura: `src/lib`, `src/types`, `src/features/<dominio>/` (componentes, hooks y llamadas de ese dominio), `src/routes`, `src/layouts`.
- Llamadas a Supabase dentro de hooks o servicios por dominio, nunca sueltas en componentes de UI.
- Tipos con los helpers generados: `Tables<'v_solicitudes'>`, `TablesInsert<'service_requests'>`, `Enums<'request_status'>`.
- Textos de la UI en español (México). Moneda MXN con `Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' })`.
- Siempre manejar `{ data, error }` de supabase-js; nunca asumir que `data` existe.
