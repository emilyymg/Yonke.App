-- ============================================================
-- EXTENSIONES REQUERIDAS
-- ============================================================
-- Esquema consolidado con los cambios estructurales de Migracion_001.
-- Orden sugerido: Estructura.sql, StoreProcedures.sql, Triggers.sql,
-- Datos.sql (si aplica), Vistas.sql y JOBS.sql (si aplica).
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. CONFIGURACIÓN Y CATÁLOGOS
-- ============================================================

CREATE TABLE configuracion_sistema (
    clave VARCHAR(100) PRIMARY KEY,
    valor JSONB NOT NULL,
    descripcion TEXT,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Catálogo de marcas de vehículos
CREATE TABLE marcas_vehiculo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    pais_origen VARCHAR(100),
    activo BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Catálogo de modelos por marca
CREATE TABLE modelos_vehiculo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    marca_id UUID NOT NULL REFERENCES marcas_vehiculo(id),
    nombre VARCHAR(100) NOT NULL,
    anio_inicio INT,
    anio_fin INT,
    tipo_vehiculo VARCHAR(50), -- sedan, suv, pickup, etc.
    metadata JSONB DEFAULT '{}',
    UNIQUE(marca_id, nombre),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. UBICACIONES (Para yonques y usuarios)
-- ============================================================

CREATE TABLE ubicaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    calle VARCHAR(150) NOT NULL,
    numero VARCHAR(20),
    colonia VARCHAR(150),
    codigo_postal VARCHAR(10),
    ciudad VARCHAR(100) NOT NULL,
    estado VARCHAR(100) NOT NULL,
    pais VARCHAR(100) DEFAULT 'México',
    latitud DECIMAL(10, 8),
    longitud DECIMAL(11, 8),
    referencia TEXT,
    -- Campo geoespacial para búsquedas por proximidad (PostGIS opcional)
    coordenadas POINT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ubicaciones_ciudad_estado ON ubicaciones(ciudad, estado);
CREATE INDEX idx_ubicaciones_cp ON ubicaciones(codigo_postal);

-- ============================================================
-- 3. USUARIOS Y ROLES (Control de Acceso - Requerimiento 4)
-- ============================================================

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE, -- administrador, vendedor, almacen, consulta
    permisos JSONB NOT NULL DEFAULT '{}',
    descripcion TEXT,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    contrasena_hash TEXT NOT NULL,
    telefono VARCHAR(20),
    foto_perfil_url TEXT, -- URL de S3
    rol_id INT NOT NULL REFERENCES roles(id),
    ubicacion_id UUID REFERENCES ubicaciones(id),
    
    -- Datos del negocio (para dueños de yonque)
    es_yonquero BOOLEAN DEFAULT FALSE,
    nombre_negocio VARCHAR(200),
    rfc VARCHAR(13),
    certificacion_yonque VARCHAR(100),
    
    estado VARCHAR(20) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'suspendido', 'pendiente')),
    ultimo_acceso TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_usuarios_rol ON usuarios(rol_id);
CREATE INDEX idx_usuarios_estado ON usuarios(estado);
-- Un correo no puede duplicarse aunque cambien mayúsculas/minúsculas.
CREATE UNIQUE INDEX ux_usuarios_email ON usuarios (lower(email));

-- ============================================================
-- 4. YONQUES (Registro de yonques - Requerimiento Funcional)
-- ============================================================

CREATE TABLE yonques (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(10) UNIQUE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id), -- Dueño
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    ubicacion_id UUID NOT NULL REFERENCES ubicaciones(id),
    
    -- Información fiscal y legal
    rfc VARCHAR(13),
    regimen_fiscal VARCHAR(100),
    licencia_operacion VARCHAR(100),
    
    -- Configuración del yonque
    capacidad_vehiculos INT,
    horario_atencion JSONB, -- {"lunes": "9:00-18:00", ...}
    metodos_pago JSONB, -- ["efectivo", "transferencia", "tarjeta"]
    
    -- Estado y validación
    estado VARCHAR(20) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'pendiente', 'suspendido')),
    verificado BOOLEAN DEFAULT FALSE,
    
    -- Métricas
    total_vehiculos_registrados INT DEFAULT 0,
    total_piezas_disponibles INT DEFAULT 0,
    
    metadata JSONB DEFAULT '{}',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_yonques_usuario ON yonques(usuario_id);
