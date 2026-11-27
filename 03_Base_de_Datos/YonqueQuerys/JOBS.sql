-- ============================================================
-- JOBS PROGRAMADOS (pg_cron en AWS RDS o pgAgent en pgAdmin4)
-- Requiere Vistas.sql.
-- ============================================================

-- Notifica a los dueños y administradores cuando hay menos de 10 piezas
-- disponibles. Evita repetir la misma alerta durante los siguientes 7 días.
CREATE OR REPLACE FUNCTION job_monitoreo_inventario()
RETURNS void AS $$
BEGIN
    INSERT INTO notificaciones (usuario_id, tipo, titulo, contenido)
    SELECT u.id,
           'alerta_inventario',
           'Inventario bajo en ' || i.yonque,
           'El yonque tiene solo ' || i.piezas_disponibles || ' piezas disponibles.'
      FROM v_inventario_actual i
      JOIN usuarios u ON u.id IN (
          SELECT usuario_id FROM yonques WHERE id = i.yonque_id
          UNION
          SELECT us.id
            FROM usuarios us
            JOIN roles r ON r.id = us.rol_id
           WHERE r.nombre = 'administrador'
      )
     WHERE i.piezas_disponibles < 10
       AND NOT EXISTS (
           SELECT 1
             FROM notificaciones n
            WHERE n.usuario_id = u.id
              AND n.tipo = 'alerta_inventario'
              AND n.titulo = 'Inventario bajo en ' || i.yonque
              AND n.fecha_envio > now() - INTERVAL '7 days'
       );
END;
$$ LANGUAGE plpgsql;

-- Guarda el resumen de ventas del día actual.
CREATE OR REPLACE FUNCTION job_reporte_diario_ventas()
RETURNS void AS $$
BEGIN
    INSERT INTO reportes_generados (tipo_reporte, estado, resultado)
    SELECT 'ventas_diarias',
           'generado',
           jsonb_build_object(
               'fecha', CURRENT_DATE,
               'total_ventas', COUNT(*),
               'ingreso_total', COALESCE(SUM(v.total), 0),
               'top_yonques', (
                   SELECT jsonb_agg(
                              jsonb_build_object('yonque', t.nombre, 'ventas', t.cnt)
                              ORDER BY t.cnt DESC
                          )
                     FROM (
                           SELECT y.nombre, COUNT(*) AS cnt
                             FROM ventas v2
                             JOIN yonques y ON y.id = v2.yonque_id
                            WHERE v2.estado = 'completada'
                              AND v2.fecha_venta >= CURRENT_DATE
                              AND v2.fecha_venta < CURRENT_DATE + 1
                            GROUP BY y.nombre
                            ORDER BY cnt DESC
                            LIMIT 5
                     ) t
               )
           )
      FROM ventas v
     WHERE v.estado = 'completada'
       AND v.fecha_venta >= CURRENT_DATE
       AND v.fecha_venta < CURRENT_DATE + 1;
END;
$$ LANGUAGE plpgsql;

-- Ejemplos de programación (habilitar pg_cron según el entorno):
-- SELECT cron.schedule('0 9 * * *', 'SELECT job_monitoreo_inventario()');
-- SELECT cron.schedule('0 23 * * *', 'SELECT job_reporte_diario_ventas()');
