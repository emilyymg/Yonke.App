-- ============================================================
-- DATOS: Catálogo base de piezas y plantillas por tipo de vehículo
-- ============================================================
-- Requiere: Estructura.sql, StoreProcedures.sql (generar_piezas_vehiculo)
--           y Datos_Tipo_Vehiculos.sql (tipo_vehiculo de los modelos).
-- Idempotente: se puede ejecutar varias veces sin duplicar registros.
--
-- Plantillas:
--   Base        (aplica a todos los vehículos)
--   Sedán, Hatchback, SUV, Pickup, Van (aplican según tipo_vehiculo)
-- Si una pieza aparece en varias plantillas compatibles, se genera una sola vez.
-- Cada fila de plantilla_items genera 1 pieza (cantidad = 1).

-- ------------------------------------------------------------
-- 1. Categorías
-- ------------------------------------------------------------
INSERT INTO categorias_piezas (nombre, descripcion, nivel, activo)
SELECT v.nombre, NULL, 1, TRUE
  FROM (VALUES
    ('Motor'),
    ('Transmisión'),
    ('Suspensión y dirección'),
    ('Frenos'),
    ('Carrocería'),
    ('Iluminación'),
    ('Interior'),
    ('Eléctrico y clima')
  ) AS v(nombre)
 WHERE NOT EXISTS (
    SELECT 1 FROM categorias_piezas c WHERE c.nombre = v.nombre
 );

-- ------------------------------------------------------------
-- 2. Piezas del catálogo (abreviatura = 4 letras para el SKU)
-- ------------------------------------------------------------
INSERT INTO piezas_catalogo (categoria_id, nombre, abreviatura)
SELECT c.id, v.nombre, v.abreviatura
  FROM (VALUES
    -- Motor
    ('Motor', 'Motor completo', 'MOTC'),
    ('Motor', 'Cabeza de motor', 'CABE'),
    ('Motor', 'Múltiple de admisión', 'MADM'),
    ('Motor', 'Radiador', 'RADI'),
    ('Motor', 'Bomba de agua', 'BAGU'),
    ('Motor', 'Alternador', 'ALTE'),
    ('Motor', 'Marcha', 'MARR'),
    -- Transmisión
    ('Transmisión', 'Transmisión automática', 'TRAU'),
    ('Transmisión', 'Transmisión manual', 'TRAM'),
    ('Transmisión', 'Diferencial', 'DIFE'),
    ('Transmisión', 'Flecha cardán', 'CARD'),
    -- Suspensión y dirección
    ('Suspensión y dirección', 'Amortiguador delantero', 'AMDE'),
    ('Suspensión y dirección', 'Amortiguador trasero', 'AMTR'),
    ('Suspensión y dirección', 'Caja de dirección', 'CDIR'),
    ('Suspensión y dirección', 'Maza delantera', 'MAZA'),
    -- Frenos
    ('Frenos', 'Disco delantero', 'DISD'),
    ('Frenos', 'Disco trasero', 'DIST'),
    ('Frenos', 'Caliper delantero', 'CALD'),
    -- Carrocería
    ('Carrocería', 'Puerta delantera izquierda', 'PDIZ'),
    ('Carrocería', 'Puerta delantera derecha', 'PDDE'),
    ('Carrocería', 'Puerta trasera izquierda', 'PTIZ'),
    ('Carrocería', 'Puerta trasera derecha', 'PTDE'),
    ('Carrocería', 'Cofre', 'COFR'),
    ('Carrocería', 'Portón trasero', 'PORT'),
    ('Carrocería', 'Defensa delantera', 'DEFD'),
    ('Carrocería', 'Defensa trasera', 'DEFT'),
    ('Carrocería', 'Espejo izquierdo', 'ESIZ'),
    ('Carrocería', 'Espejo derecho', 'ESDE'),
    ('Carrocería', 'Tapa de cajuela', 'TAPC'),
    ('Carrocería', 'Caja de carga', 'CAJC'),
    ('Carrocería', 'Puerta corrediza', 'PUCO'),
    -- Iluminación
    ('Iluminación', 'Faro delantero izquierdo', 'FADI'),
    ('Iluminación', 'Faro delantero derecho', 'FADD'),
    ('Iluminación', 'Faro trasero izquierdo', 'FATI'),
    ('Iluminación', 'Faro trasero derecho', 'FATD'),
    -- Interior
    ('Interior', 'Asiento delantero', 'ASDE'),
    ('Interior', 'Tablero', 'TABL'),
    ('Interior', 'Volante', 'VOLA'),
    ('Interior', 'Consola central', 'CONS'),
    -- Eléctrico y clima
    ('Eléctrico y clima', 'Módulo de control', 'MODU'),
    ('Eléctrico y clima', 'Batería', 'BATE'),
    ('Eléctrico y clima', 'Compresor de A/C', 'COMP'),
    ('Eléctrico y clima', 'Condensador', 'COND')
  ) AS v(categoria, nombre, abreviatura)
  JOIN categorias_piezas c ON c.nombre = v.categoria
 WHERE NOT EXISTS (
    SELECT 1 FROM piezas_catalogo p WHERE p.nombre = v.nombre
 );

