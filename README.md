# ServiceHome — Frontend

Cliente web de **ServiceHome**, una plataforma que conecta a clientes con técnicos para servicios del hogar (electricidad, plomería, etc.). Los clientes exploran categorías de servicio y solicitan una visita; los técnicos reciben y gestionan esas solicitudes; los administradores supervisan usuarios, técnicos, facturas y reportes.

Este repositorio contiene solo el frontend. Por ahora funciona con **datos de prueba (mocks)**: todavía no hay conexión con un backend.

## Tecnologías

- [React 19](https://react.dev) + [TypeScript](https://www.typescriptlang.org)
- [Vite](https://vite.dev) como servidor de desarrollo y para compilar
- [React Router 7](https://reactrouter.com) para el enrutamiento
- Componentes de [Ant Design 6](https://ant.design) e íconos de `@ant-design/icons` (además de `lucide-react`)
- CSS plano con variables de diseño compartidas en `src/styles/variables.css`
- ESLint (configuración flat) con `typescript-eslint` y reglas de React Hooks
- [pnpm](https://pnpm.io) como gestor de paquetes (`pnpm-lock.yaml`)

## Primeros pasos

Requisitos: Node.js 20+ y pnpm.

```bash
pnpm install
pnpm dev
```

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

- [ ] Conectar con la API del backend (autenticación, categorías, solicitudes)
- [ ] Manejo real de sesión y protección de rutas por rol
- [ ] Páginas del cliente: mis pedidos, perfil
- [ ] Panel del técnico
- [ ] Panel de administración (usuarios, técnicos, facturas, reportes)
- [ ] Recuperación de contraseña (`/recuperar`)