CREATE INDEX idx_yonques_estado ON yonques(estado);
CREATE INDEX idx_yonques_ubicacion ON yonques(ubicacion_id);

-- Usuarios que pertenecen a cada yonque y su rol dentro del negocio
CREATE TABLE miembros_yonque (
    yonque_id UUID NOT NULL REFERENCES yonques(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    rol_id INT NOT NULL REFERENCES roles(id),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_alta TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (yonque_id, usuario_id)
);

CREATE INDEX idx_miembros_usuario ON miembros_yonque(usuario_id);

-- ============================================================
-- 5. VEHÍCULOS (Autos en el yonque)
-- ============================================================

CREATE TABLE vehiculos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    yonque_id UUID NOT NULL REFERENCES yonques(id),
    -- El trigger trg_numero_unidad asigna el consecutivo antes de insertar.
    numero_unidad INT NOT NULL,
    usuario_registro_id UUID NOT NULL REFERENCES usuarios(id),
    
    -- Información básica (puede venir incompleta)
    marca_id UUID REFERENCES marcas_vehiculo(id),
    modelo_id UUID REFERENCES modelos_vehiculo(id),
    marca_texto VARCHAR(100), -- Fallback si no está en catálogo
    modelo_texto VARCHAR(100),
    anio INT,
    version VARCHAR(100),
    vin VARCHAR(17),
    numero_serie VARCHAR(50),
    
    -- Estado del vehículo en el yonque
    estado VARCHAR(50) DEFAULT 'ingresado' 
        CHECK (estado IN ('ingresado', 'en_revision', 'aprobado', 'en_desarme', 'desmantelado', 'descartado')),
    
    -- Datos semiestructurados para flexibilidad
    caracteristicas JSONB DEFAULT '{}', -- {"color": "rojo", "transmision": "automatica", "combustible": "gasolina"}
    condicion JSONB DEFAULT '{}', -- {"motor": "funcional", "carroceria": "danada", "interior": "bueno"}
    
    -- Documentación
    factura_origen BOOLEAN DEFAULT FALSE,
    tenencias_al_corriente BOOLEAN DEFAULT FALSE,
    verificacion_al_corriente BOOLEAN DEFAULT FALSE,
    
    -- Fechas importantes
    fecha_ingreso_yonque DATE DEFAULT CURRENT_DATE,
    fecha_desarme DATE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Control
    activo BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_vehiculos_yonque ON vehiculos(yonque_id);
CREATE INDEX idx_vehiculos_estado ON vehiculos(estado);
CREATE INDEX idx_vehiculos_marca ON vehiculos(marca_texto);
CREATE INDEX idx_vehiculos_anio ON vehiculos(anio);
CREATE INDEX idx_vehiculos_caracteristicas ON vehiculos USING GIN (caracteristicas);
CREATE INDEX idx_vehiculos_modelo ON vehiculos(modelo_id);
CREATE UNIQUE INDEX ux_unidad_por_yonque ON vehiculos(yonque_id, numero_unidad);
CREATE UNIQUE INDEX ux_vehiculo_vin ON vehiculos(vin)
    WHERE vin IS NOT NULL AND activo;

-- ============================================================
-- 6. CATÁLOGO DE PIEZAS (Template/Genérico)
-- ============================================================

CREATE TABLE categorias_piezas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL,
    categoria_padre_id UUID REFERENCES categorias_piezas(id),
    descripcion TEXT,
    
    -- Atributos esperados para esta categoría (schema flexible)
    atributos_esperados JSONB DEFAULT '[]', -- [{"nombre": "material", "tipo": "texto", "obligatorio": false}, ...]
    
    -- Piezas típicas que se generan automáticamente
    piezas_tipicas JSONB DEFAULT '[]', -- ["puerta_delantera_izq", "espejo_retrovisor", ...]
    
    nivel INT DEFAULT 1,
    activo BOOLEAN DEFAULT TRUE,
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categorias_padre ON categorias_piezas(categoria_padre_id);

-- Catálogo maestro de piezas genéricas
CREATE TABLE piezas_catalogo (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    categoria_id UUID REFERENCES categorias_piezas(id),
    nombre VARCHAR(150) NOT NULL,
    abreviatura VARCHAR(4),
    descripcion TEXT,
    
    -- Compatibilidad común
    compatibilidad_generica JSONB DEFAULT '{}', -- {"marcas": ["toyota", "honda"], "años": [2010, 2015]}
    
    -- Atributos por defecto
    atributos_default JSONB DEFAULT '{}',
    
    -- Configuración de generación automática
    generar_automaticamente BOOLEAN DEFAULT TRUE,
    prioridad INT DEFAULT 100, -- Orden de generación
    
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_piezas_catalogo_categoria ON piezas_catalogo(categoria_id);
CREATE INDEX idx_piezas_catalogo_compatibilidad ON piezas_catalogo USING GIN (compatibilidad_generica);

-- Plantillas por capas para generar piezas según las características del vehículo
CREATE TABLE plantillas_pieza (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    aplica_a JSONB NOT NULL DEFAULT '{}',
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE plantilla_items (
    plantilla_id UUID NOT NULL REFERENCES plantillas_pieza(id) ON DELETE CASCADE,
    catalogo_pieza_id UUID NOT NULL REFERENCES piezas_catalogo(id),
    cantidad SMALLINT NOT NULL DEFAULT 1 CHECK (cantidad > 0),
    PRIMARY KEY (plantilla_id, catalogo_pieza_id)
);

CREATE INDEX idx_plantilla_items_catalogo ON plantilla_items(catalogo_pieza_id);

-- ============================================================
-- 7. INVENTARIO DE PIEZAS (Piezas reales del yonque)
-- ============================================================

CREATE TABLE piezas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehiculo_id UUID NOT NULL REFERENCES vehiculos(id),
    catalogo_pieza_id UUID REFERENCES piezas_catalogo(id),
    
    -- Identificación
    codigo_sku VARCHAR(50) UNIQUE, -- Generado automático: YNQ-XXXX-XXXX
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    
    -- Categorización
    categoria_id UUID REFERENCES categorias_piezas(id),
    
    -- Estado físico
    condicion VARCHAR(50) CHECK (condicion IN ('nuevo', 'seminuevo', 'usado', 'refaccionado', 'danado', 'para_reparar')),
    estado_inventario VARCHAR(50) NOT NULL DEFAULT 'por_confirmar'
        CHECK (estado_inventario IN ('por_confirmar', 'disponible', 'reservado', 'vendido', 'descartado', 'en_revision')),
    -- Distingue piezas generadas por plantilla de las capturadas manualmente.
    origen VARCHAR(20) NOT NULL DEFAULT 'manual'
        CHECK (origen IN ('plantilla', 'manual')),
    
    -- Ubicación física en el yonque
    ubicacion_almacen JSONB DEFAULT '{}', -- {"zona": "A", "anaquel": "3", "nivel": "2"}
    
    -- Atributos variables (JSONB para flexibilidad)
    atributos JSONB DEFAULT '{}', -- {"color": "rojo", "material": "plastico", "lado": "izquierdo"}
    
    -- Precios
    precio_venta DECIMAL(12,2),
    precio_minimo DECIMAL(12,2),
    moneda VARCHAR(3) DEFAULT 'MXN',
    
    -- Control de calidad
    inspeccionado BOOLEAN DEFAULT FALSE,
    notas_inspeccion TEXT,
    
    -- Metadatos
    metadata JSONB DEFAULT '{}',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_piezas_precios
        CHECK (precio_venta >= 0 AND precio_minimo >= 0 AND precio_minimo <= precio_venta)
);

CREATE INDEX idx_piezas_vehiculo ON piezas(vehiculo_id);
CREATE INDEX idx_piezas_estado ON piezas(estado_inventario);
CREATE INDEX idx_piezas_condicion ON piezas(condicion);
CREATE INDEX idx_piezas_categoria ON piezas(categoria_id);
CREATE INDEX idx_piezas_catalogo ON piezas(catalogo_pieza_id);
CREATE INDEX idx_piezas_atributos ON piezas USING GIN (atributos);
CREATE INDEX idx_piezas_disponibles ON piezas(vehiculo_id)
    WHERE estado_inventario = 'disponible';

-- Transiciones permitidas para el estado del inventario de una pieza
CREATE TABLE transiciones_pieza (
    desde VARCHAR(50) NOT NULL,
    hacia VARCHAR(50) NOT NULL,
    PRIMARY KEY (desde, hacia)
);

INSERT INTO transiciones_pieza (desde, hacia) VALUES
    ('por_confirmar', 'disponible'), ('por_confirmar', 'descartado'),
    ('disponible', 'reservado'), ('disponible', 'vendido'),
    ('disponible', 'en_revision'), ('disponible', 'descartado'),
    ('reservado', 'disponible'), ('reservado', 'vendido'),
    ('en_revision', 'disponible'), ('en_revision', 'descartado'),
    ('vendido', 'disponible');

-- Las fotos se almacenan como registros independientes; s3_key contiene la key,
-- no la URL pública del objeto.
CREATE TABLE fotos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pieza_id UUID NOT NULL REFERENCES piezas(id),
    s3_key TEXT NOT NULL UNIQUE,
    ancho INT,
    alto INT,
    bytes BIGINT,
    sha256 CHAR(64),
    orden SMALLINT NOT NULL DEFAULT 0,
    es_principal BOOLEAN NOT NULL DEFAULT FALSE,
    publicable BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fotos_pieza ON fotos(pieza_id, orden);
CREATE UNIQUE INDEX ux_foto_principal ON fotos(pieza_id) WHERE es_principal;

-- ============================================================
-- 8. BORRADORES DE PUBLICACIÓN (Flujo de publicación)
-- ============================================================

CREATE TABLE borradores_publicacion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pieza_id UUID NOT NULL REFERENCES piezas(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id), -- Quién creó el borrador
    
    -- Información editable antes de publicar
    titulo VARCHAR(200),
    descripcion_marketplace TEXT,
    precio_publico DECIMAL(12,2),
    condicion_publicada VARCHAR(50),
    
    -- Fotos específicas para marketplace (pueden ser diferentes a las del inventario)
    fotos_marketplace JSONB DEFAULT '[]',
    
    -- Estado del borrador
    estado VARCHAR(30) DEFAULT 'pendiente' 
        CHECK (estado IN ('pendiente', 'en_edicion', 'listo_para_publicar', 'publicado', 'descartado')),
    
    -- Motivo si se descarta
    motivo_descarte TEXT,
    
    -- Validaciones
    validaciones_pasadas JSONB DEFAULT '[]', -- ["fotos", "descripcion", "precio"]
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_edicion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_publicacion TIMESTAMP
);

CREATE INDEX idx_borradores_pieza ON borradores_publicacion(pieza_id);
CREATE INDEX idx_borradores_estado ON borradores_publicacion(estado);
CREATE INDEX idx_borradores_usuario ON borradores_publicacion(usuario_id);
CREATE UNIQUE INDEX ux_borrador_abierto_por_pieza ON borradores_publicacion(pieza_id)
    WHERE estado IN ('pendiente', 'en_edicion', 'listo_para_publicar');

-- ============================================================
-- 9. PUBLICACIONES (Marketplace activo)
-- ============================================================

CREATE TABLE publicaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borrador_id UUID NOT NULL REFERENCES borradores_publicacion(id),
    pieza_id UUID NOT NULL REFERENCES piezas(id),
    yonque_id UUID NOT NULL REFERENCES yonques(id),
    usuario_publicacion_id UUID NOT NULL REFERENCES usuarios(id),
    
    -- Datos publicados (snapshot del borrador aprobado)
    titulo VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL,
    condicion VARCHAR(50),
    
    -- Visibilidad
    estado VARCHAR(30) DEFAULT 'activa' 
        CHECK (estado IN ('activa', 'pausada', 'vendida', 'eliminada', 'expirada')),
    
    -- Métricas de marketplace
    vistas INT DEFAULT 0,
    contactos INT DEFAULT 0,
    favoritos_count INT DEFAULT 0,
    
    -- SEO y búsqueda
    tags JSONB DEFAULT '[]',
    palabras_clave TSVECTOR GENERATED ALWAYS AS (
        setweight(to_tsvector('spanish', coalesce(titulo, '')), 'A') ||
        setweight(to_tsvector('spanish', coalesce(descripcion, '')), 'B')
    ) STORED,
    
    -- Geolocalización para búsqueda cercana
    ubicacion_id UUID REFERENCES ubicaciones(id),
    
    fecha_publicacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP,
    fecha_ultima_renovacion TIMESTAMP,
    fecha_eliminacion TIMESTAMP
);