-- ------------------------------------------------------------
-- 3. Plantillas
-- ------------------------------------------------------------
INSERT INTO plantillas_pieza (nombre, aplica_a) VALUES
    ('Base',      '{}'),
    ('Sedán',     '{"tipo_vehiculo": "sedan"}'),
    ('Hatchback', '{"tipo_vehiculo": "hatchback"}'),
    ('SUV',       '{"tipo_vehiculo": "suv"}'),
    ('Pickup',    '{"tipo_vehiculo": "pickup"}'),
    ('Van',       '{"tipo_vehiculo": "van"}')
ON CONFLICT (nombre) DO NOTHING;

-- ------------------------------------------------------------
-- 4. Piezas de cada plantilla
-- ------------------------------------------------------------
INSERT INTO plantilla_items (plantilla_id, catalogo_pieza_id, cantidad)
SELECT t.id, c.id, 1
  FROM (VALUES
    -- Base: piezas comunes a cualquier vehículo
    ('Base', 'Motor completo'),
    ('Base', 'Cabeza de motor'),
    ('Base', 'Múltiple de admisión'),
    ('Base', 'Radiador'),
    ('Base', 'Bomba de agua'),
    ('Base', 'Alternador'),
    ('Base', 'Marcha'),
    ('Base', 'Batería'),
    ('Base', 'Compresor de A/C'),
    ('Base', 'Condensador'),
    ('Base', 'Módulo de control'),
    ('Base', 'Transmisión automática'),
    ('Base', 'Transmisión manual'),
    ('Base', 'Amortiguador delantero'),
    ('Base', 'Amortiguador trasero'),
    ('Base', 'Caja de dirección'),
    ('Base', 'Maza delantera'),
    ('Base', 'Disco delantero'),
    ('Base', 'Disco trasero'),
    ('Base', 'Caliper delantero'),
    ('Base', 'Puerta delantera izquierda'),
    ('Base', 'Puerta delantera derecha'),
    ('Base', 'Puerta trasera izquierda'),
    ('Base', 'Puerta trasera derecha'),
    ('Base', 'Cofre'),
    ('Base', 'Defensa delantera'),
    ('Base', 'Defensa trasera'),
    ('Base', 'Espejo izquierdo'),
    ('Base', 'Espejo derecho'),
    ('Base', 'Faro delantero izquierdo'),
    ('Base', 'Faro delantero derecho'),
    ('Base', 'Faro trasero izquierdo'),
    ('Base', 'Faro trasero derecho'),
    ('Base', 'Asiento delantero'),
    ('Base', 'Tablero'),
    ('Base', 'Volante'),
    ('Base', 'Consola central'),
    -- Por tipo
    ('Sedán', 'Tapa de cajuela'),
    ('Hatchback', 'Portón trasero'),
    ('SUV', 'Portón trasero'),
    ('SUV', 'Flecha cardán'),
    ('SUV', 'Diferencial'),
    ('Pickup', 'Flecha cardán'),
    ('Pickup', 'Diferencial'),
    ('Pickup', 'Caja de carga'),
    ('Van', 'Portón trasero'),
    ('Van', 'Puerta corrediza')
  ) AS v(plantilla, pieza)
  JOIN plantillas_pieza t ON t.nombre = v.plantilla
  JOIN piezas_catalogo c ON c.nombre = v.pieza
ON CONFLICT (plantilla_id, catalogo_pieza_id) DO NOTHING;
