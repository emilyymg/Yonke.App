-- ============================================================
-- DATOS DE PRUEBA
-- 3 yonques, 15 publicaciones y 8 borradores abiertos.
-- El yonque "Refacciones Lozano" concentra 6 publicaciones y los 8 borradores.
--
-- Requiere: Estructura.sql (con pgcrypto), StoreProcedures.sql, Triggers.sql.
-- Todos los IDs de este script empiezan con f1..f7, para no chocar con datos existentes
-- y poder borrarlos fácilmente (ver bloque de limpieza al final).
--
-- Credenciales de los 3 usuarios dueños (contraseña única):  Demo1234!
--   pedro.lozano@example.com   -> Refacciones Lozano     (6 publicaciones + 8 borradores)
--   maria.cota@example.com     -> Deshuesadero La Mesa   (5 publicaciones)
--   jorge.rios@example.com     -> Yonke Hermanos Ríos    (4 publicaciones)
-- ============================================================

BEGIN;

-- Genera UUIDs predecibles: sid('f5', 7) -> f5000000-0000-0000-0000-000000000007
CREATE FUNCTION pg_temp.sid(prefijo text, n int) RETURNS uuid
LANGUAGE sql IMMUTABLE AS $$
    SELECT (prefijo || '000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid
$$;

-- ------------------------------------------------------------
-- 1. Roles (si ya existen, no se tocan)
-- ------------------------------------------------------------
INSERT INTO roles (nombre, permisos, descripcion) VALUES
    ('administrador', '{}', 'Control total'),
    ('vendedor',      '{}', 'Gestiona inventario y publicaciones'),
    ('almacen',       '{}', 'Gestiona inventario'),
    ('consulta',      '{}', 'Solo lectura')
ON CONFLICT (nombre) DO NOTHING;

-- ------------------------------------------------------------
-- 2. Ubicaciones de los yonques (domicilios inventados)
-- ------------------------------------------------------------
INSERT INTO ubicaciones (id, calle, numero, colonia, codigo_postal, ciudad, estado, latitud, longitud, referencia) VALUES
    (pg_temp.sid('f2', 1), 'Blvd. Industrial',  '2450', 'Ciudad Industrial', '22444', 'Tijuana',  'Baja California', 32.50850000, -116.96470000, 'Frente a la gasolinera'),
    (pg_temp.sid('f2', 2), 'Av. Internacional', '1520', 'Zona Norte',        '22000', 'Tijuana',  'Baja California', 32.53970000, -117.03640000, 'Junto a la vulcanizadora'),
    (pg_temp.sid('f2', 3), 'Calle Décima',      '315',  'Obrera',            '22830', 'Ensenada', 'Baja California', 31.86670000, -116.60700000, 'Portón verde');

-- ------------------------------------------------------------
-- 3. Usuarios dueños (contraseña: Demo1234!, hash bcrypt generado con pgcrypto)
-- ------------------------------------------------------------
INSERT INTO usuarios (id, nombre, email, contrasena_hash, telefono, rol_id, es_yonquero, nombre_negocio, estado) VALUES
    (pg_temp.sid('f1', 1), 'Pedro Lozano',     'pedro.lozano@example.com', crypt('Demo1234!', gen_salt('bf', 10)), '664-100-0001',
        (SELECT id FROM roles WHERE nombre = 'vendedor'), TRUE, 'Refacciones Lozano',   'activo'),
    (pg_temp.sid('f1', 2), 'María Fernanda Cota', 'maria.cota@example.com', crypt('Demo1234!', gen_salt('bf', 10)), '664-100-0002',
        (SELECT id FROM roles WHERE nombre = 'vendedor'), TRUE, 'Deshuesadero La Mesa', 'activo'),
    (pg_temp.sid('f1', 3), 'Jorge Ríos',       'jorge.rios@example.com',   crypt('Demo1234!', gen_salt('bf', 10)), '646-100-0003',
        (SELECT id FROM roles WHERE nombre = 'vendedor'), TRUE, 'Yonke Hermanos Ríos', 'activo');

-- ------------------------------------------------------------
-- 4. Yonques (los contadores no los mantiene ningún trigger, se fijan a mano)
-- ------------------------------------------------------------
INSERT INTO yonques (id, codigo, usuario_id, nombre, descripcion, ubicacion_id, capacidad_vehiculos,
                     horario_atencion, metodos_pago, estado, verificado,
                     total_vehiculos_registrados, total_piezas_disponibles) VALUES
    (pg_temp.sid('f3', 1), 'LOZ',  pg_temp.sid('f1', 1), 'Refacciones Lozano',
        'Refacciones usadas para autos compactos y sedanes.', pg_temp.sid('f2', 1), 120,
        '{"lunes-viernes":"9:00-18:00","sabado":"9:00-14:00"}', '["efectivo","transferencia"]', 'activo', TRUE, 3, 14),
    (pg_temp.sid('f3', 2), 'MESA', pg_temp.sid('f1', 2), 'Deshuesadero La Mesa',
        'Especialistas en pickups y camionetas.', pg_temp.sid('f2', 2), 80,
        '{"lunes-sabado":"8:30-17:30"}', '["efectivo","tarjeta","transferencia"]', 'activo', TRUE, 2, 5),
    (pg_temp.sid('f3', 3), 'RIOS', pg_temp.sid('f1', 3), 'Yonke Hermanos Ríos',
        'Motores, transmisiones y electrónica automotriz.', pg_temp.sid('f2', 3), 60,
        '{"lunes-viernes":"9:00-17:00"}', '["efectivo","transferencia"]', 'activo', TRUE, 2, 4);

INSERT INTO miembros_yonque (yonque_id, usuario_id, rol_id) VALUES
    (pg_temp.sid('f3', 1), pg_temp.sid('f1', 1), (SELECT id FROM roles WHERE nombre = 'administrador')),
    (pg_temp.sid('f3', 2), pg_temp.sid('f1', 2), (SELECT id FROM roles WHERE nombre = 'administrador')),
    (pg_temp.sid('f3', 3), pg_temp.sid('f1', 3), (SELECT id FROM roles WHERE nombre = 'administrador'));

-- ------------------------------------------------------------
-- 5. Vehículos (numero_unidad se fija a mano; el trigger lo respeta si viene informado)
-- ------------------------------------------------------------
INSERT INTO vehiculos (id, yonque_id, numero_unidad, usuario_registro_id, marca_texto, modelo_texto, anio, version,
                       estado, caracteristicas, fecha_ingreso_yonque, fecha_desarme) VALUES
    -- Refacciones Lozano
    (pg_temp.sid('f4', 1), pg_temp.sid('f3', 1), 1, pg_temp.sid('f1', 1), 'Nissan', 'Tsuru',   2010, 'GS II',
        'en_desarme', '{"color":"blanco","transmision":"manual","combustible":"gasolina"}',     CURRENT_DATE - 60, CURRENT_DATE - 50),
    (pg_temp.sid('f4', 2), pg_temp.sid('f3', 1), 2, pg_temp.sid('f1', 1), 'Toyota', 'Corolla', 2012, 'LE',
        'en_desarme', '{"color":"gris","transmision":"automatica","combustible":"gasolina"}',   CURRENT_DATE - 45, CURRENT_DATE - 35),
    (pg_temp.sid('f4', 3), pg_temp.sid('f3', 1), 3, pg_temp.sid('f1', 1), 'Honda',  'Civic',   2008, 'LX',
        'en_desarme', '{"color":"negro","transmision":"manual","combustible":"gasolina"}',      CURRENT_DATE - 30, CURRENT_DATE - 20),
    -- Deshuesadero La Mesa
    (pg_temp.sid('f4', 4), pg_temp.sid('f3', 2), 1, pg_temp.sid('f1', 2), 'Ford',      'F-150', 2011, 'XLT',
        'en_desarme', '{"color":"azul","transmision":"automatica","combustible":"gasolina"}',   CURRENT_DATE - 40, CURRENT_DATE - 30),
    (pg_temp.sid('f4', 5), pg_temp.sid('f3', 2), 2, pg_temp.sid('f1', 2), 'Chevrolet', 'Aveo',  2013, 'LT',
        'en_desarme', '{"color":"rojo","transmision":"manual","combustible":"gasolina"}',       CURRENT_DATE - 25, CURRENT_DATE - 15),
    -- Yonke Hermanos Ríos
    (pg_temp.sid('f4', 6), pg_temp.sid('f3', 3), 1, pg_temp.sid('f1', 3), 'Volkswagen', 'Jetta', 2009, 'Style',
        'en_desarme', '{"color":"plata","transmision":"manual","combustible":"gasolina"}',      CURRENT_DATE - 50, CURRENT_DATE - 40),
    (pg_temp.sid('f4', 7), pg_temp.sid('f3', 3), 2, pg_temp.sid('f1', 3), 'Mazda',      'Mazda 3', 2015, 'i Touring',
        'en_desarme', '{"color":"blanco","transmision":"manual","combustible":"gasolina"}',     CURRENT_DATE - 20, CURRENT_DATE - 10);

-- ------------------------------------------------------------
-- 6. Piezas (SKU con el mismo formato que genera el trigger: YNQ-<código><unidad>-<abrev><n>)
--    01-06: publicadas (Lozano)      07-14: con borrador abierto (Lozano)
--    15-17: por confirmar (Lozano)   18-22: publicadas (La Mesa)   23-26: publicadas (Ríos)
-- ------------------------------------------------------------
INSERT INTO piezas (id, vehiculo_id, codigo_sku, nombre, descripcion, condicion, estado_inventario, origen,
                    atributos, precio_venta, precio_minimo, inspeccionado) VALUES
    -- Lozano: publicadas
    (pg_temp.sid('f5', 1),  pg_temp.sid('f4', 1), 'YNQ-LOZ1-MOT1', 'Motor 1.6L completo',
        'Motor 1.6L completo con múltiple y cuerpo de aceleración. Probado en banco, sin fugas.',
        'usado', 'disponible', 'manual', '{"cilindrada":"1.6L","combustible":"gasolina"}', 4500.00, 4000.00, TRUE),
    (pg_temp.sid('f5', 2),  pg_temp.sid('f4', 1), 'YNQ-LOZ1-PUE1', 'Puerta delantera izquierda',
        'Puerta completa con vidrio y elevador. Sin golpes, pintura original.',
        'usado', 'disponible', 'manual', '{"color":"blanco","lado":"izquierdo"}', 1200.00, 1000.00, TRUE),
    (pg_temp.sid('f5', 3),  pg_temp.sid('f4', 2), 'YNQ-LOZ2-FAR1', 'Faro delantero derecho',
        'Faro original con mica sin rayones ni humedad.',
        'seminuevo', 'disponible', 'manual', '{"lado":"derecho","tipo":"halogeno"}', 850.00, 700.00, TRUE),
    (pg_temp.sid('f5', 4),  pg_temp.sid('f4', 2), 'YNQ-LOZ2-TRA1', 'Transmisión automática',
        'Transmisión automática de 4 velocidades. Cambios suaves, incluye convertidor de par.',
        'usado', 'disponible', 'manual', '{"tipo":"automatica","velocidades":"4"}', 6800.00, 6000.00, TRUE),
    (pg_temp.sid('f5', 5),  pg_temp.sid('f4', 3), 'YNQ-LOZ3-ALT1', 'Alternador',
        'Alternador funcionando, probado con voltímetro. Incluye polea.',
        'usado', 'disponible', 'manual', '{"voltaje":"12V","amperaje":"90A"}', 950.00, 800.00, TRUE),
    (pg_temp.sid('f5', 6),  pg_temp.sid('f4', 3), 'YNQ-LOZ3-RIN1', 'Rin de aluminio 16"',
        'Rin de aluminio rodada 16, sin golpes ni fisuras. Precio por pieza.',
        'usado', 'disponible', 'manual', '{"rodada":"16","material":"aluminio","color":"plata"}', 700.00, 550.00, TRUE),
    -- Lozano: con borrador abierto
    (pg_temp.sid('f5', 7),  pg_temp.sid('f4', 1), 'YNQ-LOZ1-SAL1', 'Salpicadera delantera derecha',
        'Salpicadera sin golpes, lista para pintar.',
        'usado', 'disponible', 'manual', '{"color":"blanco","lado":"derecho"}', 650.00, 500.00, TRUE),
    (pg_temp.sid('f5', 8),  pg_temp.sid('f4', 1), 'YNQ-LOZ1-CAL1', 'Calavera trasera izquierda',
        'Calavera con cristal íntegro y portalámparas completo.',
        'usado', 'disponible', 'manual', '{"lado":"izquierdo"}', 500.00, 400.00, TRUE),
    (pg_temp.sid('f5', 9),  pg_temp.sid('f4', 2), 'YNQ-LOZ2-ESP1', 'Espejo retrovisor izquierdo',
        'Espejo eléctrico original.',
        'usado', 'disponible', 'manual', '{"lado":"izquierdo","electrico":true}', 450.00, 350.00, TRUE),
    (pg_temp.sid('f5', 10), pg_temp.sid('f4', 2), 'YNQ-LOZ2-RAD1', 'Radiador',
        'Radiador de aluminio, sin fugas.',
        'usado', 'disponible', 'manual', '{"material":"aluminio"}', 1100.00, 900.00, TRUE),
    (pg_temp.sid('f5', 11), pg_temp.sid('f4', 2), 'YNQ-LOZ2-COM1', 'Compresor de aire acondicionado',
        'Compresor funcionando, enfría correctamente.',
        'usado', 'disponible', 'manual', '{"voltaje":"12V"}', 2200.00, 1800.00, TRUE),
    (pg_temp.sid('f5', 12), pg_temp.sid('f4', 3), 'YNQ-LOZ3-TAB1', 'Tablero de instrumentos',
        'Tablero completo con cluster, sin grietas.',
        'usado', 'disponible', 'manual', '{"color":"negro"}', 1800.00, 1500.00, TRUE),
    (pg_temp.sid('f5', 13), pg_temp.sid('f4', 3), 'YNQ-LOZ3-ASI1', 'Asientos delanteros (par)',
        'Par de asientos en tela, estructura firme.',
        'usado', 'disponible', 'manual', '{"material":"tela","color":"gris"}', 2500.00, 2000.00, TRUE),
    (pg_temp.sid('f5', 14), pg_temp.sid('f4', 3), 'YNQ-LOZ3-ECU1', 'Computadora ECU',
        'ECU original, probada.',
        'usado', 'disponible', 'manual', '{}', 1600.00, 1300.00, TRUE),
    -- Lozano: por confirmar (generadas por plantilla, sin precio ni condición)
    (pg_temp.sid('f5', 15), pg_temp.sid('f4', 1), 'YNQ-LOZ1-PAR1', 'Parabrisas',
        NULL, NULL, 'por_confirmar', 'plantilla', '{}', NULL, NULL, FALSE),
    (pg_temp.sid('f5', 16), pg_temp.sid('f4', 2), 'YNQ-LOZ2-TAP1', 'Tapa de cajuela',
        NULL, NULL, 'por_confirmar', 'plantilla', '{}', NULL, NULL, FALSE),
    (pg_temp.sid('f5', 17), pg_temp.sid('f4', 3), 'YNQ-LOZ3-DEF1', 'Defensa trasera',
        NULL, NULL, 'por_confirmar', 'plantilla', '{}', NULL, NULL, FALSE),
    -- La Mesa: publicadas
    (pg_temp.sid('f5', 18), pg_temp.sid('f4', 4), 'YNQ-MESA1-MOT1', 'Motor 5.0L V8',
        'Motor V8 5.0L con compresión verificada. Incluye computadora y arneses.',
        'usado', 'disponible', 'manual', '{"cilindrada":"5.0L","cilindros":"8"}', 18500.00, 16500.00, TRUE),
    (pg_temp.sid('f5', 19), pg_temp.sid('f4', 4), 'YNQ-MESA1-DEF1', 'Defensa delantera cromada',
        'Defensa cromada sin picaduras ni abolladuras.',
        'usado', 'disponible', 'manual', '{"acabado":"cromado"}', 3200.00, 2700.00, TRUE),
    (pg_temp.sid('f5', 20), pg_temp.sid('f4', 4), 'YNQ-MESA1-TAP1', 'Tapa de caja (tailgate)',
        'Tapa de caja completa con bisagras y manija.',
        'usado', 'disponible', 'manual', '{"color":"azul"}', 2400.00, 2000.00, TRUE),
    (pg_temp.sid('f5', 21), pg_temp.sid('f4', 5), 'YNQ-MESA2-COF1', 'Cofre',
        'Cofre sin golpes, pintura roja original.',
        'usado', 'disponible', 'manual', '{"color":"rojo"}', 1500.00, 1200.00, TRUE),
    (pg_temp.sid('f5', 22), pg_temp.sid('f4', 5), 'YNQ-MESA2-BOM1', 'Bomba de gasolina',
        'Bomba de gasolina con aforador, funcionando.',
        'seminuevo', 'disponible', 'manual', '{"voltaje":"12V"}', 700.00, 550.00, TRUE),
    -- Ríos: publicadas
    (pg_temp.sid('f5', 23), pg_temp.sid('f4', 6), 'YNQ-RIOS1-MOT1', 'Motor 2.5L 5 cilindros',
        'Motor 2.5L de 5 cilindros, buen arranque y sin humo.',
        'usado', 'disponible', 'manual', '{"cilindrada":"2.5L","cilindros":"5"}', 9500.00, 8500.00, TRUE),
    (pg_temp.sid('f5', 24), pg_temp.sid('f4', 6), 'YNQ-RIOS1-ABS1', 'Módulo ABS',
        'Módulo ABS probado, sin códigos de falla.',
        'usado', 'disponible', 'manual', '{}', 2100.00, 1700.00, TRUE),
    (pg_temp.sid('f5', 25), pg_temp.sid('f4', 7), 'YNQ-RIOS2-FAR1', 'Faro delantero izquierdo',
        'Faro original en excelente estado.',
        'seminuevo', 'disponible', 'manual', '{"lado":"izquierdo"}', 1400.00, 1100.00, TRUE),
    (pg_temp.sid('f5', 26), pg_temp.sid('f4', 7), 'YNQ-RIOS2-CAJ1', 'Caja de velocidades manual',
        'Caja manual de 6 velocidades, sincronizadores en buen estado.',
        'usado', 'disponible', 'manual', '{"tipo":"manual","velocidades":"6"}', 5200.00, 4500.00, TRUE);

-- ------------------------------------------------------------
-- 7. Fotos: 2 por pieza disponible (23 piezas = 46 fotos).
--    s3_key sigue la estructura del bucket: originales/{vehiculo_id}/{pieza_id}/{foto_id}.jpg
--    -> Los derivados esperados serán derivados/{vehiculo_id}/{pieza_id}/{foto_id}/thumb.webp y medium.webp
--    Reemplaza las keys por las reales (ver consulta de apoyo al final).
-- ------------------------------------------------------------
WITH base AS MATERIALIZED (
    SELECT gen_random_uuid() AS id, p.id AS pieza_id, p.vehiculo_id, g.n
      FROM piezas p
     CROSS JOIN generate_series(1, 2) AS g(n)
     WHERE p.id::text LIKE 'f5000000-0000-0000-0000-0000000000__'
       AND p.estado_inventario = 'disponible'
)
INSERT INTO fotos (id, pieza_id, s3_key, ancho, alto, orden, es_principal, publicable)
SELECT id, pieza_id,
       format('originales/%s/%s/%s.jpg', vehiculo_id, pieza_id, id),
       4032, 3024, (n - 1)::smallint, (n = 1), TRUE
  FROM base;

-- ------------------------------------------------------------
-- 8. Borradores
--    a) 15 borradores "publicado": respaldan a las 15 publicaciones (publicaciones.borrador_id es NOT NULL).
--    b) 8 borradores abiertos (todos de Refacciones Lozano): los que verá la app en "Borradores".
-- ------------------------------------------------------------
CREATE TEMP TABLE _pub_seed ON COMMIT DROP AS
SELECT num, orden::int AS orden
  FROM unnest(ARRAY[1,2,3,4,5,6, 18,19,20,21,22, 23,24,25,26]) WITH ORDINALITY AS s(num, orden);