CREATE INDEX idx_publicaciones_estado ON publicaciones(estado);
CREATE INDEX idx_publicaciones_yonque ON publicaciones(yonque_id);
CREATE INDEX idx_publicaciones_pieza ON publicaciones(pieza_id);
CREATE INDEX idx_publicaciones_precio ON publicaciones(precio);
CREATE INDEX idx_publicaciones_palabras_clave ON publicaciones USING GIN (palabras_clave);
CREATE INDEX idx_publicaciones_fecha ON publicaciones(fecha_publicacion);
CREATE INDEX idx_publicaciones_borrador ON publicaciones(borrador_id);
CREATE UNIQUE INDEX ux_publicacion_vigente_por_pieza ON publicaciones(pieza_id)
    WHERE estado IN ('activa', 'pausada');

-- ============================================================
-- 10. VENTAS (Punto de venta - Requerimiento Funcional)
-- ============================================================

CREATE TABLE ventas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    publicacion_id UUID REFERENCES publicaciones(id), -- Puede ser NULL si venta directa
    pieza_id UUID NOT NULL REFERENCES piezas(id),
    yonque_id UUID NOT NULL REFERENCES yonques(id),
    
    -- Quién vende y quién compra
    vendedor_id UUID NOT NULL REFERENCES usuarios(id),
    comprador_id UUID REFERENCES usuarios(id), -- NULL si es venta anónima
    
    -- Información del comprador (para facturación)
    comprador_nombre VARCHAR(200),
    comprador_email VARCHAR(150),
    comprador_telefono VARCHAR(20),
    comprador_rfc VARCHAR(13),
    
    -- Detalle de venta
    precio_lista DECIMAL(12,2),
    descuento DECIMAL(12,2) DEFAULT 0,
    precio_final DECIMAL(12,2) NOT NULL,
    impuestos DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL,
    
    -- Método de pago
    metodo_pago VARCHAR(50) CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'deposito', 'credito', 'otro')),
    referencia_pago VARCHAR(100),
    
    -- Estado
    estado VARCHAR(30) DEFAULT 'completada' 
        CHECK (estado IN ('pendiente', 'completada', 'cancelada', 'devuelta', 'garantia')),
    
    -- Facturación
    requiere_factura BOOLEAN DEFAULT FALSE,
    factura_emitida BOOLEAN DEFAULT FALSE,
    datos_facturacion JSONB DEFAULT '{}',
    
    notas TEXT,
    metadata JSONB DEFAULT '{}',
    
    fecha_venta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega TIMESTAMP,
    fecha_cancelacion TIMESTAMP,
    CONSTRAINT ck_ventas_montos
        CHECK (precio_final >= 0 AND descuento >= 0 AND total >= 0)
);

