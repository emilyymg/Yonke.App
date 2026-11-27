# YonkeApp
# YonkeApp – Auto Partes Red

Plataforma que conecta los inventarios de yonkes con talleres mecánicos y clientes, para buscar, consultar y localizar autopartes usadas.

Proyecto integrador de **Gestión de Proyectos de Software** · Instituto Tecnológico de Tijuana · Periodo agosto–diciembre 2026 · Docente: Mtra. María Guadalupe Rodríguez López.

## Integrantes

| Integrante | Matrícula | Rol |
|---|---|---|
| Camacho Otañez Juan Pablo | 23211928 | Líder de proyecto, backend y base de datos |
| Hernandez Cuadras Ana Cecilia | 23211985 | Frontend y diseño UI/UX |
| Mijangos Garibay Emily | 23212020 | Calidad de software y arquitectura de datos |

## Estructura del repositorio

```
YonkeApp
├── YonkeMain              Página web pública (clientes y talleres)
├── Yonke_App              Aplicación móvil del yonke (iOS)
├── Yonke_Back             Backend (API REST)
├── YonqueBaseDeDatos      Base de datos (scripts)
└── README.md
```

| Componente | Para qué sirve |
|---|---|
| **Página web** | Los clientes ven publicaciones, buscan por texto, categoría y precio, y consultan el detalle de cada pieza. No requiere cuenta. |
| **App móvil** | El personal autorizado del yonke inicia sesión, registra vehículos, verifica piezas, agrega fotos, administra inventario, publicaciones y ventas. |
| **Backend** | API REST que usan la web y la app; maneja usuarios, vehículos, piezas, publicaciones, ventas y fotos. |
| **Base de datos** | PostgreSQL con las tablas del sistema. |

## Tecnologías y lenguajes

| Capa | Tecnologías | Lenguajes |
|---|---|---|
| Web | Next.js, React, Tailwind CSS, lucide-react | TypeScript, JavaScript |
| App móvil | Xcode, app para iOS (Swift) | 
| Backend | Node.js, Express 4, `pg`, `bcrypt`, `jsonwebtoken`, `cors`, `dotenv`, AWS SDK (S3 y presigner), nodemon | JavaScript |
| Base de datos | PostgreSQL (local o AWS RDS) | SQL |
| Almacenamiento de fotos | AWS S3 | — |
| Control de versiones | Git y GitHub | — |

## Requisitos

- Node.js [18 o superior, confirmar] y npm
- PostgreSQL [versión]
- Xcode [versión] y un simulador o iPhone, para la app
- Cuenta de AWS con un bucket de S3, si se usan las fotos

## Instalación y ejecución

Sigan este orden: base de datos, backend, web y app.

### 1. Base de datos (`YonqueBaseDeDatos`)

1. Cree una base de datos vacía, por ejemplo `yonke`.
2. Ejecute el script de creación incluido en la carpeta: `[nombre_del_script.sql]`.
3. [Si hay datos de prueba, ejecute `[nombre_del_archivo.sql]`.]

### 2. Backend (`Yonke_Back`)

```bash
cd Yonke_Back
npm install
```

Cree un archivo `.env` en la carpeta (no lo suba a GitHub; ya está en `.gitignore`):

```env
PORT=3001

DB_HOST=localhost
DB_PORT=5432
DB_USER=[usuario]
DB_PASSWORD=[contraseña]
DB_NAME=[nombre_de_la_base]
DB_SSL=false

AWS_ACCESS_KEY_ID=[clave]
AWS_SECRET_ACCESS_KEY=[clave]
AWS_SESSION_TOKEN=[token, si las credenciales son temporales]
AWS_REGION=[región]
S3_BUCKET_NAME=[bucket]

JWT_SECRET=[cadena larga y secreta]
```

Notas:

- `PORT=3001` evita chocar con la web, que corre en el puerto 3000. Si no se define `PORT`, el backend usa 3000.
- `DB_SSL=true` solo se usa con AWS RDS; con una base local va en `false`.
- Si usan credenciales temporales de AWS (con `AWS_SESSION_TOKEN`), caducan y hay que renovarlas.

Inicie el servidor:

```bash
npm start        # producción
npm run dev      # desarrollo, con reinicio automático (nodemon)
```

Prueba rápida: abra `http://127.0.0.1:3001/` y debe responder "API del Yonke funcionando correctamente...".

El servidor escucha solo en `127.0.0.1`, por lo que únicamente se puede acceder desde la misma computadora.

### 3. Página web (`YonkeMain`)

```bash
cd YonkeMain
npm install
npm run dev
```

Abra `http://127.0.0.1:3000`. La web consume la API en `[http://127.0.0.1:3001]`; si cambia el puerto o la dirección, actualice `[archivo o variable donde está la URL, por ejemplo .env.local]`.

### 4. App móvil (`Yonke_App`)

1. Abra el proyecto en Xcode: `[Yonke_App.xcodeproj]`.
2. Verifique que la app apunte al backend: `[archivo y variable con la URL]`.
3. Elija un simulador o un iPhone y pulse Run.

Notas:

- El archivo `Info.plist` activa `NSAllowsLocalNetworking` para permitir HTTP hacia el backend local durante el desarrollo.
- En el simulador, el backend en `127.0.0.1` funciona directamente. Para probar en un **iPhone físico**, el teléfono y la computadora deben estar en la misma red, y el backend debe escuchar en una dirección accesible (hoy solo escucha en `127.0.0.1`) [confirmar cómo lo resolvieron].
- La app pide permiso de cámara y de acceso a fotos al agregar imágenes a una pieza.

## Endpoints principales del API

| Ruta base | Uso |
|---|---|
| `/api/users` | Registro, inicio de sesión y usuarios |
| `/api/yonques` | Datos de los yonkes |
| `/api/vehiculos` | Registro y consulta de vehículos |
| `/api/piezas` | Piezas del inventario |
| `/api/borradores` | Borradores de publicación |
| `/api/publicaciones` | Publicaciones visibles en la web |
| `/api/ventas` | Registro de ventas |
| `/api/fotos` | Fotos de piezas (AWS S3) |
| `/api/catalogos` | Catálogos de piezas |
| `/api/autos` | Marcas, modelos y años |
| `/api/categories` | Categorías de autopartes |
| `/api/locations` | Ubicaciones |

## Credenciales de prueba

| Perfil | Dónde se usa | Correo o usuario | Contraseña |
|---|---|---|---|
| Yonke (Refacciones Lozano) | App móvil | `pedro.lozano@example.com` | `[contraseña de prueba]` |
| Cliente | Web | No requiere cuenta | — |
| Administrador | [confirmar] | `[usuario]` | `[contraseña]` |

## Alcance de esta versión

Incluye: sitio web público con publicaciones, búsqueda y detalle; app del yonke con registro de vehículos, verificación de piezas, fotos, inventario y publicaciones; backend y base de datos.

No incluye (Fase 2): pasarela de pagos, fletes y seguimiento de envíos, y carga automática por VIN y geolocalización.

## Documentación del proyecto

Planeación, calidad, seguimiento, bitácora de pruebas, bitácora individual y manual de usuario están en la carpeta de entrega `PROYECTO_FINAL_YONKEAPP`.

## Seguridad

- No suba nunca el archivo `.env` ni credenciales de AWS al repositorio.
- El archivo `.gitignore` excluye `node_modules/`, `.env` y `.DS_Store`.
- Las contraseñas se almacenan cifradas con `bcrypt` y las sesiones usan tokens JWT.
