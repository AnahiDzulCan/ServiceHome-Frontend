# ServiceHome — Frontend

Cliente web de **ServiceHome**, una plataforma que conecta a clientes con técnicos para servicios del hogar (electricidad, plomería, etc.). Los clientes exploran categorías de servicio y solicitan una visita; los técnicos reciben y gestionan esas solicitudes; los administradores supervisan usuarios, técnicos, facturas y reportes.

Este repositorio contiene solo el frontend. El backend es [Supabase](https://supabase.com): el cliente ya está configurado, pero las pantallas todavía usan **datos de prueba (mocks)** mientras se van conectando.

## Tecnologías

- [React 19](https://react.dev) + [TypeScript](https://www.typescriptlang.org)
- [Vite](https://vite.dev) como servidor de desarrollo y para compilar
- [React Router 7](https://reactrouter.com) para el enrutamiento
- [Supabase](https://supabase.com) como backend (base de datos y autenticación), mediante `@supabase/supabase-js`
- Componentes de [Ant Design 6](https://ant.design) e íconos de `@ant-design/icons` (además de `lucide-react`)
- CSS plano con variables de diseño compartidas en `src/styles/variables.css`
- ESLint (configuración flat) con `typescript-eslint` y reglas de React Hooks
- [pnpm](https://pnpm.io) como gestor de paquetes (`pnpm-lock.yaml`)

## Primeros pasos

Requisitos: Node.js 20+, pnpm y acceso a un proyecto de Supabase.

```bash
pnpm install
cp .env.example .env.local   # luego rellena los valores (ver abajo)
pnpm dev
```

### Variables de entorno

El archivo [`.env.example`](.env.example) es una plantilla con las variables que necesita la app, **sin valores reales**. Cópialo como `.env.local` y rellénalo con los datos de tu proyecto de Supabase:

| Variable                        | Dónde encontrarla en Supabase                                                  |
| ------------------------------- | ------------------------------------------------------------------------------ |
| `VITE_SUPABASE_URL`             | Botón **Connect** o *Project Settings → Data API*. Tiene la forma `https://<project-id>.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | *Project Settings → API Keys* → **Publishable key** (`sb_publishable_...`), o la clave `anon` en proyectos antiguos |

Importante:

- **`.env.local` no se sube al repositorio** (está en `.gitignore`). No subas tus claves; si añades una variable nueva, agrégala también a `.env.example` con un valor de ejemplo.
- **Usa solo la clave *publishable* / `anon`.** Nunca pongas la clave `service_role` / *secret* en el frontend: ignora las políticas de seguridad (RLS).
- Las variables deben empezar por `VITE_`; si no, Vite no las expone al código del navegador.
- Después de modificar `.env.local`, **reinicia `pnpm dev`**: Vite solo lee el archivo al arrancar.
- Si falta alguna variable, la app muestra en la consola el error *"Faltan variables de entorno de Supabase"* (ver [`src/lib/supabase.ts`](src/lib/supabase.ts)).

Después abre <http://localhost:5173/login>. Aún no existe una ruta en `/`, así que empieza desde `/login`.

### Scripts

| Comando        | Descripción                                                        |
| -------------- | ------------------------------------------------------------------ |
| `pnpm dev`     | Inicia el servidor de desarrollo de Vite con recarga en caliente   |
| `pnpm build`   | Revisa los tipos (`tsc -b`) y compila para producción en `dist/`   |
| `pnpm preview` | Sirve localmente la versión compilada                              |
| `pnpm lint`    | Ejecuta ESLint sobre el proyecto                                   |

## Rutas

Definidas en [`src/routes/AppRouter.tsx`](src/routes/AppRouter.tsx).

| Ruta              | Pantalla                                                                 |
| ----------------- | ------------------------------------------------------------------------ |
| `/login`          | Formulario de inicio de sesión. Al enviarlo pasa a la selección de rol (aún sin autenticación). |
| `/seleccionRol`   | Elegir entrar como **Cliente** o **Técnico**.                            |
| `/cliente/inicio` | Inicio del cliente: carrusel de anuncios y categorías de servicio. Al elegir una categoría se abre el formulario de solicitud (dirección, fecha, hora, notas). |
| `/cliente/*`      | Panel de cliente provisional                                             |
| `/tecnico/*`      | Panel de técnico provisional                                             |

Los menús de navegación de cada rol (`cliente`, `tecnico`, `admin`) se configuran en [`src/utils/navigation.tsx`](src/utils/navigation.tsx). Algunas páginas enlazadas (por ejemplo `/cliente/solicitudes`, `/recuperar` y toda la sección `/admin/*`) todavía no están implementadas.

## Estructura del proyecto

```
src/
├── assets/          Imágenes y recursos estáticos
├── components/
│   ├── announcements/   Carrusel de anuncios del inicio
│   ├── common/layout/   Layout de las páginas públicas
│   ├── navigation/      Barra lateral (escritorio), navegación inferior (móvil), tarjeta de usuario
│   ├── requests/        Tarjetas de categoría y modal de solicitud de servicio
│   └── ui/              Piezas de UI compartidas (p. ej. AuthCard)
├── layouts/         PanelLayout: estructura del panel con navegación según el rol
├── lib/             Cliente de Supabase (supabase.ts), compartido por toda la app
├── mocks/           Datos de prueba (anuncios, categorías)
├── pages/
│   ├── public/      Inicio de sesión, selección de rol
│   └── client/      Páginas del cliente
├── routes/          Enrutador de la app
├── styles/          Estilos globales, variables de diseño, CSS por componente y por página
├── types/           Tipos de TypeScript compartidos (usuario, catálogo, navegación…)
└── utils/           Utilidades (formato, íconos de categorías, configuración de navegación)
```

## Convenciones

- Cada componente o página importa su propia hoja de estilos desde `src/styles/components/` o `src/styles/pages/`. Los colores, espaciados y demás variables viven en `variables.css`.
- Los nombres de los campos siguen la nomenclatura en español del backend (`nombre`, `descripcion`, `activa`, `mano_obra_max`…), para que los tipos de `src/types/` correspondan directamente con las respuestas de la API.
- Los datos de prueba están en `src/mocks/`. Cuando el backend esté listo, hay que reemplazar esas importaciones por llamadas a servicios. Los puntos que aún falta conectar están marcados con comentarios: el envío del login en `Login.tsx` y el envío de la solicitud en `RequestModal.tsx`.

## Pendientes

- [x] Configurar el cliente de Supabase y las variables de entorno
- [ ] Conectar las pantallas con Supabase (autenticación, categorías, solicitudes)
- [ ] Manejo real de sesión y protección de rutas por rol
- [ ] Páginas del cliente: mis pedidos, perfil
- [ ] Panel del técnico
- [ ] Panel de administración (usuarios, técnicos, facturas, reportes)
- [ ] Recuperación de contraseña (`/recuperar`)
