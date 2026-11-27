-- ============================================================
-- FUNCIONES Y OPERACIONES DE NEGOCIO
-- Consolidado con Migracion_001: transiciones controladas, generación por
-- plantillas, publicación sin alterar inventario y procesamiento de ventas.
-- Se instala después de Estructura.sql y antes de Triggers.sql.
-- ============================================================

-- Cambios de estado auditados y limitados a las transiciones permitidas.
CREATE OR REPLACE FUNCTION cambiar_estado_pieza(
    p_pieza_id UUID,
    p_nuevo VARCHAR,
    p_usuario_id UUID,
    p_motivo TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_actual VARCHAR;
BEGIN
    SELECT estado_inventario
      INTO v_actual
      FROM piezas
     WHERE id = p_pieza_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pieza % no existe', p_pieza_id;
    END IF;

    IF v_actual = p_nuevo THEN
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM transiciones_pieza
         WHERE desde = v_actual AND hacia = p_nuevo
    ) THEN
        RAISE EXCEPTION 'Transición no permitida: % -> %', v_actual, p_nuevo;
    END IF;

    PERFORM set_config('app.usuario_id', COALESCE(p_usuario_id::text, ''), true);
    PERFORM set_config('app.motivo', COALESCE(p_motivo, ''), true);

    UPDATE piezas
       SET estado_inventario = p_nuevo,
           fecha_actualizacion = now()
     WHERE id = p_pieza_id;

    PERFORM set_config('app.motivo', '', true);
    PERFORM set_config('app.usuario_id', '', true);
END;
$$ LANGUAGE plpgsql;

-- Genera piezas desde todas las plantillas activas compatibles con el vehículo.
CREATE OR REPLACE FUNCTION generar_piezas_vehiculo(p_vehiculo_id UUID)
RETURNS INT AS $$
DECLARE
    v_attrs JSONB;
    v_n INT;
BEGIN
    SELECT COALESCE(v.caracteristicas, '{}')
           || jsonb_strip_nulls(jsonb_build_object('tipo_vehiculo', m.tipo_vehiculo))
      INTO v_attrs
      FROM vehiculos v
      LEFT JOIN modelos_vehiculo m ON m.id = v.modelo_id
     WHERE v.id = p_vehiculo_id;

    IF v_attrs IS NULL THEN
        RETURN 0;
    END IF;

    INSERT INTO piezas (vehiculo_id, catalogo_pieza_id, nombre, categoria_id, atributos, origen)
    SELECT p_vehiculo_id, c.id, c.nombre, c.categoria_id, c.atributos_default, 'plantilla'
      FROM (
            SELECT i.catalogo_pieza_id, MAX(i.cantidad) AS cantidad
              FROM plantillas_pieza t
              JOIN plantilla_items i ON i.plantilla_id = t.id
             WHERE t.activa AND t.aplica_a <@ v_attrs
             GROUP BY i.catalogo_pieza_id
      ) x
      JOIN piezas_catalogo c ON c.id = x.catalogo_pieza_id AND c.activo
      CROSS JOIN LATERAL generate_series(1, x.cantidad) AS g(n)
     ORDER BY c.prioridad, c.nombre, g.n;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n;
END;
$$ LANGUAGE plpgsql;

-- Registra un vehículo, asigna su número de unidad en el trigger y genera piezas.
CREATE OR REPLACE FUNCTION registrar_vehiculo_con_piezas(
    p_yonque_id UUID,
    p_usuario_id UUID,
    p_marca_texto VARCHAR,
    p_modelo_texto VARCHAR,
    p_anio INT,
    p_caracteristicas JSONB DEFAULT '{}',
    p_modelo_id UUID DEFAULT NULL
) RETURNS TABLE(vehiculo_id UUID, piezas_generadas INT) AS $$
DECLARE
    v_id UUID;
    v_n INT;
BEGIN
    INSERT INTO vehiculos (
        yonque_id, usuario_registro_id, marca_id, modelo_id,
        marca_texto, modelo_texto, anio, caracteristicas, estado
    )
    SELECT p_yonque_id, p_usuario_id, m.marca_id, m.id,
           COALESCE(p_marca_texto, mk.nombre), COALESCE(p_modelo_texto, m.nombre),
           p_anio, p_caracteristicas, 'ingresado'
      FROM (SELECT 1) d
      LEFT JOIN modelos_vehiculo m ON m.id = p_modelo_id
      LEFT JOIN marcas_vehiculo mk ON mk.id = m.marca_id
    RETURNING id INTO v_id;

    v_n := generar_piezas_vehiculo(v_id);

    INSERT INTO historial_movimientos (
        tabla_afectada, registro_id, tipo_movimiento,
        datos_nuevos, usuario_id, descripcion
    ) VALUES (
        'vehiculos', v_id, 'INSERT',
        jsonb_build_object('marca', p_marca_texto, 'modelo', p_modelo_texto, 'anio', p_anio),
        p_usuario_id, 'Vehículo registrado con ' || v_n || ' piezas por confirmar'
    );

    RETURN QUERY SELECT v_id, v_n;