-- a) Publicados
INSERT INTO borradores_publicacion (id, pieza_id, usuario_id, titulo, descripcion_marketplace, precio_publico,
                                    condicion_publicada, estado, validaciones_pasadas,
                                    fecha_creacion, fecha_ultima_edicion, fecha_publicacion)
SELECT pg_temp.sid('f6', s.num), p.id, y.usuario_id,
       p.nombre || ' ' || v.marca_texto || ' ' || v.modelo_texto || ' ' || v.anio,
       p.descripcion, p.precio_venta, p.condicion, 'publicado', '["fotos","descripcion","precio"]'::jsonb,
       now() - (s.orden * interval '1 day') - interval '1 day',
       now() - (s.orden * interval '1 day') - interval '2 hours',
       now() - (s.orden * interval '1 day')
  FROM _pub_seed s
  JOIN piezas p    ON p.id = pg_temp.sid('f5', s.num)
  JOIN vehiculos v ON v.id = p.vehiculo_id
  JOIN yonques y   ON y.id = v.yonque_id;

-- b) Abiertos (varios grados de avance para probar validaciones y filtros)
INSERT INTO borradores_publicacion (id, pieza_id, usuario_id, titulo, descripcion_marketplace, precio_publico,
                                    condicion_publicada, estado, validaciones_pasadas,
                                    fecha_creacion, fecha_ultima_edicion) VALUES
    -- pendiente: casi vacíos
    (pg_temp.sid('f6', 7),  pg_temp.sid('f5', 7),  pg_temp.sid('f1', 1),
        'Salpicadera delantera derecha Nissan Tsuru 2010', NULL, NULL, 'usado',
        'pendiente', '[]', now() - interval '3 days', now() - interval '3 days'),
    (pg_temp.sid('f6', 8),  pg_temp.sid('f5', 8),  pg_temp.sid('f1', 1),
        'Calavera trasera izquierda Nissan Tsuru 2010', NULL, 500.00, 'usado',
        'pendiente', '["precio"]', now() - interval '3 days', now() - interval '2 days'),
    (pg_temp.sid('f6', 14), pg_temp.sid('f5', 14), pg_temp.sid('f1', 1),
        NULL, NULL, NULL, NULL,
        'pendiente', '[]', now() - interval '1 day', now() - interval '1 day'),
    -- en_edicion: con título y descripción
    (pg_temp.sid('f6', 9),  pg_temp.sid('f5', 9),  pg_temp.sid('f1', 1),
        'Espejo retrovisor izquierdo eléctrico Toyota Corolla 2012',
        'Espejo original con ajuste eléctrico. Cristal sin rayones.', 450.00, 'usado',
        'en_edicion', '["descripcion","precio"]', now() - interval '5 days', now() - interval '1 day'),
    (pg_temp.sid('f6', 10), pg_temp.sid('f5', 10), pg_temp.sid('f1', 1),
        'Radiador Toyota Corolla 2012',
        'Radiador de aluminio, sin fugas, probado a presión.', 1100.00, 'usado',
        'en_edicion', '["descripcion","precio"]', now() - interval '4 days', now() - interval '12 hours'),
    (pg_temp.sid('f6', 13), pg_temp.sid('f5', 13), pg_temp.sid('f1', 1),
        'Asientos delanteros Honda Civic 2008 (par)',
        'Par de asientos en tela gris, estructura firme, sin rasgaduras.', 2500.00, 'usado',
        'en_edicion', '["descripcion","precio"]', now() - interval '2 days', now() - interval '6 hours'),
    -- listo_para_publicar: validados
    (pg_temp.sid('f6', 11), pg_temp.sid('f5', 11), pg_temp.sid('f1', 1),
        'Compresor de aire acondicionado Toyota Corolla 2012',
        'Compresor funcionando, enfría correctamente. Incluye polea y clutch.', 2200.00, 'usado',
        'listo_para_publicar', '["fotos","descripcion","precio"]', now() - interval '6 days', now() - interval '2 hours'),
    (pg_temp.sid('f6', 12), pg_temp.sid('f5', 12), pg_temp.sid('f1', 1),
        'Tablero de instrumentos Honda Civic 2008',
        'Tablero completo con cluster, sin grietas ni faltantes.', 1800.00, 'usado',
        'listo_para_publicar', '["fotos","descripcion","precio"]', now() - interval '6 days', now() - interval '1 hour');