CREATE INDEX idx_ventas_yonque ON ventas(yonque_id);
CREATE INDEX idx_ventas_pieza ON ventas(pieza_id);
CREATE INDEX idx_ventas_estado ON ventas(estado);
CREATE INDEX idx_ventas_fecha ON ventas(fecha_venta);
CREATE INDEX idx_ventas_vendedor ON ventas(vendedor_id);
CREATE INDEX idx_ventas_publicacion ON ventas(publicacion_id);
CREATE INDEX idx_ventas_comprador ON ventas(comprador_id);
CREATE UNIQUE INDEX ux_venta_vigente_por_pieza ON ventas(pieza_id)
    WHERE estado IN ('pendiente', 'completada', 'garantia');

-- ============================================================
-- 11. HISTORIAL DE MOVIMIENTOS (Auditoría)
-- ============================================================

CREATE TABLE historial_movimientos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Entidad afectada
    tabla_afectada VARCHAR(50) NOT NULL,
    registro_id UUID NOT NULL,
    tipo_movimiento VARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE, VENTA, PUBLICACION, etc.
    
    -- Datos
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    
    -- Quién y cuándo
    usuario_id UUID REFERENCES usuarios(id),
    ip_address INET,
    user_agent TEXT,
    
    -- Contexto
    descripcion TEXT,
    metadata JSONB DEFAULT '{}',
    
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_historial_tabla ON historial_movimientos(tabla_afectada, registro_id);
CREATE INDEX idx_historial_fecha ON historial_movimientos(fecha);
CREATE INDEX idx_historial_usuario ON historial_movimientos(usuario_id);
CREATE INDEX idx_historial_tipo ON historial_movimientos(tipo_movimiento);

