-- ============================================================
-- TRIGGERS
-- Consolidado con Migracion_001: auditoría por diferencias, notificación
-- de ventas, asignación secuencial de unidades y SKU.
-- Requiere Estructura.sql y StoreProcedures.sql.
-- ============================================================

-- Audita únicamente las diferencias reales y evita vender una pieza que aún
-- tenga una publicación activa. El motivo/usuario los establece la operación
-- de negocio que cambia el estado.
CREATE OR REPLACE FUNCTION trigger_auditar_piezas()
RETURNS TRIGGER AS $$
DECLARE
    v_old JSONB;
    v_new JSONB;
BEGIN
    SELECT jsonb_object_agg(n.key, o.value), jsonb_object_agg(n.key, n.value)
      INTO v_old, v_new
      FROM jsonb_each(to_jsonb(NEW)) n
      JOIN jsonb_each(to_jsonb(OLD)) o USING (key)
     WHERE n.value IS DISTINCT FROM o.value
       AND n.key <> 'fecha_actualizacion';

    IF v_new IS NULL THEN
        RETURN NEW;
    END IF;

    IF OLD.estado_inventario <> 'vendido'
       AND NEW.estado_inventario = 'vendido'
       AND EXISTS (
           SELECT 1
             FROM publicaciones
            WHERE pieza_id = NEW.id AND estado = 'activa'
       ) THEN
        RAISE EXCEPTION 'No se puede marcar como vendida una pieza con publicación activa';
    END IF;

    INSERT INTO historial_movimientos (
        tabla_afectada, registro_id, tipo_movimiento,
        datos_anteriores, datos_nuevos, usuario_id, descripcion
    ) VALUES (
        'piezas', NEW.id, 'UPDATE', v_old, v_new,
        NULLIF(current_setting('app.usuario_id', true), '')::uuid,
        NULLIF(current_setting('app.motivo', true), '')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditar_piezas ON piezas;

CREATE TRIGGER trg_auditar_piezas
AFTER UPDATE ON piezas
FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*)
EXECUTE FUNCTION trigger_auditar_piezas();

-- Las publicaciones informan del evento, pero nunca modifican el inventario.
CREATE OR REPLACE FUNCTION trigger_actualizar_inventario_venta()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM pg_notify(
            'venta_realizada',
            jsonb_build_object(
                'venta_id', NEW.id,
                'pieza_id', NEW.pieza_id,
                'yonque_id', NEW.yonque_id
            )::text
        );
    ELSIF OLD.estado = 'completada'
          AND NEW.estado IN ('cancelada', 'devuelta') THEN
        PERFORM cambiar_estado_pieza(
            NEW.pieza_id,
            'disponible',
            NULL,
            'Venta ' || NEW.estado
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ventas_inventario ON ventas;

CREATE TRIGGER trg_ventas_inventario
AFTER INSERT OR UPDATE ON ventas
FOR EACH ROW
EXECUTE FUNCTION trigger_actualizar_inventario_venta();

-- Asigna consecutivo por yonque y serializa las altas concurrentes del mismo
-- yonque bloqueando su fila.
CREATE OR REPLACE FUNCTION trigger_asignar_numero_unidad()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.numero_unidad IS NULL THEN
        PERFORM 1 FROM yonques WHERE id = NEW.yonque_id FOR UPDATE;
        SELECT COALESCE(MAX(numero_unidad), 0) + 1
          INTO NEW.numero_unidad
          FROM vehiculos
         WHERE yonque_id = NEW.yonque_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_numero_unidad ON vehiculos;

CREATE TRIGGER trg_numero_unidad
BEFORE INSERT ON vehiculos
FOR EACH ROW
EXECUTE FUNCTION trigger_asignar_numero_unidad();

-- SKU legible y secuencial por vehículo y abreviatura de catálogo.
CREATE OR REPLACE FUNCTION trigger_asignar_sku()
RETURNS TRIGGER AS $$
DECLARE
    v_pref TEXT;
    v_abr TEXT;
    v_n INT;
BEGIN
    IF NEW.codigo_sku IS NOT NULL THEN
        RETURN NEW;
    END IF;

    SELECT 'YNQ-' || COALESCE(y.codigo, UPPER(LEFT(REPLACE(y.id::text, '-', ''), 4)))
                  || v.numero_unidad || '-'
      INTO v_pref
      FROM vehiculos v
      JOIN yonques y ON y.id = v.yonque_id
     WHERE v.id = NEW.vehiculo_id
     FOR UPDATE OF v;

    SELECT COALESCE(
               c.abreviatura,
               NULLIF(UPPER(LEFT(regexp_replace(NEW.nombre, '[^A-Za-z]', '', 'g'), 3)), ''),
               'PZA'
           )
      INTO v_abr
      FROM (SELECT 1) d
      LEFT JOIN piezas_catalogo c ON c.id = NEW.catalogo_pieza_id;

    SELECT COUNT(*) + 1
      INTO v_n
      FROM piezas
     WHERE vehiculo_id = NEW.vehiculo_id
       AND codigo_sku LIKE v_pref || v_abr || '%';

    NEW.codigo_sku := v_pref || v_abr || v_n;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_asignar_sku ON piezas;

CREATE TRIGGER trg_asignar_sku
BEFORE INSERT ON piezas
FOR EACH ROW
EXECUTE FUNCTION trigger_asignar_sku();