END;
$$ LANGUAGE plpgsql;

-- Publica un borrador sin cambiar el estado de inventario de la pieza.
CREATE OR REPLACE FUNCTION publicar_borrador(p_borrador_id UUID, p_usuario_id UUID)
RETURNS UUID AS $$
DECLARE
    v_b borradores_publicacion%ROWTYPE;
    v_pub UUID;
BEGIN
    SELECT *
      INTO v_b
      FROM borradores_publicacion
     WHERE id = p_borrador_id
     FOR UPDATE;

    IF NOT FOUND OR v_b.estado <> 'listo_para_publicar' THEN
        RAISE EXCEPTION 'El borrador no está listo para publicar';
    END IF;

    PERFORM 1
      FROM piezas
     WHERE id = v_b.pieza_id AND estado_inventario = 'disponible'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La pieza no está disponible en inventario';
    END IF;

    INSERT INTO publicaciones (
        borrador_id, pieza_id, yonque_id, usuario_publicacion_id,
        titulo, descripcion, precio, condicion, estado
    )
    SELECT v_b.id, v_b.pieza_id, veh.yonque_id, p_usuario_id,
           v_b.titulo, v_b.descripcion_marketplace, v_b.precio_publico,
           v_b.condicion_publicada, 'activa'
      FROM piezas p
      JOIN vehiculos veh ON veh.id = p.vehiculo_id
     WHERE p.id = v_b.pieza_id
    RETURNING id INTO v_pub;

    UPDATE borradores_publicacion
       SET estado = 'publicado', fecha_publicacion = now()
     WHERE id = v_b.id;

    RETURN v_pub;
END;
$$ LANGUAGE plpgsql;

-- Cierra la publicación antes de marcar vendida la pieza, para preservar la
-- integridad publicación-inventario y registrar el usuario/motivo de la venta.
CREATE OR REPLACE FUNCTION procesar_venta(
    p_pieza_id UUID,
    p_vendedor_id UUID,
    p_comprador_nombre VARCHAR DEFAULT NULL,
    p_precio_final DECIMAL DEFAULT NULL,
    p_metodo_pago VARCHAR DEFAULT 'efectivo',
    p_notas TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_p piezas%ROWTYPE;
    v_yonque UUID;
    v_pub UUID;
    v_venta UUID;
    v_precio DECIMAL(12,2);
BEGIN
    SELECT *
      INTO v_p
      FROM piezas
     WHERE id = p_pieza_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pieza no encontrada';
    END IF;

    IF v_p.estado_inventario NOT IN ('disponible', 'reservado') THEN
        RAISE EXCEPTION 'Pieza no vendible. Estado actual: %', v_p.estado_inventario;
    END IF;

    SELECT yonque_id INTO v_yonque
      FROM vehiculos
     WHERE id = v_p.vehiculo_id;

    IF NOT EXISTS (
        SELECT 1
          FROM miembros_yonque
         WHERE yonque_id = v_yonque AND usuario_id = p_vendedor_id AND activo
    ) THEN
        RAISE EXCEPTION 'El vendedor no pertenece a este yonque';
    END IF;

    v_precio := COALESCE(p_precio_final, v_p.precio_venta);
    IF v_precio IS NULL THEN
        RAISE EXCEPTION 'La pieza no tiene precio';
    END IF;

    UPDATE publicaciones
       SET estado = 'vendida', fecha_eliminacion = now()
     WHERE pieza_id = p_pieza_id AND estado IN ('activa', 'pausada')
    RETURNING id INTO v_pub;

    INSERT INTO ventas (
        publicacion_id, pieza_id, yonque_id, vendedor_id, comprador_nombre,
        precio_lista, precio_final, total, metodo_pago, notas, estado
    ) VALUES (
        v_pub, p_pieza_id, v_yonque, p_vendedor_id, p_comprador_nombre,
        COALESCE(v_p.precio_venta, v_precio), v_precio, v_precio,
        p_metodo_pago, p_notas, 'completada'
    )
    RETURNING id INTO v_venta;

    PERFORM cambiar_estado_pieza(p_pieza_id, 'vendido', p_vendedor_id, 'Venta ' || v_venta);
    RETURN v_venta;
END;
$$ LANGUAGE plpgsql;