-- ============================================================
-- 12. CONVERSACIONES Y MENSAJES (Mantenido del original)
-- ============================================================

CREATE TABLE conversaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    publicacion_id UUID REFERENCES publicaciones(id),
    asunto VARCHAR(200),
    estado VARCHAR(20) DEFAULT 'activa',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE participantes_conversacion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversacion_id UUID NOT NULL REFERENCES conversaciones(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol VARCHAR(20) DEFAULT 'participante', -- comprador, vendedor, admin
    fecha_union TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(conversacion_id, usuario_id)
);

CREATE TABLE mensajes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversacion_id UUID NOT NULL REFERENCES conversaciones(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    contenido TEXT NOT NULL,
    tipo VARCHAR(20) DEFAULT 'texto', -- texto, imagen, oferta, sistema
    metadata JSONB DEFAULT '{}', -- Para ofertas: {"tipo": "oferta", "monto": 1500, "estado": "pendiente"}
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    leido BOOLEAN DEFAULT FALSE,
    fecha_lectura TIMESTAMP
);

CREATE INDEX idx_conversaciones_publicacion ON conversaciones(publicacion_id);
CREATE INDEX idx_mensajes_conversacion ON mensajes(conversacion_id);
CREATE INDEX idx_mensajes_usuario ON mensajes(usuario_id);
CREATE INDEX idx_participantes_usuario ON participantes_conversacion(usuario_id);