-- Fotos del marketplace en cada borrador (formato propuesto: referencia a fotos.id + s3_key).
-- Ajusta esto si tu app/web usa otro formato en fotos_marketplace.
UPDATE borradores_publicacion b
   SET fotos_marketplace = COALESCE((
         SELECT jsonb_agg(jsonb_build_object(
                    'foto_id', f.id, 's3_key', f.s3_key, 'orden', f.orden, 'principal', f.es_principal)
                    ORDER BY f.orden)
           FROM fotos f
          WHERE f.pieza_id = b.pieza_id), '[]'::jsonb)
 WHERE b.id::text LIKE 'f6000000-0000-0000-0000-0000000000__';

-- ------------------------------------------------------------
-- 9. Publicaciones (15). Equivalen a lo que haría publicar_borrador().
--    Dos de Lozano (piezas 5 y 6) quedan "pausada" para probar el filtro por estado; el resto "activa".
-- ------------------------------------------------------------
INSERT INTO publicaciones (id, borrador_id, pieza_id, yonque_id, usuario_publicacion_id, titulo, descripcion,
                           precio, condicion, estado, vistas, contactos, favoritos_count, tags,
                           ubicacion_id, fecha_publicacion)
SELECT pg_temp.sid('f7', s.num), b.id, b.pieza_id, y.id, b.usuario_id, b.titulo, b.descripcion_marketplace,
       b.precio_publico, b.condicion_publicada,
       CASE WHEN s.num IN (5, 6) THEN 'pausada' ELSE 'activa' END,
       20 + abs(hashtext(b.id::text)::bigint) % 180,
       abs(hashtext(b.titulo)::bigint) % 12,
       abs(hashtext(b.id::text || 'fav')::bigint) % 9,
       jsonb_build_array(lower(v.marca_texto), lower(v.modelo_texto), v.anio::text),
       y.ubicacion_id, b.fecha_publicacion
  FROM _pub_seed s
  JOIN borradores_publicacion b ON b.id = pg_temp.sid('f6', s.num)
  JOIN piezas p    ON p.id = b.pieza_id
  JOIN vehiculos v ON v.id = p.vehiculo_id
  JOIN yonques y   ON y.id = v.yonque_id;

