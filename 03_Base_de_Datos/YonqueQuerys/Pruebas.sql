-- ============================================================
-- PRUEBAS DE LA ESTRUCTURA ACTUAL
-- Ejecutar después de Estructura.sql, StoreProcedures.sql,
-- Triggers.sql, Datos.sql, Vistas.sql y JOBS.sql.
-- Las operaciones de escritura se revierten al final.
-- ============================================================

-- ============================================================
-- 1. VISTAS
-- ============================================================

SELECT *
  FROM v_vehiculos_desmantelados
 ORDER BY total_piezas DESC;

SELECT pieza_nombre, categoria, total_ventas, ingreso_total, precio_promedio
  FROM v_piezas_mas_vendidas
 ORDER BY total_ventas DESC
 LIMIT 10;

SELECT yonque_id, yonque, total_vehiculos, total_piezas,
       piezas_por_confirmar, piezas_disponibles, piezas_reservadas,
       piezas_vendidas, publicaciones_activas, valor_inventario
  FROM v_inventario_actual
 ORDER BY valor_inventario DESC;

SELECT * FROM v_dashboard_admin;

SELECT publicacion_id, titulo, precio, condicion, marca, modelo, anio,
       yonque_nombre, estado_ubicacion, foto_principal
  FROM v_marketplace_catalogo
 ORDER BY precio;

-- ============================================================
-- 2. TRANSICIONES Y AUDITORÍA DE PIEZAS
-- ============================================================

BEGIN;

-- Transición permitida y reversión de la prueba mediante la transición válida.
SELECT cambiar_estado_pieza(
    '91000000-0000-0000-0000-000000000005',
    'vendido',
    'b1000000-0000-0000-0000-000000000005',
    'Prueba de transición'
);

SELECT cambiar_estado_pieza(
    '91000000-0000-0000-0000-000000000005',
    'disponible',
    'b1000000-0000-0000-0000-000000000005',
    'Restauración de prueba'
);

SELECT tipo_movimiento,
       datos_anteriores->>'estado_inventario' AS estado_anterior,
       datos_nuevos->>'estado_inventario' AS estado_nuevo,
       usuario_id,
       descripcion
  FROM historial_movimientos
 WHERE registro_id = '91000000-0000-0000-0000-000000000005'
 ORDER BY fecha DESC
 LIMIT 2;

-- Una transición no registrada debe fallar; se captura el error para poder
-- continuar con las demás pruebas.
DO $$
BEGIN
    BEGIN
        PERFORM cambiar_estado_pieza(
            '91000000-0000-0000-0000-000000000001',
            'por_confirmar',
            'b1000000-0000-0000-0000-000000000005',
            'Prueba de transición inválida'
        );
        RAISE EXCEPTION 'La prueba esperaba que se rechazara la transición';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM = 'La prueba esperaba que se rechazara la transición' THEN
            RAISE;
        END IF;
    END;
END;
$$;

-- ============================================================
-- 3. PUBLICAR SIN MODIFICAR EL INVENTARIO
-- ============================================================

SELECT publicar_borrador(
    'a2000000-0000-0000-0000-000000000007',
    'b1000000-0000-0000-0000-000000000003'
) AS publicacion_creada;

SELECT id, estado_inventario
  FROM piezas
 WHERE id = '91000000-0000-0000-0000-000000000013';

-- ============================================================
-- 4. VENTA Y CANCELACIÓN
-- ============================================================

-- Venta directa: el vendedor debe pertenecer al yonque y la pieza queda vendida.
SELECT procesar_venta(
    '91000000-0000-0000-0000-000000000005',
    'b1000000-0000-0000-0000-000000000005',
    'Comprador de prueba',
    300.00,
    'efectivo',
    'Prueba de venta'
) AS venta_creada;

SELECT id, estado_inventario
  FROM piezas
 WHERE id = '91000000-0000-0000-0000-000000000005';

-- Una venta completada cancelada devuelve la pieza al estado disponible.
UPDATE ventas
   SET estado = 'cancelada', fecha_cancelacion = now()
 WHERE id = 'c2000000-0000-0000-0000-000000000001';

SELECT id, estado_inventario
  FROM piezas
 WHERE id = '91000000-0000-0000-0000-000000000004';

-- ============================================================
-- 5. SKU, NÚMERO DE UNIDAD Y PLANTILLAS
-- ============================================================

DO $$
DECLARE
    v_vehiculo_id UUID;
    v_piezas_generadas INT;
    v_numero_unidad INT;
    v_piezas_por_confirmar INT;
BEGIN
    SELECT r.vehiculo_id, r.piezas_generadas
      INTO v_vehiculo_id, v_piezas_generadas
      FROM registrar_vehiculo_con_piezas(
          'e1000000-0000-0000-0000-000000000001',
          'b1000000-0000-0000-0000-000000000007',
          'Nissan',
          'Tsuru de prueba',
          2010,
          '{"combustible":"gasolina"}'::jsonb,
          'd1000000-0000-0000-0000-000000000001'
      ) r;

    SELECT numero_unidad
      INTO v_numero_unidad
      FROM vehiculos
     WHERE id = v_vehiculo_id;

    SELECT COUNT(*)
      INTO v_piezas_por_confirmar
      FROM piezas
     WHERE vehiculo_id = v_vehiculo_id
       AND estado_inventario = 'por_confirmar'
       AND origen = 'plantilla';

    IF v_piezas_generadas <> v_piezas_por_confirmar OR v_piezas_generadas = 0 THEN
        RAISE EXCEPTION 'La generación de piezas por plantilla no produjo el resultado esperado';
    END IF;

    IF v_numero_unidad IS NULL OR EXISTS (
        SELECT 1 FROM piezas
         WHERE vehiculo_id = v_vehiculo_id
           AND codigo_sku NOT LIKE 'YNQ-MTY' || v_numero_unidad || '-%'
    ) THEN
        RAISE EXCEPTION 'El número de unidad o los SKU no se generaron correctamente';
    END IF;

    DELETE FROM piezas WHERE vehiculo_id = v_vehiculo_id;
    DELETE FROM vehiculos WHERE id = v_vehiculo_id;
END;
$$;

-- ============================================================
-- 6. JOBS Y CONSISTENCIA
-- ============================================================

SELECT job_monitoreo_inventario();
SELECT job_reporte_diario_ventas();

SELECT tipo_reporte, estado, resultado, fecha_generacion
  FROM reportes_generados
 ORDER BY fecha_generacion DESC
 LIMIT 5;

SELECT p.id, p.nombre, p.estado_inventario,
       COUNT(v.id) AS ventas_completadas
  FROM piezas p
  LEFT JOIN ventas v ON v.pieza_id = p.id AND v.estado = 'completada'
 WHERE p.estado_inventario = 'vendido'
 GROUP BY p.id, p.nombre, p.estado_inventario
HAVING COUNT(v.id) = 0;

SELECT pub.id, pub.titulo, p.estado_inventario
  FROM publicaciones pub
  JOIN piezas p ON p.id = pub.pieza_id
 WHERE pub.estado = 'activa'
   AND p.estado_inventario = 'vendido';

ROLLBACK;