-- ============================================================
-- 13. FAVORITOS Y CALIFICACIONES
-- ============================================================

CREATE TABLE favoritos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    publicacion_id UUID NOT NULL REFERENCES publicaciones(id) ON DELETE CASCADE,
    fecha_agregado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(usuario_id, publicacion_id)
);

CREATE TABLE calificaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id), -- Calificado
    autor_id UUID NOT NULL REFERENCES usuarios(id), -- Quién califica
    tipo VARCHAR(20) DEFAULT 'vendedor', -- vendedor, comprador, pieza
    
    puntuacion INT CHECK (puntuacion BETWEEN 1 AND 5),
    comentario TEXT,
    
    -- Referencia a la transacción
    venta_id UUID REFERENCES ventas(id),
    
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_favoritos_usuario ON favoritos(usuario_id);
CREATE INDEX idx_favoritos_publicacion ON favoritos(publicacion_id);
CREATE INDEX idx_calificaciones_usuario ON calificaciones(usuario_id);
CREATE INDEX idx_calificaciones_venta ON calificaciones(venta_id);

-- ============================================================
-- 14. NOTIFICACIONES
-- ============================================================

CREATE TABLE notificaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL, -- venta, mensaje, sistema, alerta_inventario
    titulo VARCHAR(200),
    contenido TEXT,
    
    -- Acción clickable
    accion_url TEXT,
    metadata JSONB DEFAULT '{}',
    
    leida BOOLEAN DEFAULT FALSE,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_lectura TIMESTAMP
);

CREATE INDEX idx_notificaciones_usuario ON notificaciones(usuario_id, leida);
CREATE INDEX idx_notificaciones_tipo ON notificaciones(tipo);

-- ============================================================
-- 15. REPORTES Y CONFIGURACIÓN DE JOBS
-- ============================================================

CREATE TABLE jobs_programados (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(50), -- reporte, monitoreo, limpieza
    frecuencia VARCHAR(50), -- diario, semanal, mensual
    hora_ejecucion TIME,
    dia_semana INT, -- 0-6 para semanales
    dia_mes INT, -- 1-31 para mensuales
    
    -- Configuración
    parametros JSONB DEFAULT '{}',
    ultima_ejecucion TIMESTAMP,
    proxima_ejecucion TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'activo',
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reportes_generados (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES jobs_programados(id),
    tipo_reporte VARCHAR(100),
    parametros JSONB,
    resultado JSONB, -- Datos del reporte
    archivo_url TEXT, -- S3 si es descargable
    estado VARCHAR(20) DEFAULT 'generado',
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