COMMIT;

-- ============================================================
-- VERIFICACIÓN: debe dar Lozano = 6 publicaciones y 8 borradores abiertos; La Mesa = 5; Ríos = 4
-- ============================================================
SELECT y.nombre,
       (SELECT COUNT(*) FROM publicaciones pub WHERE pub.yonque_id = y.id) AS publicaciones,
       (SELECT COUNT(*) FROM borradores_publicacion b
          JOIN piezas pz ON pz.id = b.pieza_id
          JOIN vehiculos v ON v.id = pz.vehiculo_id
         WHERE v.yonque_id = y.id
           AND b.estado IN ('pendiente', 'en_edicion', 'listo_para_publicar')) AS borradores_abiertos
  FROM yonques y
 WHERE y.id::text LIKE 'f3000000-%'
 ORDER BY y.nombre;

-- ============================================================
-- APOYO PARA REEMPLAZAR LAS FOTOS por las reales
-- ============================================================
-- Lista de fotos (una fila por foto) con su SKU:
--   SELECT pz.codigo_sku, f.id, f.orden, f.s3_key
--     FROM fotos f JOIN piezas pz ON pz.id = f.pieza_id
--    WHERE pz.id::text LIKE 'f5000000-%' ORDER BY pz.codigo_sku, f.orden;
--
-- Reemplazo de una foto (si cambias la key, actualiza también el JSON del borrador):
--   UPDATE fotos SET s3_key = 'originales/<vehiculo>/<pieza>/<foto>.jpg' WHERE id = '<id>';
--
-- Tras cambiar keys, vuelve a ejecutar el UPDATE de borradores.fotos_marketplace (sección 8).

-- ============================================================
-- LIMPIEZA (borra solo lo creado por este script)
-- ============================================================
-- BEGIN;
-- DELETE FROM publicaciones           WHERE id::text        LIKE 'f7000000-%';
-- DELETE FROM borradores_publicacion  WHERE id::text        LIKE 'f6000000-%';
-- DELETE FROM fotos                   WHERE pieza_id::text  LIKE 'f5000000-%';
-- DELETE FROM historial_movimientos   WHERE registro_id::text LIKE 'f5000000-%';
-- DELETE FROM piezas                  WHERE id::text        LIKE 'f5000000-%';
-- DELETE FROM vehiculos               WHERE id::text        LIKE 'f4000000-%';
-- DELETE FROM miembros_yonque         WHERE yonque_id::text LIKE 'f3000000-%';
-- DELETE FROM yonques                 WHERE id::text        LIKE 'f3000000-%';
-- DELETE FROM usuarios                WHERE id::text        LIKE 'f1000000-%';
-- DELETE FROM ubicaciones             WHERE id::text        LIKE 'f2000000-%';
-- COMMIT;
