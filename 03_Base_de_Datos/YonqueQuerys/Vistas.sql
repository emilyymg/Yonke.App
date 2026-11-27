-- ============================================================
-- VISTAS
-- Consolidado con Migracion_001: inventario por estado y marketplace
-- consultando las fotografías desde la tabla fotos.
-- Requiere Estructura.sql, StoreProcedures.sql, Triggers.sql y Datos.sql.
-- ============================================================

-- Vehículos desmantelados con resumen de sus piezas.
CREATE OR REPLACE VIEW v_vehiculos_desmantelados AS
SELECT v.id AS vehiculo_id,
       v.marca_texto AS marca,
       v.modelo_texto AS modelo,
       v.anio,
       v.vin,
       v.fecha_ingreso_yonque,
       v.fecha_desarme,
       y.nombre AS yonque,
       y.id AS yonque_id,
       COUNT(p.id) AS total_piezas,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'disponible') AS piezas_disponibles,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'vendido') AS piezas_vendidas,
       v.caracteristicas->>'color' AS color
  FROM vehiculos v
  JOIN yonques y ON y.id = v.yonque_id
  LEFT JOIN piezas p ON p.vehiculo_id = v.id
 WHERE v.estado = 'desmantelado'
 GROUP BY v.id, y.nombre, y.id;

-- Piezas más vendidas, con las cinco marcas de vehículo más frecuentes.
CREATE OR REPLACE VIEW v_piezas_mas_vendidas AS
SELECT pc.nombre AS pieza_nombre,
       c.nombre AS categoria,
       COUNT(v.id) AS total_ventas,
       SUM(v.precio_final) AS ingreso_total,
       AVG(v.precio_final) AS precio_promedio,
       COUNT(DISTINCT p.vehiculo_id) AS vehiculos_origen,
       (
           SELECT jsonb_agg(t.marca)
             FROM (
                   SELECT veh.marca_texto AS marca
                     FROM piezas p2
                     JOIN vehiculos veh ON veh.id = p2.vehiculo_id
                    WHERE p2.catalogo_pieza_id = pc.id
                    GROUP BY veh.marca_texto
                    ORDER BY COUNT(*) DESC
                    LIMIT 5
             ) t
       ) AS marcas_populares
  FROM piezas_catalogo pc
  LEFT JOIN piezas p ON p.catalogo_pieza_id = pc.id
  LEFT JOIN ventas v ON v.pieza_id = p.id AND v.estado = 'completada'
  LEFT JOIN categorias_piezas c ON c.id = pc.categoria_id
 GROUP BY pc.id, pc.nombre, c.nombre
HAVING COUNT(v.id) > 0
 ORDER BY total_ventas DESC;

-- Inventario real por yonque, sin duplicar piezas por múltiples publicaciones.
CREATE OR REPLACE VIEW v_inventario_actual AS
SELECT y.id AS yonque_id,
       y.nombre AS yonque,
       COUNT(DISTINCT v.id) AS total_vehiculos,
       COUNT(p.id) AS total_piezas,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'por_confirmar') AS piezas_por_confirmar,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'disponible') AS piezas_disponibles,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'reservado') AS piezas_reservadas,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'vendido') AS piezas_vendidas,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'en_revision') AS piezas_en_revision,
       COUNT(p.id) FILTER (WHERE p.estado_inventario = 'descartado') AS piezas_descartadas,
       COUNT(p.id) FILTER (
           WHERE EXISTS (
               SELECT 1
                 FROM publicaciones pub
                WHERE pub.pieza_id = p.id AND pub.estado = 'activa'
           )
       ) AS publicaciones_activas,
       COALESCE(SUM(p.precio_venta) FILTER (WHERE p.estado_inventario = 'disponible'), 0)
           AS valor_inventario
  FROM yonques y
  LEFT JOIN vehiculos v ON v.yonque_id = y.id AND v.activo
  LEFT JOIN piezas p ON p.vehiculo_id = v.id
 WHERE y.estado = 'activo'
 GROUP BY y.id, y.nombre;

-- Métricas globales para el panel administrativo.
CREATE OR REPLACE VIEW v_dashboard_admin AS
SELECT (SELECT COUNT(*) FROM usuarios WHERE estado = 'activo') AS usuarios_activos,
       (SELECT COUNT(*) FROM yonques WHERE estado = 'activo') AS yonques_activos,
       (SELECT COUNT(*) FROM vehiculos WHERE estado IN ('ingresado', 'en_desarme')) AS vehiculos_proceso,
       (SELECT COUNT(*) FROM piezas WHERE estado_inventario = 'disponible') AS piezas_disponibles,
       (SELECT COUNT(*) FROM publicaciones WHERE estado = 'activa') AS publicaciones_activas,
       (SELECT COUNT(*) FROM ventas
         WHERE estado = 'completada' AND fecha_venta >= CURRENT_DATE - INTERVAL '30 days') AS ventas_30dias,
       (SELECT COALESCE(SUM(total), 0) FROM ventas
         WHERE estado = 'completada' AND fecha_venta >= CURRENT_DATE - INTERVAL '30 days') AS ingresos_30dias;

-- Catálogo visible del marketplace. Las fotos se consultan desde la tabla fotos.
CREATE OR REPLACE VIEW v_marketplace_catalogo AS
SELECT pub.id AS publicacion_id,
       pub.titulo,
       pub.descripcion,
       pub.precio,
       pub.condicion,
       pub.vistas,
       pub.fecha_publicacion,
       p.id AS pieza_id,
       p.nombre AS pieza_nombre,
       p.atributos,
       foto.s3_key AS foto_principal,
       v.marca_texto AS marca,
       v.modelo_texto AS modelo,
       v.anio,
       v.caracteristicas,
       y.id AS yonque_id,
       y.nombre AS yonque_nombre,
       u.ciudad,
       u.estado AS estado_ubicacion
  FROM publicaciones pub
  JOIN piezas p ON p.id = pub.pieza_id
  JOIN vehiculos v ON v.id = p.vehiculo_id
  JOIN yonques y ON y.id = pub.yonque_id
  LEFT JOIN ubicaciones u ON u.id = y.ubicacion_id
  LEFT JOIN LATERAL (
      SELECT f.s3_key
        FROM fotos f
       WHERE f.pieza_id = p.id AND f.publicable
       ORDER BY f.es_principal DESC, f.orden, f.fecha_creacion
       LIMIT 1
  ) foto ON TRUE
 WHERE pub.estado = 'activa'
 ORDER BY pub.fecha_publicacion DESC;
